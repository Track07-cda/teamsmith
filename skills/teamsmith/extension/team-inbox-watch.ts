/**
 * teamsmith · inbox-watch 扩展 — 投递换道：收件箱监视唤醒取代输入框粘贴（M30）
 *
 * 为什么换道：自动化消息以前只有一条投递路径 —— `tmux send-keys -l` + `Enter` 直接打进 pi 的
 * 输入框。五次 draft-race 事故（D20 / M17 / M24 / …）证明「人的草稿 vs 我们刚贴进去的 payload」
 * 在真实 TUI 上判不准：一个错误的 ENTER 就把人写了一半的话送出去。用户拍板：不再修框检测。
 *
 * pi 通道现在的形状（完全不碰输入框）：
 *   1. 发送方（outbox.sh）把消息写进 **durable 收件箱** `docs/team/inbox/<name>.md`（唯一真相）；
 *   2. 再往本项目 `state/inbox-watch/<key>.wake` 追加**一行指针**（kind / from / inbox / 截断预览）；
 *   3. 本扩展 `fs.watch` 那个目录，读到新行就
 *      `pi.sendMessage({customType:'team-inbox'}, …, {triggerTurn:true, deliverAs:'followUp'})`
 *      —— 消息进会话队列（agent 空闲时立刻触发一轮），输入框一个键都不碰。
 *
 * 就绪注册（发送方据此判定「目标是 pi 且有监视」）：`state/inbox-watch/<key>.reg` 里写
 * target / inbox / pid / cwd / started / heartbeat；心跳每 HEARTBEAT_MS 刷新。`team_inbox_watch_route`
 * 只认「pid 活着 + cwd 在本项目内」的注册（心跳是 cwd 读不出来时的兜底判据，也是排障时间线）。
 *
 * 投递纪律（照 E8 §5 与 team-bg 的实测教训）：
 *   - 一个新行 = 一次唤醒；同一拍到的多行**合并成一条**（merge window），不按行刷屏；
 *   - 唤醒消息只带**一行指针 + 截断预览**，不带 payload 全文（全文在收件箱；防注入习惯不变）；
 *   - session 启动时以 spool 当前大小为基线：**历史行不叫醒任何人**（backlog 是 pulse 的活），
 *     启动**之后**写入的行才唤醒 —— 关掉这个窗口的原语就是 M30 验收里那条「启动前的行不唤醒」；
 *   - spool 有上限（TEAM_INBOX_WATCH_MAX_BYTES，默认 128KB）：超了截头留尾（尾部信号不丢）；
 *   - **spool 变小（size < offset）= 外部截断/重写**（M43：仓内写路径只有 `>>` 追加，变小一定是
 *     外部力量）。旧行为是静默 `offset = 0`、下一拍把整个 spool 从 0 重读 —— 2026-09-19 就是这条
 *     把同一份 42 行叫了两遍、`total` 灌水 84。现在的语义（投递保真三条）：
 *       1. **shrink 必记账本**（`spool shrink …` 一行），不再是静默重置；
 *       2. **去重**：整行 `(epoch_ms, kind, from, durable, preview)` 元组进过去重记忆（内存 +
 *          `<key>.seen` 持久化，跨会话重启有效），已投递的行一律不再投；
 *       3. **有界重放**：shrink 后的 rescan 对「真新」行只投最近 TEAM_INBOX_WATCH_REPLAY_MAX 条
 *          （默认 20），更早的跳过并在唤醒文本与账本里说明；全去重压掉时**不唤醒**（没什么好说的），
 *          账本记 `rescan … deliver=0`。
 *     `seen`（账本 `total=`）只随**真实投递**增长 —— 重放/去重跳过都不计数。
 *
 * 生命周期（Pi 文档的硬约束）：factory 里不起任何后台资源；watch / 定时器 / 注册文件都在
 * session_start 里建、session_shutdown 里清（并删掉自己的注册文件 —— 不然发送方会一直以为
 * 「有个活着的监视器」而不再走粘贴路径）。任何失败都只写自己的账本（state/inbox-watch.log），
 * 绝不抛进会话。
 *
 * 降级可见（M46）：跳过 setup 不再只写日志 —— 本项目 state/inbox-watch/<key>.skip 记下「哪个 target、
 * 为什么跳过」（reason=session-mismatch / …），doctor / status / digest / 面板据此报「本项目 PM 没有
 * inbox-watch 注册 → 通知走输入框慢路径」；成功注册会删掉同 target 的旧记录。state 目录一律锚定
 * cwd 推导出的项目根：继承来的 TEAM_STATE_DIR / TEAM_CONFIG_FILE 若指向**另一个 teamsmith 项目**，
 * 一律拒绝并记账本（绝不把别人家的 state / 会话名当自己的，M40 原则的文件面）。
 *
 * 作用域：只认本项目（git 主工作树）的 state 目录 —— 注册与 spool 是**发送方与会话之间的接口**
 * （发送方是 CLI，它的 TEAM_STATE_DIR 在主工作树），所以它们必须待在共享根，不能跟着会话的 worktree 走。
 * 会话本地的产物（作业日志/账户）不归这里管（那是 team-bg 的活，它跟会话自己的工作树走）。只服务
 * dispatch/PM 启动链 `-e` 注入的团队会话 —— 用户自己的 pi 会话没有它。
 */
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent'
import { execFileSync } from 'node:child_process'
import { appendFileSync, closeSync, existsSync, mkdirSync, openSync, readFileSync, readSync, readdirSync, realpathSync, renameSync, rmSync, statSync, watch, writeFileSync } from 'node:fs'
import { basename, dirname, join, resolve } from 'node:path'

