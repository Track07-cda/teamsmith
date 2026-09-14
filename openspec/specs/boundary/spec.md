# boundary Specification

## Purpose

Where the team may act: inside the project, inside its own tmux session, with directories owned by the actor, and
never in another project's repository, session or credentials. Why these guards exist (empty tmux targets, foreign
sessions, cross-directory edits): `references/protocol.md` and `AGENTS.md`'s team protocol section.

## Requirements

### Requirement: Actions stay inside the project and its own session

A `team` command SHALL act on the project root it resolved and on the tmux session `TEAM_SESSION` only. It MUST NOT
create, modify or delete files in another project, and it MUST NOT read or write another project's state
(`.pi/team/**`) — cross-project traffic goes through `team meeting` (see the `meeting` capability).

#### Scenario: Another project's session is not touched

- **GIVEN** two initialised projects with different `TEAM_SESSION` values
- **WHEN** a `say`, `notify`, `close` or `up` is aimed at the other project's session
- **THEN** the command is refused (or resolves only the current project) and the other project's files are unchanged

### Requirement: Empty or relative tmux targets are refused

Because tmux treats an empty `-t` as "the current pane/window/session", every destructive or typing operation in the
skill MUST reject an empty or relative target before calling tmux, and MUST print what it refused.

#### Scenario: An empty target cannot hit the caller

- **WHEN** an internal kill-window / respawn-pane / send-keys call is made with an empty target
- **THEN** it exits non-zero with a message that the target is required, and no window or pane is affected

### Requirement: Typing into a foreign session needs an explicit, human-granted override

With `TEAM_GUARD_FOREIGN_TARGET=1` (the default) the skill MUST refuse to type into a window that is not in
`TEAM_SESSION`. The refusal MUST name the target and the guard, and the only ways to proceed MUST be an explicit
environment override plus user authorization — never a silent fallback.

#### Scenario: The refusal is explicit

- **WHEN** `team say other:pm "…"` runs while `other` is not the team session
- **THEN** the command exits non-zero, prints the refused target and the guard name, and the other session's pane is
  unchanged

### Requirement: Credentials are never read, echoed or committed

No `team` command SHALL read credential files (`~/.pi/agent/auth.json`, the project's token file), and token values
MUST NOT appear in any command output, log or commit. Tokens are injected by the PM into real tool calls
(`GH_TOKEN="$(< <token file>)" gh …`) and never pass through the skill.

#### Scenario: A sentinel token never appears in output

- **GIVEN** a fixture home containing `~/.pi/agent/auth.json` whose content includes the marker `SENTINEL-TOKEN` and
  a project token file with the same marker
- **WHEN** `team doctor`, `team paths`, `team roster` and `team dispatch … --print` run against that fixture home
- **THEN** no command output (stdout or stderr) contains `SENTINEL-TOKEN`

#### Scenario: The scripts contain no credential reads

- **WHEN** the skill's scripts are searched for reads of `auth.json` or of the configured token file
- **THEN** there is no such read (the token file path is only ever printed as a hint for the PM)

### Requirement: An actor touches only the paths its brief allows

A task's changes SHALL stay inside the paths its brief allows: ownership comes from `docs/team/OWNERSHIP.md`, and a
need for another owner's directory MUST be reported as `BLOCKED:` in the worker's report instead of edited. The
PM's review SHALL show the changed file list, so an out-of-ownership change is visible in the evidence.

#### Scenario: An out-of-scope change is visible in the review

- **GIVEN** a task whose brief allows only `docs/team/reports/**` and a branch that also changed
  `skills/teamsmith/scripts/team`
- **WHEN** `team review <ID> --dir <checkout>` runs
- **THEN** the record's file list contains both paths, so the reviewer can reject the out-of-scope change
