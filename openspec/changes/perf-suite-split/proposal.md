## Why

The user's decision (D33): "性能相关测试不要放在全量测试里，单独做一个性能的测试，全量测试只测正确性。"

The full gate mixes two verdicts. It carries exactly three wall-clock/CPU red lines — the 27-d assembly median
(2000 ms, premise 0.75), `tests/panel-cpu.sh`'s interactive first frame (2000 ms, premise 0.25) and the
steady-state pane CPU (< 1 % of one core) — and everything else it asserts is correctness. Measured here 30 s
apart on the same tree, premise holding in both: host first frame median **3415 ms** (RED) vs the pinned
`ci/Containerfile` image **209 ms** (OK) — the environment decides the colour, and a red nobody can act on blocks
merges on the machine's behalf.

## What Changes

- **ADDED — `verification`**: the correctness gate judges correctness only (a pure-logic guard keeps every perf
  marker out of it and inside the performance suite); the performance suite is a separate, single-command,
  self-describing suite (`tests/perf.sh`, fronted by `team perf`) with the unchanged thresholds, premises,
  medians and exit-4 visible skip, runnable on the host and in the pinned image; CI runs the two gates as
  separate, non-blocking conclusions; the docs and `team doctor` name the division.
- **MODIFIED — `panel`**: "Frame assembly is asynchronous, cached and never blocks input" keeps its correctness
  promises and its performance contract verbatim, but the judgment moves to the performance suite; the fixture
  knobs stay fixture-only and the gate keeps a time-independent check of that.
- **Moved**: §27-d's timing half, §35's judgment fixtures, §36's `panel-cpu-premise.sh` driving. **Kept**: §27-a/b/c,
  §27-d's JSON shape, §34's queue accounting, the knob check, the bounded liveness polls, §37's call counts.

## Capabilities

### Modified Capabilities

- `panel`: the performance red lines are judged by the performance suite; the correctness gate neither runs nor
  judges them.

### Added Capabilities

- `verification`: two gates with separate conclusions — correctness per change, performance separately and
  before a release — with the environment self-description that makes a performance verdict readable.

## Impact

New `tests/perf.sh` and `tests/panel-knobs.sh`; `tests/smoke.sh`, `tests/panel-cpu.sh`;
`scripts/lib/{cmd-docs,cmd-project}.sh`; `SKILL.md`, `references/{protocol,workflows}.md`;
`.github/workflows/gates.yml`; `docs/team/PUBLISH.md`. Untouched: the thresholds and premise factors, the
`queued`/`ran` accounting, `exit 4`, `refuse`/CAS/write/authz, the panel bundle.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```

## What flips

- **R1**: `TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_FRAME_DELAY_MS=2600 TEAM_SMOKE_FAST=1 bash tests/smoke.sh` — red
  (27-d) before, **green** after; the same delay through the suite
  (`TEAM_PERF_FIXTURE=1 TEAM_PERF_FRAME_DELAY_MS=2600 bash tests/perf.sh`) must be **red** there.
- **Guard**: reintroduce the judgment into `smoke.sh`, or drop its marker from `perf.sh` → guard red; restore → green.
- **R3**: delete the knob-ignore check, a §27-b isolation assertion, or §34's queue scenario → the gate red.
- **R2**: injected slow frame → suite exit 2 with its numbers; over-premise load → exit 4; a skipped judgment is
  never exit 0.

## Boundaries

Planning only: this task writes `openspec/changes/perf-suite-split/**` and its report, nothing else. Apply must
not change a threshold or premise factor, weaken the visible SKIP, or touch `refuse`/CAS/write/authz, and the
correctness gate must not depend on the performance suite. The implementation paths (`skills/teamsmith/tests/**`,
`scripts/**`, `SKILL.md`, `references/**`, `.github/workflows/**`, `docs/team/PUBLISH.md`) each need the apply
brief's explicit grant (OWNERSHIP).

## Evidence the report must contain

The baseline and post-change `openspec validate --all --strict` tails; the FAST-smoke tail with ✓/✗ counts and
the skip list; the delta→requirement, requirement→item and scenario→fixture maps; the R1/R2/R3/guard flip pairs
with real output tails; the self-description of one host run and one container run with their medians; and the
`git status --porcelain` tail.
