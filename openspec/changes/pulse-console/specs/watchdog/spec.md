## MODIFIED Requirements

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
