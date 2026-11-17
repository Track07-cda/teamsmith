# Spec Delta

## REMOVED Requirements

### Requirement: The console shows the project contract with its effect class, and refuses what it must not change

**Reason**: Retire the complete-table presentation, unknown/new-key auto-appearance, mandatory CLI-key titles and per-row class/default badges. Those scenarios intentionally cease to describe the selected UI; they are not silently dropped by a MODIFIED block.
**Migration**: Use the selected-operations requirement below. Full configuration remains in the existing CLI; owning-command permission, errors, navigation and machine-output boundaries survive in its replacement scenarios.

### Requirement: The console offers the schema's choice set wherever there is one, and degrades visibly where there is none

**Reason**: Retire editors for every schema kind, automatic new-key UI editors, the whole-map jump and raw pattern composition. Hidden enum/path settings no longer need UI editors or their fixture scenarios.
**Migration**: The selected-editors requirement below retains command-owned values/choices, direct choice versus confirmed free input, CAS, danger, cancellation and responsiveness; only simultaneous-task rules gain a field form over the same value. No CLI validation or choices behavior is removed.

### Requirement: The settings view groups the contract by the functional group the command reports, and carries the effect class on the row

**Reason**: Retire mandatory schema-token order/group-label equality, unknown fallback group, automatic new-group headings and repetitive class badges.
**Migration**: Use purpose groups below; CLI group metadata stays unchanged, with meaningful action state in words, bilingual headings and existing focus/mouse rules.

### Requirement: The disk floor's keys are contract rows the console carries

**Reason**: Retire disk-space/inode keys as mandatory UI rows and fixture-key labels as mandatory UI strings; no resource-threshold subpage replaces them.
**Migration**: The selected-operations disk scenario preserves full CLI/schema facts and actual capacity errors. Both thresholds and the fixture seam remain unchanged outside this view.

## ADDED Requirements

### Requirement: Project settings expose selected user operations rather than the complete configuration table

Project settings SHALL select operations for models and automatic checks, with project-command and model-record secondary views, not mirror the CLI schema. Values, defaults, choices, permissions and errors SHALL remain command-owned. Categories SHALL follow project data without a fixed vocabulary or count; excluded keys SHALL remain in the CLI, not return through search.

#### Scenario: Models precede settings and every project category is reachable
- **GIVEN** valid identical input with C=3 categories, A=5 assignment rows, one PM launch and no unknown keys
- **WHEN** the default view opens
- **THEN** it has ten focusable rows: all three categories first, then PM model, concurrent tasks by model, check interval, PM recoveries per hour and startup update check, then project-command and model-record entries
- **AND** every reported category remains directly editable in its reported order for larger or differently named project category sets; C+7 is a count formula, not a limit

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
- **AND** model-record filtering searches its own record facts rather than reopening excluded settings

#### Scenario: Navigation preserves the overlay and two secondary origins
- **WHEN** the overlay's project-settings entry opens, each secondary entry opens and Esc is used to return
- **THEN** title/tabs/key band remain, each secondary view returns to its originating default entry, and default Esc restores the original overlay focus without collapsing the console
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
- **THEN** Models and Automatic checks are the two content groups followed by the two named secondary entries; changing a retained key's group does not move its operation and adding an excluded key/group adds no UI heading

#### Scenario: Headings are visible without becoming interaction targets
- **WHEN** groups render and are walked by keyboard/mouse in both languages
- **THEN** each nonempty group has a localized section rule immediately before its rows without another blank separator, headings take no focus/click stop, and necessary timing/read-only/error state appears in words rather than colour or repetitive class badges

#### Scenario: String completeness follows purpose references
- **WHEN** a presented purpose/navigation label is missing, or a new CLI group belongs only to excluded keys
- **THEN** the missing displayed label fails its existing string check, but the unrelated CLI group requires no new UI label or page

## MODIFIED Requirements

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
