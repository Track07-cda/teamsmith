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
the PM state, the pending counts (unread notifications, task reports awaiting review, blocked board rows, unread
meeting turns and their total), the deferred-delivery counts, and the capacity figures (RAM available in MB, swap
free in MB, the agent estimate, and for the filesystems a worker will write to — the temp root and the worktrees
root — their available bytes and free inodes, with a figure that cannot be read rendered as `—`, and a mini chart
built from the tail of `state/capacity.log`). The zram physical figure SHALL leave the panel and stay available in
`team watchdog status`. The same fields SHALL appear in `--json` under `panel.pm`, `panel.pending` (whose counts
object carries the unread-meeting count as `meetings` and includes it in `total`), `panel.capacity` and
`panel.standby` with the PM state in a closed vocabulary (`running`, `starting`, `absent`, `foreign`, `unknown`) and
standby as `{on, reason}`; `panel.capacity.disk` SHALL be one entry per judged filesystem carrying its path, its
available bytes and free inodes, or `null` for a figure that cannot be read.

The pending counts, their total and their human-readable text SHALL reflect the current pending snapshot rather
than the last reminded snapshot, even when a count-only change was suppressed by `TEAM_PULSE_NUDGE_GAP`. The
existing pending JSON fields (`inbox`, `reports`, `todo`, `wip`, `review`, `blocked`, `stopped`, `meetings`, `total`,
`text`) SHALL retain their count/text meanings: a category-only wake identity MUST NOT replace counts with
booleans. `team monitor --print`, `team monitor --json` and `team __panel-data --block pending` MUST remain
read-only and MUST NOT advance, clear or create reminder state. Rationale for observer modes and pending-only
patrols: `skills/teamsmith/references/config.md` and `skills/teamsmith/references/workflows.md` §I.

#### Scenario: The band mirrors the measured state

- **GIVEN** a fixture project with no PM window, one unread inbox line, two task reports without review records, one
  `blocked` board row, three queue entries and 40 `capacity.log` samples
- **WHEN** `team monitor --print` and `team monitor --json` run
- **THEN** `panel.pm.state` is `absent`, the pending counts are 1, 2, 1 and 4, `panel.outbox.queued` is 3, and
  `panel.capacity.ram_avail_mb` equals the last sample's value while `panel.capacity.spark` has at least two samples
- **AND** the printed status band contains the queue count and the PM state token, and carries no zram physical MB

#### Scenario: The disk readings reach the band and the JSON

- **GIVEN** `TEAM_DISK_STATS_FILE` holds figures for the temp root and the worktrees root
- **WHEN** `team monitor --print` and `team monitor --json` run
- **THEN** `panel.capacity.disk` holds one entry per judged filesystem with its path, available bytes and free
  inodes, and the printed band names each path with its measured availability

#### Scenario: A filesystem that cannot be read is not assigned a number

- **GIVEN** the temp root's figures cannot be read (no fixture row and no readable `df` result)
- **WHEN** `team monitor --print` and `team monitor --json` run
- **THEN** its `panel.capacity.disk` entry carries no availability number, and the printed band renders `—` for it
  rather than a value

#### Scenario: Standby is visible where the wake-ups are decided

- **GIVEN** a fixture project where `team standby on --reason "waiting for the user"` has run
- **WHEN** `team monitor --json` runs
- **THEN** `panel.standby.on` is true and `panel.standby.reason` is that reason, and the printed status band shows
  the reason on the title or PM line

#### Scenario: The band carries unread meeting turns

- **GIVEN** a fixture project with no unread inbox lines, no reports, no blocked rows and two unread peer turns
  across its meetings
- **WHEN** `team monitor --print` and `team monitor --json` run
- **THEN** `panel.pending.meetings` is 2, `panel.pending.total` is 2, `panel.pending.text` contains `未读会议 2`,
  and the printed band shows `未读会议 2`

#### Scenario: A suppressed reminder does not freeze the displayed counts

- **GIVEN** a running fixture PM reminded for one unread notification, `TEAM_PULSE_NUDGE_GAP=3600`, and a later
  tick inside that gap after the count becomes four without another pending category
- **WHEN** `team monitor --print`, `team monitor --json` and `team __panel-data --block pending` run
- **THEN** the JSON and pending block carry `inbox=4`, `total=4` and text containing `未读通知 4`, and the print
  shows the current unread count rather than one
- **AND** file contents and timestamps under `state/` remain the same across these observer reads, with no
  additional `state/nudges.log` line, new outbox entry or reminder-state update

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
(default 64 KiB, hard cap 1 MiB) and the `truncated` / `tail_limit` markers are still reported. The built-in Pi source SHALL use the complete current assignment SID/worktree, never the latest neighboring/base session; a missing identity or missing recorded file yields unavailable with a reason. Explicit custom log-glob behavior remains frozen and unchanged. The last six lines of
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

The read-only panel SHALL additionally expose impeded delivery count and reasons (`geometry-untrusted`, `queue-stalled`) from the delivery diagnostics in the status band and messages page, and as additive fields `panel.outbox.impeded` and `panel.outbox.impediments` in JSON. An impediment item SHALL name its entry id, target, reason and last observation time. The plain-text path SHALL expose the same impediment facts; a TUI-only field is not sufficient. Reasons MUST NOT be replaced by a draft-clearing promise. An unreadable diagnostic SHALL render as unknown/unavailable, never silently infer zero impediments. These observers MUST NOT capture a pane, advance drain observations, create a diagnostic or retry delivery; the existing flush subprocess owns all changes.

#### Scenario: An impediment is visible in every observer mode without mutation

- **GIVEN** a held `queue-stalled` entry and a held `geometry-untrusted` entry with recorded payload/diagnostic hashes
- **WHEN** `team monitor --json`, `team monitor --print` and a TUI messages frame render
- **THEN** JSON reports `panel.outbox.impeded=2` and both entry ids/reasons in `panel.outbox.impediments`; text and TUI name the same impediment count/reasons; all hashes and drain observation counts are unchanged, and the outbox block itself performs no pane capture or key operation

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
(a trusted read observed a draft) or held (a durable copy under `outbox/held/`) — mapped from the send command's
machine-readable outcome and exit code, never parsed from human prose. A `geometry-untrusted` or `queue-stalled` held outcome MUST retain that reason in the receipt rather than say that the PM has a draft or promise automatic delivery after clearing it. While composing, the input line SHALL
pause refreshing and every other block SHALL keep refreshing; multi-line input, pasted or typed, SHALL stay one
draft (a `\r` is normalized — E6 §2.2) and SHALL be sent as one message (E6 §2.1).

The draft SHALL settle with the receipt of the send that consumed it, and the input line and `state/draft.md` SHALL
never disagree about it. A settled receipt — `delivered`, `queued` or `held`, the three classes the receipt maps
from a machine verdict — SHALL empty the input line and `state/draft.md` together, so the next `m` opens an empty
draft and a relaunch after the send shows no ghost draft. A `held` receipt is a settle, not a loss: the entry is
durable under `state/outbox/held/` and the receipt names its reason, and for an `unconfirmed` hold the payload may
already sit in the PM's box — the console MUST NOT keep the draft as a retry handle, because re-sending it would
paste a message that may already have arrived and the guarded send's draft path carries no deduplication. A receipt
in the `error` class — no state the console can settle on: the bridge could not run or printed no verdict line, or
the guarded send exited non-zero, whatever durable copy its own reason names — SHALL keep the draft: the input line
and `state/draft.md` SHALL both still hold exactly the text that was sent, so the human's words survive the failure
and the next Enter retries from them. When the console cannot empty `state/draft.md` after a settled send it MUST
NOT report the draft as gone: the input line SHALL keep the draft and the receipt SHALL name the file it could not
empty, so memory and disk still agree and no ghost draft can surface on the next start. The existing entries keep
their meanings: Esc still keeps the draft between sends, an empty compose stays empty, and a draft the human deleted
with the compose line's own keys is not resurrected by a later receipt or a refresh.

#### Scenario: Geometry and stalled outcomes retain their machine reason

- **GIVEN** a compose send or flush subprocess returning a machine-readable held outcome with reason `geometry-untrusted` or `queue-stalled` and non-zero exit
- **WHEN** the panel displays its receipt
- **THEN** the receipt says held with that reason and durable entry id, not delivered or a draft-clearing promise; removing the reason mapping in a test process makes the receipt test fail

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

#### Scenario: A settled send empties the box and the file together

- **GIVEN** a fixture project with a fake TUI in the PM pane and the console composing `half a thought`
- **WHEN** Enter is pressed and the send settles as `delivered` (an empty PM box), and in a second run as `queued`
  (the PM's box holds someone else's draft)
- **THEN** in both runs the input line is empty, `state/draft.md` is 0 bytes, and a relaunch followed by `m` opens
  an empty compose rather than the sent text

#### Scenario: A held send is a settle, not a retry handle

- **GIVEN** the static-footer fixture PM pane (the send holds with reason `unconfirmed`) and the console composing
  `half a thought`
- **WHEN** Enter is pressed and the receipt settles as `held`
- **THEN** the input line and `state/draft.md` are empty, the receipt names the durable copy under
  `state/outbox/held/` and its reason, and the console offers no kept retry of the sent text

#### Scenario: A failed send keeps the human's words

- **GIVEN** a fixture whose draft bridge exits non-zero without a machine verdict, and a second run whose guarded
  send reports the target offline with no durable entry, with the console composing `half a thought`
- **WHEN** Enter is pressed and the receipt is the `error` class
- **THEN** the input line still reads `half a thought`, `state/draft.md` holds exactly that text, and a following
  Enter retries from it — the words exist nowhere else and are not lost

#### Scenario: A draft the console cannot empty is not reported as gone

- **GIVEN** the console composing `half a thought` and `state/draft.md` made read-only after the text was typed
- **WHEN** Enter is pressed and the send settles
- **THEN** the input line still reads `half a thought` and the receipt names `state/draft.md` as a file it could not
  empty, so memory and disk agree instead of a ghost draft surviving the send

### Requirement: Settings are panel preferences in `state/panel.conf`, never the project contract

The settings overlay (`,`) SHALL edit exactly five preferences — language (`zh`/`en`), the default page (`1`–`5`),
the activity columns, the mouse and the density (`comfortable`/`compact`) — persisted in `state/panel.conf` and
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

#### Scenario: Default-page preference includes key replies

