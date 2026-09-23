## ADDED Requirements

### Requirement: The bottom border is the lowest qualifying rule row below the cursor

When the guard locates the input box from the cursor row, the bottom border SHALL be the **LOWEST** row below the
cursor that qualifies as a bottom border: a full-rule row (the whole row is the rule character, no other text) that
pairs with a top-border candidate **strictly above the cursor row** under the pairing rule of *An automated send
never types into a non-empty input box* — an equal-width full-rule row, or a spinner-shaped row where a spinner-shaped
top border is admissible. The admission is what makes the located box contain the cursor row (the box grows from the
cursor), so a lower candidate whose pairing lies entirely below the cursor MUST NOT decide the geometry: a
mixed-width frame can hold a second, self-paired pair of rule rows under the cursor, and pairing with it would locate
a box that does not contain the cursor at all. A candidate that fails the admission MUST be skipped and the search
MUST continue with the nearer candidates (the order is lowest-first, so the next candidate is the one closer to the
cursor). The guard MUST NOT take
the NEAREST qualifying row: a rule row the human's own draft draws below the cursor (an equal-width rule row, a
longer one a clipping TUI cuts at the pane edge, a pasted markdown separator or
a table border) SHALL stay inside the located box and be read as content, so the box reads busy instead of empty —
this is the mirror of that requirement's HIGHEST rule for the top border, and the same defect class
(V9-A4/A5/A8/A10 on the top end). The rows excluded by the update-banner rule MUST NOT be candidates, and when
skipping that block finds no box the existing retry-with-the-block-admitted fallback MUST stay in place. A cursor
row that is itself a full-rule row MUST NOT be a candidate: the bottom border is searched strictly below the cursor
row (V9-A10). When no row pairs, the existing unknown-shape path applies unchanged (deliver as today with one
warning; never a permanent hold).

