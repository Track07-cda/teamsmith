// PM-only Reminder tool identity, authority invocation and live capability evidence (P442).
// Reminder data itself stays in state-authority.mjs: this file never reads or writes reminders/state.json.
// Invalid identities fail before runReminderAuthority is called. The separate evidence file is only a
// freshness-bounded report from this extension instance; it is not proof of model visibility or tool use.
import { closeSync, constants as C, fstatSync, fsyncSync, lstatSync, openSync, readFileSync, realpathSync, renameSync, unlinkSync, writeFileSync } from 'node:fs'
import { spawn, spawnSync } from 'node:child_process'
import { createHash, randomUUID } from 'node:crypto'
import { join } from 'node:path'
import { isDeepStrictEqual } from 'node:util'
import { ancestor, processIdentity, proofPid, readRegular, resolvePMIdentity, safeDirectory, tmuxEvidence } from './reply-capture.mjs'

export const REMIND_CAPABILITY_TTL_MS = 20000
export const remindCapabilitySourceFiles = ['extension/team-remind.ts', 'scripts/remind-capability.mjs', 'scripts/reply-capture.mjs', 'scripts/replies.mjs']
const digest = value => createHash('sha256').update(value).digest('hex')
export const remindCapabilityFingerprint = hashes => digest(JSON.stringify(remindCapabilitySourceFiles.map(file => [file, hashes[file]])))
export function remindCapabilityDiskFingerprint(skill) {
  const hashes = Object.fromEntries(remindCapabilitySourceFiles.map(file => [file, digest(readFileSync(join(skill, file)))]))
  return remindCapabilityFingerprint(hashes)
}

function regular(path, flags, mode = 0o600) {
  const fd = openSync(path, flags | C.O_NOFOLLOW | C.O_NONBLOCK, mode)
  const st = fstatSync(fd)
  const unsafe = !st.isFile() ? 'is not a regular file' : st.uid !== process.getuid() ? 'is not owned by this process' : ''
  if (unsafe) { closeSync(fd); throw new Error(`unsafe regular file: ${path} ${unsafe}`) }
  return fd
}

