# P17 report — propose: `console-board-page` (kanban board page + markdown detail view)

**Phase**: propose · **Agent**: dev · **Branch**: `task/P17-propose-pulse-console-board-markdown` (local; not
pushed — local mode) · **Date**: 2026-09-18

## Deliverable

`openspec/changes/console-board-page/` — four artifacts, `openspec status`: **4/4 complete**.

- `proposal.md` — why/what/capabilities/impact, the brief's five answers, the defect flip, acceptance, boundaries.
- `specs/panel/spec.md` — delta: **ADDED ×4, MODIFIED ×1, REMOVED ×1**.
- `design.md` — nine decisions with alternatives, risks, migration.
- `tasks.md` — three apply briefs (B1 footer/height flip → B2 kanban → B3 detail) + requirement→task coverage map.

Commits: `0195609` (proposal + delta specs), `f1cbf09` (design + tasks).

## The brief's five questions → where they are answered

1. **Kanban layout** — design.md §3/§4: six fixed lanes in BOARD.md legend order, empty lanes rendered with a
   dim marker; ≥100 side-by-side, <100 one state-grouped column, <60 one-line cards; card = id+glyph+agent+
   phase+title; lane-local scroll with hidden-count edges; `done`/`dropped` windows anchor on newest.
2. **Navigation/focus** — design.md §2/§5: `1`–`4`+Tab; `←`/`→` lanes, `↑`/`↓` cards, Enter opens; click=focus,
   click-on-focused=open; focus = `›` + `selected` tone, tracked by entry id across refreshes; `state/panel-page`
   accepts 1–4 with out-of-range fallback.
3. **Detail view** — design.md §6/§7: full-page replacement (title band/tabs/key band stay); discovery =
   `tasks/<ID>-*.md`, `reports/<ID>-*.md` (files only), `reviews/<ID>.md`+`reviews/<ID>-*.md`, id boundary
   `.`/`-`; self-written markdown subset (headings/fences/tables/lists/quotes/inline spans; unknown → source
   text); 128 KiB cap; Esc/`q` back without collapsing (the `q` exception is scenario-pinned); read-only.
4. **Performance contract** — design.md §8: the `detail` block builds only while the view is open (never on the
   tick path), first frame ≤1s; kanban reuses the 15s-TTL `board` block + one-pass phase enrichment; <1%-of-one-
   core red line held; frame-signature repaint gating unchanged. CPU and the ≤1s budget are spec scenarios
   (B2 §6.4, B3 §9.4) with `[real]` fixtures + headless siblings.
5. **Spec home** — design.md §1: `panel` extended (pulse-console precedent: the console is one surface; a new
   capability would duplicate the frame/navigation/sanitize/read-only contracts). Every scenario is falsifiable
   (concrete fixtures, commands, row counts, exit codes); degradation (99/59 columns, 60x8 pane) and CPU are
   first-class scenarios, not prose.

## Change-scope statement (brief requirement)

The three existing pages' behavior semantics are unchanged **apart from the footer/height fix**, which the user
added to scope (thread 2026-09-18T06:11+06:12): the shared assembly now fills the bounded height and pins the
key band to the last row — one assembly, no per-page fork (design.md §9). The kanban is a **fourth** page; the
work page's board block stays. Everything is read-only: no new write operation, the three-command rule is
untouched, the detail reader refuses paths outside the discovered set (spec scenario). BOARD.md storage format
unchanged. Both user quotes are copied verbatim into proposal.md §Why.

## The two scope additions (thread)

- **Footer pinned + content absorbs spare height**: ADDED requirement "A bounded frame fills the pane…" with the
  flip scenario (`team monitor --print --width 120 --height 40`: before ≈30 rows key-band mid-frame; after
  exactly 40 rows, key band last). Root cause (renders natural content height, ≈29-row 120x29 baseline) is
  quoted in the requirement text as the forbidden behavior — the red line the PM asked to spec.
