## ADDED Requirements

### Requirement: The console composes four pages and remembers the position

The TUI SHALL compose four pages — an overview (the status banner, the project-progress counts, the recent
deliveries, the agent table, the capacity sparkline and the recent events), a work page (the board rows, the
active changes with their phases, the spec counts and the recent decisions), a messages-and-logs page (the
deferred queue, the inbox and threads, the patrol log, the capacity trend and the health block) and a board page
(the kanban of "The board page is a kanban over the board's states") — plus a settings overlay. A block whose
source has no data SHALL collapse and yield its space. Tab and the keys `1`–`4` SHALL switch pages, and the
current page SHALL be written to `state/panel-page` and restored on the next start; a value outside `1`–`4` in
that file SHALL fall back to the default page, never fail the render. Pages are a TUI-only concept: `--print`
and `--json` render the overview content.

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

### Requirement: The board page is a kanban over the board's states

The board page SHALL render every BOARD.md row as a card in one of six state lanes, in the fixed order the
BOARD.md header legend declares (`todo`, `wip`, `review`, `done`, `blocked`, `dropped`). Every lane SHALL render
even when it holds no card — an empty lane shows a dim empty marker — so lanes never shift position between
frames. A card SHALL carry the entry's id, title, agent, state glyph and the phase token from its task brief's
`phase:` header (an entry with no brief or no `phase:` line renders a placeholder), truncated to the lane width.
At 100 columns and wider the lanes SHALL be side by side with an even share of the usable width; under 100
columns the page SHALL degrade to a single column grouped by state in the same lane order; under 60 columns a
card SHALL shrink to one line (state glyph, id, title — the agent and phase drop). The focused card SHALL be
marked by a cursor glyph and the `selected` tone — never by color alone — and SHALL be tracked by entry id, so a
data refresh that reorders or extends the board does not move the focus to a different entry; when the focused
entry leaves the board, the lane's first card SHALL take the focus. A lane holding more cards than its visible
window SHALL scroll (`↑`/`↓` past the edge, and the wheel over the lane) and SHALL mark each edge that hides
cards with their count. The lane windows of the `done` and `dropped` history lanes SHALL anchor on the newest
cards.

#### Scenario: Six lanes at the reference geometry

- **GIVEN** a fixture project whose BOARD.md holds rows in `todo`, `wip`, `review` and `done`, and the console on
  the board page in a 160-column fixture pane
- **WHEN** one frame renders
- **THEN** the capture shows the six lane headers in the legend order, the cards under their states, and the
  `blocked` lane with an empty marker

#### Scenario: A card carries id, agent, phase and title

- **GIVEN** a fixture row `M9` whose task brief's header declares `phase: apply`, and a row `X1` with no task
  brief
- **WHEN** one board-page frame renders at 160 columns
- **THEN** M9's card shows `M9`, its agent, the `apply` token and its title, and X1's card shows the placeholder
  where the phase would be

#### Scenario: Narrow terminals degrade to one grouped column

- **GIVEN** the same fixture
- **WHEN** the board page renders one bounded frame at 99 columns and one at 59 columns
- **THEN** both frames stack the states in a single column in the legend order, and the 59-column frame renders
  one line per card (state glyph, id, title) with no agent field

#### Scenario: The focus survives a refresh

- **GIVEN** the console on the board page in a fixture pane with the focus on entry `M9`
- **WHEN** a refresh rebuilds the board block with `M9`'s row at a different position, and later with `M9` gone
- **THEN** the focus marker still sits on `M9` after the first refresh, and lands on that lane's first card
  after the second

#### Scenario: A long lane scrolls and counts what it hides

- **GIVEN** a fixture board whose `done` lane holds 20 cards and a lane window of six cards
- **WHEN** the board page first renders, and the focus then moves down past the window's edge
- **THEN** the first frame shows the newest six `done` cards with a `+14` style count at the bottom edge, the
  window scrolls with the focus, and wheel-down over the lane scrolls it without moving the focus

### Requirement: A focused card opens a read-only markdown detail view

Enter (or a click on the already focused card) SHALL open a detail view that replaces the page's blocks — as
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
view SHALL be read-only: it adds no action key. Esc or `q` SHALL return to the board page and SHALL NOT collapse
the console — a documented exception to the global `q`, in force only while the detail view is open. The reader
MUST NOT serve a path outside the discovered set: a `--file` argument naming any other path SHALL fail.

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

## MODIFIED Requirements

### Requirement: Every key affordance is also a mouse target

With the mouse preference on, the console SHALL enable SGR mouse reporting for its lifetime and disable it on
exit, and every documented key — `m`, `f`, `s`, `,`, Tab, `1`–`4`, `↑`/`↓`, `q`, and on the board page `←`/`→`
and Enter — SHALL have a clickable target that acts identically; the wheel SHALL scroll the current page's
scrollable region (one offset per page, one line per notch on pages 1–3, where there is no focused block — V15
F5 ruling; on the board page each lane carries its own offset and the wheel SHALL scroll the lane under the
cursor). A click on a kanban card SHALL focus it, and a click on the already focused card SHALL open its detail
view. Coordinates are 1:1: a click on a target activates that target (E6 §1.1 measured the full path, with
tmux's own mouse option in either state). With the preference off the console SHALL emit no mouse-reporting
sequence and clicks SHALL do nothing. The settings overlay is an in-page overlay, not a modal: it replaces the
page's blocks but keeps the title band, the tabs and the key band, so the footer chips still visible under it
stay clickable and act exactly as they do with the overlay closed, while the replaced blocks keep **no**
targets — a click at a block's former coordinates does nothing (V16 F-V16-4, ruled as the actual behaviour).
The same replacement rule SHALL apply to the detail view: while it is open, the kanban's cards keep no targets.
`r` (rebuild the cached blocks on demand) is the one named exception, because it is a keyboard-only key: it has
no chip in the key band and MUST NOT appear in the frame's target map, so "every affordance is clickable" counts
only the affordances the console shows (V16 F-V16-5).

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

## REMOVED Requirements

### Requirement: The console composes three pages and remembers the position

**Reason**: the board page makes the console four pages; the three-page heading can no longer name the
composition, and a rename is a remove-plus-add (the delta vocabulary has no rename). The replacement is "The
console composes four pages and remembers the position", which carries the three pages' content and the page
file's restore semantics forward unchanged apart from the widened range.

**Migration**: pages 1–3 keep their blocks and their keys; `state/panel-page` values `1`–`3` keep their meaning
and `4` names the board page; `--print`/`--json` keep rendering the overview content.
