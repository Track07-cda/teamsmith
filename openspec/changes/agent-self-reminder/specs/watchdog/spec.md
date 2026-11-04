## MODIFIED Requirements

### Requirement: One backend, inside the team's tmux session

`team pulse up` SHALL run the patrol in a window named `TEAM_PULSE_WINDOW` (default `pulse`) of the session
`TEAM_SESSION`, and that window MUST also serve as the status monitor (`team monitor`). The window has two
shapes — the console, whose process owns the tick, and the headless tick loop the same window is rebuilt into
when the human collapses the console — and both shapes are the same one window and the same one backend: the
pulse MUST NOT depend on a container, a systemd unit or any second backend, and `status`, `logs`, `restart` and
`down` SHALL act on that one window in either shape. `team pulse up` against the headless shape SHALL restore
the console in place, and `status` SHALL report which shape the window is in.


Both shapes SHALL also own the lightweight Reminder due check in `agent-self-reminder`; it is not a second backend or a full patrol. A long full patrol SHALL NOT prevent due admission, and overlapping recovery requests SHALL coalesce to one recheck after the in-flight patrol/recovery ends.

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
task is unfinished but whose window is gone, an unread peer turn in a meeting this project participates in and that
is not closed (a meeting that is expired but not closed still counts; the count comes from the meeting's
per-project read position and MUST NOT include this project's own turns), or (only with
`TEAM_PULSE_PENDING_BOARD=1`) `todo`/`wip` board rows. The pending summary SHALL name the unread-meeting count
(`未读会议 N`) so the nudge text carries it. With nothing pending it MUST do nothing beyond the log line: no message
typed into the PM window and no PM start.


This definition governs the ordinary patrol's pending work and its ordinary nudge/start. An eligible PM self-Reminder has the separate direct admission and Reminder-only recovery path in `agent-self-reminder`; its presence does not add other pending categories to that path.

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

### Requirement: Repeated reminders for the same batch are rate limited

The pulse SHALL NOT repeat a reminder for an unchanged pending batch more often than `TEAM_PULSE_NUDGE_GAP`
seconds (default 900). For reminders to a running PM, a batch SHALL be identified by the set of positive pending
categories: `inbox`, `reports`, `todo`, `wip`, `review`, `blocked`, `stopped` and `meetings`, after the existing
pending-board policy has been applied. Counts and descriptive text MUST NOT affect that identity. While that set
is nonempty and unchanged, a tick inside the gap MUST append no reminder to `state/nudges.log` and MUST submit no
new pulse reminder to the delivery channel; suppression MUST NOT postpone the next allowed reminder. A changed
nonempty set (addition or removal) SHALL allow a reminder immediately, regardless of the previous reminder's age.
A tick that observes no pending categories SHALL rearm the next nonempty batch, including when emptiness is
observed under standby. Standby MUST still suppress these ordinary pulse reminders and their PM startup; rearming MUST NOT itself send a
message. PM startup and its quota, and the delivery guard's handling of a reminder, remain unchanged. The
reminder text and `state/nudges.log` SHALL keep the current counts whenever a reminder is generated. Rationale
for pending-only patrols and the gap configuration: `skills/teamsmith/references/workflows.md` §I and
`skills/teamsmith/references/config.md`.


These pulse pending-batch reminders are distinct from a PM self-Reminder. The self-Reminder exception and its own batch spacing are specified in `agent-self-reminder` and MUST NOT relax the ordinary nudge gap.

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

### Requirement: Standby stops the wake-ups but keeps the backlog visible

With `team standby on --reason "…"`, ordinary pending work MUST NOT make patrol ticks nudge or start the PM; the pending work MUST still be
written to `state/watchdog.log`, and `team standby status` SHALL report that standby is on together with the reason.
`team standby off` restores ordinary wake-ups. A due PM self-Reminder MAY invoke the guarded Reminder-only recovery path in `agent-self-reminder`; queueing, starting or an unobserved send alone MUST NOT switch Standby off. An actual correlated Reminder wake switches off only its provably bound current generation, once per batch; a newer ambiguous generation stays on and is reported. Explicit ordinary Outbox drain remains independently authorized as before. For the whole alias period the patrol keeps its historical state file
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

#### Scenario: A due self-Reminder does not release ordinary backlog prematurely

- **GIVEN** Standby is on, the PM is stopped, ordinary inbox work is pending and a self-Reminder is due
- **WHEN** the Reminder-only recovery starts the PM but its correlated Pi wake has not been observed
- **THEN** Standby stays on, no ordinary pending nudge or generic startup prompt is sent, and separately authorized ordinary Outbox handling remains unchanged

### Requirement: Restart quota and capacity logging

The pulse SHALL start the PM at most `TEAM_PULSE_MAX_RESTARTS` times per hour (default 5). Beyond that it MUST
stop starting the PM and warn instead. Each tick MUST append one line to `.pi/team/state/capacity.log` carrying the
timestamp and the measured capacity readings — the RAM/swap figures and the agent estimate plus, for the temp root
and the worktrees root, the available bytes and free inodes — so capacity has a trend across the filesystem
dimension too, not just a current value.


A PM start for an eligible self-Reminder SHALL use this same quota and the existing capacity and starting/identity guards; it SHALL NOT gain a separate restart allowance.

#### Scenario: The quota refuses further restarts

- **GIVEN** the PM is not running and the restart log already shows `TEAM_PULSE_MAX_RESTARTS` starts in the last hour
- **WHEN** a tick with pending work runs
- **THEN** it does not start a PM process and logs a warning about the exceeded quota

#### Scenario: Capacity is recorded per tick

- **GIVEN** `TEAM_DISK_STATS_FILE` holds figures for the temp root and the worktrees root
- **WHEN** two patrol ticks run
- **THEN** `state/capacity.log` has two new lines, each carrying the timestamp, the memory/swap figures and both
  filesystems' available bytes and free inodes

### Requirement: The pulse never manages tmux layout, agents or quota

The pulse SHALL NOT rebuild a missing session or window while `TEAM_PULSE_REBUILD_TMUX=0` (the default) — it
reports the state instead; it MUST NOT resume stopped agents; and it MUST NOT merge, change the board or directly
select a model or spend model quota itself. A correlated PM self-Reminder can trigger a Pi model turn under the
existing PM model; it gives Pulse no authority to change model policy. A stopped worker retains its assignment; patrol SHALL NOT reselect category policy or launch a fresh worker. A PM continuity/config refusal SHALL be reported with its explicit correction/fresh route, no PM launch and no consumed restart slot. Those are the PM's calls (`team up`, `team resume`).

#### Scenario: A missing window is reported, not rebuilt

- **GIVEN** `TEAM_PULSE_REBUILD_TMUX=0` and no PM window in the session
- **WHEN** a tick runs
- **THEN** the tick output reports the missing window and creates no new tmux window

#### Scenario: A stopped agent is not resumed

- **GIVEN** an agent with a recorded unfinished task whose window does not exist
- **WHEN** a tick runs with pending work
- **THEN** the agent is listed as pending work for the PM, and no agent window is started

#### Scenario: A Reminder does not override a missing PM-window guard

- **GIVEN** a queued self-Reminder, no PM window and `TEAM_PULSE_REBUILD_TMUX=0`
- **WHEN** Reminder-only recovery is considered
- **THEN** it reports the missing window and does not create one or select a fresh model
