// remind-store.mjs — the reminder domain of the project-state authority (P409 · change:
// agent-self-reminder 2.1/2.3; design.md "One snapshot is the authority" and "API, limits and lifecycle").
//
// This module never touches the filesystem: scripts/state-authority.mjs reads, validates, mutates under
// its flock transaction and writes the versioned snapshot, and calls applyReminder() inside that
// transaction. So there is exactly one state file, one lock and one durable order; the CLI and (later)
// the PM tool differ only in their presentation.
//
// What the snapshot stores is the delivery truth: phase, due instant, request, full text, source and the
// transitions. What a person sees is *derived* from that truth on every read -- `scheduled` gains the
// clock-derived `derived-due` view, and no counter is stored a second time, so a hand-corrected snapshot
// or a later Pulse admission is visible without a migration.

import { randomUUID } from 'node:crypto';
//
// Scopes: 2.x is the durable create/list/show/cancel lifecycle and the derived views (P409); 4.1/3.1/3.2
// add the delivery path here (P423): due admission (`queued`), the one frozen batch intent, the correlated
// observation that closes it, the explicit unknown outcome and the operator's acknowledgment. Everything
// still happens inside state-authority.mjs's single flock transaction; this file stays filesystem-free and
// the Pi call itself is *not* here (the caller sends after intent and reports the matching event back).

const PHASES = new Set(['scheduled', 'queued', 'intent', 'observed', 'unknown', 'cancelled', 'resolved']);
// A batch is the one durable delivery decision: at most one is outstanding until it is observed or an
// operator acknowledges it, and its single right is what may clear one Standby generation.
const BATCH_PHASES = new Set(['intent', 'observed', 'unknown', 'resolved']);
const OBSERVE_DEADLINE_MS = 60000;     // after intent, no correlated event within 60s = unknown, never a resend
const OVERDUE_LAG_MS = 30000;          // normal polling delay is not overdue; 30s of admission lag is
// Terminal = the outcome is known and the reminder can no longer fire. A key survives `unknown` (a
// delivery attempt is outstanding, so the logical reminder is still "in play") and is released by any
// terminal phase (design: "A key remains reserved for scheduled, queued, intent and unknown records").
const TERMINAL = new Set(['observed', 'cancelled', 'resolved']);
const KEY_HOLDING = new Set(['scheduled', 'queued', 'intent', 'unknown']);
const VIEWS = ['scheduled', 'derived-due', 'queued', 'intent', 'observed', 'unknown', 'cancelled', 'resolved'];

// Bounded terminal history (task 2.3). Active and unknown records are never evicted; the issued-ID
// high-water lives in the snapshot's sequence and only ever moves forward.
const TERMINAL_KEEP = 1000;
const AUDIT_KEEP = 1000;
const RETENTION_MS = 30 * 24 * 60 * 60 * 1000;

// An unquoted number in `--after` and a date-time without an offset are the two shapes a person most
// often means and the design explicitly rejects (an offset-free local time is ambiguous across machines).
const INSTANT_RE = /^(\d{4})-(\d{2})-(\d{2})[Tt](\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,9}))?([Zz]|[+-]\d{2}:\d{2})$/;
const DELAY_RE = /^(\d+)([smh])$/;
const KEY_RE = /^[\x20-\x7e]+$/;           // printable ASCII: a key is a durable identifier, not prose
const CONTROL_RE = /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/;

const fail = message => { throw new Error(message); };
const isTerminal = phase => TERMINAL.has(phase);
const iso = ms => new Date(ms).toISOString();
const msOf = text => Date.parse(text);

// ---------------------------------------------------------------- time parsing
function daysInMonth(year, month) { return new Date(Date.UTC(year, month, 0)).getUTCDate(); }

function parseInstant(text) {
  const raw = String(text ?? '').trim();
  if (!raw) return { error: 'time is empty: give --at <RFC 3339 date-time with offset> or --after <30s|5m|2h>' };
  const m = INSTANT_RE.exec(raw);
  if (!m) {
    if (/^\d{4}-\d{2}-\d{2}[Tt ]\d{2}:\d{2}(:\d{2})?(\.\d+)?$/.test(raw)) {
      return { error: `--at '${raw}' has no time zone: an absolute reminder must name its offset (…+08:00 or …Z)` };
    }
    return { error: `--at '${raw}' is not an RFC 3339 date-time (expected YYYY-MM-DDTHH:MM:SS with Z or ±HH:MM)` };
  }
  const year = Number(m[1]); const month = Number(m[2]); const day = Number(m[3]);
  const hour = Number(m[4]); const minute = Number(m[5]); const second = Number(m[6]);
  const frac = m[7] ? Number((m[7] + '000').slice(0, 3)) : 0;
  const zone = m[8];
  if (month < 1 || month > 12) return { error: `--at '${raw}' has no month ${month}` };
  if (day < 1 || day > daysInMonth(year, month)) return { error: `--at '${raw}' is not a real calendar date` };
  if (hour > 23) return { error: `--at '${raw}' has no hour ${hour}` };
  if (minute > 59) return { error: `--at '${raw}' has no minute ${minute}` };
  if (second > 59) return { error: `--at '${raw}' has no second ${second} (leap seconds are not representable)` };
  let offsetMinutes = 0;
  if (zone !== 'Z' && zone !== 'z') {
    const sign = zone[0] === '-' ? -1 : 1;
    const oh = Number(zone.slice(1, 3)); const om = Number(zone.slice(4, 6));
    if (oh > 23 || om > 59) return { error: `--at '${raw}' has an invalid offset ${zone}` };
    offsetMinutes = sign * (oh * 60 + om);
  }
  const utc = Date.UTC(year, month - 1, day, hour, minute, second, frac) - offsetMinutes * 60000;
  if (!Number.isFinite(utc)) return { error: `--at '${raw}' is outside the representable date range` };
  // Date.UTC normalizes overflow (Feb 30 -> Mar 2); a round trip through the same offset must land on
  // the components the caller wrote, or the date was not real.
  const back = new Date(utc + offsetMinutes * 60000);
  if (back.getUTCFullYear() !== year || back.getUTCMonth() !== month - 1 || back.getUTCDate() !== day ||
      back.getUTCHours() !== hour || back.getUTCMinutes() !== minute || back.getUTCSeconds() !== second) {
    return { error: `--at '${raw}' is not a real instant` };
  }
  return { ms: utc, value: raw };
}

