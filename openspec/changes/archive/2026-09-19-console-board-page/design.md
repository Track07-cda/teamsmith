# Design: `console-board-page` — kanban board page + markdown detail view

## Context

The console (`skills/teamsmith/scripts/panel/`, spec `openspec/specs/panel/spec.md`) composes three pages plus a
settings overlay over a pure `layout(width, height, data, view)` function; data arrives as async per-block
children (`team __panel-data --block <name>`, TTL-cached in `data.ts`), and every disk string passes
`sanitizeDeep` before layout. The board already reaches the console as the `board` block (`rows[]` with
id/title/agent/branch/deps/state, plus counts and deliveries), at a 15s TTL.

Two hard constraints shape everything below:

- **The root-caused screen-use defect** (PM screenshot, 2026-09-18): `layout()` emits only the rows the content
  needs and App pads *below* the frame, so the key band floats mid-frame and spare pane height is wasted. The
  fix is spec-pinned ("A bounded frame fills the pane…") and applies to all pages — one shared assembly, no fork.
- **The bundle contract** ("The panel ships as one committed bundle with no install step"): no new runtime
  dependency may enter `panel.js`; the rebuild stays byte-identical.

## Goals / Non-Goals

**Goals:**

- A fourth page: a kanban over BOARD.md's six states, focusable and scrollable, mouse included.
- A read-only markdown detail view for a board entry's files (brief / reports / reviews).
- The footer pinned to the bounded frame's last row, with the content area absorbing spare height — on all four
  pages and in the detail view.
- The performance contract intact: <1% of one core idle, uncached frame ≤2s, detail first frame ≤1s.

**Non-Goals (v1):**

- The ROADMAP milestone segment in the detail view (no machine-readable section boundary; plain `[v1.1]`
  follow-up).
- Report-package *directories* (`reports/<ID>-<agent>/pkg/**`): discovery lists files only.
- Editing, queue discard, or any new write action from the console; BOARD.md's storage format.
- Syntax highlighting inside code fences; full CommonMark conformance.
- Double-click detection (SGR mouse gives press/release only; the open gesture is click-on-focused-card).

## Decisions

### 1. `panel` extended, no new capability

Same ruling as pulse-console: the kanban and the detail view are what `team monitor` renders, governed by the
same frame, navigation, sanitize and read-only contracts; a separate capability would duplicate them. The delta
is ADDED ×4, MODIFIED ×1 (the mouse/key map), REMOVED ×1 (the three-page requirement — a rename is
remove-plus-add; the delta vocabulary has no rename).

### 2. Page 4, and the navigation extends rather than moves

`PageId` becomes `1|2|3|4`; keys `1`–`4` and the Tab cycle extend; `state/panel-page` accepts `1`–`4` with
out-of-range → default fallback; the settings `defaultPage` pref cycles over four. The board page is *added* —
the work page's board block stays (it is the "is there work" glance; the kanban is the working surface).
Alternative considered: replacing the work page's board block with the kanban — rejected, it would silently
change an existing page's semantics (the brief forbids that).

### 3. Lane model: six fixed lanes in BOARD.md legend order, always rendered

Lanes = `todo, wip, review, done, blocked, dropped`, the order BOARD.md's own header legend declares — the file
is the contract, and a fixed order keeps mouse/keyboard positions stable across frames. Empty lanes render with
a dim `·` marker: hiding them would move the other lanes and break muscle memory (and click maps).
`done`/`dropped` are history lanes: they hold every card (no folding on this page — the fold stays on page 2's
block) and their windows anchor on the *newest* cards.

Card = id + state glyph + agent + phase token + title (truncated to lane width). The phase comes from the task
brief's `phase:` header, parsed by the `board` reader in **one pass** (`awk` over `docs/team/tasks/*.md`
extracting `task:`/`phase:` pairs — not one fork per row; 73 rows on the reference board). Missing brief or
missing header → `-`. This adds a field to the console-only `board` block — additive, and the machine exits
never carry blocks, so the `--json` contract is untouched.

### 4. Degradation follows the existing tier vocabulary

- ≥100 columns: six lanes side by side, even share of the usable width (≈18 cols/lane at 120).
- <100: one column, states as section headers with their cards under them (the same lane order), one scroll
  window for the page.
- <60 (minimal): the same single column, but a card is one line — glyph, id, title.

The four-widths × two-themes snapshot suite gains page-4 pins, so these shapes are gate-checked, not prose.

### 5. Focus is keyed by entry id, and the open gesture is explicit

Focus state = `{lane, id}`. A refresh rebuilds rows from disk; keying by id means a reordered board cannot move
the marker onto a different entry (scenario-pinned). A vanished entry lands the focus on the lane's first card.
Focus affordance = `›` cursor + `selected` tone — never color alone (the existing contrast requirement's spirit,
extended to focus).

Keys on page 4: `←`/`→` move lanes, `↑`/`↓` move within the lane (scrolling its window at the edge), Enter
opens the detail. Mouse: click = focus; click on the already focused card = open; the wheel scrolls the lane
under the cursor — the board page is the one place a focused block exists, so the wheel rule gets a scoped
exception (pages 1–3 keep V15 F5's one-offset-per-page). Alternative considered: double-click to open —
rejected, SGR mouse has no double-click event and a timer is untestable flakiness.

### 6. The detail view is a full-page replacement, not a floating overlay

It replaces the page's blocks and keeps the title band, the page tabs and the key band — exactly the settings
overlay's shape (V16 F-V16-4's live-footer rule is reused verbatim in the delta). A floating overlay would need
a second layout layer inside the pure function for no gain: terminal markdown wants full width. Alternative
considered: reuse the messages page's in-block full-text view — rejected, that shape caps at one small block and
cannot hold a 50 KB brief.

