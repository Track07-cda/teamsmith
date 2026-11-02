/** Directed PM reply capture: lexical cleanup and source operations (not a reply store). */
import { TITLE_FORBIDDEN_RE, validateTitle, validateBody } from './replies.mjs'
import { closeSync, constants as C, fstatSync, fsyncSync, lstatSync, mkdirSync, openSync, readFileSync, realpathSync, renameSync, unlinkSync, writeFileSync } from 'node:fs'
import { spawn, spawnSync } from 'node:child_process'
import { createHash, randomUUID } from 'node:crypto'
import { basename, dirname, isAbsolute, join, resolve, sep } from 'node:path'
import { isDeepStrictEqual } from 'node:util'

function logicalLines(text) {
  const lines = []
  let start = 0
  while (start < text.length) {
    const lf = text.indexOf('\n', start)
    const end = lf < 0 ? text.length : lf + 1
    const textEnd = lf < 0 ? end : lf > start && text[lf - 1] === '\r' ? lf - 1 : lf
    lines.push({ start, end, text: text.slice(start, textEnd) })
    start = end
  }
  return lines
}

function fences(lines, length) {
  const ranges = []
  let open = null
  for (const line of lines) {
    if (open) {
      const close = /^ {0,3}(`+|~+)([ \t]*)$/.exec(line.text)
      if (close && close[1][0] === open.type && close[1].length >= open.length) {
        ranges.push([open.start, line.end])
        open = null
      }
    } else {
      const match = /^ {0,3}(`{3,}|~{3,})(.*)$/.exec(line.text)
      if (match && !(match[1][0] === '`' && match[2].includes('`'))) {
        open = { start: line.start, type: match[1][0], length: match[1].length }
      }
    }
  }
  if (open) ranges.push([open.start, length])
  return ranges
}

function inlineSpans(text, start, end) {
  // Physical runs are the closer index: backslashes inside a span never escape a closer.
  const runs = []
  const byLength = new Map()
  for (let pos = start; pos < end;) {
    if (text[pos] !== '`') { pos++; continue }
    const from = pos
    while (pos < end && text[pos] === '`') pos++
    let slashes = 0
    for (let p = from - 1; p >= start && text[p] === '\\'; p--) slashes++
    const index = runs.length
    runs.push({ start: from, end: pos, escaped: slashes % 2 })
    const length = pos - from
    if (!byLength.has(length)) byLength.set(length, [])
    byLength.get(length).push(index)
  }
  const ranges = []
  for (let i = 0; i < runs.length; i++) {
    const run = runs[i]
    // An odd escape consumes ONLY the first tick, leaving its unescaped suffix.
    const opener = run.start + run.escaped
    const length = run.end - opener
    if (!length) continue
    const closers = byLength.get(length) ?? []
    let lo = 0, hi = closers.length
    while (lo < hi) {
      const mid = (lo + hi) >>> 1
      if (closers[mid] <= i) lo = mid + 1
      else hi = mid
    }
    if (lo === closers.length) continue // Unmatched opener is literal, not protection to EOF.
    const next = closers[lo]
    ranges.push([opener, runs[next].end])
    i = next
  }
  return ranges
}

function protectedRanges(text, lines) {
  const fenced = fences(lines, text.length)
  const ranges = []
  let start = 0
  for (const fence of fenced) {
    ranges.push(...inlineSpans(text, start, fence[0]), fence)
    start = fence[1]
  }
  ranges.push(...inlineSpans(text, start, text.length))
  return ranges
}

function removeRanges(text, offset, ranges) {
  const parts = []
  let at = 0
  for (const [start, end] of ranges) {
    const lo = Math.max(0, start - offset), hi = Math.min(text.length, end - offset)
    if (lo >= hi) continue
    parts.push(text.slice(at, lo))
    at = hi
  }
  parts.push(text.slice(at))
  return parts.join('')
}

function derivedTitle(body) {
  for (const line of logicalLines(body)) {
    const view = line.text.trim().replace(/^§[0-9]+§[ \t]*/, '').trim()
    if (!view) continue
    const title = Array.from(view.replace(new RegExp(TITLE_FORBIDDEN_RE.source, 'g'), '')).slice(0, 160).join('')
    if (title.trim()) return title
  }
  return '关键回复'
}

