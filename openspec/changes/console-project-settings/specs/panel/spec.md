## ADDED Requirements

### Requirement: The console shows the project contract with its effect class, and refuses what it must not change

The settings overlay's navigation row SHALL open a **project-settings view** that replaces the page's blocks — the
title band, the page tabs and the key band stay, exactly as with the overlay itself, and the view is closed with
`esc` back to the overlay it was opened from without collapsing the console. The view SHALL list the project
contract (`.pi/team/config.sh`, `memory-and-deps`'s single-writer file): one row per key of the owning command's
schema plus one row per key the file itself carries that the schema does not know, and per row the key name, the
current value (the file's value, else the schema's default marked as unset), the key's **class** from the schema
and the key's own trailing inline comment when its line has one. The class vocabulary SHALL be the owning
command's, closed and rendered from the tables: `apply` (the next read of the file uses it), `restart` (a running
process holds the old value until it is restarted — the badge names the target: the pulse, the PM or a live
session) and `refuse` (the console must not change it). The row set and the classes MUST come from the owning
command's machine-readable read at render time; the bundle MUST NOT carry a second key table, so a key added to
the command's schema appears in the view without rebuilding `panel.js`. `↑`/`↓` SHALL move a row focus (group
headings are not focusable) and SHALL drag a window that counts the rows it hides at each edge; a click SHALL
focus a row and a click on the focused row SHALL open its editor, the kanban's rule. `/` SHALL open a filter line
that narrows the list to the rows whose key or value contains the filter text (case-insensitively) and `esc` SHALL
clear it without closing the view. A `refuse` row SHALL open no editor and its interaction SHALL surface the
owning command's refusal, which names the right route (hand-editing the file, `team add-agent`, …). The view's
own labels SHALL come from the zh/en tables. The view is a console-only block: `--print` and `--json` MUST NOT
read or render it, and the machine exits' bytes are unchanged. The view MUST NOT be a fifth page: the four-page
composition and `state/panel-page` keep their meaning.

#### Scenario: The rows carry the three classes and the unset key its default

- **GIVEN** a fixture contract whose file holds `TEAM_GATES`, `TEAM_PULSE_INTERVAL` and `TEAM_PROJECT`, and a
  schema whose `TEAM_DEFER_TTL` the file does not carry
- **WHEN** the project-settings view renders in a 160-column fixture pane
- **THEN** the three ruled rows carry the `apply`, `restart` and `refuse` badges, the `TEAM_DEFER_TTL` row shows
  the schema's default and the unset marker, and every rendered label exists in both tables

#### Scenario: The row set and the classes come from the command, not from the bundle

- **GIVEN** a scratch copy of the CLI whose schema carries an extra key `TEAM_ZZZ_TEST` and whose `TEAM_GATES`
  class is `refuse`
- **WHEN** the view renders against that CLI with the committed `panel.js` unchanged
- **THEN** the list carries a `TEAM_ZZZ_TEST` row and `TEAM_GATES`'s badge reads `refuse`

#### Scenario: A refuse row opens no editor and the route is named

- **GIVEN** the view open with the focus on `TEAM_SESSION`, and then on `TEAM_AGENTS`, the roster key, with the
  contract's sha256 recorded
- **WHEN** `enter` is pressed on each and `x` is typed
- **THEN** neither opens an editor, each receipt names the route (`team add-agent` / `team teardown` for the
  roster, hand-editing the file for an identity key), and the contract's sha256 is unchanged after both

#### Scenario: The filter narrows and clears

- **GIVEN** the view open on a contract with more keys than one frame shows
- **WHEN** `/` is pressed and `pulse` is typed, and then `esc`
- **THEN** the first frame lists only rows whose key or value contains `pulse`, and the frame after `esc` lists
  every row again with the view still open

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

An editable row's `enter` SHALL open a one-line value editor that is the compose line's editor (the insertion
point, pi's key map, the windowed draft — the `panel` requirement that owns it) holding the file's value, or the
schema's default when the key is not in the file. `enter` in the editor SHALL NOT write: it SHALL ask the owning
command for a validation (`team config set … --dry-run`, a read that writes nothing) and, when accepted, show a
confirmation line with the key, the old value, the new value and the class's timing (and, for a `restart` class,
the exact restart command); a second `enter` SHALL perform the write by invoking `team config set … --yes` as a
subprocess, and `esc` SHALL cancel with nothing written, no audit line and no temporary file left behind. A value
the command reports as dangerous SHALL NOT be written on the first `enter`: the confirmation line SHALL carry the
warning and require one more `enter`. The receipt SHALL be one honest line mapped from the command's exit code —
written (with the class's timing), refused as read-only, rejected as invalid (naming the accepted domain),
refused because the file changed under the editor, or a write error that says the file was left unchanged — and
MUST NOT be parsed from human prose. On a conflict the view SHALL reload the contract and display the other
writer's value; on any settle the list and the audit tail SHALL be re-read. The console MUST NOT open the
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

## MODIFIED Requirements

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

## REMOVED Requirements

### Requirement: The console is read-only except through three commands

**Reason**: the project-settings write is a fourth state-changing action, so the title's count can no longer name
the discipline, and a rename is a remove-plus-add (the delta vocabulary has no rename). The replacement is "The
console is read-only except through its owning commands", which keeps this requirement's content — the owning
commands as subprocesses, the console's own three files, the `C-v` paste as input editing — and adds the fourth
action, the contract-write path and the dry-run-is-a-read rule.

**Migration**: `m`/`f`/`s` keep their keys and their owning commands; the contract is still written by a `team`
command (now `team config set`) and never by the panel; the read-only sweep keeps its old assertion and adds the
contract and the audit log to the files it watches.