function parseDelay(text) {
  const raw = String(text ?? '').trim();
  if (!raw) return { error: '--after is empty: give a positive number of seconds, minutes or hours (30s, 5m, 2h)' };
  const m = DELAY_RE.exec(raw);
  if (!m) {
    if (/^-/.test(raw)) return { error: `--after '${raw}' is negative: a reminder is in the future` };
    if (/^0+[smh]$/.test(raw)) return { error: `--after '${raw}' is zero: a reminder is in the future` };
    return { error: `--after '${raw}' is not a whole number followed by s, m or h (30s, 5m, 2h)` };
  }
  const value = Number(m[1]);
  if (!Number.isSafeInteger(value)) return { error: `--after '${raw}' is too large to represent` };
  if (value < 1) return { error: `--after '${raw}' is zero: a reminder is in the future` };
  const unit = { s: 1000, m: 60000, h: 3600000 }[m[2]];
  const delta = value * unit;
  if (!Number.isSafeInteger(delta) || delta > 8.64e15) return { error: `--after '${raw}' is too large to represent` };
  return { ms: delta, value: raw };
}

// ---------------------------------------------------------------- input validation
function normKey(key) {
  if (key === undefined || key === null || key === '') return { key: null };
  const value = String(key).trim();
  if (!value) return { error: 'key is empty (omit the flag instead)' };
  if (Buffer.byteLength(value, 'utf8') > 128) return { error: 'key is longer than 128 bytes' };
  if (!KEY_RE.test(value)) return { error: `key '${value}' has characters outside printable ASCII (a key is a durable identifier)` };
  return { key: value };
}

function normTask(task) {
  if (task === undefined || task === null || task === '') return { task: null };
  const value = String(task);
  if (CONTROL_RE.test(value)) return { error: 'task reference contains control characters' };
  if (Buffer.byteLength(value, 'utf8') > 200) return { error: 'task reference is longer than 200 bytes' };
  return { task: value };
}

// A message is stored, shown and delivered byte for byte; nothing here trims, folds or shortens it.
function normMessage(message) {
  if (typeof message !== 'string') return { error: 'message is missing' };
  if (message === '') return { error: 'message is empty: a reminder needs the text the future agent should read' };
  if (message.indexOf('\u0000') !== -1) return { error: 'message contains a NUL byte' };
  if (message.trim() === '') return { error: 'message is blank: a reminder needs readable text' };
  return { message };
}

const SOURCES = new Set(['cli', 'pm-tool']);
function normSource(source) {
  const value = source === undefined || source === null || source === '' ? 'cli' : String(source);
  if (!SOURCES.has(value)) return { error: `unknown source '${value}' (cli|pm-tool)` };
  return { source: value };
}

// ---------------------------------------------------------------- delivery (P423 · 3.1/3.2/4.1)
// `peek` is the only classification a caller may do without the lock: it answers "is there anything to
// commit right now" from a whole snapshot read (rename is atomic, so an unlocked read never sees half a
// file). Every decision that changes the snapshot still runs inside the transaction below.
export function peekReminders(snapshot, nowMs) {
  if (!snapshot || !Array.isArray(snapshot.reminders)) return { due: [], queued: [], staleIntent: [] };
  const due = [];
  const queued = [];
  const staleIntent = [];
  for (const record of snapshot.reminders) {
    if (record.phase === 'scheduled' && Number.isFinite(msOf(record.dueAt)) && msOf(record.dueAt) <= nowMs) due.push(record.id);
    if (record.phase === 'queued') queued.push(record.id);
  }
  for (const batch of Array.isArray(snapshot.batches) ? snapshot.batches : []) {
    if (batch.phase === 'intent' && Number.isFinite(msOf(batch.intentAt)) && nowMs - msOf(batch.intentAt) >= OBSERVE_DEADLINE_MS) staleIntent.push(batch.id);
  }
  return { due, queued, staleIntent };
}

function findBatch(snapshot, id) {
  return snapshot.batches.find(batch => batch.id === id) ?? null;
}

function parseBatchId(id, projectId) {
  const prefix = `bat-${projectId}-`;
  if (typeof id !== 'string' || !id.startsWith(prefix)) return null;
  const tail = id.slice(prefix.length);
  if (!/^[1-9][0-9]*$/.test(tail)) return null;
  const seq = Number(tail);
  return Number.isSafeInteger(seq) ? { seq } : null;
}

// The single outstanding delivery, if any. `unknown` is still outstanding: an operator has to inspect the
// batch before the next one may be frozen (design: "Only one batch is outstanding until observed or
// explicitly acknowledged"). A late correlated observation closes it too -- that is not a resend.
function outstandingBatch(snapshot) {
  return snapshot.batches.find(batch => batch.phase === 'intent' || batch.phase === 'unknown') ?? null;
}

// After the deadline, an intent without a correlated event is `unknown`: absence of an event is not proof
// that nothing entered the session, so the members stop being independently sendable and nothing resends.
function sweepStaleIntents(snapshot, nowMs) {
  const swept = [];
  for (const batch of snapshot.batches) {
    if (batch.phase !== 'intent' || !Number.isFinite(msOf(batch.intentAt))) continue;
    if (nowMs - msOf(batch.intentAt) < OBSERVE_DEADLINE_MS) continue;
    batch.phase = 'unknown';
    batch.unknownAt = iso(nowMs);
    for (const id of batch.members) {
      const record = snapshot.reminders.find(item => item.id === id);
      if (record && record.phase === 'intent') { record.phase = 'unknown'; record.unknownAt = batch.unknownAt; }
    }
    note(snapshot, nowMs, 'remind-unknown', { batch: batch.id, ids: batch.members.slice(), detail: 'no correlated wake within 60s; no automatic resend' });
    swept.push(batch.id);
  }
  return swept;
}

