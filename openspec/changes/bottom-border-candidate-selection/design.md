# bottom-border-candidate-selection · design

## 1. The measured scene

`skills/teamsmith/scripts/lib/outbox.sh` → `_team_box_geometry <cy>` collects the bottom-border candidates as the
full-rule rows (a row whose text is only the rule character, byte-compared under `LC_ALL=C`) **strictly below the
cursor**, in row order, then tries them **nearest-first** and takes the first one that finds a top border above it
(tier1: the highest equal-width full-rule row; tier2: a spinner-shaped row). The banner block is skipped first
(M45) and a second pass admits it when skipping finds no box. The **top** border's candidate choice is pinned by
the base requirement ("the HIGHEST qualifying row … never the nearest one", V9-A4/A5/A8/A10); the **bottom** choice
is not pinned anywhere, and the implementation is nearest-first.

P74's independent verifier measured the consequence (`docs/team/reports/P74-dev2/pkg/20-border.sh` §20h/20h2,
re-measured for this proposal with the production code; `docs/team/reports/P78-verify/logs/pkg-10.log`):

| frame | shape (rows, cursor) | geometry today | box text today | verdict today |
|---|---|---|---|---|
| `p78-draft-rule-below-cursor.txt` | rule / blank (cy) / **draft's own equal-width rule** / draft text / real bottom / footer | `[1 3]` | empty | `idle-read=EMPTY` |
| `p78-draft-rule-only.txt` | rule / blank (cy) / draft's rule / real bottom / footer | `[1 3]` | empty | `idle-read=EMPTY` |
| `p78-draft-rule-below-cursor-line.txt` | rule / ` half a sentence` (cy) / draft's rule / ` more draft` / real bottom / footer | `[1 3]` | ` half a sentence` | `idle-read=NOT-EMPTY`, and `holds_only` for the payload `half a sentence` answers **only-ours** |

The first two read `EMPTY` while the box holds a draft: the readiness gate releases and a payload is pasted into
it. The third is subtler — the box is not empty, but its text is truncated at the draft's rule row, so a payload
that equals the part above that row is credited as the box's entire content. The content between the draft's rule
and the real bottom border is never examined. This is the mirror of the incident P67 fixed (a draft rule above the
cursor posing as the **top** border), and the same defect class V9-A4/A5/A8/A10 named.

## 2. Goals / Non-Goals

**Goals.** Pin the bottom border's candidate choice so a rule row the draft draws below the cursor can never shrink
the located box; keep every other box-shape behaviour identical; make the decision falsifiable in both directions
and give the fixtures one shared implementation of it.

**Non-Goals.** The top-border rule, the border-adjacent-row judgement (P67), the overlay predicate (P59/F2), the
fold/prefix windows (`team_box_text_holds_only`), `team_box_mid_render`, `team_retract`, and the delivery
confirmation path are untouched. No new TUI-geometry heuristic (footer detection, version detection, content
whitelists) is introduced: the rule stays structural.

## 3. Decision D1 — the bottom border is the LOWEST qualifying row below the cursor

Measured candidate table (production code vs each variant; `logs/pkg-10.log`, `logs/pkg-50.log`):

