/**
 * teamsmith · notify 扩展
 *
 * 作用：worker agent 每结束一个回合（`agent_settled`，Pi 不会再自动继续的那个点），
 * 自动把一条简报写进 PM 的收件箱，并（可选）在 PM 的 tmux 窗口里敲一行把它唤醒。
 *
 * 为什么必须显式 `-e` 加载：linked worktree 里 Pi 不会自动发现项目本地的
 * `.pi/extensions/`（CEP 已验证过），所以 `team dispatch` 用 `-e <skill>/extension/team-notify.ts`
 * 显式传入。
 *
 * 守卫（全部失败都静默，通知绝不能影响 agent 会话）：
 *   - cwd 必须位于 <项目根>/<worktrees>/ 之下（主工作树/PM 会话不触发）
 *   - 窗口名不能等于 PM 窗口名（避免 PM 自触发循环）
 *   - tmux session 必须是配置里的那个
 *   - 同样的简报在 TEAM_NOTIFY_DEDUP_SEC 秒内只发一次（Pi 可能连续 settle）
 *
 * 配置来自 <项目根>/.pi/team/config.sh，仅解析需要的少量扁平 KEY=VALUE，
 * 不 source（不在 agent 的 Node 进程里执行项目代码）。
 */
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent'
import { execFileSync } from 'node:child_process'
import { appendFileSync, existsSync, lstatSync, mkdirSync, readFileSync, readdirSync, realpathSync, rmSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

type Cfg = {
  session: string
  pmWindow: string
  worktreesDir: string
  docsDir: string
  notifyTmux: boolean
  dedupSec: number
  maxChars: number
  log: string
  roster: string[]
}

const DEFAULTS: Cfg = {
  session: 'team',
  pmWindow: 'pm',
  worktreesDir: '.worktrees',
  docsDir: 'docs/team',
  notifyTmux: true,
  dedupSec: 20,
  maxChars: 150,
  log: '/tmp/teamsmith-notify.log',
  roster: [],
}

/** P160 F2 · 修订标识的宽度：HEAD 的**前 12 个十六进制字符**，工具自己截（不用受 core.abbrev
 *  和对象数影响的 `--short`）—— 与 CLI 的 `cut -c1-12` 是同一契约，同一 HEAD 在两个发送方逐字节相同。
 *  接收方不需要 checkout：reviews/<ID>.md 里记的 HEAD 与 tip 互为前缀（同一个 revision）就算已判过
 *  （`team review` 今天写 9 位，12 位的 wire 形状让这个判定不受 Git 设置影响）。 */
const TIP_WIDTH = 12

/** 本扩展所在 skill 的目录（<skill>/extension/team-notify.ts） */
function skillDir(): string {
  try {
    return resolve(dirname(fileURLToPath(import.meta.url)), '..')
  } catch {
    return ''
  }
}

/** 从 <skill>/scripts/lib/common.sh 读 TEAM_VERSION */
function skillVersion(): string {
  try {
    const f = join(skillDir(), 'scripts/lib/common.sh')
    return /^TEAM_VERSION="([^"]+)"/m.exec(readFileSync(f, 'utf8'))?.[1] ?? ''
  } catch {
    return ''
  }
}

function run(cmd: string, args: string[], cwd?: string): string {
  try {
    return execFileSync(cmd, args, { cwd, encoding: 'utf8', timeout: 5000 }).trim()
  } catch {
    return ''
  }
}

function expand(value: string): string {
  return value
    .replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/g, (_, name: string) => process.env[name] ?? '')
    .replace(/\$([A-Za-z_][A-Za-z0-9_]*)/g, (_, name: string) => process.env[name] ?? '')
}

function unquote(raw: string): string {
  const v = raw.trim()
  if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) return v.slice(1, -1)
  return v
}

/** 去掉行尾注释：「值 + 空白 + #...」。配置约定：值里不要写 # */
function stripComment(raw: string): string {
  const m = /^(.*?)\s+#.*$/.exec(raw)
  return m ? m[1] : raw
}

/** 定位团队根目录（期望是主工作树）。
 *  M40：与 team CLI / inbox-watch 同一条原则 —— **cwd 推导优先**，TEAM_ROOT 只在①与推导结果一致、
 *  或②完全推导不出来且它指向一个真项目时被信任。为什么不许 env 优先（M40 实测）：agent 工作树里也有
 *  config.sh 的副本，而收件箱/重载标记必须落在主工作树的账本里 —— env 指到工作树时，旧实现会把 cwd
 *  判成「不在 worktrees 之下」（前缀是 <wt>/.worktrees/），于是**整个回合通知都不发**（收件箱 0 行）。
 *  推导顺序：git 主工作树（账本所在地）→ 向上找 config.sh；两路都推不出来才退回 TEAM_ROOT。 */
