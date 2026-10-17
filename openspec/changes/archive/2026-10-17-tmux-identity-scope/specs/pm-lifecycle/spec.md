## ADDED Requirements

### Requirement: Starting this project's tmux objects never writes its identity into the shared server's environment

Every tmux object this project creates — the session and PM window of `team up`, the patrol window of
`team pulse up`, a dispatch window, a draft window — SHALL be created by a tmux client whose environment does not
carry this project's `TEAM_*` namespace. A tmux server copies the environment of the client that starts it into
the server's **global** environment, and every session and pane created afterwards on that server inherits it,
whichever project it belongs to; the client that may start the server therefore MUST be run with that namespace
removed, and the identity the created objects need SHALL reach them through their own session scope or through the
launch command rendered into the window. No product path SHALL write the running server's global environment
(`set-environment -g`) with this project's variables. Both consequences are required: the global environment of a
server this project started carries no `TEAM_*` variable of this project, and the windows this project created
still carry the identity of the directory they belong to (a worker window its worktree; the PM, patrol and draft
windows the main worktree).

#### Scenario: A server started by `team up` carries no `TEAM_*`

- **GIVEN** a private socket with no running server, and a shell whose environment carries this project's identity
  variables and the gate's pins
- **WHEN** `team up` creates the session and the PM window
- **THEN** `tmux show-environment -g` names no `TEAM_*` variable, and the PM window's process environment still
  carries the identity of the main worktree
- **AND** with the creating client's environment left intact the same start leaves the identity variables in the
  global environment, so the assertion can fail (that red side is in the apply report)

#### Scenario: Another project's session on the same server inherits nothing

- **GIVEN** a second project with its own session on the same running server
- **WHEN** a pane of that session is read
- **THEN** its environment carries none of the first project's `TEAM_*` values, and the first project's session and
  windows are unchanged

#### Scenario: The tool never writes the shared server's global environment

- **GIVEN** a running private server
- **WHEN** the tool creates its session, opens and closes its own windows, and runs its own destructive calls
  against its own named objects
- **THEN** the server's global environment is byte-identical before and after, and it carries no `TEAM_*` variable
  of this project

### Requirement: Identity inherited from the shared server's global environment resolves by the working directory

When the identity gate finds inherited `TEAM_*` values disagreeing with the project the working directory belongs
to, and **every** disagreeing variable's inherited value is exactly the value the running tmux server holds in its
**global** environment for that variable, the command SHALL treat the disagreement as residue of that shared
server rather than as the caller's intent: it SHALL resolve the project from the working directory, print one line
naming the running server's global environment as the source and the route that removes it, and it MUST NOT clear,
rewrite or otherwise change anything in that server's global environment. Every other disagreement keeps the
existing refusal unchanged — the same wording, the same non-zero exit and the same explicit escape hatches — a
deliberately inherited foreign environment, a disagreement whose value the server does not hold, a disagreement
with no tmux server to attribute it to, and a nested invocation whose inherited identity is its own project's. The
one-line notice SHALL go to standard error so machine-readable output stays parseable. `team doctor` SHALL report
such residue read-only, naming the variables and the command that removes them, and MUST NOT change it.

#### Scenario: Residue of the shared server stops blocking another project

- **GIVEN** a running private server whose global environment carries another project's `TEAM_ROOT`,
  `TEAM_MAIN_ROOT`, `TEAM_PROJECT` and `TEAM_SESSION`, and a project whose shell inherits exactly those values
- **WHEN** a command that starts this project's windows runs from that project's directory
- **THEN** it exits 0, the objects it creates belong to that project, the other project's session and windows are
  untouched, one line on standard error names the running server's global environment, and the server's global
  environment is unchanged
- **AND** before the change the same call is refused with the identity-conflict message and creates nothing (that
  red side is in the apply report)

#### Scenario: A deliberate foreign environment is still refused

- **GIVEN** the same identity values in a shell's environment while the running server's global environment does
  not carry them
- **WHEN** a command that would act on shared state runs from the other project's directory
- **THEN** it is refused with the existing identity-conflict wording and a non-zero exit, nothing is created,
  nothing is cleared, and the server's global environment is unchanged

#### Scenario: A matching inherited identity is untouched

- **GIVEN** a nested invocation — a fixture, a gate or a worker window — whose inherited identity is its own
  project's
- **WHEN** a command runs there
- **THEN** no residue line is printed, no variable is cleared, and no global environment write happens

#### Scenario: The residue is visible without being changed

- **GIVEN** a running server whose global environment carries residue
- **WHEN** `team doctor` runs
- **THEN** its output names the residue variables and the command that removes them, and the server's global
  environment is byte-identical afterwards
