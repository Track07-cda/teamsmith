# Tasks: `one-line-draft-judgement`

Planning only — nothing in this file is executed by the propose task (P63). **One apply brief** (three verifiable
batches, landed in order) plus **one independent verify brief** (a different agent). The change touches two
capabilities: `delivery-guard` (one MODIFIED requirement: the border-adjacent row's judgement and the single
implementation of the extraction) and `notify-and-inbox` (one MODIFIED requirement: the one-line draft queues).

Coverage map (requirement → items): **delivery-guard#An automated send never types into a non-empty input box** →
1.1–1.4, 2.1–2.5, 3.1–3.3; **notify-and-inbox#Messages to a stopped agent fall back to the inbox** → 1.3, 3.1–3.3.
Every item names the capability it moves; no item is an orphan.

Batches: **B1** — the judgement and the production path (`delivery-guard`, 1.x), observable in pure-function probes
and on a fixture pane; **B2** — the fixture/gate side shares the one call and the real frames are stored
(`delivery-guard`, 2.x); **B3** — the delivery-path consequence, the docs and the gates (`notify-and-inbox` +
report, 3.x). B2 needs B1; B3 needs both.

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/tests/**` (incl. `tests/frames/**`) is
`agent:dev`'s; `skills/teamsmith/scripts/lib/outbox.sh` and `skills/teamsmith/references/troubleshooting.md` are
PM-owned and need the brief's explicit grant. Everything else under `skills/teamsmith/scripts/**`,
`extension/**`, `panel/**`, the other specs (`verification` included) and `openspec/**` is **not** touched.

Fixture notes that must survive the change: every synthetic box in the tree draws its status row as
` fake-pi 1.0` (`tests/fake-tui.py`'s `draw()`, `smoke.sh`'s M45 `m45_frame`/adversarial/no-banner frames and its
M59 control frames, `flip-m45.sh`'s adversarial frame). The new rule reads that row as **content** (measured: the
empty-box fixtures would read `fake-pi1.0` instead of empty), so those fixtures MUST be given the measured shape
(` fake-pi  Fake Pi  max` or equivalent) or the 0.87.0 box shape — then every existing assertion keeps passing for
a *shape* reason. One expected string grows: `draft-top.txt` locates its box as `[1 5]`, so its border-adjacent
row is ` Changelog: https://x` and becomes content; its expected string becomes the full value (design §4). **No
existing assertion may be dropped, weakened or re-worded.** `flip-m45.sh`'s cross-tree probe keeps its own
extractor (it must read a pre-fix tree) and is the one documented exception to the one-implementation rule.

## 1. B1 — the judgement, in one place (`delivery-guard` MODIFIED)

- [ ] 1.1 `scripts/lib/outbox.sh`: add the pure `_team_box_text_of_frame <cy>` (stdin = captured frame) beside
  `_team_box_rows_of_frame`, and route `team_input_box_text <target>` through it (capture + `#{cursor_y}`, 1-based);
  the row filter is the new rule: empty → not content, cursor row → content, border-adjacent row matching the
  status-row shape → chrome, everything else → content. Verify: `bash -n` on the file; a pure probe over the stored
  frames prints `HUMAN-ONE-LINE-DRAFT` for `tests/frames/pi-0.87.0-one-line-draft.txt` (once 2.3 has stored it; use
  the P61 log until then) and an empty string for `tests/frames/pi-0.85.1-update-banner.txt`.
- [ ] 1.2 `scripts/lib/outbox.sh`: the border-adjacent row's decision is **one separate overridable function**
  (`_team_box_row_is_chrome <cy> <row> <text>`: the cursor row → false, the measured shape → true, otherwise
  false) whose only positive shape is the measured one (one leading space, model token, two spaces, provider
  display name, two spaces, a thinking level from `off minimal low medium high xhigh max`). Verify (pure):
  ` deepseek-flash  Deepseek  max` and ` k3  Kimi Coding  max` → chrome; `half a sentence`,
  `HUMAN-ONE-LINE-DRAFT`, ` fake-pi 1.0`, `max`, a whitespace-only row and a full-rule row → content; shadowing
  the function to `return 0` reproduces the legacy slot exclusion (the red side used in 2.4).
- [ ] 1.3 Production path (`delivery-guard` + `notify-and-inbox`): on a fixture pane (fake TUI at the 0.87.0 box
  shape, or a frame-replay `M24_PI_BIN`) whose box holds one line with the cursor on it,
  `team_input_box_state`/`team_delivery_verdict` report `BUSY`/not-`EMPTY`, `team_box_holds_only <target> <that
  line>` is true and with a foreign payload false, and `team say dev …` / `team draft send` send **no key**: the
  box still holds exactly that line, the output says `queued`, and `state/outbox/` holds one entry. Verify: run the
  three commands and paste the tails plus the submit log's zero-entry count.
- [ ] 1.4 Regression: `skills/teamsmith/tests/guard-matrix.sh` stays green **without edits** (its status rows are
  already real-shaped), and no existing box shape's verdict changes (`empty` → `EMPTY`, multi-line draft → `BUSY`,
  folded placeholder → `holds_only`). Verify: `bash skills/teamsmith/tests/guard-matrix.sh` tail.

## 2. B2 — one extraction for the fixture and the gate (`delivery-guard` MODIFIED)

- [ ] 2.1 `tests/lib/box-judge.sh`: `team_box_frame_verdict` calls `_team_box_text_of_frame` instead of its inline
  `awk '$1+0 != 1'`; `team_box_overlay_kind` and the overlay precedence are untouched. Verify: the frame mode of
  `pm-box-real.sh --frame … --cursor 26` over the stored frames prints the same verdicts as 1.1's probe.
- [ ] 2.2 `tests/smoke.sh` (§12b-h0b) and any other frame probe call the shared function; `tests/fake-tui.py`'s
  `draw()` and the synthetic frames listed in the fixture note get real-shaped status rows; **no existing
  assertion changes except `draft-top.txt`'s expected `box_nows` string, which grows by the ` Changelog: …` row its
  frame really contains**. Verify: `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` stays green
  and §12b-h0b's `box_nows=[]`/`box_nows=[半句草稿halfasentence]` lines are unchanged; the non-FAST 12b-h box
  section (fake TUI) stays green too.
- [ ] 2.3 Store the real frames byte-identically (`cmp`) from `docs/team/reports/P61-dev3/logs/`:
  `tests/frames/pi-0.87.0-one-line-draft.txt` (`15b-one-line-draft-frame.log`),
  `tests/frames/pi-0.87.0-draft-half-sentence.txt` (`10c-real-draft-box.log`),
  `tests/frames/pi-0.87.0-empty-box.txt` (`10c-real-empty-box.log`), each with a `tests/frames/README.md` row
  naming Pi 0.87.0, the pane geometry, cursor row 26, the source log and the P61 provenance. Verify: `cmp` for each
  file and `grep` for the three README rows.
- [ ] 2.4 A new FAST section (beside §12b-h0b) with the probe over the stored frames plus the 0.85.1 frame:
  one-line-draft frames → `idle-read=NOT-EMPTY` and the draft text; 0.87.0 empty and 0.85.1 → `idle-read=EMPTY`
  and empty text; the **same frame through the production extraction and through `pm-box-real.sh --frame`** prints
  identical text/verdict; with the predicate shadowed to "always chrome" in the probe process the draft frames
  flip back to `EMPTY` while the 0.85.1 frame stays `EMPTY`. Verify: run the section and paste both directions.
- [ ] 2.5 Two more scenarios as stored frames: (a) the cursor resting on a status-row-shaped border-adjacent row is
  content (`BUSY`); (b) the 0.87.0 V7-F1 shape (blank cursor row above a single text row at the border-adjacent
  row) is content (`BUSY`) — synthesized frames are acceptable here and the section says which are synthetic;
  (c) the 0.87.0 multi-line draft control (live capture stored, or synthetic if capture is not reproducible) reads
  `BUSY` under both the new and the shadowed predicate. Verify: the section's lines for these three frames.

## 3. B3 — the delivery-path consequence, the docs, the gates (`notify-and-inbox` MODIFIED)

- [ ] 3.1 `tests/pm-box-real.sh`'s readiness gate must refuse the one-line-draft pane: run the fixture against a
  frame-replay `M24_PI_BIN` that draws `pi-0.87.0-one-line-draft.txt` and assert `rc≠0`, the last-state line names
  `idle-read=NOT-EMPTY`, the last frame is printed, no `deliver_text_lines=` appears and the keylog has zero lines
  (before the fix the same run is P61's `15d`: `rc=0`, `M45 idle-read=EMPTY ok`, one keylog line). This case needs
  a real tmux pane → it belongs in the non-FAST box section, never as the only evidence for the requirement.
  Verify: the run's tail plus the recorded `15d` tail.
- [ ] 3.2 `references/troubleshooting.md` §3: replace the open "single-line draft exactly on the hint slot
  (V9-C3)" hole with the new residual (a single row that is a verbatim status-row clone with the cursor parked
  elsewhere) plus the unrecognised-status-row-spelling case (reads busy, never empty), keep the whitespace-only
  hole, and state that the 0.87.0 layout (status row below the box) is supported while the 0.85.1 sample stays
  excluded by shape. Verify: `grep -n` finds the two new residual names and no longer claims the V9-C3 hole is open.
- [ ] 3.3 Gates and report: `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`,
  `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null`,
  then `docs/team/reports/<ID>-<agent>.md` carrying every tail the proposal's evidence list names, the before/
  after probe output, the flip directions, the touched-path list, and the multi-line control's `BUSY`. Verify: the
  `openspec` half exits 0; the smoke halves may still exit non-zero on the known pre-existing
  `container-tmux.sh:159/215` fpcheck lint red (P61's F3, a separate follow-up) — then the report must name it and
  show the counts are unchanged from the base tree, never claim a green the tree does not have.
