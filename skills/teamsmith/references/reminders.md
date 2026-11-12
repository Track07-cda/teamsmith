# Reminders

A Reminder is a durable one-shot note the project PM leaves for itself. The project state, not a model
session or a timer process, decides when it is due, whether it was sent and what remains uncertain.

This page covers the CLI, the PM-only tool, delivery, stopped-PM recovery and operator recovery.

## Create and inspect

```bash
team remind add --after 20m --message "check the build"
team remind add --at 2026-10-28T09:00:00+08:00 --message-file note.md --key morning-review --task P443
team remind list
team remind list --all
team remind show rem-<project id>-3
team remind cancel rem-<project id>-3
```

The verified PM also has the `team_remind` model tool with `add/list/show/cancel`. It uses the same
state authority and records `source=pm-tool`; CLI-created records record `source=cli`. The tool is not
injected into workers or `/team`. A switch, fork, reload or stale identity hides it immediately, and
`team doctor` no longer reports the previous registration as ready. Missing evidence is `unknown`, not
proof that the extension failed to load.

There are no Reminder rate, active-count, message-size, batch-size or spacing quotas and no Reminder
configuration keys. Input is still checked: exactly one future time, nonempty valid UTF-8 text without
NUL, and a valid optional key/task. Text is never truncated. `--message-file` preserves trailing
newlines. With `--json`, stdin decoding and NUL refusals are JSON objects with
`{ok:false, refusal:"bad-message", reason:"…"}` and a nonzero exit status.

`--at` requires RFC 3339 with `Z` or an explicit offset. `--after` is a positive integer plus `s`, `m`
or `h`; one second is valid. A relative deadline is computed once inside the locked create transaction.

## Keys and repeated one-shots

`--key <name>` deduplicates only the active request. An identical retry returns the original ID and its
first persisted due time. A different request under that key is refused. `scheduled`, `queued`,
`intent` and `unknown` hold the key; `observed`, `cancelled` and `resolved` release it.

Periodic work is a sequence of one-shot Reminders, not a recurring scheduler: after one wake is
observed, create the next one-shot with the same key. It receives a new monotone ID. Do not infer a
period from the old record or retry a terminal creation expecting global idempotency.

## Due is not queued, and queued is not a wake

The views are `scheduled`, `derived-due`, `queued`, `intent`, `observed`, `unknown`, `cancelled` and
`resolved`. `derived-due` means the clock reached the due instant; it does not prove that Pulse was
running or admitted the item. `queued` has a durable queue order and enqueue time. `intent` means one
whole batch was frozen before a Pi call. Only a correlated Pi `message_start` is an observed wake; a
process start, API return, queue entry, deferred action or model completion is not.

Both Pulse shapes run the lightweight due check about every ten seconds without increasing the full
patrol frequency. A long patrol does not stop admission. There is at most one full patrol and one
Reminder recovery decision; due items arriving during either are coalesced into one recovery recheck
after it ends. Pulse reaps its patrol/recovery children on shutdown.

In normal conditions (Pulse alive, healthy clock/storage/lock and responsive OS scheduling), durable
admission targets 30 seconds after due. An item due before this Pulse instance started, or admitted
more than 30 seconds late, is marked `overdue`. This target says nothing about Pi start time, model
latency or work completion. Pulse stopped or a failed lock is visible failure, not a passing timing
measurement.

## Delivery and Standby

The PM inbox watcher freezes all currently queued Reminders into one full-text batch. There is no
member cap and no post-outcome spacing timer. One batch remains outstanding until observation or an
explicit unknown acknowledgment. The watcher sends one Pi custom follow-up message; it does not type
into the editor or disturb a draft.

The batch intent binds the current Standby generation before the Pi call. Observation, the consumed
batch right, the Standby result and the audit commit atomically:

- the same bound generation still current: switch it off once as `auto-off`;
- already manually off: record `already-off`;
- a newer generation whose ordering cannot be proven: preserve it as `generation-ambiguous`.

An ordinary pending nudge is a different mechanism and does not count as a Reminder wake. Ordinary
Outbox drain and an explicitly directed `--now` keep their independent authorization.

## A stopped PM: Reminder-only recovery

An eligible queued Reminder can recover the stopped built-in Pi PM while Standby is on. Recovery uses
the existing PM identity, continuity, `starting`, window ownership, capacity evidence and restart
quota. It starts or resumes Pi with the usual resume arguments and PM extensions, but **without**
`@pm-prompt` or any replacement initial user/model prompt. The watcher starts with the process and
delivers the queued Reminder through the normal direct path.

