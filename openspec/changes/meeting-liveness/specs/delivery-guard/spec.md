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
the pairing finds no box and the pane is typed as today with one warning). When several rows qualify, the top border is the HIGHEST qualifying row above the
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


### Requirement: Which senders defer is explicit, and `--now` is the audited override

`team say` SHALL defer for every target whose box is busy (worker targets included, not only the PM); `team say
--now` and `team outbox flush --now` SHALL type immediately even into a non-empty box and SHALL append one line
naming the sender, the target and the entry to `state/outbox/forced.log`. A `team dispatch` prompt SHALL NOT be
deferred by the guard (it travels as the agent CLI's argument, not through the input box), a meeting knock SHALL
defer on a busy peer box and its entry SHALL target the registered peer `session:window` (the knock is the one
sender whose target is outside the team session, and the meeting registration is what authorizes it), and with
`TEAM_NOTIFY_TMUX=0` no knock is attempted and no queue entry is created.
When `TMUX` is unset (a non-tmux shell, CI) the knock path is likewise not attempted and no queue entry is created,
but the command MUST say so with one warning line instead of staying silent (V7-F6); the inbox record is written in
all cases.

#### Scenario: --now types into a dirty box and is logged

- **GIVEN** a dirty box
- **WHEN** `team say dev "check the failing test" --now` runs
- **THEN** the pane holds the draft followed by the message (today's behaviour), and `state/outbox/forced.log` gained
  one line naming `say` and the target

#### Scenario: The inbox-only switch creates no queue entry

- **GIVEN** `TEAM_NOTIFY_TMUX=0` and a dirty PM box
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** `docs/team/inbox/pm.md` gains one line and `state/outbox/` stays empty

#### Scenario: A queued knock drains to the registered peer window

- **GIVEN** one queued meeting-knock entry in the sender's `state/outbox/` and the peer box cleared
- **WHEN** the sender's next drain runs
- **THEN** the notice is typed into the registered `<peer-session>:<peer-window>` and the entry leaves the queue

