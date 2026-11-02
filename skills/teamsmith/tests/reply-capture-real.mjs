#!/usr/bin/env node
import assert from 'node:assert/strict'
import { createServer } from 'node:http'
import { spawnSync } from 'node:child_process'
import { appendFileSync, cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { setTimeout as delay } from 'node:timers/promises'
import { CaptureJournal, captureDiskFingerprint, inspectRuntime } from '../scripts/reply-capture.mjs'
const tests = dirname(fileURLToPath(import.meta.url)), skill = dirname(tests)
const selection = (process.argv.find(a => a.startsWith('--select='))?.slice(9) ?? (process.argv.includes('--select') ? process.argv[process.argv.indexOf('--select') + 1] : undefined) ?? 'print,tui,terminal,identity,lifecycle,owner-mutations').split(',')
const evidence = resolve(process.env.P396_EVIDENCE ?? `${process.env.HOME}/.cache/P396/pi-${Date.now()}`)
mkdirSync(evidence, { recursive: true, mode: 0o700 })
const temporary = mkdtempSync('/var/tmp/p396-real-'), socket = join(temporary, 'socket')
const pi = process.env.P396_PI ?? `${process.env.HOME}/.bun/bin/pi`
const bunbin = dirname(pi)
mkdirSync(join(temporary, 'driver-home'))
const base = { HOME: join(temporary, 'driver-home'), PATH: `${bunbin}:/usr/local/bin:/usr/bin:/bin`, LANG: 'C.UTF-8', TERM: 'xterm-256color', USER: process.env.USER ?? 'fixture', LOGNAME: process.env.LOGNAME ?? 'fixture', TMPDIR: temporary }
const sh = value => `'${value.replaceAll("'", "'\\''")}'`
function command(bin, args, options = {}) {
  const r = spawnSync(bin, args, { encoding: 'utf8', env: base, ...options })
  assert.equal(r.error, undefined, `${bin}: ${r.error}`)
  assert.equal(r.status, 0, `${bin} ${args.join(' ')}: ${r.stderr}\n${r.stdout}`)
  return r.stdout
}
const tmux = (...args) => command('tmux', ['-S', socket, '-f', '/dev/null', ...args])
const json = path => JSON.parse(readFileSync(path, 'utf8'))
const jsonl = path => existsSync(path) ? readFileSync(path, 'utf8').trim().split('\n').filter(Boolean).map(s => JSON.parse(s)) : []
const text = message => message.content.filter(b => b.type === 'text').map(b => b.text).join('')
let server, failed = 0, passed = 0
async function until(test, label) {
  const end = Date.now() + 90000 // External fixture watchdog only, not a product latency assertion.
  while (!test()) { if (Date.now() > end) throw new Error(`watchdog: ${label}`); await delay(40) }
}
const plans = new Map()
server = createServer(async (req, res) => {
  let raw = ''; for await (const chunk of req) raw += chunk
  const body = JSON.parse(raw), name = req.url.split('/')[1], plan = plans.get(name)
  if (!plan) { res.writeHead(404); res.end(); return }
  const n = plan.requests++
  appendFileSync(join(plan.dir, 'requests.jsonl'), JSON.stringify(body) + '\n')
  if (n === 0 && plan.gate) await plan.gate
  if (plan.kind === 'retry' && n === 1) { res.writeHead(503, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ error: { message: 'controlled 503 overload', type: 'server_error' } })); return }
  const followup = n > 0 && ['queued', 'continued', 'tool', 'retry'].includes(plan.kind)
  let answer = followup ? `普通续答 ${name}` : `决定 ${name} 保留。\n[[team-reply:决定 ${name}]]`
  let finish = plan.kind === 'length' ? 'length' : 'stop'
  if (plan.kind === 'partial') answer = `未闭控制 ${name}\n[[team-reply:未闭`
  res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive' })
  const emit = (delta, reason = null) => res.write(`data: ${JSON.stringify({ id: `fixture-${name}-${n}`, object: 'chat.completion.chunk', created: 1, model: 'controlled', choices: [{ index: 0, delta, finish_reason: reason }] })}\n\n`)
  emit({ role: 'assistant', content: '' })
  // Whole markers actually arrive in raw output; the interactive case leaves them visible until message_end.
  for (const chunk of [answer.slice(0, answer.indexOf('\n') + 1), answer.slice(answer.indexOf('\n') + 1)]) {
    if (chunk) { emit({ content: chunk }); await delay(100) }
  }
  if (plan.kind === 'aborted') await delay(250)
  if (plan.kind === 'error') { res.destroy(new Error('controlled stream interruption')); return }
  if (plan.kind === 'tool' && n === 0) {
    emit({ tool_calls: [{ index: 0, id: 'fixture-call', type: 'function', function: { name: 'p396-tool', arguments: '{}' } }] })
    finish = 'tool_calls'
  }
  emit({}, finish); res.end('data: [DONE]\n\n')
})
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve))
const port = server.address().port
async function run(name, kind = 'print', opts = {}) {
  const dir = join(evidence, name), root = join(temporary, name), home = join(root, 'home'), state = join(root, '.pi/team/state'), config = join(root, '.pi/team/config.sh')
  for (const path of [dir, home, state, join(root, 'docs/team/tasks'), join(root, 'docs/team/inbox'), join(root, 'docs/team/outbox'), join(home, '.pi/agent')]) mkdirSync(path, { recursive: true })
  const runSkill = opts.skillCopy ? join(root, 'skill') : skill
  if (opts.skillCopy) cpSync(skill, runSkill, { recursive: true })
  if (opts.ownerFlip) {
    const path = join(runSkill, 'extension/team-reply.ts'), bytes = readFileSync(path, 'utf8'), anchor = 'if (owners.has(key)) return'
    assert.equal(bytes.split(anchor).length, 2); writeFileSync(path, bytes.replace(anchor, 'if (false) return'))
  }
  writeFileSync(join(home, '.pi/agent/settings.json'), JSON.stringify({ retry: { enabled: kind === 'retry', maxRetries: 1, baseDelayMs: 1 }, compaction: { enabled: false } }))
  writeFileSync(join(root, 'docs/team/BOARD.md'), '# untouched\n')
  command('git', ['init', '-q', '-b', 'main'], { cwd: root })
  const session = `p396-${name}`, mode = kind === 'tui' || opts.interactive ? '' : '--print'
  const fixture = join(tests, 'fixtures/reply-capture-provider.ts')
  let extra = `--offline --no-extensions --no-skills --no-tools --no-context-files ${mode} -e ${sh(fixture)}`
  let copy
  if (opts.duplicate) {
    copy = join(root, 'copy')
    cpSync(runSkill, copy, { recursive: true })
    extra += ` -e ${sh(join(copy, 'extension/team-reply.ts'))}`
  }
  writeFileSync(config, `TEAM_PROJECT='${session}'\nTEAM_SESSION='${session}'\nTEAM_PM_WINDOW='pm'\nTEAM_PM_MODEL='p396/controlled'\nTEAM_TASK_MODELS='routine=p396/controlled analysis=p396/controlled verify=p396/controlled'\nTEAM_VCS='local'\nTEAM_PI_THEME='dark'\nTEAM_PI_BIN=${sh(pi)}\nTEAM_PM_EXTRA_PI_ARGS=${sh(extra)}\n`)
  const prompt = join(state, 'pm-prompt.md'); writeFileSync(prompt, `CASE ${name}\n`)
  const env = { ...base, HOME: home, PI_CODING_AGENT_DIR: join(home, '.pi/agent'), P396_CASE: kind, P396_EVIDENCE: dir, P396_ENDPOINT: `http://127.0.0.1:${port}/${name}/v1`, P396_TUI: kind === 'tui' ? '1' : '0' }
  const sourceScript = `source ${sh(join(runSkill, 'scripts/lib/common.sh'))}; source ${sh(join(runSkill, 'scripts/lib/cmd-config.sh'))}; team_load_config; team_pm_launch_cmd ${sh(prompt)} ${sh(join(state, 'pm.pid.spawn'))}`
  let launch = command('bash', ['-c', sourceScript], { cwd: root, env })
  if (opts.invalid === 'no-entry') launch = launch.replace(` -e ${join(runSkill, 'extension/team-reply.ts')}`, '')
  if (opts.invalid === 'foreign' || opts.invalid === 'worker') {
    const other = join(root, opts.invalid)
    if (opts.invalid === 'foreign') { mkdirSync(other); command('git', ['init', '-q', '-b', 'main'], { cwd: other }) }
    else {
      writeFileSync(join(root, 'README'), 'fixture'); command('git', ['add', 'README'], { cwd: root })
      command('git', ['-c', 'user.name=fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture'], { cwd: root })
      command('git', ['worktree', 'add', '-q', '--detach', other, 'HEAD'], { cwd: root })
    }
    launch = launch.replace(`cd ${root} &&`, `cd ${other} &&`)
  }
  if (opts.invalid === 'inherited') launch = launch.replace(`export TEAM_ROOT=${sh(root)}`, `export TEAM_ROOT=${sh(join(root, 'elsewhere'))}`)
  if (opts.invalid === 'config-link') {
    const real = join(root, 'real-config.sh'); writeFileSync(real, readFileSync(config, 'utf8')); rmSync(config); symlinkSync(real, config)
  }
  if (opts.invalid === 'ordinary') launch = `cd ${sh(root)} && exec ${sh(pi)} --provider p396 --model controlled -e ${sh(join(skill, 'extension/team-reply.ts'))} ${extra} @${sh(prompt)}`
  if (opts.invalid === 'custom') {
    const custom = `${sh(pi)} --provider {provider} --model {model} ${extra} {prompt}`
    const customScript = sourceScript.replace('; team_pm_launch_cmd ', `; TEAM_PM_FRESH_LAUNCH=1; TEAM_PM_CMD=${sh(custom)}; team_pm_launch_cmd `)
    launch = command('bash', ['-c', customScript], { cwd: root, env })
    assert(!launch.includes('extension/team-reply.ts'), 'custom template was not injected')
  }
  writeFileSync(join(dir, 'launch.txt'), launch + '\n')
  if (!opts.invalid) assert.equal((launch.match(/extension\/team-reply\.ts/g) ?? []).length, opts.duplicate ? 2 : 1, 'one directed entry plus explicitly requested test copy')
  assert(!launch.includes('extension/team-notify.ts'), 'recipient PM does not load worker notify')
  let release
  const gate = opts.onReady ? new Promise(resolve => { release = resolve }) : null
  plans.set(name, { requests: 0, kind, dir, gate })
  // Start a quiet private pane, install the raw PTY tap before the actual builtin launch.
  tmux('new-session', '-d', '-s', session, '-n', 'pm', '-c', root, 'sleep 600')
  const globalBefore = tmux('show-environment', '-g')
  const pane = tmux('display-message', '-p', '-t', `${session}:pm`, '#{pane_id}').trim()
  tmux('pipe-pane', '-O', '-t', pane, `cat >>${sh(join(dir, 'raw.pty'))}`)
  const script = join(root, 'launch.sh'), done = join(dir, 'done')
  // All environment is process-local. Never set-environment -g or mutate the caller's tmux server.
  const assignments = Object.entries(env).map(([key, value]) => `export ${key}=${sh(value)};`).join('\n')
  writeFileSync(script, `#!/usr/bin/env bash\n${assignments}\nunset TEAM_ROOT TEAM_MAIN_ROOT TEAM_CONFIG_FILE TEAM_STATE_DIR\nbash -c ${sh(launch)} ${sh(readFileSync(prompt, 'utf8'))} ${kind === 'tui' || opts.interactive ? '' : `>${sh(join(dir, 'stdout'))} 2>${sh(join(dir, 'stderr'))}`}\nrc=$?; printf '%s\\n' "$rc" >${sh(done)}\nsleep 600\n`)
  tmux('respawn-pane', '-k', '-t', pane, `bash ${sh(script)}`)
  if (opts.onReady) {
    await until(() => existsSync(join(dir, 'session-start')) || existsSync(done), `${name} startup`)
    try { await opts.onReady({ dir, root, state, config, session, env, pane, skill: runSkill }) } finally { release() }
  }
  if (opts.interactive) {
    try { await opts.interactive({ dir, root, state, config, session, env, pane, skill: runSkill }) }
    catch (e) {
      cpSync(state, join(dir, 'state'), { recursive: true })
      writeFileSync(join(dir, 'failure-screen.txt'), tmux('capture-pane', '-p', '-S', '-', '-t', pane))
      throw e
    }
  }
  const customExit = join(state, 'pm-launch.exit')
  await until(() => existsSync(done) || (opts.invalid === 'custom' && existsSync(customExit)), `${name} launch`)
  if (opts.interactive) {
    cpSync(state, join(dir, 'state'), { recursive: true })
    cpSync(join(home, '.pi/agent/sessions'), join(dir, 'sessions'), { recursive: true })
    writeFileSync(join(dir, 'final-screen.txt'), tmux('capture-pane', '-p', '-S', '-', '-t', pane))
    assert.equal(tmux('show-environment', '-g'), globalBefore, 'capture does not write tmux global identity')
    tmux('kill-session', '-t', session)
    return
  }
  const rc = existsSync(done) ? Number(readFileSync(done, 'utf8').trim()) : Number(readFileSync(customExit, 'utf8').trim().split(' ')[1])
  const events = jsonl(join(dir, 'events.jsonl')), requests = jsonl(join(dir, 'requests.jsonl'))
  const ends = events.filter(e => e.type === 'message_end'), turns = events.filter(e => e.type === 'turn_end')
  assert(ends.length, `${name}: no finalized assistant; stderr=${existsSync(join(dir, 'stderr')) ? readFileSync(join(dir, 'stderr'), 'utf8') : tmux('capture-pane', '-p', '-t', pane)}`)
  const start = events.find(e => e.type === 'session_start')
  cpSync(state, join(dir, 'state'), { recursive: true })
  if (start?.sessionFile && existsSync(start.sessionFile)) cpSync(start.sessionFile, join(dir, 'transcript.jsonl'))
  assert(start && !start.finalPidPresent, 'initial startup precedes final pm.pid metadata')
  if (!['ordinary', 'custom'].includes(opts.invalid)) assert(start.spawnPresent, 'initial capture observes the spawn proof')
  for (const event of ends) {
    if (opts.invalid) assert(text(event.message).includes('[[team-reply'), `${name}: unproven context must stay literal`)
    else if (kind === 'partial') assert(text(event.message).includes('[[team-reply:未闭'))
    else assert(!text(event.message).includes('[[team-reply'), `${name}: finalized marker leaked`)
    const turn = turns.find(t => t.entry?.message?.timestamp === event.message.timestamp)
    assert(turn?.id && turn.entry.id === turn.id, `${name}: real entry binding`)
    assert.deepEqual(turn.entry.message, event.message)
    assert.notEqual(event.leaf, turn.id, `${name}: message_end precedes Pi append`)
  }
  assert(events.find(e => e.type === 'agent_settled'), `${name}: missing real settled`)
  const transcript = jsonl(start.sessionFile)
  for (const entry of transcript.filter(e => e.type === 'message' && e.message.role === 'assistant')) {
    if (kind !== 'partial' && !opts.invalid) assert(!text(entry.message).includes('[[team-reply'), 'transcript cleanup')
  }
  const index = join(state, 'key-replies/index.v1'), count = existsSync(index) ? readFileSync(index).length / 4096 : 0
  const expected = !opts.invalid && !opts.noPublish && ['print', 'tui'].includes(kind) ? 1 : 0
  assert.equal(count, expected, `${name}: store count`)
  const journalDir = join(state, 'reply-capture'), sourceFiles = existsSync(journalDir) ? readdirSync(journalDir).filter(s => s.endsWith('.json') && s !== 'runtime.json') : []
  const source = sourceFiles.length ? json(join(journalDir, sourceFiles[0])) : null
  if (expected) {
    const record = Object.values(source.sources)[0]
    assert.equal(record.status, 'saved'); assert.equal(record.no, 1)
    const body = readdirSync(join(state, 'key-replies/bodies')).map(file => readFileSync(join(state, 'key-replies/bodies', file), 'utf8'))
    assert.deepEqual(body, [text(ends.at(-1).message)])
  }
  if (kind === 'overallabort') assert(events.find(e => e.type === 'agent_settled').aborted, 'real stop followed by overall abort')
  if (['queued', 'continued', 'tool', 'retry'].includes(kind)) {
    assert.equal(ends.length, kind === 'retry' ? 3 : 2); assert.equal(requests.length, kind === 'retry' ? 3 : 2)
    if (kind === 'retry') assert(ends.some(e => e.message.stopReason === 'error') && ends.at(-1).message.stopReason === 'stop', 'real 503 error terminal then retry stop')
    if (kind === 'tool') assert(ends.some(e => e.message.stopReason === 'toolUse' && e.message.content.some(b => b.type === 'toolCall')), 'actual tool-use terminal and tool metadata retained')
    const history = requests[1].messages.filter(m => m.role === 'assistant')
    assert.equal(history.length, 1); assert.equal(history[0].content, text(ends[0].message))
    assert(!JSON.stringify(history).includes('[[team-reply'), 'next provider history is clean')
  }
  if (kind === 'print') assert.equal(readFileSync(join(dir, 'stdout'), 'utf8'), text(ends.at(-1).message) + '\n', 'exact final print stdout')
  if (kind === 'tui') {
    await delay(100)
    const raw = readFileSync(join(dir, 'raw.pty'), 'utf8')
    assert(raw.includes(`[[team-reply:决定 ${name}]]`), 'raw PTY actual matching marker positive')
    const screen = tmux('capture-pane', '-p', '-S', '-', '-t', pane)
    writeFileSync(join(dir, 'final-screen.txt'), screen)
    assert(screen.includes(`决定 ${name} 保留。`), 'final frame matching body positive')
    assert(!screen.includes('[[team-reply'), 'final frame has no complete control')
    // Scrollback may retain transient frames: validate finalized authoritative message separately, never claim zero flash.
    assert(raw.includes(`决定 ${name} 保留。`), 'raw PTY actual body positive')
  }
  assert.equal(tmux('show-environment', '-g'), globalBefore, 'capture does not write tmux global identity')
  assert.equal(readFileSync(join(root, 'docs/team/BOARD.md'), 'utf8'), '# untouched\n')
  assert.equal(readdirSync(join(root, 'docs/team/tasks')).length, 0)
  assert.equal(readdirSync(join(root, 'docs/team/inbox')).length, 0)
  assert.equal(readdirSync(join(root, 'docs/team/outbox')).length, 0)
  for (const file of ['notify.events', 'pending', 'wake']) assert(!existsSync(join(state, file)), `no ${file} publication side effect`)
  const runtime = events.find(e => e.type === 'runtime')?.value
  if (opts.invalid) assert.equal(runtime, undefined, 'unproven context cannot register ready')
  else {
    assert.equal(runtime?.fingerprint?.length, 64, 'actual loaded source registered')
    assert.equal(runtime.status, 'degraded', 'shutdown registration is not falsely ready')
    assert.equal(runtime.reason, 'session shutdown')
    assert.equal(runtime.extension, join(runSkill, 'extension/team-reply.ts'), 'first path keeps owner/runtime even with a second loaded copy')
  }
  writeFileSync(join(dir, 'receipt.json'), JSON.stringify({ rc, events: events.map(e => e.type), sources: source, requests: requests.length, storeCount: count, runtime }, null, 2))
  tmux('kill-session', '-t', session)
  return { dir, root, state, config, session, env, pane, events, requests, runtime, rc }
}
const storeCount = state => existsSync(join(state, 'key-replies/index.v1')) ? readFileSync(join(state, 'key-replies/index.v1')).length / 4096 : 0
const confirmedCount = state => existsSync(join(state, 'reply-capture')) ? readdirSync(join(state, 'reply-capture'))
  .filter(f => f.endsWith('.json') && f !== 'runtime.json')
  .flatMap(f => Object.values(json(join(state, 'reply-capture', f)).sources)).filter(s => s.status === 'saved').length : 0