/** No mutation outside exact original control ranges; character offsets are NOT UTF-8 byte offsets. */
export function parseReply(message) {
  const blocks = Array.isArray(message.content) ? message.content : []
  const original = blocks.filter(b => b.type === 'text').map(b => b.text).join('')
  const unchanged = { message, ranges: [], body: original, candidate: false, reason: 'unmarked' }
  if (message.role !== 'assistant') return unchanged
  const lines = logicalLines(original)
  const protectedCode = protectedRanges(original, lines)
  const controls = []
  for (const line of lines) {
    const match = /^\[\[team-reply(?::((?:(?!\]\]).)*))?\]\]$/.exec(line.text)
    if (!match || protectedCode.some(([lo, hi]) => lo < line.end && hi > line.start)) continue
    controls.push({ ...line, explicit: match[1] })
  }
  if (!controls.length) return unchanged
  const ranges = controls.map(line => [line.start, line.end])
  let offset = 0
  const content = blocks.map(block => {
    if (block.type !== 'text') return block
    const text = removeRanges(block.text, offset, ranges)
    offset += block.text.length
    return text === block.text ? block : { ...block, text }
  })
  const body = content.filter(b => b.type === 'text').map(b => b.text).join('')
  const result = { message: { ...message, content }, ranges, body, candidate: false, reason: '' }
  if (controls.length !== 1) return { ...result, reason: 'ambiguous' }
  const control = controls[0]
  if (!/^(?:[ \t]*\r?\n)*[ \t]*$/.test(original.slice(control.end))) return { ...result, reason: 'misplaced' }
  if (!/\S/.test(body)) return { ...result, reason: 'empty-body' }
  const title = control.explicit === undefined ? derivedTitle(body) : control.explicit
  try { validateTitle(title) } catch { return { ...result, title, reason: 'invalid-title' } }
  try {
    // Buffer.from replaces lone surrogates; reject rather than silently change those bytes.
    const bytes = Buffer.from(body, 'utf8')
    if (bytes.toString('utf8') !== body) throw new Error('invalid UTF-8 source')
    validateBody(bytes)
  } catch { return { ...result, title, reason: 'invalid-body' } }
  return { ...result, title, candidate: true, reason: 'candidate' }
}

const digest = value => createHash('sha256').update(value).digest('hex')
const tupleOf = identity => [identity.root, identity.state, identity.sessionId, identity.sessionFile]
export const sessionKey = identity => digest(JSON.stringify(tupleOf(identity)))
export const sourceKey = (identity, entryId) => digest(JSON.stringify([...tupleOf(identity), entryId]))
const sameIdentity = (a, b) => isDeepStrictEqual(tupleOf(a), tupleOf(b))
const statuses = new Set(['pending', 'eligible', 'attempting', 'saved', 'unconfirmed', 'not-written', 'uncertain'])

export function processIdentity(pid) {
  if (!Number.isSafeInteger(pid) || pid < 1) return {}
  try {
    const stat = readFileSync(`/proc/${pid}/stat`, 'utf8')
    const fields = stat.slice(stat.lastIndexOf(')') + 2).trim().split(/\s+/)
    return { pid, starttime: fields[19], ppid: Number(fields[1]), zombie: fields[0] === 'Z' }
  } catch (e) {
    if (e.code === 'ENOENT') return { dead: true }
    return {} // /proc inaccessible is unknown, never proof that an attempt did not run.
  }
}

/** Canonical, nonsymlink ancestry. Sticky system temp parents are allowed, writable private parents are not. */
export function safeDirectory(path, create = false) {
  if (!isAbsolute(path) || resolve(path) !== path) throw new Error('noncanonical directory')
  let at = sep
  for (const part of path.split(sep).filter(Boolean)) {
    at = join(at, part)
    let st
    try { st = lstatSync(at) } catch (e) {
      if (e.code !== 'ENOENT' || !create) throw e
      mkdirSync(at, { mode: 0o700 })
      st = lstatSync(at)
    }
    if (!st.isDirectory() || st.isSymbolicLink() || ((st.mode & 0o022) && !(st.mode & 0o1000))) throw new Error('unsafe directory ancestry')
  }
  if (realpathSync(path) !== path) throw new Error('directory identity changed')
  return path
}

