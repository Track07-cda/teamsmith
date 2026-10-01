#!/usr/bin/env node
/**
 * teamsmith · team-inbox-watch 扩展的确定性夹具（M30）
 *
 *   <node|bun> team-inbox-watch-harness.mjs <skill>/extension/team-inbox-watch.ts [--keep]
 *
 * 为什么用「假 Pi 宿主」而不是真模型：本夹具要证的是**扩展自己的契约**——注册文件（发送方据此判定
 * 「目标是 pi 且有监视」）、spool 增量读取、合并成一条、只带指针不带 payload、会话级清理、账本格式。
 * 这些完全由接口（on('session_start'/'session_shutdown') / sendMessage / 文件）决定，用真模型只会把判据
 * 换成「模型有没有照着做」。真实的「唤醒一个空闲 pi 会话」由 E8 的 RPC 探针实证过（docs/team/reports/E8-verify/），
 * 「pi 通道零 tmux 调用」由 smoke 12b/13d 的 tmux shim 实证。
 *
 * 隔离纪律（M7.2 的教训）：继承来的团队身份/tmux 身份先清掉，TEAM_ROOT 显式指向临时仓库；每条断言都要求
 * 产物落在临时仓库里；跑完再对比**真实仓库** state/ 的前后快照（反向守卫）。
 *
 * 每个用例打印一行 `TEAM-IW-CASE PASS|FAIL <name> [:: detail]`，任一 FAIL → 退出码 1。
 */
import { execFileSync, spawnSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, readlinkSync, rmSync, statSync, watch, writeFileSync, appendFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'

const args = process.argv.slice(2)
const keep = args.includes('--keep') || process.env.TEAM_IW_KEEP === '1'
const ext = args.find(a => !a.startsWith('--'))
if (!ext) {
  console.error('usage: team-inbox-watch-harness.mjs <path/to/team-inbox-watch.ts> [--keep]')
  process.exit(2)
}
const EXT = resolve(ext)
const SKILL_DIR = resolve(EXT, '../..')   // <skill>/extension/<file> → <skill>

// ── 身份隔离：绝不继承调用者的团队身份与 tmux 身份；但这四个**夹具控制**必须在清掉之前
//    快照、清完后只还原它们 —— 否则夹具自己的隔离会把「这次要强制失败」丢掉（有意制造的
//    故障被当成继承环境静默丢弃，这条正是 M53 要求说清楚的形状）。
const CONTROL_KEYS = ['TEAM_INBOX_WATCH_FORCE_FAIL', 'TEAM_IW_REQUIRE_WATCH', 'TEAM_IW_ONLY', 'TEAM_IW_KEEP',
  'TEAM_INBOX_WATCH_ABORT_AFTER', 'TEAM_SMOKE_FIXTURE',
  'TEAM_IW_CHILD_REPO', 'TEAM_IW_CHILD_TARGET', 'TEAM_IW_CHILD_KIND', 'TEAM_IW_CHILD_FROM', 'TEAM_IW_CHILD_INBOX', 'TEAM_IW_CHILD_PAYLOAD']
const CONTROLS = Object.fromEntries(CONTROL_KEYS.map(k => [k, process.env[k]]))
for (const key of Object.keys(process.env)) {
  if (/^(TEAM_|SMOKE_)/.test(key) || key === 'TMUX' || key === 'TMUX_PANE') delete process.env[key]
}
for (const [k, v] of Object.entries(CONTROLS)) {
  if (v === undefined) delete process.env[k]
  else process.env[k] = v
}

// ── P81 · 崩溃子进程（夹具只在 TEAM_SMOKE_FIXTURE=1 下生效）：父进程用 `--child` 启动同一个文件，
//    子进程跑一任真会话、追加一行 spool，然后由扩展的注入点（TEAM_INBOX_WATCH_ABORT_AFTER=read|intent）
//    在写前日志的那一步 SIGKILL 自己 —— 重启后的判定必须由日志（而不是内存）做出来。
if (args.includes('--child')) {
  const repo = process.env.TEAM_IW_CHILD_REPO || ''
  if (!repo) { console.error('harness --child: TEAM_IW_CHILD_REPO missing'); process.exit(2) }
  process.env.TEAM_ROOT = repo
  process.env.TEAM_INBOX_WATCH_TARGET = process.env.TEAM_IW_CHILD_TARGET || 'm30s:pm'
  process.env.TEAM_INBOX_WATCH_POLL_MS = '50'
  process.env.TEAM_INBOX_WATCH_HEARTBEAT_MS = '200'
  const cdir = join(repo, '.pi/team/state/inbox-watch')
  const handlersC = {}
  const factoryC = (await import(EXT)).default
  factoryC({ on: (n, fn) => { (handlersC[n] ||= []).push(fn) }, registerTool() {}, registerCommand() {}, sendMessage: () => {} })
  for (const fn of handlersC.session_start ?? []) await fn({ reason: 'startup' }, { cwd: repo })
  const regC = readdirSync(cdir).find(f => f.endsWith('.reg'))
  if (!regC) { console.error('harness --child: no .reg after session_start'); process.exit(2) }
  appendFileSync(join(cdir, regC.replace(/\.reg$/, '.wake')),
    `${Date.now()}\t${process.env.TEAM_IW_CHILD_KIND || 'say'}\t${process.env.TEAM_IW_CHILD_FROM || 'pm'}\t${process.env.TEAM_IW_CHILD_INBOX || 'pm'}\t${process.env.TEAM_IW_CHILD_PAYLOAD || 'child line'}\n`)
  await new Promise(r => setTimeout(r, 4000))
  console.error('harness --child: the abort knob never fired')
  process.exit(3)   // 走到这里 = 注入点没生效（父进程必须为此红）
}

// ── M53 前提：这个用户此刻能不能注册一个 watch（量它，不猜它）。只靠监视器唤醒的用例依赖它；
//    TEAM_INBOX_WATCH_FORCE_FAIL 显式造出同一个不可用前提（不真去注册），并标 forced=1。
const FORCE_FAIL = (process.env.TEAM_INBOX_WATCH_FORCE_FAIL || '').trim()
let premise = { ok: true, errno: '', forced: false }
if (FORCE_FAIL) {
  premise = { ok: false, errno: FORCE_FAIL, forced: true }
} else {
  try {
    const probeDir = mkdtempSync(join(tmpdir(), 'teamsmith-iw-prereq-'))
    const probeWatcher = watch(probeDir, () => {})
    probeWatcher.close()
    rmSync(probeDir, { recursive: true, force: true })
  } catch (error) {
    premise = { ok: false, errno: String(error?.code ?? 'unknown'), forced: false }
  }
}

// 前提行里的「额度观察」：与扩展同一条完整性规则（嵌套 PID 命名空间 / 读不到的 fdinfo → unknown）。
// 它只是前提行的上下文；判定权在前提本身（一次真注册），不在这个数。
function quotaObservation() {
  let max = 'unknown'
  try {
    const t = readFileSync('/proc/sys/fs/inotify/max_user_watches', 'utf8').trim()
    if (/^[0-9]+$/.test(t)) max = t
  } catch { /* unknown */ }
  let used = 'unknown'
  try {
    const ns = /^NSpid:\s*(.+)$/m.exec(readFileSync('/proc/self/status', 'utf8'))
    if (ns && ns[1].trim().split(/\s+/).length === 1 && typeof process.getuid === 'function') {
      const uid = process.getuid()
      let total = 0
      let complete = true
      for (const entry of readdirSync('/proc')) {
        if (!/^[0-9]+$/.test(entry)) continue
        let owner
        try { owner = statSync(`/proc/${entry}`).uid } catch { continue }
        if (owner !== uid) continue
        let fds
        try { fds = readdirSync(`/proc/${entry}/fd`) } catch { complete = false; break }
        for (const fd of fds) {
          let link = ''
          try { link = readlinkSync(`/proc/${entry}/fd/${fd}`) } catch { continue }
          if (link !== 'anon_inode:inotify') continue
          let info = ''
          try { info = readFileSync(`/proc/${entry}/fdinfo/${fd}`, 'utf8') } catch { complete = false; break }
          total += new Set([...info.matchAll(/^inotify wd:([0-9a-f]+)\s/gm)].map(m => m[1])).size
        }
        if (!complete) break
      }
      if (complete) used = String(total)
    }
  } catch { /* unknown */ }
  return `${used}/${max}`
}

const sleep = (ms) => new Promise(r => setTimeout(r, ms))
let failures = 0
let skipped = 0
const STRICT = /^(1|y|yes|true|on)$/i.test(String(process.env.TEAM_IW_REQUIRE_WATCH ?? ''))
const ONLY = new Set(String(process.env.TEAM_IW_ONLY ?? '').split(',').map(x => x.trim()).filter(Boolean))
const caseId = (name) => (name.match(/^[A-Za-z0-9][\w.-]*/) ?? [''])[0]
const only = (id) => ONLY.size === 0 || ONLY.has(id)
// 只靠监视器唤醒的用例（**逐字的名单**，不看启发式）：前提不可用时既不算 PASS 也不算 FAIL。
// 前缀匹配；S24 的两条「成功注册」断言只依赖真 watcher，单独列出（同用例的强制失败部分照跑）。
const WATCH_DEPENDENT = [
  'S2 ', 'S3 ', 'S4 ', 'S5 ', 'S6 ', 'S9 ', 'S10 ', 'S11 ', 'S12 ', 'S13 ', 'S21',
  'S24 a healthy session writes no degraded record',
  'S24 a successful registration clears a stale degraded record',
]
const isWatchDependent = (name) => WATCH_DEPENDENT.some(p => name.startsWith(p))
const check = (name, ok, detail = '') => {
  if (!only(caseId(name))) return   // TEAM_IW_ONLY：不选中的用例不打印、不计数（也不许悄悄算绿）
  if (!premise.ok && isWatchDependent(name)) {
    if (STRICT) {
      console.log(`TEAM-IW-CASE FAIL ${name} :: watch premise unavailable (errno=${premise.errno}${premise.forced ? ', forced=1' : ''}) and TEAM_IW_REQUIRE_WATCH=1`)
      failures++
    } else {
      console.log(`TEAM-IW-CASE SKIP ${name} :: watch unavailable (errno=${premise.errno}${premise.forced ? ', forced=1' : ''})`)
      skipped++
    }
    return
  }
  console.log(`TEAM-IW-CASE ${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ` :: ${detail}` : ''}`)
  if (!ok) failures++
}
async function waitFor(fn, ms = 3000, step = 25) {
  const t0 = Date.now()
  for (;;) {
    try { if (fn()) return true } catch { /* ignore */ }
    if (Date.now() - t0 > ms) return false
    await sleep(step)
  }
}

console.log(premise.ok
  ? `TEAM-IW-PREREQ watch=ok forced=0 strict=${STRICT ? 1 : 0}`
  : `TEAM-IW-PREREQ watch=errno=${premise.errno} watches=${quotaObservation()} forced=${premise.forced ? 1 : 0} strict=${STRICT ? 1 : 0}`)

// ── 夹具仓库（有 .pi/team/config.sh 的 git 仓库；findRoot 走 git 主工作树那一支）────────
const TMP = mkdtempSync(join(tmpdir(), 'teamsmith-iw-'))
const ROOT = join(TMP, 'repo')
mkdirSync(join(ROOT, '.pi/team'), { recursive: true })
mkdirSync(join(ROOT, 'docs/team/inbox'), { recursive: true })
process.env.TEAM_ROOT = ROOT
process.env.TEAM_INBOX_WATCH_TARGET = 'm30s:pm'      // headless 夹具：显式 target（不查 tmux）
process.env.TEAM_INBOX_WATCH_POLL_MS = '3600000'     // 先关掉轮询兜底：这一段只允许 fs.watch 叫醒
process.env.TEAM_INBOX_WATCH_HEARTBEAT_MS = '200'
process.env.TEAM_INBOX_WATCH_PREVIEW = '60'
if (!keep) process.on('exit', () => { try { rmSync(TMP, { recursive: true, force: true }) } catch {} })
try { execFileSync('git', ['init', '-q', '-b', 'main', ROOT], { stdio: 'ignore' }) } catch {}
writeFileSync(join(ROOT, ".pi/team/config.sh"),
  'TEAM_PROJECT="iw-harness"\nTEAM_SESSION="m30s"\nTEAM_PM_WINDOW="pm"\nTEAM_DOCS_DIR="docs/team"\n')
const STATE = join(ROOT, '.pi/team/state')
const WATCH_DIR = join(STATE, 'inbox-watch')
const LEDGER = join(STATE, 'inbox-watch.log')

// ── 反向守卫：真实仓库 state/ 前后快照 ────────────────────────────────────────
const REAL_REPO = resolve(EXT, '../../..')           // <repo>/skills/teamsmith/extension/team-inbox-watch.ts
const snapshot = (dir) => {
  if (!existsSync(dir)) return 'absent'
  const walk = (d) => readdirSync(d, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name)).flatMap(e =>
    e.isDirectory() ? walk(join(d, e.name)) : [`${join(d, e.name)}:${statSync(join(d, e.name)).size}:${statSync(join(d, e.name)).mtimeMs}`])
  return walk(dir).join('\n')
}
const REAL_STATE = join(REAL_REPO, '.pi/team/state')
const REAL_BEFORE = snapshot(REAL_STATE)