export function configValue(text, key) {
  const match = new RegExp(`^\\s*(?:export\\s+)?${key}=(.*)\\s*$`, 'm').exec(text)
  if (!match) return null
  const raw = match[1].trim()
  const quoted = /^(["'])(.*)\1(?:[ \t]+#.*)?$/.exec(raw)
  if (quoted) return quoted[2]
  return raw.replace(/[ \t]+#.*$/, '').trimEnd()
}

function verifyConfiguration(identity) {
  const text = readRegular(identity.config)
  for (const [key, expected] of [['TEAM_SESSION', identity.tmux.session], ['TEAM_PM_WINDOW', identity.tmux.window]]) {
    const actual = configValue(text, key)
    if (actual !== expected) throw new Error(`PM config ${key} does not match the directed launch`)
  }
  for (const key of ['TEAM_PM_CMD', 'TEAM_PM_BIN']) {
    const value = configValue(text, key)
    if (value !== null && value !== '') throw new Error(`custom PM adapter has no team_remind contract (${key})`)
  }
}

function launchRecord(identity, required = false) {
  const path = join(identity.state, 'pm-launch.env')
  let text
  try { text = readRegular(path) } catch (e) {
    if (e.code === 'ENOENT' && !required) return { nonce: null, time: null }
    throw e
  }
  const record = {}
  for (const line of text.split('\n')) {
    if (!line) continue
    const match = /^([a-z_]+)=(.*)$/.exec(line)
    if (!match || Object.hasOwn(record, match[1])) throw new Error('invalid PM launch record')
    record[match[1]] = match[2]
  }
  if (record.metadata_version !== '1' || record.project !== identity.root || record.window !== identity.tmux.window ||
      !/^[A-Za-z0-9._-]+$/.test(record.nonce ?? '') || !Number.isFinite(Date.parse(record.time)) ||
      !['fresh', 'continued'].includes(record.mode) || typeof record.resume_key !== 'string' || !record.resume_key) {
    throw new Error('PM launch record does not belong to this project/window or is unreadable')
  }
  // The record is published after Pi starts. It cannot predate this process by more than the same
  // one-second floor used by the PM spawn proof; an older record belongs to an earlier PM launch.
  const stat = readFileSync(`/proc/${identity.pid}/stat`, 'utf8')
  const fields = stat.slice(stat.lastIndexOf(')') + 2).trim().split(/\s+/)
  const btime = /^btime (\d+)$/m.exec(readFileSync('/proc/stat', 'utf8'))?.[1]
  const ticksResult = spawnSync('getconf', ['CLK_TCK'], { encoding: 'utf8' })
  if (ticksResult.error || ticksResult.status !== 0) throw new Error('process clock evidence unavailable')
  const started = (Number(btime) + Number(fields[19]) / Number(ticksResult.stdout.trim())) * 1000
  if (lstatSync(path).mtimeMs + 1000 < started) throw new Error('PM launch record predates this process')
  return { nonce: record.nonce, time: record.time }
}

/** Current directed PM proof plus the late-published launch nonce (which may be absent at session_start). */
export function resolveRemindIdentity(context, env = process.env, { requireLaunch = false, checkConfiguration = true } = {}) {
  const identity = resolvePMIdentity(context, env)
  if (checkConfiguration) verifyConfiguration(identity)
  const launch = launchRecord(identity, requireLaunch)
  return { ...identity, launchNonce: launch.nonce, launchTime: launch.time }
}

export function sameRemindIdentity(a, b) {
  return isDeepStrictEqual(
    [a.root, a.state, a.config, a.sessionId, a.sessionFile, a.pid, a.starttime, a.tmux, a.launchNonce],
    [b.root, b.state, b.config, b.sessionId, b.sessionFile, b.pid, b.starttime, b.tmux, b.launchNonce],
  )
}

function currentLaunchProof(identity) {
  if (proofPid(join(identity.state, 'pm.pid.spawn'), identity.pid, identity.root)) return true
  return proofPid(join(identity.state, 'pm.pid'), identity.pid, identity.root) &&
    /^(argv|spawn)$/.test(readRegular(join(identity.state, 'pm.pid.proof')).trim())
}

/** Fixed-lock atomic evidence update. A delayed shutdown may remove only its own generation. */
export function updateRemindCapability(identity, change, { create = true } = {}) {
  safeDirectory(identity.root)
  safeDirectory(identity.state)
  const directory = join(identity.state, 'remind-tool')
  safeDirectory(directory, create)
  const dir = openSync(directory, C.O_RDONLY | C.O_DIRECTORY | C.O_NOFOLLOW)
  const expected = fstatSync(dir)
  const at = name => `/proc/self/fd/${dir}/${name}`
  let lock, temp
  try {
    lock = regular(at('capability.lock'), C.O_RDWR | C.O_CREAT)
    const held = spawnSync('flock', ['-x', '3'], { stdio: ['ignore', 'ignore', 'ignore', lock] })
    if (held.error || held.status !== 0) throw new Error('capability flock unavailable')
    let current = null
    try { const fd = regular(at('current.json'), C.O_RDONLY); try { current = JSON.parse(readFileSync(fd, 'utf8')) } finally { closeSync(fd) } }
    catch (e) { if (e.code !== 'ENOENT') throw e }
    const next = change(current)
    if (next === undefined) return
    if (next === null) {
      try { unlinkSync(at('current.json')) } catch (e) { if (e.code !== 'ENOENT') throw e }
    } else {
      temp = `.current-${randomUUID()}`
      const fd = regular(at(temp), C.O_WRONLY | C.O_CREAT | C.O_EXCL)
      try { writeFileSync(fd, JSON.stringify(next) + '\n'); fsyncSync(fd) } finally { closeSync(fd) }
      renameSync(at(temp), at('current.json')); temp = null
    }
    safeDirectory(directory)
    const actual = lstatSync(directory)
    if (actual.dev !== expected.dev || actual.ino !== expected.ino) throw new Error('capability directory replaced')
    fsyncSync(dir)
  } finally {
    if (temp) unlinkSync(at(temp))
    if (lock !== undefined) closeSync(lock)
    closeSync(dir)
  }
}

export function publishRemindCapability(identity, { generation, extensionVersion, status, exposure, reason = null }) {
  const record = {
    version: 1,
    at: new Date().toISOString(),
    status,
    exposure,
    reason,
    generation,
    extensionVersion,
    root: identity.root,
    state: identity.state,
    config: identity.config,
    sessionId: identity.sessionId,
    sessionFile: identity.sessionFile,
    pid: identity.pid,
    starttime: identity.starttime,
    cwd: identity.cwd,
    launchNonce: identity.launchNonce,
    launchTime: identity.launchTime,
    tmux: identity.tmux,
  }
  updateRemindCapability(identity, () => record)
}

export function removeRemindCapability(identity, generation) {
  updateRemindCapability(identity, current => current?.generation === generation ? null : undefined, { create: false })
}

/** Doctor reads only this evidence plus live process/tmux/launch proof, never the Reminder snapshot. */
export function inspectRemindCapability({ root, state, config, session, window, skill }) {
  let disk
  try { disk = remindCapabilityDiskFingerprint(skill) } catch (e) { return { state: 'unknown', reason: `disk:${e.code ?? e.name}` } }
  let runtime
  try { runtime = JSON.parse(readRegular(join(state, 'remind-tool/current.json'))) }
  catch (e) { return { disk, state: 'unknown', reason: `evidence:${e.code ?? e.name}` } }
  const base = { disk, loaded: runtime.extensionVersion, generation: runtime.generation, sessionId: runtime.sessionId, at: runtime.at }
  try {
    if (runtime.version !== 1 || !['registered', 'error', 'hidden'].includes(runtime.status) ||
        runtime.root !== realpathSync(root) || runtime.state !== realpathSync(state) || runtime.config !== realpathSync(config)) {
      throw new Error('mismatched evidence')
    }
    const age = Date.now() - Date.parse(runtime.at)
    if (!Number.isFinite(age) || age < -1000 || age > REMIND_CAPABILITY_TTL_MS) throw new Error('stale evidence')
    if (runtime.extensionVersion !== disk) throw new Error('loaded source differs from disk')
    const life = processIdentity(runtime.pid)
    if (life.dead || life.zombie || !life.starttime || life.starttime !== runtime.starttime || realpathSync(`/proc/${runtime.pid}/cwd`) !== runtime.cwd) {
      throw new Error('dead/reused/foreign process')
    }
    const actual = tmuxEvidence(runtime.tmux.socket, runtime.tmux.pane)
    // A config mismatch makes the generated session/window differ from the live pane by definition.
    // Error evidence still requires the same live process/pane; ready/hidden evidence also matches current config names.
    if (!isDeepStrictEqual(actual, runtime.tmux) || !ancestor(actual.panePid, runtime.pid) ||
        (runtime.status !== 'error' && (actual.session !== session || actual.window !== window))) {
      throw new Error('pane/session changed')
    }
    if (!currentLaunchProof(runtime)) throw new Error('current PM launch proof missing')
    const launch = launchRecord(runtime, true)
    // Pi can publish its first capability record before team up publishes the launch nonce. A null value
    // is adopted only with this same live process/launch proof; a later conflicting nonce is not.
    if (runtime.launchNonce !== null && launch.nonce !== runtime.launchNonce) throw new Error('PM launch nonce changed')
    if (runtime.status === 'error') return { ...base, state: 'error', reason: runtime.reason ?? 'extension bootstrap failed' }
    if (runtime.status === 'hidden') return { ...base, state: 'unknown', reason: runtime.reason ?? 'tool is hidden in the current session' }
    if (runtime.status === 'registered' && runtime.exposure === 'direct') {
      return { ...base, state: 'ready', reason: `extension reported registered/active at ${runtime.at}` }
    }
    return { ...base, state: 'unknown', reason: 'evidence does not report direct registration' }
  } catch (e) { return { ...base, state: 'unknown', reason: e.message } }
}

function authorityArgs(action, params) {
  const args = []
  if (action === 'add') {
    args.push('remind-add', '--source', 'pm-tool')
    if (params.at !== undefined) args.push('--at', String(params.at))
    if (params.after !== undefined) args.push('--after', String(params.after))
    if (params.key !== undefined) args.push('--key', String(params.key))
    if (params.task !== undefined) args.push('--task', String(params.task))
  } else if (action === 'list') {
    args.push('remind-list')
    if (params.all === true) args.push('--all')
  } else if (action === 'show' || action === 'cancel') {
    args.push(`remind-${action}`, '--id', String(params.id ?? ''))
  } else throw new Error(`team_remind: unknown action ${action}`)
  args.push('--json')
  return args
}

/** Invoke the one existing authority; no project/owner/state/recipient field crosses the tool schema. */
export async function runReminderAuthority({ identity, skill, action, params, signal }) {
  if (!identity || !skill) throw new Error('team_remind: verified PM identity is required')
  let input = Buffer.alloc(0)
  if (action === 'add') {
    if (typeof params.message !== 'string') throw new Error('team_remind: message must be a string')
    input = Buffer.from(params.message, 'utf8')
    if (input.toString('utf8') !== params.message) throw new Error('team_remind: message is not valid UTF-8')
  }
  const script = join(skill, 'scripts/state-authority.mjs')
  const args = [script, '--cli', identity.root, identity.state, ...authorityArgs(action, params)]
  const env = { ...process.env, TEAM_ROOT: identity.root, TEAM_MAIN_ROOT: identity.root,
    TEAM_STATE_DIR: identity.state, TEAM_CONFIG_FILE: identity.config }
  const child = spawn(process.execPath, args, { cwd: identity.root, env, stdio: ['pipe', 'pipe', 'pipe'] })
  const stdout = [], stderr = []
  child.stdout.on('data', chunk => stdout.push(chunk))
  child.stderr.on('data', chunk => stderr.push(chunk))
  const onAbort = () => child.kill('SIGTERM')
  try {
    signal?.addEventListener('abort', onAbort, { once: true })
    child.stdin.end(input)
    const code = await new Promise((resolve, reject) => {
      child.once('error', reject)
      child.once('close', resolve)
    })
    const out = Buffer.concat(stdout).toString('utf8')
    const err = Buffer.concat(stderr).toString('utf8')
    let result
    try { result = JSON.parse(out) } catch { throw new Error(`team_remind authority failed (rc=${code}): ${err || out || 'no result'}`) }
    if (code !== 0 && result.ok !== false) throw new Error(`team_remind authority failed (rc=${code}): ${err || 'no refusal result'}`)
    return result
  } finally {
    signal?.removeEventListener('abort', onAbort)
  }
}
