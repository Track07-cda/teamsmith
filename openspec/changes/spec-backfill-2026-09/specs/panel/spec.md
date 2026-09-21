# panel delta · 2026-09 回填：focus is a row identity, not a bare entry id (M48)

## MODIFIED Requirements

### Requirement: The board page is a kanban over the board's states

The board page SHALL render every BOARD.md row as a card in one of six state lanes, in the fixed order the
BOARD.md header legend declares (`todo`, `wip`, `review`, `done`, `blocked`, `dropped`). Every lane SHALL render
even when it holds no card — an empty lane shows a dim empty marker — so lanes never shift position between
frames. A card SHALL carry the entry's id, title, agent, state glyph and the phase token from its task brief's
`phase:` header (an entry with no brief or no `phase:` line renders a placeholder), truncated to the lane width.
At 100 columns and wider the lanes SHALL be side by side with an even share of the usable width; under 100
columns the page SHALL degrade to a single column grouped by state in the same lane order; under 60 columns a
card SHALL shrink to one line (state glyph, id, title — the agent and phase drop). The focused card SHALL be
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

#### Scenario: Two rows with one id are two stops

- **GIVEN** a board whose drawn rows are `M39` (title "first duplicate", agent `dev1`), `M39` (title "second
  duplicate", agent `dev2`) and `M48`, and the console on the board page
- **WHEN** the page renders, `↓` is pressed twice, `r` refreshes, then `enter` opens the detail and `esc` returns
- **THEN** exactly one row carries the cursor glyph at every step; the first `↓` stops on the second `M39` row
  (the same id, the next occurrence — not a frozen cursor), the second `↓` reaches `M48`, `↑` twice returns to
  the first `M39` row, and after `r`, `enter` and `esc` the cursor is still on the second `M39` row, with the
  `M39` detail view opened in between

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

- **GIVEN** a fixture project whose BOARD.md has no rows, the console on the work page in a 120x30 pane, and then a
  second fixture with rows in a 60x10 pane where the block degrades to its summary line
- **WHEN** `↓` and `enter` are pressed in each
- **THEN** neither capture carries a focus cursor and no detail view opens, and each frame's click-target map holds
  no `focus` and no `open-focused` action on the work page

#### Scenario: Duplicate rows are two stops on the work page too

- **GIVEN** a board whose rows are `M39` (first duplicate), `M39` (second duplicate) and `M48`, and the console on
  the work page
- **WHEN** the page renders and `↓` is pressed past the two same-id rows
- **THEN** exactly one row carries the cursor at each step, both `M39` rows are separate stops that the walk
  reaches in drawn order (the second does not restart or freeze on the first), and the next press reaches `M48`
