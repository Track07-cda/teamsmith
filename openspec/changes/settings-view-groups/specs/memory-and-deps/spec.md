## ADDED Requirements

### Requirement: The machine read reports each key's functional group, and the schema is its only source

`team config list --json` SHALL report, for every key record, a `group` field: for a key the schema carries, the
schema row's **tenth column** verbatim — a closed ASCII token matching `^[a-z][a-z0-9-]*$` — and for a key the
file carries and the schema does not know, the empty string.

- The group SHALL be the row's own data: the command MUST NOT carry a second group table, and it MUST NOT derive
  the group by parsing the schema's section comments (they are documentation, not a grammar). A key added to the
  schema SHALL appear under its group with the console bundle unchanged.
- Every schema row SHALL declare a group. A row whose tenth field is missing, or whose token does not match the
  shape above, SHALL fail the project's fixture gate naming the key (and the token where there is one) — the read
  MUST NOT invent a default group, drop the row, or filter the malformed token silently.
- The read is the only carrier: the human `team config list` table, every existing `--json` record field,
  `team monitor --print` and `team monitor --json` SHALL keep their current bytes and columns, and no machine
  exit other than `team config list --json` SHALL carry the field.

#### Scenario: The group is the row's tenth column, per section

- **GIVEN** a fixture project initialised from this tree
- **WHEN** `team config list --json` runs
- **THEN** `TEAM_PROJECT` reports `group` `identity`, `TEAM_PULSE_INTERVAL` reports `panel`, `TEAM_DEFAULT_MODEL`
  reports `seat-model` and `TEAM_GATES` reports `workflow`, and the records' `group` values are exactly the tokens
  the schema's rows carry, in the schema's own row order
- **AND** a key the file carries and the schema does not still gets a record, with `group` `""`

#### Scenario: A missing or malformed token is a gate failure

- **GIVEN** a scratch copy of the CLI whose `TEAM_GATES` row lost its tenth field, and a second scratch copy
  whose `TEAM_PULSE_INTERVAL` token reads `NoPe!`
- **WHEN** the project's config fixture runs its group walk against each tree
- **THEN** it exits non-zero naming `TEAM_GATES` in the first and `TEAM_PULSE_INTERVAL` with `NoPe!` in the
  second — the gate, not a silent default, is what keeps the field honest
- **AND** restoring each row makes the walk pass

#### Scenario: The field is additive and nothing else moves

- **GIVEN** a fixture project and two contracts whose values differ
- **WHEN** `team config list`, `team config list --json`, `team monitor --print` and `team monitor --json` run
  under each
- **THEN** the human table keeps its `KEY CLASS KIND VALUE` header and gains no group column, the `--json`
  record keeps every existing field name and type next to the new `group`, and neither machine exit carries a
  group field
