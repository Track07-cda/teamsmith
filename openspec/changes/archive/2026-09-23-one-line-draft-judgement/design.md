# one-line-draft-judgement · design

## 1. The measured scene

Two real layouts, both captured raw (`tmux capture-pane -p`, 120×30 pane) and both with cursor row 26 (1-based):

```
0.85.1 (tests/frames/pi-0.85.1-update-banner.txt)     0.87.0 (docs/team/reports/P61-dev3/logs/…)
24 ────────────────────────────  <- top border        25 ────────────────────────────  <- top border
25 (blank)                                            26 HUMAN-ONE-LINE-DRAFT          <- content
26 (blank)  <- cursor                                 27 ────────────────────────────  <- bottom border
27 (blank)                                            28 /tmp/p61pkg.… (main)               <- cwd
28  deepseek-flash  Deepseek  max  <- box status row   29 0.0%/1.0M … deepseek-flash • max   <- status
29 ────────────────────────────  <- bottom border     30 mc: 0 (0%) · idle off-peak ×0.5     <- status
30  proj | mc: … | deepseek-flash | 0.0%/1.0M | …
```

`_team_box_rows_of_frame` numbers the rows it finds by `OFFSET = bottom - row`, so the border-adjacent row is
`OFFSET==1` in both layouts — but in the first it is the **box's own status row** (chrome) and in the second it is
**real content**. The extraction excludes `OFFSET==1` unconditionally (a 0.85.1-era decision, correct then), so on
0.87.0 the only row of a single-line draft disappears. Measured with the unmodified tree:

```
frame=15b-one-line-draft-frame.log cy=26      geometry=[25 27]  rows=[1|HUMAN-ONE-LINE-DRAFT|26 ]  verdict=idle-read=EMPTY
frame=10c-real-draft-box.log cy=26            geometry=[25 27]  rows=[1|DRAFT-p61-half-sentence|26 ]  verdict=idle-read=EMPTY
frame=10c-real-empty-box.log cy=26            geometry=[25 27]  rows=[1||26 ]                     verdict=idle-read=EMPTY
frame=pi-0.85.1-update-banner.txt cy=26       geometry=[24 29]  rows=[… 1| deepseek-flash  Deepseek  max|28]  verdict=idle-read=EMPTY
```

Downstream (P61 evidence): the readiness gate releases and the fixture types (`15d`: `rc=0`,
`M45 idle-read=EMPTY ok`, one keylog line); the production path `team_delivery_verdict` returns `EMPTY` and
`team_box_holds_only <target> <draft>` returns empty-box semantics, so a drain pastes over the draft. Multi-line
drafts read `BUSY` (`15c`), so the hole is exactly one visible text row on the border-adjacent slot.

## 2. What the new rule has to satisfy

1. 0.87.0, one text row at `OFFSET==1` (cursor on it, `15b`/`10c`) → **content** (BUSY; `HOLDS_ONLY=no` for a
   foreign payload, `yes` for our own).
2. 0.85.1, status row at `OFFSET==1`, box otherwise empty (cursor row 26) → **chrome** (EMPTY).
3. 0.85.1 with a draft above the status row → status row excluded, draft content → BUSY (and `holds_only` still
   compares our own payload verbatim — with a multi-line payload the cursor sits on the last line, which is
   `OFFSET==1`, and must be ours).
4. A draft whose text is below the cursor (the V7-F1 shape) with its **only** text row at `OFFSET==1` (0.87.0
   `\nfoo`, cursor on the blank row above) → content (BUSY), not chrome.
5. Nothing may be excluded by position alone; nothing may be excluded by matching text alone.

## 3. Rule choice