- **WHEN** the default-page preference cycles through page 5 and persists it, and a later start has no page file
- **THEN** page 5 is available in the preference cycle and is restored as the default
- **AND** an invalid preference still falls back without failing the render

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
exit, and every documented key — `m`, `f`, `s`, `,`, Tab, `1`–`4`, `↑`/`↓`, `q`, on the board page `←`/`→`, `c`
and Enter, and on the work page the board rows (a click focuses a row, a click on the focused row opens its detail) —
SHALL have a clickable target that acts identically; the wheel SHALL scroll the current page's scrollable region
(one offset per page, one line per notch on pages 1–3 — V15 F5 ruling; on the work page `↑`/`↓` move the board-row
focus and the wheel keeps scrolling the page; on the board page each lane carries its own offset and the wheel
SHALL scroll the lane under the cursor). While the project-settings view is open the wheel is its region and MUST
NOT reach the page the view was opened from: it scrolls the view's row window — one row per notch, the row focus
unchanged, the view's hidden-row counts at both edges following the window — and with either of the view's
pickers open it walks that picker's entries instead; the `↑`/`↓` keys and the view's `↑/↓ 行` target SHALL keep
moving the focus and SHALL push the window so the focused row is inside it. A click on a kanban card SHALL focus it, and a click on the already
focused card SHALL open its detail view. A click on a lane's header line — the top border of an unfolded lane, or
a folded lane's single line — SHALL toggle that lane's fold, the same frame change `c` produces for the lane it
names; the folded line keeps the lane's wheel region, so the wheel over it MUST NOT scroll the page behind it.
Coordinates are 1:1: a click on a target activates that target (E6 §1.1 measured the full path, with
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

#### Scenario: The lane header is the fold key's target

- **GIVEN** the console on the board page in a fixture pane with the mouse preference on, the `todo` lane
  folded and the focus on another lane
- **WHEN** a click lands on the folded `todo` line, and a later click lands on the `c 折叠` chip
- **THEN** the first click unfolds `todo` exactly as `c` would act on that lane, and the chip click folds the
  lane the focus names — the key would produce the same frame

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

The TUI SHALL compose five pages — an overview (the status banner, the project-progress counts, the recent
deliveries, the agent table, the capacity sparkline, the recent events and the latest key-reply metadata), a work
page (the board rows, the active changes with their phases, the spec counts and the recent decisions), a
messages-and-logs page (the deferred queue, the inbox and threads, the patrol log, the capacity trend and the
health block), a board page (the kanban of "The board page is a kanban over the board's states") and a key-replies
page — plus a settings overlay. The first four pages MUST retain their existing numbers and meanings; page 5
SHALL be key replies, never project settings. A block whose source has no data SHALL collapse and yield its
space, except the key-reply summary and fixed key-replies page SHALL retain explicit empty/unavailable states
and the key-replies page SHALL retain its page identity. Tab and the
keys `1`–`5` SHALL switch pages, with Tab wrapping from 5 to 1. The current page SHALL be written to
`state/panel-page` and restored on the next start; a value outside `1`–`5` in that file SHALL fall back to the
default page, never fail the render. Pages are a TUI-only concept: `--print` and `--json` render the overview's
existing machine content, without reading key-reply blocks or exposing key-reply fields.

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

#### Scenario: Fifth page is fixed and remembered

- **WHEN** `5` selects key replies in an empty fixture, the console restarts, and Tab is pressed
- **THEN** the empty key-replies page remains identifiable, restart restores page 5, and Tab returns to page 1
- **AND** keys `1`–`4` still reach their original pages

#### Scenario: Narrow tabs remain reachable

- **WHEN** a 59-column fixture switches pages by `1`–`5`, Tab and mouse in both languages
- **THEN** the active tab's number and label remain visible and the page band provides reachable targets for all five pages without horizontal overflow

### Requirement: The board page is a kanban over the board's states

With no label filter, the board page SHALL render every BOARD.md row as a card. An explicit label selection
SHALL limit cards to matching task-table rows. The six state lanes SHALL keep the fixed order the
BOARD.md header legend declares (`todo`, `wip`, `review`, `done`, `blocked`, `dropped`). Every lane SHALL render
even when it holds no card — an unfolded empty lane shows a dim empty marker, an empty lane folded by default
shows its folded line — so lanes never shift position between frames. A card's line SHALL carry the entry's id,
the state glyph and its title, truncated to the lane width; the agent and the phase token from its task brief's
`phase:` header MUST NOT render on a card's line — they are demoted out of the lane's width (an entry with no
brief or no `phase:` line renders the placeholder in the demoted pair, never on the card). On the board page the
key band SHALL carry the focused card's demoted pair from the width its own key chips leave free: with room
`agent · phase`, and, as that width shrinks, the phase alone before the pair disappears — the agent is dropped
before the phase, and the pair before the band's chips are disturbed. The degradation order SHALL therefore be
explicit — agent, then phase, then the title — and the card line starts at the title, so no width exists at which
a card truncates its title to keep an agent or a phase. Labels and priority MUST NOT occupy card-line space.
At 100 columns and wider the lanes SHALL be side by side with an even share of the usable width among the lanes
that are not folded (a folded lane's one line takes the width it needs; the lane-fold requirement owns that
share); under 100 columns the page SHALL degrade to a single column grouped by state in the same lane order;
under 60 columns the card keeps its one-line form (state glyph, id, title), the id SHALL NOT be the field that
drops, and the title SHALL truncate last. The focused card SHALL be
marked by a cursor glyph and the `selected` tone — never by color alone — and SHALL be tracked by **row
identity**: the entry id together with the row's occurrence among the rows carrying that id, in BOARD.md order.
In the interactive board page's default order, each lane SHALL show rows with a valid task-table update time first, in descending
time order. Equal times SHALL keep BOARD.md order. Rows without time follow: in `todo`, `wip`, `review` and
`blocked` they keep BOARD.md order; in `done` and `dropped` they run from the file's tail towards its head. The
history lanes' initial windows SHALL start at the head of that display order, not reproduce the old bottom-aligned
offset. With no recorded times the first history window therefore starts with the rows from the old tail, without
ascribing a time to those rows. In a grouped layout this is the order within each lane, not a new page-wide
sort or a separate scroll window per lane. The update time MUST NOT be printed on the card. A label filter
without a priority selection SHALL preserve this order among matching rows. In explicit priority order each
lane SHALL start at its highest ranks, subject to the existing focus and scroll behavior.

Rendering, the visible window, arrow navigation and pointer targets SHALL agree on that order at both layout widths.
Clicking an unfocused card SHALL focus its original row; clicking a focused card SHALL open that frame's row,
not a position reinterpreted after sorting. Enter SHALL open the selected original row. A refresh that changes
the display order or the row's state SHALL keep addressing the same original row while its identity is still
available and the row is eligible. A row is eligible if it belongs to the current view's filtered set, including
cards outside its current window or in a folded lane, or to the unfiltered view when no filter is selected.
Two rows with one id remain separate stops with the cursor on exactly one; the occurrence is counted before
sorting, not in the lane. The identity does not distinguish identical ids that a manual edit exchanges or
inserts before an existing occurrence. When that occurrence is unavailable or ineligible, the first eligible
row carrying its id SHALL take the focus. If no eligible row carries that id, the old lane's first included card
SHALL take the focus, or the first included card of the first nonempty lane if that lane emptied. If none exists,
Enter SHALL open no card. A lane holding more cards than its
window SHALL scroll (`↑`/`↓` past the edge, and the wheel over the lane) and SHALL mark each edge that hides cards
with its count. In the side-by-side layout, the wheel MAY deliberately scroll a lane away from its selection as
before. Reordering SHALL adjust a window only when it would move a previously visible selection out of view,
without resetting unrelated windows or undoing that deliberate scroll. The narrow grouped layout SHALL keep
one page window and continue keeping its focused row in that window when scrolling and navigating. Folding,
detail discovery and work-page actions keep their existing contracts.

Filtering and ordering SHALL NOT mutate the source rows, their counts, or the work page's order or history
selection; when a label is selected the board page SHALL show matching counts. The optional row time belongs to the existing internal board block; public `--json` keeps its
existing output shape and `--print` keeps its existing order and window even when given page 4.

#### Scenario: Six lanes at the reference geometry

- **GIVEN** a fixture project whose BOARD.md holds rows in `todo`, `wip`, `review` and `done`, and the console on
  the board page in a 160-column fixture pane
- **WHEN** one frame renders
- **THEN** the capture shows the six lane headers in the legend order, the cards under their states, and the
  empty `blocked` lane rendered as its folded line with its count `0` instead of a boxed empty lane

#### Scenario: A card carries id, agent, phase and title

- **GIVEN** a fixture row `M9` whose task brief's header declares `phase: apply`, a row `X1` with no task
  brief, and the console on the board page with the focus on `M9`
- **WHEN** one board-page frame renders at 160 columns
- **THEN** the frame carries M9's id, agent, `apply` token and title across the two surfaces the requirement
  names — the card's line shows the state glyph, `M9` and its title and neither the agent nor `apply`, while
  the key band carries M9's agent and `apply`; after the focus moves to X1 the band carries the placeholder
  where the phase would be, and no card line carries an agent or phase token

#### Scenario: The title is the line's last truncation

- **GIVEN** a fixture board whose card carries a long title and an agent, and the console at 190 columns with
  the focus on that card
- **WHEN** the frame renders there and again in a pane narrow enough that the band cannot carry the pair
- **THEN** the card's line carries the glyph, the id and the title with no agent or phase token in both frames —
  the title is never squeezed by the demoted fields, and the id is never the field that drops

#### Scenario: The demoted pair drops the agent before the phase

- **GIVEN** the same fixture and three pane widths — one where the band's free width fits `agent · phase`, one
  where it fits only the phase, and one where it fits neither
- **WHEN** the board page renders at each width with the card focused
- **THEN** the band carries `agent · phase`, then the phase alone, then neither, while the key chips the band
  documented at that width stay in place (the pair never pushes a chip out)

#### Scenario: Narrow terminals degrade to one grouped column

- **GIVEN** a fixture whose board does not fit in one page window and contains a lane with timed rows
- **WHEN** the board page renders at 99 and at 59 columns and arrow navigation moves past the window edge
- **THEN** both widths stack the states in the legend order with the same within-lane order as in the wider
  layout; the single window follows the selected row, and at 59 columns the card remains one line with
  state glyph, id and title, without agent or phase

#### Scenario: The focus survives a refresh

- **GIVEN** `M9` was added before `M8` with distinct times, the two tasks are in one lane, and the console
  shows `M8` above the selected `M9`
- **WHEN** `M9` actually changes agent later, the board page refreshes, a still later operation repeats
  `M8`'s current agent, and the page refreshes again
- **THEN** `M9` moves above `M8` in both grouped and side-by-side layouts, stays selected as the same row,
  and the repeated operation changes neither `M8`'s time nor the displayed order
- **AND** moving from `M9` to `M8` with `↓` and pressing Enter opens `M8`'s file; after returning, focusing
  and opening `M9` by its drawn card opens `M9`'s distinct file
- **AND** when the selected id later leaves the board, the same lane's first displayed card receives focus

#### Scenario: A long lane scrolls and counts what it hides

- **GIVEN** a side-by-side board with `done` and `dropped` lanes that each exceed their visible window,
  each containing two rows with distinct times in the opposite file order and several rows with no valid time
- **WHEN** the board page first renders, and the focus then moves down past the window's edge
- **THEN** each history lane's first window starts with its two timed rows, newest first, followed by
  the undated rows from the file's tail, with an edge count for what is hidden below
- **AND** the window scrolls with the focus, and wheel-down over an unfolded history lane exposes
  previously hidden older rows without changing the selected row

#### Scenario: Two rows with one id are two stops

- **GIVEN** two `M39` rows in one active lane with different titles and equal valid times in a task table,
  followed by an undated `M48` and a row with an invalid time
- **WHEN** the page renders, the user moves from the first `M39` row to the second, and an agent assignment
  really changes only that selected row before a refresh
- **THEN** the two `M39` rows were distinct stops in file order and the undated rows follow them in file
  order; after refresh the second `M39` moves above the first and is still the only row with the cursor
- **AND** `↓` can reach the first `M39` and continue to `M48`; pressing Enter on the second `M39` and
  returning keeps that row selected by its title even though the detail files are shared by id

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

The reader SHALL serve the console's read-only previews through that same block and that same contract — the same
file-list-plus-one-body shape, the same 128 KiB bound, the same off-input-path assembly and the same sanitizer —
addressed by an explicit source. `--source spec --id <capability>` SHALL serve `openspec/specs/<capability>/spec.md`
as one tab; `--source change --id <change-id>` SHALL serve that change's own `proposal.md`, `design.md` and
`tasks.md`, in that order and one tab each, MUST NOT invent a file the change does not have, and MUST NOT serve a
file of any other change or of the archive directory **by its own path** — a change directory that is a symbolic
link resolving inside the project root is served as the change its id names, and the archive answers nothing when
addressed by its own directory name; `--source decision --id <D-number>` SHALL serve the body
of that decision entry out of `docs/team/DECISIONS.md` as one tab. A reader that is given no source keeps its
present meaning (the entry-id families above), so an existing caller behaves exactly as it does today. The sources'
roots are the reader's own project root: the spec and change sources read only under the openspec directory the
panel's other readers already resolve, the decision source only the ledger's `docs/team/DECISIONS.md`, and the entry
source only the three ledger directories above. A request whose source is outside that closed set, whose id leaves
its source's grammar (`[A-Za-z0-9._-]` for a capability or change id, `D<digits>` for a decision), or whose `--file`
is not one of the paths the requested source discovered SHALL fail with a non-zero exit and one line naming what was
refused, printing no file content. A discovered path that is a symbolic link SHALL be resolved to its real path
before it is judged: a real path that stays inside the reader's project root SHALL be served, and every
symbolic-link segment the read passed through SHALL be reported with the block rather than hidden; a real path that
leaves the project root SHALL be refused and named together with both the real path and the project root, and never
read through. A discovered path that is not a regular file — a FIFO, a device, a directory, a socket or a broken
link — SHALL NOT be opened at all: it SHALL be refused and named with its kind, so a corrupt or hostile ledger entry
can neither be served nor block the console. The decision source serves exactly one entry and offers no whole-file
exit: its `--file` selects the ledger
file it discovered, and the body is always the requested entry's slice. A target that does not exist is not an
error: the block SHALL answer with an empty file list and a human-readable reason, the detail view SHALL say that
the source is unavailable rather than render an empty document as a successful read, and no mode SHALL crash. The
decision entry SHALL be located by its id heading (`##` or `###`, the id followed by a non-digit) and its body SHALL
run to the next heading at that level or higher — a same-id addendum one level deeper stays inside the body — cut by
the same 128 KiB bound when the entry is longer. The previews SHALL be console-only: `--print` and `--json` MUST NOT
read them or add a field, opening and closing one SHALL leave the machine frame byte-identical apart from the
timestamp, and reading one SHALL write nothing outside the console's own three files. The previews inherit the
display contracts of the detail view they extend — sanitize before layout, the width tiers, the themes and the zh/en
tables — and add no action key of their own.

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

#### Scenario: A capability's spec opens as one tab

- **GIVEN** a fixture project whose `openspec/specs/demo/spec.md` holds two requirements and a decoy
  `openspec/specs/demo/notes.md`
- **WHEN** `team __panel-data --block detail --source spec --id demo` runs and the detail view opens on it
- **THEN** the file list is exactly that one spec.md with one tab, the body is that file's text, and no decoy is
  listed or served

#### Scenario: A change's three artifacts are its tabs, in order

- **GIVEN** a fixture change holding `proposal.md`, `design.md` and `tasks.md`, and a second fixture change whose
  `design.md` is absent
- **WHEN** each is read through `--source change` and opened in the detail view
- **THEN** the first serves three tabs in the order proposal, design, tasks and the second serves exactly its two
  existing artifacts — no tab is invented for the missing file, and neither read serves a file of the other change
  or of `openspec/changes/archive/`

#### Scenario: A decision opens at its number and ends at the next heading

- **GIVEN** a fixture `DECISIONS.md` whose `D7` entry sits at `##` between `D6` and `D8`, carries a deeper
  `### D7 补记` addendum inside it, and whose `D8` follows at `##`
- **WHEN** `--source decision --id D7` and `--source decision --id D8` are read, and then a number the file does not
  carry
- **THEN** the `D7` body starts at its heading, includes the deeper addendum and stops before `D8`; the `D8` body
  stops at the next `##` heading; and the missing number answers with an empty file list and an unavailable reason
  rather than a neighbouring entry's text

#### Scenario: Every preview source refuses what is outside it

- **GIVEN** the fixture spec, change and decision above
- **WHEN** `--source spec --id ../../etc` runs, then `--source spec --id demo --file
  openspec/changes/other/proposal.md`, then `--source change --id demo --file openspec/specs/demo/spec.md`, then
  `--source decision --id D7 --file docs/team/BOARD.md`, then `--source decision --id 7`, then `--source bogus
  --id demo`
- **THEN** every one of them exits non-zero and prints no file content, and each line names the source, the id or
  the path it refused

#### Scenario: A symlinked path that stays inside the project opens

- **GIVEN** a fixture whose ledger root is a symbolic link to a ledger tree elsewhere in the same project, and whose
  `openspec/changes/<id>` is a symbolic link to another change of the same project
- **WHEN** the entry detail view opens and `--source change --id <id>` runs
- **THEN** both reads return count > 0 with the real body, report the symbolic-link segments they passed through,
  and answer with no unavailable reason — the ledger and the change previews stay readable through the links,
  while a change the fixture does not have still answers with an empty list

#### Scenario: A symlinked entry is refused, never read through

- **GIVEN** a fixture whose `openspec/changes/demo/proposal.md` is a symbolic link to a file outside the project root,
  and whose ledger root is a symbolic link to a directory outside the project root
- **WHEN** `--source change --id demo` and the entry detail view run
- **THEN** both refuse with count 0 and print no file content, each reason names the real path **and** the project root
  it left, and the change's other two artifacts still open with both reads still exiting 0

#### Scenario: A non-regular discovered path is refused and named

- **GIVEN** a fixture whose `docs/team/reports/<ID>-dev.md` is a FIFO, directly or through a symbolic link
- **WHEN** the entry detail view runs under a ten-second bound
- **THEN** it returns within that bound with count 0 and prints no content, and its reason names the path and that it
  is a FIFO; `--file` naming that path exits non-zero

#### Scenario: A preview body is bounded and sanitized

- **GIVEN** a fixture capability whose `spec.md` is 200 KiB and a fixture change whose `tasks.md` carries
  `ESC [2J` inside a fenced block
- **WHEN** each is read through its source in the detail view and the pane is captured
- **THEN** the long body carries the truncation marker and the read exits 0 within the reader's bound, and the
  capture holds the fence's visible text with no `0x1b` byte

#### Scenario: The previews stay off the machine exits and out of the write sweep

- **GIVEN** a fixture project with the hashes of `docs/`, `openspec/` and `state/` recorded and a stored
  `team monitor --print` / `team monitor --json` pair
- **WHEN** a spec, a change and a decision preview are opened, their tabs switched, their bodies scrolled and the
  view closed
- **THEN** both stored machine outputs are unchanged apart from the timestamp and carry no preview field, and no
  file outside the console's own three changed

#### Scenario: Preview tabs remain reachable in a narrow pane and both languages

- **GIVEN** a fixture change with three artifacts, a 59-column fixture pane, and the zh and en tables in turn
- **WHEN** its preview opens and its tabs are switched by keyboard and by click
- **THEN** the tab row still names the open tab, every tab remains reachable without horizontal overflow, the
  active-page identity and the key band stay visible, and no preview row is wider than the pane

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

Every row the work page draws for an entry the detail view can open SHALL be focusable on the same terms, and the
page SHALL report one drawn-row order across its blocks: the blocks in the order the layout placed them (today the
board block, then the changes, the specs and the decisions block), and inside a block the order the block drew its
rows — so `↑`/`↓` cross from a block's last drawn row to the next block's first drawn row, exactly one row carries
the cursor glyph at every step, and the first press with no focus yet focuses the first row of that order. A block
that is empty, degraded to its summary line, or absent from the frame SHALL contribute no row to that order, no
cursor and no focus target. A row's source is fixed by the block it was drawn in — the board block's rows are
`entry`, the other three are `change`, `spec` and `decision` — and it is that source together with the row's id (the
change id, the capability name, `D<digits>` for a decision) that `enter`, or a click on the already focused row,
hands to the detail view; a row's display title is never its id, and `--file` is never composed by the console from
a title. The preview a preview row opens behaves exactly as a board row's detail does: it renders on the page it was
opened from, `esc`/`q` returns to that page without collapsing the console, and while any work-page row is focused
the key band names the row keys.

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

