## MODIFIED Requirements

### Requirement: A wake is at most once: the delivery record is written before the send and survives a restart

The inbox watcher SHALL keep, per target, an append-only delivery journal
(`state/inbox-watch/<key>.deliver`) and SHALL treat it — never process memory — as the durable authority for
what may still be woken about. The journal SHALL record each session start (`start`, carrying the baseline
offset, the observed size and the head fingerprint) and, for every line the reader decides to wake about, in
this order:

- before it calls the session's message API it MUST have appended a `read` record naming the line's identity
  and the wake material it will carry (kind, from, durable inbox, preview) together with the byte offset the
  read consumed to, the observed size and the head fingerprint, and then an `intent` record for the batch;
- after the call returns it MUST append `sent`, or `failed` when the call raised or the session API refused
  the message.

A wake MUST NOT be sent unless its `intent` record was appended successfully. When the journal cannot be
appended to, the reader MUST NOT send anything, MUST record `deliver blocked` in the ledger, and MUST leave
the lines unseen so that a later tick can pick them up. The persisted offsets are the audit trail of where a
session's reader stood; this requirement does not change the session's own baseline, which stays the current
spool end as `notify-and-inbox#The wake reader's offset advances by the bytes it read, never past the file end`
defines it.

After a restart a line's identity MUST be judged from the journal, in exactly these three states:

- `read` without `intent` (the send never started): the line MAY be woken about exactly once by a later
  session, out of the wake material the `read` record already holds, and the wake MUST be recorded as
  `recovery`;
- `intent` without `sent` and without `failed` (the outcome is unknown, and a torn or unparsable trailing
  record MUST be read as this state): the line MUST NOT be woken about again; the reader MUST record
  `inflight assumed n=<n>` once and MUST treat it as delivered from then on;
- `sent`: the line MUST NOT be woken about again, ever.

A `failed` record means the message never entered the session: that line MAY be retried, at most once per
read tick and never after it has passed the freshness horizon of the requirement
`notify-and-inbox#Only fresh lines wake the session; stale lines stay silent and countable`. An identity older
than the journal's eviction floor MUST NOT be woken about again — the journal can no longer prove it was not
delivered — and MUST be counted as `unprovable`.


This requirement governs ordinary inbox-spool wakes. A PM self-Reminder uses the separate authority and direct custom-message contract in `agent-self-reminder`, not a second spool or this journal; its Pi call return and ambiguous failure SHALL NOT be treated as a receipt or safe retry.

#### Scenario: Killed after the read, before the intent — one recovery, never two

- **GIVEN** a fixture that kills the watcher process (SIGKILL, a separate process) after it appended the
  `read` record for a fresh line and before any `intent` record
- **WHEN** a new session starts for the same target
- **THEN** exactly one wake is sent for that line, the ledger records it as `recovery`, and a later rewrite
  of the same bytes produces no second wake

#### Scenario: Killed after the intent, before the send — never sent twice

- **GIVEN** the same fixture killed after the `intent` record for a fresh line, with the durable inbox line
  already written by the sender
- **WHEN** a new session starts
- **THEN** no wake is sent, the ledger records `inflight assumed n=1`, the line's durable inbox line is still
  readable, and any later re-read of the line stays silent

#### Scenario: A send that raises is visible and retryable, and a journal that cannot be written blocks the wake

- **GIVEN** a session whose message API raises for one batch, and separately a session whose journal
  directory is not writable
- **WHEN** the reader flushes a fresh line in each case
- **THEN** the first case records `wake failed`, does not mark the line delivered, and retries it on the next
  tick exactly once (`total=` does not move before the retry succeeds); the second case sends nothing,
  records `deliver blocked`, and delivers the line exactly once when the journal becomes writable again

#### Scenario: A rewrite of journaled lines is suppressed and named

- **GIVEN** a spool whose earlier lines all have `sent` records in the journal, truncated and rewritten with
  the same bytes
- **WHEN** the bounded rescan runs
- **THEN** no wake is sent, the ledger records `replay suppressed n=<n> reason=rescan`, and the last `total=`
  is unchanged

#### Scenario: An identity below the eviction floor is not woken again

- **GIVEN** a journal that has been compacted, its `floor=` older than a line that comes back through an
  external rewrite
- **WHEN** the rescan reads that line
- **THEN** no wake is sent and the ledger counts it as `unprovable`

