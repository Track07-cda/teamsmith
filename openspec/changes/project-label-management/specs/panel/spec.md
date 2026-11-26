## ADDED Requirements

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

## MODIFIED Requirements

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