- **GIVEN** a fixture project whose BOARD.md has no rows and whose changes, specs and decisions blocks draw no row
  either, the console on the work page in a 120x30 pane, and then a second fixture with rows in a 60x10 pane where
  the blocks degrade to their summary lines
- **WHEN** `↓` and `enter` are pressed in each
- **THEN** neither capture carries a focus cursor and no detail view opens, and each frame's click-target map holds
  no `focus` and no `open-focused` action on the work page
- **AND** a third fixture whose board is empty but whose specs block draws one row focuses that row on the first
  press and opens its preview — an empty board is not a reason to drop a live row

#### Scenario: Duplicate rows are two stops on the work page too

- **GIVEN** a board whose rows are `M39` (first duplicate), `M39` (second duplicate) and `M48`, and the console on
  the work page
- **WHEN** the page renders and `↓` is pressed past the two same-id rows
- **THEN** exactly one row carries the cursor at each step, both `M39` rows are separate stops that the walk
  reaches in drawn order (the second does not restart or freeze on the first), and the next press reaches `M48`

#### Scenario: A spec row opens its preview without leaving the work page

- **GIVEN** a fixture project whose specs block draws the row `demo` and the console on the work page in a 120x30
  fixture pane (`state/panel-page` holds `2`)
- **WHEN** the walk is moved onto that row and `enter` is pressed, and then `esc` closes the view
- **THEN** the detail view shows the `demo` capability's spec with its one tab, the close returns to the work page,
  and `state/panel-page` still holds `2`