// 4.1: commit each due Reminder's queue identity, order and enqueue time. Runs for both Pulse shapes and
// is independent of PM availability and Standby; a repeated scan never creates a second queue entry.
function admitReminders(snapshot, request, nowMs) {
  const pulseStartedAt = typeof request.pulseStartedAt === 'string' ? request.pulseStartedAt : '';
  const startedMs = Number.isFinite(msOf(pulseStartedAt)) ? msOf(pulseStartedAt) : null;
  const swept = sweepStaleIntents(snapshot, nowMs);
  const due = snapshot.reminders
    .filter(record => record.phase === 'scheduled' && Number.isFinite(msOf(record.dueAt)) && msOf(record.dueAt) <= nowMs)
    .sort((a, b) => (msOf(a.dueAt) - msOf(b.dueAt)) || (a.seq - b.seq));
  const admitted = [];
  const overdue = [];
  for (const record of due) {
    const dueMs = msOf(record.dueAt);
    record.phase = 'queued';
    record.queuedAt = iso(nowMs);
    record.queueSeq = snapshot.sequences.queue;
    snapshot.sequences.queue += 1;
    record.overdue = (startedMs !== null && dueMs < startedMs) || nowMs - dueMs > OVERDUE_LAG_MS;
    if (record.overdue) overdue.push(record.id);
    admitted.push(record.id);
  }
  if (pulseStartedAt && (admitted.length || swept.length)) {
    snapshot.pulse = { startedAt: pulseStartedAt, lastAdmitAt: iso(nowMs) };
  }
  if (admitted.length) {
    note(snapshot, nowMs, 'remind-admit', { ids: admitted, detail: `due <= ${iso(nowMs)}; overdue ${overdue.length}` });
  }
  return {
    ok: true, now: iso(nowMs),
    admitted, overdue, swept,
    queue: snapshot.reminders.filter(record => record.phase === 'queued').length,
    queuedIds: snapshot.reminders.filter(record => record.phase === 'queued')
      .sort((a, b) => ((a.queueSeq ?? 0) - (b.queueSeq ?? 0)) || (a.seq - b.seq)).map(record => record.id),
    outstanding: outstandingBatch(snapshot)?.id ?? null,
  };
}

// 3.1: freeze every currently queued Reminder into ONE batch and bind the current Standby generation,
// before any Pi call. Returns the whole payload so the caller sends exactly what was frozen (full text,
// byte for byte) and nothing else. The next batch is eligible as soon as this outcome settles.
function intentBatch(snapshot, request, nowMs) {
  const swept = sweepStaleIntents(snapshot, nowMs);
  const outstanding = outstandingBatch(snapshot);
  if (outstanding) {
    return {
      ok: true, action: 'wait', now: iso(nowMs), batch: outstanding.id, swept,
      reason: outstanding.phase === 'unknown'
        ? `batch ${outstanding.id} is unknown: inspect it and run \`team remind resolve ${outstanding.id} --ack-unknown\`; nothing is resent`
        : `batch ${outstanding.id} is already in flight (intent at ${outstanding.intentAt})`,
    };
  }
  const queued = snapshot.reminders
    .filter(record => record.phase === 'queued')
    .sort((a, b) => ((a.queueSeq ?? 0) - (b.queueSeq ?? 0)) || (a.seq - b.seq));
  if (!queued.length) return { ok: true, action: 'idle', now: iso(nowMs), swept };
  const session = typeof request.session === 'string' ? request.session.trim() : '';
  if (!session) return { ok: false, refusal: 'bad-session', reason: 'the batch intent needs the verified PM session id (which session may observe the wake)' };
  const seq = snapshot.sequences.batch;
  snapshot.sequences.batch = seq + 1;
  const batch = {
    id: `bat-${snapshot.project.id}-${seq}`,
    seq,
    nonce: randomUUID(),
    phase: 'intent',
    intentAt: iso(nowMs),
    // Bound before the call: whatever the snapshot says now is the only generation this wake may clear.
    generation: snapshot.standby.on ? snapshot.standby.generation : 'off',
    target: { session, pid: Number.isSafeInteger(request.pid) ? request.pid : null },
    members: queued.map(record => record.id),
    right: 'unspent',
    rightSpentBy: null,
    attempts: 1,
    lastError: null,
    observedAt: null,
    unknownAt: null,
    resolvedAt: null,
    outcome: null,
  };
  for (const record of queued) {
    record.phase = 'intent';
    record.batchId = batch.id;
    record.intentAt = batch.intentAt;
  }
  snapshot.batches.push(batch);
  note(snapshot, nowMs, 'remind-intent', {
    batch: batch.id, ids: batch.members.slice(), detail: `standby generation ${batch.generation}; session ${session}`,
  });
  return {
    ok: true, action: 'send', now: iso(nowMs), swept,
    batch: {
      id: batch.id, nonce: batch.nonce, generation: batch.generation, intentAt: batch.intentAt, session,
      members: queued.map(record => ({
        id: record.id, dueAt: record.dueAt, enqueuedAt: record.queuedAt, overdue: Boolean(record.overdue),
        source: record.source, task: record.task, key: record.key, message: record.message,
      })),
    },
  };
}

// 3.2: the one atomic outcome. Observation, the consumed right, the generation-checked automatic off and
// the audit all commit in this same snapshot, so a replay is a no-op and a newer generation always wins.
function observeBatch(snapshot, request, nowMs) {
  const id = String(request.id ?? '');
  const batch = findBatch(snapshot, id);
  if (!batch) {
    const parsed = parseBatchId(id, snapshot.project.id);
    if (!parsed || parsed.seq >= snapshot.sequences.batch) {
      return { ok: false, refusal: 'unknown-batch', reason: `'${id}' is not a batch issued by this project` };
    }
    return {
      ok: false, refusal: 'history-pruned',
      reason: `'${id}' left the retained batch history (issued high-water ${snapshot.sequences.batch - 1}); it cannot be reopened or resent`,
    };
  }
  if (typeof request.nonce !== 'string' || request.nonce !== batch.nonce) {
    return { ok: false, refusal: 'nonce-mismatch', reason: `the observed message does not carry the nonce of ${batch.id} (identity unknown; no right consumed)` };
  }
  const session = typeof request.session === 'string' ? request.session.trim() : '';
  if (!session || batch.target?.session !== session) {
    return { ok: false, refusal: 'session-mismatch', reason: `${batch.id} was frozen for session ${batch.target?.session ?? '(none)'}, not '${session || '(none)'}'` };
  }
  if (batch.phase === 'resolved') return { ok: false, refusal: 'already-resolved', reason: `${batch.id} was acknowledged as unknown; it cannot be reopened` };
  if (batch.right === 'spent' || batch.phase === 'observed') {
    return { ok: true, outcome: 'duplicate', now: iso(nowMs), batch: batch.id, right: batch.right, reason: 'this batch already spent its one right; no second off' };
  }
  if (batch.phase !== 'intent' && batch.phase !== 'unknown') {
    return { ok: false, refusal: `bad-phase`, reason: `${batch.id} is ${batch.phase}; only an intent or an unknown batch can be observed` };
  }
  let standby = 'already-off';
  if (batch.generation === 'off') standby = 'already-off';
  else if (!snapshot.standby.on) standby = 'already-off';
  else if (snapshot.standby.generation === batch.generation) {
    snapshot.standby = { on: false, generation: snapshot.standby.generation, reason: null, since: iso(nowMs), migrated: true };
    standby = 'auto-off';
  } else standby = 'generation-ambiguous';
  batch.phase = 'observed';
  batch.observedAt = iso(nowMs);
  batch.right = 'spent';
  batch.rightSpentBy = 'wake';
  batch.outcome = { standby };
  for (const mid of batch.members) {
    const record = snapshot.reminders.find(item => item.id === mid);
    if (!record) continue;
    record.phase = 'observed';
    record.observedAt = batch.observedAt;
    record.endedAt = batch.observedAt;
  }
  note(snapshot, nowMs, 'remind-observed', {
    batch: batch.id, ids: batch.members.slice(),
    sources: batch.members.map(mid => snapshot.reminders.find(item => item.id === mid)?.source ?? '?'),
    detail: `standby ${standby} (bound generation ${batch.generation})`,
  });
  return { ok: true, outcome: 'observed', now: iso(nowMs), batch: batch.id, standby, generation: batch.generation, ids: batch.members.slice() };
}