// ── 假 Pi 宿主 ────────────────────────────────────────────────────────────────
const sent = []
let hostFail = 0   // S25c：下一批 sendMessage 抛错（会话 API 拒绝的夹具形状）
const handlers = {}
const api = {
  on: (name, fn) => { (handlers[name] ||= []).push(fn) },
  registerTool: () => {},
  registerCommand: () => {},
  sendMessage: (msg, opts) => {
    if (hostFail > 0) { hostFail--; throw new Error('S25c fake host refused the message') }
    sent.push({ msg, opts, at: Date.now() })
  },
}
const emit = async (name, ...rest) => { for (const fn of handlers[name] ?? []) await fn(...rest) }
const ctx = { cwd: ROOT }
const captureKey = () => { const r = regs()[0]; if (r) KEY = r.replace(/\.reg$/, ''); return KEY }
const sessionStart = async () => { await emit('session_start', { reason: 'startup' }, ctx); captureKey() }
const shutdown = () => emit('session_shutdown', { reason: 'quit' }, ctx)

const regs = () => (existsSync(WATCH_DIR) ? readdirSync(WATCH_DIR).filter(f => f.endsWith('.reg')) : [])
const wakes = () => (existsSync(WATCH_DIR) ? readdirSync(WATCH_DIR).filter(f => f.endsWith('.wake')) : [])
// spool 与注册同名（只差后缀）：先看真的 .wake，再从未删的 .reg 推导，最后用记住的路径 ——
// shutdown 之后还要能往同一个 spool 写「历史行」（S5）。P81 组在 resetState 后会先按住 KEY 再建文件。
let lastSpool = ''
let KEY = ''
const spoolFile = () => {
  const w = wakes()[0]
  if (w) return (lastSpool = join(WATCH_DIR, w))
  const r = regs()[0]
  if (r) return (lastSpool = join(WATCH_DIR, r.replace(/\.reg$/, '.wake')))
  if (KEY) return (lastSpool = join(WATCH_DIR, `${KEY}.wake`))
  return lastSpool
}
const appendWake = (kind, from, inbox, payload) => appendWakeAt(Date.now(), kind, from, inbox, payload)
const appendWakeAt = (ts, kind, from, inbox, payload) => {
  mkdirSync(WATCH_DIR, { recursive: true })
  const f = spoolFile()
  if (!f) throw new Error('no spool file: the extension never registered')
  appendFileSync(f, `${ts}\t${kind}\t${from}\t${inbox}\t${payload}\n`)
}
// P28/B1：原样追加字节（生产者的 `LC_ALL=C cut -c1-700` 会写出非法 UTF-8 的预览）——
// 夹具里用 Buffer 直写，保证测的是「spool 里有非法字节」这个形状，而不是 String 的往返。
const appendWakeRaw = (buf) => {
  mkdirSync(WATCH_DIR, { recursive: true })
  const f = spoolFile()
  if (!f) throw new Error('no spool file: the extension never registered')
  appendFileSync(f, buf)
}
const ledger = () => (existsSync(LEDGER) ? readFileSync(LEDGER, 'utf8').trim().split('\n') : [])
const ledgerMatches = (re) => ledger().filter(l => re.test(l)).length
const lastText = (i = -1) => String(sent.at(i)?.msg?.content ?? '')

// ── P81 · 投递日志的**独立**解析（不复用实现里的解析器：夹具自己按规格解一遍）────────────────
const jesc = (s) => String(s).replace(/\\/g, '\\\\').replace(/\n/g, '\\n').replace(/\r/g, '\\r').replace(/\t/g, '\\t').replace(/ /g, '\\s')
const junesc = (s) => String(s).replace(/\\(.)/g, (_m, c) => (c === 'n' ? '\n' : c === 'r' ? '\r' : c === 't' ? '\t' : c === 's' ? ' ' : c))
const jrec = (line) => {
  const m = /^(\S+) (start|read|intent|sent|failed|floor)(?: (.*))?$/.exec(line)
  if (!m) return null
  const fields = {}
  for (const tok of (m[3] ?? '').split(' ')) {
    if (!tok) continue
    const i = tok.indexOf('=')
    if (i <= 0) return null
    fields[tok.slice(0, i)] = junesc(tok.slice(i + 1))
  }
  return { ts: m[1], kind: m[2], fields }
}
const journalPathOf = () => { const f = spoolFile(); return f ? f.replace(/\.wake$/, '.deliver') : '' }
const journalLines = () => { const f = journalPathOf(); return f && existsSync(f) && statSync(f).isFile() ? readFileSync(f, 'utf8').split('\n').filter(l => l.trim()) : [] }
const journalOf = (kind) => journalLines().map(jrec).filter(r => r && r.kind === kind)
const spoolLines = () => { const f = spoolFile(); return f && existsSync(f) ? readFileSync(f, 'utf8').split('\n').filter(l => l.trim()) : [] }
/** 与实现同口径的行身份：发送方的 `id=` 字段优先，否则整行 sha1（夹具自己算，不读实现） */
const identityOf = (line) => {
  const id = (String(line).split('\t')[5] ?? '').trim()
  if (id) return id
  return `sha1:${createHash('sha1').update(String(line), 'utf8').digest('hex')}`
}
/** 清空夹具状态（只动临时仓库）：新用例（P81 组）拿一个干净日志，避免前面用例的账本/日志串味 */
const resetStateSync = () => {
  rmSync(WATCH_DIR, { recursive: true, force: true })
  rmSync(LEDGER, { force: true })
  lastSpool = ''
}
const resetState = async () => {
  await shutdown()
  resetStateSync()
}
/** 子进程崩溃运行器：父进程在**另一个进程**里跑一任会话，在注入点真死（SIGKILL） */
const runChild = (abortAfter, payload) => {
  const env = {
    ...process.env,
    TEAM_SMOKE_FIXTURE: '1',
    TEAM_IW_CHILD_REPO: ROOT,
    TEAM_IW_CHILD_TARGET: 'm30s:pm',
    TEAM_IW_CHILD_PAYLOAD: payload,
    TEAM_INBOX_WATCH_ABORT_AFTER: abortAfter,
  }
  return spawnSync(process.execPath, [...process.execArgv, resolve(process.argv[1]), EXT, '--child'],
    { cwd: ROOT, env, encoding: 'utf8', timeout: 20000 })
}

if (!existsSync(EXT)) {
  check('import', false, `extension missing: ${EXT}`)
  console.log('TEAM-IW-HARNESS FAIL (extension missing — this is the pre-M30 shape)')
  process.exit(1)
}
let factory
try {
  factory = (await import(EXT)).default
} catch (error) {
  check('import', false, String(error?.stack ?? error))
  console.log('TEAM-IW-HARNESS FAIL (import)')
  process.exit(1)
}
factory(api)
check('factory registers session_start / session_shutdown hooks',
  (handlers.session_start ?? []).length > 0 && (handlers.session_shutdown ?? []).length > 0)
check('factory starts no session resource (no state/ before session_start)', !existsSync(WATCH_DIR) && !existsSync(LEDGER))
check('nothing is delivered before session_start', sent.length === 0)

// ── S1：session_start 写出注册（发送方据此判定「目标是 pi 且有监视」）────────────
await sessionStart()
spoolFile()   // 注册后把 spool 路径记下来：被 TEAM_IW_ONLY 过滤掉的用例（S2…）不再替后面钉路径
check('S1 session_start creates exactly one .reg', regs().length === 1, `regs=${regs().length}`)
const regText = regs().length ? readFileSync(join(WATCH_DIR, regs()[0]), 'utf8') : ''
for (const [field, want] of [['target', 'm30s:pm'], ['inbox', 'pm'], ['cwd', ROOT]]) {
  check(`S1 registry carries ${field}=${want}`, new RegExp(`^${field}=${want}$`, 'm').test(regText), regText.replace(/\n/g, ' | '))
}
const pid = Number(/^pid=(\d+)$/m.exec(regText)?.[1] ?? 0)
check('S1 registry pid is this live process', pid === process.pid, `pid=${pid}`)
check('S1 registry has a fresh heartbeat', (() => {
  const hb = Number(/^heartbeat=(\d+)$/m.exec(regText)?.[1] ?? 0)
  return hb > 0 && Math.abs(Math.floor(Date.now() / 1000) - hb) <= 2
})())

// 心跳确实在刷新（文件被重写、mtime 前进；heartbeat 字段是秒级，400ms 内可能看不出变化）
{
  const regPath = join(WATCH_DIR, regs()[0])
  const m0 = statSync(regPath).mtimeMs
  process.env.TEAM_INBOX_WATCH_HEARTBEAT_MS = '100'
  await sleep(500)
  const m1 = statSync(regPath).mtimeMs
  check('S1 heartbeat keeps refreshing the registry file', m1 > m0, `mtimeMs ${m0} -> ${m1}`)
  process.env.TEAM_INBOX_WATCH_HEARTBEAT_MS = '200'
}

// ── S2：spool 新行 → 唤醒（fs.watch；轮询被关掉，所以红 = 没在监视）──────────────
if (only('S2')) {
  const before = sent.length
  appendWake('say', 'pm', 'pm', 'please read the failing test')
  const ok = await waitFor(() => sent.length > before + 0)
  check('S2 a new spool line wakes the session (fs.watch, polling disabled)', ok && sent.length === before + 1,
    `messages=${sent.length - before}`)
  check('S2 wake is a custom team-inbox message with triggerTurn+followUp',
    sent.at(-1)?.msg?.customType === 'team-inbox' && sent.at(-1)?.opts?.triggerTurn === true && sent.at(-1)?.opts?.deliverAs === 'followUp',
    JSON.stringify({ customType: sent.at(-1)?.msg?.customType, ...(sent.at(-1)?.opts ?? {}) }))
  const body = lastText()
  check('S2 wake is a pointer to the inbox file, not the payload', body.includes('docs/team/inbox/pm.md'), body.split('\n')[0])
  check('S2 wake carries a one-line preview and says it is a pointer', body.includes('please read the failing test') && /one-line pointer/i.test(body))
}

// ── S3：同一拍的多行合并成一条（不按行刷屏） ─────────────────────────────────
if (only('S3')) {
  const before = sent.length
  mkdirSync(WATCH_DIR, { recursive: true })
  for (const n of [1, 2, 3]) appendWake('say', 'dev', 'pm', `burst line ${n}`)
  await sleep(600)
  check('S3 a burst of three lines produces exactly one wake', sent.length === before + 1, `messages=${sent.length - before}`)
  const body = lastText()
  check('S3 the merged wake names every line', [1, 2, 3].every(n => body.includes(`burst line ${n}`)), body.replace(/\n/g, ' | '))
}

// ── S4：预览截断 + 每条约 4 行上限（只带指针，不带 payload 全文） ───────────────
if (only('S4')) {
  const before = sent.length
  const long = 'X'.repeat(400)
  appendWake('knock', 'dev', 'pm', `${long}TAIL-MARKER`)
  await sleep(500)
  const body = lastText()
  check('S4 long payload is truncated in the wake (no payload dump)', !body.includes('TAIL-MARKER') && body.includes('…'),
    `len=${body.length}`)
  const before2 = sent.length
  for (let i = 0; i < 8; i++) appendWake('say', 'dev', 'pm', `many ${i}`)
  await sleep(600)
  check('S4 eight lines in one burst still produce one wake', sent.length === before2 + 1, `messages=${sent.length - before2}`)
  const body2 = lastText()
  check('S4 the wake lists at most 5 lines and says how many more', body2.includes('and 3 more'), body2.replace(/\n/g, ' | '))
}

// ── S5：启动基线（历史行不叫醒任何人；启动后的行才唤醒） ─────────────────────────
if (only('S5')) {
  await shutdown()
  const before = sent.length
  appendWake('say', 'pm', 'pm', 'historical line written while nobody watched')
  await sleep(400)
  check('S5 no wake while shut down (timers closed)', sent.length === before, `messages=${sent.length - before}`)
  await sessionStart()
  // 基线 = 启动那一刻 spool 的字节数：账本行把这件事写成可直接复核的事实（setabline 的定点破坏必红在这条）
  const startedLine = ledger().filter(l => / started target=/.test(l)).at(-1) ?? ''
  const spoolSize = statSync(spoolFile()).size
  check('S5 startup baseline equals the current spool size', startedLine.includes(`baseline=${spoolSize}`) && spoolSize > 0,
    `${startedLine.trim()} (size=${spoolSize})`)
  await sleep(600)
  check('S5 a line written before session_start is baseline, not a wake', sent.length === before,
    `messages=${sent.length - before}`)
  appendWake('say', 'pm', 'pm', 'line after startup')
  const ok = await waitFor(() => sent.length > before)
  check('S5 a line after startup still wakes (from the previous offset)', ok && sent.length === before + 1,
    `messages=${sent.length - before}`)
  check('S5 the wake only mentions the new line', lastText().includes('line after startup') && !lastText().includes('historical line'))
}

// ── S6：spool 上限（截头留尾）不把尾部重叫一遍 ───────────────────────────────
if (only('S6')) {
  process.env.TEAM_INBOX_WATCH_MAX_BYTES = '2048'
  const before = sent.length
  const f = spoolFile()
  // P28：裁剪是读者自己的记账动作 —— offset 对上新大小之后，账本不该出现任何恢复行。
  // 快照必须在裁剪**之前**取（M30 翻转包的 trim-offset 定点破坏就钉在这一条上）。
  const recovery0 = ledgerMatches(/spool shrink/) + ledgerMatches(/ rescan lines=/) + ledgerMatches(/offset clamp/)
  // 一条超长行 + 紧跟一条正常行：裁剪后尾部应当留下后者（而不是被整段丢掉）
  appendFileSync(f, `huge\tknock\tdev\tpm\t${'Y'.repeat(4096)}\n`)
  appendFileSync(f, 'kept\tknock\tdev\tpm\tkeep-me-after-trim\n')
  await sleep(700)
  check('S6 oversized spool content is delivered once (both lines in one wake)',
    sent.length === before + 1 && lastText().includes('keep-me-after-trim'), `messages=${sent.length - before}`)
  const size = statSync(f).size
  check('S6 spool is trimmed under the cap and keeps the tail line',
    size <= 2048 && readFileSync(f, 'utf8').includes('keep-me-after-trim'), `bytes=${size}`)
  appendWake('say', 'pm', 'pm', 'after trim')
  await sleep(700)
  check('S6 the trim is reconciled locally (no spool shrink / rescan / clamp afterwards)',
    ledgerMatches(/spool shrink/) + ledgerMatches(/ rescan lines=/) + ledgerMatches(/offset clamp/) === recovery0,
    `${ledger().slice(-3).join(' | ')}`)
  check('S6 exactly one new wake after the trim (tail line is not replayed)', sent.length === before + 2,
    `messages=${sent.length - before}`)
  check('S6 the post-trim wake is the new line', lastText().includes('after trim'), lastText().replace(/\n/g, ' | '))
  delete process.env.TEAM_INBOX_WATCH_MAX_BYTES
}

