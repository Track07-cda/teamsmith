#!/usr/bin/env node
/**
 * P230 · long-job-suspend · A 刀夹具（`tests/bg-ledger.sh` 的确定性驱动）
 *
 *   <node|bun> bg-ledger-harness.mjs --bg <extension/team-bg.ts> --root <fixture repo> \
 *       [--notify <extension/team-notify.ts>] [--groups wording,ledger,suspend-shape,owner-scope] [--marker <pre>]
 *
 * 为什么用「假 Pi 宿主」而不是真模型：本夹具要证的是**扩展自己的合同** —— 注册工具面的文本、
 * 账本两类新行、挂起判定的目录解析与身份验证。这些都被接口（registerTool / agent_settled）完全决定，
 * 用真模型只会把判据换成「模型有没有照着做」。
 *
 * 三条纪律（M7.2 / §13c）：
 *   ① 身份隔离：启动时清掉继承来的 TEAM_ / SMOKE_ / TMUX 变量，绝不用调用者的项目身份；
 *   ② 每条用例的夹具仓库各带自己的 `.pi/team/config.sh`，只写 --root 与它旁边的 scratch 子树（/tmp 下）；
 *   ③ 起的每个后台作业都登记 pid，退出时只对**登记过的 pid**发信号（不按名字/模式找进程）。
 *
 * 输出：每个用例一行 `BG-CASE PASS|FAIL <name> [:: detail]`；任一 FAIL → 退出码 1。
 */
