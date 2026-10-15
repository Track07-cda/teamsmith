## MODIFIED Requirements

### Requirement: The console shows the project contract with its effect class, and refuses what it must not change

The settings overlay's navigation row SHALL open a **project-settings view** that replaces the page's blocks — the
title band, the page tabs and the key band stay, exactly as with the overlay itself, and the view is closed with
`esc` back to the overlay it was opened from without collapsing the console. The view SHALL list the project
contract (`.pi/team/config.sh`, `memory-and-deps`'s single-writer file): one row per key of the owning command's
schema plus one row per key the file itself carries that the schema does not know, **except** a key the read
reports as fixture-only — the schema row's own note carries the declared `fixture-only: ` marker (`memory-and-deps`
owns the marker): the read still reports it, `team config list` still lists it and `team config set` still refuses
it, but the view MUST NOT render a row for it, MUST NOT open a heading for it, and MUST NOT let `/` match it (a
key the fixture never meant to show must not be reachable through the filter either). A key the read does not mark
that way is never hidden, whatever its class, group or value. Per row the view renders the key's **human
label** — from the console's zh/en tables, looked up by the key name the command reported — the current value
(the file's value, else the schema's default marked as unset), the key's **class** from the schema and the key's
own trailing inline comment when its line has one. The bare key name MUST NOT be the row's main text: every key of
the command's schema SHALL have a non-empty label in both tables (a fact the string-table gate asserts in both
directions — a schema key without a label and a label whose schema key is gone both fail it), and the raw key
SHALL appear only where the view aligns with the command line: the editor's prompt and its confirmation, the
view's own line naming what to do for the focused row — `team config set <KEY> <value>` for a key the command can
set, the category's own command (`team config set-task-model <category> <model>`) for a category row, and for a
`refuse` key the plain route sentence **「这个值要改项目配置文件 `.pi/team/config.sh`，界面不能改」**
(the path is a fact and stays; the sentence replaces the private shorthand) or the route the schema's own note
names when that route is a command (`team add-agent`, `team config upgrade-models`, …) — and the migration
diagnosis lines the owning command prints (a CLI route, rendered verbatim; the `memory-and-deps` capability owns
its words). Every other string the view renders SHALL be plain user-facing language: the panel's own words come
from the zh/en tables and the facts (label, value, class, group, comment, warning) from the read. The prose the
view renders verbatim — the schema's note column (`memory-and-deps` owns it) — SHALL be written for that reader;
whether a phrase is plain enough is judged by design and review, not by a gate (D170), so no wording assertion
belongs in the fixtures. A key the schema
does not know has no label and none SHALL be invented for it: its row falls back to the raw key name, which is
what the file and the command carry; its route line says in plain language that the tool does not know the setting
and that the panel cannot change it. The class vocabulary SHALL be the owning
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
owning command's route in plain language — the file sentence above for a value that only the file carries, the
command the schema's note names for the roster, and the command's own refusal line for anything else (the line the
command prints, never a rewritten copy of it). The view's
own labels SHALL come from the zh/en tables, the key labels included: no visible text is written into the bundle.
The view is a console-only block: `--print` and `--json` MUST NOT
read or render it or add a project-settings field. Opening/closing the console-only view does not change machine output under identical monitor inputs; the specified model-policy, assignment and SID-reader changes are not frozen to old bytes. The view MUST NOT be a top-level page: the five-page
composition reserves page 5 for key replies and `state/panel-page` records only top-level pages.

#### Scenario: The rows carry the three classes and the unset key its default

- **GIVEN** a fixture contract whose file holds `TEAM_GATES`, `TEAM_PULSE_INTERVAL` and `TEAM_PROJECT`, and a
  schema whose `TEAM_DEFER_TTL` the file does not carry
- **WHEN** the project-settings view renders in a 160-column fixture pane
- **THEN** the three ruled rows carry the `apply`, `restart` and `refuse` badges, the `TEAM_DEFER_TTL` row shows
  the schema's default and the unset marker, every rendered label exists in both tables, and each row's main text
  is that key's label in the active language (no row reads `TEAM_…`)