Discovery (read-only, by entry id; the character after `<ID>` must be `.` or `-`, so `P1` never matches `P17`):

- `docs/team/tasks/<ID>-*.md` → tab `brief`
- `docs/team/reports/<ID>-*.md` (files only) → tab `report[:<agent>]`
- `docs/team/reviews/<ID>.md`, `docs/team/reviews/<ID>-*.md` → tab `review[:<suffix>]`

Tabs switch with `←`/`→` or a click; `↑`/`↓` and the wheel scroll the document; Esc or `q` returns (the `q`
exception is scenario-pinned: while the detail is open, `q` backs out instead of collapsing — the brief asks for
it, and the collapse stays one key away on the kanban itself). Read-only: no action keys, and the read-only
discipline requirement ("three commands") is untouched.

### 7. Markdown: a narrow self-written renderer, no new dependency

`src/markdown.ts`: `markdownToLines(source, width) → PlacedLine[]`, pure and snapshot-testable. Subset: ATX
headings (heading tone), fenced code blocks (verbatim, dim — no highlighting), pipe tables (display-width
aligned through the same `cell()` the agents table uses — the board family files are table-heavy, and a
misaligned table is the top readability complaint), bullet/numbered lists, blockquotes, `**bold**` / `` `code` ``
/ links (`text (url)`) as tone spans, `---` rules. Anything outside the subset renders as its source text —
never dropped, never an error. Alternatives: `marked`+`marked-terminal` (two new pinned dependencies and a
chalk-styled output that fights the panel's tone system — breaks the bundle's spirit and rebuild review),
Ink-community markdown components (none fit the segment/tone model). The fidelity target is *readable
structure*, stated in the spec; CommonMark conformance is a non-goal.

### 8. Data path: an on-demand `detail` block, off the tick path

New console-only block: `team __panel-data --block detail --id <ID> [--file <path>]`. Without `--file` it
returns the discovered file list plus the first file's text; with `--file` it returns that file's text — and
refuses (non-zero, no content) any path outside the discovered set, so the console never becomes an arbitrary
file reader. Text is bounded at 128 KiB with a `truncated` marker. JS side: the cache gains `detail` in its
wanted-blocks only while the view is open (a `setDetail(id|null)` on the api, the same shape as `setActivity`),
so idle cost is exactly unchanged; `refreshNow` after open forces the first build; rendering runs through
`sanitizeDeep` like every block. The markdown→rows conversion is layout-side and memoized by content key, so a
tab switch repaints only changed rows (`stableRows`). First frame ≤1s on the reference checkout — the reader is
one bounded `cat`; the budget is generous.

### 9. Footer pinning: the assembly emits exactly the bounded height

`layout()` currently *caps* at `height` but emits natural content height; App pads below the frame, stranding
the key band. The fix is in the one shared assembly: with `height > 0`, layout emits exactly `height` rows, the
key band is the last one, and the spare is spent inside the content area in the documented order — board folded
history first (the existing `boardDoneKeep` relax), then kanban lanes' extra cards / detail document rows, then
the last card's blank content space (the existing flush-bottom rule, extended from two-column pages to the
single-column tiers). App's `pad` disappears (it becomes 0 by construction); while composing, the key band sits
directly above the hint/input lines, which stay last for the IME cursor (V15/F1 untouched). The uncapped
`--print` path is explicitly excluded — no filler rows, byte-identical output apart from the timestamp
(scenario-pinned). This is a defect fix with a flip: §"The defect flip" in proposal.md.

## Risks / Trade-offs

- [Six lanes at 100–119 columns are ≈15 columns wide] → accepted: cards truncate to id + short title there, and
  the <100 grouped form is one resize away; the snapshot pins make the shape reviewable.
- [The markdown subset will mis-render some construct someone paste into a brief] → the fallback is source text,
  never an error; the subset is enumerated in the spec so the verify phase can attack each element.
- [The `q` exception inside the detail view could confuse a user who expects collapse] → the detail view's hint
  line names Esc/`q` as "back"; the collapse remains available from the kanban; scenario-pinned so it cannot
  silently regress.
- [Phase enrichment reads `docs/team/tasks/*.md` every board TTL] → one `awk` pass, bounded by the task count
  (~80 files), inside a block that already parses the whole BOARD.md; the 15s TTL keeps it off the red line.
- [Re-pinning the existing 8 snapshots is a one-time diff flood] → the apply report pastes the before/after
  tails; the only intended change is the footer's position and the growth rows.

## Migration Plan

Additive change on one branch, three apply briefs (tasks.md): B1 the assembly fix (defect flip), B2 the kanban
page, B3 the detail view. Rollback = revert the branch; no state-file format changes (`panel-page` gains one
allowed value; old values unchanged).

## Open Questions

None that change scope. (Whether the lane order should follow workflow intuition instead of the BOARD.md legend
is a review-time call — the spec pins legend order and flipping it is a one-line change plus snapshots.)