import { execFileSync, spawn } from 'node:child_process'
import { existsSync, lstatSync, mkdirSync, readdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'

// ── 参数与身份隔离 ─────────────────────────────────────────────────────────────
const argv = process.argv.slice(2)
const opt = (name, fallback = '') => {
  const i = argv.indexOf(`--${name}`)
  return i >= 0 && i + 1 < argv.length ? argv[i + 1] : fallback
}
const BG = opt('bg') ? resolve(opt('bg')) : ''
const NOTIFY = opt('notify', '-')
const ROOT = opt('root') ? resolve(opt('root')) : ''
const MARKER = opt('marker', 'bg-ledger')
const GROUPS = new Set(opt('groups', 'wording,ledger,suspend-shape,owner-scope').split(',').filter(Boolean))
if (!BG || !existsSync(BG)) {
  console.error('bg-ledger-harness: --bg <extension/team-bg.ts> 是必需的')
  process.exit(2)
}
if (!ROOT || !existsSync(join(ROOT, '.pi/team/config.sh'))) {
  console.error('bg-ledger-harness: --root <夹具仓库> 是必需的（它必须带 .pi/team/config.sh）')
  process.exit(2)
}
if ((GROUPS.has('suspend-shape') || GROUPS.has('owner-scope') || GROUPS.has('merge') || GROUPS.has('detail') || GROUPS.has('wake')) && NOTIFY === '-') {
  console.error('bg-ledger-harness: suspend-shape / owner-scope / merge / detail / wake 需要 --notify <extension/team-notify.ts>')
  process.exit(2)
}
for (const key of Object.keys(process.env)) {
  if (/^(TEAM_|SMOKE_)/.test(key) || key === 'TMUX' || key === 'TMUX_PANE') delete process.env[key]
}

// ── 基础工具 ──────────────────────────────────────────────────────────────────
const sleep = ms => new Promise(r => setTimeout(r, ms))
const waitFor = async (fn, ms = 4000) => { const t = Date.now(); for (;;) { if (fn()) return true; if (Date.now() - t > ms) return false; await sleep(25) } }
let failures = 0
const check = (name, ok, detail = '') => {
  console.log(`BG-CASE ${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ` :: ${detail}` : ''}`)
  if (!ok) failures++
}
const trackedPids = new Set()
const trackPid = pid => { if (pid > 0) trackedPids.add(pid) }
process.on('exit', () => { for (const pid of trackedPids) { try { process.kill(pid, 'SIGKILL') } catch { /* ignore */ } } })

const git = (args, cwd) => execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim()
const escapeRe = s => String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
const jobName = suffix => `${MARKER}-${suffix}`

// ── 扩展加载（每个场景一个独立的假宿主实例；同一模块可以被 default() 多次实例化）─────
const modules = new Map()
const loadModule = async path => {
  if (!modules.has(path)) modules.set(path, await import(path))
  return modules.get(path)
}
const newBgHost = mod => {
  const tools = {}
  const handlers = {}
  const sent = []
  mod.default({
    on: (name, fn) => { (handlers[name] ||= []).push(fn) },
    registerTool: def => { tools[def.name] = def },
    registerCommand: () => {},
    sendMessage: (msg, opts) => { sent.push({ msg, opts }) },
    getAllTools: () => Object.keys(tools),
  })
  return {
    tools,
    handlers,
    sent,
    emit: async (name, ...rest) => { for (const fn of handlers[name] ?? []) await fn(...rest) },
  }
}
const makeRunner = (host, cwd) => {
  const ctx = { cwd }
  const run = async (command, name) => {
    const res = await host.tools.team_bg_run.execute('call-run', { command, name }, null, null, ctx)
    const id = String(res?.details?.id ?? '')
    const pid = Number(res?.details?.pid ?? 0)
    trackPid(pid)
    return { id, pid, text: String(res?.content?.[0]?.text ?? ''), log: String(res?.details?.log ?? '') }
  }
  const wait = async (id, timeout_ms, signal) => {
    const params = timeout_ms === undefined ? { id } : { id, timeout_ms }
    const res = await host.tools.team_bg_wait.execute('call-wait', params, signal ?? null, null, ctx)
    return String(res?.content?.[0]?.text ?? '')
  }
  const stop = async (job, ms = 4000) => {
    try { process.kill(job.pid, 'SIGKILL') } catch { /* 已经不在了 */ }
    try { await wait(job.id, ms) } catch { /* 作业表已经清掉等场合 */ }
  }
  return { ctx, run, wait, stop }
}

// ── 账本读取 ──────────────────────────────────────────────────────────────────
const ledgerLines = stateDir => existsSync(join(stateDir, 'bg.log'))
  ? readFileSync(join(stateDir, 'bg.log'), 'utf8').trim().split('\n').filter(Boolean)
  : []
const ledgerFor = (stateDir, id, kind) => ledgerLines(stateDir)
  .filter(l => new RegExp(` ${kind} id=${escapeRe(id)}( |$)`).test(l)).at(-1) ?? ''
const waitedOf = line => Number(/ waited_s=([0-9.]+)/.exec(line)?.[1] ?? NaN)

// ── 夹具仓库 ──────────────────────────────────────────────────────────────────
const SCRATCH = join(dirname(ROOT), 'p230-bg-ledger')
mkdirSync(SCRATCH, { recursive: true })

/** 一个独立夹具仓库：主工作树 + 每个席位一个链接工作树（默认只有 `dev`；不带 config —— 复现生产形状）。
 *  wip.txt 让树保持脏：挂起要证明「⚠ 前缀被省略」，非挂起形状要对出「前缀在」。
 *  seats 多于一个时（P236 owner-scope）名册与工作树同步扩展：两席位共享同一个车道 state 目录。 */
const makeBase = (name, { ownConfigInWorktree = false, seats = ['dev'] } = {}) => {
  const base = join(SCRATCH, 'bases', name)
  rmSync(base, { recursive: true, force: true })
  mkdirSync(join(base, '.pi/team/state'), { recursive: true })
  mkdirSync(join(base, 'docs/team/inbox'), { recursive: true })
  writeFileSync(join(base, '.pi/team/config.sh'),
    `TEAM_PROJECT="bg-ledger-${name}"\nTEAM_AGENTS="${seats.join(' ')}"\nTEAM_WORKTREES_DIR=".worktrees"\n` +
    `TEAM_NOTIFY_LOG="${base}/.pi/team/state/notify-ext.log"\n`)
  writeFileSync(join(base, 'README.md'), `# bg-ledger fixture ${name}\n`)
  git(['init', '-q', '-b', 'main'], base)
  git(['add', 'README.md'], base)
  git(['-c', 'user.email=fixture@teamsmith', '-c', 'user.name=fixture', 'commit', '-qm', 'init'], base)
  const wts = {}
  for (const [i, seat] of seats.entries()) {
    const wt = join(base, '.worktrees', seat)
    git(['worktree', 'add', '-q', '-b', i === 0 ? `task/P230-${name}` : `task/P230-${name}-${seat}`, wt], base)
    writeFileSync(join(wt, 'wip.txt'), 'uncommitted fixture line\n')
    if (ownConfigInWorktree) {
      mkdirSync(join(wt, '.pi/team'), { recursive: true })
      writeFileSync(join(wt, '.pi/team/config.sh'), readFileSync(join(base, '.pi/team/config.sh'), 'utf8'))
    }
    wts[seat] = wt
  }
  return { base, wt: wts[seats[0]], wts, state: join(base, '.pi/team/state') }
}

/** /proc/<pid>/stat 的启动时间指纹（第 22 字段），与扩展同一规则 —— 手写记录要用真指纹。 */
const procStartTime = pid => {
  try {
    const stat = readFileSync(`/proc/${pid}/stat`, 'utf8')
    const rest = stat.slice(stat.lastIndexOf(')') + 1).trim().split(/\s+/)
    return rest[19] ?? ''
  } catch {
    return ''
  }
}

/** 写一条 `state/bg/<id>.job` 记录（与 team-bg 的记录同形状）。 */
const writeRecord = (bgDir, id, { pid, pgid = pid, start, cwd = '', log = '', cmd = 'fixture' }) => {
  mkdirSync(bgDir, { recursive: true })
  writeFileSync(join(bgDir, `${id}.job`),
    `id=${id}\npid=${pid}\npgid=${pgid}\nstart=${start}\ncwd=${cwd}\nlog=${log}\ncmd=${cmd}\n`)
}
const spawnSleep = (seconds) => {
  const child = spawn('sleep', [String(seconds)], { stdio: 'ignore' })
  trackPid(child.pid)
  return child
}
const reapedPid = async () => {
  const child = spawnSleep(0.05)
  const pid = child.pid
  await new Promise(r => child.on('exit', r))
  trackedPids.delete(pid)
  return pid
}

// ── 通知侧驱动 ────────────────────────────────────────────────────────────────
const newNotify = async () => {
  const mod = await loadModule(resolve(NOTIFY))
  const handlers = {}
  mod.default({
    on: (name, fn) => { (handlers[name] ||= []).push(fn) },
    registerCommand: () => {},
    registerTool: () => {},
    sendMessage: () => {},
  })
  const settled = handlers.agent_settled?.[0]
  if (typeof settled !== 'function') throw new Error('notify 扩展没有注册 agent_settled')
  return {
    settle: (cwd, stopReason, text) => settled({}, {
      cwd,
      sessionManager: { getEntries: () => [{ message: { role: 'assistant', stopReason, content: [{ text }] } }] },
    }),
  }
}
const resetNotify = (base, agent = 'dev') => {
  rmSync(join(base, '.pi/team/state/notify-dedup'), { force: true })
  rmSync(join(base, 'docs/team/inbox', `${agent}.md`), { force: true })
}
const inboxLine = (base, agent = 'dev') => {
  const file = join(base, 'docs/team/inbox', `${agent}.md`)
  const lines = existsSync(file) ? readFileSync(file, 'utf8').trim().split('\n').filter(Boolean) : []
  return lines.at(-1) ?? ''
}

// ── wording：注册工具面的挂起口径 ─────────────────────────────────────────────
const groupWording = async () => {
  const mod = await loadModule(BG)
  const host = newBgHost(mod)
  const R = makeRunner(host, ROOT)
  const receipt = await R.run('echo P230-wording', jobName('wording-receipt'))
  const texts = {
    'team_bg_run.description': String(host.tools.team_bg_run?.description ?? ''),
    'team_bg_run.promptSnippet': String(host.tools.team_bg_run?.promptSnippet ?? ''),
    'team_bg_run.promptGuidelines': (host.tools.team_bg_run?.promptGuidelines ?? []).join(' '),
    'team_bg_run.start-result': receipt.text,
    'team_bg_wait.description': String(host.tools.team_bg_wait?.description ?? ''),
  }



  // 完成叫醒：多条合并成一条、点名每个 id、指 team_bg_wait（既有行为，钉住）。
  // 先把回执作业收割掉（否则它会带着自己的叫醒混进下面那条合并消息的窗口）。
  await R.wait(receipt.id, 5000)
  const before = host.sent.length
  const a = await R.run('sleep 0.25; echo WAKE-A', jobName('wording-wake-a'))
  const b = await R.run('sleep 0.3; echo WAKE-B', jobName('wording-wake-b'))
  const named = m => { const s = String(m?.msg?.content ?? ''); return s.includes(a.id) && s.includes(b.id) }
  const woke = await waitFor(() => host.sent.slice(before).some(named), 5000)
  const merged = host.sent.slice(before)
  const body = String(merged[0]?.msg?.content ?? '')
  check('wording: the merged completion wake-up still names both ids and team_bg_wait',
    woke && merged.length === 1 && body.includes(a.id) && body.includes(b.id) && body.includes('team_bg_wait'),
    `messages=${merged.length} ids=${a.id},${b.id} body=${body.split('\n')[0]}`)
  await R.wait(a.id, 5000)
  await R.wait(b.id, 5000)
  await host.emit('session_shutdown', { reason: 'fixture' }, { cwd: ROOT })
}

// ── ledger：state/bg.log 的 start / wait 两类新行 ─────────────────────────────
const groupLedger = async () => {
  const mod = await loadModule(BG)
  const host = newBgHost(mod)
  const R = makeRunner(host, ROOT)
  const STATE = join(ROOT, '.pi/team/state')

  // ① start 行与 .job 记录同点位、在返回 id 之前就落盘：作业还在跑（sleep 2）时读盘
  const j1 = await R.run('sleep 2; echo LEDGER-1', jobName('lg-start'))
  const startLine = ledgerFor(STATE, j1.id, 'start')
  check('ledger: the start line lands on disk before the id is returned',
    !!startLine && new RegExp(` start id=${escapeRe(j1.id)} pid=${j1.pid}$`).test(startLine) &&
    existsSync(join(STATE, 'bg', `${j1.id}.job`)),
    startLine || '(no start line)')
  await R.wait(j1.id, 5000)

  // ② 原地收割：wait 行量的是这次调用（≈ 作业运行时长）
  const j2 = await R.run('sleep 1.1; echo LEDGER-2', jobName('lg-inline'))
  await R.wait(j2.id, 5000)
  const w2 = ledgerFor(STATE, j2.id, 'wait')
  const s2 = waitedOf(w2)
  check('ledger: an inline harvest records a wait line tracking the job runtime',
    / outcome=harvested /.test(w2) && s2 >= 0.7 && s2 <= 2.5, w2 || '(no wait line)')
  const inlineSettled = ledgerLines(STATE).some(l => / settled-with-unharvested=\d/.test(l) && l.includes(j2.id))
  check('ledger: the inline pattern has no suspension line naming it', !inlineSettled,
    ledgerLines(STATE).filter(l => l.includes(j2.id)).join(' | '))

  // ③ 超时：outcome=running，且作业没有因此被标成已收割（完成后照常叫醒）
  const j3 = await R.run('sleep 1.0; echo LEDGER-3', jobName('lg-timeout'))
  const timeoutText = await R.wait(j3.id, 250)
  const w3 = ledgerFor(STATE, j3.id, 'wait')
  const s3 = waitedOf(w3)
  check('ledger: a timed-out wait records outcome=running with this call’s own wait',
    / outcome=running /.test(w3) && s3 >= 0.1 && s3 <= 0.8 && /still running/.test(timeoutText), w3 || '(no wait line)')
  const beforeWake3 = host.sent.length
  const woke3 = await waitFor(() => host.sent.slice(beforeWake3).some(m => String(m.msg?.content ?? '').includes(j3.id)), 5000)
  check('ledger: a timed-out wait leaves the job unharvested (it still wakes)',
    woke3, `wakes=${host.sent.length - beforeWake3}`)
  await R.wait(j3.id, 5000)

  // ④ 中止（AbortSignal）：outcome=interrupted，同样不标收割
  const j4 = await R.run('sleep 1.2; echo LEDGER-4', jobName('lg-abort'))
  const ac = new AbortController()
  setTimeout(() => ac.abort(), 200)
  const abortText = await R.wait(j4.id, undefined, ac.signal)
  const w4 = ledgerFor(STATE, j4.id, 'wait')
  const s4 = waitedOf(w4)
  check('ledger: an aborted wait records outcome=interrupted with this call’s own wait',
    / outcome=interrupted /.test(w4) && s4 >= 0.05 && s4 <= 1.0, w4 || '(no wait line)')
  const beforeWake4 = host.sent.length
  const woke4 = await waitFor(() => host.sent.slice(beforeWake4).some(m => String(m.msg?.content ?? '').includes(j4.id)), 5000)
  check('ledger: an aborted wait leaves the job unharvested (it still wakes)',
    woke4, `wakes=${host.sent.length - beforeWake4} abort="${abortText.split('\n')[0]}"`)
  await R.wait(j4.id, 5000)

  // ⑤ 挂起：start → settled-with-unharvested（点名该 id）→ wake（点名该 id）→ wait（waited_s≈0）
  const beforeWake5 = host.sent.length
  const j5 = await R.run('sleep 0.6; echo LEDGER-5', jobName('lg-suspend'))
  await host.emit('agent_settled', {}, { cwd: ROOT })
  const settled = ledgerLines(STATE)
    .filter(l => / settled-with-unharvested=\d/.test(l) && l.includes(j5.id)).at(-1) ?? ''
  const woke5 = await waitFor(() => host.sent.slice(beforeWake5).some(m => String(m.msg?.content ?? '').includes(j5.id)), 5000)
  const wakeLine = ledgerLines(STATE).filter(l => / wake count=/.test(l)).at(-1) ?? ''
  await R.wait(j5.id, 5000)
  const w5 = ledgerFor(STATE, j5.id, 'wait')
  const s5 = waitedOf(w5)
  const lines = ledgerLines(STATE)
  const iStart = lines.findIndex(l => new RegExp(` start id=${escapeRe(j5.id)}( |$)`).test(l))
  const iSettled = lines.findIndex(l => new RegExp(` settled-with-unharvested=1 jobs=${escapeRe(j5.id)}:running`).test(l))
  const iWait = lines.findIndex(l => new RegExp(` wait id=${escapeRe(j5.id)}( |$)`).test(l))
  check('ledger: a suspension is distinguishable from an inline wait from the ledger alone',
    woke5 && !!settled && wakeLine.includes(j5.id) && / outcome=harvested /.test(w5) &&
    s5 >= 0 && s5 < 0.4 && iStart >= 0 && iStart < iSettled && iSettled < iWait && s2 >= 0.7,
    `settled=[${settled}] wake=[${wakeLine}] wait=[${w5}] inline_wait=${s2}s suspend_wait=${s5}s`)

  // ⑥ 既有行形状不变（wake / settled-with-unharvested）；start / wait 是这里新增的两类
  const iso = '\\d{4}-\\d{2}-\\d{2}T[\\d:.]+Z'
  check('ledger: the wake line keeps its shape',
    lines.some(l => new RegExp(`^${iso} wake count=\\d+ ids=[A-Za-z0-9._,-]+$`).test(l)),
    lines.find(l => / wake /.test(l)) ?? '(none)')
  check('ledger: the settled line keeps its shape',
    lines.some(l => new RegExp(`^${iso} settled-with-unharvested=\\d+( jobs=[A-Za-z0-9._,-:]+)?$`).test(l)),
    lines.find(l => / settled-with-unharvested=\d/.test(l)) ?? '(none)')
  const newLines = lines.filter(l => / (start|wait) /.test(l))
  check('ledger: the start and wait lines have the documented shape',
    newLines.length >= 8 && newLines.every(l =>
      new RegExp(`^${iso} start id=[A-Za-z0-9._-]+ pid=\\d+$`).test(l) ||
      new RegExp(`^${iso} wait id=[A-Za-z0-9._-]+ outcome=(harvested|running|interrupted) waited_s=\\d+(\\.\\d+)?$`).test(l)),
    newLines.slice(0, 3).join(' | '))

  // ⑦ spawn-error 行形状不变（既有形状，逐字节）：PATH 里只留 git（findRoot 还要用它），没有 bash
  {
    const fakeBin = join(SCRATCH, 'fake-bin')
    rmSync(fakeBin, { recursive: true, force: true })
    mkdirSync(fakeBin, { recursive: true })
    symlinkSync(execFileSync('bash', ['-c', 'command -v git'], { encoding: 'utf8' }).trim(), join(fakeBin, 'git'))
    const savedPath = process.env.PATH
    process.env.PATH = fakeBin
    let badJob
    try {
      badJob = await R.run('true', jobName('lg-spawn-error'))
    } finally {
      process.env.PATH = savedPath
    }
    const want = new RegExp(` spawn-error id=${escapeRe(badJob.id)} `)
    await waitFor(() => ledgerLines(STATE).some(l => want.test(l)), 3000)
    const spawnLine = ledgerLines(STATE).find(l => want.test(l)) ?? ''
    check('ledger: the spawn-error line keeps its shape (and a failed spawn records no start)',
      !!spawnLine && new RegExp(`^${iso} spawn-error id=${escapeRe(badJob.id)} \\S`).test(spawnLine) &&
      !ledgerLines(STATE).some(l => new RegExp(` start id=${escapeRe(badJob.id)}( |$)`).test(l)),
      spawnLine || '(no spawn-error line)')
  }

  // ⑧ 重启（会话级 job 表）：新会话拒绝旧 id、不收养、不剪记录；作业本身不受影响
  {
    const j8 = await R.run('sleep 2.5; echo RESTART-EVIDENCE', jobName('lg-restart'))
    const record = join(STATE, 'bg', `${j8.id}.job`)
    const logFile = join(STATE, 'bg', `${j8.id}.log`)
    const host2 = newBgHost(await loadModule(BG))
    await host2.emit('session_start', { reason: 'restart' }, { cwd: ROOT })
    const R2 = makeRunner(host2, ROOT)
    let errText = ''
    try { await R2.wait(j8.id, 0) } catch (error) { errText = String(error?.message ?? error) }
    let alive = false
    try { process.kill(j8.pid, 0); alive = true } catch { /* 作业已经不在 */ }
    check('ledger: a restarted session refuses the old id and keeps the evidence',
      /unknown job/.test(errText) && /started: \(none\)/.test(errText) &&
      existsSync(record) && existsSync(logFile) && alive,
      `err=${errText.slice(0, 80)} record=${existsSync(record)} log=${existsSync(logFile)} alive=${alive}`)
    const own = await R2.run('echo NEW-SESSION', jobName('lg-restart-own'))
    await R2.wait(own.id, 3000)
    await host2.emit('agent_settled', {}, { cwd: ROOT })
    const adopted = host2.sent.some(m => String(m.msg?.content ?? '').includes(j8.id))
    check('ledger: a restarted session neither re-adopts nor prunes the old records',
      !adopted && existsSync(record) && existsSync(logFile),
      `adopted=${adopted} record=${existsSync(record)} log=${existsSync(logFile)}`)
    await host2.emit('session_shutdown', { reason: 'fixture' }, { cwd: ROOT })
    await R.wait(j8.id, 5000)
  }
  await host.emit('session_shutdown', { reason: 'fixture' }, { cwd: ROOT })
}

// ── suspend-shape：turn-end 通知的挂起判定 ────────────────────────────────────
const groupSuspendShape = async () => {
  const bgMod = await loadModule(BG)
  const bgHost = newBgHost(bgMod)
  const notify = await newNotify()
  const jobs = []

  // ① 完成 + 活记录（真作业真记录）→ suspended + awaiting + 省略 ⚠ + 保留 uncommitted
  {
    const b = makeBase('suspend')
    const R = makeRunner(bgHost, b.wt)
    const job = await R.run('sleep 30', jobName('sus-live'))
    jobs.push([R, job])
    resetNotify(b.base)
    await notify.settle(b.wt, 'stop', 'BG-LEDGER-SUSPEND completed turn parked on the job')
    const line = inboxLine(b.base)
    check('suspend: a completed turn with a live job record is tagged suspended',
      line.includes('[auto·suspended]') && line.includes(`awaiting=${job.id}`) &&
      /uncommitted=[1-9]/.test(line) && !line.includes('⚠ 未提交'),
      line || '(no inbox line)')
  }

  // ② 完成 + 无记录 → 今天的形状逐字节不变（[auto] + 脏树告警、无 awaiting）
  {
    const b = makeBase('clean')
    resetNotify(b.base)
    await notify.settle(b.wt, 'stop', 'BG-LEDGER-CLEAN completed turn with nothing running')
    const line = inboxLine(b.base)
    check('suspend: a completed turn with no running jobs stays in today’s shape',
      line.includes('[auto] ') && !line.includes('awaiting=') && line.includes('⚠ 未提交'),
      line || '(no inbox line)')
  }

  // ③ 死 pid → 不挂起
  {
    const b = makeBase('dead')
    const pid = await reapedPid()
    // cwd 指到本会话的工作树：本用例判的只是身份指纹（不让归属判据替它挡枪），
    // 否则「去掉身份验证」的翻转会被归属判据掩盖而不再变红（P236 实测）。
    writeRecord(join(b.state, 'bg'), 'bg-ledger-dead', { pid, pgid: pid, start: '1', cwd: b.wt })
    resetNotify(b.base)
    await notify.settle(b.wt, 'stop', 'BG-LEDGER-DEAD dead pid must not suspend')
    const line = inboxLine(b.base)
    check('suspend: a dead pid does not suspend',
      line.includes('[auto] ') && !line.includes('awaiting=') && line.includes('⚠ 未提交'),
      line || '(no inbox line)')
  }

  // ④ pid 复用（活着但启动指纹对不上）→ 不挂起
  {
    const b = makeBase('reused')
    const sleeper = spawnSleep(30)
    writeRecord(join(b.state, 'bg'), 'bg-ledger-reused', { pid: sleeper.pid, pgid: sleeper.pid, start: '1', cwd: b.wt })
    resetNotify(b.base)
    await notify.settle(b.wt, 'stop', 'BG-LEDGER-REUSED reused pid must not suspend')
    const line = inboxLine(b.base)
    check('suspend: a reused pid (fingerprint mismatch) does not suspend',
      line.includes('[auto] ') && !line.includes('awaiting=') && line.includes('⚠ 未提交'),
      line || '(no inbox line)')
    try { process.kill(sleeper.pid, 'SIGKILL') } catch { /* ignore */ }
  }

  // ⑤ 畸形 / 不可读记录（非数字 pid、缺 start、目录、软链）→ 都不算在跑
  {
    const b = makeBase('malformed')
    const sleeper = spawnSleep(30)
    const bgDir = join(b.state, 'bg')
    writeRecord(bgDir, 'bg-ledger-badpid', { pid: 'abc', pgid: '1', start: '1' })
    writeFileSync(join(bgDir, 'bg-ledger-nostart.job'),
      `id=bg-ledger-nostart\npid=${sleeper.pid}\npgid=${sleeper.pid}\ncwd=\nlog=\ncmd=fixture\n`)
    mkdirSync(join(bgDir, 'bg-ledger-dir.job'), { recursive: true })
    const target = join(bgDir, 'bg-ledger-link-target')
    writeFileSync(target, `id=bg-ledger-link-target\npid=${sleeper.pid}\npgid=${sleeper.pid}\nstart=1\ncwd=\nlog=\ncmd=fixture\n`)
    symlinkSync(target, join(bgDir, 'bg-ledger-link.job'))
    resetNotify(b.base)
    await notify.settle(b.wt, 'stop', 'BG-LEDGER-MALFORMED malformed records must not suspend')
    const line = inboxLine(b.base)
    check('suspend: an unreadable or malformed record does not suspend',
      line.includes('[auto] ') && !line.includes('awaiting=') && line.includes('⚠ 未提交'),
      line || '(no inbox line)')
    try { process.kill(sleeper.pid, 'SIGKILL') } catch { /* ignore */ }
  }

  // ⑥ 中断 + 活记录 → 保持 [auto·interrupted] 且带 awaiting=
  {
    const b = makeBase('interrupted')
    const R = makeRunner(bgHost, b.wt)
    const job = await R.run('sleep 30', jobName('int-live'))
    jobs.push([R, job])
    resetNotify(b.base)
    await notify.settle(b.wt, 'toolUse', 'BG-LEDGER-INTERRUPTED incomplete turn with a running job')
    const line = inboxLine(b.base)
    check('suspend: an interrupted turn with a running job keeps the interrupted tag and names it',
      line.includes('[auto·interrupted]') && line.includes(`awaiting=${job.id}`),
      line || '(no inbox line)')
  }

  // ⑦ worktree 自带 config → 用车道自己的目录；主工作树的活诱饵不算
  {
    const b = makeBase('wtown', { ownConfigInWorktree: true })
    const own = await makeRunner(bgHost, b.wt).run('sleep 30', jobName('own-worktree'))
    const decoy = await makeRunner(bgHost, b.base).run('sleep 30', jobName('decoy-main'))
    jobs.push([makeRunner(bgHost, b.wt), own], [makeRunner(bgHost, b.base), decoy])
    check('suspend: fixture — the linked worktree carries its own config',
      existsSync(join(b.wt, '.pi/team/config.sh')) &&
      existsSync(join(b.wt, '.pi/team/state/bg', `${own.id}.job`)) &&
      existsSync(join(b.state, 'bg', `${decoy.id}.job`)),
      `wt=${b.wt}`)
    resetNotify(b.base)
    await notify.settle(b.wt, 'stop', 'BG-LEDGER-WTOWN worktree-with-config lane records')
    const line = inboxLine(b.base)
    check('suspend: a worktree carrying its own config uses its own lane records',
      line.includes('[auto·suspended]') && line.includes(`awaiting=${own.id}`) && !line.includes(decoy.id),
      line || '(no inbox line)')
  }

  // ⑧ 显式 TEAM_STATE_DIR → 就是车道目录；notify 自己 root 下的活诱饵不算
  {
    const b = makeBase('statedir')
    const lane = join(SCRATCH, 'statedir-lane')
    rmSync(lane, { recursive: true, force: true })
    process.env.TEAM_STATE_DIR = lane
    let own
    try { own = await makeRunner(bgHost, b.wt).run('sleep 30', jobName('own-statedir')) } finally { delete process.env.TEAM_STATE_DIR }
    const decoy = await makeRunner(bgHost, b.base).run('sleep 30', jobName('decoy-statedir'))
    jobs.push([makeRunner(bgHost, b.wt), own], [makeRunner(bgHost, b.base), decoy])
    check('suspend: fixture — the explicit state directory holds the lane record',
      existsSync(join(lane, 'bg', `${own.id}.job`)) && existsSync(join(b.state, 'bg', `${decoy.id}.job`)),
      `lane=${lane}`)
    resetNotify(b.base)
    process.env.TEAM_STATE_DIR = lane
    try { await notify.settle(b.wt, 'stop', 'BG-LEDGER-STATEDIR explicit state directory') } finally { delete process.env.TEAM_STATE_DIR }
    const line = inboxLine(b.base)
    check('suspend: an explicit TEAM_STATE_DIR is the lane’s directory',
      line.includes('[auto·suspended]') && line.includes(`awaiting=${own.id}`) && !line.includes(decoy.id),
      line || '(no inbox line)')
  }

  // 收尾：只按登记过的作业停（kill + 收割），然后清掉扩展的会话资源
  for (const [R, job] of jobs) await R.stop(job)
  await bgHost.emit('session_shutdown', { reason: 'fixture' }, { cwd: ROOT })
}

// ── owner-scope：挂起判定只认**本会话自己的**作业（P236）────────────────────────
// 缺陷现场（2026-10-12 真实运行）：两个席位共享同一个车道 state 目录，dev 的作业躺在里面，
// dev2 结束回合时被打上 awaiting=<dev 的作业>。归属判据 = 记录里的 cwd（作业启动时的工作目录，
// 也就是拥有它的那个席位的工作树）与本会话自己的工作树/cwd 解析到同一个真实路径；别人的记录、
// 缺 cwd / 相对 cwd / 解析不出来的畸形记录一律不算（fail-closed）。
const groupOwnerScope = async () => {
  const bgMod = await loadModule(BG)
  const bgHost = newBgHost(bgMod)
  const notify = await newNotify()
  const jobs = []

  // ① 三个席位各有自己的活作业：各自只认自己的 id（另外两个席位的作业既不入 awaiting 也不改标签）
  {
    const b = makeBase('owner-two', { seats: ['dev', 'dev2', 'dev3'] })
    const seats = ['dev', 'dev2', 'dev3']
    const tag = { dev: 'own-a', dev2: 'own-b', dev3: 'own-c' } // 后缀互不为前缀（否则子串断言会互相命中）
    const own = {}
    for (const seat of seats) {
      const R = makeRunner(bgHost, b.wts[seat])
      own[seat] = await R.run('sleep 30', jobName(tag[seat]))
      jobs.push([R, own[seat]])
      resetNotify(b.base, seat)
    }
    for (const seat of seats) {
      await notify.settle(b.wts[seat], 'stop', `BG-LEDGER-OWNER-THREE ${seat} settles with its own job`)
      const line = inboxLine(b.base, seat)
      const others = seats.filter(s => s !== seat).map(s => own[s].id)
      check(`owner-scope: each seat suspends on its own job only (${seat})`,
        line.includes('[auto·suspended]') && line.includes(`awaiting=${own[seat].id}`) && others.every(id => !line.includes(id)),
        line || '(no inbox line)')
    }
  }

  // ② 只有一个席位有作业：**另外两个席位**（dev2、dev3）都不得出现 awaiting= / suspended
  //    （PM 在真实运行里两处都看到了：PM 2026-10-12 追加，dev3 的回合同样带着 dev 的 awaiting=）
  {
    const b = makeBase('owner-idle', { seats: ['dev', 'dev2', 'dev3'] })
    const rDev = makeRunner(bgHost, b.wt)
    const jDev = await rDev.run('sleep 30', jobName('own-busy'))
    jobs.push([rDev, jDev])
    for (const seat of ['dev2', 'dev3']) {
      resetNotify(b.base, seat)
      await notify.settle(b.wts[seat], 'stop', `BG-LEDGER-OWNER-IDLE ${seat} must not inherit the busy seat’s job`)
      const line = inboxLine(b.base, seat)
      check(`owner-scope: a seat with no job of its own is not suspended by another seat’s job (${seat})`,
        line.includes('[auto] ') && !line.includes('awaiting=') && !line.includes('suspended') && line.includes('⚠ 未提交'),
        line || '(no inbox line)')
    }
  }

  // ③ 活 pid 的畸形记录：缺 cwd / 相对 cwd / 解析不出来的 cwd → 都不判挂起（fail-closed）
  {
    const b = makeBase('owner-nocwd')
    const sleeper = spawnSleep(30)
    const start = procStartTime(sleeper.pid)
    const bgDir = join(b.state, 'bg')
    mkdirSync(bgDir, { recursive: true })
    writeFileSync(join(bgDir, 'bg-ledger-nocwd.job'),
      `id=bg-ledger-nocwd\npid=${sleeper.pid}\npgid=${sleeper.pid}\nstart=${start}\nlog=\ncmd=fixture\n`)
    writeRecord(bgDir, 'bg-ledger-relcwd', { pid: sleeper.pid, pgid: sleeper.pid, start, cwd: '.worktrees/dev' })
    writeRecord(bgDir, 'bg-ledger-gonecwd', { pid: sleeper.pid, pgid: sleeper.pid, start, cwd: '/nonexistent/p236/worktree' })
    resetNotify(b.base)
    await notify.settle(b.wt, 'stop', 'BG-LEDGER-NOCWD records without an owning cwd must not suspend')
    const line = inboxLine(b.base)
    check('owner-scope: a live record with a missing, relative or unresolvable cwd does not suspend (fail-closed)',
      line.includes('[auto] ') && !line.includes('awaiting=') && line.includes('⚠ 未提交'),
      line || '(no inbox line)')
    try { process.kill(sleeper.pid, 'SIGKILL') } catch { /* ignore */ }
  }

  // ④ 软链 + 尾斜杠：记录里的 cwd 文本不同、真实路径相同 → 仍然是本会话的作业（挂起）
  {
    const b = makeBase('owner-realpath')
    const sleeper = spawnSleep(30)
    const link = join(b.base, 'link-to-dev')
    symlinkSync(b.wt, link)
    writeRecord(join(b.state, 'bg'), 'bg-ledger-symlink', {
      pid: sleeper.pid, pgid: sleeper.pid, start: procStartTime(sleeper.pid), cwd: `${link}/`,
    })
    resetNotify(b.base)
    await notify.settle(b.wt, 'stop', 'BG-LEDGER-REALPATH symlink and trailing slash resolve to the seat worktree')
    const line = inboxLine(b.base)
    check('owner-scope: a job cwd reaching the session worktree through a symlink still belongs to it',
      line.includes('[auto·suspended]') && line.includes('awaiting=bg-ledger-symlink'),
      line || '(no inbox line)')
    try { process.kill(sleeper.pid, 'SIGKILL') } catch { /* ignore */ }
  }

  // ⑤ 主工作树里起的作业（不属于任何席位工作树）→ 席位不判挂起
  {
    const b = makeBase('owner-main')
    const rMain = makeRunner(bgHost, b.base)
    const jMain = await rMain.run('sleep 30', jobName('own-main'))
    jobs.push([rMain, jMain])
    resetNotify(b.base)
    await notify.settle(b.wt, 'stop', 'BG-LEDGER-MAINJOB a main-worktree job must not suspend a seat')
    const line = inboxLine(b.base)
    check('owner-scope: a job started from the main worktree does not suspend a seat',
      line.includes('[auto] ') && !line.includes('awaiting=') && line.includes('⚠ 未提交'),
      line || '(no inbox line)')
  }

  // 收尾：只按登记过的作业停（kill + 收割），然后清掉扩展的会话资源
  for (const [R, job] of jobs) await R.stop(job)
  await bgHost.emit('session_shutdown', { reason: 'fixture' }, { cwd: ROOT })
}

// ── turn-notice-merge（merge / detail / wake）：写入侧合并 + 明细 + 叫醒 ──────────────
// 夹具驱动**真扩展 + 真 CLI**：扩展调 CLI 的 __inbox-write（per-recipient 锁 + 先明细后合并），
// harness 读收件箱 / state/notify.log / outbox 断言合同。CLI 路径从 --notify 派生：
//   <notify 的父目录>/../scripts/team —— 所以变异树（$MUT/<tag>/{extension,scripts}）能同时破坏扩展
//   与 CLI，而不会因为 skillDir() 找不到 CLI 变成假红。
const CLI = () => {
  const explicit = opt('cli')
  return explicit ? resolve(explicit) : resolve(dirname(NOTIFY), '..', 'scripts', 'team')
}
const runCliRaw = (base, args) => execFileSync('bash', [CLI(), '--root', base, ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] })
const runCliRc = (base, args) => {
  try { return { rc: 0, out: runCliRaw(base, args) } }
  catch (error) { return { rc: typeof error?.status === 'number' ? error.status : 1, out: `${error?.stdout ?? ''}${error?.stderr ?? ''}` } }
}
const inboxAll = (base, agent = 'dev') => {
  const f = join(base, 'docs/team/inbox', `${agent}.md`)
  return existsSync(f) && !lstatSync(f).isDirectory() ? readFileSync(f, 'utf8').split('\n').filter(Boolean) : []
}
const detailFileOf = base => join(base, '.pi/team/state/notify.log')
const detailRaw = base => {
  const f = detailFileOf(base)
  return existsSync(f) && !lstatSync(f).isDirectory() ? readFileSync(f, 'utf8') : ''
}
const detailEventCount = text => text.split('\n').filter(l => l.startsWith('- ')).length
const detailRecs = base => detailRaw(base).split('\n').filter(l => l.startsWith('- '))
const configAdd = (base, line) => writeFileSync(join(base, '.pi/team/config.sh'), `${line}\n`, { flag: 'a' })
const extLogOf = base => {
  const f = join(base, '.pi/team/state/notify-ext.log')
  return existsSync(f) && !lstatSync(f).isDirectory() ? readFileSync(f, 'utf8') : ''
}
const taskProof = (base, agent, id) => writeFileSync(join(base, '.pi/team/state', `${agent}.env`), `task=${id}\n`)
const liveRecord = (base, id, cwd) => {
  const child = spawnSleep(30)
  writeRecord(join(base, '.pi/team/state', 'bg'), id, { pid: child.pid, pgid: child.pid, start: procStartTime(child.pid), cwd })
  return child.pid
}
const dropRecord = (base, id) => rmSync(join(base, '.pi/team/state', 'bg', `${id}.job`), { force: true })
const killPid = pid => { try { process.kill(pid, 'SIGKILL') } catch { /* 已经不在了 */ } }
const tipOfLine = text => /tip=([0-9a-f]+)/.exec(text)?.[1] ?? ''
const isoOfLine = text => /^- (\S+) /.exec(text)?.[1] ?? ''
// 敲门的可观察面：① 还在 outbox 里的条目（含 held/）；② delivered.log（投递成功后会移出目录）。
// 只数 knock 的**行身份**（dedup 以 `line|` 开头）的条目 —— 旧键（摘要指纹）在这里则不会被数到。
const knockEntries = base => {
  const dir = join(base, '.pi/team/state/outbox')
  let n = 0
  const log = join(dir, 'delivered.log')
  if (existsSync(log)) for (const line of readFileSync(log, 'utf8').split('\n')) {
    const f = line.split('\t')
    if ((f[1] ?? '').startsWith('line|')) n++
  }
  const scan = d => {
    if (!existsSync(d)) return
    for (const f of readdirSync(d)) {
      const p = join(d, f)
      let st
      try { st = lstatSync(p) } catch { continue }
      if (st.isDirectory()) { if (f !== 'diagnostics') scan(p); continue }
      if (!f.endsWith('.msg')) continue
      try { if (/^dedup: line\|/m.test(readFileSync(p, 'utf8'))) n++ } catch { /* ignore */ }
    }
  }
  scan(dir)
  return n
}
const inboxNewCount = (base, agent = 'dev') => Number(/新 (\d+) 条/.exec(runCliRaw(base, ['inbox', agent]))?.[1] ?? 0)

