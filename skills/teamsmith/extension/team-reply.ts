/** PM-only, explicit live-message capture. No tools, provider hooks, history import, or automatic selection. */
import type { ExtensionAPI, ExtensionContext } from '@earendil-works/pi-coding-agent'
import { createHash, randomUUID } from 'node:crypto'
import { appendFileSync, readFileSync, realpathSync, statSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { isDeepStrictEqual } from 'node:util'

// Captured during module evaluation, never reread later as a claim about loaded code.
const entry = realpathSync(fileURLToPath(import.meta.url))
const entryBytes = readFileSync(entry)
const hash = (bytes: Buffer | string) => createHash('sha256').update(bytes).digest('hex')
const slot = Symbol.for('teamsmith.reply-capture.owners.v1')
const owners: Map<string, object> = (globalThis as any)[slot] ??= new Map()
const moduleURL = (bytes: string) => `data:text/javascript;base64,${Buffer.from(bytes).toString('base64')}`

export default async function (pi: ExtensionAPI) {
  const skill = dirname(dirname(entry))
  // Snapshot and evaluate both dependencies on every factory/reload, bypassing native/Jiti dependency caches.
  // This is the same reviewed local code, not generated behaviour or a general module loader.
  const parserBytes = readFileSync(join(skill, 'scripts/reply-capture.mjs'), 'utf8')
  const repliesBytes = readFileSync(join(skill, 'scripts/replies.mjs'), 'utf8')
  const dependency = moduleURL(repliesBytes)
  const parserURL = moduleURL(parserBytes.replace("'./replies.mjs'", JSON.stringify(dependency)))
  const capture = await import(parserURL)
  const fingerprint = capture.captureFingerprint({
    'extension/team-reply.ts': hash(entryBytes),
    'scripts/reply-capture.mjs': hash(parserBytes),
    'scripts/replies.mjs': hash(repliesBytes),
  })
  let engine: any, registration: any, key = '', active = false
  const context = (ctx: ExtensionContext) => ({ cwd: ctx.cwd, sessionId: ctx.sessionManager.getSessionId(), sessionFile: ctx.sessionManager.getSessionFile() })
  const current = () => active && owners.get(key) === registration
  const view = (ctx: ExtensionContext) => ({
    identity: registration,
    leaf: ctx.sessionManager.getLeafId(),
    branch: ctx.sessionManager.getBranch(),
    entry: (id: string) => ctx.sessionManager.getEntry(id),
  })
  const diagnostic = (d: { reason: string; entryId: string; path: string }) => {
    // Never title/body/model text. Pi renders extension stderr in the TUI, so routine diagnostics stay local.
    const line = `[team-reply] ${d.reason}; source=${d.entryId || 'unbound'}; evidence=${d.path}\n`
    // Keep the line beside the journal: a refused publication remains diagnosable without changing the session output.
    try {
      const state = registration?.state
      if (!state) return
      const file = join(state, 'reply-capture', 'diagnostics.log')
      appendFileSync(file, `${new Date().toISOString()} ${line}`)
      const stat = statSync(file)
      if (stat.size > 256 * 1024) {
        const kept = readFileSync(file, 'utf8').split('\n').slice(-400).join('\n')
        writeFileSync(file, kept)
      }
    } catch { /* A diagnostic sink that cannot be written must not block cleanup. */ }
  }
  const runtime = (status: string, reason?: string) => {
    if (!current()) return
    capture.updateRuntime(registration, (previous: any) => {
      if (status !== 'ready' && previous?.generation !== registration.generation) return undefined
      return { ...registration, status, reason, extension: entry, fingerprint, at: new Date().toISOString() }
    })
  }
  pi.on('session_start', (_event, ctx) => {
    active = false
    engine = undefined
    let identity: any
    try { identity = capture.resolvePMIdentity(context(ctx)) }
    catch {
      return // Unproven contexts stay disabled; doctor/runtime evidence explains the absent registration.
    }
    key = capture.sessionKey(identity)
    if (owners.has(key)) return // A second loaded path must not sanitize, stage, or register a second owner.
    registration = { ...identity, generation: randomUUID() }
    owners.set(key, registration)
    active = true
    const claimed = registration
    const owns = () => current() && registration === claimed
    const expected = identity
    const verify = () => {
      try {
        const valid = isDeepStrictEqual(expected, capture.resolvePMIdentity(context(ctx)))
        if (!valid) runtime('degraded', 'identity/config changed')
        return valid
      } catch (e: any) {
        try { runtime('degraded', e.message) } catch { /* A failed registry write cannot change identity refusal. */ }
        return false
      }
    }
    engine = new capture.ReplyCapture({ identity, current: owns, verify, owner: { pid: identity.pid, starttime: identity.starttime, generation: registration.generation }, diagnostic,
      writer: (record: any) => capture.runReplyWriter({ team: join(skill, 'scripts/team'), identity, env: { ...process.env } }, record) })
    try { runtime('ready') }
    catch (e: any) { diagnostic({ reason: `runtime:${e.code ?? e.name}`, entryId: '', path: join(identity.state, 'reply-capture/runtime.json') }) }
    engine.recover(view(ctx))
  })
  pi.on('before_agent_start', (_event, ctx) => { if (current()) engine.before(view(ctx)) })
  pi.on('message_start', (event, ctx) => { if (current()) engine.start(event.message, view(ctx)) })
  pi.on('message_end', (event, ctx) => {
    if (!current()) return
    return { message: engine.end(event.message, view(ctx)) }
  })
  pi.on('turn_end', (event, ctx) => { if (current()) engine.turn(event, view(ctx)) })
  pi.on('agent_settled', (event, ctx) => { if (current()) engine.settled(event, view(ctx)) })
  for (const event of ['session_before_switch', 'session_before_fork', 'session_tree'] as const) {
    pi.on(event, () => { if (current()) engine.reset() })
  }
  pi.on('session_shutdown', async () => {
    if (!current()) return
    engine.reset()
    await engine.drain()
    try { runtime('degraded', 'session shutdown') }
    catch (e: any) { diagnostic({ reason: `shutdown-runtime:${e.code ?? e.name}`, entryId: '', path: join(registration.state, 'reply-capture/runtime.json') }) }
    // A delayed old shutdown must not clear a replacement generation.
    if (owners.get(key) === registration) owners.delete(key)
    active = false
  })
}
