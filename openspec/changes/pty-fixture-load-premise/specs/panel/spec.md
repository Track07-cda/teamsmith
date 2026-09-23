## ADDED Requirements

### Requirement: The project-settings pty fixture judges under a machine premise

`bash skills/teamsmith/tests/panel-p21.sh choices` — and the `groups settings wheel` batch the gate's §38-f drives
— SHALL, before the first assertion of every scenario, print a **premise line** carrying the machine's real
readings: `loadavg_1m`/`loadavg_5m`, the logical core count (`nproc`, else `getconf _NPROCESSORS_ONLN`), and the
value of a **code-independent probe** — a fixed micro-workload that only starts processes and never touches the
panel (`python3 -c pass`, `bash -c true`, `git rev-parse`), printed in milliseconds. The probe's ceiling SHALL be
`TEAM_P21_PREMISE_PROBE_MS` (default **120 ms**; the measured band on the reference host is 12–34 ms across
`loadavg` 8.4–42.4 on 32 cores, so the ceiling sits outside every composition measured so far, and a composition
that reaches it is a calibration the apply must record) and the coarse load guard SHALL be
`TEAM_P21_PREMISE_LOAD_FACTOR` (default **2.0**), deliberately above the highest measured green load (1.33 ×
cores) so it can only ever skip a grossly overloaded host. The load average is printed as context and used only
by that coarse guard: it is **not** the deciding premise, because no threshold inside the measured band separates
the green runs from the observed red one.

The fixture's wait horizons stay exactly what they are (`PTY_WAIT_ITERS` and `PTY_WAIT_PAUSE` in
`tests/lib/pty-wait.sh` and the sites' overrides, unchanged) and are failure detectors, never judgments. When a
horizon runs out the fixture SHALL NOT report a failure on the spot. While the scene is still painting (the
masked capture changed within the last `PTY_STALL_ROUNDS`, default 8, rounds) it SHALL keep polling up to
`PTY_EXT_FACTOR` (default **3**) times the base horizon, so a slow but painting machine is still judged; at that
ceiling it SHALL read the machine and decide:

- still painting, or the probe over its ceiling, or `loadavg_1m` over the coarse guard → the wait and the rest of
  the scenario are a **visible SKIP**: one line naming the wait, its rounds, its elapsed time, the scene report
  and the readings; the scenario is counted as skipped, stops there (bounded cost) and the fixture exits **4**
  when no assertion failed — neither green nor a failure;
- a static scene with both readings under their ceilings → a **failure** with the M59 scene, so a real regression
  (a state that never appears) still reds on a healthy machine.

The fixture's exit status SHALL distinguish the outcomes: **0** every selected scenario judged and green, **1** at
least one assertion failed, **4** no failure but at least one scenario visibly skipped, **3** a setup failure
(unchanged). The gate's sections for the fixture (§38-b for `choices`, §38-f for `groups settings wheel`) SHALL
map 4 to a visible `SKIP` line carrying the fixture's reason and readings and leave the gate's exit status
unchanged, map 0 to the all-green line and 1 to a failure; a skipped scenario MUST NOT be printed as all-green.
The FAST/full split is unchanged: the pty scenarios run in the full gate only, FAST keeps its visible skip for
them, and the gate's load-independent pins (§38-d, §38-e) stay in FAST and stay able to fail — the premise does
not move work into FAST and does not remove a pin.

The premise knobs SHALL be honored only under the fixture switch (`TEAM_SMOKE_FIXTURE=1`): in the real path an
injected reading MUST be ignored, printed as ignored, and the premise line MUST carry the real readings. No
threshold on the panel's own speed is added anywhere: this requirement moves where a machine-caused exhaustion is
attributed, not what the console must do.

#### Scenario: A machine over the premise is skipped visibly, never turned into a red

- **GIVEN** the fixture switch on with the probe reading injected over its ceiling
  (`TEAM_SMOKE_FIXTURE=1 TEAM_P21_PREMISE_PROBE_MS=999`)
- **WHEN** `bash skills/teamsmith/tests/panel-p21.sh choices` runs
- **THEN** it exits `4`, prints a `SKIP` line naming the wait that hit its horizon, its elapsed time, the scene
  report and the readings, counts the skip in its summary, and reports no failure — no assertion of that
  scenario is judged after it

#### Scenario: A machine under the premise still reds a real regression

- **GIVEN** a scratch tree whose panel sources lost the wheel consumption the `wheel` scenario asserts, the bundle
  rebuilt there, and the premise readings under their ceilings
- **WHEN** `bash skills/teamsmith/tests/panel-p21.sh wheel` runs against that tree
- **THEN** the wheel assertions fail, the fixture exits `1` and the failing assertion is named — the same run
  against the unmodified tree prints those assertions green, which is the flip

#### Scenario: A static failure is neither extended nor skipped on a healthy machine

- **GIVEN** the fixture switch on with a step whose needle never appears while the scene is static (the picker's
  own negative fixture) and both readings under their ceilings
- **WHEN** the scenario runs
- **THEN** the wait's report shows the base horizon was used (its rounds are the site's `PTY_WAIT_ITERS`, not the
  extension ceiling) and the outcome is a failure with the scene, not a skip

#### Scenario: The premise line stays real on the real path

- **GIVEN** `TEAM_P21_PREMISE_PROBE_MS=999` and `TEAM_P21_PREMISE_LOAD_FACTOR=0.01` set with the fixture switch
  **off**
- **WHEN** the fixture runs
- **THEN** the premise line carries the real load, core count and probe value, the injected values are printed as
  ignored, and the run's verdict comes from the real readings

#### Scenario: The gate maps a skipped fixture to a visible skip, not a failure

- **GIVEN** the over-premise injection of the first scenario and a full-mode gate run
- **WHEN** the gate's §38-b section runs
- **THEN** it prints a `SKIP` line with the fixture's reason and readings, the all-green line for that section
  does not appear, and the gate's exit status is unaffected — while a fixture exiting `1` still turns the section
  red

#### Scenario: FAST keeps the pty scenarios out and the load-independent pins in

- **GIVEN** `TEAM_SMOKE_FAST=1`
- **WHEN** `bash skills/teamsmith/tests/smoke.sh </dev/null` runs
- **THEN** §38-b/§38-f are skipped visibly with their reason (as today), §38-d/§38-e still run and still fail
  when the pinned behavior is removed, and the premise did not move the pty scenarios into FAST or delete a pin
