## Purpose

Keep the console's read-only previews usable when the project's own ledger or spec tree is reached through a
symbolic link, while keeping the one boundary that matters: nothing outside the project root is ever read.

## MODIFIED Requirements

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
