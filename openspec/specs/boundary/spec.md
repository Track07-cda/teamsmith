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
of `pass`, `refused`, `allowed-owned` or `explicit-flag`. Every call whose action is not `pass` is additionally
copied into the gate's long-retention record (`boundary#A destructive call's record outlives the call log's
rotation`); when that copy does not happen, this same line carries `retention=failed` and the gate prints that
requirement's diagnostic — the log still appends exactly one line per call. The log records the caller's traffic —
its content is the caller's own argv and resolved socket — so it MUST NOT be read as project ledger state: the
gate's fixture-trace scan excludes those exact paths
(`verification#The fixture-trace scan reads ledger state, not traffic records`).

The log SHALL stay bounded: past 2000 call lines the oldest go and the newest 1000 stay, a target that cannot be
written MUST NOT block the call, and a log that never crossed the bound carries no rotation marker. When the bound
is enforced, the surviving file MUST say so: its first line is a **rotation marker** carrying the rotation's
ISO-8601 timestamp, the word `rotation` and `dropped=<N>`, where `N` is the cumulative number of call lines no
longer in the file, counted from the last marker whose `N` was readable — zero when the file carries no readable
marker, and a value is readable only when it is a plain decimal count the gate parses back unchanged (an empty,
non-numeric or oversized literal is not). The marker is not a call line — it carries no `act=` action, so the
action vocabulary above stays closed to the four call values — it does not count toward the 2000-line bound, and it
does not survive the next rotation (the new marker replaces it); the newest 1000 call lines always survive, in
order. A marker whose `N` cannot be read MUST NOT make the gate invent a number: the count restarts at zero and
the next marker states the call lines dropped since that restart.

The launch command of the PM window and of every worker window SHALL put the gate's directory first on `PATH`, pin
`TEAM_TMUX_CALLS_LOG` to the project's state file and `TEAM_TMUX_REAL` to the resolved real tmux, and MUST NOT write
any destructive-call authorization into the environment: a freshly launched window's environment MUST NOT contain
`TEAM_ALLOW_DESTRUCTIVE_TMUX`, and no `team` command SHALL export it. `TEAM_ALLOW_DESTRUCTIVE_TMUX` SHALL stay
registered in the settings schema as a non-writable legacy key whose description states that it grants nothing, and
`team doctor` SHALL report the key when the running tmux server's global environment still carries it, naming the
server-restart remedy.

#### Scenario: One bounded line with the action vocabulary

- **GIVEN** a gate log that already holds 2100 lines
- **WHEN** calls whose verdicts are refused, allowed-owned, flagged and passed run in turn
- **THEN** each new line carries the timestamp, `sock=`, `TMUX=`, `TMUX_TMPDIR=`, `argv=`, `pid=`, `ppid=` and
  `cwd=`, the action is one of the four defined values, the file holds one marker plus exactly 1000 call lines
  whose last line is the newest call, and a FIFO log target does not block the call

#### Scenario: A truncated log says so

- **GIVEN** a gate log that already holds 2100 call lines
- **WHEN** one more gated call runs, and then 1100 more gated calls run
- **THEN** after the first rotation the file's first line is the rotation marker — the rotation's timestamp,
  `rotation`, `dropped=1101` — and exactly 1000 call lines follow with the newest call last; the second rotation
  then runs 1100 call lines past the bound and its marker carries the cumulative count (`dropped=2201`), no call
  line carries an action outside the four values, and a log that never crossed the bound carries no marker at all
  — on the pre-change shim the same two rotations leave no trace that history was dropped (that red side is in
  the delivery report)

#### Scenario: An unreadable marker restarts the count

- **GIVEN** a gate log whose first line is a rotation marker carrying `dropped=abc` followed by 2100 call lines
- **WHEN** one more gated call runs
- **THEN** the file's first line is a new marker with `dropped=1101` — this rotation's removals, counted from zero
  because the old count was unreadable — the unreadable marker is gone, and exactly 1000 call lines follow with the
  newest call last

#### Scenario: An oversized count is not readable

- **GIVEN** a gate log whose first line is a rotation marker carrying a `dropped=` literal too large for the gate's
  arithmetic followed by 2093 call lines
- **WHEN** one more gated call runs
- **THEN** the file's first line is a new marker with `dropped=1094` — this rotation's removals, counted from zero
  because the oversized count cannot be parsed back — never a wrapped number, the oversized marker is gone, and
  exactly 1000 call lines follow

#### Scenario: The marker does not count toward the bound