function regular(path, flags, mode = 0o600) {
  const fd = openSync(path, flags | C.O_NOFOLLOW | C.O_NONBLOCK, mode)
  const st = fstatSync(fd)
  if (!st.isFile() || st.nlink !== 1 || (st.mode & 0o022)) {
    closeSync(fd)
    throw new Error('unsafe regular file')
  }
  return fd
}

/** Fixed flock + anchored snapshot transaction; the lock is never unlinked. */
export class CaptureJournal {
  constructor(identity) {
    this.identity = { ...identity }
    this.directory = join(identity.state, 'reply-capture')
    this.name = `${sessionKey(identity)}.json`
    this.path = join(this.directory, this.name)
    this.failed = false
  }

  validate(snapshot) {
    if (snapshot.version !== 1 || !isDeepStrictEqual(snapshot.tuple, tupleOf(this.identity)) ||
        !snapshot.intents || !snapshot.sources || typeof snapshot.intents !== 'object' || typeof snapshot.sources !== 'object') throw new Error('invalid capture journal')
    for (const [key, record] of Object.entries(snapshot.sources)) {
      if (!record || !statuses.has(record.status) || typeof record.entryId !== 'string' || !record.entryId ||
          key !== sourceKey(this.identity, record.entryId) || !isDeepStrictEqual(record.source, [...snapshot.tuple, record.entryId])) throw new Error('invalid source record')
      if (!successful(record.message) || record.body !== record.message.content.filter(b => b.type === 'text').map(b => b.text).join('')) throw new Error('inconsistent source content')
      validateTitle(record.title)
      validateBody(Buffer.from(record.body, 'utf8'))
      if (['eligible', 'attempting', 'saved', 'unconfirmed', 'not-written', 'uncertain'].includes(record.status) && !record.settledLeaf) throw new Error('missing settlement witness')
      if (['attempting', 'saved', 'unconfirmed', 'not-written', 'uncertain'].includes(record.status) && !record.attempt?.token) throw new Error('missing attempt evidence')
    }
    return snapshot
  }

  transact(change, { create = false } = {}) {
    if (this.failed) throw new Error('capture journal disabled after transaction failure')
    safeDirectory(this.identity.root)
    safeDirectory(this.identity.state, create)
    safeDirectory(this.directory, create)
    const directory = openSync(this.directory, C.O_RDONLY | C.O_DIRECTORY | C.O_NOFOLLOW)
    const dirStat = fstatSync(directory)
    const anchored = name => `/proc/self/fd/${directory}/${name}`
    let lock, temp
    try {
      lock = regular(anchored(`${this.name}.lock`), C.O_RDWR | (create ? C.O_CREAT : 0))
      const held = spawnSync('flock', ['-x', '3'], { stdio: ['ignore', 'ignore', 'ignore', lock] })
      if (held.error || held.status !== 0) throw new Error('capture flock unavailable')
      this.checkDirectory(dirStat)
      let snapshot
      try {
        const fd = regular(anchored(this.name), C.O_RDONLY)
        try { snapshot = this.validate(JSON.parse(readFileSync(fd, 'utf8'))) } finally { closeSync(fd) }
      } catch (e) {
        if (e.code !== 'ENOENT' || !create) throw e
        snapshot = { version: 1, tuple: tupleOf(this.identity), intents: {}, sources: {} }
      }
      const before = JSON.stringify(snapshot)
      const result = change(snapshot)
      this.validate(snapshot)
      if (JSON.stringify(snapshot) !== before) {
        temp = `.capture-${randomUUID()}`
        const fd = regular(anchored(temp), C.O_WRONLY | C.O_CREAT | C.O_EXCL)
        try { writeFileSync(fd, JSON.stringify(snapshot) + '\n'); fsyncSync(fd) } finally { closeSync(fd) }
        this.checkDirectory(dirStat)
        // Refuse substitution of the target, even when rename itself would safely replace it.
        try { const fd = regular(anchored(this.name), C.O_RDONLY); closeSync(fd) } catch (e) { if (e.code !== 'ENOENT') throw e }
        renameSync(anchored(temp), anchored(this.name))
        temp = null
        fsyncSync(directory)
        this.checkDirectory(dirStat)
      }
      return result
    } catch (e) {
      // A missing initial journal has no recovery work; other failures disable this runtime's journal.
      if (e.code !== 'ENOENT') this.failed = true
      throw e
    } finally {
      if (temp) unlinkSync(anchored(temp))
      if (lock !== undefined) closeSync(lock)
      closeSync(directory)
    }
  }

