# delivery-guard delta · 2026-09 回填：pi's update banner above the input box (M45)

## ADDED Requirements

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
- **WHEN** `team notify`/`team say` delivers into the empty one and into the drafted one
- **THEN** the empty box receives the payload and exactly one submit happens; the drafted box receives no key, the
  draft is unchanged, and the send is reported as queued

#### Scenario: The update check stays on

- **GIVEN** the real-pi box fixture, which starts pi without `PI_OFFLINE`/`PI_SKIP_VERSION_CHECK` and reports
  `banner=present|absent` for the frame it inspected
- **WHEN** it is asked to require a banner (`M45_REQUIRE_BANNER=1`) on a run where pi drew none
- **THEN** it fails and states that the run is not banner evidence, instead of reporting the banner shape as
  exercised; on a run with a banner the `EMPTY`/`RETRACT=ok` verdicts are recorded in that same frame
