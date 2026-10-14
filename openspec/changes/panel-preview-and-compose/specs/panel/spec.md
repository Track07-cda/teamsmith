## MODIFIED Requirements

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
file of any other change or of `openspec/changes/archive/`; `--source decision --id <D-number>` SHALL serve the body
of that decision entry out of `docs/team/DECISIONS.md` as one tab. A reader that is given no source keeps its
present meaning (the entry-id families above), so an existing caller behaves exactly as it does today. The sources'
roots are the reader's own project root: the spec and change sources read only under the openspec directory the
panel's other readers already resolve, the decision source only the ledger's `docs/team/DECISIONS.md`, and the entry
source only the three ledger directories above. A request whose source is outside that closed set, whose id leaves
its source's grammar (`[A-Za-z0-9._-]` for a capability or change id, `D<digits>` for a decision), or whose `--file`
is not one of the paths the requested source discovered SHALL fail with a non-zero exit and one line naming what was
refused, printing no file content; a discovered path that is a symbolic link SHALL be refused and named, never read
through. The decision source serves exactly one entry and offers no whole-file exit: its `--file` selects the ledger
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

#### Scenario: A symlinked entry is refused, never read through

- **GIVEN** a fixture whose `openspec/changes/demo/proposal.md` is a symbolic link to a file outside the change
- **WHEN** `--source change --id demo` runs and the detail view opens on it
- **THEN** the symlinked path is refused and named, the link's target text is not printed, and the change's other
  two artifacts still open

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