  checkDirectory(expected) {
    safeDirectory(this.identity.state)
    const actual = lstatSync(this.directory)
    if (!actual.isDirectory() || actual.dev !== expected.dev || actual.ino !== expected.ino) throw new Error('capture directory replaced')
  }
}

function branchWitness(view, startLeaf, source, settledLeaf = view.leaf) {
  const ids = view.branch.map(entry => entry.id)
  const start = startLeaf === null ? -1 : ids.indexOf(startLeaf)
  const at = ids.indexOf(source), end = ids.indexOf(settledLeaf)
  return (startLeaf === null || start >= 0) && at > start && end >= at && view.leaf === ids.at(-1)
}
const successful = m => m?.role === 'assistant' && m.stopReason === 'stop' && !m.content.some(b => b.type === 'toolCall')

/** The real command, argv-only. No shell interpolation, fake receipt, or second writer. */
export function runReplyWriter({ team, identity, env }, record) {
  return new Promise(resolveResult => {
    let child
    try {
      child = spawn('bash', [team, '--root', identity.root, 'reply', 'post', '--from', 'pm', '--title', record.title, '--stdin'], {
        cwd: identity.root,
        env: { ...env, TEAM_ROOT: identity.root, TEAM_MAIN_ROOT: identity.root, TEAM_STATE_DIR: identity.state, TEAM_CONFIG_FILE: identity.config },
        stdio: ['pipe', 'pipe', 'pipe'],
      })
    } catch (e) { resolveResult({ error: e.code, started: false }); return }
    let stdout = '', pipeError = false, startError
    child.stdout.setEncoding('utf8')
    child.stdout.on('data', data => { stdout += data })
    child.stderr.resume() // Writer diagnostics can include a title; capture reports only source/status/evidence.
    child.stdin.on('error', () => { pipeError = true })
    child.on('error', e => { startError = e.code })
    child.on('close', (status, signal) => resolveResult({ status, signal, stdout, pipeError, error: startError, started: child.pid !== undefined }))
    child.stdin.end(record.body, 'utf8')
  })
}

function writerOutcome(result, record) {
  const number = n => Number.isSafeInteger(n) && n > 0
  if (result.error === 'ENOENT' && result.started === false) return { status: 'not-written', reason: 'not-started' }
  if (result.signal || result.error || result.pipeError) return { status: 'uncertain', reason: 'process-outcome' }
  if ([2, 5].includes(result.status)) return { status: 'not-written', reason: result.status === 5 ? 'busy' : 'input' }
  let receipt
  try { receipt = JSON.parse(result.stdout) } catch { return { status: 'uncertain', reason: 'missing-or-bad-receipt' } }
  const bytes = Buffer.from(record.body)
  if (receipt.from !== 'pm' || receipt.title !== record.title || receipt.bytes !== bytes.length || receipt.sha256 !== digest(bytes) ||
      typeof receipt.at !== 'string' || !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?Z$/.test(receipt.at)) return { status: 'uncertain', reason: 'inconsistent-receipt' }
  if (result.status === 0 && receipt.outcome === 'saved' && number(receipt.no) && receipt.candidate_no === undefined) return { status: 'saved', no: receipt.no }
  if (result.status === 6 && receipt.outcome === 'unconfirmed' && number(receipt.candidate_no) && receipt.no === undefined) return { status: 'unconfirmed', candidate_no: receipt.candidate_no }
  return { status: 'uncertain', reason: 'inconsistent-outcome' }
}