// ── S7：session_shutdown 清场（删注册 + 停表）——不然发送方会一直以为有活监视器 ──
{
  await shutdown()
  await sleep(300)
  check('S7 shutdown removes the registry file', regs().length === 0, `regs=${regs().length}`)
  const before = sent.length
  appendWake('say', 'pm', 'pm', 'after shutdown')
  await sleep(600)
  check('S7 no wake after shutdown', sent.length === before, `messages=${sent.length - before}`)
}

// ── S8：没有 tmux 目标就不注册（绝不假装自己是某个窗口的收件箱） ─────────────────
{
  delete process.env.TEAM_INBOX_WATCH_TARGET
  await sessionStart()
  check('S8 without a tmux target nothing is registered', regs().length === 0, `regs=${regs().length}`)
  check('S8 the ledger says why it skipped', ledger().some(l => /skip setup: no tmux target/.test(l)),
    ledger().at(-1) ?? '(no ledger)')
  await shutdown()
}

// ── S9：账本（state/inbox-watch.log：started / wake / stopped，每行 ISO 前缀） ──
{
  const lines = ledger()
  const iso = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z /
  check('S9 every ledger line starts with an ISO timestamp', lines.length > 0 && lines.every(l => iso.test(l)), `${lines.length} lines`)
  check('S9 ledger records startup with target+inbox', lines.some(l => / started target=m30s:pm inbox=pm /.test(l)))
  check('S9 ledger records each wake with the merged count', lines.some(l => / wake n=3 /.test(l)) && lines.some(l => / wake n=1 /.test(l)),
    lines.filter(l => l.includes('wake')).slice(0, 3).join(' | '))
  // P81：wake 行点名 seq 与身份；启动基线的代价单独计数（doctrine 不变，只是不再静默）
  check('S9 wake lines name their seq and the identities they carry',
    lines.some(l => / wake n=\d+ total=\d+ inbox=\S+ kinds=\S+ seq=\d+ ids=\S+/.test(l)),
    lines.filter(l => / wake n=/.test(l)).at(-1) ?? '(no wake line)')
  check('S9 startup accounting is in the ledger (baseline swallowed n=)',
    lines.some(l => /baseline swallowed n=\d+ /.test(l)), lines.filter(l => /baseline swallowed/.test(l)).at(-1) ?? '(none)')
  check('S9 ledger records shutdown', lines.some(l => / stopped target=m30s:pm /.test(l)))
}

// ── S10：端到端（真扩展 + 真 CLI + 真文件）：假 worker 的回合结束通知 → 监视唤醒 → 收件箱可读 ──
//   这是 brief 要求的那条实录的**零模型**形态：把假 Pi 宿主换掉，其余全是生产件（真扩展注册、
//   `team notify pm` 真跑、真 durable 收件箱、真 spool）。真实的「唤醒一个空闲 pi 会话（含模型一轮）」
//   由 E8 的 RPC 探针实证（docs/team/reports/E8-verify/probes），这里不重复付模型成本。
process.env.TEAM_INBOX_WATCH_TARGET = 'm30s:pm'
process.env.TEAM_INBOX_WATCH_POLL_MS = '3600000'
if (only('S10')) {
  await sessionStart()
  const before = sent.length
  const summary = join(TMP, 'summary-dev-M30.md')
  writeFileSync(summary, 'M30-E2E: fake worker turn end went through the watch channel')
  const cli = join(SKILL_DIR, 'scripts/team')
  let out = ''
  let rc = 0
  try {
    out = execFileSync('bash', [cli, 'notify', 'pm', '--from-file', summary], {
      cwd: ROOT, encoding: 'utf8', timeout: 20000,
      env: { ...process.env, TEAM_ROOT: ROOT, TEAM_NOTIFY_TMUX: '1' },
    })
  } catch (error) {
    rc = 1
    out = `${String(error?.stdout ?? '')}${String(error?.stderr ?? '')}`
  }
  check('S10 real `team notify pm` exits 0', rc === 0, out.trim().split('\n').at(-1) ?? '')
  check('S10 the CLI reports the pi watch channel (not a paste, not a tmux gate)',
    /pi 监视通道/.test(out) && !/不在 tmux 会话里/.test(out), out.trim().split('\n').slice(-2).join(' | '))
  const inboxFile = join(ROOT, 'docs/team/inbox/pm.md')
  const hits = (existsSync(inboxFile) ? readFileSync(inboxFile, 'utf8') : '').split('\n').filter(l => l.includes('M30-E2E')).length
  check('S10 the durable inbox line exists exactly once (no duplicate from the channel)', hits === 1, `lines=${hits}`)
  const woke = await waitFor(() => sent.length > before, 5000)
  check('S10 the running extension wakes the session (zero model calls)',
    woke && sent.length === before + 1, `messages=${sent.length - before}`)
  const body = lastText()
  check('S10 the wake carries the summary and points at the inbox',
    body.includes('M30-E2E') && body.includes('docs/team/inbox/pm.md'), body.replace(/\n/g, ' | '))
  const activeEntries = existsSync(join(STATE, 'outbox'))
    ? readdirSync(join(STATE, 'outbox')).filter(f => f.endsWith('.msg')).length : 0
  check('S10 the outbox is empty after the watch delivery', activeEntries === 0, `entries=${activeEntries}`)
  // P81/2.4：spool 行带发送方自己的记录 id，唤醒文本印的就是它，且能在 delivered.log 里一一定位
  const spoolTail = (readFileSync(spoolFile(), 'utf8').trimEnd().split('\n').at(-1) ?? '').split('\t')
  const entryId = (spoolTail[5] ?? '').trim()
  check('S10 the spool line carries the sender record id (6th field)', !!entryId, `fields=${spoolTail.length} id=${entryId || '(none)'}`)
  const deliveredLog = join(STATE, 'outbox/delivered.log')
  const idHits = existsSync(deliveredLog)
    ? readFileSync(deliveredLog, 'utf8').split('\n').filter(l => l.split('\t')[2] === entryId).length : 0
  check('S10 the printed identity resolves to exactly one delivered.log record',
    !!entryId && idHits === 1 && lastText().includes(entryId), `hits=${idHits} id=${entryId}`)
  await shutdown()
}

// ── S11：外部截断+重写（M43 事故形状）：已投递行不得重放，total 不灌水 ─────────────────
// 2026-09-19 事故（this-project 主树 inbox-watch.log:118-120）：外部力量把 spool **原位截断又写回
// 同样内容**（两次，间隔 6 秒；inode btime 证明不是 rename 替换；仓内写路径只有 `>>` 追加）。
// 旧实现 `size < offset → offset = 0` 静默重置 → 下一拍从 0 全量重读 → 同一份 42 行被叫两遍、
// total 被灌水 84。修复后：shrink 必须记账本、已投递行靠去重记忆压掉、total 只随真新增涨。
const lastTotal = () => {
  // 只看**本会话**（最后一个 started 之后）的 wake 行：`seen` 在 session_start 归零，
  // 拿上一个会话的 total 跟本会话比会得出假结论。
  const lines = ledger()
  const started = lines.map((l, i) => (/ started target=/.test(l) ? i : -1)).filter(i => i >= 0).at(-1) ?? -1
  const m = [...lines.slice(started + 1).join('\n').matchAll(/ wake n=\d+ total=(\d+) /g)]
  return m.length ? Number(m.at(-1)[1]) : 0
}
let s11Lines = []
if (only('S11')) {
  await sessionStart()
  const f = spoolFile()
  // 三条新行先正常投递（合并成一条唤醒），确保重放内容**全部已投递**
  const b0 = sent.length
  for (const n of [1, 2, 3]) appendWake('knock', 'dev', 'pm', `m43-replay-line-${n}`)
  await waitFor(() => sent.length > b0)
  await sleep(400)
  // 事故里重写的是**同一批字节**：直接从 spool 尾取真实的三行作为重写内容
  const content = readFileSync(f, 'utf8')
  s11Lines = content.trimEnd().split('\n').slice(-3)
  const before = sent.length
  const totalBefore = lastTotal()
  // 事故形状①：原位截断到 0（flush 在 merge window 后看到空文件 → shrink）
  writeFileSync(f, '')
  await sleep(500)
  // 事故形状②：写回同一批已投递行（flush 看到从 0 长回 → 旧实现从 0 全量重读）
  appendFileSync(f, `${s11Lines.join('\n')}\n`)
  await sleep(700)
  check('S11 external truncate+rewrite does not redeliver already-delivered lines',
    sent.length === before, `messages=${sent.length - before}`)
  const shrinkLines = ledger().filter(l => /spool shrink/.test(l))
  const dedupLines = ledger().filter(l => /replay suppressed/.test(l))
  check('S11 the ledger records the shrink and the replay suppression (auditable, not a silent reset)',
    shrinkLines.length >= 1 && dedupLines.length >= 1,
    `${shrinkLines.at(-1) ?? '(no shrink line)'} || ${dedupLines.at(-1) ?? '(no replay line)'}`)
  check('S11 total is not inflated by the rewrite', lastTotal() === totalBefore, `${totalBefore} -> ${lastTotal()}`)
  // 真新增仍然只叫一次、计数只 +1
  appendWake('say', 'pm', 'pm', 'genuinely-new-after-rewrite')
  const ok = await waitFor(() => sent.length > before)
  check('S11 a genuinely new line after the rewrite still wakes exactly once',
    ok && sent.length === before + 1 && lastText().includes('genuinely-new-after-rewrite'),
    `messages=${sent.length - before}`)
  check('S11 total grows by exactly one for the real new line', lastTotal() === totalBefore + 1,
    `${totalBefore} -> ${lastTotal()}`)
}

// ── S12：截短后的重放有界 + 说明跳过（只投最近 N 条「真新」，计数与文本一致）────────────────
if (only('S12')) {
  process.env.TEAM_INBOX_WATCH_REPLAY_MAX = '5'
  const f = spoolFile()
  // 垫大 spool（两条正常投递的填克行），保证后面的重写内容**一定比当前 offset 小**（真 shrink）
  const bPad = sent.length
  appendWake('say', 'dev', 'pm', `m43-pad-${'P'.repeat(240)}`)
  appendWake('say', 'dev', 'pm', `m43-pad-${'Q'.repeat(240)}`)
  await waitFor(() => sent.length > bPad)
  await sleep(400)
  const oldContent = readFileSync(f, 'utf8').trimEnd().split('\n')
  const oneOld = [oldContent.reduce((a, b) => (Buffer.byteLength(a) <= Buffer.byteLength(b) ? a : b))] // 最短的一行（已投递）
  const fresh = []
  for (let i = 1; i <= 12; i++) fresh.push(`${Date.now()}\tsay\tdev\tpm\trescan-fresh-${i}`)
  const rewritten = `${[...oneOld, ...fresh].join('\n')}\n`
  const curSize = statSync(f).size
  check('S12 fixture precondition: rewritten content is smaller than the current offset (a real shrink)',
    Buffer.byteLength(rewritten, 'utf8') < curSize, `${Buffer.byteLength(rewritten, 'utf8')} < ${curSize}`)
  const before = sent.length
  const totalBefore = lastTotal()
  // 单次 writeFileSync（O_TRUNC+写一盘）：merge window 后唯一一拍 flush 直接看到终态 → shrink → rescan
  writeFileSync(f, rewritten)
  await sleep(800)
  check('S12 rescan after a shrink delivers exactly one bounded wake',
    sent.length === before + 1, `messages=${sent.length - before}`)
  const body = lastText()
  check('S12 the bounded wake carries the newest fresh lines, not the skipped older ones',
    body.includes('rescan-fresh-12') && body.includes('rescan-fresh-8') && !body.includes('rescan-fresh-7'),
    body.replace(/\n/g, ' | '))
  check('S12 the wake text says it is a rescan and names the skipped counts',
    /rescan/.test(body) && /skipped 1 already-delivered \+ 7 older/.test(body), body.split('\n').find(l => /rescan/.test(l)) ?? '(no rescan line)')
  const rescanLine = ledger().filter(l => / rescan /.test(l)).at(-1) ?? ''
  check('S12 ledger records the rescan counts (lines/dup/skipped/deliver)',
    /rescan lines=13 dup=1 skipped=7 deliver=5 /.test(rescanLine), rescanLine.trim())
  check('S12 total grows only by the delivered bound (5, not 14)',
    lastTotal() === totalBefore + 5, `${totalBefore} -> ${lastTotal()}`)
  delete process.env.TEAM_INBOX_WATCH_REPLAY_MAX
}

