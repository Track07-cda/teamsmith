#!/usr/bin/env node
// P442 private real Pi + private tmux + controlled loopback provider. No live team, credentials or model.
import assert from 'node:assert/strict'
import { createServer } from 'node:http'
import { spawnSync } from 'node:child_process'
import { appendFileSync, cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { setTimeout as delay } from 'node:timers/promises'

const tests = dirname(fileURLToPath(import.meta.url)), skill = dirname(tests)
const selection = (process.argv.find(a => a.startsWith('--select='))?.slice(9) ?? 'pm,large,identity,doctor').split(',')
const evidence = resolve(process.env.P442_EVIDENCE ?? `/var/tmp/p442-real-evidence-${Date.now()}`)
mkdirSync(evidence, { recursive: true, mode: 0o700 })
const temporary = mkdtempSync('/var/tmp/p442-real-'), socket = join(temporary, 'socket')
const pi = process.env.P442_PI ?? `${process.env.HOME}/.bun/bin/pi`, bunbin = dirname(pi)
mkdirSync(join(temporary, 'driver-home'))
const base = { HOME: join(temporary, 'driver-home'), PATH: `${bunbin}:/usr/local/bin:/usr/bin:/bin`, LANG: 'C.UTF-8',
  TERM: 'xterm-256color', USER: process.env.USER ?? 'fixture', LOGNAME: process.env.LOGNAME ?? 'fixture', TMPDIR: temporary }
const sh = value => `'${value.replaceAll("'", "'\\''")}'`
function command(bin, args, options = {}) {
  const result = spawnSync(bin, args, { encoding: 'utf8', env: base, ...options })
  assert.equal(result.error, undefined, `${bin}: ${result.error}`)
  assert.equal(result.status, 0, `${bin} ${args.join(' ')}: ${result.stderr}\n${result.stdout}`)
  return result.stdout
}
const tmux = (...args) => command('tmux', ['-S', socket, '-f', '/dev/null', ...args])
const json = path => JSON.parse(readFileSync(path, 'utf8'))
const jsonl = path => existsSync(path) ? readFileSync(path, 'utf8').trim().split('\n').filter(Boolean).map(line => JSON.parse(line)) : []
const snapshot = state => json(join(state, 'reminders/state.json'))
const events = info => jsonl(join(info.dir, 'events.jsonl'))
const requests = info => jsonl(join(info.dir, 'requests.jsonl'))
const plans = new Map()
let server, passed = 0, failed = 0
async function until(test, label) {
  const end = Date.now() + 90000 // Fixture watchdog, not a product latency claim.
  let last
  for (;;) {
    try { if (test()) return } catch (e) { last = e } // A snapshot/process may not exist on the first poll.
    if (Date.now() > end) throw new Error(`watchdog: ${label}: ${last?.message ?? 'condition stayed false'}`)
    await delay(50)
  }
}
function sse(res, { text = '', tool = null, name }) {
  res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive' })
  const emit = (delta, finish = null) => res.write(`data: ${JSON.stringify({ id: `p442-${name}`, object: 'chat.completion.chunk',
    created: 1, model: 'controlled', choices: [{ index: 0, delta, finish_reason: finish }] })}\n\n`)
  emit({ role: 'assistant', content: '' })
  if (text) emit({ content: text })
  if (tool) {
    emit({ tool_calls: [{ index: 0, id: `p442-call-${tool.n}`, type: 'function',
      function: { name: 'team_remind', arguments: JSON.stringify(tool.input) } }] }, 'tool_calls')
  } else emit({}, 'stop')
  res.end('data: [DONE]\n\n')
}
server = createServer(async (req, res) => {
  let raw = ''; for await (const chunk of req) raw += chunk
  const body = JSON.parse(raw), name = req.url.split('/')[1], plan = plans.get(name)
  if (!plan) { res.writeHead(404); res.end(); return }
  const n = plan.requests++
  appendFileSync(join(plan.dir, 'requests.jsonl'), JSON.stringify(body) + '\n')
  if (n === (plan.gateN ?? 0) && plan.gate) await plan.gate
  await plan.respond({ body, n, res, plan })
})
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve))
const port = server.address().port
function publishLaunch(info) {
  const source = `source ${sh(join(info.skill, 'scripts/lib/common.sh'))}; source ${sh(join(info.skill, 'scripts/lib/cmd-config.sh'))}; team_load_config; team_pm_metadata_publish p442-${info.name}`
  command('bash', ['-c', source], { cwd: info.root, env: info.env })
}
function doctor(info) {
  const result = spawnSync('bash', [join(info.skill, 'scripts/team'), '--root', info.root, 'doctor'],
    { cwd: info.root, env: { ...info.env, TMUX: `${socket},${info.serverPid},0`, TMUX_PANE: info.pane }, encoding: 'utf8' })
  const output = result.stdout + result.stderr
  writeFileSync(join(info.dir, `doctor-${Date.now()}.txt`), output)
  return output
}
async function start(name, respond, opts = {}) {
  const dir = join(evidence, name), root = join(temporary, name), home = join(root, 'home'), state = join(root, '.pi/team/state'), config = join(root, '.pi/team/config.sh')
  for (const path of [dir, home, join(home, '.pi/agent')]) mkdirSync(path, { recursive: true })
  const runSkill = opts.skillCopy ? join(root, 'skill') : skill
  if (opts.skillCopy) cpSync(skill, runSkill, { recursive: true })
  if (opts.mutate) opts.mutate(runSkill)
  writeFileSync(join(home, '.pi/agent/settings.json'), JSON.stringify({ retry: { enabled: false }, compaction: { enabled: false } }))
  command('git', ['init', '-q', '-b', 'main'], { cwd: root })
  const session = `p442-${name}`, fixture = join(tests, 'fixtures/remind-tool-provider.ts')
  const extra = `--offline --no-extensions --no-skills --no-context-files -e ${sh(fixture)}`
  command('bash', [join(skill, 'scripts/team'), 'init', '--no-skills', '--session', session,
    '--agents', 'dev', '--vcs', 'local', '--gates', 'true', '--pm-model', 'p442/controlled',
    '--task-models', 'routine=p442/controlled analysis=p442/controlled verify=p442/controlled code=p442/controlled'], { cwd: root, env: base })
  writeFileSync(join(dir, 'config.generated.sh'), readFileSync(config))
  for (const path of [state, join(root, 'docs/team/tasks'), join(root, 'docs/team/inbox'), join(root, 'docs/team/outbox')]) mkdirSync(path, { recursive: true })
  const prompt = join(state, 'pm-prompt.md'); writeFileSync(prompt, `CASE ${name}\n`)
  const env = { ...base, HOME: home, PI_CODING_AGENT_DIR: join(home, '.pi/agent'), P442_EVIDENCE: dir,
    P442_ENDPOINT: `http://127.0.0.1:${port}/${name}/v1`, TEAM_REMIND_POLL_MS: '200',
    TEAM_PI_BIN: pi, TEAM_PM_EXTRA_PI_ARGS: extra, ...(opts.env ?? {}) }
  const info = { name, dir, root, home, state, config, session, env, skill: runSkill, pane: '', done: join(dir, 'done') }
  let launch
  if (['ordinary', 'worker'].includes(opts.invalid)) {
    let cwd = root
    if (opts.invalid === 'worker') {
      cwd = join(root, 'worker'); writeFileSync(join(root, 'README'), 'fixture'); command('git', ['add', 'README'], { cwd: root })
      command('git', ['-c', 'user.name=fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture'], { cwd: root })
      command('git', ['worktree', 'add', '-q', '--detach', cwd, 'HEAD'], { cwd: root })
    }
    launch = `cd ${sh(cwd)} && exec ${sh(pi)} --provider p442 --model controlled -e ${sh(join(runSkill, 'extension/team-remind.ts'))} ${extra} @${sh(prompt)}`
  } else {
    const sourceScript = `source ${sh(join(runSkill, 'scripts/lib/common.sh'))}; source ${sh(join(runSkill, 'scripts/lib/cmd-config.sh'))}; team_load_config; team_pm_launch_cmd ${sh(prompt)} ${sh(join(state, 'pm.pid.spawn'))}`
    launch = command('bash', ['-c', sourceScript], { cwd: root, env })
    if (opts.invalid === 'no-entry') launch = launch.replace(` -e ${join(runSkill, 'extension/team-remind.ts')}`, '')
  }
  // Mutate after computing the directed launch so its environment still belongs to the real pane.
  // The extension then rejects the changed file, matching a live config edit rather than a forged launch.
  if (opts.configure) opts.configure(config)
  if (opts.earlierHandler) {
    const watcher = join(runSkill, 'extension/team-inbox-watch.ts')
    const earlier = join(runSkill, 'tests/fixtures/remind-adversarial-delay.ts')
    assert(launch.includes(`-e ${watcher}`), 'the real PM launch names the production watcher')
    launch = launch.replace(`-e ${watcher}`, `-e ${earlier} -e ${watcher}`)
  }
  writeFileSync(join(dir, 'launch.txt'), launch + '\n')
  if (!opts.invalid) assert.equal((launch.match(/extension\/team-remind\.ts/g) ?? []).length, 1, 'one directed Reminder extension')
  let release
  const gate = opts.deferFirstResponse ? new Promise(resolve => { release = resolve }) : null
  plans.set(name, { requests: 0, dir, state, respond, gate })
  const window = opts.invalid === 'forged' ? 'not-pm' : 'pm'
  tmux('new-session', '-d', '-s', session, '-n', window, '-c', root, 'sleep 600')
  tmux('set-option', '-t', session, 'remain-on-exit', 'on')
  const pane = tmux('display-message', '-p', '-t', `${session}:${window}`, '#{pane_id}').trim(); info.pane = pane
  info.serverPid = tmux('display-message', '-p', '-t', pane, '#{pid}').trim()
  const script = join(root, 'launch.sh')
  const assignments = Object.entries(env).map(([key, value]) => `export ${key}=${sh(value)};`).join('\n')
  writeFileSync(script, `#!/usr/bin/env bash\n${assignments}\nunset TEAM_ROOT TEAM_MAIN_ROOT TEAM_CONFIG_FILE TEAM_STATE_DIR\nbash -c ${sh(launch)}\nrc=$?; printf '%s\\n' "$rc" >${sh(info.done)}\nsleep 600\n`)
  tmux('respawn-pane', '-k', '-t', pane, `bash ${sh(script)}`)
  await until(() => existsSync(join(dir, 'session-start')) || existsSync(info.done), `${name} session_start`)
  if (!['ordinary', 'worker', 'forged', 'no-entry'].includes(opts.invalid)) publishLaunch(info)
  if (release) release()
  if (opts.invalid === 'no-entry' && release) release()
  const tick = () => {
    if (['ordinary', 'worker', 'forged', 'no-entry'].includes(opts.invalid)) return
    spawnSync(process.execPath, [join(runSkill, 'scripts/remind-tick.mjs'), '--root', root, '--state-dir', state,
      '--pulse-started', new Date().toISOString(), '--json'], { cwd: root, env, stdio: 'ignore' })
  }
  const armTicker = () => setInterval(tick, 250)
  info.ticker = opts.pauseTicker ? null : armTicker()
  info.armTicker = () => { if (!info.ticker) info.ticker = armTicker() }
  return info
}
async function stopPi(info) {
  clearInterval(info.ticker)
  if (!existsSync(info.done)) {
    const pid = Number(readFileSync(join(info.dir, 'session-start'), 'utf8').trim())
    const alive = () => { try { process.kill(pid, 0); return true } catch { return false } }
    tmux('send-keys', '-t', info.pane, '-l', '/p442-control stop'); tmux('send-keys', '-t', info.pane, 'Enter')
    // team_pm_start restarts do not use launch.sh, so they have no `done` receipt. Wait for either
    // that receipt or the actual process exit; a stuck private fixture is killed by its recorded pid.
    for (let n = 0; n < 200 && !existsSync(info.done) && alive(); n++) await delay(50)
    if (!existsSync(info.done) && alive()) {
      console.error(`CLEANUP ${info.name}: graceful shutdown did not exit; killing private Pi pid ${pid}`)
      process.kill(pid, 'SIGKILL')
    }
    await until(() => existsSync(info.done) || !alive(), `${info.name} process reaped`)
  }
}
async function stop(info) {
  const alive = spawnSync('tmux', ['-S', socket, '-f', '/dev/null', 'has-session', '-t', info.session], { env: base, encoding: 'utf8' })
  if (alive.status === 0) {
    await stopPi(info)
    tmux('kill-session', '-t', info.session)
  } else clearInterval(info.ticker)
}
function team(info, args, label = 'team') {
  const result = spawnSync('bash', [join(info.skill, 'scripts/team'), '--root', info.root, ...args], {
    cwd: info.root, env: { ...info.env, TMUX: `${socket},${info.serverPid},0`, TMUX_PANE: info.pane }, encoding: 'utf8' })
  writeFileSync(join(info.dir, `${label}.txt`), (result.stdout ?? '') + (result.stderr ?? ''))
  return result
}
function recover(info) {
  // tmux respawn inherits the private server's environment, not spawnSync's. Publish the same
  // controlled fixture environment the initial launch.sh supplied explicitly.
  for (const [key, value] of Object.entries(info.env)) tmux('set-environment', '-t', info.session, key, String(value))
  const source = `source ${sh(join(info.skill, 'scripts/lib/common.sh'))}; source ${sh(join(info.skill, 'scripts/lib/cmd-config.sh'))}; source ${sh(join(info.skill, 'scripts/lib/cmd-remind.sh'))}; team_load_config; team_remind_recovery`
  const result = spawnSync('bash', ['-c', source], { cwd: info.root,
    env: { ...info.env, TMUX: `${socket},${info.serverPid},0`, TMUX_PANE: info.pane }, encoding: 'utf8' })
  writeFileSync(join(info.dir, `recovery-${Date.now()}.txt`), (result.stdout ?? '') + (result.stderr ?? ''))
  return result
}
function control(info, action) {
  tmux('send-keys', '-t', info.pane, '-l', `/p442-control ${action}`)
  tmux('send-keys', '-t', info.pane, 'Enter')
}
async function hardStop(info) {
  const pid = Number(readFileSync(join(info.dir, 'session-start'), 'utf8').trim())
  assert(Number.isSafeInteger(pid) && pid > 1, `real Pi pid in ${info.name}`)
  process.kill(pid, 'SIGKILL')
  await until(() => existsSync(info.done), `${info.name} hard death`)
}
async function restartDirect(info) {
  // An outstanding intent is deliberately not eligible for team_remind_recovery (that path never
  // resends). Restart the same stopped PM through the production prompt-free start primitive instead.
  rmSync(info.done, { force: true })
  delete info.env.P444_KILL_AT
  for (const [key, value] of Object.entries(info.env)) tmux('set-environment', '-t', info.session, key, String(value))
  const script = join(info.root, 'launch.sh')
  writeFileSync(script, readFileSync(script, 'utf8').replace(/^export P444_KILL_AT=.*;$/m, 'unset P444_KILL_AT;'))
  const before = events(info).filter(e => e.type === 'session_start').length
  const source = `source ${sh(join(info.skill, 'scripts/lib/common.sh'))}; source ${sh(join(info.skill, 'scripts/lib/cmd-config.sh'))}; team_load_config; TEAM_REMINDER_ONLY_RECOVERY=1 team_pm_start`
  const result = spawnSync('bash', ['-c', source], { cwd: info.root,
    env: { ...info.env, TMUX: `${socket},${info.serverPid},0`, TMUX_PANE: info.pane }, encoding: 'utf8' })
  writeFileSync(join(info.dir, `restart-${Date.now()}.txt`), (result.stdout ?? '') + (result.stderr ?? ''))
  assert.equal(result.status, 0, `prompt-free restart after death: ${result.stdout}${result.stderr}`)
  await until(() => events(info).filter(e => e.type === 'session_start').length > before && !existsSync(info.done),
    `${info.name} restart after death`)
}
async function restartForeign(info) {
  await hardStop(info)
  rmSync(info.done, { force: true })
  const before = events(info).filter(e => e.type === 'session_start').length
  const oldSession = events(info).filter(e => e.type === 'session_start').at(-1).sessionId
  const launch = readFileSync(join(info.dir, 'launch.txt'), 'utf8').trim()
    .replace(' -c --offline', ' --offline').replace(/ @\S*pm-prompt\.md\s*$/, '')
  const script = join(info.root, 'launch-foreign.sh')
  const assignments = Object.entries(info.env).map(([key, value]) => `export ${key}=${sh(value)};`).join('\n')
  writeFileSync(script, `#!/usr/bin/env bash\n${assignments}\nunset TEAM_ROOT TEAM_MAIN_ROOT TEAM_CONFIG_FILE TEAM_STATE_DIR\nbash -c ${sh(launch)}\nrc=$?; printf '%s\\n' "$rc" >${sh(info.done)}\nsleep 600\n`)
  tmux('respawn-pane', '-k', '-t', info.pane, `bash ${sh(script)}`)
  await until(() => events(info).filter(e => e.type === 'session_start').length > before &&
    events(info).filter(e => e.type === 'session_start').at(-1).sessionId !== oldSession, 'actual foreign process/session')
}
function addReal(info, message, key, label = 'add-adversarial') {
  const args = ['remind', 'add', '--after', '1s', '--message', message]
  if (key) args.push('--key', key)
  const result = team(info, args, label)
  assert.equal(result.status, 0, `${label}: ${result.stdout}${result.stderr}`)
}
function lastBatch(info) { return snapshot(info.state).batches.at(-1) }
function replayPayload(info, name = 'replay') {
  const event = events(info).find(e => e.type === 'delay_enter' && e.message?.customType === 'team-reminder')
  assert(event?.message?.content && event.message.details?.members, 'a real earlier-handler event supplied the replay payload')
  const file = join(info.dir, `${name}.json`)
  writeFileSync(file, JSON.stringify(event.message))
  return file
}
async function replay(info, file, label) {
  const sends = events(info).filter(e => e.type === 'fixture_send').length
  control(info, `send ${file}`)
  await until(() => events(info).filter(e => e.type === 'fixture_send').length > sends, `${label} actual Pi send`)
}
async function test(name, body) {
  try { await body(); console.log(`PASS real Pi ${name}`); passed++ }
  catch (e) { failed++; console.error(`FAIL real Pi ${name}: ${e.stack}`) }
}
const add = (after, message, key) => ({ action: 'add', after, message, ...(key ? { key } : {}) })
const final = text => ({ text })
const large = `${'x'.repeat(64 * 1024)}\n`
const hasExact = (value, target) => value === target || (Array.isArray(value) ? value.some(item => hasExact(item, target))
  : value && typeof value === 'object' ? Object.values(value).some(item => hasExact(item, target)) : false)