#### Scenario: A fixture-only key is in the read and never in the view

- **GIVEN** a fixture project whose contract carries the four fixture-only keys, and a scratch copy of the CLI
  whose schema carries one more key whose note begins with the `fixture-only: ` marker
- **WHEN** `team config list --json` runs and the settings view renders (with and without a `/` filter that
  matches the fixture keys' labels and raw names)
- **THEN** the read reports every one of those keys, `team config list` still lists them and `team config set`
  still refuses them with exit 5, while the rendered frame carries no row, no heading and no filter hit for any of
  them
- **AND** a scratch tree whose row has lost the marker renders that key's row again (the same fixture's red side),
  so the hiding follows the read's data and not a name baked into the bundle

#### Scenario: The raw key is exactly where the CLI is named

- **GIVEN** the view open with the focus on `TEAM_PULSE_INTERVAL` (an editable `restart` key), then on
  `TEAM_SESSION` (a `refuse` key) and then on the `routine` category
- **WHEN** each row is focused
- **THEN** the view's own command line reads `team config set TEAM_PULSE_INTERVAL <value>` for the first row,
  carries the plain file sentence for the second (the project config path `.pi/team/config.sh` is part of it and
  the sentence names no private shorthand), and names `team config set-task-model routine …` for the
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
- **AND** the fixture-only keys are covered like every other key — their row is hidden, their label is not

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
- **THEN** neither opens an editor, each receipt names the route in plain language (`team add-agent` / `team
  teardown` for the roster, the project config file for an identity key), and the contract's sha256 is unchanged
  after both

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
contract and display the other writer's value; on any settle the list SHALL be re-read in the
background, and that re-read MUST NOT hold the receipt frame. The audit SHALL stay readable where it already
lives — `state/config.log`, `team config list`'s own footer and `team config log` — and the console SHALL NOT be
one of its readers: the tail this view draws under its rows carries the focused row's command line and nothing
from the log. The console MUST NOT open the
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
- **WHEN** the contract's own human read (`team config list`, whose footer is the audit tail) and `team config log 5` run
- **THEN** both show the same newest line naming the timestamp, the actor, the key, the old and the new value — the
  audit stays readable from the contract's own reads, exactly as it was before this change, and `state/config.log`
  still grew exactly one line for the write
- **AND** the console's settings view is deliberately not one of its readers: the rendered frame carries no audit
  heading and no audit line, and drawing that tail again in a scratch copy of the view turns the fixture red

### Requirement: The settings view groups the contract by the functional group the command reports, and carries the effect class on the row

The project-settings view's row list SHALL group the contract's keys by the `group` the owning command reports
for each key, and the read's order SHALL be the view's order: a heading opens when the token changes, the
schema's order is kept inside a group, and the headings themselves appear in the order the read reports their
first rows. A heading MUST NOT be a focus target and MUST NOT be a click target. The heading's text SHALL come
from the zh/en tables, looked up by the token (`group_<token>`), so no group word is written into the bundle; a
token with no label SHALL render as the raw token — the same visible fallback the key labels use for a key the
schema does not know — and the string-table gate SHALL assert the tokens the schema's rows carry and the group
labels in both tables match in **both** directions (a token without a label and a label no row uses both fail
it). The heading phrases themselves SHALL be plain user-facing language — the panel's own word for a functional
domain, never a private shorthand or an effect class — and whether a phrase is plain enough SHALL be judged by
design and review, not by a gate (D170), like every other visible string. The bundle MUST NOT carry a key→group table or a group list of its own: a group or a key added to the
command's schema SHALL appear under the reported heading with the committed `panel.js`, and a row the read
reports under a different token SHALL move. A key the read marks fixture-only (the requirement that owns the row
set) SHALL NOT open a heading: once every row of a token is hidden by that rule the group produces no heading,
and a group whose remaining rows are visible keeps exactly one.

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

#### Scenario: A group whose rows are all fixture-only opens no heading

- **GIVEN** a scratch copy of the CLI whose schema carries two fixture-marked rows under a token no other row
  uses, and the view open