function findRoot(cwd: string): string {
  const envRoot = process.env.TEAM_ROOT ? resolve(process.env.TEAM_ROOT) : ''
  let derived = ''
  const common = run('git', ['-C', cwd, 'rev-parse', '--path-format=absolute', '--git-common-dir'])
  if (common) {
    const main = dirname(common)
    if (existsSync(join(main, '.pi/team/config.sh'))) derived = main
  }
  if (!derived) {
    let dir = resolve(cwd)
    for (;;) {
      if (existsSync(join(dir, '.pi/team/config.sh'))) { derived = dir; break }
      const parent = dirname(dir)
      if (parent === dir) break
      dir = parent
    }
  }
  if (envRoot && envRoot !== derived) {
    if (derived) {
      log(`TEAM_IDENTITY_CONFLICT inherited TEAM_ROOT=${envRoot} ≠ cwd-derived=${derived}: using cwd`, readCfg(derived))
      return derived
    }
    if (existsSync(join(envRoot, '.pi/team/config.sh'))) return envRoot
    return ''
  }
  return derived || envRoot
}

/** 后台车道自己写记录的 state 目录（team-bg 的 findRoot + stateDir 两条规则的复刻）——挂起判定
 *  **只**读这里。为什么不拿 notify 自己的 root 顶替（design 决策 4）：本仓 worker worktree 不带 config，
 *  两侧今天巧合都落主工作树；而 worktree 自带 config 的形状（S11 夹具）下车道落 worktree 侧，
 *  notify 的 git-common-dir 就会读错目录。规则：显式 TEAM_STATE_DIR 优先；否则「cwd 的 worktree 带
 *  config → 它自己；TEAM_ROOT（带 config）；最近的带 config 的祖先；git 主工作树（最后的兜底）」。
 *  任何一步推不出来 → 空串（调用方 fail-closed：不挂起）。 */
function laneStateDir(cwd: string): string {
  const envDir = process.env.TEAM_STATE_DIR
  if (envDir) return resolve(envDir)
  let root = ''
  const top = run('git', ['-C', cwd, 'rev-parse', '--path-format=absolute', '--show-toplevel'])
  if (top && existsSync(join(top, '.pi/team/config.sh'))) root = resolve(top)
  const envRoot = process.env.TEAM_ROOT ? resolve(process.env.TEAM_ROOT) : ''
  if (!root && envRoot && existsSync(join(envRoot, '.pi/team/config.sh'))) root = envRoot
  if (!root) {
    let dir = resolve(cwd)
    for (;;) {
      if (existsSync(join(dir, '.pi/team/config.sh'))) { root = dir; break }
      const parent = dirname(dir)
      if (parent === dir) break
      dir = parent
    }
  }
  if (!root) {
    const common = run('git', ['-C', cwd, 'rev-parse', '--path-format=absolute', '--git-common-dir'])
    if (common) {
      const main = dirname(common)
      if (existsSync(join(main, '.pi/team/config.sh'))) root = main
    }
  }
  return root ? join(root, '.pi/team/state') : ''
}

/** notify 自己的落点（它的项目根 + .pi/team/state）。**不许**拿它当车道的目录；只用来在两侧分歧时
 *  记一行日志点名（否则这种错位会静默地读到错目录）。 */
function notifyStateDir(root: string): string {
  return root ? join(root, '.pi/team/state') : ''
}

/** /proc/<pid>/stat 的启动时间指纹（第 22 字段）。comm 字段带空格/括号 → 按**最后一个** `)` 切开再数。
 *  进程不在 / 读不到 → 空串（调用方据此判「不算在跑」）。 */
function procStartTime(pid: number): string {
  try {
    const stat = readFileSync(`/proc/${pid}/stat`, 'utf8')
    const rest = stat.slice(stat.lastIndexOf(')') + 1).trim().split(/\s+/)
    return rest[19] ?? ''
  } catch {
    return ''
  }
}

/** 真实路径（软链与尾斜杠都归一）：只接受绝对路径 —— 相对路径在记录里没有对象可解析，属畸形；
 *  解析失败（路径已不存在 / 无权限）返回空串。调用方拿空串一律 fail-closed（不判挂起，绝不猜）。 */
function realPathOf(p: string): string {
  if (!p || p[0] !== '/') return ''
  try {
    return realpathSync(p)
  } catch {
    return ''
  }
}

/** P236 · 本会话的归属路径集合（真实路径）：会话自己的 cwd 与它所在的工作树。任一路径解析失败就不
 *  放进去 —— 集合为空 = 一条作业都不认（fail-closed 的极端形状，好过认错别人的作业）。 */