// A synchronous refusal from the session API is not a receipt: the batch becomes unknown (visible, no
// automatic resend) so the next delivery waits for an operator instead of blindly sending it twice.
function failBatch(snapshot, request, nowMs) {
  const id = String(request.id ?? '');
  const batch = findBatch(snapshot, id);
  if (!batch) return { ok: false, refusal: 'unknown-batch', reason: `'${id}' is not a batch of this project` };
  if (typeof request.nonce !== 'string' || request.nonce !== batch.nonce) {
    return { ok: false, refusal: 'nonce-mismatch', reason: `the failed attempt does not carry the nonce of ${batch.id}` };
  }
  if (batch.right === 'spent') {
    return { ok: true, outcome: 'already-observed', now: iso(nowMs), batch: batch.id, reason: 'a wake was already observed; the failure is recorded but nothing is reopened' };
  }
  if (batch.phase !== 'intent') {
    return { ok: true, outcome: 'already-unknown', now: iso(nowMs), batch: batch.id, reason: `${batch.id} is already ${batch.phase}` };
  }
  const reason = String(request.reason ?? '').slice(0, 400) || 'the session API refused the message';
  batch.phase = 'unknown';
  batch.unknownAt = iso(nowMs);
  batch.attempts = (batch.attempts ?? 1) + 1;
  batch.lastError = reason;
  for (const mid of batch.members) {
    const record = snapshot.reminders.find(item => item.id === mid);
    if (record && record.phase === 'intent') { record.phase = 'unknown'; record.unknownAt = batch.unknownAt; }
  }
  note(snapshot, nowMs, 'remind-send-failed', { batch: batch.id, ids: batch.members.slice(), detail: reason });
  return { ok: true, outcome: 'unknown', now: iso(nowMs), batch: batch.id, ids: batch.members.slice(), reason };
}

// The operator's explicit acknowledgment of an inspected unknown batch: close every member, burn the one
// remaining right and do not resend. It does not assert whether delivery happened.
function resolveBatch(snapshot, request, nowMs) {
  const id = String(request.id ?? '');
  const batch = findBatch(snapshot, id);
  if (!batch) return { ok: false, refusal: 'unknown-batch', reason: `'${id}' is not a batch of this project` };
  if (batch.phase === 'resolved') {
    return { ok: true, outcome: 'already-resolved', now: iso(nowMs), batch: batch.id, ids: batch.members.slice() };
  }
  if (batch.phase === 'intent') {
    return { ok: false, refusal: 'in-flight', reason: `${batch.id} is still an intent (no observation yet); wait for the 60s deadline or check ${snapshot.project.stateRoot}/reminders/state.json` };
  }
  if (batch.phase === 'observed') {
    return { ok: false, refusal: 'already-observed', reason: `${batch.id} was observed at ${batch.observedAt}; there is nothing uncertain to acknowledge` };
  }
  batch.phase = 'resolved';
  batch.resolvedAt = iso(nowMs);
  batch.right = 'spent';
  batch.rightSpentBy = 'resolve';
  for (const mid of batch.members) {
    const record = snapshot.reminders.find(item => item.id === mid);
    if (!record) continue;
    record.phase = 'resolved';
    record.resolvedAt = batch.resolvedAt;
    record.endedAt = batch.resolvedAt;
  }
  note(snapshot, nowMs, 'remind-resolved', { batch: batch.id, ids: batch.members.slice(), detail: 'operator acknowledged an unknown batch; nothing resent' });
  return { ok: true, outcome: 'resolved', now: iso(nowMs), batch: batch.id, ids: batch.members.slice(), right: 'spent' };
}

// ---------------------------------------------------------------- views (derived, never stored)
function viewOf(record, nowMs) {
  if (record.phase === 'scheduled') return msOf(record.dueAt) <= nowMs ? 'derived-due' : 'scheduled';
  return record.phase;
}

function viewOfRecord(record, nowMs) {
  const dueMs = msOf(record.dueAt);
  return {
    id: record.id,
    seq: record.seq,
    phase: record.phase,
    view: viewOf(record, nowMs),
    dueAt: record.dueAt,
    dueInMs: dueMs - nowMs,
    createdAt: record.createdAt,
    key: record.key,
    source: record.source,
    owner: record.owner,
    task: record.task,
    message: record.message,
    endedAt: record.endedAt ?? null,
    batchId: record.batchId ?? null,
    queuedAt: record.queuedAt ?? null,
    intentAt: record.intentAt ?? null,
    overdue: record.overdue === undefined ? null : Boolean(record.overdue),
  };
}

function countsOf(records, nowMs) {
  const counts = Object.fromEntries(VIEWS.map(view => [view, 0]));
  for (const record of records) counts[viewOf(record, nowMs)] = (counts[viewOf(record, nowMs)] ?? 0) + 1;
  return counts;
}

// ---------------------------------------------------------------- request identity (key idempotency)
function sameRequest(record, request) {
  return record.request.form === request.form && record.request.value === request.value &&
    record.message === request.message && (record.task ?? null) === (request.task ?? null);
}