// ── S13：去重记忆跨会话重启（<key>.deliver 投递日志是唯一 durable 权威；P81 起 .seen 只是被一次性导入）
if (only('S13')) {
  await shutdown()
  await sessionStart()   // 内存态清零 → 去重记忆只能从 <key>.deliver 重新加载
  const deliverFiles = existsSync(WATCH_DIR) ? readdirSync(WATCH_DIR).filter(x => x.endsWith('.deliver')) : []
  check('S13 the dedup memory is persisted (<key>.deliver is the journal)', deliverFiles.length === 1,
    `deliver=${deliverFiles.length}`)
  const f = spoolFile()
  const before = sent.length
  // 重写一批**上一会话投递过**的行（S11 那三行）：若记忆只活在内存里，这里就会重放
  writeFileSync(f, `${s11Lines.join('\n')}\n`)
  await sleep(800)
  check('S13 after a restart, rewriting already-delivered lines stays silent',
    sent.length === before, `messages=${sent.length - before}`)
  const rescanLine = ledger().filter(l => / rescan /.test(l)).at(-1) ?? ''
  check('S13 ledger records the post-restart rescan with deliver=0',
    /rescan lines=3 dup=3 skipped=0 deliver=0 /.test(rescanLine), rescanLine.trim())
  await shutdown()
}

// ── M46：跳过留痕 / 注册清痕 / 继承的 TEAM_STATE_DIR 不许指向别的项目 ──────────────────
// 事故（2026-09-20）：other_project 的 PM 加载的是旧扩展，按继承的 TEAM_* 解到 this-project，
// 用 this-project 的会话名算出期望 target 与真实会话不符 → 每 2 秒 skip setup 一次，痕迹全写进
// **别人的** state，而投递已经静默退回输入框粘贴路径（draft-raced-left + 两条消息滞留）。
// 这三条钉住修复后的契约：① 跳过的原因留在**本项目**；② 成功注册会把旧痕迹删掉；
// ③ 继承的 TEAM_STATE_DIR 指向别的项目时一律拒绝（M40 的 state 面）。
const skipFiles = () => (existsSync(WATCH_DIR) ? readdirSync(WATCH_DIR).filter(f => f.endsWith('.skip')) : [])
const cliPath = join(SKILL_DIR, 'scripts/team')
{
  await shutdown()
  const savedOverride = process.env.TEAM_INBOX_WATCH_TARGET
  const savedState = process.env.TEAM_STATE_DIR

  // ── S14：会话名不符（配置说 m30s，target 指向 other-project）→ 本项目 state 里的 skip 记录
  // 注意：TEAM_INBOX_WATCH_TARGET 只改「从哪读 target」，不改「哪个会话是本项目的」——所以这条
  // 显式覆盖同样会被拒（bun 会缓存启动时的 PATH，夹具不能靠 PATH 假 tmux 来造这个形状）。
  process.env.TEAM_INBOX_WATCH_TARGET = 'other-project:pm'
  await sessionStart()
  const skips = skipFiles()
  check('M46-S14 a session-name mismatch leaves exactly one .skip record', skips.length === 1, `skips=${skips.length}`)
  const skipText = skips.length ? readFileSync(join(WATCH_DIR, skips[0]), 'utf8') : ''
  for (const [field, want] of [['session', 'other-project'], ['window', 'pm'], ['expect', 'm30s'], ['reason', 'session-mismatch'], ['pid', String(process.pid)], ['cwd', ROOT]]) {
    check(`M46-S14 the skip record carries ${field}=${want}`, new RegExp(`^${field}=${want}$`, 'm').test(skipText), skipText.replace(/\n/g, ' | '))
  }
  check('M46-S14 the skip record lives in the cwd-derived project state dir',
    skips.length === 1 && existsSync(join(WATCH_DIR, skips[0])), `watch=${WATCH_DIR}`)
  check('M46-S14 a foreign session is not registered', regs().length === 0, `regs=${regs().length}`)
  check('M46-S14 the ledger still records the skip reason',
    ledger().some(l => /skip setup: session other-project != m30s/.test(l)), ledger().at(-1) || '(no ledger)')
  // 端到端：真 CLI 读这条痕迹 → status 报降级（不是只有日志里有）
  {
    let out = ''
    try {
      out = execFileSync('bash', ['-c', 'bash "$1" status 2>&1', 'bash', cliPath], {
        cwd: ROOT, encoding: 'utf8', timeout: 20000,
        env: { ...process.env, TEAM_ROOT: ROOT },
      })
    } catch (error) { out = `${String(error?.stdout ?? '')}${String(error?.stderr ?? '')}` }
    check('M46-S14 the real CLI reports the delivery degradation in `team status`',
      /投递通道降级/.test(out) && /会话名不符/.test(out),
      out.trim().split('\n').filter(l => /降级/.test(l)).join(' | ') || out.trim().split('\n').at(-1) || '')
  }
  await shutdown()

  // ── S15：成功注册会删掉同 target 的旧 .skip（痕迹不许一直骗人）
  process.env.TEAM_INBOX_WATCH_TARGET = 'm30s:pm'
  mkdirSync(WATCH_DIR, { recursive: true })
  writeFileSync(join(WATCH_DIR, 'stale-skip.skip'),
    `version=1\ntarget=m30s:pm\nkey=stale-skip\nreason=session-mismatch\ndetail=x\npid=${process.pid}\ncwd=${ROOT}\n`)
  await sessionStart()
  check('M46-S15 a successful registration clears the stale .skip for its target',
    !existsSync(join(WATCH_DIR, 'stale-skip.skip')), `skips=${skipFiles().length}`)
  check('M46-S15 the registration itself exists', regs().length === 1, `regs=${regs().length}`)
  await shutdown()

  // ── S16：继承的 TEAM_STATE_DIR 指向**另一个项目**的 state → 拒绝，写本项目
  const OTHER = join(TMP, 'other-project')
  mkdirSync(join(OTHER, '.pi/team'), { recursive: true })
  writeFileSync(join(OTHER, '.pi/team/config.sh'), 'TEAM_PROJECT="other-project"\nTEAM_SESSION="m30s"\n')
  process.env.TEAM_STATE_DIR = join(OTHER, '.pi/team/state')
  await sessionStart()
  check('M46-S16 an inherited TEAM_STATE_DIR pointing at another project is refused',
    regs().length === 1 && !existsSync(join(OTHER, '.pi/team/state/inbox-watch')),
    `regs=${regs().length} other=${existsSync(join(OTHER, '.pi/team/state/inbox-watch'))}`)
  check('M46-S16 the refusal is recorded in the cwd-derived ledger',
    ledger().some(l => /TEAM_IDENTITY_CONFLICT inherited TEAM_STATE_DIR=/.test(l)), ledger().at(-1) || '(no ledger)')
  await sessionStart()   // 幂等：第二次也不再往别处写
  check('M46-S16 repeated setup still writes only to the derived project',
    !existsSync(join(OTHER, '.pi/team/state/inbox-watch')), `other=${existsSync(join(OTHER, '.pi/team/state/inbox-watch'))}`)
  await shutdown()

  // ── S17：继承的 TEAM_CONFIG_FILE 指向**另一个项目** → 忽略（期望会话名必须来自本项目配置）
  delete process.env.TEAM_STATE_DIR
  const savedCfg = process.env.TEAM_CONFIG_FILE
  writeFileSync(join(OTHER, '.pi/team/config.sh'), 'TEAM_PROJECT="other-project"\nTEAM_SESSION="other-project"\n')
  process.env.TEAM_CONFIG_FILE = join(OTHER, '.pi/team/config.sh')
  await sessionStart()   // target m30s:pm = 本项目配置的会话；外来配置说是 other-project
  check('M46-S17 an inherited TEAM_CONFIG_FILE pointing at another project is ignored',
    regs().length === 1 && skipFiles().length === 0,
    `regs=${regs().length} skips=${skipFiles().length}`)
  check('M46-S17 the refusal is recorded in the cwd-derived ledger',
    ledger().some(l => /TEAM_IDENTITY_CONFLICT inherited TEAM_CONFIG_FILE=/.test(l)), ledger().at(-1) || '(no ledger)')
  if (savedCfg === undefined) delete process.env.TEAM_CONFIG_FILE; else process.env.TEAM_CONFIG_FILE = savedCfg
  await shutdown()

  // 还原环境：后面的用例（与反向守卫）走原来的状态
  if (savedOverride === undefined) delete process.env.TEAM_INBOX_WATCH_TARGET; else process.env.TEAM_INBOX_WATCH_TARGET = savedOverride
  if (savedState === undefined) delete process.env.TEAM_STATE_DIR; else process.env.TEAM_STATE_DIR = savedState
  for (const f of skipFiles()) { try { rmSync(join(WATCH_DIR, f), { force: true }) } catch { /* ignore */ } }
}

// ── S18：字节裁切的 spool 行不再把 offset 推过文件末尾（P28/R1 · D2）────────────────────────
// 事故（2026-09-20 06:42）：outbox.sh 的 `LC_ALL=C cut -c1-700` 把预览裁在多字节字符中间 →
// spool 行不是合法 UTF-8；旧 readNewLines 用 `Buffer.byteLength(解码结果)` 算 advance
// （每个 U+FFFD 量成 3 字节）→ `baseline=19635` 落在 19634 字节的文件上 → 每拍都像外部缩容。
{
  await shutdown()
  process.env.TEAM_INBOX_WATCH_POLL_MS = '100'   // 三拍空闲：这一段要看账本有没有动
  mkdirSync(WATCH_DIR, { recursive: true })
  const f = spoolFile()
  const clipped = Buffer.from(`xy${'红'.repeat(300)}`, 'utf8').subarray(0, 700)   // 700 字节落在“红”中间
  appendWakeRaw(Buffer.concat([
    Buffer.from(`${Date.now()}\tknock\tpm\tpm\t`, 'utf8'), clipped, Buffer.from('\n'),
  ]))
  const size = statSync(f).size
  let valid = true
  try { execFileSync('iconv', ['-f', 'UTF-8', '-t', 'UTF-8'], { input: clipped, stdio: ['pipe', 'ignore', 'ignore'] }) } catch { valid = false }
  check('S18 precondition: the clipped preview is not valid UTF-8 (the incident trigger)', !valid && clipped.length === 700, `bytes=${clipped.length}`)
  const shrinkBefore = ledgerMatches(/spool shrink/)
  const before = sent.length
  await sessionStart()
  const started = ledger().filter(l => / started target=/.test(l)).at(-1) ?? ''
  check('S18 the baseline is the spool byte size (no U+FFFD skew)', started.includes(`baseline=${size}`), `${started.trim()} (size=${size})`)
  const regNow = regs()[0]
  const regPath = regNow ? join(WATCH_DIR, regNow) : ''
  const hb0 = regPath ? statSync(regPath).mtimeMs : 0
  await sleep(400)
  // 心跳前进 = 定时器真的在跑：空闲断言不是「压根没拍」（POLL_MS 低于 envNum 下限会被拒）
  const hbMoved = regPath ? statSync(regPath).mtimeMs > hb0 : false
  check('S18 idle ticks after a byte-clipped line add no spool shrink',
    hbMoved && ledgerMatches(/spool shrink/) === shrinkBefore,
    `timers-alive=${hbMoved} shrink lines ${shrinkBefore} -> ${ledgerMatches(/spool shrink/)}`)
  check('S18 the byte-clipped line stays in the baseline (no wake for it)', sent.length === before, `messages=${sent.length - before}`)
  appendWake('say', 'pm', 'pm', 'after-clipped-line')
  const woke = await waitFor(() => sent.length > before)
  check('S18 the next line after a byte-clipped line wakes exactly once', woke && sent.length === before + 1,
    `messages=${sent.length - before}`)
  check('S18 the wake preview is the appended line, byte-complete (no leading fragment)', lastText().includes('after-clipped-line'),
    lastText().replace(/\n/g, ' | '))
  check('S18 total grows by exactly one (the clipped baseline line never counts)', lastTotal() === 1, `total=${lastTotal()}`)
  await shutdown()
}

