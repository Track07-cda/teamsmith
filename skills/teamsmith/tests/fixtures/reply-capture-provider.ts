/** Test-only loopback provider plus lifecycle observer. Never loaded by product launch defaults. */
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent'
import { appendFileSync, existsSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
export default function (pi: ExtensionAPI) {
  const dir = process.env.P396_EVIDENCE!
  const log = (value: object) => appendFileSync(join(dir, 'events.jsonl'), JSON.stringify(value) + '\n')
  pi.registerProvider('p396', { baseUrl: process.env.P396_ENDPOINT!, apiKey: 'local-fixture-not-a-credential', api: 'openai-completions', models: [{
    id: 'controlled', name: 'Controlled loopback fixture', reasoning: false, input: ['text'],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 128000, maxTokens: 8192,
    compat: { supportsDeveloperRole: false, supportsStore: false },
  }] })
  if (process.env.P396_CASE === 'tool') pi.registerTool({
    name: 'p396-tool', label: 'Fixture tool', description: 'Controlled tool round',
    parameters: { type: 'object', properties: {} } as any,
    execute: async () => ({ content: [{ type: 'text', text: 'controlled tool result' }], details: {} }),
  })
  pi.registerCommand('p396-control', {
    description: 'Private fixture lifecycle driver',
    handler: async (action, ctx) => {
      await ctx.waitForIdle()
      const original = join(dir, 'original-session')
      if (action === 'snapshot') {
        writeFileSync(original, ctx.sessionManager.getSessionFile()!)
        log({ type: 'snapshot', entries: ctx.sessionManager.getEntries(), ...state(ctx) })
      } else if (action === 'reload') await ctx.reload()
      else if (action === 'tree') {
        const user = ctx.sessionManager.getBranch().find((e: any) => e.type === 'message' && e.message.role === 'user')!
        await ctx.navigateTree(user.id, { summarize: false })
      } else if (action === 'fork') {
        const entry = ctx.sessionManager.getBranch().find((e: any) => e.type === 'message' && e.message.role === 'assistant')!
        await ctx.fork(entry.id, { position: 'at' })
      } else if (action === 'new') await ctx.newSession()
      else if (action === 'switch') await ctx.switchSession(readFileSync(original, 'utf8'))
      else if (action === 'stop') ctx.shutdown()
      else throw new Error(`unknown fixture action ${action}`)
      log({ type: 'command_done', action })
    },
  })
  let ends = 0, continued = false
  const state = (ctx: any) => ({ sessionId: ctx.sessionManager.getSessionId(), sessionFile: ctx.sessionManager.getSessionFile(), leaf: ctx.sessionManager.getLeafId() })
  pi.on('session_start', (_event, ctx) => {
    log({ type: 'session_start', pid: process.pid, finalPidPresent: existsSync(join(process.env.TEAM_STATE_DIR ?? '', 'pm.pid')), spawnPresent: existsSync(join(process.env.TEAM_STATE_DIR ?? '', 'pm.pid.spawn')), ...state(ctx) })
    writeFileSync(join(dir, 'session-start'), String(process.pid))
  })
  pi.on('before_agent_start', (_event, ctx) => { log({ type: 'before_agent_start', ...state(ctx) }) })
  pi.on('message_update', (event, ctx) => {
    const update: any = event.assistantMessageEvent
    if (update.type === 'text_delta') log({ type: 'raw_delta', delta: update.delta })
    if (process.env.P396_CASE === 'aborted' && update.type === 'text_delta' && update.delta.includes(']]')) ctx.abort()
  })
  pi.on('message_end', (event, ctx) => {
    if (event.message.role !== 'assistant') return
    ends++
    log({ type: 'message_end', message: event.message, ...state(ctx) })
    if (process.env.P396_CASE === 'queued' && ends === 1) pi.sendUserMessage('CASE queued-followup', { deliverAs: 'followUp' })
  })
  pi.on('turn_end', (event, ctx) => {
    log({ type: 'turn_end', id: event.messageEntryId, entry: event.messageEntryId ? ctx.sessionManager.getEntry(event.messageEntryId) : null, ...state(ctx) })
  })
  pi.on('agent_end', (event, ctx) => { log({ type: 'agent_end', willRetry: event.willRetry, ...state(ctx) }) })
  pi.on('agent_before_settle', (_event, ctx) => {
    if (process.env.P396_CASE === 'overallabort') ctx.abort()
    if (['continued', 'retry'].includes(process.env.P396_CASE!) && !continued) { continued = true; pi.sendUserMessage('CASE continued-followup', { deliverAs: 'followUp' }); return { continue: true } }
  })
  pi.on('agent_settled', (event, ctx) => {
    log({ type: 'agent_settled', aborted: event.aborted, ...state(ctx) })
    if (process.env.P396_TUI === '1') setTimeout(() => ctx.shutdown(), 500)
  })
  pi.on('session_shutdown', () => {
    // Registered after product capture: its shutdown has drained any writer first.
    log({ type: 'shutdown' })
    try { log({ type: 'runtime', value: JSON.parse(readFileSync(join(process.env.TEAM_STATE_DIR!, 'reply-capture/runtime.json'), 'utf8')) }) }
    catch (e: any) { log({ type: 'runtime_missing', reason: e.code }) }
  })
}