const mismatchGeneratedSession = config => {
  const source = readFileSync(config, 'utf8')
  const changed = source.replace(/^TEAM_SESSION=.*$/m, "TEAM_SESSION='p442-not-the-directed-session'")
  assert.notEqual(changed, source, 'change only the generated TEAM_SESSION line')
  writeFileSync(config, changed)
}
function assertConfigMismatch(info) {
  const evidence = join(info.state, 'remind-tool/current.json')
  assert(existsSync(evidence), 'mismatched config leaves visible error evidence')
  const record = json(evidence)
  assert.equal(record.status, 'error', 'mismatched config records status=error')
  assert.equal(record.exposure, 'hidden', 'mismatched config never exposes the tool')
  assert.match(record.reason, /PM config TEAM_SESSION does not match the directed launch/, 'error evidence names the mismatched key')
  const started = events(info).filter(e => e.type === 'session_start').at(-1)
  assert.equal(started.reminderTools[0]?.exposure, 'hidden', 'real Pi registers only the hidden tool')
  assert(!started.activeTools.includes('team_remind'), 'real Pi active tools exclude team_remind')
  assert.match(doctor(info), /PM 提醒工具\s+.*error PM config TEAM_SESSION does not match the directed launch/,
    'doctor reports the configuration error instead of unknown or ready')
  assert(!existsSync(join(info.state, 'reminders/state.json')), 'rejected config touches no Reminder state')
}

