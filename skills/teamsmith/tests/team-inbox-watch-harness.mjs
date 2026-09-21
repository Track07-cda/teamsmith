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

// ── S11：外部截断+重写（M43 事故形状）：已投递行不得重放，total 不灌水 ─────────────────
// 2026-09-19 事故（pm-skills 主树 inbox-watch.log:118-120）：外部力量把 spool **原位截断又写回
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
{
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
  const dedupLines = ledger().filter(l => /dedup: skipped/.test(l))
  check('S11 the ledger records the shrink and the dedup skip (auditable, not a silent reset)',
    shrinkLines.length >= 1 && dedupLines.length >= 1,
    `${shrinkLines.at(-1) ?? '(no shrink line)'} || ${dedupLines.at(-1) ?? '(no dedup line)'}`)
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
{
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

// ── S13：去重记忆跨会话重启（<key>.seen 持久化；重启后的重写仍然静默）────────────────────
{
  await shutdown()
  await sessionStart()   // 内存态清零 → 去重记忆只能从 <key>.seen 重新加载
  const seenFiles = existsSync(WATCH_DIR) ? readdirSync(WATCH_DIR).filter(x => x.endsWith('.seen')) : []
  check('S13 the dedup memory is persisted (<key>.seen exists)', seenFiles.length === 1,
    `seen=${seenFiles.length}`)
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
// 事故（2026-09-20）：ai_interview 的 PM 加载的是旧扩展，按继承的 TEAM_* 解到 pm-skills，
// 用 pm-skills 的会话名算出期望 target 与真实会话不符 → 每 2 秒 skip setup 一次，痕迹全写进
// **别人的** state，而投递已经静默退回输入框粘贴路径（draft-raced-left + 两条消息滞留）。
// 这三条钉住修复后的契约：① 跳过的原因留在**本项目**；② 成功注册会把旧痕迹删掉；
// ③ 继承的 TEAM_STATE_DIR 指向别的项目时一律拒绝（M40 的 state 面）。
const skipFiles = () => (existsSync(WATCH_DIR) ? readdirSync(WATCH_DIR).filter(f => f.endsWith('.skip')) : [])
const cliPath = join(SKILL_DIR, 'scripts/team')
{
  await shutdown()
  const savedOverride = process.env.TEAM_INBOX_WATCH_TARGET
  const savedState = process.env.TEAM_STATE_DIR

  // ── S14：会话名不符（配置说 m30s，target 指向 ai-interview）→ 本项目 state 里的 skip 记录
  // 注意：TEAM_INBOX_WATCH_TARGET 只改「从哪读 target」，不改「哪个会话是本项目的」——所以这条
  // 显式覆盖同样会被拒（bun 会缓存启动时的 PATH，夹具不能靠 PATH 假 tmux 来造这个形状）。
  process.env.TEAM_INBOX_WATCH_TARGET = 'ai-interview:pm'
  await sessionStart()
  const skips = skipFiles()
  check('M46-S14 a session-name mismatch leaves exactly one .skip record', skips.length === 1, `skips=${skips.length}`)
  const skipText = skips.length ? readFileSync(join(WATCH_DIR, skips[0]), 'utf8') : ''
  for (const [field, want] of [['session', 'ai-interview'], ['window', 'pm'], ['expect', 'm30s'], ['reason', 'session-mismatch'], ['pid', String(process.pid)], ['cwd', ROOT]]) {
    check(`M46-S14 the skip record carries ${field}=${want}`, new RegExp(`^${field}=${want}$`, 'm').test(skipText), skipText.replace(/\n/g, ' | '))
  }
  check('M46-S14 the skip record lives in the cwd-derived project state dir',
    skips.length === 1 && existsSync(join(WATCH_DIR, skips[0])), `watch=${WATCH_DIR}`)
  check('M46-S14 a foreign session is not registered', regs().length === 0, `regs=${regs().length}`)
  check('M46-S14 the ledger still records the skip reason',
    ledger().some(l => /skip setup: session ai-interview != m30s/.test(l)), ledger().at(-1) || '(no ledger)')
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
  const regPath = join(WATCH_DIR, regs()[0])
  const hb0 = statSync(regPath).mtimeMs
  await sleep(400)
  // 心跳前进 = 定时器真的在跑：空闲断言不是「压根没拍」（POLL_MS 低于 envNum 下限会被拒）
  const hbMoved = statSync(regPath).mtimeMs > hb0
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
  const seenFile = readdirSync(WATCH_DIR).filter(n => n.endsWith('.seen')).map(n => join(WATCH_DIR, n))[0]
  const seenLines = readFileSync(seenFile, 'utf8').split('\n').filter(l => l.trim())
  // (a) 只含已投递行的重写 → deliver=0 + dup>0、total 不动、无唤醒
  const picked = seenLines.filter(l => /burst line|after-clipped-line/.test(l)).slice(-3)
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

// ── 反向守卫：真实仓库 state/ 未被触碰 ───────────────────────────────────────
{
  const after = snapshot(REAL_STATE)
  check('reverse guard: the real repo state/ is untouched', after === REAL_BEFORE,
    after === REAL_BEFORE ? '' : 'real state/ changed during the harness')
}

console.log(failures === 0 ? 'TEAM-IW-HARNESS OK' : `TEAM-IW-HARNESS FAIL (${failures})`)
console.log(`fixture: ${keep || process.env.TEAM_IW_KEEP === '1' ? TMP : '(removed)'}`)
process.exit(failures === 0 ? 0 : 1)
