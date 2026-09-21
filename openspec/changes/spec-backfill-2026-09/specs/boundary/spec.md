# boundary delta · 2026-09 回填：the tmux runtime gate and the container discipline (M28/M36/M41)

## ADDED Requirements

### Requirement: Destructive tmux calls that resolve to the shared default socket are refused

Every `tmux` call made from a PM or worker window SHALL pass through the gate that the window's launch command puts
first on `PATH`; the gate records the call and, for the subcommands `kill-server`, `kill-session`, `kill-window`
and `kill-pane` (including tmux's unambiguous prefixes such as `kill-ser`) resolving to the shared default socket
(`/tmp/tmux-<uid>/default`), MUST NOT execute it: it MUST exit 64 with a one-line refusal naming the subcommand,
the resolved socket, the audited override and — for a fake isolation — the reason and the remedy.

Socket resolution MUST reproduce tmux's own order and fallbacks: `-S`/`-L` (command line) > `$TMUX` (the part
before the first comma; ignored when it starts with a comma) > the `${TMUX_TMPDIR:-/tmp}` path table, where each
candidate is resolved with `realpath(3)`-style semantics and a candidate that does not resolve is skipped. That
makes `-L default`, `-S <default socket path>` and `$TMUX` pointing at the default all the shared socket, and it
makes an unresolvable or non-directory `TMUX_TMPDIR` **fake isolation**: the reported private isolation is not in
effect (tmux silently falls back to, or fails at, the default socket), so a destructive call MUST be refused and
the refusal MUST say so. Read-only commands MUST never be refused. `TEAM_ALLOW_DESTRUCTIVE_TMUX=1` MUST execute
the call and record the audited override; a private socket MUST execute the call. The executed bytes MUST be the
caller's argv unchanged (the decision is made on a copy; global flags are never consumed), and an incomplete call
(`tmux -L`, `tmux -V`, no subcommand) MUST be passed through rather than hang.

#### Scenario: The four destructive subcommands are refused on the default socket

- **WHEN** a window's `tmux kill-server` runs with no `TMUX`/`TMUX_TMPDIR` set, and then
  `kill-session -t x`, `kill-window -t x:1`, `kill-pane -t %1` and the prefix `kill-ser`
- **THEN** each exits 64, the output names the refused subcommand, the resolved `/tmp/tmux-<uid>/default`, exit 64's
  reason and the `TEAM_ALLOW_DESTRUCTIVE_TMUX=1` override, and the downstream tmux is never executed

#### Scenario: Every spelling that resolves to the default is caught

- **WHEN** `TMUX=/tmp/tmux-<uid>/default,12345,0 tmux kill-server`, `tmux -L default kill-server` and
  `tmux -S /tmp/tmux-<uid>/default kill-server` run
- **THEN** all three exit 64 — the resolved socket, not the spelling, decides

#### Scenario: Fake isolation is refused, a real private directory passes

- **WHEN** `TMUX_TMPDIR=<a directory that does not exist>/sock tmux kill-server` and
  `TMUX_TMPDIR=<a regular file> tmux kill-server` run, then the same command with `TMUX_TMPDIR=<an existing
  private directory>`
- **THEN** the first two exit 64 with the fake-isolation wording and the `mkdir -p` remedy (the log recording the
  resolved **default** socket), and the third exits 0 with the log recording the private socket path

#### Scenario: Read-only calls are never refused

- **WHEN** `ls`, `list-sessions`, `display-message -p hi`, `capture-pane -p -t x` and `send-keys -t x y` run while
  the resolved socket is the default
- **THEN** every one of them reaches the downstream tmux, and the log carries no `act=refused` line

#### Scenario: The override passes and the gate is what refuses

- **WHEN** `TEAM_ALLOW_DESTRUCTIVE_TMUX=1 tmux kill-server` runs, and then the same call runs with the gate's
  directory removed from `PATH`
- **THEN** the first reaches the downstream tmux and logs `act=override`; the second reaches it too — the refusal
  comes from the gate, not from tmux

#### Scenario: A private server really dies, the default survives, and the argv is passed through