// ---------------------------------------------------------------- snapshot validation
// Runs under the lock before any mutation. A snapshot that contradicts itself (an id at or above the
// high-water, a high-water that forgot its own pruned records) is refused instead of used: a lower
// high-water would silently turn a pruned identity into a never-issued one and make an old ID look
// reusable.
export function validateReminders(snapshot, failWith) {
  const bad = message => failWith(message);
  const highWater = snapshot.sequences.reminder;
  if (snapshot.pruned > highWater - 1) {
    bad(`state snapshot pruned count ${snapshot.pruned} exceeds the issued high-water ${highWater - 1}; the high-water went backwards`);
  }
  const seen = new Set();
  for (const record of snapshot.reminders) {
    if (typeof record.id !== 'string') bad('a Reminder record has no id');
    const parsed = parseId(record.id, snapshot.project.id);
    if (!parsed) bad(`invalid Reminder id: ${record.id}`);
    if (parsed.seq >= highWater) bad(`Reminder ${record.id} claims sequence ${parsed.seq} at or above the issued high-water ${highWater - 1}`);
    if (seen.has(record.id)) bad(`duplicate Reminder id: ${record.id}`);
    seen.add(record.id);
    if (record.seq !== parsed.seq) bad(`Reminder ${record.id} carries seq ${record.seq}, its id says ${parsed.seq}`);
    if (record.owner !== 'pm') bad(`Reminder ${record.id} has an unknown owner: ${record.owner}`);
    if (!SOURCES.has(record.source)) bad(`Reminder ${record.id} has an unknown source: ${record.source}`);
    if (!PHASES.has(record.phase)) bad(`Reminder ${record.id} has an unknown phase: ${record.phase}`);
    if (typeof record.message !== 'string' || record.message === '' || record.message.indexOf('\u0000') !== -1) {
      bad(`Reminder ${record.id} has no usable message`);
    }
    if (typeof record.dueAt !== 'string' || !Number.isFinite(msOf(record.dueAt))) bad(`Reminder ${record.id} has an unreadable due time`);
    if (typeof record.createdAt !== 'string' || !Number.isFinite(msOf(record.createdAt))) bad(`Reminder ${record.id} has an unreadable creation time`);
    if (!record.request || typeof record.request !== 'object' || !['at', 'after'].includes(record.request.form) || typeof record.request.value !== 'string') {
      bad(`Reminder ${record.id} has no readable time request`);
    }
    if (record.key !== null && record.key !== undefined && typeof record.key !== 'string') bad(`Reminder ${record.id} has an unreadable key`);
    if (record.task !== null && record.task !== undefined && typeof record.task !== 'string') bad(`Reminder ${record.id} has an unreadable task reference`);
    if (isTerminal(record.phase) && (typeof record.endedAt !== 'string' || !Number.isFinite(msOf(record.endedAt)))) {
      bad(`terminal Reminder ${record.id} has no ended time`);
    }
    if (record.batchId !== null && record.batchId !== undefined && typeof record.batchId !== 'string') {
      bad(`Reminder ${record.id} has an unreadable batch id`);
    }
    for (const field of ['queuedAt', 'intentAt', 'unknownAt']) {
      if (record[field] !== undefined && record[field] !== null && !Number.isFinite(msOf(record[field]))) {
        bad(`Reminder ${record.id} has an unreadable ${field}`);
      }
    }
  }
  // The batches are the delivery truth, so they are validated with the same care: a batch that names a
  // member it does not own, a right that is neither spent nor unspent, or a sequence at the high-water
  // would let a resend decision be made from a contradiction.
  const batchWater = snapshot.sequences.batch;
  const batchIds = new Set();
  for (const batch of snapshot.batches) {
    if (typeof batch.id !== 'string') bad('a batch record has no id');
    const parsed = parseBatchId(batch.id, snapshot.project.id);
    if (!parsed) bad(`invalid batch id: ${batch.id}`);
    if (parsed.seq >= batchWater) bad(`batch ${batch.id} claims sequence ${parsed.seq} at or above the issued high-water ${batchWater - 1}`);
    if (batch.seq !== parsed.seq) bad(`batch ${batch.id} carries seq ${batch.seq}, its id says ${parsed.seq}`);
    if (batchIds.has(batch.id)) bad(`duplicate batch id: ${batch.id}`);
    batchIds.add(batch.id);
    if (!BATCH_PHASES.has(batch.phase)) bad(`batch ${batch.id} has an unknown phase: ${batch.phase}`);
    if (typeof batch.nonce !== 'string' || !batch.nonce) bad(`batch ${batch.id} has no correlation nonce`);
    if (typeof batch.intentAt !== 'string' || !Number.isFinite(msOf(batch.intentAt))) bad(`batch ${batch.id} has an unreadable intent time`);
    if (!Number.isSafeInteger(batch.generation) && batch.generation !== 'off') bad(`batch ${batch.id} has an unreadable Standby binding`);
    if (batch.right !== 'unspent' && batch.right !== 'spent') bad(`batch ${batch.id} has an unreadable right: ${batch.right}`);
    if (batch.rightSpentBy !== null && !['wake', 'resolve'].includes(batch.rightSpentBy)) bad(`batch ${batch.id} has an unreadable right holder: ${batch.rightSpentBy}`);
    if (!Number.isSafeInteger(batch.attempts) || batch.attempts < 1) bad(`batch ${batch.id} has an unreadable attempt count`);
    if (!Array.isArray(batch.members) || !batch.members.length) bad(`batch ${batch.id} has no members`);
    for (const mid of batch.members) {
      const record = snapshot.reminders.find(item => item.id === mid);
      if (!record) bad(`batch ${batch.id} names a member that is not in the snapshot: ${mid}`);
      else if (record.batchId !== batch.id) bad(`batch ${batch.id} names ${mid}, whose record says ${record.batchId}`);
    }
  }
  for (const record of snapshot.reminders) {
    if (record.batchId === null || record.batchId === undefined) continue;
    const batch = snapshot.batches.find(item => item.id === record.batchId);
    if (!batch) bad(`Reminder ${record.id} names a batch that is not in the snapshot: ${record.batchId}`);
    else if (!batch.members.includes(record.id)) bad(`Reminder ${record.id} claims ${record.batchId}, which does not list it`);
  }
  if (snapshot.audit.some(entry => !entry || typeof entry !== 'object' || typeof entry.op !== 'string' ||
      typeof entry.at !== 'string' || !Number.isFinite(msOf(entry.at)))) {
    bad('the state audit has an unreadable entry');
  }
}

