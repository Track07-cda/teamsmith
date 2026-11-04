## MODIFIED Requirements

### Requirement: An automated send never types into a non-empty input box

The protected automated senders (`team notify`'s pane delivery, the watchdog wake line, the notify extension's
knock, the meeting knock, ordinary `team draft send` and ordinary queued pane delivery) SHALL locate the target
pane's input box from the captured pane and, when the box holds text, MUST send no key at all — neither the payload nor an `Enter`; it MUST hold the message
in `state/outbox/` instead. Default `team say` with no usable watcher and explicit `draft send --now` /
`outbox flush --now` are direct-attempt exceptions, not protected sends; their scope and audit are specified in
*Which senders defer is explicit, and `--now` is the audited override*. A watched say sends no keys regardless of
editor content. The check MUST be cursor-anchored (the box is not pinned to the pane bottom, so the
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
- **WHEN** the production extraction and ordinary `team draft send <file>` with payload `draft guard probe` inspect that PM pane
- **THEN** text is `P143-HUMAN-DRAFT`, the verdict is `BUSY`, the send is queued, no key is sent, and the editor/frame are unchanged

#### Scenario: A rule-shaped draft cannot borrow the closed-layout exception

- **GIVEN** a real Pi draft containing a 120-character rule, a spinner-shaped line or a footer-shaped line with the cursor before, on or after that text, a status-row clone with the cursor on the clone, and the pre-change equal-width synthetic draft frames
- **WHEN** each capture is read and an ordinary draft send attempts a different payload
- **THEN** every draft reads `BUSY` or a visibly untrusted geometry, never `EMPTY`; no key is sent; the real wrapping and Unicode terminal-cell measurements are retained
- **AND** enabling a nearest-top or nearest-bottom selection without the closed-layout admission makes the equal-width draft guard test fail

#### Scenario: An ambiguous Pi suffix is held, not guessed empty

- **GIVEN** a Pi frame with a footer mismatch, a clipped editor, scroll-indicator borders, two eligible rectangles or an incomplete redraw
- **WHEN** a protected send cannot establish the supported rectangle with a trustworthy conservative read
- **THEN** it sends no key, retains a durable payload with reason `geometry-untrusted`, exits non-zero and gives the entry and recovery command rather than claiming a human draft

#### Scenario: An empty box with a package hint row is free

- **GIVEN** a captured pane in the PM-faithful shape: full-rule top and bottom borders, blank content rows and the
  hint row ` k3  Kimi Coding  max` between them, with the cursor on the first blank content row
- **WHEN** the guard is evaluated on that pane
- **THEN** it reports the box free and no key is sent for the message

#### Scenario: A multi-line draft keeps the box busy and survives the send

- **GIVEN** a fixture pane whose box holds three lines and whose cursor sits on the blank row after them
- **WHEN** ordinary `team draft send <file>` with payload `check the failing test` runs
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
- **WHEN** ordinary `team draft send <file>` with payload `check the failing test` runs
- **THEN** the message is typed as today, the output warns once that the input-box shape is unknown, and
  `state/outbox/` holds no entry

#### Scenario: A draft appearing before the Enter holds the message

- **GIVEN** a fixture pane that reports an empty box at the check and a non-empty box at the pre-`Enter` re-check
- **WHEN** a protected send runs
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

Protected senders and ordinary queued pane delivery SHALL report a message deferred behind a trusted non-empty box as queued (exit code 0, the literal token `queued`, never
`已确认送达`). An untrusted-geometry or queue-stalled outcome from *Queue impediments are factual, bounded and recoverable* SHALL instead exit non-zero and name the durable held entry and reason. Both deferral outcomes MUST return before the pane-verification loop, because an untyped message provokes no pane change.
A default say direct attempt SHALL instead report that it attempted immediate sending without confirmation of
model receipt, whether the editor was clean or dirty. It MUST NOT claim confirmed delivery from a snapshot
change, an exit code or a `forced.log` line, and MUST NOT mention a say `--now` option. A watched say SHALL report
the durable inbox/spool handoff and zero keys, not that the model has already received or acted on it. A real
watch-path queued/held outcome SHALL retain its factual outcome rather than automatically alleging a draft.
The direct-attempt path retains its best-effort tmux behavior; failure there MUST NOT be presented as a confirmed
receipt or as an automatically queued retry. No new global recovery guarantee is introduced.
For guarded pane delivery, delivery is confirmed by reading the pane back after the `Enter` (V9-B5): the delivery SHALL count as confirmed
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

- **GIVEN** the shipped real-Pi container recipe at a frozen revision, pinned verdict runtime 0.99.2, no dev inbox watcher, a completed first correction and an idle empty editor
- **WHEN** its second default say runs and the matching single-run second-message judge reads the request, event and frame evidence
- **THEN** exactly one second-message reception and backend submission are observed, a later settle occurs and the judge prints `PASS second say delivered`; neither direct attempt creates a pending queue entry or is duplicated by flush, while the CLI still describes an attempt rather than confirmed model receipt

#### Scenario: A queued message says queued, not delivered

- **GIVEN** a dirty box
- **WHEN** ordinary `team draft send <file>` to PM with payload `check the failing test` runs
- **THEN** it exits 0, the output contains `queued` and does not contain `已确认送达`, and `state/outbox/` holds
  exactly one entry for `pm`

#### Scenario: A clean box still confirms delivery

- **GIVEN** an empty box in a fixture pane that renders the message when it arrives
- **WHEN** ordinary `team draft send <file>` to PM with payload `check the failing test` runs
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
- **WHEN** ordinary `team draft send <file>` to PM with payload `static footer probe` runs
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

### Requirement: Which senders defer is explicit, and `--now` is the audited override

`team say` SHALL prefer a valid live inbox-watch route, for clean and dirty boxes alike. After selecting that
route, inbox/spool persistence failure or route loss during the handoff MUST NOT trigger a blind direct fallback
in that attempt; the pending payload and factual failure outcome SHALL remain recoverable through the existing
Outbox. With no usable watcher, say SHALL attempt the existing forced direct send by default, including into a
draft, only after the existing recipient, team-session, offline, dead-pane and empty-shell checks permit it.
An invalid, stale, dead or foreign-project watcher registration is not evidence of delivery and MUST NOT by itself
authorize typing: the ordinary no-watch target checks still apply. The normal no-watch direct attempt creates no
active Outbox entry and does not require a later flush. Selecting watch MUST send zero keys and create no forced
record. If persistence of the initial watch queue entry itself fails, the command SHALL exit non-zero and
report that failure without claiming a nonexistent queued entry, inbox fallback or confirmed delivery; it MUST
NOT type as a fallback.
Each actual default say direct attempt SHALL append exactly one line to the existing
`state/outbox/forced.log`, preserving its timestamp and `kind`, `from`, `target`, `entry` field order and spelling
(`kind=say`, `from=pm`, `entry=none`). The record is an audit of bypassing the draft guard, not evidence that Pi
accepted the message. `team say --now` SHALL be rejected as an unknown flag, without an alias or delivery side
effects. `--any` and `--no-verify` keep their existing semantics; the latter only suppresses the direct attempt's
snapshot/wait/extra-Enter behavior, not recipient, route or target checks.
Protected senders continue to defer behind drafts. `team draft send --now` and `team outbox flush --now` retain
their existing explicit override behavior and audit; an ordinary later drain of a queued `kind=say` entry MUST NOT
inherit say's new direct default. A `team dispatch` prompt SHALL NOT be
deferred by the guard (it travels as the agent CLI's argument, not through the input box), a meeting knock SHALL
defer on a busy peer box and its entry SHALL target the registered peer `session:window` (the knock is the one
sender whose target is outside the team session, and the meeting registration is what authorizes it), and with
`TEAM_NOTIFY_TMUX=0` no knock is attempted and no queue entry is created.
When `TMUX` is unset (a non-tmux shell, CI) the knock path is likewise not attempted and no queue entry is created,
but the command MUST say so with one warning line instead of staying silent (V7-F6); the inbox record is written in
all cases.

#### Scenario: Default say attempts the old forced action on the same dirty box

- **GIVEN** independent real-Pi runs with identical genuine non-empty draft bytes and no watcher: baseline default say, baseline say with `--now`, and candidate default say
- **WHEN** each sends the same single-line correction without clearing the draft or flushing the queue
- **THEN** baseline default queues with no model request; baseline `--now` and candidate default submit the draft followed by the correction in the same actual model request, each adding exactly one existing-format forced line and no active queue entry
- **AND** before/after frames and backend request bytes demonstrate that equivalence; candidate output describes an immediate attempt, not confirmed receipt

#### Scenario: A clean no-watch box also uses the default direct attempt

- **GIVEN** a running permitted target, an empty editor and no usable watcher
- **WHEN** default say runs
- **THEN** it attempts the old direct action without a flush, adds one forced line and no active queue entry, and reports an attempt rather than confirmed receipt

#### Scenario: Say's retired flag has no side effects in either position

- **GIVEN** fingerprints of target key events, inbox, spool, forced log and active/held Outbox in an isolated project
- **WHEN** `team say --now dev "correction"` and `team say dev "correction" --now` run separately
- **THEN** each exits 2 through the unknown-flag path naming `--now`, and every fingerprint remains unchanged

#### Scenario: Watched say never takes the force shortcut

- **GIVEN** a valid live watcher, once with an empty editor and once with a genuine draft
- **WHEN** default say runs
- **THEN** the normal successful handoff writes one durable inbox message and one spool wake, sends zero keys, leaves the draft unchanged and adds no forced line; eventual model receipt is evidenced separately and occurs once

#### Scenario: A selected watch handoff fails without typing

- **GIVEN** a watcher accepted for this say attempt, with inbox or spool persistence failing, or its route disappearing before handoff
- **WHEN** default say attempts the handoff
- **THEN** no key or forced line is produced, the payload remains in the existing queue/held recovery path, and output distinguishes pending or failed handoff from watched success and model receipt

#### Scenario: Initial watch queue persistence failure is an error, not delivery

- **GIVEN** a selected valid watch route whose initial queue entry cannot be persisted
- **WHEN** default say attempts the handoff
- **THEN** it exits non-zero naming the persistence failure, sends zero keys, adds no forced line and claims neither a queued entry nor offline inbox success

#### Scenario: --now types into a dirty box and is logged

- **GIVEN** dirty boxes without watchers, protected notify/automatic completion/meeting/Pulse/draft sends, and nonterminal versus terminal queued entries
- **WHEN** those protected sends, an ordinary flush and explicit `draft send --now` / `outbox flush --now` are exercised separately
- **THEN** protected sends and ordinary drains do not type into the drafts; `outbox flush --now` types into the dirty box and logs one line naming its sender, target and entry, and `draft send --now` keeps its prior audit and action; terminal `draft-raced` or `unconfirmed` entries are never repasted

#### Scenario: Direct-send transport trouble is not a receipt or an automatic queue promise

- **GIVEN** a permitted no-watch say target and a recorded tmux payload/Enter failure during the old best-effort direct action
- **WHEN** default say returns
- **THEN** its immediate-attempt wording never claims model receipt, confirmed pane delivery or automatic queueing; the forced record alone does not prove a successful submission

#### Scenario: The inbox-only switch creates no queue entry

- **GIVEN** `TEAM_NOTIFY_TMUX=0` and a dirty PM box
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** `docs/team/inbox/pm.md` gains one line and `state/outbox/` stays empty

#### Scenario: A queued knock drains to the registered peer window

- **GIVEN** one queued meeting-knock entry in the sender's `state/outbox/` and the peer box cleared
- **WHEN** the sender's next drain runs
- **THEN** the notice is typed into the registered `<peer-session>:<peer-window>` and the entry leaves the queue

### Requirement: The input-box verdict tolerates pi's update banner

When pi draws an update banner (`Update Available` / `Package Updates Available`, a block of full-width rule rows
that have the same shape as the input box's borders) directly above the input box, the guard SHALL still locate the
real box and judge it by its content: an idle empty box MUST be judged `EMPTY`, a box holding a real draft MUST be
judged `HOLDS_ONLY=yes` for that draft, and the retraction path MUST report `RETRACT=ok`. The banner MUST NOT be
read as box content, and a real draft MUST NOT be swallowed as banner text. The tolerance MUST NOT be obtained by
turning pi's update check off: no command or fixture of the tool SHALL set `PI_OFFLINE`, `PI_SKIP_VERSION_CHECK` or
any equivalent, and the guard's verdicts MUST hold in the frame pi actually draws — banner present or absent.

The exclusion MUST be conservative in both directions: box rows MUST be found from the cursor, and when excluding
a suspected banner leaves no usable box, the guard MUST fall back to its pre-existing judgement instead of
concluding that the box is empty; a draft that itself looks like a banner block MUST stay box content, so an
unlucky draft cannot open the box and let a send paste over it.

#### Scenario: An idle empty box under a real banner reads empty

- **GIVEN** a captured real pane frame of pi with an update banner above the input box (`tests/frames/`) and the
  cursor on the box's content row
- **WHEN** the guard locates and reads the box
- **THEN** the located geometry is the input box's (not the banner's border) and the box text is empty, so the
  caller's verdict is `EMPTY`

#### Scenario: A real draft under the banner is still the draft

- **GIVEN** a frame with the banner block above a box holding `半句草稿 half a sentence`
- **WHEN** the guard reads the box and compares it with that payload
- **THEN** the read text is the draft, `HOLDS_ONLY=yes`, and the geometry is unchanged by the banner

#### Scenario: A draft that looks like a banner is not eaten

- **GIVEN** a frame whose box content is a block shaped like the update banner (a full rule row, a header, a
  `Changelog:` line, a full rule row), and a frame where excluding the suspected banner leaves no locatable box
- **WHEN** the guard reads the box in each
- **THEN** the content is still read as box content (never `EMPTY`), and the no-box frame falls back to the
  conservative judgement rather than sending keys

#### Scenario: The end-to-end delivery holds in a banner frame

- **GIVEN** a pane whose TUI draws the banner above the box, once empty and once holding a draft
- **WHEN** a protected `team notify` or ordinary `team draft send` delivers into the empty one and into the drafted one
- **THEN** the empty box receives the payload and exactly one submit happens; the drafted box receives no key, the
  draft is unchanged, and the send is reported as queued

#### Scenario: The update check stays on

- **GIVEN** the real-pi box fixture, which starts pi without `PI_OFFLINE`/`PI_SKIP_VERSION_CHECK` and reports
  `banner=present|absent` for the frame it inspected
- **WHEN** it is asked to require a banner (`M45_REQUIRE_BANNER=1`) on a run where pi drew none
- **THEN** it fails and states that the run is not banner evidence, instead of reporting the banner shape as
  exercised; on a run with a banner the `EMPTY`/`RETRACT=ok` verdicts are recorded in that same frame

### Requirement: Queue impediments are factual, bounded and recoverable

For protected senders and queued deliveries (not default say's direct-attempt exception), a draft-clearing explanation SHALL be emitted only for a trustworthy non-empty box read. A `geometry-untrusted` outcome SHALL send no key, durably hold the payload, exit non-zero and name the entry, target, reason and recovery command. It MUST NOT state that the human has a draft or promise that clearing the box will automatically deliver it.

For an entry that has not touched the input box, three consecutive eligible drain evaluations that read a trusted empty box but leave the entry queued without progress SHALL move it to durable `held/` with reason `queue-stalled` by the third evaluation. An eligible evaluation is one that owns the entry's claim, has a live target and is not blocked by an earlier entry or another delivery in progress; queueing during work, real drafts, lock contention and offline targets MUST NOT be counted as this empty-box defect. The diagnostic SHALL record the entry id, target, first/last observation time, consecutive count, read verdict and geometry/trust reason, and its durable full-text path. Enqueue, bounded retry, tick and flush SHALL use the same observation rule. A later busy/working read resets the consecutive-empty count; the payload and original immutable entry header MUST NOT be rewritten to track attempts.

The obstructing command SHALL print `held`, the reason and the recovery command and exit non-zero. `team outbox list`, `team status` and `team digest` SHALL expose a nonzero impeded count and the reason while such an entry exists. Geometry/stall holds MUST NOT bypass terminal `draft-raced` or `unconfirmed` protections: once any payload reached the box, later drains never repaste it. A never-typed hold MAY be retried only after fresh trusted geometry permits it. Observer commands MUST NOT advance attempt counts, emit a wake or mutate the queue. The existing TTL remains a backstop, not the first indication of this defect. Rationale belongs in `references/troubleshooting.md` §3.

#### Scenario: Untrusted geometry is not a draft-clearing promise

- **GIVEN** a replay of the real P143 frame with an invalidated supported-layout/footer premise and no trustworthy conservative box read
- **WHEN** ordinary `team draft send <file>` with payload `geometry diagnostic` runs
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