// ── S19：回退要有证据，恢复要收敛（P28/R2 · D3+D4）────────────────────────────────────
// 判据：同一头部的小回退 = 我们自己的 offset 算错了（修复，不重扫、不唤醒）；头部变了 = 真重写
// （一次有界重扫，下一拍收敛）；同一 (size, head) 不重扫第二次。
{
  process.env.TEAM_INBOX_WATCH_POLL_MS = '100'
  await sessionStart()
  const f = spoolFile()

  // (a) 末字节被删、头部不变 → 一次 offset clamp；clamp 落在行中，下一次读取的碎片被 resync 吸收
  const sizeFull = statSync(f).size
  const clampA = ledgerMatches(/offset clamp/)
  const shrinkA = ledgerMatches(/spool shrink/)
  const rescanA = ledgerMatches(/ rescan lines=/)
  const wakesA = sent.length
  writeFileSync(f, readFileSync(f).subarray(0, sizeFull - 1))
  const clamped = await waitFor(() => ledgerMatches(/offset clamp/) > clampA, 2000)
  check('S19a a one-byte regression with an unchanged head is repaired with one offset clamp',
    clamped && ledgerMatches(/offset clamp/) === clampA + 1 && ledgerMatches(/spool shrink/) === shrinkA,
    ledger().filter(l => /offset clamp|spool shrink/.test(l)).at(-1) ?? '(no clamp line)')
  check('S19a the clamp is recorded with head=same (auditable repair)',
    /offset clamp from=\d+ to=\d+ head=same/.test(ledger().filter(l => /offset clamp/.test(l)).at(-1) ?? ''),
    ledger().filter(l => /offset clamp/.test(l)).at(-1) ?? '')
  check('S19a the clamp neither rescans nor wakes',
    ledgerMatches(/ rescan lines=/) === rescanA && sent.length === wakesA,
    `rescans=${ledgerMatches(/ rescan lines=/)} messages=${sent.length - wakesA}`)
  const resyncA = ledgerMatches(/offset resync/)
  appendWake('say', 'pm', 'pm', 'fragment-joined-to-the-clamped-line')
  const resynced = await waitFor(() => ledgerMatches(/offset resync/) > resyncA, 2000)
  check('S19a the read that starts inside the clamped line resyncs instead of delivering a fragment',
    resynced && ledgerMatches(/offset resync/) === resyncA + 1 && sent.length === wakesA,
    ledger().filter(l => /offset resync/.test(l)).at(-1) ?? '(no resync line)')
  check('S19a the resync records the skipped byte count (one line per action)',
    /offset resync skipped=\d+ /.test(ledger().filter(l => /offset resync/.test(l)).at(-1) ?? ''),
    ledger().filter(l => /offset resync/.test(l)).at(-1) ?? '')
  appendWake('say', 'pm', 'pm', 'clean-line-after-resync')
  const wokeA = await waitFor(() => sent.length > wakesA, 3000)
  check('S19a a line appended after the resync wakes exactly once',
    wokeA && sent.length === wakesA + 1 && lastText().includes('clean-line-after-resync'),
    `messages=${sent.length - wakesA}`)
  check('S19a the fragment itself never appears in a wake', !lastText().includes('fragment-joined-to-the-clamped-line'),
    lastText().replace(/\n/g, ' | '))

  // (b) 头部变了、文件变短 → 一次 spool shrink + 一次 rescan，下一拍什么都不加
  const sizeB = statSync(f).size
  const shrinkB = ledgerMatches(/spool shrink/)
  const rescanB = ledgerMatches(/ rescan lines=/)
  const wakesB = sent.length
  const ts = Date.now()
  const rewritten = Buffer.from([1, 2, 3].map(i => `${ts}\tsay\tdev\tpm\trewrite-fresh-${i}`).join('\n') + '\n')
  const headNow = readFileSync(f).subarray(0, 16)
  check('S19b precondition: the rewrite is shorter than the offset and its head differs',
    rewritten.length < sizeB && !headNow.equals(rewritten.subarray(0, 16)), `${rewritten.length} < ${sizeB}`)
  writeFileSync(f, rewritten)
  const rescanned = await waitFor(() => ledgerMatches(/ rescan lines=/) > rescanB, 2000)
  check('S19b a rewrite with a changed head is rescanned exactly once',
    rescanned && ledgerMatches(/spool shrink/) === shrinkB + 1 && ledgerMatches(/ rescan lines=/) === rescanB + 1,
    ledger().filter(l => /rescan lines=/.test(l)).at(-1) ?? '(no rescan line)')
  check('S19b the rescan delivers the rewritten content',
    sent.length === wakesB + 1 && lastText().includes('rewrite-fresh-3'), `messages=${sent.length - wakesB}`)
  await sleep(400)
  check('S19b the next tick adds nothing (converged)',
    ledgerMatches(/spool shrink/) === shrinkB + 1 && ledgerMatches(/ rescan lines=/) === rescanB + 1 && sent.length === wakesB + 1,
    `shrink=${ledgerMatches(/spool shrink/)} rescan=${ledgerMatches(/ rescan lines=/)} messages=${sent.length - wakesB}`)

  // (c) 同一 (size, head) 不再重扫第二次：先制造事件（clamp 到行中），再用一次 resync 推进
  //     offset（不投递任何行 → 事件记忆保留），然后把文件截回同一 (size, head)——回归 201 字节 > clamp 上限，
  //     没有 repeat 守卫就会重扫第二次。
  const sizeC = statSync(f).size
  const clampC = ledgerMatches(/offset clamp/)
  const shrinkC = ledgerMatches(/spool shrink/)
  const rescanC = ledgerMatches(/ rescan lines=/)
  const repeatsC = ledgerMatches(/shrink repeat/)
  const wakesC = sent.length
  writeFileSync(f, readFileSync(f).subarray(0, sizeC - 1))
  const clampedC = await waitFor(() => ledgerMatches(/offset clamp/) > clampC, 2000)
  check('S19c (setup) the clamp into the middle of a line is recorded once',
    clampedC && ledgerMatches(/offset clamp/) === clampC + 1 && sent.length === wakesC,
    ledger().filter(l => /offset clamp/.test(l)).at(-1) ?? '(no clamp line)')
  const resyncC = ledgerMatches(/offset resync/)
  appendWakeRaw(Buffer.from(`${'F'.repeat(200)}\n`))   // 200 字节碎片 + 换行：整段被跳过，不投递
  const resyncedC = await waitFor(() => ledgerMatches(/offset resync/) > resyncC, 2000)
  check('S19c (setup) the restored fragment is skipped as a resync (no line is delivered)',
    resyncedC && ledgerMatches(/offset resync/) === resyncC + 1 && sent.length === wakesC,
    ledger().filter(l => /offset resync/.test(l)).at(-1) ?? '(no resync line)')
  writeFileSync(f, readFileSync(f).subarray(0, sizeC - 1))   // 截回同一 (size, head)：回归 201 > 64
  const repeated = await waitFor(() => ledgerMatches(/shrink repeat/) > repeatsC, 2000)
  check('S19c the same (size, head) is recorded as a repeat and clamped, not rescanned twice',
    repeated && ledgerMatches(/shrink repeat/) === repeatsC + 1 && ledgerMatches(/ rescan lines=/) === rescanC
      && ledgerMatches(/spool shrink/) === shrinkC && sent.length === wakesC,
    ledger().filter(l => /shrink repeat/.test(l)).at(-1) ?? '(no repeat line)')
  check('S19c the repeat line names the state and the action',
    /shrink repeat size=\d+ head=fnv[0-9a-f]+ action=clamp/.test(ledger().filter(l => /shrink repeat/.test(l)).at(-1) ?? ''),
    ledger().filter(l => /shrink repeat/.test(l)).at(-1) ?? '')
  await shutdown()
}

// ── S20：只有新鲜行唤醒；过期行只计数、不投递、不丢字节（P28/R3 · D5）────────────────────
// 判据是行自带的 `team_epoch_ms`（第一个字段）：不看 mtime，也不看 .seen 的顺序。
{
  process.env.TEAM_INBOX_WATCH_POLL_MS = '100'
  await sessionStart()
  const f = spoolFile()
  // (a) 一小时前的未投递行（不在 .seen）+ 它的 durable 收件箱行 → 重扫里 stale=1、deliver=0、不唤醒
  const inboxFile = join(ROOT, 'docs/team/inbox/pm.md')
  mkdirSync(join(ROOT, 'docs/team/inbox'), { recursive: true })
  appendFileSync(inboxFile, '\n- [knock] S20 stale line body\n')
  const staleLine = `${Date.now() - 3600_000}\tknock\tpm\tpm\tS20-stale-line`
  const rescanA = ledgerMatches(/ rescan lines=/)
  const totalA = lastTotal()
  const wakesA = sent.length
  writeFileSync(f, `${staleLine}\n`)
  const rescanned = await waitFor(() => ledgerMatches(/ rescan lines=/) > rescanA, 2000)
  check('S20a an hour-old unseen line is rescan-counted, never woken about',
    rescanned && /rescan lines=1 dup=0 skipped=0 deliver=0 stale=1 /.test(ledger().filter(l => /rescan lines=/.test(l)).at(-1) ?? ''),
    ledger().filter(l => /rescan lines=/.test(l)).at(-1) ?? '(no rescan line)')
  check('S20a a stale-only recovery moves neither the wake count nor total',
    sent.length === wakesA && lastTotal() === totalA,
    `messages=${sent.length - wakesA} total=${totalA}->${lastTotal()}`)
  check('S20a the durable inbox copy is still there and the spool keeps the bytes',
    readFileSync(inboxFile, 'utf8').includes('S20 stale line body') && readFileSync(f, 'utf8').includes('S20-stale-line'),
    `spool=${statSync(f).size}B`)
  // (b) 紧跟一条新行 → 只叫这一条一次，total +1
  appendWake('say', 'pm', 'pm', 'S20-fresh-after-stale')
  const wokeB = await waitFor(() => sent.length > wakesA, 3000)
  check('S20b a fresh line after a stale one still wakes exactly once',
    wokeB && sent.length === wakesA + 1 && lastText().includes('S20-fresh-after-stale') && !lastText().includes('S20-stale-line'),
    `messages=${sent.length - wakesA}`)
  check('S20b total grows by exactly one', lastTotal() === totalA + 1, `${totalA} -> ${lastTotal()}`)
  // (c) 时间戳读不出来的行照样投（不静默吞），并计数 unparsable=1
  const wakesC = sent.length
  appendWakeRaw(Buffer.from('zzz\tsay\tpm\tpm\tS20-unparsable-line\n'))
  const wokeC = await waitFor(() => sent.length > wakesC, 3000)
  check('S20c a line whose timestamp is not a number is delivered (never swallowed)',
    wokeC && sent.length === wakesC + 1 && lastText().includes('S20-unparsable-line'), `messages=${sent.length - wakesC}`)
  check('S20c the ledger counts it as unparsable=1', ledgerMatches(/unparsable=1/) >= 1,
    ledger().filter(l => /unparsable=1/.test(l)).at(-1) ?? '(no classify line)')
  // (d) 普通路径（不是重扫）上的过期行同样不唤醒、但要计数
  const wakesD = sent.length
  appendWakeRaw(Buffer.from(`${Date.now() - 7200_000}\tsay\tpm\tpm\tS20-stale-normal-path\n`))
  await sleep(500)
  check('S20d a stale line on the ordinary path stays silent but is counted',
    sent.length === wakesD && ledgerMatches(/classify stale=1/) >= 1,
    ledger().filter(l => /classify /.test(l)).at(-1) ?? '(no classify line)')
  await shutdown()
}

// ── S21：账本把新流量与恢复分开（P28/R4 · D6）──────────────────────────────────────────
// 操作员要能一眼看出「这次唤醒是新消息还是恢复」：`total=` 只随真投递增长，rescan 有自己的分解。
{
  process.env.TEAM_INBOX_WATCH_POLL_MS = '100'
  await sessionStart()
  const f = spoolFile()
  // (a) 先投递三条真新行（从 spool 尾取回它们的真实字节），再把这批**已投递**行重写回 spool
  //     → deliver=0 + dup>0、total 不动、无唤醒
  const bPick = sent.length
  for (const n of [1, 2, 3]) appendWake('knock', 'dev', 'pm', `S21a-delivered-${n}`)
  await waitFor(() => sent.length > bPick)
  await sleep(300)
  const picked = readFileSync(f, 'utf8').trimEnd().split('\n').slice(-3)
  const rescanA = ledgerMatches(/ rescan lines=/)
  const shrinkA = ledgerMatches(/spool shrink/)
  const totalA = lastTotal()
  const wakesA = sent.length
  const sizeA = statSync(f).size
  const rewriteA = Buffer.from(`${picked.join('\n')}\n`)
  check('S21a precondition: a rewrite built from delivered lines, smaller, with a different head',
    picked.length >= 2 && rewriteA.length < sizeA && !readFileSync(f).subarray(0, 16).equals(rewriteA.subarray(0, 16)),
    `picked=${picked.length} ${rewriteA.length} < ${sizeA}`)
  writeFileSync(f, rewriteA)
  const rescannedA = await waitFor(() => ledgerMatches(/ rescan lines=/) > rescanA, 2000)
  check('S21a a dedup-only rescan reads deliver=0 with a non-zero dup and moves nothing',
    rescannedA && new RegExp(`rescan lines=${picked.length} dup=${picked.length} skipped=0 deliver=0 `).test(ledger().filter(l => /rescan lines=/.test(l)).at(-1) ?? '')
      && sent.length === wakesA && lastTotal() === totalA,
    ledger().filter(l => /rescan lines=/.test(l)).at(-1) ?? '(no rescan line)')
  // (b) 只含过期行的重写 → deliver=0 stale=<n>、total 不动、无唤醒
  const rescanB = ledgerMatches(/ rescan lines=/)
  const totalB = lastTotal()
  const wakesB = sent.length
  const staleA = `${Date.now() - 3600_000}\tknock\tpm\tpm\tS21-stale-a`
  const staleB = `${Date.now() - 7200_000}\tknock\tpm\tpm\tS21-stale-b`
  const rewriteB = Buffer.from(`${staleA}\n${staleB}\n`)
  check('S21b precondition: a stale-only rewrite, smaller, with a different head',
    rewriteB.length < statSync(f).size && !readFileSync(f).subarray(0, 16).equals(rewriteB.subarray(0, 16)),
    `${rewriteB.length} < ${statSync(f).size}`)
  writeFileSync(f, rewriteB)
  const rescannedB = await waitFor(() => ledgerMatches(/ rescan lines=/) > rescanB, 2000)
  check('S21b a stale-only rescan reads deliver=0 with stale=<n> and moves nothing',
    rescannedB && /rescan lines=2 dup=0 skipped=0 deliver=0 stale=2 /.test(ledger().filter(l => /rescan lines=/.test(l)).at(-1) ?? '')
      && sent.length === wakesB && lastTotal() === totalB,
    ledger().filter(l => /rescan lines=/.test(l)).at(-1) ?? '(no rescan line)')
  // (c) 两条新鲜行合并成一条唤醒 → wake n=2、total +2
  const totalC = lastTotal()
  const wakesC = sent.length
  appendWake('say', 'pm', 'pm', 'S21-fresh-a')
  appendWake('say', 'pm', 'pm', 'S21-fresh-b')
  const wokeC = await waitFor(() => sent.length > wakesC, 3000)
  check('S21c a real delivery is one wake naming both lines',
    wokeC && sent.length === wakesC + 1 && lastText().includes('S21-fresh-a') && lastText().includes('S21-fresh-b'),
    `messages=${sent.length - wakesC}`)
  check('S21c the wake line reads n=2 and total grows by exactly two',
    ledgerMatches(/wake n=2 /) >= 1 && lastTotal() === totalC + 2,
    `total=${totalC}->${lastTotal()} ${ledger().filter(l => / wake n=/.test(l)).at(-1) ?? ''}`)
  await shutdown()
}

