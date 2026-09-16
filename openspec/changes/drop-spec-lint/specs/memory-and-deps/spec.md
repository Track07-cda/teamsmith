## MODIFIED Requirements

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
