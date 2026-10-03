## MODIFIED Requirements

### Requirement: A manual notification is attributed to its sender, not its recipient

`team notify <recipient> …` SHALL attribute the message to the sender it resolves from the caller's runtime
context and MUST NOT use the recipient as the sender. The resolution SHALL be, in this order:

- an explicit `--from <name>` claim, recorded verbatim; when it disagrees with the runtime directory the
  disagreement MUST be named on stderr;
- the runtime directory (`team`'s M40 identity): a worktree under the main worktree's worktrees directory
  resolves to that worktree's own directory name, also when the process runs in one of its subdirectories; the
  project's main worktree resolves to `pm` only while no **seat clue** is present — with a seat clue the call is
  refused instead of resolved (below);
- otherwise the sender is unresolved.

A **seat clue** is a name of this project's roster (`TEAM_AGENTS`): a name outside the roster is not a clue, and
a clue MUST NOT become the sender — it only vetoes the main worktree's `pm`. The clues are the window name of
the caller's own tmux pane, read with `tmux display-message -p -t "$TMUX_PANE" '#{window_name}'` and only when
that pane's session is this project's `TEAM_SESSION`, and an inherited `TEAM_AGENT`. A window name read without
the caller's own pane answers the attached client's current window — an echo, not evidence — and a window of
the same name in another session is not this project's seat. A clue that names `pm` agrees with the directory
and is not a conflict.

A call from the main worktree that carries a seat clue MUST exit non-zero, MUST NOT write an inbox line and MUST
NOT enqueue a knock: the ledger records the author, so the directory's `pm` claim MUST NOT be recorded and the
clue MUST NOT be adopted. Its output MUST name the directory's `pm`, each clue with its source and its name, and
both ways out — state the sender explicitly with `--from <name>`, or run the command from the caller's own
worktree under the main worktree's worktrees directory.

An inherited `TEAM_AGENT` MUST NOT override the runtime directory: when it disagrees, the runtime directory wins
and the ignored value MUST be named on stderr — except that a roster name in `TEAM_AGENT` makes the main
worktree's call the seat-clue refusal above, where that value is named as the clue instead. An unresolved call
MUST exit non-zero, MUST NOT write an inbox line and MUST NOT enqueue a knock, and its output MUST name
`--from` as the way to state the sender.

The resolved sender MUST be the name in the durable inbox line and in the knock text, in the
`[<tag>] agent:<name> · <text>` position the turn-end notification already uses, and the knock SHALL carry the
same name as the outbox entry's `from:` field, so the wake text and the delivery ledger name the sender too.
The recipient stays the inbox file (`docs/team/inbox/<recipient>.md`); the manual notification knock still targets the PM. The inbox declaration carried through the outbox and the wake full-text path MUST identify that same recipient file, not infer a file from the PM knock destination. The declaration MUST be made only after a successful durable write. A failed write MUST exit non-zero without a wake that asserts the file was written; it MUST NOT be converted into success by a warning. The `[auto]` and
`[manual]` paths SHALL resolve the sender by this same rule, so one runtime context (working directory and
window) yields the same `agent:<name>` in both. Why a silent `pm` fallback is worse than a refusal:
`references/philosophy.md` (a false green is worse than nothing).

#### Scenario: A manual worker inbox and PM wake name the same full-text file

- **GIVEN** a real Pi PM inbox watcher and recipient `dev` in the roster, with no `docs/team/inbox/pm.md`, and explicit sender `pm`
- **WHEN** `team notify dev --from pm "pointer truth probe"` runs
- **THEN** exactly one durable line is appended to `docs/team/inbox/dev.md` naming `agent:pm`, the PM receives one wake, the outbox inbox-written declaration and wake full-text path both name `dev`, the referenced file exists and contains the full text, and no `pm.md` is fabricated merely to conceal a pointer mismatch

#### Scenario: The same pointer survives a queued PM knock

- **GIVEN** recipient `dev`, sender `dev2`, a PM draft, and then a cleared PM box
- **WHEN** `team notify dev --from dev2 "queued pointer probe"` runs and later `team outbox flush` drains its knock
- **THEN** `dev.md` holds one durable line, the queued entry's inbox-written declaration names `dev`, the PM draft receives no key before clearing, and the eventual knock points to that same existing full-text file with sender `dev2`

#### Scenario: A failed durable write cannot authorize a wake

- **GIVEN** an unwritable recipient inbox directory and a live PM watcher
- **WHEN** `team notify dev --from pm "write refusal probe"` runs
- **THEN** it exits non-zero and names the failed path, emits no wake asserting that the inbox was written, and creates no inbox-written declaration for a nonexistent line

#### Scenario: An inbox-only notification retains its named recipient

- **GIVEN** `TEAM_NOTIFY_TMUX=0`, recipient `dev` and explicit sender `pm`
- **WHEN** `team notify dev --from pm "inbox only probe"` runs
- **THEN** it writes one line to `dev.md` naming `agent:pm`, attempts no knock and creates no outbox entry

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

#### Scenario: A seat clue in the main worktree refuses instead of claiming `pm`

- **GIVEN** the project's main worktree, run from a pane whose own window is named `dev` in this project's
  session, with `TEAM_AGENT` unset and no `--from`
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the command exits non-zero, `docs/team/inbox/pm.md` is byte-identical to its previous content,
  `state/outbox/` gains no entry, and the output names `pm` as what the runtime directory claims, names `dev`
  as the window-name clue, and names both ways out: `--from`, and the caller's own worktree

#### Scenario: The window clue is the caller's own pane, not the client's current window

- **GIVEN** the project's main worktree, run from a pane whose own window is named `dev2` in this project's
  session, with the attached client's current window named `pm`
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the command exits non-zero, no line is added to `docs/team/inbox/pm.md`, and the output names `dev2`
  as the window-name clue (a window name read without the caller's own pane answers the attached client's
  current window — an echo, not evidence)

#### Scenario: An inherited roster name refuses the main worktree's call

- **GIVEN** the project's main worktree with no tmux and `TEAM_AGENT=dev` exported
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the command exits non-zero, `docs/team/inbox/pm.md` is byte-identical to its previous content,
  `state/outbox/` gains no entry, and the output names `TEAM_AGENT` and `dev` as the clue

#### Scenario: A name outside the roster is not a clue

- **GIVEN** the project's main worktree with `TEAM_AGENT=nosuch` exported and no tmux
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the command exits 0 and the new line matches `[manual] agent:pm · `
- **AND** the same holds when the caller's window is named `nosuch` in this project's session, so an unknown
  name neither refuses the call nor becomes the sender

#### Scenario: Another session's window of the same name is not a clue

- **GIVEN** the project's main worktree, run from a pane whose own window is named `dev` in a session that is
  not this project's `TEAM_SESSION`
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the command exits 0 and the new line matches `[manual] agent:pm · `

#### Scenario: An explicit `--from` is still honoured with a seat clue present

- **GIVEN** the project's main worktree, run from a pane whose own window is named `dev` in this project's
  session
- **WHEN** `team notify pm --from dev3 --from-file <file>` runs
- **THEN** the command exits 0, the new line matches `[manual] agent:dev3 · `, and stderr names the
  disagreement with the runtime directory's `pm`

#### Scenario: A seat worktree is not refused by a roster clue

- **GIVEN** the `dev2` worktree context with `TEAM_AGENT=dev3` exported
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the command exits 0, the new line matches `[manual] agent:dev2 · `, and stderr names the ignored
  `TEAM_AGENT=dev3` (the clue list vetoes the main worktree's `pm` only)

