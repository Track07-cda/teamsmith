## Context

See `proposal.md` for motivation. Source references below are bound to base revision `f07d6c1c`.

| Path and lines | Observed mechanism |
| --- | --- |
| `scripts/lib/common.sh:3074–3097` | Eight counts: inbox, reports, todo, wip, review, blocked, stopped, meetings. With pending-board disabled, todo/wip/review become zero; blocked is retained. |
| `scripts/lib/common.sh:3099–3125` | Independent count-bearing text, including stopped-seat classification prose. |
| `scripts/lib/common.sh:3127`, `:1202` | `team_pending_sig` hashes the count vector with `cksum`; **it does not hash the reminder text**. Any changed count changes the current key. |
| `scripts/lib/cmd-watch.sh:328–332`, `:360–377` | The tick gets counts once, computes text/signature, compares signature with `_watch.env:nudge_sig`, OR checks elapsed gap; a permitted attempt updates nudge time and signature. |
| `scripts/lib/cmd-watch.sh:334–358` | Standby/no-work return before the running-PM branch. No-work updates only `last_sig`; it leaves `nudge_sig`/`nudge_epoch` intact. |
| `scripts/lib/common.sh:3144–3158` | `team_nudge` unconditionally appends current text to `nudges.log` and writes `watchdog.nudge`, then attempts guarded delivery only if PM is alive. Thus a log line records a reminder **attempt**, not confirmed receipt; queued/held outcomes are unchanged. `watchdog.nudge` currently rescans counts for its signature. |
| `scripts/lib/cmd-watch.sh:762–777` | Pending JSON uses actual counts, sum and count-bearing text, not reminder history. |

All paths in the table are under `skills/teamsmith/`. The patrol log's `last_sig` serves observation/log deduplication;
`nudge_sig` serves reminder deduplication. Conflating them would remove count-bearing backlog changes from logs.

## Goals / Non-Goals

**Goals:** implement the watchdog delta without coupling counts, human text and wake identity; retain the panel
contract and every copied baseline scenario. The pure comparison probe can run without a model or tmux process.

**Non-Goals:** no per-message identity, per-category clocks, new scheduler, setting or daemon. Do not infer
unobserved empty intervals between ticks. Do not rate-limit dedicated meeting/death notifications or already
queued messages with this key. The gap continues to govern reminder attempts, not confirmed delivery; changing
that contract would require a separate delivery change.

## Decisions

### 1. A separate, canonical category key; counts stay intact

Add a pure `team_pending_nudge_key` helper alongside `team_pending_sig`. It consumes the tick's already policy-filtered
snapshot in the established eight-field order and serializes positive category names in that order, with an explicit
version prefix such as `pending:v1:inbox,reports` (empty: `pending:v1:none`). Missing legacy eighth field means zero.
It excludes all numeric magnitudes and stopped-seat prose. A namespaced literal is small, explainable and avoids
hash collisions. Do not overwrite the count vector or put booleans in pending JSON.

Retain the existing count signature for `last_sig` and count-sensitive logging. Use the new key only for running-PM
reminder comparisons against `nudge_sig`. Allow `team_nudge` to receive that same precomputed key as an optional
second argument; its single-argument compatibility path may compute the category key. `watchdog.nudge` and
`_watch.env:nudge_sig` then describe the same snapshot without a second scan. The key's literal bytes are internal,
not a public JSON contract.

Alternatives rejected: normalizing the human reminder text (language/prose dependence); a longer gap (does not
repair count-dependent bypass); a constant key or one global unconditional timer (suppresses new categories);
per-category timers (extra state, does not implement set transitions).

### 2. Clear reminder history on observed empty work, before standby returns

After calculating the snapshot, an all-zero category set clears the reminder signature/time. Do this before the
standby early return so emptiness under standby rearms without sending anything. Leave nonempty standby ticks'
reminder history unchanged: standby does not consume a reminder slot. The subsequent no-work path still logs its
existing conclusion and never starts a PM. Suppressed nonempty ticks do not write `nudge_epoch` or `nudge_sig`.

For the existing running-PM branch, the decision is: changed category key OR elapsed time >= gap. Both addition
and removal qualify. All existing PM-state and restart-quota branches stay untouched.

Alternatives rejected: merely setting `last_sig` on emptiness (the actual baseline bug); rearming on every standby
toggle (unrelated to an observed empty batch); refreshing the epoch on every suppressed tick (continuous count
traffic could postpone the next reminder forever).

### 3. Preserve observers, with focused falsifiable tests

No panel renderer/bundle change is needed. Use existing current-snapshot readers and assert that a suppressed tick
still permits an observer to show four unread notifications. Fingerprint state contents and timestamps across
reads. Test every signal position for count-only noise, additions/removals, gap-1/gap, normal/standby empty rearming,
empty/no-PM silence and legacy seven-field text. Verify pending-board policy with actual count readers in the apply
fixture rather than treating the probe's prefiltered vector as policy evidence.

The P172 evidence package sources real key/text/nudge/tick/state/pending-JSON functions. Only scanning, capacity,
PM liveness/start and guarded-send boundaries are stubbed; it records submitted payloads. It deliberately contains
no candidate fix. A constant-key in-memory mutation must break immediate category wakes; a frozen panel mutation
must break the count assertion. Actual draft/queue behavior remains the existing delivery gate's responsibility.
Focused CLI observer fixtures and the existing smoke suite supply the integration layer; all tmux-touching tests
stay inside disposable containers.

## Risks / Trade-offs

- [A count/key refactor drops meetings or opt-in board signals] → fixed eight-field order, seven-field compatibility,
  every-position probes, and apply-side policy checks including `review`; no pending-classification rewrite.
- [A category is added and removed while standby prevents reminders] → after standby, compare the current set with
  the last reminded set. Unobserved intermediate sets do not create historical catch-up messages.
- [Dedicated death/meeting messages still arrive inside the gap] → they are separately justified notifications;
  this fix governs the ordinary pulse reminder only, not all notification traffic.
- [Two processes tick concurrently] → do not add locking here; retain the existing single patrol-loop invariant.
- [Active `meeting-liveness` also modifies the panel status-band requirement] → leave its files untouched. Before
  archiving the second change, PM must compose its meeting additions and this current-count paragraph/scenario so
  neither whole-block MODIFIED delta overwrites the other's promises. The watchdog blocks do not overlap.
- [Synthetic boundaries hide transport failures] → label probe results as policy evidence; require the isolated
  full gate and independent verification, never a model-delivery claim.

## Migration Plan

No operator config edit: default 900, effective configured 3600 in the reported incident, and legacy variable
precedence remain unchanged. A previous numeric `nudge_sig` cannot equal the namespaced category key; the first
eligible nonempty tick therefore generates one fresh reminder and writes the new form. Preserve state filenames,
logs and outbox entries. Verify this using an old signature and a recent epoch in a fixture; do not reset real
project state. The existing code-fingerprint reload mechanism picks up changed library code without manipulating
the shared pulse window.

Rollback restores the previous library behavior; a different signature representation can cause one extra reminder,
not permanent suppression. Do not delete reminder history or queue entries. Archive follows independent verification
and user/PM-recorded confirmation, with the panel sibling-delta composition checked on a disposable spec copy.