- **GIVEN** a private tmux server started under a private `TMUX_TMPDIR`, and the default server's liveness recorded
  before the probe
- **WHEN** `tmux kill-server` runs with that private `TMUX_TMPDIR`, and then `tmux -L <private> kill-server` and the
  incomplete `tmux -L` run against a stub
- **THEN** the private server is gone, the log records `act=pass` with the private socket path, the default server
  is still alive, and each command reaches the downstream tmux with its argv byte-for-byte and returns instead of
  hanging

### Requirement: Every gate decision is logged and the gate is injected into the windows

Each gated call SHALL append one line to `$TEAM_TMUX_CALLS_LOG` — in launched windows the project's
`state/tmux-calls.log` — carrying an ISO-8601 timestamp, the resolved socket, `TMUX`, `TMUX_TMPDIR`, the full argv,
the pid and ppid, the cwd and the action (`refused`, `override` or `pass`). The log SHALL stay bounded (beyond
2000 lines the oldest are dropped and the newest 1000 kept) and a log target that cannot be written (for example a
FIFO) MUST NOT block or fail the call. The launch command of the PM window and of every worker window SHALL put
the gate's directory first on `PATH`, export `TEAM_TMUX_CALLS_LOG` into the project's state directory, and pin
`TEAM_TMUX_REAL` to the resolved real tmux.

The gate is a `PATH` executable: a call that executes a literal absolute tmux path bypasses it. That blind spot
MUST be reported by the repository's isolation lint — red for a literal absolute-path destructive call even when it
carries a private `-L`, exempt for the variable form the launch commands use.

#### Scenario: A call leaves one complete, bounded log line

- **WHEN** a gated call runs and the log already holds 2100 lines
- **THEN** the new line carries the timestamp, `act=`, `sock=`, `TMUX=`, `TMUX_TMPDIR=`, `argv=`, `pid=`/`ppid=`
  and `cwd=`, and the file holds 1000 lines whose last line is the new call

#### Scenario: The gate is injected into PM and worker windows

- **WHEN** the PM launch command and a worker launch command are rendered, and a worker is dispatched
- **THEN** both carry the gate directory first in `PATH`, `TEAM_TMUX_CALLS_LOG=<project>/state/tmux-calls.log` and
  `TEAM_TMUX_REAL=<real tmux>`; the window's environment shows them, and an ad-hoc tmux call made inside the window
  lands in that log

#### Scenario: The isolation lint catches the bypass shape

- **WHEN** the lint scans a fixture containing `/usr/bin/tmux -L <private> kill-server`, and a fixture containing
  `"$REAL_TMUX" -L <private> kill-server`
- **THEN** the first is reported red (the gate cannot see it) and the second is clean

#### Scenario: Without the gate the same call lands

- **WHEN** the offending `kill-server` runs with the gate's directory absent from `PATH`
- **THEN** it reaches the downstream tmux and exits 0, and no refusal text appears

### Requirement: Destructive tmux fixtures run inside the container

A test fixture that starts or kills tmux servers, or drives a real pi pane, SHALL run through the container runner,
which mounts neither the host's tmux socket directory nor the host's `HOME`; a bare `kill-server` inside the
container MUST leave the host server's fingerprint byte for byte unchanged and the host socket path MUST NOT be
visible inside. When no container runtime is available the fixture MUST be skipped visibly — exit 77 with the
reason printed — and MUST NOT fall back to an unisolated run.

#### Scenario: The container run cannot reach the host server

- **WHEN** `bash skills/teamsmith/tests/container-tmux.sh --selftest` runs
- **THEN** it exits 0, a session created and a bare `kill-server` inside the container behave normally, the host
  socket path does not exist inside, and the host server fingerprint recorded before and after is byte-identical

#### Scenario: No runtime means a visible skip, never an unisolated run

- **WHEN** the container runner cannot resolve a runtime (no `podman`, no usable host bridge)
- **THEN** it exits 77 and prints the `SKIP` reason, the gate reports the section as skipped, and no tmux server
  experiment runs on the host