#### Scenario: A change row and a decision row open their own sources

- **GIVEN** the same fixture whose changes block draws the change `demo` and whose decisions block draws `D7`
- **WHEN** each row is opened with `enter`
- **THEN** the change's view carries its artifact tabs and the decision's view carries the `D7` body, neither view
  can be reached from the other row, and each close returns to the work page it was opened from

#### Scenario: One cursor walks the page's drawn rows across the blocks

- **GIVEN** a fixture work page whose board block draws two rows and whose specs block draws one row, in a pane
  where both blocks draw their rows
- **WHEN** `↓` is pressed from no focus and then twice more
- **THEN** the first press focuses the board's first row, the second its second row, the third crosses to the spec
  row — all three in the frame's drawn order — and exactly one row carries the cursor glyph at every step

#### Scenario: A preview row's click focuses it, the second click opens it

- **GIVEN** the console on the work page in a fixture pane with the mouse preference on
- **WHEN** a click lands on a spec row and a second click lands on the same row
- **THEN** the first click moves the cursor onto that row and the second opens its preview, exactly as a board
  row's clicks do

### Requirement: The console writes a project setting only through `team config set`, after validation and a confirmation

Category rows use `team config set-task-model` with the same dry-run, fingerprint, actor, confirmation, receipt and background re-read rules; PM uses `team config set TEAM_PM_MODEL`. Model-policy receipts SHALL distinguish next new task from exact same-task recovery and say no live process changed. The concurrent-tasks-by-model form uses the same whole-value validation, confirmation and writer below; model/count subfield choices only edit its unsaved draft. Other editable rows' `enter` SHALL open the row's editor: the **choice editor** (the requirement that owns it) when
the command's read reports a choice set for the key, and otherwise a one-line value editor that is the compose
line's editor (the insertion point, pi's key map, the windowed draft — the `panel` requirement that owns it)
holding the file's value, or the schema's default when the key is not in the file. Whichever editor opened, the
value it leaves — the entry the human accepted, or the text they typed — SHALL be the write this requirement's
validation and writer then consume, and the editor selection MUST NOT change any step below. In the **free-text
editor** `enter` SHALL NOT write: it SHALL ask the owning command for a validation (`team config set … --dry-run`,
a read that writes nothing) and, when accepted, show a confirmation line with the user-facing label, the old value, the new
value and the operation's actual timing (and, for a `restart` class, the exact restart command); a second `enter` SHALL
perform the write by invoking `team config set … --yes` as a subprocess, and `esc` SHALL cancel with nothing
written, no audit line and no temporary file left behind. For a value the human **accepted from the choice
editor**, the same validation and the same write SHALL happen on that accept — `--dry-run` first, then `--yes`
with the fingerprint the editor's read carried — and no confirmation frame SHALL be drawn, except for a value the
command reports as dangerous: that SHALL NOT be written by the first accept however it was chosen, the
confirmation line SHALL carry the warning and require one more `enter`. The receipt SHALL be one honest line
mapped from the command's exit code — written (with the class's timing), refused as read-only, rejected as invalid
(naming the accepted domain), refused because the file changed under the editor, or a write error that says the
file was left unchanged — and MUST NOT be parsed from human prose. On a conflict the view SHALL reload the
contract and display the other writer's value; on any settle the list SHALL be re-read in the
background, and that re-read MUST NOT hold the receipt frame. The audit SHALL stay readable where it already
lives — `state/config.log`, `team config list`'s own footer and `team config log` — and the console SHALL NOT be
one of its readers: the selected-item area carries only necessary operation/timing information and nothing
from the log, not a repeated config-set command line. The console MUST NOT open the
contract for writing itself: every byte of `.pi/team/config.sh` changes through the owning command (the wrapper's
argv log is the evidence), and a `restart`-class write SHALL NOT claim it took effect — the running process keeps
the old value until the appropriate restart, and the receipt names that process. Category receipts say new tasks
only; PM model changes require guarded fresh PM startup; check-interval changes require Pulse restart. The panel MUST NOT offer an action that restarts
the pulse: it runs inside the pulse window and would kill itself; the restart command is printed instead.

#### Scenario: An edit writes one line and keeps every other byte

- **GIVEN** a fixture contract whose line reads `TEAM_PULSE_INTERVAL="900"  # 15min` among comments and other keys
- **WHEN** the row is opened, `1200` is typed, `enter` is pressed twice, and the receipt says written
- **THEN** `bash -n .pi/team/config.sh` exits 0 and `diff` shows exactly one changed line, which reads
  `TEAM_PULSE_INTERVAL='1200'  # 15min`

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

- **GIVEN** the editor holding `30` for retained `TEAM_REVIEW_TIMEOUT`, which the unchanged command reports as dangerous, with the contract's sha256 recorded
- **WHEN** `enter` is pressed once
- **THEN** the confirmation line carries the danger warning, the sha256 is unchanged and no audit line exists
- **AND** when `enter` is pressed again the value is written and the receipt carries the actual warning and timing

#### Scenario: A restart-class write does not claim it took effect

- **GIVEN** a running Pulse using check interval 900, and the row for `TEAM_PULSE_INTERVAL`
- **WHEN** it is set to `1200` and the write settles
- **THEN** the receipt names the pulse restart, no restart is invoked by the panel, and the written setting reads back as 1200 without claiming the running Pulse adopted it

#### Scenario: The audit is readable from the view and from the CLI

- **GIVEN** a value written with the panel as the actor
- **WHEN** the contract's own human read (`team config list`, whose footer is the audit tail) and `team config log 5` run
- **THEN** both show the same newest line naming the timestamp, the actor, the key, the old and the new value — the
  audit stays readable from the contract's own reads, exactly as it was before this change, and `state/config.log`
  still grew exactly one line for the write
- **AND** the console's settings view is deliberately not one of its readers: the rendered frame carries no audit
  heading and no audit line, and drawing that tail again in a scratch copy of the view turns the fixture red

### Requirement: The console is read-only except through its owning commands

Every block the console shows SHALL come from read-only reads, and the only state-changing actions the console
offers SHALL be the ones that invoke the owning command as a subprocess: `m`/Enter → `team draft send`, `f` →
`team outbox flush` (both `delivery-guard`), `s` → `team standby on|off` (`watchdog`), and the project-settings
view's confirmed configuration edit → `team config set` or `team config set-task-model` (`memory-and-deps`, which owns the contract's write path). The same view's task-label definition form, on Save or confirmed Delete, invokes `team board label define|edit|delete` (`board-and-status`). The console
process itself MUST NOT write patrol, queue, inbox, board, ledger or contract files: the contract is written by
the command, never by the panel, and the only files the console writes on its own are its three
(`state/draft.md`, `state/panel.conf`, `state/panel-page`). No other project write is offered. An in-panel pulse
restart is deliberately not an action, because the console runs inside the pulse window and would kill itself; a
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
  project-settings view's navigation, including the label list, and a cancelled edit
- **THEN** no file outside the console's own three changed, and the contract's audit log did not grow

#### Scenario: The paste writes outside the project and runs no command

- **GIVEN** a fixture project with the hashes of `state/`, `docs/` and the inbox recorded, an image clipboard, and a
  `team` CLI wrapper that logs every invocation
- **WHEN** `C-v` is pressed in the compose line and the paste settles
- **THEN** the temp file exists under `TMPDIR` with the image bytes and the draft holds its path, while no file
  outside the console's own three changed and the wrapper's log gained no line

#### Scenario: The label form invokes only its definition command

- **WHEN** a user navigates the label list, cancels an edit or declines the separate deletion confirmation, then saves a change to an existing definition
- **THEN** reading and cancellation invoke no label write; saving invokes only `team board label edit` for the current project with the changed fields
- **AND** no config writer runs and the configuration, its audit, panel preferences and board bytes, including task-update times, remain unchanged

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

### Requirement: The settings view fills the pane it is given and its row window grows with it

The project-settings view SHALL spend the height the frame hands it: the last row it draws SHALL be at most one
blank row above the key band at every pane height the frame can draw a card for, and the number of rows the
window draws SHALL grow with the pane. A row's price in the window's fit SHALL be what the row really draws —
one line per row, plus the line of a group heading when that heading's first row is inside the window — so a key
row's note never costs a second line. The two hidden-row count lines SHALL be a ceiling rather than a fixed
cost: a count line is spent only when the window really hides rows at that edge, and the line the counts do not
use SHALL go to the window instead of the page's blank space. The rows the window draws plus its `↑n` and `↓n`
counts SHALL equal the number of focusable rows the view holds (excluded keys and headings are not focusable and are not counted; only the current view's
operations, navigation, rule fields or record rows count). The space the rows do not use SHALL stay inside the card (the detail view's own fill rule), so the key band remains the frame's last row. This SHALL hold in
every view state the block can render — the default and secondary lists, the choice picker and the concurrent-tasks-by-model editor. It sharpens, and
MUST NOT weaken, the frame-level promise that a bounded frame fills the pane: there the spare height is spent
*inside the content area*, and this view's share of it is rows.

#### Scenario: The card fills the pane and the window grows with it

- **GIVEN** a fixture with enough actual categories to exceed every measured pane and the view open at the top of the list
- **WHEN** the pane is 45, 33, 30 and 25 rows tall
- **THEN** at every height the card's last drawn row is at most one blank row above the key band, the rows drawn
  plus `↑n` plus `↓n` equal the view's focusable row count (the current view's actual focusable row set, not all command keys or off-view records), and the 45-row pane draws at least eight more rows than the 30-row pane

#### Scenario: A short list keeps its blank space inside the card

- **GIVEN** the view open with a filter that matches a single key
- **WHEN** the frame renders in a tall pane
- **THEN** the card still ends at most one blank row above the key band, the blank space is inside the card, and
  the row, its heading and any necessary selected-item timing remain reachable, without adding excluded settings

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

### Requirement: The agents block carries each seat's death cause

`team __panel-data --block agents` (and through it the `agents` block of `team monitor --json`) SHALL add,
for every seat whose current launch has an abnormal death, `cause` (the category), `cause_source`
(`pane`, `session` or `recorded`) and `cause_line` (the raw evidence line, sanitized), plus `cause_time`
when the record time is known. A seat without an abnormal death SHALL carry none of these keys, and the
new keys MUST NOT change the existing `state` vocabulary or the `pane`/`pane_exit` keys. A running seat
MUST NOT carry a cause. The block SHALL stay read-only: no file under `.pi/team/state/` may change
contents or timestamps because of it.

