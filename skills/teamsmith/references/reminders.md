# Reminders

A reminder is a durable one-shot note the project PM leaves for itself: "come back to this at that
time". It is stored in the same versioned project state as the rest of teamsmith, so it survives a
restart, a lost session and a new checkout, and it is the only copy of that decision.

This page is the operator's manual for the part that exists today: recording, reading and cancelling
a reminder. It does not describe delivery, because this build does not deliver.

## What this build does and does not do

- Records a reminder with its full text, its due instant, its source and an optional key and task.
- Lists what is waiting, when it is due, and whether it is due *now*; shows one record in full;
  cancels a reminder that has not been frozen for delivery.
- Does **not** wake the PM, does not queue anything for delivery, and does not touch Standby. A due
  reminder is shown as `derived-due` and stays there until the delivery part of the change reads it.
- Does **not** accept a project, an owner or a recipient from the caller: those come from the
  checkout the command runs in and from the authority itself.

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

`due` is not `queued`: a reminder can be overdue for a long time and still never have been sent. This
build produces only `scheduled`, `cancelled` and, from the clock, `derived-due`; the other phases are
written by the delivery and Pulse tasks of the same change, and this reader already shows them
because it derives from the snapshot rather than from a second copy.

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

Pulse admission, the PM wake-up and its message, Standby interaction, the configurable limits (active
count, message bytes, create rate) and the PM-only tool are later tasks of the same change. Until
they land, a reminder is a durable note that a person reads — it does not summon anyone.
