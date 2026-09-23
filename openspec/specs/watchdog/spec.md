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

### Requirement: A live degraded channel is reported by `team doctor` and `team status`

When a live `state/inbox-watch/<key>.degraded` record exists for the project's PM target — its `pid` is alive and its
`cwd` is inside the project, the same evidence rule `.reg` and `.skip` use — `team doctor` and `team status` SHALL
print one degradation line for the wake channel carrying the token `投递通道降级`, the recorded `errno`, the recorded
quota (`watches <used>/<max>`), the fact that the channel fell back to polling (`轮询`), and the remedy
(`fs.inotify.max_user_watches=524288`). While the target has a live registration and no live degraded record, the
degradation line MUST NOT appear — the channel check may report the registration as healthy. A record whose `pid` is
dead or whose `cwd` is outside the project MUST NOT produce the line. A degraded-but-registered target MUST NOT be
reported with the missing-registration wording (`没有 inbox-watch 注册`) or with the "no registration" remedy
(restart the PM process): the registration exists and only the wake mechanism degraded.

#### Scenario: A dry host is named, not reported as healthy

- **GIVEN** a fixture project whose PM target has a live registration and a live `.degraded` record with
  `errno=ENOSPC` and `watches=65312/65536`
- **WHEN** `team doctor` and `team status` run
- **THEN** both outputs contain `投递通道降级`, `ENOSPC`, `65312/65536` and `524288`
- **AND** neither output contains `没有 inbox-watch 注册`, and the doctor check line is a warning, not a pass

#### Scenario: A stale record is not evidence

- **GIVEN** the same record whose `pid` no longer exists
- **WHEN** `team doctor` and `team status` run
- **THEN** neither output contains `投递通道降级`

#### Scenario: A healthy channel stays quiet

- **GIVEN** a fixture project whose PM target has a live registration and no `.degraded` record
- **WHEN** `team status` runs
- **THEN** the output contains no `投递通道降级` line

### Requirement: `team doctor` reports the inotify headroom of the wake channel

`team doctor` SHALL print one inotify headroom line for the wake channel carrying: the value of
`/proc/sys/fs/inotify/max_user_watches` (or that it cannot be read), the current user's counted inotify watch usage
only when a complete same-UID scope can be established (otherwise `unknown` — a partial count MUST NOT be presented
as the total), and a one-shot registration probe verdict — `ok`, the errno, or `unavailable` when no JS runtime
resolves.
The probe registers one watch on a private temporary directory and removes it; its verdict, not the counted usage,
is what decides the warning. The line MUST warn — without making `team doctor` exit non-zero — when the probe is not
`ok` or when the known headroom is below `TEAM_INOTIFY_MIN_FREE` (default 1024, non-numeric falls back), and the
warning MUST name the remedy `fs.inotify.max_user_watches=524288` together with Syncthing and VSCode as common
consumers of the quota. Raising the quota is an operator action: no command of this tool may attempt it.

#### Scenario: A working host reports the quota and the probe verdict

- **GIVEN** an environment where a watch registers and the default threshold
- **WHEN** `team doctor` runs
- **THEN** exactly one line names the inotify headroom, carries the `max_user_watches` value and the verdict `ok`
- **AND** `team doctor`'s exit status is unchanged by this check

#### Scenario: A low headroom warns with the fix

- **GIVEN** `TEAM_INOTIFY_MIN_FREE` set above the known free headroom
- **WHEN** `team doctor` runs
- **THEN** the line is a warning naming `524288`, `Syncthing` and `VSCode`
- **AND** `team doctor` does not fail on this check

#### Scenario: A probe that cannot register is a visible warning

- **GIVEN** a fixture whose resolved JS runtime makes the probe report `errno=ENOSPC`
- **WHEN** `team doctor` runs
- **THEN** the line names `ENOSPC` and the remedy, and the check is a warning rather than a pass

#### Scenario: Without a runtime the probe says unavailable, never ok

- **GIVEN** an environment where no JS runtime resolves
- **WHEN** `team doctor` runs
- **THEN** the line reports the probe as `unavailable` and warns, and it does not claim the headroom is fine

### Requirement: A dead pane is a seat condition with a readable scene, and never a running seat

The condition the read-only surfaces report for a seat SHALL distinguish four observable cases:
`running` (an agent is proven alive in the pane), `exited` (the window and its pane are alive, no
agent is alive in it), `dead` (the pane is dead, its window retained), and `absent` (no window). The
`running` case MUST keep the proof rule unchanged — a dead pane, a dead recorded pid, or a merely
existing window MUST NOT be reported as running. `team roster` SHALL print the three window-bearing
conditions distinguishably, the dead one carrying the pane's exit evidence (`status=<n>` or
`signal=<n>`), and its legend SHALL name what each of them means. `team status <ID>` SHALL print the
condition of the seat recorded for that task, the exit evidence when it is known, and the last
`TEAM_AGENT_SCENE_LINES` lines (default 40; a non-numeric value falls back to the default) of the
seat's most recent death or agent-exit record, labelled with the source it read and that record's
time. The sources are ordered by recency — a retained dead pane's screen read with its scrollback
(`capture-pane -S -`, bounded afterwards; the visible screen alone can lose the last line, measured),
then `state/dispatch-<agent>-pane-dead.txt`, then `state/dispatch-<agent>-tail.txt` — and a seat with
none of them MUST be described without any scene block.