function ownedSessionPaths(cwd: string, worktree: string): Set<string> {
  const owned = new Set<string>()
  for (const p of [cwd, worktree]) {
    const real = realPathOf(resolve(p))
    if (real) owned.add(real)
  }
  return owned
}

/** P236 · 归属判据：作业记录里的 `cwd`（作业启动时的工作目录，也就是拥有它的那个席位的工作树）
 *  解析到本会话自己的工作树/cwd（真实路径相等）才算「我的作业」。缺 `cwd`、相对路径、解析失败、
 *  或指向别人的工作树 → 都不算（fail-closed）。 */
function isOwnedCwd(jobCwd: string, owned: Set<string>): boolean {
  const real = realPathOf(jobCwd)
  return real !== '' && owned.has(real)
}

/** 在跑作业集合：读车道目录下的 `bg/*.job`，逐条做 (pid, start-time) 活体验证（与 `team bg list`
 *  同一条身份规则），再按 `cwd` 只留**本会话自己的**作业（P236 归属范围 —— 同一车道目录里的记录
 *  可能属于别的席位，把别人的长作业算成自己挂起会污染 `awaiting=`）。任何一条失败都**跳过**
 *  （目录/记录读不了、软链-FIFO 记录、pid 非正整数、start 缺失、/proc 读不到、指纹不符、cwd 缺失
 *  或不属于本会话）—— fail-closed：判定的不确定方向永远是「不挂起」，绝不假造挂起（design 决策 4）。 */
function runningLaneJobs(laneDir: string, owned: Set<string>): string[] {
  if (!laneDir || owned.size === 0) return []
  let names: string[]
  try {
    names = readdirSync(join(laneDir, 'bg'))
  } catch {
    return [] // 车道还没起过作业（目录不存在）/ 读不了：没有在跑作业
  }
  const ids: string[] = []
  for (const name of names.sort()) {
    if (!name.endsWith('.job')) continue
    const id = name.slice(0, -'.job'.length)
    if (!/^[A-Za-z0-9._-]+$/.test(id)) continue // 平坦 id（读侧边界与 team bg 同规则）
    try {
      const file = join(laneDir, 'bg', name)
      if (!lstatSync(file).isFile()) continue // 软链 / FIFO / 目录：记录畸形
      const fields: Record<string, string> = {}
      for (const line of readFileSync(file, 'utf8').split(/\r?\n/)) {
        const i = line.indexOf('=')
        if (i > 0) fields[line.slice(0, i).trim()] = line.slice(i + 1).trim()
      }
      const pid = Number(fields.pid ?? '')
      const start = fields.start ?? ''
      if (!Number.isInteger(pid) || pid <= 0 || !start) continue
      if (procStartTime(pid) !== start) continue // 死进程 / pid 复用 / /proc 读不到：都不算在跑
      if (!isOwnedCwd(fields.cwd ?? '', owned)) continue // P236：别人的作业不算自己挂起
      ids.push(id)
    } catch {
      continue // 读不了：不算在跑
    }
  }
  return ids
}

function readCfg(root: string): Cfg {
  const file = process.env.TEAM_CONFIG_FILE || join(root, '.pi/team/config.sh')
  const cfg: Cfg = { ...DEFAULTS }
  let text = ''
  try {
    text = readFileSync(file, 'utf8')
  } catch {
    return cfg
  }
  const values: Record<string, string> = {}
  for (const line of text.split(/\r?\n/)) {
    const m = /^\s*(TEAM_[A-Z0-9_]+)\s*=\s*(.*?)\s*$/.exec(line)
    if (!m) continue
    const raw = m[2]
    values[m[1]] = expand(unquote(stripComment(raw)))
  }
  const pick = (key: string): string | undefined => values[key]?.trim() || undefined
  cfg.session = pick('TEAM_SESSION') ?? cfg.session
  cfg.pmWindow = pick('TEAM_PM_WINDOW') ?? cfg.pmWindow
  cfg.worktreesDir = pick('TEAM_WORKTREES_DIR') ?? cfg.worktreesDir
  cfg.docsDir = pick('TEAM_DOCS_DIR') ?? cfg.docsDir
  if (pick('TEAM_NOTIFY_TMUX')) cfg.notifyTmux = values.TEAM_NOTIFY_TMUX !== '0' && values.TEAM_NOTIFY_TMUX !== 'false'
  const dedup = Number(pick('TEAM_NOTIFY_DEDUP_SEC') ?? NaN)
  if (Number.isFinite(dedup) && dedup >= 0) cfg.dedupSec = dedup
  const max = Number(pick('TEAM_INBOX_MAX_CHARS') ?? NaN)
  if (Number.isFinite(max) && max > 0) cfg.maxChars = max
  cfg.log = pick('TEAM_NOTIFY_LOG') ?? cfg.log
  cfg.roster = (pick('TEAM_AGENTS') ?? '').split(/[\s,]+/).filter(Boolean)
  return cfg
}

