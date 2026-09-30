## MODIFIED Requirements

### Requirement: Pending work is defined, and no work means no wake-up

A patrol tick SHALL append one line to `.pi/team/state/capacity.log` and then wake the PM only when there is pending
work: an unread notification, a task report without a review record, a `blocked` board row, an agent whose recorded
task is unfinished but whose window is gone, an unread peer turn in a meeting this project participates in and that
is not closed (a meeting that is expired but not closed still counts; the count comes from the meeting's
per-project read position and MUST NOT include this project's own turns), or (only with
`TEAM_PULSE_PENDING_BOARD=1`) `todo`/`wip` board rows. The pending summary SHALL name the unread-meeting count
(`未读会议 N`) so the nudge text carries it. With nothing pending it MUST do nothing beyond the log line: no message
typed into the PM window and no PM start.

#### Scenario: Nothing pending is silent

- **GIVEN** an empty inbox, no reports awaiting review, no blocked rows and no stopped agent with an unfinished task
- **WHEN** `team watch --once` runs
- **THEN** `state/capacity.log` gains one line and the PM window receives no new text

#### Scenario: An unread notification wakes the PM

- **GIVEN** `docs/team/inbox/pm.md` contains an unread line
- **WHEN** `team watch --once` runs
- **THEN** the tick logs the pending batch and the PM window receives one `[pulse] pending: …` line

#### Scenario: A dirty PM input box holds the wake instead of gluing it

- **GIVEN** `docs/team/inbox/pm.md` contains an unread line and the PM window's input box holds a draft
- **WHEN** `team watch --once` runs
- **THEN** the PM window still shows exactly that draft, `state/nudges.log` gained one line, and `state/outbox/` holds
  one entry whose payload is the `[pulse] pending: …` text

#### Scenario: An unread peer turn wakes the PM

- **GIVEN** a meeting this project participates in with exactly one peer turn after this project's read position,
  the inbox empty, no reports awaiting review, no blocked rows and no stopped agent with an unfinished task
- **WHEN** `team watch --once` runs
- **THEN** `state/capacity.log` gains one line, `state/watchdog.log` names the pending batch with `未读会议 1`, and
  the PM window receives one `[pulse] pending: …` line

#### Scenario: Reading the peer turn makes the next tick silent

- **GIVEN** that meeting after `team meeting read <slug>` advanced this project's read position, with nothing else
  pending
- **WHEN** `team watch --once` runs
- **THEN** `state/capacity.log` gains one line and the PM window receives no new text

#### Scenario: This project's own turn is not pending

- **GIVEN** a meeting whose only transcript turn was written by this project with `team meeting say`, and nothing
  else pending
- **WHEN** `team watch --once` runs
- **THEN** `state/capacity.log` gains one line and the PM window receives no new text

