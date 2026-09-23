# panel Specification

## Purpose
What `team monitor` draws, in which mode, from which data, and what it must never do. The panel is the window a
human leaves open to answer two questions — "is someone in charge?" and "is there work?" — so its layout, its
degradation on a small terminal and its behaviour on a pipe are part of the contract, not styling. The data layer
(`scripts/monitor.mjs --json`, the probes, the bounded tail reads, the sanitizer) is unchanged and stays the source
of every untrusted string; this capability describes the front end that consumes it. Why a TUI framework at all, and
why the bundle is committed: `references/config.md`, E4's measurements and `docs/team/DECISIONS.md` D19/D24.
## Requirements
### Requirement: The panel is a TUI in a terminal and never a TUI on a pipe

`team monitor` SHALL render through the TUI renderer only when stdout is a terminal; when stdout is redirected, or
`--print` is given, or `TEAM_MONITOR_UI=text`, it MUST render one plain-text frame and MUST write no escape
sequence, no screen clear and no alternate-screen switch. `TEAM_MONITOR_UI=tui` SHALL force the TUI path even when
stdout is redirected, and `auto` (the default) SHALL be the rule above. Rendering SHALL exit 0, and every failure
to render (no runtime, unreadable project root, unusable terminal geometry) MUST exit non-zero with one line
naming the reason — an empty or partial panel MUST NOT be reported as success. Under the console the plain-text
frame SHALL keep its pre-console shape — the overview content, ending in the key line — and the JSON object SHALL
keep its top-level keys (`panel`, `activity`; additive fields allowed). Pagination is a TUI-only concept and MUST
NOT leak into either machine exit.

#### Scenario: A pipeline receives plain text

- **WHEN** `team monitor --once --print` runs with stdout redirected to a file
- **THEN** the command exits 0, the file contains no `0x1b` byte, and its first line names the project and the
  patrol interval

#### Scenario: Redirecting stdout selects the plain-text path

- **GIVEN** a fixture project
- **WHEN** `team monitor --once > out.txt` and `team monitor --once --print > print.txt` run
- **THEN** both exit 0, neither output contains a `0x1b` byte, and `out.txt` equals `print.txt` apart from the
  timestamp

#### Scenario: The TUI still renders in a real pane

- **GIVEN** a fixture tmux session with a 120x29 pane, and a sandbox project whose state directory is a temporary
  directory
- **WHEN** `team monitor` runs in that pane and the pane is captured with `tmux capture-pane`
- **THEN** the capture contains the panel's title band with the project name and the interval
- **AND** the same pane running `team monitor --print` writes no `ESC[H` and no `ESC[2J` into the capture

#### Scenario: The machine exits ignore the pages

- **GIVEN** a fixture project
- **WHEN** `team monitor --print` and `team monitor --json` run
- **THEN** the frame carries the overview's banner, agent table and key line and no page marker, and the JSON
  carries the `panel` and `activity` top-level keys

### Requirement: `--once`, `--print` and `--json` are three explicitly different one-frame modes

`team monitor --print` SHALL render exactly one plain-text frame, write nothing into `TEAM_STATE_DIR` and write no
patrol tick. `team monitor --json` SHALL print one JSON object on stdout containing a `panel` object (the fields the
layout uses) and an `activity` array (the data layer's result, unchanged) and MUST likewise write nothing into
`TEAM_STATE_DIR`. `team monitor --once` SHALL render one frame through the renderer selection of the previous
requirement and SHALL keep today's tick semantics (a tick runs when due). `--print` and `--json` are the
machine-readable exits: neither may depend on terminal capabilities, and neither may be the only way to see a field
the TUI shows.

#### Scenario: The observers write no patrol state

- **GIVEN** a fixture project with `TEAM_STATE_DIR=<temp>` and no previous tick
- **WHEN** `team monitor --print` and `team monitor --json` each run once
- **THEN** both exit 0 and `<temp>` contains no `capacity.log` and no `watchdog.tick.log`

#### Scenario: JSON carries the panel fields and the untouched data layer

- **GIVEN** a fixture project whose agent log holds two events
- **WHEN** `team monitor --json` runs
- **THEN** the output parses as one JSON object whose `panel.agents` is a list of one object per roster agent, and
  whose `activity` entries carry the `source`, `available`, `truncated`, `tail_limit`, `count` and `events` keys
  that `monitor.mjs --json` prints for the same fixture

#### Scenario: `--once` keeps the tick it has today

- **GIVEN** a fixture session and a sandbox project with an empty `state/capacity.log`
- **WHEN** `team monitor --once` runs in a fixture pane
- **THEN** it exits 0 and `state/capacity.log` gained exactly one line

### Requirement: The status band answers "who is in charge" and "is there work"

The status band SHALL carry, in this order: the project name, the timestamp, the patrol interval, the standby state,
the PM state, the pending counts (unread notifications, task reports awaiting review, blocked board rows and their
total), the deferred-delivery counts, and the capacity figures (RAM available in MB, swap free in MB, the agent
estimate and a mini chart built from the tail of `state/capacity.log`). The zram physical figure SHALL leave the
panel and stay available in `team watchdog status`. The same fields SHALL appear in `--json` under `panel.pm`,
`panel.pending`, `panel.capacity` and `panel.standby` with the PM state in a closed vocabulary
(`running`, `starting`, `absent`, `foreign`, `unknown`) and standby as `{on, reason}`.

#### Scenario: The band mirrors the measured state

- **GIVEN** a fixture project with no PM window, one unread inbox line, two task reports without review records, one
  `blocked` board row, three queue entries and 40 `capacity.log` samples
- **WHEN** `team monitor --print` and `team monitor --json` run
- **THEN** `panel.pm.state` is `absent`, the pending counts are 1, 2, 1 and 4, `panel.outbox.queued` is 3, and
  `panel.capacity.ram_avail_mb` equals the last sample's value while `panel.capacity.spark` has at least two samples
- **AND** the printed status band contains the queue count and the PM state token, and carries no zram physical MB

#### Scenario: Standby is visible where the wake-ups are decided

- **GIVEN** a fixture project where `team standby on --reason "waiting for the user"` has run
- **WHEN** `team monitor --json` runs
- **THEN** `panel.standby.on` is true and `panel.standby.reason` is that reason, and the printed status band shows
  the reason on the title or PM line

### Requirement: The agent table keeps today's fields and adds the branch columns the PM asks for

The agent table SHALL keep one row per roster agent with the name, the window state in a closed vocabulary
(`running`, `exited`, `absent`), the recorded task id, the idle time and the event count (when the width allows), and
SHALL add the branch name, a dirty marker, the number of commits ahead of the protected branch and the estimated
session size; those four come from the same read-only subcommands (`team_git_cols`, `team_session_tokens_est`) that
`team status` already uses. The uptime (`elapsed`) SHALL leave the table and stay available in `--json`. A row whose
window is gone but whose recorded task is unfinished SHALL still name that task, because that row is how the PM sees
a stopped agent.

#### Scenario: The added columns are real values

- **GIVEN** a fixture project with two agents, one of them in a worktree on a task branch with one uncommitted file
  and three commits ahead of the protected branch
- **WHEN** `team monitor --json` runs
- **THEN** that agent's entry carries its branch name, `dirty` true, `ahead` 3 and a non-empty `session_tokens`
  field, and `panel.agents` still carries `elapsed` while the printed table does not show the uptime token

#### Scenario: A stopped agent keeps its task visible

- **GIVEN** a fixture project whose `verify` window does not exist and whose recorded task is `P9`
- **WHEN** `team monitor --print` runs
- **THEN** the `verify` row reports the `absent` state and names `P9`

### Requirement: The activity column is part of the default layout and stays bounded and session-scoped

The panel SHALL show the activity column by default: `TEAM_MONITOR_ACTIVITY` changes its default from `0` to `1`,
and `--activity` / `--no-activity` keep overriding it in both directions. With the column off, `--json` SHALL carry
an empty `activity` array and the panel SHALL read no session or log file. The data layer's bounds SHALL survive the
rewrite: the activity covers only the windows of the current session, the tail read stays at the configured window
(default 64 KiB, hard cap 1 MiB) and the `truncated` / `tail_limit` markers are still reported. The last six lines of
the patrol's action log (`watchdog.log`, whose name the `watchdog` capability owns and
`rename-watchdog-to-pulse` renames) SHALL stay as the recent-actions column.

#### Scenario: The column is on by default and off on request

- **GIVEN** a fixture project with `TEAM_AGENT_LOG_GLOB` pointing at a log holding the event `wrote the report`
- **WHEN** `team monitor --print` runs, and then `team monitor --print --no-activity`
- **THEN** the first output contains `wrote the report` and the second contains neither the event text nor the
  activity heading, and its `--json` counterpart carries an empty `activity` array

#### Scenario: The bounded read survives

- **GIVEN** a fixture log of 12 MiB
- **WHEN** `team monitor --json` runs
- **THEN** the activity entry reports `truncated` true and `tail_limit` 65536, and the recent-actions column in the
  printed frame has at most six lines

#### Scenario: Only this session's windows are watched

- **GIVEN** a fixture session with one agent window and one foreign window in another session
- **WHEN** `team monitor --print` runs in the fixture session
- **THEN** the activity column names the fixture session's agent and no window of the other session

### Requirement: Display safety: sanitize before layout, and keep the visible text

Every string the panel renders from disk — session and log text, branch names, task ids, state files, queue names —
SHALL pass the sanitizer before it is laid out, so the panel emits no ESC, BEL, CR or C1 byte in any mode, in the
TUI as well as in text. The sanitizer MUST remove the control bytes and keep the surrounding visible text: a hostile
payload MUST NOT truncate the line at its first control character and MUST NOT lose the text after it.

#### Scenario: An OSC 52 payload is stripped, not obeyed and not truncated

- **GIVEN** a fixture log whose last event is `safe ESC ]52;c;aGVsbG8=BEL MORE ESC [2J END`
- **WHEN** `team monitor --print` and `team monitor --json` run
- **THEN** both exit 0, the output contains no `0x1b` byte, and it contains `safe`, `MORE` and `END`

#### Scenario: A hostile branch name cannot clear the screen

- **GIVEN** a fixture worktree whose branch name embeds `ESC [2J`
- **WHEN** `team monitor --print` runs
- **THEN** the output contains no `0x1b` byte and still shows the branch name's visible characters

#### Scenario: The TUI frame is captured clean

- **GIVEN** a fixture session and a fixture project whose log holds the hostile payload
- **WHEN** one `team monitor --once` frame renders in a fixture pane and the pane is captured
- **THEN** the capture contains no `0x1b` byte and still shows `MORE` and `END`

### Requirement: The panel process is the patrol's single tick loop

The run that owns the patrol window SHALL be the process that renders the console and that runs one patrol tick
per `TEAM_WATCH_INTERVAL`; it MUST NOT create a second tmux window or leave a background worker behind.
Collapsing the console (`q`) SHALL rebuild the same window in place as a headless tick loop — the tick survives
the renderer, with one window and one process throughout — and reopening the console SHALL reuse that window. The
flag that turns the tick off today (`--no-watchdog`) SHALL keep the console while suppressing the ticks. The two
observer modes (`--print`, `--json`) SHALL never tick, and no console mode SHALL write `queue` or patrol state
other than what the tick itself writes (the console's own files — `state/draft.md`, `state/panel.conf`,
`state/panel-page` — are the console's, not the patrol's).

#### Scenario: The tick-off flag leaves the panel alive

- **GIVEN** a fixture session and a sandbox project
- **WHEN** `team monitor --no-watchdog` runs in a fixture pane for two intervals and the pane is captured
- **THEN** the capture still shows the panel, `state/capacity.log` gained no line, and `tmux list-windows` gained
  no window

#### Scenario: One tick per interval, one process

- **GIVEN** the same fixture
- **WHEN** `team monitor` runs for three intervals
- **THEN** `state/capacity.log` gained one line per interval (±1 for the first), and the number of tmux windows
  and of processes in the session changed only by the panel's own

#### Scenario: Collapse keeps the tick, not the renderer

- **GIVEN** a fixture session with the console running in the patrol window
- **WHEN** `q` is sent and two intervals pass
- **THEN** the window list is unchanged, the window's process is the headless tick loop, no renderer process
  survives, and `state/capacity.log` kept gaining one line per interval

#### Scenario: The console is restored in place

- **GIVEN** the collapsed patrol window
- **WHEN** `team pulse up` runs
- **THEN** the same window renders the console again and `team pulse status` still reports exactly one backend

### Requirement: Without a JS runtime the panel fails loudly, and the escape key is doctor-only

`team monitor` in every mode SHALL exit non-zero with one line naming the fix when no JS runtime resolves; it MUST
NOT print a panel and MUST NOT exit 0. `TEAM_REQUIRE_JS=0` SHALL NOT change that (it downgrades the `team doctor`
check only, `memory-and-deps`). `team watchdog up` SHALL refuse in the same environment before creating a window,
for the same reason: a window whose process cannot render is not a running patrol.

#### Scenario: No runtime is a named failure, not an empty panel

- **GIVEN** a `PATH` without `node`, `bun` and `tsx`, and `TEAM_JS_BIN` unset
- **WHEN** `team monitor --once` and `team monitor --print` run
- **THEN** both exit non-zero, their output names node or bun and the fix, and neither prints the panel's title

#### Scenario: The escape key does not resurrect the panel

- **GIVEN** the same `PATH`, `TEAM_REQUIRE_JS=0`, and the other required dependencies still resolvable (a stub
  OpenSpec CLI on `PATH` and `TEAM_REQUIRE_MAGIC_CONTEXT=0`)
- **WHEN** `team monitor --print` and `team doctor` run
- **THEN** `team monitor --print` still exits non-zero, while `team doctor` exits 0 and warns about the missing
  runtime

#### Scenario: No patrol window is created without a runtime

- **GIVEN** the same `PATH` and a fixture session with no `watchdog` window
- **WHEN** `team watchdog up` runs
- **THEN** it exits non-zero, names the missing runtime, and `tmux list-windows` still holds no `watchdog` window

