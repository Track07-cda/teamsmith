## MODIFIED Requirements

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
set, the file to hand-edit plus the key for a `refuse` key, the category's own command for a category. A key the schema
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
read or render it or add a project-settings field. Opening/closing the console-only view does not change machine output under identical monitor inputs; the specified model-policy, assignment and SID-reader changes are not frozen to old bytes. The view MUST NOT be a fifth page: the four-page
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
  `TEAM_SESSION` (a `refuse` key) and then on the `routine` category
- **WHEN** each row is focused
- **THEN** the view's own command line reads `team config set TEAM_PULSE_INTERVAL <value>` for the first row, names
  the file to hand-edit together with `TEAM_SESSION` for the second and `team config set-task-model routine …` for the
  category, and the editor the first row opens is titled with the raw key

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

- **GIVEN** a fixture project with identical monitor-visible configuration and committed routing/SID identity before and after its console-only settings view is opened/closed
- **WHEN** `team monitor --print` and `team monitor --json` run in each state
- **THEN** prints are identical apart from timestamp, JSON objects carry no project-settings field, and the machine paths do not read the settings overlay; separately specified model/SID changes remain observable

### Requirement: The console writes a project setting only through `team config set`, after validation and a confirmation

Category rows use `team config set-task-model` with the same dry-run, fingerprint, actor, confirmation, receipt and background re-read rules; PM uses `team config set TEAM_PM_MODEL`. Model-policy receipts SHALL distinguish next new task from exact same-task recovery and say no live process changed. An editable row's `enter` SHALL open the row's editor: the **choice editor** (the requirement that owns it) when
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

### Requirement: The console is read-only except through its owning commands

Every block the console shows SHALL come from read-only reads, and the only state-changing actions the console
offers SHALL be the ones that invoke the owning command as a subprocess: `m`/Enter → `team draft send`, `f` →
`team outbox flush` (both `delivery-guard`), `s` → `team standby on|off` (`watchdog`), and the project-settings
view's confirmed edit → `team config set` or `team config set-task-model` (`memory-and-deps`, which owns the contract's write path). The console
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
- `task-model-map` SHALL NOT be composed in the console: its editor SHALL be the categories block (the requirement that
  owns per-category model editing), reachable by `enter` from the row without any free-text composition of the pair
  list, and the row's command line SHALL name `team config set-task-model <category> <model>`.
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

- **GIVEN** a fixture project whose PM model is `deepseek/deepseek-flash`, whose `TEAM_TASK_MODELS` carries
  `routine=kimi-coding/k3-256k`, and whose complete valid `state/dev.env` assignment records `openai-codex/gpt-5.6-terra:xhigh`; and a fixture
  `HOME` whose Pi model catalogue names `sub2api/gpt-5.6-luna`
- **WHEN** the `TEAM_PM_MODEL` row's editor opens, and then the categories block's `routine` picker
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

- **GIVEN** the view open with more rows than the pane shows and the focus on `TEAM_TASK_MODELS`
- **WHEN** `enter` is pressed
- **THEN** the categories block becomes the row's editor: the focus moves to it, no compose editor and no option list
  opens, and the command line names `team config set-task-model <category> <model>`

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
keys and before the categories block: it MUST NOT be dropped, merged into a group the command did not report, or
rendered without its own badge and command line. The categories block SHALL keep its own trailing heading, whose label
is distinct from every group heading.

#### Scenario: The headings are functional domains, not effect classes

- **GIVEN** a fixture contract and the view open in a 160-column fixture pane
- **WHEN** the rows render
- **THEN** the headings are the schema's functional labels in the read's order (身份与账本布局 before 工作流与门禁
  before 跨项目会议), no heading reads `立即生效`, `需要重启` or `只读`, the keys of one group render together in
  the schema's order, and a walk down the list stops only on key and category rows — never on a heading

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
- **THEN** both rows appear under the visible fallback heading after the grouped keys and before the categories block,
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
- **THEN** the category rows appear under the tables' own categories heading, that heading's text differs from the
  task-model group's heading, and the keys of that group appear under their own functional heading with the
  group's own order

#### Scenario: A heading is a section rule and it separates its own group

- **GIVEN** the view open on a contract whose read reports more than one group, in a pane tall enough to show
  two of them
- **WHEN** the rows render
- **THEN** every heading (the functional groups, the fallback group and the categories block alike) is drawn as a
  section rule — the label between the two `─` runs of a full-width rule line — while key rows and category rows
  carry no section rule, so a heading is distinguishable from a row by shape and not only by tone
- **AND** a heading sits directly between the previous group's last row and its own group's first row: the
  heading itself is the visible separation between groups and no extra line is spent on one

## REMOVED Requirements

### Requirement: The console edits a seat's model and shows where the displayed model came from

**Reason**: Seat/default policy is retired; task category policy and persisted assignments replace it.

**Migration**: Explicitly upgrade the model keys with `team config upgrade-models`; edit categories through `team config set-task-model` and PM through `team config set TEAM_PM_MODEL`. No seat override or worker fallback remains.

## ADDED Requirements

### Requirement: Settings edit task categories and independent PM policy rather than worker seats

Settings SHALL render ordered category rows and an independent PM model row from config JSON, with both languages' labels and owning command route. Category picker uses project known models plus free text and SHALL write `set-task-model`, never compose a mapping; whole-map row routes to category rows and has no pairlist/seat override editor. PM uses `config set TEAM_PM_MODEL`. Missing mapping/retired policy yields a visible migration diagnosis and explicit CLI upgrade route, not an in-panel migration/restart. Existing editor keyboard/mouse, direct-choice/free-text confirmation, dry-run/CAS/actor panel/cancel/conflict/background-refresh behavior remains. Category policy receipts name next new task; they explicitly do not switch a running or resumed assignment. PM receipts name guarded next PM launch and fresh when model changes. Assignments appear read-only with actual task/category/complete model/original and launch source/SID, visually separate from future policy. There is no worker default or per-worker model editor and no process restart action.

#### Scenario: Category and PM writes are CLI-owned in a real pane
- **GIVEN** real fixture tmux pane, valid config and logging CLI wrapper
- **WHEN** keyboard and mouse select a category model, free-text edit PM model and confirm
- **THEN** captures show category/PM labels and honest timing; argv logs carry set-task-model and PM-set dry-run then CAS writes with actor panel; exactly intended config tokens change and no restart occurs

#### Scenario: Policy changes cannot be presented as resumed task models
- **GIVEN** routine assignment with explicit strong model
- **WHEN** routine policy is changed in settings
- **THEN** read-only assignment still shows original model/SID/provenance, category policy shows new value and receipt says new tasks only; same-task preview remains the assignment model

#### Scenario: Cancel invalid input and conflicts preserve bytes
- **WHEN** picker is cancelled, invalid model entered, or a second writer changes config under the editor
- **THEN** cancel/invalid write nothing and retain appropriate focus/draft; conflict names exit 3, leaves other writer bytes and refreshes the view; no panel process directly writes config

#### Scenario: Legacy and small multilingual settings remain navigable
- **WHEN** settings open under legacy config in zh and en, and valid policy in narrow/tall panes
- **THEN** migration route remains visible without false editable seat defaults; keyboard/mouse scrolling and filtering reach all category/PM/read-only assignment rows, with group headings not focusable
