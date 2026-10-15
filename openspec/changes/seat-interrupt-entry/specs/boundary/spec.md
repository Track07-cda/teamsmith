## ADDED Requirements

### Requirement: A running seat's turn is ended only by an audited interrupt aimed at that seat's own process

`team interrupt <seat> --reason <one line> [--force] [--yes]` SHALL be the only entry whose job is to end one
seat's running turn and stop there: `team dispatch`, `team resume` and `team teardown` may replace a seat's window
and thereby end whatever turn it holds, but they never ask why and they leave no interruption record, while
`team reap` stays the entry for an orphan seat process and `team resume` the way back into a stopped seat's session.
Without `--yes` the command SHALL be a plan: it SHALL print the seat, the pid it resolved,
the evidence it read and the signal it would send, signal nothing, write nothing, and exit 0 — except that a plan
whose target cannot be interrupted SHALL exit non-zero, naming the refusal and its route. `--yes` SHALL be the only
authorization to signal: no configuration key, environment variable or inherited value may turn a signal on.

The target SHALL be proved, never searched for: the pid SHALL be the agent process of the window the seat's own
assignment record names, read from that window's pane (its foreground process, or the direct child that is this
project's agent executable), and it SHALL satisfy the identity rule the seat-process census applies — the process's
own environment carries this project's `TEAM_MAIN_ROOT` and a `TEAM_ROOT` equal to the worktree the assignment
records, and its command line names this project's configured agent executable. A process whose identity belongs to
another project, a process carrying no teamsmith identity, the caller itself and the caller's ancestors MUST NOT be
signalled, and another project's project name, seat name, worktree or pid MUST NOT appear in the output or in the
audit. Immediately before the signal the same pid SHALL be re-proved — still that seat's agent process in a live
pane, with the same process start time the plan read, so a recycled pid and a pane that came back cannot be hit —
and a target that fails that re-verification SHALL be named with its reason, left unsignalled, and make the command
exit non-zero. The signal SHALL be `SIGTERM` first, then `SIGKILL` after a bounded wait (five seconds by default)
for a target still alive; the command SHALL print the pid and the signal, SHALL print the route back
(`team resume --agent <seat>`, which re-enters the recorded session), and SHALL exit non-zero when a target
survived. It MUST NOT select the process by name, pattern or predicate.

Every authorized interrupt SHALL append exactly one line to the project's `state/interrupt.log`, carrying the
timestamp, the actor that ran the command, the seat, the pid, the reason, the interrupted session's last write
time, the number of uncommitted files in the seat's worktree as read before the signal, and the signal's outcome; a
refused interrupt SHALL write no audit line and signal nothing. The actor SHALL be resolved from the runtime
directory, and a run whose actor cannot be resolved SHALL be refused with nothing written and nothing signalled.

A seat with no running process, a seat whose window is gone while its process lives, a seat that is not in the
roster, and a pid that is the caller or one of its ancestors SHALL each be refused, the first two naming the entry
that owns them (`team resume` for a stopped seat, `team reap --orphans` for an orphan), and no signal SHALL be sent.
The command MUST NOT remove or replace the seat's window: it ends the turn, and the window stays for the next
`resume` to replace by its own path.

#### Scenario: The plan signals nothing and names the pid, the evidence and the signal

- **GIVEN** a live seat of this project whose session file was last written long before the freshness window and
  whose worktree has no uncommitted files
- **WHEN** `team interrupt <seat> --reason "<one line>"` runs without `--yes`
- **THEN** the agent process is still alive, `state/interrupt.log` did not grow, the seat's thread and the seat's
  inbox are byte-identical, and the output names the seat, the pid and the signal the run would send

#### Scenario: An authorized interrupt ends the turn and audits the evidence read before it

- **GIVEN** the same seat with three uncommitted files in its worktree and a session file whose last write is known
- **WHEN** `team interrupt <seat> --reason "<one line>" --yes` runs
- **THEN** the agent process is gone within the bounded wait, `state/interrupt.log` gained exactly one line carrying
  the timestamp, the actor, the seat, the pid, the reason, the session's last write time, `3` and the outcome, and
  the output names the pid, the signal and the `team resume --agent <seat>` route
- **AND** `team resume --agent <seat> --dry-run` lists the seat as resumable, so the seat is no longer a live seat
  and the route back is open

#### Scenario: A target that stopped being the proved process is refused, not signalled

- **GIVEN** a plan printed for a live seat whose pane then died, and a pid whose recorded process start time
  changed because the kernel recycled it
