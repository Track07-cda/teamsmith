# extension-slash Specification

## Purpose
The `/team` slash command is the human's front door from a Pi conversation to the project's real teamsmith CLI: a
short, curated list of the commands a user runs by hand (status reads and the few actions they own) is executed as a
child process and its output and exit status are brought back into the conversation. It adds no command of its own,
no authorization of its own, and no model-callable tool: the user typed it, and the CLI's own guards decide.
## Requirements
### Requirement: `/team` runs the project's real CLI, and it is user input rather than a tool

The extension SHALL register exactly one Pi slash command (`/team`) and MUST NOT register a model-callable tool, so
that no model turn can invoke it. A listed invocation SHALL be executed by running the project's `team` CLI as a
child process whose arguments are the user's own tokens, in order, unchanged — the extension MUST NOT implement,
wrap or reinterpret any teamsmith command, and MUST NOT add, remove or rewrite a token. The child SHALL run with
the project root as its working directory, and the project SHALL be resolved from the session's directory (the
directory holding `.pi/team/config.sh`), not from the extension's own location.

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

The extension SHALL accept only the invocations listed in one table: read rows match a fixed shape (their command
path plus, where the row carries one, a single `<ID>`/`<n>`/`<slug>` argument), and action rows match their command
path followed by the user's remaining tokens, passed through unchanged. Every other invocation SHALL be refused
before any process is started; the refusal SHALL name the refused command or token and SHALL say that this command
belongs to the PM or a seat and is to be run in a terminal. The menu printed by `/team` with no arguments (and by
`/team help`) and the command-line completion SHALL be rendered from the same table, and the table MUST be the only
place the list lives: a row added to it appears in the menu, a row removed from it disappears from both the menu and
the set of accepted invocations.

#### Scenario: A command outside the table is refused by name, and nothing runs

- **GIVEN** an initialised project, a recording stand-in CLI and a Pi session in it
- **WHEN** the user submits `/team dispatch dev P1 docs/team/tasks/P1.md`, and then `/team config set TEAM_AGENTS "x"`
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

### Requirement: The PM-restarting invocation is refused, and no listed invocation can hang the conversation

An invocation that is the CLI's `up` command, or that carries `--fresh-pm`, SHALL be refused and MUST NOT be started:
its message SHALL say that the session it was typed in is the PM session, so starting it here would replace the
conversation the user is in, and that it belongs in a terminal. Every listed invocation SHALL run without a
controlling stdin and under a bounded wait: a child still running at that bound SHALL be terminated and reported as
a failure that names the bound, and MUST NOT be left running or waited on further.

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

A successful result SHALL be placed by its size: an output that is a single line of at most 200 characters SHALL
be reported as a notification and SHALL NOT add an entry to the conversation; any other successful output SHALL be
written into the conversation as an entry that carries the command line, the exit code and the output (stdout and
stderr). A child that exited non-zero, or that was terminated, MUST be reported as a failure: a notification of
the failure kind naming the exit code or the reason, and always an entry carrying the command line, the exit code
and the output — a non-zero exit MUST NOT be presented as success. When the output exceeds the safety bound (500
lines or 64 KiB, whichever is reached first) the entry SHALL carry the beginning and the end and a notice that the
middle was elided and how to read the full output.

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

The extension MUST NOT ask for a confirmation of its own and MUST NOT inject an authorization flag: an invocation
runs exactly the tokens the user typed, so every guard the CLI owns (write authorization, dispatch guards, capacity,
identity and lifecycle checks) decides as it does in a terminal. The child environment SHALL be the session
environment without the variables that authorize on the user's behalf — `TEAM_ASSUME_YES`, `TEAM_UPGRADE_CONFIRMED`
and `TEAM_ALLOW_FOREIGN_SESSION` — which MUST NOT be inherited from the session.

#### Scenario: A session's stray "yes" is not the user's authorization

- **GIVEN** a project whose configuration is at a recorded hash, a session whose environment carries
  `TEAM_ASSUME_YES=1`, and a recorder standing in for the CLI
- **WHEN** `/team config upgrade-models --task-models 'routine=vendor/light' --pm-model vendor/strong` is submitted
  without `--yes`, and then the same command with the user's own `--yes`
- **THEN** the first child's logged environment does not carry `TEAM_ASSUME_YES`, `TEAM_UPGRADE_CONFIRMED` or
  `TEAM_ALLOW_FOREIGN_SESSION`, and its argv carries no injected `--yes`; the second child's argv carries the
  `--yes` the user typed — and against the real CLI the first run leaves the configuration's bytes unchanged

### Requirement: The command is available where the project installed it

`/team` SHALL be available in the session that runs in the worktree the project-local install targets, and absent
where that install did not happen: the extension is a project-local Pi extension discovered from the working
directory's `.pi/extensions/` (the install mode, the conflict table and the doctor row are
`init-skill#team init installs the project skills` and
`init-skill#The project-local install is visible in team doctor, and repairable with team init`). It MUST NOT also
be injected through a second load path for the same session, so the command is registered exactly once.

#### Scenario: The main worktree session has it; a checkout without the install does not

- **GIVEN** a project initialised by `team init` and one of its linked worktrees, which the install does not target
- **WHEN** a Pi session starts in each and its commands are listed
- **THEN** the main-worktree session offers `/team` and the worktree session does not, and neither registered it
  twice