| candidate | 0.87.0 single line (cursor on it) | 0.85.1 empty (status row) | 0.87.0 `\nfoo` (cursor above) | verdict |
|---|---|---|---|---|
| A · slot exclusion (today) | EMPTY ✗ | EMPTY ✓ | EMPTY ✗ | the defect |
| B · *only* shape: exclude `OFFSET==1` when the text looks like a status row | EMPTY ✗ (swallows a clone) | EMPTY ✓ | BUSY ✓ | unsafe alone |
| C · *only* structure: `OFFSET==1` is chrome iff it is the only non-empty row and the cursor is off it | BUSY ✓ | EMPTY ✓ | EMPTY ✗ | safe, but leaves the same defect in the V7-F1 shape |
| E · no exclusion at all | BUSY ✓ | BUSY ✗ (the status row reads as content, so every delivery queues on 0.85.1) | BUSY ✓ | blocks delivery where it used to work |
| D · **cursor first, shape as the degraded signal** | BUSY ✓ | EMPTY ✓ | BUSY ✓ | chosen |

Why C cannot be repaired: `\nfoo` and the 0.85.1 empty box differ **only** in the text of that one row (one blank
row above it, the text row at `OFFSET==1`, nothing else in the box). No positional rule can separate them, so a
text predicate is unavoidable; making it the *second* signal (with the cursor able to override it) keeps it from
swallowing a draft the user is editing.

**Rejected: detect the layout version.** Both layouts draw the same full-width borders, and both draw status
lines *below* the box (0.85.1 one footer line, 0.87.0 two); nothing in the frame names Pi's version, and a
line-count heuristic would depend on pane height and Pi's footer contents. Its failure direction is the
destructive one (a one-line draft judged empty), so the measured content/shape signal is preferred.

**The rule (chosen).** For each row of the located box, in row order:

1. empty text → not content;
2. the row the cursor rests on → **content**, whatever its text (Pi's cursor never rests on the box's status row);
3. otherwise, `OFFSET==1` whose text matches the **status-row shape** → chrome (excluded);
4. otherwise → content.

**The status-row shape** (measured; both real samples are in the repo — 0.85.1 frame row 28 and the E3 fixture row
used by `guard-matrix.sh`):

```
^ [^ ]+  [^ ].*  (off|minimal|low|medium|high|xhigh|max)$
  ^ one leading space, model token without spaces, two spaces, provider display name, two spaces,
    thinking level from Pi's set (verified in the installed 0.87.0 bundle: dist/core/defaults.js,
    THINKING_LEVEL_OPTIONS = off, minimal, low, medium, high, xhigh, max)
```

Samples: ` deepseek-flash  Deepseek  max`, ` k3  Kimi Coding  max`. Everything else — `half a sentence`,
`HUMAN-ONE-LINE-DRAFT`, ` fake-pi 1.0`, a rule row, `max`, a whitespace-only row — is content (the last one is the
pre-existing whitespace hole, unchanged). The predicate is deliberately narrow: an unrecognised future status-row
spelling reads the box **busy** (blocks delivery, the conservative direction), never empty.

**Direction of change.** The old rule excluded every `OFFSET==1` row; the new rule excludes only rows that pass
both tests. The exclusion set strictly shrinks, so no draft that is visible today becomes invisible: the rule can
only discover more drafts, never fewer. That is why it does not weaken the "a draft in the box means no key" red
line (M24/M30).

## 4. One extraction, not three

The exclusion lives in three places today: `outbox.sh:team_input_box_text`, `box-judge.sh:team_box_frame_verdict`
(inline `awk '$1+0 != 1'`), and the frame probes in `smoke.sh` (§12b-h0b) and `flip-m45.sh` (`b-NR == 1`). A fix in
one leaves the others lying, which is exactly how a fixture can keep reporting the old verdict after production is
fixed (or the reverse).

- `outbox.sh` gains the pure `_team_box_text_of_frame <cy>` (stdin = captured frame) plus a separate overridable
  predicate for the border-adjacent row, `_team_box_row_is_chrome <cy> <row> <text>` — the default answers
  `false` when the row is the cursor row, the shape test otherwise. The caller only asks it about `OFFSET==1`
  rows; `team_input_box_text <target>` is `capture + cursor_y +` that function.
- `box-judge.sh`'s `team_box_frame_verdict` calls the same function (it already sources `outbox.sh`), so
  `pm-box-real.sh`'s readiness wait and the gate's frame mode inherit the rule for free.
