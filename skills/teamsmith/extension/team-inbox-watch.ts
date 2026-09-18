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
 *   - spool 有上限（TEAM_INBOX_WATCH_MAX_BYTES，默认 128KB）：超了截头留尾（尾部信号不丢），
 *     读取端发现 size < offset 就当文件被裁剪/轮转，从 0 重读。
 *
 * 生命周期（Pi 文档的硬约束）：factory 里不起任何后台资源；watch / 定时器 / 注册文件都在
 * session_start 里建、session_shutdown 里清（并删掉自己的注册文件 —— 不然发送方会一直以为
 * 「有个活着的监视器」而不再走粘贴路径）。任何失败都只写自己的账本（state/inbox-watch.log），
 * 绝不抛进会话。
 *
 * 作用域：只认本项目（git 主工作树）的 state 目录 —— 注册与 spool 是**发送方与会话之间的接口**
 * （发送方是 CLI，它的 TEAM_STATE_DIR 在主工作树），所以它们必须待在共享根，不能跟着会话的 worktree 走。
 * 会话本地的产物（作业日志/账户）不归这里管（那是 team-bg 的活，它跟会话自己的工作树走）。只服务
 * dispatch/PM 启动链 `-e` 注入的团队会话 —— 用户自己的 pi 会话没有它。
 */
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent'
import { execFileSync } from 'node:child_process'
import { appendFileSync, closeSync, existsSync, mkdirSync, openSync, readFileSync, readSync, readdirSync, renameSync, rmSync, statSync, watch, writeFileSync } from 'node:fs'
import { basename, dirname, join, resolve } from 'node:path'

const DEFAULT_PREVIEW = 160          // 预览截断（字符）：唤醒消息只带一行指针，不带全文
const DEFAULT_MAX_BYTES = 128 * 1024 // spool 上限
const DEFAULT_POLL_MS = 5000         // fs.watch 的兜底轮询（错过 inotify 事件时仍能醒来）
const DEFAULT_HEARTBEAT_MS = 5000    // 注册心跳
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

/** 定位团队根（主工作树）：TEAM_ROOT > git 主工作树 > 向上找 .pi/team/config.sh（与 team-bg / team-notify 同口径）。 */
function findRoot(cwd: string): string {
  const envRoot = process.env.TEAM_ROOT
  if (envRoot && existsSync(join(envRoot, '.pi/team/config.sh'))) return resolve(envRoot)
  // worktree 里 .pi/team/config.sh 是副本，git 主工作树才是账本所在地（不能靠向上查找碰运气）
  try {
    const out = execFileSync('git', ['-C', cwd, 'rev-parse', '--path-format=absolute', '--git-common-dir'],
      { encoding: 'utf8', timeout: 5000 })
    const main = dirname(out.trim())
    if (existsSync(join(main, '.pi/team/config.sh'))) return main
  } catch {
    /* 不是 git 仓库 / 没有 git */
  }
  let dir = resolve(cwd)
  for (;;) {
    if (existsSync(join(dir, '.pi/team/config.sh'))) return dir
    const parent = dirname(dir)
    if (parent === dir) return ''
    dir = parent
  }
}

function stateDir(root: string): string {
  return process.env.TEAM_STATE_DIR || join(root, '.pi/team/state')
}

function watchDir(root: string): string {
  return join(stateDir(root), 'inbox-watch')
}