function parseId(id, projectId) {
  const prefix = `rem-${projectId}-`;
  if (typeof id !== 'string' || !id.startsWith(prefix)) return null;
  const tail = id.slice(prefix.length);
  if (!/^[1-9][0-9]*$/.test(tail)) return null;
  const seq = Number(tail);
  return Number.isSafeInteger(seq) ? { seq } : null;
}

// ---------------------------------------------------------------- retention
// Same-transaction compaction: keep the newest TERMINAL_KEEP terminal outcomes that are also inside the
// retention window, and never touch a record that is not terminal. The count pruned is cumulative and
// the sequence high-water is untouched, so an issued ID can never be handed out a second time.
function endedMs(record) { return msOf(record.endedAt ?? record.createdAt); }

function pruneHistory(snapshot, nowMs) {
  // A retained batch needs every member for validation and late-event correlation, so batches and
  // their terminal members compact as one unit. Intent/unknown batches and every unspent right stay.
  const terminalBatches = snapshot.batches.filter(batch =>
    (batch.phase === 'observed' || batch.phase === 'resolved') && batch.right === 'spent' &&
    batch.members.every(id => {
      const record = snapshot.reminders.find(item => item.id === id);
      return record && isTerminal(record.phase);
    }));
  const batchEndedMs = batch => msOf(batch.observedAt ?? batch.resolvedAt ?? batch.intentAt);
  const rankedBatches = terminalBatches.slice().sort((a, b) => (batchEndedMs(b) - batchEndedMs(a)) || (b.seq - a.seq));
  const keepBatches = new Set();
  for (let i = 0; i < rankedBatches.length; i++) {
    if (i < TERMINAL_KEEP && nowMs - batchEndedMs(rankedBatches[i]) <= RETENTION_MS) keepBatches.add(rankedBatches[i].id);
  }
  const droppedBatches = terminalBatches.filter(batch => !keepBatches.has(batch.id));
  const droppedBatchIds = new Set(droppedBatches.map(batch => batch.id));

  const standalone = snapshot.reminders.filter(record => isTerminal(record.phase) && !record.batchId);
  const ranked = standalone.slice().sort((a, b) => (endedMs(b) - endedMs(a)) || (b.seq - a.seq));
  const keep = new Set();
  for (let i = 0; i < ranked.length; i++) {
    if (i < TERMINAL_KEEP && nowMs - endedMs(ranked[i]) <= RETENTION_MS) keep.add(ranked[i].id);
  }
  const droppedStandalone = standalone.filter(record => !keep.has(record.id));
  const droppedStandaloneIds = new Set(droppedStandalone.map(record => record.id));
  const droppedCount = droppedStandalone.length + droppedBatches.reduce((n, batch) => n + batch.members.length, 0);
  if (droppedCount) {
    const droppedIds = [
      ...droppedStandalone,
      ...droppedBatches.flatMap(batch => batch.members.map(id => snapshot.reminders.find(record => record.id === id)).filter(Boolean)),
    ];
    snapshot.reminders = snapshot.reminders.filter(record =>
      record.batchId ? !droppedBatchIds.has(record.batchId) : !droppedStandaloneIds.has(record.id));
    snapshot.batches = snapshot.batches.filter(batch => !droppedBatchIds.has(batch.id));
    snapshot.pruned += droppedCount;
    snapshot.audit.push({
      at: iso(nowMs), op: 'retention-prune', count: droppedCount,
      ids: droppedIds.sort((a, b) => b.seq - a.seq).slice(0, 20).map(record => record.id),
      detail: `kept the newest ${TERMINAL_KEEP} terminal outcomes inside 30 days; active/unknown rights stay and sequence high-water never moves back`,
    });
  }
  const audit = snapshot.audit.filter(entry => nowMs - msOf(entry.at) <= RETENTION_MS);
  snapshot.audit = audit.length > AUDIT_KEEP ? audit.slice(audit.length - AUDIT_KEEP) : audit;
  return droppedCount;
}

function note(snapshot, nowMs, op, fields) {
  snapshot.audit.push({ at: iso(nowMs), op, ...fields });
}

// ---------------------------------------------------------------- operations (inside the lock)
function newRecord(snapshot, fields, nowMs) {
  const seq = snapshot.sequences.reminder;
  snapshot.sequences.reminder = seq + 1;
  const record = {
    id: `rem-${snapshot.project.id}-${seq}`,
    seq,
    owner: 'pm',
    source: fields.source,
    task: fields.task,
    key: fields.key,
    phase: 'scheduled',
    createdAt: iso(nowMs),
    request: { form: fields.form, value: fields.value },
    dueAt: iso(fields.dueMs),
    message: fields.message,
    endedAt: null,
  };
  snapshot.reminders.push(record);
  return record;
}