- The gate's frame probes call it too; they may not re-implement the exclusion.
- **One documented exception**: `flip-m45.sh`'s cross-tree probe deliberately parses both the pre-fix and the
  post-fix trees with its own extractor so their `geometry`/`box_nows` outputs are comparable; it is a flip
  harness, not evidence for this judgement, and the file says so.
- The red side needs no production switch: a test process that sources `outbox.sh` and then shadows
  `_team_box_row_is_chrome() { return 0; }` reproduces the legacy slot exclusion exactly — that is why the
  cursor/shape decision is one predicate rather than an inline test (the same pattern as M45's `M45_NO_STRIP=1`
  probe).

**Fixture universe to update (measured, not guessed).** Every synthetic box in the tree draws its status row as
` fake-pi 1.0`, which the new rule (correctly) reads as **content**; left alone, it would turn every empty-box
fixture non-empty and redden the gate for the wrong reason. Measured with a filter simulation over the current
frames: `smoke.sh` §12b-h0b's `m45_frame`/adversarial/no-banner frames, §12b-h0c's M59 empty-box/draft-box frames
and `tests/fake-tui.py`'s `draw()` all need the measured shape (e.g. ` fake-pi  Fake Pi  max`) or the 0.87.0 box
shape. Then: `box_nows=[]` stays `[]`, `box_nows=[半句草稿halfasentence]` stays itself, and the M59 controls stay
`rc=0`/`rc≠0` — the fixtures keep passing for a *shape* reason. One expected string genuinely grows: the
`draft-top.txt` adversarial frame locates its box as `[1 5]`, so ` Changelog: https://x` is the border-adjacent
row and becomes content — its assertion becomes
`box_nows=[UpdateAvailableNewversion1.0.0isavailable.RunpiupdateChangelog:https://x]`, which is what the frame
really shows (the property asserted, "not NONE, banner text stays content", is unchanged). `flip-m45.sh`'s
adversarial frame also gets the real shape; its assertions are substring-based and unaffected. **No assertion may
be dropped or weakened** — only expected strings that follow what the frame contains may grow.

## 5. F2 (the overlay predicate vs a draft holding the same wording) — ruled, not fixed here

P61's F2: `team_box_overlay_kind` (fixture-side, P59) classifies a frame whose text contains all three marker
groups (`Trust project folder?` … `Do not trust` … a `navigate`/`enter select` line) as `overlay=trust-prompt`, so
a **draft** containing that wording is never delivered by the fixture (`overlay=trust-prompt`, rc 0 in overlay
mode; the readiness wait refuses in normal mode). The brief's leaning — position/structure first, text matching
only as a degraded signal — is applied **to this change's judgement** (the cursor is the primary signal; the text
shape can only exclude, and only when the cursor is elsewhere). The overlay predicate itself is left alone, for
three reasons:

1. It is a promise of the unarchived `trust-prompt-and-fixtures` change in the `verification` capability, with its
   own falsifiability evidence (all 30 cursor rows of the stored prompt frame must classify as overlay). Making it
   structure-first requires defining "a genuine, bottom-anchored input box" against the prompt's own full-pane
   rule pair and re-doing that evidence — that is a `verification` change; this change's `deltas:` line is
   `delivery-guard` + `notify-and-inbox`.
2. Both directions are safe for the red line: nothing is typed into the pane (the fixture stops before the payload
   steps), and the **production** guard never consults the overlay predicate, so a marker-text draft is `BUSY` and
   queued there.
3. The new judgement must not *add* a text-based swallow. It removes one (strictly fewer exclusions, §3).

**Named follow-up for the PM to file** (not this change): "a marker block that lies **inside** a located,
bottom-anchored input box is box content; the overlay predicate applies only outside one", with the two frames
that make it falsifiable — a draft-with-markers frame in a genuine box (must be `idle-read=NOT-EMPTY`) and the
stored trust-prompt frame (must stay `overlay=trust-prompt`, 30/30 cursor rows).

## 6. Red/green evidence plan

Probe (pure functions, no tmux, no Pi). Before the fix use `docs/team/reports/P63-dev3/repro.sh` (it reads the
current extraction); after the fix the report must paste this one-liner for each frame, both directions:

