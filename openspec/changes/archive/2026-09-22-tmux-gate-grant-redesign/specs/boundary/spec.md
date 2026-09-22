# boundary delta · tmux-gate-grant-redesign: the destructive-call grant

## ADDED Requirements

### Requirement: A destructive tmux call is decided by the object it targets, never by an inherited environment

A destructive tmux call made through the gate — the `tmux` executable that the PM and worker launch commands put
first on `PATH`, guarding `kill-server`, `kill-session`, `kill-window` and `kill-pane` including tmux's unambiguous
prefixes — SHALL be decided by the object the call resolves to:

- A call resolving to a **private socket** MUST pass through byte-for-byte and be recorded as `act=pass` (no grant
  is needed there). The socket resolution order, the `realpath`-style candidate table and the **fake isolation**
  verdicts MUST stay as they are.
- A call resolving to the **shared default socket** (`/tmp/tmux-<uid>/default`) MUST be refused with exit 64 unless
  the object it targets is a named object of the caller's own session. `kill-server` MUST always be refused there
  (a server is not a project-owned named object), and `kill-session -a` MUST always be refused there (it targets
  every other session on the shared server). For the three other subcommands, the target counts as the caller's own
  named object only when the effective `-t` value is non-empty and its session component — the part before the
  first `:` — is a literal session name equal to a non-empty `TEAM_SESSION`, with that identity **bound to the
  caller**: `TEAM_ROOT` or `TEAM_MAIN_ROOT` resolves to the gate's cwd or to an ancestor of it. A target that is
  absent, empty, a pane id (`%N`), a window id (`@N`), a relative or empty session component (`:win`, `.`, `+`,
  `-`), or a window name without its session MUST NOT be accepted. An accepted call MUST be executed and recorded
  as `act=allowed-owned`.
- No environment variable SHALL authorize anything. `TEAM_ALLOW_DESTRUCTIVE_TMUX` MUST NOT be read by the gate,
  MUST NOT be exported by the CLI, and its presence in the caller's environment or in the running tmux server's
  global environment MUST NOT change any verdict. No gate action SHALL be named `override`.
- The only way past a refusal MUST be an explicit act of the caller: the gate's own argv token
  `--teamsmith-allow-destructive`, or executing an absolute tmux path, which the gate cannot see. The token MUST be
  a standalone word in the global-option position (before the subcommand); every occurrence MUST be consumed and
  removed before the downstream exec, MUST NOT be exported and MUST NOT appear in the environment of the executed
  process, and MUST be recorded as `act=explicit-flag` — a call carrying it MUST execute and be recorded as
  `explicit-flag` whatever socket it resolves to, because the token is the caller's grant. A token equal to it
  after the subcommand is data and MUST reach the downstream tmux unchanged.
- The refusal MUST exit 64 and name the subcommand, the resolved socket, why the target is not the caller's own
  named object, the argv token and the private-socket route.

#### Scenario: An own-session named target is allowed on the shared socket

