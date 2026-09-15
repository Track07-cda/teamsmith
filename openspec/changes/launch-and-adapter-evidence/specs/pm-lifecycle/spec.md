## Purpose

The PM is a process with a lifecycle, not a window: liveness is proven from evidence, a start in flight is its own
state, and a reload request is bookkeeping rather than a restart. It exists so no command ever reports a PM that is
not there — and never kills the PM that is coming up. Why each rule exists: `references/protocol.md` (the liveness
model) and `references/troubleshooting.md`.

## ADDED Requirements

### Requirement: PM liveness is proven, not inferred

Every command that reports whether the PM runs — `team ps`, `team watchdog-status`, `team digest`, `team up` — SHALL
decide it from positive evidence only: either `state/pm.pid` names a live process whose working directory is inside
this project, or the PM window's foreground process (the pane's pid or one of its direct children) has the configured
PM executable in its command line (`TEAM_PM_BIN` > the first word of `TEAM_PM_CMD` > `TEAM_PI_BIN`) and a working
directory inside the project. A window that merely exists MUST NOT count; a recorded pid that is dead MUST NOT count;
a project-local process with another command line (a fresh empty window, `sleep`, an editor, a tmux transient) is
`unknown`, and a process whose working directory is outside the project is `foreign`. Read-only commands MUST NOT
clear or rewrite `state/pm.pid`. `team up` SHALL start a PM when the state is `missing`, `idle` or `unknown`, MUST
refuse to overwrite a `foreign` occupant unless `TEAM_REPLACE_FOREIGN_PM=1` is set, and MUST record the evidence it
used (`state/pm.pid.proof` = `argv` when the window process is the configured executable, `spawn` when the pid it
started is alive in the project, which is what covers a wrapper that `exec`s its own image away).

#### Scenario: An empty window is not a running PM

- **GIVEN** a session whose `pm` window holds an idle shell, and then a window whose foreground process is `tmux`
  itself
- **WHEN** `team watchdog-status` and `team up` run
- **THEN** neither state is reported as a running PM, and `team up` exits 0 having really started one
  (`state/pm.pid` records a live pid whose command line is the configured PM executable)

#### Scenario: A recorded pid that has died is not a running PM

- **GIVEN** `state/pm.pid` names the pid of a PM that was then killed
- **WHEN** the state is read
- **THEN** it is no longer `running:*` and `team watchdog-status` does not claim the PM is running

#### Scenario: A non-PM occupant is not a running PM and does not suppress a start

- **GIVEN** a `pm` window whose foreground process is `sleep 300` with a working directory inside the project
- **WHEN** the state is read and `team up` runs
- **THEN** the state is `unknown:<cmd>` (never `running`), `team watchdog-status` does not claim a running PM, and
  `team up` replaces the occupant with a real PM start

#### Scenario: A foreign occupant is refused, not overwritten

- **GIVEN** a `pm` window whose occupant's working directory is outside the project
- **WHEN** `team up` runs
- **THEN** the state is `foreign:<cmd>`, `team up` exits non-zero saying the occupant does not belong to this
  project, and only `TEAM_REPLACE_FOREIGN_PM=1` makes it replace the occupant

#### Scenario: A manually started PM, and a wrapper that `exec`d itself, are recognized

- **GIVEN** no `state/pm.pid`, and a `pm` window whose foreground process is the configured PM executable; then a
  wrapper script that `exec`s a CLI and thereby changes its process image
- **WHEN** the state is read after each start
- **THEN** the manual start is `running:*`, and the wrapper start reports `proof=spawn` with a live pid in
  `state/pm.pid` and stays `running` — while a `sleep` that nobody recorded is still only `unknown`

#### Scenario: A read-only command does not clear the evidence

- **GIVEN** `state/pm.pid` still records a pid that has died
- **WHEN** `team ps`, `team digest`, `team roster` and `team paths` run
- **THEN** the state is reported honestly (not `running`) and every file in `state/`, `state/pm.pid` included,
  is byte-identical to what it was before the reads

### Requirement: A PM that is starting is a state, not a missing PM

Between the decision to start the PM and the arrival of the launch proof, the PM state SHALL be
`starting:<seconds>`, derived from `state/pm.pid.starting` (the start's epoch, initiator and target window), and every
consumer MUST treat it as "a PM is coming" instead of "there is no PM": an overlapping `team up` or watchdog tick MUST
NOT respawn the window — doing so kills the PM that is coming up — and MUST NOT consume the restart quota. The PM
state vocabulary SHALL be exactly `running/starting/idle/unknown/foreign/missing`, each state named together with the
evidence used to decide it; there is no other state (in particular no `busy` — the pane-busy probe only separates
`idle` from `unknown`). A start marker SHALL only count while it is fresh (`TEAM_PM_START_WAIT + 5` seconds) and for
its own target window, so a stalled start cannot lock the window forever, and it MUST be removed once the start
succeeds or fails.

#### Scenario: A second tick during a start does not start a second PM

- **GIVEN** a first patrol tick is starting the PM (the pane has already been respawned) and the start marker is not
  yet replaced by the launch proof
- **WHEN** a second tick runs immediately
- **THEN** the second tick says it will not start the PM again, the pane pid is unchanged (the PM was not
  killed), and `state/pm-restarts.log` records one restart for the one real start

#### Scenario: A stale marker expires, a fresh one is reported as starting

- **GIVEN** a hand-written start marker, first fresh and then older than `TEAM_PM_START_WAIT + 5` seconds
- **WHEN** the state is read and a tick runs in each case
- **THEN** the fresh marker makes the state `starting:*` and the tick consumes no restart and starts nothing, while
  `team watchdog-status`, `team digest` and `team up` all say the PM is starting
- **AND** after the marker expires it is no longer reported as `starting` and the next tick starts the PM (a marker
  left behind by a crashed starter is not a lock), and a successful start removes the marker

### Requirement: A reload request is bookkeeping, not a restart

`team reload` SHALL write `state/reload-requested` as a request marker and MUST state what really makes the reload
take effect (typing `/reload`, or `/teamsmith-reload`, in the Pi session, or the `reload_skills` tool) and that no
component restarts a session because of the marker: the only reader is the Pi notification extension, which removes
the marker after a reload. No script may read the marker as an instruction to restart anything. `team reload --done`
SHALL clear the marker.

#### Scenario: The reload text matches the mechanism

- **WHEN** `team reload` runs
- **THEN** `state/reload-requested` exists and the output names `/reload` as the way to make it effective
- **AND** the output does not promise that the watchdog restarts the PM session, and says explicitly that no
  component restarts a session because of the marker
- **AND** a search of `scripts/` finds no file other than the reload command itself reading `reload-requested`

#### Scenario: `--done` clears the marker

- **GIVEN** a marker written by `team reload`
- **WHEN** `team reload --done` runs
- **THEN** `state/reload-requested` no longer exists