- **WHEN** the rows render
- **THEN** the frame carries no heading for that token (the hidden rows do not leave an empty heading behind) and
  the visible tokens keep exactly one heading each in the read's order

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

### Requirement: The settings view fills the pane it is given and its row window grows with it

The project-settings view SHALL spend the height the frame hands it: the last row it draws SHALL be at most one
blank row above the key band at every pane height the frame can draw a card for, and the number of rows the
window draws SHALL grow with the pane. A row's price in the window's fit SHALL be what the row really draws —
one line per row, plus the line of a group heading when that heading's first row is inside the window — so a key
row's note never costs a second line. The two hidden-row count lines SHALL be a ceiling rather than a fixed
cost: a count line is spent only when the window really hides rows at that edge, and the line the counts do not
use SHALL go to the window instead of the page's blank space. The rows the window draws plus its `↑n` and `↓n`
counts SHALL equal the number of focusable rows the view holds (a row hidden as fixture-only is not a focusable
row and is not counted). The space the rows do not use SHALL stay inside the card (the detail view's own fill rule), so the key band remains the frame's last row. This SHALL hold in
every view state the block can render — the row list, the choice picker and the seat picker. It sharpens, and
MUST NOT weaken, the frame-level promise that a bounded frame fills the pane: there the spare height is spent
*inside the content area*, and this view's share of it is rows.

#### Scenario: The card fills the pane and the window grows with it

- **GIVEN** a fixture contract with more rows than any measured pane and the view open at the top of the list
- **WHEN** the pane is 45, 33, 30 and 25 rows tall
- **THEN** at every height the card's last drawn row is at most one blank row above the key band, the rows drawn
  plus `↑n` plus `↓n` equal the view's focusable row count (the command's keys minus the fixture-only ones, plus
  its seats), and the 45-row pane draws at least eight more rows than the 30-row pane

#### Scenario: A short list keeps its blank space inside the card

- **GIVEN** the view open with a filter that matches a single key
- **WHEN** the frame renders in a tall pane
- **THEN** the card still ends at most one blank row above the key band, the blank space is inside the card, and
  the row, its heading and the command line are all still drawn

### Requirement: The disk floor's keys are contract rows the console carries

The capacity floor's two thresholds SHALL be rows of the project contract's schema — `TEAM_TMP_MIN_FREE_MB`
(kind `mb`, default `1024`) and `TEAM_TMP_MIN_FREE_INODES` (kind `int`, default `100000`), both class `apply` and
group `delivery` — and the disk fixtures' seam `TEAM_DISK_STATS_FILE` SHALL be a `refuse` schema row whose note
carries the fixture-only marker, so the read carries it for the suites and the settings view does not render it
(the row-set rule above): the two thresholds render as editable `apply` rows with their zh/en label and, while the
file is silent, the schema's default; the seam reaches the machine read and never the view.
`team config list --json` SHALL report the same classes, defaults and group, and both tables SHALL carry a
non-empty `label_<KEY>` for each of the three (the string-table gate checks those in both directions and within
the row's label column); the seam's label stays in the tables even though its row is hidden, because the gate
covers the schema, not the view.

#### Scenario: The three keys reach the view and the machine read

- **GIVEN** a fixture project whose contract does not carry the three keys and a JS runtime
- **WHEN** `team config list --json` runs and the settings view renders in a fixture pane
- **THEN** the three keys each reach the machine read: the two thresholds' records carry class `apply`, defaults
  `1024` and `100000` and group `delivery`, and the seam's record carries class `refuse` and a note that begins
  with the fixture-only marker, while the human `team config list` still lists all three
- **AND** only the two thresholds reach the view (each row's main text is that key's label in the active language,
  no row reads `TEAM_…`); the seam is the deliberate exception the row-set rule owns — the rendered frame carries
  no row, heading or filter hit for it — and removing its marker in a scratch tree brings the row back

### Requirement: Settings edit task categories and independent PM policy rather than worker seats

Settings SHALL render ordered category rows and an independent PM model row from config JSON, with both languages' labels and owning command route. Category picker uses project known models plus free text and SHALL write `set-task-model`, never compose a mapping; whole-map row routes to category rows and has no pairlist/seat override editor. PM uses `config set TEAM_PM_MODEL`. Missing mapping/retired policy yields a visible migration diagnosis and explicit CLI upgrade route, not an in-panel migration/restart: the diagnosis lines are the owning command's own text (a CLI route, rendered verbatim under a heading from the zh/en tables) and the heading is a plain user-facing phrase. Existing editor keyboard/mouse, direct-choice/free-text confirmation, dry-run/CAS/actor panel/cancel/conflict/background-refresh behavior remains. Category policy receipts name next new task; they explicitly do not switch a running or resumed assignment. PM receipts name guarded next PM launch and fresh when model changes. Assignments appear read-only with actual task/category/complete model/original and launch source/SID, visually separate from future policy. There is no worker default or per-worker model editor and no process restart action.

The two halves SHALL be told apart in plain user-facing language, not in the project's private shorthand: the
future-policy block's heading says that these are the models the **next** dispatch will use (「下一次派任务会用的模型」)
and the committed block's heading says that these are the models **running** tasks actually use (「正在运行的任务
实际使用的模型」), with a sentence that says why they can differ — a task keeps the model it was dispatched with,
so changing the future setting never changes a task already running. A seat whose record is not complete SHALL
show a plain-language reason chosen from the facts the read reports, never the command's diagnostic string: the
file carries no record at all → 「这个席位还没有派过任务」; a record exists but cannot be read → a sentence saying
so (the panel does not invent a model and does not claim the seat was never used). The `SID` the row carries
SHALL be labelled as a session id in plain words, and the origin tokens SHALL read as plain phrases rather than
schema field names.

