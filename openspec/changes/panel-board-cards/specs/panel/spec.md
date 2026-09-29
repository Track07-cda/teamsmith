## ADDED Requirements

### Requirement: A lane folds from its header, and empty lanes fold by default

The board page SHALL fold and unfold each lane from its header. A folded lane SHALL render as exactly one line
carrying its label, its card count and the folded text marker, and SHALL NOT render any of its cards, any edge
counter, or the empty-lane marker; each lane keeps its position in the fixed lane order, so folding never
reorders the board. A folded lane's column SHALL keep the lane body's height — its one line draws at the top and
the rows below stay blank — so the frame stays filled and the key band stays the frame's last row. The fold
marker SHALL be a glyph together with a text token, never colour alone, and the header of an unfolded lane SHALL
carry the mirror marker so the toggle is visible in both states.

Folding changes the width share, not the lane order: a folded lane's line SHALL take the width it needs, bounded
by a documented floor, and the lanes that are not folded SHALL share the remaining usable width — folding a lane
widens the lanes that still show cards. When the width cannot satisfy every unfolded lane's floor, the folded
line SHALL truncate first: the fold degrades before the cards' shares do.

A folded lane's presentation follows the pane's width tier, because the scarce resource differs by width. In the
tiers where the board draws its lanes side by side, a folded lane SHALL take a three-column frame: a rounded
corner at each of its four corners (the panel's own corner glyphs, `╭ ╮ ╰ ╯`), a vertical border on each side and,
in the middle column, the ellipsis (`╭─╮` over `│…│` over `╰─╯`, the middle column drawn down the lane's height
as the ellipsis). The folded lane SHALL keep its position in the fixed lane order, so the frame alone says which lane it
is, and the whole width the three columns do not use SHALL go to the unfolded lanes — folding gives columns back,
and the lane row SHALL NOT render wider than the usable width in any tier. The focused folded lane SHALL name
itself — its label and card count — where the focused card's demoted pair renders, since three columns cannot
carry the label. In the tiers where the usable width cannot hold the unfolded lanes' floors and the board groups
its lanes, a folded lane SHALL stay in place as its single line carrying the label, the count and the folded
marker — there folding is what saves rows — and the three-column frame SHALL NOT be used.

A folded lane SHALL stay reachable through its cards: `←`/`→` still stop on a folded lane that holds cards, and
while the focused card lives in a folded lane the lane's one line SHALL carry the focus cursor and the `selected`
tone (exactly one cursor in the frame). `↑`/`↓` SHALL NOT move the focus while the focused lane is folded, and
Enter SHALL still open the focused card's detail view. The wheel over a folded lane SHALL stay that lane's and
MUST NOT scroll the page behind it.

The `c` key SHALL toggle the fold of the focused lane on the board page and the key band SHALL carry its chip
(`c 折叠` / `c fold`); the key is ignored while the detail view or the settings overlay owns the page region (the
kanban is not drawn). Each toggle SHALL be written to `state/panel.conf` as it happens.

An empty lane SHALL fold by default and a lane holding cards SHALL stay unfolded, unless the human set that
lane's state explicitly: `state/panel.conf` carries `boardFold` (the lanes folded explicitly) and `boardShow`
(the lanes kept unfolded explicitly), both written in the lane legend's order with unknown lane names dropped
and a lane named by both lists folded (the explicit hide wins), and `boardEmptyFold` (`0`/`1`, default `1`)
turns the empty-lane default off. A lane an empty default folded
SHALL unfold by itself as soon as it holds a card; an explicit state SHALL survive both a re-render and a
restart. The file's absence or corruption falls back to the defaults exactly as the settings requirement rules,
and `--print`/`--json` MUST NOT read these keys: a machine frame renders the default fold state, so two
`panel.conf` fold states produce byte-identical machine frames.

#### Scenario: Folding a lane stops rendering its cards

- **GIVEN** the fixture board whose `done` lane holds 20 cards, the console on the board page at 160 columns
- **WHEN** the `done` lane is folded, and later unfolded
- **THEN** the folded frame draws the lane's one line with its count `20` and none of the 20 cards (no title, no
  edge counter), the unfolded frame draws the newest six cards with the `+14` count again, and no other lane's
  cards changed

#### Scenario: Empty lanes fold by default, and the default can be turned off

- **GIVEN** a fixture board with cards in `todo` and none in `review`, `blocked` or `dropped`, and a second
  `state/panel.conf` carrying `boardEmptyFold=0`
