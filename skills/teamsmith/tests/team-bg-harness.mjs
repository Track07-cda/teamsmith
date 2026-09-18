#!/usr/bin/env node
/**
 * teamsmith · team-bg 扩展的确定性夹具（M27）
 *
 *   <node|bun> team-bg-harness.mjs <skill>/extension/team-bg.ts [--keep]
 *
 * 为什么用「假 Pi 宿主」而不是真模型：本夹具要证的是**扩展自己的契约**——job 表、收割/未收割、
 * 合并成一条、账本行格式、日志有界。这些都被接口（registerTool / agent_settled / sendMessage）完全
 * 决定，用真模型只会把判据换成「模型有没有照着做」。真实的「唤醒一个空闲 pi 会话」由 E8 的 RPC 探针
 * 实证过（docs/team/reports/E8-verify/probes/），本夹具不重复付那份成本（模型调用 + 波动）。
 *
 * 隔离纪律（M7.2 的教训）：继承来的团队身份先清掉，TEAM_ROOT 显式指向临时仓库；每条断言都要求
 * 产物落在临时仓库里；跑完再对比**真实仓库** state/ 的前后快照（反向守卫）。
 *
 * 每个用例打印一行 `TEAM-BG-CASE PASS|FAIL <name> [:: detail]`，任一 FAIL → 退出码 1。
 */
import { execFileSync } from 'node:child_process'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'

const args = process.argv.slice(2)
const keep = args.includes('--keep') || process.env.TEAM_BG_KEEP === '1'
const ext = args.find(a => !a.startsWith('--'))
if (!ext) {
  console.error('usage: team-bg-harness.mjs <path/to/team-bg.ts> [--keep]')
  process.exit(2)
}
const EXT = resolve(ext)

// ── 身份隔离：绝不继承调用者的团队身份与 tmux 身份 ──────────────────────────────
for (const key of Object.keys(process.env)) {
  if (/^(TEAM_|SMOKE_)/.test(key) || key === 'TMUX' || key === 'TMUX_PANE') delete process.env[key]
}

const sleep = (ms) => new Promise(r => setTimeout(r, ms))
let failures = 0
const check = (name, ok, detail = '') => {
  console.log(`TEAM-BG-CASE ${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ` :: ${detail}` : ''}`)
  if (!ok) failures++
}

// ── 夹具仓库（有 .pi/team/config.sh 的 git 仓库；findRoot 走 git 主工作树那一支）────────
const TMP = mkdtempSync(join(tmpdir(), 'teamsmith-bg-'))
const ROOT = join(TMP, 'repo')
mkdirSync(ROOT, { recursive: true })
process.env.TEAM_ROOT = ROOT
if (!keep) process.on('exit', () => { try { rmSync(TMP, { recursive: true, force: true }) } catch {} })
try { execFileSync('git', ['init', '-q', '-b', 'main', ROOT], { stdio: 'ignore' }) } catch {}
mkdirSync(join(ROOT, '.pi/team'), { recursive: true })
writeFileSync(join(ROOT, '.pi/team/config.sh'), 'TEAM_PROJECT="bg-harness"\n')
const STATE = join(ROOT, '.pi/team/state')

// ── 反向守卫：真实仓库 state/ 前后快照 ────────────────────────────────────────
const REAL_REPO = resolve(EXT, '../../..') // <repo>/skills/teamsmith/extension/team-bg.ts
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
const tools = {}
const handlers = {}
const api = {
  on: (name, fn) => { (handlers[name] ||= []).push(fn) },
  registerTool: (def) => { tools[def.name] = def },
  registerCommand: () => {},
  sendMessage: (msg, opts) => { sent.push({ msg, opts }) },
  getAllTools: () => Object.keys(tools),
}
const emit = async (name, ...rest) => { for (const fn of handlers[name] ?? []) await fn(...rest) }
const ctx = { cwd: ROOT }
const turnStart = () => emit('agent_start', {}, ctx)
const turnEnd = () => emit('agent_settled', {}, ctx)

