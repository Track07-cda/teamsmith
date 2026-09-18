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
import { execFileSync } from 'node:child_process'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync, appendFileSync } from 'node:fs'
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

// ── 身份隔离：绝不继承调用者的团队身份与 tmux 身份 ──────────────────────────────
for (const key of Object.keys(process.env)) {
  if (/^(TEAM_|SMOKE_)/.test(key) || key === 'TMUX' || key === 'TMUX_PANE') delete process.env[key]
}

const sleep = (ms) => new Promise(r => setTimeout(r, ms))
let failures = 0
const check = (name, ok, detail = '') => {
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
const handlers = {}
const api = {
  on: (name, fn) => { (handlers[name] ||= []).push(fn) },
  registerTool: () => {},
  registerCommand: () => {},
  sendMessage: (msg, opts) => { sent.push({ msg, opts, at: Date.now() }) },
}
const emit = async (name, ...rest) => { for (const fn of handlers[name] ?? []) await fn(...rest) }
const ctx = { cwd: ROOT }
const sessionStart = () => emit('session_start', { reason: 'startup' }, ctx)
const shutdown = () => emit('session_shutdown', { reason: 'quit' }, ctx)

const regs = () => (existsSync(WATCH_DIR) ? readdirSync(WATCH_DIR).filter(f => f.endsWith('.reg')) : [])
const wakes = () => (existsSync(WATCH_DIR) ? readdirSync(WATCH_DIR).filter(f => f.endsWith('.wake')) : [])
// spool 与注册同名（只差后缀）：先看真的 .wake，再从未删的 .reg 推导，最后用记住的路径 ——
// shutdown 之后还要能往同一个 spool 写「历史行」（S5）。
let lastSpool = ''
const spoolFile = () => {
  const w = wakes()[0]
  if (w) return (lastSpool = join(WATCH_DIR, w))
  const r = regs()[0]
  if (r) return (lastSpool = join(WATCH_DIR, r.replace(/\.reg$/, '.wake')))
  return lastSpool
}
const appendWake = (kind, from, inbox, payload) => {
  mkdirSync(WATCH_DIR, { recursive: true })
  const f = spoolFile()
  if (!f) throw new Error('no spool file: the extension never registered')
  appendFileSync(f, `${Date.now()}\t${kind}\t${from}\t${inbox}\t${payload}\n`)
}
const ledger = () => (existsSync(LEDGER) ? readFileSync(LEDGER, 'utf8').trim().split('\n') : [])
const lastText = (i = -1) => String(sent.at(i)?.msg?.content ?? '')

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
{
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
{
  const before = sent.length
  mkdirSync(WATCH_DIR, { recursive: true })
  for (const n of [1, 2, 3]) appendWake('say', 'dev', 'pm', `burst line ${n}`)
  await sleep(600)
  check('S3 a burst of three lines produces exactly one wake', sent.length === before + 1, `messages=${sent.length - before}`)
  const body = lastText()
  check('S3 the merged wake names every line', [1, 2, 3].every(n => body.includes(`burst line ${n}`)), body.replace(/\n/g, ' | '))
}

// ── S4：预览截断 + 每条约 4 行上限（只带指针，不带 payload 全文） ───────────────
{
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
{
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
{
  process.env.TEAM_INBOX_WATCH_MAX_BYTES = '2048'
  const before = sent.length
  const f = spoolFile()
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
  check('S9 ledger records shutdown', lines.some(l => / stopped target=m30s:pm /.test(l)))
}

// ── S10：端到端（真扩展 + 真 CLI + 真文件）：假 worker 的回合结束通知 → 监视唤醒 → 收件箱可读 ──
//   这是 brief 要求的那条实录的**零模型**形态：把假 Pi 宿主换掉，其余全是生产件（真扩展注册、
//   `team notify pm` 真跑、真 durable 收件箱、真 spool）。真实的「唤醒一个空闲 pi 会话（含模型一轮）」
//   由 E8 的 RPC 探针实证（docs/team/reports/E8-verify/probes），这里不重复付模型成本。
{
  process.env.TEAM_INBOX_WATCH_TARGET = 'm30s:pm'
  process.env.TEAM_INBOX_WATCH_POLL_MS = '3600000'
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
  await shutdown()
}

// ── 反向守卫：真实仓库 state/ 未被触碰 ───────────────────────────────────────
{
  const after = snapshot(REAL_STATE)
  check('reverse guard: the real repo state/ is untouched', after === REAL_BEFORE,
    after === REAL_BEFORE ? '' : 'real state/ changed during the harness')
}

console.log(failures === 0 ? 'TEAM-IW-HARNESS OK' : `TEAM-IW-HARNESS FAIL (${failures})`)
console.log(`fixture: ${keep || process.env.TEAM_IW_KEEP === '1' ? TMP : '(removed)'}`)
process.exit(failures === 0 ? 0 : 1)
