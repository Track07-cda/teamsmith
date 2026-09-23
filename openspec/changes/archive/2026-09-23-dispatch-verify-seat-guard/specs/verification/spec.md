## ADDED Requirements

### Requirement: The verification seat does not implement

The independence of verification has two sides: the agent that authored a change's work does not verify it, and the
seat a project reserves for verification does not implement at all. A project SHALL identify that seat by name with
`TEAM_VERIFY_SEAT`; unset or empty resolves to `verify`, so the default protects the conventional verification seat
and blanking the value cannot switch the boundary off. `team dispatch` MUST refuse implementation work for that
seat, under the refusal, `--print` and `--force`-with-one-audit-line contract specified by
`dispatch#A verification seat is never dispatched implementation work`. Verification work itself MUST stay allowed
for the seat: the `explore`, `propose`, `verify` and `archive` phases, and undeclared-phase briefs whose `grant:`
names only `docs/team/` or `openspec/` paths — the seat writes proposal reviews and reconnaissance there. The
verification seat's row in `docs/team/OWNERSHIP.md` MUST state the boundary and point at the guard, so the roster
table and the tool agree.

#### Scenario: The ownership row states the boundary and points at the guard

- **WHEN** `docs/team/OWNERSHIP.md` is read
- **THEN** the verification seat's row states that the seat does not implement and names the `team dispatch`
  refusal, so a reader learns the rule from the table itself

#### Scenario: The configured seat replaces the default, and a blank value does not switch it off

- **GIVEN** a project whose roster carries a `checker` seat as well as the conventional `verify`
- **WHEN** `TEAM_VERIFY_SEAT=checker` is configured and an apply brief is dispatched to `checker`
- **THEN** it is refused, while the same brief dispatched to `verify` proceeds
- **AND** with `TEAM_VERIFY_SEAT` unset or empty, an apply brief dispatched to `verify` is refused

#### Scenario: Verification work stays allowed for the seat

- **GIVEN** a brief with `agent: verify`, `phase: verify` and `grant: docs/team/reports/V1-verify.md ·
  openspec/changes/alpha/specs/`
- **WHEN** `team dispatch verify V1 <brief> --print` runs
- **THEN** it proceeds, so the guard never blocks the seat's reviews and reconnaissance
