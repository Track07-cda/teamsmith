## MODIFIED Requirements

### Requirement: Pending work is defined, and no work means no wake-up

A patrol tick SHALL append one line to `.pi/team/state/capacity.log` and then wake the PM only when there is pending
work: an unread notification, a task report without a review record, a `blocked` board row, an agent whose recorded
task is unfinished but whose window is gone, or (only with `TEAM_WATCH_PENDING_BOARD=1`) `todo`/`wip` board rows.
With nothing pending it MUST do nothing beyond the log line: no message typed into the PM window and no PM start.

The wake line goes through the delivery guard (`delivery-guard`): it is typed only while the PM's input box is free,
otherwise it is held in the outbox instead of typed, while the tick still records the pending batch and
`state/nudges.log` keeps the nudge record.

#### Scenario: Nothing pending is silent

- **GIVEN** an empty inbox, no reports awaiting review, no blocked rows and no stopped agent with an unfinished task
- **WHEN** `team watch --once` runs
- **THEN** `state/capacity.log` gains one line and the PM window receives no new text

#### Scenario: An unread notification wakes the PM

- **GIVEN** `docs/team/inbox/pm.md` contains an unread line
- **WHEN** `team watch --once` runs
- **THEN** the tick logs the pending batch and the PM window receives one `[watchdog] pending: …` line


#### Scenario: A dirty PM input box holds the wake instead of gluing it

- **GIVEN** `docs/team/inbox/pm.md` contains an unread line and the PM window's input box holds a draft
- **WHEN** `team watch --once` runs
- **THEN** the PM window still shows exactly that draft, `state/nudges.log` gained one line, and `state/outbox/` holds
  one entry whose payload is the `[watchdog] pending: …` text
