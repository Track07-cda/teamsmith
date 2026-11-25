## MODIFIED Requirements

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
In the interactive board page, each lane SHALL show rows with a valid task-table update time first, in descending
time order. Equal times SHALL keep BOARD.md order. Rows without time follow: in `todo`, `wip`, `review` and
`blocked` they keep BOARD.md order; in `done` and `dropped` they run from the file's tail towards its head. The
history lanes' initial windows SHALL start at the head of that display order, not reproduce the old bottom-aligned
offset. With no recorded times the first history window therefore starts with the rows from the old tail, without
ascribing a time to those rows. In a grouped layout this is the order within each lane, not a new page-wide
sort or a separate scroll window per lane. The update time MUST NOT be printed on the card.

Rendering, the visible window, arrow navigation and pointer targets SHALL agree on that order at both layout widths.
Clicking an unfocused card SHALL focus its original row; clicking a focused card SHALL open that frame's row,
not a position reinterpreted after sorting. Enter SHALL open the selected original row. A refresh that changes
the display order or the row's state SHALL keep addressing the same original row while its identity is still
available. Two rows with one id remain separate stops with the cursor on exactly one; the occurrence is counted
before sorting, not in the lane. The identity does not distinguish identical ids that a manual edit exchanges
or inserts before an existing occurrence. When the focused occurrence is no longer addressable, the first row
carrying its id SHALL take the focus; when none carries it, the old lane's first displayed card SHALL take the
focus, or the first card of the first nonempty lane if that lane emptied. A lane holding more cards than its
window SHALL scroll (`↑`/`↓` past the edge, and the wheel over the lane) and SHALL mark each edge that hides cards
with its count. In the side-by-side layout, the wheel MAY deliberately scroll a lane away from its selection as
before. Reordering SHALL adjust a window only when it would move a previously visible selection out of view,
without resetting unrelated windows or undoing that deliberate scroll. The narrow grouped layout SHALL keep
one page window and continue keeping its focused row in that window when scrolling and navigating. Folding,
detail discovery and work-page actions keep their existing contracts.

The display order SHALL NOT mutate the source rows, their counts, or the work page's order or history
selection. The optional row time belongs to the existing internal board block; public `--json` keeps its
existing output shape and `--print` keeps its existing order and window even when given page 4.

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

- **GIVEN** a fixture whose board does not fit in one page window and contains a lane with timed rows
- **WHEN** the board page renders at 99 and at 59 columns and arrow navigation moves past the window edge
- **THEN** both widths stack the states in the legend order with the same within-lane order as in the wider
  layout; the single window follows the selected row, and at 59 columns the card remains one line with
  state glyph, id and title, without agent or phase

#### Scenario: The focus survives a refresh

- **GIVEN** `M9` was added before `M8` with distinct times, the two tasks are in one lane, and the console
  shows `M8` above the selected `M9`
- **WHEN** `M9` actually changes agent later, the board page refreshes, a still later operation repeats
  `M8`'s current agent, and the page refreshes again
- **THEN** `M9` moves above `M8` in both grouped and side-by-side layouts, stays selected as the same row,
  and the repeated operation changes neither `M8`'s time nor the displayed order
- **AND** moving from `M9` to `M8` with `↓` and pressing Enter opens `M8`'s file; after returning, focusing
  and opening `M9` by its drawn card opens `M9`'s distinct file
- **AND** when the selected id later leaves the board, the same lane's first displayed card receives focus

#### Scenario: A long lane scrolls and counts what it hides

- **GIVEN** a side-by-side board with `done` and `dropped` lanes that each exceed their visible window,
  each containing two rows with distinct times in the opposite file order and several rows with no valid time
- **WHEN** the board page first renders, and the focus then moves down past the window's edge
- **THEN** each history lane's first window starts with its two timed rows, newest first, followed by
  the undated rows from the file's tail, with an edge count for what is hidden below
- **AND** the window scrolls with the focus, and wheel-down over an unfolded history lane exposes
  previously hidden older rows without changing the selected row

#### Scenario: Two rows with one id are two stops

- **GIVEN** two `M39` rows in one active lane with different titles and equal valid times in a task table,
  followed by an undated `M48` and a row with an invalid time
- **WHEN** the page renders, the user moves from the first `M39` row to the second, and an agent assignment
  really changes only that selected row before a refresh
- **THEN** the two `M39` rows were distinct stops in file order and the undated rows follow them in file
  order; after refresh the second `M39` moves above the first and is still the only row with the cursor
- **AND** `↓` can reach the first `M39` and continue to `M48`; pressing Enter on the second `M39` and
  returning keeps that row selected by its title even though the detail files are shared by id