The printed agent table SHALL append the category to the seat's state cell (for example
`▲ 已死 signal=9 · quota`) whenever the table renders its full state text; in its minimal layout the
token may drop with the state text, and `cause_line` stays available through the block and
`team status <ID>`.

#### Scenario: The block carries the cause for a quota corpse

- **GIVEN** the quota corpse fixture (a dead pane whose scene ends with the `403 permission_error`
  frame) with an unfinished recorded task
- **WHEN** `team __panel-data --block agents` runs
- **THEN** that seat's entry carries `cause` `quota`, `cause_source` `pane`, and a `cause_line` holding
  the raw frame — while its `state` stays `exited`, its `pane` stays `dead` and its `pane_exit` keeps the
  exit evidence

#### Scenario: A running seat carries no cause key

- **GIVEN** a seat proven alive beside the corpse of the previous scenario
- **WHEN** the agents block is read
- **THEN** the running seat's entry has no `cause`, `cause_source`, `cause_line` or `cause_time` key

#### Scenario: The printed row shows the token and the machine block keeps the raw line

- **GIVEN** the quota corpse fixture and a panel width that renders the full agent table
- **WHEN** the panel's agent table is printed
- **THEN** that seat's state cell carries `quota`, and the block's `cause_line` still carries the full raw
  frame

### Requirement: A lane folds from its header, and empty lanes fold by default

The board page SHALL fold and unfold each lane from its header. A folded lane SHALL render as exactly one line
carrying its label, its card count and the folded text marker, and SHALL NOT render any of its cards, any edge
counter, or the empty-lane marker; each lane keeps its position in the fixed lane order, so folding never
reorders the board. A folded lane's column SHALL keep the lane body's height — its one line draws at the top and
the rows below stay blank — so the frame stays filled and the key band stays the frame's last row. The fold
marker SHALL be a glyph together with a text token, never colour alone, and the header of an unfolded lane SHALL
carry the mirror marker so the toggle is visible in both states.

Folding changes the width share, not the lane order: a folded lane's line SHALL take the width it needs, bounded
by a documented floor, and the lanes that are not folded SHALL share the remaining usable width — folding a lane
widens the lanes that still show cards. When the width cannot satisfy every unfolded lane's floor, the folded
line SHALL truncate first: the fold degrades before the cards' shares do.

A folded lane's presentation follows the pane's width tier, because the scarce resource differs by width. In the
tiers where the board draws its lanes side by side, a folded lane SHALL take a three-column frame: a rounded
corner at each of its four corners (the panel's own corner glyphs, `╭ ╮ ╰ ╯`), a vertical border on each side and,
in the middle column, the ellipsis (`╭─╮` over `│…│` over `╰─╯`, the middle column drawn down the lane's height
as the ellipsis). The folded lane SHALL keep its position in the fixed lane order, so the frame alone says which lane it
is, and the whole width the three columns do not use SHALL go to the unfolded lanes — folding gives columns back,
and the lane row SHALL NOT render wider than the usable width in any tier. The focused folded lane SHALL name
itself — its label and card count — where the focused card's demoted pair renders, since three columns cannot
carry the label. In the tiers where the usable width cannot hold the unfolded lanes' floors and the board groups
its lanes, a folded lane SHALL stay in place as its single line carrying the label, the count and the folded
marker — there folding is what saves rows — and the three-column frame SHALL NOT be used. That in-place line
SHALL sit in the column its own card lines use: the same leading indent (including the focus cursor's column),
with its fold marker in the column where those cards' state glyphs are drawn, so the folded line lines up with
the cards it stands for instead of hanging at the lane header's marker column.

A folded lane SHALL stay reachable through its cards: `←`/`→` still stop on a folded lane that holds cards, and
while the focused card lives in a folded lane the lane's one line SHALL carry the focus cursor and the `selected`
tone (exactly one cursor in the frame). `↑`/`↓` SHALL NOT move the focus while the focused lane is folded, and
Enter SHALL still open the focused card's detail view. The wheel over a folded lane SHALL stay that lane's and
MUST NOT scroll the page behind it.

The `c` key SHALL toggle the fold of the focused lane on the board page and the key band SHALL carry its chip
(`c 折叠` / `c fold`); the key is ignored while the detail view or the settings overlay owns the page region (the
kanban is not drawn). Each toggle SHALL be written to `state/panel.conf` as it happens.

An empty lane SHALL fold by default and a lane holding cards SHALL stay unfolded, unless the human set that
lane's state explicitly: `state/panel.conf` carries `boardFold` (the lanes folded explicitly) and `boardShow`
(the lanes kept unfolded explicitly), both written in the lane legend's order with unknown lane names dropped
and a lane named by both lists folded (the explicit hide wins), and `boardEmptyFold` (`0`/`1`, default `1`)
turns the empty-lane default off. A lane an empty default folded
SHALL unfold by itself as soon as it holds a card; an explicit state SHALL survive both a re-render and a
restart. The file's absence or corruption falls back to the defaults exactly as the settings requirement rules,
and `--print`/`--json` MUST NOT read these keys: a machine frame renders the default fold state, so two
`panel.conf` fold states produce byte-identical machine frames.

#### Scenario: Folding a lane stops rendering its cards

- **GIVEN** the fixture board whose `done` lane holds 20 cards, the console on the board page at 160 columns
- **WHEN** the `done` lane is folded, and later unfolded
- **THEN** the folded frame draws the lane's one line with its count `20` and none of the 20 cards (no title, no
  edge counter), the unfolded frame draws the newest six cards with the `+14` count again, and no other lane's
  cards changed

#### Scenario: Empty lanes fold by default, and the default can be turned off

- **GIVEN** a fixture board with cards in `todo` and none in `review`, `blocked` or `dropped`, and a second
  `state/panel.conf` carrying `boardEmptyFold=0`
- **WHEN** the board page renders at 160 columns under each
- **THEN** with the default the `review` line reads its folded marker and its count `0` while `todo` renders its
  card, and with `boardEmptyFold=0` the empty lanes render their box and the dim empty marker instead

#### Scenario: The fold state survives a restart, and an explicit unfold sticks

- **GIVEN** the console in a fixture pane with the `done` lane folded and an empty lane unfolded
- **WHEN** the console is quit and relaunched, and the board later gains the first card in that empty lane
- **THEN** the relaunch still folds `done` and still shows the unfolded empty lane, and the lane that gained a
  card stays unfolded

#### Scenario: The focus stays on a folded lane's card

- **GIVEN** the console on the board page with the focus on a card of the `wip` lane
- **WHEN** `c` folds `wip`, `↑`/`↓` are pressed, and `c` is pressed again
- **THEN** the folded `wip` line carries the cursor glyph and the selected tone, `↑`/`↓` leave the cursor there,
  and the second `c` restores the cards with the cursor on the same card

#### Scenario: Folding does not disturb the board's other interactions

- **GIVEN** the console on the board page with one lane folded and a board longer than the pane
- **WHEN** `←`/`→` walk the lanes, `↑`/`↓` walk the cards of an unfolded lane, Tab cycles the pages, the wheel
  scrolls a lane, the language is switched to `en`, and the frame renders in a bounded pane
- **THEN** the lane walk keeps the legend order and steps over empty lanes as before, the card walk keeps its
  window-follow rule, Tab still reaches page 4, the wheel still moves only the lane under the cursor, the labels
  come from the `en` table, and the frame's row count equals the pane height with the key band last

#### Scenario: Folding gives the unfolded lanes width

- **GIVEN** a fixture board with an empty `blocked` lane and the board page at 160 columns
- **WHEN** the empty lane is folded, and later unfolded
- **THEN** the unfolded lanes' borders move apart (a wider share each) while the frame's rows stay within 160
  columns and the six lane positions keep their legend order

#### Scenario: A wide pane gives a folded lane's columns to the unfolded lanes

- **GIVEN** the fixture board whose `review` and `blocked` lanes are both empty, the board page at 190 columns,
  and the board page rendering wider than 190 columns before the fold
- **WHEN** the empty default folds both lanes
- **THEN** each folded lane renders as a three-column frame — rounded corners, a border column, an ellipsis
  column, a border column — the lane row renders within the 190 columns, and the unfolded lanes' combined width is larger than in the in-place form

#### Scenario: A focused folded lane names itself

- **GIVEN** a folded lane holding cards, the focus moved onto its three-column frame
- **WHEN** the frame renders
- **THEN** the lane's label and card count appear where the focused card's demoted pair renders, and the frame
  carries the focus cursor

#### Scenario: The in-place folded line lines up with the cards it replaces

- **GIVEN** the board page in a grouped tier (the narrow form) whose `done` lane holds cards and the focus on a
  card of that lane
- **WHEN** the lane is folded
- **THEN** the lane's one line starts in the same column its card lines started in (its marker in the cards'
  glyph column) and the focus cursor still marks that line, while the lane's header keeps the marker column of
  the other headers

#### Scenario: A narrow pane saves rows, not columns

- **GIVEN** a fixture board at 59 columns whose `done` lane holds cards
- **WHEN** that lane is folded
- **THEN** the frame's card rows shrink by that lane's cards, the folded lane draws in place as its single line
  carrying its label and count, and the three-column frame of the wide form is not used

#### Scenario: Machine frames ignore the human's fold state

- **GIVEN** two `state/panel.conf` files, one folding a non-empty lane and one carrying no fold keys
- **WHEN** `team monitor --print --page 4` runs under each
- **THEN** the two prints are identical apart from the timestamp, and the empty lanes are folded in both

### Requirement: Settings edit task categories and independent PM policy rather than worker seats

Settings SHALL render ordered category rows and an independent PM model row from config JSON, with both languages' labels and owning command route. Category picker uses project known models plus free text and SHALL write `set-task-model`, never compose a mapping; there is no duplicate whole-map row or pairlist/seat override editor. PM uses `config set TEAM_PM_MODEL`. Missing mapping/retired policy yields a visible migration diagnosis and explicit CLI upgrade route, not an in-panel migration/restart: the diagnosis lines are the owning command's own text (a CLI route, rendered verbatim under a heading from the zh/en tables) and the heading is a plain user-facing phrase. Existing editor keyboard/mouse, direct-choice/free-text confirmation, dry-run/CAS/actor panel/cancel/conflict/background-refresh behavior remains. Category policy receipts name next new task; they explicitly do not switch a running or resumed assignment. PM receipts name guarded next PM launch and fresh when model changes. Assignments and last PM launch appear read-only in the model-records secondary view with their actual task/category/complete model/original and launch source/SID and any time the source reports. There is no worker default or per-worker model editor and no process restart action.

