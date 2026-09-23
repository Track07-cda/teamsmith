## MODIFIED Requirements

### Requirement: Messages to a stopped agent fall back to the inbox

`team say <agent> "<one line>"` SHALL type into the agent's TUI only while the agent process is running; when the
agent is not running (empty prompt) the message MUST be appended to `docs/team/inbox/<agent>.md` instead, and the
command MUST say that this is what happened.

While the agent is running but its input box holds a draft the message MUST NOT be typed: it is held in
`state/outbox/` and delivered when the box clears, and the command MUST report it as queued rather than delivered
(`delivery-guard` specifies the guard, the queue and the drain). A draft is any text visible in the box, a
**single line** included: on Pi 0.87.0 the box's own status row moved below the box, so a one-line human draft
sits on the row the guard used to skip, and this command MUST judge it a draft — no key, held in
`state/outbox/`, reported `queued` — instead of typing over it (measured before the fix: the delivery path judged
that box `EMPTY`).

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

#### Scenario: A single-line draft queues the message

- **GIVEN** `dev`'s window runs Pi 0.87.0 whose input box holds the single line `half a sentence` with the cursor
  on it (the shape of the real frame `docs/team/reports/P61-dev3/logs/15b-one-line-draft-frame.log`)
- **WHEN** `team say dev "check the failing test"` runs
- **THEN** the pane still shows exactly that line, no key was sent, the output contains `queued`,
  `state/outbox/` holds exactly one entry for `dev` whose payload is that message, and the text does not appear in
  the pane