function addReminder(snapshot, request, nowMs) {
  const source = normSource(request.source);
  if (source.error) return { ok: false, refusal: 'bad-source', reason: source.error };
  const key = normKey(request.key);
  if (key.error) return { ok: false, refusal: 'bad-key', reason: key.error };
  const task = normTask(request.task);
  if (task.error) return { ok: false, refusal: 'bad-task', reason: task.error };
  const message = normMessage(request.message);
  if (message.error) return { ok: false, refusal: 'bad-message', reason: message.error };

  const hasAt = request.at !== undefined && request.at !== null && String(request.at) !== '';
  const hasAfter = request.after !== undefined && request.after !== null && String(request.after) !== '';
  if (hasAt && hasAfter) return { ok: false, refusal: 'both-times', reason: 'give exactly one of --at or --after, not both' };
  if (!hasAt && !hasAfter) return { ok: false, refusal: 'no-time', reason: 'give one of --at <instant> or --after <duration>' };
  const form = hasAt ? 'at' : 'after';
  const parsed = hasAt ? parseInstant(request.at) : parseDelay(request.after);
  if (parsed.error) return { ok: false, refusal: form === 'at' ? 'bad-at' : 'bad-after', reason: parsed.error };

  // An active key is answered before the deadline is recomputed and before the past-time rule: a retry
  // of the same request after its due is the *same* reminder, not a new one and not a bad time.
  if (key.key) {
    const active = snapshot.reminders.find(record => record.key === key.key && KEY_HOLDING.has(record.phase));
    if (active) {
      const candidate = { form, value: parsed.value, message: message.message, task: task.task };
      if (!sameRequest(active, candidate)) {
        return {
          ok: false, refusal: 'key-conflict',
          reason: `key '${key.key}' is already held by ${active.id} (${active.phase}, due ${active.dueAt}) with a different request; ` +
            'cancel or wait for it, or use another key',
          existingId: active.id,
        };
      }
      return { ok: true, created: false, duplicate: true, now: iso(nowMs), reminder: viewOfRecord(active, nowMs) };
    }
  }

  const dueMs = form === 'at' ? parsed.ms : nowMs + parsed.ms;
  if (!Number.isFinite(dueMs) || Math.abs(dueMs) > 8.64e15) {
    return { ok: false, refusal: 'bad-time-range', reason: 'the computed due instant is outside the representable date range' };
  }
  if (dueMs <= nowMs) {
    return {
      ok: false, refusal: 'past-time',
      reason: `${form === 'at' ? `--at '${parsed.value}'` : 'the computed due instant'} is not in the future (now ${iso(nowMs)}); a reminder cannot fire in the past`,
    };
  }

  const record = newRecord(snapshot, {
    source: source.source, task: task.task, key: key.key, message: message.message,
    form, value: parsed.value, dueMs,
  }, nowMs);
  note(snapshot, nowMs, 'remind-add', { ids: [record.id], source: source.source, detail: record.key ? `key=${record.key}` : null });
  pruneHistory(snapshot, nowMs);
  return { ok: true, created: true, now: iso(nowMs), reminder: viewOfRecord(record, nowMs) };
}

function findReminder(snapshot, id, projectId) {
  const record = snapshot.reminders.find(item => item.id === id) ?? null;
  if (record) return { record };
  const parsed = parseId(id, projectId);
  if (!parsed) return { refusal: 'unknown-id', reason: `'${id}' is not a reminder id of this project (rem-<project id>-<n>)` };
  if (parsed.seq >= snapshot.sequences.reminder) {
    return { refusal: 'unknown-id', reason: `'${id}' was never issued by this project (issued high-water ${snapshot.sequences.reminder - 1})` };
  }
  return {
    refusal: 'history-pruned',
    reason: `'${id}' was issued and has left the retained history (issued high-water ${snapshot.sequences.reminder - 1}, ` +
      `${snapshot.pruned} terminal outcomes pruned); it cannot be revived or re-sent`,
  };
}

function showReminder(snapshot, request, nowMs) {
  const found = findReminder(snapshot, String(request.id ?? ''), snapshot.project.id);
  if (!found.record) {
    return { ok: false, refusal: found.refusal, reason: found.reason, highWater: snapshot.sequences.reminder - 1, pruned: snapshot.pruned };
  }
  return { ok: true, found: true, now: iso(nowMs), highWater: snapshot.sequences.reminder - 1, pruned: snapshot.pruned, reminder: viewOfRecord(found.record, nowMs) };
}

function cancelReminder(snapshot, request, nowMs) {
  const found = findReminder(snapshot, String(request.id ?? ''), snapshot.project.id);
  if (!found.record) {
    return { ok: false, refusal: found.refusal, reason: found.reason, highWater: snapshot.sequences.reminder - 1 };
  }
  const record = found.record;
  if (record.phase === 'cancelled') {
    return { ok: true, outcome: 'already-cancelled', now: iso(nowMs), reminder: viewOfRecord(record, nowMs), reason: 'it was already cancelled; nothing changed' };
  }
  if (isTerminal(record.phase)) {
    return {
      ok: false, refusal: `already-${record.phase}`,
      reason: `${record.id} is already ${record.phase} (${record.endedAt}); a terminal reminder cannot be cancelled`,
      reminder: viewOfRecord(record, nowMs),
    };
  }
  if (record.phase === 'intent' || record.phase === 'unknown') {
    return {
      ok: false, refusal: 'in-flight',
      reason: `${record.id} is ${record.phase}: the batch was already frozen for delivery, so withdrawal cannot be guaranteed; ` +
        'nothing was changed (inspect the batch and its delivery evidence first)',
      reminder: viewOfRecord(record, nowMs),
    };
  }
  const from = record.phase;
  record.phase = 'cancelled';
  record.cancelledFrom = from;
  record.endedAt = iso(nowMs);
  note(snapshot, nowMs, 'remind-cancel', { ids: [record.id], source: record.source, detail: `from ${from}` });
  pruneHistory(snapshot, nowMs);
  return { ok: true, outcome: 'cancelled', from, now: iso(nowMs), reminder: viewOfRecord(record, nowMs) };
}

function listReminders(snapshot, request, nowMs) {
  const all = request.all === true;
  const active = snapshot.reminders.filter(record => !isTerminal(record.phase))
    .sort((a, b) => (msOf(a.dueAt) - msOf(b.dueAt)) || (a.seq - b.seq))
    .map(record => viewOfRecord(record, nowMs));
  const terminal = snapshot.reminders.filter(record => isTerminal(record.phase))
    .sort((a, b) => (endedMs(b) - endedMs(a)) || (b.seq - a.seq))
    .map(record => viewOfRecord(record, nowMs));
  const batchCounts = { intent: 0, observed: 0, unknown: 0, resolved: 0 };
  for (const batch of snapshot.batches) batchCounts[batch.phase] = (batchCounts[batch.phase] ?? 0) + 1;
  const outstanding = outstandingBatch(snapshot);
  return {
    ok: true,
    now: iso(nowMs),
    projectId: snapshot.project.id,
    stateRoot: snapshot.project.stateRoot,
    highWater: snapshot.sequences.reminder - 1,
    pruned: snapshot.pruned,
    counts: countsOf(snapshot.reminders, nowMs),
    active,
    terminal: all ? terminal : [],
    terminalTotal: terminal.length,
    terminalShown: all,
    outstanding: outstanding ? { id: outstanding.id, phase: outstanding.phase, intentAt: outstanding.intentAt, members: outstanding.members.slice() } : null,
    batchCounts,
  };
}

