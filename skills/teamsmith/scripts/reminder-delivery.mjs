// reminder-delivery.mjs — the presentation and match half of the Reminder wake (P423 · agent-self-reminder
// 3.1/3.2). The delivery *decisions* (admission, the frozen batch, observation, unknown, resolve) live in
// remind-store.mjs inside the authority transaction; this file only answers two questions, both pure:
//
//   reminderContent(batch)  what exact text goes into the session (full text per Reminder, never clipped)
//   matchesObservation(message, batch)  is this the event that proves *our* message entered the run
//
// The caller (the PM's inbox watcher) writes the intent, then calls pi.sendMessage with this content and
// these details, then reports the matching `message_start` back to the transaction. A return value, a
// thrown error or a deferred action never becomes success on its own: only the correlated event does.

export const REMINDER_CUSTOM_TYPE = 'team-reminder';

const oneLine = (text, limit) => String(text).replace(/\s*\n\s*/g, ' ').slice(0, limit);

function attributes(member) {
  const parts = [`source ${member.source ?? 'cli'}`];
  if (member.task) parts.push(`task ${member.task}`);
  if (member.key) parts.push(`key ${member.key}`);
  return parts.join(' · ');
}

/** The complete batch as one message. Nothing is shortened; ids and times are the durable record's. */
export function reminderContent(batch) {
  const attempted = batch.attemptedAt ?? batch.intentAt ?? new Date().toISOString();
  const head = [
    `[teamsmith reminder] ${batch.id} · ${batch.members.length} reminder${batch.members.length === 1 ? '' : 's'}`,
    `Nonce: ${batch.nonce}`,
  ];
  const bodies = batch.members.map(member => [
    `ID: ${member.id}`,
    `Due: ${member.dueAt}`,
    `Enqueued: ${member.enqueuedAt ?? '-'}${member.overdue ? ' (overdue: the patrol queued it late)' : ''}`,
    `Attempted: ${attempted}`,
    `From: ${attributes(member)}`,
    '',
    member.message,
  ].join('\n'));
  return `${head.join('\n')}\n\n${bodies.join('\n\n---\n\n')}\n\n---\n` +
    'This message is a scheduled reminder this project\'s PM created earlier. The project and task state may have ' +
    'changed since it was scheduled: check the current state before you continue.\n';
}

/** The machine-side identity of the same message: what the observation must match, never model-visible. */
export function reminderDetails(batch) {
  return {
    batchId: batch.id,
    nonce: batch.nonce,
    members: batch.members.map(member => member.id),
    generation: batch.generation,
  };
}

/**
 * True only for the public `message_start` of THIS batch's custom message: same custom type, same batch id,
 * same nonce, same member set. A same-named message from another sender, an assistant/user message or a
 * batch whose details are absent is not an observation.
 */
export function matchesObservation(message, batch) {
  if (!message || typeof message !== 'object') return false;
  if (message.role !== 'custom' || message.customType !== REMINDER_CUSTOM_TYPE) return false;
  const details = message.details;
  if (!details || typeof details !== 'object') return false;
  if (details.batchId !== batch.id || details.nonce !== batch.nonce) return false;
  if (!Array.isArray(details.members)) return false;
  const expected = batch.members.map(member => (typeof member === 'string' ? member : member.id));
  if (details.members.length !== expected.length) return false;
  return expected.every((id, index) => details.members[index] === id);
}

/** One bounded log line for the watcher's ledger: what was decided, never the reminder text. */
export function deliveryLogLine(batch, outcome) {
  const ids = batch.members.map(member => (typeof member === 'string' ? member : member.id));
  return `reminder ${outcome} batch=${batch.id} n=${ids.length} ids=${ids.join('|')} ` +
    `generation=${batch.generation} attempted=${oneLine(batch.attemptedAt ?? batch.intentAt ?? '-', 40)}`;
}