```sh
for f in docs/team/reports/P61-dev3/logs/15b-one-line-draft-frame.log \
         docs/team/reports/P61-dev3/logs/10c-real-draft-box.log \
         docs/team/reports/P61-dev3/logs/10c-real-empty-box.log \
         skills/teamsmith/tests/frames/pi-0.85.1-update-banner.txt; do
  ( . skills/teamsmith/scripts/lib/common.sh; . skills/teamsmith/scripts/lib/outbox.sh
    . skills/teamsmith/tests/lib/box-judge.sh
    printf '%s  box_text=[%s]  verdict=%s\n' "$(basename "$f")" \
      "$(_team_box_text_of_frame 26 < "$f" | tr -d '[:space:]')" "$(team_box_frame_verdict 26 < "$f")" )
done
```

Storage: the P61 raw captures become `tests/frames/pi-0.87.0-one-line-draft.txt` (`15b`),
`tests/frames/pi-0.87.0-draft-half-sentence.txt` (`10c` draft), `tests/frames/pi-0.87.0-empty-box.txt` (`10c`
empty), each byte-identical to its log (`cmp`), with README rows naming source, cursor row and the P61 log. The
multi-line control gets a 0.87.0 frame captured live into `tests/frames/` (P61's `15c` measured `BUSY`; if the
capture cannot be reproduced deterministically, a synthetic frame of the same 0.87.0 box shape is the fallback and
the report says which it is). The decision value is the verdict class, not the file name.

Gate section (FAST, next to §12b-h0b): run the probe over the stored frames and assert —
drafts → `idle-read=NOT-EMPTY`; 0.87.0 empty and 0.85.1 → `idle-read=EMPTY`; the same frames through
`team_input_box_text`'s pure path (the production extraction) give identical strings — plus the shadowed-predicate
run (legacy behaviour) in which the drafts must flip back to `EMPTY`, printing both directions' tails.

End-to-end consequence: `pm-box-real.sh`'s readiness wait must refuse a pane holding a one-line draft — `rc≠0`,
`idle-read=NOT-EMPTY` in the last-state line, the frame printed, no `deliver_text_lines=`, and a keylog with zero
lines (the pre-fix scene is `15d`: `rc=0`, `M45 idle-read=EMPTY ok`, one line).

## 7. Residuals (recorded, not fixed here)

1. **Status-row clone.** A draft whose *only* row matches the status-row shape exactly, with the cursor parked on
   another row (leading newline + one line, then `Up`), is still read as chrome → EMPTY. This is the same shape
   class as today's slot exclusion (today *every* `OFFSET==1` row is swallowed), so the change strictly narrows
   the hole; it is the mirror of F2 (text matching can be fooled). It goes into `references/troubleshooting.md` §3
   with the other members of the class.
2. **Unknown future status-row shapes.** If Pi changes the status-row spelling, the row is read as content →
   false BUSY → messages queue instead of being delivered. Conservative; named in §3 of troubleshooting.
3. **Whitespace-only draft** stays a known miss (unchanged).
4. **The whitespace/`NONE` behaviour** of `team_box_rows_of_frame` and the UNKNOWN → "deliver as today" path are
   untouched.

## 8. What apply must not do

- Not skip, weaken or re-word any existing scenario of the modified requirements, and not drop an M45,
  `guard-matrix.sh` or V8/V9 assertion (the fixtures may only be updated where §4 says the synthetic status row is
  not real-shaped).
- Not touch the border/banner geometry (`_team_box_geometry`, `_team_box_banner_rows`), the fold/prefix windows
  (`team_box_text_holds_only`), `team_box_mid_render`, `team_retract`'s key sequence, `team_payload_slice`,
  `team_transcript_*`, or the overlay predicate.
- Not add a production switch for the legacy behaviour (the red side is a test-process shadow, §4).
- Not change delivery semantics for any other box shape, and not introduce "any text → BUSY".
- Not edit the P61 report or its logs (they are the frozen evidence); copy them into `tests/frames/`.
