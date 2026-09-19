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

### Requirement: A human can write to the PM from any page

`m` on any page SHALL open a bottom input line. Enter SHALL send the draft through the guarded delivery path
(`team draft send`; the `delivery-guard` capability owns the semantics) — the console itself MUST NOT paste or
send keys into the PM's pane. Esc SHALL cancel the compose and keep the draft in `state/draft.md`, restored on
the next compose. `C-e` SHALL hand the draft to `$EDITOR` and return to an intact frame, with rendering
suspended while the editor runs. The receipt SHALL be exactly one of three honest states — delivered, queued
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
- **WHEN** `C-e` opens `$EDITOR`, a second line is appended, the editor is saved and closed, and Enter is pressed
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

### Requirement: Settings are panel preferences in `state/panel.conf`, never the project contract

The settings overlay (`,`) SHALL edit exactly five preferences — language (`zh`/`en`), the default page, the
activity columns, the mouse and the density (`comfortable`/`compact`) — persisted in `state/panel.conf` and
applied immediately. A missing or corrupt `panel.conf` SHALL fall back to the defaults and MUST NOT fail the
render. The file is runtime state: it MUST NOT be read by `--print` or `--json`, MUST NOT be read by any command
other than the panel, and MUST NOT carry `TEAM_*` meanings — the overlay's activity-columns toggle overrides
`TEAM_MONITOR_ACTIVITY` for TUI sessions only. A `theme` key (`dark`/`light`, absent = auto-detect from the
terminal) MAY pin the theme; it is not an overlay item.

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
exit, and every documented key — `m`, `f`, `s`, `,`, Tab, `1`–`4`, `↑`/`↓`, `q`, and on the board page `←`/`→`
and Enter — SHALL have a clickable target that acts identically; the wheel SHALL scroll the current page's
scrollable region (one offset per page, one line per notch on pages 1–3, where there is no focused block — V15
F5 ruling; on the board page each lane carries its own offset and the wheel SHALL scroll the lane under the
cursor). A click on a kanban card SHALL focus it, and a click on the already focused card SHALL open its detail
view. Coordinates are 1:1: a click on a target activates that target (E6 §1.1 measured the full path, with
tmux's own mouse option in either state). With the preference off the console SHALL emit no mouse-reporting
sequence and clicks SHALL do nothing. The settings overlay is an in-page overlay, not a modal: it replaces the
page's blocks but keeps the title band, the tabs and the key band, so the footer chips still visible under it
stay clickable and act exactly as they do with the overlay closed, while the replaced blocks keep **no**
targets — a click at a block's former coordinates does nothing (V16 F-V16-4, ruled as the actual behaviour).
The same replacement rule SHALL apply to the detail view: while it is open, the kanban's cards keep no targets.
`r` (rebuild the cached blocks on demand) is the one named exception, because it is a keyboard-only key: it has
no chip in the key band and MUST NOT appear in the frame's target map, so "every affordance is clickable" counts
only the affordances the console shows (V16 F-V16-5).

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

### Requirement: The console is read-only except through three commands

Every block the console shows SHALL come from read-only reads, and the only state-changing actions the console
offers SHALL be the three global keys, each invoking the owning command as a subprocess: `m`/Enter →
`team draft send`, `f` → `team outbox flush` (both `delivery-guard`), `s` → `team standby on|off` (`watchdog`).
The console process itself MUST NOT write patrol, queue, inbox, board or ledger files, and v1 SHALL NOT grow a
fourth action. This is the design's read-only discipline made falsifiable.

#### Scenario: The three actions invoke their owning commands

- **GIVEN** a fixture project with one queued outbox entry and the console running in a fixture pane
- **WHEN** `f` is pressed, then `s`, then `s` again
- **THEN** `team outbox flush` ran (its own log line is the evidence), standby was on after the first `s` and
  off after the second (`team watchdog status` reports it), and the console wrote nothing under `state/outbox/`
  itself

#### Scenario: Undocumented keys change nothing

- **GIVEN** a fixture project with the hashes of `state/`, `docs/` and the inbox recorded
- **WHEN** the console runs through several undocumented keys and every read-only navigation key
- **THEN** no file outside the console's own three (`state/draft.md`, `state/panel.conf`, `state/panel-page`)
  changed

### Requirement: All visible text comes from external zh/en string tables

Every string the console renders SHALL come from the string tables — one table per language, `zh` and `en` at
minimum — and the two tables SHALL hold identical key sets with the same value shapes and no empty values. A
machine-checkable assertion of the key-set equality SHALL run in the gate (`skills/teamsmith/tests/smoke.sh`).
Switching the language preference SHALL take effect on the next frame.

#### Scenario: The key sets are asserted equal

- **GIVEN** the shipped string tables
- **WHEN** the key-set assertion runs, and then runs again with one key deleted from the `en` table
- **THEN** the first run exits 0 and the second exits non-zero naming the missing key

#### Scenario: The language switches live

- **GIVEN** the console running in a fixture pane in `zh`
- **WHEN** the overlay switches the language to `en`
- **THEN** a following frame's static labels are English

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
marked by a cursor glyph and the `selected` tone — never by color alone — and SHALL be tracked by entry id, so a
data refresh that reorders or extends the board does not move the focus to a different entry; when the focused
entry leaves the board, the lane's first card SHALL take the focus. A lane holding more cards than its visible
window SHALL scroll (`↑`/`↓` past the edge, and the wheel over the lane) and SHALL mark each edge that hides
cards with their count. The lane windows of the `done` and `dropped` history lanes SHALL anchor on the newest
cards.

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

### Requirement: A focused card opens a read-only markdown detail view

Enter (or a click on the already focused card) SHALL open a detail view that replaces the page's blocks — as
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
view SHALL be read-only: it adds no action key. Esc or `q` SHALL return to the board page and SHALL NOT collapse
the console — a documented exception to the global `q`, in force only while the detail view is open. The reader
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

