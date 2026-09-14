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

#### Scenario: Paths expose the resolved tools

- **WHEN** `team paths` runs with `TEAM_OPENSPEC_BIN=/usr/bin/true TEAM_SPEC_DIR=openspec`
- **THEN** the output contains `"/usr/bin/true"` as the OpenSpec binary and `"openspec"` as the spec directory

### Requirement: Spec management belongs to OpenSpec

teamsmith MUST NOT grow a second, rival requirement/specification format: the only requirement artifacts in the
project are the OpenSpec specs under `TEAM_SPEC_DIR`, and the change workflow is OpenSpec's. A behavior promise that
cannot be made falsifiable yet MUST be written as prose in `references/` instead of being turned into a requirement.

#### Scenario: No rival requirement tree

- **WHEN** every Markdown file in the repository is searched for `### Requirement:` blocks
- **THEN** all of them live under `openspec/specs/`, and none under `skills/teamsmith/`

#### Scenario: An invalid spec fails the project gate

- **GIVEN** a spec whose requirement has no scenario
- **WHEN** the project gate runs (`TEAM_GATES`; `openspec validate --all --strict` alone stays green here)
- **THEN** `bash skills/teamsmith/tests/spec-lint.sh` exits non-zero and names the offending spec
- **AND** restoring the scenario makes the lint and the gate exit 0 again

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
