## MODIFIED Requirements

### Requirement: Frame assembly is asynchronous, cached and never blocks input

The console SHALL render every frame from an in-memory cache whose rebuild runs off the input path, so a refresh
in progress MUST NOT delay, merge or reinterpret keystrokes. Each block's data SHALL be rebuilt independently: a
source that is missing, unreadable, too slow or failing SHALL render that block as `—` and MUST NOT blank, delay
or fail the rest of the frame. One uncached frame SHALL assemble within 2 seconds on the reference checkout (the
pre-change measurement is ≈7.2s wall / 6.3s user CPU — E6 §0), and the running console SHALL burn less than 1% of
one core in steady state. The 3-second refresh cadence and this red line together are the design's performance
contract.

Those two numbers are verdicts about the panel, not about the machine, so they SHALL be judged under a
**measurement premise**: `loadavg_1m ≤ factor × logical CPU cores` (the CPU count from `nproc`, else
`getconf _NPROCESSORS_ONLN`). The factor is per measurement, because the measurements have different noise:
**0.75** for the five-sample median assembly assertion, and **0.25** for the interactive first frame and the
sampled pane CPU (overridable with `TEAM_PANEL_CPU_PREMISE_FACTOR`). When the premise holds, the red line applies
unchanged — an uncached frame over 2 seconds, or a steady state at or above 1% of one core, MUST be reported as
red. When the premise does not hold, every assertion that judges one of these numbers MUST instead report a
**visible SKIP** that prints the measured value(s) and the observed load; a SKIP is neither a pass nor a red, its
outcome MUST be distinguishable from both (its own exit status, or a counted entry in the run's summary), and the
red-line thresholds MUST NOT be scaled, relaxed or made configurable. The same visible SKIP with the missing tool
named MUST replace the judgment when the environment lacks a tool a measurement needs — the tree CPU figure
`tests/panel-cpu.sh` prints alongside its samples needs GNU time (`/usr/bin/time`) — and the fixture that drives
it MUST follow it into that SKIP instead of reporting it as a setup failure.

Both factors are calibrated from measurement, not chosen. The assembly **median** of five samples stays green at
0.22 ×, 0.40 × and 0.71 × cores (measured medians 1238 / 1573 / 1713 ms), and the false red that motivated this
requirement sat at 0.81–1.0 × cores (load 26–32 on 32 logical cores, M49) — so 0.75 separates green from red for
that line. The interactive first frame is measured differently (a cold process start, not a median over an existing
process): with the median-of-three rule below it reads 1542 ms at 0.22 × cores but 2005 ms at 0.40 × and 3919 ms at
0.71 ×, so its green→red crossing lies between 0.22 × and 0.40 × — hence **0.25**, below the crossing and above the
measured-green level. Both the first frame and the pane CPU SHALL be the **median of three measurements** with all
three samples printed, and only that median is compared against the unchanged 2000 ms and 1 % thresholds.

The performance contract stays part of this requirement, but its **judgment belongs to the performance suite, not
to the correctness gate**: `tests/perf.sh` (fronted by `team perf`) SHALL be the only entry that judges the
assembly budget, the first frame and the steady-state CPU, and the correctness gate
(`openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`, the pair `team review` runs) MUST NOT
contain a wall-clock or CPU-share judgment: a slower-but-correct console MUST NOT turn that gate red, and the
gate MUST NOT invoke the measuring fixtures. Thresholds, premise factors, the medians-of-three/five rules, the
visible SKIP and its exit status are unchanged — the change moves *where* the numbers are judged, not what they
are.

The fixture knobs that substitute a reading or inject a delay (`TEAM_SMOKE_LOADAVG`, `TEAM_SMOKE_CORES`,
`TEAM_SMOKE_FRAME_DELAY_MS`, `TEAM_PANEL_CPU_LOADAVG`, `TEAM_PANEL_CPU_CORES`, `TEAM_PANEL_CPU_FRAME_DELAY_MS`)
SHALL only be honored under a fixture switch (`TEAM_SMOKE_FIXTURE=1`), and so SHALL any knob the performance suite
adds. In the real path an injected knob MUST be ignored and printed, and a premise line MUST reflect the real
readings. The correctness gate SHALL keep a **time-independent** check of that promise — `tests/panel-cpu.sh`
gains a premise-only mode that prints the premise line and the ignore notices without measuring — so
"the knobs do not leak into the real path" is verified on every gate run.

#### Scenario: The parenthetical measurements a verdict rests on are stated

- **GIVEN** this requirement
- **WHEN** a reader looks for why the premise factor is 0.75 and where the numbers came from
- **THEN** the requirement states, per measurement, the factor, the band that holds (the 5-sample median green at
  0.22–0.71 × cores; the first frame green at 0.22 ×), the band that broke (the M49 red at 0.81–1.0 × cores; the
  first frame red at 0.40 × and above) and the median-of-three rule with its printed samples

#### Scenario: Keystrokes survive a refresh in progress

- **GIVEN** a fixture project whose data reader is a stub that sleeps five seconds, and the console running in a
  fixture pane
- **WHEN** a refresh starts and the pty then sends `m`, `hello` and Enter during the sleep
- **THEN** the compose line opens and the draft holds exactly `hello` — no meta-`m` misfire and no merged
  multi-character event (E6 §2.3's two measured distortions flip from red to green)

#### Scenario: A broken block renders `—` and never fails the frame

- **GIVEN** a fixture project whose `BOARD.md` is unreadable and whose capacity log is absent
- **WHEN** `team monitor --once --print` runs
- **THEN** it exits 0, the affected blocks render `—`, and every other block renders its fields

#### Scenario: The correctness gate cannot fail on a slow frame

- **GIVEN** the fixture switch on and the injected assembly delay that makes every sample exceed the 2000 ms
  budget (`TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_FRAME_DELAY_MS=2600`)
- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` runs
- **THEN** it exits 0 and none of its assertions compares a duration or a CPU share against a red line — while
  the same injection under the performance suite's fixture switch is what reports the red (the next scenarios)

#### Scenario: The red line is measured, not promised

- **GIVEN** the reference checkout
- **WHEN** `bash skills/teamsmith/tests/perf.sh` runs
- **THEN** the suite measures the uncached frame assembly (five samples, their median) and the fixture-pane
  console's first frame and steady-state CPU (three samples each, their medians), and compares the medians against
  the unchanged 2 s and 1 % thresholds; the correctness gate neither runs nor judges them

#### Scenario: A loaded machine skips visibly instead of judging

- **GIVEN** a fixture whose load reading is 26.0 with 32 logical cores (the premise does not hold) and an
  injected first-frame delay that would make every sample exceed 2000 ms
- **WHEN** the performance suite's assembly or first-frame judgment runs
- **THEN** it reports `SKIP` with the measured value and the load, its skip is counted and named in the suite's
  summary, and no red is reported for it — the same injection on a machine below the premise is what the next
  scenario judges

#### Scenario: A quiet machine still fails a slow frame

- **GIVEN** a fixture whose load reading is 0.5 with 32 logical cores (the premise holds) and the same injected
  first-frame delay
- **WHEN** the performance suite runs
- **THEN** the measured value is over 2000 ms and the judgment is red — removing the injection makes it green,
  so the premise is not an escape from the red line

#### Scenario: The steady-state CPU line carries the same premise

- **GIVEN** a fixture-pane console measured over its window with a load reading above the premise, and then with
  one below it
- **WHEN** the performance suite's CPU red-line judgment runs
- **THEN** the first run reports a visible SKIP with the measured percentage and the load, and the second run
  judges the percentage against the unchanged below-1% threshold

#### Scenario: A machine without the measuring tool skips visibly instead of judging red

- **GIVEN** a machine without GNU time (`/usr/bin/time`), which `tests/panel-cpu.sh` needs for the tree CPU
  figure, and the `panel-cpu-premise` fixture driving it
- **WHEN** the performance suite runs there
- **THEN** it prints the missing tool as the reason and reports `SKIP` (its own exit status, no conclusion), the
  suite follows it into the same visible SKIP, and neither reports a red against the panel nor a silent pass

#### Scenario: The fixture knobs do not leak into the real path

- **GIVEN** the correctness gate and `tests/panel-cpu.sh` invoked in its premise-only mode with injected knob
  values set (`TEAM_PANEL_CPU_LOADAVG=9999`, `TEAM_PANEL_CPU_CORES=1`, `TEAM_PANEL_CPU_FRAME_DELAY_MS=99999`) and
  the fixture switch off
- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` runs
- **THEN** the gate asserts the three ignore notices, asserts the premise line carries the real load and core
  count (no `9999`, no `1 cores`), judges no duration, and exits 0 — the same promise the pre-split
  `d-realpath` fixture asserted with a measurement attached