### Requirement: The deferred-delivery queue is read, counted and never touched

The console SHALL read `state/outbox/` read-only and expose the queued entry count, the count under `held/`, the
age of the oldest queued entry and the number of forced deliveries, so that "N messages are waiting because the
PM's box was busy" is visible where the PM looks. A missing `outbox/` directory SHALL be rendered as zero, never
as an error, and the console MUST NOT create it. The console MUST NOT enqueue, claim, move or drain an entry
itself: the drain belongs to the sender, the tick and `team outbox flush` (`delivery-guard`). The console's flush
action (`f`) SHALL invoke `team outbox flush` as a subprocess and report its outcome; the renderer MUST NOT edit
the queue's files. The messages page SHALL list the queued and held entries individually and SHALL show one
entry's full text read-only and sanitized; discarding an entry is not a console action in v1.

#### Scenario: A missing queue is a zero

- **GIVEN** a fixture project with no `state/outbox/` directory
- **WHEN** `team monitor --json` and `team monitor --print` run
- **THEN** `panel.outbox.queued` is 0, the printed status band shows the zero, and `state/outbox/` still does not
  exist

#### Scenario: Queued, held and the oldest age come from the entry names

- **GIVEN** three entries named `<epoch-ms>-<seq>-pm.msg` under `state/outbox/` and one under `state/outbox/held/`
- **WHEN** `team monitor --json` runs
- **THEN** `panel.outbox.queued` is 3, `panel.outbox.held` is 1 and `panel.outbox.oldest_age_s` is the current
  time minus the oldest name's epoch in milliseconds, within two seconds

#### Scenario: Three render modes leave the queue byte-identical

- **GIVEN** a fixture project with two queued entries and their file hashes recorded
- **WHEN** `team monitor --print`, `team monitor --json` and one `team monitor --once` frame have run
- **THEN** both entries still hash the same, no file was added under `state/outbox/`, and `forced.log` and
  `HOLDING.log` did not grow

#### Scenario: Flush goes through the guard, never through the renderer

- **GIVEN** a fixture project with one queued entry and a fixture PM pane whose input box holds a draft
- **WHEN** `f` is pressed in the console
- **THEN** `team outbox flush` runs as a subprocess, the receipt reports the entry as still queued (the box was
  busy), and the entry file's hash is unchanged

#### Scenario: Entries are listed and shown read-only

- **GIVEN** two queued entries and one held entry with recorded hashes
- **WHEN** the messages page renders and one entry is viewed in full
- **THEN** both queued entries are listed with their ages, the viewed text is the file's sanitized content, and
  every file under `state/outbox/` hashes the same afterwards

### Requirement: The panel ships as one committed bundle with no install step

`team monitor` SHALL run a single committed JavaScript file (`skills/teamsmith/scripts/panel/panel.js`) through the
resolved runtime; that file SHALL run with no `node_modules` present and with no network access, so an installation
of the skill needs no package manager. The TSX sources, the build script and the pinned dependency versions SHALL be
committed next to it, and the file SHALL declare its provenance (the framework versions and the build command) so a
reader can tell a stale bundle from a current one. Rebuilding from the sources SHALL reproduce the committed file
byte for byte; that check needs the pinned dependencies installed and is therefore a release-time check, not a gate
item.

#### Scenario: A fresh checkout runs the bundle

- **GIVEN** a checkout with no `node_modules` anywhere in the repository and an empty `NODE_PATH`
- **WHEN** `node skills/teamsmith/scripts/panel/panel.js --once --print --root <fixture>` runs
- **THEN** it exits 0 and prints the panel's first band

#### Scenario: The bundle declares what built it

- **WHEN** the committed `panel.js` and `skills/teamsmith/scripts/panel/package.json` are read
- **THEN** the file's header names the pinned framework versions and the build command, and those versions equal the
  pins in `package.json`

#### Scenario: The rebuild is byte-identical

- **GIVEN** a scratch checkout and network access to the pinned registry
- **WHEN** `bun install --frozen-lockfile && bash skills/teamsmith/scripts/panel/build.sh` runs there
- **THEN** the rebuilt `panel.js` is byte-identical to the committed one (`cmp` exits 0)

### Requirement: The `TEAM_MONITOR_*` keys keep their meaning, one default changes and one key is added

`TEAM_MONITOR_REFRESH` SHALL keep its name and become the visible page's data-refresh cadence, with a default of
3 seconds (was 5): each cadence SHALL rebuild the cache once rather than poll in a loop, and the effective value
SHALL be visible as `panel.refresh_s` in `--json`. `TEAM_MONITOR_EVENTS` (default 4) SHALL keep its name and
meaning. `TEAM_MONITOR_ACTIVITY` SHALL keep its default `1`, keep accepting `0`/`1` with the flags overriding
it — the settings overlay MAY override it further, for TUI sessions only. `TEAM_MONITOR_UI` SHALL keep the
values `auto` (default), `tui` and `text`. Every one of the four keys SHALL stay documented in
`references/config.md` with its default and its effect.

#### Scenario: The redraw period is the redraw period

- **GIVEN** a fixture session and a fixture project running `TEAM_MONITOR_REFRESH=1 team monitor` in a pane
- **WHEN** the pane is captured twice with a 1.5 second gap between the captures
- **THEN** the second capture's timestamp line differs from the first, so the redraw follows the key

#### Scenario: The activity default is a documented contract change

- **GIVEN** a fixture project with `TEAM_MONITOR_ACTIVITY` unset and an event in the agent log
- **WHEN** `team monitor --print` runs, and then `TEAM_MONITOR_ACTIVITY=0 team monitor --print` runs
- **THEN** the first output contains the event and the second does not, and `references/config.md` names the
  default for that key

#### Scenario: The UI key selects the renderer

- **GIVEN** a fixture project
- **WHEN** `TEAM_MONITOR_UI=text team monitor --once` and `TEAM_MONITOR_UI=tui team monitor --once` are
  redirected to files, and `team monitor --print` is redirected as well
- **THEN** the `text` output has no `0x1b` byte and equals the `--print` output apart from the timestamp

#### Scenario: The refresh cadence defaults to three seconds and is visible

- **WHEN** `team monitor --json` runs with `TEAM_MONITOR_REFRESH` unset, and then with
  `TEAM_MONITOR_REFRESH=7`
- **THEN** `panel.refresh_s` is `3` in the first output and `7` in the second, and `references/config.md` names
  the new default

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

### Requirement: A human can write to the PM from any page