// ── merge：合并键 / 合并行形状 / 尾行锚 / 既有读者 ─────────────────────────────
const groupMerge = async () => {
  const notify = await newNotify()

  // ① 首条事件的行逐字节形状不变；同 run 三条 → 一行 ×3 + 明细三条（首末时间点名首末事件）
  {
    const b = makeBase('merge-run')
    taskProof(b.base, 'dev', 'P230')
    resetNotify(b.base)
    await notify.settle(b.wt, 'stop', 'MERGE-RUN first summary')
    const l1 = inboxAll(b.base)[0] ?? ''
    const shape = new RegExp('^- \\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?Z (⚠ 未提交 \\d+ 个文件 · )?\\[auto\\] agent:dev · P230 · branch=task/P230-merge-run · uncommitted=\\d+ · unpushed=\\d+(\\(no-upstream\\))? · task=P230 tip=[0-9a-f]{12} :: MERGE-RUN first summary$')
    check('merge: a single-event line keeps today’s shape',
      shape.test(l1) && !l1.includes('×') && !l1.includes('first=') && !l1.includes('last='), l1 || '(no inbox line)')
    await notify.settle(b.wt, 'stop', 'MERGE-RUN second summary')
    await notify.settle(b.wt, 'stop', 'MERGE-RUN third summary')
    const ls = inboxAll(b.base)
    const dl = detailRecs(b.base)
    const line = ls[0] ?? ''
    check('merge: a run of same-key notifications is one line with its window',
      ls.length === 1 && /×3 first=\S+ last=\S+/.test(line) && dl.length === 3 &&
      isoOfLine(line) === isoOfLine(dl[0]) && /last=(\S+)/.exec(line)?.[1] === isoOfLine(dl[2]),
      `lines=${ls.length} detail=${dl.length} :: ${line}`)
    check('merge: the run’s summaries stay readable in the detail file',
      dl.some(r => r.includes('first summary')) && dl.some(r => r.includes('third summary')) && dl.every(r => !r.includes('×') && r.startsWith('- ')),
      dl.join(' | ').slice(0, 200))
  }

  // ② 汇总行取**最后一条**的值（uncommitted/tip/last）；取最大值、平均或第一条的值都在这里变红
  {
    const b = makeBase('merge-last')
    taskProof(b.base, 'dev', 'P230')
    resetNotify(b.base)
    for (const f of ['w2.txt', 'w3.txt', 'w4.txt']) writeFileSync(join(b.wt, f), 'x\n')
    await notify.settle(b.wt, 'stop', 'MERGE-LAST one')
    const rec1 = detailRecs(b.base).at(-1) ?? ''
    git(['add', '-A'], b.wt)
    git(['-c', 'user.email=fixture@teamsmith', '-c', 'user.name=fixture', 'commit', '-qm', 'merge-last one'], b.wt)
    writeFileSync(join(b.wt, 'w5.txt'), 'x\n')
    await notify.settle(b.wt, 'stop', 'MERGE-LAST two')
    rmSync(join(b.wt, 'w5.txt'), { force: true })
    await notify.settle(b.wt, 'stop', 'MERGE-LAST three')
    const rec3 = detailRecs(b.base).at(-1) ?? ''
    const line = inboxAll(b.base)[0] ?? ''
    const tip1 = tipOfLine(rec1); const tip3 = tipOfLine(rec3)
    check('merge: the merged line carries the last event’s values',
      tip1 !== '' && tip3 !== '' && tip1 !== tip3 && /uncommitted=0( |·)/.test(line) && line.includes(`tip=${tip3}`) &&
      !line.includes(`tip=${tip1}`) && /last=(\S+)/.exec(line)?.[1] === isoOfLine(rec3) && line.includes('×3'),
      `tip1=${tip1} tip3=${tip3} :: ${line}`)
  }

  // ③ 状态类变化必然新起一行（两个同 awaiting 的 suspended 不跨过 delivered 合并）
  {
    const b = makeBase('merge-class')
    resetNotify(b.base)
    const pA = liveRecord(b.base, 'J1', b.wt)
    await notify.settle(b.wt, 'stop', 'MERGE-CLASS suspended one')
    dropRecord(b.base, 'J1'); killPid(pA)
    await notify.settle(b.wt, 'stop', 'MERGE-CLASS delivered')
    const pB = liveRecord(b.base, 'J1', b.wt)
    await notify.settle(b.wt, 'stop', 'MERGE-CLASS suspended two')
    const ls = inboxAll(b.base)
    check('merge: a state-class change starts a new line',
      ls.length === 3 && ls[0].includes('[auto·suspended]') && ls[0].includes('awaiting=J1') && !ls[0].includes('×') &&
      ls[1].includes('[auto] ') && !ls[1].includes('awaiting=') && !ls[1].includes('×') &&
      ls[2].includes('[auto·suspended]') && ls[2].includes('awaiting=J1') && !ls[2].includes('×'),
      ls.join(' || ').slice(0, 240))
    // 只有类变、awaiting 集合不变：suspended → interrupted 也必须新起一行（键里的类分量单独可观测）
    await notify.settle(b.wt, 'aborted', 'MERGE-CLASS interrupted same job')
    const ls2 = inboxAll(b.base)
    check('merge: a class change with the same awaiting set starts a new line',
      ls2.length === 4 && ls2[3].includes('[auto·interrupted]') && ls2[3].includes('awaiting=J1') && !ls2[3].includes('×'),
      ls2.join(' || ').slice(0, 260))
    killPid(pB); dropRecord(b.base, 'J1')
  }

  // ④ 任务 / awaiting 集合任一变化都新起一行
  {
    const b = makeBase('merge-key')
    taskProof(b.base, 'dev', 'P230')
    resetNotify(b.base)
    const p1 = liveRecord(b.base, 'X1', b.wt)
    await notify.settle(b.wt, 'stop', 'MERGE-KEY awaiting one')
    dropRecord(b.base, 'X1'); killPid(p1)
    const p2 = liveRecord(b.base, 'X2', b.wt)
    await notify.settle(b.wt, 'stop', 'MERGE-KEY awaiting two')
    dropRecord(b.base, 'X2'); killPid(p2)
    const p3 = liveRecord(b.base, 'X3', b.wt)
    git(['checkout', '-q', '-b', 'task/P231-other'], b.wt)
    await notify.settle(b.wt, 'stop', 'MERGE-KEY other task')
    const ls = inboxAll(b.base)
    check('merge: a different task or awaiting set starts a new line',
      ls.length === 3 && ls[0].includes('awaiting=X1') && ls[1].includes('awaiting=X2') && ls[2].includes('awaiting=X3') &&
      ls.every(l => !l.includes('×')), `lines=${ls.length} :: ${ls.join(' || ').slice(0, 200)}`)
    killPid(p3); dropRecord(b.base, 'X3')
  }

  // ⑤ 跨席位：各写各的文件
  {
    const b = makeBase('merge-seats', { seats: ['dev', 'dev2'] })
    resetNotify(b.base, 'dev'); resetNotify(b.base, 'dev2')
    await notify.settle(b.wt, 'stop', 'MERGE-SEATS dev')
    await notify.settle(b.wts.dev2, 'stop', 'MERGE-SEATS dev2')
    const ld = inboxAll(b.base, 'dev'); const l2 = inboxAll(b.base, 'dev2')
    check('merge: a different seat’s run stays in its own file',
      ld.length === 1 && l2.length === 1 && ld[0].includes('agent:dev ') && !ld[0].includes('agent:dev2') && l2[0].includes('agent:dev2'),
      `dev=[${ld.join('||')}] dev2=[${l2.join('||')}]`)
  }

  // ⑥ awaiting 是集合：夹具预置的反序锚行与扩展的排序结果必须合并
  {
    const b = makeBase('merge-order')
    resetNotify(b.base)
    const pa = liveRecord(b.base, 'aaa', b.wt); const pz = liveRecord(b.base, 'zzz', b.wt)
    const branch = git(['rev-parse', '--abbrev-ref', 'HEAD'], b.wt)
    writeFileSync(join(b.base, 'docs/team/inbox/dev.md'),
      `- 2026-10-14T00:00:00Z [auto·suspended] agent:dev · P230 · branch=${branch} · uncommitted=1 · awaiting=zzz,aaa · unpushed=0\n`)
    await notify.settle(b.wt, 'stop', 'MERGE-ORDER second settle')
    const ls = inboxAll(b.base)
    const line = ls[0] ?? ''
    check('merge: the awaiting set’s order does not split a run',
      ls.length === 1 && line.includes('×2') && line.includes('awaiting=aaa,zzz'), line)
    killPid(pa); killPid(pz); dropRecord(b.base, 'aaa'); dropRecord(b.base, 'zzz')
  }

  // ⑦ 中间插入的手工通知结束 run，且本人逐字节不变
  {
    const b = makeBase('merge-break')
    resetNotify(b.base)
    await notify.settle(b.wt, 'stop', 'MERGE-BREAK one')
    const before = inboxAll(b.base)[0] ?? ''
    runCliRc(b.base, ['notify', 'dev', 'MERGE-BREAK manual notice'])
    const manual = inboxAll(b.base).at(-1) ?? ''
    await notify.settle(b.wt, 'stop', 'MERGE-BREAK two')
    const ls = inboxAll(b.base)
    check('merge: a notice appended between two events ends the run untouched',
      ls.length === 3 && ls[0] === before && ls[1] === manual && ls[1].includes('[manual]') &&
      ls[1].includes('MERGE-BREAK manual notice') && ls[2].includes('MERGE-BREAK two') && !ls[2].includes('×'),
      ls.join(' || ').slice(0, 240))
  }

  // ⑧ 去重窗口内的重复 settle 既不进明细也不推 ×N
  {
    const b = makeBase('merge-dedup')
    resetNotify(b.base)
    await notify.settle(b.wt, 'stop', 'MERGE-DEDUP same text')
    await notify.settle(b.wt, 'stop', 'MERGE-DEDUP same text')
    const ls = inboxAll(b.base); const dl = detailRecs(b.base)
    check('merge: a settle inside the dedup window neither counts nor records',
      ls.length === 1 && !ls[0].includes('×') && dl.length === 1, `lines=${ls.length} detail=${dl.length}`)
  }

  // ⑨ 行计数读者：合并行算一行；被后续事件扩展后仍是已读
  //    turn-notice-in-pm-inbox（A1）之后本席位自己的记录行**不计流量**（一次交付让待办 +1 而不是 +2），
  //    所以未读只能从**指针行**（docs/team/inbox/pm.md，agent: 是发送者）量：三条同键事件 = 一条指针行、
  //    ack 之后再来一条同键事件仍并进那一行 → 仍然已读。合并语义（×N 与首末窗口）在记录行与指针行
  //    两处同时验，所以这条仍然守着「合并」本身，而不是 A1 之前的计数。
  {
    const b = makeBase('merge-readers')
    resetNotify(b.base)
    for (const t of ['one', 'two', 'three']) await notify.settle(b.wt, 'stop', `MERGE-READERS ${t}`)
    const before = inboxNewCount(b.base, 'pm')
    runCliRc(b.base, ['inbox', 'pm', '--ack'])
    await notify.settle(b.wt, 'stop', 'MERGE-READERS four')
    const after = inboxNewCount(b.base, 'pm')
    const recLine = inboxAll(b.base)[0] ?? ''
    const pmLine = inboxAll(b.base, 'pm')[0] ?? ''
    check('merge: line-counting readers count a merged line once',
      before === 1 && after === 0 && inboxAll(b.base).length === 1 && inboxAll(b.base, 'pm').length === 1 &&
      /×4 first=\S+ last=\S+/.test(recLine) && /×4 first=\S+ last=\S+/.test(pmLine),
      `before=${before} after=${after} :: pm=${pmLine} || dev=${recLine}`)
  }

  // ⑩ 陈旧判据在合并行上读最后一条的 tip（更早的事件从明细里判）
  {
    const b = makeBase('merge-stale')
    taskProof(b.base, 'dev', 'P230')
    resetNotify(b.base)
    await notify.settle(b.wt, 'stop', 'MERGE-STALE one')
    const tip1 = tipOfLine(detailRecs(b.base).at(-1) ?? '')
    git(['add', '-A'], b.wt)
    git(['-c', 'user.email=fixture@teamsmith', '-c', 'user.name=fixture', 'commit', '-qm', 'merge-stale one'], b.wt)
    await notify.settle(b.wt, 'stop', 'MERGE-STALE two')
    const tip2 = tipOfLine(detailRecs(b.base).at(-1) ?? '')
    const line = inboxAll(b.base)[0] ?? ''
    mkdirSync(join(b.base, 'docs/team/reviews'), { recursive: true })
    writeFileSync(join(b.base, 'docs/team/reviews/P230.md'), `# P230\n\n- HEAD ${tip1}\n`)
    const reviewed = new RegExp(tip1).test(readFileSync(join(b.base, 'docs/team/reviews/P230.md'), 'utf8'))
    const judged = t => tip1.startsWith(t) || t.startsWith(tip1)
    check('merge: a merged line is judged by its last event, not as current state',
      /×2/.test(line) && tip1 !== tip2 && line.includes(`tip=${tip2}`) && !judged(tip2) && judged(tip1) && reviewed,
      `tip1=${tip1} tip2=${tip2} :: ${line}`)
  }
}

