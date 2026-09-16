## ADDED Requirements

### Requirement: A JS runtime is a required dependency

The JS runtime the panel bundle runs on SHALL be required like magic-context and OpenSpec (see the capability's
"magic-context and OpenSpec are required dependencies" requirement): `team doctor` MUST fail (non-zero) when none of
`node`, `bun` and `tsx` resolves on `PATH` and `TEAM_JS_BIN` names nothing usable, and when the resolved runtime's
major version is below the minimum the shipped panel bundle declares (`node` 20 or `bun` 1.3 today). The failure MUST
name the path or version it resolved and print the fix. `TEAM_REQUIRE_JS=0` SHALL downgrade this one check to a
warning; it does not give the panel a degraded mode of its own — the panel still requires a runtime (`panel`).

#### Scenario: A machine without a JS runtime fails the environment check

- **GIVEN** a `PATH` without `node`, `bun` and `tsx`, `TEAM_JS_BIN` unset, and the other required dependencies still
  resolvable (a stub OpenSpec CLI on `PATH` and `TEAM_REQUIRE_MAGIC_CONTEXT=0`)
- **WHEN** `team doctor` runs, and then `TEAM_REQUIRE_JS=0 team doctor` runs
- **THEN** the first run exits non-zero, names node and bun and prints the fix
- **AND** the second exits 0 and only warns

#### Scenario: An unusable or too-old runtime is named

- **GIVEN** `TEAM_JS_BIN` pointing first at a file that is not executable and then at a shim that prints `v18.0.0`
- **WHEN** `team doctor` runs against each of the two
- **THEN** the first run exits non-zero and names that path, and the second exits non-zero naming the version `18` and
  the required minimum

## MODIFIED Requirements

### Requirement: Tool resolution is visible

The OpenSpec CLI and spec root SHALL be configurable (`TEAM_OPENSPEC_BIN`, default `openspec`, an absolute path
allowed; `TEAM_SPEC_DIR`, default `openspec`) and the resolved values MUST be reported by `team paths` together with
the requirement switches, so the PM never has to guess which binary and directory are in use.

The resolved JS runtime SHALL be reported the same way: `team paths` MUST carry `js_runner` (the resolved path —
`TEAM_JS_BIN` first, else `node`, `bun` or `tsx` on `PATH`) and `require_js` (the effective value of
`TEAM_REQUIRE_JS`, default `1`) next to the existing keys.

#### Scenario: Paths expose the resolved tools

- **WHEN** `team paths` runs with `TEAM_OPENSPEC_BIN=/usr/bin/true TEAM_SPEC_DIR=openspec`
- **THEN** the output contains `"/usr/bin/true"` as the OpenSpec binary and `"openspec"` as the spec directory

#### Scenario: Paths expose the resolved runtime

- **WHEN** `team paths` runs with `TEAM_JS_BIN=/usr/bin/node`, and then with `TEAM_REQUIRE_JS=0`
- **THEN** the first output contains `"/usr/bin/node"` as `js_runner` and `"1"` as `require_js`, and the second
  contains `"0"` as `require_js`
