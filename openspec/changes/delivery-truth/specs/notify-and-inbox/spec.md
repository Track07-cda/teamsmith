## MODIFIED Requirements

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