The machine-readable agents block (`team __panel-data --block agents`, and through it the `agents`
block of `team monitor --json`) SHALL make every seat's condition readable without a human rendering:
the existing `state` key keeps its vocabulary (`running`/`exited`/`absent`) so no consumer is told
something false, a `pane` key carries `live`/`dead` whenever a window exists, and a `pane_exit` key
carries `status=<n>` or `signal=<n>` when that evidence is known. A dead pane MUST NOT be reported in
that block as `running`. `team doctor` SHALL name a dead-pane seat in one warning line carrying the
exit evidence and the scene command (`team status <ID>`), and MUST print no such line when no pane is
dead; `team digest` SHALL name a dead-pane seat together with its recorded task.

A retained window is an anomaly only while its seat has an unfinished recorded task: after
`team close <ID> --keep-window` (which clears the seat's recorded task) or `team teardown`,
`team digest`, `team doctor` and the pending counts (the pulse's stopped-agent signal, visible as the
`stopped` field of `team __panel-data --block pending`) MUST NOT report that window as an abnormal
exit or a stopped agent, while `team roster` still prints its honest condition. All of these readers
SHALL be read-only: no file under `.pi/team/state/` may change contents or timestamps because of them.

#### Scenario: The four conditions are distinguishable and the proof rule is untouched

- **GIVEN** a fixture project with one agent proven alive in its window, one window whose agent has
  exited (a live pane, no agent), one window whose pane was killed (`pane_dead=1`,
  `pane_dead_signal=9`), and one seat with no window
- **WHEN** `team roster` runs and `team __panel-data --block agents` (equivalently the `agents` block
  of `team monitor --json`) is read
- **THEN** the four rows carry four distinct conditions — the dead one naming `signal=9` — and no row
  is reported as running except the one whose agent was proven alive
- **AND** the machine block carries `pane=live` for the running and exited seats, `pane=dead` with
  `pane_exit=signal=9` for the dead one, and `state=absent` with no `pane` key for the seat without a
  window, while no entry carries `state=running` on weaker evidence than the proof rule
- **AND** no file under `.pi/team/state/` differs in contents from the fingerprint taken before the
  reads

#### Scenario: `team status` shows the evidence and a bounded scene from the newest record

- **GIVEN** the dead-pane seat of the previous scenario, its retained screen holding at least five
  marker lines, and `TEAM_AGENT_SCENE_LINES=2`
- **WHEN** `team status <ID>` runs for the task recorded on that seat, and then for a task whose seat
  is proven alive and has no death or exit record
- **THEN** the first output names the seat, its condition, `signal=9`, the scene source and that
  record's time, and shows exactly the two last scene lines including the marker line
- **AND** the second output shows the seat's condition and prints no scene block

#### Scenario: `doctor` names the dead seat with the way to the scene, and stays quiet otherwise

- **GIVEN** the fixture of the first scenario
- **WHEN** `team doctor` runs, and then runs again against a fixture whose every pane is alive
- **THEN** the first run prints one warning line naming the dead seat, `signal=9` and
  `team status <ID>`, and the command's exit status is unchanged by that check
- **AND** the second run prints no such line and no `signal=` warning

#### Scenario: A deliberately kept window is not an abnormal exit

- **GIVEN** a seat whose task `<ID>` was closed with `team close <ID> --keep-window` (the window is
  still there, the seat's recorded task is cleared, its pane dead from the fixture's kill), and a
  second seat that still has an unfinished recorded task and a dead pane
- **WHEN** `team roster`, `team digest`, `team doctor` and `team __panel-data --block pending` are
  read
- **THEN** the closed seat's window is not reported as an abnormal exit, is not counted in the
  block's `stopped` field, and `team digest` names it with no task — while the second seat IS named
  as an anomaly with its task and its exit evidence
- **AND** `team teardown --agent` on the closed seat removes the window, after which the surfaces
  report it as having no window

### Requirement: `team doctor` reports the temp root's headroom

`team doctor` SHALL print one line for the temp root the fixtures resolve to (`${TMPDIR:-/tmp}`), carrying that
resolved path, the free and total bytes **and** the free and total inodes of its filesystem, and a verdict. The
line MUST warn — without making `team doctor` exit non-zero — when the free bytes are below
`TEAM_TMP_MIN_FREE_MB` (default 1024) or the free inodes are below `TEAM_TMP_MIN_FREE_INODES` (default 100000; a
non-numeric value falls back to the default), and the warning MUST name the figures it measured, the threshold it
crossed and the remedy (`bash skills/teamsmith/tests/tmp-hygiene.sh --status`, then `--sweep`). When the path or a
figure cannot be read the line SHALL say so and MUST NOT report the headroom as fine. The check MUST read nothing
inside the temp root and MUST NOT delete anything; raising the headroom is an operator action (as with the inotify
quota, the sibling host-resource row). Why a full temp filesystem is a gate risk, and the measured floor behind the
defaults: the `test-tmp-hygiene` change's `design.md` and `references/troubleshooting.md`.

#### Scenario: A healthy temp root is reported with its numbers

- **WHEN** `team doctor` runs with both figures above their thresholds
- **THEN** exactly one line names the resolved temp root, the free/total bytes and the free/total inodes, and the check passes — and the doctor's exit status is unchanged by this check

#### Scenario: A low temp root warns with its remedy and does not fail the doctor

- **GIVEN** `TEAM_TMP_MIN_FREE_MB` set above the free bytes actually measured
- **WHEN** `team doctor` runs
- **THEN** the line is a warning naming the measured figures, the threshold it crossed and the `tmp-hygiene.sh` remedy, and `team doctor` still exits 0

#### Scenario: An unreadable temp root is never reported as healthy

- **GIVEN** a resolved temp root that does not exist
- **WHEN** `team doctor` runs
- **THEN** the line states that the figures could not be read and the check is a warning, not a pass, and it does not invent a number