try {
  if (selection.includes('pm')) await test('PM add/list/show/cancel, retry, observed same-key renewal and no-key IDs', async () => {
    let firstId = '', firstDue = ''
    const info = await start('pm', async ({ n, res, plan }) => {
      const ids = () => snapshot(plan.state).reminders.map(record => record.id)
      if (n === 0) return sse(res, { name: 'pm', tool: { n, input: add('1s', 'same body\n', 'cycle') } })
      if (n === 1) return sse(res, { name: 'pm', tool: { n, input: add('1s', 'same body\n', 'cycle') } })
      if (n === 2) return sse(res, { name: 'pm', ...final('active retry recorded') })
      if (n === 3) return sse(res, { name: 'pm', tool: { n, input: add('1s', 'same body\n', 'cycle') } })
      if (n === 4) return sse(res, { name: 'pm', tool: { n, input: add('1h', 'identical no key') } })
      if (n === 5) return sse(res, { name: 'pm', tool: { n, input: add('1h', 'identical no key') } })
      if (n === 6) return sse(res, { name: 'pm', tool: { n, input: { action: 'show', id: ids()[1] } } })
      if (n === 7) return sse(res, { name: 'pm', tool: { n, input: { action: 'cancel', id: ids()[1] } } })
      if (n === 8) return sse(res, { name: 'pm', tool: { n, input: { action: 'cancel', id: ids()[2] } } })
      if (n === 9) return sse(res, { name: 'pm', tool: { n, input: { action: 'cancel', id: ids()[3] } } })
      return sse(res, { name: 'pm', ...final('PM reminder tool sequence complete') })
    }, { deferFirstResponse: true })
    const generated = readFileSync(info.config, 'utf8')
    assert.match(generated, /^TEAM_SESSION=.*\s+# tmux session name/m, 'fixture keeps the generated TEAM_SESSION trailing comment')
    assert.match(generated, /^TEAM_PM_WINDOW=.*\s+# window running the PM/m, 'fixture keeps the generated TEAM_PM_WINDOW trailing comment')
    try {
      await until(() => requests(info).length >= 3 && events(info).some(e => e.type === 'agent_settled'), 'initial add and retry settle')
      let snap = snapshot(info.state)
      assert.equal(snap.reminders.length, 1, 'active retry does not allocate another reminder')
      firstId = snap.reminders[0].id; firstDue = snap.reminders[0].dueAt
      assert.equal(snap.reminders[0].source, 'pm-tool')
      assert.equal(snap.reminders[0].message, 'same body\n')
      const toolEnds = events(info).filter(e => e.type === 'tool_end')
      assert(toolEnds.length >= 2 && toolEnds.every(e => !e.isError), 'real PM tool calls succeed')
      assert(events(info).some(e => e.type === 'before_agent_start' && e.activeTools.includes('team_remind') && e.reminderTools[0]?.exposure === 'direct'), 'PM tool is direct and active')
      await until(() => events(info).some(e => e.type === 'custom_start' && e.customType === 'team-reminder') && snapshot(info.state).reminders[0].phase === 'observed', 'first real Reminder wake observed')
      await until(() => requests(info).length >= 11 && snapshot(info.state).reminders.length === 4, 'post-wake same-key and no-key sequence')
      snap = snapshot(info.state)
      assert.equal(snap.reminders[0].id, firstId); assert.equal(snap.reminders[0].dueAt, firstDue)
      assert.equal(snap.reminders[0].phase, 'observed')
      assert.equal(snap.reminders[1].seq, 2); assert.notEqual(snap.reminders[1].id, firstId)
      assert.equal(snap.reminders[1].key, 'cycle'); assert.equal(snap.reminders[1].phase, 'cancelled')
      assert.equal(snap.reminders[2].message, 'identical no key'); assert.equal(snap.reminders[3].message, 'identical no key')
      assert.notEqual(snap.reminders[2].id, snap.reminders[3].id)
      assert(snap.reminders.every(record => record.source === 'pm-tool'))
      const output = doctor(info); assert.match(output, /PM 提醒工具\s+.*ready extension reported registered\/active/)
      const capability = json(join(info.state, 'remind-tool/current.json'))
      assert(capability.launchNonce && capability.sessionId && capability.starttime && capability.extensionVersion)
      writeFileSync(join(info.dir, 'receipt.json'), JSON.stringify({ firstId, firstDue, final: snap, capability }, null, 2))
    } finally { await stop(info) }
    assert(!existsSync(join(info.state, 'remind-tool/current.json')), 'shutdown removes only its own capability evidence')
    assert.match(doctor(info), /PM 提醒工具\s+.*not-running/)
  })

  if (selection.includes('large')) await test('64 KiB plus final newline through real PM tool add/show/list/cancel', async () => {
    const info = await start('large', async ({ n, res, plan }) => {
      if (n === 0) return sse(res, { name: 'large', tool: { n, input: add('1h', large) } })
      if (n === 1) return sse(res, { name: 'large', tool: { n, input: { action: 'show', id: snapshot(plan.state).reminders[0].id } } })
      if (n === 2) return sse(res, { name: 'large', tool: { n, input: { action: 'list', all: true } } })
      if (n === 3) return sse(res, { name: 'large', tool: { n, input: { action: 'cancel', id: snapshot(plan.state).reminders[0].id } } })
      return sse(res, { name: 'large', ...final('large complete') })
    }, { deferFirstResponse: true })
    // The server closure starts after info is assigned; its first response is gated by session_start.
    try {
      await until(() => requests(info).length >= 5 && events(info).some(e => e.type === 'agent_settled'), 'large add/show/list/cancel')
      const snap = snapshot(info.state)
      assert.equal(snap.reminders[0].message, large)
      assert.equal(Buffer.byteLength(snap.reminders[0].message, 'utf8'), 65537)
      assert.equal(snap.reminders[0].phase, 'cancelled')
      assert(requests(info).some(request => (request.messages ?? []).some(message => {
        if (message.role !== 'tool' || typeof message.content !== 'string') return false
        try { return hasExact(JSON.parse(message.content), large) } catch { return false }
      })), 'large full text is returned to the controlled provider, not truncated')
    } finally { await stop(info) }
  })

  if (selection.includes('identity')) {
    for (const invalid of ['ordinary', 'worker', 'forged']) await test(`${invalid}: globally loaded copy stays hidden with zero Reminder state`, async () => {
      const info = await start(invalid, async ({ n, res }) => sse(res, { name: invalid, ...final(`invalid ${invalid}`) }), { invalid })
      try {
        await until(() => events(info).some(e => e.type === 'agent_settled'), `${invalid} response`)
        assert(events(info).every(e => !e.activeTools?.includes('team_remind')))
        assert(requests(info).every(request => !(request.tools ?? []).some(tool => tool.function?.name === 'team_remind')))
        assert(!existsSync(join(info.state, 'reminders/state.json')))
      } finally { await stop(info) }
    })
    await test('reload into an invalid pane hides all actions without changing Reminder state', async () => {
      const info = await start('reload', async ({ n, res }) => {
        if (n === 0) return sse(res, { name: 'reload', tool: { n, input: add('1h', 'before invalid reload') } })
        return sse(res, { name: 'reload', ...final(`reload response ${n}`) })
      }, { deferFirstResponse: true })
      try {
        await until(() => snapshot(info.state).reminders.length === 1 && events(info).some(e => e.type === 'agent_settled'), 'pre-reload add')
        const before = readFileSync(join(info.state, 'reminders/state.json'), 'utf8')
        tmux('rename-window', '-t', info.pane, 'not-pm')
        tmux('send-keys', '-t', info.pane, '-l', '/p442-control reload'); tmux('send-keys', '-t', info.pane, 'Enter')
        await until(() => events(info).filter(e => e.type === 'session_start').length >= 2 && requests(info).length >= 2, 'invalid reload response')
        const current = events(info).filter(e => e.type === 'session_start').at(-1)
        assert.equal(current.reminderTools[0]?.exposure, 'hidden'); assert.equal(current.activeTools.length, 0)
        assert.equal(readFileSync(join(info.state, 'reminders/state.json'), 'utf8'), before)
        assert.match(doctor(info), /PM 提醒工具\s+.*not-running/) // configured PM pane is gone; no ready claim follows the stale evidence
      } finally { await stop(info) }
    })
  }

  if (selection.includes('recovery')) await test('stopped PM resumes without a generic prompt; Reminder arrives before ordinary backlog', async () => {
    const info = await start('recovery', async ({ n, res }) => sse(res, { name: 'recovery', ...final(`controlled response ${n}`) }), { deferFirstResponse: true })
    try {
      await until(() => requests(info).length === 1 && events(info).some(e => e.type === 'agent_settled'), 'seed PM response')
      const seedSession = events(info).find(e => e.type === 'session_start').sessionId
      await stopPi(info)
      const before = requests(info).length
      const promptBefore = readFileSync(join(info.state, 'pm-prompt.md'), 'utf8')
      const wrapper = join(info.dir, 'pi-argv-wrapper.sh'), argvBytes = join(info.dir, 'argv.bin')
      writeFileSync(wrapper, `#!/usr/bin/env bash\nprintf '%s\\0' "$@" >${sh(argvBytes)}\nexec ${sh(pi)} "$@"\n`)
      command('chmod', ['+x', wrapper])
      writeFileSync(info.config, readFileSync(info.config, 'utf8').replace(/^TEAM_PI_BIN=.*$/m, `TEAM_PI_BIN=${sh(wrapper)}`))
      let result = team(info, ['notify', 'pm', 'P443_ORDINARY_BACKLOG'], 'ordinary-backlog')
      assert.equal(result.status, 0, 'ordinary backlog is pending before recovery')
      result = team(info, ['standby', 'on', '--reason', 'P443 stopped recovery'], 'standby-on')
      assert.equal(result.status, 0, 'Standby on succeeds')
      result = team(info, ['remind', 'add', '--after', '1s', '--message', 'P443_RECOVERY_ONLY', '--key', 'recovery'], 'add-recovery')
      assert.equal(result.status, 0, 'recovery Reminder is created')
      await delay(1200)
      result = recover(info)
      assert.equal(result.status, 0, `prompt-free recovery: ${result.stdout}${result.stderr}`)
      assert.match(result.stdout, /result=started/)
      await delay(500)
      const pane = spawnSync('tmux', ['-S', socket, '-f', '/dev/null', 'capture-pane', '-p', '-t', `${info.session}:pm`, '-S', '-100'], { env: base, encoding: 'utf8' })
      writeFileSync(join(info.dir, 'recovery-pane.txt'), (pane.stdout ?? '') + (pane.stderr ?? ''))
      const pid = readFileSync(join(info.state, 'pm.pid'), 'utf8').trim()
      const argv = readFileSync(argvBytes).toString('utf8').split('\0').filter(Boolean)
      writeFileSync(join(info.dir, 'recovery-argv.json'), JSON.stringify(argv, null, 2))
      assert(!argv.some(arg => arg.startsWith('@') || arg.includes('pm-prompt')), 'actual PM argv has no generic or replacement initial prompt')
      assert((argv.includes('-c') || argv.includes('--continue')) && argv.some(arg => arg.endsWith('team-inbox-watch.ts')) && argv.some(arg => arg.endsWith('team-remind.ts')))
      assert.equal(readFileSync(join(info.state, 'pm-prompt.md'), 'utf8'), promptBefore, 'the previous prompt file is untouched')
      await until(() => snapshot(info.state).reminders[0]?.phase === 'observed' && requests(info).length === before + 1 &&
        events(info).filter(e => e.type === 'agent_settled').length >= 2, 'Reminder observation and one controlled response')
      assert.equal(snapshot(info.state).standby.on, false, 'only the correlated wake exits Standby')
      const newRequests = requests(info).slice(before)
      assert.equal(newRequests.length, 1, 'there is no generic startup model turn before the Reminder')
      assert(newRequests.every(request => JSON.stringify(request).includes('P443_RECOVERY_ONLY')))
      assert(newRequests.every(request => !JSON.stringify(request).includes('P443_ORDINARY_BACKLOG')), 'ordinary backlog did not run first')
      assert(events(info).filter(e => e.type === 'custom_start').every(e => e.customType === 'team-reminder'), 'no ordinary inbox wake preceded the Reminder')
      const recoveredSession = events(info).filter(e => e.type === 'session_start').at(-1).sessionId
      assert.equal(recoveredSession, seedSession, 'usual resume arguments preserve the PM session')

      // A second Reminder holds the controlled response open. Recovery during that busy turn must not respawn.
      const plan = plans.get('recovery')
      plan.gateN = plan.requests
      let releaseBusy
      plan.gate = new Promise(resolve => { releaseBusy = resolve; info.releaseBusy = resolve })
      result = team(info, ['remind', 'add', '--after', '1s', '--message', 'P443_BUSY_FOLLOW_UP'], 'add-busy')
      assert.equal(result.status, 0)
      await delay(1200)
      result = recover(info)
      assert.equal(result.status, 0)
      assert.match(result.stdout, /result=running/)
      await until(() => requests(info).length === plan.gateN + 1, 'busy controlled response is pending')
      const restartsBeforeBusyCheck = readFileSync(join(info.state, 'pm-restarts.log'), 'utf8')
      result = recover(info)
      assert.equal(result.status, 0)
      assert.doesNotMatch(result.stdout, /result=started/, 'an in-flight Reminder never causes another PM start')
      assert.equal(readFileSync(join(info.state, 'pm-restarts.log'), 'utf8'), restartsBeforeBusyCheck)
      assert.equal(readFileSync(join(info.state, 'pm.pid'), 'utf8').trim(), pid, 'running/busy recovery keeps the same PM process')
      releaseBusy()
      await until(() => snapshot(info.state).reminders[1]?.phase === 'observed', 'busy follow-up observation')
      writeFileSync(join(info.dir, 'recovery-receipt.json'), JSON.stringify({ pid, argv, seedSession, recoveredSession,
        genericTurns: 0, ordinaryBacklogTurns: 0, final: snapshot(info.state) }, null, 2))
    } finally { info.releaseBusy?.(); await stop(info) }
  })

  if (selection.includes('adversarial') || selection.some(name => name.startsWith('adversarial-'))) {
    const adversarialCase = name => selection.includes('adversarial') || selection.includes(`adversarial-${name}`)
    if (adversarialCase('batch')) await test('A+B exact event, duplicate/member/foreign-session replay preserve a fresh generation', async () => {
      const info = await start('adversarial-batch', async ({ n, res }) => sse(res, { name: 'adversarial-batch', ...final(`batch response ${n}`) }),
        { deferFirstResponse: true, earlierHandler: true, pauseTicker: true, env: { P444_DELAY: '1' } })
      try {
        await until(() => requests(info).length === 1 && events(info).some(e => e.type === 'agent_settled'), 'batch initial response')
        assert.equal(team(info, ['standby', 'on', '--reason', 'P444 G1'], 'batch-g1').status, 0)
        addReal(info, 'P444_A first line\nsecond line\n', 'batch-a', 'add-a')
        addReal(info, 'P444_B full text', 'batch-b', 'add-b')
        await delay(1100) // Both one-second Reminders are actually due before admission is allowed to run.
        info.armTicker()
        await until(() => lastBatch(info)?.phase === 'intent' && events(info).some(e => e.type === 'delay_enter'), 'A+B real event paused in earlier handler')
        const frozen = lastBatch(info)
        assert.equal(frozen.generation, 1); assert.equal(frozen.members.length, 2)
        const delayed = events(info).find(e => e.type === 'delay_enter')
        assert(delayed.message.content.includes('P444_A first line\nsecond line\n'))
        assert(delayed.message.content.includes('P444_B full text'))
        assert.deepEqual(delayed.message.details.members, frozen.members)
        const original = replayPayload(info, 'original-batch')
        writeFileSync(join(info.dir, 'release-event'), 'release')
        await until(() => lastBatch(info)?.phase === 'observed', 'A+B observed')
        let snap = snapshot(info.state)
        assert.equal(snap.standby.on, false); assert.equal(lastBatch(info).outcome.standby, 'auto-off')
        assert.equal(lastBatch(info).rightSpentBy, 'wake')
        const audits = snap.audit.filter(a => a.op === 'remind-observed')
        assert.equal(audits.length, 1); assert.deepEqual(audits[0].ids, frozen.members)
        assert.deepEqual(audits[0].sources, ['cli', 'cli'])
        await until(() => requests(info).filter(r => JSON.stringify(r).includes('P444_A') && JSON.stringify(r).includes('P444_B')).length === 1,
          'the frozen A+B batch caused one controlled model request')
        assert.equal(requests(info).filter(r => JSON.stringify(r).includes('P444_A') && JSON.stringify(r).includes('P444_B')).length, 1)

        assert.equal(team(info, ['standby', 'on', '--reason', 'P444 fresh G2'], 'batch-g2').status, 0)
        const malformed = join(info.dir, 'wrong-members.json')
        writeFileSync(malformed, JSON.stringify({ ...delayed.message, details: { ...delayed.message.details, members: [] } }))
        await replay(info, malformed, 'wrong members')
        await until(() => readFileSync(join(info.state, 'inbox-watch.log'), 'utf8').includes('member-mismatch'), 'member mismatch is visible')
        assert.equal(snapshot(info.state).standby.generation, 2); assert.equal(snapshot(info.state).standby.on, true)
        await replay(info, original, 'duplicate')
        await until(() => readFileSync(join(info.state, 'inbox-watch.log'), 'utf8').includes('reminder duplicate event'), 'duplicate handled')
        snap = snapshot(info.state)
        assert.equal(snap.standby.on, true); assert.equal(snap.standby.generation, 2)
        assert.equal(snap.audit.filter(a => a.op === 'remind-observed').length, 1)

        await restartForeign(info)
        const foreignSession = events(info).filter(e => e.type === 'session_start').at(-1).sessionId
        assert.notEqual(foreignSession, frozen.target.session)
        await replay(info, original, 'foreign session')
        await until(() => readFileSync(join(info.state, 'inbox-watch.log'), 'utf8').includes('session-mismatch'), 'foreign session rejected')
        snap = snapshot(info.state)
        assert.equal(snap.standby.on, true); assert.equal(snap.standby.generation, 2)
        assert.equal(snap.audit.filter(a => a.op === 'remind-observed').length, 1)
        writeFileSync(join(info.dir, 'receipt.json'), JSON.stringify({ frozen, foreignSession, final: snap,
          sends: events(info).filter(e => e.type === 'fixture_send') }, null, 2))
      } finally { writeFileSync(join(info.dir, 'release-event'), 'release'); await stop(info) }
    })

    if (adversarialCase('event-first')) await test('event before manual off/on G2 stays ambiguous and Standby commands do not wait for Pi', async () => {
      const info = await start('adversarial-event-first', async ({ n, res }) => sse(res, { name: 'adversarial-event-first', ...final(`event first ${n}`) }),
        { deferFirstResponse: true, earlierHandler: true, env: { P444_DELAY: '1' } })
      try {
        await until(() => events(info).some(e => e.type === 'agent_settled'), 'event-first initial response')
        team(info, ['standby', 'on', '--reason', 'G1'], 'event-first-g1')
        addReal(info, 'P444_EVENT_BEFORE_G2', 'event-first')
        await until(() => events(info).some(e => e.type === 'delay_enter') && lastBatch(info)?.phase === 'intent', 'real event arrived before G2')
        assert.equal(team(info, ['standby', 'off'], 'event-first-off').status, 0)
        assert.equal(team(info, ['standby', 'on', '--reason', 'G2'], 'event-first-g2').status, 0)
        assert.equal(snapshot(info.state).standby.generation, 2)
        assert.equal(lastBatch(info).phase, 'intent', 'paused earlier handler has not committed observation')
        assert(!events(info).some(e => e.type === 'delay_exit'), 'both Standby commands completed while Pi handler was paused')
        writeFileSync(join(info.dir, 'release-event'), 'release')
        await until(() => lastBatch(info)?.phase === 'observed', 'event-first observation')
        assert.equal(lastBatch(info).outcome.standby, 'generation-ambiguous')
        assert.equal(snapshot(info.state).standby.on, true); assert.equal(snapshot(info.state).standby.generation, 2)
        writeFileSync(join(info.dir, 'receipt.json'), JSON.stringify({ final: snapshot(info.state),
          timeline: events(info).filter(e => ['delay_enter', 'delay_exit', 'custom_start'].includes(e.type)) }, null, 2))
      } finally { writeFileSync(join(info.dir, 'release-event'), 'release'); await stop(info) }
    })

    if (adversarialCase('event-after')) await test('busy follow-up emitted after manual G2 keeps the unprovable order boundary', async () => {
      const info = await start('adversarial-event-after', async ({ n, res }) => sse(res, { name: 'adversarial-event-after', ...final(`event after ${n}`) }),
        { deferFirstResponse: true })
      try {
        await until(() => events(info).some(e => e.type === 'agent_settled'), 'event-after initial response')
        const plan = plans.get('adversarial-event-after')
        plan.gateN = plan.requests
        let releaseBusy
        plan.gate = new Promise(resolve => { releaseBusy = resolve; info.releaseBusy = resolve })
        control(info, 'busy')
        await until(() => requests(info).length === plan.gateN + 1, 'unrelated controlled turn is busy')
        team(info, ['standby', 'on', '--reason', 'G1'], 'event-after-g1')
        addReal(info, 'P444_EVENT_AFTER_G2', 'event-after')
        await until(() => lastBatch(info)?.phase === 'intent' && readFileSync(join(info.state, 'inbox-watch.log'), 'utf8').includes('intent-sent'),
          'busy follow-up call returned with durable intent')
        assert(!events(info).some(e => e.type === 'custom_start' && e.customType === 'team-reminder'), 'no message event before the busy turn ends')
        assert.equal(lastBatch(info).phase, 'intent', 'sendMessage returning is not a wake')
        assert.equal(team(info, ['standby', 'off'], 'event-after-off').status, 0)
        assert.equal(team(info, ['standby', 'on', '--reason', 'G2'], 'event-after-g2').status, 0)
        releaseBusy()
        await until(() => lastBatch(info)?.phase === 'observed', 'busy follow-up observed after G2')
        assert(events(info).some(e => e.type === 'custom_start' && e.customType === 'team-reminder'))
        assert.equal(lastBatch(info).outcome.standby, 'generation-ambiguous')
        assert.equal(snapshot(info.state).standby.on, true); assert.equal(snapshot(info.state).standby.generation, 2)
        writeFileSync(join(info.dir, 'receipt.json'), JSON.stringify({ final: snapshot(info.state),
          reminderRequests: requests(info).filter(r => JSON.stringify(r).includes('P444_EVENT_AFTER_G2')).length,
          timeline: events(info).filter(e => ['custom_start', 'fixture_send', 'agent_settled'].includes(e.type)) }, null, 2))
      } finally { info.releaseBusy?.(); await stop(info) }
    })

    if (adversarialCase('generations')) await test('G2 committed before intent exits once; manual off before the event is already-off', async () => {
      const bound = await start('adversarial-g2-bound', async ({ n, res }) => sse(res, { name: 'adversarial-g2-bound', ...final(`G2 bound ${n}`) }), { deferFirstResponse: true })
      try {
        await until(() => events(bound).some(e => e.type === 'agent_settled'), 'G2-bound initial response')
        team(bound, ['standby', 'on', '--reason', 'G1'], 'bound-g1')
        team(bound, ['standby', 'off'], 'bound-off1')
        team(bound, ['standby', 'on', '--reason', 'G2'], 'bound-g2')
        addReal(bound, 'P444_G2_BOUND', 'g2-bound')
        await until(() => lastBatch(bound)?.phase === 'observed', 'G2-bound observation')
        assert.equal(lastBatch(bound).generation, 2); assert.equal(lastBatch(bound).outcome.standby, 'auto-off')
        assert.equal(snapshot(bound.state).standby.on, false)
        writeFileSync(join(bound.dir, 'receipt.json'), JSON.stringify({ final: snapshot(bound.state) }, null, 2))
      } finally { await stop(bound) }

      const manual = await start('adversarial-manual-off', async ({ n, res }) => sse(res, { name: 'adversarial-manual-off', ...final(`manual off ${n}`) }),
        { deferFirstResponse: true, earlierHandler: true, env: { P444_DELAY: '1' } })
      try {
        await until(() => events(manual).some(e => e.type === 'agent_settled'), 'manual-off initial response')
        team(manual, ['standby', 'on', '--reason', 'G1'], 'manual-g1')
        addReal(manual, 'P444_MANUAL_OFF', 'manual-off')
        await until(() => events(manual).some(e => e.type === 'delay_enter'), 'manual-off real event paused')
        assert.equal(team(manual, ['standby', 'off'], 'manual-off-command').status, 0)
        writeFileSync(join(manual.dir, 'release-event'), 'release')
        await until(() => lastBatch(manual)?.phase === 'observed', 'manual-off observation')
        assert.equal(lastBatch(manual).outcome.standby, 'already-off')
        assert.equal(snapshot(manual.state).standby.on, false)
        writeFileSync(join(manual.dir, 'receipt.json'), JSON.stringify({ final: snapshot(manual.state) }, null, 2))
      } finally { writeFileSync(join(manual.dir, 'release-event'), 'release'); await stop(manual) }
    })

    if (adversarialCase('death-event')) await test('death after a real event becomes unknown without resend; late replay cannot clear fresh G2', async () => {
      const info = await start('adversarial-death-event', async ({ n, res }) => sse(res, { name: 'adversarial-death-event', ...final(`death event ${n}`) }),
        { deferFirstResponse: true, earlierHandler: true, env: { P444_KILL_AT: 'event' } })
      try {
        await until(() => events(info).some(e => e.type === 'agent_settled'), 'death-event initial response')
        team(info, ['standby', 'on', '--reason', 'G1'], 'death-event-g1')
        addReal(info, 'P444_DEATH_AFTER_EVENT', 'death-event')
        await until(() => existsSync(info.done) && events(info).some(e => e.type === 'delay_enter'), 'death inside earlier real event handler')
        const original = replayPayload(info, 'late-original-event')
        assert.equal(lastBatch(info).phase, 'intent'); assert.equal(snapshot(info.state).standby.on, true)
        await restartDirect(info)
        await delay(500)
        const ledger = () => readFileSync(join(info.state, 'inbox-watch.log'), 'utf8')
        assert.equal((ledger().match(/reminder intent-sent/g) ?? []).length, 1, 'restart did not resend the old intent')
        await until(() => lastBatch(info)?.phase === 'unknown', 'actual sixty-second deadline marks the old intent unknown')
        assert.equal(snapshot(info.state).standby.on, true)
        team(info, ['standby', 'off'], 'death-event-off1')
        team(info, ['standby', 'on', '--reason', 'fresh G2 after restart'], 'death-event-g2')
        await replay(info, original, 'late original event')
        await until(() => lastBatch(info)?.phase === 'observed', 'late real event observes unknown batch')
        assert.equal(lastBatch(info).outcome.standby, 'generation-ambiguous')
        assert.equal(snapshot(info.state).standby.on, true); assert.equal(snapshot(info.state).standby.generation, 2)
        assert.equal(snapshot(info.state).audit.filter(a => a.op === 'remind-observed').length, 1)
        assert.equal((ledger().match(/reminder intent-sent/g) ?? []).length, 1, 'late observation caused no automatic resend')
        writeFileSync(join(info.dir, 'receipt.json'), JSON.stringify({ final: snapshot(info.state),
          automaticSendCount: (ledger().match(/reminder intent-sent/g) ?? []).length,
          replaySends: events(info).filter(e => e.type === 'fixture_send'), requestCount: requests(info).length,
          timeline: events(info).filter(e => ['session_start', 'delay_enter', 'custom_start', 'fixture_send'].includes(e.type)) }, null, 2))
      } finally { await stop(info) }
    })
  }

  if (selection.includes('death')) {
    for (const point of ['before-call', 'after-call']) await test(`process death ${point} preserves intent and never blind-resends`, async () => {
      const name = `adversarial-death-${point}`
      const info = await start(name, async ({ n, res }) => sse(res, { name, ...final(`${point} ${n}`) }), {
        skillCopy: true, deferFirstResponse: true, env: { P444_KILL_AT: point },
        mutate: copied => {
          const path = join(copied, 'extension/team-inbox-watch.ts'), source = readFileSync(path, 'utf8')
          const before = '        pi.sendMessage({\n'
          const after = "        }, { triggerTurn: true, deliverAs: 'followUp' })\n"
          assert.equal(source.split(before).length, 2); assert.equal(source.split(after).length, 2)
          writeFileSync(path, source.replace(before, `        appendFileSync(join(process.env.P442_EVIDENCE, 'pi-calls.log'), 'before-invoke\\n')\n        if (process.env.P444_KILL_AT === 'before-call') process.kill(process.pid, 'SIGKILL')\n${before}`)
            .replace(after, `${after}        appendFileSync(join(process.env.P442_EVIDENCE, 'pi-calls.log'), 'after-invoke\\n')\n        if (process.env.P444_KILL_AT === 'after-call') process.kill(process.pid, 'SIGKILL')\n`))
        },
      })
      try {
        await until(() => events(info).some(e => e.type === 'agent_settled'), `${point} initial response`)
        const plan = plans.get(name)
        if (point === 'after-call') {
          plan.gateN = plan.requests
          plan.gate = new Promise(resolve => { info.releaseBusy = resolve })
          control(info, 'busy')
          await until(() => requests(info).length === plan.gateN + 1, 'after-call busy turn')
        }
        team(info, ['standby', 'on', '--reason', point], `${point}-g1`)
        addReal(info, `P444_DEATH_${point}`, point)
        await until(() => existsSync(info.done), `${point} process death`)
        assert.equal(lastBatch(info).phase, 'intent'); assert.equal(snapshot(info.state).standby.on, true)
        assert(!events(info).some(e => e.type === 'custom_start' && e.customType === 'team-reminder'), 'no observation was manufactured')
        const ledgerBefore = readFileSync(join(info.state, 'inbox-watch.log'), 'utf8')
        assert.equal((ledgerBefore.match(/reminder intent-sent/g) ?? []).length, 0, 'death precedes the post-call ledger append')
        const callsBefore = readFileSync(join(info.dir, 'pi-calls.log'), 'utf8')
        assert.equal((callsBefore.match(/before-invoke/g) ?? []).length, 1)
        assert.equal((callsBefore.match(/after-invoke/g) ?? []).length, point === 'before-call' ? 0 : 1)
        await restartDirect(info)
        await delay(500)
        const ledgerAfter = readFileSync(join(info.state, 'inbox-watch.log'), 'utf8')
        assert.equal((ledgerAfter.match(/reminder intent-sent/g) ?? []).length, 0,
          'restart did not reach another post-call ledger append')
        const callsAfter = readFileSync(join(info.dir, 'pi-calls.log'), 'utf8')
        assert.equal((callsAfter.match(/before-invoke/g) ?? []).length, 1, 'restart did not issue another Pi call')
        assert.equal((callsAfter.match(/after-invoke/g) ?? []).length, point === 'before-call' ? 0 : 1)
        assert.equal(lastBatch(info).phase, 'intent'); assert.equal(snapshot(info.state).standby.on, true)
        writeFileSync(join(info.dir, 'receipt.json'), JSON.stringify({ point, final: snapshot(info.state),
          calls: callsAfter, automaticPostCallLedgerCount: (ledgerAfter.match(/reminder intent-sent/g) ?? []).length }, null, 2))
      } finally { info.releaseBusy?.(); await stop(info) }
    })
  }

  if (selection.includes('withdrawal')) {
    for (const action of ['new', 'fork']) await test(`${action}: invalid replacement session immediately loses ready evidence`, async () => {
      const name = `${action}-hide`
      const info = await start(name, async ({ n, res }) => sse(res, { name, ...final(`${action} response ${n}`) }), { deferFirstResponse: true })
      try {
        await until(() => requests(info).length === 1 && events(info).some(e => e.type === 'agent_settled'), `${action} initial response`)
        const added = team(info, ['remind', 'add', '--after', '1h', '--message', `before ${action}`], `add-before-${action}`)
        assert.equal(added.status, 0)
        const before = readFileSync(join(info.state, 'reminders/state.json'), 'utf8')
        tmux('rename-window', '-t', info.pane, 'not-pm')
        tmux('send-keys', '-t', info.pane, '-l', `/p442-control ${action}`); tmux('send-keys', '-t', info.pane, 'Enter')
        await until(() => events(info).filter(e => e.type === 'session_start').length >= 2, `${action} replacement session`)
        const current = events(info).filter(e => e.type === 'session_start').at(-1)
        assert.equal(current.reminderTools[0]?.exposure, 'hidden')
        assert.equal(current.activeTools.length, 0)
        const evidencePath = join(info.state, 'remind-tool/current.json')
        if (existsSync(evidencePath)) assert.equal(json(evidencePath).status, 'hidden')
        assert(!/PM 提醒工具\s+.*ready/.test(doctor(info)), 'doctor is not ready in the same replacement, without a 20s wait')
        assert.equal(readFileSync(join(info.state, 'reminders/state.json'), 'utf8'), before)
      } finally { await stop(info) }
    })
  }

  if (selection.includes('doctor')) {
    await test('running PM with no entry is unknown, not a load failure', async () => {
      const info = await start('noentry', async ({ n, res }) => sse(res, { name: 'noentry', ...final('no entry') }), { invalid: 'no-entry', deferFirstResponse: true })
      try {
        await until(() => events(info).some(e => e.type === 'agent_settled'), 'no-entry response')
        assert.match(doctor(info), /PM 提醒工具\s+.*unknown evidence:ENOENT/)
        assert(!existsSync(join(info.state, 'reminders/state.json')))
      } finally { await stop(info) }
    })
    await test('generated config mismatch hides the tool and leaves a specific doctor error', async () => {
      const info = await start('config-mismatch', async ({ n, res }) => sse(res, { name: 'config-mismatch', ...final('config mismatch') }), {
        configure: mismatchGeneratedSession, deferFirstResponse: true,
      })
      try {
        await until(() => existsSync(join(info.state, 'remind-tool/current.json')) && events(info).some(e => e.type === 'agent_settled'), 'config mismatch settles')
        assertConfigMismatch(info)
      } finally { await stop(info) }
    })
    await test('flip: deleting config-error evidence turns the named visibility assertion red', async () => {
      const info = await start('config-error-flip', async ({ n, res }) => sse(res, { name: 'config-error-flip', ...final('config error flip') }), {
        skillCopy: true, configure: mismatchGeneratedSession, deferFirstResponse: true,
        mutate: copied => {
          const path = join(copied, 'extension/team-remind.ts'), source = readFileSync(path, 'utf8')
          const anchor = "        publish('error', 'hidden', e?.message ?? String(e))"
          assert.equal(source.split(anchor).length, 2)
          writeFileSync(path, source.replace(anchor, '        // P450 flip: config-error evidence write removed'))
        },
      })
      try {
        await until(() => events(info).some(e => e.type === 'agent_settled'), 'config error flip settles')
        let failure
        try { assertConfigMismatch(info) } catch (e) { failure = e }
        assert.match(failure?.message ?? '', /mismatched config leaves visible error evidence/,
          'removing the write must fail the named error-evidence assertion')
        console.log(`EXPECTED RED config-error evidence: ${failure.message.split('\n')[0]}`)
      } finally { await stop(info) }
    })
    await test('explicit bootstrap failure is error while fresh', async () => {
      const info = await start('loaderror', async ({ n, res }) => sse(res, { name: 'loaderror', ...final('load error') }), {
        skillCopy: true, deferFirstResponse: true,
        mutate: copied => {
          const path = join(copied, 'extension/team-remind.ts'), source = readFileSync(path, 'utf8')
          const anchor = "pi.registerTool(definition('direct') as any)"
          assert.equal(source.split(anchor).length, 2)
          writeFileSync(path, source.replace(anchor, "throw new Error('controlled direct registration failure')"))
        },
      })
      try {
        await until(() => existsSync(join(info.state, 'remind-tool/current.json')), 'bootstrap error evidence')
        const record = json(join(info.state, 'remind-tool/current.json'))
        assert.equal(record.status, 'error'); assert.equal(record.exposure, 'hidden')
        assert.match(doctor(info), /PM 提醒工具\s+.*error controlled direct registration failure/)
        assert(!existsSync(join(info.state, 'reminders/state.json')))
      } finally { await stop(info) }
    })
  }
} finally {
  server.closeAllConnections(); await new Promise(resolve => server.close(resolve))
  const remaining = spawnSync('tmux', ['-S', socket, 'list-sessions'], { env: base, encoding: 'utf8' })
  if (remaining.status === 0) tmux('kill-server')
  else assert.match(remaining.stderr, /no server running|error connecting/, 'only the private server may already be gone')
  if (!process.env.P442_KEEP) rmSync(temporary, { recursive: true, force: true })
  else console.log(`kept private fixture root=${temporary}`)
}
console.log(`remind-tool-real: passed=${passed} failed=${failed} evidence=${evidence}`)
if (failed) process.exitCode = 1