- **WHEN** the authorized interrupt runs for each
- **THEN** neither process is signalled, `state/interrupt.log` did not grow, the seat's thread and inbox are
  unchanged, each refusal names the pid and its reason, and each run exits non-zero

#### Scenario: The seats this entry does not own are refused with the route that fits each

- **GIVEN** a seat whose process has exited, a seat whose window is gone while its process still lives, a seat that
  is not in the roster, and a pid whose identity belongs to another project's seat
- **WHEN** an authorized interrupt is aimed at each
- **THEN** none is signalled, the first names `team resume`, the second names `team reap --orphans`, the third
  names the roster, and the fourth is refused without that project's name, seat name, worktree or pid appearing in
  the output

#### Scenario: A read command never ends a turn

- **GIVEN** one live seat of this project
- **WHEN** `team ps`, `team status`, `team roster` and `team digest` run
- **THEN** the process is still alive and `state/interrupt.log` did not grow

### Requirement: An interrupt carries its reason to the seat, and a seat that is writing is not interrupted by accident

`--reason` SHALL be required: a run without it, or with an empty one, SHALL be refused before anything is
signalled and before anything is written — no audit line, no thread entry, no inbox line — and the refusal SHALL
name the missing reason. A reason carrying newlines or control characters SHALL be recorded and delivered as a
single line, because the audit line's shape is fixed. Before the signal the reason SHALL be appended to the seat's own thread and to the seat's
inbox: the thread entry SHALL name who interrupted the seat, when, why, and what the seat has to do first, so that
the route the command prints re-enters the recorded session and the seat meets the reason at the step of its own
reading order that already names its thread; the inbox line SHALL be the same interruption's durable notice. If the
reason cannot be written to the seat's thread, the interrupt SHALL be refused with nothing signalled.

An interrupt of a seat whose newest disk evidence is younger than the freshness window MUST NOT signal silently:
such a run SHALL be refused unless `--force` is given, the refusal SHALL name the evidence it read (the file and
its age) and the window, and nothing SHALL be signalled or written. The seat's own disk evidence is the session
file of the session id its assignment records — the file the seat's own turn appends to — and the files git reports
as changed in its worktree; the newest of those mtimes is what the window is measured against. The freshness window
SHALL be 3600 seconds by default and configurable through `TEAM_INTERRUPT_FRESH_SEC` (a non-numeric value falls back
to the default). With `--force` the run SHALL proceed and its one audit line SHALL record that the guard was
overridden. `--force` MUST NOT override any other refusal: the identity, liveness, roster, cross-project and
self/ancestor refusals hold without it.

An interrupt SHALL change nothing in the seat's worktree: the uncommitted files the seat had SHALL be byte-identical
afterwards, its session file SHALL still hold its bytes, and the only files an interrupt writes are the seat's
thread, the seat's inbox and the project's `state/interrupt.log`.

#### Scenario: A missing reason is refused before anything is written or signalled

- **GIVEN** a live seat of this project
- **WHEN** an authorized interrupt runs with no `--reason`, and again with an empty one
- **THEN** nothing is signalled, `state/interrupt.log` did not grow, the seat's thread and inbox are byte-identical
  and each run exits non-zero naming the missing reason

#### Scenario: A seat that is writing is refused, and the refusal names the evidence

- **GIVEN** a live seat whose session file was written within the freshness window, and a second live seat whose
  only fresh evidence is an uncommitted file in its worktree
- **WHEN** the interrupt runs at each seat without `--force`
- **THEN** both processes are alive, `state/interrupt.log` did not grow, and each refusal names the file it read,
  that file's age and the window

#### Scenario: `--force` overrides the freshness refusal, and the audit says so

- **GIVEN** the same fresh evidence
- **WHEN** `team interrupt <seat> --reason "<one line>" --force --yes` runs
- **THEN** the process is gone and its one audit line carries the same pre-signal evidence and records the override
- **AND** `--force` overrides nothing else: a foreign, orphan, stopped, roster-absent or self target is refused
  exactly as it is without it

#### Scenario: The reason is where the seat's reading order takes it, and the disk state survives

- **GIVEN** a live seat with an uncommitted file of known bytes and a stale session record
- **WHEN** the authorized interrupt runs
- **THEN** the uncommitted file is byte-identical, the session file still exists with its bytes, the seat's thread
  gained exactly one entry naming the actor, the time, the reason and what to do first, and the seat's inbox gained
  exactly one line
- **AND** the route the command prints re-enters the seat's recorded session id — the printed plan names that id and
  the continued mode — and the prompt rendered for that route names the seat's own thread among the steps it reads
