# Propose: `gate-hygiene` — the review timeout covers the run, not the queue; timing assertions carry a load premise

## Why

Two false reds in one verification round (M49, 2026-09-20). `team review`'s hard timeout covered
**930 s of waiting for the smoke lock plus the gate run**, and killed a healthy gate at 28-i; the same
tick judged 27-d's first-frame median of **4942 ms** against the 2000 ms red line while the machine ran
**loadavg 26–32** (four agents) — and the identical tree passed after the machine quieted
(`docs/team/reviews/M49.md`). Both are measurement errors, not code failures, and each one costs a
re-verification round.

The user decided (2026-09-20): the hard timeout must exclude the queue — and no queue-jumping — and
time-sensitive assertions must carry a **load premise**: a visible SKIP with the recorded load when the
machine is busy, the unchanged red line when it is quiet.

## What Changes

- **ADDED** — `verification`: `team review` serializes the gate run on the shared gate lock **before** the
  hard-timeout clock starts; queue time is accounted separately (`queued Ns / ran Ns / limit Ns`), a queue
  over `TEAM_SMOKE_LOCK_WAIT` fails loudly naming the holder (never `TIMEOUT`), and the record distinguishes
  `PASS` / `FAIL` / `TIMEOUT(ran=…)`; queue time never participates in the verdict.
- **MODIFIED** — `panel`: the performance contract's two red lines (uncached frame ≤ 2 s; steady state < 1 %
  of one core) gain a measurement premise — judged only when `loadavg_1m ≤ 75 % × logical cores`; otherwise a
  visible SKIP prints the measured value and the load. The thresholds themselves do not move.
- **Docs only (no requirement, per the user's decision)**: `references/protocol.md` §9b,
  `templates/AGENTS.section.md.tmpl` + `AGENTS.md`, `SKILL.md` — "the full gate is the machine's single shared
  resource": `TEAM_SMOKE_FAST=1` for in-batch self-tests, the full suite for delivery and review, plus the lock
  and its queue cap.

## Capabilities

### Modified Capabilities

- `verification` — the hard timeout and what it covers (ADDED requirement: "The hard timeout covers the gate
  run, not the queue").
- `panel` — the performance contract's measurement premise (MODIFIED requirement: "Frame assembly is
  asynchronous, cached and never blocks input").

No new capability: the queue rule belongs to the capability that owns the timeout (`verification`), and the
premise belongs to the requirement that owns the red lines (`panel`) — a parallel requirement would restate
both statements.

## Impact

`skills/teamsmith/scripts/lib/cmd-review.sh` (queue + accounting + record lines), `skills/teamsmith/tests/smoke.sh`
(gate-lock isolation for fixtures, load premise for 27-d, a visible skip tally), `skills/teamsmith/tests/panel-cpu.sh`
(premise + a distinct skip exit code), `skills/teamsmith/references/protocol.md`, `skills/teamsmith/SKILL.md`,
`templates/AGENTS.section.md.tmpl`, `AGENTS.md`. No new `TEAM_*` key, no change to the lock's default path
`/tmp/teamsmith-smoke.lock`, no change to what `TEAM_REVIEW_TIMEOUT` means for the run itself; nothing
digest-related (M50's path).

## Acceptance

This propose task (run now):

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```

The apply phase's acceptance (built by this change; not runnable yet):

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
```

## What flips

Lock held 930 s, gate needs 870 s, `TEAM_REVIEW_TIMEOUT=1800`: **today `TIMEOUT`** (queue and run share the
budget) → **after `PASS`** with `queued 930s / ran 870s / limit 1800s`. The apply tasks name the fixture pair
for every scenario and the "break the implementation → the guard must fail → restore it" recipe.

## Boundaries

- This task writes only `openspec/changes/gate-hygiene/**` and `docs/team/reports/P26-verify.md`.
- Out of scope: any implementation (apply phase), verification queue-jumping (the user rejected it), the lock's
  default path `/tmp/teamsmith-smoke.lock`, every existing red-line threshold, and anything digest-related.
- PM-owned and needing an explicit grant in the apply brief: `skills/teamsmith/scripts/**`, `references/**`,
  `templates/**`, `SKILL.md`, `AGENTS.md`, `openspec/specs/**`. `skills/teamsmith/tests/**` is `agent:dev`'s.

## Evidence the report must contain

Both acceptance tails; the requirement → task map; for every scenario the observable that fails on the current
tree and the fixture that will pin it; the trial-archive output; the M49/V16 measurement trail the premise and
its threshold rest on.
