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
import { appendFileSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
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
    // R2：通知要指认它讲的是哪个修订 —— task 从分支推，tip 从 HEAD 短哈希；
    // 非任务分支（主工作树/临时工作树）没有 task 语义就不盖（宁可没有，不许编造）。
    const isTaskBranch = /^(?:task|agent)\//.test(branch)
    const tip = isTaskBranch ? run('git', ['-C', cwd, 'rev-parse', '--short', 'HEAD']) : ''
    const revStamp = isTaskBranch && tip ? ` · task=${id} tip=${tip}` : ''
    const dirty = run('git', ['-C', cwd, 'status', '--porcelain']).split('\n').filter(Boolean).length
    // 未提交 = 没交付干净：让 PM 一眼看出来（CEP 实测：这种状态和"干净交付"在通知里长得一样）
    const dirtyFlag = dirty > 0 ? `⚠ 未提交 ${dirty} 个文件 · ` : '' 
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

    const summary = [
      `agent:${agent}`,
      id,
      `branch=${branch || '-'}`,
      `uncommitted=${dirty}`,
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

    count++
    const tag = completed ? '[auto]' : '[auto·interrupted]'
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
    try {
      const dir = join(root, cfg.docsDir, 'inbox')
      mkdirSync(dir, { recursive: true })
      appendFileSync(join(dir, `${agent}.md`), `- ${line}\n`)
      log(`inbox ${tag} ${summary}`, cfg)
    } catch (error) {
      log(`inbox write failed: ${String(error)}`, cfg)
    }

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
    // （D20 的原始事故）。入队时带上扩展自己的去重键（key），两层抑制不会打架。
    // 失败只记日志：绝不回退到打字（那会悄悄重建同一个 bug）。
    const notice = `${dirtyFlag}${tag} ${summary}${revStamp}${completed && last ? `\n> ${last}` : ''}`
    const cli = join(skillDir(), 'scripts/team')
    const tmp = join(stateDir, `knock-${process.pid}-${Date.now()}.txt`)
    try {
      writeFileSync(tmp, notice)
      const out = execFileSync(
        'bash',
        [cli, '--root', root, 'outbox', 'enqueue', '--kind', 'knock', '--target', target,
         '--from', agent, '--dedup', key, '--from-file', tmp],
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