export function applyReminder(snapshot, request, nowMs) {
  switch (request.op) {
    case 'remind-add': return addReminder(snapshot, request, nowMs);
    case 'remind-list': return listReminders(snapshot, request, nowMs);
    case 'remind-show': return showReminder(snapshot, request, nowMs);
    case 'remind-cancel': return cancelReminder(snapshot, request, nowMs);
    case 'remind-admit': return admitReminders(snapshot, request, nowMs);
    case 'remind-intent': return intentBatch(snapshot, request, nowMs);
    case 'remind-observe': return observeBatch(snapshot, request, nowMs);
    case 'remind-fail': return failBatch(snapshot, request, nowMs);
    case 'remind-resolve': return resolveBatch(snapshot, request, nowMs);
    default: fail(`unknown reminder operation: ${request.op}`);
  }
}

export const REMIND_OPS = new Set([
  'remind-add', 'remind-list', 'remind-show', 'remind-cancel',
  'remind-admit', 'remind-intent', 'remind-observe', 'remind-fail', 'remind-resolve',
]);

// ---------------------------------------------------------------- presentation
// Tokens (id, phase/view names, source, times) stay machine-shaped: they are the same words the spec and
// the JSON use, so a person and a script read one vocabulary. Prose is Chinese, like the rest of the CLI.

function humanDelta(ms) {
  const a = Math.abs(ms);
  const suffix = a < 1000 ? '<1s'
    : a < 60000 ? `${Math.ceil(a / 1000)}s`
      : a < 3600000 ? `${Math.floor(a / 60000)}m`
        : a < 86400000 ? `${Math.floor(a / 3600000)}h`
          : `${Math.floor(a / 86400000)}d`;
  return ms >= 0 ? `还有 ${suffix}` : `已过 ${suffix}`;
}

function dueLine(record, nowMs) {
  const delta = msOf(record.dueAt) - nowMs;
  const rel = record.view === 'derived-due' ? '已到期，等 Pulse 入队' : humanDelta(delta);
  return `到期 ${record.dueAt}（${rel}）`;
}

function attrLine(record) {
  const parts = [`来源 ${record.source}`];
  if (record.key) parts.push(`key ${record.key}`);
  if (record.task) parts.push(`task ${record.task}`);
  return parts.join(' · ');
}

function renderAdd(result) {
  if (!result.ok) return `team remind add：${result.reason}\n`;
  const record = result.reminder;
  const head = result.created
    ? `已创建 ${record.id} · ${record.view}`
    : `已存在 ${record.id} · ${record.view}（key '${record.key}' 下的同一请求；due 不重算）`;
  return `${head}\n  ${dueLine(record, Date.parse(result.now))}\n  ${attrLine(record)} · owner ${record.owner}\n`;
}

function renderList(result) {
  const c = result.counts;
  const activeN = result.active.length;
  const lines = [
    `提醒 · ${activeN} 条活跃 · 已签发 ${result.highWater} · 已修剪 ${result.pruned} · 现在 ${result.now}`,
    `视图 ${VIEWS.map(view => `${view}=${c[view] ?? 0}`).join(' ')}`,
  ];
  if (result.outstanding) {
    const ob = result.outstanding;
    lines.push(ob.phase === 'unknown'
      ? `批次 ${ob.id} · unknown（未确认送达：检查后 team remind resolve ${ob.id} --ack-unknown；不会自动重发）`
      : `批次 ${ob.id} · intent（已冻结，等唤醒回执；冻结于 ${ob.intentAt}）`);
  }
  if (!activeN && !result.terminalTotal) {
    lines.push('（还没有提醒：team remind add --after 20m --message "…"）');
    return lines.join('\n') + '\n';
  }
  for (const record of result.active) {
    lines.push(`${record.id} · ${record.view} · ${dueLine(record, Date.parse(result.now))} · ${attrLine(record)}`);
    lines.push(record.message);
    lines.push('');
  }
  if (result.terminalShown) {
    for (const record of result.terminal) {
      lines.push(`${record.id} · ${record.view} · 到期 ${record.dueAt} · 结束 ${record.endedAt} · ${attrLine(record)}`);
      lines.push(record.message);
      lines.push('');
    }
  } else if (result.terminalTotal) {
    lines.push(`（另有 ${result.terminalTotal} 条已终结：team remind list --all 看它们）`);
  }
  return lines.join('\n') + '\n';
}

function renderShow(result) {
  if (!result.ok) return `team remind show：${result.reason}\n`;
  const record = result.reminder;
  const ended = record.endedAt ? `\n  结束     ${record.endedAt}` : '';
  const queued = record.queuedAt ? `\n  入队     ${record.queuedAt}${record.overdue ? '（补发：到期时巡检没在看）' : ''}` : '';
  const batch = record.batchId ? `\n  批次     ${record.batchId}` : '';
  return [
    `${record.id} · ${record.view}（phase ${record.phase}）`,
    `  到期     ${record.dueAt}`,
    `  创建     ${record.createdAt}${ended}`,
    `  视图     ${record.view}`,
    `  归属     owner ${record.owner}${record.key ? ` · key ${record.key}` : ''} · 来源 ${record.source}${record.task ? ` · task ${record.task}` : ''}`,
    `${queued}${batch}`.replace(/^\n/, ''),
    '  正文（逐字，未截断）：',
    record.message,
    '',
  ].filter(line => line !== '').join('\n');
}

function renderResolve(result) {
  if (result.outcome === 'resolved') {
    return `已确认未知批次 ${result.batch}（${result.ids.length} 条：${result.ids.join(' ')}）：已关闭、不再重发，也不声称送达过\n`;
  }
  if (result.outcome === 'already-resolved') {
    return `批次 ${result.batch} 早已确认过（${result.ids.length} 条）；这次没有改动\n`;
  }
  return `team remind resolve：${result.reason}\n`;
}

function renderCancel(result) {
  if (result.outcome === 'cancelled') {
    return `已取消 ${result.reminder.id}（原 phase ${result.from}）· 到期时不会再响\n`;
  }
  if (result.outcome === 'already-cancelled') {
    return `已取消 ${result.reminder.id}：${result.reason}\n`;
  }
  const record = result.reminder;
  return `team remind cancel：${result.reason}${record ? `\n  ${record.id} · phase ${record.phase}` : ''}\n`;
}

export function renderRemind(op, result) {
  switch (op) {
    case 'remind-add': return renderAdd(result);
    case 'remind-list': return renderList(result);
    case 'remind-show': return renderShow(result);
    case 'remind-cancel': return renderCancel(result);
    case 'remind-resolve': return renderResolve(result);
    default: return JSON.stringify(result) + '\n';
  }
}
