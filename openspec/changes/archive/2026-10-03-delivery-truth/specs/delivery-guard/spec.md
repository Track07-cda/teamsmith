## ADDED Requirements

### Requirement: Queue impediments are factual, bounded and recoverable

A draft-clearing explanation SHALL be emitted only for a trustworthy non-empty box read. A `geometry-untrusted` outcome SHALL send no key, durably hold the payload, exit non-zero and name the entry, target, reason and recovery command. It MUST NOT state that the human has a draft or promise that clearing the box will automatically deliver it.

For an entry that has not touched the input box, three consecutive eligible drain evaluations that read a trusted empty box but leave the entry queued without progress SHALL move it to durable `held/` with reason `queue-stalled` by the third evaluation. An eligible evaluation is one that owns the entry's claim, has a live target and is not blocked by an earlier entry or another delivery in progress; queueing during work, real drafts, lock contention and offline targets MUST NOT be counted as this empty-box defect. The diagnostic SHALL record the entry id, target, first/last observation time, consecutive count, read verdict and geometry/trust reason, and its durable full-text path. Enqueue, bounded retry, tick and flush SHALL use the same observation rule. A later busy/working read resets the consecutive-empty count; the payload and original immutable entry header MUST NOT be rewritten to track attempts.

The obstructing command SHALL print `held`, the reason and the recovery command and exit non-zero. `team outbox list`, `team status` and `team digest` SHALL expose a nonzero impeded count and the reason while such an entry exists. Geometry/stall holds MUST NOT bypass terminal `draft-raced` or `unconfirmed` protections: once any payload reached the box, later drains never repaste it. A never-typed hold MAY be retried only after fresh trusted geometry permits it. Observer commands MUST NOT advance attempt counts, emit a wake or mutate the queue. The existing TTL remains a backstop, not the first indication of this defect. Rationale belongs in `references/troubleshooting.md` §3.

#### Scenario: Untrusted geometry is not a draft-clearing promise

- **GIVEN** a replay of the real P143 frame with an invalidated supported-layout/footer premise and no trustworthy conservative box read
- **WHEN** `team say dev "geometry diagnostic"` runs
- **THEN** it exits non-zero, prints `held` and `geometry-untrusted`, names an existing durable payload and recovery command, sends no key, and prints neither a draft assertion nor an automatic-after-clearing promise

#### Scenario: Three empty-box evaluations expose a stalled entry

- **GIVEN** a queued, never-typed entry and the real P143 idle-empty frame, with a test-only shadow that prevents progress after a trusted empty read
- **WHEN** three eligible drain evaluations run before the TTL
- **THEN** the third exits non-zero and reports `held` / `queue-stalled`; the payload is unchanged under `held/`, the diagnostic records three observations and the original entry id, and list/status/digest show the impediment
- **AND** suppressing the observation/diagnostic transition in the test process makes the guard test fail on the same frame

#### Scenario: A human draft and a working target are not labelled stalled

- **GIVEN** the real P143 human-draft frame or a real working-Pi frame
- **WHEN** three drain evaluations run
- **THEN** no key is sent into the draft, the empty-observation count does not reach three, and no `queue-stalled` defect is inferred from work or a draft

#### Scenario: Recovery does not double-send a terminal payload

- **GIVEN** a never-typed `geometry-untrusted` hold, a never-typed `queue-stalled` hold and a terminal `draft-raced` hold
- **WHEN** trustworthy empty geometry returns and `team outbox flush` then `team outbox flush --now` run
- **THEN** the never-typed entries can each be submitted once through the guard, while the terminal entry receives no key and remains held; no payload is silently dropped

## MODIFIED Requirements

### Requirement: An automated send never types into a non-empty input box