/** Pi event state, deliberately independent of the host. Only view.entry/branch of the actual current session bind a source. */
export class ReplyCapture {
  constructor({ identity, journal = new CaptureJournal(identity), current, verify, writer, owner, diagnostic }) {
    Object.assign(this, { identity, journal, current, verify, writer, owner, diagnostic })
    this.activity = null
    this.running = new Set()
  }
  memoryHost(view) { return this.current() && sameIdentity(this.identity, view.identity) }
  eligibleHost(view) { return this.memoryHost(view) && this.verify() }
  report(reason, entryId = '') {
    try { this.diagnostic({ reason, entryId, path: this.journal.path }) }
    catch { /* An unavailable diagnostic sink must not block final message cleanup. */ }
  }
  before(view) {
    this.activity = this.memoryHost(view) ? { id: randomUUID(), startLeaf: view.leaf, ordinal: 0, latest: null } : null
  }
  start(message, view) {
    if (message.role !== 'assistant' || !this.activity) return
    if (!this.memoryHost(view)) { this.activity = null; return }
    const a = this.activity
    a.latest = { ordinal: ++a.ordinal, ended: false }
  }
  end(message, view) {
    if (!this.current()) return message
    // This transform must finish even when identity, staging, locking, or disk writes fail.
    const parsed = parseReply(message)
    if (message.role !== 'assistant') return message
    const a = this.activity, latest = a?.latest
    if (!latest || latest.ended) return parsed.message
    latest.ended = true
    latest.message = parsed.message
    if (!parsed.candidate || !successful(parsed.message)) return parsed.message
    try {
      if (!this.eligibleHost(view)) return parsed.message
      const intent = `${a.id}:${latest.ordinal}`
      this.journal.transact(snapshot => {
        snapshot.intents[intent] = { status: 'unbound', activity: a.id, ordinal: latest.ordinal, startLeaf: a.startLeaf, title: parsed.title, body: parsed.body, message: parsed.message }
      }, { create: true })
      latest.intent = intent
    } catch (e) { this.report(`stage:${e.code ?? e.name}`) }
    return parsed.message
  }
  turn(event, view) {
    const a = this.activity, latest = a?.latest
    if (!latest?.intent || latest.entryId || !this.eligibleHost(view)) return
    const entry = view.entry(event.messageEntryId)
    if (!event.messageEntryId || entry?.type !== 'message' || !isDeepStrictEqual(entry.message, latest.message) ||
        !isDeepStrictEqual(event.message, latest.message) || !branchWitness(view, a.startLeaf, event.messageEntryId)) {
      latest.intent = null // A bad binding cannot be repaired by another event or current-leaf inference.
      this.report('binding-mismatch', event.messageEntryId)
      return
    }
    try {
      const key = sourceKey(this.identity, event.messageEntryId)
      const bound = this.journal.transact(snapshot => {
        const intent = snapshot.intents[latest.intent]
        if (!intent || intent.status !== 'unbound' || snapshot.sources[key]) return false
        snapshot.sources[key] = { ...intent, status: 'pending', entryId: event.messageEntryId, source: [...tupleOf(this.identity), event.messageEntryId] }
        delete snapshot.intents[latest.intent]
        return true
      })
      if (bound) latest.entryId = event.messageEntryId
    } catch (e) { latest.intent = null; this.report(`binding:${e.code ?? e.name}`, event.messageEntryId) }
  }
  settled(event, view) {
    const a = this.activity, latest = a?.latest
    this.activity = null
    if (a && !event.aborted && latest?.entryId && latest.ended && successful(latest.message) && this.eligibleHost(view) &&
        branchWitness(view, a.startLeaf, latest.entryId)) {
      try {
        this.journal.transact(snapshot => {
          const record = snapshot.sources[sourceKey(this.identity, latest.entryId)]
          if (record?.status !== 'pending' || record.activity !== a.id || record.ordinal !== latest.ordinal) return
          record.status = 'eligible'
          record.settledLeaf = view.leaf
        })
      } catch (e) { this.report(`eligibility:${e.code ?? e.name}`, latest.entryId); return }
    }
    if (!event.aborted) this.recover(view)
  }
  reset() { this.activity = null }
  recover(view) {
    if (this.activity || !this.eligibleHost(view)) return
    let records
    try {
      records = this.journal.transact(snapshot => {
        for (const record of Object.values(snapshot.sources)) {
          if (record.status !== 'attempting') continue
          const life = processIdentity(record.attempt.pid)
          if (life.dead || life.zombie || (life.starttime && life.starttime !== record.attempt.starttime)) {
            record.status = 'uncertain'
            record.reason = 'attempt-owner-exited'
          }
        }
        return Object.values(snapshot.sources).filter(record => record.status === 'eligible' &&
          branchWitness(view, record.startLeaf, record.entryId, record.settledLeaf) &&
          isDeepStrictEqual(view.entry(record.entryId)?.message, record.message))
      })
    } catch (e) {
      if (e.code !== 'ENOENT') this.report(`recovery:${e.code ?? e.name}`)
      return // Missing journal is not a reason to reconstruct entries from history.
    }
    for (const record of records) this.attempt(record, view)
  }
  attempt(record, view) {
    if (this.activity || !this.eligibleHost(view)) return
    const token = randomUUID()
    const key = sourceKey(this.identity, record.entryId)
    try {
      const acquired = this.journal.transact(snapshot => {
        const stored = snapshot.sources[key]
        if (stored?.status !== 'eligible') return false
        stored.status = 'attempting'
        stored.attempt = { token, ...this.owner, at: new Date().toISOString() }
        return true
      })
      if (!acquired || !this.eligibleHost(view)) return
    } catch (e) { this.report(`attempting:${e.code ?? e.name}`, record.entryId); return }
    // Durable CAS above is the barrier, including a crash right before this invocation.
    const work = Promise.resolve().then(() => {
      if (this.activity || !this.eligibleHost(view)) return { started: false, error: 'STALE_OWNER' }
      return this.writer(record)
    }).then(result => {
      if (!this.current()) return // A stale callback cannot replace a newer generation's evidence.
      const outcome = writerOutcome(result, record)
      try {
        this.journal.transact(snapshot => {
          const stored = snapshot.sources[key]
          if (stored?.status !== 'attempting' || stored.attempt.token !== token) return
          Object.assign(stored, outcome)
        })
        if (outcome.status !== 'saved') this.report(outcome.reason ?? outcome.status, record.entryId)
      } catch (e) { this.report(`result:${e.code ?? e.name}`, record.entryId) }
    }).catch(e => this.report(`writer:${e.code ?? e.name}`, record.entryId)).finally(() => this.running.delete(work))
    this.running.add(work)
  }
  async drain() { await Promise.all([...this.running]) }
}

