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
  if (n === 0 && plan.gate) await plan.gate
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
  for (const path of [dir, home, state, join(root, 'docs/team/tasks'), join(root, 'docs/team/inbox'), join(root, 'docs/team/outbox'), join(home, '.pi/agent')]) mkdirSync(path, { recursive: true })
  const runSkill = opts.skillCopy ? join(root, 'skill') : skill
  if (opts.skillCopy) cpSync(skill, runSkill, { recursive: true })
  if (opts.mutate) opts.mutate(runSkill)
  writeFileSync(join(home, '.pi/agent/settings.json'), JSON.stringify({ retry: { enabled: false }, compaction: { enabled: false } }))
  command('git', ['init', '-q', '-b', 'main'], { cwd: root })
  const session = `p442-${name}`, fixture = join(tests, 'fixtures/remind-tool-provider.ts')
  const extra = `--offline --no-extensions --no-skills --no-context-files -e ${sh(fixture)}`
  writeFileSync(config, `TEAM_PROJECT='${session}'\nTEAM_SESSION='${session}'\nTEAM_PM_WINDOW='pm'\nTEAM_PM_MODEL='p442/controlled'\nTEAM_TASK_MODELS='routine=p442/controlled analysis=p442/controlled verify=p442/controlled code=p442/controlled'\nTEAM_VCS='local'\nTEAM_PI_THEME='dark'\nTEAM_PI_BIN=${sh(pi)}\nTEAM_PM_EXTRA_PI_ARGS=${sh(extra)}\n`)
  const prompt = join(state, 'pm-prompt.md'); writeFileSync(prompt, `CASE ${name}\n`)
  const env = { ...base, HOME: home, PI_CODING_AGENT_DIR: join(home, '.pi/agent'), P442_EVIDENCE: dir,
    P442_ENDPOINT: `http://127.0.0.1:${port}/${name}/v1`, TEAM_REMIND_POLL_MS: '200' }
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
  writeFileSync(join(dir, 'launch.txt'), launch + '\n')
  if (!opts.invalid) assert.equal((launch.match(/extension\/team-remind\.ts/g) ?? []).length, 1, 'one directed Reminder extension')
  let release
  const gate = opts.deferFirstResponse ? new Promise(resolve => { release = resolve }) : null
  plans.set(name, { requests: 0, dir, state, respond, gate })
  const window = opts.invalid === 'forged' ? 'not-pm' : 'pm'
  tmux('new-session', '-d', '-s', session, '-n', window, '-c', root, 'sleep 600')
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
  const ticker = setInterval(() => {
    if (['ordinary', 'worker', 'forged', 'no-entry'].includes(opts.invalid)) return
    spawnSync(process.execPath, [join(runSkill, 'scripts/remind-tick.mjs'), '--root', root, '--state-dir', state,
      '--pulse-started', new Date().toISOString(), '--json'], { cwd: root, env, stdio: 'ignore' })
  }, 250)
  info.ticker = ticker
  return info
}
async function stop(info) {
  clearInterval(info.ticker)
  if (!existsSync(info.done)) {
    tmux('send-keys', '-t', info.pane, '-l', '/p442-control stop'); tmux('send-keys', '-t', info.pane, 'Enter')
    await until(() => existsSync(info.done), `${info.name} shutdown`)
  }
  tmux('kill-session', '-t', info.session)
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

  if (selection.includes('doctor')) {
    await test('running PM with no entry is unknown, not a load failure', async () => {
      const info = await start('noentry', async ({ n, res }) => sse(res, { name: 'noentry', ...final('no entry') }), { invalid: 'no-entry', deferFirstResponse: true })
      try {
        await until(() => events(info).some(e => e.type === 'agent_settled'), 'no-entry response')
        assert.match(doctor(info), /PM 提醒工具\s+.*unknown evidence:ENOENT/)
        assert(!existsSync(join(info.state, 'reminders/state.json')))
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
  rmSync(temporary, { recursive: true, force: true })
}
console.log(`remind-tool-real: passed=${passed} failed=${failed} evidence=${evidence}`)
if (failed) process.exitCode = 1
