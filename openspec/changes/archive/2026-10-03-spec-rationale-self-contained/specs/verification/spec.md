## MODIFIED Requirements

### Requirement: A fixture observes a data-derived state before it asserts it

A fixture under `skills/teamsmith/tests/**`, and the fixtures those sources drive, that asserts a state the
console derives from an **asynchronous read** — the project-settings view's entry read, a contract re-read, the
panel's first frame, a log the tool writes — SHALL, before that assertion, observe **the state it is about to
assert**, on a settled frame and with a bounded wait: the value itself (for example the settings row already
showing the hand-edited value), not a proxy for it. A skeleton marker (a group heading, a loading or placeholder
line, an empty frame) MUST NOT be accepted as evidence that the data landed. An unconditional fixed delay followed
by a single sample (`sleep N` and one `capture-pane`/capture) MUST NOT be the evidence a data-derived assertion
rests on.

The wait SHALL be bounded and SHALL follow the counted-wait discipline of the gate's pty fixtures
(`skills/teamsmith/tests/lib/pty-wait.sh` is the model): it polls in counted rounds, carries a cap, and names
**which data-derived state** was expected in its attribution — not only that a wait expired — alongside the wait
itself and the rounds it used. When the wait runs out the fixture MUST NOT make the assertion and MUST NOT report
that scenario green. Whether the exhaustion is a **failure** or a **visible SKIP** is decided by
`verification#The correctness gate judges correctness only`: a scene that stays static while the machine's
readings are under their premise is a regression and stays red, and a machine over the premise takes the visible
skip — never a pass.

The bound MUST NOT be a wall-clock or CPU-share performance red line
(`verification#The correctness gate judges correctness only`, D33's rule): a read that lands slowly but inside the
bound MUST stay green, and no assertion in the fixture may fail because a correct read was slow. The bound SHALL
be recorded where the fixture lives together with the measured latency band it is derived from.

A fixed delay that only paces input (the interval between keystrokes) is not evidence and is not what this
requirement governs. What it governs is a fixed delay, or a skeleton frame, used as the evidence that data the
fixture is about to assert has landed.

#### Scenario: A read that lands later is observed, and the old shape is its red side

- **GIVEN** a scratch copy of `skills/teamsmith/tests/panel-p21.sh` whose CLI wrapper delays the settings block
  read (`__panel-data --block settings`) by a fixed delay that is inside the bounded wait (the attribution
  recipe: 0 s green, 6 s red, 6 s plus five times the horizon still red)
- **WHEN** the hand-edited-value scenario runs (the contract is edited by hand to `TEAM_NOTIFY_TMUX=true`, the
  view is reopened, the row is filtered to, and the picker is opened)
- **THEN** the fixture observes the derived state (the hand-edited value is in the picker's current entry) and the
  scenario is green, while the same run against the pre-change shape — a skeleton wait plus an unconditional
  `sleep` before Enter — is red with `非规范拼写的手改值原样显示成当前条目` unmet, the 2-core CI shape
  `✓ 108 ✗ 3`

#### Scenario: Data that never lands exhausts the wait instead of passing

- **GIVEN** the same scratch fixture with the settings read delayed past the wait's cap, or never completing
- **WHEN** the scenario runs
- **THEN** one attribution line names the wait and the state it waited for, the derived state is not asserted,
  the scenario is not green, and the exit status is not 0; on a machine under the premise the scene is static and
  the run is a **failure**, and where the machine reads over the premise it is the visible `SKIP` of
  `verification#The correctness gate judges correctness only` — in neither case a timeout reported as a pass

#### Scenario: The collapse scene's single sample becomes a bounded observation

- **GIVEN** `bash skills/teamsmith/tests/panel-b3.sh collapse` and a console whose first frame lands later than
  the fixed window the scene samples today — a delayed bundle injected through the fixture's own `TEAM_B3_PANEL`
  hook, or the loaded host on which 4 of 6 runs were red
- **WHEN** the scene runs
- **THEN** it observes the console's own title (`teamsmith pulse`) on a settled frame by polling inside a bound
  and is green, while the pre-change shape — `sleep 5` then one `capture-pane`, and `sleep 6` then one capture for
  the restore — is red with `pulse 窗口里是控制台` and `恢复后同一窗口里又是控制台` unmet; the scene's other
  evidence waits (`pulse up`'s log naming the window, `capacity.log` gaining rows) follow the same rule, and a
  title that never appears is attributed at the cap by the previous scenario's rule

#### Scenario: No duration judgement enters the fixture

- **GIVEN** the fixtures' sources after this change
- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` and the gate's guard
  (`verification#The correctness gate judges correctness only`) run
- **THEN** no assertion in these fixtures compares an elapsed time or a CPU share to a threshold — the waits'
  caps are liveness bounds recorded with their measured band — and a run in which the read landed slowly inside
  the bound is green; a fixture that turned such a bound into a duration verdict is the red side of that flip

### Requirement: A measuring fixture measures a fixed tree, not the caller's worktree

A fixture whose number is a verdict — `skills/teamsmith/tests/panel-cpu.sh`, driven by
`tests/panel-cpu-premise.sh` and the performance suite — SHALL measure a **fixed measurement target**: a neutral
reference project the fixture fixes itself, not the caller's current worktree. The tree under test, whose console
bundle the run reports as the revision under test, SHALL stay the tree the fixture was invoked against, so that
the code being judged and the data being measured are two separate, named things.

The output SHALL name both: the project root that was measured and the console bundle that was run. This is
separate from the performance suite's environment self-description
(`verification#The performance suite is separate, self-describing and non-blocking`), which names the environment
and the revision under test; this requirement fixes and names the **measurement target**. Invoking the same
command from two different worktrees SHALL measure the same project root and reach the same conclusion — the
caller's working directory MUST NOT change what is measured, and a checkout's own accumulated data (its
`state/`, its worktrees, its reports) MUST NOT be what the number describes.

#### Scenario: Two worktrees, one measured target

- **GIVEN** a large checkout (this repository's worktree, with its accumulated state) and a fresh project with
  almost no data, and the same console bundle under test
- **WHEN** `bash skills/teamsmith/tests/panel-cpu.sh` runs with default arguments from each
- **THEN** both runs measure the fixture's fixed project root, name it in their output, and reach the same
  conclusion — both green, both red, or both visibly skipped with the same attribution; the pre-change shape
  measures the caller's tree instead — measured as 3683 ms from a large checkout against 391 ms from a fresh
  project, one of the two past the fixture's ~3 s polling budget and therefore red — the red side of this flip

#### Scenario: The measured root and the revision under test are named

- **WHEN** `bash skills/teamsmith/tests/panel-cpu.sh` runs
- **THEN** its output carries the project root it measured and the console bundle it ran, neither implicit, so a
  reader can tell what the number describes without reading the fixture's source; the printed root is the
  fixture's own fixed project, and a caller that names another tree explicitly for diagnostics sees that tree
  named in the output instead of it being measured silently