const DEFAULT_PREVIEW = 160          // 预览截断（字符）：唤醒消息只带一行指针，不带全文
const DEFAULT_MAX_BYTES = 128 * 1024 // spool 上限
const DEFAULT_POLL_MS = 5000         // fs.watch 的兜底轮询（错过 inotify 事件时仍能醒来）
const DEFAULT_HEARTBEAT_MS = 5000    // 注册心跳
const DEFAULT_REPLAY_MAX = 20        // shrink 后 rescan 的「真新」行投递上限（更早的跳过并说明）
const DEFAULT_SEEN_MAX = 512         // 去重记忆的容量（最近投递的行键，持久化到 <key>.seen）
const HEAD_BYTES = 256               // 头部指纹前缀（P28/B2：回退时比较「开头有没有被改写」）
const DEFAULT_CLAMP_BYTES = 64       // 头部不变、回退 ≤ 此字节数 = 我们自己的 offset 错了（修复，不是重写）
const DEFAULT_STALE_SEC = 900        // 行年龄超过此秒数 = 过期：只计数、不唤醒（P28/B3/R3）
const MERGE_MS = 150                 // 同一拍到的多行合并成一条唤醒
const MAX_LISTED = 5                 // 一条唤醒消息里最多列几条

function envNum(name: string, fallback: number, min: number): number {
  const n = Number(process.env[name] ?? NaN)
  return Number.isFinite(n) && n >= min ? n : fallback
}

function previewLimit(): number { return envNum('TEAM_INBOX_WATCH_PREVIEW', DEFAULT_PREVIEW, 16) }
function maxBytes(): number { return envNum('TEAM_INBOX_WATCH_MAX_BYTES', DEFAULT_MAX_BYTES, 1024) }
function pollMs(): number { return envNum('TEAM_INBOX_WATCH_POLL_MS', DEFAULT_POLL_MS, 100) }
function heartbeatMs(): number { return envNum('TEAM_INBOX_WATCH_HEARTBEAT_MS', DEFAULT_HEARTBEAT_MS, 100) }
function replayMax(): number { return envNum('TEAM_INBOX_WATCH_REPLAY_MAX', DEFAULT_REPLAY_MAX, 1) }
function seenMax(): number { return envNum('TEAM_INBOX_WATCH_SEEN_MAX', DEFAULT_SEEN_MAX, 32) }
function clampBytes(): number { return Math.min(1024 * 1024, envNum('TEAM_INBOX_WATCH_CLAMP_BYTES', DEFAULT_CLAMP_BYTES, 1)) }
function staleSec(): number { return envNum('TEAM_INBOX_WATCH_STALE_SEC', DEFAULT_STALE_SEC, 1) }

/**
 * 定位团队根（主工作树）：M40 —— **cwd 推导为准**（与 team CLI 同一条原则）。
 * TEAM_ROOT 只在①与推导结果一致，或②完全推导不出来且它指向一个真项目时被信任；
 * 不一致时按 cwd 走，并往 state/inbox-watch.log 记一行 —— 绝不静默服务别的项目
 * （事故②：cwd=ai_interview 的进程却渲染/读写 pm-skills）。
 * 推导顺序：git 主工作树（账本所在地；worktree 里的 `.pi/team/config.sh` 是副本）→ 向上找 config.sh。
 */
function findRoot(cwd: string): string {
  const envRoot = process.env.TEAM_ROOT ? resolve(process.env.TEAM_ROOT) : ''
  let derived = ''
  try {
    const out = execFileSync('git', ['-C', cwd, 'rev-parse', '--path-format=absolute', '--git-common-dir'],
      { encoding: 'utf8', timeout: 5000 })
    const main = dirname(out.trim())
    if (existsSync(join(main, '.pi/team/config.sh'))) derived = main
  } catch {
    /* 不是 git 仓库 / 没有 git */
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
      appendLedger(derived, `TEAM_IDENTITY_CONFLICT inherited TEAM_ROOT=${envRoot} ≠ cwd-derived=${derived}；按 cwd 走`)
      return derived
    }
    if (existsSync(join(envRoot, '.pi/team/config.sh'))) {
      appendLedger(envRoot, `TEAM_IDENTITY_CONFLICT cwd（${cwd}）推导不出项目，回退到 TEAM_ROOT=${envRoot}`)
      return envRoot
    }
    return ''
  }
  return derived || envRoot
}

/** M46：这个 state 目录属于**另一个 teamsmith 项目**吗（<other>/.pi/team/config.sh 是别的根）？
 *  是 → 返回那个项目根（调用方拒绝该路径）。不是（本项目内 / 项目外的普通目录）= null。
 *  为什么只拒「别的项目」而不是「项目外的一切」：TEAM_STATE_DIR 是显式旋钮（夹具把它指到
 *  /tmp/xxx 搬家队列 —— 规格 scenario「TEAM_STATE_DIR moves the queue」）；但**继承来的**旋钮
 *  若落在别的项目的 state 上，就是把别人家当自己家（M40 事故②的形状：cwd=ai_interview 的进程
 *  读写 pm-skills 的 state）——那条绝不许静默通过。 */
function foreignProjectRoot(dir: string, root: string): string | null {
  const norm = (p: string): string => { try { return realpathSync(p) } catch { return resolve(p) } }
  const r = norm(dir)
  const rr = norm(root)
  if (r === rr || r.startsWith(rr.endsWith('/') ? rr : `${rr}/`)) return null   // 本项目内（含根本身）
  let d = r
  for (;;) {
    if (existsSync(join(d, '.pi/team/config.sh'))) return norm(d) === rr ? null : d
    const parent = dirname(d)
    if (parent === d) return null
    d = parent
  }
}