// ── S22–S24（M53）：注册失败被记录、轮询兜底被证明、记录随生命周期收敛 ─────────────────
// 事故（2026-09-21）：宿主 inotify 配额耗尽 → 扩展静默丢掉 errno 与配额，而 `.reg` 还在 →
// doctor 把「只剩轮询」的通道报成健康。三条契约：① 失败带 errno/额度/轮询间隔，落一条耐久记录；
// ② 轮询兜底仍投递一次且不改变消息形状；③ 记录只活到「成功注册」或「干净退出」。
const degradedFiles = () => (existsSync(WATCH_DIR) ? readdirSync(WATCH_DIR).filter(f => f.endsWith('.degraded')) : [])
{
  await shutdown()
  await sleep(150)
  process.env.TEAM_INBOX_WATCH_POLL_MS = '200'
  process.env.TEAM_INBOX_WATCH_FORCE_FAIL = 'ENOSPC'
  const beforeNotify = sent.length
  await sessionStart()

  // S22 —— 失败的两条痕迹都要自解释；`.reg` 必须留着（发送方的路由绝不因降级改道）
  const failLine = ledger().filter(l => /watch unavailable/.test(l)).at(-1) ?? ''
  check('S22 the failure line names errno, watches, poll_ms and fallback=polling',
    /watch unavailable: errno=ENOSPC watches=([0-9]+|unknown)\/([0-9]+|unknown) poll_ms=200 fallback=polling forced=1$/.test(failLine),
    failLine.trim() || '(no failure line)')
  check('S22 the failure line marks the fixture-caused fault as forced=1', /\bforced=1$/.test(failLine), failLine.trim())
  const deg = degradedFiles()
  check('S22 a degraded record is written (exactly one)', deg.length === 1, `records=${deg.length}`)
  const degText = deg.length ? readFileSync(join(WATCH_DIR, deg[0]), 'utf8') : ''
  for (const [field, want] of [
    ['version', '1'], ['target', 'm30s:pm'], ['reason', 'watch-unavailable'], ['errno', 'ENOSPC'],
    ['poll_ms', '200'], ['forced', '1'], ['pid', String(process.pid)], ['cwd', ROOT],
  ]) {
    check(`S22 the record carries ${field}=${want}`, new RegExp(`^${field}=${want}$`, 'm').test(degText), degText.replace(/\n/g, ' | '))
  }
  check('S22 the record carries watches=<used>/<max>',
    /^watches=([0-9]+|unknown)\/([0-9]+|unknown)$/m.test(degText), degText.replace(/\n/g, ' | '))
  check('S22 a degraded watcher does not lose the registration (.reg is still there)',
    regs().length === 1, `regs=${regs().length}`)
  // 真 CLI 的 route 助手仍从 .reg 解出 target → 走 pi 通道（降级不把发送方推回粘贴慢路径）
  const m53Summary = join(TMP, 'summary-dev-M53.md')
  writeFileSync(m53Summary, 'M53-S22: a degraded watcher keeps the spool route')
  let notifyOut = ''
  try {
    notifyOut = execFileSync('bash', [join(SKILL_DIR, 'scripts/team'), 'notify', 'pm', '--from-file', m53Summary], {
      cwd: ROOT, encoding: 'utf8', timeout: 20000,
      env: { ...process.env, TEAM_ROOT: ROOT, TEAM_NOTIFY_TMUX: '1' },
    })
  } catch (error) { notifyOut = `${String(error?.stdout ?? '')}${String(error?.stderr ?? '')}` }
  check('S22 the real route helper still resolves the target from .reg (pi channel, never the paste path)',
    /pi 监视通道/.test(notifyOut), notifyOut.trim().split('\n').at(-1) ?? '')
  await waitFor(() => sent.length > beforeNotify, 1500)   // 先把通知那一拍投完，S23 才是干净的一行一次

  // S23 —— 兜底是「被证明的保证」：强制失败 + 秒级轮询，一条新 spool 行在一个周期内唤醒一次
  const beforeWake = sent.length
  appendWake('say', 'pm', 'pm', `S23-POLL-FALLBACK-${'Z'.repeat(200)}S23-TAIL-MARKER`)
  const woke = await waitFor(() => sent.length > beforeWake, 600)
  await sleep(300)
  check('S23 a forced-failure session still wakes within one poll interval (200 ms)',
    woke && sent.length === beforeWake + 1, `messages=${sent.length - beforeWake}`)
  const fallbackWake = sent.at(-1)
  check('S23 the fallback wake keeps the live-watcher shape (customType/triggerTurn/followUp)',
    fallbackWake?.msg?.customType === 'team-inbox' && fallbackWake?.opts?.triggerTurn === true
      && fallbackWake?.opts?.deliverAs === 'followUp',
    JSON.stringify({ customType: fallbackWake?.msg?.customType, ...(fallbackWake?.opts ?? {}) }))
  const fallbackBody = lastText()
  check('S23 the fallback wake points at the inbox and truncates the payload',
    fallbackBody.includes('docs/team/inbox/pm.md') && fallbackBody.includes('S23-POLL-FALLBACK-')
      && !fallbackBody.includes('S23-TAIL-MARKER'), fallbackBody.replace(/\n/g, ' | '))
  check('S23 the ledger records the fallback delivery as one wake',
    /wake n=1 /.test(ledger().filter(l => / wake n=/.test(l)).at(-1) ?? ''), ledger().at(-1) ?? '')

  // S24 —— 生命周期：干净退出删记录；真注册成功也删旧记录
  await shutdown()
  check('S24 a clean shutdown removes the degraded record', degradedFiles().length === 0, `records=${degradedFiles().length}`)
  delete process.env.TEAM_INBOX_WATCH_FORCE_FAIL
  mkdirSync(WATCH_DIR, { recursive: true })
  writeFileSync(join(WATCH_DIR, 'stale-m53.degraded'),
    `version=1\ntarget=m30s:pm\nkey=stale-m53\nreason=watch-unavailable\nerrno=ENOSPC\nwatches=1/2\n` +
    `poll_ms=5000\nforced=0\nsince=x\npid=${process.pid}\ncwd=${ROOT}\nheartbeat=${Math.floor(Date.now() / 1000)}\n`)
  await sessionStart()
  check('S24 a healthy session writes no degraded record', degradedFiles().length === 0, `records=${degradedFiles().length}`)
  check('S24 a successful registration clears a stale degraded record',
    !existsSync(join(WATCH_DIR, 'stale-m53.degraded')), `records=${degradedFiles().length}`)
  await shutdown()
  process.env.TEAM_INBOX_WATCH_POLL_MS = '3600000'
}

// ═══════════════════════════════════════════════════════════════════════════════
// P81 · wake-delivery-idempotence：投递日志 / 至多一次 / fail-closed / 源行点名
// 事故：一条 nudge 让 PM 在一个多小时里被「同一条」叫醒三次，而 durable 文件回答不了
// 「到底投过没有」。契约：唤醒是 at-most-once（门铃），durable 收件箱行是 exactly-once（消息）。
// 每个断言都指向**文件**（日志 / 账本），不读实现内部状态；本节用 100ms 轮询，不依赖 fs.watch。
// ═══════════════════════════════════════════════════════════════════════════════
process.env.TEAM_INBOX_WATCH_POLL_MS = '100'

// ── S25j：日志形状与写前顺序（start → read → intent → sent）；过期行不写记录（1.1）────
if (only('S25j')) {
  await resetState()
  await sessionStart()
  const f = spoolFile()
  appendWake('say', 'pm', 'pm', 'S25j-fresh-line')
  const woke = await waitFor(() => journalOf('sent').length > 0)
  const recs = journalLines().map(jrec).filter(Boolean)
  check('S25j the journal is start → read → intent → sent, one record per line',
    woke && recs.map(r => r.kind).join(',') === 'start,read,intent,sent', recs.map(r => r.kind).join(','))
  const read = recs.find(r => r.kind === 'read')
  const rawLine = spoolLines().find(l => l.includes('S25j-fresh-line')) ?? ''
  const size = statSync(f).size
  check('S25j the read record carries the line identity and the wake material',
    read && read.fields.id === identityOf(rawLine) && read.fields.kind === 'say' && read.fields.from === 'pm'
      && read.fields.durable === 'pm' && read.fields.preview === 'S25j-fresh-line' && Number(read.fields.src) > 0,
    read ? JSON.stringify(read.fields) : '(no read record)')
  check('S25j the read record carries the offset/size/head fingerprint',
    read && read.fields.off === String(size) && read.fields.size === String(size) && /^(fnv[0-9a-f]+|empty|absent)$/.test(read.fields.head),
    read ? `off=${read.fields.off} size=${read.fields.size} head=${read.fields.head}` : '(no read record)')
  check('S25j the batch is closed by intent then sent with the same seq',
    recs.some(r => r.kind === 'intent' && r.fields.seq === read?.fields.seq)
      && recs.some(r => r.kind === 'sent' && r.fields.seq === read?.fields.seq),
    recs.map(r => `${r.kind}${r.fields.seq ? `=${r.fields.seq}` : ''}`).join(' '))
  check('S25j every record is ISO-stamped', recs.every(r => /^\d{4}-\d{2}-\d{2}T/.test(r.ts)), recs[0]?.ts ?? '')
  check('S25j the wake ledger line names seq and the identities',
    / wake n=1 total=1 inbox=pm kinds=say seq=1 ids=\S+$/.test(ledger().filter(l => / wake n=/.test(l)).at(-1) ?? ''),
    ledger().filter(l => / wake n=/.test(l)).at(-1) ?? '(no wake line)')
  // 过期行：不写日志记录、不唤醒、只计数
  const before = sent.length
  const recordsBefore = journalLines().length
  const totalBefore = lastTotal()
  appendWakeRaw(Buffer.from(`${Date.now() - 3600_000}\tsay\tpm\tpm\tS25j-stale-line\n`))
  // 等分类行真的出现再断言「没写记录、没唤醒」：不然慢机器上可能是「还没读到」的假绿
  const classified = await waitFor(() => ledgerMatches(/classify stale=1 unparsable=0/) >= 1, 3000)
  check('S25j a stale line writes no journal record and wakes nobody',
    classified && sent.length === before && journalLines().length === recordsBefore,
    `messages=${sent.length - before} records=${journalLines().length - recordsBefore}`)
  check('S25j the stale line is counted apart from total',
    ledgerMatches(/classify stale=1 unparsable=0/) >= 1 && lastTotal() === totalBefore,
    ledger().filter(l => /classify /.test(l)).at(-1) ?? '(no classify line)')
  await shutdown()
}

// ── S25g：启动核算 —— 没人看过的行只计数，基线契约不变（4.2）──────────────────────────
if (only('S25g')) {
  await resetState()
  appendWake('say', 'pm', 'pm', 'S25g-nobody-watched')
  const before = sent.length
  await sessionStart()
  const started = ledger().filter(l => / started target=/.test(l)).at(-1) ?? ''
  check('S25g startup accounting names the swallowed lines and keeps the baseline contract',
    /baseline swallowed n=1 /.test(ledger().filter(l => /baseline swallowed/.test(l)).at(-1) ?? '')
      && started.includes(`baseline=${statSync(spoolFile()).size}`),
    `${ledger().filter(l => /baseline swallowed/.test(l)).at(-1) ?? '(none)'} || ${started.trim()}`)
  await sleep(500)
  check('S25g a line written while nobody watched wakes nobody', sent.length === before, `messages=${sent.length - before}`)
  appendWake('say', 'pm', 'pm', 'S25g-after-start')
  const woke = await waitFor(() => sent.length > before)
  check('S25g a line after startup still wakes exactly once',
    woke && sent.length === before + 1 && lastText().includes('S25g-after-start'), `messages=${sent.length - before}`)
  await shutdown()
}

// ── S25r：恢复路径也受新鲜度约束 —— 已过期的恢复只计数、不唤醒（3.2 的 stale 半边）──
if (only('S25r')) {
  await resetState()
  mkdirSync(WATCH_DIR, { recursive: true })
  const oldTs = Date.now() - 3600_000
  const line = `${oldTs}\tsay\tpm\tpm\tS25r-recovered-but-stale`
  writeFileSync(spoolFile(), `${line}\n`)
  const lineBytes = Buffer.byteLength(line, 'utf8') + 1
  writeFileSync(journalPathOf(),
    `${new Date().toISOString()} start baseline=0 size=0 head=absent\n` +
    `${new Date().toISOString()} read seq=1 off=${lineBytes} size=${lineBytes} head=empty id=${jesc(identityOf(line))} src=${oldTs} kind=say from=pm durable=pm preview=S25r-recovered-but-stale\n`)
  const before = sent.length
  await sessionStart()
  check('S25r a recovered line past the horizon is counted stale, not woken',
    sent.length === before && ledgerMatches(/recovery candidates=1 fresh=0 stale=1 unparsable=0/) === 1
      && ledgerMatches(/recovery n=/) === 0,
    `${ledger().filter(l => /recovery /.test(l)).at(-1) ?? '(none)'} || messages=${sent.length - before}`)
  await sleep(400)
  check('S25r the stale recovery stays silent and total does not move',
    sent.length === before && lastTotal() === 0, `messages=${sent.length - before} total=${lastTotal()}`)
  await shutdown()
}

