## MODIFIED Requirements

### Requirement: The correctness gate judges correctness only

The project's correctness gate — `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`, the
pair configured in `TEAM_GATES` and run by `team review` — SHALL contain no wall-clock or CPU-share performance
red line. No assertion in it may fail because a correct operation took longer than a threshold, and no fixture it
runs (transitively) may make such a judgment; slower-but-correct behaviour MUST stay green. The gate's sources
SHALL carry a pure-logic guard that fails when a perf judgment marker (a frame-budget comparison, a CPU-share
comparison, or an invocation of the measuring fixtures) reappears in the gate or disappears from the performance
suite. The one shared gate lock and its accounting (`TEAM_SMOKE_LOCK`, `TEAM_SMOKE_LOCK_WAIT`, the
`queued`/`ran`/`limit` record) are unchanged, and the gate keeps the time-independent knob-integrity check of
`panel#Frame assembly is asynchronous, cached and never blocks input`.

A section's per-section hard budget (`verification#Every gate section accounts for itself, and a stuck section is
named`) is a **liveness detector, not a performance judgment**, and the promise above holds inside it: the budget
is derived from a recorded measured band with a stated factor and floor, it MUST NOT be tightened below that band,
a section that finishes inside its bound MUST stay green however slow the machine is, and the only thing its clock
can decide is that the section did not terminate — a trip names the section and is always a red, never a skip and
never a silent pass. The timing record the gate writes is not a verdict: no other assertion in the gate may
compare a measured duration to a threshold, and the pure-logic guard SHALL keep that true (a duration comparison
reappearing outside the guard module, beside the frame-budget/CPU-share markers, turns it red).

#### Scenario: A slow-but-correct console keeps the correctness gate green

- **GIVEN** the assembly-delay fixture knob set in fixture mode
  (`TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_FRAME_DELAY_MS=2600`), which makes every sampled frame exceed the 2000 ms
  budget
- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` runs
- **THEN** it exits 0 with no failing assertion, and its output contains no frame-budget or CPU-share judgment —
  the same knob on the pre-split gate is the red side of that flip

#### Scenario: A wall-clock judgment cannot come back unnoticed

- **GIVEN** the correctness gate's sources
- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` runs
- **THEN** its guard asserts that the gate's files carry no frame-budget/CPU-share marker and invoke no measuring
  fixture, and that the performance suite carries the same marker — reintroducing the old judgment into the gate,
  or deleting it from the suite, makes the guard red

#### Scenario: The knob-integrity check stays in the gate, without a measurement

- **GIVEN** the fixture knobs set with the fixture switch off
- **WHEN** the gate runs the panel fixture's premise-only mode
- **THEN** the gate asserts the ignore notices for every injected knob and that the premise line carries the real
  load and core count, and it judges no duration

#### Scenario: A section that is slowed on purpose still stays green under its bound

- **GIVEN** the correctness gate's sources and `TEAM_SMOKE_FIXTURE=1` with the assembly-delay knob of the first
  scenario set, which slows the section that drives the pty fixture in this run
- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` runs
- **THEN** it exits 0, every section's start line carries its budget and its closing line carries the elapsed
  time, and no timeout line appears — the slower section's duration is recorded, not judged

## ADDED Requirements

### Requirement: Every gate section accounts for itself, and a stuck section is named

A run of `skills/teamsmith/tests/smoke.sh` SHALL account for itself section by section. Before a section's body
runs, the run SHALL print one start line carrying, in this order, the token `#<N>` with the run's monotone section
number (the first section is `#1`, one number per section, no gaps), the section's id as the sources spell it, an
ISO-8601 start timestamp, and the budget the section runs under as `<B>s` (for example
`== #7 4c · 看板重复 ID（M48）… == 2026-09-22T12:34:56+00:00 · 预算 120s`). When a section finishes, the run SHALL
print a closing line carrying the same `#<N>` and its elapsed time in seconds, and SHALL append the section to a
machine-readable timing record (a header line and one row per started section: number, id, ISO-8601 start,
elapsed seconds, progress ticks) in the run's temp root.

