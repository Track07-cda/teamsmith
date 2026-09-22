## ADDED Requirements

### Requirement: The settings view groups the contract by the functional group the command reports, and carries the effect class on the row

The project-settings view's row list SHALL group the contract's keys by the `group` the owning command reports
for each key, and the read's order SHALL be the view's order: a heading opens when the token changes, the
schema's order is kept inside a group, and the headings themselves appear in the order the read reports their
first rows. A heading MUST NOT be a focus target and MUST NOT be a click target. The heading's text SHALL come
from the zh/en tables, looked up by the token (`group_<token>`), so no group word is written into the bundle; a
token with no label SHALL render as the raw token — the same visible fallback the key labels use for a key the
schema does not know — and the string-table gate SHALL assert the tokens the schema's rows carry and the group
labels in both tables match in **both** directions (a token without a label and a label no row uses both fail
it). The bundle MUST NOT carry a key→group table or a group list of its own: a group or a key added to the
command's schema SHALL appear under the reported heading with the committed `panel.js`, and a row the read
reports under a different token SHALL move.

The **effect class** SHALL be carried on the row, not by the grouping: every key row SHALL render its class as a
text badge (`apply`, `restart`, `refuse`, plus the unknown-key badge) with that class's tone, and the tone SHALL
never be the only channel — the panel's "state is never carried by color alone" rule applies here as everywhere.
No group heading SHALL name an effect class or carry a class's tone.

A key whose `group` is empty — a schema row that declares none, or a key the file carries and the schema does
not know — SHALL render under one visible trailing fallback heading, labelled from the tables, after the grouped
keys and before the seats block: it MUST NOT be dropped, merged into a group the command did not report, or
rendered without its own badge and command line. The seats block SHALL keep its own trailing heading, whose label
is distinct from every group heading.

#### Scenario: The headings are functional domains, not effect classes

- **GIVEN** a fixture contract and the view open in a 160-column fixture pane
- **WHEN** the rows render
- **THEN** the headings are the schema's functional labels in the read's order (身份与账本布局 before 工作流与门禁
  before 跨项目会议), no heading reads `立即生效`, `需要重启` or `只读`, the keys of one group render together in
  the schema's order, and a walk down the list stops only on key and seat rows — never on a heading

#### Scenario: A key added to the schema lands in its group, with the committed bundle

- **GIVEN** a scratch copy of the CLI whose schema carries `TEAM_ZZZ_TEST` with the group `workflow` and, in a
  second run, whose `TEAM_GATES` row carries `meeting`
- **WHEN** the committed `panel.js` renders the view against each
- **THEN** the new row appears under 工作流与门禁 in the first run and `TEAM_GATES` appears under 跨项目会议 in the
  second, each in the schema's own order inside its group, while `panel.js` is byte-identical between the runs

#### Scenario: A row without a group renders under the fallback heading

- **GIVEN** a scratch copy of the CLI whose `TEAM_GATES` row declares no group and a contract carrying a key the
  schema does not know
- **WHEN** the view renders
- **THEN** both rows appear under the visible fallback heading after the grouped keys and before the seats block,
  the schema key keeps its label, badge and command line, and the schema-unknown key is still read-only, named by
  its raw key and marked as unknown

#### Scenario: The class is a word on the row and its tone is redundant

- **GIVEN** the view open on a contract holding an `apply` key, a `restart` key and a `refuse` key
- **WHEN** the three rows render
- **THEN** each carries its own badge word, the `restart` badge is drawn in the theme's `warn` tone, the `refuse`
  badge in the theme's `dim` tone and the `apply` badge in the plain text tone, while the values beside them stay
  in the plain text tone
- **AND** a capture with the SGR sequences stripped still shows all three classes as words — colour is never the
  only channel

#### Scenario: The seats block keeps its own heading and no label collides with it

- **GIVEN** a fixture project with a roster and the view open
- **WHEN** the rows render
- **THEN** the seat rows appear under the tables' own seats heading, that heading's text differs from the
  per-seat-model group's heading, and the keys of that group appear under their own functional heading with the
  group's own order

## MODIFIED Requirements

### Requirement: Every key affordance is also a mouse target

With the mouse preference on, the console SHALL enable SGR mouse reporting for its lifetime and disable it on
exit, and every documented key — `m`, `f`, `s`, `,`, Tab, `1`–`4`, `↑`/`↓`, `q`, on the board page `←`/`→` and
Enter, and on the work page the board rows (a click focuses a row, a click on the focused row opens its detail) —
SHALL have a clickable target that acts identically; the wheel SHALL scroll the current page's scrollable region
(one offset per page, one line per notch on pages 1–3 — V15 F5 ruling; on the work page `↑`/`↓` move the board-row
focus and the wheel keeps scrolling the page; on the board page each lane carries its own offset and the wheel
SHALL scroll the lane under the cursor). While the project-settings view is open the wheel is its region and MUST
NOT reach the page the view was opened from: it scrolls the view's row window — one row per notch, the row focus
unchanged, the view's hidden-row counts at both edges following the window — and with either of the view's
pickers open it walks that picker's entries instead; the `↑`/`↓` keys and the view's `↑/↓ 行` target SHALL keep
moving the focus and SHALL push the window so the focused row is inside it. A click on a kanban card SHALL focus it, and a click on the already
focused card SHALL open its detail view. Coordinates are 1:1: a click on a target activates that target (E6 §1.1 measured the full path, with
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