/** 本项目的 state 目录：锚定 cwd 推导出的根。继承的 TEAM_STATE_DIR 指向别的项目的 state 时
 *  一律改用 <root>/.pi/team/state（并记账本，见 noteStateDirConflict）；其它显式值照用。 */
function stateDir(root: string): string {
  const envDir = (process.env.TEAM_STATE_DIR || '').trim()
  if (envDir) {
    const abs = resolve(envDir)
    if (!foreignProjectRoot(abs, root)) return abs
  }
  return join(root, '.pi/team/state')
}

/** 被拒绝的继承指针（TEAM_STATE_DIR / TEAM_CONFIG_FILE）要留痕（写进**本项目**的账本；绝不静默）。 */
function noteIdentityFileConflicts(root: string): void {
  const stateEnv = (process.env.TEAM_STATE_DIR || '').trim()
  if (stateEnv) {
    const abs = resolve(stateEnv)
    const foreign = foreignProjectRoot(abs, root)
    if (foreign) {
      appendLedger(root,
        `TEAM_IDENTITY_CONFLICT inherited TEAM_STATE_DIR=${abs}（属于别的项目 ${foreign}）≠ cwd-derived=${root}；按 cwd 走`)
    }
  }
  const cfgEnv = (process.env.TEAM_CONFIG_FILE || '').trim()
  if (cfgEnv) {
    const abs = resolve(cfgEnv)
    const foreign = foreignProjectRoot(abs, root)
    if (foreign && abs !== join(root, '.pi/team/config.sh')) {
      appendLedger(root,
        `TEAM_IDENTITY_CONFLICT inherited TEAM_CONFIG_FILE=${abs}（属于别的项目 ${foreign}）≠ cwd-derived=${root}；按 cwd 走`)
    }
  }
}

function watchDir(root: string): string {
  return join(stateDir(root), 'inbox-watch')
}

/** 项目配置文件的定位（M46）：TEAM_CONFIG_FILE 只在**不指向别的项目**时被信任 ——
 *  与 state 目录同一条规则（继承的文件指针也不许把别的项目的会话名/文档目录当成本项目的）。 */
function configFile(root: string): string {
  const def = join(root, '.pi/team/config.sh')
  const envFile = (process.env.TEAM_CONFIG_FILE || '').trim()
  if (envFile) {
    const abs = resolve(envFile)
    if (abs === def || !foreignProjectRoot(abs, root)) return abs
  }
  return def
}

