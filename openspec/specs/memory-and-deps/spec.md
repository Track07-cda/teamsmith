# memory-and-deps Specification

## Purpose

What teamsmith requires from its environment (long-lived PM memory and an OpenSpec root) and where the truth lives:
OpenSpec owns specs and the change workflow, teamsmith owns the evidence ledger, and the disk wins over any memory.
Why: `references/philosophy.md` (handover-ready, no rival spec system) and `references/openspec.md`.
## Requirements
### Requirement: magic-context and OpenSpec are required dependencies

The project SHALL treat the PM's cross-session memory (magic-context) and OpenSpec as required: `team doctor` MUST
fail (non-zero) when magic-context is not detected, when the OpenSpec CLI cannot be resolved, or when the spec
directory is missing, and each failure MUST print the concrete fix. `TEAM_REQUIRE_MAGIC_CONTEXT=0` and
`TEAM_REQUIRE_OPENSPEC=0` SHALL downgrade the check to a warning for environments where the tool is deliberately
absent.

#### Scenario: A missing dependency fails the environment check

- **GIVEN** `TEAM_PI_SETTINGS_FILE` points at a fixture without magic-context and `TEAM_OPENSPEC_BIN=/nonexistent`
- **WHEN** `team doctor` runs
- **THEN** it exits non-zero, names both dependencies, and prints the fix command for each
- **AND** the same command with `TEAM_REQUIRE_MAGIC_CONTEXT=0 TEAM_REQUIRE_OPENSPEC=0` exits 0 and only warns

#### Scenario: A missing spec directory is a failure with a fix

- **GIVEN** `TEAM_SPEC_DIR` points at a directory that does not exist
- **WHEN** `team doctor` runs
- **THEN** it exits non-zero and the message contains the `openspec init --tools none` fix

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

### Requirement: Spec management belongs to OpenSpec

teamsmith MUST NOT grow a second, rival requirement/specification format: the only requirement artifacts in the
project are the OpenSpec specs under `TEAM_SPEC_DIR`, and the change workflow is OpenSpec's. A behavior promise that
cannot be made falsifiable yet MUST be written as prose in `references/` instead of being turned into a requirement.

#### Scenario: No rival requirement tree

- **WHEN** every Markdown file in the repository is searched for `### Requirement:` blocks
- **THEN** all of them live under `openspec/specs/`, and none under `skills/teamsmith/`

#### Scenario: An invalid spec fails the project gate

- **GIVEN** a change whose delta would drop a scenario from an existing requirement (the measured defect class:
  both arbiters were run against exactly this shape on 2026-09-16)
- **WHEN** the project gate runs (`TEAM_GATES`), and when the phase-5 trial archive runs on a scratch copy
- **THEN** `openspec validate --all --strict` refuses the change at gate time, and the trial archive refuses it with
  "scenario(s) not present in the modified block" — the base specs themselves are only ever written through archive
  (direct edits are out of process), so no gate can see a base spec that archive did not produce
- **AND** restoring the scenario in the delta makes both pass

### Requirement: The disk is the source of truth, memory is a convenience

Project memory (magic-context) SHALL only accelerate recall: every decision, piece of evidence and piece of pending
work MUST be reconstructible from files on disk (BOARD, ROADMAP, DECISIONS, reports, reviews, threads, state) after
a restart or a compaction, without reading any memory store.

#### Scenario: Pending work survives a memory-less start

- **GIVEN** a project with one unread notification and one report awaiting review, and no memory store available
- **WHEN** a fresh shell runs `team digest`
- **THEN** both items are listed as pending work

#### Scenario: Decisions are on disk, not only in memory

- **WHEN** a key decision was made in a task
- **THEN** its rationale and impact are written in `docs/team/DECISIONS.md` (or the task's review record) and are
  readable without any memory tooling

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

