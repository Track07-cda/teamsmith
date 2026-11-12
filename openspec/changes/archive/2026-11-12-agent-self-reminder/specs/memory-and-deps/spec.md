## MODIFIED Requirements

### Requirement: Tool resolution is visible

The OpenSpec CLI and spec root SHALL be configurable (`TEAM_OPENSPEC_BIN`, default `openspec`, an absolute path
allowed; `TEAM_SPEC_DIR`, default `openspec`) and the resolved values MUST be reported by `team paths` together with
the requirement switches, so the PM never has to guess which binary and directory are in use.

The resolved JS runtime SHALL be reported the same way: `team paths` MUST carry `js_runner` (the resolved path —
`TEAM_JS_BIN` first, else `node`, `bun` or `tsx` on `PATH`) and `require_js` (the effective value of
`TEAM_REQUIRE_JS`, default `1`) next to the existing keys.


The `flock` utility needed for serialized Standby/Reminder mutation SHALL likewise be resolved and shown as `flock_runner` by `team paths`. `team doctor` SHALL name a missing or unusable executable and its concrete repair; it MUST NOT claim serialized mutations are available without it. Mutation against a filesystem that does not support the exclusive lock SHALL fail visibly without an unlocked fallback. This is an additional OS utility requirement even for Standby in a project without Reminders, not a new scheduler service.
#### Scenario: Paths expose the resolved tools

- **WHEN** `team paths` runs with `TEAM_OPENSPEC_BIN=/usr/bin/true TEAM_SPEC_DIR=openspec`
- **THEN** the output contains `"/usr/bin/true"` as the OpenSpec binary and `"openspec"` as the spec directory

#### Scenario: Paths expose the resolved runtime

- **WHEN** `team paths` runs with `TEAM_JS_BIN=/usr/bin/node`, and then with `TEAM_REQUIRE_JS=0`
- **THEN** the first output contains `"/usr/bin/node"` as `js_runner` and `"1"` as `require_js`, and the second
  contains `"0"` as `require_js`

#### Scenario: Missing flock is visible and does not silently downgrade Standby

- **GIVEN** a verified project on a PATH without `flock` and with no Reminders
- **WHEN** `team paths`, `team doctor` and `team standby on --reason test` run
- **THEN** paths exposes the unresolved lock utility, doctor identifies it and its repair, and Standby fails without an unlocked write

#### Scenario: Unsupported lock operation is diagnosed

- **GIVEN** `flock` resolves but exclusive locking the actual canonical project-state filesystem fails
- **WHEN** a Reminder mutation is attempted
- **THEN** it fails visibly without changing the authority and the diagnostic identifies the lock or filesystem failure