- **GIVEN** a gate log whose first line is a rotation marker followed by 1999 call lines
- **WHEN** one more gated call runs
- **THEN** no new rotation happens — the file is a marker plus exactly 2000 call lines, and that marker is
  unchanged — because the marker is not a call line and the bound counts call lines only

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

### Requirement: A destructive call's record outlives the call log's rotation

For every gated call whose action is not `pass` — `refused`, `allowed-owned` or `explicit-flag` — the gate SHALL
append the call log's line for that call, byte for byte, to a **long-retention file** at the exact path
`$TEAM_TMUX_CALLS_LOG.forensics`, beside the call log, so the destructive call stays readable after the call log
has rotated its line away. A call whose action is `pass` SHALL NOT be copied into that file — including a
destructive subcommand the gate passed on a private socket — because retention covers the gate's destructive
verdicts, not the whole traffic: the verdict decides, never the subcommand's name.

A retained line MUST carry the same ISO-8601 timestamp, action, resolved socket, `TMUX`, `TMUX_TMPDIR`, argv,
pid/ppid and cwd as the call log's line, so the two files can be cross-checked: while the call log still holds the
line the two MUST be byte-identical, and once the call log has dropped it, the call log's rotation marker's
`dropped=<N>` MUST account for a line that was really there.

The retention file SHALL obey the call log's own bound rule and rotation: past 2000 lines the oldest go and the
newest 1000 stay, and when the bound is enforced the surviving file's first line is the same rotation marker
(ISO-8601 timestamp, `rotation`, `dropped=<N>`) with the same counting and restart rules — the marker is not a
line, it does not count toward the bound and it does not survive the next rotation. Long retention MUST NOT mean
unbounded growth: no line is exempt from that bound, so a `pass`-shaped line in the file — planted there or left
by an older version — carries no retention promise and is dropped by the same rotation as any other line.

A retention that does not happen MUST NOT stay silent: when the file cannot be appended to (including a FIFO
target, which the gate skips instead of blocking on it), the gate SHALL print a `✗`-marked diagnostic on stderr
naming the retention path, and the call log's line SHALL carry `retention=failed` so the gap stays readable there
too. Retention never changes the verdict: a refused call still exits 64, an allowed call still executes, and a
retention failure changes neither.

#### Scenario: The retained line is the call log's line

- **GIVEN** a scratch gate log whose sibling retention file does not exist
- **WHEN** a gated `kill-server` call without the token is refused
- **THEN** the retention file holds exactly one line, byte-identical to the call log's line for that call
  (`grep -F` over the call log matches it), carrying the call's timestamp, `act=refused`, its argv, pid/ppid and cwd

#### Scenario: A destructive record survives the call log's rotation

- **GIVEN** a scratch gate whose retention file already holds the line of a refused call and whose call log is then
  seeded with 2100 later call lines
- **WHEN** one more gated call runs, forcing the call log's rotation
- **THEN** the call log no longer holds the refused line — its first line is the rotation marker and its `dropped`
  count accounts for the removed lines — while the retention file still holds the refused line byte for byte; on
  the pre-change shim that line existed only in the call log and is gone (that red side is in the delivery report)

#### Scenario: The retention file is bounded and says when it rotated

- **GIVEN** a scratch gate whose retention file is seeded with 2100 lines, and a second scratch gate whose
  retention file holds three lines
- **WHEN** a gated refused call runs through the first gate, and a gated refused call through the second
- **THEN** the first file's first line is the rotation marker with `dropped=1101` and exactly 1000 lines follow
  with the refused call last, while the second file holds its four lines and no marker

#### Scenario: A failed retention is visible and never blocks

- **GIVEN** a scratch gate whose call log is writable and whose retention path already exists as a directory, and a
  second scratch gate whose retention path is a FIFO
- **WHEN** an `allowed-owned` call runs through the first gate and a refused `kill-server` call through the second
- **THEN** the first call reaches the stub and exits with the stub's status, its call log line carries
  `act=allowed-owned` and `retention=failed`, and stderr carries the `✗`-marked diagnostic naming the retention
  path; the second call still exits 64 within the probe's timeout, with the same diagnostic and no blocked write

#### Scenario: A `pass` call is not retained

- **GIVEN** a scratch gate whose retention file holds the line of one refused call
- **WHEN** three gated read-only calls run
- **THEN** the retention file is byte-identical to before them and no line carries a read-only call's argv, while
  the call log holds their three `act=pass` lines

