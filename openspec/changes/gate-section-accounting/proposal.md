# gate-section-accounting · proposal

## Why

On **2026-09-22 12:03** `main`'s CI `gates` job sat in `Gates (pinned container)` for **45+ minutes** against a
normal whole-run time of ~12 minutes (job timeout 60 minutes), and an in-progress job's logs return 404: **not one
line said which section it was in**. The same commit ran the whole smoke **green** in the local pinned image
(`✓2837 ✗0`, ~11 minutes), so something was *waiting*. The gate is a 12 107-line script with **92 inline
sections**: each prints a header and nothing else — no timestamp, no elapsed time, no budget, no bound. The first
clock that can stop a section is the *outer* one (`TEAM_REVIEW_TIMEOUT` 1800 s, the job's 60 minutes), and it
cannot say where.

## What Changes

- **MODIFIED — `verification`** (*The correctness gate judges correctness only*): a per-section hard budget is a
  **liveness detector, not a performance judgment** — derived from a recorded measured band, never tightened below
  it, green for any section that finishes inside it however slow the machine is, and a trip is a red that names
  the section (never a skip). The timing record is data, and the pure-logic guard keeps it that way.
- **ADDED — `verification`** (*Every gate section accounts for itself, and a stuck section is named*): every
  section prints `#<N>`, its id, an ISO-8601 timestamp and its budget, then a closing line with its elapsed time
  and a timing record; budgets come from one committed table whose derivation (measured band × factor, with a
  floor) is in the file, with a bounded default for a section not listed yet; the first section past its budget
  stops the run with a red naming it (exit 2) and a **scene** written before the stop, outside the run's temp
  root, where D39's existing `docker cp` channel already looks; a run an outer clock kills is still attributable
  (the run self-reports while a section is in progress); the watchdog is not a job (a bare `wait` must return) and
  signals descendants only, never a process group.
- **ADDED — `verification`** (*Every wait in the gate is bounded and attributes at its cap*): the gate's poll
  loops (43 `while`+`sleep` loops today, 3 without a visible cap) are inventoried with their caps; new waits count
  rounds, refresh the section's progress reading and attribute at the cap; an uninventoried unbounded loop reds.

## Capabilities

Modified `verification`; added two `verification` requirements. `deltas: verification`.

## Impact

`skills/teamsmith/tests/**` (agent-owned): `smoke.sh`, `lib/section-guard.sh`, `section-budgets.tsv`,
`gate-guard.sh`, a fixture, the loop inventory. Out of scope: any section's decision semantics, D33's split and
thresholds (the self-report is a report, not a verdict), D39's channel and the workflow file, the panel
fixtures' premise rules, the outer timeouts.

## Flip

Red before: a section that never returns (a `sleep infinity` injected into an early section) leaves the run with
nothing naming it — only the outer clock stops it. Green after: the same run exits 2 inside the injected budget,
one line carries `#<N>`, the id, the budget and the elapsed time, no later section runs, and the scene holds the
stuck process and the last progress reading. Break-it: removing the trip-marker check from the suite's safe points
lets the stuck run finish its section and exit 0 — the guard fixture goes red; restoring it is green.

## Boundaries

Propose only: no `skills/**` change in this phase. The delta modifies one requirement another open change
(`pty-fixture-load-premise`) also modified — design D7 states the archive-order precondition and the rewrite rule.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/gate-guard.sh
git status --porcelain
```

## Evidence the report must carry

The validate and smoke tails; the probe's five shapes and its v1 findings; the FAST and full per-section tables
with their commands; the loop census; the per-requirement re-check table; and the measured columns the budget
table rests on.
