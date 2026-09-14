# meeting Specification

## Purpose

Cross-project peer exchange between PMs: interface work, advice with evidence and problem reports — never commands.
The transcript lives in a shared area outside both projects, so neither side can write into the other's repository.
Why the mechanism has no "order" intent: `references/meeting.md` and `references/philosophy.md` (authority comes
from evidence, not from a title).

## Requirements

### Requirement: Intents are informational, and the mechanism has no way to order

`team meeting say <slug> --intent <intent>` SHALL accept only `info`, `question`, `report`, `proposal` and
`request`. A `command`/`order` intent MUST be rejected, and a message carrying an explicit order marker
(`[order]`, `[command]`) MUST be refused as well.

#### Scenario: An unknown intent is refused

- **WHEN** `team meeting say <slug> --intent command "do X"` runs
- **THEN** the command exits non-zero and prints the allowed intents

#### Scenario: An order marker is refused

- **WHEN** `team meeting say <slug> --intent info "[order] deploy that now"` runs
- **THEN** the command exits non-zero and the transcript gains no entry

### Requirement: The shared area is the single source of truth

Every meeting SHALL live under `TEAM_MEETINGS_DIR` (`~/.pi/team/meetings/<slug>/`), with an append-only
`transcript/NNN_<project>_<intent>.md` as the authoritative record, plus `state.env`, `agenda.md`, `agreements/`
and per-project read positions. Reading and replying MUST work by file inspection, and the knock MUST be an
optional notification on top.

#### Scenario: A message is readable without any notification

- **GIVEN** `team meeting say <slug> --intent report "…"` ran with `TEAM_MEETING_KNOCK=0`
- **WHEN** the other project runs `team meeting read <slug>`
- **THEN** the message text is printed from the transcript file, and the read position is advanced

### Requirement: Only a human terminal may speak as the user

`--as-user` SHALL be refused when stdout/stdin is not a terminal, and MUST additionally require
`TEAM_MEETING_ALLOW_USER_ID` to be `1`, `yes` or `true`; the message then carries the sender `user` instead of the
project name.

#### Scenario: A non-interactive caller cannot impersonate the user

- **GIVEN** `TEAM_MEETING_ALLOW_USER_ID=1` and a non-tty invocation
- **WHEN** `team meeting say <slug> --as-user --intent info "…"` runs
- **THEN** it exits non-zero with a message that `--as-user` is for human terminals only

#### Scenario: The switch alone is not enough in a non-tty

- **GIVEN** a non-tty invocation with `TEAM_MEETING_ALLOW_USER_ID` unset
- **WHEN** `team meeting say <slug> --as-user --intent info "…"` runs
- **THEN** it exits non-zero and the transcript is unchanged

### Requirement: Consensus needs both sides

An agreement SHALL be recorded as `agreements/<id>.md` and MUST NOT be confirmed by its proposer; `team meeting
agree <slug> <id>` from the proposing project MUST be refused, and confirmation MUST be accepted once per project.
Each side lands its own half in its own project; a confirmed agreement MUST NOT trigger any write in the peer's
project.

#### Scenario: A project cannot agree with itself

- **GIVEN** `agreements/A1.md` with `proposer: alpha` and the current project is `alpha`
- **WHEN** `team meeting agree <slug> A1` runs
- **THEN** it exits non-zero and says the agreement must be confirmed by the other side

#### Scenario: The other side's confirmation is recorded

- **GIVEN** the current project is `beta`
- **WHEN** `team meeting agree <slug> A1` runs
- **THEN** `agreements/A1.md` gains `agreed-by: beta`, and the command prints that each side lands its own half

### Requirement: Meetings are bounded

A meeting SHALL carry a TTL (`TEAM_MEETING_TTL_HOURS`, default 72) and a per-side message cap
(`TEAM_MEETING_MAX_TURNS`, default 20); `team meeting say` MUST refuse further messages once the cap is reached, and
`team meeting close` SHALL be the only way to end a meeting (with `--yes`, because it changes shared state).

#### Scenario: The turn cap refuses the next message

- **GIVEN** this project already wrote `TEAM_MEETING_MAX_TURNS` messages in the meeting
- **WHEN** `team meeting say <slug> --intent info "one more"` runs
- **THEN** it exits non-zero and names the cap

### Requirement: Zero writes into the peer project

A meeting command SHALL write only inside `TEAM_MEETINGS_DIR` (and, with a knock, type a notification into the
peer's registered PM window). It MUST NOT create, modify or delete files in the peer's repository, and it MUST NOT
run git in the peer's worktree.

#### Scenario: A full exchange leaves the peer repository untouched

- **GIVEN** a peer project registered via `team meeting peer <slug> <project>:<session>`
- **WHEN** `open`, `say`, `read`, `propose`, `agree` and `close` have all run
- **THEN** the peer project's `git status --porcelain` is unchanged and no new file exists under its main worktree