| candidate | ① rule below cursor | ①b draft = only a rule | ② wider rule | ③ spinner row | ⑤ cursor mid-draft | ④ rule below the box | rule+blank-line draft | stored real frames | verdict |
|---|---|---|---|---|---|---|---|---|---|
| **A** nearest candidate (today) | `EMPTY` ✗ | `EMPTY` ✗ | busy ✓ | busy ✓ | busy ✓ | `EMPTY` ✓ | `EMPTY` ✗ | unchanged | the defect |
| **B** lowest qualifying row (**chosen**) | busy ✓ | busy ✓ | busy ✓ | busy ✓ | busy ✓ | busy (documented cost) | busy ✓ | unchanged | chosen |
| **C** extend only when the rows between the two candidates hold a non-blank row | busy ✓ | busy ✓ | busy ✓ | busy ✓ | busy ✓ | `EMPTY` ✓ | `EMPTY` ✗ | unchanged | rejected |
| **D** equal-width pairing only, else nearest | `EMPTY` ✗ (the draft's rule *is* equal width) | `EMPTY` ✗ | — | — | — | ✓ | ✗ | — | rejected |
| **E** drop the pairing requirement | busy ✓ | busy ✓ | — | — | — | busy | busy | a phantom box appears on mismatched rule rows | rejected |

- **B** is the symmetric partner of the top border's HIGHEST rule: both ends take the **outermost** qualifying
  row, so anything the draft itself draws between them becomes box content. "Qualifying" keeps the existing
  pairing constraint (tier1 equal width, tier2 spinner), the banner-block exclusion, the strictly-below-cursor
  search (V9-A10) and the retry-with-banner-admitted fallback.
- **The admission condition (P86).** A candidate counts only when the top border it pairs with sits **strictly
  above the cursor row**: the located box therefore always contains the cursor row (the box grows from the cursor).
  This is a correction, not a refinement — P84's verification measured that the "monotone" claim written here
  earlier was **false as written**: on a mixed-width frame (`tests/frames/p86-f1-mixed-width-disjoint-box.txt`: a
  100-column box whose cursor row holds ` HUMAN DRAFT LINE`, then a second, self-paired 120-column pair of rule rows
  below) the lowest candidate's pairing lies entirely below the cursor, so the located box `[5 7]` is disjoint from
  the cursor's `[1 3]`, reads empty, and the readiness gate releases — a rule row below the box is not content when
  the box never covered it. A candidate that fails the admission is skipped and the search continues with the
  nearer candidates; when none passes in a pass, the existing unknown-shape path applies (no new behaviour).
  Because of that, the change does **not** assert a monotonicity theorem: the gate machine-checks the frame corpus
  (every stored frame, against the admission shadowed off: no `BUSY`→`EMPTY`; every located box satisfies
  `top < cursor < bottom`) and names the residual its own boundary leaves (§8).
- **C** is rejected by its own falsifier: the region between a draft's rule and the real bottom border can be blank
  (a draft that is a rule row plus a trailing blank line), and C then keeps the truncated box and reads `EMPTY`
  again (`p78-draft-rule-blank-region.txt`, measured in `pkg-10.log` §10h). A content predicate cannot be the
  second signal here without re-opening the hole for another draft shape.
- **D** is A for equal-width draft rules — exactly the shape that matters (V9-A4) — and is therefore not a fix.
- **E** is rejected by its falsifier (`pkg-50.log`): a pane whose upper and lower rule rows do **not** match
  (e.g. an 80-wide separator above the cursor, a 120-wide one below) is `geometry=[]` under the pairing rule — the
  documented unknown-shape path, visible with one warning — while E manufactures a phantom box `[1 3]` whose blank
  cursor row reads `EMPTY` and would be typed into. The pairing constraint is load-bearing for the bottom rule,
  not an implementation detail.

## 4. Decision D2 — ADD a requirement; do not modify the base one

The base requirement *An automated send never types into a non-empty input box* states the geometry ("the box is
not pinned to the pane bottom, so the top/bottom borders are found from the cursor row") and pins the **top**
candidate only. It is **silent** about the bottom candidate, so there is no existing statement to supersede:
`## ADDED Requirements` with a new, independently falsifiable requirement is the OpenSpec-correct delta, and it
keeps `## MODIFIED`'s failure mode (transcribing a page of prose and 13 scenarios without dropping one) off the
table entirely.

The archive order is the decisive argument. `one-line-draft-judgement` (which rewrote the same requirement's
border-adjacent-row clause) is **verified but not yet archived**, and the archive replaces a requirement's whole
text by name. A `## MODIFIED` delta written against today's base text would revert P67's clause when this change
archives after it; written against P67's delta text it would smuggle P67's unarchived content in if this change
archives first. `## ADDED` has no such interaction: this change and P67's can archive in **any** order, and the
base requirement's scenarios — 8 today, 13 after P67's archive — are untouched as the regression set. The one cost
is that the pairing rule is described in the base requirement and the bottom-candidate rule in the new one, so the
new requirement cross-references it instead of restating it.

## 5. Decision D3 — two decision points, each with one implementation; the red side is a shadow

The candidate **order** must be decided in exactly one place, and so must the admission bound, both shared by the
production extraction
(`_team_box_text_of_frame`/`team_input_box_text`), the fixture-side judgement (`box-judge.sh`) and the gate's frame
probes — the same "one implementation" promise the border-adjacent row already carries (P67). Concretely: the
geometry function asks a separate overridable function for the candidate order (`_team_box_bottom_candidate_order`)
and one for the admission bound (`_team_box_top_border_max_row`) instead of hard-coding the loop direction or the
cursor bound, so a test process that shadows one of them reproduces the previous behaviour exactly: the order shadowed to
nearest-first reproduces the legacy rule, the admission shadowed to a huge row reproduces the pre-fix rule (lowest
candidate, no admission — the rule P84 measured `EMPTY` on the `p86-f1-*` frames). Those shadows are this change's
red sides (the pattern of `M45_NO_STRIP=1` and `M24_SHADOW_CHROME=1`); **no environment switch belongs in production**
— a switch would ship two behaviours where the spec pins one. `flip-m45.sh`'s cross-tree probe stays the one
documented exception (it must parse a pre-fix tree).

## 6. Decision D4 — the mirror cost is documented, and the ambiguity is proved

The new direction has a cost: a full-rule row **below** the located box that still pairs with a top border above
the cursor enlarges the box over it and the rows between, so the pane reads busy and delivery waits
(`p78-conversation-rule-below-box.txt`: `[1 4]`, busy) — a row whose pairing lies below the cursor is not a
candidate at all under the admission condition, so it cannot enlarge anything (and cannot move the box off the
cursor). It must
be in `references/troubleshooting.md` §3 beside the top border's documented cost, and it is the same shape of
cost: today a rule row drawn in the **conversation above** the box already enlarges the box under the HIGHEST rule
(measured: `logs/pkg-20.log` §20c, busy). Two measurements bound the cost:

- **Not reachable in the measured layouts.** On every stored real capture (Pi 0.85.1 and Pi 0.87.0) the pane's
  lowest full-rule row is the box's own bottom border, and no full-rule row sits below it — the rows below are the
  box's footer/status rows (`logs/pkg-30.log`; the 0.87.0 capture: rows 28–30 are the cwd/usage/mc rows). The
  trust-prompt frame has no box at all (its lowest rule row is the overlay's lower edge) and the overlay path takes
  precedence before any geometry.
- **Not separable in principle.** The brief's shape ①b ("the draft is exactly one rule row") and shape ④ ("the
  conversation draws a rule row immediately below an empty box") are the **same bytes** — sha256
  `e463c80cddc00efb84456a93b151536cd2683da923a789a5381baacb4f5053a6` for both readings, `logs/pkg-20.log` §20a.
  One rule must serve both, and the conservative reading (content → busy) is the one that cannot glue.

So the requirement states the cost and its direction; it does not pretend to eliminate it.

## 7. Decision D5 — fixtures: new synthetic frames stored, real captures untouched

Eight synthetic frames (2 × P74's §20h shapes + the wider rule + the spinner row + cursor-mid-draft + the
conversation rule below the box + the `holds_only` frame + the rule+blank-line falsifier) are stored under
`skills/teamsmith/tests/frames/p78-*.txt`
and three more are stored under `skills/teamsmith/tests/frames/p86-f1-*.txt` (P84's F1 frame and its two variants —
the mixed-width box, the spinner-shaped lower top border, the narrower lower pair; byte-identical to the frames P84's
verification built, sha256-pinned in the gate) with `README.md` rows naming the shape, the cursor row and that they are
**synthetic models of a clipping TUI** (the real captures are the four `pi-0.*` files plus the trust-prompt frame,
which stay byte-identical). The construction is the one P74's verifier used (`p78_rule`/`p78_spin` in
`docs/team/reports/P78-verify/pkg/lib.sh`), so the apply's stored frames can be `cmp`-checked against the frames
this proposal's red-side measurements used. The FAST gate section prints, per frame: `geometry`, `box_nows`, the
verdict and rc — in **both** candidate orders — and asserts the values in the delta's scenarios; the unaffected
control frames must print identical values in both orders. The frames must not be given a real-Pi provenance in the
README.

## 8. Risks / trade-offs

| Risk | Mitigation |
|---|---|
| A future layout draws a full-rule row below the box → that pane queues instead of delivering (the mirror cost) | documented in `troubleshooting.md` §3; measured unreachable in both layouts today; the opposite direction glues, which is strictly worse |
| The frame corpus is synthetic ("a clipping-type TUI") | the five real captures stay the regression anchor (verdicts and geometry pinned by the delta's last scenario) and are never edited |
| A later change re-introduces nearest-first for "performance" or "simplicity" | the gate's shadowed run fails the moment the two directions stop diverging (`pkg-50` pattern is pinned in the gate) |
| The admission's own boundary: when every candidate below a draft's rule row is inadmissible, the nearest admitted candidate can still be that draft's rule row, so the box truncates the draft (the pre-P80 shape, mixed-width frames only) | measured (P86): the shape `rule(A) / blank(cursor) / rule(A) / blank / rule(B) / text / rule(B) / footer` reads `EMPTY` with the admission in place where the pre-fix rule read busy; the admission only promises "the located box contains the cursor", the stored corpus does not contain the shape — named here rather than implied away, and handed to the PM |
| Someone reads the change as fixing the top border too | explicit non-goal (§2) and the untouched top-rule prose in the base requirement |
| The new requirement drifts from the base requirement's pairing rule | the new requirement cross-references it by name and the gate pins the values both ends produce |

## 9. Verification plan (what apply must leave behind)

1. `bash docs/team/reports/P78-verify/pkg/run.sh` — this proposal's package (pure functions) must stay
   `✓57 ✗0 · findings=1`; it is the propose-phase evidence, not the apply's proof.
2. The new FAST gate section over the stored frames, in both candidate orders, with the red frames flipping to
   `EMPTY` under the shadow.
2b. The P86 FAST section over the three `p86-f1-*` frames (admission off: the pre-fix `[5 7]`/`EMPTY`; admission on:
   the cursor-containing `[1 3]`/busy) and over the whole stored corpus (16 frames): every located box contains the
   cursor row and no verdict moves from busy to `EMPTY` in either comparison (admission off, order shadowed).
3. `bash skills/teamsmith/tests/guard-matrix.sh` — green (31/0) and the same state lines as the unmodified tree
   (the monotonicity check).
4. `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` and the full gate:
   `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null`.
5. The end-to-end safety face (non-FAST, a fixture pane holding the attack draft): the readiness gate refuses
   (`rc≠0`), the `idle-read=NOT-EMPTY` line is printed, no `deliver_text_lines=`, zero keylog lines — never as the
   only evidence for the requirement.
6. `references/troubleshooting.md` §3: the mirror cost and the byte-identical reading are named, and the
   same-class-hole list keeps naming the whitespace-only draft and the P67 status-row-clone residual.

## 10. Migration / rollback

No persisted state, no config, no protocol change: the change is one candidate-order decision plus its fixtures and
its documentation. Rollback is reverting the commit; the queue format and the delivery path are untouched.

## 11. What apply must not do

- Not touch the top-border candidate rule, `_team_box_row_is_chrome`'s shape test, the overlay predicate, the
  banner-block detector, the two-pass fallback, the fold/prefix windows, `team_box_mid_render`, `team_retract`,
  `team_payload_slice` or the transcript helpers.
- Not weaken, drop or re-word any existing scenario or any M24/M45/M59/M67 assertion; the synthetic fixtures may
  only be added, never re-shaped — except where an existing fixture's own frame text changes under the new rule
  (none is expected: the guard matrix is measured identical).
- Not add a production switch for the legacy order, and not change the verdict vocabulary (`EMPTY` / `NOT-EMPTY` /
  overlay / UNKNOWN).
- Not edit the stored real captures, the P61/P67/P74 reports or their logs.

## 12. Open questions (deferrable, none blocks apply)

- Whether a future layout with conversation text below the box deserves a chrome-aware exclusion instead of the
  documented busy cost. Deferrable: no such capture exists, and the cost is on the safe side.
- Whether the one decision point should be a shell function or a candidate-list function. Apply's call, as long as
  the shadow contract in D3 holds and the gate proves it.
