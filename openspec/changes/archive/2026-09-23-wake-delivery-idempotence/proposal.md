# Propose: `wake-delivery-idempotence` — the wake reader records before it sends, and never twice

## Why

Three reports land on one contract: a delivered line must never wake the same session (or its successor)
again, and an operator must be able to tell from durable files whether a wake was new, recovered or a replay.

- **dev2** reported the PM's 14:09 line as a duplicate at 14:44:48. The ledger has exactly one send for it
  (`2026-09-22T14:09:56.190Z wake n=1 total=4 inbox=dev2 kinds=say`), `.seen` holds its id, and
  `docs/team/inbox/dev2.md:82` holds it once — the second presentation came from the session side, not from
  the watcher. But the same target's files do show the real hole: `.wake` has 9 lines and `.seen` has 8, and
  the missing one is the *oldest delivered* line (`1789810336525` at `09-19T09:32:16.682Z`) — the dedup
  memory is not a complete record of deliveries, and a rewrite inside the 900 s horizon would wake it again.
- **The PM** was woken by a "2-hour-old" nudge and then by "the same text" 10 minutes later, after a spool
  truncation whose rescan recorded `deliver=0`. `nudges.log` shows the truth: `16:13:56Z 未读通知 7 · 待复验 4`
  and `16:28:56Z 未读通知 7 · 待复验 4` are two *distinct* lines (ids `1790093637236` / `1790094537381`) with
  byte-identical text, each delivered exactly once (`total=85` / `86`), and the `16:43:56Z 9 · 4`
  (`1790095437514`) likewise (`total=89`). All three were queued as `followUp` while the PM ran a long turn and
  presented at later boundaries. The reader's offset did **not** fail to persist and `.seen` was consulted: no
  re-read after 16:43 produced any `wake` or `dedup:` line. What failed is that a wake carries no identity —
  neither the recipient nor the PM can tell "queued late" from "sent twice", and identical text makes it worse.
- **`total=1`** at `14:33:07.285 inbox=dev` is the dev watcher's first wake of its session; the line it woke
  about is the fresh `docs/team/inbox/dev.md:82` `[say]` line, and the neighbouring log lines belong to dev3's
  restart (one ledger, all targets). `total` is a per-session counter, so the line is not a mislabel and no
  spool was read from the head.

The deeper contract hole is structural: `wake()` writes the dedup memory and the ledger *before*
`pi.sendMessage`, whose failure is swallowed, and the reader's position is process memory only. So "delivered
but unrecorded" and "recorded but never accepted" are both reachable, and neither is visible from the files —
which is exactly why the PM could not answer "was it delivered?" either.

## What Changes

Three ADDED requirements and two MODIFIED ones in `notify-and-inbox`; nothing removed.

- **ADDED — A wake is at most once: the delivery record is written before the send and survives a restart.**
  The watcher keeps an append-only delivery journal (`state/inbox-watch/<key>.deliver`), written in the order
  `read` → `intent` → send → `sent`/`failed`; no send without its `intent`; an unwritable journal means no wake
  (`deliver blocked`) and the lines stay unseen. After a restart the state is read from the journal: `read`
  without `intent` is recovered **once** (`recovery`), `intent` without `sent`/`failed` (a torn tail included)
  is `inflight assumed` and never re-sent, `sent` is never re-sent, `failed` is retried at most once per tick
  and never after the stale horizon, and an identity below the compaction floor is `unprovable`.
- **ADDED — A wake names its source line so a recipient can prove what it is.** The wake text carries a
  monotonic `#<seq>`, its absolute send time, and per line the source line's absolute timestamp and identity;
  the sender writes the id of its own durable record (the outbox entry name in
  `state/outbox/delivered.log`) into the spool line. Two byte-identical payloads from two lines become
  distinguishable; a repeated identity is a provable replay.
