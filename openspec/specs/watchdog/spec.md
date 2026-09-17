# watchdog Specification

## Purpose

Wake the PM only when there is work: one patrol loop in a tmux window of the same session, a precise definition of
"pending", a stand-down switch, and limits so a broken PM cannot be restarted forever. Why this shape (and why the
watchdog is not a heartbeat): `references/workflows.md` §I and `references/philosophy.md` (govern less).
## Requirements
### Requirement: One backend, inside the team's tmux session

`team pulse up` SHALL run the patrol in a window named `TEAM_PULSE_WINDOW` (default `pulse`) of the session
`TEAM_SESSION`, and that window MUST also serve as the status monitor (`team monitor`). The window has two
shapes — the console, whose process owns the tick, and the headless tick loop the same window is rebuilt into
when the human collapses the console — and both shapes are the same one window and the same one backend: the
pulse MUST NOT depend on a container, a systemd unit or any second backend, and `status`, `logs`, `restart` and
`down` SHALL act on that one window in either shape. `team pulse up` against the headless shape SHALL restore
the console in place, and `status` SHALL report which shape the window is in.

#### Scenario: Up creates exactly one patrol window

- **WHEN** `team pulse up` runs in a project whose session exists
- **THEN** `tmux list-windows -t <session>` contains exactly one `pulse` window
- **AND** `team pulse status` reports the tmux backend, the interval and that window

#### Scenario: Down removes it

- **WHEN** `team pulse down` runs
- **THEN** the `pulse` window is gone and `team pulse status` reports that the pulse is not running

#### Scenario: Collapse and restore keep one window

- **GIVEN** a fixture session with the console up in the patrol window
- **WHEN** the console is collapsed and `team pulse up` runs again two intervals later
- **THEN** `tmux list-windows -t <session>` holds exactly one `pulse` window throughout, the tick kept logging
  through the collapse, and `team pulse status` reported the headless shape and reports the console shape after
  the restore

### Requirement: Pending work is defined, and no work means no wake-up

A patrol tick SHALL append one line to `.pi/team/state/capacity.log` and then wake the PM only when there is pending
work: an unread notification, a task report without a review record, a `blocked` board row, an agent whose recorded
task is unfinished but whose window is gone, or (only with `TEAM_PULSE_PENDING_BOARD=1`) `todo`/`wip` board rows.
With nothing pending it MUST do nothing beyond the log line: no message typed into the PM window and no PM start.

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

### Requirement: Repeated reminders for the same batch are rate limited

The pulse SHALL NOT repeat a reminder for an unchanged pending batch more often than `TEAM_PULSE_NUDGE_GAP`
seconds (default 900).

#### Scenario: The second tick stays quiet

- **GIVEN** a pending batch that was already nudged, less than `TEAM_PULSE_NUDGE_GAP` seconds ago
- **WHEN** `team watch --once` runs again
- **THEN** no new `[pulse] pending:` line is typed into the PM window

#### Scenario: Standby suppresses the nudge

- **GIVEN** `team standby on --reason "waiting for the user"` and a pending batch
- **WHEN** `team watch --once` runs
- **THEN** the PM window receives no nudge, the tick is logged in `state/watchdog.log`, and
  `team standby status` reports standby on with that reason

### Requirement: Standby stops the wake-ups but keeps the backlog visible

With `team standby on --reason "…"`, patrol ticks MUST NOT nudge or start the PM; the pending work MUST still be
written to `state/watchdog.log`, and `team standby status` SHALL report that standby is on together with the reason.
`team standby off` restores the wake-ups. For the whole alias period the patrol keeps its historical state file
names (`state/watchdog.log`, `state/watchdog.pid`, `state/watchdog.last`, `state/watchdog.nudge`,
`state/watchdog.tick.log`) and creates no `state/pulse.*` file.

#### Scenario: Standby suppresses the nudge

- **GIVEN** `team standby on --reason "waiting for the user"` and a pending batch
- **WHEN** `team watch --once` runs
- **THEN** the PM window receives no nudge, the tick is logged in `state/watchdog.log`, and
  `team standby status` reports standby on with that reason

#### Scenario: The alias period keeps the historical state file names

- **WHEN** `team watch --once` runs
- **THEN** `state/watchdog.last` is updated and no `state/pulse.*` file exists

#### Scenario: The quota refuses further restarts

- **GIVEN** the PM is not running and the restart log already shows `TEAM_WATCH_MAX_RESTARTS` starts in the last hour
- **WHEN** a tick with pending work runs
- **THEN** it does not start a PM process and logs a warning about the exceeded quota

#### Scenario: Capacity is recorded per tick

- **WHEN** two patrol ticks run
- **THEN** `state/capacity.log` has two new lines, each with a timestamp and the memory/swap figures

### Requirement: Restart quota and capacity logging

The pulse SHALL start the PM at most `TEAM_PULSE_MAX_RESTARTS` times per hour (default 5). Beyond that it MUST
stop starting the PM and warn instead. Each tick MUST append one line to `.pi/team/state/capacity.log`
(timestamp + RAM/swap/agent estimate) so capacity has a trend, not just a current value.

#### Scenario: The quota refuses further restarts

