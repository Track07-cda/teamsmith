/** Test-only earlier message_start handler for P444. Loaded before team-inbox-watch in private Pi. */
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent'
import { appendFileSync, existsSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { setTimeout as delay } from 'node:timers/promises'

export default function (pi: ExtensionAPI) {
  pi.on('message_start', async (event, ctx) => {
    const message: any = event.message
    if (message?.role !== 'custom' || message.customType !== 'team-reminder') return
    const dir = process.env.P442_EVIDENCE!
    const record = {
      type: 'delay_enter', pid: process.pid, sessionId: ctx.sessionManager.getSessionId(),
      message: { role: message.role, customType: message.customType, content: message.content,
        details: message.details, display: true },
    }
    appendFileSync(join(dir, 'events.jsonl'), JSON.stringify(record) + '\n')
    writeFileSync(join(dir, 'delay-entered'), String(process.pid))
    if (process.env.P444_KILL_AT === 'event') process.kill(process.pid, 'SIGKILL')
    if (process.env.P444_DELAY === '1') {
      const release = join(dir, 'release-event')
      while (!existsSync(release)) await delay(25)
    }
    appendFileSync(join(dir, 'events.jsonl'), JSON.stringify({ type: 'delay_exit', pid: process.pid,
      sessionId: ctx.sessionManager.getSessionId(), details: message.details }) + '\n')
  })
}
