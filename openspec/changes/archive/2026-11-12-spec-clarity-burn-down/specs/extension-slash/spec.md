## MODIFIED Requirements

### Requirement: `/team` runs the project's real CLI, and it is user input rather than a tool
The extension SHALL register exactly one Pi slash command, `/team`, and no model-callable tool. A listed invocation SHALL run the project's real `team` CLI as a child process with the user's tokens in order and unchanged. The child SHALL use the project root resolved from the session directory containing `.pi/team/config.sh`, not the extension location, as its working directory.

#### Scenario: It is a command, and nothing else

- **GIVEN** the extension loaded in a Pi session
- **WHEN** the session's available commands and tools are listed
- **THEN** `/team` is present as a command and this extension has registered no tool, so a model turn cannot reach
  the CLI through it

#### Scenario: The user's tokens are exactly what the CLI receives

- **GIVEN** a project initialised by `team init` whose `team` CLI is replaced by a recorder that logs its argv, its
  working directory and its environment, and a Pi session started in that project
- **WHEN** the user submits `/team ps`, and then `/team meeting say alpha --intent proposal "two words"`
- **THEN** the recorder logs the argv `[ps]` and then `[meeting, say, alpha, --intent, proposal, two words]`, with
  the project root as the working directory, and no token the user did not type

### Requirement: The whitelist is one table, and only the shapes it lists run
The extension SHALL accept only shapes listed in one table. Read rows SHALL match their command path plus, where declared, one `<ID>`/`<n>`/`<slug>` argument; action rows SHALL pass remaining user tokens unchanged. Every other invocation SHALL be refused before starting a process; the refusal SHALL name the refused command or token and direct it to the PM or a seat in a terminal. `/team`, `/team help` and completion SHALL render from that same table, the list's only location.

#### Scenario: A command outside the table is refused by name, and nothing runs

- **GIVEN** an initialised project, a recording stand-in CLI and a Pi session in it
- **WHEN** the user submits `/team dispatch dev <id> docs/team/tasks/<id>.md`, and then `/team config set TEAM_AGENTS "x"`
- **THEN** both are refused, each refusal names the refused command (`dispatch`, `config set`) and states that it is
  a PM or seat command to be run in a terminal, and the recorder logged no argv — no child process was started

#### Scenario: A read row accepts only its own shape

- **WHEN** the user submits `/team config list --json` or `/team version --check`
- **THEN** the invocation is refused and nothing runs — a read row does not pass extra tokens through

#### Scenario: The menu and the accepted set are the same list

- **WHEN** `/team` is submitted with no arguments, and the same check is repeated on a copy whose table has one row
  added and another removed
- **THEN** each menu lists every row of that copy's table once, in its declared group, and lists no command that is
  not in it — the menu is not a second hand-written list

#### Scenario: Every row names a command the CLI dispatches

- **GIVEN** the whitelist table and the project CLI
- **WHEN** each row's command path is given a deliberately unknown flag
- **THEN** the CLI answers with its unknown-parameter or subcommand refusal, never with its top-level unknown-command
  refusal naming that row's command — a row naming a command the CLI does not dispatch fails this check

#### Scenario: Editing the table edits both presentation and admission
- **GIVEN** a copy whose table has one row added and another removed
- **WHEN** the menu, completion and admission checks are rendered or run
- **THEN** the added row appears and its listed shape is accepted, while the removed row disappears and its former invocation is refused before a child starts
- **AND** no second hand-written command list supplies either result

### Requirement: The PM-restarting invocation is refused, and no listed invocation can hang the conversation
The extension SHALL refuse `up` and any invocation carrying `--fresh-pm` before starting a child. The refusal SHALL explain that the current session is the PM session, restarting there would replace this conversation, and the command belongs in a terminal. Every listed invocation SHALL run without controlling stdin and with a bounded wait; a child exceeding the bound SHALL be terminated, reported as a failure naming the bound, and neither left running nor awaited further.

#### Scenario: Restarting the PM from its own conversation is refused with the reason

