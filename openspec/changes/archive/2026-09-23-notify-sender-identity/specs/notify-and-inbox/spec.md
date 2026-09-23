## ADDED Requirements

### Requirement: A manual notification is attributed to its sender, not its recipient

`team notify <recipient> …` SHALL attribute the message to the sender it resolves from the caller's runtime
context and MUST NOT use the recipient as the sender. The resolution SHALL be, in this order:

- an explicit `--from <name>` claim, recorded verbatim; when it disagrees with the runtime directory the
  disagreement MUST be named on stderr;
- the runtime directory (`team`'s M40 identity): the project's main worktree resolves to `pm`, and a worktree
  under the main worktree's worktrees directory resolves to that worktree's own directory name, also when the
  process runs in one of its subdirectories;
- otherwise the sender is unresolved.

An inherited `TEAM_AGENT` MUST NOT override the runtime directory: when it disagrees, the runtime directory
wins and the ignored value MUST be named on stderr. An unresolved call MUST exit non-zero, MUST NOT write an
inbox line and MUST NOT enqueue a knock, and its output MUST name `--from` as the way to state the sender.

The resolved sender MUST be the name in the durable inbox line and in the knock text, in the
`[<tag>] agent:<name> · <text>` position the turn-end notification already uses, and the knock SHALL carry the
same name as the outbox entry's `from:` field, so the wake text and the delivery ledger name the sender too.
The recipient stays the inbox file (`docs/team/inbox/<recipient>.md`) and the knock target. The `[auto]` and
`[manual]` paths SHALL resolve the sender by this same rule, so one runtime context (working directory and
window) yields the same `agent:<name>` in both. Why a silent `pm` fallback is worse than a refusal:
`references/philosophy.md` (a false green is worse than nothing).

#### Scenario: A worker's notification names the worker

- **GIVEN** a project whose seat `dev2` has the worktree `<main>/.worktrees/dev2`, run from that directory
  with `TEAM_AGENT` unset and no tmux
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the command exits 0, `docs/team/inbox/pm.md` gains exactly one line matching
  `[manual] agent:dev2 · `, and no added line is attributed to `pm`

#### Scenario: The PM's own notification still names `pm`

- **GIVEN** the same project, run from the main worktree
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the new line matches `[manual] agent:pm · `

#### Scenario: An inherited `TEAM_AGENT` does not become the sender

- **GIVEN** the `dev2` worktree context above with `TEAM_AGENT=pm` exported
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the new line names `agent:dev2`, and stderr names the ignored `TEAM_AGENT` value

#### Scenario: An unclassifiable runtime directory refuses instead of claiming `pm`

- **GIVEN** a worktree of the same project outside `<main>/.worktrees/` (for example
  `git worktree add <tmp>/elsewhere`), run there with no `--from`
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the command exits non-zero, `docs/team/inbox/pm.md` is byte-identical to its previous content, and
  the output names `--from`

#### Scenario: `--from` is recorded as an explicit claim

- **GIVEN** the same unclassifiable worktree with `--from dev3`
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the command exits 0 and the new line matches `[manual] agent:dev3 · `

#### Scenario: The knock and its queued entry carry the same sender

- **GIVEN** the `dev2` worktree context with `TEAM_NOTIFY_TMUX=1` and a PM input box holding a draft
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** `state/outbox/` holds one entry whose `from:` field is `dev2` and whose payload contains
  `[manual] agent:dev2 · `

#### Scenario: Both paths name the same sender for one runtime context

- **GIVEN** the `dev2` worktree context, used once for `team notify pm --from-file <file>` and once for the
  turn-end extension's settle
- **WHEN** both lines are read
- **THEN** each line's `agent:<name>` token is `dev2`

## MODIFIED Requirements

### Requirement: A turn-end notification appends one inbox line and knocks once

The Pi notify extension SHALL append one line to `docs/team/inbox/<agent>.md` (timestamp, agent, summary) and knock
on the PM window; the same summary MUST be deduplicated inside `TEAM_NOTIFY_DEDUP_SEC` (default 20 s) so a
repeated settle does not spam the PM. The inbox is a local artifact and MUST be gitignored.

`<agent>` SHALL be the sender the extension resolves from its runtime context by the same rule
`notify-and-inbox#A manual notification is attributed to its sender, not its recipient` defines: a session
running in a worktree under the main worktree's worktrees directory is that worktree's name. The tmux window
name MUST NOT override the runtime directory, and a disagreement MUST be written to the extension's log.

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

#### Scenario: The worktree, not the window, names the sender

- **GIVEN** a session whose working directory is `<main>/.worktrees/dev2` while its tmux window is named `dev`
- **WHEN** a turn settles
- **THEN** the line is appended to `docs/team/inbox/dev2.md` with `agent:dev2`, `docs/team/inbox/dev.md` is
  unchanged, and the extension's log names the ignored window
