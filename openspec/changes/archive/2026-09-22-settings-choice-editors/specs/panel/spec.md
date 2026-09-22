## ADDED Requirements

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

## MODIFIED Requirements

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