- **Old pages included**: the fix lives in the one shared `layout()` assembly, so all pages gain it; tasks B1
  re-pins the eight stored snapshots and adds flip-guard smoke assertions (2.1–2.3), with the uncapped `--print`
  byte-identicality pinned (1.5) so the machine exits don't drift.

## Acceptance gate tails (verbatim, run on tip `f1cbf09`)

```text
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
- Validating...
✓ spec/agent-adapters
✓ spec/board-and-status
✓ spec/boundary
✓ change/console-board-page
✓ spec/delivery-guard
✓ spec/dispatch
✓ spec/init-skill
✓ spec/meeting
✓ spec/memory-and-deps
✓ spec/notify-and-inbox
✓ spec/panel
✓ spec/pm-lifecycle
✓ spec/verification
✓ spec/watchdog
Totals: 14 passed, 0 failed (14 items)
```

```text
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
…
== 15 · 完成 ==
   （全流程已在 0–14 节覆盖）
== 结果 ==  ✓ 1506  ✗ 0
FAST 模式：跳过 19 个真进程段落（…）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿
```

## Hand-check of MODIFIED/REMOVED against `openspec/specs/panel/spec.md` (the D23 validate hole)

Grepped the base spec and compared headings one by one:

- **MODIFIED** `Every key affordance is also a mouse target` (base line 544): heading matches exactly. Base
  scenarios (5) all carried into the delta verbatim — `A click acts like the key`, `The wheel scrolls the page's
  scrollable region` (re-added after validate correctly flagged its omission in my first draft), `Off means
  silent`, `The overlay keeps the visible footer live and the page behind it dead`, `The refresh key is
  deliberately keyboard-only` — plus two new board-page scenarios. The one-offset-per-page wheel rule is kept
  for pages 1–3 with the lane exception scoped to the board page (V15 F5 stands).
- **REMOVED** `The console composes three pages and remembers the position` (base line 392): heading matches
  exactly; REMOVED block carries `**Reason**` + `**Migration**`. All three base scenarios (`Pages switch and the
  position survives a restart`, `An empty block collapses`, `The messages page lists the queue`) are carried
  into the ADDED replacement `The console composes four pages and remembers the position` (the rename is
  remove-plus-add; the delta vocabulary has no rename).
- No ADDED requirement duplicates or shadows an existing base requirement (checked the panel spec's heading
  list: the kanban, detail-view and bounded-frame promises have no existing counterpart).

## Requirement → task coverage map

In `tasks.md` §"Requirement → task coverage map": every delta requirement (4 ADDED + 1 MODIFIED) is covered by
at least one item, and each item names the requirement it moves; `[real]` items all have headless siblings.

## PM checklist self-check (the eight points)

1. `openspec status`: 4/4 complete ✓ · validate output above ✓
2. Delta names match base headings exactly (hand-check above) ✓
3. Design ties choices to the base spec's constraints (bundle contract §Context, sanitize, read-only, V15/V16
   rulings) and lists discarded alternatives per decision ✓
4. Tasks: each has a command that can fail; page-4 layout/scroll/mouse/CPU fixtures included ✓
5. Proposal boundaries: propose-phase writes only the change dir + this report; v1.1 cuts listed ✓
6. English, markdown valid (openspec validate parses it) ✓
7. No conflict with existing specs: the only overlapping promises are the MODIFIED/REMOVED deltas, not parallel
   restatements; the bounded-frame requirement has no existing counterpart ✓
8. Format: proposal/design/tasks/delta specs — four files ✓

## Boundaries honored

Touched only `openspec/changes/console-board-page/**` and this report. No code, no `openspec/specs/**`, no
ledger, no `docs/team/tasks/P17-*` (the PM's read-only brief). Branch is local for PM review (local mode).

## What the PM's proposal review should poke at

- The lane order choice (BOARD.md legend order; workflow order is the open alternative — design.md Open
  Questions).
- The `q`-means-back exception inside the detail view (spec-pinned, but it is a real UX trade-off).
- The 128 KiB detail cap and the six-lane width floor of 100 columns (both arbitrary but falsifiable).