- **GIVEN** the PM is not running and the restart log already shows `TEAM_PULSE_MAX_RESTARTS` starts in the last hour
- **WHEN** a tick with pending work runs
- **THEN** it does not start a PM process and logs a warning about the exceeded quota

#### Scenario: Capacity is recorded per tick

- **WHEN** two patrol ticks run
- **THEN** `state/capacity.log` has two new lines, each with a timestamp and the memory/swap figures

### Requirement: The pulse never manages tmux layout, agents or quota

The pulse SHALL NOT rebuild a missing session or window while `TEAM_PULSE_REBUILD_TMUX=0` (the default) — it
reports the state instead; it MUST NOT resume stopped agents; and it MUST NOT merge, change the board or spend model
quota. Those are the PM's calls (`team up`, `team resume`).

#### Scenario: A missing window is reported, not rebuilt

- **GIVEN** `TEAM_PULSE_REBUILD_TMUX=0` and no PM window in the session
- **WHEN** a tick runs
- **THEN** the tick output reports the missing window and creates no new tmux window

#### Scenario: A stopped agent is not resumed

- **GIVEN** an agent with a recorded unfinished task whose window does not exist
- **WHEN** a tick runs with pending work
- **THEN** the agent is listed as pending work for the PM, and no agent window is started

### Requirement: The old command names keep working during the alias period

Until the first major release after the rename (v2.0.0), `team watchdog up|down|restart|status|logs`,
`team watchdog-status`, `team install-watchdog`, `team uninstall-watchdog` and the `--no-watchdog` flags of
`team monitor` and `team bootstrap` MUST keep working, and every alias command SHALL print the deprecation line
`[deprecated] team watchdog 已改名 team pulse（别名保留到 v2.0.0）` as the first line of its output.

#### Scenario: The alias reports itself as deprecated

- **WHEN** `team watchdog status` runs
- **THEN** the first line of stdout is `[deprecated] team watchdog 已改名 team pulse（别名保留到 v2.0.0）`
- **AND** the remaining output reports the resolved window and the interval, as `team pulse status` does

### Requirement: Legacy environment variable names are read during the alias period

`TEAM_WATCH_INTERVAL`, `TEAM_WATCH_NUDGE_GAP`, `TEAM_WATCH_MAX_RESTARTS`, `TEAM_WATCH_PENDING_BOARD`,
`TEAM_WATCH_REBUILD_TMUX` and `TEAM_WATCH_WINDOW` MUST keep taking effect until v2.0.0. The effective value is
`TEAM_PULSE_<NAME>` when it is set, else `TEAM_WATCH_<NAME>`, else the default; `team pulse status` SHALL name every
legacy variable it fell back to.

#### Scenario: A legacy interval is honoured and named

- **GIVEN** `TEAM_PULSE_INTERVAL` is unset and `TEAM_WATCH_INTERVAL=17`
- **WHEN** `team pulse status` runs
- **THEN** the output reports the interval as `17s` and names `TEAM_WATCH_INTERVAL` as the legacy source

#### Scenario: The new name wins over the legacy name

- **GIVEN** `TEAM_PULSE_INTERVAL=11` and `TEAM_WATCH_INTERVAL=17`
- **WHEN** `team pulse status` runs
- **THEN** the output reports the interval as `11s` and names no legacy variable

### Requirement: A running legacy window is migrated explicitly

While the resolved pulse window does not exist but a window named `watchdog` exists in `TEAM_SESSION`, `team pulse`
SHALL treat the `watchdog` window as the running backend; `team pulse status` and `team doctor` SHALL name it as
legacy and name `team pulse restart` as the migration. `team pulse up` in that state MUST create no window. `team
pulse restart` SHALL remove both window names and leave exactly one patrol window, named `TEAM_PULSE_WINDOW`.

#### Scenario: A legacy window is recognized, not doubled

- **GIVEN** a session whose only patrol window is named `watchdog` and the resolved window name is `pulse`
- **WHEN** `team pulse up` runs
- **THEN** no window named `pulse` is created
- **AND** the output names the legacy `watchdog` window and `team pulse restart`

#### Scenario: Restart leaves one window under the new name

- **GIVEN** a running `watchdog` window and no `pulse` window
- **WHEN** `team pulse restart` runs
- **THEN** `tmux list-windows -t <session>` contains exactly one patrol window, named `pulse`

### Requirement: The read-only commands report the pulse surface

`team paths` SHALL include the resolved window name and the effective interval under the keys `pulse_window` and
`pulse_interval`; `team doctor` SHALL name the backend `pulse` and SHALL name a legacy `TEAM_WATCH_*` variable when
one is the effective source.

#### Scenario: paths exposes the resolved pulse settings

- **WHEN** `team paths` runs
- **THEN** the JSON object has `pulse_window` equal to the resolved window name and `pulse_interval` equal to the
  effective interval in seconds

#### Scenario: doctor names the backend and the legacy source

- **GIVEN** `TEAM_WATCH_INTERVAL` is the effective interval source
- **WHEN** `team doctor` runs
- **THEN** the pulse check line contains `pulse` and names `TEAM_WATCH_INTERVAL`

