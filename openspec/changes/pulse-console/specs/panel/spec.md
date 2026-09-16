## ADDED Requirements

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

### Requirement: The console composes three pages and remembers the position

The TUI SHALL compose three pages — an overview (the status banner, the project-progress counts, the recent
deliveries, the agent table, the capacity sparkline and the recent events), a work page (the board rows, the
active changes with their phases, the spec counts and the recent decisions) and a messages-and-logs page (the
deferred queue, the inbox and threads, the patrol log, the capacity trend and the health block) — plus a settings
overlay. A block whose source has no data SHALL collapse and yield its space. Tab and the keys `1`–`3` SHALL
switch pages, and the current page SHALL be written to `state/panel-page` and restored on the next start. Pages
are a TUI-only concept: `--print` and `--json` render the overview content.

#### Scenario: Pages switch and the position survives a restart

- **GIVEN** the console running in a fixture pane of a fixture project
- **WHEN** `3` is sent, the console is quit and relaunched, and `1` is sent
- **THEN** the capture after `3` shows the patrol-log block, the relaunch opens on the messages page
  (`state/panel-page` holds it), and `1` returns to the overview

#### Scenario: An empty block collapses

- **GIVEN** a fixture project with no active changes
- **WHEN** the work page renders in a fixture pane
- **THEN** the changes block is absent from the capture and the page's other blocks render fully

#### Scenario: The messages page lists the queue

- **GIVEN** a fixture project with two queued outbox entries
- **WHEN** the messages page renders
- **THEN** both entries are listed with their ages

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
frame, and the four tiers SHALL be pinned against stored snapshots in both themes in the test suite.

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

### Requirement: Every key affordance is also a mouse target

With the mouse preference on, the console SHALL enable SGR mouse reporting for its lifetime and disable it on
exit, and every documented key — `m`, `f`, `s`, `,`, Tab, `1`–`3`, `↑`/`↓`, `q` — SHALL have a clickable target
that acts identically; the wheel SHALL scroll the focused block. Coordinates are 1:1: a click on a target
activates that target (E6 §1.1 measured the full path, with tmux's own mouse option in either state). With the
preference off the console SHALL emit no mouse-reporting sequence and clicks SHALL do nothing.

#### Scenario: A click acts like the key

- **GIVEN** the console running in a fixture pane with the mouse preference on
- **WHEN** the pty driver injects a left press and release on the `m` hint's coordinates
- **THEN** the compose line opens

#### Scenario: The wheel scrolls the focused block

- **GIVEN** the same fixture with more events than the events block can show
- **WHEN** wheel-down and wheel-up sequences are injected over the block
- **THEN** the visible window of events shifts down and back

#### Scenario: Off means silent

- **GIVEN** the console running with the mouse preference off
- **WHEN** a frame is captured and a click is injected on the `m` hint
- **THEN** the capture contains no SGR mouse-enable sequence and the compose line stays closed

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

## MODIFIED Requirements

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

## REMOVED Requirements

### Requirement: The layout is four ordered bands with a documented degradation order

**Reason**: the console replaces the single screen's four bands with three pages composed by a geometry-pure
layout with four width tiers (the new "The layout is a pure function of geometry with four width tiers"
requirement); the band vocabulary no longer describes anything that renders.

**Migration**: everything the bands carried survives by field — the status banner, the agent table, the activity
column and the key hints move onto the pages with their content governed by the untouched status-band,
agent-table, activity and sanitize requirements, and `--print` keeps rendering the overview frame. The
height-based fold order is superseded by the documented tier order.