- **WHEN** the board page renders at 160 columns under each
- **THEN** with the default the `review` line reads its folded marker and its count `0` while `todo` renders its
  card, and with `boardEmptyFold=0` the empty lanes render their box and the dim empty marker instead

#### Scenario: The fold state survives a restart, and an explicit unfold sticks

- **GIVEN** the console in a fixture pane with the `done` lane folded and an empty lane unfolded
- **WHEN** the console is quit and relaunched, and the board later gains the first card in that empty lane
- **THEN** the relaunch still folds `done` and still shows the unfolded empty lane, and the lane that gained a
  card stays unfolded

#### Scenario: The focus stays on a folded lane's card

- **GIVEN** the console on the board page with the focus on a card of the `wip` lane
- **WHEN** `c` folds `wip`, `↑`/`↓` are pressed, and `c` is pressed again
- **THEN** the folded `wip` line carries the cursor glyph and the selected tone, `↑`/`↓` leave the cursor there,
  and the second `c` restores the cards with the cursor on the same card

#### Scenario: Folding does not disturb the board's other interactions

- **GIVEN** the console on the board page with one lane folded and a board longer than the pane
- **WHEN** `←`/`→` walk the lanes, `↑`/`↓` walk the cards of an unfolded lane, Tab cycles the pages, the wheel
  scrolls a lane, the language is switched to `en`, and the frame renders in a bounded pane
- **THEN** the lane walk keeps the legend order and steps over empty lanes as before, the card walk keeps its
  window-follow rule, Tab still reaches page 4, the wheel still moves only the lane under the cursor, the labels
  come from the `en` table, and the frame's row count equals the pane height with the key band last

#### Scenario: Folding gives the unfolded lanes width

- **GIVEN** a fixture board with an empty `blocked` lane and the board page at 160 columns
- **WHEN** the empty lane is folded, and later unfolded
- **THEN** the unfolded lanes' borders move apart (a wider share each) while the frame's rows stay within 160
  columns and the six lane positions keep their legend order

#### Scenario: A wide pane gives a folded lane's columns to the unfolded lanes

- **GIVEN** the fixture board whose `review` and `blocked` lanes are both empty, the board page at 190 columns,
  and the board page rendering wider than 190 columns before the fold
- **WHEN** the empty default folds both lanes
- **THEN** each folded lane renders as a three-column frame — rounded corners, a border column, an ellipsis
  column, a border column — the lane row renders within the 190 columns, and the unfolded lanes' combined width is larger than in the in-place form

#### Scenario: A focused folded lane names itself

- **GIVEN** a folded lane holding cards, the focus moved onto its three-column frame
- **WHEN** the frame renders
- **THEN** the lane's label and card count appear where the focused card's demoted pair renders, and the frame
  carries the focus cursor

#### Scenario: A narrow pane saves rows, not columns

- **GIVEN** a fixture board at 59 columns whose `done` lane holds cards
- **WHEN** that lane is folded
- **THEN** the frame's card rows shrink by that lane's cards, the folded lane draws in place as its single line
  carrying its label and count, and the three-column frame of the wide form is not used

#### Scenario: Machine frames ignore the human's fold state

- **GIVEN** two `state/panel.conf` files, one folding a non-empty lane and one carrying no fold keys
- **WHEN** `team monitor --print --page 4` runs under each
- **THEN** the two prints are identical apart from the timestamp, and the empty lanes are folded in both

## MODIFIED Requirements

### Requirement: Every key affordance is also a mouse target