/** 发送者解析（与 CLI 的 team_sender_from_dir 同规则，见 openspec/changes/notify-sender-identity/design.md §2）：
 *  cwd 在 <root>/<worktrees>/ 之下（上面那个守卫已经证明）→ 路径的一级目录名就是席位；名册里真有这个名字时
 *  取名册里的拼写，不匹配时目录名自己就是发送者（review-<ID> 这类非席位目录也算名字）。推不出来 → 空串。 */
function senderFromDir(cwd: string, wtPrefix: string, roster: string[]): string {
  const rel = `${cwd}`.slice(wtPrefix.length)
  const first = rel.split('/')[0] ?? ''
  if (!first) return ''
  return roster.find(name => name === first) ?? first
}

function tail(line: string, max: number): string {
  const flat = line.replace(/\s+/g, ' ').trim()
  return flat.length > max ? `${flat.slice(0, max - 1)}…` : flat
}

/** P160 F3 · 任务标识的证据：<ID> 必须在 state/<sender>.env 的 task=、看板行或任务书里真的存在
 *  （与 CLI 的 team_notify_task_proven 同一组判据）。席位名（agent/<席位>）不是任务；没有证据就不盖。 */
function hasTaskEvidence(root: string, cfg: Cfg, agent: string, id: string): boolean {
  const stateDir = process.env.TEAM_STATE_DIR || join(root, '.pi/team/state')
  try {
    const st = readFileSync(join(stateDir, `${agent}.env`), 'utf8')
    if (st.split(/\r?\n/).some(l => l.trim() === `task=${id}`)) return true
  } catch { /* 没有这个席位的状态记录 */ }
  const tasksDir = join(root, cfg.docsDir, 'tasks')
  try {
    if (existsSync(join(tasksDir, `${id}.md`))) return true
    if (readdirSync(tasksDir).some(f => f.startsWith(`${id}-`) && f.endsWith('.md'))) return true
  } catch { /* 没有任务书目录 */ }
  try {
    for (const line of readFileSync(join(root, cfg.docsDir, 'BOARD.md'), 'utf8').split(/\r?\n/)) {
      if (!line.trimStart().startsWith('|')) continue
      const cells = line.split('|')
      if ((cells[1] ?? '').trim() === id) return true
    }
  } catch { /* 没有看板 */ }
  return false
}

/** 一条 assistant 消息里的文本（字符串或 content parts） */
function messageText(content: unknown): string {
  if (typeof content === 'string') return content
  if (Array.isArray(content)) {
    return content
      .map(part => (part && typeof part === 'object' && 'text' in part ? String((part as { text?: unknown }).text ?? '') : ''))
      .join(' ')
  }
  return ''
}

/** 回合是否真的完成了：模型给了最终答复（stop/length）才算。
 *  toolUse = 还在调工具（mid-turn）；aborted/error = 被中断。M4.3 E：只有前者能当「最后消息」。 */
function isCompletedTurn(stopReason: string): boolean {
  return stopReason === 'stop' || stopReason === 'length'
}

function log(line: string, cfg: Cfg): void {
  try {
    appendFileSync(cfg.log, `${new Date().toISOString()} ${line}\n`)
  } catch {
    /* ignore */
  }
}

/** 内容指纹（FNV-1a 32 位）：去重键必须能区分「前缀相同、后半不同」的简报（M6.3 F17） */
function fingerprint(text: string): string {
  let h = 0x811c9dc5
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i)
    h = Math.imul(h, 0x01000193) >>> 0
  }
  return h.toString(16).padStart(8, '0')
}

/** 同一条简报在 dedupSec 秒内只发一次 */
function isDuplicate(key: string, sec: number, stateDir: string): boolean {
  if (sec <= 0) return false
  const file = join(stateDir, 'notify-dedup')
  const now = Date.now()
  const rows: Array<[string, number]> = []
  try {
    for (const line of readFileSync(file, 'utf8').split('\n')) {
      const idx = line.indexOf(' ')
      if (idx <= 0) continue
      const t = Number(line.slice(0, idx))
      if (Number.isFinite(t) && now - t < sec * 1000) rows.push([line.slice(idx + 1), t])
    }
  } catch {
    /* first run */
  }
  if (rows.some(([k]) => k === key)) return true
  rows.push([key, now])
  try {
    writeFileSync(file, rows.map(([k, t]) => `${t} ${k}`).join('\n') + '\n')
  } catch {
    /* ignore */
  }
  return false
}