function command(bin, args, cwd) {
  const result = spawnSync(bin, args, { cwd, encoding: 'utf8' })
  if (result.error || result.status !== 0) throw new Error(`${basename(bin)} evidence unavailable`)
  return result.stdout.trim()
}
function readRegular(path) {
  safeDirectory(dirname(path))
  const fd = regular(path, C.O_RDONLY)
  try { return readFileSync(fd, 'utf8') } finally { closeSync(fd) }
}
function ancestor(older, younger) {
  const seen = new Set()
  while (younger > 0 && !seen.has(younger)) {
    if (older === younger) return true
    seen.add(younger)
    younger = processIdentity(younger).ppid
  }
  return false
}
function proofPid(path, pid, root) {
  try {
    const raw = readRegular(path).trim()
    if (!/^\d+$/.test(raw) || !ancestor(Number(raw), pid)) return false
    const owner = processIdentity(Number(raw))
    if (!owner.starttime || owner.zombie || realpathSync(`/proc/${raw}/cwd`) !== root) return false
    const btime = /^btime (\d+)$/m.exec(readFileSync('/proc/stat', 'utf8'))?.[1]
    const ticks = Number(command('getconf', ['CLK_TCK']))
    const started = (Number(btime) + Number(owner.starttime) / ticks) * 1000
    return lstatSync(path).mtimeMs >= Math.floor(started / 1000) * 1000
  } catch (e) {
    if (['ENOENT', 'ELOOP', 'ENOTDIR'].includes(e.code)) return false // A vanished/replaced proof is not evidence.
    throw e
  }
}
function tmuxEvidence(socket, pane) {
  const fields = command('tmux', ['-S', socket, 'display-message', '-p', '-t', pane,
    '#{socket_path}\t#{pid}\t#{pane_id}\t#{pane_pid}\t#{session_name}\t#{window_name}\t#{pane_current_path}']).split('\t')
  if (fields.length !== 7) throw new Error('incomplete tmux evidence')
  return { socket: realpathSync(fields[0]), serverPid: Number(fields[1]), pane: fields[2], panePid: Number(fields[3]), session: fields[4], window: fields[5], cwd: realpathSync(fields[6]) }
}

