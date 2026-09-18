# Propose: `console-board-page` — kanban board page + markdown detail view

## Why

Two user asks, merged into one surface (task P17): "pulse must open an entry's files and render their markdown"
and "the board needs its own page, ideally a kanban". Plus a defect the PM confirmed on a live screenshot
(2026-09-18): the console renders only its natural content height (≈29 rows — the 120x29 design baseline), so the
key band floats mid-frame with blank rows below it and the board area never grows with the pane.

## What Changes

All in `panel` (extended, not a new capability — design.md §1):

- **ADDED**: a fourth page — a kanban over BOARD.md's six states; cards focusable by keyboard and mouse;
  Enter/click opens a detail view.
- **ADDED**: a read-only markdown detail view (task brief, delivery reports, review records) replacing the page's
  blocks, with file tabs and Esc/`q` back.
- **ADDED**: a bounded-frame red line — the footer is the last row and the content area absorbs the spare height;
  the fix covers the three existing pages (one shared assembly, design.md §8).
- **MODIFIED**: three pages become four (keys `1`–`4`, Tab cycle, `state/panel-page`, `defaultPage`).
- **MODIFIED**: the mouse/key map gains `4`, `←`/`→` and Enter on the board page, and the wheel scrolls the
  focused lane there (the one-offset-per-page rule stands on pages 1–3).

## Capabilities

### Modified Capabilities

- `panel`: the four-page composition, the kanban page, the detail view, the footer/height red line, and the
  extended key/mouse map are all the console's own contract.

## Impact

Apply-phase code (not this phase): `skills/teamsmith/scripts/panel/src/**` (new `markdown.ts`; kanban + detail in
`layout.ts`; navigation in `App.tsx`/`main.tsx`), `skills/teamsmith/scripts/lib/cmd-watch.sh` (the `board` reader
gains a `phase` field; a new on-demand `detail` block), `skills/teamsmith/tests/**` (snapshots, smoke sections),
`references/config.md` (`panel-page` range). Zero new runtime dependencies; BOARD.md's format unchanged; no new
write operation (the console stays read-only except through the existing three commands).

## The five answers (brief)

1. **Kanban**: six lanes in BOARD.md legend order, always rendered (an empty lane shows a dim marker); side-by-side
   ≥100 columns, a single state-grouped column <100, one-line cards <60; card = id + agent + phase + title;
   lane-local scroll with hidden-count edge markers.
2. **Navigation**: `1`–`4` and Tab; `←`/`→` between lanes, `↑`/`↓` within a lane, Enter opens; click focuses, a
   click on the focused card opens; focus is a `›` glyph plus the `selected` tone, tracked by entry id across
   refreshes.
3. **Detail**: full-page replacement (title band, tabs and key band stay, as in the settings overlay); discovery =
   `tasks/<ID>-*.md`, `reports/<ID>-*.md` (files only), `reviews/<ID>.md` + `reviews/<ID>-*.md`; a self-written
   markdown subset renderer (no new dependency — the bundle's no-install contract), 128 KiB cap; read-only.
4. **Performance**: the detail block builds only while the view is open (never on the tick path), first frame ≤1s;
   the kanban reuses the existing `board` block; the <1%-of-one-core red line holds; a bounded frame fills the
   pane exactly.
5. **Spec home**: `panel` — ADDED ×4, MODIFIED ×1, REMOVED ×1 (the three-page requirement, a remove-plus-add), every scenario falsifiable, degradation and CPU included.

## The defect flip (the footer fix)

`team monitor --print --width 120 --height 40` on a fixture with ~30 rows of natural content: **before** — the
frame is ~30 rows and the key band sits mid-frame; **after** — exactly 40 rows and the key band is the last one.

## Acceptance (verbatim)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
```

## Boundaries

- This phase writes only `openspec/changes/console-board-page/**` and `docs/team/reports/P17-dev.md`; no code, no
  `openspec/specs/**`, no ledger.
- v1 excludes: the ROADMAP milestone segment in the detail view, editing or acting from the detail view, queue
  discard, and any BOARD.md storage change. The three existing pages' behavior semantics are unchanged apart from
  the footer/height fix.

## Evidence the report must contain

Both acceptance tails; the hand-check of every MODIFIED requirement/scenario heading against
`openspec/specs/panel/spec.md` (the validate hole, D23); the requirement → task coverage map.
