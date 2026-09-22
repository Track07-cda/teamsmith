# Tasks: `bottom-border-candidate-selection`

Planning only — nothing in this file is executed by the propose task (P78). **One apply brief** (three verifiable
batches, landed in order) plus **one independent verify brief** (a different agent). The change touches one
capability: `delivery-guard` (one **ADDED** requirement: *The bottom border is the lowest qualifying rule row below
the cursor*). The base requirement *An automated send never types into a non-empty input box* is **not modified**,
so no base scenario is at risk and no archive order against `one-line-draft-judgement` has to be enforced.

Coverage map (requirement → items): **delivery-guard#The bottom border is the lowest qualifying rule row below the
cursor** → 1.1–1.4, 2.1–2.3, 3.1–3.2. Every item names the capability it moves; no item is an orphan.

Batches: **B1** — the candidate rule and its one decision point (`delivery-guard`, 1.x), observable in
pure-function probes; **B2** — the stored frames, the fixture/gate side and the regression proof (`delivery-guard`,
2.x); **B3** — the end-to-end safety face, the docs and the gate (`delivery-guard` + report, 3.x). B2 needs B1;
B3 needs both.

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/tests/**` (incl. `tests/frames/**`) is
`agent:dev`'s; `skills/teamsmith/scripts/lib/outbox.sh` and `skills/teamsmith/references/troubleshooting.md` are
PM-owned and need the brief's explicit grant. Everything else under `skills/teamsmith/scripts/**`,
`extension/**`, `panel/**`, the other capabilities' specs and `openspec/specs/**` is **not** touched.

Planning evidence to reuse (do not re-invent): `docs/team/reports/P78-verify/pkg/lib.sh` builds the seven
synthetic frames byte-for-byte, and `logs/pkg-*.log` carries every measured value this change's delta asserts. The
apply's stored frames must be `cmp`-identical to the frames the propose-phase red-side numbers came from.

## 1. B1 — the candidate rule, in one place (`delivery-guard` ADDED)

- [ ] 1.1 `scripts/lib/outbox.sh`: the bottom-border candidates are tried **lowest-first** — the chosen bottom
  border is the lowest full-rule row below the cursor that pairs with a top-border candidate — while the banner
  block exclusion, the retry-with-banner-admitted second pass, the strictly-below-cursor search, tier1
  (equal-width full rule) and tier2 (spinner) stay exactly as they are. Verify (pure, no tmux):
  `bash docs/team/reports/P78-verify/pkg/run.sh 10` prints `geometry=[1 5]`/`idle-read=NOT-EMPTY` for
  `p78-draft-rule-below-cursor.txt` and `geometry=[1 4]` for `p78-draft-rule-only.txt`, and the control frames
  (`p78-wider-rule-below-cursor.txt`, `p78-spinner-row-below-cursor.txt`, `p78-cursor-mid-draft.txt`) print the
  values the delta's scenarios name.
- [ ] 1.2 `scripts/lib/outbox.sh`: the candidate **order** is one separate overridable decision (a function the
  geometry asks for the candidate rows/order), not a hard-coded loop direction; no environment switch is added.
  Verify (pure): a probe that sources the guard, shadows that one function to nearest-first and re-reads
  `p78-draft-rule-below-cursor.txt` and `p78-draft-rule-only.txt` prints `geometry=[1 3]`, `box_nows=[]`,
  `idle-read=EMPTY` (rc 0), while the control frames and the five stored real captures print their unchanged
  values in both directions.
- [ ] 1.3 One implementation, not two: `tests/lib/box-judge.sh`'s `team_box_frame_verdict` and the gate's frame
  probes inherit the decision (they call the shared pure functions; no inline candidate logic, no second extractor
  — `flip-m45.sh`'s cross-tree probe stays the documented exception). Verify: `grep -n` finds no second candidate
  loop under `tests/**`; the frame-mode probe and the production extraction agree on every stored frame
  (`pm-box-real.sh --frame … --cursor …` vs the pure-function probe).
- [ ] 1.4 `holds_only` reaches the whole box: on `p78-draft-rule-below-cursor-line.txt` the box text carries the
  draft's rule row and ` more draft`, so a payload equal to the field above the rule is `extra-text`. Verify
  (pure): the probe's `holds_only=extra-text` beside the pre-fix `only-ours` (measured: `logs/pkg-10.log` §10g).

## 2. B2 — the stored frames and the gate (`delivery-guard` ADDED)

- [ ] 2.1 Store the eight synthetic frames byte-identically as `tests/frames/p78-{draft-rule-below-cursor,
  draft-rule-only,wider-rule-below-cursor,spinner-row-below-cursor,cursor-mid-draft,
  draft-rule-below-cursor-line,conversation-rule-below-box,draft-rule-blank-region}.txt` and add
  `tests/frames/README.md` rows naming each
  shape, its cursor row and the fact that they are **synthetic models of a clipping TUI** (no real-Pi
  provenance). Verify: `cmp` each against the frame side of `docs/team/reports/P78-verify/pkg/run.sh`'s temp build
  (`P78_KEEP=1 bash docs/team/reports/P78-verify/pkg/run.sh 10`, then compare `$P78_TMP/frames/p78-*.txt`), and
  `grep` the README rows.
- [ ] 2.2 A new FAST gate section (beside `12b-h0b`, the M45 frame section) that prints, per stored frame,
  `geometry`, `box_nows` and the verdict/rc, and asserts the delta's values; it runs the same frames a second time
  with the candidate decision shadowed to nearest-first (**the required red side**) and asserts the attack frames
  flip back to `EMPTY` while every control frame and every stored real capture is unchanged. Verify: run the
  section and paste both directions; `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` stays
  green with the section's assertion count increased.
- [ ] 2.3 Regression and monotonicity: `bash skills/teamsmith/tests/guard-matrix.sh` is green and its 19 state
  lines plus 12 `holds_only` lines are **identical** to the unmodified tree's (no verdict may move from BUSY to
  `EMPTY`), and the five stored real captures keep `idle-read=NOT-EMPTY` / `idle-read=EMPTY` / `overlay=trust-prompt`
  with their current geometry `[25 27]`, `[24 29]`, none. Verify: run both matrices and `diff` their state lines;
  run the pure probe over `tests/frames/pi-0.*` and paste the equality.

## 3. B3 — the end-to-end face, the docs, the gates (`delivery-guard` ADDED)

- [ ] 3.1 `tests/pm-box-real.sh`'s readiness gate must refuse a pane holding the attack draft (frame-replay
  `M24_PI_BIN` drawing `p78-draft-rule-below-cursor.txt`, or the fake TUI with that draft): `rc≠0`, the last-state
  line names `idle-read=NOT-EMPTY`, the last frame is printed, no `deliver_text_lines=` appears and the keylog has
  zero lines; `team say`/`team draft send` answer `queued` with no key sent. This case needs a real tmux pane → it
  belongs in the non-FAST box section and is never the only evidence for the requirement. Verify: the run's tail
  plus the keylog's zero-line count.
- [ ] 3.2 `references/troubleshooting.md` §3: name the mirror cost (a full-rule row below the box enlarges it and
  reads busy — the mirror of the top border's documented cost), its measured unreachability in the two real
  layouts, and the byte-identical reading of "a draft that is only a rule row" and "a rule row immediately below an
  empty box"; keep the whitespace-only and status-row-clone residuals listed. Verify: `grep -n` finds the cost
  paragraph and the two readings; the same-class hole list still names its existing members.
- [ ] 3.3 Gates and report: `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`, then
  `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null`,
  then `docs/team/reports/<ID>-<agent>.md` carrying every tail the proposal's evidence list names, the red/green
  table in both directions, the shadowed run, the state-line diff, the `cmp` results and the touched-path list.
  Verify: the `openspec` half exits 0; the smoke halves must be green on this change's tree (if a pre-existing red
  is still present, the report names it and shows its counts are unchanged from the base tree — never claim a green
  the tree does not have).
