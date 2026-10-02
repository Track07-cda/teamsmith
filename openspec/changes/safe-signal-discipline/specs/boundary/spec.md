## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Signals go to a recorded pid, never to a name or a pattern

The `pkill` and `killall` executables that the launch command puts first on `PATH`
(`boundary#The gate's actions are logged, and no window carries a destructive-call grant`) SHALL refuse every
invocation that would select processes: the call MUST exit 64 without executing the real tool and without sending
any signal, and MUST print the intercepted tool, its full argv, why a name or a command-line pattern cannot prove
ownership (it reaches another project's or another session's process, and the caller's own shell), and the safe
routes (`team bg list` for a job's recorded pid, `team bg stop <id>`, and `kill` with a pid the caller recorded).

No argument makes the selection provable: `-f <pattern>` and `-x <exact name>` both select by name, `-P <pid>` and
`-u <user>` select a set an unbounded predicate defines, and `killall` is name-selection by definition. The gate
therefore MUST NOT have an allowed selection form and MUST NOT read any environment variable as an authorization.
`--help`, `-h`, `-V` and `--version` select nothing: they SHALL reach the resolved real executable unchanged and
be recorded as `act=pass`. A refusal MUST NOT depend on resolving the real executable. `kill`, `pgrep`, `ps` and
`pidof` SHALL NOT be intercepted — the gate is a `PATH` shim, so an absolute path (`/usr/bin/pkill`) and a shell
that does not carry the gate's directory first on `PATH` are outside it;
`boundary#Scripts select processes by recorded pid, and the lint keeps it that way` is the layer that covers
scripts.

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
row per job — the id, the pid and group, whether the recorded identity still holds, and the command — without
signalling anything.

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
