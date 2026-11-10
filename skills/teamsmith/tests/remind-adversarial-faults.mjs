#!/usr/bin/env node
// P444: real SIGKILL injection around Reminder intent/observation and writeAtomic boundaries.
// Faults exist only in per-case scratch copies. Recovery always runs the unmodified production helper.
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { appendFileSync, cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { setTimeout as delay } from 'node:timers/promises'

const tests = dirname(fileURLToPath(import.meta.url)), skill = dirname(tests)
const root = mkdtempSync('/var/tmp/p444-remind-faults-'), home = join(root, 'home'), tmp = join(root, 'tmp')
mkdirSync(home, { recursive: true }); mkdirSync(tmp, { recursive: true })
const runner = process.execPath, team = join(skill, 'scripts/team'), original = join(skill, 'scripts/state-authority.mjs')
const env = { ...process.env, HOME: home, TMPDIR: tmp }
for (const key of Object.keys(env)) if (key.startsWith('TEAM_') || key === 'TMUX' || key === 'TMUX_PANE') delete env[key]
let passed = 0, failed = 0
const stateFile = repo => join(repo, '.pi/team/state/reminders/state.json')
const snap = repo => JSON.parse(readFileSync(stateFile(repo), 'utf8'))
const lastBatch = repo => snap(repo).batches.at(-1)
const run = (bin, args, options = {}) => {
  const result = spawnSync(bin, args, { encoding: 'utf8', env, ...options })
  assert.equal(result.error, undefined, `${bin}: ${result.error}`)
  return result
}
const good = (result, label) => assert.equal(result.status, 0, `${label}: ${result.stdout}${result.stderr}`)
function newRepo(name) {
  const repo = join(root, name); mkdirSync(repo, { recursive: true })
  good(run('git', ['init', '-q', repo]), 'git init')
  good(run('git', ['-C', repo, '-c', 'user.name=fixture', '-c', 'user.email=fixture@example.invalid',
    'commit', '-q', '--allow-empty', '-m', 'fixture']), 'git commit')
  return repo
}
function authority(helper, repo, args, label = 'authority') {
  const result = run(runner, [helper, '--cli', repo, join(repo, '.pi/team/state'), ...args],
    { cwd: repo, stdio: ['ignore', 'pipe', 'pipe'] })
  writeFileSync(join(repo, 'last-authority.txt'), (result.stdout ?? '') + (result.stderr ?? ''))
  return result
}
function goodAuthority(helper, repo, args, label) {
  const result = authority(helper, repo, args, label)
  good(result, `${label}: ${readFileSync(join(repo, 'last-authority.txt'), 'utf8')}`)
  return JSON.parse(result.stdout)
}
function setup(op, point) {
  const repo = newRepo(`${op}-${point}`)
  const add = run('bash', [team, '--root', repo, 'remind', 'add', '--after', '1s', '--message', `P444 ${op} ${point}`], { cwd: repo })
  good(add, 'real one-second Reminder create')
  goodAuthority(original, repo, ['standby-on', '--reason', 'G1', '--json'], 'G1')
  return repo
}
async function admit(repo) {
  await delay(1100) // Real due time; the fixture never rewrites a clock or a callback timestamp.
  const started = new Date(Date.now() - 10000).toISOString()
  const result = run(runner, [join(skill, 'scripts/remind-tick.mjs'), '--root', repo, '--state-dir', join(repo, '.pi/team/state'),
    '--pulse-started', started, '--json'], { cwd: repo, stdio: ['ignore', 'pipe', 'pipe'] })
  good(result, `due admission: ${result.stdout}${result.stderr}`)
  assert.equal(snap(repo).reminders[0].phase, 'queued')
}
function makeIntent(repo) {
  return goodAuthority(original, repo, ['remind-intent', '--session', 'p444-session', '--pid', '4242'], 'original intent')
}
function observeArgs(intent) {
  return ['remind-observe', '--id', intent.batch.id, '--nonce', intent.batch.nonce,
    '--session', 'p444-session', '--members', JSON.stringify(intent.batch.members)]
}
function faultyHelper(op, point) {
  const dir = join(root, `helper-${op}-${point}`); mkdirSync(dir, { recursive: true })
  cpSync(original, join(dir, 'state-authority.mjs')); cpSync(join(skill, 'scripts/remind-store.mjs'), join(dir, 'remind-store.mjs'))
  const file = join(dir, 'state-authority.mjs'), source = readFileSync(file, 'utf8')
  const fault = `
function p444Fault(point, op, value) {
  if (process.env.P444_KILL_POINT !== point || process.env.P444_FAULT_OP !== op) return;
  if (value) {
    const auditOp = op === 'remind-intent' ? 'remind-intent' : 'remind-observed';
    if (!value.audit?.some(entry => entry.op === auditOp)) return;
  }
  fs.appendFileSync(process.env.P444_FAULT_MARK, point + '\\n');
  process.kill(process.pid, 'SIGKILL');
}
`
  const atomicAnchor = 'function writeAtomic(file, value) {'
  assert.equal(source.split(atomicAnchor).length, 2, 'writeAtomic injection anchor')
  let changed = source.replace(atomicAnchor, `${fault}\n${atomicAnchor}`)
  const anchors = [
    ["  const before = JSON.stringify(snapshot);", "  p444Fault('before-apply', request.op, null);\n  const before = JSON.stringify(snapshot);"],
    ["  const result = apply(snapshot, request, Date.now(), state);", "  const result = apply(snapshot, request, Date.now(), state);\n  p444Fault('after-apply', request.op, snapshot);"],
    ["    fs.writeFileSync(fd, JSON.stringify(value) + '\\n', 'utf8');", "    fs.writeFileSync(fd, JSON.stringify(value) + '\\n', 'utf8');\n    p444Fault('before-file-fsync', request.op, value);"],
    ["    fs.fsyncSync(fd);", "    fs.fsyncSync(fd);\n    p444Fault('after-file-fsync', request.op, value);"],
    ["    fs.renameSync(tmp, file);\n    fsyncDir(dir);", "    fs.renameSync(tmp, file);\n    p444Fault('after-rename', request.op, value);\n    fsyncDir(dir);\n    p444Fault('after-dir-fsync', request.op, value);"],
  ]
  for (const [oldText, newText] of anchors) {
    assert.equal(changed.split(oldText).length, 2, `fault anchor ${oldText}`)
    changed = changed.replace(oldText, newText)
  }
  // writeAtomic has no request parameter; the scratch-only shim receives the selected operation via env.
  changed = changed.replaceAll('request.op, value', 'process.env.P444_FAULT_OP, value')
  writeFileSync(file, changed)
  return join(dir, 'state-authority.mjs')
}
async function runCase(op, point) {
  const repo = setup(op, point)
  await admit(repo)
  const intent = op === 'remind-intent' ? null : makeIntent(repo)
  const helper = faultyHelper(op, point), mark = join(repo, 'fault-mark.txt')
  const requestEnv = { ...env, P444_FAULT_OP: op, P444_KILL_POINT: point, P444_FAULT_MARK: mark }
  const args = op === 'remind-intent' ? ['remind-intent', '--session', 'p444-session', '--pid', '4242'] : observeArgs(intent)
  const result = spawnSync(runner, [helper, '--cli', repo, join(repo, '.pi/team/state'), ...args],
    { cwd: repo, env: requestEnv, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] })
  assert.notEqual(result.status, 0, `${op} ${point}: injected process must die`)
  assert.equal(readFileSync(mark, 'utf8').trim(), point, `${op} ${point}: exact death point reached`)
  const committed = point === 'after-rename' || point === 'after-dir-fsync'
  let current = snap(repo)
  if (op === 'remind-intent') {
    if (committed) {
      assert.equal(current.batches.length, 1); assert.equal(current.reminders[0].phase, 'intent')
      const recovered = goodAuthority(original, repo, args, 'restart with original helper')
      assert.equal(recovered.action, 'wait', 'a durable intent is not sendable again after restart')
      assert.equal(snap(repo).batches.length, 1)
    } else {
      assert.equal(current.batches.length, 0); assert.equal(current.reminders[0].phase, 'queued')
      const recovered = goodAuthority(original, repo, args, 'restart with original helper')
      assert.equal(recovered.action, 'send', 'a pre-intent crash remains eligible once')
      assert.equal(snap(repo).batches.length, 1)
    }
    assert.equal(snap(repo).standby.on, true, 'intent and recovery never clear Standby')
  } else {
    if (committed) {
      assert.equal(current.batches[0].phase, 'observed'); assert.equal(current.reminders[0].phase, 'observed')
      assert.equal(current.standby.on, false); assert.equal(current.batches[0].rightSpentBy, 'wake')
      assert.equal(current.audit.filter(entry => entry.op === 'remind-observed').length, 1)
    } else {
      assert.equal(current.batches[0].phase, 'intent'); assert.equal(current.reminders[0].phase, 'intent')
      assert.equal(current.standby.on, true); assert.equal(current.batches[0].right, 'unspent')
      assert.equal(current.audit.filter(entry => entry.op === 'remind-observed').length, 0)
    }
    goodAuthority(original, repo, ['standby-off', '--json'], 'manual off before fresh G2')
    goodAuthority(original, repo, ['standby-on', '--reason', 'fresh G2', '--json'], 'fresh G2')
    const replay = goodAuthority(original, repo, observeArgs(intent), 'original-helper replay')
    assert.equal(replay.outcome, committed ? 'duplicate' : 'observed')
    assert.equal(replay.standby, committed ? undefined : 'generation-ambiguous')
    current = snap(repo)
    assert.equal(current.standby.on, true); assert.equal(current.standby.generation, 2)
    assert.equal(current.audit.filter(entry => entry.op === 'remind-observed').length, 1)
  }
  writeFileSync(join(repo, 'recovery-receipt.json'), JSON.stringify({ op, point, committed,
    restart: snap(repo) }, null, 2))
}

const points = ['before-apply', 'after-apply', 'before-file-fsync', 'after-file-fsync', 'after-rename', 'after-dir-fsync']
try {
  const lock = run('flock', ['--version'])
  assert.equal(lock.status, 0, 'flock is required; missing evidence is a failure, not SKIP')
  for (const op of ['remind-intent', 'remind-observe']) for (const point of points) {
    try { await runCase(op, point); console.log(`FAULT PASS ${op} ${point}`); passed++ }
    catch (error) { console.error(`FAULT FAIL ${op} ${point}: ${error.stack}`); failed++ }
  }
} finally {
  if (process.env.P444_KEEP) console.log(`kept fault evidence=${root}`)
  else rmSync(root, { recursive: true, force: true })
}
console.log(`fault-matrix: passed=${passed} failed=${failed}`)
if (failed) process.exitCode = 1