if (!existsSync(EXT)) {
  check('import', false, `extension missing: ${EXT}`)
  console.log('TEAM-BG-HARNESS FAIL (extension missing — this is the pre-M27 shape)')
  process.exit(1)
}
let factory
try {
  factory = (await import(EXT)).default
} catch (error) {
  check('import', false, String(error?.stack ?? error))
  console.log('TEAM-BG-HARNESS FAIL (import)')
  process.exit(1)
}
factory(api)
check('factory registers team_bg_run', typeof tools.team_bg_run?.execute === 'function')
check('factory registers team_bg_wait', typeof tools.team_bg_wait?.execute === 'function')
check('factory starts no session resource (no ledger before any job)', !existsSync(join(STATE, 'bg.log')))
check('session_start / session_shutdown hooks registered',
  (handlers.session_start ?? []).length > 0 && (handlers.session_shutdown ?? []).length > 0)
await emit('session_start', { reason: 'startup' }, ctx)

const run = async (command, name) => {
  const res = await tools.team_bg_run.execute('call-run', { command, name }, null, null, ctx)
  const text = String(res?.content?.[0]?.text ?? '')
  const id = /job ([^ ]+) started/.exec(text)?.[1]
  check(`run ${name} returns id+pid inside the fixture root`,
    !!id && /pid \d+/.test(text) && String(res?.details?.log ?? '').startsWith(ROOT), `id=${id}`)
  return { id, log: String(res?.details?.log ?? ''), pid: Number(res?.details?.pid ?? 0), text }
}
const wait = async (id, timeout_ms) => String((await tools.team_bg_wait.execute('call-wait', { id, timeout_ms }, null)).content[0].text)
const ledger = () => existsSync(join(STATE, 'bg.log')) ? readFileSync(join(STATE, 'bg.log'), 'utf8').trim().split('\n') : []
const settledCounts = () => ledger().map(l => Number(/ settled-with-unharvested=(\d+)/.exec(l)?.[1] ?? -1))

// ── S1：未收割 → 空闲时被唤醒（合并窗口后一条消息） ─────────────────────────────
{
  const { id } = await run('sleep 0.4; echo S1-DONE', 's1')
  await turnStart(); await turnEnd() // 回合在作业还在跑时结束
  check('S1 no wake before the job exits', sent.length === 0, `sent=${sent.length}`)
  await sleep(1500)
  const wake = sent[0]
  check('S1 unharvested job wakes the idle agent exactly once', sent.length === 1, `sent=${sent.length}`)
  check('S1 wake is a followUp with triggerTurn', wake?.opts?.triggerTurn === true && wake?.opts?.deliverAs === 'followUp',
    JSON.stringify(wake?.opts ?? {}))
  check('S1 wake names the job and its exit code',
    String(wake?.msg?.content ?? '').includes(id) && String(wake?.msg?.content ?? '').includes('exit=0'))
  const waited = await wait(id)
  check('S1 harvest returns the result inline', waited.includes('exit=0') && waited.includes('S1-DONE'))
  await sleep(500)
  check('S1 harvested job stays silent afterwards', sent.length === 1, `sent=${sent.length}`)
}

// ── S2：已收割 → 静默（#689 第 1 条） ─────────────────────────────────────────
{
  const { id } = await run('sleep 0.2; echo S2-DONE', 's2')
  const waited = await wait(id) // 阻塞等到结束并收割
  check('S2 wait harvests a running job', waited.includes('exit=0') && waited.includes('S2-DONE'))
  const before = sent.length
  await turnStart(); await turnEnd()
  await sleep(800)
  check('S2 harvested job never wakes the agent',
    sent.length === before && !sent.slice(before).some(m => String(m?.msg?.content ?? '').includes(id)),
    `sent ${before} -> ${sent.length}`)
}

// ── S3：空闲时多条同时完成 → 合并成一条 ───────────────────────────────────────
{
  const before = sent.length
  const { id: a } = await run('sleep 0.15; echo M1', 'm1')
  const { id: b } = await run('sleep 0.2; echo M2', 'm2')
  await sleep(1500)
  const merged = sent.slice(before)
  check('S3 two jobs finishing together produce exactly one message', merged.length === 1, `messages=${merged.length}`)
  const body = String(merged[0]?.msg?.content ?? '')
  check('S3 the merged message names both jobs', body.includes(a) && body.includes(b) && /2 background job/.test(body))
  check('S3 merged wake is followUp+triggerTurn',
    merged[0]?.opts?.triggerTurn === true && merged[0]?.opts?.deliverAs === 'followUp')
  // 礼貌的 agent 被唤醒后会把结果收割掉（也证明「先通知后收割」这条路通）
  check('S3 both notified jobs can still be harvested inline',
    (await wait(a)).includes('M1') && (await wait(b)).includes('M2'))
}

