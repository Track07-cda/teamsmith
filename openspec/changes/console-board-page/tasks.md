# Tasks: `console-board-page`

Three apply briefs, dispatched and verified one by one, in this order (design.md §Migration): **B1** the
bounded-frame assembly fix (footer pinned, content absorbs the height — a defect fix with a flip), **B2** the
kanban board page, **B3** the markdown detail view. Each item names the `panel` requirement it moves and the
command that can fail. `[real]` items need a real tmux pane/pty; each has a headless sibling so no requirement
hangs on a real process alone.

Path grants the apply briefs must state (OWNERSHIP): `skills/teamsmith/scripts/**` (panel sources, bundle,
`cmd-watch.sh`) and `skills/teamsmith/references/config.md` are PM-owned and granted explicitly;
`skills/teamsmith/tests/**` belongs to agent:dev. `openspec/specs/**`, `docs/team/**` and the ledger stay
PM-owned.

## B1 — a bounded frame fills the pane (apply brief 1)

Moves: "A bounded frame fills the pane: the footer is the last row and the content absorbs the spare height".

### 0. The measured "before" (the flip the report must carry)

- [ ] 0.1 Record the red: on a fixture whose overview is ~30 rows of natural content,
  `team monitor --print --width 120 --height 40 | wc -l` prints far less than 40 and
  `team monitor --print --width 120 --height 40 | tail -3` shows the key band mid-frame followed by nothing.
  Verify: both output tails pasted in the batch report.

### 1. The assembly emits exactly the bounded height

- [ ] 1.1 `layout()` fills a bounded frame: the key band is the last row, no all-blank row below it, on every
  page and in every width tier. Verify: `team monitor --print --width 120 --height 40` prints exactly 40 rows
  with the key-band tokens in row 40; the same holds at `--width 99` and `--width 59`.
- [ ] 1.2 Spare height goes to content in the documented order (folded board history first, then the last card's
  blank space). Verify: a `--snapshot --page 2 --width 120 --height 60` frame of a fixture with folded
  done/dropped history shows strictly more board rows than the `--height 40` frame, and both end on the key band.