Every section SHALL run under a **hard per-section budget**, and the run SHALL stop at the first section that
exceeds it. The budgets SHALL come from one committed table (`skills/teamsmith/tests/section-budgets.tsv`) whose
derivation is recorded in the file: the measured band for that section — the worst observed time on the reference
host and in the pinned gate container, with the load of each measurement (the CI column is recorded beside them
once a CI run has produced it) — multiplied by a stated factor, with a stated floor. Every section in the sources SHALL have a row; a section the table does not list yet SHALL still get
the bounded default (never no bound) and its start line SHALL say the budget came from the default. The run SHALL
also self-report while it runs, so that a run an outer clock kills is still attributable: while a section is in
progress, one bounded progress line SHALL be printed every `SMOKE_PROGRESS_INTERVAL` seconds (default 60) carrying
that section's `#<N>`, its id, how long it has been running and the slowest sections so far, and a section that
closes above its recorded band SHALL print one warning line. Neither line is a verdict: the progress report MUST
NOT stop a run or turn a section red — the per-section budget is the only clock that can — and the outer timeouts
(`TEAM_REVIEW_TIMEOUT`, the CI job's) remain the outermost backstops.

When a section exceeds its budget the run MUST stop and report it as a **red that names the section**: the line
SHALL carry `#<N>`, the section's id, its budget and its elapsed time, the run SHALL write the section's scene
(below), and the run SHALL exit non-zero with status 2. No later section may run, no result line may be printed,
and the timeout MUST NOT be reported as a skip, as a pass, or as a run that continued — a timeout is never an
attribution that turns the machine into a green.

The watchdog that enforces the budgets SHALL be a child that is not in the suite's job table (a bare `wait` in the
suite MUST return without waiting for it), SHALL be reclaimed when the run ends normally, SHALL poll with a
bounded interval, and MUST NOT signal a process group: it stops the stuck section's descendants and the suite
itself, escalating `TERM` to `KILL`, so that a caller that shares the suite's process group (`team review`, the CI
step, the session that started the gate) is never signalled. The suite SHALL also check the trip at its own safe
points (a section boundary and every assertion), so that a section whose child was killed cannot quietly continue.
The fixture knobs (`TEAM_SMOKE_STUCK_SECTION`, `TEAM_SMOKE_SECTION_BUDGET`, `TEAM_SMOKE_PROGRESS_INTERVAL`,
`TEAM_SMOKE_GUARD_POLL`) SHALL be honoured only under the fixture switch (`TEAM_SMOKE_FIXTURE=1`) and SHALL be
printed as ignored otherwise, so an inherited environment cannot weaken the bounds.

The scene SHALL be written **before** the stop signals and SHALL outlive the run: it SHALL be a dot-prefixed
directory under the resolved temp root (`${TMPDIR:-/tmp}`), outside the run's own temp root, so the suite's normal
cleanup (and its failure path, which deletes the temp root) cannot take it, and so the CI's existing collection
(`docker cp <container>:/tmp/.`) carries it out unchanged. It SHALL hold, bounded in lines and bytes: the section's
number, id, budget and elapsed time; the last progress reading; the suite's descendant process tree and a bounded
process-table snapshot; the tail of every fixture log the run wrote under its temp root during that section; the
last lines of every pane on the run's private tmux server when one exists; and the partial timing record. A normal
run SHALL NOT create it.

#### Scenario: A section that never returns is named, stops the run, and leaves a scene

- **GIVEN** a nested `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` whose fixture switch is on,
  whose stuck-section knob names an early section, and whose budget override is a few seconds
- **WHEN** that run executes the named section, which does not return
- **THEN** the run exits 2, its output carries one line naming that section's `#<N>`, its id, its budget and its
  elapsed time, no result line and no later section appear, and the line is within the last lines of the output
  (the tail `team review` records)
- **AND** a timeout line is not accompanied by any `SKIP` attribution for that section, and the run's exit status
  is not 0

#### Scenario: The scene survives the run and carries the section's evidence

- **GIVEN** the timed-out run of the previous scenario, whose stuck command is a sleeping process that ignores
  `TERM`
