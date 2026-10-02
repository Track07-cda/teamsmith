## MODIFIED Requirements

### Requirement: Repeated reminders for the same batch are rate limited

The pulse SHALL NOT repeat a reminder for an unchanged pending batch more often than `TEAM_PULSE_NUDGE_GAP`
seconds (default 900). For reminders to a running PM, a batch SHALL be identified by the set of positive pending
categories: `inbox`, `reports`, `todo`, `wip`, `review`, `blocked`, `stopped` and `meetings`, after the existing
pending-board policy has been applied. Counts and descriptive text MUST NOT affect that identity. While that set
is nonempty and unchanged, a tick inside the gap MUST append no reminder to `state/nudges.log` and MUST submit no
new pulse reminder to the delivery channel; suppression MUST NOT postpone the next allowed reminder. A changed
nonempty set (addition or removal) SHALL allow a reminder immediately, regardless of the previous reminder's age.
A tick that observes no pending categories SHALL rearm the next nonempty batch, including when emptiness is
observed under standby. Standby MUST still suppress reminders and PM startup; rearming MUST NOT itself send a
message. PM startup and its quota, and the delivery guard's handling of a reminder, remain unchanged. The
reminder text and `state/nudges.log` SHALL keep the current counts whenever a reminder is generated. Rationale
for pending-only patrols and the gap configuration: `skills/teamsmith/references/workflows.md` §I and
`skills/teamsmith/references/config.md`.

#### Scenario: The second tick stays quiet

- **GIVEN** a pending batch that was already nudged, less than `TEAM_PULSE_NUDGE_GAP` seconds ago
- **WHEN** `team watch --once` runs again
- **THEN** no new `[pulse] pending:` line is typed into the PM window

#### Scenario: Standby suppresses the nudge

- **GIVEN** `team standby on --reason "waiting for the user"` and a pending batch
- **WHEN** `team watch --once` runs
- **THEN** the PM window receives no nudge, the tick is logged in `state/watchdog.log`, and
  `team standby status` reports standby on with that reason

#### Scenario: Counts change without changing the batch

- **GIVEN** a running fixture PM, `TEAM_PULSE_NUDGE_GAP=3600`, and one unread notification already reminded at time T
- **WHEN** the unread count becomes four and `team watch --once` runs at T+900 with no other pending category
- **THEN** `state/nudges.log` still has one reminder line and no additional pulse delivery is submitted
- **AND** the same count-only suppression holds independently for every other positive pending category

#### Scenario: An additional category wakes immediately

- **GIVEN** the same fixture whose first reminder at T names only one unread notification
- **WHEN** one report becomes pending for review and `team watch --once` runs at T+100
- **THEN** `state/nudges.log` gains a second line containing `未读通知 1` and `待复验 1`, and exactly one new pulse
  reminder is submitted to the guarded delivery channel

#### Scenario: Removing a category also changes the batch

- **GIVEN** the previous fixture reminded for inbox plus reports at T+100
- **WHEN** the report stops being pending, the unread notification remains, and `team watch --once` runs at T+200
- **THEN** `state/nudges.log` gains a third line containing `未读通知 1` without `待复验`, and exactly one new pulse
  reminder is submitted

#### Scenario: An empty tick rearms the returning batch

- **GIVEN** a running fixture PM reminded for one unread notification at T and `TEAM_PULSE_NUDGE_GAP=3600`
- **WHEN** all pending categories become zero, `team watch --once` runs at T+100, and the same category returns
  with one unread notification before a tick at T+200
- **THEN** the empty tick submits no reminder, and the returning tick appends a second `state/nudges.log` line and
  submits exactly one new pulse reminder despite being inside the original gap

#### Scenario: Emptiness under standby still rearms without waking

- **GIVEN** the previous fixture reminded at T, followed by `team standby on --reason "waiting for the user"`
- **WHEN** all pending categories become zero at T+100 and `team watch --once` runs, then one unread notification
  returns, `team standby off` runs and another tick runs at T+200
- **THEN** the standby tick generates no reminder or PM start, and the returning tick appends a second reminder
  line and submits one new pulse reminder

#### Scenario: The gap expires from the last actual reminder attempt

- **GIVEN** a running fixture PM reminded for one unread notification at T and `TEAM_PULSE_NUDGE_GAP=3600`
- **WHEN** unchanged-category ticks run at T+3599 and T+3600
- **THEN** the first tick adds no reminder, and the second appends exactly one new `state/nudges.log` line and
  submits one pulse reminder carrying the count at T+3600

#### Scenario: Empty pending work remains silent with no PM running

- **GIVEN** no pending categories and a fixture PM that is not running
- **WHEN** `team watch --once` runs
- **THEN** `state/capacity.log` gains one line, `state/nudges.log` gains no line, no pulse delivery is submitted
  and no PM process is started