Before the correlated observation and a permitted Standby result, ordinary startup work and ordinary
inbox recovery remain suppressed. Starting, queueing or a failed/lost send does not switch Standby
off. A newer ambiguous Standby generation remains on. After a valid observation, ordinary work
resumes under the existing rules; startup-age backlog still follows the watcher's baseline rules.

Recovery has explicit outcomes instead of a success message for every path:

- running/busy PM: no second process and no ordinary nudge; a busy PM receives only the later
  correlated follow-up;
- `starting`: wait, do not respawn or consume another restart slot;
- missing window/session: report it; do not rebuild tmux unless the existing rebuild policy allows it;
- restart quota, identity/continuity or foreign-window refusal: no launch;
- missing required extension: no launch;
- custom PM adapter: `unsupported-adapter`; the prompt-free Pi watcher contract is not claimed;
- launch failure, send failure or lost outcome: no success claim, no blind resend and no Standby off.

`result=started` means launch proof was obtained, not that the Reminder was observed. Only the later
correlated event changes the batch to `observed`.

## Unknown outcomes and operator resolution

A synchronous send failure, process death after intent, or 60 seconds without a correlated observation
makes the batch `unknown`. It is never automatically resent, and it blocks the next batch until a late
valid observation or an explicit operator acknowledgment. Creating new Reminders is still allowed.

Inspect the whole batch, then run:

```bash
team remind resolve <batch-id> --ack-unknown
```

This closes every member as `resolved`, burns the batch's remaining automatic-off right and returns
the member IDs. It does not claim that delivery happened or did not happen and does not resend. A late
event cannot reopen the batch or clear a newer Standby generation. To arrange another reminder, create
a new ID.

## State, locking and retention

```text
<main checkout>/.pi/team/reminder-locator.json      pinned state root and project identity
<main checkout>/.pi/team/reminder-locator.lock      serializes locator establishment
<state root>/reminders/state.json                   reminders, batches, Standby and audit
<state root>/reminders/authority.lock               one cross-process transaction lock
```

Every mutation uses `flock`: read and validate the snapshot, mutate briefly, write a same-directory
temporary file, `fsync` it, rename and `fsync` the directory. Pi/model calls and patrols never run under
this lock. Different `TMPDIR` values still use the canonical project lock. Missing `flock`, lock
timeout, corrupt/unsupported state or a state-root mismatch is a visible error with no unlocked
fallback and no partial snapshot replacement.

Terminal reminders and batches retain at most the newest 1000 outcomes or 30 days. Active/unknown
records and every unspent batch right are never evicted. A retained batch keeps all its members. IDs
and the issued high-water are never reused; an absent issued ID reports `history-pruned`. A late event
for retained unknown history can still be observed once. A late event for a pruned ID is reported and
ignored: it cannot synthesize a Reminder, recreate a batch, spend another right or authorize a resend.

## Upgrade and rollback

1. Quiesce the old PM, Pulse and other writers. Old code that writes the legacy Standby marker must not
   run beside the new authority.
2. Back up the runtime state, verify `flock` and the JS runtime, and confirm the intended canonical
   state root before starting the new writers. The legacy Standby marker migrates once under the lock
   with its reason and generation preserved. `flock` is required for Standby even when the project has
   no Reminders; `team paths` exposes the exact `flock_runner` used by transactions.
3. A missing executable reports `flock unavailable: no executable flock on PATH`; an unusable one names
   its path. An OS locking failure reports `exclusive flock failed at <lock>` and the filesystem repair.
   `team doctor` fails in all three cases and gives the corresponding repair. There is no unlocked
   mutation or requirement switch that bypasses the dependency.
4. Before rollback, quiesce the new writers, inspect and resolve outstanding intents and export
   `reminders/state.json`. Restore the legacy Standby marker from the authoritative generation/reason
   and keep the Reminder snapshot outside the old code's path. The exact `cp` / `node -e` export,
   recovery check, migration-failure states and restart order are in [migration.md §9](migration.md#9-reminder-state-and-prompt-free-recovery);
   there is no separate export or automatic rollback command.
5. Old binaries cannot interpret or deliver outstanding Reminders. Rollback suspends them; it does not
   auto-replay them. Verify the backup, marker and stopped processes before resuming old code.

`team doctor` checks the lock dependency and PM-tool evidence. There is no scheduler daemon, separate
Reminder outbox, TUI scheduler or model-autonomy guarantee in this design.
