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

The launch command of the PM window and of every worker window SHALL put the gate's directory — the one holding
the tmux gate and the signal gate — first on `PATH`, and pin, beside `TEAM_TMUX_CALLS_LOG` (the project's state
file) and `TEAM_TMUX_REAL` (the resolved real tmux), `TEAM_SIGNAL_CALLS_LOG` (the project's signal call log) and
`TEAM_SIGNAL_REAL` (the resolved real executable the signal gate passes a read-only call through to). It MUST NOT
write any destructive-call authorization into the environment: a freshly launched window's environment MUST NOT
contain `TEAM_ALLOW_DESTRUCTIVE_TMUX` or any signal-family authorization, and no `team` command SHALL export one.
`TEAM_ALLOW_DESTRUCTIVE_TMUX` SHALL stay registered in the settings schema as a non-writable legacy key whose
description states that it grants nothing, and `team doctor` SHALL report the key when the running tmux server's
global environment still carries it, naming the server-restart remedy.

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

#### Scenario: The rendered window carries the whole gate family

- **WHEN** the PM launch command and a worker launch command are rendered
- **THEN** both put the gate directory first in `PATH` and pin `TEAM_SIGNAL_CALLS_LOG` and `TEAM_SIGNAL_REAL`
  beside `TEAM_TMUX_CALLS_LOG` and `TEAM_TMUX_REAL`, and neither writes an authorization assignment for either
  gate

#### Scenario: The window's gate resolves the name-selecting tools

- **GIVEN** a window launched with the rendered prefix
- **WHEN** `command -v pkill` and `command -v killall` run inside it
- **THEN** both name the gate directory, and the window's environment carries the two signal pins

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

### Requirement: Signals go to a recorded pid, never to a name or a pattern

The `pkill` and `killall` executables that the launch command puts first on `PATH`
(`boundary#The gate's actions are logged, and no window carries a destructive-call grant`) SHALL refuse every
invocation that would select processes: the call MUST exit 64 without executing the real tool and without sending
any signal, and MUST print the intercepted tool, its full argv, why a name or a command-line pattern cannot prove
ownership (it reaches another project's or another session's process, and the caller's own shell), and the safe
routes (`team bg list` for a job's recorded pid, `team bg stop <id>`, and `kill` with a pid the caller recorded).

No argument makes a `pkill`/`killall` selection provable: `-f <pattern>` and `-x <exact name>` both select by name,
`-P <pid>` and `-u <user>` select a set an unbounded predicate defines, and `killall` is name-selection by
definition. These tools therefore MUST NOT have an allowed selection form. The gate MUST NOT read any environment
variable as an authorization or accept any signal-family override token. For each intercepted tool, the single
argument `--help`, `-h`, `-V` or `--version` selects nothing and SHALL reach that tool's resolved real executable
unchanged and be recorded as `act=pass`; no other arguments may accompany an informational token. A refusal MUST
NOT depend on resolving the real executable.

The same launch `PATH` SHALL also intercept `pgrep` and `pidof`. Apart from the single informational arguments
above, `pgrep` SHALL pass only these complete argv forms:

- `-g N` or `-P N`, where `N` matches `[1-9][0-9]*` (one explicit positive decimal group or parent ID);
- `-fc PATTERN`, `-f -c PATTERN` or `-c -f PATTERN`, where `PATTERN` is one nonempty argument that does not begin
  with `-`. These forms return only a count, not a PID list.

Every other `pgrep` form and every selecting `pidof` form MUST exit 64 before resolving or executing a real
selector, produce no stdout, and print the intercepted tool, full argv, refusal reason and recorded-PID safe
routes. In particular, default name selection, PID-producing full-command patterns, user/group-owner selection,
zero or implicit IDs, lists, inversion, extra predicates and unrecognized option spellings MUST be refused.
Allowed queries SHALL preserve argv, stdout, stderr and exit status from the correct same-name real tool, and
SHALL be recorded as `act=pass`. A `TEAM_SIGNAL_REAL` pin naming `pkill` or `killall` MUST NOT route an allowed
`pgrep`/`pidof` call to that other tool; each new selector SHALL resolve its own name outside the gate directory.
New calls and refusals SHALL obey `boundary#The signal gate's calls are recorded, and its refusals outlive the
call log's rotation` without a new action vocabulary or logging channel.

A parent/group query is diagnostic, not proof that its returned PIDs were recorded by a spawner. A count is not a
PID. Neither permits signalling by predicate. `kill`, `ps` and `fuser` SHALL NOT be intercepted. The gate remains
a `PATH` shim: absolute executables (including `/usr/bin/pgrep` and `/usr/bin/pidof`), ungated shells, shell
functions and other sources of PID lists remain outside its reach. The script layer remains
`boundary#Scripts select processes by recorded pid, and the lint keeps it that way`; rationale and residual
boundaries live in `skills/teamsmith/references/protocol.md`.

#### Scenario: A pattern kill is refused, executes nothing, and the decoys live

- **GIVEN** the signal gate first on `PATH`, a scratch `TEAM_SIGNAL_CALLS_LOG`, `TEAM_SIGNAL_REAL` pinned to an
  argv-recording stub, and two decoy processes this fixture spawned and holds the pids of
- **WHEN** `pkill -f '<the marker both decoys carry>'` runs
- **THEN** it exits 64, its message names `pkill -f`, the marker, why a pattern is not an identity and
  `team bg stop`, the stub recorded no call, both decoys are alive, and the call log's new line carries
  `act=refused`

#### Scenario: Every selecting form is refused

- **WHEN** `pkill -x sleep`, `pkill -P <a pid the caller owns>`, `pkill -u "$(id -u)"` and `killall sleep` run
  through the gate
- **THEN** each exits 64 with a message naming the tool and the reason, the stub recorded no call, and the call log
  holds one `act=refused` line per call

#### Scenario: An inherited environment grants nothing

- **GIVEN** a gated shell whose environment carries `TEAM_ALLOW_PATTERN_KILL=1`, and a child shell started from it
- **WHEN** `pkill -f '<a marker>'` runs in each
- **THEN** both exit 64, the stub recorded no call, and no call-log line carries an action outside `pass`/`refused`

#### Scenario: The read-only forms pass through

- **WHEN** `pkill --help`, `pkill -V`, `killall --help` and `killall -V` run with the stub pinned
- **THEN** each exits with the stub's status, the stub's record carries that call's argv byte for byte, and the
  call log's lines for them carry `act=pass`

#### Scenario: The pid-exact route stays open

- **WHEN** `kill -TERM <the recorded pid of one decoy>` runs from a gated shell
- **THEN** that decoy is gone while the other decoy is alive, and the call log holds no line for that call (the
  gate does not intercept `kill`)

#### Scenario: The launched PATH intercepts both selectors

- **GIVEN** a PM window and a worker window launched with the rendered gate prefix inside the disposable container
- **WHEN** `command -v pgrep` and `command -v pidof` run in each window
- **THEN** all four paths name the gate directory, both windows carry `TEAM_SIGNAL_CALLS_LOG`, and their pins grant
  no selection override

#### Scenario: PID-producing pattern, name and owner queries are refused

- **GIVEN** a gated shell with recording same-name selector stubs immediately after the gate on `PATH`
- **WHEN** `pgrep -f marker`, `pgrep --full marker`, `pgrep -fmarker`, `pgrep -x sleep`, `pgrep sleep`,
  `pgrep -u 1000`, `pgrep -U 1000`, `pgrep -G 1000`, `pidof sleep` and `pidof -s sleep` run
- **THEN** each exits 64 with empty stdout and a diagnostic naming the tool, argv and safe routes, the stubs
  received no call, and each call adds one `act=refused` line with the correct `tool=`

#### Scenario: Explicit group and parent diagnostics retain their tool semantics

- **GIVEN** a fixture-owned recorded group ID `GROUP` and parent ID `PARENT`, and same-name selector stubs
- **WHEN** `pgrep -g "$GROUP"` and `pgrep -P "$PARENT"` run
- **THEN** each reaches only the `pgrep` stub with identical argv, stdout, stderr and exit status (including a
  configured nonzero status), and the log records `act=pass`; neither call sends any signal

#### Scenario: The existing FAST count-only assertion is not blocked

- **GIVEN** a stub that returns stdout `0` and exit 1 for no matches, and a second response `2` and exit 0
- **WHEN** `pgrep -fc /tmp/p164-fixture/pi-sleep`, `pgrep -f -c /tmp/p164-fixture/pi-sleep` and
  `pgrep -c -f /tmp/p164-fixture/pi-sleep` run with each response
- **THEN** stdout and status are preserved in all six calls, the stub's argv is unchanged, the log records
  `act=pass`, and no `.forensics` line is added for them

#### Scenario: Partial allowlist matches and implicit IDs cannot widen selection

- **WHEN** `pgrep -g 0`, `pgrep -P 0`, `pgrep -g 1,2`, `pgrep -P -1`, `pgrep -g`, `pgrep -P ''`,
  `pgrep -P 12 -v`, `pgrep -v -g 12`, `pgrep -g 12 sleep`, `pgrep -P 12 -u 1000`, `pgrep --parent=12`,
  `pgrep -fc`, `pgrep -fc ''`, `pgrep -fc -sleep`, `pgrep -fc sleep -l`, `pgrep -fcl sleep`,
  `pgrep --teamsmith-allow-pattern sleep` and `pidof --help sleep` run through the gate
- **THEN** each exits 64 with empty stdout and the recording selectors receive no calls

#### Scenario: Informational selectors use their own real tool despite the old pin

- **GIVEN** `TEAM_SIGNAL_REAL` pinned to a `pkill` witness and separate recording `pgrep`/`pidof` tools following
  the gate directory on `PATH`
- **WHEN** each new tool runs once for each single argument `--help`, `-h`, `-V`, `--version`, and then
  `pgrep -P 12` runs
- **THEN** each reaches its same-name witness with original argv and preserves that witness's status, the `pkill`
  witness has zero calls, and the signal log names the actual intercepted tool with `act=pass`

#### Scenario: Selector refusal is independent of pins and inherited grants

- **GIVEN** an unusable `TEAM_SIGNAL_REAL`, same-name fallback witnesses, and `TEAM_ALLOW_PATTERN_KILL=1` in a
  gated shell and its child
- **WHEN** `pgrep -f marker` and `pidof sleep` run in each shell
- **THEN** all four exit 64, stdout is empty, no fallback witness executes, and the log records only `refused`

#### Scenario: A refused substitution supplies no PID to the shell

- **GIVEN** a gated shell with a `kill` function that only records argv and same-name selector witnesses
- **WHEN** `kill $(pgrep -f marker)` and `kill $(pidof sleep)` run
- **THEN** each selector exits 64 and emits no stdout, the recording `kill` receives zero PID arguments, the
  selector witnesses receive zero calls, and no real signal is sent; with an unconditional pass-through gate the
  witnesses supply `424242` and both zero-argument assertions fail

#### Scenario: New selector refusals use the existing forensic record

- **GIVEN** a scratch log, recording real selectors and `pgrep -f marker` followed by `pidof sleep`
- **WHEN** those refusals run, then 2100 later `pgrep --help` calls force the main log to rotate
- **THEN** the original two refusal lines carry the tool, argv, pid, ppid, cwd and `act=refused`, their byte-identical
  copies survive in `.forensics`, and the main log has the existing cumulative rotation marker; with a retention
  path that is a directory or FIFO, a refusal still exits 64 within the fixture's timeout and prints the existing
  path-naming diagnostic with `retention=failed` in the main call line

#### Scenario: Other read-only tools remain outside this gate

- **GIVEN** recording `ps` and `fuser` tools on `PATH` after the signal gate directory
- **WHEN** `ps -p 12` and `fuser /tmp/p164-file` run
- **THEN** both reach their witnesses with unchanged argv and status, and neither adds a signal-gate log line

### Requirement: The signal gate's calls are recorded, and its refusals outlive the call log's rotation

Every signal-gate call SHALL append exactly one line to `$TEAM_SIGNAL_CALLS_LOG` carrying the ISO-8601 timestamp,
the intercepted tool, the full argv, the pid, the ppid, the cwd and an action that is exactly one of `pass` or
`refused`. Every line whose action is `refused` SHALL be copied byte for byte into the sibling long-retention file
`$TEAM_SIGNAL_CALLS_LOG.forensics`; when that copy does not happen the gate MUST print a `✗`-marked diagnostic
naming the retention path, and that same line MUST carry `retention=failed` — the log still appends exactly one
line per call, and the verdict and the exit code are unchanged. A `pass` line SHALL NOT be copied (retention
covers the gate's refusals, not its traffic).

Both files SHALL obey the call log's bound and rotation rule (`boundary#The gate's actions are logged, and no
window carries a destructive-call grant`): past 2000 call lines the oldest go and the newest 1000 stay, the
surviving file's first line is the rotation marker (`<ISO-8601 timestamp> · rotation · dropped=<N>`) with the same
reading and restart rules, the marker is not a call line and does not survive the next rotation, a target that
cannot be written MUST NOT block the call, and a file that never crossed the bound carries no marker.

#### Scenario: One line per call, and a refusal's line is its record

- **GIVEN** a scratch gate whose call log does not exist
- **WHEN** a refused `pkill -f x` call and a `pkill --help` call run
- **THEN** the call log holds exactly two lines carrying the timestamp, `tool=`, `argv=`, `pid=`, `ppid=` and
  `cwd=`, with actions `refused` and `pass`, and the retention file holds the refused line byte for byte

#### Scenario: A refusal survives the call log's rotation

- **GIVEN** a scratch gate whose retention file already holds a refused line and whose call log is seeded with
  2100 later call lines
- **WHEN** one more gated call runs
- **THEN** the call log's first line is the rotation marker whose `dropped` count accounts for the removed lines,
  while the retention file still holds the refused line byte for byte

#### Scenario: A failed retention is visible and never blocks

- **GIVEN** a scratch gate whose retention path already exists as a directory
- **WHEN** a refused `pkill -f x` call runs
- **THEN** it still exits 64 within the probe's timeout, its call-log line carries `act=refused` and
  `retention=failed`, and stderr carries the `✗`-marked diagnostic naming the retention path

#### Scenario: A pass call is not retained

- **GIVEN** a scratch gate whose retention file holds one refused line
- **WHEN** `pkill --help` runs
- **THEN** the retention file is byte-identical to before it, and the call log holds the new `act=pass` line

### Requirement: `team bg` stops a job by the pid it recorded, and prints what it signalled

The job lane SHALL record every job it starts before the job id is returned to its caller: `state/bg/<id>.job`
carrying the job's pid, its process-group id, the process's start-time fingerprint, its working directory, its log
path and its command. `team bg list` SHALL read those records from the project's own state directory and print one
row per job — the id, the pid and group, the identity verdict, and the command — without signalling anything, and
it SHALL reach that verdict through the same validation `team bg stop` runs on the same record (the flat-id rule,
the record's location and type, the readable payload, the positive-integer `pid`/`pgid`, the start-time
fingerprint's presence and match, and the live process group): a record `stop` would refuse MUST NOT be shown as a
holding identity. The verdict vocabulary is closed — `holds` and `gone` are the usable outcomes (`stop` exits 0),
`unusable` covers the unknown and malformed records (`stop` exits 2, 3 or 4), and `mismatch` is the failed
identity check (`stop` exits 5) — and a row whose verdict is not usable SHALL be shown with the same reason
sentence `stop` prints for that refusal. The row's id SHALL be the record's own name, the one
`team bg stop <id>` accepts.

`team bg stop <id>` SHALL stop exactly the job whose record it finds there, and MUST verify, before any signal,
that the recorded pid is alive and that its start-time fingerprint equals the recorded one: the (pid, start-time)
pair is the identity. An unknown id SHALL exit 3, a malformed or unreadable record exit 4, a failed identity check
exit 5, and a failed signal exit 6 — each with nothing signalled, naming the check that failed. A verified job's
**group** SHALL be signalled (`TERM`, then `KILL` after a bounded grace) while the group id equals the recorded
pid, so the job's own descendants are reached; when the group id differs only the recorded pid is signalled, and
the output MUST say that descendants were not reached. The command SHALL print the job id, the group or pid it
signalled and the command it stopped, and SHALL append one `stop` line naming the job, the signal and the result
to `state/bg.log`.

A job whose recorded process is already gone SHALL print that nothing was signalled and exit 0; the descendants of
a finished leader MUST NOT be hunted — no name, command-line or tree search is ever used. The job record SHALL be
resolved through the current project's state directory only: an id with no record there MUST be refused, and the
command MUST NOT look for the process in another working tree, another project or another session's state.

A job id SHALL be a flat name — non-empty, without a path separator, not `.` or `..`, and bounded in length (the
spawner's slug is at most 32 characters; the command's own bound is 128) — and the record file SHALL be a regular
file that resolves inside the project's own `bg` directory: a symbolic link, a FIFO, a device, a directory, or a
path that resolves outside that directory MUST be refused as a malformed record (exit 4) before the payload is
read, so no such record can block the command, and nothing is signalled; an id that is not a flat name is a usage
error (exit 2). The `bg` directory itself SHALL resolve inside the project's own state directory — both sides are
read through `realpath`, so the state directory's own spelling and symlinked ancestors are not a boundary — and
`team bg list` and `team bg stop` SHALL apply that same check before touching any record: when the directory
resolves outside, both MUST refuse as a malformed record (exit 4) with a diagnostic naming the `bg` directory and
the directory it resolves to, `team bg list` MUST NOT print a row from it, and nothing is signalled — a `bg`
symbolic link MUST NOT be a route to another project's records. The recorded `pid` and `pgid` SHALL both be
positive decimal integers, and before any signal the process's current process group SHALL equal the recorded
`pgid` — a non-positive or non-numeric value is a malformed record (exit 4), a live process that has left the
recorded group is a failed identity check (exit 5), and each refusal signals nothing.

#### Scenario: Stopping a job kills the job and not its neighbour

- **GIVEN** a scratch project whose state directory holds a job record written by the job's spawner and a live job
  process group, plus a second process the fixture owns and does not record
- **WHEN** `team bg stop <id>` runs
- **THEN** it exits 0, prints the job id, the group it signalled and the command, the job's process is gone, the
  unrecorded neighbour is alive, and `state/bg.log` gains one `stop` line naming the job and the result

#### Scenario: An id this project never recorded is refused

- **GIVEN** a scratch project and a live process recorded only in a sibling state directory
- **WHEN** `team bg stop <that id>` runs in the scratch project
- **THEN** it exits 3, names `<id>` and the state directory it searched, the live process is alive, and nothing was
  written to `state/bg.log`

#### Scenario: A reused pid and a malformed record are not stopped

- **GIVEN** a job record whose pid is a live process the fixture owns but whose recorded start-time fingerprint
  does not match, and a second record whose payload is malformed
- **WHEN** `team bg stop <id>` runs for each
- **THEN** the first exits 5 and the second exits 4, each names the failed check, and the live process is still
  alive

#### Scenario: An already finished job is a no-op, and its descendants are not hunted

- **GIVEN** a job record whose leader has exited while a descendant in its group is still alive
- **WHEN** `team bg stop <id>` runs
- **THEN** it exits 0, prints that nothing was signalled and that descendants are not hunted, and the descendant is
  still alive

#### Scenario: A record outside the project's bg directory is refused

- **GIVEN** a scratch project whose `bg` directory holds a symbolic link to a live job record written by a sibling
  project, and an id that names the sibling's record through a relative path
- **WHEN** `team bg stop <the linked id>` runs, and `team bg stop <the traversing id>` runs
- **THEN** the traversing id exits 2 as a usage error, the symbolic link exits 4 as a malformed record, each names
  the check that failed, and the sibling's process is still alive

#### Scenario: A bg directory that resolves outside the project is refused by both read and write

- **GIVEN** a scratch project whose `bg` directory is a symbolic link to a sibling directory holding a live job
  record written by a sibling project
- **WHEN** `team bg stop <that id>` runs, and `team bg list` runs
- **THEN** each exits 4 with a diagnostic naming the `bg` directory and the directory it resolves to, the sibling's
  process is still alive, `state/bg.log` gains no line, and `team bg list` prints no row from the linked directory

#### Scenario: A malformed record is refused before it can be read or block

- **GIVEN** a record with a matching live pid and start-time fingerprint whose `pgid` is `0`, and a second record
  path that is a FIFO with no writer
- **WHEN** `team bg stop <id>` runs for each
- **THEN** each exits 4 within the command's own bounded wait — never a timeout — with a diagnostic naming the
  record and the failed check, and no process is signalled

#### Scenario: The read side refuses what the write side refuses

- **GIVEN** a scratch project whose `bg` directory holds a live flat-named record, a record whose file is named
  with a space, a record whose `pgid` is `0`, and a record whose recorded group differs from the live process's
  current group
- **WHEN** `team bg list` runs, and `team bg stop <id>` runs for each of the last three
- **THEN** none of those three rows claims a holding identity — they carry `unusable`, `unusable` and `mismatch`
  — `stop` exits 2, 4 and 5 with nothing signalled, each row carries the same reason sentence its `stop` printed,
  and the flat-named record's row still carries `holds` and its `stop` still stops the job

### Requirement: Scripts select processes by recorded pid, and the lint keeps it that way

The project's scripts, fixtures and templates MUST address processes by a pid their own spawner recorded, and MUST
NOT select them by name, command line, owner or any other predicate. A lint at
`skills/teamsmith/tests/signal-lint.pl` SHALL judge the trees the isolation lint judges and report every violation
with its file and line. It MUST be red for: a `pkill` or `killall` command word (including behind a
`command`/`env` prefix, and as a literal absolute path), an `xargs` whose arguments include
`kill`/`pkill`/`killall`, and a `kill` whose argument carries a command substitution over `pgrep`, `pidof`, `ps` or
`fuser`. It MUST be clean for the pid-exact forms (`kill -TERM "$pid"`, `kill -0 "$pid"`,
`kill -- -"$pgid"`, `kill "$pid1" "$pid2"`, `kill "$(cat "$pidfile")"`), MUST exit 0 clean / 1 red / 2 usage, and
MUST carry a two-directional self-test. The gate SHALL run it in the fast gate as well, so a planted pattern kill
in a scratch copy reddens the section with the file and the line.

The real tree SHALL be clean by default: a violation in a historic evidence package (the adversarial packages
written before this rule, which the lint family freezes by content hash) MAY be frozen in
`tests/signal-lint-legacy.txt` under the family's rules (the count is checked, every run prints the frozen files,
and `--no-legacy` reports them all as red), but a violation under `skills/teamsmith/tests/**` MUST be fixed, not
exempted — the gate's own fixture that stopped a control process by pattern SHALL stop it by the pid it recorded.

#### Scenario: The real tree is clean and a planted pattern kill is red with its file and line

- **GIVEN** a scratch root holding one script whose only signal is `pkill -f x`
- **WHEN** `perl skills/teamsmith/tests/signal-lint.pl` runs on the real tree, and then
  `perl skills/teamsmith/tests/signal-lint.pl --root <scratch>` runs, and then the scratch script is rewritten to
  `kill -TERM "$pid"` and the lint runs on the scratch root again
- **THEN** the first run exits 0, the second exits 1 naming the scratch file and its line, and the third exits 0

#### Scenario: The predicate-fed kill and the absolute path are caught

- **WHEN** the lint runs over a scratch root holding `kill $(pgrep -f x)`, `/usr/bin/pkill -f x`,
  `pgrep -f x | xargs kill` and `killall sleep`
- **THEN** it exits 1 and names all four file-and-line pairs

#### Scenario: The pid-exact forms are clean

- **WHEN** the lint runs over a scratch root holding `kill -TERM "$pid"`, `kill -0 "$pid"`,
  `kill -- -"$pgid"`, `kill "$pid1" "$pid2"` and `kill "$(cat "$pidfile")"`
- **THEN** it exits 0 with no violation reported

### Requirement: Specs are the contract

`openspec/specs/**` ships in the public tree; the maintainers' ledger (`docs/team/**`: briefs, reports, reviews,
decisions — the evidence behind a rationale) does not. A spec SHALL therefore stand on its own: a claim's evidence
SHALL be stated in its text — the conclusion and the numbers it quotes — and MUST NOT be delegated to a record the
reader cannot open. A `docs/team/…` reference in a spec SHALL name a **declared reference**, and every declared
reference SHALL be a row of `skills/teamsmith/tests/spec-ledger-refs.tsv` carrying its kind and its basis. Every
non-comment row of the table SHALL carry exactly its three columns — a `pattern`, a `kind` from the closed set
`slot | ledger | example`, and a non-empty `basis` — and a row that lacks any of them MUST be refused when the
table is read, naming the table, the row's line number and the row's text. A `ledger` or `example` row SHALL hold
a **literal** reference; a row of either kind whose pattern carries `<…>` or `*` MUST be refused the same way,
naming the pattern — those shapes belong to `slot` rows alone. A **slot-shaped** reference (one that carries `<…>`
or `*`) SHALL match a `slot` row — the slots the skill defines in a project's ledger
(`docs/team/tasks/<ID>-<slug>.md`, `docs/team/reports/<ID>-<agent>.md`, `docs/team/inbox/<agent>.md`, …); a
**concrete** reference SHALL equal an exact `ledger`/`example` row character for character — one of the ledger's
own fixed files, or an example record a fixture owns — never merely resemble one. A slot row MUST NOT allow a
concrete reference: a concrete report reference is undeclared even though the slot pattern
`docs/team/reports/<ID>-*.md` matches its shape. The
maintainers' record ids MAY stay in the text — a reason may name the verification pass a ruling came from, and a
scenario must be able to quote what its fixture prints — but the specs' text SHALL carry one line beginning
`Id families:` and a family that line does not name MUST NOT appear in `openspec/specs/**`:

Id families: `P<n>` a task brief, `M<n>` a milestone, `D<n>` a decision record, `V<n>` a verification pass and
`V<n>-<letter><m>` one of its findings, `E<n>` an exploration report, `F<n>` a finding — the records they name live
outside the distributed tree and are not needed to re-run any scenario.

The project gate SHALL judge the contract's text as the archive will write it: the base spec for a capability no
pending change touches and, for a requirement a pending change adds, modifies or removes, that change's own block.
It SHALL read the pending changes in dependency order rather than directory order: when a pending change's
`MODIFIED` or `REMOVED` block names a requirement the base spec does not have and another pending change's `ADDED`
block supplies it, the walk SHALL take that block as the baseline, SHALL name the supplying change and the archive
order that implies, and MUST NOT fail; a block whose title neither the base nor any pending change supplies MUST
fail, naming its file and the title. A reference the pending changes retire MUST be reported once with the file,
the line and the retiring change and
MUST NOT fail the run; a reference no pending change retires MUST fail it, naming the file, the line and the path.
The walk SHALL need no window, process or network — it reads text, so it runs in the fast gate as well.

#### Scenario: The walk passes here, and reddens on a citation nothing retires

- **WHEN** `bash skills/teamsmith/tests/spec-refs.sh --check` runs on this tree
- **THEN** it exits 0, reports every reference the pending changes retire with its file, its line and the retiring
  change's id, names no undeclared reference, and prints how many references it judged
- **AND** with `--root` pointed at a copy of the tree whose `openspec/changes/` holds no change directory, the same
  command exits non-zero and names `openspec/specs/verification/spec.md`, the line the reference sits on and the
  cited path it refused
- **AND** `bash skills/teamsmith/tests/spec-refs.sh --flips` reports one `red` line for a concrete report path
  planted in a copy — the shape a slot pattern would otherwise swallow — so the walk cannot pass a citation by
  matching it against `docs/team/reports/<ID>-*.md`

#### Scenario: A record-id family without its key is red

- **GIVEN** a copy of the tree whose spec text uses `V9-B5` and `F2` under the `Id families:` line
- **WHEN** `bash skills/teamsmith/tests/spec-refs.sh --check` runs on the copy with that line deleted, and again on
  a copy whose line names `V<n>` but not `F<n>`
- **THEN** each run exits non-zero and names the file and the unnamed family, while the untouched copy exits 0
- **AND** `bash skills/teamsmith/tests/spec-refs.sh --flips` prints one `red` line per mutation that must be caught
  and one `clean` line per mutation that must stay green, and exits 0 only when every mutation behaved as required

#### Scenario: A row that cannot mean what it says is refused, not skipped

- **GIVEN** a copy of `skills/teamsmith/tests/spec-ledger-refs.tsv` carrying, one at a time, a `ledger` row whose
  pattern holds a `*`, an `example` row whose pattern holds a `<…>`, a row with a column missing, a row with a
  column too many, a row whose `basis` is empty, and a row whose `kind` is outside `slot | ledger | example`
- **WHEN** `bash skills/teamsmith/tests/spec-refs.sh --check --table <copy>` runs on each copy
- **THEN** every run exits non-zero and names the table, the offending line's number and its text, so no such row
  can be dropped in silence
- **AND** the same command with the table untouched exits 0, still declares the `slot` rows whose patterns carry
  `<…>`, still declares a concrete reference that equals a `ledger` row character for character, and still refuses
  a concrete report path that only resembles the slot pattern

#### Scenario: A requirement another pending change supplies and one nothing supplies

- **GIVEN** a tree where change `zz-provider`'s `ADDED` block introduces a requirement and change `zz-consumer`'s
  `MODIFIED` block rewrites it, and the same tree with `zz-provider`'s change directory removed
- **WHEN** `bash skills/teamsmith/tests/spec-refs.sh --check` runs on each
- **THEN** the first exits 0 and names `zz-provider` as the provider of that baseline and the order that implies,
  while the second exits non-zero and names `zz-consumer`'s file and the title it could not resolve