// ── S25z：注入旋钮是夹具专属；裸设无效、不杀会话、不留痕（3.1）────────────────────────
if (only('S25z')) {
  await resetState()
  process.env.TEAM_INBOX_WATCH_ABORT_AFTER = 'read'
  await sessionStart()
  check('S25z the abort knob without TEAM_SMOKE_FIXTURE=1 is printed as ignored',
    ledger().some(l => /fixture knob ignored: TEAM_INBOX_WATCH_ABORT_AFTER=read/.test(l)),
    ledger().filter(l => /fixture knob/.test(l)).at(-1) ?? '(no ignored line)')
  const before = sent.length
  appendWake('say', 'pm', 'pm', 'S25z-live-process')
  const woke = await waitFor(() => sent.length > before)
  check('S25z an ignored knob does not kill the session (the line is still delivered)',
    woke && sent.length === before + 1, `messages=${sent.length - before}`)
  const recs = journalOf('sent')
  check('S25z the delivery went through the journal as usual', recs.length === 1, `sent records=${recs.length}`)
  delete process.env.TEAM_INBOX_WATCH_ABORT_AFTER
  await shutdown()
}

// ── S25a：read 之后被杀 → 重启后**恰好一次**恢复（不是两次）（3.2）──────────────────
if (only('S25a')) {
  await resetState()
  const payload = `S25a-read-then-die-${Date.now()}`
  const r = runChild('read', payload)
  check('S25a the child is a real separate process killed at the injection point',
    r.status === null && r.signal === 'SIGKILL',
    `status=${r.status} signal=${r.signal} stderr=${String(r.stderr ?? '').trim().split('\n').at(-1) ?? ''}`)
  const recs = journalLines().map(jrec).filter(Boolean)
  check('S25a the child left a read record and no intent/sent',
    recs.some(x => x.kind === 'read') && !recs.some(x => x.kind === 'intent' || x.kind === 'sent'),
    recs.map(x => x.kind).join(','))
  check('S25a the durable spool line survived the crash', spoolLines().some(l => l.includes(payload)), `lines=${spoolLines().length}`)
  const before = sent.length
  await sessionStart()
  const woke = await waitFor(() => sent.length > before, 3000)
  check('S25a exactly one recovery wake is sent for the crashed line',
    woke && sent.length === before + 1, `messages=${sent.length - before}`)
  const wakeLine = ledger().filter(l => / wake n=/.test(l)).at(-1) ?? ''
  check('S25a the ledger records it as recovery with its seq',
    / wake n=1 total=1 inbox=pm kinds=say seq=\d+ ids=\S+ recovery n=1$/.test(wakeLine), wakeLine.trim())
  check('S25a the recovery is recorded in the journal as sent (at most once from now on)',
    journalOf('sent').length === 1, `sent records=${journalOf('sent').length}`)
  // 同一批字节再重写一次 —— **跨一次重启**（重启本身也不得再恢复）：证明至多一次是由日志
  // （不是内存）保证的
  await shutdown()
  const beforeR = sent.length
  await sessionStart()
  await sleep(400)
  check('S25a a restart after the recovery wakes nobody again (sent is terminal)',
    sent.length === beforeR, `messages=${sent.length - beforeR}`)
  const bytes = readFileSync(spoolFile())
  const rescan0 = ledgerMatches(/ rescan lines=/)
  const replay0 = ledgerMatches(/replay suppressed/)
  writeFileSync(spoolFile(), '')
  await waitFor(() => ledgerMatches(/ rescan lines=/) > rescan0, 3000)
  appendFileSync(spoolFile(), bytes)
  await waitFor(() => ledgerMatches(/replay suppressed/) > replay0, 3000)
  check('S25a a later rewrite of the same bytes produces no second wake',
    sent.length === beforeR && ledgerMatches(/replay suppressed/) > replay0,
    `messages=${sent.length - beforeR} replay=${ledgerMatches(/replay suppressed/)}`)
  await shutdown()
}

// ── S25b：intent 之后被杀 → 重启后零重投 + inflight assumed（3.3）────────────────────
if (only('S25b')) {
  await resetState()
  const inboxFile = join(ROOT, 'docs/team/inbox/pm.md')
  mkdirSync(join(ROOT, 'docs/team/inbox'), { recursive: true })
  appendFileSync(inboxFile, '\n- [say] S25b durable inbox line\n')
  const payload = `S25b-intent-then-die-${Date.now()}`
  const r = runChild('intent', payload)
  check('S25b the child is a real separate process killed at the intent injection point',
    r.status === null && r.signal === 'SIGKILL',
    `status=${r.status} signal=${r.signal} stderr=${String(r.stderr ?? '').trim().split('\n').at(-1) ?? ''}`)
  const recs = journalLines().map(jrec).filter(Boolean)
  check('S25b the child left a complete read+intent and no sent/failed',
    recs.filter(x => x.kind === 'read').length === 1 && recs.some(x => x.kind === 'intent')
      && !recs.some(x => x.kind === 'sent' || x.kind === 'failed'),
    recs.map(x => x.kind).join(','))
  // 证明权威是日志而不是 .seen：重启前删掉任何 .seen
  for (const n of readdirSync(WATCH_DIR).filter(x => x.endsWith('.seen'))) rmSync(join(WATCH_DIR, n), { force: true })
  const before = sent.length
  await sessionStart()
  await sleep(500)
  check('S25b the restart sends no wake at all', sent.length === before, `messages=${sent.length - before}`)
  check('S25b the ledger records exactly one inflight assumed n=1',
    ledger().filter(l => /inflight assumed n=1 /.test(l)).length === 1,
    ledger().filter(l => /inflight assumed/.test(l)).join(' | ') || '(none)')
  check('S25b the durable inbox line is still readable', readFileSync(inboxFile, 'utf8').includes('S25b durable inbox line'))
  check('S25b total did not move', lastTotal() === 0, `total=${lastTotal()}`)
  // 之后的重读同样沉默，total 也不动（先真的截断、让读者看见 shrink，再把字节写回）
  const bytes = readFileSync(spoolFile())
  const rescan0 = ledgerMatches(/ rescan lines=/)
  const replay0 = ledgerMatches(/replay suppressed/)
  writeFileSync(spoolFile(), '')
  await waitFor(() => ledgerMatches(/ rescan lines=/) > rescan0, 3000)
  appendFileSync(spoolFile(), bytes)
  await waitFor(() => ledgerMatches(/replay suppressed/) > replay0, 3000)
  check('S25b a later re-read of those bytes adds no wake and no total',
    sent.length === before && lastTotal() === 0 && ledgerMatches(/replay suppressed/) > replay0,
    `messages=${sent.length - before} total=${lastTotal()} replay=${ledgerMatches(/replay suppressed/)}`)
  await shutdown()
}

// ── S25c：API 拒绝可重试（每拍至多一次）；日志写不进去 = 一条都不发（1.2/1.3/1.4）──────
if (only('S25c')) {
  // (a) 抛出两次 → 下一拍重试 → 只产生一次唤醒
  await resetState()
  await sessionStart()
  hostFail = 2
  const before = sent.length
  appendWake('say', 'pm', 'pm', 'S25c-host-raises')
  const failed = await waitFor(() => ledgerMatches(/wake failed/) >= 2, 4000)
  check('S25c a raising message API is recorded as wake failed once per attempt',
    failed && ledgerMatches(/wake failed/) === 2, `failed=${ledgerMatches(/wake failed/)}`)
  check('S25c a failed send moves neither the wake count nor total',
    sent.length === before && lastTotal() === 0, `messages=${sent.length - before} total=${lastTotal()}`)
  check('S25c the failed batch left no sent record', journalOf('sent').length === 0, `sent=${journalOf('sent').length}`)
  const retried = await waitFor(() => sent.length > before, 4000)
  check('S25c the retry is the only wake that line ever produces',
    retried && sent.length === before + 1 && lastText().includes('S25c-host-raises'), `messages=${sent.length - before}`)
  check('S25c the retry closed the batch with sent', journalOf('sent').length === 1, `sent=${journalOf('sent').length}`)
  check('S25c total grew by exactly one after the retry', lastTotal() === 1, `total=${lastTotal()}`)
  await shutdown()

  // (b) 日志不可写（把 <key>.deliver 做成目录 → EISDIR）→ 零投递 + deliver blocked；恢复后恰好一次
  await resetState()
  await sessionStart()
  const df = journalPathOf()
  await shutdown()
  rmSync(df, { force: true })
  mkdirSync(df, { recursive: true })
  await sessionStart()
  check('S25c a session whose journal cannot be written records deliver blocked',
    ledgerMatches(/deliver blocked/) >= 1, ledger().filter(l => /deliver blocked/.test(l)).at(-1) ?? '(none)')
  const beforeB = sent.length
  appendWake('say', 'pm', 'pm', 'S25c-blocked-line')
  await sleep(600)
  check('S25c nothing is sent while the journal is unwritable',
    sent.length === beforeB && lastTotal() === 0, `messages=${sent.length - beforeB} total=${lastTotal()}`)
  rmSync(df, { recursive: true, force: true })
  const delivered = await waitFor(() => sent.length > beforeB, 4000)
  check('S25c the line is delivered exactly once when the journal becomes writable again',
    delivered && sent.length === beforeB + 1 && lastTotal() === 1, `messages=${sent.length - beforeB} total=${lastTotal()}`)
  check('S25c the line was never delivered while blocked (one wake, one sent record)',
    journalOf('sent').length === 1, `sent=${journalOf('sent').length}`)
  await shutdown()

  // (c) 过期即止：失败的行越过新鲜度地平线后不再重试、不唤醒、只计数
  //     （初始年龄 9s、地平线 10s —— 慢机器上第一拍也不会误判成过期；失败后把地平线降到 1s）
  await resetState()
  await sessionStart()
  process.env.TEAM_INBOX_WATCH_STALE_SEC = '10'
  hostFail = 1
  appendWakeRaw(Buffer.from(`${Date.now() - 9000}\tsay\tpm\tpm\tS25c-stale-retry\n`))
  const sawFail = await waitFor(() => ledgerMatches(/wake failed/) >= 1, 3000)
  process.env.TEAM_INBOX_WATCH_STALE_SEC = '1'   // 让下一拍时这一行已过期
  const beforeC = sent.length
  await waitFor(() => ledgerMatches(/retry stale=1/) >= 1, 3000)
  check('S25c a failed wake is not retried past the freshness horizon',
    sawFail && sent.length === beforeC && lastTotal() === 0, `messages=${sent.length - beforeC} total=${lastTotal()}`)
  check('S25c the skipped retry is counted as stale',
    ledgerMatches(/retry stale=1/) >= 1, ledger().filter(l => /retry /.test(l)).at(-1) ?? '(no retry line)')
  delete process.env.TEAM_INBOX_WATCH_STALE_SEC
  await shutdown()
}

// ── S25d：逐字相同的两条 payload 靠身份与源时间区分；重写不再唤醒（2.3）──────────────
if (only('S25d')) {
  await resetState()
  await sessionStart()
  const f = spoolFile()
  const before = sent.length
  const t1 = Date.now() - 2000
  const t2 = t1 + 1
  const text = '[pulse] 待办：未读通知 7 · 待复验 4'
  appendWakeAt(t1, 'nudge', 'pulse', '-', text)
  appendWakeAt(t2, 'nudge', 'pulse', '-', text)
  const woke = await waitFor(() => sent.length > before, 3000)
  const body = lastText()
  const rows = body.split('\n').filter(l => l.startsWith('- [nudge]'))
  check('S25d two byte-identical payloads are one wake listing two rows', woke && rows.length === 2, `messages=${sent.length - before} rows=${rows.length}`)
  check('S25d the two rows differ by source time and identity',
    rows.length === 2 && rows[0] !== rows[1] && new Set(rows).size === 2,
    rows.join(' | '))
  check('S25d the wake names each line\'s absolute source time and its identity',
    body.includes(new Date(t1).toISOString()) && body.includes(new Date(t2).toISOString())
      && body.includes(identityOf(`${t1}\tnudge\tpulse\t-\t${text}`)) && body.includes(identityOf(`${t2}\tnudge\tpulse\t-\t${text}`)),
    rows.join(' | '))
  check('S25d total counts both lines (two real deliveries)', lastTotal() === 2, `total=${lastTotal()}`)
  // 重写其中一条 → 零唤醒 + replay suppressed reason=rescan
  const first = readFileSync(f, 'utf8').split('\n').find(l => l.startsWith(String(t1))) ?? ''
  const beforeR = sent.length
  const rescanA = ledgerMatches(/ rescan lines=/)
  writeFileSync(f, `${first}\n`)
  await waitFor(() => ledgerMatches(/ rescan lines=/) > rescanA, 3000)
  check('S25d a rewrite of one of them produces no wake', sent.length === beforeR, `messages=${sent.length - beforeR}`)
  check('S25d the rewrite is named replay suppressed reason=rescan',
    ledgerMatches(/replay suppressed n=1 reason=rescan/) >= 1,
    ledger().filter(l => /replay suppressed/.test(l)).at(-1) ?? '(none)')
  check('S25d the rescan reads deliver=0',
    /rescan lines=1 dup=1 skipped=0 deliver=0 /.test(ledger().filter(l => / rescan lines=/.test(l)).at(-1) ?? ''),
    ledger().filter(l => / rescan lines=/.test(l)).at(-1) ?? '(none)')
  check('S25d total is unchanged by the rewrite', lastTotal() === 2, `total=${lastTotal()}`)
  await shutdown()
}

