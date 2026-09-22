## ADDED Requirements

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

### Requirement: The performance suite is separate, self-describing and non-blocking

`bash skills/teamsmith/tests/perf.sh` (fronted by `team perf`) SHALL judge the panel's performance red lines — the
interactive first frame (under the unchanged 2000 ms budget), the uncached frame assembly line (the unchanged
2000 ms budget) and the steady-state pane CPU (under the unchanged 1 % of one core) — with the premise factors
(0.75 / 0.25), the median-of-five/samples-of-three rules, the visible SKIP and the thresholds exactly as they are
today. It SHALL print an **environment self-description** before its verdicts: whether it runs on the host or in a
container, the visible logical cores, the CPU quota when one is set, the load average, the JS runtime and tmux
versions, and the revision under test. A verdict line SHALL carry the measured numbers it rests on.

Its exit status SHALL distinguish the outcomes: **0** every judgment ran and was green, **2** at least one
judgment was red, **4** no red but at least one judgment visibly skipped (or the environment lacks a tool or an
engine a measurement needs — the reason and the measured values printed), **3** a setup failure. A skip MUST NOT be
reported as green, and a red MUST NOT be hidden behind another judgment's skip. It SHALL be runnable on the host
and inside the pinned `ci/Containerfile` image (`team perf --container`, or the equivalent documented container
invocation), and it SHALL take its own lock (`TEAM_PERF_LOCK`) so two performance runs do not overlap. It MUST NOT
take the correctness gate's lock and MUST NOT be invoked by the correctness gate or by `team review`: a failing
performance run never changes a review verdict.

#### Scenario: A slow frame is red with its numbers

- **GIVEN** the suite's fixture switch and an injected first-frame delay
- **WHEN** `bash skills/teamsmith/tests/perf.sh` runs
- **THEN** it exits 2, the failing judgment prints its median and the samples behind it, and the summary names
  that judgment red

#### Scenario: A busy machine skips visibly instead of passing

- **GIVEN** an injected load reading above the premise factor, with a delay that would otherwise be red
- **WHEN** the suite runs
- **THEN** the affected judgment prints `SKIP` with the measured values and the load, the suite exits 4 (no
  conclusion) and its own exit status is not 0 — the run is never presented as green

#### Scenario: The environment self-description is printed with the verdicts

- **WHEN** the suite runs, on the host and (once) in the pinned image
- **THEN** the output names the environment (host/container), the visible cores, the CPU quota or its absence,
  the load average, the runtime and tmux versions, and the revision, and each judgment's line carries its measured
  numbers

#### Scenario: The suite is not part of a review

- **GIVEN** a checkout whose performance suite would be red
- **WHEN** `team review <ID> --dir <checkout>` runs the gates
- **THEN** the verdict comes from the correctness gate alone, and `docs/team/reviews/<ID>.md` contains no
  performance judgment

#### Scenario: Two performance runs serialize instead of measuring each other

- **GIVEN** one performance run holding `TEAM_PERF_LOCK`
- **WHEN** a second `bash skills/teamsmith/tests/perf.sh` starts with `flock` available
- **THEN** it prints the holder and queues (bounded by a wait cap) instead of measuring concurrently, and the
  correctness gate's lock was never taken by either run

### Requirement: CI runs the two gates separately and performance does not block

The CI workflow SHALL run the correctness gate and the performance suite as separate steps or jobs with
independent conclusions and logs, and a failing performance run MUST NOT turn the correctness conclusion red or
block a merge. The performance suite SHALL be run once before a release, in the pinned image, and its measured
numbers SHALL be recorded in the release checklist.

#### Scenario: The workflow carries two independent conclusions

- **WHEN** `.github/workflows/gates.yml` is read
- **THEN** the correctness command is the unchanged
  `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null`, the performance command
  is a separate step inside the same pinned image, and that step is tolerated (`continue-on-error: true`) so its
  red is visible in the log without failing the correctness conclusion

#### Scenario: The pre-release run is named

- **WHEN** the release checklist (`docs/team/PUBLISH.md`) is read
- **THEN** it names the performance command to run before a release and the place its measured numbers are
  recorded

### Requirement: The two gates are discoverable, and the doctor names the next step

`skills/teamsmith/SKILL.md` and `references/protocol.md` SHALL state the division between the two gates —
correctness on every change (`team review` and the delivery gate), performance separately and before a release —
and SHALL give the copy-pasteable command for each. `team doctor` SHALL report the performance suite's presence,
and when `tests/perf.sh` is absent it SHALL name an actionable next step instead of staying silent.

#### Scenario: The docs name both gates and their division

- **WHEN** `grep -n 'team perf' skills/teamsmith/SKILL.md skills/teamsmith/references/protocol.md` runs
- **THEN** both files name the performance command, and the protocol's gate section states that the correctness
  gate judges no wall-clock performance line

#### Scenario: A missing performance suite is a next step, not silence

- **GIVEN** a skill tree whose `skills/teamsmith/tests/perf.sh` is absent
- **WHEN** `team doctor` runs
- **THEN** it reports the performance suite as absent together with the command that restores it, and it does not
  fail the doctor for it