async function control(info, action) {
  const path = join(info.dir, 'events.jsonl'), previous = jsonl(path).filter(e => e.type === 'command_done' && e.action === action).length
  tmux('send-keys', '-t', info.pane, '-l', `/p396-control ${action}`); tmux('send-keys', '-t', info.pane, 'Enter')
  await until(() => jsonl(path).filter(e => e.type === 'command_done' && e.action === action).length > previous, `command ${action}`)
}
async function prompt(info, value) {
  const path = join(info.dir, 'events.jsonl'), previous = jsonl(path).filter(e => e.type === 'agent_settled').length
  tmux('send-keys', '-t', info.pane, '-l', value); tmux('send-keys', '-t', info.pane, 'Enter')
  await until(() => jsonl(path).filter(e => e.type === 'agent_settled').length > previous, `prompt ${value}`)
}
async function test(name, body) {
  try { await body(); console.log(`PASS real Pi ${name}`); passed++ }
  catch (e) { failed++; console.error(`FAIL real Pi ${name}: ${e.stack}`) }
}
try {
  if (selection.includes('print')) await test('builtin print/end/append/entry/settled/raw store/transcript', () => run('print'))
  if (selection.includes('tui')) await test('interactive actual-marker raw PTY and authoritative final cleanup', () => run('tui', 'tui'))
  if (selection.includes('terminal')) {
    for (const kind of ['length', 'error', 'aborted', 'partial', 'queued', 'continued', 'tool', 'retry', 'overallabort']) await test(`${kind} cleanup and publication eligibility`, () => run(kind, kind))
    await test('staging journal fault preserves real Pi stdout/transcript', () => run('stage-failure', 'print', {
      noPublish: true,
      onReady: async info => {
        const start = jsonl(join(info.dir, 'events.jsonl')).find(e => e.type === 'session_start')
        const journal = new CaptureJournal({ root: info.root, state: info.state, sessionId: start.sessionId, sessionFile: start.sessionFile })
        const outside = join(info.root, 'not-a-lock'); writeFileSync(outside, 'unchanged'); symlinkSync(outside, `${journal.path}.lock`)
      },
    }))
  }
  if (selection.includes('owner-flip')) await test('first path keeps owner/runtime', () => run('owner-flip', 'print', { skillCopy: true, duplicate: true, ownerFlip: true }))
  if (selection.includes('owner-control')) await test('first path keeps owner/runtime', () => run('owner-control', 'print', { skillCopy: true, duplicate: true }))
  if (selection.includes('owner-mutations')) await test('owner mutation named red and restoration green in private Pi', async () => {
    for (const [group, code] of [['owner-flip', 1], ['owner-control', 0]]) {
      const result = spawnSync(process.execPath, [fileURLToPath(import.meta.url), `--select=${group}`], { env: { ...process.env, P396_EVIDENCE: join(evidence, group) }, encoding: 'utf8' })
      const output = result.stdout + result.stderr
      writeFileSync(join(evidence, `${group}.log`), output)
      assert.equal(result.status, code, output)
      assert(output.includes(code ? 'first path keeps owner/runtime' : 'passed=1 failed=0'), output)
    }
  })
  if (selection.includes('lifecycle')) {
    await test('loaded dependency reload evaluates new code; tree/fork/new/switch do not import', () => run('lifecycle', 'lifecycle', {
      skillCopy: true,
      interactive: async info => {
        await until(() => storeCount(info.state) === 1 && confirmedCount(info.state) === 1, 'first lifecycle receipt journaled')
        const path = join(info.state, 'reply-capture/runtime.json'), first = json(path)
        await control(info, 'snapshot')
        const launchHash = () => command('bash', ['-c', `TEAM_SKILL_DIR=${sh(info.skill)}; source ${sh(join(info.skill, 'scripts/lib/cmd-update.sh'))}; team_skill_hash`], { env: info.env, cwd: info.root }).trim()
        const launchBefore = launchHash()
        const parser = join(info.skill, 'scripts/reply-capture.mjs'), old = readFileSync(parser, 'utf8')
        const anchor = "return { ...result, title, candidate: true, reason: 'candidate' }"
        assert(old.includes(anchor)); writeFileSync(parser, old.replace(anchor, "return { ...result, title: 'dependency-loaded-v2', candidate: true, reason: 'candidate' }"))
        const stale = inspectRuntime({ ...info, window: 'pm' }); assert.equal(stale.state, 'stale'); assert.equal(stale.loaded, first.fingerprint)
        const launchAfter = launchHash(); assert.notEqual(launchAfter, launchBefore, 'launch/version hash includes dependency-only edits')
        await control(info, 'reload')
        await until(() => json(path).status === 'ready' && json(path).generation !== first.generation, 'new loaded generation')
        const second = json(path)
        writeFileSync(join(info.dir, 'fingerprints.json'), JSON.stringify({ before: first, stale, after: second, launchBefore, launchAfter }, null, 2))
        assert.equal(second.fingerprint, captureDiskFingerprint(info.skill)); assert.notEqual(second.fingerprint, first.fingerprint)
        assert.equal(storeCount(info.state), 1, 'reload cannot reattempt saved source')
        await prompt(info, 'CASE lifecycle-after-reload')
        await until(() => storeCount(info.state) === 2 && confirmedCount(info.state) === 2, 'new dependency receipt journaled')
        const source = readdirSync(join(info.state, 'reply-capture')).find(f => f.endsWith('.json') && f !== 'runtime.json')
        const saved = Object.values(json(join(info.state, 'reply-capture', source)).sources).filter(s => s.status === 'saved')
        assert.equal(saved.find(s => s.no === 2)?.title, 'dependency-loaded-v2', 'evaluated replacement dependency, not reread hash over stale code')
        await control(info, 'tree'); assert.equal(storeCount(info.state), 2)
        await prompt(info, 'CASE lifecycle-after-tree'); await until(() => storeCount(info.state) === 3 && confirmedCount(info.state) === 3, 'post-tree new source journaled')
        await control(info, 'fork')
        assert.notEqual(json(path).sessionId, second.sessionId); assert.equal(storeCount(info.state), 3, 'copied fork entries never imported')
        assert.equal(readdirSync(join(info.state, 'reply-capture')).filter(f => f.endsWith('.json') && f !== 'runtime.json').length, 1)
        await prompt(info, 'CASE lifecycle-new-fork-entry'); await until(() => storeCount(info.state) === 4 && confirmedCount(info.state) === 4, 'new fork source journaled')
        await control(info, 'new'); assert.equal(storeCount(info.state), 4)
        await control(info, 'switch'); assert.equal(json(path).sessionId, second.sessionId); assert.equal(storeCount(info.state), 4)
        const events = jsonl(join(info.dir, 'events.jsonl'))
        assert(events.filter(e => e.type === 'session_start').length >= 5)
        assert(events.filter(e => e.type === 'message_end').every(e => !text(e.message).includes('[[team-reply')))
        await control(info, 'stop')
      },
    }))
    await test('reload cannot invent a never-injected entry', () => run('noentry', 'lifecycle', {
      skillCopy: true, invalid: 'no-entry',
      interactive: async info => {
        const events = join(info.dir, 'events.jsonl')
        await until(() => jsonl(events).some(e => e.type === 'agent_settled'), 'no-entry first answer')
        assert(!existsSync(join(info.state, 'reply-capture/runtime.json')))
        await control(info, 'reload'); await prompt(info, 'CASE noentry-after-reload')
        assert.equal(storeCount(info.state), 0); assert(!existsSync(join(info.state, 'reply-capture')))
        assert(jsonl(events).filter(e => e.type === 'message_end').every(e => text(e.message).includes('[[team-reply')))
        await control(info, 'stop')
      },
    }))
  }
  if (selection.includes('identity')) {
    for (const invalid of ['foreign', 'worker', 'ordinary', 'custom', 'inherited', 'config-link']) await test(`${invalid} context cannot clean/publish/register`, () => run(invalid, 'print', { invalid }))
    await test('two loaded paths share one owner and generation', () => run('duplicate', 'print', { duplicate: true }))
    await test('live registration distinct from disk, dead/reused process and readonly doctor', () => run('runtime', 'print', {
      onReady: async info => {
        const args = { ...info, window: 'pm', skill }
        const path = join(info.state, 'reply-capture/runtime.json'), original = readFileSync(path, 'utf8'), registration = JSON.parse(original)
        const before = inspectRuntime(args); assert.equal(before.state, 'ready'); assert.equal(before.disk, before.loaded)
        for (const patch of [{ pid: 2147483647 }, { starttime: String(Number(registration.starttime) + 1) }]) {
          writeFileSync(path, JSON.stringify({ ...registration, ...patch }))
          assert.equal(inspectRuntime(args).state, 'stale', 'dead or reused process not ready')
        }
        writeFileSync(path, original)
        const isolated = join(info.root, 'fingerprint-copy')
        for (const file of ['extension/team-reply.ts', 'scripts/reply-capture.mjs', 'scripts/replies.mjs']) {
          mkdirSync(dirname(join(isolated, file)), { recursive: true }); cpSync(join(skill, file), join(isolated, file))
        }
        assert.equal(inspectRuntime({ ...args, skill: isolated }).state, 'ready')
        appendFileSync(join(isolated, 'scripts/reply-capture.mjs'), '\n// dependency-only fixture edit\n')
        const stale = inspectRuntime({ ...args, skill: isolated }); assert.equal(stale.state, 'stale'); assert.notEqual(stale.disk, stale.loaded)
        const doctor = spawnSync('bash', [join(skill, 'scripts/team'), '--root', info.root, 'doctor'], { cwd: info.root, env: info.env, encoding: 'utf8' })
        writeFileSync(join(info.dir, 'doctor.txt'), doctor.stdout + doctor.stderr)
        assert.match(doctor.stdout, /关键回复运行/); assert.match(doctor.stdout, /ready disk=/)
        assert.equal(readFileSync(path, 'utf8'), original, 'doctor cannot repair/update the live registration')
        assert(!readdirSync(join(info.state, 'reply-capture')).some(f => f.endsWith('.json') && f !== 'runtime.json'), 'doctor cannot create source records')
        writeFileSync(join(info.state, 'pm.pid'), `${registration.pid}\n`)
        writeFileSync(join(info.state, 'pm.pid.proof'), 'spawn\n')
        rmSync(join(info.state, 'pm.pid.spawn')) // Private launcher completes metadata after initial extension registration.
        assert.equal(inspectRuntime(args).state, 'ready', 'late final metadata remains the same running PM')
      },
    }))
  }
} finally {
  server.closeAllConnections(); await new Promise(resolve => server.close(resolve))
  // This socket was allocated by this invocation, never the live/default server.
  const remaining = spawnSync('tmux', ['-S', socket, 'list-sessions'], { env: base, encoding: 'utf8' })
  if (remaining.status === 0) tmux('kill-server')
  else assert.match(remaining.stderr, /no server running|error connecting/, 'only an already-exited private server is expected')
  rmSync(temporary, { recursive: true, force: true })
}
console.log(`reply-capture-real: passed=${passed} failed=${failed} evidence=${evidence}`)
if (failed) process.exitCode = 1
