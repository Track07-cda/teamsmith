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
stdout is redirected, and `auto` (the default) SHALL be the rule above. Rendering SHALL exit 0, and every failure to
render (no runtime, unreadable project root, unusable terminal geometry) MUST exit non-zero with one line naming the
reason — an empty or partial panel MUST NOT be reported as success.

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

### Requirement: The layout is four ordered bands with a documented degradation order

The panel SHALL compose four bands in this order: A the status band (title, PM state, pending, queue, capacity),
B the agent table with the activity column, C the reserved visualization band (a labelled placeholder that reads no
extra data), D the key band. `--width N` and `--height N` SHALL override the terminal geometry for one frame, so the
layout is checkable without a terminal. When the height is smaller than the frame the panel SHALL drop bands in the
documented order — C first, then the capacity figures fold into the PM line, while A keeps the PM state and the
pending counts — and it MUST NOT write more rows than the height nor wrap a line that the width cannot hold.

#### Scenario: Band order is stable

- **WHEN** `team monitor --print --width 120 --height 29` runs on a fixture project
- **THEN** the first line names the project, the PM/pending line precedes the first agent row, the reserved band's
  label precedes the key line, and the key line is the last non-empty line

#### Scenario: The reserved band and the capacity figures fold away first

- **GIVEN** the same fixture project
- **WHEN** `team monitor --print --height 16` and `team monitor --print --height 10` run
- **THEN** neither output contains the reserved band's label, and the second output carries the capacity figures on
  the PM line while the first keeps them on their own line

#### Scenario: A tiny pane is not overrun

- **GIVEN** a fixture tmux pane of 60x8
- **WHEN** `team monitor --once` renders one frame there and the pane is captured
- **THEN** the capture has at most 8 non-empty rows and no row is wider than 60 columns

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

The run that owns the patrol window SHALL be the process that renders the panel and that runs one patrol tick per
`TEAM_WATCH_INTERVAL`; it MUST NOT create a second tmux window or leave a background worker behind. The flag that
turns the tick off today (`--no-watchdog`, renamed by `rename-watchdog-to-pulse`) SHALL keep the panel while
suppressing the ticks. The two observer modes (`--print`, `--json`) SHALL never tick, and no panel mode SHALL write
`queue` or patrol state other than what the tick itself writes.

#### Scenario: The tick-off flag leaves the panel alive

- **GIVEN** a fixture session and a sandbox project
- **WHEN** `team monitor --no-watchdog` runs in a fixture pane for two intervals and the pane is captured
- **THEN** the capture still shows the panel, `state/capacity.log` gained no line, and `tmux list-windows` gained no
  window

#### Scenario: One tick per interval, one process

- **GIVEN** the same fixture
- **WHEN** `team monitor` runs for three intervals
- **THEN** `state/capacity.log` gained one line per interval (±1 for the first), and the number of tmux windows and
  of processes in the session changed only by the panel's own

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

The panel SHALL read `state/outbox/` read-only and expose the queued entry count, the count under `held/`, the age of
the oldest queued entry and the number of forced deliveries, so that "N messages are waiting because the PM's box was
busy" is visible where the PM looks. A missing `outbox/` directory SHALL be rendered as zero, never as an error, and
the panel MUST NOT create it. The panel MUST NOT enqueue, claim, move or drain an entry: the drain belongs to the
sender, the tick and `team outbox flush` (`delivery-guard`).

#### Scenario: A missing queue is a zero

- **GIVEN** a fixture project with no `state/outbox/` directory
- **WHEN** `team monitor --json` and `team monitor --print` run
- **THEN** `panel.outbox.queued` is 0, the printed status band shows the zero, and `state/outbox/` still does not
  exist

#### Scenario: Queued, held and the oldest age come from the entry names

- **GIVEN** three entries named `<epoch-ms>-<seq>-pm.msg` under `state/outbox/` and one under `state/outbox/held/`
- **WHEN** `team monitor --json` runs
- **THEN** `panel.outbox.queued` is 3, `panel.outbox.held` is 1 and `panel.outbox.oldest_age_s` is the current time
  minus the oldest name's epoch in milliseconds, within two seconds

#### Scenario: Three render modes leave the queue byte-identical

- **GIVEN** a fixture project with two queued entries and their file hashes recorded
- **WHEN** `team monitor --print`, `team monitor --json` and one `team monitor --once` frame have run
- **THEN** both entries still hash the same, no file was added under `state/outbox/`, and `forced.log` and
  `HOLDING.log` did not grow

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

`TEAM_MONITOR_REFRESH` (default 5 seconds) and `TEAM_MONITOR_EVENTS` (default 4) SHALL keep their names and
meanings: the first is the TUI's redraw period and each redraw SHALL read the data layer once per frame rather than
poll it in a loop, the second is how many events per agent the activity column starts with. `TEAM_MONITOR_ACTIVITY` SHALL
change its default from `0` to `1` (the column is part of the layout now) and keep accepting `0`/`1` with the flags
overriding it. `TEAM_MONITOR_UI` SHALL be added with the values `auto` (default), `tui` and `text`. Every one of the
four keys SHALL be documented in `references/config.md` with its default and its effect.

#### Scenario: The redraw period is the redraw period

- **GIVEN** a fixture session and a fixture project running `TEAM_MONITOR_REFRESH=1 team monitor` in a pane
- **WHEN** the pane is captured twice with a 1.5 second gap between the captures
- **THEN** the second capture's timestamp line differs from the first, so the redraw follows the key

#### Scenario: The activity default is a documented contract change

- **GIVEN** a fixture project with `TEAM_MONITOR_ACTIVITY` unset and an event in the agent log
- **WHEN** `team monitor --print` runs, and then `TEAM_MONITOR_ACTIVITY=0 team monitor --print` runs
- **THEN** the first output contains the event and the second does not, and `references/config.md` names the new
  default for that key

#### Scenario: The UI key selects the renderer

- **GIVEN** a fixture project
- **WHEN** `TEAM_MONITOR_UI=text team monitor --once` and `TEAM_MONITOR_UI=tui team monitor --once` are redirected to
  files, and `team monitor --print` is redirected as well
- **THEN** the `text` output has no `0x1b` byte and equals the `--print` output apart from the timestamp