// ── S4：agent 跑着时完成 → 等 settled 再合并投递（不插队） ─────────────────────
{
  const before = sent.length
  await turnStart()
  const { id: a } = await run('sleep 0.15; echo N1', 'n1')
  const { id: b } = await run('sleep 0.2; echo N2', 'n2')
  await sleep(800) // 两条都在回合内结束
  check('S4 nothing is delivered while the agent is running', sent.length === before, `sent=${sent.length}`)
  await turnEnd()
  const merged = sent.slice(before)
  check('S4 settle delivers one merged message', merged.length === 1, `messages=${merged.length}`)
  const body = String(merged[0]?.msg?.content ?? '')
  check('S4 merged message names both jobs', body.includes(a) && body.includes(b))
  await wait(a); await wait(b) // 收尾：清掉未收割状态
}

// ── S5：账本格式（state/bg.log：每回合一行 settled-with-unharvested=<n>） ───────
{
  const lines = ledger()
  const iso = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z /
  check('S5 every ledger line starts with an ISO timestamp', lines.length > 0 && lines.every(l => iso.test(l)),
    `${lines.length} lines`)
  const settled = lines.filter(l => / settled-with-unharvested=\d+( |$)/.test(l))
  const counts = settledCounts().filter(n => n >= 0)
  check('S5 settled lines report the unharvested count', counts.includes(1), `counts=${counts.join(',')}`)
  check('S5 settled line 0 after the harvested job', counts.includes(0), `counts=${counts.join(',')}`)
  check('S5 settled-with-unharvested=2 while two jobs wait', counts.includes(2), `counts=${counts.join(',')}`)
  check('S5 job detail is appended for unharvested jobs',
    settled.some(l => /jobs=[^ ]+:(running|exit-?\d+)/.test(l)), settled.find(l => l.includes('jobs=')) ?? '(none)')
  check('S5 wake lines carry count+ids', lines.some(l => / wake count=2 ids=[^ ]+,[^ ]+/.test(l)))
}

// ── S6：日志有界（截断留尾段）+ 收割结果内联 ──────────────────────────────────
{
  process.env.TEAM_BG_LOG_MAX_BYTES = '4096'
  const { id, log } = await run("head -c 60000 /dev/zero | tr '\\0' x; echo TAIL-MARKER-S6", 'big')
  const waited = await wait(id)
  const size = existsSync(log) ? statSync(log).size : -1
  check('S6 log stays under the cap', size > 0 && size <= 4096, `bytes=${size}`)
  const body = existsSync(log) ? readFileSync(log, 'utf8') : ''
  check('S6 truncation keeps the tail', body.includes('TAIL-MARKER-S6') && body.includes('[team-bg] truncated'))
  check('S6 harvest reports the truncation and the tail', waited.includes('exit=0') && waited.includes('TAIL-MARKER-S6') && waited.includes('[team-bg] truncated'))
}

// ── S7：session 级 job 表（shutdown 清空；detached 作业不被杀） ────────────────
{
  const t0 = Date.now()
  const { id, pid } = await run('sleep 5; echo NEVER-HARVESTED', 's7')
  const elapsed = Date.now() - t0
  check('S7 team_bg_run returns immediately while the job runs', elapsed < 1500, `${elapsed}ms`)
  const status = await wait(id, 0)
  check('S7 timeout_ms=0 just reports that it is still running', /still running/.test(status))
  await emit('session_shutdown', { reason: 'quit' }, ctx)
  let threw = false
  try { await wait(id) } catch { threw = true }
  check('S7 session_shutdown clears the job table (old ids are unknown)', threw)
  let alive = false
  try { process.kill(pid, 0); alive = true } catch { alive = false }
  check('S7 the detached job survives session_shutdown', alive, `pid=${pid}`)
  try { process.kill(pid, 'SIGKILL') } catch {}
}

// ── 反向守卫：真实仓库 state/ 未被触碰 ───────────────────────────────────────
{
  const after = snapshot(REAL_STATE)
  check('reverse guard: the real repo state/ is untouched', after === REAL_BEFORE,
    after === REAL_BEFORE ? '' : 'real state/ changed during the harness')
}

console.log(failures === 0 ? 'TEAM-BG-HARNESS OK' : `TEAM-BG-HARNESS FAIL (${failures})`)
console.log(`fixture: ${keep || process.env.TEAM_BG_KEEP === '1' ? TMP : '(removed)'}`)
process.exit(failures === 0 ? 0 : 1)
