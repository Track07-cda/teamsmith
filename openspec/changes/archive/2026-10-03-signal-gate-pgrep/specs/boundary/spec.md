## MODIFIED Requirements

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
