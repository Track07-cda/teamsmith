/** Directed PM-only team_remind tool. Ordinary Pi and workers never receive an active tool. */
import type { ExtensionAPI, ExtensionContext } from '@earendil-works/pi-coding-agent'
import { createHash, randomUUID } from 'node:crypto'
import { readFileSync, realpathSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const entry = realpathSync(fileURLToPath(import.meta.url))
const skill = dirname(dirname(entry))
const hash = (bytes: Buffer | string) => createHash('sha256').update(bytes).digest('hex')
const moduleURL = (bytes: string) => `data:text/javascript;base64,${Buffer.from(bytes).toString('base64')}`

export default async function (pi: ExtensionAPI) {
  // Bypass dependency caches on reload: registration and the doctor fingerprint describe this loaded source.
  const capabilityBytes = readFileSync(join(skill, 'scripts/remind-capability.mjs'), 'utf8')
  const identityBytes = readFileSync(join(skill, 'scripts/reply-capture.mjs'), 'utf8')
  const repliesBytes = readFileSync(join(skill, 'scripts/replies.mjs'), 'utf8')
  const repliesURL = moduleURL(repliesBytes)
  const identityURL = moduleURL(identityBytes.replace("'./replies.mjs'", JSON.stringify(repliesURL)))
  const capabilityURL = moduleURL(capabilityBytes.replace("'./reply-capture.mjs'", JSON.stringify(identityURL)))
  const capability = await import(capabilityURL)
  const extensionVersion = capability.remindCapabilityFingerprint({
    'extension/team-remind.ts': hash(readFileSync(entry)),
    'scripts/remind-capability.mjs': hash(capabilityBytes),
    'scripts/reply-capture.mjs': hash(identityBytes),
    'scripts/replies.mjs': hash(repliesBytes),
  })
  const context = (ctx: ExtensionContext) => ({
    cwd: ctx.cwd,
    sessionId: ctx.sessionManager.getSessionId(),
    sessionFile: ctx.sessionManager.getSessionFile(),
  })

  let active = false
  let expected: any = null
  let generation = randomUUID()
  let heartbeat: ReturnType<typeof setInterval> | null = null
  const stopHeartbeat = () => { if (heartbeat) { clearInterval(heartbeat); heartbeat = null } }
  const removeFromModel = () => {
    if (typeof (pi as any).getActiveTools === 'function' && typeof (pi as any).setActiveTools === 'function') {
      ;(pi as any).setActiveTools((pi as any).getActiveTools().filter((name: string) => name !== 'team_remind'))
    }
  }
  const hide = (reason = 'session or PM identity changed') => {
    const previous = expected
    active = false
    stopHeartbeat()
    pi.registerTool({ ...definition('hidden'), defaultActive: false } as any)
    removeFromModel()
    if (previous) {
      // Doctor must stop reporting ready in the same switch/fork/reload, not one TTL later. Evidence
      // withdrawal is best effort: a failed write leaves the old record freshness-bounded.
      try { capability.publishRemindCapability(previous, { generation, extensionVersion, status: 'hidden', exposure: 'hidden', reason }) }
      catch { /* the previous evidence still expires by its existing TTL */ }
    }
  }
  const publish = (status: string, exposure: string, reason: string | null = null) => {
    if (!expected) throw new Error('team_remind: no verified identity for capability evidence')
    capability.publishRemindCapability(expected, { generation, extensionVersion, status, exposure, reason })
  }

  const activate = (ctx: ExtensionContext): boolean => {
    let candidate: any
    try { candidate = capability.resolveRemindIdentity(context(ctx), process.env) }
    catch (e: any) {
      try {
        // A valid current PM with invalid generated config gets an explicit load error. This bypasses
        // only the config comparison for evidence; the tool remains hidden and no Reminder state is touched.
        expected = capability.resolveRemindIdentity(context(ctx), process.env, { checkConfiguration: false })
        pi.registerTool({ ...definition('hidden'), defaultActive: false } as any)
        removeFromModel()
        publish('error', 'hidden', e?.message ?? String(e))
      } catch {
        // Missing/forged PM evidence, or evidence that cannot be written, stays unknown.
        expected = null
      }
      return false
    }
    expected = candidate
    try {
      pi.registerTool(definition('direct') as any)
      publish('registered', 'direct')
      active = true
      stopHeartbeat()
      heartbeat = setInterval(() => refresh(ctx), 5000)
      heartbeat.unref()
      return true
    } catch (e: any) {
      active = false
      stopHeartbeat()
      pi.registerTool({ ...definition('hidden'), defaultActive: false } as any)
      removeFromModel()
      // A bootstrap failure after valid identity is explicit only while this launch evidence remains fresh.
      publish('error', 'hidden', e?.message ?? String(e))
      return false
    }
  }

  const refresh = (ctx: ExtensionContext): boolean => {
    if (!active || !expected) return false
    try {
      const current = capability.resolveRemindIdentity(context(ctx), process.env)
      if (expected.launchNonce === null && current.launchNonce !== null) expected = current
      if (!capability.sameRemindIdentity(expected, current)) { hide('PM project/process/tmux/session/launch identity changed'); return false }
      publish('registered', 'direct')
      return true
    } catch {
      hide('PM identity could not be revalidated')
      return false
    }
  }

  const verify = (ctx: ExtensionContext) => {
    if (!active && !activate(ctx)) throw new Error('team_remind: refused before Reminder-state access (not a verified current PM session)')
    const current = capability.resolveRemindIdentity(context(ctx), process.env, { requireLaunch: true })
    if (expected.launchNonce === null && current.launchNonce !== null) expected = current
    if (!capability.sameRemindIdentity(expected, current)) {
      hide('PM project/process/tmux/session/launch identity changed')
      throw new Error('team_remind: PM project/process/tmux/session/launch identity changed; refused before Reminder-state access')
    }
    try { publish('registered', 'direct') }
    catch (e: any) {
      hide()
      throw new Error(`team_remind: capability evidence could not be refreshed; refused before Reminder-state access: ${e.message}`)
    }
    return expected
  }

  function definition(exposure: 'direct' | 'hidden') {
    return {
      name: 'team_remind',
      label: 'PM self-reminder',
      description: 'Create, list, inspect or cancel one-shot reminders for this project PM. The current verified PM is always the owner; full message text is preserved.',
      promptSnippet: 'team_remind: schedule or inspect a durable one-shot reminder for this PM',
      promptGuidelines: ['Use team_remind when this PM decides to revisit work at a future time; after an observed wake, create the next one-shot reminder with the same key when appropriate.'],
      exposure,
      executionMode: 'sequential',
      parameters: {
        type: 'object',
        properties: {
          action: { type: 'string', enum: ['add', 'list', 'show', 'cancel'] },
          at: { type: 'string', description: 'RFC 3339 date-time with Z or a numeric offset; exactly one of at/after for add' },
          after: { type: 'string', description: 'Positive integer plus s, m or h; exactly one of at/after for add' },
          key: { type: 'string', description: 'Optional logical key for active-request idempotency' },
          task: { type: 'string', description: 'Optional existing task reference' },
          message: { type: 'string', description: 'Complete reminder text for add; never truncated' },
          id: { type: 'string', description: 'Reminder ID for show or cancel' },
          all: { type: 'boolean', description: 'For list, include retained terminal history' },
        },
        required: ['action'],
        additionalProperties: false,
      },
      async execute(_toolCallId: string, params: any, signal: AbortSignal | undefined, _onUpdate: any, ctx: ExtensionContext) {
        const identity = verify(ctx)
        const result = await capability.runReminderAuthority({ identity, skill, action: params.action, params, signal })
        return {
          content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
          details: result,
          ...(result.ok ? {} : { isError: true }),
        }
      },
    }
  }

  // A discovered/global copy starts unreachable. Only session_start can prove a directed PM and activate it.
  pi.registerTool({ ...definition('hidden'), defaultActive: false } as any)
  pi.on('session_start', (_event, ctx) => {
    hide('session reloaded or replaced')
    expected = null
    generation = randomUUID()
    hide()
    activate(ctx)
  })
  for (const event of ['session_before_switch', 'session_before_fork'] as const) {
    pi.on(event, () => { if (expected) hide(event === 'session_before_fork' ? 'session forked' : 'session switched') })
  }
  pi.on('before_agent_start', (_event, ctx) => { if (!active) activate(ctx) })
  pi.on('session_shutdown', () => {
    stopHeartbeat()
    active = false
    if (expected) {
      try { capability.removeRemindCapability(expected, generation) }
      catch (e: any) {
        if (e?.code !== 'ENOENT') process.stderr.write(`[team-remind] capability cleanup failed: ${e?.message ?? e}\n`)
      }
    }
    expected = null
  })
}