- **WHEN** the run has ended and its temp root is gone (the default, no `--keep`)
- **THEN** the scene directory still exists under `${TMPDIR:-/tmp}`, its summary names the section and the
  budget, and its process evidence names the stuck command (the watchdog's `KILL` escalation is recorded)
- **AND** the scene carries the last progress reading and the tail of the fixture log the section had written, so
  the incident can be read without a rerun

#### Scenario: A normal run is unaffected, and every section is accounted for

- **GIVEN** a clean tree and `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` (no fixture knob)
- **WHEN** it runs
- **THEN** it exits 0, no timeout line and no scene directory appear, each section printed exactly one start line
  with a strictly increasing `#<N>` and a budget and one closing line with its elapsed time, and the timing record
  has exactly one row per section that started

#### Scenario: The budget table has a measured basis, and a weakened budget is red

- **GIVEN** `bash skills/teamsmith/tests/section-guard.sh --budget-check` over the committed sources and table
- **WHEN** it runs on the clean tree, and then in a scratch tree whose table entry for one section is lowered
  below its recorded band × the stated factor (and, in a second scratch tree, whose table loses one section's row)
- **THEN** the clean tree is green, verifying for every row that the budget is at least the recorded band times
  the factor and at least the floor and that the measurement's provenance (host, container and revision) is
  recorded, while both scratch trees are red and name the offending section — restoring either makes it green

#### Scenario: A run that an outer clock kills can still say where it was

- **GIVEN** the fixture switch on, a small progress interval, and a section that runs longer than that interval
- **WHEN** the run is in that section
- **THEN** progress lines carry the section's `#<N>`, its id, its running elapsed time and the slowest sections so
  far, and none of them stops the run or turns anything red — the budget remains the only clock that can
- **AND** a section that finishes inside the interval prints no progress line for itself

### Requirement: Every wait in the gate is bounded and attributes at its cap

A wait in the gate's sources (`skills/teamsmith/tests/**` and the fixtures those sources drive) that waits for a
real process or state to arrive SHALL carry a round count and a cap, SHALL poll in counted rounds, and SHALL
refresh the running section's progress reading on every round, so that a section that is legitimately waiting is
distinguishable from a section that is stuck. At its cap the wait SHALL print one attribution line — the wait's
own name, the rounds it used as `<n>/<cap>`, and what it observed (the state it was waiting for and the last
reading it got) — before it returns a non-green status; a wait MUST NOT return quietly having observed nothing.
An unbounded `while` loop that sleeps SHALL NOT exist in the gate's sources.

The gate SHALL carry a static check over its own sources: the `while`+`sleep` loops are inventoried in one place
with the cap each one carries or the structure that bounds it (a stop file, a deadline, the owner's lifetime), and
an uninventoried loop, or an inventoried loop that lost its cap, turns the check red. `tests/lib/pty-wait.sh`'s
settled-frame discipline and its premise/attribution semantics are the model for a bounded wait and are unchanged
by this requirement.

#### Scenario: An unbounded poll loop cannot appear unnoticed

- **GIVEN** the gate's sources and the static check running inside the gate (a pure-logic FAST section)
- **WHEN** the check runs on the clean tree, and then in a scratch tree that adds a new
  `while :; do sleep 1; done` loop to a fixture
- **THEN** the clean tree is green, the scratch tree is red and names the file and line of the new loop, and
  restoring the file makes it green again

#### Scenario: A wait that exhausts its cap says what it was waiting for

- **GIVEN** a fixture whose probe never reaches the waited-for state and whose cap is three rounds
- **WHEN** its wait runs
- **THEN** one line names the wait, prints `3/3`, and carries the last observed reading, the wait returns a
  non-green status, and the section's timing record shows its progress ticks advanced during the wait (the wait
  was polling, not stuck)

#### Scenario: The pty fixture's settled-frame waits are unchanged

- **WHEN** `bash skills/teamsmith/tests/lib/pty-wait.sh --self-test` and the gate's pty sections run
- **THEN** their existing semantics — settled frames, the bounded extension, and the attribution at the ceiling —
  are unchanged, and the new inventory names their loops rather than replacing them