- **GIVEN** a Pi session that is the PM session, and a recording stand-in CLI
- **WHEN** the user submits `/team up`, and then `/team up --fresh-pm`
- **THEN** both are refused, each message says the session is the PM session and that the command belongs in a
  terminal, and the recorder logged no argv

#### Scenario: A child that does not exit is killed and reported, not waited on

- **GIVEN** a stand-in CLI that sleeps past the extension's wait bound
- **WHEN** the user submits a listed invocation
- **THEN** the result is a failure naming the bound, the stand-in is no longer running, and the session is not left
  waiting for it

### Requirement: The result is written where it is visible, and its exit status is never hidden
Successful one-line output of at most 200 characters SHALL produce only a notification. Any other success SHALL add a conversation entry with command line, exit code, stdout and stderr. Non-zero or terminated children SHALL produce a failure notification and that entry, never success. Output beyond 500 lines or 64 KiB, whichever first, SHALL retain beginning and end and identify the elided middle and full-output command.

#### Scenario: A multi-line success arrives in the conversation

- **GIVEN** a stand-in CLI that prints several lines and exits 0
- **WHEN** a listed invocation is submitted
- **THEN** the conversation carries one entry naming the command line and the exit code and carrying the output,
  and no failure notification was raised

#### Scenario: A single short line is a notification only

- **GIVEN** a stand-in CLI that prints one short line and exits 0
- **WHEN** a listed invocation is submitted
- **THEN** a notification with that line is shown and no conversation entry is added

#### Scenario: A failing command is visible as a failure

- **GIVEN** a stand-in CLI that writes to stdout and stderr and exits 3
- **WHEN** a listed invocation is submitted
- **THEN** a failure notification names exit code 3, and the conversation entry carries both streams and the same
  code — it is not reported as a success

#### Scenario: An oversized output is elided with a notice, not dropped

- **GIVEN** a stand-in CLI whose output is longer than the safety bound
- **WHEN** a listed invocation is submitted
- **THEN** the entry carries the first and last lines and a notice that the middle was elided and which terminal
  command prints the full output

### Requirement: The front door adds no authorization of its own and keeps the CLI's guards
The extension MUST NOT add confirmation or inject authorization flags; CLI guards SHALL decide the user's unchanged invocation as in a terminal. The child SHALL inherit the session environment except `TEAM_ASSUME_YES`, `TEAM_UPGRADE_CONFIRMED` and `TEAM_ALLOW_FOREIGN_SESSION`, which MUST NOT be inherited.

#### Scenario: A session's stray "yes" is not the user's authorization

- **GIVEN** a project whose configuration is at a recorded hash, a session whose environment carries
  `TEAM_ASSUME_YES=1`, and a recorder standing in for the CLI
- **WHEN** `/team config upgrade-models --task-models 'routine=vendor/light' --pm-model vendor/strong` is submitted
  without `--yes`, and then the same command with the user's own `--yes`
- **THEN** the first child's logged environment does not carry `TEAM_ASSUME_YES`, `TEAM_UPGRADE_CONFIRMED` or
  `TEAM_ALLOW_FOREIGN_SESSION`, and its argv carries no injected `--yes`; the second child's argv carries the
  `--yes` the user typed — and against the real CLI the first run leaves the configuration's bytes unchanged

#### Scenario: The CLI retains every authorization decision
- **WHEN** a listed invocation reaches the CLI
- **THEN** write-authorization, dispatch, capacity, identity and lifecycle guards decide exactly as they do for the same tokens in a terminal
- **AND** the extension has added neither its own confirmation nor an authorization flag

### Requirement: The command is available where the project installed it
`/team` SHALL be available only in the worktree targeted by the project-local install, discovered from that working directory's `.pi/extensions/`. Install mode, conflicts and doctor evidence SHALL remain governed by `init-skill#team init installs the project skills` and `init-skill#The project-local install is visible in team doctor, and repairable with team init`. A second load path MUST NOT register it twice.

#### Scenario: The main worktree session has it; a checkout without the install does not

- **GIVEN** a project initialised by `team init` and one of its linked worktrees, which the install does not target
- **WHEN** a Pi session starts in each and its commands are listed
- **THEN** the main-worktree session offers `/team` and the worktree session does not, and neither registered it
  twice
