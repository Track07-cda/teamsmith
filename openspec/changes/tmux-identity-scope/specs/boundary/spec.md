## MODIFIED Requirements

### Requirement: The gate's actions are logged, and no window carries a destructive-call grant

Each gated call SHALL append exactly one line to the gate's call log — `$TEAM_TMUX_CALLS_LOG` when the caller's
environment names one, otherwise the call log of the project the gate's working directory belongs to
(`<project>/.pi/team/state/tmux-calls.log`), and nothing when neither resolves, so a call deliberately run without
the gate's pins (the tool's own server-starting calls, which must not carry this project's `TEAM_*` namespace into
a server they start) is still recorded exactly once — carrying the ISO-8601 timestamp, the resolved socket, `TMUX`,
`TMUX_TMPDIR`, the full argv, the pid and ppid, the cwd, and an action that is exactly one of `pass`, `refused`,
`allowed-owned` or `explicit-flag`. Every call whose action is not `pass` is additionally copied into the gate's
long-retention record (`boundary#A destructive call's record outlives the call log's rotation`); when that copy
does not happen, this same line carries `retention=failed` and the gate prints that requirement's diagnostic — the
log still appends exactly one line per call. The log records the caller's traffic — its content is the caller's own
argv and resolved socket — so it MUST NOT be read as project ledger state: the gate's fixture-trace scan excludes
those exact paths (`verification#The fixture-trace scan reads ledger state, not traffic records`).

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

#### Scenario: A call without the gate's pins is still logged where it stands

- **GIVEN** a project whose state directory is writable, and a gated call whose environment carries no
  `TEAM_TMUX_CALLS_LOG`, run from a directory inside that project
- **WHEN** the call runs, and then the same call runs from a directory belonging to no project
- **THEN** exactly one line is appended to that project's `state/tmux-calls.log` with the same fields and the same
  closed action vocabulary as a pinned call, the pinned variable is still absent from the caller's environment,
  and the call from no project appends nothing anywhere

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