Future-policy rows SHALL be headed Models, with new-task timing on selection and in save receipts.
Model records SHALL be titled as records: assignment entries are dispatch records, and PM is labelled last PM
startup. A durable record is not evidence that its process is currently running. The same project-owned settings
read SHALL supply them; no liveness inference, new history store or lifecycle control is added. Opening records,
selecting a record and returning SHALL write nothing. Selecting a row SHALL make its full model, task, category,
session id and provenance accessible with plain field labels. A missing file SHALL say no dispatch record;
an existing unreadable record SHALL say it could not be read, never invent a model or claim no past dispatch.
Source tokens SHALL use plain phrases rather than schema field names. No edit, resume, switch-model or restart
button is offered in records.

#### Scenario: Category and PM writes are CLI-owned in a real pane
- **GIVEN** real fixture tmux pane, valid config and logging CLI wrapper
- **WHEN** keyboard and mouse select a category model, free-text edit PM model and confirm
- **THEN** captures show category/PM labels and honest timing; argv logs carry set-task-model and PM-set dry-run then CAS writes with actor panel; exactly intended config tokens change and no restart occurs

#### Scenario: Policy changes cannot be presented as resumed task models
- **GIVEN** routine assignment with explicit strong model
- **WHEN** routine policy is changed in settings
- **THEN** the read-only assignment in model records still shows original model/SID/provenance, category policy shows new value and receipt says new tasks only; same-task preview remains the assignment model

#### Scenario: The two halves are named in plain language and keep their own model
- **GIVEN** a fixture with a committed routine assignment and a later category-policy change
- **WHEN** the default view and then model records are opened
- **THEN** policy offers the new-task model while records show the assignment's original model and labelled session/provenance; the records title and PM last-startup label make no running-process claim, and no explanatory paragraph or lifecycle control is needed

#### Scenario: A seat's missing record is a plain reason, not the command's diagnostic
- **GIVEN** verify has no record file and dev carries an unreadable record with no assignment-shaped field or an unsupported version
- **WHEN** model records renders
- **THEN** verify says no dispatch record and dev says its record could not be read, neither shows the command's diagnostic prose or an invented model
- **AND** a read that falsely reports both as record-less makes this observation fail; the reasons follow facts, not diagnostic wording

#### Scenario: Cancel invalid input and conflicts preserve bytes
- **WHEN** picker is cancelled, invalid model entered, or a second writer changes config under the editor
- **THEN** cancel/invalid write nothing and retain appropriate focus/draft; conflict names exit 3, leaves other writer bytes and refreshes the view; no panel process directly writes config

#### Scenario: Legacy and small multilingual settings remain navigable
- **WHEN** settings open under legacy config in zh and en, and valid policy in narrow/tall panes
- **THEN** migration route remains visible without false editable seat defaults; keyboard/mouse scrolling and current-view filtering reach all category/PM operations and, through the records entry, all read-only records, with working return routes and nonfocusable headings

### Requirement: Overview links the latest key reply without reading its body
The TUI overview SHALL show the latest key-reply number, title, declared publisher and publication time, or an
explicit empty/unavailable state. Its visible `5` key hint and a mouse target SHALL lead to page 5's newest list;
opening the entry SHALL use the same body viewer as page 5. Summary reads MUST contain no body. A corrupt latest
slot MUST be labelled unavailable, not replaced with an older title labelled latest. Every static label SHALL
come from the zh/en tables.

#### Scenario: Latest answer is discoverable from the fixed entry
- **WHEN** a reply is published in a fixture and the overview's background summary refresh settles
- **THEN** its safe title and number appear with declared-publisher/time metadata, `5` and the click target reach the newest key-replies list, and Enter on that entry opens its body
- **AND** the overview did not read any body before the open operation

#### Scenario: Empty or corrupt latest source remains explicit
- **WHEN** the summary observes no store or an invalid latest slot
- **THEN** the overview renders empty or unavailable respectively, and page 5 remains reachable

### Requirement: Key replies page supports paged focus and a complete read-only body
Page 5 SHALL list `key-replies` metadata newest first, with at most 50 numbered slots per fetched page. `↑`/`↓`
SHALL move a focus whose row window follows it; the wheel SHALL scroll the list viewport without changing focus
or fetching hidden history. Visible `Older` / `Newer` controls SHALL fetch adjacent cursor pages using `←` / `→`
and mouse targets, with no automatic full-history load. Repeated Older operations MUST reach the oldest committed
slot, including through entirely corrupt pages. Newer SHALL follow the retained page cursor chain; `r` SHALL
refresh to the newest page and reset that chain. Focus MUST use stable numbers, not array positions; refreshing a
retained page MUST preserve a still-present focus and clamp only if that number is no longer on it. Enter or a
second click on the focused row SHALL open that number's complete safely rendered markdown body, showing its
title, declared publisher, publication time and number. A single click on another row SHALL only focus it.
`↑`/`↓`, PgUp/PgDn, Home/End and the wheel in the body SHALL scroll the document to all of its visible content;
`esc` or `q` SHALL return to the same list cursor, focus and viewport, not collapse the console. The viewer MUST
NOT truncate an accepted body, fetch links/images, execute text or offer edit/approve/read-status actions. A
missing/corrupt body SHALL show a local unavailable notice and the same return route. In the list, `q` SHALL
retain its global collapse meaning. Digit page keys and Tab SHALL retain top-level navigation outside composing
and existing settings modal ownership; leaving the reply viewer SHALL cancel its body request. The existing
human-to-PM compose entry SHALL remain available from page 5 and MUST NOT become a reply publisher.

#### Scenario: User reaches an old answer beyond the first page
- **WHEN** 123 replies exist and a user navigates Older twice, focuses number 1 and opens it
- **THEN** the complete first answer is readable, and `esc` returns to the same oldest page, number and viewport
- **AND** Newer twice returns to the original newest page while `r` starts a fresh newest cursor chain

#### Scenario: Long body and local errors have real return routes
- **WHEN** a 131072-byte accepted body with an end marker is opened, scrolled with End/PgUp/PgDn/wheel, and closed with `q`, and then a corrupt body's row is opened
- **THEN** the end marker is reachable, `q` restores the list rather than collapsing Pulse, and the corrupt viewer gives an unavailable notice with the same return behavior

#### Scenario: Keyboard and mouse use the same row and page actions
- **WHEN** a mouse-on fixture first clicks a row, clicks it again, scrolls the body and clicks Back, then clicks Older and Newer
- **THEN** the first click focuses, the second opens, Back restores list context, and paging matches `←`/`→`
- **AND** with mouse off no mouse-enable bytes or hidden mouse actions are added

#### Scenario: A corrupt page still offers continuation
- **WHEN** all 50 slots of a page are corrupt and valid older replies remain
- **THEN** the page displays unavailable numbered rows and an enabled Older route reaching those replies

#### Scenario: Compose and original page keys do not become publication
- **WHEN** the user opens `m` on page 5 or presses `1`–`4`/Tab outside the editor and settings modal
- **THEN** compose retains the existing PM draft/send meaning and navigation retains the original pages plus page 5
- **AND** neither action posts or modifies a key reply

### Requirement: Key reply blocks are async demand reads and absent from machine exits
The key-reply summary, current list page and selected body SHALL be separate asynchronous blocks over the bounded
`key-replies` readers. Only the TUI summary SHALL be scheduled outside page 5; list SHALL be wanted only on page
5, and body only while a reply viewer is open. No rendering or input callback SHALL read files, wait for a writer
lock, spawn synchronous processes, or await these blocks. Each block SHALL have a child timeout and output cap;
a failed/slow source SHALL degrade only its block, not delay keys, the clock, other blocks or patrol. Changing
list cursor/body number or leaving a view SHALL invalidate stale responses; a late response for a previous
request MUST NOT overwrite the new selection. Completed refreshes SHALL expose new publications without implying
that the publication receipt refreshed the screen. `--print`, `--json`, piped monitor and compatibility machine
assembly SHALL not schedule, read, render or export these blocks; publication alone MUST leave their output
unchanged under otherwise identical inputs. Reply reading and navigation SHALL not call post, repair, delivery
or patrol operations; the panel's preexisting tick ownership remains unchanged.

#### Scenario: Slow reader does not block input or a newer selection
- **WHEN** a list/body child is delayed beyond its timeout while the user switches pages or opens another number
- **THEN** keys and the clock remain responsive, only the affected block degrades, the abandoned child is bounded/cancelled, and its late response cannot replace the current page/body

#### Scenario: View demand closes body reads
- **WHEN** the TUI parks on overview, enters page 5, opens a reply, returns to its list and leaves page 5
- **THEN** recorded block argv show summary-only, summary plus one cursor list, an added single-number body, no body after return, and no list/body after leaving

#### Scenario: Machine paths never read key replies
- **WHEN** otherwise identical fixture monitor inputs are printed/JSON-exported before and after publication, with differing TUI preferences and damaged or blocked reply storage
- **THEN** prints are identical apart from timestamp and JSON structures are unchanged with no reply fields
- **AND** recorded reader calls and file accesses show zero reply reads and zero reader writes

### Requirement: Key replies remain legible across pane sizes and languages
The five-page band, latest summary, reply rows, paging/back controls, body metadata and empty/unavailable notices
SHALL use the existing zh/en string tables and display sanitization before layout. Status MUST NOT rely on color
alone. In 160/120/99/59-column bounded panes the layout SHALL retain a visible active-page identity, reachable
paging/back controls, a footer on the last row and scrolling access to all body content without horizontal
escape. Resize SHALL preserve the list cursor/focus and clamp document viewport to its new range. Both dark and
light themes SHALL retain the existing display-safety and contrast contracts.

#### Scenario: Width and language do not hide the return or older route
- **WHEN** fixtures render summary, empty/list/corrupt/list-continuation and long-body views at 160/120/99/59 columns in both languages and themes, then resize an open viewer
- **THEN** the page identity, Older/Newer/Back routes and unavailable markers remain legible, no line exceeds pane width, the footer remains last, and scroll access/list context survive

#### Scenario: Hostile strings are sanitized without losing the answer around them
- **WHEN** title/body/diagnostic inputs include OSC/CSI/BEL/C1/bidi controls and safe text on both sides
- **THEN** all snapshots and real pane captures contain the safe surrounding text but no executable controls or terminal hyperlinks

### Requirement: The key replies page states what it is and who publishes into it

Page 5 of the console SHALL carry one line describing the page itself: that it holds the replies the PM wrote for
the user — the answers, conclusions, rulings, reports and decision requests the PM sends to the conversation — and
that the PM is the one who publishes them. The line SHALL also carry the criterion's own question — who is this
reply written for? — so that whoever reads the page sees, on the page itself, how a reply is judged. The line SHALL come from the zh/en string tables like every other static
label, SHALL be sanitized and truncated to the pane width, and SHALL stay readable in all four width tiers and in
both languages; it SHALL be drawn whenever the page's list renders, including an empty store and a degraded or
unavailable read. The line is a statement, not a control: it SHALL carry no mouse target and no action, and the
page's read-only contract is unchanged — the console still publishes nothing, edits nothing and offers no marking
action. No part of the console reads chat, sessions or history, so the line MUST NOT claim that a reply is marked
by itself; it says where user-facing replies land, and publishing stays the PM's act.