/** Only a directed builtin PM with current local process/pane/launch evidence can own capture. */
export function resolvePMIdentity(context, env = process.env) {
  const cwd = realpathSync(context.cwd), actualCwd = realpathSync(process.cwd())
  if (cwd !== actualCwd) throw new Error('context/process cwd mismatch')
  const root = realpathSync(command('git', ['-C', cwd, 'rev-parse', '--show-toplevel']))
  const common = realpathSync(command('git', ['-C', cwd, 'rev-parse', '--path-format=absolute', '--git-common-dir']))
  if (cwd !== root || dirname(common) !== root) throw new Error('not the main checkout')
  safeDirectory(root)
  for (const key of ['TEAM_ROOT', 'TEAM_MAIN_ROOT']) if (env[key] && realpathSync(env[key]) !== root) throw new Error('inherited root mismatch')
  if (!env.TEAM_STATE_DIR || !env.TEAM_CONFIG_FILE || !env.TEAM_PM_WINDOW || !env.TEAM_SESSION) throw new Error('missing directed PM launch environment')
  const state = safeDirectory(env.TEAM_STATE_DIR), config = resolve(env.TEAM_CONFIG_FILE)
  if (config !== env.TEAM_CONFIG_FILE || realpathSync(config) !== config) throw new Error('noncanonical PM config')
  const configBytes = readRegular(config), configStat = lstatSync(config)
  if (!context.sessionId || !context.sessionFile || !isAbsolute(context.sessionFile)) throw new Error('no persistent session identity')
  const sessionFile = join(safeDirectory(dirname(context.sessionFile)), basename(context.sessionFile))
  if (sessionFile !== context.sessionFile) throw new Error('noncanonical session path')
  try { const fd = regular(sessionFile, C.O_RDONLY); closeSync(fd) } catch (e) {
    if (e.code !== 'ENOENT') throw e // Pi may name its persistent file before the first append.
  }
  const [socketPath, serverPid] = (env.TMUX ?? '').split(',')
  if (!socketPath || !env.TMUX_PANE) throw new Error('no actual tmux pane')
  const tmux = tmuxEvidence(realpathSync(socketPath), env.TMUX_PANE)
  const life = processIdentity(process.pid)
  if (!life.starttime || life.zombie || tmux.serverPid !== Number(serverPid) || tmux.session !== env.TEAM_SESSION ||
      tmux.window !== env.TEAM_PM_WINDOW || tmux.cwd !== root || !ancestor(tmux.panePid, process.pid)) throw new Error('foreign tmux/process identity')
  let proof = proofPid(join(state, 'pm.pid.spawn'), process.pid, root) ? 'spawn' : ''
  if (!proof && proofPid(join(state, 'pm.pid'), process.pid, root) && /^(argv|spawn)$/.test(readRegular(join(state, 'pm.pid.proof')).trim())) proof = 'final'
  if (!proof) throw new Error('no current PM launch proof')
  return { root, state, config, configHash: digest(configBytes), configDev: configStat.dev, configIno: configStat.ino,
    sessionId: context.sessionId, sessionFile, pid: process.pid, starttime: life.starttime, cwd, tmux }
}

