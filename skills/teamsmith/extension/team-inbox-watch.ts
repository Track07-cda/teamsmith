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
 *       2. **去重**：整行元组进过去重记忆 —— P81 起这份记忆是 `state/inbox-watch/<key>.deliver`
 *          **投递日志**（append-only，`read` → `intent` → `sent`/`failed`），进程内存绝不是权威；
 *          `<key>.seen` 只被一次性导入（此后删掉/清空它不改变任何投递决定），已投递的行一律不再投；
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
 * 降级通道（M53）：`fs.watch` 注册失败（典型：宿主 inotify 配额耗尽 ENOSPC）不再是一行无语境的日志 ——
 * 账本写唯一形状 `watch unavailable: errno=… watches=<used|unknown>/<max> poll_ms=… fallback=polling
 * [forced=1]`，并落一条耐久记录 `<key>.degraded`（pid + cwd 可判活，成功注册或干净退出删掉）。
 * `.reg` 在失败时保留：路由（发送方）只认 `.reg`，降级绝不把消息推回输入框粘贴路径；轮询计时器
 * 无条件安装 —— 兜底是契约，不是失败路径的补丁（夹具 S22/S23 证明它）。`watches` 只报可证明完整的
 * 同 UID 视图（容器里 /proc 是嵌套 PID 命名空间 → `unknown`，绝不把局部计数当总量）。
 *
 * P81 · 投递日志（`<key>.deliver`，唯一 durable 去重权威；事故：一条 nudge 被叫醒两次，而文件无法回答
 * 「到底投过没有」）：
 *   - 顺序是契约：`read`（点名行身份 + 唤醒材料 + 偏移/大小/头指纹）→ `intent`（一批）→ **发送** →
 *     `sent`/`failed`；`intent` 没写成**绝不许发** —— 写不进去就 `deliver blocked`，行保持未读等下一拍；
 *   - 重启后按日志判三态（绝不靠内存）：`read` 无 `intent` → **恰好一次**恢复（`recovery`）；
 *     `intent` 无 `sent`/`failed`（含半截尾记录）→ `inflight assumed`，**永不重投**；`sent` → 永不；
 *     `failed` → 每拍至多重试一次、且不得越过新鲜度地平线；
 *   - 日志有界（`TEAM_INBOX_WATCH_JOURNAL_MAX`，默认 1024）：越界压缩并写 `floor=`；比地板更早的身份
 *     日志已不能证明「没投过」→ `unprovable`，永不唤醒（fail-safe，不是 fail-open）；
 *   - 唤醒文本点名源行：`#<seq>` + 绝对发送时间 + 每行的源时间与身份（发送方写进 spool 第 6 字段的
 *     `id=<outbox 条目名>`，老行用整行 sha1 摘要）—— 收件方只凭 durable 文件就能分辨「两条」与「一条两次」。
 *
 * 作用域：只认本项目（git 主工作树）的 state 目录 —— 注册与 spool 是**发送方与会话之间的接口**
 * （发送方是 CLI，它的 TEAM_STATE_DIR 在主工作树），所以它们必须待在共享根，不能跟着会话的 worktree 走。
 * 会话本地的产物（作业日志/账户）不归这里管（那是 team-bg 的活，它跟会话自己的工作树走）。只服务
 * dispatch/PM 启动链 `-e` 注入的团队会话 —— 用户自己的 pi 会话没有它。
 */
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent'
import { execFileSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import { appendFileSync, closeSync, existsSync, mkdirSync, openSync, readFileSync, readSync, readdirSync, readlinkSync, realpathSync, renameSync, rmSync, statSync, watch, writeFileSync } from 'node:fs'
import { basename, dirname, join, resolve } from 'node:path'

const DEFAULT_PREVIEW = 160          // 预览截断（字符）：唤醒消息只带一行指针，不带全文
const DEFAULT_MAX_BYTES = 128 * 1024 // spool 上限
const DEFAULT_POLL_MS = 5000         // fs.watch 的兜底轮询（错过 inotify 事件时仍能醒来）
const DEFAULT_HEARTBEAT_MS = 5000    // 注册心跳
const DEFAULT_REPLAY_MAX = 20        // shrink 后 rescan 的「真新」行投递上限（更早的跳过并说明）
const DEFAULT_SEEN_MAX = 512         // 老 <key>.seen 的一次性导入上限（P81 起日志是唯一记忆）
const DEFAULT_JOURNAL_MAX = 1024     // P81：投递日志的记录上限（越过 → 压缩 + `floor=`）
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
function journalMax(): number { return envNum('TEAM_INBOX_WATCH_JOURNAL_MAX', DEFAULT_JOURNAL_MAX, 16) }
function clampBytes(): number { return Math.min(1024 * 1024, envNum('TEAM_INBOX_WATCH_CLAMP_BYTES', DEFAULT_CLAMP_BYTES, 1)) }
function staleSec(): number { return envNum('TEAM_INBOX_WATCH_STALE_SEC', DEFAULT_STALE_SEC, 1) }

/**
 * 定位团队根（主工作树）：M40 —— **cwd 推导为准**（与 team CLI 同一条原则）。
 * TEAM_ROOT 只在①与推导结果一致，或②完全推导不出来且它指向一个真项目时被信任；
 * 不一致时按 cwd 走，并往 state/inbox-watch.log 记一行 —— 绝不静默服务别的项目
 * （事故②：cwd=other_project 的进程却渲染/读写 pm-skills）。
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
 *  若落在别的项目的 state 上，就是把别人家当自己家（M40 事故②的形状：cwd=other_project 的进程
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

/** M53 · inotify 额度上限（/proc/sys/fs/inotify/max_user_watches）。读不到 → 'unknown'。 */
function inotifyMaxWatches(): string {
  try {
    const text = readFileSync('/proc/sys/fs/inotify/max_user_watches', 'utf8').trim()
    return /^[0-9]+$/.test(text) ? text : 'unknown'
  } catch {
    return 'unknown'
  }
}

/** M53 · 当前用户的 inotify watch 占用 —— 只认「可证明完整」的同 UID 视图，否则 'unknown'。
 *  完整性有一个硬前提：我们不在嵌套的 PID 命名空间里（/proc/self/status 的 NSpid 只有一个值）。
 *  容器里 /proc 只看得见自己的 PID 命名空间，计数会小得离谱（本机实测 16/65536，而宿主已 65312），
 *  把局部计数当总量就是假绿；另：同 UID 进程的 fd/fdinfo 有一个读不到 → unknown，绝不报部分量。 */
function inotifyUsedWatches(): string {
  try {
    const status = readFileSync('/proc/self/status', 'utf8')
    const ns = /^NSpid:\s*(.+)$/m.exec(status)
    if (!ns || ns[1].trim().split(/\s+/).length > 1) return 'unknown'
  } catch {
    return 'unknown'
  }
  const uid = typeof process.getuid === 'function' ? process.getuid() : -1
  if (uid < 0) return 'unknown'
  let total = 0
  try {
    for (const entry of readdirSync('/proc')) {
      if (!/^[0-9]+$/.test(entry)) continue
      const pdir = `/proc/${entry}`
      let owner: number
      try { owner = statSync(pdir).uid } catch { continue }   // 进程刚退出：不是我们的证据缺口
      if (owner !== uid) continue
      let fds: string[]
      try { fds = readdirSync(`${pdir}/fd`) } catch (error) {
        if ((error as NodeJS.ErrnoException)?.code === 'ENOENT') continue
        return 'unknown'   // 同 UID 却读不到 = 视图不完整（不是「占用很小」）
      }
      for (const fd of fds) {
        let link = ''
        try { link = readlinkSync(`${pdir}/fd/${fd}`) } catch (error) {
          if ((error as NodeJS.ErrnoException)?.code === 'ENOENT') continue
          return 'unknown'
        }
        if (link !== 'anon_inode:inotify') continue
        let info = ''
        try { info = readFileSync(`${pdir}/fdinfo/${fd}`, 'utf8') } catch (error) {
          if ((error as NodeJS.ErrnoException)?.code === 'ENOENT') continue
          return 'unknown'
        }
        const wds = new Set<string>()   // 一个 inotify 实例里同一个 wd 只算一个 watch
        for (const line of info.split('\n')) {
          const m = /^inotify wd:([0-9a-f]+)\s/.exec(line)
          if (m) wds.add(m[1])
        }
        total += wds.size
      }
    }
  } catch {
    return 'unknown'
  }
  return String(total)
}

/** `<used>/<max>` 形状（用于账本行与降级记录；used 可能是 unknown）。 */
function watchUsageField(): string { return `${inotifyUsedWatches()}/${inotifyMaxWatches()}` }

/** 失败原因 → errno 文本（优先 error.code；取不到时从 message 里挑一个 E… 记号）。 */
function watchErrnoOf(error: unknown): string {
  const code = (error as NodeJS.ErrnoException)?.code
  if (typeof code === 'string' && /^E[A-Z0-9]+$/.test(code)) return code
  const m = /\b(E[A-Z][A-Z0-9]+)\b/.exec(String((error as Error)?.message ?? error))
  return m ? m[1] : 'unknown'
}

/** 夹具旋钮（config.md 登记为 fixture-only）：<errno> ⇒ 不尝试注册，走同一条失败路径并标 `forced=1`。 */
function forcedWatchErrno(): string {
  return (process.env.TEAM_INBOX_WATCH_FORCE_FAIL || '').trim()
}

/** M53 · 降级记录 `state/inbox-watch/<key>.degraded`（与 .reg/.skip 同一种 KEY=VALUE 家族）。
 *  为什么不是 .skip：`.skip` 的含义是「没有注册」（发送方会退回粘贴路径），而这里是「注册在、
 *  watcher 不在」——路由（`team_inbox_watch_route`）只认 .reg，绝不能被这条记录改道。
 *  读者只认「pid 活着 + cwd 在本项目内」（与 .reg/.skip 同一条证据规则）；成功注册或干净退出删掉它。 */
function writeDegradedRecord(root: string, target: string, info: {
  errno: string; watches: string; pollMs: number; forced: boolean
}): void {
  // 变量名故意不叫 dir：flip-m46 包用 `}): void {\n  const dir = watchDir(root)` 当 writeSkipRecord 的注射锚点，
  // 这里重名会让那个锚点变成 2 处（既有翻转包会 exit 2）——不动的包不该被新代码抵掉。
  const wdir = watchDir(root)
  const key = targetKey(target)
  try { mkdirSync(wdir, { recursive: true }) } catch { return }
  const body = [
    'version=1',
    `target=${target}`,
    `key=${key}`,
    'reason=watch-unavailable',
    `errno=${info.errno}`,
    `watches=${info.watches}`,
    `poll_ms=${info.pollMs}`,
    `forced=${info.forced ? 1 : 0}`,
    `since=${new Date().toISOString()}`,
    `pid=${process.pid}`,
    `cwd=${root}`,
    `heartbeat=${Math.floor(Date.now() / 1000)}`,
    '',
  ].join('\n')
  try {
    const tmp = join(wdir, `${key}.degraded.tmp-${process.pid}`)
    writeFileSync(tmp, body)
    renameSync(tmp, join(wdir, `${key}.degraded`))
  } catch {
    /* 痕迹写不进去也不能影响会话；账本那一行仍然有 */
  }
}

/** 成功注册（或本次会话结束）后，同 target 的旧降级记录不再成立 → 删掉（不再骗 doctor/status/面板）。 */
function clearDegradedRecords(root: string, target: string): void {
  const dir = watchDir(root)
  try {
    for (const name of readdirSync(dir)) {
      if (!name.endsWith('.degraded')) continue
      const file = join(dir, name)
      try { if (readField(file, 'target') === target) rmSync(file, { force: true }) } catch { /* ignore */ }
    }
  } catch {
    /* ignore */
  }
}

/** M53 · 失败路径的唯一出口：账本一行（唯一形状 `watch unavailable: errno=… watches=… poll_ms=…
 *  fallback=polling [forced=1]`）+ 一条耐久降级记录。轮询计时器**不在这里** —— 它在 session_start
 *  里无条件安装（兜底是契约，不是失败路径的补丁；兜底的证明见夹具 S23）。 */
function recordWatchFailure(root: string, target: string, err: string, forced: boolean): void {
  const usage = watchUsageField()
  const ms = pollMs()
  appendLedger(root,
    `watch unavailable: errno=${err} watches=${usage} poll_ms=${ms} fallback=polling${forced ? ' forced=1' : ''}`)
  writeDegradedRecord(root, target, { errno: err, watches: usage, pollMs: ms, forced })
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
 *  也不看日志的顺序（那只回答「投过没有」）。读不出来的时间戳算 fresh-for-delivery 并单独计数。 */
function freshnessOf(src: number): Freshness {
  if (!Number.isFinite(src) || src <= 0) return 'unparsable'   // 不可解析 ≠ 过期：投递 + 计数，绝不静默吞
  return Date.now() - src > staleSec() * 1000 ? 'stale' : 'fresh'
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

/* ── P81 · 投递日志（`state/inbox-watch/<key>.deliver`，唯一 durable 去重权威） ─────────────────
 * 形状：一行一条记录，ISO 时间戳开头，其余字段 `key=value` 空格分隔；值里的空白一律转义
 * （jesc/junesc）——身份可能是整行的摘要，绝不许把分隔符带进值里。记录种类：
 *   start baseline=<n> size=<n> head=<stamp>
 *   read  seq=<n> off=<n> size=<n> head=<stamp> id=<身份> src=<ms> kind=<k> from=<f> durable=<d> preview=<p>
 *   intent seq=<n>
 *   sent   seq=<n>          （导入老 .seen 时也写 sent seq=<负> id=<身份> imported=1）
 *   failed seq=<n> reason=<why>
 *   floor  id=<保留的最老身份> ts=<地板源时间> evicted=<n> kept=<n>
 * 判定是逐记录的：`read` 点名的身份进入「读数」态，`intent`/`sent`/`failed` 按文件顺序落到同一批的
 * 身份上 —— 最后一条说了算（`sent` → 已投递；`intent` → 结果未知；`failed` → 可重试一次；`read` → 可恢复一次）。 */

/** 日志值编码：空白 → 反斜杠转义（解析逐字可逆）。 */
function jesc(s: string): string {
  return s.replace(/\\/g, '\\\\').replace(/\n/g, '\\n').replace(/\r/g, '\\r').replace(/\t/g, '\\t').replace(/ /g, '\\s')
}

function junesc(s: string): string {
  let out = ''
  for (let i = 0; i < s.length; i++) {
    const c = s[i]
    if (c !== '\\') { out += c; continue }
    const n = s[++i]
    out += n === 'n' ? '\n' : n === 'r' ? '\r' : n === 't' ? '\t' : n === 's' ? ' ' : n === '\\' ? '\\' : (n ?? '')
  }
  return out
}

/** 行的身份：发送方写在第 6 字段的 `id=`（outbox 条目名，与 state/outbox/delivered.log 对得上）优先；
 *  没有该字段的旧行/外来行 = 整行的 SHA-1 摘要（有界的**身份**，不是 payload 全文）。日志与唤醒文本
 *  印同一个串 —— 收件方据此自证「这是哪一条」，两条逐字相同的 payload 靠源时间 + 身份区分。 */
function lineIdentity(line: string): string {
  const id = (line.split('\t')[5] ?? '').trim()
  if (id) return id
  return `sha1:${createHash('sha1').update(line, 'utf8').digest('hex')}`
}

type SpoolLine = {
  raw: string
  identity: string
  src: number          // 行首的 team_epoch_ms；0 = 不可解析（照投 + 计数，绝不静默吞）
  kind: string
  from: string
  durable: string
  preview: string
}

function parseSpoolLine(raw: string): SpoolLine {
  const f = raw.split('\t')
  const first = (f[0] ?? '').trim()
  return {
    raw,
    identity: lineIdentity(raw),
    src: /^\d+$/.test(first) ? Number(first) : 0,
    kind: (f[1] ?? '').trim() || 'msg',
    from: (f[2] ?? '').trim() || '-',
    durable: (f[3] ?? '').trim() || '-',
    preview: f[4] ?? '',
  }
}

type JournalEntryState = 'read' | 'intent' | 'sent' | 'failed'
type JournalEntry = { state: JournalEntryState; material: SpoolLine | null; failure: string }
type Journal = {
  entries: Map<string, JournalEntry>
  batch: Map<number, string[]>
  maxSeq: number
  floorTs: number | null
  floorId: string
  torn: boolean
  records: number
}

function parseJournalLine(line: string): { kind: string; fields: Map<string, string> } | null {
  const m = /^(\S+) (start|read|intent|sent|failed|floor)(?: (.*))?$/.exec(line)
  if (!m) return null
  const fields = new Map<string, string>()
  for (const tok of (m[3] ?? '').split(' ')) {
    if (!tok) continue
    const eq = tok.indexOf('=')
    if (eq <= 0) return null
    fields.set(tok.slice(0, eq), junesc(tok.slice(eq + 1)))
  }
  return { kind: m[2], fields }
}

function journalMaterial(rec: { fields: Map<string, string> }, identity: string): SpoolLine {
  const src = Number(rec.fields.get('src') ?? '')
  return {
    raw: '', identity,
    src: Number.isFinite(src) && src > 0 ? src : 0,
    kind: rec.fields.get('kind') ?? 'msg',
    from: rec.fields.get('from') ?? '-',
    durable: rec.fields.get('durable') ?? '-',
    preview: rec.fields.get('preview') ?? '',
  }
}

/** 读投递日志（唯一的 durable 去重权威）。尾部没有收尾换行 / 解析不出来的记录 = **撕裂**
 *  （崩溃正落在写日志中间）：保守地当成「结果未知」—— 有 read 没 intent 的行绝不因此被当成
 *  「还没发过」而重投（宁可漏一次敲门，也不许无据重投）。 */
function loadJournal(file: string): Journal {
  const j: Journal = { entries: new Map(), batch: new Map(), maxSeq: 0, floorTs: null, floorId: '', torn: false, records: 0 }
  let text = ''
  try { text = readFileSync(file, 'utf8') } catch { return j }
  if (!text) return j
  const lines = text.split('\n')
  if (text.endsWith('\n')) lines.pop()
  else { j.torn = true; lines.pop() }   // 没有收尾换行的尾记录 = 半截
  for (const line of lines) {
    if (!line.trim()) continue
    j.records++
    const rec = parseJournalLine(line)
    if (!rec) { j.torn = true; continue }
    const seq = Number(rec.fields.get('seq') ?? '')
    if (rec.kind === 'start') continue
    if (rec.kind === 'floor') {
      const ts = Number(rec.fields.get('ts') ?? '')
      if (Number.isFinite(ts) && ts > 0) j.floorTs = ts
      j.floorId = rec.fields.get('id') ?? j.floorId
      continue
    }
    if (Number.isFinite(seq)) j.maxSeq = Math.max(j.maxSeq, seq)
    if (rec.kind === 'read') {
      const identity = rec.fields.get('id') ?? ''
      if (!identity) continue
      j.entries.set(identity, { state: 'read', material: journalMaterial(rec, identity), failure: '' })
      if (Number.isFinite(seq)) {
        const ids = j.batch.get(seq) ?? []
        ids.push(identity)
        j.batch.set(seq, ids)
      }
      continue
    }
    // sent 带显式 id（老 .seen 的导入）：直接就是「已投递」，不依赖任何批次
    const explicit = rec.fields.get('id') ?? ''
    if (explicit && (rec.kind === 'sent' || rec.kind === 'failed')) {
      j.entries.set(explicit, {
        state: rec.kind === 'sent' ? 'sent' : 'failed',
        material: j.entries.get(explicit)?.material ?? null,
        failure: rec.fields.get('reason') ?? '',
      })
      continue
    }
    // intent / sent / failed 是批级的：落到这一批 read 记录点名的每个身份上
    for (const identity of (Number.isFinite(seq) ? (j.batch.get(seq) ?? []) : [])) {
      const entry = j.entries.get(identity)
      if (!entry) continue
      if (rec.kind === 'intent') { if (entry.state === 'read') entry.state = 'intent'; continue }
      if (rec.kind === 'sent') { entry.state = 'sent'; entry.failure = ''; continue }
      entry.state = 'failed'
      entry.failure = rec.fields.get('reason') ?? ''
    }
  }
  return j
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
  let journalPath = ''
  let offset = 0
  let seen = 0
  let delivered = new Set<string>()      // P81：已投递的身份（来自日志 sent/intent 导入/本次会话成功发送）
  let journalEntries = new Map<string, JournalEntry>()   // 启动时从日志载入的身份态（只读快照）
  let retryQueue = new Map<string, SpoolLine>()          // failed：会话 API 拒过、每拍至多重试一次
  let recoveryQueue = new Map<string, SpoolLine>()       // read 无 intent：恰好允许一次恢复
  let floorTs: number | null = null                      // 日志淘汰下限（更早的身份 → unprovable）
  let floorId = ''
  let journalRecords = 0
  let seqCounter = 1                                     // 唤醒序号（跨重启单调；来自日志 max seq）
  let abortAt = ''                                       // 夹具注入点（只在 TEAM_SMOKE_FIXTURE=1 下生效）
  let watcher: any = null
  let fileWatcher: any = null                            // spool 的**文件级** watcher（Bun 的目录 watcher 会丢逐文件事件）
  let pollTimer: ReturnType<typeof setInterval> | null = null
  let beatTimer: ReturnType<typeof setInterval> | null = null
  let mergeTimer: ReturnType<typeof setTimeout> | null = null

  const stopAll = (): void => {
    try { watcher?.close?.() } catch { /* ignore */ }
    watcher = null
    try { fileWatcher?.close?.() } catch { /* ignore */ }
    fileWatcher = null
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
    if (rescan() === 'blocked') lastShrink = null   // 日志写不进去：不收敛到 clamp，下一拍重试同一份重写
  }

  /** 追加一条日志记录。失败 = false：调用方**绝不因此发送任何东西**（fail-closed），
   *  账本记 `deliver blocked`，行保持未读等下一拍（丢一次敲门允许，丢日志不允许）。 */
  const journalAppend = (record: string): boolean => {
    try {
      mkdirSync(dirname(journalPath), { recursive: true })
      appendFileSync(journalPath, `${new Date().toISOString()} ${record}\n`)
      journalRecords++
      return true
    } catch {
      return false
    }
  }

  /** P81 · 一次性导入老代码的 `<key>.seen`（仅当投递日志还不存在时）。导入的身份作为
   *  「已投递」追加进日志（synthetic seq + 显式 id）；此后不再读它 —— 删掉/清空 `.seen` 不改变
   *  任何投递决定（日志是唯一记忆）。 */
  const importSeen = (): number => {
    let lines: string[] = []
    try { lines = readFileSync(seenPath, 'utf8').split('\n').filter(l => l.trim()) } catch { return 0 }
    let n = 0
    for (const raw of lines.slice(-seenMax())) {
      if (!journalAppend(`sent seq=-${n + 1} id=${jesc(lineIdentity(raw))} imported=1`)) break
      n++
    }
    return n
  }

  /** P81 · 压缩：日志越过上限 → 只留最近的记录（**绝不从一组 read/intent/sent 中间切起**，
   *  不然已投递的身份会连同它的 read 一起丢掉），写一条 `floor` 记淘汰下限；地板 = 保留下来的
   *  read 里最小的源时间戳 —— 比它更早的身份日志已不能证明「没投过」（`unprovable`，永不唤醒）。
   *  tmp + rename：崩溃只留下旧文件，绝不留半截。 */
  const compactJournal = (): boolean => {
    let lines: string[] = []
    try {
      const text = readFileSync(journalPath, 'utf8')
      if (!text.endsWith('\n')) return false      // 撕裂尾先不碰（下一次完整追加后再压）
      lines = text.split('\n').filter(l => l.trim())
    } catch { return false }
    const max = journalMax()
    if (lines.length <= max) return false
    // 组的边界：一批 read…intent…sent/failed 不能从中间切开（不然已投递的身份会连同它的 read 一起丢掉）。
    // 从尾往前按**整组**累计，直到再加一组就超过上限 —— floor 行也算一条记录，所以留一个位置。
    const starts: number[] = []
    for (let i = 0; i < lines.length; i++) {
      const kind = parseJournalLine(lines[i])?.kind
      if (i === 0 || kind === 'read' || kind === 'start' || kind === 'floor') starts.push(i)
    }
    let cut = lines.length
    for (let i = starts.length - 1; i >= 0; i--) {
      if (lines.length - starts[i] + 1 > max) break   // +1 = 将要写下的 floor 行
      cut = starts[i]
    }
    const dropped = lines.slice(0, cut)
    const kept = lines.slice(cut)
    let evicted = 0
    for (const line of dropped) if (parseJournalLine(line)?.kind === 'read') evicted++
    let floor: number | null = null
    let floorIdentity = ''
    for (const line of kept) {
      const rec = parseJournalLine(line)
      if (rec?.kind !== 'read') continue
      const src = Number(rec.fields.get('src') ?? '')
      if (Number.isFinite(src) && src > 0 && (floor === null || src < floor)) { floor = src; floorIdentity = rec.fields.get('id') ?? '' }
    }
    if (floor === null) { floor = floorTs ?? Date.now(); floorIdentity = floorId }
    const floorLine = `${new Date().toISOString()} floor id=${jesc(floorIdentity || '-')} ts=${floor} evicted=${evicted} kept=${kept.length}`
    try {
      const tmp = `${journalPath}.tmp-${process.pid}`
      writeFileSync(tmp, `${[floorLine, ...kept].join('\n')}\n`)
      renameSync(tmp, journalPath)
    } catch { return false }
    floorTs = floor
    floorId = floorIdentity
    journalRecords = kept.length + 1
    appendLedger(root,
      `journal compacted records=${lines.length} kept=${kept.length} floor=${floorIdentity || '-'} floor_ts=${floor} evicted=${evicted} inbox=${inbox}`)
    return true
  }

  const maybeCompact = (): void => {
    if (journalRecords <= journalMax()) return
    if (!compactJournal()) return
    // 地板与记录数重新对齐（内存里的 delivered/retry/recovery 保留 —— 被淘汰的身份在本次会话里
    // 仍然有证据，绝不因为压缩反而放行）
    const reloaded = loadJournal(journalPath)
    floorTs = reloaded.floorTs ?? floorTs
    floorId = reloaded.floorId || floorId
    journalRecords = reloaded.records
  }

  /** 夹具注入点（只在 `TEAM_SMOKE_FIXTURE=1` 下生效，否则启动时记一行 ignored）：
   *  `TEAM_INBOX_WATCH_ABORT_AFTER=read|intent` 让**当前进程**在写前记录的那一步真死（SIGKILL）——
   *  崩溃必须发生在另一个进程里，日志才有机会证明自己是权威。 */
  const fixtureAbort = (): void => {
    try { process.kill(process.pid, 'SIGKILL') } catch { /* ignore */ }
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

  type WakeMeta = {
    dup?: number
    skipped?: number
    recovery?: boolean
    retry?: boolean
    off?: number
    size?: number
    head?: string
  }

  /** P81 · 唤醒文本：`#<seq>` + 绝对发送时间 + 每行的源时间/身份 + 投递日志路径。
   *  指针 + 截断预览，绝不带 payload 全文；身份是有界的（发送方的 id 或整行 sha1 摘要）。 */
  const wakeText = (seq: number, lines: SpoolLine[], meta: WakeMeta): string => {
    const sendTs = new Date().toISOString()
    const rows = lines.map(l => {
      const from = l.from && l.from !== '-' ? ` from ${l.from}` : ''
      const where = l.durable && l.durable !== '-' ? ` → ${l.durable}.md` : ''
      const src = l.src > 0 ? new Date(l.src).toISOString() : '(no timestamp)'
      const preview = oneLine(l.preview || '(empty)', previewLimit())
      return `- [${l.kind}]${from}${where} :: ${preview}  (src ${src} · id ${l.identity})`
    })
    const shown = rows.slice(0, MAX_LISTED)
    const more = rows.length - shown.length
    const hasInbox = lines.some(l => !!l.durable && l.durable !== '-')
    const hasLogOnly = lines.some(l => !l.durable || l.durable === '-')
    const firstInbox = lines.map(l => l.durable).find(d => !!d && d !== '-') || inbox
    const inboxPath = `${docsDir(root)}/inbox/${firstInbox}.md`
    const rescanNote = meta.dup !== undefined
      ? `(spool rescan after external shrink: delivered the last ${lines.length} unseen line(s); ` +
        `skipped ${meta.dup} already-delivered + ${meta.skipped ?? 0} older. Full history stays in the spool file.)\n`
      : ''
    const recoveryNote = meta.recovery
      ? `(recovered from the delivery journal: a previous session read these lines and stopped before sending them.)\n`
      : ''
    const retryNote = meta.retry ? `(retry of a wake whose delivery failed earlier; at most one retry per tick.)\n` : ''
    return (
      `[teamsmith] inbox wake #${seq} · ${sendTs}\n` +
      `${shown.join('\n')}${more > 0 ? `\n- … and ${more} more` : ''}\n` +
      rescanNote + recoveryNote + retryNote +
      `Delivery journal: ${journalPath} — the ids above are recorded there (cross-check the sender's state/outbox/delivered.log).\n` +
      (hasInbox && hasLogOnly
        ? `Full text: the ${inboxPath} file named on each line; the others (knock/nudge) are pointers to the sender's own log (\`team inbox\` / \`team digest\` / state/nudges.log).\n`
        : hasLogOnly
          ? `These wakes point at the sender's own log (\`team inbox\` / \`team digest\`); they carry no inbox line.\n`
          : `Full text: read ${inboxPath} — this wake-up carries a one-line pointer, not the payload.\n`)
    )
  }

  const shortError = (error: unknown): string => oneLine(String((error as Error)?.message ?? error ?? 'unknown'), 160)

  /** P81 · 唯一的发送出口：写前记录（read → intent）→ 发送 → sent/failed。
   *  `intent` 没写成**绝不发送**（fail-closed）；API 拒了记 `failed`，下一拍重试。 */
  const sendWake = (lines: SpoolLine[], meta: WakeMeta = {}): 'ok' | 'failed' | 'blocked' => {
    if (!lines.length) return 'ok'
    const seq = seqCounter++
    const off = meta.off ?? offset
    const size = meta.size ?? fileSize(spool)
    const head = meta.head ?? headStamp(readHead(spool, size))
    const readRecord = (l: SpoolLine): string =>
      `read seq=${seq} off=${off} size=${size} head=${head} id=${jesc(l.identity)} src=${l.src || ''} ` +
      `kind=${jesc(l.kind)} from=${jesc(l.from)} durable=${jesc(l.durable)} preview=${jesc(oneLine(l.preview || '(empty)', previewLimit()))}`
    const blocked = (): 'blocked' => {
      appendLedger(root, `deliver blocked seq=${seq} inbox=${inbox}（投递日志写不进去 → 按失败关闭：一条都不发，行保持未读）`)
      return 'blocked'
    }
    for (const l of lines) if (!journalAppend(readRecord(l))) return blocked()
    maybeCompact()
    if (abortAt === 'read') fixtureAbort()
    if (!journalAppend(`intent seq=${seq}`)) return blocked()
    maybeCompact()
    if (abortAt === 'intent') fixtureAbort()
    try {
      pi.sendMessage({ customType: 'team-inbox', content: wakeText(seq, lines, meta), display: true },
        { triggerTurn: true, deliverAs: 'followUp' })
    } catch (error) {
      journalAppend(`failed seq=${seq} reason=${jesc(shortError(error))}`)
      appendLedger(root,
        `wake failed seq=${seq} reason=${oneLine(shortError(error), 120)} inbox=${inbox}（会话 API 拒绝：这一行没投出，下一拍重试至多一次）`)
      for (const l of lines) retryQueue.set(l.identity, l)
      return 'failed'
    }
    if (!journalAppend(`sent seq=${seq}`)) {
      appendLedger(root, `sent record blocked seq=${seq} inbox=${inbox}（会话已接受但日志没记上 sent → 下一次启动按 inflight 处理，绝不重投）`)
    }
    maybeCompact()
    seen += lines.length
    for (const l of lines) {
      delivered.add(l.identity)
      retryQueue.delete(l.identity)
      recoveryQueue.delete(l.identity)
    }
    appendLedger(root,
      `wake n=${lines.length} total=${seen} inbox=${inbox} kinds=${lines.map(l => l.kind).join(',')} seq=${seq} ids=${lines.map(l => l.identity).join('|')}` +
      (meta.recovery ? ` recovery n=${lines.length}` : '') +
      (meta.retry ? ' retry=1' : '') +
      (meta.dup !== undefined ? ` rescan[dup=${meta.dup} skipped=${meta.skipped ?? 0}]` : ''))
    return 'ok'
  }

  type Classification = { fresh: SpoolLine[]; replay: number; stale: number; unparsable: number; unprovable: number }

  /** 逐行判定（普通读/重扫共用一个口径）：日志里有记录 → 绝不重投；日志没有但早于淘汰下限 → unprovable；
   *  过期 → 只计数；时间戳不可解析 → 照投并计数；其余才是真的新行。 */
  const classify = (lines: SpoolLine[]): Classification => {
    const out: Classification = { fresh: [], replay: 0, stale: 0, unparsable: 0, unprovable: 0 }
    for (const l of lines) {
      if (delivered.has(l.identity) || retryQueue.has(l.identity) || recoveryQueue.has(l.identity) || journalEntries.has(l.identity)) {
        out.replay++
        continue
      }
      if (l.src > 0 && floorTs !== null && l.src < floorTs) { out.unprovable++; continue }
      const f = freshnessOf(l.src)
      if (f === 'stale') { out.stale++; continue }
      if (f === 'unparsable') out.unparsable++
      out.fresh.push(l)
    }
    return out
  }

  /** 普通路径：追加读到的新行。与日志重叠的行跳过并记账本；过期行只计数不唤醒（B3/R3），
   *  它们可读的副本是发送方在 spool 行之前写的 durable 收件箱行。 */
  const deliverNormal = (lines: string[], meta: { off: number; size: number; head: string }): 'ok' | 'blocked' => {
    const cls = classify(lines.map(parseSpoolLine))
    if (cls.replay > 0) {
      appendLedger(root, `replay suppressed n=${cls.replay} reason=normal inbox=${inbox}（外部重写带回了日志里已有记录的行）`)
    }
    if (cls.unprovable > 0) {
      appendLedger(root, `unprovable n=${cls.unprovable} inbox=${inbox}（身份早于日志淘汰下限：日志已不能证明它没投过 → 永不唤醒）`)
    }
    if (cls.stale > 0 || cls.unparsable > 0) {
      appendLedger(root, `classify stale=${cls.stale} unparsable=${cls.unparsable} inbox=${inbox}（过期行不唤醒；时间戳不可解析的行照投）`)
    }
    if (!cls.fresh.length) return 'ok'
    return sendWake(cls.fresh, { off: meta.off, size: meta.size, head: meta.head })
  }

  /** shrink 后的有界重扫（M43）：从 0 读，但①日志里已有一律不重复投 ②真新行只投最近 replayMax 条，
   *  更早的跳过 ③过期行只计数不投（B3/R3）—— 三种数量都进账本；全部被压掉时不唤醒（没什么好说的），
   *  total 不动。`lines=/dup=/skipped=/deliver=` 保持原样在前（M43 的断言逐字不改），新计数接在后面。 */
  const rescan = (): 'ok' | 'blocked' => {
    const res = readNewLines(spool, 0)
    offset = res.offset
    headBytes = readHead(spool, res.size)   // 重扫后 offset 重新建立：头部证据跟着刷新
    const cls = classify(res.lines.map(parseSpoolLine))
    const cap = replayMax()
    const skipped = Math.max(0, cls.fresh.length - cap)
    const fresh = skipped > 0 ? cls.fresh.slice(-cap) : cls.fresh
    appendLedger(root,
      `rescan lines=${res.lines.length} dup=${cls.replay} skipped=${skipped} deliver=${fresh.length} stale=${cls.stale} unparsable=${cls.unparsable} total=${seen} inbox=${inbox}`)
    if (cls.replay > 0) appendLedger(root, `replay suppressed n=${cls.replay} reason=rescan inbox=${inbox}`)
    if (cls.unprovable > 0) {
      appendLedger(root, `unprovable n=${cls.unprovable} inbox=${inbox}（身份早于日志淘汰下限：日志已不能证明它没投过 → 永不唤醒）`)
    }
    if (!fresh.length) return 'ok'
    return sendWake(fresh, { dup: cls.replay, skipped, off: res.offset, size: res.size, head: headStamp(readHead(spool, res.size)) })
  }

  /** `failed` 的重试：每拍至多一次、不得越过新鲜度地平线（过期即丢弃并计数，绝不唤醒）。 */
  const runRetryTick = (): void => {
    if (!retryQueue.size) return
    let stale = 0
    const fresh: SpoolLine[] = []
    for (const [identity, material] of [...retryQueue]) {
      if (delivered.has(identity)) { retryQueue.delete(identity); continue }
      if (freshnessOf(material.src) === 'stale') { stale++; retryQueue.delete(identity); continue }
      fresh.push(material)
    }
    if (stale > 0) appendLedger(root, `retry stale=${stale} fresh=${fresh.length} inbox=${inbox}（重试不越过新鲜度地平线）`)
    if (fresh.length) sendWake(fresh, { retry: true })
  }

  /** `read` 无 `intent`（上一次的发送根本没开始）：恰好一次恢复。新鲜度优先 ——
   *  已过期的只计数（`stale=`，不是 `recovery=`），绝不唤醒。 */
  const runRecoveryTick = (): void => {
    if (!recoveryQueue.size) return
    let stale = 0
    let unparsable = 0
    const fresh: SpoolLine[] = []
    for (const [identity, material] of [...recoveryQueue]) {
      if (delivered.has(identity)) { recoveryQueue.delete(identity); continue }
      const f = freshnessOf(material.src)
      if (f === 'stale') { stale++; recoveryQueue.delete(identity); delivered.add(identity); continue }
      if (f === 'unparsable') unparsable++
      fresh.push(material)
    }
    appendLedger(root,
      `recovery candidates=${stale + fresh.length} fresh=${fresh.length} stale=${stale} unparsable=${unparsable} inbox=${inbox}`)
    if (!fresh.length) return
    const state = sendWake(fresh, { recovery: true })
    if (state !== 'blocked') for (const l of fresh) recoveryQueue.delete(l.identity)
  }

  /** 启动基线的代价核算（P81/D4）：启动那一刻 spool 里已经完整、但没有任何日志记录的行，
   *  仍然按 doctrine 被基线吞掉（不唤醒）—— 但不再静默：只计数，不改 `started … baseline=` 契约。 */
  const baselineSwallowed = (): void => {
    let n = 0
    try {
      const res = readNewLines(spool, 0)
      for (const raw of res.lines) {
        const identity = lineIdentity(raw)
        if (delivered.has(identity) || journalEntries.has(identity)) continue
        n++
      }
    } catch { /* 读不到就当 0：核算绝不把会话搞崩 */ }
    appendLedger(root, `baseline swallowed n=${n} inbox=${inbox}（启动时完整行里没有任何日志记录的行；基线仍是 spool 末尾）`)
  }

  /** 读 spool 的新行并合并成一条唤醒（同一拍收到的多行只叫一次）。
   *  日志写不进去时 `deliverNormal` 返回 blocked：offset 不动，行保持未读（下一拍重读）。 */
  const flush = (): void => {
    if (!spool) return
    try { runRetryTick() } catch { /* ignore */ }
    try { runRecoveryTick() } catch { /* ignore */ }
    const res = readNewLines(spool, offset)
    if (res.shrank) {
      // M43：spool 变小/消失了 —— 仓内写路径只有 `>>` 追加，变小一定是外部力量（截断/重写/替换）。
      // 旧行为在这里静默 offset=0，下一拍把整个 spool 从 0 重读（2026-09-19 的 42 行双投事故）。
      // P28/B2：先看证据（头部 + 回退幅度 + 上次的事件），小回退是修复，其余才是有界重扫。
      handleShrink()
      return
    }
    if (res.lines.length > 0) {
      const state = deliverNormal(res.lines, { off: res.offset, size: res.size, head: headStamp(readHead(spool, res.size)) })
      if (state === 'blocked') return   // fail-closed：行保持未读，offset 不动
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
  }

  const scheduleFlush = (): void => {
    if (mergeTimer) return
    mergeTimer = setTimeout(() => {
      mergeTimer = null
      try { flush() } catch { /* ignore */ } finally { armFileWatcher() }
    }, MERGE_MS)
  }

  /** Bun 实测（harness S2/S3）：目录 watcher 在 spool 被**创建**之后会静默丢掉它的逐文件事件
   *  （之后对 spool 的追加一个都不报），而同一个进程里对 spool 的文件级 watch 照常工作。
   *  spool 只被 `>>` 追加（inode 不变），所以文件级 watcher 一旦 arm 上就长期有效；
   *  目录 watcher 继续负责「文件还不存在」那一刻的创建事件，轮询是兜底。 */
  const armFileWatcher = (): void => {
    try { fileWatcher?.close?.() } catch { /* ignore */ }
    fileWatcher = null
    if (!spool || !existsSync(spool)) return
    try { fileWatcher = watch(spool, () => { scheduleFlush() }) } catch { /* 目录 watcher 与轮询兜底仍在 */ }
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
    journalPath = join(dir, `${key}.deliver`)
    seenPath = join(dir, `${key}.seen`)
    startedAt = new Date().toISOString()
    // 基线：启动之前写入的行不叫醒任何人（backlog 是 pulse 的活）—— P81 不改变这条 doctrine，
    // 只把它的代价数出来（baseline swallowed）
    offset = baselineOffset(spool)
    headBytes = readHead(spool, fileSize(spool))
    lastShrink = null
    seen = 0
    delivered = new Set()
    journalEntries = new Map()
    retryQueue = new Map()
    recoveryQueue = new Map()
    floorTs = null
    floorId = ''
    journalRecords = 0
    seqCounter = 1
    // P81：投递日志是唯一 durable 去重权威。首次启动把老代码的 `.seen` 一次性导入 ——
    // 此后删掉/清空它不再影响任何投递决定。
    if (!existsSync(journalPath)) {
      const imported = importSeen()
      if (imported > 0) appendLedger(root, `seen import n=${imported} inbox=${inbox}（一次性：此后投递日志是唯一去重记忆）`)
    }
    const loaded = loadJournal(journalPath)
    journalEntries = loaded.entries
    floorTs = loaded.floorTs
    floorId = loaded.floorId
    journalRecords = loaded.records
    seqCounter = Math.max(1, loaded.maxSeq + 1)
    // 重启后的三态判定（只从日志，绝不从内存）：sent → 永不；intent 无结论 → inflight assumed（含撕裂尾）；
    // read 无 intent → 恰好一次 recovery；failed → 每拍至多重试一次
    let assumed = 0
    for (const [identity, entry] of loaded.entries) {
      if (entry.state === 'sent' || entry.state === 'intent') {
        delivered.add(identity)
        if (entry.state === 'intent') assumed++
      } else if (entry.state === 'read') {
        if (entry.material) recoveryQueue.set(identity, entry.material)
      } else if (entry.state === 'failed') {
        if (entry.material) retryQueue.set(identity, entry.material)
      }
    }
    if (loaded.torn) {
      appendLedger(root, `torn tail inbox=${inbox}（日志尾部有半截记录：结果未知，绝不重投）`)
      for (const identity of [...recoveryQueue.keys()]) {
        recoveryQueue.delete(identity)
        delivered.add(identity)
        assumed++
      }
    }
    if (assumed > 0) appendLedger(root, `inflight assumed n=${assumed} inbox=${inbox}（intent 无 sent/failed：结果未知，永不重投）`)
    // 夹具注入点：裸设（没有 TEAM_SMOKE_FIXTURE=1）无效，并留一行「被忽略」的痕迹
    const abortEnv = (process.env.TEAM_INBOX_WATCH_ABORT_AFTER || '').trim()
    abortAt = ''
    if (abortEnv) {
      if (process.env.TEAM_SMOKE_FIXTURE === '1' && (abortEnv === 'read' || abortEnv === 'intent')) abortAt = abortEnv
      else appendLedger(root, `fixture knob ignored: TEAM_INBOX_WATCH_ABORT_AFTER=${abortEnv}（需要 TEAM_SMOKE_FIXTURE=1）`)
    }
    reapDeadRegs(dir, reg)
    clearSkipRecords(root, keyTarget)   // M46：注册成功 = 这个 target 不再降级，旧痕迹不骗人
    clearDegradedRecords(root, keyTarget)   // M53：上一次失败留下的记录同样不再成立
    writeReg('ready')
    appendLedger(root, `started target=${keyTarget} inbox=${inbox} spool=${spool} baseline=${offset}`)
    // P81 · 启动记录（审计：这一任读者从哪里起步）+ 越界就压缩（写下 floor）
    if (!journalAppend(`start baseline=${offset} size=${fileSize(spool)} head=${headStamp(headBytes)}`)) {
      appendLedger(root, `deliver blocked inbox=${inbox}（启动时投递日志写不进去 → 本次会话一条都不发）`)
    }
    maybeCompact()
    baselineSwallowed()
    runRecoveryTick()
    // M53 · 失败不再静默：errno + 额度观察 + 轮询间隔进账本，并写一条耐久降级记录（读的人看 pid+cwd）。
    // 夹具旋钮强制失败时同样走这条路径（evidence 里带 forced=1，免得测试事故被当成真事故）。
    const forced = forcedWatchErrno()
    if (forced) {
      recordWatchFailure(root, keyTarget, forced, true)
    } else {
      try {
        watcher = watch(dir, (_type: string, filename: string | null) => {
          if (filename && basename(String(filename)) !== `${key}.wake`) return
          scheduleFlush()
        })
      } catch (error) {
        recordWatchFailure(root, keyTarget, watchErrnoOf(error), false)
      }
    }
    armFileWatcher()   // spool 可能早已存在（上一任会话留下的）：文件级 watcher 现在就 arm 上
    pollTimer = setInterval(() => { try { flush() } catch { /* ignore */ } }, pollMs())
    beatTimer = setInterval(() => { try { writeReg('ready') } catch { /* ignore */ } }, heartbeatMs())
  })

  pi.on('session_shutdown', async () => {
    stopAll()
    if (reg) {
      try { rmSync(reg, { force: true }) } catch { /* ignore */ }
      appendLedger(root, `stopped target=${keyTarget} inbox=${inbox}`)
    }
    // M53：干净退出 = 这条降级不再成立（下一次会话会重新注册，或重新记录一次失败）
    if (keyTarget) clearDegradedRecords(root, keyTarget)
    root = ''; key = ''; inbox = ''; spool = ''; reg = ''; offset = 0
    headBytes = null; lastShrink = null
    journalPath = ''; journalEntries = new Map(); retryQueue = new Map(); recoveryQueue = new Map()
    delivered = new Set(); floorTs = null; floorId = ''; journalRecords = 0; abortAt = ''
  })
}