### Requirement: A wake names its source line so a recipient can prove what it is

Every ordinary inbox-spool wake SHALL carry, in its text: a monotonically increasing wake sequence number and the absolute send
time of the wake; and for each line it lists, that line's own absolute timestamp and its identity. When the
line carries a sender record id, the identity shown MUST be that id; otherwise it MUST be the same string the
delivery journal uses for that line. The sender SHALL write that id into the spool line (the id of its own
durable record for the message, i.e. the outbox entry name recorded in `state/outbox/delivered.log`).

Timestamps MUST be absolute (ISO-8601 UTC) and MUST NOT be relative ages, and the preview MUST stay bounded,
folded to one line per listed line, and MUST NOT carry the payload dump. The wake text MUST name the delivery
journal file the listed identities were recorded in, so the recipient can resolve an identity without guessing
which state file holds it. The purpose is that a recipient can
decide from durable files alone whether two wake texts are two lines or one line twice: two byte-identical
payloads from two distinct lines MUST be distinguishable by identity and source time, and a wake text that
repeats an identity is a replay the recipient can name.


A direct PM self-Reminder is not a spool preview: its full text, IDs, scheduled and actual timestamps, source and overdue indication follow `agent-self-reminder` and SHALL NOT be clipped to this preview.

#### Scenario: Identical text, two lines — distinguishable, and neither replayed

- **GIVEN** two spool lines whose payload text is byte-identical (the pulse's `未读通知 N · 待复验 M` nudge
  is written every `TEAM_PULSE_NUDGE_GAP` with unchanged counts, so this is the production shape) and whose
  ids and timestamps differ
- **WHEN** both are woken about and then one of them is rewritten into the spool
- **THEN** the two wake texts differ by the identity and the source timestamp they print, and the rewrite
  produces no wake at all

#### Scenario: The identity cross-references the sender's own record

- **GIVEN** a line delivered by the real CLI on the pi route
- **WHEN** the wake text's id is looked up in `state/outbox/delivered.log`
- **THEN** exactly one record for that message carries that id, and the spool line for it names the durable
  inbox line the recipient can read

### Requirement: The delivery journal is the only dedup memory, and it is bounded and auditable

The journal SHALL be human-auditable: one record per line, each ISO-stamped, carrying its record kind
(`start`, `read`, `intent`, `sent`, `failed`, `floor`), the line identity and the fields above. A torn or
unparsable trailing record MUST be treated as an unknown outcome (never as a licence to re-send) and MUST be
visible in the ledger as `torn tail`.

The journal MUST be bounded: past `TEAM_INBOX_WATCH_JOURNAL_MAX` records (default 1024) compaction SHALL
rewrite it under the bound and SHALL record its eviction floor (`floor=<oldest retained identity>`). A
compaction MUST NOT be able to resurrect a delivery, and the records it keeps MUST keep their state.

`state/inbox-watch/<key>.seen` SHALL be retired as the dedup memory. On the first start of a target it MAY be
imported once, additively, as already-delivered identities so that an upgrade does not replay; from then on
the journal MUST be the only memory, and deleting, emptying or corrupting `<key>.seen` MUST NOT change a
single delivery decision.


This journal is the only dedup memory for ordinary inbox-spool lines. A PM self-Reminder's separate authoritative batch intent is never imported into it and this journal cannot authorize a Reminder resend.

#### Scenario: An upgrade imports `.seen` once, and then `.seen` stops mattering

- **GIVEN** a target whose state holds a `<key>.seen` written by the previous code and no journal
- **WHEN** a session starts and an already-delivered line is rewritten into the spool
- **THEN** no wake is sent, the journal records the import, and after `<key>.seen` is deleted the same
  rewrite is still silent

#### Scenario: A torn tail is an unknown outcome, not evidence of "not sent"

- **GIVEN** a journal whose last record is cut mid-line (a crash while appending the `intent`)
- **WHEN** a new session starts and the line comes back through a rewrite
- **THEN** no wake is sent, the ledger names the `torn tail`, and the line is treated as delivered from then
  on

#### Scenario: Compaction stays under the bound and keeps every retained delivery

- **GIVEN** a journal that has grown past `TEAM_INBOX_WATCH_JOURNAL_MAX`
- **WHEN** compaction runs
- **THEN** the file is at or under the bound, one `floor=` line names the oldest retained identity, and every
  retained identity is still suppressed on a rewrite
