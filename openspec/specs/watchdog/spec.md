# watchdog Specification

## Purpose

Wake the PM only when there is work: one patrol loop in a tmux window of the same session, a precise definition of
"pending", a stand-down switch, and limits so a broken PM cannot be restarted forever. Why this shape (and why the
watchdog is not a heartbeat): `references/workflows.md` §I and `references/philosophy.md` (govern less).

## Requirements

### Requirement: One backend, inside the team's tmux session

`team watchdog up` SHALL run the patrol in a window named `TEAM_WATCH_WINDOW` (default `watchdog`) of the session
`TEAM_SESSION`, and that window MUST also serve as the status monitor (`team monitor`). The watchdog MUST NOT depend
on a container, a systemd unit or any second backend; `status`, `logs`, `restart` and `down` SHALL act on that one
window.

#### Scenario: Up creates exactly one patrol window

- **WHEN** `team watchdog up` runs in a project whose session exists
- **THEN** `tmux list-windows -t <session>` contains exactly one `watchdog` window
- **AND** `team watchdog status` reports the tmux backend, the interval and that window

#### Scenario: Down removes it

- **WHEN** `team watchdog down` runs
- **THEN** the `watchdog` window is gone and `team watchdog status` reports that the watchdog is not running

### Requirement: Pending work is defined, and no work means no wake-up

A patrol tick SHALL append one line to `.pi/team/state/capacity.log` and then wake the PM only when there is pending
work: an unread notification, a task report without a review record, a `blocked` board row, an agent whose recorded
task is unfinished but whose window is gone, or (only with `TEAM_WATCH_PENDING_BOARD=1`) `todo`/`wip` board rows.
With nothing pending it MUST do nothing beyond the log line: no message typed into the PM window and no PM start.

#### Scenario: Nothing pending is silent

- **GIVEN** an empty inbox, no reports awaiting review, no blocked rows and no stopped agent with an unfinished task
- **WHEN** `team watch --once` runs
- **THEN** `state/capacity.log` gains one line and the PM window receives no new text

#### Scenario: An unread notification wakes the PM

- **GIVEN** `docs/team/inbox/pm.md` contains an unread line
- **WHEN** `team watch --once` runs
- **THEN** the tick logs the pending batch and the PM window receives one `[watchdog] pending: …` line

### Requirement: Repeated reminders for the same batch are rate limited

The watchdog SHALL NOT repeat a reminder for an unchanged pending batch more often than `TEAM_WATCH_NUDGE_GAP`
seconds (default 900).

#### Scenario: The second tick stays quiet

- **GIVEN** a pending batch that was already nudged, less than `TEAM_WATCH_NUDGE_GAP` seconds ago
- **WHEN** `team watch --once` runs again
- **THEN** no new `[watchdog] pending:` line is typed into the PM window

### Requirement: Standby stops the wake-ups but keeps the backlog visible

With `team standby on --reason "…"`, patrol ticks MUST NOT nudge or start the PM; the pending work MUST still be
written to `state/watchdog.log`, and `team standby status` SHALL report that standby is on together with the reason.
`team standby off` restores the wake-ups.

#### Scenario: Standby suppresses the nudge

- **GIVEN** `team standby on --reason "waiting for the user"` and a pending batch
- **WHEN** `team watch --once` runs
- **THEN** the PM window receives no nudge, the tick is logged in `state/watchdog.log`, and
  `team standby status` reports standby on with that reason

### Requirement: Restart quota and capacity logging

The watchdog SHALL start the PM at most `TEAM_WATCH_MAX_RESTARTS` times per hour (default 5). Beyond that it MUST
stop starting the PM and warn instead. Each tick MUST append one line to `.pi/team/state/capacity.log`
(timestamp + RAM/swap/agent estimate) so capacity has a trend, not just a current value.

#### Scenario: The quota refuses further restarts

- **GIVEN** the PM is not running and the restart log already shows `TEAM_WATCH_MAX_RESTARTS` starts in the last hour
- **WHEN** a tick with pending work runs
- **THEN** it does not start a PM process and logs a warning about the exceeded quota

#### Scenario: Capacity is recorded per tick

- **WHEN** two patrol ticks run
- **THEN** `state/capacity.log` has two new lines, each with a timestamp and the memory/swap figures

### Requirement: The watchdog never manages tmux layout, agents or quota

The watchdog SHALL NOT rebuild a missing session or window while `TEAM_WATCH_REBUILD_TMUX=0` (the default) — it
reports the state instead; it MUST NOT resume stopped agents; and it MUST NOT merge, change the board or spend model
quota. Those are the PM's calls (`team up`, `team resume`).

#### Scenario: A missing window is reported, not rebuilt

- **GIVEN** `TEAM_WATCH_REBUILD_TMUX=0` and no PM window in the session
- **WHEN** a tick runs
- **THEN** the tick output reports the missing window and creates no new tmux window

#### Scenario: A stopped agent is not resumed

- **GIVEN** an agent with a recorded unfinished task whose window does not exist
- **WHEN** a tick runs with pending work
- **THEN** the agent is listed as pending work for the PM, and no agent window is started