#### Scenario: The page names itself in both languages
- **WHEN** page 5 renders a fixture store in zh and in en at 160, 120, 99 and 59 columns
- **THEN** the description line is present in the pane in both languages and no rendered line exceeds the pane width
- **AND** the line carries no mouse target: clicking its row changes neither the page, the focus nor the store

#### Scenario: Nothing marks a question for the user
- **WHEN** page 5 is rendered with typed text in the compose line and the recorded reader calls of that frame are inspected
- **THEN** the description line carries the same text as in a quiet fixture, and the only readers recorded are the bounded key-reply block reads
- **AND** no chat, session or history reader is consulted, so the console has no way to learn what the user just asked and cannot claim to have marked the reply

### Requirement: Project settings expose selected user operations rather than the complete configuration table

Project settings SHALL select operations for models and automatic checks, with project-command, model-record and task-label secondary views, not mirror the CLI schema. Values, defaults, choices, permissions and errors SHALL remain command-owned. Categories SHALL follow project data without a fixed vocabulary or count; excluded keys SHALL remain in the CLI, not return through search.

#### Scenario: Models precede settings and every project category is reachable
- **GIVEN** valid identical input with C=3 categories, A=5 assignment rows, one PM launch and no unknown keys
- **WHEN** the default view opens
- **THEN** it has eleven focusable rows: all three categories first, then PM model, concurrent tasks by model, check interval, PM recoveries per hour and startup update check, then project-command, model-record and task-label entries
- **AND** every reported category remains directly editable in its reported order for larger or differently named project category sets; C+8 is a count formula, not a limit

#### Scenario: Command editing has a small named destination
- **WHEN** project commands opens by Enter or mouse
- **THEN** it offers only install command, acceptance command and acceptance time limit, sourced from TEAM_INSTALL_CMD, TEAM_GATES and TEAM_REVIEW_TIMEOUT; it offers editing, not command execution
- **AND** default and command views together have C+8 configuration-editing entry points, separate from record rows, navigation and editor fields

#### Scenario: Excluded keys stay out of rows and search
- **GIVEN** new ordinary schema keys, unknown file keys, fixture-only keys, memory thresholds and the whole task-model map in the read
- **WHEN** settings lists render and those excluded identifiers are searched
- **THEN** none becomes a row, heading, editor or filter hit; the whole-map row does not duplicate the directly available category operations and the full CLI still reports every key
- **AND** removing a fixture marker does not by itself select a new user operation

#### Scenario: Disk settings leave the selected UI but not the complete read
- **GIVEN** no explicit value for TEAM_TMP_MIN_FREE_MB, TEAM_TMP_MIN_FREE_INODES or TEAM_DISK_STATS_FILE
- **WHEN** complete CLI reads run and settings renders or searches those names
- **THEN** CLI still reports defaults 1024/100000, apply/delivery for the two thresholds and the fixture-only refuse seam with existing metadata, but none appears as a settings row or search hit
- **AND** an actual low-space/inode error remains visible in the existing capacity/error display; the page change does not change thresholds, choices, validation or capacity behavior

#### Scenario: Labels and effective values replace routine implementation text
- **WHEN** a retained row and its editor/confirmation/receipt render in either language
- **THEN** user labels name operations; values use the file value else the read's default, explicit empty remains distinguishable as unfilled, and only the selected item needs a default indication
- **AND** ordinary rows do not repeat raw keys, unset/default markers, class badges, schema notes/comments or per-item CLI lessons; necessary new-task/PM/Pulse timing is available on selection and in receipts, and original error/repair commands remain available

#### Scenario: The read remains authoritative without a second schema
- **GIVEN** a read whose retained key becomes refuse or whose default/choices change
- **WHEN** that operation is shown and activated
- **THEN** its values/defaults/choices/permission follow that read, no writable editor opens for refuse, and the actual refusal/repair route remains available; presentation selection/order does not copy validation, defaults or classes

#### Scenario: Excluded-key warnings and migration errors remain visible
- **GIVEN** a warning for a key with no selected row, a settings-read failure or a model-policy migration diagnosis
- **WHEN** settings opens
- **THEN** the genuine error remains visible with its original facts and required repair route, no model is invented and no in-panel migration/restart action appears
- **AND** hiding key rows does not cut off additional real errors; opening settings still does not read an audit log

#### Scenario: Filtering narrows only the current view
- **WHEN** a retained operation is filtered by label, raw identifier or value case-insensitively and then Esc is pressed
- **THEN** only matching operations from the current selected list appear under their user labels, and Esc clears the filter without closing the view
- **AND** model-record filtering searches its own record facts rather than reopening excluded settings; the default search can find the Task labels entry, not individual definitions from its list

#### Scenario: Navigation preserves the overlay and two secondary origins
- **WHEN** the overlay's project-settings entry opens, Project commands and Model records each open and Esc is used to return
- **THEN** title/tabs/key band remain, each of these views returns to its originating default entry, and default Esc restores the original overlay focus without collapsing the console
- **AND** navigation writes no configuration/preference/audit, adds no top-level page or persisted navigation state, leaves page 5 and state/panel-page unchanged, and q outside editors retains global collapse behavior

#### Scenario: Focus wheel and clicks use the actual current list
- **GIVEN** enough categories or records to exceed the pane and mouse enabled
- **WHEN** focus passes the visible edge, the wheel scrolls over settings and a row is clicked twice
- **THEN** focus remains reachable, hidden counts match this list, headings are not focus/click targets, the first click focuses and the second performs the row action, and the page behind it does not scroll

#### Scenario: Presentation strings cover displayed operations not all CLI keys
- **WHEN** bilingual string completeness checks the selected operations and navigation
- **THEN** a missing presented label fails with its reference and zh/en field sets agree, but labels for excluded schema keys/groups are not mandatory; no wording blacklist is introduced

#### Scenario: Machine observers do not acquire console-only state
- **WHEN** settings opens and closes under identical monitor-visible configuration and committed model/SID identity
- **THEN** --print remains identical apart from timestamp, --json gains no settings field and neither path reads these views; separately specified model/SID changes remain observable

### Requirement: Selected settings editors preserve owning-command choices and writes

Retained editors SHALL use the on-screen command read, its choices and fingerprint; ordinary choice acceptance writes through validation once, free input confirms, and danger needs its extra confirmation. Concurrent-tasks-by-model fields SHALL edit the same complete rule value without changing matching semantics. Cancel/failure/conflict SHALL retain the existing no-overwrite behavior; no editor invents key deletion or a second configuration store.

#### Scenario: A bool choice keeps canonical values and direct saving
- **GIVEN** TEAM_UPDATE_CHECK unset with default 1, then set to 0 in a second fixture
- **WHEN** its picker opens and 1 is accepted
- **THEN** exactly canonical 1/0 with localized on/off labels appear, current/default facts remain identifiable and no free-text entry appears
- **AND** one accept performs dry-run then fingerprinted --yes with no ordinary confirmation frame, changes one config value and adds one audit line with actor panel; the receipt carries actual timing

#### Scenario: Model choices are project data and retain their order
- **GIVEN** distinct models in policy, PM and complete committed assignments and an unrelated model in the machine catalogue
- **WHEN** a category or PM model picker opens
- **THEN** its options use only the read's project-owned models plus current/default entries and free input, deduplicated in current/default/choices order, never the machine-only model
- **AND** a value added to a retained key's reported choices appears without rebuilding the UI, while adding a schema key does not create a new operation

#### Scenario: Numeric suggestions retain free input and validation
- **GIVEN** TEAM_PULSE_INTERVAL default 900, minimum 60 and suggestions 300,900,1800,3600 from the read
- **WHEN** suggestions are viewed and free input 30 is submitted
- **THEN** distinct current/default/suggestion entries keep read order, only supplied interval bounds need labels and the real range error retains the draft/config bytes without an audit write
- **AND** accepting an ordinary valid suggestion directly validates and writes without opening free input or an extra confirmation; no kind/unbounded teaching line is required

#### Scenario: A command without choices opens usable free input
- **WHEN** the acceptance-command row opens
- **THEN** the insertion-point editor holds the original value under its user label, with no empty option list or schema-kind explanation; validation then user-labelled old/new confirmation precedes a confirmed write
- **AND** any clear action is offered only if the read accepts empty, never as deletion of the key

#### Scenario: Keeping an unset value does not fabricate reset support
- **GIVEN** an unset retained key with a default, then an already explicitly set key
- **WHEN** its editor opens and keep-default is accepted where available
- **THEN** that action only cancels with no config/audit/temp-file change; if the default is empty it is labelled leave-unset, and explicit values have no restore-default deletion action
- **AND** choosing the actual default value instead follows ordinary validation and writes the explicit value, rather than claiming the key was removed

#### Scenario: Keyboard mouse and cancellation share the same action
- **WHEN** entries are reached with arrows or wheel, clicked once then twice, or Esc is pressed
- **THEN** the first click focuses without writing, the second accepts like Enter, the wheel reaches long lists, and Esc returns to the originating row without config/audit/temp-file changes; free input is reachable by keyboard and mouse

#### Scenario: Existing dangerous values retain their extra confirmation
- **GIVEN** TEAM_REVIEW_TIMEOUT with free input 30, or current value 30 accepted as an option, with the original bytes recorded
- **WHEN** the first accept returns the unchanged writer's danger result
- **THEN** no --yes write/audit has occurred and the warning is shown; only the next accept writes with the existing danger allowance and actual timing/warning

#### Scenario: Stale fingerprint and write failure do not become success
- **GIVEN** an editor opened on a fingerprint followed by a second writer's change, or an actual failed write
- **WHEN** save is accepted
- **THEN** conflict preserves the second writer's bytes, adds its existing conflict audit and reloads the shown value; failure retains the appropriate draft and actual reason, never a saved receipt

#### Scenario: Interaction never synchronously re-reads configuration
- **WHEN** a retained editor opens, focus moves, an ordinary entry is accepted or free input opens
- **THEN** no config-list/panel-data read stands between that interaction and its answering frame; validation/write use the opening read's fingerprint, and only settled background re-read follows without holding the receipt

