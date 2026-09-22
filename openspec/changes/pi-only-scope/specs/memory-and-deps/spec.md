## ADDED Requirements

### Requirement: The worker-launch keys are an internal frozen seam, not a supported extension point

The four worker-launch keys (`TEAM_AGENT_CMD`, `TEAM_AGENT_NOTIFY_CMD`, `TEAM_AGENT_LOG_GLOB`,
`TEAM_AGENT_BIN`) SHALL stay in the schema with class `apply` and keep every behaviour they have today. The
schema row and `references/config.md` SHALL describe them as an **internal seam (frozen)** — reserved for a
possible future non-Pi adapter, **no compatibility promise**, and not asked in the new-project questionnaire.
The marking SHALL live in the schema row's free-text column so `team config list --json` reports it verbatim
on each of the four records (the console shows it under the row, the same place a `refuse` key's route is
shown), and the schema's own header comment SHALL document the free-text column as the same route/note field
for `apply` keys. The human table (`KEY CLASS KIND VALUE`), the writer's validation, quoting, CAS, audit and
danger rules, the four keys' validated domains and the value of the keys' `class` SHALL be unchanged; the
questionnaire's silence is the `init-skill` capability's promise, this requirement owns the schema and
documentation marking.

#### Scenario: The marking reaches the machine read, and the walk makes it falsifiable

- **GIVEN** a fixture project initialised from this tree
- **WHEN** `team config list --json` runs
- **THEN** each of the four records reports `"class":"apply"`, its existing `kind`/`form`/`default` fields
  unchanged, and a `"route"` naming the frozen seam (`内部接缝（frozen）`) together with the no-compatibility
  promise, while `team config list`'s human header is still `KEY CLASS KIND VALUE`
- **AND** the fixture's red side — a scratch tree via `TEAM_CONFIG_TREE` whose `TEAM_AGENT_CMD` row lost its
  marking — makes the config section exit non-zero and name `TEAM_AGENT_CMD`; restoring the marking is green

#### Scenario: The keys stay writable and their domains do not change

- **GIVEN** a contract whose sha256 is recorded
- **WHEN** `team config set TEAM_AGENT_CMD 'myagent {prompt}' --yes`, then
  `team config set TEAM_AGENT_BIN /nonexistent/cli --yes`, then
  `team config set TEAM_AGENT_CMD $'line1\nline2' --yes` are attempted
- **THEN** the first two exit 0 and each appends exactly one `result=ok` audit line, the third exits 4 naming
  the single-line rule with the sha256 unchanged, and no write to the four keys is ever refused with the
  frozen text as its route (class stays `apply`, not `refuse`)

#### Scenario: Templates keep the keys and stop offering a worked example

- **GIVEN** `templates/config.sh.tmpl` and a contract freshly rendered from it
- **WHEN** both are read
- **THEN** the rendered adapter section carries the frozen wording and still declares the four keys (empty),
  and it offers no ready-to-use example of another CLI — worked examples live only in
  `references/agent-adapters.md`, under the frozen wording
- **AND** the `config-cli.sh` completeness walk (schema ↔ template ↔ `references/config.md`) stays green with
  no test edit