/** Registry is process evidence, not a second source index. Fixed lock and atomic replacement match journal discipline. */
export function updateRuntime(identity, change) {
  const directory = join(safeDirectory(identity.state), 'reply-capture')
  safeDirectory(directory, true)
  const dir = openSync(directory, C.O_RDONLY | C.O_DIRECTORY | C.O_NOFOLLOW), expected = fstatSync(dir)
  const at = name => `/proc/self/fd/${dir}/${name}`
  let lock, temp
  try {
    lock = regular(at('runtime.lock'), C.O_RDWR | C.O_CREAT)
    const held = spawnSync('flock', ['-x', '3'], { stdio: ['ignore', 'ignore', 'ignore', lock] })
    if (held.error || held.status !== 0) throw new Error('runtime flock unavailable')
    let current = null
    try { const fd = regular(at('runtime.json'), C.O_RDONLY); try { current = JSON.parse(readFileSync(fd, 'utf8')) } finally { closeSync(fd) } }
    catch (e) { if (e.code !== 'ENOENT') throw e }
    const next = change(current)
    if (next === undefined) return
    temp = `.runtime-${randomUUID()}`
    const fd = regular(at(temp), C.O_WRONLY | C.O_CREAT | C.O_EXCL)
    try { writeFileSync(fd, JSON.stringify(next) + '\n'); fsyncSync(fd) } finally { closeSync(fd) }
    safeDirectory(directory)
    const actual = lstatSync(directory)
    if (actual.dev !== expected.dev || actual.ino !== expected.ino) throw new Error('runtime directory replaced')
    try { const fd = regular(at('runtime.json'), C.O_RDONLY); closeSync(fd) } catch (e) { if (e.code !== 'ENOENT') throw e }
    renameSync(at(temp), at('runtime.json')); temp = null; fsyncSync(dir)
  } finally {
    if (temp) unlinkSync(at(temp))
    if (lock !== undefined) closeSync(lock)
    closeSync(dir)
  }
}

export const captureSourceFiles = ['extension/team-reply.ts', 'scripts/reply-capture.mjs', 'scripts/replies.mjs']
export const captureFingerprint = hashes => digest(JSON.stringify(captureSourceFiles.map(file => [file, hashes[file]])))
export function captureDiskFingerprint(skill) {
  const hashes = Object.fromEntries(captureSourceFiles.map(file => [file, digest(readFileSync(join(skill, file)))]))
  return captureFingerprint(hashes)
}
export function inspectRuntime({ root, state, config, session, window, skill }) {
  let disk
  try { disk = captureDiskFingerprint(skill) } catch (e) { return { state: 'unknown', reason: `disk:${e.code ?? e.name}` } }
  let runtime
  try { runtime = JSON.parse(readRegular(join(state, 'reply-capture/runtime.json'))) }
  catch (e) { return { disk, state: 'unknown', reason: `registration:${e.code ?? e.name}` } }
  const base = { disk, loaded: runtime.fingerprint, generation: runtime.generation, extension: runtime.extension, sessionId: runtime.sessionId }
  try {
    if (runtime.root !== realpathSync(root) || runtime.state !== realpathSync(state) || runtime.config !== realpathSync(config) ||
        runtime.configHash !== digest(readRegular(config))) throw new Error('identity/config changed')
    const life = processIdentity(runtime.pid)
    if (life.dead || life.zombie || !life.starttime || life.starttime !== runtime.starttime || realpathSync(`/proc/${runtime.pid}/cwd`) !== runtime.cwd) throw new Error('dead/reused/foreign process')
    const actual = tmuxEvidence(runtime.tmux.socket, runtime.tmux.pane)
    if (!isDeepStrictEqual(actual, runtime.tmux) || actual.session !== session || actual.window !== window || !ancestor(actual.panePid, runtime.pid)) throw new Error('pane/session changed')
    if (runtime.status !== 'ready') return { ...base, state: 'degraded', reason: runtime.reason ?? runtime.status }
    if (runtime.fingerprint !== disk) return { ...base, state: 'stale', reason: 'disk differs from loaded source' }
    return { ...base, state: 'ready', reason: 'live PM registered actual loaded source' }
  } catch (e) { return { ...base, state: 'stale', reason: e.message } }
}