// ── S25e：.seen 一次性导入 / 撕裂尾 / 压缩边界与 floor（3.3/3.4/4.1/4.3）────────────
if (only('S25e')) {
  // (a) 升级：老 .seen 只被导入一次，之后删掉它不改变任何决定
  await resetState()
  const key = KEY
  const oldLine = `${Date.now() - 7200_000}\tsay\tpm\tpm\tS25e-seen-line`
  mkdirSync(WATCH_DIR, { recursive: true })
  writeFileSync(join(WATCH_DIR, `${key}.seen`), `${oldLine}\n`)
  await sessionStart()
  check('S25e the first start imports <key>.seen once and records it',
    ledgerMatches(/seen import n=1 /) === 1
      && journalLines().some(l => / sent .*imported=1/.test(l) && l.includes(identityOf(oldLine))),
    ledger().filter(l => /seen import/.test(l)).at(-1) ?? '(no import line)')
  const beforeA = sent.length
  appendWakeRaw(Buffer.from(`${oldLine}\n`))
  await sleep(600)
  check('S25e an imported (already-delivered) line wakes nobody',
    sent.length === beforeA && lastTotal() === 0 && ledgerMatches(/replay suppressed/) >= 1,
    `messages=${sent.length - beforeA} total=${lastTotal()}`)
  // 删掉 .seen：同一份字节再重写一次，仍然沉默（日志是唯一记忆；先截断让读者看见 shrink）
  rmSync(join(WATCH_DIR, `${key}.seen`), { force: true })
  const bytes = readFileSync(spoolFile())
  const rescanB = ledgerMatches(/ rescan lines=/)
  const replayB = ledgerMatches(/replay suppressed/)
  writeFileSync(spoolFile(), '')
  await waitFor(() => ledgerMatches(/ rescan lines=/) > rescanB, 3000)
  appendFileSync(spoolFile(), bytes)
  await waitFor(() => ledgerMatches(/replay suppressed/) > replayB, 3000)
  check('S25e deleting .seen changes no delivery decision',
    sent.length === beforeA && lastTotal() === 0, `messages=${sent.length - beforeA} total=${lastTotal()}`)
  await shutdown()

  // (b) 撕裂尾：read 完整、intent 被截断 → 结果未知，永不重投
  await resetState()
  mkdirSync(WATCH_DIR, { recursive: true })
  const tornLine = `${Date.now()}\tsay\tpm\tpm\tS25e-torn-line`
  writeFileSync(spoolFile(), `${tornLine}\n`)
  const tornId = identityOf(tornLine)
  writeFileSync(journalPathOf(),
    `${new Date().toISOString()} start baseline=0 size=0 head=absent\n` +
    `${new Date().toISOString()} read seq=1 off=1 size=1 head=empty id=${jesc(tornId)} src=${tornLine.split('\t')[0]} kind=say from=pm durable=pm preview=S25e-torn-line\n` +
    `${new Date().toISOString()} intent seq=`)
  await sessionStart()
  check('S25e a torn trailing record is named in the ledger',
    ledgerMatches(/torn tail/) >= 1, ledger().filter(l => /torn tail/.test(l)).at(-1) ?? '(none)')
  check('S25e a torn tail is treated as inflight assumed',
    ledgerMatches(/inflight assumed n=1 /) === 1, ledger().filter(l => /inflight assumed/.test(l)).join(' | ') || '(none)')
  const beforeB = sent.length
  await sleep(500)
  check('S25e a line whose outcome is unknown is never woken', sent.length === beforeB, `messages=${sent.length - beforeB}`)
  const rescanC = ledgerMatches(/ rescan lines=/)
  writeFileSync(spoolFile(), '')
  await waitFor(() => ledgerMatches(/ rescan lines=/) > rescanC, 3000)
  appendFileSync(spoolFile(), `${tornLine}\n`)
  await waitFor(() => ledgerMatches(/replay suppressed/) >= 1, 3000)
  check('S25e a later rewrite of a torn-read line stays silent',
    sent.length === beforeB && lastTotal() === 0, `messages=${sent.length - beforeB} total=${lastTotal()}`)
  await shutdown()

  // (c) 压缩：越界即压到界内、写 floor=；保留的身份仍被压制，被淘汰的身份 unprovable
  await resetState()
  process.env.TEAM_INBOX_WATCH_JOURNAL_MAX = '24'
  await sessionStart()
  for (let i = 0; i < 12; i++) {
    appendWakeAt(Date.now() - (12 - i) * 60_000, 'say', 'pm', 'pm', `S25e-compact-${i}`)
    await waitFor(() => journalOf('sent').length > i, 4000)
  }
  check('S25e compaction keeps the journal under the bound', journalLines().length <= 24, `records=${journalLines().length}`)
  check('S25e compaction records its eviction floor',
    ledgerMatches(/journal compacted /) >= 1 && / floor=\S+ floor_ts=\d+ /.test(ledger().filter(l => /journal compacted/.test(l)).at(-1) ?? ''),
    ledger().filter(l => /journal compacted/.test(l)).at(-1) ?? '(none)')
  const all = spoolLines()
  const oldest = all[0] ?? ''
  const newest = all[all.length - 1] ?? ''
  const keptIds = journalOf('read').map(r => r.fields.id)
  check('S25e the retained identities are still in the journal and the evicted one is not',
    keptIds.includes(identityOf(newest)) && !keptIds.includes(identityOf(oldest)),
    `kept=${keptIds.length} oldestEvicted=${!keptIds.includes(identityOf(oldest))}`)
  await shutdown()
  // 重启后（内存清零）重写两条：保留的 → replay suppressed；被淘汰的 → unprovable，永不唤醒
  await sessionStart()
  const beforeC = sent.length
  const totalC = lastTotal()
  const rescan0 = ledgerMatches(/ rescan lines=/)
  writeFileSync(spoolFile(), `${oldest}\n${newest}\n`)
  await waitFor(() => ledgerMatches(/ rescan lines=/) > rescan0, 3000)
  await waitFor(() => ledgerMatches(/unprovable n=1 /) >= 1, 3000)
  check('S25e a retained identity is suppressed on a rewrite',
    ledgerMatches(/replay suppressed n=1 reason=rescan/) >= 1,
    ledger().filter(l => /replay suppressed/.test(l)).at(-1) ?? '(none)')
  check('S25e an identity below the eviction floor is unprovable, never woken',
    ledgerMatches(/unprovable n=1 /) >= 1, ledger().filter(l => /unprovable/.test(l)).at(-1) ?? '(none)')
  check('S25e compaction cannot resurrect a delivery',
    sent.length === beforeC && lastTotal() === totalC,
    `messages=${sent.length - beforeC} total=${totalC}->${lastTotal()}`)
  check('S25e the rescan reads deliver=0 with dup=1 and the unprovable counted separately',
    /rescan lines=2 dup=1 skipped=0 deliver=0 /.test(ledger().filter(l => / rescan lines=/.test(l)).at(-1) ?? ''),
    ledger().filter(l => / rescan lines=/.test(l)).at(-1) ?? '(none)')
  delete process.env.TEAM_INBOX_WATCH_JOURNAL_MAX
  await shutdown()
}

// ── S25f：事故重放（原始字节 + 从 .seen/交付事实播种的日志）→ 零唤醒、deliver=0（5.1）──
if (only('S25f')) {
  await resetState()
  const fx = join(SKILL_DIR, 'tests/fixtures/p71-incident')
  const dev2 = readFileSync(join(fx, 'dev2.wake'))
  const seenLines = readFileSync(join(fx, 'dev2.seen'), 'utf8').split('\n').filter(l => l.trim())
  const pmNudges = readFileSync(join(fx, 'pm-nudges.wake'))
  mkdirSync(WATCH_DIR, { recursive: true })
  writeFileSync(spoolFile(), Buffer.concat([dev2, pmNudges]))
  // 从事故的 sent 事实播种：dev2 的 8 条 .seen + PM 的三条 nudge；最老的 dev2 行（投过但没记进 .seen）不播种
  const seeded = [...seenLines.map(identityOf), ...pmNudges.toString('utf8').split('\n').filter(l => l.trim()).map(identityOf)]
  const seedRecs = [`${new Date().toISOString()} start baseline=0 size=0 head=absent`]
  seeded.forEach((id, i) => seedRecs.push(`${new Date().toISOString()} sent seq=-${i + 1} id=${jesc(id)} imported=1`))
  writeFileSync(journalPathOf(), `${seedRecs.join('\n')}\n`)
  const before = sent.length
  await sessionStart()          // 基线吞掉整份 spool（没有人活着看过它）
  await sleep(500)
  check('S25f the incident spool produces zero wakes at startup', sent.length === before, `messages=${sent.length - before}`)
  // ① 记录下来的那一拍（事故 17:46:49）：原位截断 → 读者看到 shrink，rescan 读 0 行（`deliver=0`）
  const bytes = readFileSync(spoolFile())
  writeFileSync(spoolFile(), '')
  await waitFor(() => ledgerMatches(/ rescan lines=/) >= 1, 3000)
  check('S25f the recorded truncation reads deliver=0 (the incident shape)',
    sent.length === before && /rescan lines=0 dup=0 skipped=0 deliver=0 /.test(ledger().filter(l => / rescan lines=/.test(l)).at(-1) ?? ''),
    ledger().filter(l => / rescan lines=/.test(l)).at(-1) ?? '(none)')
  // ② 同一批字节写回（普通路径）：已投递的身份一律 replay suppressed，没记进 .seen 的那一行过期只计数
  appendFileSync(spoolFile(), bytes)
  await waitFor(() => ledgerMatches(/replay suppressed n=11 reason=normal/) >= 1, 3000)
  check('S25f every seeded identity is replay-suppressed, none is woken',
    sent.length === before && ledgerMatches(/replay suppressed n=11 reason=normal/) >= 1,
    ledger().filter(l => /replay suppressed/.test(l)).at(-1) ?? '(none)')
  check('S25f the one delivered-but-unrecorded line is counted stale and never woken',
    ledgerMatches(/classify stale=1 unparsable=0/) >= 1, ledger().filter(l => /classify /.test(l)).at(-1) ?? '(none)')
  // ③ 截断与写回落在同一拍：有界重扫也要逐条分类、零唤醒（reason=rescan）
  const classifyBefore = ledgerMatches(/classify stale=/)
  appendFileSync(spoolFile(), `${Date.now() - 3600_000}\tknock\tpm\t-\tS25f-padding-${'P'.repeat(200)}\n`)
  await waitFor(() => ledgerMatches(/classify stale=/) > classifyBefore, 3000)
  const rescanBefore = ledgerMatches(/ rescan lines=/)
  writeFileSync(spoolFile(), bytes)
  await waitFor(() => ledgerMatches(/ rescan lines=/) > rescanBefore, 3000)
  await waitFor(() => ledgerMatches(/replay suppressed n=11 reason=rescan/) >= 1, 3000)
  const rescanLine = ledger().filter(l => / rescan lines=/.test(l)).at(-1) ?? ''
  check('S25f a one-shot truncate+rewrite is rescanned, classified and silent',
    ledgerMatches(/ rescan lines=/) > rescanBefore && sent.length === before
      && /rescan lines=12 dup=11 skipped=0 deliver=0 stale=1 /.test(rescanLine)
      && ledgerMatches(/replay suppressed n=11 reason=rescan/) >= 1,
    `${rescanLine.trim()} || messages=${sent.length - before}`)
  check('S25f total is untouched by the incident replay', lastTotal() === 0, `total=${lastTotal()}`)
  await shutdown()
}

// ── S26：唤醒文本契约（源行点名 / 单调序号 / 日志路径 / 形状不变）（2.2）──────────────
if (only('S26')) {
  await resetState()
  await sessionStart()
  const f = spoolFile()
  const t1 = Date.now()
  const b0 = sent.length
  appendWakeAt(t1, 'say', 'pm', 'pm', 'S26-first')
  await waitFor(() => sent.length >= b0 + 1)
  const seq1 = Number(/#(\d+)/.exec(lastText())?.[1] ?? 0)
  const t2 = t1 + 1
  appendWakeAt(t2, 'say', 'pm', 'pm', 'S26-second')
  await waitFor(() => sent.length >= b0 + 2)
  const body = lastText()
  const seq2 = Number(/#(\d+)/.exec(body)?.[1] ?? 0)
  check('S26 the wake carries a monotonic sequence and an absolute send time',
    seq2 === seq1 + 1 && /#\d+ · \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/.test(body), `seqs=${seq1}->${seq2}`)
  const line2 = `${t2}\tsay\tpm\tpm\tS26-second`
  check('S26 every listed line names its own absolute source time and identity',
    body.includes(new Date(t2).toISOString()) && body.includes(identityOf(line2)),
    body.split('\n').filter(l => l.startsWith('- ')).join(' | '))
  check('S26 the wake names the delivery journal the identities were recorded in',
    body.includes(journalPathOf()) && existsSync(journalPathOf()),
    (body.split('\n').find(l => l.includes('Delivery journal')) ?? '(none)').slice(0, 200))
  check('S26 the wake shape is unchanged (customType/triggerTurn/followUp)',
    sent.at(-1)?.msg?.customType === 'team-inbox' && sent.at(-1)?.opts?.triggerTurn === true
      && sent.at(-1)?.opts?.deliverAs === 'followUp',
    JSON.stringify({ customType: sent.at(-1)?.msg?.customType, ...(sent.at(-1)?.opts ?? {}) }))
  check('S26 no payload dump: the wake stays a bounded one-line pointer per line',
    body.split('\n').filter(l => l.startsWith('- ')).every(l => l.length <= 220), `len=${body.length}`)
  check('S26 every wake line in the ledger names seq and ids',
    ledger().filter(l => / wake n=/.test(l)).every(l => / seq=\d+ ids=\S+/.test(l)),
    ledger().filter(l => / wake n=/.test(l)).join(' | '))
  await shutdown()
}

// ── 反向守卫：真实仓库 state/ 未被触碰 ───────────────────────────────────────
{
  const after = snapshot(REAL_STATE)
  check('reverse guard: the real repo state/ is untouched', after === REAL_BEFORE,
    after === REAL_BEFORE ? '' : 'real state/ changed during the harness')
}

console.log(failures === 0
  ? `TEAM-IW-HARNESS OK (skipped=${skipped})`
  : `TEAM-IW-HARNESS FAIL (${failures})`)
console.log(`fixture: ${keep || process.env.TEAM_IW_KEEP === '1' ? TMP : '(removed)'}`)
process.exit(failures === 0 ? 0 : 1)
