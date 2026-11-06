# Reminders

A reminder is a durable one-shot note the project PM leaves for itself: "come back to this at that
time". It is stored in the same versioned project state as the rest of teamsmith, so it survives a
restart, a lost session and a new checkout, and it is the only copy of that decision.

This page is the operator's manual: recording, reading, cancelling, and what happens when a reminder
comes due.

## What this build does and does not do

- Records a reminder with its full text, its due instant, its source and an optional key and task.
- Lists what is waiting, when it is due, and whether it is due *now*; shows one record in full;
  cancels a reminder that has not been frozen into a batch.
- Queues a reminder when it comes due (the pulse's own ten-second due check) and delivers it — as one
  complete message, one batch at a time — into the verified PM session through the inbox watcher. The
  message is a Pi custom message: nothing is typed into the editor and a draft is never touched.
- Leaves Standby once, and only after the wake is actually observed. Being due, queued, frozen or
  refused does **not** leave Standby, and a newer Standby generation is never cleared by an older
  batch.
- Does **not** resend a batch whose delivery cannot be proven: it becomes `unknown` and waits for an
  operator (`team remind resolve <batch> --ack-unknown`).
- Does **not** accept a project, an owner or a recipient from the caller: those come from the
  checkout the command runs in and from the authority itself.
- Does **not** start a stopped PM for a reminder, and does not expose a PM model tool: the CLI is the
  way this build creates reminders, and a queued reminder waits for the session that comes back.

## Where the state lives

```
<main checkout>/.pi/team/reminder-locator.json      the pinned state root and the project identity
<main checkout>/.pi/team/reminder-locator.lock      serialises establishing that locator
<state root>/reminders/state.json                   the versioned snapshot: reminders, batches, audit
<state root>/reminders/authority.lock               serialises every state transaction
```

The state root is the project's own `<main checkout>/.pi/team/state` unless the project pins
`TEAM_STATE_DIR`; the first use pins it in the locator and every later process must agree with it.
Two processes with different `TMPDIR` values still meet on that one path. A different state root is
refused instead of silently creating a second authority.

Every read and write is one `flock` transaction: read and validate the snapshot, mutate it, write a
temporary file, `fsync` it, rename it into place, `fsync` the directory. A missing `flock`, a timeout,
an unreadable snapshot or an identity mismatch is a visible error; there is no unlocked fallback and
an unreadable snapshot is never replaced by an empty store.

## Commands

```bash
team remind add --after 20m --message "check the build"
team remind add --at 2026-10-28T09:00:00+08:00 --message-file note.md --key morning-review --task P409
team remind list
team remind list --all
team remind list --json
team remind show rem-<project id>-3
team remind cancel rem-<project id>-3
```

`list` prints a count line per view, then one block per active reminder: its stable id, its view, the
due instant with a relative distance, then the text exactly as stored. Ended reminders are kept but
printed only with `--all`; they are counted either way. `--json` on any of the four subcommands returns
the same snapshot the text is rendered from, for scripts.

`show` prints one record in full. A message is never shortened: `list` and `show` print the bytes that
were stored, and `--message-file` stores the file byte for byte (a trailing newline is part of the
text — the shell does not get to trim it).

## Time

Exactly one of the two forms:

- `--at` is an RFC 3339 date-time with an explicit offset (`2026-10-28T09:00:00+08:00`) or `Z`. A
  time without an offset, an impossible date such as `2026-02-30`, a leap second, a second that does
  not exist or an instant in the past is refused with the reason, and nothing is written.
- `--after` is a positive whole number followed by `s`, `m` or `h` (`90s`, `20m`, `2h`). Zero,
  negative, non-numeric and overflowing values are refused.

The relative form is resolved **once, inside the locked transaction**, and the resulting instant is
what the snapshot stores. Printing it is the record's due time, not a recomputation.

## Keys

`--key <name>` names one logical reminder. While a live record holds the key:

- the identical request (same time form and value, same text, same task) returns that record and its
  original due instant, and allocates nothing;
- a different request under the same key is refused, naming the record that holds it.

A key is held by `scheduled`, `queued`, `intent` and `unknown` records. Any terminal phase
(`observed`, `cancelled`, `resolved`) releases it, and the next request is a new reminder with a new
id — reuse after release is deliberately not an exactly-once guarantee.

## Views

The snapshot stores phases, never views. Every read derives the view from the phase, the due instant
and the clock:

| View | Meaning |
|---|---|
| `scheduled` | recorded, due in the future, not admitted for delivery |
| `derived-due` | recorded, due now or in the past, still not admitted — the clock alone says "due" |
| `queued` | delivery admitted with a queue identity and enqueue time |
| `intent` | frozen into a delivery batch, before the Pi call |
| `observed` | the correlated Pi message was seen; delivery is proven, nothing more |
| `unknown` | a batch was frozen and no correlated observation exists; never resent blindly |
| `cancelled` | withdrawn before delivery was frozen |
| `resolved` | an operator acknowledged an unknown batch |

`due` is not `queued`: a reminder can be overdue for a long time and still never have been sent.
All of these phases are produced by this build; the reader derives the view from the snapshot rather
than from a second copy, so a record written by any process shows up the same way in every reader.

## Delivery

The delivery path has four separate facts, and each one is durable before the next step:

1. **Due admission.** Both pulse shapes (the console and the headless tick loop) run a lightweight
   check about every ten seconds, apart from the full patrol. A due reminder is committed as `queued`
   with a queue order and its enqueue time; a repeated scan never creates a second queue entry. An
   item is marked `overdue` when its due instant predates the pulse instance that admitted it (a
   catch-up after a restart) or when admission lagged due by more than 30 seconds — an ordinary
   polling delay is not labelled overdue. A reminder still arriving 5 seconds late is normal; one
   that arrives 5 minutes late says so.
2. **One frozen batch.** The PM session's inbox watcher freezes at most eight queued reminders into
   one batch, records the intent — every member, the full text, the correlation nonce and the current
   Standby generation — and only then calls Pi. One batch is outstanding at a time; at most one
   submission per five seconds. Nothing is written into the editor and the input draft is untouched.
3. **Observation.** Pi's own `message_start` for that custom message, carrying the batch id and the
   nonce, is the only thing that counts as a wake. A return value, a thrown error, a deferred action
   or an unrelated run is not. The observation, the consumed right and the Standby exit commit in one
   atomic snapshot with an audit line naming the batch and every reminder id and source.
4. **Standby.** A reminder may wake a PM that is on standby (this is the one wake that Standby does
   not suppress). If the generation bound at intent is still the current one, the same observation
   transaction switches standby off — once per batch, never twice. If a newer generation exists, it
   is preserved and the outcome is reported as `generation-ambiguous`. If standby was already
   manually off, the audit says `already-off` rather than inventing an automatic exit.

If the session API refuses the message, the batch becomes `unknown` (visible in `team remind list`),
its members stop being independently sendable and nothing resends automatically: a call returning or
throwing is not a receipt. `team remind resolve <batch-id> --ack-unknown` is the operator's explicit
acknowledgment — it closes every member of that batch, burns its remaining right and reports the ids
without claiming delivery.

After a restart, `queued` reminders are still queued and are delivered by the next watcher; an intent
that never saw an observation past its 60-second deadline becomes `unknown` instead of being resent;
`observed` and `resolved` reminders are never queued again.

## Retention and the issued high-water

Ended reminders are history: the newest 1000 terminal outcomes within 30 days are kept, older ones are
compacted inside the same transaction that mutates. Active and unknown records are never evicted, and
the count of pruned outcomes is cumulative.

Ids are never reused. The snapshot carries the next sequence number, so a compaction, a restart or a
lost reply cannot hand out an id twice. Asking for an id that was issued and has since been compacted
answers `history-pruned`; an id above the issued high-water answers as never issued. Neither can be
revived or sent.

## When it refuses

- No `flock` on the machine, lock timeout, an unreadable or unsupported snapshot, or a snapshot whose
  identity contradicts the locator: the command fails with the reason and writes nothing. Repair the
  host or the snapshot; there is no unlocked mode to fall back to.
- `already-observed`, `in-flight` or `unknown` on `cancel`: the reminder is past the point where
  withdrawal can be guaranteed, and the command says so instead of pretending it was cancelled.
- A message that is empty, blank, contains a NUL byte or is not valid UTF-8: refused before anything
  is stored.

## Not in this build

The PM-only model tool, starting a stopped PM for a reminder (the prompt-free handoff), and the
configurable limits (active count, message bytes, create rate) are later tasks of the same change.
Until they land, the CLI is how a reminder is created and a queued reminder waits for a PM session
that is running.