#### Scenario: Separate fields preserve the existing model-concurrency rules
- **GIVEN** a complete value with exact/wildcard expressions, overlaps and duplicate matches
- **WHEN** model/count fields edit one rule, add/remove another in the draft and then save
- **THEN** the model field offers known project models and free entry for existing expressions, the operation is named “模型同时运行任务数 / Concurrent tasks by model”, fields identify applicable model and simultaneous quantity, count 0 is labelled “此项不限制 / No limit from this entry” and the summary uses the actual item count, such as “2项 / 2 entries”, and ordinary editing does not require composing pattern=N
- **AND** field choices only edit the unsaved draft; final save performs one whole-key dry-run, user-labelled full old/new confirmation and one fingerprinted TEAM_MODEL_LIMITS write, without new per-model state or matching/precedence logic
- **AND** unchanged token contents, order and duplicates retain their meaning; after an actual edit, saving joins the complete token list with spaces for the existing writer, without preserving separator whitespace. Cancel/invalid/stale saves preserve original config bytes as above; existing warnings or malformed source stay visible for existing whole-value correction without a lossless parser or new error classification, and empty is the original writer's empty value, not deletion or a promise to disable runtime defaults

### Requirement: Settings groups follow user purposes and keep visible action state

Settings SHALL group selected operations by user purpose, not CLI group order, while preserving localized noninteractive section headings and readable action state. The presentation SHALL NOT copy schema classes/defaults/validation or change complete CLI group metadata. Empty groups SHALL not create headings; necessary state SHALL remain readable without colour.

#### Scenario: Purpose order does not follow schema section order
- **GIVEN** retained keys whose CLI groups differ and categories in project order
- **WHEN** the default view renders
- **THEN** Models and Automatic checks are the two content groups followed by the three named secondary entries: Project commands, Model records and Task labels; changing a retained key's group does not move its operation and adding an excluded key/group adds no UI heading

#### Scenario: Headings are visible without becoming interaction targets
- **WHEN** groups render and are walked by keyboard/mouse in both languages
- **THEN** each nonempty group has a localized section rule immediately before its rows without another blank separator, headings take no focus/click stop, and necessary timing/read-only/error state appears in words rather than colour or repetitive class badges

#### Scenario: String completeness follows purpose references
- **WHEN** a presented purpose/navigation label is missing, or a new CLI group belongs only to excluded keys
- **THEN** the missing displayed label fails its existing string check, but the unrelated CLI group requires no new UI label or page

### Requirement: Board labels and priority are optional read-only views

The interactive board SHALL default to all tasks in recent-first order. An explicit priority choice uses
descending shared score within each lane, breaking ties by original board row order. The single-label filter applies
to either order. Display and navigation SHALL use the same matching rows. Task detail SHALL show label
names and score alongside its file details. These controls SHALL NOT write labels or view choices.

#### Scenario: Filtered cards and interactions use one row order

- **GIVEN** a lane with two separately focusable rows sharing an ID and label, another card in between, and
  other cards including a score tie and a label with no matching card anywhere
- **WHEN** the second row is focused and priority is selected, `r` refreshes after a peer's weight is changed,
  and a keyboard or mouse selection applies a filter hiding the originally focused row
- **THEN** the second original occurrence retains focus while eligible, including across detail and back;
  renderer, arrows, mouse, windows and Enter use the same new order; filtering moves focus to the first matching
  card in its prior lane's shown order, or the first matching card of the first lane with matches
- **AND** each lane and its edge counts reflect matches, folded lanes with matches still open the focused matching
  card, and no-match selection gives zero counts, follows the existing empty-fold policy and opens no detail
- **AND** if an eligible task is focused under the filter and a refresh removes its last matching occurrence
  while a same-ID row outside the task table remains, focus moves to an eligible card and Enter cannot open
  the hidden row; with no eligible card, Enter opens nothing

#### Scenario: A same-ID row outside the task table never inherits labels

- **GIVEN** two task-table rows sharing an ID, its label and score, and a separate table below with a different title
  but the same ID at the same column position and a valid `todo` state
- **WHEN** the board opens in its default view, the three original rows are opened in detail separately, and
  the label filter is then applied
- **THEN** the default still shows all three rows in the normal recent-first view; the two real rows are separate focus stops
  and their details show the shared labels and score; the unrelated row's detail keeps its normal file result
  but no label area; the filter matches only the two real rows, and cannot open the unrelated row
- **AND** when the unrelated row is opened from the work page and a same-ID task is inserted before it, `r`
  refreshes the same open detail without adding any labels, even if its former occurrence now identifies a task
- **AND** detail from either page shows labels on refresh only if its source was a task-table row when opened
  and its current row reference still points into that table; file lookup still uses the original ID

#### Scenario: Explicit priority and default history anchor are different views

- **GIVEN** a board whose done and dropped history exceed the lane windows and whose highest scores are not on its newest rows
- **WHEN** page 4 opens with default choices, then selects priority, then returns to recent-first order
- **THEN** the default and restored order put valid times first, newest first, then the undated history
  rows from the file's tail; the priority windows start at the highest ranks subject to the focused card
- **AND** a label filter retains matching rows in the chosen order; two equal priorities keep original
  BOARD.md row order even when their update times differ; page 2's order, machine exits and board file stay unchanged
- **AND** with no filter, any displayed same-lane non-task rows remain visible but unranked after ranked rows

#### Scenario: Choices are local to the current console session

- **GIVEN** a board with definitions and a client using keyboard, and a second client using mouse in the other locale
- **WHEN** each selects a label and priority, switches page and returns, and then restarts the console
- **THEN** each control displays its current value using zh/en interface strings, the choices survive page changes
  but restart opens all tasks in recent-first order, and no choice is written to panel preferences or project files
- **AND** when no definitions are present and the catalog read has no error, the original board display has no added controls

#### Scenario: The chooser acts on exact names and owns its inputs

- **GIVEN** distinct project labels that differ by case or beyond the chip's displayed width
- **WHEN** plain `t` or `o` on the board opens a choice, the human selects by keyboard or mouse, and later
  uses `Ctrl+o` while composing
- **THEN** the selection matches the full unchanged label value, never its shortened text; arrows, wheel,
  clicks, Enter and Esc in the picker act on the list, not the board behind it; plain `t` and `o` do not open
  these controls elsewhere or over another modal, and `Ctrl+o` still opens the compose editor

#### Scenario: A task with no file still exposes its labels

- **GIVEN** a task with no task brief, report or review and a label with a custom color
- **WHEN** task detail is opened, then only that color is edited through the CLI and the board refreshes
- **THEN** detail opened from either owning page shows the name, updated color and unchanged score separately
  from the existing no-file result, the name remains visible without color, and opening or closing it does not
  change labels or make a filtered-out card reachable
- **AND** a task with files retains its file tabs and Markdown; a task without a label on a board with definitions
  shows no labels and score 0; a board without definitions adds no label row; the labels and score are reachable
  by scrolling, with no write or edit action

#### Scenario: Missing label choices and invalid data do not hide the board

- **GIVEN** a selected label that is renamed through the CLI and a catalog that is later damaged and repaired
- **WHEN** the same running board refreshes after the rename, the damage and the repair
- **THEN** the rename clears only the filter and shows the new name in its choices; the damaged source shows
  the default board with a labels-unavailable notice, all original rows and neither old nor false zero scores
  in detail; the repair restores current names and scores on refresh without restarting the board

#### Scenario: The 59-column card keeps its text

- **GIVEN** the same focused row at 59 columns with and without labels, and no filter or lane-fold change
- **WHEN** both board frames and the labeled task's detail render
- **THEN** both card lines carry the same glyph, ID and title text, both frames fit the width, each choice is
  reachable with keyboard and mouse where applicable, and detail shows name text without changing the card

### Requirement: Project settings manage the current project's task label definitions

Task labels SHALL open a project-local definition list with name, color and weight. Users SHALL be able to add and edit a definition with one save, cancel without writing, and delete only after a separate confirmation. The view MUST use the same reads, identity and writes as `team board label`, not a board card's displayed data.

#### Scenario: The first label can be saved from a normal form

- **GIVEN** the current project's catalog is absent or valid and empty
- **WHEN** Task labels is opened and a user fills Name, chooses a named color and saves Weight as an integer, initially zero
- **THEN** the empty list had no prefilled labels; the saved row shows the exact name, the named color with a swatch and its weight; listing definitions through the CLI for that project shows that same row
- **AND** no field asks for a color code, configuration expression, path or command

#### Scenario: Editing one field preserves unedited fields and existing links

- **GIVEN** a definition with a custom color and an existing task association
- **WHEN** its weight alone is changed to an integer such as `-9007199254740993`, or separately its name alone is changed
- **THEN** only the changed field is submitted with its full value, the exact decimal and original custom color survive, and the association still refers to the edited definition under its current name
- **AND** a custom color has text and a keep-current choice; opening and leaving the color picker without a choice does not modify the draft color; a name with spaces, a leading dash or non-ASCII text is passed literally

#### Scenario: Cancel and refused deletion do not change current definitions

- **GIVEN** a label in use and another unused label
- **WHEN** an edit is changed and cancelled, deletion of the in-use label is confirmed, then deletion of the unused label is confirmed
- **THEN** after cancellation the list reads the current catalog and reopening has no cancelled draft; in-use deletion reports the refusal and its blocking IDs, shows fresh definitions and removes no association or definition; only the confirmed deletion of the unused label succeeds
- **AND** duplicate names and invalid fields show the command's reason in ordinary words, keep the entered draft for correction and do not show a save receipt

#### Scenario: A failed catalog read is not an empty project

- **WHEN** opening or reloading the list fails to read the catalog, or reading back after a refusal fails
- **THEN** the view reports that it could not read labels rather than showing No labels yet or offering a write on an assumed empty catalog; any rejected draft remains separate from the current catalog

#### Scenario: The console does not automatically retry an unconfirmed write

- **WHEN** the write cannot be confirmed, including a missing or invalid command result after launch
- **THEN** the form shows that the outcome is unconfirmed, not that the change succeeded or that nothing changed, keeps the draft and separately reads the catalog to show what is now visible
- **AND** it makes no automatic or blind repeat write; a further write requires a fresh read and a new explicit decision with the current values available

#### Scenario: The board observes the completed edit rather than a read already in flight

- **GIVEN** a board read started before a successful definition edit and has not yet completed
- **WHEN** the console finishes the save and returns to the board or selects priority
- **THEN** the labels list and interactive board use reads started after that write, not the earlier sample as the post-save result
- **AND** if a read fails, the console identifies the refresh failure rather than presenting old data as current; the board still defaults to recent updates, explicit priority still uses the existing weights and original-row tie-break, and task times do not change

#### Scenario: Label controls work within the settings stack in either language

- **GIVEN** a narrow terminal and the setting opened by keyboard or mouse in either supported language
- **WHEN** the user selects a row, uses the fields and color picker, and returns from the list
- **THEN** text identifies the actions and colors, controls remain reachable, and the active list or picker, not the view behind it, receives its keys, clicks and scroll
- **AND** returning restores the Task labels entry and then the original settings overlay position; no label entry is available on the top-level pages or in machine output
