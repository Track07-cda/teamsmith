## ADDED Requirements

### Requirement: Orphan seat processes of this project are reaped by pid, with an audit and no pattern

`team reap` SHALL be the only teamsmith entry that signals an orphan seat process of this project. It SHALL accept
`team reap --orphans` (the plan, no `--yes`) and `team reap <pid> --yes` (one recorded pid), and the plan SHALL
signal nothing and exit 0 while printing every target it would signal. With `--yes`, every target SHALL be
re-verified immediately before it is signalled — still a seat process of this project, still without a live pane,
and the same process start time the plan recorded, so that a pid the kernel has recycled cannot be killed — and a
target that fails re-verification SHALL be named with its reason, left unsignalled, and make the command exit
non-zero. A target whose identity belongs to another project, or which carries no teamsmith identity, or which is
the caller itself or one of its ancestors, MUST NOT be signalled. The signal SHALL be `SIGTERM` first, then
`SIGKILL` after a bounded wait for a target still alive, and every signal SHALL append exactly one line to the
project's `state/reap.log` carrying the timestamp, the pid, the seat, the signal and the outcome. `--yes` SHALL be
the only authorization: no configuration key, environment variable or inherited value may make a signal the
default. The command SHALL print what it signalled (pid, seat and signal) and SHALL exit non-zero when a target
survived. It MUST NOT select processes by name, pattern or predicate: the pid is the object.

#### Scenario: The plan signals nothing

- **GIVEN** one orphan of this project
- **WHEN** `team reap --orphans` runs without `--yes`
- **THEN** the process is still alive, `state/reap.log` did not grow, and the command exits 0 naming the pid

#### Scenario: An authorized reap removes the orphan and audits it

- **GIVEN** the same orphan
- **WHEN** `team reap --orphans --yes` runs
- **THEN** the process is gone within the bounded wait, `state/reap.log` gained exactly one line carrying the
  timestamp, the pid, the seat, the signal and the outcome, and the command exits 0

#### Scenario: A pid that is no longer an orphan is refused, not killed

- **GIVEN** a pid that was an orphan when the plan was printed and whose pane has since come back, and a pid whose
  process start time changed because the kernel recycled it
- **WHEN** `team reap <pid> --yes` runs for each
- **THEN** neither process is signalled, each refusal names the pid and its reason, and each run exits non-zero

#### Scenario: A foreign, identity-empty or self pid is refused

- **GIVEN** a pid belonging to another project's seat, a pid with no teamsmith identity, and the caller's own pid
- **WHEN** `team reap <pid> --yes` runs for each
- **THEN** none is signalled, each refusal names its reason, and each run exits non-zero

#### Scenario: A read command never signals

- **GIVEN** one orphan of this project
- **WHEN** `team ps`, `team status` and `team up` run
- **THEN** the process is still alive and `state/reap.log` did not grow
