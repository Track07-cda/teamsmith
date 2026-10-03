# meeting-liveness · proposal

## Why

A peer PM's reports (CEP, 2026-09-11) sat unread 2.5 weeks: nothing in `team watch`/`status`/`digest` names a
meeting (D65). D64/D66: a knock that glues into a draft, one shared `PM_WINDOW` field serving both
directions, invisible and unclosable expiry, identity hanging on one spelling (`你不是参与方`), a late knock
indistinguishable from a fresh one.

## What Changes

- **A — discovery** (`watchdog`/`panel` MODIFIED, `meeting` ADDED): an unread peer turn joins the patrol's pending
  definition and reaches `status`/`digest`/the band.
- **B — closure** (`meeting` MODIFIED): expiry becomes the visible derived state `expired` (still read-only);
  `close --stale` closes exactly the expired meetings and refuses when nothing is stale.
- **③ — delivery safety** (`delivery-guard`/`notify-and-inbox` MODIFIED): the knock goes through the guarded
  sender; a busy peer box queues it and the command reports queued, not knocked.
- **④ — per-participant windows** (`meeting` ADDED): `PM_WINDOWS=<project>=<window>;…`; each side registers its own
  window; legacy `PM_WINDOW` still works.
- **R1 — identity** (`meeting` ADDED): a participant is recognized by any recorded name — project name,
  repository basename, or invited session; `state.env` records both.
- **R2 — stale-proof notices** (`meeting`/`notify-and-inbox` ADDED/MODIFIED): a knock carries
  `[meeting:<slug>#<N>]` and its ledger line lands at delivery (queued knocks included); a turn-end notification
  carries `task=<ID> tip=<12-hex>` — a fixed-width prefix both senders truncate themselves, on a task branch with
  evidence only; staleness is decidable from the receiver's ledger (read position; board/review HEAD), no checkout.
- **Backfill**: the read position behind "unread" is specified; MODIFIED blocks keep their base scenarios.

## Capabilities

### Modified Capabilities

- `watchdog`: pending gains the unread meeting turn.
- `meeting`: expiry + `close --stale`; read positions; participant windows; identity; knock turn id.
- `notify-and-inbox`: knock window/queue; revision stamp.
- `delivery-guard`: the guard and defer list gain the knock.
- `panel`: band gains the unread meeting count.

## Impact

`skills/teamsmith/scripts/lib/{cmd-meeting.sh,common.sh,cmd-status.sh,cmd-watch.sh}` and
`extension/team-notify.ts`, plus the smoke; no panel JS. Untouched: `read`/`inbox`/`propose`/`agree` semantics,
intent whitelist, `--as-user`, defaults.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
```

Apply adds FAST and the full smoke.

## What flips

- A: one unread peer turn → before, the tick only logs capacity; after, it nudges `未读会议 1`; removing the count
  restores silence.
- B: an expired meeting → before, `list` prints `open(过期)` and `close` is refused; after, `expired` + closable;
  `--stale` touches only expired.
- ③: a peer draft → before, `say --knock` glues; after, no key, one queued entry, delivered once when the box clears.
- ④: rows `alpha=pm;beta=pi` → each knock targets the other side's row; re-registering ours leaves theirs unchanged.
- R1: recorded `<peer>` vs basename `<peer-project>` → before "你不是参与方"; after read/say/inbox work; a third
  project is still refused.
- R2: a revision already reviewed (`reviews/P9.md` HEAD) → stale by comparison; without the stamp it is
  indistinguishable from new work.

## Boundaries

Non-goals: no write into the peer project; no `order`/`command` intent; no cross-machine or N-party meetings (D66
defers N-party). Apply must not touch `openspec/specs/**`; MODIFIED blocks keep every base scenario.

## Evidence the report must contain

Propose: validate tail, requirement map, MODIFIED before/after table, each red side, `check.sh` tail. Apply:
validate/FAST/full-smoke tails, each flip's red/green tail, queue-entry evidence, `PM_WINDOWS` and
participant-record before/after.