The admission condition is a statement about what the located box IS — always a box that contains the cursor row —
and not a licence to claim that any frame's verdict is monotone. What the gate MUST pin instead: for every frame
stored under `skills/teamsmith/tests/frames/`, the verdict read with the admission in place is compared with the
verdict read with the admission shadowed off (the pre-fix rule: lowest candidate, no admission), and the gate MUST
fail if any frame's verdict moves from busy to `EMPTY`; the reverse moves MUST be exactly the frames the admission
fixes, and every located box MUST be shown to satisfy `top < cursor row < bottom` (the frame with no box at all is
the trust prompt, whose overlay verdict takes precedence). Both decisions — the candidate order and this admission —
MUST have exactly one implementation each, shared by the production extraction and the fixture-side frame judgement,
so a fixture cannot keep the old behaviour after the production guard changes; the red side of each is a test
process that shadows that one decision (the order back to nearest-first, the admission off;
`M24_SHADOW_CHROME`/`M45_NO_STRIP`'s pattern), and the gate MUST exercise both.

The cost SHALL be documented in `references/troubleshooting.md` §3: a full-rule row that lies BELOW the located
box and still pairs with a top border above the cursor (a rule row drawn in the conversation, or any chrome rule
row under the box — `p78-conversation-rule-below-box.txt` is that shape) enlarges the box over that row and
the rows between it and the box's own bottom border, so the box reads busy and delivery waits — the conservative
direction, never a glue. That cost is not reachable in either measured layout: on every stored real capture (Pi
0.85.1 and Pi 0.87.0, `skills/teamsmith/tests/frames/`) the pane's lowest full-rule row is the box's own bottom
border (the trust-prompt frame is an overlay with no box, and the overlay path takes precedence) and no full-rule
row sits below it (measured). It is also not separable in principle: a frame whose
draft is exactly one rule row and a frame whose conversation draws a rule row immediately below an empty box are
the same bytes (sha256 `e463c80c…f5053a6`), so one rule must serve both readings and this requirement chooses the
one that cannot glue.

#### Scenario: A rule row the draft draws below the cursor keeps the box busy

- **GIVEN** the frame `skills/teamsmith/tests/frames/p78-draft-rule-below-cursor.txt` (120-wide rules, cursor row
  2; rows: rule / blank / rule / ` draft text below my own rule` / rule / ` footer` — a draft that is a blank
  line, its own equal-width rule and a text line below it)
- **WHEN** `bash skills/teamsmith/tests/pm-box-real.sh --frame skills/teamsmith/tests/frames/p78-draft-rule-below-cursor.txt --cursor 2` runs
- **THEN** `box_text` carries the draft's rule row and ` draft text below my own rule`, the verdict is
  `idle-read=NOT-EMPTY` with rc 1, and the gate's frame probe prints `geometry=[1 5]` — the draft's rule row is
  content, not the box edge
- **AND** with the candidate decision shadowed to the legacy nearest-first order in the probe process the same
  frame reads `geometry=[1 3]`, `box_text=[]` and `idle-read=EMPTY` (rc 0) — the red side the gate must show

#### Scenario: A draft that is only a rule row below the cursor keeps the box busy

- **GIVEN** the frame `skills/teamsmith/tests/frames/p78-draft-rule-only.txt` (cursor row 2; rows: rule / blank /
  rule / rule / ` footer`) — its middle rule row is either the draft's own or the bottom border of an empty box,
  and the two readings are the same bytes
- **WHEN** the guard reads that frame (production extraction and `pm-box-real.sh --frame … --cursor 2`)
- **THEN** the verdict is `idle-read=NOT-EMPTY` (rc 1) with `geometry=[1 4]` (the conservative reading: a rule row
  below the cursor is content), never `EMPTY`
- **AND** under the shadowed nearest-first order the same frame reads `idle-read=EMPTY` with `geometry=[1 3]`

#### Scenario: A wider rule row below the cursor is not a bottom border

- **GIVEN** the frame `skills/teamsmith/tests/frames/p78-wider-rule-below-cursor.txt` (cursor row 2; rows: rule
  (120) / blank / rule (140) / ` draft text` / rule (120) / ` footer`) — a draft rule a clipping TUI cuts at the
  pane edge less than the box border
- **WHEN** the guard reads it (frame probe and `pm-box-real.sh --frame … --cursor 2`)
- **THEN** `geometry=[1 5]` (the unpaired wide row cannot be a border), the wide row is box content and the verdict
  is `idle-read=NOT-EMPTY` (rc 1) — unchanged from the nearest-candidate rule

#### Scenario: A spinner-shaped row below the cursor is not a bottom border candidate

- **GIVEN** the frame `skills/teamsmith/tests/frames/p78-spinner-row-below-cursor.txt` (cursor row 2; the third row
  is `── ⠋ Blanching… 0s ` plus a long rule run, followed by ` draft text`)
- **WHEN** the guard reads it
- **THEN** `geometry=[1 5]` — only full-rule rows are bottom-border candidates, so the spinner-shaped row stays in
  the box as content and the verdict is `idle-read=NOT-EMPTY` (rc 1)

#### Scenario: A cursor in the middle of a draft keeps every draft row in the box

- **GIVEN** the frame `skills/teamsmith/tests/frames/p78-cursor-mid-draft.txt` (cursor row 3 on the second of
  three draft lines, the bottom border below all three)
- **WHEN** the guard reads it
- **THEN** the box text carries all three draft lines and the verdict is `idle-read=NOT-EMPTY` (rc 1) — unchanged

#### Scenario: A payload that matches only the part above the draft's rule is not the whole box

- **GIVEN** the frame `skills/teamsmith/tests/frames/p78-draft-rule-below-cursor-line.txt` (cursor row 2 on
  ` half a sentence`, a draft rule row below it, ` more draft` between that rule and the real bottom border)
- **WHEN** the box text is compared against the payload `half a sentence`
- **THEN** the comparison is `extra-text` (the box holds the rule row and ` more draft` too), so the entry is held
  rather than credited as this payload's own visible box — under the nearest-candidate rule the truncated box text
  equals the payload and the comparison answers `only-ours`

#### Scenario: A full-rule row below the located box enlarges the box and reads busy

- **GIVEN** the frame `skills/teamsmith/tests/frames/p78-conversation-rule-below-box.txt` (cursor row 2; an empty
  box whose bottom border is immediately followed by another full-rule row and ` conversation text`)
- **WHEN** the guard reads it
- **THEN** `geometry=[1 4]` and the verdict is `idle-read=NOT-EMPTY` (rc 1) — the documented mirror cost: the box
  is enlarged over the row below it and delivery waits, and `references/troubleshooting.md` §3 names this cost
  beside the top border's

#### Scenario: The stored real frames keep their verdicts

- **GIVEN** the stored real captures `skills/teamsmith/tests/frames/pi-0.87.0-one-line-draft.txt` (cursor 26),
  `pi-0.87.0-draft-half-sentence.txt` (26), `pi-0.87.0-empty-box.txt` (26),
  `pi-0.85.1-update-banner.txt` (26) and `pi-0.87.0-project-trust-prompt.txt` (16)
- **WHEN** each is read through the production extraction and the fixture-side judgement
- **THEN** the verdicts are `idle-read=NOT-EMPTY`, `idle-read=NOT-EMPTY`, `idle-read=EMPTY`,
  `idle-read=EMPTY` and `overlay=trust-prompt` respectively — identical to the nearest-candidate rule, with the
  locations `[25 27]`, `[25 27]`, `[25 27]`, `[24 29]` and no box (the overlay takes precedence)

#### Scenario: A candidate whose pairing lies below the cursor cannot decide the box

- **GIVEN** the frames `skills/teamsmith/tests/frames/p86-f1-mixed-width-disjoint-box.txt` (cursor row 2; the
  located box's own 100-column rule rows at 1 and 3 hold ` HUMAN DRAFT LINE` on the cursor row, and a second,
  self-paired 120-column pair of rule rows sits at rows 5 and 7 below it),
  `p86-f1-spinner-top-disjoint-box.txt` (the same shape with a spinner-shaped top border at row 5) and
  `p86-f1-narrower-width-disjoint-box.txt` (a 120-column box and an 80-column pair below)
- **WHEN** the guard reads each frame — the production extraction, `pm-box-real.sh --frame … --cursor 2` and the
  gate's frame probe
- **THEN** the admission refuses the lower candidate (its paired top border sits at row 5, below the cursor), the
  search falls back to the nearest admitted candidate, `geometry=[1 3]` — the located box contains the cursor row
  — the cursor row's draft is box content and the verdict is `idle-read=NOT-EMPTY` (rc 1); it is never `EMPTY`
- **AND** in a probe process that shadows the admission decision off (the pre-fix rule) the same bytes read
  `geometry=[5 7]`, `box_text=[]` and `idle-read=EMPTY` (rc 0) — the readiness gate releases and a payload is
  typed into the draft: the red side the gate must show

#### Scenario: Every stored frame's located box contains the cursor and no verdict moves from busy to EMPTY

- **GIVEN** every frame stored under `skills/teamsmith/tests/frames/` (the five real captures, the eight `p78-*`
  synthetic frames and the three `p86-f1-*` frames) with the cursor row each is measured at
- **WHEN** the gate's frame probe reads each of them through the production extraction with the admission in place
  and with the admission shadowed off (the pre-fix rule), and again with the candidate order shadowed to
  nearest-first
- **THEN** every located box satisfies `top < cursor row < bottom` (the only frame without a box is
  `pi-0.87.0-project-trust-prompt.txt`, whose overlay verdict takes precedence), no frame's verdict moves from
  `idle-read=NOT-EMPTY` to `idle-read=EMPTY` in either comparison, and the only frames moving the other way
  (`EMPTY` → busy) are the three `p86-f1-*` frames

#### Scenario: The candidate order has one implementation

- **GIVEN** the two synthetic attack frames above and the production extraction that `team_input_box_text` and
  `team_box_frame_verdict` share
- **WHEN** a probe process sources the guard and shadows the one candidate decision to the legacy nearest-first
  order
- **THEN** both frames flip back to `idle-read=EMPTY` on the same bytes, and the unaffected control frames
  (`p78-wider-rule-below-cursor.txt`, `p78-spinner-row-below-cursor.txt`, `p78-cursor-mid-draft.txt` and the
  stored real captures) keep their verdicts in both directions — proving the fixtures read the same decision the
  production guard does