// ── detail：明细文件 / 轮转 / 读面缺口 ────────────────────────────────────────
const groupDetail = async () => {
  const notify = await newNotify()

  // ① 计数与记录一致；② 明细不是流量（记录不写收件箱行、不入队 knock）
  {
    const b = makeBase('detail-agree')
    resetNotify(b.base)
    await notify.settle(b.wt, 'stop', 'DETAIL one')
    await notify.settle(b.wt, 'stop', 'DETAIL two')
    await notify.settle(b.wt, 'stop', 'DETAIL three')
    const dl = detailRecs(b.base)
    const out = runCliRc(b.base, ['inbox', 'dev', '--detail']).out
    check('detail: a run’s count and its records agree',
      /×3/.test(inboxAll(b.base)[0] ?? '') && dl.length === 3 && /记录 3\/3 OK/.test(out),
      `recs=${dl.length} out=${out.split('\n').slice(0, 3).join(' / ')}`)
    check('detail: the detail file is not traffic',
      inboxAll(b.base).length === 1 && knockEntries(b.base) === 0,
      `lines=${inboxAll(b.base).length} knocks=${knockEntries(b.base)}`)
  }

  // ③ 轮转：搬走一代 + 新代轮转头（时间 / state/notify.log.1 / 事件数）+ 扩展日志点名
  {
    const b = makeBase('detail-rotate')
    configAdd(b.base, 'TEAM_NOTIFY_DETAIL_MAX=2')
    resetNotify(b.base)
    for (const t of ['one', 'two', 'three']) await notify.settle(b.wt, 'stop', `ROTATE ${t}`)
    const cur = detailRaw(b.base)
    const rotated = existsSync(`${detailFileOf(b.base)}.1`) ? readFileSync(`${detailFileOf(b.base)}.1`, 'utf8') : ''
    const log = existsSync(join(b.base, '.pi/team/state/notify-ext.log')) ? readFileSync(join(b.base, '.pi/team/state/notify-ext.log'), 'utf8') : ''
    check('detail: a rotated generation names where the older events went',
      /^# rotation \S+ moved=2 /.test(cur) && cur.includes('state/notify.log.1') && detailEventCount(cur) <= 2 && detailEventCount(rotated) === 2 && /rotated/.test(log),
      `head=${cur.split('\n')[0] ?? ''} curEvents=${detailEventCount(cur)} rotEvents=${detailEventCount(rotated)}`)
    for (const t of ['four', 'five', 'six', 'seven']) await notify.settle(b.wt, 'stop', `ROTATE ${t}`)
    const cur2 = detailRaw(b.base)
    check('detail: the bound holds as the file grows',
      detailEventCount(cur2) <= 2 && !existsSync(`${detailFileOf(b.base)}.2`),
      `curEvents=${detailEventCount(cur2)} generations=${existsSync(`${detailFileOf(b.base)}.1`) ? 1 : 0}`)
  }

  // ④ 缺文件：点名 state/notify.log 与 .1，非零退出，不假装完整
  {
    const b = makeBase('detail-missing')
    resetNotify(b.base)
    await notify.settle(b.wt, 'stop', 'GAP one')
    await notify.settle(b.wt, 'stop', 'GAP two')
    rmSync(detailFileOf(b.base), { force: true })
    const r = runCliRc(b.base, ['inbox', 'dev', '--detail'])
    check('detail: a missing record is named, not silent',
      r.rc !== 0 && r.out.includes('state/notify.log') && r.out.includes('state/notify.log.1') && !/记录 2\/2 OK/.test(r.out),
      `rc=${r.rc} :: ${r.out.replace(/\n/g, ' | ').slice(0, 220)}`)
  }

  // ⑤ 轮转后当前代缺记录：点名缺口与 .1，非零退出
  {
    const b = makeBase('detail-rotgap')
    configAdd(b.base, 'TEAM_NOTIFY_DETAIL_MAX=2')
    resetNotify(b.base)
    for (const t of ['one', 'two', 'three']) await notify.settle(b.wt, 'stop', `ROTGAP ${t}`)
    const r = runCliRc(b.base, ['inbox', 'dev', '--detail'])
    check('detail: a rotated run’s gap is named with the older generation',
      r.rc !== 0 && /缺口/.test(r.out) && r.out.includes('state/notify.log.1') && /×3/.test(r.out) && /记录 1\/3/.test(r.out),
      `rc=${r.rc} :: ${r.out.replace(/\n/g, ' | ').slice(0, 240)}`)
  }

  // ⑥ 只读：不 ack、未读数不变
  //    A1 之后本席位自己的记录行不计流量，所以未读用**同一个文件里的一条 [manual] 流量行**来量：
  //    `--detail` 读的是记录，它不能把这条流量行 ack 掉（否则 before=1 → after=0 立刻红）。
  {
    const b = makeBase('detail-readonly')
    resetNotify(b.base)
    await notify.settle(b.wt, 'stop', 'READONLY one')
    await notify.settle(b.wt, 'stop', 'READONLY two')
    runCliRc(b.base, ['notify', 'dev', 'READONLY manual notice'])
    const before = inboxNewCount(b.base)
    // --detail 在有缺口时**按契约非零退出**：夹具用 rc 宽容的调用（否则破坏树会把 harness 自身搞崩）
    runCliRc(b.base, ['inbox', 'dev', '--detail'])
    const after = inboxNewCount(b.base)
    check('detail: detail reading does not acknowledge', before === 1 && after === 1,
      `before=${before} after=${after} :: ${inboxAll(b.base).at(-1) ?? ''}`)
  }
}

