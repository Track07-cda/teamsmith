## MODIFIED Requirements

### Requirement: Messages to a stopped agent fall back to the inbox

`team say <agent> "<one line>"` SHALL type into the agent's TUI only while the agent process is running; when the
agent is not running (empty prompt) the message MUST be appended to `docs/team/inbox/<agent>.md` instead, and the
command MUST say that this is what happened.

While the agent is running but its input box holds a draft the message MUST NOT be typed: it is held in
`state/outbox/` and delivered when the box clears, and the command MUST report it as queued rather than delivered
(`delivery-guard` specifies the guard, the queue and the drain).

#### Scenario: Offline delivery is visible

- **GIVEN** the agent's window exists but its CLI process has exited
- **WHEN** `team say dev "check the failing test"` runs
- **THEN** the message appears in `docs/team/inbox/dev.md`, the output states that it went to the inbox, and no text
  is typed into the window's shell prompt


#### Scenario: A draft in the target's input box is not disturbed

- **GIVEN** `dev`'s window runs a TUI whose input box holds `half a sentence`
- **WHEN** `team say dev "check the failing test"` runs
- **THEN** the pane still shows exactly that draft, the message text does not appear in the pane, and `state/outbox/`
  holds exactly one entry for `dev` whose payload is that message

### Requirement: A turn-end notification appends one inbox line and knocks once

The Pi notify extension SHALL append one line to `docs/team/inbox/<agent>.md` (timestamp, agent, summary) and knock
on the PM window; the same summary MUST be deduplicated inside `TEAM_NOTIFY_DEDUP_SEC` (default 20 s) so a
repeated settle does not spam the PM. The inbox is a local artifact and MUST be gitignored.

The knock goes through the delivery guard: the knock text is typed only while the PM's input box is free, otherwise
it is held in the same outbox; the inbox line is written either way, and the knock text MUST NOT be appended to a
draft.

#### Scenario: One summary, one line

- **WHEN** the notify extension runs once with the summary `T1.1 done: parser shipped`
- **THEN** `docs/team/inbox/dev.md` gains exactly one line containing that summary

#### Scenario: A repeated settle inside the dedup window is dropped

- **GIVEN** the same summary was notified less than `TEAM_NOTIFY_DEDUP_SEC` seconds ago
- **WHEN** the extension runs again with it
- **THEN** the inbox file does not gain a second line for that summary


#### Scenario: A dirty PM input box turns the knock into a queued entry

- **GIVEN** the PM window's input box holds a draft and `TEAM_NOTIFY_TMUX=1`
- **WHEN** the notify extension delivers a summary
- **THEN** the inbox line is written, the PM's draft is unchanged, and `state/outbox/` holds one entry for the PM
  window whose payload is the knock text
