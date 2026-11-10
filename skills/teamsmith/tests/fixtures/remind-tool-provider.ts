/** Test-only controlled provider and lifecycle recorder for P442. Never injected by product defaults. */
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent'
import { appendFileSync, existsSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

export default function (pi: ExtensionAPI) {
  const dir = process.env.P442_EVIDENCE!
  const log = (value: object) => appendFileSync(join(dir, 'events.jsonl'), JSON.stringify(value) + '\n')
  pi.registerProvider('p442', {
    baseUrl: process.env.P442_ENDPOINT!, apiKey: 'local-fixture-not-a-credential', api: 'openai-completions',
    models: [{ id: 'controlled', name: 'Controlled loopback fixture', reasoning: false, input: ['text'],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 262144, maxTokens: 8192,
      compat: { supportsDeveloperRole: false, supportsStore: false } }],
  })
  pi.registerCommand('p442-control', {
    description: 'Private P442 lifecycle driver',
    handler: async (action, ctx) => {
      await ctx.waitForIdle()
      if (action === 'reload') await ctx.reload()
      else if (action === 'stop') ctx.shutdown()
      else throw new Error(`unknown fixture action ${action}`)
      log({ type: 'command_done', action })
    },
  })
  const state = (ctx: any) => ({
    sessionId: ctx.sessionManager.getSessionId(), sessionFile: ctx.sessionManager.getSessionFile(),
    reminderTools: pi.getAllTools().filter((tool: any) => tool.name === 'team_remind')
      .map((tool: any) => ({ name: tool.name, exposure: tool.exposure })),
    activeTools: pi.getActiveTools().filter((name: string) => name === 'team_remind'),
  })
  pi.on('session_start', (_event, ctx) => {
    log({ type: 'session_start', pid: process.pid, ...state(ctx) })
    writeFileSync(join(dir, 'session-start'), String(process.pid))
  })
  pi.on('before_agent_start', (_event, ctx) => { log({ type: 'before_agent_start', ...state(ctx) }) })
  pi.on('message_start', (event, ctx) => {
    if (event.message.role === 'custom') log({ type: 'custom_start', customType: event.message.customType,
      details: event.message.details, ...state(ctx) })
  })
  pi.on('tool_execution_end', event => {
    if (event.toolName === 'team_remind') log({ type: 'tool_end', isError: event.isError, result: event.result })
  })
  pi.on('agent_settled', (_event, ctx) => { log({ type: 'agent_settled', ...state(ctx) }) })
  pi.on('session_shutdown', () => {
    log({ type: 'shutdown' })
    const file = join(process.env.TEAM_STATE_DIR ?? '', 'remind-tool/current.json')
    try { log({ type: 'capability', value: JSON.parse(readFileSync(file, 'utf8')) }) }
    catch (e: any) { log({ type: 'capability_missing', reason: e.code, exists: existsSync(file) }) }
  })
}
