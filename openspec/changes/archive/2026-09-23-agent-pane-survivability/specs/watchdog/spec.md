## ADDED Requirements

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
