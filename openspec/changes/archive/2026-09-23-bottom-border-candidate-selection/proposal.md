# bottom-border-candidate-selection · proposal

## Why

The spec pins the **top** border's candidate selection ("the top border is the **HIGHEST** qualifying row above
the bottom border, never the nearest one", V9-A4/A5/A8/A10) but says nothing about which candidate the **bottom**
border takes. The implementation takes the **nearest** full-rule row below the cursor, so a rule row the draft
itself draws below the cursor becomes the bottom border: the box is located **too small**, the content between it
and the real bottom border (often the rest of the draft) falls outside the located box, and the box can read
`EMPTY` — the readiness gate releases and a payload is pasted into the human's draft. It is the mirror of the
incident P67 fixed, on the other end (P74's F1, `docs/team/reviews/P74.md`; the red frames are in P74's §20h/20h2).

## What Changes

- **ADDED — `delivery-guard`** (*The bottom border is the lowest qualifying rule row below the cursor*): the
  bottom border is the **LOWEST** full-rule row below the cursor that pairs with a top-border candidate, never the
  nearest one; a rule row the draft draws below the cursor stays in the box and is read as content. A requirement is
  **added** rather than modifying *An automated send never types into a non-empty input box*: that requirement is
  silent about the bottom half (nothing to supersede), and a MODIFIED delta would have to race the archive of the
  not-yet-archived `one-line-draft-judgement` change (`design.md` §4).
- **Same requirement**: the candidate decision has exactly one implementation, shared by the production extraction
  and the fixture-side frame judgement; shadowing it to nearest-first must flip the attack frames back to `EMPTY`.
- **Documented cost**: a full-rule row **below** the located box enlarges the box and reads busy (the mirror of the
  top border's documented "err to busy" cost); `references/troubleshooting.md` §3 names it. Measured: no real
  capture (Pi 0.85.1/0.87.0, `tests/frames/`) has a full-rule row below the box.

## Flip

Red before (measured on the synthetic frames, production guard): `p78-draft-rule-below-cursor.txt` →
`geometry=[1 3]`, `box_nows=[]`, `idle-read=EMPTY`; `p78-draft-rule-only.txt` → the same; and a payload equal to
the part above the draft's rule is credited `only-ours` although more draft exists. Green after: both frames →
`geometry=[1 5]`/`[1 4]`, `idle-read=NOT-EMPTY`; the same payload → `extra-text`; the 0.85.1/0.87.0 real frames
keep `EMPTY`/`NOT-EMPTY`/`overlay` exactly as today; the guard matrix stays `✓31 ✗0`. Falsifier: shadowing the
candidate order to nearest-first must return the red values.

## Capabilities

- **New Capabilities**: none.
- **Modified Capabilities**: `delivery-guard` — one requirement added
  (`specs/delivery-guard/spec.md`, `## ADDED Requirements`). The base requirement and its scenarios are untouched,
  so no base scenario can be dropped and the archive order against `one-line-draft-judgement` does not matter.

## Boundaries

Planning only, no code. Apply touches `skills/teamsmith/scripts/lib/outbox.sh`,
`skills/teamsmith/tests/**` (incl. `tests/frames/**`) and `skills/teamsmith/references/troubleshooting.md`; the
apply brief must grant those three. Out of scope: the top-border rule, the border-adjacent-row judgement, the
overlay predicate, the fold/prefix windows, `team_box_mid_render`, `extension/**`, `panel/**`,
`openspec/specs/**` and any other capability's spec. The new frames are synthetic models of a clipping TUI (the
real layouts keep their verdicts, measured) and the report must say which files are synthetic.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
bash docs/team/reports/P78-verify/pkg/run.sh
```

(The first and last lines run on this proposal — the last is the propose-phase evidence package and must stay
`✓57 ✗0 · findings=1`; the third needs the apply commit and is the full gate.)

## Evidence the report must contain

Both gate tails; the red/green table for the five shapes the brief lists plus the cost shape and the `holds_only`
case (probe output with geometry, box text, verdict, rc); the byte-identity proof of the two readings with their
sha256; the real-frame structure and verdict equality; the shadowed-candidate run flipping the attack frames back to
`EMPTY`; the guard matrix green in both directions with identical state lines; and the `troubleshooting.md` §3 diff.
