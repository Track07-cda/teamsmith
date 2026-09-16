# notify-and-inbox Specification

## Purpose

The asynchronous channel between workers and the PM: a worker's turn end lands in the inbox and (optionally) knocks
on the PM's window, and the PM's one-line messages reach a running agent's TUI or fall back to the inbox. Why
delivery must be verifiable and never touch a shell prompt: `references/protocol.md` (safety model) and
`references/philosophy.md`.
## Requirements
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

### Requirement: `--from-file` delivers the summary byte for byte

`team notify <agent> --from-file <path>` SHALL treat the file's content as data: shell metacharacters, quotes,
backticks and literal brace tokens MUST reach the inbox unchanged, newlines and carriage returns MUST be folded to
one line, and nothing in the content MUST be executed. A missing or blank file MUST fail the command and MUST NOT
write to the inbox.

#### Scenario: A hostile summary is delivered, not executed

- **GIVEN** a file containing `$(touch <sentinel>)` and `x"; touch <sentinel>; echo "`
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the inbox line contains that text byte for byte and `<sentinel>` does not exist

#### Scenario: A missing summary file fails loudly

- **WHEN** `team notify pm --from-file /nonexistent/summary.md` runs
- **THEN** it exits non-zero and the inbox file is not modified

#### Scenario: Multi-line summaries become one line

- **GIVEN** a summary file with `first line\nsecond line`
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the inbox line contains `first line second line` and no newline inside the line

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

### Requirement: Cross-session targets are refused

The skill MUST NOT type into windows that do not belong to the team session. With `TEAM_GUARD_FOREIGN_TARGET=1` (the
default), `team say`/`team notify`/`team meeting knock` MUST refuse a foreign session target, MUST name the refused
target and the guard, and MUST explain how a human authorizes it.

#### Scenario: A foreign window is not touched

- **GIVEN** another tmux session `other` with a window `pm`
- **WHEN** `team say other:pm "hi"` (or a meeting knock aimed at it without registration) runs
- **THEN** the command exits non-zero, the refused target is printed, and the other session's pane content is
  unchanged

### Requirement: A meeting knock requires both sides' consent and a registered peer

A meeting knock (`team meeting say … --knock`, `team meeting knock <slug>`) SHALL only reach the peer's PM window
when `TEAM_MEETING_KNOCK=1` and the peer's `session` is registered via `team meeting peer <slug> <project>:<session>`.
Without the switch or the registration the message MUST still land in the shared transcript and the command MUST
say that the knock was skipped.

#### Scenario: Unregistered peer means no knock

- **GIVEN** `TEAM_MEETING_KNOCK=1` and a meeting with no registered peer session
- **WHEN** `team meeting say <slug> --intent info "…" --knock` runs
- **THEN** the transcript gains the message, the output says the peer session is unknown, and no tmux text is typed
  anywhere

### Requirement: Reading the inbox is explicit and reversible

`team inbox [<agent>] [--ack] [--all]` SHALL print unread lines and, with `--ack`, mark exactly those lines as read
so that `team digest` no longer counts them as pending; without `--ack` the unread count MUST be unchanged.

#### Scenario: Ack clears the pending count

- **GIVEN** one unread line in `docs/team/inbox/pm.md` and `team digest` reporting it as pending
- **WHEN** `team inbox --ack` runs and then `team digest` runs again
- **THEN** the line is no longer counted as pending work