With the mouse preference on, the console SHALL enable SGR mouse reporting for its lifetime and disable it on
exit, and every documented key — `m`, `f`, `s`, `,`, Tab, `1`–`4`, `↑`/`↓`, `q`, on the board page `←`/`→`, `c`
and Enter, and on the work page the board rows (a click focuses a row, a click on the focused row opens its detail) —
SHALL have a clickable target that acts identically; the wheel SHALL scroll the current page's scrollable region
(one offset per page, one line per notch on pages 1–3 — V15 F5 ruling; on the work page `↑`/`↓` move the board-row
focus and the wheel keeps scrolling the page; on the board page each lane carries its own offset and the wheel
SHALL scroll the lane under the cursor). While the project-settings view is open the wheel is its region and MUST
NOT reach the page the view was opened from: it scrolls the view's row window — one row per notch, the row focus
unchanged, the view's hidden-row counts at both edges following the window — and with either of the view's
pickers open it walks that picker's entries instead; the `↑`/`↓` keys and the view's `↑/↓ 行` target SHALL keep
moving the focus and SHALL push the window so the focused row is inside it. A click on a kanban card SHALL focus it, and a click on the already
focused card SHALL open its detail view. A click on a lane's header line — the top border of an unfolded lane, or
a folded lane's single line — SHALL toggle that lane's fold, the same frame change `c` produces for the lane it
names; the folded line keeps the lane's wheel region, so the wheel over it MUST NOT scroll the page behind it.
Coordinates are 1:1: a click on a target activates that target (E6 §1.1 measured the full path, with
tmux's own mouse option in either state). With the preference off the console SHALL emit no mouse-reporting
sequence and clicks SHALL do nothing. The settings overlay is an in-page overlay, not a modal: it replaces the
page's blocks but keeps the title band, the tabs and the key band, so the footer chips still visible under it
stay clickable and act exactly as they do with the overlay closed, while the replaced blocks keep **no**
targets — a click at a block's former coordinates does nothing (V16 F-V16-4, ruled as the actual behaviour).
The same replacement rule SHALL apply to the detail view: while it is open, the kanban's cards keep no targets,
and so do the work page's board rows. `r` (rebuild the cached blocks on demand) is a named exception, because it is
a keyboard-only key: it has no chip in the key band and MUST NOT appear in the frame's target map, so "every
affordance is clickable" counts only the affordances the console shows (V16 F-V16-5). `pageUp`/`pageDown` are the
second named exception: they exist so the work page stays scrollable by keyboard once `↑`/`↓` move the board-row
focus, they carry no chip (the band is width-bounded), and they MUST NOT appear in the target map either.

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

#### Scenario: The lane header is the fold key's target

- **GIVEN** the console on the board page in a fixture pane with the mouse preference on, the `todo` lane
  folded and the focus on another lane
- **WHEN** a click lands on the folded `todo` line, and a later click lands on the `c 折叠` chip
- **THEN** the first click unfolds `todo` exactly as `c` would act on that lane, and the chip click folds the
  lane the focus names — the key would produce the same frame

#### Scenario: The wheel scrolls the settings view's window

- **GIVEN** the project-settings view open at the top on a fixture contract with more rows than the pane shows
- **WHEN** three wheel-down notches are injected over the view
- **THEN** the visible window moves down three rows (the row that was first is gone and a later one entered), the
  row focus does not move (the view's command line still names the same key), and the top count line reads `↑3`
- **AND** three wheel-up notches bring the window back to the top and the count line disappears

#### Scenario: The wheel over the view does not move the page behind it

- **GIVEN** a page scrolled away from its top, the project-settings view opened over it, and the page's window
  recorded
- **WHEN** wheel events are injected over the view and `esc` returns to the page
- **THEN** the page renders the same window it had before the view opened — the view consumed the wheel
- **AND** with the choice editor `enter`ed open, or with the seat picker open, the wheel walks that picker's
  entries (the selection moves, the page still does not) and `esc` afterwards keeps that picker closed
- **AND** with the mouse preference off the same wheel emits no report and neither the view nor the page moves

#### Scenario: The focus keys keep the focused row inside the window

- **GIVEN** the view wheel-scrolled so the focused row is outside the visible window
- **WHEN** `↓` or `↑` moves the focus, and `enter` opens the focused row
- **THEN** the window has been pushed so the focused row is visible, and the row the editor was opened for is the
  row the view's command line names

### Requirement: The board page is a kanban over the board's states

The board page SHALL render every BOARD.md row as a card in one of six state lanes, in the fixed order the
BOARD.md header legend declares (`todo`, `wip`, `review`, `done`, `blocked`, `dropped`). Every lane SHALL render
even when it holds no card — an unfolded empty lane shows a dim empty marker, an empty lane folded by default
shows its folded line — so lanes never shift position between frames. A card's line SHALL carry the entry's id,
the state glyph and its title, truncated to the lane width; the agent and the phase token from its task brief's
`phase:` header MUST NOT render on a card's line — they are demoted out of the lane's width (an entry with no
brief or no `phase:` line renders the placeholder in the demoted pair, never on the card). On the board page the
key band SHALL carry the focused card's demoted pair from the width its own key chips leave free: with room
`agent · phase`, and, as that width shrinks, the phase alone before the pair disappears — the agent is dropped
before the phase, and the pair before the band's chips are disturbed. The degradation order SHALL therefore be
explicit — agent, then phase, then the title — and the card line starts at the title, so no width exists at which
a card truncates its title to keep an agent or a phase.
At 100 columns and wider the lanes SHALL be side by side with an even share of the usable width among the lanes
that are not folded (a folded lane's one line takes the width it needs; the lane-fold requirement owns that
share); under 100 columns the page SHALL degrade to a single column grouped by state in the same lane order;
under 60 columns the card keeps its one-line form (state glyph, id, title), the id SHALL NOT be the field that
drops, and the title SHALL truncate last. The focused card SHALL be
marked by a cursor glyph and the `selected` tone — never by color alone — and SHALL be tracked by **row
identity**: the entry id together with the row's occurrence among the rows carrying that id, in BOARD.md order.
A refresh that reorders or extends the board, a lane change, and a click MUST all keep addressing the same row,
two rows that share an id are two separate stops with the cursor on exactly one of them, and when the focused row
leaves the board the first row carrying its id SHALL take the focus — when no row carries the id, the lane's
first card SHALL take the focus. A lane holding more cards than its visible window SHALL scroll (`↑`/`↓` past the
edge, and the wheel over the lane) and SHALL mark each edge that hides cards with their count. The lane windows
of the `done` and `dropped` history lanes SHALL anchor on the newest cards.

#### Scenario: Six lanes at the reference geometry

- **GIVEN** a fixture project whose BOARD.md holds rows in `todo`, `wip`, `review` and `done`, and the console on
  the board page in a 160-column fixture pane
- **WHEN** one frame renders
- **THEN** the capture shows the six lane headers in the legend order, the cards under their states, and the
  empty `blocked` lane rendered as its folded line with its count `0` instead of a boxed empty lane

#### Scenario: A card carries id, agent, phase and title

- **GIVEN** a fixture row `M9` whose task brief's header declares `phase: apply`, a row `X1` with no task
  brief, and the console on the board page with the focus on `M9`
- **WHEN** one board-page frame renders at 160 columns
- **THEN** the frame carries M9's id, agent, `apply` token and title across the two surfaces the requirement
  names — the card's line shows the state glyph, `M9` and its title and neither the agent nor `apply`, while
  the key band carries M9's agent and `apply`; after the focus moves to X1 the band carries the placeholder
  where the phase would be, and no card line carries an agent or phase token

#### Scenario: The title is the line's last truncation

- **GIVEN** a fixture board whose card carries a long title and an agent, and the console at 190 columns with
  the focus on that card
- **WHEN** the frame renders there and again in a pane narrow enough that the band cannot carry the pair
- **THEN** the card's line carries the glyph, the id and the title with no agent or phase token in both frames —
  the title is never squeezed by the demoted fields, and the id is never the field that drops

#### Scenario: The demoted pair drops the agent before the phase

- **GIVEN** the same fixture and three pane widths — one where the band's free width fits `agent · phase`, one
  where it fits only the phase, and one where it fits neither
- **WHEN** the board page renders at each width with the card focused
- **THEN** the band carries `agent · phase`, then the phase alone, then neither, while the key chips the band
  documented at that width stay in place (the pair never pushes a chip out)

#### Scenario: Narrow terminals degrade to one grouped column

- **GIVEN** the same fixture
- **WHEN** the board page renders one bounded frame at 99 columns and one at 59 columns
- **THEN** both frames stack the states in a single column in the legend order, and the 59-column frame renders
  one line per card — state glyph, id and title — with no agent or phase field and with the id present

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

#### Scenario: Two rows with one id are two stops

- **GIVEN** a board whose drawn rows are `M39` (title "first duplicate", agent `dev1`), `M39` (title "second
  duplicate", agent `dev2`) and `M48`, and the console on the board page
- **WHEN** the page renders, `↓` is pressed twice, `r` refreshes, then `enter` opens the detail and `esc` returns
- **THEN** exactly one row carries the cursor glyph at every step; the first `↓` stops on the second `M39` row
  (the same id, the next occurrence — not a frozen cursor), the second `↓` reaches `M48`, `↑` twice returns to
  the first `M39` row, and after `r`, `enter` and `esc` the cursor is still on the second `M39` row, with the
  `M39` detail view opened in between