/** 从 <root>/.pi/team/config.sh 读 TEAM_DOCS_DIR（只解析需要的扁平 KEY=VALUE，不 source）。 */
function docsDir(root: string): string {
  try {
    const file = configFile(root)
    const text = readFileSync(file, 'utf8')
    const m = /^\s*TEAM_DOCS_DIR\s*=\s*(.*?)\s*$/m.exec(text)
    if (!m) return 'docs/team'
    const raw = m[1].replace(/\s+#.*$/, '').trim()
    const v = (raw.startsWith('"') && raw.endsWith('"')) || (raw.startsWith("'") && raw.endsWith("'")) ? raw.slice(1, -1) : raw
    return v.replace(/\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?/g, (_s, name: string) => process.env[name] ?? '') || 'docs/team'
  } catch {
    return 'docs/team'
  }
}

function cfgSession(root: string): string {
  try {
    const file = configFile(root)
    const m = /^\s*TEAM_SESSION\s*=\s*(.*?)\s*$/m.exec(readFileSync(file, 'utf8'))
    if (!m) return 'team'
    const raw = m[1].replace(/\s+#.*$/, '').trim()
    return ((raw.startsWith('"') && raw.endsWith('"')) || (raw.startsWith("'") && raw.endsWith("'")) ? raw.slice(1, -1) : raw) || 'team'
  } catch {
    return 'team'
  }
}

function pmWindow(root: string): string {
  try {
    const file = configFile(root)
    const m = /^\s*TEAM_PM_WINDOW\s*=\s*(.*?)\s*$/m.exec(readFileSync(file, 'utf8'))
    if (!m) return 'pm'
    const raw = m[1].replace(/\s+#.*$/, '').trim()
    return ((raw.startsWith('"') && raw.endsWith('"')) || (raw.startsWith("'") && raw.endsWith("'")) ? raw.slice(1, -1) : raw) || 'pm'
  } catch {
    return 'pm'
  }
}

/** target（`<session>:<window>`）→ spool/注册文件名用的 key：可读前缀 + 32 位短哈希（两个不同 target 不撞名）。
 *  发送侧只从**注册文件名**读 key（`team_inbox_watch_route` 返回的第 1 段），所以两边不需要共享哈希实现。 */
function targetKey(target: string): string {
  const slug = target.replace(/[^A-Za-z0-9._-]+/g, '_').slice(0, 40) || 'target'
  let h = 0
  for (let i = 0; i < target.length; i++) h = (Math.imul(h, 31) + target.charCodeAt(i)) >>> 0
  return `${slug}-${h.toString(16).padStart(8, '0')}`
}

/** 本会话在 tmux 里的 `session:window`（env 覆盖优先：headless 与夹具用它）。
 *  注意（M46）：覆盖只改「从哪里读 target」，**不改**「哪个会话才是这个项目的」——
 *  session_start 的会话检查对覆盖值同样生效（外来会话不许接管本项目的投递）。 */
function resolveTarget(): { target: string; session: string; window: string } | null {
  const override = (process.env.TEAM_INBOX_WATCH_TARGET || '').trim()
  if (override) {
    const idx = override.indexOf(':')
    if (idx > 0) return { target: override, session: override.slice(0, idx), window: override.slice(idx + 1) }
    return null
  }
  const pane = process.env.TMUX_PANE
  if (!pane) return null
  try {
    const out = execFileSync('tmux', ['display-message', '-p', '-t', pane, '#{session_name}:#{window_name}'],
      { encoding: 'utf8', timeout: 5000 }).trim()
    const idx = out.indexOf(':')
    if (idx <= 0) return null
    return { target: out, session: out.slice(0, idx), window: out.slice(idx + 1) }
  } catch {
    return null
  }
}

/** 收件人 = PM 窗口 → `pm`，其它窗口 → 窗口名（与 `team say`/`team notify` 的收件箱名一致）。 */
function inboxName(window: string, root: string): string {
  return window === pmWindow(root) ? 'pm' : window
}

function oneLine(raw: string, max: number): string {
  const flat = raw.replace(/\s+/g, ' ').trim()
  return flat.length > max ? `${flat.slice(0, Math.max(1, max - 1))}…` : flat
}

function appendLedger(root: string, line: string): void {
  try {
    mkdirSync(stateDir(root), { recursive: true })
    appendFileSync(join(stateDir(root), 'inbox-watch.log'), `${new Date().toISOString()} ${line}\n`)
  } catch {
    /* 账本绝不能影响会话 */
  }
}

/** M46 · 降级痕迹：跳过/失败不再只活在日志里 —— 在**本项目** state/inbox-watch/ 里写
 *  `<key>.skip`（与 .reg 同一种 KEY=VALUE 格式，发送侧与 doctor/status/panel 都读它）。
 *  为什么需要它：「本项目 PM 没有注册」有两种原因（会话名不符 vs 扩展没加载），只有扩展自己
 *  知道前者；没有这份记录，检查方只能给一句笼统的「未注册」。字段：target/session/window/expect/
 *  reason/detail/pid/cwd/ts/heartbeat。成功注册时同 target 的旧记录会被删掉（不再骗人）。 */
function writeSkipRecord(root: string, target: string, info: {
  session?: string; window?: string; expect?: string; inbox?: string; reason: string; detail: string
}): void {
  const dir = watchDir(root)
  const key = targetKey(target)
  try { mkdirSync(dir, { recursive: true }) } catch { return }
  const body = [
    'version=1',
    `target=${target}`,
    `key=${key}`,
    `session=${info.session ?? '-'}`,
    `window=${info.window ?? '-'}`,
    `expect=${info.expect ?? '-'}`,
    `inbox=${info.inbox ?? '-'}`,
    `reason=${info.reason}`,
    `detail=${info.detail}`,
    `pid=${process.pid}`,
    `cwd=${root}`,
    `ts=${new Date().toISOString()}`,
    `heartbeat=${Math.floor(Date.now() / 1000)}`,
    '',
  ].join('\n')
  try {
    const tmp = join(dir, `${key}.skip.tmp-${process.pid}`)
    writeFileSync(tmp, body)
    renameSync(tmp, join(dir, `${key}.skip`))
  } catch {
    /* 痕迹写不进去也不能影响会话；账本那一行仍然有 */
  }
}

/** 成功注册 = 这个 window 在本项目不再降级：删掉自己或上一次进程留下的 .skip。
 *  匹配两条：① target 逐字相同；② 同一个 window 的 session-mismatch 记录 —— 我们刚刚
 *  用**匹配配置的会话**注册成功，那条「会话名不符」对同一个 window 已经不成立了（与 CLI 侧
 *  读记录时的 window 匹配规则成对；否则修好会话后旧痕迹会永远刷降级告警）。 */
function clearSkipRecords(root: string, target: string): void {
  const dir = watchDir(root)
  const wantWin = target.includes(':') ? target.slice(target.indexOf(':') + 1) : target
  try {
    for (const name of readdirSync(dir)) {
      if (!name.endsWith('.skip')) continue
      const file = join(dir, name)
      try {
        const ft = readField(file, 'target')
        if (ft === target) { rmSync(file, { force: true }); continue }
        if (readField(file, 'window') === wantWin && readField(file, 'reason') === 'session-mismatch') {
          rmSync(file, { force: true })
        }
      } catch { /* ignore */ }
    }
  } catch {
    /* ignore */
  }
}

/** 读一份 KEY=VALUE 文件里的单个字段（.reg/.skip 共用；没有 → 空串）。 */
function readField(file: string, name: string): string {
  try {
    const m = new RegExp(`^${name}=(.*)$`, 'm').exec(readFileSync(file, 'utf8'))
    return m ? m[1].trim() : ''
  } catch {
    return ''
  }
}

/** spool 的当前大小（读不到 = -1）。 */
function fileSize(file: string): number {
  try { return statSync(file).size } catch { return -1 }
}

/** spool 的头部前缀（前 min(HEAD_BYTES, size) 字节）：回退时用它判断「开头有没有被改写」（B2/D3）。
 *  只读前缀；读不到 → null（调用方按「没有证据」处理，不会误判成「没变」）。 */
function readHead(file: string, size: number): Buffer | null {
  if (size < 0) return null
  const n = Math.min(HEAD_BYTES, size)
  if (n === 0) return Buffer.alloc(0)
  try {
    const fd = openSync(file, 'r')
    try {
      const buf = Buffer.alloc(n)
      const got = readSync(fd, buf, 0, n, 0)
      return Buffer.from(buf.subarray(0, got))
    } finally {
      closeSync(fd)
    }
  } catch {
    return null
  }
}

/** 头部指纹（账本里的可读短记号；只用于记账本与 repeat 比较，不参与「变没变」的判断）。 */
function headStamp(head: Buffer | null): string {
  if (head === null) return 'absent'
  if (head.length === 0) return 'empty'
  let h = 2166136261
  for (let i = 0; i < head.length; i++) { h ^= head[i]; h = Math.imul(h, 16777619) >>> 0 }
  return `fnv${h.toString(16).padStart(8, '0')}`
}

type Freshness = 'fresh' | 'stale' | 'unparsable'

/** 行年龄（B3/R3）：spool 行的第一个字段是发送者落盘时的 `team_epoch_ms`（毫秒）。
 *  判据只用行自带的这个字段 —— 不看文件 mtime（外部重写会动它，且它回答不了「这一行什么时候写的」），
 *  也不看 `.seen` 的顺序（那只回答「投过没有」）。读不出来的时间戳算 fresh-for-delivery 并单独计数。 */
function freshness(line: string): Freshness {
  const first = (line.split('\t')[0] ?? '').trim()
  if (!/^\d+$/.test(first)) return 'unparsable'   // 不可解析 ≠ 过期：投递 + 计数，绝不静默吞
  return Date.now() - Number(first) > staleSec() * 1000 ? 'stale' : 'fresh'
}

type ReadResult = {
  lines: string[]
  offset: number
  shrank: boolean
  size: number      // 本次读到的文件大小（-1 = 文件不见了）
  resync: number    // 起点落在行中时跳过的碎片字节数（含换行；0 = 没有碎片）
}

/** 读完 spool 自 <offset> 起的新行（只消费完整行）。
 *  size < offset 或文件消失（且此前跟踪过内容）= **外部截断/重写/替换**（仓内写路径只有追加）——
 *  此时返回 shrank=true 且一行都不读：怎么有界地重扫是 flush() 的决策（M43），这里绝不静默重置。
 *  P28/B1：offset 只按**实际读到的字节**推进 —— 在原始 buffer 上找 `\n`、认 readSync 的返回值、
 *  逐行解码。绝不经过「先解码成字符串、再用 Buffer.byteLength 量长度」的往返：非法字节会变成
 *  U+FFFD（1 字节量成 3 字节），offset 于是越过文件末尾，下一拍看起来像外部缩容（2026-09-20 事故）。
 *  起点落在行中（只有 clamp/trim 会把 offset 落在行中）→ 到下一个换行为止都是碎片，跳过并记账本。 */
function readNewLines(file: string, offset: number): ReadResult {
  let size = -1
  try { size = statSync(file).size } catch {
    return { lines: [], offset: 0, shrank: offset > 0, size: -1, resync: 0 }   // 文件没了 = 缩到 0
  }
  if (size < offset) return { lines: [], offset: 0, shrank: true, size, resync: 0 }
  if (size === offset) return { lines: [], offset, shrank: false, size, resync: 0 }
  try {
    const fd = openSync(file, 'r')
    try {
      // 起点是不是落在行中：offset 前一个字节不是 `\n`（offset=0 = 文件头，永远算行首）
      let midLine = false
      if (offset > 0) {
        const prev = Buffer.alloc(1)
        midLine = readSync(fd, prev, 0, 1, offset - 1) === 1 && prev[0] !== 0x0a
      }
      const buf = Buffer.alloc(size - offset)
      const bytesRead = readSync(fd, buf, 0, buf.length, offset)   // B1：返回值算数（短读的 NUL 填充不许当内容）
      const win = buf.subarray(0, bytesRead)
      const end = win.lastIndexOf(0x0a)                            // 原始字节上的最后一个换行 = 最后一个完整行
      if (end < 0) return { lines: [], offset, shrank: false, size, resync: 0 }
      // 行中起步 = 碎片（被 clamp 截住的旧行的尾巴）：跳到它自己的换行为止，绝不投递（B1.2）
      const start = midLine ? win.indexOf(0x0a) + 1 : 0
      const resync = start
      const advance = end + 1   // P28/B1：字节真值（flip-p25.sh 的 mutant A/B 把这一行换成解码→再编码的长度）
      const lines: string[] = []
      let from = start
      for (let i = start; i <= end; i++) {
        if (i !== end && win[i] !== 0x0a) continue
        const line = win.subarray(from, i).toString('utf8').replace(/\r$/, '')   // 只解码行文本
        if (line.trim()) lines.push(line)
        from = i + 1
      }
      return { lines, offset: offset + advance, shrank: false, size, resync }
    } finally {
      closeSync(fd)
    }
  } catch {
    return { lines: [], offset, shrank: false, size, resync: 0 }
  }
}

/** spool 的当前大小 = 本次会话的**投递基线**：启动之前写入的行不叫醒任何人（backlog 是 pulse 的活）。
 *  （单抽成函数是为了让「基线」这件事有一个可定点破坏的单点。） */
function baselineOffset(file: string): number {
  return readNewLines(file, 0).offset
}

/** spool 超上限 → 截头留尾（尾部信号不丢）。返回裁剪后的新大小（没裁 → -1）：
 *  调用方必须把 offset 对上新大小，否则下一拍会看到「size < offset」走 shrink/rescan ——
 *  有去重兑底不会再叫一遍，但白扫一遍 + 账本多两行噪音，没必要。 */
function trimSpool(file: string): number {
  const cap = maxBytes()
  try {
    if (statSync(file).size <= cap) return -1
    const keep = Math.max(1024, Math.floor(cap / 2))
    const fd = openSync(file, 'r')
    let text = ''
    try {
      const size = statSync(file).size
      const start = Math.max(0, size - keep)
      const buf = Buffer.alloc(size - start)
      readSync(fd, buf, 0, buf.length, start)
      text = buf.toString('utf8')
    } finally {
      closeSync(fd)
    }
    const firstNl = text.indexOf('\n')
    writeFileSync(file, firstNl >= 0 ? text.slice(firstNl + 1) : '')
    return statSync(file).size
  } catch {
    return -1
  }
}

export default function (pi: ExtensionAPI) {
  let root = ''
  let key = ''
  let keyTarget = ''
  let startedAt = ''
  let inbox = ''
  let spool = ''
  let reg = ''
  let seenPath = ''
  let offset = 0
  let seen = 0
  let delivered = new Set<string>()   // M43 去重记忆：已投递行的整行元组（键 = 行本身）
  let deliveredOrder: string[] = []   // 同内容的 FIFO 顺序（容量裁剪用）
  let watcher: any = null
  let pollTimer: ReturnType<typeof setInterval> | null = null
  let beatTimer: ReturnType<typeof setInterval> | null = null
  let mergeTimer: ReturnType<typeof setTimeout> | null = null

  const stopAll = (): void => {
    try { watcher?.close?.() } catch { /* ignore */ }
    watcher = null
    if (pollTimer) { clearInterval(pollTimer); pollTimer = null }
    if (beatTimer) { clearInterval(beatTimer); beatTimer = null }
    if (mergeTimer) { clearTimeout(mergeTimer); mergeTimer = null }
  }

  let headBytes: Buffer | null = null   // 上次建立 offset 时的头部前缀（B2 的回退证据）
  let lastShrink: { size: number; head: string } | null = null   // 上一个 shrink 事件的 (size, head)（B2 的收敛记忆）

  /** 现在的头部算不算「没变」：与记录的头部相同，或者是它的前缀（文件在头部范围内变短了，
   *  但留下的字节一个没动）。头部读不出来（文件没了）→ 不算「没变」（没有证据就不是修复）。 */
  const headUnchanged = (cur: Buffer | null): boolean => {
    if (headBytes === null || cur === null) return false
    if (cur.length === headBytes.length) return cur.equals(headBytes)
    return cur.length < headBytes.length && cur.equals(headBytes.subarray(0, cur.length))
  }

  /** offset 越过文件末尾（size < offset）：按证据决定「修复」还是「重写」（B2 / 设计 D3+D4）。
   *  同一头部 + 小回退（≤ TEAM_INBOX_WATCH_CLAMP_BYTES）= 我们自己的 offset 算错了 → 一次 `offset clamp`；
   *  头部变了 / 回退太大 = 真重写 → 有界重扫；同一 (size, head) 已处理过 = `shrink repeat` + clamp，
   *  绝不重扫第二次（这是协议级的收敛，与 B1 的算术正确性互相独立）。
   *  clamp 目标只能是 size（当前末尾）：走回上一个换行会退回基线之前的内容、重投 S5 故意压住的行；
   *  落在行中由 B1.2 的碎片跳过规则吸掉。 */
  const handleShrink = (): void => {
    const size = fileSize(spool)
    if (size >= 0 && size >= offset) return   // 竞态：已经长回来了 → 下一拍正常读，不在这里决策
    const cur = size >= 0 ? readHead(spool, size) : null
    const stamp = headStamp(cur)
    const repeat = lastShrink !== null && lastShrink.size === size && lastShrink.head === stamp
    const regress = size >= 0 ? offset - size : Number.POSITIVE_INFINITY
    if (size >= 0 && headUnchanged(cur) && (repeat || regress <= clampBytes())) {
      if (repeat) {
        appendLedger(root, `shrink repeat size=${size} head=${stamp} action=clamp inbox=${inbox}`)
      } else {
        appendLedger(root, `offset clamp from=${offset} to=${size} head=same inbox=${inbox}`)
      }
      offset = size
      headBytes = cur
      lastShrink = { size, head: stamp }
      return
    }
    appendLedger(root, `spool shrink: size fell below offset=${offset} inbox=${inbox} → bounded rescan from 0（外部截断/重写；仓内只有追加写）`)
    lastShrink = { size, head: stamp }
    rescan()
  }

  /** 去重记忆：启动时从 <key>.seen 加载（跨会话重启仍认得「这行投过了」）。 */
  const loadSeen = (file: string): void => {
    delivered = new Set()
    deliveredOrder = []
    try {
      const lines = readFileSync(file, 'utf8').split('\n').filter(l => l.trim())
      for (const l of lines.slice(-seenMax())) { delivered.add(l); deliveredOrder.push(l) }
    } catch {
      /* 没有 .seen = 第一次投 */
    }
  }

  /** 投递成功后记入去重记忆并持久化（tmp+rename；写挂只影响跨重启去重，不影响本会话）。 */
  const markDelivered = (lines: string[]): void => {
    for (const l of lines) if (!delivered.has(l)) { delivered.add(l); deliveredOrder.push(l) }
    const cap = seenMax()
    while (deliveredOrder.length > cap) {
      const old = deliveredOrder.shift()
      if (old !== undefined) delivered.delete(old)
    }
    if (!seenPath) return
    try {
      const tmp = `${seenPath}.tmp-${process.pid}`
      writeFileSync(tmp, `${deliveredOrder.join('\n')}\n`)
      renameSync(tmp, seenPath)
    } catch {
      /* 见上 */
    }
  }

  const writeReg = (note: string): void => {
    if (!reg) return
    const body = [
      'version=1',
      `target=${keyTarget}`,
      `inbox=${inbox}`,
      `pid=${process.pid}`,
      `cwd=${root}`,
      `started=${startedAt}`,
      `heartbeat=${Math.floor(Date.now() / 1000)}`,
      `note=${note}`,
      '',
    ].join('\n')
    try {
      const tmp = `${reg}.tmp-${process.pid}`
      writeFileSync(tmp, body)
      renameSync(tmp, reg)
    } catch {
      /* 注册写不进去 → 发送方走粘贴路径；这不是会话该关心的事 */
    }
  }

  /** 投递一条唤醒：指针 + 截断预览，绝不带 payload 全文。
   *  meta（rescan 唤醒才有）：文本与账本都说明「这是 shrink 后的有界重扫，跳过了多少」。 */
  const wake = (lines: string[], meta?: { dup: number; skipped: number }): void => {
    const field = (l: string, i: number): string => (l.split('\t')[i] ?? '').trim()
    const rows = lines.map(l => {
      const kind = field(l, 1) || 'msg'
      const from = field(l, 2) && field(l, 2) !== '-' ? ` from ${field(l, 2)}` : ''
      const durable = field(l, 3)
      const where = durable && durable !== '-' ? ` → ${durable}.md` : ''
      const preview = oneLine(l.split('\t').slice(4).join(' ') || '(empty)', previewLimit())
      return `- [${kind}]${from}${where} :: ${preview}`
    })
    const shown = rows.slice(0, MAX_LISTED)
    const more = rows.length - shown.length
    const hasInbox = lines.some(l => { const d = field(l, 3); return !!d && d !== '-' })
    const hasLogOnly = lines.some(l => { const d = field(l, 3); return !d || d === '-' })
    const firstInbox = lines.map(l => field(l, 3)).find(d => !!d && d !== '-') || inbox
    const inboxPath = `${docsDir(root)}/inbox/${firstInbox}.md`
    const rescanNote = meta
      ? `(spool rescan after external shrink: delivered the last ${lines.length} unseen line(s); ` +
        `skipped ${meta.dup} already-delivered + ${meta.skipped} older. Full history stays in the spool file.)\n`
      : ''
    const text =
      `[teamsmith] inbox wake: ${lines.length} new team message(s).\n` +
      `${shown.join('\n')}${more > 0 ? `\n- … and ${more} more` : ''}\n` +
      rescanNote +
      (hasInbox && hasLogOnly
        ? `Full text: the ${inboxPath} file named on each line; the others (knock/nudge) are pointers to the sender's own log (\`team inbox\` / \`team digest\` / state/nudges.log).\n`
        : hasLogOnly
          ? `These wakes point at the sender's own log (\`team inbox\` / \`team digest\`); they carry no inbox line.\n`
          : `Full text: read ${inboxPath} — this wake-up carries a one-line pointer, not the payload.\n`)
    seen += lines.length
    markDelivered(lines)
    appendLedger(root,
      `wake n=${lines.length} total=${seen} inbox=${inbox} kinds=${lines.map(l => l.split('\t')[1] || '?').join(',')}` +
      (meta ? ` rescan[dup=${meta.dup} skipped=${meta.skipped}]` : ''))
    try {
      pi.sendMessage({ customType: 'team-inbox', content: text, display: true },
        { triggerTurn: true, deliverAs: 'followUp' })
    } catch {
      /* 会话正在退出等场合：账本已经记了，不抛 */
    }
  }

  /** 普通路径：追加读到的新行。与去重记忆重叠的行（外部重写带回来的已投递行）跳过并记账本；
   *  过期行只计数不唤醒（B3/R3），它们可读的副本是发送方在 spool 行之前写的 durable 收件箱行。 */
  const deliverNormal = (lines: string[]): void => {
    const unseen = lines.filter(l => !delivered.has(l))   // M43 去重（普通路径）：去掉这行过滤 = 重写重放不受约束
    const dup = lines.length - unseen.length
    if (dup > 0) {
      appendLedger(root, `dedup: skipped ${dup} already-delivered line(s) inbox=${inbox}（外部重写与已投递重叠）`)
    }
    const kinds = unseen.map(l => freshness(l))
    const stale = kinds.filter(k => k === 'stale').length
    const unparsable = kinds.filter(k => k === 'unparsable').length
    const deliver = unseen.filter((_l, i) => kinds[i] !== 'stale')
    if (stale > 0 || unparsable > 0) {
      appendLedger(root, `classify stale=${stale} unparsable=${unparsable} inbox=${inbox}（过期行不唤醒；时间戳不可解析的行照投）`)
    }
    if (deliver.length) wake(deliver)
  }

  /** shrink 后的有界重扫（M43）：从 0 读，但①已投递的一律不重复投 ②真新行只投最近 replayMax 条，
   *  更早的跳过 ③过期行只计数不投（B3/R3）—— 三种数量都进账本；全部被压掉时不唤醒（没什么好说的），
   *  total 不动。`lines=/dup=/skipped=/deliver=` 保持原样在前（M43 的断言逐字不改），新计数接在后面。 */
  const rescan = (): void => {
    const res = readNewLines(spool, 0)
    offset = res.offset
    headBytes = readHead(spool, res.size)   // 重扫后 offset 重新建立：头部证据跟着刷新
    const unseen = res.lines.filter(l => !delivered.has(l))   // M43 去重（rescan 路径）：去掉这行过滤 = rescan 重放旧行
    const dup = res.lines.length - unseen.length
    const kinds = unseen.map(l => freshness(l))
    const stale = kinds.filter(k => k === 'stale').length
    const unparsable = kinds.filter(k => k === 'unparsable').length
    const freshAll = unseen.filter((_l, i) => kinds[i] !== 'stale')
    const cap = replayMax()
    const skipped = Math.max(0, freshAll.length - cap)
    const fresh = skipped > 0 ? freshAll.slice(-cap) : freshAll
    appendLedger(root,
      `rescan lines=${res.lines.length} dup=${dup} skipped=${skipped} deliver=${fresh.length} stale=${stale} unparsable=${unparsable} total=${seen} inbox=${inbox}`)
    if (fresh.length) wake(fresh, { dup, skipped })
  }

  /** 读 spool 的新行并合并成一条唤醒（同一拍收到的多行只叫一次）。 */
  const flush = (): void => {
    if (!spool) return
    const res = readNewLines(spool, offset)
    if (res.shrank) {
      // M43：spool 变小/消失了 —— 仓内写路径只有 `>>` 追加，变小一定是外部力量（截断/重写/替换）。
      // 旧行为在这里静默 offset=0，下一拍把整个 spool 从 0 重读（2026-09-19 的 42 行双投事故）。
      // P28/B2：先看证据（头部 + 回退幅度 + 上次的事件），小回退是修复，其余才是有界重扫。
      handleShrink()
      return
    }
    const advanced = res.offset > offset
    offset = res.offset
    if (res.resync > 0) {
      // B1.2：读取起点落在行中 —— 碎片被跳过（它的旧行早就投递过），只记账本，不唤醒
      appendLedger(root, `offset resync skipped=${res.resync} inbox=${inbox}`)
    }
    if (advanced) headBytes = readHead(spool, res.size)   // offset 建立时记下头部证据
    if (res.lines.length > 0) lastShrink = null           // 正常推进（读到完整行）= 上一个 shrink 事件结束
    const trimmed = trimSpool(spool)
    if (trimmed >= 0) {
      offset = trimmed   // 裁剪后 size 变小：offset 对上新大小，避免把尾部重叫一次
      headBytes = readHead(spool, trimmed)
      lastShrink = null
    }
    if (res.lines.length) deliverNormal(res.lines)
  }

  const scheduleFlush = (): void => {
    if (mergeTimer) return
    mergeTimer = setTimeout(() => { mergeTimer = null; try { flush() } catch { /* ignore */ } }, MERGE_MS)
  }

  /** 本地管家的清场：注册文件里 pid 已死的条目删掉（不让陈旧注册把发送方骗走）。 */
  const reapDeadRegs = (dir: string, self: string): void => {
    try {
      for (const name of readdirSync(dir)) {
        if (!name.endsWith('.reg')) continue
        const file = join(dir, name)
        if (file === self) continue
        const m = /^pid=(\d+)$/m.exec(readFileSync(file, 'utf8'))
        if (!m) continue
        try { process.kill(Number(m[1]), 0) } catch { rmSync(file, { force: true }) }
      }
    } catch {
      /* ignore */
    }
  }

  pi.on('session_start', async (_event: any, ctx: any) => {
    stopAll()
    root = findRoot(String(ctx?.cwd ?? process.cwd()))
    if (!root) return
    noteIdentityFileConflicts(root)
    const found = resolveTarget()
    if (!found) {
      appendLedger(root, 'skip setup: no tmux target (set TEAM_INBOX_WATCH_TARGET to override)')
      return
    }
    if (found.session !== cfgSession(root)) {
      // 不是本团队的 session：绝不接管（跨项目的窗口不归这里管）。M46：跳过也留本项目可见的痕迹。
      // 注意 TEAM_INBOX_WATCH_TARGET 只是「从哪里读 target」的旋钮（headless/夹具），**不改**
      // 「哪个会话才是本项目的」——显式覆盖进来的外来会话同样拒绝（隐式与显式两个入口同一扇门）。
      const expect = cfgSession(root)
      const detail = `session ${found.session} != ${expect}`
      appendLedger(root, `skip setup: ${detail}`)
      writeSkipRecord(root, found.target, {
        session: found.session, window: found.window, expect, inbox: inboxName(found.window, root),
        reason: 'session-mismatch', detail,
      })
      return
    }
    const dir = watchDir(root)
    try { mkdirSync(dir, { recursive: true }) } catch { /* ignore */ }
    keyTarget = found.target
    key = targetKey(found.target)
    inbox = inboxName(found.window, root)
    spool = join(dir, `${key}.wake`)
    reg = join(dir, `${key}.reg`)
    startedAt = new Date().toISOString()
    // 基线：启动之前写入的行不叫醒任何人（backlog 是 pulse 的活）
    offset = baselineOffset(spool)
    headBytes = readHead(spool, fileSize(spool))
    lastShrink = null
    seen = 0
    seenPath = join(dir, `${key}.seen`)
    loadSeen(seenPath)
    reapDeadRegs(dir, reg)
    clearSkipRecords(root, keyTarget)   // M46：注册成功 = 这个 target 不再降级，旧痕迹不骗人
    writeReg('ready')
    appendLedger(root, `started target=${keyTarget} inbox=${inbox} spool=${spool} baseline=${offset}`)
    try {
      watcher = watch(dir, (_type: string, filename: string | null) => {
        if (filename && basename(String(filename)) !== `${key}.wake`) return
        scheduleFlush()
      })
    } catch {
      appendLedger(root, 'watch unavailable: falling back to polling only')
    }
    pollTimer = setInterval(() => { try { flush() } catch { /* ignore */ } }, pollMs())
    beatTimer = setInterval(() => { try { writeReg('ready') } catch { /* ignore */ } }, heartbeatMs())
  })

  pi.on('session_shutdown', async () => {
    stopAll()
    if (reg) {
      try { rmSync(reg, { force: true }) } catch { /* ignore */ }
      appendLedger(root, `stopped target=${keyTarget} inbox=${inbox}`)
    }
    root = ''; key = ''; inbox = ''; spool = ''; reg = ''; offset = 0
    headBytes = null; lastShrink = null
  })
}