Every sender that would type into a TUI input box (`team say`'s pane delivery, `team notify`'s pane delivery, the
watchdog wake line, the notify extension's knock, the meeting knock) SHALL locate the target pane's input box from the captured pane
and, when the box holds text, MUST send no key at all — neither the payload nor an `Enter`; it MUST hold the message
in `state/outbox/` instead. The check MUST be cursor-anchored (the box is not pinned to the pane bottom, so the
top/bottom borders are found from the cursor row), and the border pairing MUST reject rule-looking rows that
cannot be borders: a top border is either a full-rule row whose width equals the bottom border's or a
spinner-shaped row (a `── ` prefix with a long trailing rule run — the E3-observed working-Pi shape; Pi 0.85.1
draws its working row as ` ⠋ Blanching… · 0s` — a braille glyph plus text, drawn on its own row ABOVE the box
(its top border stays a full rule row and tier1 still locates it) — which is deliberately NOT an eligible border,
V9-D2: admitting a row that normally sits above the box would extend the box over conversation text and read
busy forever, so the documented fallback applies instead — if a future TUI promotes that row to the top border,
the pairing finds no box and the pane is typed as today with one warning). Outside the supported closed Pi layout defined below, when several rows qualify, the top border is the HIGHEST qualifying row above the
bottom border, never the nearest one (V9-A4/A5/A8/A10: a rule row the draft itself draws — equal-width, wider, or
spinner-shaped — must become box content, so the box reads busy; the old nearest-candidate rule let such a draft
row pose as the border and reproduced the dirty-box-misread-as-empty incident again). The cost is documented:
on a TUI that CLIPS long lines to the pane width, an over-long draft line can read as an equal-width rule row and
enlarge the located box — the verdict errs to busy, never to gluing (real Pi 0.85.1 wraps content at one column
short of the border width, so an equal-width content row is unreachable there; V9 90.C/90.F measurements), so a
short full-rule row inside the human's
draft (a pasted markdown separator or table border; V8-N1 replayed the original incident on real Pi through that
hole) is never mistaken for the box edge. The check MUST examine every content row of the located box — not only
rows at or above the cursor, because a draft typed after a leading newline or recalled with `Up` sits BELOW the
cursor row (V7-F1 reproduced the original D20 incident through that hole) — and MUST NOT assume a particular
empty-box shape (a package-provided hint row and a spinner during work are both normal). The row immediately
above the bottom border SHALL be read as CONTENT unless it is provably the box's own status row, and it is proved
only by BOTH of: (a) the cursor is not resting on that row, and (b) its text matches the package's status-row
shape — one leading space, a model token without spaces, two spaces, the provider display name, two spaces, and a
thinking level from Pi's set (`off`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`); the two measured real
shapes are ` deepseek-flash  Deepseek  max` and ` k3  Kimi Coding  max`. A row the cursor rests on is content
whatever its text: Pi's cursor never rests on the box's own status row, and a human's text can be shaped like
anything. The old exclusion by slot MUST NOT come back: Pi 0.87.0 moved the box's own status row to a line BELOW
the bottom border, so the border-adjacent row is where a single-line draft lives, and reading that row by position
alone judged the box empty while it held a draft (measured: the readiness gate typed its payload onto the draft
and the delivery path would have pasted over it; V9-C3). A border-adjacent row that fails the shape test is
content and reads the box busy — the conservative direction, never a glue (V9-C1). The one remaining member of
this class — a draft whose only row is a verbatim status-row clone AND whose cursor rests on another row — MUST be
named in `references/troubleshooting.md` §3 together with an unrecognised future status-row spelling (which reads
busy, never empty). The guard MUST be re-checked immediately before the `Enter` by comparing the
box's content fingerprint with what the check saw — verbatim, trimmed, or as a suffix/prefix of the visible
content are the acceptable verbatim shapes, and the only acceptable folded shape is the whole box being exactly
ONE `[paste #N +K lines]` placeholder whose `+K` equals the payload's line count (two folded pastes — ours and
the human's — MUST count as a race, V8-N4; the payload's own text MUST be compared verbatim before any
placeholder stripping, because a payload that literally contains `[paste #N +K lines]` text is not a folded
box, V8-N2); a length comparison MUST NOT be used, because a TUI that folds a long paste makes every length
heuristic fire (V7-F2) — so a draft that appeared between the check and the paste holds the message instead of
gluing it. A half-rendered placeholder frame (`[paste #N +1` without the completed pattern) is neither "settled"
nor foreign text: the re-check SHALL keep waiting for the render to finish (bounded, on the order of a second)
instead of judging that frame a race (V8-N3) — and when that bound is exhausted while the frames were still
half-rendered, the outcome MUST NOT be the terminal `draft-raced` hold: the payload was never submitted by the
drain, so the entry is held with reason `stall-timeout` and a later drain MUST retry it in resume mode —
completing the pending `Enter` when the box still holds only that payload (verbatim or `+K`-matched folded
placeholder) and never pasting it again; if the box no longer holds only the payload, the entry stays in `held/`
for the human to verify and drop or re-send, because a repaste could double-send (V9-B6). The mid-render test MUST match a whole content line
(`[paste #N +<digits>` occupying an entire row, without the completed `lines]` suffix) — never a substring — and
the settle loop MUST first check whether the payload is already verbatim in the box: a clean payload that
literally contains half-placeholder text like `[paste #` is not a rendering-in-progress frame, and waiting for
such a frame to finish would hold a clean message forever (V9-B1 reproduced that on real Pi).
A box whose only content is whitespace is one known miss of the box-content detector: the guard reports it
free (the capture trims trailing blanks), and that limitation MUST be enumerated together with the other
same-class holes in `references/troubleshooting.md` §3 — the ones fixed by the highest-candidate rule
(equal-width draft rules, spinner-shaped draft rows, a cursor resting on the draft's own rule row: V9-A4/A5/A8/A10)
and the ones deliberately still open (the whitespace-only draft; a draft whose only row is a verbatim clone of
the status-row shape with the cursor resting on another row, V9-C3) — so the document never implies the detector
has no other hole. It MUST NOT be silently wrong.
The remaining documented edges (all named in `references/troubleshooting.md` §3): notification-shaped text inside
the conversation transcript can look like box content when the box borders are mis-paired — measured: a
spinner-shaped row standing in as the top border reads that text as box content and the verdict is busy (a
conservative hold, V9-C2), and a status row whose spelling the shape test does not recognise reads as box content
with the same conservative busy following (V9-C1); only a transcript with no rule-looking row at all pairs no box and fails safe to UNKNOWN — the
prefix/suffix acceptance
window accepts a frame where only a prefix of the payload rendered (V8-N6); when that frame goes on to the
`Enter`, the submission is not credited as confirmed (B5 evidence), so the entry stays in `held/` with the full
payload in its durable inbox copy — the message is never silently deleted, even though the partially rendered
text may have been submitted (V9-B3); and a folded paste by the human whose line count
equals the payload's is geometrically indistinguishable from ours (V8-N4 residual) — the payload is visible in
the box in that case, and the human is holding the pane.
A pane whose input-box shape cannot be located MUST be treated as "deliver as today" with one warning, never as a
permanent hold — and because no box can be read there, no submission proof can be collected either, so such a pane
is NEVER reported as confirmed; its output names the unknown shape (V9-C3).

For a supported Pi layout, the candidate domain SHALL be a closed editor rectangle: its top and bottom enclose the cursor (`top < cursor < bottom`), their rule widths match the pane, the bottom directly precedes the verified two-row Pi footer, and every editor row between them fits the measured renderer's content-width and visible-height bounds. The footer's directory MUST agree with the target's runtime directory; a transcript's blank line, a status-looking draft or a rule near the cursor alone is not layout evidence. Supported-layout provenance and terminal-cell bounds MUST be recorded with real captures. Only a unique rectangle satisfying the whole shape admits the narrower candidate domain; the highest top and lowest bottom rules still apply within that domain. Unsupported, scrolled, clipped, ambiguous or partially drawn layouts MUST NOT acquire an EMPTY verdict by this exception. Existing conservative border selection, banner fallback, status-row cursor precedence and documented unknown-shape handling remain outside the domain. The documented whitespace-only and off-cursor verbatim status-clone misses remain explicitly named; this change MUST NOT claim to close them. A recognised Pi layout with conflicting geometry MUST instead defer without typing and expose `geometry-untrusted`, not treat uncertainty as a proven draft or pass it to the unknown non-Pi typing fallback. Rationale and known limits belong in `references/troubleshooting.md` §3.

#### Scenario: A real settled editor excludes transcript separators

- **GIVEN** the Pi 0.99.2 real capture `docs/team/reports/P143-verify/logs/tmux-p143-dirty/second-before.frame`, 120×32 pane, cursor row 29, actual editor empty and idle, with a transcript rule at row 21, editor top at 28 and bottom at 30 and the verified footer at 31–32
- **WHEN** the production extraction and frame judgement read the captured frame
- **THEN** the geometry is `[28 30]`, text is empty and the verdict is `EMPTY`; the transcript message and assistant reply above row 28 are not box text
- **AND** a probe that disables the supported-layout admission reads the same bytes as `[21 30]` and `BUSY`, proving the red side uses a real frame

#### Scenario: A real draft in the same layout is still protected

- **GIVEN** `docs/team/reports/P143-verify/logs/tmux-p143-draft-dirty/draft-before.frame`, actual editor `P143-HUMAN-DRAFT`, cursor row 29 and the same footer layout
- **WHEN** the production extraction and `team say dev "draft guard probe"` inspect that pane
- **THEN** text is `P143-HUMAN-DRAFT`, the verdict is `BUSY`, the send is queued, no key is sent, and the editor/frame are unchanged

#### Scenario: A rule-shaped draft cannot borrow the closed-layout exception

- **GIVEN** a real Pi draft containing a 120-character rule, a spinner-shaped line or a footer-shaped line with the cursor before, on or after that text, a status-row clone with the cursor on the clone, and the pre-change equal-width synthetic draft frames
- **WHEN** each capture is read and a different payload is sent
- **THEN** every draft reads `BUSY` or a visibly untrusted geometry, never `EMPTY`; no key is sent; the real wrapping and Unicode terminal-cell measurements are retained
- **AND** enabling a nearest-top or nearest-bottom selection without the closed-layout admission makes the equal-width draft guard test fail

#### Scenario: An ambiguous Pi suffix is held, not guessed empty

- **GIVEN** a Pi frame with a footer mismatch, a clipped editor, scroll-indicator borders, two eligible rectangles or an incomplete redraw
- **WHEN** a send cannot establish the supported rectangle with a trustworthy conservative read
- **THEN** it sends no key, retains a durable payload with reason `geometry-untrusted`, exits non-zero and gives the entry and recovery command rather than claiming a human draft

#### Scenario: An empty box with a package hint row is free

- **GIVEN** a captured pane in the PM-faithful shape: full-rule top and bottom borders, blank content rows and the
  hint row ` k3  Kimi Coding  max` between them, with the cursor on the first blank content row
- **WHEN** the guard is evaluated on that pane
- **THEN** it reports the box free and no key is sent for the message

#### Scenario: A multi-line draft keeps the box busy and survives the send

- **GIVEN** a fixture pane whose box holds three lines and whose cursor sits on the blank row after them
- **WHEN** `team say dev "check the failing test"` runs
- **THEN** the pane still shows those three lines and nothing else, no `Enter` was sent, and `state/outbox/` holds
  exactly one entry whose payload is that message

#### Scenario: The whitespace-only draft is a documented miss

- **GIVEN** a fixture pane whose box holds three spaces and nothing else
- **WHEN** the guard is evaluated on the captured pane
- **THEN** it reports the box free (one known miss of the same class), and `references/troubleshooting.md` §3 names
  that limitation together with the other members of the class (V9-C4)

#### Scenario: A draft containing a rule line keeps the box busy

- **GIVEN** a fixture pane whose box holds a draft of two content rows — `half a sentence` and a short full-rule
  row (a pasted markdown separator) — with the cursor on the blank row after them
- **WHEN** the guard is evaluated on that pane
- **THEN** it reports the box busy (the draft's own rule row is not the box border), no key is sent, and
  `state/outbox/` holds exactly one entry

#### Scenario: A draft below the cursor row keeps the box busy

- **GIVEN** a fixture pane whose box holds a draft that starts on the row below the cursor (a leading newline, or
  an old draft recalled with `Up`)
- **WHEN** the guard is evaluated on that pane
- **THEN** it reports the box busy, no key is sent, and the draft is unchanged

#### Scenario: A draft rule row as wide as the box border keeps the box busy

- **GIVEN** a fixture pane whose box holds a draft containing a full-rule row exactly as wide as the box border
  (or wider than it), with the cursor on a blank row below the draft
- **WHEN** the guard is evaluated on that pane
- **THEN** it reports the box busy (the top border is the highest qualifying row, so the draft's own rule row is
  box content), no key is sent, and the draft is unchanged

#### Scenario: An unknown pane shape delivers as today

- **GIVEN** a busy fixture pane that draws no input-box border under the cursor
- **WHEN** `team say dev "check the failing test"` runs
- **THEN** the message is typed as today, the output warns once that the input-box shape is unknown, and
  `state/outbox/` holds no entry

#### Scenario: A draft appearing before the Enter holds the message

- **GIVEN** a fixture pane that reports an empty box at the check and a non-empty box at the pre-`Enter` re-check
- **WHEN** a send runs
- **THEN** no `Enter` is sent, the fixture's draft is unchanged, and the message is one entry in `state/outbox/`

#### Scenario: A one-line draft on the border-adjacent row keeps the box busy

- **GIVEN** the stored real frame `skills/teamsmith/tests/frames/pi-0.87.0-one-line-draft.txt` (Pi 0.87.0, 120×30
  pane, cursor row 26; provenance in that directory's README) whose located box is `top border / HUMAN-ONE-LINE-DRAFT / bottom border`
- **WHEN** the guard reads that frame (production extraction and the frame-level judgement, cursor row 26)
- **THEN** the read text is the draft, the verdict is `BUSY` / `idle-read=NOT-EMPTY`, and for a payload other than
  the draft `HOLDS_ONLY=no` — the row is content, not the box's status row

#### Scenario: The 0.85.1 status row stays box chrome

- **GIVEN** the stored real frame `skills/teamsmith/tests/frames/pi-0.85.1-update-banner.txt` (Pi 0.85.1, cursor
  row 26) whose located box carries ` deepseek-flash  Deepseek  max` on the border-adjacent row
- **WHEN** the guard reads that frame
- **THEN** the read text is empty and the verdict is `EMPTY` — the measured status-row shape is excluded only
  because the cursor is not on it and its text matches that shape

#### Scenario: A cursor on the border-adjacent row is content whatever the text

- **GIVEN** a frame whose border-adjacent row reads ` k3  Kimi Coding  max` (the status-row shape) and whose cursor
  rests on exactly that row
- **WHEN** the guard reads the frame
- **THEN** the row is content and the verdict is `BUSY` — a row the human's cursor is on is never the box's own
  status row

#### Scenario: A single text row below the cursor row is content

- **GIVEN** a Pi 0.87.0-shaped frame `top border / blank (cursor) / one text row / bottom border` — a draft typed
  after a leading newline with the cursor moved up (the V7-F1 shape in the 0.87.0 layout)
- **WHEN** the guard reads the frame
- **THEN** the text row is content and the verdict is `BUSY` (the shape test does not recognise it), so the draft
  is never pasted over

#### Scenario: The production extraction and the fixture judgement are one implementation

- **GIVEN** the stored frames `pi-0.87.0-one-line-draft.txt` and `pi-0.85.1-update-banner.txt`
- **WHEN** the extraction that `team_input_box_text` performs on a frame and
  `bash skills/teamsmith/tests/pm-box-real.sh --frame <file> --cursor 26` run on each
- **THEN** the texts agree (`HUMAN-ONE-LINE-DRAFT` and empty) and the verdicts agree (`idle-read=NOT-EMPTY` and
  `idle-read=EMPTY`)
- **AND** with the status-row predicate shadowed to the legacy "always chrome" behaviour in the probe process, the
  draft frame flips back to `EMPTY` in both paths — proving they share the predicate instead of re-implementing it

#### Scenario: A meeting knock never lands on a draft

- **GIVEN** a fixture peer pane whose input box holds the draft `half a sentence`, and a meeting whose peer row
  resolves to that pane with `TEAM_MEETING_KNOCK=1`
- **WHEN** `team meeting say <slug> --intent info "…" --knock` runs
- **THEN** the pane still shows exactly that draft and no `Enter` was sent, and the sender's `state/outbox/` holds
  exactly one entry whose payload is the `[meeting:<slug>] …` notice

### Requirement: Delivery is confirmed by the pane, and a queued message is reported as queued

`team say` and `team notify` SHALL report a message deferred behind a trusted non-empty box as queued (exit code 0, the literal token `queued`, never
`已确认送达`). An untrusted-geometry or queue-stalled outcome from *Queue impediments are factual, bounded and recoverable* SHALL instead exit non-zero and name the durable held entry and reason. Both deferral outcomes MUST return before the pane-verification loop, because an untyped message provokes no pane change.
Delivery is confirmed by reading the pane back after the `Enter` (V9-B5): the delivery SHALL count as confirmed
only when the payload has left the box **and** a new submission proof appeared in the conversation area above the
box — the count of the payload's signature there (its first non-blank line, whitespace-stripped, up to 48 bytes,
compared byte-wise) exceeds the count taken before typing, or a `[paste #N +K lines]` bubble whose `+K` equals the
payload's line count newly appears. A box that is merely empty again is NOT proof: a TUI can swallow the `Enter`
(clearing the box without ever submitting — an overlay, escape handling or a redraw), and reporting that shape as
delivered loses the message silently (V9-B5 reproduced it end to end: reported delivered, entry deleted, zero
submissions, no inbox row). A send that cannot produce new proof SHALL be reported as unconfirmed — never as
delivered — and the entry held; a TUI that never echoes submissions (a static-footer pane shows nothing new after
a real submit; V7-F4) honestly degrades to "unconfirmed": the `Enter` did land exactly once, but the tool cannot
prove it, so the entry is held (terminal) with a durable inbox copy for the human to verify and drop. A pane-
fingerprint comparison MUST NOT be used as the confirmation for a readable box. While the box still holds only
the payload the drain SHALL send at most one extra `Enter`; when the box then still is not empty
the drain SHALL move the entry to `outbox/held/` immediately — it MUST NOT wait for the TTL (V8-F4b) —
and it MUST NOT paste the payload again as a second message.
An unconfirmed entry is terminal (V8-F4c): the stuck payload may ride the human's next `Enter` to the agent,
and no automatic path — `team outbox flush --now` included — SHALL paste it again; an unconfirmed
entry MUST NOT be deleted as if delivered. A pane whose box shape cannot be located is typed as today (one
warning) and is NEVER reported as confirmed — its output names the unknown shape instead. A send that
found a draft at the pre-`Enter` re-check is
terminal (V7-F3): the payload already reached the input box once and may have ridden the human's own submit to
the agent, so no automatic path — `team outbox flush --now` included — SHALL paste it again; the entry stays under
`outbox/held/` until the human drops it or re-sends the content explicitly.

#### Scenario: The real second correction reaches the settled fallback once

- **GIVEN** the P143 container recipe with real Pi, no dev inbox watcher, a completed first correction and an idle empty editor
- **WHEN** `P138_SECOND=1 bash docs/team/reports/P143-verify/pkg/run-case.sh tmux-delivery-truth-dirty HEAD 0 host` and its second-message judge run
- **THEN** exactly one second-message reception and backend submission are observed, a later settle occurs, and the judge prints `PASS second say delivered`; the first actual submission is not falsely retained as `draft-raced`, and neither message is duplicated by flush

#### Scenario: A queued message says queued, not delivered

- **GIVEN** a dirty box
- **WHEN** `team say dev "check the failing test"` runs
- **THEN** it exits 0, the output contains `queued` and does not contain `已确认送达`, and `state/outbox/` holds
  exactly one entry for `dev`

#### Scenario: A clean box still confirms delivery

- **GIVEN** an empty box in a fixture pane that renders the message when it arrives
- **WHEN** `team say dev "check the failing test"` runs
- **THEN** the output reports the confirmed delivery and `state/outbox/` stays empty

#### Scenario: An unconfirmed delivery is held, not duplicated

- **GIVEN** one entry and a fixture pane whose input box still shows the payload after the `Enter` and after one
  extra `Enter`
- **WHEN** the drain runs
- **THEN** the payload was pasted once with at most one extra `Enter`, the entry is under `outbox/held/`, and no
  second copy of it exists in the queue

#### Scenario: A cleared box without submission proof is held, never reported delivered

- **GIVEN** one entry and a fixture pane whose TUI swallows the `Enter` (the box clears, the message never
  appears in the conversation area)
- **WHEN** the drain runs
- **THEN** the output never says `已确认送达`, the entry is under `outbox/held/` with reason `unconfirmed` (not
  deleted), a durable copy sits in `docs/team/inbox/<target>.md`, zero submissions happened, and both
  `team outbox flush` and `team outbox flush --now` leave it untouched

#### Scenario: A static-footer pane degrades to unconfirmed and holds

- **GIVEN** a fixture pane that submits normally but never echoes the submission (static footer)
- **WHEN** `team say dev "static footer probe"` runs
- **THEN** exactly one submission happened, the output does not claim a confirmed delivery, the entry is under
  `outbox/held/` (terminal — a later flush pastes nothing), and the inbox holds the durable copy

#### Scenario: A draft-raced entry is never pasted again

- **GIVEN** one entry under `outbox/held/` whose hold reason is `draft-raced`
- **WHEN** `team outbox flush` and `team outbox flush --now` run
- **THEN** the pane receives no key for it, the entry stays under `outbox/held/`, and no `forced.log` line is
  written

#### Scenario: A slow fold is held recoverably and completed by the next drain

- **GIVEN** a fixture pane that folds a large paste but draws the placeholder slower than the bounded mid-render
  wait, so the first drain ends with the half-drawn placeholder still on screen (no `Enter` sent)
- **WHEN** the first `team draft send` returns and a later drain (`team outbox flush`) runs after the render
  finished
- **THEN** the first drain holds the entry with reason `stall-timeout` (not `draft-raced`) and sends no `Enter`;
  the later drain completes the pending submission with exactly one `Enter`, pastes the payload no second time
  (exactly one submission overall), and clears the entry from `held/`

### Requirement: The bottom border is the lowest qualifying rule row below the cursor

Outside the supported closed Pi layout defined in *An automated send never types into a non-empty input box*, when the guard locates the input box from the cursor row, the bottom border SHALL be the **LOWEST** row below the
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
and not a licence to claim that any frame's verdict is monotone. What the gate MUST pin instead: for every pre-change frame
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
