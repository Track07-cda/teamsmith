## ADDED Requirements

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