- [ ] 1.3 The single-column tiers gain the same growth (today's flush-bottom rule is two-column only).
  Verify: `team monitor --print --width 99 --height 50` ends on the key band at row 50.
- [ ] 1.4 Compose ordering is unchanged: while composing in a tall pane, the key band sits directly above the
  hint/input lines and the input stays the last rendered row (V15/F1's IME cursor rule). Verify `[real]`: the
  CJK cursor fixture (`cursor_x = 8` after `中文ab`) stays green in a 120x45 pane; headless sibling: the frame
  row count with a compose open equals `height`.
- [ ] 1.5 The uncapped machine frame gains nothing. Verify: `team monitor --print` without `--height` is
  byte-identical to the pre-change output apart from the timestamp (diff against the recorded 0.1 baseline).

### 2. Pins and the flip guard

- [ ] 2.1 Re-pin the eight stored snapshots (`tests/snapshots/`) — the only intended diff is the footer's
  position and the growth rows. Verify: `bash skills/teamsmith/tests/panel-snapshots.sh` exits 0 and the report
  pastes `git diff --stat tests/snapshots/`.
- [ ] 2.2 New smoke assertions: bounded frame ⇒ key band last + exact row count (120x40, 99x50, 59x12); tiny
  60x8 pane ⇒ key band is the last non-empty row. Verify: `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh`
  tail in the report.
- [ ] 2.3 Flip guard: revert the assembly change on a scratch checkout → the 2.2 assertions fail; restore →
  green. Verify: both runs' tails in the report.
- [ ] 2.4 Steady-state CPU still under the red line. Verify `[real]`: `bash skills/teamsmith/tests/panel-cpu.sh`
  log in the report shows <1% of one core.

## B2 — the kanban board page (apply brief 2)

Moves: "The board page is a kanban over the board's states", "The console composes four pages and remembers the
position", and the board-page clauses of "Every key affordance is also a mouse target". Depends on B1 (the page
is laid out by the fixed assembly).

### 3. The data: phase enrichment of the board block

- [ ] 3.1 `team_panel_board_json` rows gain a `phase` field from the task brief's `phase:` header, parsed in one
  pass over `docs/team/tasks/*.md` (design.md §3). Verify: a fixture with `tasks/M9-x.md` (`phase: apply`) makes
  `team __panel-data --block board` emit `"phase": "apply"` for M9 and `"-"` for a row with no brief.

### 4. Navigation: the fourth page

- [ ] 4.1 `PageId` → `1|2|3|4`; keys `1`–`4` and the Tab cycle; `--page 4`; the settings `defaultPage` cycles
  over four. Verify: `panel.js --snapshot --page 4 --width 160 --height 40 --root <fixture>` renders the lanes.
- [ ] 4.2 `state/panel-page` persists and restores page 4; an out-of-range value falls back to the default page.
  Verify `[real]`: send `4`, quit, relaunch → the board page; write `9` into the file, relaunch → page 1. Sibling:
  the readPage unit fixture.

### 5. The kanban layout

- [ ] 5.1 Six lanes in BOARD.md legend order, always rendered (empty lane = dim marker), even width share ≥100
  columns; card = id + glyph + agent + phase + truncated title. Verify: snapshot assertions on the 160- and
  120-column frames (six headers in order; `blocked` lane marker; the M9 card carries `apply`).
- [ ] 5.2 Degradation: <100 one state-grouped column, <60 one-line cards (glyph, id, title). Verify: the 99- and
  59-column snapshots (page 4 added to the four-widths × two-themes matrix).
- [ ] 5.3 Focus: `›` + `selected` tone, tracked by entry id; a vanished entry lands the focus on the lane's first
  card. Verify `[real]`: pty fixture reorders then removes the focused entry across two refreshes. Sibling: a
  headless frame with the focus flag/stub renders the `›` on the named card.
- [ ] 5.4 Lane scroll: `↑`/`↓` past the edge scrolls the lane's window; edges that hide cards show their count;
  `done`/`dropped` windows anchor on the newest cards. Verify: fixture with 20 done cards — first frame shows the
  newest six + the hidden count; pty `↓` past the edge scrolls.

### 6. Mouse on the board page

- [ ] 6.1 Click = focus, click on the focused card = open (the open target exists only on the focused card).
  Verify `[real]`: the pty mouse fixture (panel-b3-pty-tmux-mouse.py's shape). Sibling: the `--targets` map of a
  page-4 frame carries card hits.
- [ ] 6.2 The wheel scrolls the lane under the cursor; other lanes and the focus stay put. Verify `[real]`:
  wheel fixture over a 20-card lane; sibling: pages 1–3's one-offset-per-page assertions stay green (no
  regression of V15 F5).
- [ ] 6.3 String tables: zh/en gain the page-4 names, lane labels, focus/scroll hints; the key-set assertion
  runs in the gate. Verify: `node skills/teamsmith/tests/panel-strings.mjs` exits 0; deleting one key fails it.
- [ ] 6.4 CPU red line parked on page 4. Verify `[real]`: `panel-cpu.sh` sampling with page 4 open stays <1%.

## B3 — the markdown detail view (apply brief 3)

Moves: "A focused card opens a read-only markdown detail view" and the detail-view clauses of "Every key
affordance is also a mouse target". Depends on B2 (the focused card is the entry point).

### 7. The `detail` block reader

- [ ] 7.1 `team __panel-data --block detail --id <ID>` discovers `tasks/<ID>-*.md`, `reports/<ID>-*.md` (files
  only), `reviews/<ID>.md` and `reviews/<ID>-*.md`, with the `<ID>` boundary (`P1` ≠ `P17`). Verify: the P1
  fixture (brief + report + two reviews + a P17 decoy) returns exactly four entries and never the decoy.
- [ ] 7.2 `--file` serves only a discovered path. Verify: `--file ../../BOARD.md` and
  `--file docs/team/tasks/P17-b.md` both exit non-zero and print no file content.
- [ ] 7.3 Bounded read: files over 128 KiB are cut with a truncation marker. Verify: a 200 KiB fixture report
  returns `truncated: true` and the reader exits 0 in under one second (`time` tail in the report).

### 8. The renderer (`markdown.ts`)

- [ ] 8.1 The subset: ATX headings, fenced code (verbatim, dim), pipe tables (display-width aligned), lists,
  blockquotes, bold/code/link spans, `---` rules; anything else renders as source text. Verify: headless render
  fixtures per element — the table's columns align, the fence body is verbatim, an unknown construct appears
  unmodified, and no input throws.
- [ ] 8.2 Hostile bytes: a fence embedding `ESC [2J` renders clean. Verify `[real]`: pane capture of the open
  detail holds no `0x1b` byte and shows the fence's visible text; sibling: the sanitized reader output contains
  no `0x1b`.

### 9. The view

- [ ] 9.1 Open/close: Enter on the focused card opens; Esc and `q` return without collapsing the console (the
  documented exception). Verify `[real]`: pty fixture — after `q` the capture is the board page and the window's
  process is still the renderer; same after Esc.
- [ ] 9.2 Tabs: `←`/`→` and clicks switch files; `↑`/`↓` and the wheel scroll the document. Verify `[real]`:
  pty fixture over the P1 four-file fixture; sibling: the `--targets` map of a detail frame carries tab hits and
  no card hits (the replaced blocks are dead — V16 F-V16-4's rule).
- [ ] 9.3 Read-only proof: hashes of `state/` and `docs/` recorded before/after a session of every navigation
  key in the detail view. Verify: only the console's own three files may differ.
- [ ] 9.4 Performance: the first detail frame renders within one second of Enter on the reference checkout, and
  the `detail` block is absent from the wanted set while the view is closed (idle cost unchanged). Verify: the
  timing log in the report + a spawn-log fixture showing no `detail` child on a parked page 4.
- [ ] 9.5 Snapshot pins for the detail view (one fixture document, 120 and 59 columns, both themes).
  Verify: `panel-snapshots.sh` exits 0.

### 10. Gates (every batch, and finally)

- [ ] 10.1 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` green.
- [ ] 10.2 `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh` green; full (non-fast) run before the change
  leaves review.
- [ ] 10.3 `references/config.md`: `state/panel-page`'s range (1–4) and the `detail` block documented (PM-owned;
  the apply brief states the grant).

## Requirement → task coverage map

| Requirement (panel delta) | Items |
|---|---|
| A bounded frame fills the pane (ADDED) | 0.1, 1.1–1.5, 2.1–2.4 |
| The console composes four pages (ADDED; replaces the three-page REMOVED) | 4.1, 4.2 (+5.1 for the page's presence) |
| The board page is a kanban over the board's states (ADDED) | 3.1, 5.1–5.4, 6.3, 6.4 |
| A focused card opens a read-only markdown detail view (ADDED) | 7.1–7.3, 8.1, 8.2, 9.1–9.5 |
| Every key affordance is also a mouse target (MODIFIED) | 6.1, 6.2, 9.2 |

## v1.1 (plain bullets, not tasks — the pulse-console convention)

- The ROADMAP milestone segment as a fourth file family in the detail view.
- Report-package directories (`reports/<ID>-<agent>/pkg/`) as browsable entries.
- Syntax highlighting in fenced code blocks.
- A workflow-intuition lane order (if the review prefers it over the BOARD.md legend order).