`m` on any page SHALL open a bottom input line. Enter SHALL send the draft through the guarded delivery path
(`team draft send`; the `delivery-guard` capability owns the semantics) — the console itself MUST NOT paste or
send keys into the PM's pane. Esc SHALL cancel the compose and keep the draft in `state/draft.md`, restored on
the next compose. `C-o` SHALL hand the draft to `$EDITOR` and return to an intact frame, with rendering
suspended while the editor runs; `C-e` is the line-end key, not the editor relay (the migration to pi's key map,
which the key-map requirement owns), and the compose hint SHALL name both the editor relay's key and the newline
key in the frame, in both languages. The receipt SHALL be exactly one of three honest states — delivered, queued
(the PM's box is busy) or held (a durable copy under `outbox/held/`) — mapped from the send command's
machine-readable outcome and exit code, never parsed from human prose. While composing, the input line SHALL
pause refreshing and every other block SHALL keep refreshing; multi-line input, pasted or typed, SHALL stay one
draft (a `\r` is normalized — E6 §2.2) and SHALL be sent as one message (E6 §2.1).

#### Scenario: A busy box yields an honest queued receipt

- **GIVEN** a fixture PM pane whose input box holds a draft, and the console running in another fixture pane
- **WHEN** the human composes `hello` and presses Enter
- **THEN** the receipt shows queued, exactly one entry lands in `state/outbox/`, and the PM pane's draft is
  byte-identical

#### Scenario: Esc preserves the draft across a restart

- **GIVEN** the console running in a fixture pane
- **WHEN** the human types `half a thought`, presses Esc, quits, relaunches and presses `m`
- **THEN** the input line holds `half a thought` and `state/draft.md` survived the restart

#### Scenario: The editor relay returns to an intact frame

- **GIVEN** a compose holding `raw1`
- **WHEN** `C-o` opens `$EDITOR`, a second line is appended, the editor is saved and closed, and Enter is pressed
- **THEN** the frame is intact after the handoff, the draft holds both lines, and the send enqueues exactly one
  entry holding both lines

#### Scenario: A paste is one message

- **GIVEN** a compose open in a fixture pane
- **WHEN** a three-line payload is pasted and Enter is pressed
- **THEN** the draft held all three lines and exactly one outbox entry was written

#### Scenario: The draft survives a refresh

- **GIVEN** the five-second reader stub and a compose holding `before`
- **WHEN** a refresh completes and the human then types `after`
- **THEN** the draft reads `beforeafter` and another block's timestamp advanced during the compose

#### Scenario: `C-e` moves to the line end while `C-o` is the editor relay

- **GIVEN** a fixture project whose `state/draft.md` holds `ad`, `TEAM_PANEL_EDITOR` naming a script that writes a
  marker file and appends a line to the draft file, and the console composing with the insertion point between the
  two characters
- **WHEN** `C-e` is pressed
- **THEN** the script never ran (its marker file does not exist), the draft still reads `ad` and
  `tmux display -p '#{cursor_x}'` is 6 — the key moved to the line's end
- **AND** a following `C-o` runs the script exactly once, the appended line appears in the draft, and the frame is
  intact afterwards

### Requirement: Settings are panel preferences in `state/panel.conf`, never the project contract

The settings overlay (`,`) SHALL edit exactly five preferences — language (`zh`/`en`), the default page, the
activity columns, the mouse and the density (`comfortable`/`compact`) — persisted in `state/panel.conf` and
applied immediately. The overlay SHALL additionally carry one navigation row — the project settings — which
opens the project-settings view; selecting it changes no preference, writes no file and leaves `panel.conf` alone,
and it is the only overlay row that is not a preference. A missing or corrupt `panel.conf` SHALL fall back to the
defaults and MUST NOT fail the render. The file is runtime state: it MUST NOT be read by `--print` or `--json`,
MUST NOT be read by any command other than the panel, and MUST NOT carry `TEAM_*` meanings — the overlay's
activity-columns toggle overrides `TEAM_MONITOR_ACTIVITY` for TUI sessions only. A `theme` key
(`dark`/`light`, absent = auto-detect from the terminal) MAY pin the theme; it is not an overlay item.

#### Scenario: A corrupt file falls back to defaults

- **GIVEN** a fixture project whose `state/panel.conf` holds garbage bytes
- **WHEN** `team monitor --once --print` runs and the console renders in a fixture pane
- **THEN** the print exits 0 and equals the no-preferences output apart from the timestamp, and the pane render
  uses the defaults

#### Scenario: A preference applies immediately and persists

- **GIVEN** the console running in a fixture pane with the mouse preference on
- **WHEN** the overlay toggles the mouse off, and the console is later quit and relaunched
- **THEN** the frames after the toggle emit no SGR mouse-enable sequence, and the relaunch still has it off

#### Scenario: Preferences never reach the machine exits

- **GIVEN** a fixture project and two different `state/panel.conf` files
- **WHEN** `team monitor --print` and `team monitor --json` each run under both
- **THEN** the two prints are identical apart from the timestamp and the two JSON outputs are identical

#### Scenario: The navigation row opens the view and writes no preference

- **GIVEN** the overlay open in a fixture pane, `state/panel.conf` recorded
- **WHEN** the navigation row is selected with `enter`, and `esc` returns to the overlay
- **THEN** the project-settings view rendered, `panel.conf` is byte-identical afterwards, and neither it nor the
  overlay's own frame carries a `TEAM_*` key of the contract

### Requirement: The layout is a pure function of geometry with four width tiers

For the same width, height and data the console SHALL render a byte-identical frame. Four width tiers: 160
columns and wider lays blocks out in two columns; 100–159 keeps two compact columns (the right one narrowed,
long text truncated); under 100 stacks a single column; under 60 renders the minimal form (table columns
dropped, times shortened to the clock time, states abbreviated). The degradation order — side-by-side blocks
stack first, then blocks fold into one-line summaries and collapse, then columns are dropped — SHALL be
documented, and the console MUST NOT write more rows than the height nor a row wider than the width. A terminal
resize SHALL re-layout the next frame live. `--width` and `--height` SHALL keep overriding the geometry for one
frame, and the four tiers SHALL be pinned against stored snapshots in both themes in the test suite. In a bounded
frame (the TUI's own rows, or `--height`) the two columns SHALL end on the same row: a column shorter than its
neighbour grows its **last card's** content area — blank card space, not blank page — and the work page's board
SHALL spend that spare height on its folded done/dropped history before any blank filler row appears. The
uncapped machine frames (`--print` renders without a height) keep their pre-console shape and MUST NOT gain filler
rows.

#### Scenario: The tiers render at their boundaries

- **GIVEN** a fixture project and fixture panes of 160, 100, 99, 60 and 59 columns
- **WHEN** the console renders one frame at each width
- **THEN** 160 shows two columns side by side, 100 and 99 stay dual-compact and single-column respectively, and
  59 drops the agent table's branch column and shortens times to the clock time

#### Scenario: The same geometry renders byte-identical

- **GIVEN** a fixture project with fixed state
- **WHEN** `team monitor --print --width 120 --height 29` runs twice
- **THEN** the two outputs are identical apart from the timestamp

#### Scenario: A resize re-lays out live

- **GIVEN** the console running in an 80-column fixture pane
- **WHEN** the window is resized to 160 columns
- **THEN** a following frame reflows to the dual-column tier with no restart

#### Scenario: A tiny pane is not overrun

- **GIVEN** a fixture tmux pane of 60x8
- **WHEN** the console renders one frame there and the pane is captured
- **THEN** the capture has at most 8 non-empty rows and no row is wider than 60 columns

#### Scenario: The two columns end on the same row

- **GIVEN** a fixture project whose overview renders a short agent card beside a taller activity card, and whose
  work page renders a board with folded history beside a taller right column
- **WHEN** the console renders one bounded frame of each page
- **THEN** the agent card's bottom border lands on the taller card's bottom row (its content area gained the
  blank rows) and the board shows the folded done/dropped rows instead of a blank card bottom, while
  `team monitor --print` stays at its old line count

### Requirement: Every key affordance is also a mouse target

With the mouse preference on, the console SHALL enable SGR mouse reporting for its lifetime and disable it on
exit, and every documented key — `m`, `f`, `s`, `,`, Tab, `1`–`4`, `↑`/`↓`, `q`, on the board page `←`/`→` and
Enter, and on the work page the board rows (a click focuses a row, a click on the focused row opens its detail) —
SHALL have a clickable target that acts identically; the wheel SHALL scroll the current page's scrollable region
(one offset per page, one line per notch on pages 1–3 — V15 F5 ruling; on the work page `↑`/`↓` move the board-row
focus and the wheel keeps scrolling the page; on the board page each lane carries its own offset and the wheel
SHALL scroll the lane under the cursor). While the project-settings view is open the wheel is its region and MUST
NOT reach the page the view was opened from: it scrolls the view's row window — one row per notch, the row focus
unchanged, the view's hidden-row counts at both edges following the window — and with either of the view's
pickers open it walks that picker's entries instead; the `↑`/`↓` keys and the view's `↑/↓ 行` target SHALL keep
moving the focus and SHALL push the window so the focused row is inside it. A click on a kanban card SHALL focus it, and a click on the already
focused card SHALL open its detail view. Coordinates are 1:1: a click on a target activates that target (E6 §1.1 measured the full path, with
tmux's own mouse option in either state). With the preference off the console SHALL emit no mouse-reporting
sequence and clicks SHALL do nothing. The settings overlay is an in-page overlay, not a modal: it replaces the
page's blocks but keeps the title band, the tabs and the key band, so the footer chips still visible under it
stay clickable and act exactly as they do with the overlay closed, while the replaced blocks keep **no**
targets — a click at a block's former coordinates does nothing (V16 F-V16-4, ruled as the actual behaviour).
The same replacement rule SHALL apply to the detail view: while it is open, the kanban's cards keep no targets,
and so do the work page's board rows. `r` (rebuild the cached blocks on demand) is a named exception, because it is
a keyboard-only key: it has no chip in the key band and MUST NOT appear in the frame's target map, so "every
affordance is clickable" counts only the affordances the console shows (V16 F-V16-5). `pageUp`/`pageDown` are the
second named exception: they exist so the work page stays scrollable by keyboard once `↑`/`↓` move the board-row
focus, they carry no chip (the band is width-bounded), and they MUST NOT appear in the target map either.

#### Scenario: A click acts like the key

- **GIVEN** the console running in a fixture pane with the mouse preference on
- **WHEN** the pty driver injects a left press and release on the `m` hint's coordinates
- **THEN** the compose line opens

#### Scenario: A card click focuses, a second click opens

- **GIVEN** the console on the board page in a fixture pane with the mouse preference on
- **WHEN** a click lands on a card, and a second click lands on the same (now focused) card
- **THEN** the first click moves the focus marker onto that card and the second opens its detail view

#### Scenario: The wheel scrolls the page's scrollable region

- **GIVEN** the same fixture with more events than the events block can show, on one of pages 1–3
- **WHEN** wheel-down and wheel-up sequences are injected over the block
- **THEN** the visible window of events shifts down and back

#### Scenario: The wheel scrolls the lane under the cursor

- **GIVEN** the same fixture on the board page with a `done` lane holding more cards than its window
- **WHEN** wheel-down and wheel-up sequences are injected over that lane
- **THEN** that lane's visible window shifts down and back, the other lanes do not move, and the focus does not
  change

#### Scenario: Off means silent

- **GIVEN** the console running with the mouse preference off
- **WHEN** a frame is captured and a click is injected on the `m` hint
- **THEN** the capture contains no SGR mouse-enable sequence and the compose line stays closed

#### Scenario: The overlay keeps the visible footer live and the page behind it dead

- **GIVEN** the console running in a fixture pane with the mouse preference on and the settings overlay opened
  with `,`
- **WHEN** a click is injected on the still-visible `m` chip in the key band, and then one at the coordinates a
  page block occupied before the overlay opened
- **THEN** the compose line opens — the chip acted like the key, so the overlay does not modalize the footer —
  while the second click changes nothing: the blocks the overlay replaced keep no targets

#### Scenario: The refresh key is deliberately keyboard-only

- **GIVEN** a rendered frame and its click-target map with the mouse preference on
- **WHEN** the documented keys are enumerated against the map
- **THEN** every documented key except `r` has a target and the map carries no entry that refreshes the cached
  blocks, while pressing `r` still rebuilds them — the key has no clickable affordance by design

#### Scenario: The wheel scrolls the settings view's window

- **GIVEN** the project-settings view open at the top on a fixture contract with more rows than the pane shows
- **WHEN** three wheel-down notches are injected over the view
- **THEN** the visible window moves down three rows (the row that was first is gone and a later one entered), the
  row focus does not move (the view's command line still names the same key), and the top count line reads `↑3`
- **AND** three wheel-up notches bring the window back to the top and the count line disappears

#### Scenario: The wheel over the view does not move the page behind it

- **GIVEN** a page scrolled away from its top, the project-settings view opened over it, and the page's window
  recorded
- **WHEN** wheel events are injected over the view and `esc` returns to the page
- **THEN** the page renders the same window it had before the view opened — the view consumed the wheel
- **AND** with the choice editor `enter`ed open, or with the seat picker open, the wheel walks that picker's
  entries (the selection moves, the page still does not) and `esc` afterwards keeps that picker closed
- **AND** with the mouse preference off the same wheel emits no report and neither the view nor the page moves

#### Scenario: The focus keys keep the focused row inside the window

- **GIVEN** the view wheel-scrolled so the focused row is outside the visible window
- **WHEN** `↓` or `↑` moves the focus, and `enter` opens the focused row
- **THEN** the window has been pushed so the focused row is visible, and the row the editor was opened for is the
  row the view's command line names

### Requirement: All visible text comes from external zh/en string tables

Every string the console renders SHALL come from the string tables — one table per language, `zh` and `en` at
minimum — and the two tables SHALL hold identical key sets with the same value shapes and no empty values. A
machine-checkable assertion of the key-set equality SHALL run in the gate (`skills/teamsmith/tests/smoke.sh`).
Switching the language preference SHALL take effect on the next frame. The Chinese table SHALL name the PM↔agent
correspondence records `往来` — `线程` reads as an operating-system thread — so the messages page's block reads
`收件箱与往来`, its per-agent line reads `收件箱 {inbox} 条 · 往来 {thread} 条 · {age}` and its empty state reads
`（没有收件箱/往来记录）`; the `en` values of those three keys, the directory `docs/team/threads/`, the command
`team thread` and the English term `thread` SHALL NOT change. The tables SHALL also carry the migrated compose
hint's keys (the editor relay's and the newline key's) in both languages.

#### Scenario: The key sets are asserted equal

- **GIVEN** the shipped string tables
- **WHEN** the key-set assertion runs, and then runs again with one key deleted from the `en` table
- **THEN** the first run exits 0 and the second exits non-zero naming the missing key

#### Scenario: The language switches live

- **GIVEN** the console running in a fixture pane in `zh`
- **WHEN** the overlay switches the language to `en`
- **THEN** a following frame's static labels are English

#### Scenario: The messages page names the records 往来, not 线程

- **GIVEN** a fixture project whose inbox block has one agent row, the console on the messages page in `zh`, and the
  committed `panel.js` bundle
- **WHEN** the frame renders
- **THEN** the capture contains `收件箱与往来` and its counts line names `往来`, and no captured line contains
  `线程`
- **AND** `grep -c '线程' skills/teamsmith/scripts/panel/src/strings/zh.ts` prints 0 while the `en` table still
  carries `inbox and threads`

### Requirement: State is never carried by color alone

Every status the console shows SHALL be expressed by an icon or text token as well as by color, so a capture
with no color information still carries the state. The dark and light themes SHALL both be selectable — the
terminal's background decides by default, the `theme` key in `state/panel.conf` pins it — and each theme's
declared text/background pairs SHALL meet a contrast ratio of at least 4.5:1, checked by a gate script over the
declared palette.

#### Scenario: A monochrome capture still carries the state

- **GIVEN** a fixture project whose PM is absent and whose board holds one `blocked` row
- **WHEN** the overview renders in a fixture pane and is captured as plain text
- **THEN** the capture contains the `absent` and `blocked` tokens beside their icons, in either theme

#### Scenario: The palette meets the contrast bar

- **GIVEN** the two shipped themes
- **WHEN** the contrast script runs over the declared pairs, and then runs again with one pair forced below
  4.5:1
- **THEN** the first run exits 0 and the second exits non-zero naming the pair

### Requirement: The console composes four pages and remembers the position

The TUI SHALL compose four pages — an overview (the status banner, the project-progress counts, the recent
deliveries, the agent table, the capacity sparkline and the recent events), a work page (the board rows, the
active changes with their phases, the spec counts and the recent decisions), a messages-and-logs page (the
deferred queue, the inbox and threads, the patrol log, the capacity trend and the health block) and a board page
(the kanban of "The board page is a kanban over the board's states") — plus a settings overlay. A block whose
source has no data SHALL collapse and yield its space. Tab and the keys `1`–`4` SHALL switch pages, and the
current page SHALL be written to `state/panel-page` and restored on the next start; a value outside `1`–`4` in
that file SHALL fall back to the default page, never fail the render. Pages are a TUI-only concept: `--print`
and `--json` render the overview content.

#### Scenario: Pages switch and the position survives a restart

- **GIVEN** the console running in a fixture pane of a fixture project
- **WHEN** `4` is sent, the console is quit and relaunched, and `1` is sent
- **THEN** the capture after `4` shows the board page's lanes, the relaunch opens on the board page
  (`state/panel-page` holds it), and `1` returns to the overview

#### Scenario: An out-of-range page file falls back

- **GIVEN** a fixture project whose `state/panel-page` holds `9`
- **WHEN** the console starts in a fixture pane
- **THEN** it renders the default page and exits no error

#### Scenario: An empty block collapses

- **GIVEN** a fixture project with no active changes
- **WHEN** the work page renders in a fixture pane
- **THEN** the changes block is absent from the capture and the page's other blocks render fully

#### Scenario: The messages page lists the queue

- **GIVEN** a fixture project with two queued outbox entries
- **WHEN** the messages page renders
- **THEN** both entries are listed with their ages

### Requirement: The board page is a kanban over the board's states

The board page SHALL render every BOARD.md row as a card in one of six state lanes, in the fixed order the
BOARD.md header legend declares (`todo`, `wip`, `review`, `done`, `blocked`, `dropped`). Every lane SHALL render
even when it holds no card — an empty lane shows a dim empty marker — so lanes never shift position between
frames. A card SHALL carry the entry's id, title, agent, state glyph and the phase token from its task brief's
`phase:` header (an entry with no brief or no `phase:` line renders a placeholder), truncated to the lane width.
At 100 columns and wider the lanes SHALL be side by side with an even share of the usable width; under 100
columns the page SHALL degrade to a single column grouped by state in the same lane order; under 60 columns a
card SHALL shrink to one line (state glyph, id, title — the agent and phase drop). The focused card SHALL be
marked by a cursor glyph and the `selected` tone — never by color alone — and SHALL be tracked by **row
identity**: the entry id together with the row's occurrence among the rows carrying that id, in BOARD.md order.
A refresh that reorders or extends the board, a lane change, and a click MUST all keep addressing the same row,
two rows that share an id are two separate stops with the cursor on exactly one of them, and when the focused row
leaves the board the first row carrying its id SHALL take the focus — when no row carries the id, the lane's
first card SHALL take the focus. A lane holding more cards than its visible window SHALL scroll (`↑`/`↓` past the
edge, and the wheel over the lane) and SHALL mark each edge that hides cards with their count. The lane windows
of the `done` and `dropped` history lanes SHALL anchor on the newest cards.

#### Scenario: Six lanes at the reference geometry

- **GIVEN** a fixture project whose BOARD.md holds rows in `todo`, `wip`, `review` and `done`, and the console on
  the board page in a 160-column fixture pane
- **WHEN** one frame renders
- **THEN** the capture shows the six lane headers in the legend order, the cards under their states, and the
  `blocked` lane with an empty marker

#### Scenario: A card carries id, agent, phase and title

- **GIVEN** a fixture row `M9` whose task brief's header declares `phase: apply`, and a row `X1` with no task
  brief
- **WHEN** one board-page frame renders at 160 columns
- **THEN** M9's card shows `M9`, its agent, the `apply` token and its title, and X1's card shows the placeholder
  where the phase would be

#### Scenario: Narrow terminals degrade to one grouped column

- **GIVEN** the same fixture
- **WHEN** the board page renders one bounded frame at 99 columns and one at 59 columns
- **THEN** both frames stack the states in a single column in the legend order, and the 59-column frame renders
  one line per card (state glyph, id, title) with no agent field

#### Scenario: The focus survives a refresh

- **GIVEN** the console on the board page in a fixture pane with the focus on entry `M9`
- **WHEN** a refresh rebuilds the board block with `M9`'s row at a different position, and later with `M9` gone
- **THEN** the focus marker still sits on `M9` after the first refresh, and lands on that lane's first card
  after the second

#### Scenario: A long lane scrolls and counts what it hides

- **GIVEN** a fixture board whose `done` lane holds 20 cards and a lane window of six cards
- **WHEN** the board page first renders, and the focus then moves down past the window's edge
- **THEN** the first frame shows the newest six `done` cards with a `+14` style count at the bottom edge, the
  window scrolls with the focus, and wheel-down over the lane scrolls it without moving the focus

#### Scenario: Two rows with one id are two stops

- **GIVEN** a board whose drawn rows are `M39` (title "first duplicate", agent `dev1`), `M39` (title "second
  duplicate", agent `dev2`) and `M48`, and the console on the board page
- **WHEN** the page renders, `↓` is pressed twice, `r` refreshes, then `enter` opens the detail and `esc` returns
- **THEN** exactly one row carries the cursor glyph at every step; the first `↓` stops on the second `M39` row
  (the same id, the next occurrence — not a frozen cursor), the second `↓` reaches `M48`, `↑` twice returns to
  the first `M39` row, and after `r`, `enter` and `esc` the cursor is still on the second `M39` row, with the
  `M39` detail view opened in between

### Requirement: A focused card opens a read-only markdown detail view

Enter (or a click on the already focused card, on the board page's kanban or on the work page's board rows) SHALL
open a detail view that replaces the page's blocks — as
with the settings overlay, the title band, the page tabs and the key band stay — and renders the entry's
associated files as terminal markdown. The associated files SHALL be discovered read-only by entry id:
`docs/team/tasks/<ID>-*.md`, `docs/team/reports/<ID>-*.md` (files, not directories) and
`docs/team/reviews/<ID>.md` together with `docs/team/reviews/<ID>-*.md`, where the character after `<ID>` must
be `.` or `-`, so entry `P1` never matches `P17`'s files. Multiple files SHALL be presented as switchable tabs
(`←`/`→`, or a click on the tab), the first tab open by default. The renderer SHALL preserve the document's
structure — ATX headings as heading-tone lines, fenced code blocks verbatim in a dim tone, pipe tables aligned
by display width, lists and blockquotes kept, inline bold/code/links as tone spans — and SHALL render any
construct outside that subset as its source text, never dropped and never an error. File content SHALL be
bounded (a file over 128 KiB is cut and carries a truncation marker), SHALL pass the sanitizer like every other
disk string, and SHALL be assembled off the input path as a console-only data block that builds only while the
view is open; the first detail frame SHALL render within one second of Enter on the reference checkout. The
view SHALL be read-only: it adds no action key. Esc or `q` SHALL return to the page the view was opened from — the
board page from a card, the work page from a board row — and SHALL NOT collapse the console — a documented
exception to the global `q`, in force only while the detail view is open. The reader
MUST NOT serve a path outside the discovered set: a `--file` argument naming any other path SHALL fail.

#### Scenario: The three families are discovered and the id boundary holds

- **GIVEN** a fixture entry `P1` with `docs/team/tasks/P1-a.md`, `docs/team/reports/P1-dev.md`,
  `docs/team/reviews/P1.md` and `docs/team/reviews/P1-done.md`, and a decoy `docs/team/tasks/P17-b.md`
- **WHEN** `P1`'s detail view opens
- **THEN** the tab row names exactly four files (brief, report, review, done-review) and never the decoy

#### Scenario: Markdown structure survives the render

- **GIVEN** a fixture brief holding an ATX heading, a fenced code block, a pipe table, a bullet list and a link
- **WHEN** the detail view renders it
- **THEN** the table's columns are display-width aligned, the fence body appears verbatim, the heading renders
  without its `##` marker, and the link shows its text followed by the URL

#### Scenario: Hostile bytes in a file cannot inject escape sequences

- **GIVEN** a fixture file whose fenced code block embeds `ESC [2J`
- **WHEN** the detail view renders that file in a fixture pane and the pane is captured
- **THEN** the capture contains no `0x1b` byte and still shows the fence's visible text

#### Scenario: A large file is bounded and fast

- **GIVEN** a fixture report of 200 KiB
- **WHEN** `team __panel-data --block detail --id <ID>` runs and the detail view opens on that file
- **THEN** the reader exits 0 within one second, the view carries a truncation marker, and the first frame
  renders within one second of Enter on the reference checkout

#### Scenario: The reader refuses a path outside the discovered set

- **GIVEN** the fixture entry `P1` above
- **WHEN** `team __panel-data --block detail --id P1 --file ../../BOARD.md` runs, and when `--file` names
  `docs/team/tasks/P17-b.md`
- **THEN** both exit non-zero and neither prints the file's content

#### Scenario: Esc and `q` return without collapsing the console

- **GIVEN** the console on the board page in a fixture pane with a detail view open
- **WHEN** `q` is sent, and the detail is reopened and Esc is sent
- **THEN** both times the capture is back on the board page and the window's process is still the console
  renderer, not the headless tick loop

#### Scenario: The detail view writes nothing

- **GIVEN** a fixture project with the hashes of `state/` and `docs/` recorded
- **WHEN** the detail view is opened, its tabs switched, its document scrolled and the view closed
- **THEN** no file outside the console's own three (`state/draft.md`, `state/panel.conf`, `state/panel-page`)
  changed

### Requirement: A bounded frame fills the pane: the footer is the last row and the content absorbs the spare height

When the console renders into a bounded height — the TUI's pane, or `--height` for one frame — the frame SHALL
occupy exactly that height: the key band SHALL be the frame's last row, no all-blank row SHALL appear below it,
and any height the content does not naturally use SHALL be spent inside the content area in the documented order
(the board's folded history first, then more cards per kanban lane / more document rows in the detail view, then
the last card's blank content space). Rendering only as tall as the natural content and letting the footer float
mid-frame — the behavior measured on 2026-09-18 (≈29 rows rendered regardless of pane height, the 120x29 design
baseline) — is what this requirement forbids. The uncapped `--print` frame SHALL keep its pre-console shape and
MUST NOT gain filler rows.

#### Scenario: The footer is pinned at every height (the flip)

- **GIVEN** a fixture project whose natural overview content is about 30 rows
- **WHEN** `team monitor --print --width 120 --height 40` runs
- **THEN** the output is exactly 40 rows, the last row is the key band, and no row below the content is blank —
  the pre-change behavior (~30 rows with the key band mid-frame) fails this check

#### Scenario: More height shows more content, not more blank

- **GIVEN** a fixture project whose board holds folded `done`/`dropped` history
- **WHEN** one bounded work-page frame renders at height 40 and one at height 60
- **THEN** the 60-row frame shows strictly more board rows than the 40-row one, and both end on the key band

#### Scenario: The kanban and the detail view spend the height too

- **GIVEN** a fixture board whose `done` lane holds 20 cards, and a fixture brief longer than one screen
- **WHEN** the board page renders at heights 40 and 60, and the detail view renders at heights 40 and 60
- **THEN** the taller frames show strictly more lane cards and strictly more document rows respectively, with
  the key band as the last row in all four

#### Scenario: A tiny pane is pinned and not overrun

- **GIVEN** a fixture tmux pane of 60x8
- **WHEN** the console renders one frame there and the pane is captured
- **THEN** the capture has at most 8 non-empty rows, no row is wider than 60 columns, and the last non-empty row
  is the key band

#### Scenario: The uncapped print gains nothing

- **GIVEN** a fixture project with fixed state
- **WHEN** `team monitor --print` runs without a height override
- **THEN** its output is byte-identical to the pre-change output apart from the timestamp — no filler rows

### Requirement: The compose line edits at an insertion point, not only at its end

`m` on any page SHALL open the compose line with an editing cursor: the draft SHALL be addressed as codepoints with
an insertion point, and every text edit — a typed key, Backspace, a bracketed paste, `C-v` — SHALL apply at that
point, never at the end of the draft; opening a compose SHALL place the insertion point at the end of the draft it
restores from `state/draft.md`. `←` and `→` SHALL step the insertion point by one codepoint across explicit line
breaks and wrapped rows alike, `↑` and `↓` SHALL move it to the previous and next **visual** row at the same display
column, clamped to the shorter row, and `Home`/`End` (and their pi aliases, named by the key-map requirement) SHALL
move it to the start and the end of the **logical** line — the `\n`-separated line, so a wrapped line is one line
for them. A wide glyph (CJK, emoji) SHALL be one step of `←`/`→`, SHALL count as its two columns for the cursor
column and for `↑`/`↓`, and SHALL never be half-deleted. The terminal cursor SHALL be placed on the insertion point
— on the row the draft is drawn on, at that point's display column — so `tmux display -p '#{cursor_x}'` and
`tmux display -p '#{cursor_y}'` name the insertion point of the frame a `capture-pane` shows, for a draft on its
first row, on a wrapped row and after an explicit line break alike. While composing, the input area SHALL stay the
last block of the frame (nothing renders below it but the in-flight-send notice and the hint above the draft) and
SHALL be windowed: it MUST NOT show more than half of the pane's rows, it SHALL always contain the insertion
point's row, and the draft rows the window hides SHALL be counted on the window's edge. Everything the compose line
does today SHALL keep its meaning: Enter sends, Esc keeps the draft in `state/draft.md`, `C-o` relays to `$EDITOR`
(the key-map requirement's migration), a pasted `\r` stays one draft sent as one message, and the send path, the
three receipt states, the draft guard and the standby-reason rule are unchanged.

#### Scenario: Typing and Backspace act at the insertion point, and a wide glyph is one step

- **GIVEN** the console composing in a 120x30 fixture pane at the default (comfortable) density, the draft empty
- **WHEN** `ad` is typed, `←` is pressed, `中文` is typed, `←` is pressed and Backspace is pressed
- **THEN** the capture shows `> a文d` and `state/draft.md` holds `a文d`, and `tmux display -p '#{cursor_x}'` is 5
  (the tray's 2 columns plus the 3 display columns of `> a`)
- **AND** one `→` moves the insertion point by one codepoint over a glyph that is two columns wide
  (`#{cursor_x}` becomes 7), and the next Backspace removes the whole `文` (`state/draft.md` becomes `ad`)

#### Scenario: A wrapped draft keeps the cursor on the row it is drawn on

- **GIVEN** a 40-column fixture pane at the default density, `state/draft.md` holding 40 `x` characters (36 on the
  first drawn row and 4 on the wrapped row), and the console composing — the insertion point at the end of the
  draft, on the wrapped row, `#{cursor_x}` 8
- **WHEN** `Home` is pressed, then `Z` is typed
- **THEN** the capture's row `#{cursor_y}` is the first drawn row of the draft (the row that shows the 36 `x`) and
  `#{cursor_x}` is 5 — the tray, the prompt and the typed `Z` — because `Home` moved the insertion point to the
  logical line's start, which is that row
- **AND** `state/draft.md` is `Z` followed by the 40 `x`: the insertion landed where the cursor was moved, not at
  the end of the draft

#### Scenario: Vertical movement clamps to the shorter row

- **GIVEN** a 40-column fixture pane at the default density, `state/draft.md` holding `ab`, a line break and 8 `X`
  characters, and the console composing (the insertion point at the end of the draft, `#{cursor_x}` 12)
- **WHEN** `↑` is pressed
- **THEN** the capture's row `#{cursor_y}` is the row that shows `ab` and `#{cursor_x}` is 6 (the tray, the prompt
  and `ab`), while the capture still shows all 8 `X` on the other row

#### Scenario: Home, End and `↑` move between the rows of a broken line

- **GIVEN** a fixture project whose `state/draft.md` holds `alpha\nbeta` and the console composing at the default
  density in a 120x30 pane (the insertion point at the end of the draft, on the `beta` row, `#{cursor_x}` 8)
- **WHEN** `Home` is pressed, then `End`, then `↑`, then `X` is typed
- **THEN** the capture's row `#{cursor_y}` is the row that shows `alpha`, `#{cursor_x}` is 9 (the tray, the prompt
  and `alphX`), and `state/draft.md` reads `alphXa\nbeta` — the `↑` moved the insertion point to the other row, so
  the `X` did not land at the end of the draft

#### Scenario: A draft longer than the pane is windowed around the insertion point

- **GIVEN** a 120x20 fixture pane and `state/draft.md` holding 30 lines `L01`…`L30`, and the console composing (the
  insertion point at the end of the draft, on the `L30` row)
- **WHEN** the frame renders
- **THEN** the capture shows at most 10 draft rows, one of them holds `L30` and the insertion point, and a marker
  counts the draft rows the window hides above
- **AND** the overview frame still renders above the input area and `state/draft.md` still holds all 30 lines

#### Scenario: The window follows the insertion point

- **GIVEN** the same fixture with the compose open (the insertion point on the `L30` row)
- **WHEN** `↑` is pressed 12 times
- **THEN** the capture's window still contains the insertion point's row (now `L18`) and the hidden-rows marker
  counts fewer lines above than before

### Requirement: The compose line's key map is pi's editor key map

The compose line SHALL bind pi's editor keys (pi's `tui.editor.*` defaults) so that muscle memory carries over:
`←`/`→` and `ctrl+b`/`ctrl+f` step one codepoint; `alt+←`/`ctrl+←`/`alt+b` and `alt+→`/`ctrl+→`/`alt+f` step one
word; `Home`/`ctrl+a` and `End`/`ctrl+e` move to the logical line's start and end; `pageUp`/`pageDown` move by a
page of the draft's visual rows; `backspace` deletes the codepoint before the insertion point and
`delete`/`ctrl+d` the codepoint after it; `ctrl+w`/`alt+backspace` delete the word before the insertion point and
`alt+d`/`alt+delete` the word after it; `ctrl+u` and `ctrl+k` delete to the logical line's start and end. A word
SHALL be delimited the way pi delimits it — the platform word segmenter over the logical line — so punctuation and
CJK behave as they do in pi. Every one of these bindings SHALL work in both encodings a terminal may use: the legacy
one (`ctrl+a` as `0x01`, `alt+b` as `ESC b`, …) and the Kitty keyboard protocol one (`CSI <codepoint>;<modifiers>u`);
the pty fixtures send the Kitty bytes directly, so the bindings are testable without a Kitty-capable terminal. A
`ctrl`- or `alt`-modified key with no binding (e.g. `ctrl+c`) SHALL change nothing — it MUST NOT insert its letter
into the draft. Only `enter` SHALL submit and only `esc` SHALL cancel: no other key MAY leave the compose line.

#### Scenario: The word, line and forward-delete keys act where the insertion point is

- **GIVEN** a fixture project whose `state/draft.md` holds `alpha beta gamma` and the console composing at the
  default density in a 120x30 pane (the insertion point at the end of the draft, `#{cursor_x}` 18)
- **WHEN** `ctrl+w` is pressed, then `alt+b`, then `ctrl+d`, then `ctrl+k`, then `ctrl+a`, then `Z` is typed
- **THEN** `state/draft.md` reads `Zalpha ` and `#{cursor_x}` is 5 (the tray, the prompt and the `Z`): `ctrl+w`
  deleted `gamma` with its space, `alt+b` stepped one word left, `ctrl+d` deleted one codepoint forward, `ctrl+k`
  deleted to the logical line's end, and `ctrl+a` moved to the line's start where the `Z` landed
- **AND** `esc` is the only way the draft was left (`enter` was never pressed): the fixture's PM pane submitted
  nothing

#### Scenario: Line operations use the logical line, not the drawn row

- **GIVEN** a 40-column fixture pane at the default density and `state/draft.md` holding one 45-character line (two
  drawn rows) followed by a line break and `second`, and the console composing (the insertion point at the end of
  the draft)
- **WHEN** `↑` is pressed, then `ctrl+a`, then `ctrl+k`
- **THEN** `state/draft.md` is `\nsecond` — the whole 45-character logical line went, not just the 36 characters of
  the drawn row `↑` did not land on
- **AND** `tmux display -p '#{cursor_x}'` is 4 (the tray and the prompt) on the first drawn row, now empty

#### Scenario: The Kitty encoding of a bound key behaves like the legacy one

- **GIVEN** a fixture project whose `state/draft.md` holds `alpha beta` and the console composing (the insertion
  point at the end of the draft)
- **WHEN** the Kitty bytes for `ctrl+b` (`\x1b[98;5u`) are sent three times, and then the Kitty bytes for `alt+b`
  (`\x1b[98;3u`) once
- **THEN** `state/draft.md` is unchanged and `#{cursor_x}` is 10 — three codepoints back (`alpha b|eta`) and then one
  word back (`alpha |beta`; `│ > alpha ` is ten columns) — exactly as the same sequence sent as the legacy bytes
  (`0x02` ×3 then `ESC b`) moves it

### Requirement: The compose line has pi's kill ring and undo

Deleting in the compose line SHALL be recoverable the way pi makes it recoverable. Every deletion — `backspace`,
`delete`, `ctrl+w`, `alt+backspace`, `alt+d`, `alt+delete`, `ctrl+u`, `ctrl+k` — SHALL push its text onto a bounded
kill ring, and consecutive deletions of the same kind SHALL accumulate into the newest entry instead of filling the
ring (`ctrl+w` twice in a row is one entry holding both words, in the order they were cut); `ctrl+y` SHALL insert
the newest entry at the insertion point and `alt+y`, pressed immediately after a yank, SHALL replace that inserted
text with the next-older entry. `ctrl+-` SHALL undo the last edit — an insertion, a deletion, a yank or a paste —
restoring both the draft and the insertion point as they were before it; the undo history SHALL be bounded and SHALL
be discarded when the compose opens and when `$EDITOR` hands the draft back. `ctrl+-` is reported only through the
Kitty keyboard protocol (a terminal that does not report it leaves the key unbound, and the compose line produces
no text for it), so that path SHALL be exercised through the protocol's encoding.

#### Scenario: A deletion yanks back, and `alt+y` pops the older one

- **GIVEN** a fixture project whose `state/draft.md` holds `alpha beta gamma` and the console composing at the
  default density in a 120x30 pane (the insertion point at the end of the draft)
- **WHEN** `ctrl+w` is pressed (the word `gamma` and the space before it are cut), then `ctrl+a`, then `ctrl+k`
  (the rest of the line is cut as a newer entry), then `ctrl+y`, then `alt+y`
- **THEN** `state/draft.md` is ` gamma`: the first `ctrl+y` put `alpha beta` back and `alt+y` replaced it with the
  older entry — so both deletions were in the ring and the pop walked it

#### Scenario: Undo restores the draft and the insertion point

- **GIVEN** a fixture project whose `state/draft.md` holds `ad`, the insertion point between the two characters, and
  `#{cursor_x}` 5
- **WHEN** `Z` is typed, then the Kitty bytes for `ctrl+-` (`\x1b[45;5u`) are sent
- **THEN** the capture and `state/draft.md` hold `ad` again and `tmux display -p '#{cursor_x}'` is 5 — both the text
  and the insertion point came back, not just the text
- **AND** the same Kitty bytes sent once more change nothing (the history is empty at the draft it opened on)

### Requirement: The compose line edits multiple lines, and `ctrl+j` is the newline key

The compose line SHALL edit a multi-line draft: `ctrl+j` SHALL insert a line break at the insertion point, and
`enter` SHALL keep submitting the draft exactly as today. A terminal sends `\n` for `ctrl+j` and `\r` for `enter`,
so the compose line SHALL read a lone `\n` as the newline key and a lone `\r` as submit; the consequence SHALL be
explicit and documented rather than silent: a terminal that reports its Enter key as `\n` inserts a line break
instead of submitting (pi's editor behaves the same way, and such terminals are rare). `shift+enter` SHALL insert a
line break when the terminal reports it (`CSI 13;2u`, i.e. the Kitty keyboard protocol — see the key-map
requirement) and SHALL behave as `enter` when it does not, so no terminal shows a binding that silently does
nothing. A newline inside a paste SHALL keep today's meaning: it is part of the pasted text, the draft stays one
draft and it is sent as one message (the bracketed-paste handling is unchanged). In standby-reason mode the draft is
one line — a line break, typed or pasted, SHALL become a single space — so the reason handed to
`team standby on --reason` never contains a newline. The multi-line draft's path out of the console SHALL be the
unchanged one: `state/draft.md` holds LF, `team draft send` delivers a multi-line draft as one message (bracketed
paste) or as a file plus a pointer, and the delivery guard, the three receipts and the standby-reason rule are
untouched.

#### Scenario: The legacy `ctrl+j` byte inserts a line break, and Enter still submits

- **GIVEN** a fixture project with a fake TUI in the PM pane and the console composing `ad`, the insertion point at
  the end of the draft
- **WHEN** the raw `\n` byte is sent, then `b` is typed, then `\r`
- **THEN** the capture shows the draft on two rows and `state/draft.md` held `ad\nb` before the submit, the PM's
  fixture received exactly one message, and that message carried both lines

#### Scenario: The Kitty `ctrl+j` and `shift+enter` bytes insert a line break

- **GIVEN** the same fixture with the compose open and the draft `ad`
- **WHEN** the Kitty bytes for `ctrl+j` (`\x1b[106;5u`) are sent, `b` is typed, the Kitty bytes for `shift+enter`
  (`\x1b[13;2u`) are sent and `c` is typed
- **THEN** `state/draft.md` is `ad\nb\nc` and nothing was submitted

#### Scenario: A pasted newline is still one draft and one message

- **GIVEN** the same fixture with the compose open and the draft empty
- **WHEN** a three-line payload is pasted and `\r` is pressed
- **THEN** the draft held all three lines and the PM's fixture received exactly one message carrying all three —
  the newline key changed nothing about the paste path

#### Scenario: A standby reason is one line

- **GIVEN** a fixture project whose `state/draft.md` holds `half a thought` and a `team` CLI wrapper that logs each
  invocation with its arguments, and the console composing a standby reason (`s`)
- **WHEN** a three-line payload is pasted into the reason and `\r` is pressed
- **THEN** the wrapper's log shows `standby on --reason` with the three parts separated by spaces and no newline in
  the argument, the standby state's reason is that one line, and `state/draft.md` still holds `half a thought`

### Requirement: `C-v` pastes a clipboard image as a temporary file path

While composing, `C-v` SHALL paste the clipboard's image, when the clipboard offers one, as the path of a temporary
file: the image bytes SHALL be written to `${TMPDIR:-/tmp}/teamsmith-paste-<uuid>.<ext>` — `<ext>` from the MIME
type, `png` for `image/png` and `jpg`/`webp`/`gif` for those three — and that path SHALL be inserted at the
insertion point as one draft edit, in message mode and in standby-reason mode alike. The probe SHALL consult
`wl-paste` first and `xclip -selection clipboard` second, SHALL accept only those four MIME types, and SHALL be
bounded (the offered-type list within 1 s, the byte read within 3 s and 50 MiB), so a clipboard tool that never
answers cannot hold the console. The probe MUST NOT run on the render or refresh path: only a `C-v` press starts it,
the frame SHALL keep rendering while it runs, and typing SHALL keep landing in the draft. The panel MUST NOT delete
the file it wrote. When the clipboard holds no image (no image type offered, no bytes, a type outside the four, or
neither `wl-paste` nor `xclip` on `PATH`), `C-v` SHALL fall back to pasting the clipboard's text at the insertion
point; when that too is unavailable, `C-v` SHALL change nothing — draft, `state/draft.md`, the frame and the
console's liveness unaffected, with no error line and no new file. The standby reason SHALL NOT write
`state/draft.md` (the existing rule), whatever a paste into it does.

#### Scenario: An image clipboard becomes a path at the insertion point

- **GIVEN** a fixture whose `TMPDIR` is inside the fixture and whose `PATH` holds a fake `wl-paste` that offers
  `image/png` and returns 8 known bytes for the image read, and a compose holding `ad` with the insertion point
  between the two characters
- **WHEN** `C-v` is pressed and the paste settles
- **THEN** the fixture's `TMPDIR` holds exactly one `teamsmith-paste-*.png` file whose contents are those 8 bytes,
  and `state/draft.md` is `a<that path>d`
- **AND** the capture shows that path and the console is still composing, so the next typed character lands in the
  draft

#### Scenario: The probe is Wayland first, X11 second

- **GIVEN** a fixture `PATH` holding a fake `wl-paste` that exits non-zero and logs its call, and a fake `xclip`
  that logs its call, offers `image/png` for the offered-type list and returns 8 known bytes for the image read
- **WHEN** `C-v` is pressed and the paste settles
- **THEN** a `teamsmith-paste-*.png` file with those 8 bytes exists, its path is in the draft, and the call log
  names `wl-paste` before `xclip`

#### Scenario: No image falls back to the clipboard's text

- **GIVEN** a fixture whose fake `wl-paste` offers only `text/plain;charset=utf-8` and returns
  `from the clipboard` for the text read, and a compose holding `ad` with the insertion point between the two
  characters
- **WHEN** `C-v` is pressed and the paste settles
- **THEN** `state/draft.md` is `afrom the clipboardd`, the fixture's `TMPDIR` holds no `teamsmith-paste-*` file, and
  `xclip` was not called

#### Scenario: No clipboard tool changes nothing

- **GIVEN** a fixture whose `PATH` resolves neither `wl-paste` nor `xclip`, and a compose holding `half a thought`
- **WHEN** `C-v` is pressed
- **THEN** `state/draft.md`, the capture and the fixture's `TMPDIR` are byte-identical to before the press, no error
  line appears, and the console still answers (the next typed character appears and Enter still sends)

#### Scenario: A clipboard tool that never answers changes nothing within the bound

- **GIVEN** a fixture `PATH` whose fake `wl-paste` never exits, and a compose holding `half a thought`
- **WHEN** `C-v` is pressed
- **THEN** within 5 s no `teamsmith-paste-*` file exists, `state/draft.md` is still `half a thought`, and the console
  still answers (the next typed character appears and Esc still closes the compose with the draft kept)

#### Scenario: A paste into the standby reason leaves the message draft alone

- **GIVEN** a fixture project whose `state/draft.md` holds `half a thought` and an image clipboard, and the console
  composing a standby reason (`s`)
- **WHEN** `C-v` is pressed and the paste settles
- **THEN** the reason line holds the pasted image's path and `state/draft.md` still holds `half a thought`

### Requirement: The work page's board rows are focusable and open the same detail view

On the work page (page 2), the board block's rows SHALL be focusable exactly as the kanban page's cards are: the
frame SHALL mark one focused row with a cursor glyph and the `selected` tone (never colour alone), and it SHALL
report the drawn rows in the order it drew them — each row's id together with its occurrence among the rows
carrying that id — so `↑`/`↓` walk the drawn order — the first press with no focus yet SHALL focus the first
drawn row — and the focused row SHALL always be among the rows the block renders. Two rows
that share an id SHALL be two separate stops here as well, and the focus SHALL stay on the same row across a
refresh and across entering and leaving the detail view. `enter`, or
a click on the already focused row, SHALL open the same read-only detail view the board page opens (the `panel`
detail contract: the same discovery by entry id, the same 128 KiB bound, the same tabs, the same sanitizer); a click
on an unfocused row SHALL focus it. The detail view SHALL render on the page it was opened from, so `esc`/`q`
returns to that page — opening from the work page MUST NOT move the user to the board page, and opening from the
board page MUST NOT move the user to the work page. While a board row is focused the key band SHALL name the row
keys (`↑`/`↓` to move, `enter` to open), and `pageUp`/`pageDown` SHALL keep scrolling the page by keyboard, because
`↑`/`↓` no longer do on this page (they did before this change; the wheel keeps scrolling the page as it does
today). A block that is empty (no board row) or degraded to its summary line SHALL render no row, no cursor and no
row keys, and SHALL register no focus target — there SHALL be no focusable item on the work page that cannot be
opened.

#### Scenario: `↓` focuses a row and `enter` opens its detail without leaving the page

- **GIVEN** a fixture project with three board rows whose first row is a task brief with a report, and the console
  on the work page in a 120x30 fixture pane (`state/panel-page` holds `2`)
- **WHEN** `↓` is pressed, then `enter`
- **THEN** the capture after `↓` carries the focus cursor on the first drawn row (and no other row), and the capture
  after `enter` is the detail view of that entry (its file tabs and its first file's heading), still on page 2
  (`state/panel-page` still holds `2`)

#### Scenario: Closing returns to the page the detail was opened from

- **GIVEN** the same fixture, on the work page with a row's detail open, and then a fresh console on the board page
  with a card's detail open
- **WHEN** `q` is sent in the first console, and `esc` in the second
- **THEN** the first capture is the work page (`state/panel-page` `2`, the board block and its counts line visible)
  and the second is the board page (its lanes visible) — neither reader was dumped on the other page, and in both
  cases the window's process is still the console renderer

#### Scenario: A click focuses a row, a second click opens it

- **GIVEN** the console on the work page in a fixture pane with the mouse preference on
- **WHEN** a click lands on a board row, and a second click lands on the same (now focused) row
- **THEN** the first click moves the focus cursor onto that row and the second opens its detail view, exactly as on
  the board page

#### Scenario: An empty or degraded board has no dead item

- **GIVEN** a fixture project whose BOARD.md has no rows, the console on the work page in a 120x30 pane, and then a
  second fixture with rows in a 60x10 pane where the block degrades to its summary line
- **WHEN** `↓` and `enter` are pressed in each
- **THEN** neither capture carries a focus cursor and no detail view opens, and each frame's click-target map holds
  no `focus` and no `open-focused` action on the work page

#### Scenario: Duplicate rows are two stops on the work page too

- **GIVEN** a board whose rows are `M39` (first duplicate), `M39` (second duplicate) and `M48`, and the console on
  the work page
- **WHEN** the page renders and `↓` is pressed past the two same-id rows
- **THEN** exactly one row carries the cursor at each step, both `M39` rows are separate stops that the walk
  reaches in drawn order (the second does not restart or freeze on the first), and the next press reaches `M48`

### Requirement: The console shows the project contract with its effect class, and refuses what it must not change

The settings overlay's navigation row SHALL open a **project-settings view** that replaces the page's blocks — the
title band, the page tabs and the key band stay, exactly as with the overlay itself, and the view is closed with
`esc` back to the overlay it was opened from without collapsing the console. The view SHALL list the project
contract (`.pi/team/config.sh`, `memory-and-deps`'s single-writer file): one row per key of the owning command's
schema plus one row per key the file itself carries that the schema does not know, and per row the key's **human
label** — from the console's zh/en tables, looked up by the key name the command reported — the current value
(the file's value, else the schema's default marked as unset), the key's **class** from the schema and the key's
own trailing inline comment when its line has one. The bare key name MUST NOT be the row's main text: every key of
the command's schema SHALL have a non-empty label in both tables (a fact the string-table gate asserts in both
directions — a schema key without a label and a label whose schema key is gone both fail it), and the raw key
SHALL appear only where the view aligns with the command line: the editor's prompt and its confirmation, and the
view's own line naming what to run for the focused row — `team config set <KEY> <value>` for a key the command can
set, the file to hand-edit plus the key for a `refuse` key, the seat's own command for a seat. A key the schema
does not know has no label and none SHALL be invented for it: its row falls back to the raw key name, which is
what the file and the command carry. The class vocabulary SHALL be the owning
command's, closed and rendered from the tables: `apply` (the next read of the file uses it), `restart` (a running
process holds the old value until it is restarted — the badge names the target: the pulse, the PM or a live
session) and `refuse` (the console must not change it). The row set and the classes MUST come from the owning
command's machine-readable read at render time; the bundle MUST NOT carry a second **schema** — no key list with
classes, defaults or a row order — so a key added to the command's schema appears in the view without rebuilding
`panel.js`, with the class, the default and the row that command gives it (and, having no label yet, its raw name
as the row's text). `↑`/`↓` SHALL move a row focus (group
headings are not focusable) and SHALL drag a window that counts the rows it hides at each edge; a click SHALL
focus a row and a click on the focused row SHALL open its editor, the kanban's rule. `/` SHALL open a filter line
that narrows the list to the rows whose **label, raw key or value** contains the filter text (case-insensitively) —
so the user who reads the labels and the user who knows the CLI's keyword both find the row — and `esc` SHALL clear
it without closing the view. A `refuse` row SHALL open no editor and its interaction SHALL surface the
owning command's refusal, which names the right route (hand-editing the file, `team add-agent`, …). The view's
own labels SHALL come from the zh/en tables, the key labels included: no visible text is written into the bundle.
The view is a console-only block: `--print` and `--json` MUST NOT
read or render it, and the machine exits' bytes are unchanged. The view MUST NOT be a fifth page: the four-page
composition and `state/panel-page` keep their meaning.

#### Scenario: The rows carry the three classes and the unset key its default

- **GIVEN** a fixture contract whose file holds `TEAM_GATES`, `TEAM_PULSE_INTERVAL` and `TEAM_PROJECT`, and a
  schema whose `TEAM_DEFER_TTL` the file does not carry
- **WHEN** the project-settings view renders in a 160-column fixture pane
- **THEN** the three ruled rows carry the `apply`, `restart` and `refuse` badges, the `TEAM_DEFER_TTL` row shows
  the schema's default and the unset marker, every rendered label exists in both tables, and each row's main text
  is that key's label in the active language (no row reads `TEAM_…`)

#### Scenario: The raw key is exactly where the CLI is named

- **GIVEN** the view open with the focus on `TEAM_PULSE_INTERVAL` (an editable `restart` key), then on
  `TEAM_SESSION` (a `refuse` key) and then on the `dev` seat
- **WHEN** each row is focused
- **THEN** the view's own command line reads `team config set TEAM_PULSE_INTERVAL <value>` for the first row, names
  the file to hand-edit together with `TEAM_SESSION` for the second and `team config set-agent-model dev …` for the
  seat, and the editor the first row opens is titled with the raw key

#### Scenario: A search by the raw key still finds the row

- **GIVEN** the view open on a contract with more keys than one frame shows
- **WHEN** `/` is pressed, `TEAM_PULSE_INTERVAL` is typed and applied
- **THEN** that row is listed with its label as the main text and the raw key named by the command line under it,
  and every other row is gone

#### Scenario: A key the schema does not know falls back to the raw name

- **GIVEN** a contract whose file carries `TEAM_HAND_ADDED` while the command's schema does not, and the view open
- **WHEN** the row renders and is focused
- **THEN** the row's main text is the raw key `TEAM_HAND_ADDED`, its badge is the unknown-key badge, and the
  command line says the key is not in the command's schema (no `team config set` is offered for it)

#### Scenario: The string tables cover the command's schema, both directions

- **GIVEN** the console tree with the owning command's schema table and the zh/en tables
- **WHEN** the string-table gate runs
- **THEN** it exits non-zero naming the key when one schema key has no label in either table, and equally when a
  label is left behind for a key the schema no longer carries; restoring the label (or the schema row) makes it
  pass

#### Scenario: The row set and the classes come from the command, not from the bundle

- **GIVEN** a scratch copy of the CLI whose schema carries an extra key `TEAM_ZZZ_TEST` and whose `TEAM_GATES`
  class is `refuse`
- **WHEN** the view renders against that CLI with the committed `panel.js` unchanged
- **THEN** the list carries a `TEAM_ZZZ_TEST` row, whose main text is the raw name (the tables never saw that key),
  and `TEAM_GATES`'s badge reads `refuse`

#### Scenario: A refuse row opens no editor and the route is named

- **GIVEN** the view open with the focus on `TEAM_SESSION`, and then on `TEAM_AGENTS`, the roster key, with the
  contract's sha256 recorded
- **WHEN** `enter` is pressed on each and `x` is typed
- **THEN** neither opens an editor, each receipt names the route (`team add-agent` / `team teardown` for the
  roster, hand-editing the file for an identity key), and the contract's sha256 is unchanged after both

#### Scenario: The filter narrows and clears

- **GIVEN** the view open on a contract with more keys than one frame shows
- **WHEN** `/` is pressed and `pulse` is typed, and then `esc`
- **THEN** the first frame lists only rows whose label, raw key or value contains `pulse` (the raw-key spelling
  finds the rows the CLI names, while their text stays the label), and the frame after `esc` lists every row again
  with the view still open

#### Scenario: The focus window and the clicks

- **GIVEN** a fixture contract of 40 keys in a pane that shows 12 rows, and the mouse preference on
- **WHEN** `↓` moves the focus past the last visible row, and then a click lands on a visible row and a second
  click on the same row
- **THEN** the window scrolls with the focus and counts the hidden rows above and below, the click moves the
  cursor glyph, and the second click opens that row's editor

#### Scenario: The origin is remembered and `q` keeps its meaning

- **GIVEN** the settings overlay open with the focus on the project-settings row
- **WHEN** `enter` opens the view and `esc` is pressed, and then the view is reopened and `q` is pressed
- **THEN** the overlay renders again with that row selected, and the `q` collapses the console (the global
  meaning, not a view-local exception)

#### Scenario: The machine exits stay byte-stable

- **GIVEN** a fixture project and two contracts whose values differ
- **WHEN** `team monitor --print` and `team monitor --json` run under each
- **THEN** the two prints are identical apart from the timestamp and the two JSON objects carry no
  project-settings field

### Requirement: The console writes a project setting only through `team config set`, after validation and a confirmation

An editable row's `enter` SHALL open the row's editor: the **choice editor** (the requirement that owns it) when
the command's read reports a choice set for the key, and otherwise a one-line value editor that is the compose
line's editor (the insertion point, pi's key map, the windowed draft — the `panel` requirement that owns it)
holding the file's value, or the schema's default when the key is not in the file. Whichever editor opened, the
value it leaves — the entry the human accepted, or the text they typed — SHALL be the write this requirement's
validation and writer then consume, and the editor selection MUST NOT change any step below. In the **free-text
editor** `enter` SHALL NOT write: it SHALL ask the owning command for a validation (`team config set … --dry-run`,
a read that writes nothing) and, when accepted, show a confirmation line with the key, the old value, the new
value and the class's timing (and, for a `restart` class, the exact restart command); a second `enter` SHALL
perform the write by invoking `team config set … --yes` as a subprocess, and `esc` SHALL cancel with nothing
written, no audit line and no temporary file left behind. For a value the human **accepted from the choice
editor**, the same validation and the same write SHALL happen on that accept — `--dry-run` first, then `--yes`
with the fingerprint the editor's read carried — and no confirmation frame SHALL be drawn, except for a value the
command reports as dangerous: that SHALL NOT be written by the first accept however it was chosen, the
confirmation line SHALL carry the warning and require one more `enter`. The receipt SHALL be one honest line
mapped from the command's exit code — written (with the class's timing), refused as read-only, rejected as invalid
(naming the accepted domain), refused because the file changed under the editor, or a write error that says the
file was left unchanged — and MUST NOT be parsed from human prose. On a conflict the view SHALL reload the
contract and display the other writer's value; on any settle the list and the audit tail SHALL be re-read in the
background, and that re-read MUST NOT hold the receipt frame. The console MUST NOT open the
contract for writing itself: every byte of `.pi/team/config.sh` changes through the owning command (the wrapper's
argv log is the evidence), and a `restart`-class write SHALL NOT claim it took effect — the running console keeps
the old value until it is restarted, and the receipt says so. The panel MUST NOT offer an action that restarts
the pulse: it runs inside the pulse window and would kill itself; the restart command is printed instead.

#### Scenario: An edit writes one line and keeps every other byte

- **GIVEN** a fixture contract whose line reads `TEAM_PULSE_NUDGE_GAP="900"  # 15min` among comments and other keys
- **WHEN** the row is opened, `1200` is typed, `enter` is pressed twice, and the receipt says written
- **THEN** `bash -n .pi/team/config.sh` exits 0 and `diff` shows exactly one changed line, which reads
  `TEAM_PULSE_NUDGE_GAP='1200'  # 15min`

#### Scenario: The write goes through the owning command and never around it

- **GIVEN** a `team` wrapper that logs its argv and a fixture contract whose sha256 is recorded
- **WHEN** a value is edited and confirmed, and then a second edit is cancelled with `esc`
- **THEN** the log's last two entries are `config set … --dry-run` and `config set … --yes` for the first edit and
  only a `--dry-run` for the second, and no other process wrote the contract (its bytes changed once, in the
  first edit)

#### Scenario: A concurrent change is refused and nothing is overwritten

- **GIVEN** the editor open (its fingerprint pinned) and a second writer replacing the contract's bytes
- **WHEN** `enter` is pressed twice
- **THEN** the receipt names the conflict, the contract is byte-identical to the second writer's version, the
  view shows that writer's value, and `state/config.log` gained one `result=conflict` line

#### Scenario: An invalid value writes nothing and keeps the draft

- **GIVEN** the editor holding `0` for `TEAM_PULSE_INTERVAL`, the contract's sha256 recorded
- **WHEN** `enter` is pressed
- **THEN** the receipt carries the command's refusal naming the accepted range, the sha256 is unchanged, the
  audit log did not grow, and the editor stays open with the draft

#### Scenario: A dangerous value needs the second confirmation

- **GIVEN** the editor holding `0` for `TEAM_MIN_FREE_SWAP_MB`, the contract's sha256 recorded
- **WHEN** `enter` is pressed once
- **THEN** the confirmation line carries the danger warning, the sha256 is unchanged and no audit line exists
- **AND** when `enter` is pressed again the value is written and the receipt names the guard that is now off

#### Scenario: A restart-class write does not claim it took effect

- **GIVEN** a running console whose frame reports `panel.refresh_s` 3, and the row for `TEAM_MONITOR_REFRESH`
- **WHEN** it is set to `7` and the write settles
- **THEN** the receipt names the pulse restart, the running console's frame still reports 3, and a following
  `team monitor --json` reports 7

#### Scenario: The audit is readable from the view and from the CLI

- **GIVEN** a value written with the panel as the actor
- **WHEN** the view renders its audit footer and `team config log 5` runs
- **THEN** both show the same newest line naming the timestamp, the actor, the key, the old and the new value,
  and the footer shows at most three lines

### Requirement: The console edits a seat's model and shows where the displayed model came from

The project-settings view SHALL carry a **seats** block: one row per roster seat (`TEAM_AGENTS`) plus the PM seat
(`pm`), each showing the model the console is displaying, its **source** in the CLI's own three states — `配置`
(the configuration resolution, or no record), `显式` (the last `--model`), `历史记录` (the state record differs
from the configuration, so the next spawn uses the new configuration) — and whether the seat carries a
configuration override. The model and its source SHALL come from the owning command's machine read
(`team config list --json`'s `models` block, computed by the same semantics `team ps` prints, `team_agent_model_src`
in `common.sh`); the bundle MUST NOT compute a fourth state and MUST NOT render a bare model name. `enter` on a seat
row SHALL open a picker — the models the command reports as known (the configuration's and the seats' recorded
models) followed by a free-text line using the compose editor — and its confirmation SHALL write through
**`team config set-agent-model <seat> <model|->`**, never by composing the pair list in the console; the
confirmation and the receipt SHALL name the seat, the new model and the rule that the seat's **running window keeps
its model until it is spawned again** (the next `dispatch`/`resume`; the PM seat needs the PM process rebuilt). `-`
SHALL remove the seat's override so the fallback (`TEAM_DEFAULT_MODEL`) applies. A seat the roster does not name (a
typo like `dev4`) and a model without the `provider/model` shape SHALL be refused by the owning command with its
message shown, and a model whose fallback the seat does not override SHALL be displayed as such. The console MUST
NOT re-spawn, kill or restart a seat to make a model change take effect: it prints the route
(`team resume --agent <a>` for a stopped seat; dispatch stays the PM's).

#### Scenario: A running seat keeps its model and the next spawn uses the new one

- **GIVEN** a fixture project with a running `dev` window whose record names `deepseek/deepseek-flash`
- **WHEN** `TEAM_AGENT_MODELS` is given `kimi-coding/k3-256k` for `dev` through the seats picker and the write
  settles
- **THEN** the running window's process arguments and `state/dev.env` still carry the old model, the receipt names
  the next-spawn rule and prints no restart, and `team dispatch dev <ID> <brief> --print` renders the new model in
  the command it would run

#### Scenario: The source tri-state matches `team ps`

- **GIVEN** a fixture whose `state/dev.env` records a model that differs from the configuration's resolution for
  `dev`, and a second seat with no record
- **WHEN** the seats block renders and `team ps` runs for the same fixture
- **THEN** the differing seat's row carries `历史记录` and the record's model while `team ps`'s line for that seat
  carries the same model and `·历史记录`, and the record-less seat's row carries `配置`
- **AND** when a scripted dispatch writes the record with the current configuration, the row's badge reads `配置`

#### Scenario: The override can be removed

- **GIVEN** `TEAM_AGENT_MODELS` carrying a `dev=…` token
- **WHEN** `-` is chosen for `dev` and confirmed
- **THEN** the token left the line (the other seats' tokens and every other byte unchanged), the row shows the
  fallback model with `配置`, and `team config list --json`'s `models.default` is that model

#### Scenario: A seat's model is edited from its own row, and the seat's source is displayed

- **GIVEN** a fixture project whose `TEAM_AGENT_MODELS` gives `dev` one model while `state/dev.env` records another,
  and the console in a fixture pane
- **WHEN** the seats block renders, and then the picker is opened on `dev`, a model is chosen and confirmed
- **THEN** the `dev` row showed the recorded model with the CLI's `历史记录` badge before the write, the receipt
  names `dev` and the next-spawn rule, `TEAM_AGENT_MODELS`'s line gained that seat's token with every other byte
  unchanged, `state/dev.env` is untouched, and the row's badge now reads `配置`

#### Scenario: An unknown seat or a shapeless model is refused

- **GIVEN** the picker's free-text line holding `deepseek-flash` (no provider) and, in a second run, a hand-edited
  `TEAM_AGENT_MODELS` token naming a seat the roster does not have (`dev4=…`)
- **WHEN** each is confirmed
- **THEN** the receipts carry the owning command's refusal naming the accepted shape and the roster, and the
  contract's sha256 is unchanged in both runs

### Requirement: The console is read-only except through its owning commands

Every block the console shows SHALL come from read-only reads, and the only state-changing actions the console
offers SHALL be the ones that invoke the owning command as a subprocess: `m`/Enter → `team draft send`, `f` →
`team outbox flush` (both `delivery-guard`), `s` → `team standby on|off` (`watchdog`), and the project-settings
view's confirmed edit → `team config set` (`memory-and-deps`, which owns the contract's write path). The console
process itself MUST NOT write patrol, queue, inbox, board, ledger or contract files: the contract is written by
the command, never by the panel, and the only files the console writes on its own are its three
(`state/draft.md`, `state/panel.conf`, `state/panel-page`). v1 SHALL NOT grow a fifth action — an in-panel pulse
restart is deliberately not one, because the console runs inside the pulse window and would kill itself; a
"restart this seat now" action is not one either, because spawning a seat is dispatch (`dispatch`/`resume` with a
brief, the PM's guards and the `--fresh`-or-continue decision the console cannot make) — the view prints the
restart command for the pulse and the resume/dispatch route for a seat instead. The validation call
(`team config set --dry-run`) is a read: it MUST NOT
change the contract or the audit log. The `C-v` clipboard paste is input editing, not an action: it invokes no
`team` subcommand and writes no file inside the project — its one write is the temporary copy of the clipboard
image under the system temp directory, which the console never deletes. This is the design's read-only discipline
made falsifiable.

#### Scenario: The four actions invoke their owning commands

- **GIVEN** a fixture project with one queued outbox entry, the console running in a fixture pane, and a `team`
  wrapper logging every invocation
- **WHEN** `f` is pressed, then `s`, then `s` again, and then a project setting is edited and confirmed
- **THEN** `team outbox flush` ran (its own log line is the evidence), standby was on after the first `s` and off
  after the second (`team watchdog status` reports it), the contract was written by `team config set` (the
  wrapper's argv), and the console wrote nothing under `state/outbox/` or to the contract itself

#### Scenario: Undocumented keys change nothing

- **GIVEN** a fixture project with the hashes of `state/`, `docs/`, the inbox and the contract recorded
- **WHEN** the console runs through several undocumented keys and every read-only navigation key, including the
  project-settings view's navigation and a cancelled edit
- **THEN** no file outside the console's own three changed, and the contract's audit log did not grow

#### Scenario: The paste writes outside the project and runs no command

- **GIVEN** a fixture project with the hashes of `state/`, `docs/` and the inbox recorded, an image clipboard, and a
  `team` CLI wrapper that logs every invocation
- **WHEN** `C-v` is pressed in the compose line and the paste settles
- **THEN** the temp file exists under `TMPDIR` with the image bytes and the draft holds its path, while no file
  outside the console's own three changed and the wrapper's log gained no line

### Requirement: The delivery warning covers a degraded wake channel

The panel's PM block (`team __panel-data --block pm`) SHALL set `delivery_warning` in two classes: the PM target has
no live inbox-watch registration, or it has a live registration whose watcher is degraded (a live
`state/inbox-watch/<key>.degraded` record). The console SHALL render a non-empty `delivery_warning` as its own
status line carrying a text token as well as colour, and MUST omit that line while the field is empty. The warning
MUST name the consequence that matches the class: a missing registration falls back to the input-box paste path
(`delivery-guard` owns that path), while a degraded watcher keeps the spool channel and only slows the wake to the
polling cadence — the degraded class MUST NOT be described as falling back to the paste path. The wording SHALL come
from the same reader `team doctor` and `team status` use, so one condition never produces two stories.

#### Scenario: A degraded watcher is visible and named correctly

- **GIVEN** a fixture project whose PM target has a live registration and a live `.degraded` record with
  `errno=ENOSPC` and `watches=65312/65536`
- **WHEN** `team __panel-data --block pm` and `team monitor --print` run
- **THEN** `delivery_warning` is non-empty and names `ENOSPC` or the polling fallback
- **AND** the printed frame carries the delivery-degraded line with that text
- **AND** neither the field nor the line says the notification falls back to the paste path

#### Scenario: The missing-registration class keeps its own wording

- **GIVEN** a live `.skip` record with `reason=session-mismatch` and no live registration
- **WHEN** `team __panel-data --block pm` and `team monitor --print` run
- **THEN** `delivery_warning` names the session mismatch and the paste-path consequence it names today

#### Scenario: A healthy channel shows no warning line

- **GIVEN** a fixture project whose PM target has a live registration and no `.degraded` record
- **WHEN** `team monitor --print` runs
- **THEN** the frame carries no delivery warning line and `delivery_warning` is the empty string

### Requirement: The console offers the schema's choice set wherever there is one, and degrades visibly where there is none

An editable row's editor SHALL take its options from the owning command's read — `team config list --json`'s
`choices` object for the key, the same payload the `settings` block carries — and from nowhere else: the bundle
MUST NOT carry a per-key option table, and a key or a value added to the command's schema MUST be offered without
rebuilding `panel.js`. The editor SHALL be built from the `settings` block already on screen, and it SHALL build
its entries in this order: the file's value marked as current (only when the file carries the key), the schema's
default marked as default (only when non-empty), the distinct `choices.values` in their order, and then the kind's
own entries. An editor whose entry list would be empty MUST NOT render an empty line — it opens the free-text
editor and names the reason.

**Accepting an entry** (keyboard or click) SHALL be one interaction, not the start of a second editor. For the
value entries — `current`, `default`, each `choices.values` entry and `clear` — the console SHALL ask the owning
command for the validation it already uses (`team config set <KEY> <VALUE> --dry-run`, a read that writes
nothing) and, when the command accepts it, SHALL perform the write immediately (`team config set <KEY> <VALUE>
--yes --fingerprint <the fingerprint of the read the editor was built from>`) and SHALL draw the receipt the
command settles with — no confirmation frame and no free-text step on that path. The danger rule keeps its one
exception: a value the command reports as dangerous SHALL NOT be written by that first accept, the confirmation
line SHALL carry the warning, and one more accept SHALL write it with the command's danger allowance. The
free-text entry is the **only** entry that opens the compose editor, and it SHALL keep that editor's validation
**and** confirmation unchanged. `keep-unset` SHALL cancel with nothing written, no audit line and no temporary
file left behind; a value the command refuses SHALL write nothing and its reason SHALL be the receipt.

**Responsiveness is a behavior, not a budget.** Opening the editor, moving in it, accepting an entry and opening
the free-text entry MUST NOT wait on a new read of the owning command: no `team config list`/`__panel-data`
invocation may stand between the keystroke and the frame that answers it, and the fingerprint the direct write
carries SHALL be the one the read that built the editor produced. A contract changed under the editor is the
command's conflict verdict — the receipt names it and the view reloads — not a reason to re-read before every
action. After a write settles the console SHALL re-read the `settings` block in the background and adopt it when
it lands; the receipt frame SHALL come from the write's own settle and MUST NOT be held by that re-read.

Per kind:

- `bool` SHALL offer exactly the two canonical values (`1` and `0`), never a free-text entry, each with the zh/en
  tables' word for it, the default entry marked and the current entry marked when the file carries the key.
- `enum` SHALL offer exactly `choices.values` in their declared order, rendered verbatim — no table entry per
  value, so a value added to the command's `constraints` appears without a rebuild — and no free-text entry.
- `int`/`seconds`/`mb`/`bytes`/`pct` SHALL offer `choices.values` (the schema's suggested values pass through
  unchanged), the current and default entries, and a free-text entry, and SHALL name the accepted interval
  `choices.min`–`choices.max` (an empty bound reads as unbounded).
- `path` SHALL offer the current value, the default, a clear entry **only** when `choices.empty` is true, and a
  free-text entry; every path entry and the typed value SHALL carry an existence mark under the kind's rule
  (`dir`/`file`/`exec`), and that mark SHALL be an advisory the confirmation repeats — never a claim that the
  command will refuse the write.
- `model` SHALL offer `choices.values` (this project's known models), the current and default entries, and a
  free-text entry, and MUST NOT offer a model the command did not report — the machine's Pi model catalogue is
  not a source for this view.
- `winlist`/`pattern` SHALL offer the known models as token vocabulary: choosing one opens the free-text editor
  holding the current value with `<model>=` inserted at the insertion point.
- `pairlist` SHALL NOT be composed in the console: its editor SHALL be the seats block (the requirement that
  owns per-seat model editing), reachable by `enter` from the row without any free-text composition of the pair
  list, and the row's command line SHALL name `team config set-agent-model <seat> <model|->`.
- A key whose `choices.source` is `none` and whose kind carries no action set (`text`, `cmd`, `tpl`, `list`)
  SHALL open the free-text editor with one visible line naming the reason (the schema's kind has no choice set,
  and the command still validates the write). A key the schema does not know stays read-only as it is today.

An unset key SHALL render as `未设 · 默认 X` and its editor SHALL lead with an explicit keep-unset entry whose
effect is to cancel with nothing written, no audit line and no temporary file left behind; the writer has no
removal operation and the view MUST NOT pretend otherwise.

The editor SHALL be keyboard- and mouse-complete: `↑`/`↓` move the entry focus, `enter` accepts the focused entry,
a click on an entry moves the cursor to it and a click on the focused entry accepts it as `enter` does, the wheel
scrolls an entry list longer than the visible budget, `esc` closes the editor back to the row list with the row
focus where it was, and the free-text entry opens the compose editor by keyboard and by click alike.

#### Scenario: A bool key is chosen from two labelled entries

- **GIVEN** a fixture contract whose `TEAM_NOTIFY_TMUX` the file does not carry (schema default `1`) and, in a
  second run, one carrying `TEAM_NOTIFY_TMUX='0'`
- **WHEN** the row's editor opens in a 160-column fixture pane in each run, and in the second run the `1` entry is
  accepted
- **THEN** the first editor lists exactly the two entries `1`/`0` with the tables' on/off words and the default
  marker on `1`, and the second marks `0` as current and `1` as default, and neither editor renders a free-text
  entry and no rendered line is an empty box
- **AND** the accept writes `TEAM_NOTIFY_TMUX='1'` — the wrapper's argv log carries `config set TEAM_NOTIFY_TMUX 1
  --dry-run` and then the same invocation with `--yes` and the fingerprint the editor's read carried, no
  confirmation line renders between the two, the contract changed once, the audit grew one line, and the receipt
  names the class's timing

#### Scenario: An enum offers exactly its constraints

- **GIVEN** the real schema's `TEAM_MONITOR_UI` (`constraints` `auto,tui,text`, default `auto`) in a fixture
  contract that does not carry it, with the contract's sha256 and audit length recorded
- **WHEN** its editor opens and `tui` is accepted
- **THEN** the entries are exactly `auto`, `tui`, `text` in that order with the default marker on `auto`, and no
  free-text entry exists
- **AND** the accept writes `tui`: the log carries `team config set TEAM_MONITOR_UI tui --dry-run` and then the
  same with `--yes` and the fingerprint, no confirmation frame exists on the way, the sha256 changed, the audit
  grew exactly one line, and the receipt carries the `restart` class's timing

#### Scenario: A new enum key and a new enum value need no console change

- **GIVEN** a scratch CLI whose schema gains `TEAM_ZZZ_MODE|apply|enum|red,blue|plain|red`, and the committed
  `panel.js` used unchanged
- **WHEN** the view renders against that CLI and the `TEAM_ZZZ_MODE` row's editor opens
- **THEN** the row is listed (its raw key is its text, since no zh/en label exists for it) and its editor offers
  `red` and `blue` in order with the default marker on `red`
- **AND** when the scratch schema reads `TEAM_ZZZ_MODE|apply|enum||plain|red` instead, the same bundle opens the
  free-text editor and the reason line names the kind with no choice set
- **AND** the pre-change bundle opens a blank editor in both runs — the red side of this flip

#### Scenario: The model entries are this project's, never the machine's catalogue

- **GIVEN** a fixture project whose contract names `deepseek/deepseek-flash`, whose `TEAM_AGENT_MODELS` carries
  `dev=kimi-coding/k3-256k`, and whose `state/dev.env` records `openai-codex/gpt-5.6-terra:xhigh`; and a fixture
  `HOME` whose Pi model catalogue names `sub2api/gpt-5.6-luna`
- **WHEN** the `TEAM_DEFAULT_MODEL` row's editor opens, and then the seats block's `dev` picker
- **THEN** the entries are those three project models (with the current/default markers) in both editors and no
  `sub2api` entry appears anywhere
- **AND** the same run's `team config list --json` carries no `sub2api` value in `choices.values` or in
  `models.known`

#### Scenario: A numeric key suggests values and its free-text entry still validates and confirms

- **GIVEN** `TEAM_PULSE_INTERVAL` (`seconds`, `constraints` `60,`, default `900`, suggestion column
  `300,900,1800,3600`) in a fixture contract that does not carry it, with the contract's sha256 recorded, and the
  wrapper's argv log cleared
- **WHEN** the row's editor opens and its free-text entry is accepted, `30` is typed and the editor's first
  `enter` is pressed
- **THEN** the entries carry `300`, `900`, `1800`, `3600` in that order with the default marker on `900`, a
  free-text entry is present, and the editor names the accepted interval `60–` as unbounded
- **AND** the free-text run receives the owning command's exit 4 naming the minimum, the editor stays open with
  its draft, nothing was written, and the sha256 is unchanged
- **AND** a suggestion entry accepted instead takes the direct write of the requirement above — the log carries
  `--dry-run` then `--yes` with no confirmation frame and no editor for it

#### Scenario: A path key marks existence and offers clear only what the command accepts

- **GIVEN** a fixture contract whose `TEAM_AGENT_BIN` (path `exec,opt`) points at a file that does not exist and
  whose `TEAM_PI_BIN` (path `exec`, required) points at one that does
- **WHEN** each row's editor opens, and then a second missing path is typed into `TEAM_AGENT_BIN`
- **THEN** `TEAM_AGENT_BIN` offers its current value with a missing mark, a clear entry and a free-text entry,
  while `TEAM_PI_BIN` offers no clear entry, and the typed value carries the missing mark
- **AND** the typed value's confirmation line repeats the mark while still offering the write (the command has no
  existence check, and the console does not invent a refusal)

#### Scenario: A key without a choice set opens free text and names the reason

- **GIVEN** a fixture contract whose file carries `TEAM_GATES` (kind `cmd`)
- **WHEN** its row's `enter` is pressed
- **THEN** the compose editor opens holding the value together with one visible line saying that the schema's
  kind defines no choice set and that the command still validates the write, and no entry list is rendered

#### Scenario: An unset key leads with an entry, not a blank box

- **GIVEN** a fixture contract that does not carry `TEAM_DEFER_TTL` (default `300`), with its sha256 and audit
  length recorded
- **WHEN** the row renders and its editor opens on the keep-unset entry, which is then accepted
- **THEN** the row reads `未设 · 默认 300` and the accept cancels with no compose editor, no write, no audit line,
  no temporary file and an unchanged sha256
- **AND** opening the editor again and accepting the `300` entry instead writes `TEAM_DEFER_TTL='300'` on that one
  accept (validation then write, the fingerprint from the editor's read, no confirmation frame) — the view does
  not call that an unset and opens no compose editor for it

#### Scenario: The pairlist row routes to the seats block

- **GIVEN** the view open with more rows than the pane shows and the focus on `TEAM_AGENT_MODELS`
- **WHEN** `enter` is pressed
- **THEN** the seats block becomes the row's editor: the focus moves to it, no compose editor and no option list
  opens, and the command line names `team config set-agent-model <seat> <model|->`

#### Scenario: The picker is mouse-complete and writes nothing on cancel

- **GIVEN** the view open on an editable enum row with the mouse preference on and the contract's sha256 and audit
  length recorded
- **WHEN** a click lands on a non-focused entry, and then `esc` is pressed instead of accepting the focused entry
- **THEN** the click moves the cursor to that entry without writing anything, `esc` closes the editor back to the
  row list with the row focus unchanged, the sha256 is unchanged, the audit log did not grow, and the wrapper's
  argv log carries no `config set`
- **AND** a second click on the focused entry accepts it as `enter` does and writes it through the same
  `--dry-run` → `--yes` pair, and a wheel event over an entry list longer than the visible budget scrolls it

#### Scenario: A dangerous value from the options keeps its one confirmation

- **GIVEN** the numeric editor for `TEAM_MIN_FREE_SWAP_MB` with its `0` entry open, the contract's sha256 and the
  audit length recorded
- **WHEN** the `0` entry is accepted
- **THEN** the confirmation line carries the danger warning, the sha256 is unchanged, the audit did not grow, the
  log carries no `config set … --yes`, and nothing was written
- **AND** when the focused entry is accepted again the value is written with the command's danger allowance and the
  receipt names the guard that is now off

#### Scenario: A conflict under the editor is refused and nothing is overwritten

- **GIVEN** an editor open on its fingerprint and a second writer replacing the contract's bytes
- **WHEN** an entry is accepted
- **THEN** the receipt names the conflict, the contract is byte-identical to the second writer's version, the view
  reloads and shows that writer's value, and `state/config.log` gained one `result=conflict` line

#### Scenario: The interaction path never waits on a read

- **GIVEN** a fixture project whose CLI is a wrapper logging its argv, and the view open on the contract's rows
- **WHEN** a row's editor is opened, the focus moves, an entry is accepted and a free-text entry is opened
- **THEN** the log carries no `config list`/`__panel-data` invocation between each keystroke and the frame that
  answered it — the editor is built from the `settings` block the view already read
- **AND** the accept's first child is `config set … --dry-run` and the write that follows it is the second, with
  the fingerprint the editor's read carried; the settle's re-read of the `settings` block is the only read that
  follows, it runs in the background, and the receipt frame renders without waiting for it

### Requirement: The settings view groups the contract by the functional group the command reports, and carries the effect class on the row

The project-settings view's row list SHALL group the contract's keys by the `group` the owning command reports
for each key, and the read's order SHALL be the view's order: a heading opens when the token changes, the
schema's order is kept inside a group, and the headings themselves appear in the order the read reports their
first rows. A heading MUST NOT be a focus target and MUST NOT be a click target. The heading's text SHALL come
from the zh/en tables, looked up by the token (`group_<token>`), so no group word is written into the bundle; a
token with no label SHALL render as the raw token — the same visible fallback the key labels use for a key the
schema does not know — and the string-table gate SHALL assert the tokens the schema's rows carry and the group
labels in both tables match in **both** directions (a token without a label and a label no row uses both fail
it). The bundle MUST NOT carry a key→group table or a group list of its own: a group or a key added to the
command's schema SHALL appear under the reported heading with the committed `panel.js`, and a row the read
reports under a different token SHALL move.

The **effect class** SHALL be carried on the row, not by the grouping: every key row SHALL render its class as a
text badge (`apply`, `restart`, `refuse`, plus the unknown-key badge) with that class's tone, and the tone SHALL
never be the only channel — the panel's "state is never carried by color alone" rule applies here as everywhere.
No group heading SHALL name an effect class or carry a class's tone.

A key whose `group` is empty — a schema row that declares none, or a key the file carries and the schema does
not know — SHALL render under one visible trailing fallback heading, labelled from the tables, after the grouped
keys and before the seats block: it MUST NOT be dropped, merged into a group the command did not report, or
rendered without its own badge and command line. The seats block SHALL keep its own trailing heading, whose label
is distinct from every group heading.

#### Scenario: The headings are functional domains, not effect classes

- **GIVEN** a fixture contract and the view open in a 160-column fixture pane
- **WHEN** the rows render
- **THEN** the headings are the schema's functional labels in the read's order (身份与账本布局 before 工作流与门禁
  before 跨项目会议), no heading reads `立即生效`, `需要重启` or `只读`, the keys of one group render together in
  the schema's order, and a walk down the list stops only on key and seat rows — never on a heading

#### Scenario: A key added to the schema lands in its group, with the committed bundle

- **GIVEN** a scratch copy of the CLI whose schema carries `TEAM_ZZZ_TEST` with the group `workflow` and, in a
  second run, whose `TEAM_GATES` row carries `meeting`
- **WHEN** the committed `panel.js` renders the view against each
- **THEN** the new row appears under 工作流与门禁 in the first run and `TEAM_GATES` appears under 跨项目会议 in the
  second, each in the schema's own order inside its group, while `panel.js` is byte-identical between the runs

#### Scenario: A row without a group renders under the fallback heading

- **GIVEN** a scratch copy of the CLI whose `TEAM_GATES` row declares no group and a contract carrying a key the
  schema does not know
- **WHEN** the view renders
- **THEN** both rows appear under the visible fallback heading after the grouped keys and before the seats block,
  the schema key keeps its label, badge and command line, and the schema-unknown key is still read-only, named by
  its raw key and marked as unknown

#### Scenario: The class is a word on the row and its tone is redundant

- **GIVEN** the view open on a contract holding an `apply` key, a `restart` key and a `refuse` key
- **WHEN** the three rows render
- **THEN** each carries its own badge word, the `restart` badge is drawn in the theme's `warn` tone, the `refuse`
  badge in the theme's `dim` tone and the `apply` badge in the plain text tone, while the values beside them stay
  in the plain text tone
- **AND** a capture with the SGR sequences stripped still shows all three classes as words — colour is never the
  only channel

#### Scenario: The seats block keeps its own heading and no label collides with it

- **GIVEN** a fixture project with a roster and the view open
- **WHEN** the rows render
- **THEN** the seat rows appear under the tables' own seats heading, that heading's text differs from the
  per-seat-model group's heading, and the keys of that group appear under their own functional heading with the
  group's own order

#### Scenario: A heading is a section rule and it separates its own group

- **GIVEN** the view open on a contract whose read reports more than one group, in a pane tall enough to show
  two of them
- **WHEN** the rows render
- **THEN** every heading (the functional groups, the fallback group and the seats block alike) is drawn as a
  section rule — the label between the two `─` runs of a full-width rule line — while key rows and seat rows
  carry no section rule, so a heading is distinguishable from a row by shape and not only by tone
- **AND** a heading sits directly between the previous group's last row and its own group's first row: the
  heading itself is the visible separation between groups and no extra line is spent on one

### Requirement: The settings view fills the pane it is given and its row window grows with it

The project-settings view SHALL spend the height the frame hands it: the last row it draws SHALL be at most one
blank row above the key band at every pane height the frame can draw a card for, and the number of rows the
window draws SHALL grow with the pane. A row's price in the window's fit SHALL be what the row really draws —
one line per row, plus the line of a group heading when that heading's first row is inside the window — so a key
row's note never costs a second line. The two hidden-row count lines SHALL be a ceiling rather than a fixed
cost: a count line is spent only when the window really hides rows at that edge, and the line the counts do not
use SHALL go to the window instead of the page's blank space. The rows the window draws plus its `↑n` and `↓n`
counts SHALL equal the number of focusable rows the view holds. The space the rows do not use SHALL stay inside
the card (the detail view's own fill rule), so the key band remains the frame's last row. This SHALL hold in
every view state the block can render — the row list, the choice picker and the seat picker. It sharpens, and
MUST NOT weaken, the frame-level promise that a bounded frame fills the pane: there the spare height is spent
*inside the content area*, and this view's share of it is rows.

#### Scenario: The card fills the pane and the window grows with it

- **GIVEN** a fixture contract with more rows than any measured pane and the view open at the top of the list
- **WHEN** the pane is 45, 33, 30 and 25 rows tall
- **THEN** at every height the card's last drawn row is at most one blank row above the key band, the rows drawn
  plus `↑n` plus `↓n` equal the view's focusable row count (the command's keys plus its seats), and the 45-row
  pane draws at least eight more rows than the 30-row pane

#### Scenario: A short list keeps its blank space inside the card

- **GIVEN** the view open with a filter that matches a single key
- **WHEN** the frame renders in a tall pane
- **THEN** the card still ends at most one blank row above the key band, the blank space is inside the card, and
  the row, its heading, the command line and the audit footer are all still drawn

