#!/usr/bin/env node
// remind-delivery-node.mjs — the Node half of tests/remind-delivery.sh (P423 · agent-self-reminder 3.1/3.2).
//
// Three groups, each printing `RD PASS|FAIL <name> [:: detail]` lines (the bash fixture owns the
// authority-level lifecycle; this file owns the presentation/match contract and the watcher itself):
//
//   content   reminderContent(): every Reminder's text byte for byte, ids, due/enqueued/attempt times,
//             source/task/overdue, no truncation; reminderDetails() carries the correlation identity.
//   match     matchesObservation(): only our custom message with the frozen batch id, nonce and member
//             set matches; role, type, nonce, batch and members each fail it on their own.
//   watcher   the real extension with a fake Pi host: one frozen batch → exactly one sendMessage
//             (followUp, triggerTurn), durable intent before the call, the correlated message_start
//             commits observed + one automatic Standby exit, a duplicate event changes nothing.
//
// Isolation: the caller (the fixture) prepares a repository, HOME/TMPDIR and strips the inherited team
// identity; this file only touches the repository path it is given and never the real project.
import { readFileSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

const [skillArg, repoArg, group] = process.argv.slice(2)
if (!skillArg || !repoArg || !group) {
  console.error('usage: remind-delivery-node.mjs <skill-dir> <fixture-repo> <content|match|watcher>')
  process.exit(2)
}
const SKILL = resolve(skillArg)
const REPO = resolve(repoArg)
const MOD = await import(pathToFileURL(join(SKILL, 'scripts/reminder-delivery.mjs')).href)

let pass = 0
let fail = 0
const ok = (name, detail = '') => { pass++; process.stdout.write(`RD PASS ${name}${detail ? ` :: ${detail}` : ''}\n`) }
const bad = (name, detail = '') => { fail++; process.stdout.write(`RD FAIL ${name}${detail ? ` :: ${detail}` : ''}\n`) }
const check = (name, condition, detail = '') => (condition ? ok(name, detail) : bad(name, detail))
const snapshot = () => JSON.parse(readFileSync(join(REPO, '.pi/team/state/reminders/state.json'), 'utf8'))
const sleep = ms => new Promise(r => setTimeout(r, ms))
async function waitFor(fn, timeoutMs, name) {
  const deadline = Date.now() + timeoutMs
  while (Date.now() < deadline) {
    try { const value = fn(); if (value) return value } catch { /* the file may not exist yet */ }
    await sleep(100)
  }
  bad(`${name}（等待超时 ${timeoutMs}ms）`)
  return null
}

const MESSAGE = '第一行 hello 100%\nsecond line\n\n'   // trailing blank line: the bytes are part of the text

function batchFixture(overrides = {}) {
  return {
    id: 'bat-00000000-0000-0000-0000-000000000000-3',
    nonce: 'nonce-abc',
    generation: 'off',
    intentAt: '2026-11-05T10:00:00.000Z',
    session: 'sess-1',
    members: [
      { id: 'rem-x-1', dueAt: '2026-11-05T10:00:00.000Z', enqueuedAt: '2026-11-05T10:00:09.000Z', overdue: false,
        source: 'cli', task: null, key: null, message: MESSAGE },
      { id: 'rem-x-2', dueAt: '2026-11-05T09:59:00.000Z', enqueuedAt: '2026-11-05T10:00:09.000Z', overdue: true,
        source: 'cli', task: 'P423', key: 'check', message: 'second reminder' },
    ],
    ...overrides,
  }
}

if (group === 'content') {
  const batch = batchFixture()
  const text = MOD.reminderContent(batch)
  check('content 每条正文逐字节出现（含结尾空行）', text.includes(MESSAGE) && text.includes('second reminder'))
  check('content 点名批次与 nonce', text.includes(batch.id) && text.includes('Nonce: nonce-abc'))
  check('content 点名每条 id / due / enqueued / attempted', ['rem-x-1', 'rem-x-2'].every(id => text.includes(id)) &&
    text.includes('Due: 2026-11-05T09:59:00.000Z') && text.includes('Enqueued: 2026-11-05T10:00:09.000Z') &&
    text.includes('Attempted: 2026-11-05T10:00:00.000Z'))
  check('content 标出补发与来源/任务/key', text.includes('overdue: the patrol queued it late') &&
    text.includes('source cli') && text.includes('task P423') && text.includes('key check'))
  check('content 不截断：整条正文长度原样留在消息里', (text.match(new RegExp(MESSAGE.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g')) ?? []).length === 1)
  const details = MOD.reminderDetails(batch)
  check('details 带批次身份与成员（模型看不见的那一半）', details.batchId === batch.id && details.nonce === 'nonce-abc' &&
    details.members.join(',') === 'rem-x-1,rem-x-2')
  const line = MOD.deliveryLogLine(batch, 'intent-sent')
  check('账本行点名批次/条数/来源，且不含提醒正文', line.includes(batch.id) && line.includes('n=2') && !line.includes('hello'))
  process.stdout.write(`== remind-delivery-node content 结果 == ✓${pass} ✗${fail}\n`)
  process.exit(fail ? 1 : 0)
}

if (group === 'match') {
  const batch = batchFixture()
  const good = { role: 'custom', customType: 'team-reminder', details: MOD.reminderDetails(batch), content: 'x' }
  check('match 我们那条消息 + 冻结的身份 → 真', MOD.matchesObservation(good, batch) === true)
  check('match 别的 customType → 假', MOD.matchesObservation({ ...good, customType: 'team-inbox' }, batch) === false)
  check('match 非 custom 角色（助手/用户）→ 假', MOD.matchesObservation({ ...good, role: 'assistant' }, batch) === false)
  check('match 没有 details → 假（身份无从证明）', MOD.matchesObservation({ ...good, details: undefined }, batch) === false)
  check('match 别的 nonce → 假', MOD.matchesObservation({ ...good, details: { ...good.details, nonce: 'other' } }, batch) === false)
  check('match 别的批次 → 假', MOD.matchesObservation({ ...good, details: { ...good.details, batchId: 'bat-other' } }, batch) === false)
  check('match 成员集不同 → 假', MOD.matchesObservation({ ...good, details: { ...good.details, members: ['rem-x-1'] } }, batch) === false)
  process.stdout.write(`== remind-delivery-node match 结果 == ✓${pass} ✗${fail}\n`)
  process.exit(fail ? 1 : 0)
}

if (group !== 'watcher') {
  console.error(`remind-delivery-node: unknown group ${group}`)
  process.exit(2)
}

// ---------------------------------------------------------------- watcher (fake Pi host)
process.env.TEAM_REMIND_POLL_MS = '200'
const EXT = join(SKILL, 'extension/team-inbox-watch.ts')
const sent = []
const handlers = {}
let factory
try {
  factory = (await import(pathToFileURL(EXT).href)).default
} catch (e) {
  bad(`watcher 扩展导入失败（需要 bun/tsx 这类能直接跑 .ts 的运行时）：${e.message}`)
  process.stdout.write(`== remind-delivery-node watcher 结果 == ✓${pass} ✗${fail}\n`)
  process.exit(1)
}
factory({
  on: (name, fn) => { (handlers[name] ||= []).push(fn) },
  registerTool() {},
  registerCommand() {},
  sendMessage: (message, options) => { sent.push({ message, options }) },
})
if (!handlers.session_start?.length || !handlers.message_start?.length) {
  bad('watcher 没有注册 session_start / message_start')
  process.stdout.write(`== remind-delivery-node watcher 结果 == ✓${pass} ✗${fail}\n`)
  process.exit(1)
}

let sessionId = 'sess-live'
const ctx = { cwd: REPO, sessionManager: { getSessionId: () => sessionId } }
await handlers.session_start[0]({ reason: 'startup' }, ctx)
const frozen = await waitFor(() => snapshot().batches.some(b => b.phase === 'intent') || null, 8000, 'watcher 把到点提醒冻结成一批')
check('watcher 冻结后不再有 queued 记录（同一批，不会重复入队）',
  Boolean(frozen) && snapshot().reminders.every(r => r.phase !== 'queued'))
const waiting = await waitFor(() => (sent.length ? sent : null), 8000, 'watcher 在一批冻结后发出消息')
const first = sent[0]
check('watcher 只发一条完整消息（一批一条）', sent.length === 1, `sent=${sent.length}`)
check('watcher 用 followUp + triggerTurn（不打断当前回合）', first?.options?.triggerTurn === true && first?.options?.deliverAs === 'followUp')
check('watcher 的 customType 是我们自己的', first?.message?.customType === 'team-reminder')
const body = String(first?.message?.content ?? '')
check('watcher 的正文带完整提醒文本（不截断）', body.includes('watcher reminder text'))
check('watcher 先写 intent 再发（快照里已有该批次）', (() => {
  const snap = snapshot()
  const batch = snap.batches.find(b => b.id === first?.message?.details?.batchId)
  return Boolean(batch) && batch.phase === 'intent' && batch.right === 'unspent'
})(), 'snapshot has no matching intent')
const intentBatch = snapshot().batches.find(b => b.id === first?.message?.details?.batchId)
check('watcher 的意图绑定了当前待命代次', intentBatch?.generation === 1, `generation=${intentBatch?.generation}`)

// the observation: Pi's own message_start for that very message
await handlers.message_start[0]({ message: { role: 'custom', customType: first.message.customType, details: first.message.details } })
const after = snapshot()
const observed = after.batches.find(b => b.id === first.message.details.batchId)
check('watcher 观察到匹配事件 → 批次 observed、right 花掉', observed?.phase === 'observed' && observed?.right === 'spent', `${observed?.phase}/${observed?.right}`)
check('watcher 的观察原子地退出待命（auto-off）', after.standby.on === false && observed?.outcome?.standby === 'auto-off',
  `standby=${after.standby.on}/${observed?.outcome?.standby}`)
const observedAudit = after.audit.filter(a => a.op === 'remind-observed')
check('watcher 的审计点名批次与每个提醒（含来源）', observedAudit.length === 1 &&
  observedAudit[0].batch === observed.id && observedAudit[0].ids.length === 1 && observedAudit[0].sources.length === 1)

// a duplicate/late event must change nothing and must not exit a newer generation
await handlers.message_start[0]({ message: { role: 'custom', customType: first.message.customType, details: first.message.details } })
await sleep(400)
const again = snapshot()
check('watcher 重复事件不产生第二次自动退待命', again.audit.filter(a => a.op === 'remind-observed').length === 1 &&
  again.batches.find(b => b.id === observed.id)?.rightSpentBy === 'wake')

// shutdown clears the timer: nothing is sent afterwards
await handlers.session_shutdown[0]({}, ctx)
const sentAtShutdown = sent.length
await sleep(700)
check('watcher shutdown 后不再发送', sent.length === sentAtShutdown, `sent=${sent.length}`)

process.stdout.write(`== remind-delivery-node watcher 结果 == ✓${pass} ✗${fail}\n`)
process.exit(fail ? 1 : 0)
