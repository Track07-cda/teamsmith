## ADDED Requirements

### Requirement: Board labels and priority are optional read-only views

The interactive board SHALL offer a read-only single-label filter and an optional within-lane priority order.
The default is all tasks in the board's existing recent-first order. Only an explicit choice of priority
replaces that order with descending shared score and then original BOARD.md row order. The same label
filter can be used with either order. Display and navigation SHALL address the same matching row identities. Task detail SHALL show label
names and score without replacing file details. Neither labels nor view choices are written by these controls.

#### Scenario: Filtered cards and interactions use one row order

- **GIVEN** a lane with two separately focusable rows sharing an ID and label, another card in between, and
  other cards including a score tie and a label with no matching card anywhere
- **WHEN** the second row is focused and priority is selected, `r` refreshes after a peer's weight is changed,
  and a keyboard or mouse selection applies a filter hiding the originally focused row
- **THEN** the second original occurrence retains focus while eligible, including across detail and back;
  renderer, arrows, mouse, windows and Enter use the same new order; filtering moves focus to the first matching
  card in its prior lane's shown order, or the first matching card of the first lane with matches
- **AND** each lane and its edge counts reflect matches, folded lanes with matches still open the focused matching
  card, and no-match selection gives zero counts, follows the existing empty-fold policy and opens no detail

#### Scenario: A same-ID row outside the task table never inherits labels

- **GIVEN** two task-table rows sharing an ID, its label and score, and a separate table below with a different title
  but the same ID at the same column position and a valid `todo` state
- **WHEN** the board opens in its default view, the three original rows are opened in detail separately, and
  the label filter is then applied
- **THEN** the default still shows all three rows in the normal recent-first view; the two real rows are separate focus stops
  and their details show the shared labels and score; the unrelated row's detail keeps its normal file result
  but no label area; the filter matches only the two real rows, and cannot open the unrelated row
- **AND** when the unrelated row is opened from the work page and a same-ID task is inserted before it, `r`
  refreshes the same open detail without adding any labels, even if its former occurrence now identifies a task
- **AND** detail from either page shows labels on refresh only if its source was a task-table row when opened
  and its current row reference still points into that table; file lookup still uses the original ID

#### Scenario: Explicit priority and default history anchor are different views

- **GIVEN** a board whose done and dropped history exceed the lane windows and whose highest scores are not on its newest rows
- **WHEN** page 4 opens with default choices, then selects priority, then returns to recent-first order
- **THEN** the default and restored order put valid times first, newest first, then the undated history
  rows from the file's tail; the priority windows start at the highest ranks subject to the focused card
- **AND** a label filter retains matching rows in the chosen order; two equal priorities keep original
  BOARD.md row order even when their update times differ; page 2's order, machine exits and board file stay unchanged
- **AND** with no filter, any displayed same-lane non-task rows remain visible but unranked after ranked rows

#### Scenario: Choices are local to the current console session

- **GIVEN** a board with definitions and a client using keyboard, and a second client using mouse in the other locale
- **WHEN** each selects a label and priority, switches page and returns, and then restarts the console
- **THEN** each control displays its current value using zh/en interface strings, the choices survive page changes
  but restart opens all tasks in recent-first order, and no choice is written to panel preferences or project files
- **AND** when no definitions are present and the catalog read has no error, the original board display has no added controls

#### Scenario: The chooser acts on exact names and owns its inputs

- **GIVEN** distinct project labels that differ by case or beyond the chip's displayed width
- **WHEN** plain `t` or `o` on the board opens a choice, the human selects by keyboard or mouse, and later
  uses `Ctrl+o` while composing
- **THEN** the selection matches the full unchanged label value, never its shortened text; arrows, wheel,
  clicks, Enter and Esc in the picker act on the list, not the board behind it; plain `t` and `o` do not open
  these controls elsewhere or over another modal, and `Ctrl+o` still opens the compose editor

#### Scenario: A task with no file still exposes its labels

- **GIVEN** a task with no task brief, report or review and a label with a custom color
- **WHEN** task detail is opened, then only that color is edited through the CLI and the board refreshes
- **THEN** detail opened from either owning page shows the name, updated color and unchanged score separately
  from the existing no-file result, the name remains visible without color, and opening or closing it does not
  change labels or make a filtered-out card reachable
- **AND** a task with files retains its file tabs and Markdown; a task without a label on a board with definitions
  shows no labels and score 0; a board without definitions adds no label row; the labels and score are reachable
  by scrolling, with no write or edit action

#### Scenario: Missing label choices and invalid data do not hide the board

- **GIVEN** a selected label that is renamed through the CLI and a catalog that is later damaged and repaired
- **WHEN** the same running board refreshes after the rename, the damage and the repair
- **THEN** the rename clears only the filter and shows the new name in its choices; the damaged source shows
  the default board with a labels-unavailable notice, all original rows and neither old nor false zero scores
  in detail; the repair restores current names and scores on refresh without restarting the board

#### Scenario: The 59-column card keeps its text

- **GIVEN** the same focused row at 59 columns with and without labels, and no filter or lane-fold change
- **WHEN** both board frames and the labeled task's detail render
- **THEN** both card lines carry the same glyph, ID and title text, both frames fit the width, each choice is
  reachable with keyboard and mouse where applicable, and detail shows name text without changing the card

## MODIFIED Requirements

### Requirement: The board page is a kanban over the board's states

With no label filter, the board page SHALL render every BOARD.md row as a card. An explicit label selection
SHALL limit cards to matching task-table rows. The six state lanes SHALL keep the fixed order the
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
a card truncates its title to keep an agent or a phase. Labels and priority MUST NOT occupy card-line space.
At 100 columns and wider the lanes SHALL be side by side with an even share of the usable width among the lanes
that are not folded (a folded lane's one line takes the width it needs; the lane-fold requirement owns that
share); under 100 columns the page SHALL degrade to a single column grouped by state in the same lane order;
under 60 columns the card keeps its one-line form (state glyph, id, title), the id SHALL NOT be the field that
drops, and the title SHALL truncate last. The focused card SHALL be
marked by a cursor glyph and the `selected` tone — never by color alone — and SHALL be tracked by **row
identity**: the entry id together with the row's occurrence among the rows carrying that id, in BOARD.md order.
In the interactive board page's default order, each lane SHALL show rows with a valid task-table update time first, in descending
time order. Equal times SHALL keep BOARD.md order. Rows without time follow: in `todo`, `wip`, `review` and
`blocked` they keep BOARD.md order; in `done` and `dropped` they run from the file's tail towards its head. The
history lanes' initial windows SHALL start at the head of that display order, not reproduce the old bottom-aligned
offset. With no recorded times the first history window therefore starts with the rows from the old tail, without
ascribing a time to those rows. In a grouped layout this is the order within each lane, not a new page-wide
sort or a separate scroll window per lane. The update time MUST NOT be printed on the card. A label filter
without a priority selection SHALL preserve this order among matching rows. In explicit priority order each
lane SHALL start at its highest ranks, subject to the existing focus and scroll behavior.

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

Filtering and ordering SHALL NOT mutate the source rows, their counts, or the work page's order or history
selection; when a label is selected the board page SHALL show matching counts. The optional row time belongs to the existing internal board block; public `--json` keeps its
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