// ── wake：只有写新行才入队 knock（合并的 settle 不叫醒）──────────────────────
const groupWake = async () => {
  const notify = await newNotify()
  const prevPane = process.env.TMUX_PANE
  // 敲门要「有 PM 窗口」的形状：TMUX_PANE 在进程内设就够（子进程继承）；假 tmux 由 bg-ledger.sh 在
  // **启动 runner 之前**放进 PATH —— bun 在启动时缓存 PATH，运行中改 process.env.PATH 对子进程查找无效。
  process.env.TMUX_PANE = 'p251-fixture-pane'
  try {
    // ① 交付：每个新行恰好一条 knock，同键合并的 settle 零条目
    {
      const b = makeBase('wake-once')
      configAdd(b.base, 'TEAM_NOTIFY_DEDUP_SEC=0')
      resetNotify(b.base)
      await notify.settle(b.wt, 'stop', 'WAKE-ONCE one')
      const k1 = knockEntries(b.base)
      await notify.settle(b.wt, 'stop', 'WAKE-ONCE two')
      const k2 = knockEntries(b.base)
      await notify.settle(b.wt, 'stop', 'WAKE-ONCE three')
      const k3 = knockEntries(b.base)
      check('wake: each new line wakes exactly once', k1 === 1 && k2 === 1 && k3 === 1, `k=${k1},${k2},${k3}`)
      // 合并的 settle 不敲：既不能新增条目（会被 outbox 自己的去重挡住，所以还要看扩展自己的账本）
      // 也不能走「入队」那条路径 —— 扩展日志里必须是 no knock（state=extended），零次 knock queued。
      const log3 = extLogOf(b.base)
      check('wake: a merged settle does not wake again',
        k3 === 1 && /×3/.test(inboxAll(b.base)[0] ?? '') && /no knock \(inbox write state=extended\)/.test(log3),
        `k=${k3} log=${log3.split('\n').filter(Boolean).slice(-3).join(' | ')}`)
    }

    // ② 挂起只记录、不叫醒（用户裁定 2026-10-14）：行与明细都在、queue 为空；同键合并也不叫醒
    {
      const b = makeBase('wake-suspended')
      configAdd(b.base, 'TEAM_NOTIFY_DEDUP_SEC=0')
      resetNotify(b.base)
      const pid = liveRecord(b.base, 'W2', b.wt)
      await notify.settle(b.wt, 'stop', 'WAKE-SUSPENDED one')
      const k1 = knockEntries(b.base)
      const line1 = inboxAll(b.base)[0] ?? ''
      const rec1 = detailRecs(b.base).length
      await notify.settle(b.wt, 'stop', 'WAKE-SUSPENDED two')
      const k2 = knockEntries(b.base)
      const line2 = inboxAll(b.base)[0] ?? ''
      const rec2 = detailRecs(b.base).length
      check('wake: a suspended line never wakes',
        k1 === 0 && line1.includes('[auto·suspended]') && line1.includes('awaiting=W2') && rec1 === 1,
        `k=${k1} recs=${rec1} :: ${line1}`)
      check('wake: a merged suspended run never wakes',
        k2 === 0 && /×2/.test(line2) && line2.includes('awaiting=W2') && rec2 === 2,
        `k=${k2} recs=${rec2} :: ${line2}`)
      killPid(pid); dropRecord(b.base, 'W2')
    }

    // ③ 状态类变化：挂起不叫醒，随后交付 / 中断各叫醒一次
    {
      const b = makeBase('wake-class')
      configAdd(b.base, 'TEAM_NOTIFY_DEDUP_SEC=0')
      resetNotify(b.base)
      const pid = liveRecord(b.base, 'W3', b.wt)
      await notify.settle(b.wt, 'stop', 'WAKE-CLASS suspended')
      const k0 = knockEntries(b.base)
      dropRecord(b.base, 'W3'); killPid(pid)
      await notify.settle(b.wt, 'stop', 'WAKE-CLASS delivered')
      const k1 = knockEntries(b.base)
      const pid2 = liveRecord(b.base, 'W3', b.wt)
      await notify.settle(b.wt, 'aborted', 'WAKE-CLASS interrupted')
      const k2 = knockEntries(b.base)
      check('wake: a class change away from suspended wakes once',
        k0 === 0 && k1 === 1 && k2 === 2,
        `k=${k0},${k1},${k2} :: ${inboxAll(b.base).map(l => l.slice(0, 60)).join(' || ')}`)
      killPid(pid2); dropRecord(b.base, 'W3')
    }

    // ④ 计数抖动不叫醒：先显式清掉上一条 knock（否则 outbox 自己的去重会替实现挡住这条断言）
    {
      const b = makeBase('wake-churn')
      configAdd(b.base, 'TEAM_NOTIFY_DEDUP_SEC=0')
      resetNotify(b.base)
      await notify.settle(b.wt, 'stop', 'WAKE-CHURN one')
      const k1 = knockEntries(b.base)
      runCliRc(b.base, ['outbox', 'drop', 'all'])
      const k0 = knockEntries(b.base)
      await notify.settle(b.wt, 'stop', 'WAKE-CHURN two')
      await notify.settle(b.wt, 'stop', 'WAKE-CHURN three')
      const k2 = knockEntries(b.base)
      check('wake: count churn does not wake',
        k1 >= 1 && k2 === k0 && /×3/.test(inboxAll(b.base)[0] ?? ''),
        `afterFirst=${k1} afterDrop=${k0} afterChurn=${k2} lines=${inboxAll(b.base).length}`)
    }

    // ⑤ 两条文本逐字相同的不同行（手工通知打断 + 夹具去掉 settle 去重簿）：行身份不互吞。
    // 不去掉 outbox 的去重窗口（默认 20s）：用摘要当键的破坏实现会被它摕下（这正是要红的地方）。
    // 不去掉 outbox 的去重窗口（默认 20s）：用摘要当键的破坏实现会被它摕下（这正是要红的地方）。
    {
      const b = makeBase('wake-identity')
      resetNotify(b.base)
      await notify.settle(b.wt, 'stop', 'WAKE-IDENTICAL text')
      runCliRc(b.base, ['notify', 'dev', 'WAKE-IDENTICAL break'])
      rmSync(join(b.base, '.pi/team/state/notify-dedup'), { force: true })
      await notify.settle(b.wt, 'stop', 'WAKE-IDENTICAL text')
      const ls = inboxAll(b.base)
      const stripped = l => l.replace(/^- \S+ /, '')
      check('wake: two text-identical lines are not conflated',
        ls.length === 3 && knockEntries(b.base) === 2 && ls[0] !== ls[2] && stripped(ls[0]) === stripped(ls[2]),
        `lines=${ls.length} knocks=${knockEntries(b.base)} :: ${ls.join(' || ').slice(0, 200)}`)
    }

    // ⑥ 写盘失败不叫醒（收件箱路径是个目录 → 追加必败）
    {
      const b = makeBase('wake-writefail')
      resetNotify(b.base)
      rmSync(join(b.base, 'docs/team/inbox/dev.md'), { force: true })
      mkdirSync(join(b.base, 'docs/team/inbox/dev.md'), { recursive: true })
      await notify.settle(b.wt, 'stop', 'WAKE-WRITEFAIL must not wake')
      const k = knockEntries(b.base)
      rmSync(join(b.base, 'docs/team/inbox/dev.md'), { recursive: true, force: true })
      check('wake: a failed inbox write does not wake', k === 0, `knocks=${k}`)
    }
  } finally {
    if (prevPane === undefined) delete process.env.TMUX_PANE
    else process.env.TMUX_PANE = prevPane
  }
}

// ── 主流程 ────────────────────────────────────────────────────────────────────
console.log(`bg-ledger-harness · root=${ROOT} · groups=${[...GROUPS].join(',')} · bg=${BG} · notify=${NOTIFY}`)
try {
  if (GROUPS.has('wording')) await groupWording()
  if (GROUPS.has('ledger')) await groupLedger()
  if (GROUPS.has('suspend-shape')) await groupSuspendShape()
  if (GROUPS.has('owner-scope')) await groupOwnerScope()
  if (GROUPS.has('merge')) await groupMerge()
  if (GROUPS.has('detail')) await groupDetail()
  if (GROUPS.has('wake')) await groupWake()
} catch (error) {
  check('harness: no unexpected exception', false, String(error?.stack ?? error).split('\n').slice(0, 3).join(' / '))
}
console.log(failures === 0 ? 'BG-LEDGER-HARNESS OK' : `BG-LEDGER-HARNESS FAIL (${failures})`)
process.exit(failures === 0 ? 0 : 1)