#### Scenario: Category and PM writes are CLI-owned in a real pane
- **GIVEN** real fixture tmux pane, valid config and logging CLI wrapper
- **WHEN** keyboard and mouse select a category model, free-text edit PM model and confirm
- **THEN** captures show category/PM labels and honest timing; argv logs carry set-task-model and PM-set dry-run then CAS writes with actor panel; exactly intended config tokens change and no restart occurs

#### Scenario: Policy changes cannot be presented as resumed task models
- **GIVEN** routine assignment with explicit strong model
- **WHEN** routine policy is changed in settings
- **THEN** read-only assignment still shows original model/SID/provenance, category policy shows new value and receipt says new tasks only; same-task preview remains the assignment model

#### Scenario: The two halves are named in plain language and keep their own model
- **GIVEN** a fixture with a committed `routine` assignment and a later category-policy change
- **WHEN** the settings view renders both blocks
- **THEN** the future-policy heading says the next dispatch will use these models and the committed heading says
  these are the models running tasks use, a sentence says a dispatched task keeps the model it was given, and the
  committed row still shows the assignment's own model while the category row shows the new policy value

#### Scenario: A seat's missing record is a plain reason, not the command's diagnostic
- **GIVEN** a fixture project whose `verify` seat has no record file and whose `dev` seat carries an unreadable
  record (no assignment-shaped field, or a version this tool does not read)
- **WHEN** the settings view renders the committed block
- **THEN** the `verify` row carries 「这个席位还没有派过任务」 and the `dev` row carries a sentence saying its record
  could not be read, neither row renders the command's diagnostic string (`legacy/unknown assignment_version`,
  `malformed …`, missing-file prose, …) and neither row shows a model
- **AND** a scratch copy of the read that reports both seats as record-less turns the fixture red — the two
  reasons are chosen from the read's facts, not from the wording

#### Scenario: Cancel invalid input and conflicts preserve bytes
- **WHEN** picker is cancelled, invalid model entered, or a second writer changes config under the editor
- **THEN** cancel/invalid write nothing and retain appropriate focus/draft; conflict names exit 3, leaves other writer bytes and refreshes the view; no panel process directly writes config

#### Scenario: Legacy and small multilingual settings remain navigable
- **WHEN** settings open under legacy config in zh and en, and valid policy in narrow/tall panes
- **THEN** migration route remains visible without false editable seat defaults; keyboard/mouse scrolling and filtering reach all category/PM/read-only assignment rows, with group headings not focusable
