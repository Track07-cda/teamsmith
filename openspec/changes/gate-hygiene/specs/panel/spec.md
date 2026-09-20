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
**measurement premise**: `loadavg_1m ≤ 0.75 × logical CPU cores` (the CPU count from `nproc`, else
`getconf _NPROCESSORS_ONLN`). When the premise holds, the red line applies unchanged — an uncached frame over
2 seconds, or a steady state at or above 1% of one core, MUST be reported as red. When the premise does not
hold, every assertion that judges one of these numbers MUST instead report a **visible SKIP** that prints the
measured value(s) and the observed load; a SKIP is neither a pass nor a red, its outcome MUST be distinguishable
from both (its own exit status, or a counted entry in the run's summary), and the red-line thresholds MUST NOT be
scaled, relaxed or made configurable.

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

#### Scenario: The red line is measured, not promised

- **GIVEN** the reference checkout
- **WHEN** `time team monitor --once --print` runs, and a fixture-pane console's CPU is sampled over 60 seconds
- **THEN** the uncached frame assembles within 2 seconds and the steady-state CPU stays below 1% of one core

#### Scenario: A loaded machine skips visibly instead of judging

- **GIVEN** a fixture whose load reading is 26.0 with 32 logical cores (the premise does not hold) and an
  injected first-frame delay that would make every sample exceed 2000 ms
- **WHEN** the assembly assertion runs
- **THEN** it reports `SKIP` with the measured value and the load, its skip is counted and named in the run's
  summary, and no red is reported for it — the same injection on a machine below the premise is what the next
  scenario judges

#### Scenario: A quiet machine still fails a slow frame

- **GIVEN** a fixture whose load reading is 0.5 with 32 logical cores (the premise holds) and the same injected
  first-frame delay
- **WHEN** the assembly assertion runs
- **THEN** the measured value is over 2000 ms and the assertion is red — removing the injection makes it green,
  so the premise is not an escape from the red line

#### Scenario: The steady-state CPU line carries the same premise

- **GIVEN** a fixture-pane console measured over its window with a load reading above the premise, and then with
  one below it
- **WHEN** the CPU red-line assertion runs
- **THEN** the first run reports a visible SKIP with the measured percentage and the load, and the second run
  judges the percentage against the unchanged below-1% threshold
