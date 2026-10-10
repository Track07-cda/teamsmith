#!/usr/bin/env node
/**
 * P230 · long-job-suspend · A 刀夹具（`tests/bg-ledger.sh` 的确定性驱动）
 *
 *   <node|bun> bg-ledger-harness.mjs --bg <extension/team-bg.ts> --root <fixture repo> \
 *       [--notify <extension/team-notify.ts>] [--groups wording,ledger,suspend-shape] [--marker <pre>]
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
import { existsSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs'
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
const GROUPS = new Set(opt('groups', 'wording,ledger,suspend-shape').split(',').filter(Boolean))
if (!BG || !existsSync(BG)) {
  console.error('bg-ledger-harness: --bg <extension/team-bg.ts> 是必需的')
  process.exit(2)
}
if (!ROOT || !existsSync(join(ROOT, '.pi/team/config.sh'))) {
  console.error('bg-ledger-harness: --root <夹具仓库> 是必需的（它必须带 .pi/team/config.sh）')
  process.exit(2)
}
if (GROUPS.has('suspend-shape') && NOTIFY === '-') {
  console.error('bg-ledger-harness: suspend-shape 需要 --notify <extension/team-notify.ts>')
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

/** 一个独立夹具仓库：主工作树 + `.worktrees/dev` 链接工作树（默认不带 config —— 复现生产形状）。
 *  wip.txt 让树保持脏：挂起要证明「⚠ 前缀被省略」，非挂起形状要对出「前缀在」。 */
const makeBase = (name, { ownConfigInWorktree = false } = {}) => {
  const base = join(SCRATCH, 'bases', name)
  rmSync(base, { recursive: true, force: true })
  mkdirSync(join(base, '.pi/team/state'), { recursive: true })
  mkdirSync(join(base, 'docs/team/inbox'), { recursive: true })
  writeFileSync(join(base, '.pi/team/config.sh'),
    `TEAM_PROJECT="bg-ledger-${name}"\nTEAM_AGENTS="dev"\nTEAM_WORKTREES_DIR=".worktrees"\n` +
    `TEAM_NOTIFY_LOG="${base}/.pi/team/state/notify.log"\n`)
  writeFileSync(join(base, 'README.md'), `# bg-ledger fixture ${name}\n`)
  git(['init', '-q', '-b', 'main'], base)
  git(['add', 'README.md'], base)
  git(['-c', 'user.email=fixture@teamsmith', '-c', 'user.name=fixture', 'commit', '-qm', 'init'], base)
  const wt = join(base, '.worktrees', 'dev')
  git(['worktree', 'add', '-q', '-b', `task/P230-${name}`, wt], base)
  writeFileSync(join(wt, 'wip.txt'), 'uncommitted fixture line\n')
  if (ownConfigInWorktree) {
    mkdirSync(join(wt, '.pi/team'), { recursive: true })
    writeFileSync(join(wt, '.pi/team/config.sh'), readFileSync(join(base, '.pi/team/config.sh'), 'utf8'))
  }
  return { base, wt, state: join(base, '.pi/team/state') }
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
const resetNotify = base => {
  rmSync(join(base, '.pi/team/state/notify-dedup'), { force: true })
  rmSync(join(base, 'docs/team/inbox/dev.md'), { force: true })
}
const inboxLine = base => {
  const file = join(base, 'docs/team/inbox/dev.md')
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
  const hasDefault = t => /end your turn/i.test(t) && /completion wake-up/i.test(t) && /normal harvest point/i.test(t)
  const hasBudget = t => /inline-wait budget/i.test(t) && /2 minutes/.test(t)
  const hasBlocked = t => /blocks your immediate next step/i.test(t)
  const hasExclusive = t => /no other task work/i.test(t)
  const hasException = t => /bounded exception/i.test(t) && hasBudget(t) && hasBlocked(t) && hasExclusive(t)

  check('wording: team_bg_run description presents the suspend default',
    hasDefault(texts['team_bg_run.description']), texts['team_bg_run.description'].slice(0, 90))
  check('wording: team_bg_run prompt snippet presents the suspend default',
    hasDefault(texts['team_bg_run.promptSnippet']), texts['team_bg_run.promptSnippet'].slice(0, 90))
  check('wording: team_bg_run guidelines present the suspend default and the bounded exception',
    hasDefault(texts['team_bg_run.promptGuidelines']) && hasException(texts['team_bg_run.promptGuidelines']),
    texts['team_bg_run.promptGuidelines'].slice(0, 120))
  check('wording: the start result presents the suspend default and the bounded exception',
    hasDefault(texts['team_bg_run.start-result']) && hasException(texts['team_bg_run.start-result']),
    texts['team_bg_run.start-result'].split('\n').at(-1)?.slice(0, 120) ?? '')
  check('wording: team_bg_wait description names the three exception conditions and the budget',
    hasDefault(texts['team_bg_wait.description']) && hasException(texts['team_bg_wait.description']),
    texts['team_bg_wait.description'].slice(0, 120))

  // 旧措辞零命中：两个被点名的退休句 + 更宽的「回合结束前必须收割」与「叫醒=损失」形状。
  const retired = [
    'Harvest it with team_bg_wait before you end your turn',
    'harvest every job with team_bg_wait before ending your turn',
    'before you end your turn',
    'before ending your turn',
    'must not end with unharvested',
    'costs a turn',
  ]
  const offenders = []
  for (const [name, text] of Object.entries(texts)) {
    for (const phrase of retired) if (text.includes(phrase)) offenders.push(`${name} :: ${phrase}`)
    if (/\b(cost|penalt|loss|waste)/i.test(text)) offenders.push(`${name} :: loss framing`)
  }
  check('wording: the retired duty wording is gone from every registered text',
    offenders.length === 0, offenders.join(' | ') || 'clean')

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
    writeRecord(join(b.state, 'bg'), 'bg-ledger-dead', { pid, pgid: pid, start: '1' })
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
    writeRecord(join(b.state, 'bg'), 'bg-ledger-reused', { pid: sleeper.pid, pgid: sleeper.pid, start: '1' })
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

// ── 主流程 ────────────────────────────────────────────────────────────────────
console.log(`bg-ledger-harness · root=${ROOT} · groups=${[...GROUPS].join(',')} · bg=${BG} · notify=${NOTIFY}`)
try {
  if (GROUPS.has('wording')) await groupWording()
  if (GROUPS.has('ledger')) await groupLedger()
  if (GROUPS.has('suspend-shape')) await groupSuspendShape()
} catch (error) {
  check('harness: no unexpected exception', false, String(error?.stack ?? error).split('\n').slice(0, 3).join(' / '))
}
console.log(failures === 0 ? 'BG-LEDGER-HARNESS OK' : `BG-LEDGER-HARNESS FAIL (${failures})`)
process.exit(failures === 0 ? 0 : 1)
