## ADDED Requirements

### Requirement: A fixture's input-box judgement distinguishes an unexpected overlay

Fixtures that judge a TUI pane's input box from a captured frame — the real-pane fixture
`skills/teamsmith/tests/pm-box-real.sh` and the frame-level judgement it shares with the correctness gate — SHALL
distinguish an **unexpected overlay** from a non-empty input box. An overlay is a whole-pane modal that has
replaced the TUI's normal input state; the measured case is Pi's project-trust prompt (`Trust project folder?` …
`Do not trust`), drawn for a project whose `.pi/skills/` the fixture's own `team init` installed. A fixture MUST
NOT report an overlay as `idle-read=NOT-EMPTY`: that token asserts that the input box holds text, and the measured
prompt holds none — the frame made the judgement locate no box below the pane's cursor (so the fixture's
`EMPTY`-only check called it a draft), and with the cursor inside the prompt it paired the prompt's own rule rows
and read the question and options as box content.

The fixture's readiness wait SHALL release only on the TUI's real input state — an input box the judgement
locates whose text is empty — and not on the first full-rule row in the pane, because the prompt's frame carries
rule rows that satisfy a bare rule-row wait. When the wait expires with an overlay present, the fixture MUST name
the overlay in its output, keep the last frame for the report, and exit non-zero **without typing anything into
the overlay**: the payload steps MUST NOT run on a pane whose input box was never located.

The real-pane fixture SHALL reach that empty input box in a project `team init` provisioned with `.pi/skills/`
installed, with no interactive trust decision and with no trust decision written to Pi's store. It MUST NOT remove
the project-local install to dodge the prompt (that would drop the shape the fixture exists to exercise), and it
MUST NOT answer the prompt by hand; the trust override it starts Pi with applies to the single run and leaves Pi's
trust store untouched. The overlay classification SHALL be exercised by a stored real frame (the
`skills/teamsmith/tests/frames/` convention) with a visible red side: with the overlay predicate disabled, the
same frame MUST be judged a draft (never `EMPTY`), so the classification is falsifiable rather than vacuous.

#### Scenario: The stored trust-prompt frame is an overlay, not a draft

- **GIVEN** the real frame `skills/teamsmith/tests/frames/pi-0.87.0-project-trust-prompt.txt` (Pi 0.87.0, private
  tmux socket, 120×30 pane, `--no-session`; provenance and cursor row recorded in that directory's README) and the
  fixture's frame-level judgement
- **WHEN** `bash skills/teamsmith/tests/pm-box-real.sh --frame
  skills/teamsmith/tests/frames/pi-0.87.0-project-trust-prompt.txt --cursor <row>` runs
- **THEN** it exits 0, prints `overlay=trust-prompt`, and does not print `idle-read=NOT-EMPTY`
- **AND** with the overlay predicate disabled (`M24_OVERLAY_DETECT=0` in the same command) it exits non-zero and
  prints `idle-read=NOT-EMPTY` — the red side proving the predicate is what changes the verdict, not the frame

#### Scenario: A real pane reaches the empty box in a provisioned project

- **GIVEN** a project provisioned by `team init` (`<main worktree>/.pi/skills/teamsmith` installed) and a real Pi
  in a private tmux socket, with Pi's trust store not carrying a decision for the project
- **WHEN** `bash skills/teamsmith/tests/pm-box-real.sh --idle-secs 3` runs, and `bash
  skills/teamsmith/tests/container-tmux.sh --with-pi --cmd "bash skills/teamsmith/tests/pm-box-real.sh --idle-secs 3"`
  runs it again in the pinned image whose HOME carries no trust store
- **THEN** both runs exit 0, both print `M45 idle-read=EMPTY ok` and `RETRACT=ok`, and neither frame carries the
  `Trust project folder?` overlay
- **AND** the project-local `.pi/skills/teamsmith` entry is still installed after the run, and the container run
  created no `trust.json` under its HOME — the prompt was neither dodged by removing the install nor answered

#### Scenario: An overlay stops the fixture before it types

- **GIVEN** the same fixture in its documented overlay mode, which starts Pi without the single-run trust override
  so the project-trust prompt is on screen
- **WHEN** `bash skills/teamsmith/tests/pm-box-real.sh --idle-secs 3 --expect-overlay` runs
- **THEN** it exits 0 after printing `overlay=trust-prompt`, and its output carries no payload step
  (`deliver_text_lines=` does not appear) and no `idle-read=NOT-EMPTY` — nothing was typed into the prompt
