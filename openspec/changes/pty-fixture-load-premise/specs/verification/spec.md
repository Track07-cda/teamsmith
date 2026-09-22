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

A fixture that waits for a real process to reach a state SHALL treat its wait horizon as a **failure detector,
never as a judgment**: when the horizon runs out, the verdict MUST be attributed from evidence collected at that
moment — whether the scene is still changing, and the machine's own readings (`loadavg_1m`/`loadavg_5m`, the
logical core count, and a code-independent probe that measures how long this machine needs to start processes).
A machine over the premise MUST produce a **visible SKIP** for that wait and the rest of its scenario: the line
names the wait, its elapsed time and the readings, the run's summary counts it as a skip, it is never reported as
a pass and never as a failure, and the gate still exits 0 — a fixture that cannot be judged SHALL say so instead
of turning the machine into a red. A machine under the premise whose scene is static MUST still fail: a
regression is a code verdict and the premise MUST NOT become an escape. While the scene is still changing the
fixture SHALL be allowed to extend its polling beyond the base horizon (a bounded factor) so a merely slow
machine is still judged rather than skipped. The readings MUST be real on the real path — an injection knob is
honored only under the fixture switch, and the injected values are printed as ignored — and the numbers that
decide SHALL be calibrated from measurement with their measured bands stated next to the fixture. Nothing here
adds a wall-clock or CPU-share red line: the horizons themselves are unchanged, and no assertion may fail
because a correct operation was slow.

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

#### Scenario: A machine over the premise skips visibly, and the gate is not red

- **GIVEN** the pty fixture's premise readings injected over their ceiling under the fixture switch
  (`TEAM_SMOKE_FIXTURE=1 TEAM_P21_PREMISE_PROBE_MS=999`), i.e. the machine reads as unable to deliver a frame in
  the fixture's budget
- **WHEN** `bash skills/teamsmith/tests/panel-p21.sh choices` runs and `TEAM_SMOKE_FAST=1 bash
  skills/teamsmith/tests/smoke.sh </dev/null` runs the section that drives it (§38-b)
- **THEN** the fixture exits `4`, prints a `SKIP` line naming the wait that hit its horizon, its elapsed time,
  the probe value and the load, counts the skip in its summary, and reports no failure — and the gate's section
  prints the same reason and still exits 0, so no review verdict turns red for it

#### Scenario: The premise is not an escape from a real regression

- **GIVEN** a scratch tree whose panel sources lost the wheel consumption the `wheel` scenario and the gate's
  §38-e structural pin assert (a real regression), the bundle rebuilt there, and the machine readings under
  their premise
- **WHEN** `bash skills/teamsmith/tests/panel-p21.sh wheel` runs against that tree
- **THEN** the wheel assertions fail (not skip), the fixture exits `1`, and the failure names the assertion — the
  same run against the unmodified tree is green, which is the flip

#### Scenario: A skipped fixture is never reported as a passing one

- **GIVEN** the over-premise injection of the first scenario
- **WHEN** the gate's section for the pty fixture runs
- **THEN** its line reads `SKIP` with the reason and the readings, the all-green line for that section does not
  appear, the run's skip count is non-zero, and the gate's output tail that `team review` records carries the
  same line

#### Scenario: The premise's readings stay real on the real path

- **GIVEN** `TEAM_P21_PREMISE_PROBE_MS=999` (and the other premise knobs) set with the fixture switch **off**
- **WHEN** the pty fixture runs
- **THEN** its premise line carries the real load, core count and probe value, the injected values are printed as
  ignored, and the verdict comes from the real readings — the same promise the knob-integrity scenario makes for
  the panel's measurement knobs

## ADDED Requirements

### Requirement: A load experiment signals only the processes it started

A test, fixture or calibration that applies a machine-side perturbation (a `SIGSTOP`/`SIGCONT` freeze, a CPU-share
throttle, a whole-machine load) SHALL target only processes it started itself: it records the owner it spawned
(or the PIDs it spawned) and MUST refuse every target outside that set, printing the refusal and exiting non-zero
**before** any signal is sent — selecting a signal target by command line, name or any other host-wide pattern
MUST NOT be used, because such a pattern's boundary can never be shown to exclude another seat's process (the
2026-09-22 incident: a `pgrep`-based pattern froze the panel of the PM's P42 verification fixture). Every
`SIGSTOP` SHALL be paired with a release: the script MUST carry a `CONT` trap for `EXIT`, `INT` and `TERM` that
resumes every PID it actually stopped, and its hold SHALL be interruptible, so a script killed mid-freeze leaves
no process in state `T`. Whole-machine load SHALL come from processes the experiment owns and can reclaim (spin
processes, `stress-ng`, …), never from freezing another seat's processes, and the experiment's fixtures SHALL use
their own temporary root and their own tmux socket/server name so two seats' experiments coexist. A guard test
SHALL exercise all of it: the owned target freezes and is released, a `TERM` mid-hold resumes it, and a target the
experiment did not start (and a pattern-shaped target) is refused with nothing signalled.

#### Scenario: A target the experiment did not start is refused before any signal

- **GIVEN** an experiment that spawned its own fixture (its owner PID recorded) and a second process of the same
  shape started outside that subtree
- **WHEN** the experiment's freeze script is asked to stop the second process's PID
- **THEN** it exits non-zero, prints that the target is neither the owner nor one of its descendants, the second
  process's state is unchanged (`ps -o stat=` shows no `T`), and the same script with its own owner's PID stops
  and then resumes it

#### Scenario: A pattern-shaped target is refused, because no pattern can be proven to exclude another seat

- **GIVEN** the same script and a target given as a command-line pattern (for example
  `panel.js.*--root /tmp/panel-p21`) or an empty target list
- **WHEN** it runs
- **THEN** it exits non-zero with a printed reason and signals nothing — there is no code path that selects
  targets by matching host-wide process names

#### Scenario: A freeze that is killed mid-hold leaves nothing stopped

- **GIVEN** the experiment's own fixture frozen by the script
- **WHEN** the script receives `TERM` (and, in a second run, `INT`) while the freeze is still on
- **THEN** it resumes every PID it stopped before exiting — a `T` left behind is a failure — and its own guard
  test asserts this for both signals

#### Scenario: Whole-machine load is owned load, and the fixtures stay private

- **GIVEN** an experiment asked for whole-machine load while another seat's fixture is running
- **WHEN** the load starts and both experiments run to completion
- **THEN** the load comes from processes the experiment itself started, it signalled no process outside its own
  set, and its fixtures used their own temporary root and tmux socket name, so the other seat's run is unaffected
