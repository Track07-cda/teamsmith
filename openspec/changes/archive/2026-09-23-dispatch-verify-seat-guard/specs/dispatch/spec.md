## ADDED Requirements

### Requirement: A verification seat is never dispatched implementation work

`team dispatch` SHALL refuse to start implementation work for the project's verification seat — the agent named by
`TEAM_VERIFY_SEAT`, so a project that reserves a differently named seat is covered instead of being silently
unprotected. The brief runs implementation when its `phase:` is `apply`, or when its `phase:` is undeclared (no
line, `-`, or a value outside `explore|propose|apply|verify|archive`) and its `grant:` names at least one
implementation path. A `grant:` entry counts as an implementation path unless it is `docs/team`, `openspec`, or lies
under `docs/team/` or `openspec/`; the refusal MUST print the entries it read that way, so a false positive is
visible instead of silent. The declared phases `explore`, `propose`, `verify` and `archive`, and an undeclared phase
whose `grant:` names only `docs/team/`/`openspec/` paths (or has no `grant:` line), MUST proceed.

The refusal MUST name the seat, the verification row of `docs/team/OWNERSHIP.md` (the boundary the seat may not
cross) and two ways out — dispatch the work to a seat that may implement, or keep the seat and make the task
verification-only (`phase: verify`) — MUST come before any window is opened and for `--print` as well, and MUST NOT
change the task's board status. `--force` MUST proceed with a warning and append exactly one audit line to
`state/watchdog.log` naming the task, the seat and the signal that triggered the guard (an `apply` phase or the
implementation paths); `--print` writes no audit line. Why the seat's independence includes not implementing, and
which work stays allowed: `verification#The verification seat does not implement` and `references/protocol.md` §5b.

#### Scenario: Apply work for the verification seat is refused

- **GIVEN** a brief with `agent: verify` and `phase: apply`, and a board row for its task
- **WHEN** `team dispatch verify T1.1 <brief>` runs
- **THEN** it exits non-zero, names `docs/team/OWNERSHIP.md`, the seat and both ways out
- **AND** it requests no tmux window and leaves the task's board row unchanged

#### Scenario: `--print` refuses the same brief

- **WHEN** `team dispatch verify T1.1 <brief> --print` runs on the same brief
- **THEN** it exits non-zero and prints no prompt

#### Scenario: An undeclared phase with implementation grants is refused, and says why

- **GIVEN** a brief with `agent: verify`, no usable `phase:` value and
  `grant: skills/teamsmith/scripts/lib/cmd-agents.sh · scripts/lib/common.sh · extension/team-bg.ts`
- **WHEN** `team dispatch verify T1.1 <brief>` runs
- **THEN** it exits non-zero, prints those three entries as the implementation paths it read, and states that the
  phase was undeclared

#### Scenario: Ledger and reconnaissance work proceeds without a phase

- **GIVEN** a brief with `agent: verify`, no usable `phase:` value and
  `grant: docs/team/reports/V1-verify.md · openspec/changes/alpha/`
- **WHEN** `team dispatch verify V1 <brief> --print` runs
- **THEN** it proceeds and reports no implementation path

#### Scenario: A seat that may implement is not affected

- **GIVEN** the apply brief of the first scenario with `agent: dev` instead
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** it proceeds — the guard is about the seat, not about the `apply` phase

#### Scenario: `--force` proceeds with exactly one audit line

- **GIVEN** the apply brief of the first scenario
- **WHEN** `team dispatch verify T1.1 <brief> --force` really starts the worker (the record-only tmux shim the
  smoke suite uses)
- **THEN** it proceeds with a warning naming the seat and the task, and `state/watchdog.log` gains exactly one line
  naming them
- **AND** the same command with `--print` writes no audit line