- **GIVEN** the gate first on `PATH`, an argv-recording stub pinned as the real tmux (`TEAM_TMUX_REAL`), no `TMUX`
  and no `TMUX_TMPDIR` (so every call resolves to `/tmp/tmux-<uid>/default`), and an identity bound to the caller
  (`TEAM_SESSION=teamx`, `TEAM_ROOT` the gate's cwd or an ancestor of it)
- **WHEN** `tmux kill-window -t teamx:dev`, `tmux kill-pane -t teamx:dev.0` and `tmux kill-session -t teamx` run
- **THEN** each exits 0, the log's new lines carry `act=allowed-owned` with the resolved default socket, and the
  stub received each call's argv byte-for-byte

#### Scenario: A target that is not the caller's own named object is refused

- **WHEN** `tmux kill-window -t otherproj:pm`, `tmux kill-session -t otherproj`, `tmux kill-window -t %1`,
  `tmux kill-window -t dev`, `tmux kill-window -t :dev`, `tmux kill-window -t ""` and `tmux kill-session` run with
  that same bound identity and no `TMUX`/`TMUX_TMPDIR`
- **THEN** each exits 64 with a refusal naming the subcommand and the reason, the log carries `act=refused` for
  each, and the stub was never called

#### Scenario: The server-wide and widening shapes are refused with a complete own identity

- **WHEN** `tmux kill-server`, `tmux kill-ser` and `tmux kill-session -a -t teamx` run with the bound
  `TEAM_SESSION=teamx` identity on the shared default socket
- **THEN** each exits 64 (the refusal names the shared server or the widening), and the stub was never called

#### Scenario: An unbound or empty identity does not authorize a target

- **GIVEN** a caller whose cwd lies outside both `TEAM_ROOT` and `TEAM_MAIN_ROOT` while `TEAM_SESSION=teamx` is
  inherited into its environment
- **WHEN** `tmux kill-window -t teamx:dev` runs, and then the same call with `TEAM_SESSION` unset and with
  `TEAM_SESSION=""` from a bound cwd
- **THEN** each exits 64, the log carries `act=refused`, and the stub was never called

#### Scenario: An inherited environment grants nothing

- **GIVEN** a gate call whose own environment carries `TEAM_ALLOW_DESTRUCTIVE_TMUX=1` and a second one whose server
  was started from such an environment (the variable is in the server's global environment and in every new pane)
- **WHEN** `tmux kill-server`, `tmux kill-window -t otherproj:pm` and `tmux kill-window -t ""` run on the shared
  default socket with no bound identity
- **THEN** each exits 64, the log's new lines carry `act=refused`, and no new line carries `act=override`

#### Scenario: The argv token executes once, is consumed, and stays out of the environment

- **WHEN** `tmux --teamsmith-allow-destructive kill-server` and
  `tmux --teamsmith-allow-destructive kill-window -t otherproj:pm` run on the shared default socket against the
  stub, and then `tmux send-keys -t teamx:dev --teamsmith-allow-destructive` runs
- **THEN** the first two exit 0, the log carries `act=explicit-flag` with the resolved socket, the stub's argv is
  the caller's argv without the token, the executed process's environment carries no such variable, and the third
  reaches the stub with the token as its payload argument

#### Scenario: Private sockets pass and fake isolation still refuses

- **WHEN** `TMUX_TMPDIR=<private directory> tmux kill-server` runs, and then
  `TMUX_TMPDIR=<directory that does not exist>/sock tmux kill-window -t teamx:dev` and
  `TMUX_TMPDIR=<a regular file> tmux kill-session -t teamx` run with a bound identity
- **THEN** the first exits 0 with `act=pass` and the private socket recorded, and the other two exit 64 with the
  fake-isolation wording and the resolved **default** socket recorded

#### Scenario: Read-only calls are never refused

- **WHEN** `ls`, `list-sessions`, `display-message -p hi`, `capture-pane -p -t teamx:dev` and
  `send-keys -t teamx:dev y` run through the gate on the shared default socket
- **THEN** every one reaches the stub, and no new log line carries `act=refused`, `act=allowed-owned` or
  `act=explicit-flag`

### Requirement: The gate's actions are logged, and no window carries a destructive-call grant

Each gated call SHALL append exactly one line to `$TEAM_TMUX_CALLS_LOG` carrying the ISO-8601 timestamp, the
resolved socket, `TMUX`, `TMUX_TMPDIR`, the full argv, the pid and ppid, the cwd, and an action that is exactly one
of `pass`, `refused`, `allowed-owned` or `explicit-flag`. The log SHALL stay bounded (past 2000 lines the oldest go,
the newest 1000 stay) and a target that cannot be written MUST NOT block the call. The launch command of the PM
window and of every worker window SHALL put the gate's directory first on `PATH`, pin `TEAM_TMUX_CALLS_LOG` to the
project's state file and `TEAM_TMUX_REAL` to the resolved real tmux, and MUST NOT write any destructive-call
authorization into the environment: a freshly launched window's environment MUST NOT contain
`TEAM_ALLOW_DESTRUCTIVE_TMUX`, and no `team` command SHALL export it. `TEAM_ALLOW_DESTRUCTIVE_TMUX` SHALL stay
registered in the settings schema as a non-writable legacy key whose description states that it grants nothing, and
`team doctor` SHALL report the key when the running tmux server's global environment still carries it, naming the
server-restart remedy.

#### Scenario: One bounded line with the action vocabulary

- **GIVEN** a gate log that already holds 2100 lines
- **WHEN** calls whose verdicts are refused, allowed-owned, flagged and passed run in turn
- **THEN** each new line carries the timestamp, `sock=`, `TMUX=`, `TMUX_TMPDIR=`, `argv=`, `pid=`, `ppid=` and
  `cwd=`, the action is one of the four defined values, the file holds 1000 lines whose last line is the newest
  call, and a FIFO log target does not block the call

#### Scenario: A freshly launched window carries the gate and no grant

- **WHEN** the PM launch command and a worker launch command are rendered and a worker is dispatched into a real
  window while the dispatching shell has `TEAM_ALLOW_DESTRUCTIVE_TMUX=1` in its environment
- **THEN** the rendered commands carry the gate directory first in `PATH`, `TEAM_TMUX_CALLS_LOG` and
  `TEAM_TMUX_REAL`, and no `TEAM_ALLOW_DESTRUCTIVE_TMUX` assignment; the environment read inside the window
  contains the first two and not the third

#### Scenario: The CLI grants nothing and the retired key is visible

- **WHEN** `team teardown`, a review cleanup and the pulse window close run inside a gated window, and
  `team config set TEAM_ALLOW_DESTRUCTIVE_TMUX 1` runs, and `team doctor` runs while the default server's global
  environment still carries the key
- **THEN** the CLI's destructive calls are logged `act=allowed-owned` (never `explicit-flag` and never `override`),
  the `config set` is refused as a non-writable key without changing the config file, and the doctor output names
  the key, states that it grants nothing, and gives the server-restart remedy; with no such residue the doctor
  prints no line for it

### Requirement: Destructive gate fixtures never aim the real tmux at the real default socket

A fixture that exercises a refusal or an allowed-owned verdict against the shared default socket SHALL pin an
argv-recording stub downstream through `TEAM_TMUX_REAL`, so a wrong verdict executes nothing. A fixture that
executes a destructive call for real SHALL use a private socket (`-L`/`-S` or a private `TMUX_TMPDIR`) or the
container runner. A fixture that reproduces the leak (a server started from a process whose environment carries
`TEAM_ALLOW_DESTRUCTIVE_TMUX`) MUST run inside the container. The repository's isolation lint SHALL keep requiring
its isolation proofs, SHALL classify a mutating call carrying the gate's argv token as mutating (the token cannot
hide a call from the lint), SHALL NOT accept the token as an isolation proof, and SHALL keep reporting a literal
absolute tmux path as red.

#### Scenario: The gate section's default-socket probes cannot execute anything real

- **WHEN** the gate section of the smoke suite runs on a machine with the shared default socket present
- **THEN** every probe whose call resolves to that socket pins `TEAM_TMUX_REAL` to the argv-recording stub, every
  probe that executes a real tmux call resolves to a private socket, and the section's record of the default
  server's liveness before and after shows it unchanged

#### Scenario: The lint sees the token and still demands isolation

- **WHEN** the lint scans a fixture containing `tmux --teamsmith-allow-destructive kill-server`, the same call with
  a private `-L`, and `/usr/bin/tmux -L <private> kill-server`
- **THEN** the first is reported red (no isolation proof), the second is clean, and the third is red

#### Scenario: The leak shape is reproduced in the container

- **GIVEN** the container runner available, and inside it a tmux server started from a process whose environment
  carries `TEAM_ALLOW_DESTRUCTIVE_TMUX=1`
- **WHEN** a pane of that server runs `tmux kill-server` through the gate without the token, and then with
  `--teamsmith-allow-destructive`
- **THEN** the first exits 64 with `act=refused`, the second exits 0 with the container's server gone, and the host
  server fingerprint recorded before and after is byte-identical; with no container runtime the fixture exits 77
  with the SKIP reason and never runs on the host