export default function (pi: ExtensionAPI) {
  let count = 0

  // M4.3 E：内部生命周期事件（压缩 / 会话重启 / reload）会以**同一个回合里的 settle** 形式冒出来，
  // 而那不是「agent 交回合了、在等 PM」（现场：PM 收到一条读起来像「agent 停了但还有未提交文件」的
  // 通知，其实 agent 正 mid-turn）。这里记「本回合内发生过什么」，settle 时据此判断真伪。
  // 回合边界用 before_agent_start（一次用户提交只发一次；继续/重试/压缩不走它）。
  let lifecycleDuringTurn = ''
  const noteLifecycle = (what: string): void => {
    lifecycleDuringTurn = what
  }
  pi.on('before_agent_start', async () => {
    lifecycleDuringTurn = ''
  })
  pi.on('session_start', async (event: any) => {
    // startup 是正常开局；reload/new/resume/fork 都是「会话被换掉了」的内部事件
    const reason = String(event?.reason ?? '')
    if (reason && reason !== 'startup') noteLifecycle(`session_start(${reason})`)
  })
  pi.on('session_before_compact', async () => noteLifecycle('compaction'))
  pi.on('session_compact', async (event: any) => noteLifecycle(`compaction(${String(event?.reason ?? '?')})`))
  pi.on('session_compact_failed', async () => noteLifecycle('compaction-failed'))
  pi.on('session_shutdown', async (event: any) => noteLifecycle(`session_shutdown(${String(event?.reason ?? '?')})`))

  pi.on('agent_settled', async (_event, ctx) => {
    const cwd = ctx.cwd ?? process.cwd()
    const root = findRoot(cwd)
    if (!root) return
    const cfg = readCfg(root)

    const wtPrefix = `${resolve(root, cfg.worktreesDir)}/`
    if (!`${resolve(cwd)}`.startsWith(wtPrefix)) {
      log(`skip settle (not in worktrees): cwd=${cwd} root=${root} prefix=${wtPrefix}`, cfg)
      return
    }

    const pane = process.env.TMUX_PANE
    const window = pane ? run('tmux', ['display-message', '-p', '-t', pane, '#{window_name}']) : ''
    const session = pane ? run('tmux', ['display-message', '-p', '-t', pane, '#{session_name}']) : ''
    if (window && window === cfg.pmWindow) {
      log(`skip settle (pm window): window=${window}`, cfg)
      return
    }
    if (window && session && session !== cfg.session) {
      log(`skip settle (session ${session} != ${cfg.session})`, cfg)
      return
    }

    // P82（notify-sender-identity）：发送者 = **运行时目录**（M40 身份），不是窗口名。
    // cwd 在这个守卫里已经证明位于 <root>/<worktrees>/ 之下 → 取那段路径的一级目录名（名册里的席位优先）；
    // 窗口名是可改的 UI 状态、headless 时不存在，只用来发现并记录分歧（设计 §2 的裁决）。
    const agent = senderFromDir(resolve(cwd), wtPrefix, cfg.roster)
    if (!agent) {
      log(`skip settle (worktrees prefix matches but names no sender): cwd=${cwd}`, cfg)
      return
    }
    if (window && window !== agent) log(`window ${window} ignored: the runtime directory names ${agent}`, cfg)
    const branch = run('git', ['-C', cwd, 'rev-parse', '--abbrev-ref', 'HEAD'])
    const task = /^(?:task|agent)\/([^/]+)/.exec(branch)?.[1] ?? ''
    const id = task.split('-')[0] || 'unknown'
    // R2/P160：通知要指认它讲的是哪个修订 —— task 从分支推，tip 从 HEAD 推；非任务分支（主工作树/
    // 临时工作树/普通席位分支 agent/<席位>）没有 task 语义就不盖（宁可没有，不许编造），
    // 而且 task/<ID>-… 的 <ID> 必须有任务证据（state/<agent>.env 的 task=、看板行或任务书）。
    const isTaskBranch = /^task\//.test(branch)
    const proven = isTaskBranch && id !== 'unknown' && hasTaskEvidence(root, cfg, agent, id)
    const tip = proven ? run('git', ['-C', cwd, 'rev-parse', 'HEAD']).slice(0, TIP_WIDTH) : ''
    const revStamp = tip ? ` · task=${id} tip=${tip}` : ''
    const dirty = run('git', ['-C', cwd, 'status', '--porcelain']).split('\n').filter(Boolean).length
    const upstream = run('git', ['-C', cwd, 'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}'])
    const unpushed = upstream
      ? run('git', ['-C', cwd, 'rev-list', '--count', '@{upstream}..HEAD']) || '?'
      : run('git', ['-C', cwd, 'rev-list', '--count', 'HEAD', '--not', '--remotes']) || '?'

    // 最后一条 assistant 消息才是「本轮的最后消息」；只有**完成了的回合**才允许当摘要（M4.3 E）。
    // 旧实现在回合未完成时从末尾往前找第一条有文本的消息 —— 于是一轮长工具调用里的开头那句
    // （"I'll start by reading the required files in order."）被当成结论报给 PM，读起来像「agent 停了」。
    let last = ''
    let completed = false
    try {
      const entries = ctx.sessionManager.getEntries() as Array<{ message?: { role?: string; stopReason?: string; content?: unknown } }>
      for (let i = entries.length - 1; i >= 0; i--) {
        const message = entries[i]?.message
        if (message?.role !== 'assistant') continue
        completed = isCompletedTurn(String(message.stopReason ?? ''))
        if (completed) last = tail(messageText(message.content), cfg.maxChars)
        break
      }
    } catch {
      /* 通知绝不能打断会话 */
    }

    // 挂起判定（design 决策 4 + P236 归属范围）：在跑集合从**车道自己写记录的目录**读（laneStateDir），
    // 逐条 (pid, start-time) 验活、再按 cwd 只留**本会话自己的**作业；判定失败一律退回非挂起形状
    // （fail-closed）——既不假造挂起，也不拿 notify 自己的 root 顶替车道目录（两侧分歧时它只负责把
    // 这件事记进日志）。
    // P236（缺陷现场）：同一车道目录里的记录可能属于**别的席位** —— 只看「项目里有活作业」会把别人的
    // 长作业算成自己挂起。归属判据 = 作业的 cwd 与本会话自己的工作树/cwd 解析到同一个真实路径。
    const laneDir = laneStateDir(cwd)
    const ownDir = notifyStateDir(root)
    if (laneDir && ownDir && laneDir !== ownDir) {
      log(`suspend check reads the lane's directory ${laneDir} (notify's own root would be ${ownDir})`, cfg)
    }
    const owned = ownedSessionPaths(cwd, join(wtPrefix, agent))
    const running = runningLaneJobs(laneDir, owned)
    const awaiting = running.length > 0 ? `awaiting=${running.join(',')}` : ''
    const suspended = completed && running.length > 0

    const summary = [
      `agent:${agent}`,
      id,
      `branch=${branch || '-'}`,
      `uncommitted=${dirty}`,
      ...(awaiting ? [awaiting] : []),
      `unpushed=${unpushed}${upstream ? '' : '(no-upstream)'}`,
    ].join(' · ')
    // 未完成的回合 + 本轮内有过生命周期事件 = 内部重启/压缩的产物，不是交付：不发简报、不敲门。
    // 未完成但**没有**生命周期事件（Esc / 错误）仍然告诉 PM，只是绝不带摘要（不编造「最后消息」）。
    if (!completed && lifecycleDuringTurn) {
      log(`skip settle (${lifecycleDuringTurn} 期间的 settle，回合未完成 → 不是交付) ${summary}`, cfg)
      lifecycleDuringTurn = ''
      return
    }
    lifecycleDuringTurn = ''

    // 未提交 = 没交付干净：让 PM 一眼看出来（CEP 实测：这种状态和"干净交付"在通知里长得一样）。
    // 挂起不是交付主张：省略 ⚠ 前缀（事实留在 uncommitted=<n> 字段里），否则告警框只会误导。
    const dirtyFlag = dirty > 0 && !suspended ? `⚠ 未提交 ${dirty} 个文件 · ` : ''

    count++
    const tag = completed ? (suspended ? '[auto·suspended]' : '[auto]') : '[auto·interrupted]'
    // 去重键：整条末消息的「长度+指纹」+ 修订标识（新 tip = 新修订，不该被去重吞掉）。
    // 老键（last[0:60]）会把三条开头相同、后半不同的简报当成同一条吞掉（M6.3 F17）。
    const key = `${agent}|${tag}|${summary}|${revStamp}|${last.length}:${fingerprint(last)}`

    const stateDir = join(root, '.pi/team/state')
    try {
      mkdirSync(stateDir, { recursive: true })
    } catch {
      /* ignore */
    }
    if (isDuplicate(key, cfg.dedupSec, stateDir)) {
      log(`dedup settle #${count} ${summary}`, cfg)
      return
    }

    const line = `${new Date().toISOString()} ${dirtyFlag}${tag} ${summary}${revStamp}${completed && last ? ` :: ${last}` : ''}`
    // turn-notice-merge（写入侧合并 + 明细）：判定「扩展末尾的同类 run 还是新起一行」在 CLI 的收件箱
    // 写入口里（每收件人一把锁 + 先明细后合并），扩展只消费写入结果 —— 只有写下**新行**才入队 knock。
    const cli = join(skillDir(), 'scripts/team')
    const lineFile = join(stateDir, `notify-line-${process.pid}-${Date.now()}.txt`)
    let writeOut = ''
    try {
      writeFileSync(lineFile, line)
      writeOut = execFileSync(
        'bash',
        [cli, '--root', root, '__inbox-write', '--agent', agent, '--from-file', lineFile],
        { encoding: 'utf8', timeout: 5000 },
      )
      log(`inbox ${tag} ${summary}`, cfg)
    } catch (error) {
      writeOut = ''
      log(`inbox write failed: ${String(error)}`, cfg)
    } finally {
      try { rmSync(lineFile, { force: true }) } catch { /* ignore */ }
    }
    const writeState = /^state=([a-z]+)/m.exec(writeOut)?.[1] ?? ''
    if (writeState !== 'new') {
      // 扩展既有 run（state=extended）的 settle 不入队、不敲字：计数抖动看得见但不叫醒。
      // 写盘失败（异常 / state=failed）也不叫醒 —— 与手工路径的「写失败不得授权唤醒」同一条规则。
      log(`no knock (inbox write state=${writeState || 'failed'})`, cfg)
      return
    }

    // 挂起只记录、不叫醒（用户裁定 2026-10-14）：`[auto·suspended]` 是设计好的状态（席位起了长任务并
    // 正确地结束回合等叫醒），PM 没有可行动的事 —— 行、明细、面板、digest 照旧，但不入队 knock。交付
    // （要复验/合并）与中断（要诊断）照旧敲门；挂起中的失败面（席位死去、任务永不完）归巡检的
    // 「任务未完成 + 窗口不在」那一档，不由这条通知兜。
    if (suspended) {
      log('no knock (suspended records only)', cfg)
      return
    }
    const firstEvent = /^first=(\S+)/m.exec(writeOut)?.[1] ?? ''
    const mergeKey = /^key=(\S*)/m.exec(writeOut)?.[1] ?? ''
    // knock 的去重身份 = **行身份**（席位 + 合并键 + 首事件时间）：两条文本逐字相同但不同的行不会互吞，
    // 同一 run 的重复 settle 也绝不会二次敲门（此时它连条目都不入队）。席位是 mergeKey 的第一个分量。
    const lineIdentity = `line|${mergeKey}|${firstEvent}`

    if (!cfg.notifyTmux || !window) return
    const target = `${cfg.session}:${cfg.pmWindow}`
    try {
      // 安全：只有当 PM 窗口里真的在跑 pi 时才敲键盘。
      // 否则（PM 已退出、窗口停在 shell）send-keys 会被 shell 当命令执行。
      const paneCmd = run('tmux', ['display-message', '-p', '-t', target, '#{pane_current_command}'])
      if (!paneCmd || /^(bash|sh|zsh|fish|dash|ash|ksh|nu)$/.test(paneCmd)) {
        log(`skip tmux notify (pm not running: pane=${paneCmd || 'missing'}) inbox only`, cfg)
        return
      }
    } catch {
      /* PM 窗口不在：只留收件箱 */
      return
    }
    // 敲门不再自己 send-keys：交给 teamsmith 的投递守卫 + 延后队列（delivery-guard）。
    // 为什么：扩展原来直接 `send-keys -l` + Enter，人正在 PM 输入框里写草稿时会把草稿粘走
    // （D20 的原始事故）。入队时带上 knock 自己的**行身份**（lineIdentity），两层抑制不会打架。
    // 失败只记日志：绝不回退到打字（那会悄悄重建同一个 bug）。
    const notice = `${dirtyFlag}${tag} ${summary}${revStamp}${completed && last ? `\n> ${last}` : ''}`
    const tmp = join(stateDir, `knock-${process.pid}-${Date.now()}.txt`)
    try {
      writeFileSync(tmp, notice)
      const out = execFileSync(
        'bash',
        [cli, '--root', root, 'outbox', 'enqueue', '--kind', 'knock', '--target', target,
         '--from', agent, '--dedup', lineIdentity, '--from-file', tmp],
        { encoding: 'utf8', timeout: 5000 },
      )
      log(`knock queued (${String(out).trim() || 'entry written'})`, cfg)
    } catch (error) {
      log(`knock enqueue failed — inbox line kept, NOT falling back to typing: ${String(error)}`, cfg)
    } finally {
      try { rmSync(tmp, { force: true }) } catch { /* ignore */ }
    }
    try {
      // 一次有界排水：PM 输入框空则立刻投递；有草稿则留在队列（下一次 tick / flush 再送）
      execFileSync('bash', [cli, '--root', root, 'outbox', 'flush', '--quiet'], { timeout: 5000 })
    } catch { /* PM 窗口不在或队列不可写：条目已经落盘，下一次 drain 再送 */ }
  })

  // ---------------------------------------------------------------------------
  // skill 热重载：/teamsmith-reload（/reload 的别名，语义更直白）
  //
  // 为什么需要：skill 更新后，`scripts/**` 立刻生效，但 SKILL.md 的清单/描述
  // 只在下一次资源加载时才刷新。Pi 的 /reload 会重新发现 skills 并重建 system prompt，
  // 所以 PM 发现版本落后时跑这个命令即可，不必重启会话。
  // 工具 reload_skills 让模型也能自助触发：Pi 的工具跑在 ExtensionContext 里，
  // 不能直接调 ctx.reload()，得把命令作为 follow-up 消息排队（官方推荐做法）。
  const reloadHandler = {
    description: '重新加载 skills/扩展（等同于 /reload）——skill 更新后用它生效',
    handler: async (ctx: any) => {
      try {
        log('teamsmith-reload: reloading resources', readCfg(findRoot(ctx?.cwd ?? process.cwd()) ?? process.cwd()))
      } catch { /* ignore */ }
      if (typeof ctx?.reload === 'function') {
        await ctx.reload()
        return
      }
      if (typeof ctx?.showMessage === 'function') ctx.showMessage('当前环境不支持热重载：请手动输入 /reload')
    },
  }
  if (typeof (pi as any).registerCommand === 'function') pi.registerCommand('teamsmith-reload', reloadHandler)
  // 兼容别名：旧名（v1.13.0 前叫 pi-team）
  if (typeof (pi as any).registerCommand === 'function') {
    try { pi.registerCommand('pi-team-reload', reloadHandler) } catch { /* ignore */ }
  }

  // ---------------------------------------------------------------------------
  // /reload 之后：历史里已经读过的 SKILL.md 是旧文本（Pi 不会改写历史消息），
  // 所以这里主动提醒 agent 重新 read 一遍 skill —— 否则"重载"只刷新了清单/描述，
  // 正文仍是旧的。顺带清掉 team reload 留下的请求标记。
  pi.on('session_start', async (event: any, ctx: any) => {
    try {
      if (event?.reason !== 'reload') return
      const cwd = ctx?.cwd ?? process.cwd()
      const root = findRoot(cwd)
      if (!root) return
      const v = skillVersion()
      const dir = skillDir()
      // 重载已完成 → 清掉请求标记
      try {
        const marker = join(root, '.pi/team/state/reload-requested')
        if (existsSync(marker)) rmSync(marker, { force: true })
      } catch {
        /* ignore */
      }
      const text =
        `[teamsmith] skill 已重载${v ? `（v${v}）` : ''}：**历史里读过的 SKILL.md 是旧版**，` +
        `当前会话不会自动更新那段文本。请现在重新 read ${dir}/SKILL.md` +
        `（需要时再读 references/ 或 templates/），然后跑 \`team version --check\` 记录新版本。`
      ;(pi as any).sendMessage(
        { customType: 'teamsmith-reloaded', content: text, display: true },
        { deliverAs: 'followUp', triggerTurn: true },
      )
    } catch {
      /* 重载提示绝不能影响会话 */
    }
  })

  if (typeof (pi as any).registerTool === 'function') pi.registerTool({
    name: 'reload_skills',
    description:
      '重新加载 skill/扩展定义（等同于 /reload）。当 team version --check 提示 skill 已更新时调用它。',
    parameters: { type: 'object', properties: {}, additionalProperties: false } as any,
    async execute(_toolCallId: string, _params: any, _signal: any, _onUpdate: any, ctx: any) {
      const prompt = '/teamsmith-reload'
      if (typeof ctx?.queueFollowUp === 'function') {
        await ctx.queueFollowUp(prompt)
      } else if (typeof ctx?.pi?.queueFollowUp === 'function') {
        await ctx.pi.queueFollowUp(prompt)
      } else if (typeof ctx?.sendMessage === 'function') {
        await ctx.sendMessage(prompt)
      } else {
        return {
          content: [
            { type: 'text', text: `请手动运行 ${prompt}（当前上下文不支持排队 follow-up 消息）` },
          ],
        }
      }
      return { content: [{ type: 'text', text: `已排队 ${prompt}：本回合结束后会自动重新加载 skill。` }] }
    },
  } as any)
}