/** 从 <root>/.pi/team/config.sh 读 TEAM_DOCS_DIR（只解析需要的扁平 KEY=VALUE，不 source）。 */
function docsDir(root: string): string {
  try {
    const file = process.env.TEAM_CONFIG_FILE || join(root, '.pi/team/config.sh')
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
    const file = process.env.TEAM_CONFIG_FILE || join(root, '.pi/team/config.sh')
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
    const file = process.env.TEAM_CONFIG_FILE || join(root, '.pi/team/config.sh')
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

/** 本会话在 tmux 里的 `session:window`（env 覆盖优先：headless 与夹具用它）。 */
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

/** 读完 spool 自 <offset> 起的新行（只消费完整行；size < offset = 被裁剪/轮转 → 从 0 重读）。 */
function readNewLines(file: string, offset: number): { lines: string[]; offset: number } {
  try {
    const size = statSync(file).size
    if (size < offset) offset = 0
    if (size === offset) return { lines: [], offset }
    const fd = openSync(file, 'r')
    try {
      const buf = Buffer.alloc(size - offset)
      readSync(fd, buf, 0, buf.length, offset)
      const text = buf.toString('utf8')
      const end = text.lastIndexOf('\n')
      if (end < 0) return { lines: [], offset }
      const consumed = Buffer.byteLength(text.slice(0, end + 1), 'utf8')
      const lines = text.slice(0, end).split('\n').map(l => l.replace(/\r$/, '')).filter(l => l.trim())
      return { lines, offset: offset + consumed }
    } finally {
      closeSync(fd)
    }
  } catch {
    return { lines: [], offset }
  }
}

/** spool 的当前大小 = 本次会话的**投递基线**：启动之前写入的行不叫醒任何人（backlog 是 pulse 的活）。
 *  （单抽成函数是为了让「基线」这件事有一个可定点破坏的单点。） */
function baselineOffset(file: string): number {
  return readNewLines(file, 0).offset
}

/** spool 超上限 → 截头留尾（尾部信号不丢）。返回裁剪后的新大小（没裁 → -1）：
 *  调用方必须把 offset 对上新大小，否则「size < offset → 从 0 重读」会把刚投过的尾部再叫一次。 */
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
  let offset = 0
  let seen = 0
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

  /** 投递一条唤醒：指针 + 截断预览，绝不带 payload 全文。 */
  const wake = (lines: string[]): void => {
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
    const text =
      `[teamsmith] inbox wake: ${lines.length} new team message(s).\n` +
      `${shown.join('\n')}${more > 0 ? `\n- … and ${more} more` : ''}\n` +
      (hasInbox && hasLogOnly
        ? `Full text: the ${inboxPath} file named on each line; the others (knock/nudge) are pointers to the sender's own log (\`team inbox\` / \`team digest\` / state/nudges.log).\n`
        : hasLogOnly
          ? `These wakes point at the sender's own log (\`team inbox\` / \`team digest\`); they carry no inbox line.\n`
          : `Full text: read ${inboxPath} — this wake-up carries a one-line pointer, not the payload.\n`)
    seen += lines.length
    appendLedger(root, `wake n=${lines.length} total=${seen} inbox=${inbox} kinds=${lines.map(l => l.split('\t')[1] || '?').join(',')}`)
    try {
      pi.sendMessage({ customType: 'team-inbox', content: text, display: true },
        { triggerTurn: true, deliverAs: 'followUp' })
    } catch {
      /* 会话正在退出等场合：账本已经记了，不抛 */
    }
  }

  /** 读 spool 的新行并合并成一条唤醒（同一拍收到的多行只叫一次）。 */
  const flush = (): void => {
    if (!spool) return
    const res = readNewLines(spool, offset)
    offset = res.offset
    const trimmed = trimSpool(spool)
    if (trimmed >= 0) offset = trimmed   // 裁剪后 size 变小：offset 对上新大小，避免把尾部重叫一次
    if (res.lines.length) wake(res.lines)
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
    const found = resolveTarget()
    if (!found) {
      appendLedger(root, 'skip setup: no tmux target (set TEAM_INBOX_WATCH_TARGET to override)')
      return
    }
    const override = !!(process.env.TEAM_INBOX_WATCH_TARGET || '').trim()
    if (!override && found.session !== cfgSession(root)) {
      // 不是本团队的 session：绝不接管（跨项目的窗口不归这里管）
      appendLedger(root, `skip setup: session ${found.session} != ${cfgSession(root)}`)
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
    seen = 0
    reapDeadRegs(dir, reg)
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
  })
}