- **ADDED — The delivery journal is the only dedup memory, and it is bounded and auditable.** One ISO-stamped
  record per line, a torn tail treated as unknown (never as a licence to re-send), compaction under
  `TEAM_INBOX_WATCH_JOURNAL_MAX` (default 1024) recording its `floor=`, and `<key>.seen` retired after a
  one-time additive import (deleting or corrupting it afterwards changes no decision).
- **MODIFIED — Only fresh lines wake the session; stale lines stay silent and countable.** The path list gains
  the journal's recovery path, with a scenario proving a recovered-but-stale line is counted, not woken.
- **MODIFIED — The ledger separates new traffic from recovery.** The named counters grow: `replay suppressed
  n= reason=<normal|rescan>`, `inflight assumed n=`, `recovery n=`, `unprovable n=`, `deliver blocked`,
  `torn tail`, `baseline swallowed n=`; every wake line names its `seq=` and the identities it carries, so a
  wake can be matched to the inbox line and to the sender's delivered log.

## Capabilities

### Modified Capabilities

- `notify-and-inbox` — three ADDED requirements and two MODIFIED ones. The modified two are the base
  requirements `Only fresh lines wake the session; stale lines stay silent and countable` and `The ledger
  separates new traffic from recovery`; both are restated in full in the delta. No other open change touches
  either requirement (the only other open `notify-and-inbox` delta, `one-line-draft-judgement`, modifies
  `Messages to a stopped agent fall back to the inbox`), so composition is clean.

## Impact

- `skills/teamsmith/extension/team-inbox-watch.ts` — the journal, the three-state restart judgment, recovery,
  compaction, the wake text, the ledger counters (replaces the `.seen` write path).
- `skills/teamsmith/scripts/lib/outbox.sh` — one field appended to the spool line at `1137` (the sender record
  id), no other sender change.
- `skills/teamsmith/tests/team-inbox-watch-harness.mjs` (child-process crash runner, S25a–S25f, S26, S11/S13
  assertions moved to the journal), `tests/smoke.sh` (the 12b-pi section titles/pins), new
  `tests/flip-p71.sh`.
- `skills/teamsmith/references/{agent-adapters,troubleshooting}.md` — the state-file and ledger docs
  (`<key>.seen` → `<key>.deliver`, the new counters, the one-way migration).

## Acceptance

This propose (run now):

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
git status --porcelain
```

The apply's acceptance (planned, not runnable yet):

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_INBOX_WATCH_HARNESS=1 node --experimental-strip-types skills/teamsmith/tests/team-inbox-watch-harness.mjs \
  skills/teamsmith/extension/team-inbox-watch.ts
bash skills/teamsmith/tests/flip-p71.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null
```

## The flip

Red before (today's tree): S25a's kill-after-read case sends **twice** (no write-ahead record) or loses the
wake; S25b's kill-after-intent case cannot even be expressed (no `intent`); S25d's two identical-text lines
produce indistinguishable texts; S25e shows a stale `.seen` as the only, incomplete memory; S25f's incident
replay has no journal to consult. Green after: each case passes with its ledger line, and breaking the
`intent` write, the three-state read, the identity in the text, or the `floor` rule reds its case
(`flip-p71.sh` carries the four break-it mutations).

## Boundaries

Propose only: this phase writes `openspec/changes/wake-delivery-idempotence/**` and the report, nothing under
`skills/**`. The apply needs explicit grants for `skills/teamsmith/extension/**`,
`skills/teamsmith/scripts/lib/outbox.sh`, `skills/teamsmith/references/**` and (already `agent:dev`'s)
`skills/teamsmith/tests/**`. Out of scope: the `deliverAs` mode and the session-side queue (no ack API), the
pulse's re-nudge cadence, the outbox entry format, `.reg`/`.skip`/`.degraded`, the inbox/digest read paths,
and every other spec.

## Evidence the report must contain

The requirement→item map and the scenario→item→evidence map; the incident replay with the real ids and the
expected classifications; each fixture's red-before/green-after tail including the four break-it mutations;
the `openspec validate --all --strict` and gate tails; and the refutation of the two wrong inferences
(offset-not-persisted, `total=1` = head read) quoted from the ledger lines above.
