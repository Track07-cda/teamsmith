## MODIFIED Requirements

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


A start justified only by an eligible PM self-Reminder SHALL reuse these state, launch identity, continuity, window, capacity and existing PM-restart quota guards, but SHALL use the prompt-free Reminder-only handoff in `agent-self-reminder`: no generic startup prompt or ordinary pending nudge is sent before the actual correlated wake. These are unchanged PM-start checks, not Reminder creation or delivery quotas. An unobserved or failed send does not make Standby off.

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

#### Scenario: A Reminder start remains starting without generic work

- **GIVEN** Standby is on, a due self-Reminder just started the PM and its launch proof is pending
- **WHEN** an overlapping ordinary tick and Reminder recovery recheck occur
- **THEN** neither respawns the PM or consumes another quota slot, and no ordinary startup prompt or pending nudge is delivered
