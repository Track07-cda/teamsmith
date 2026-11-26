## ADDED Requirements

### Requirement: Project label definition commands can report a structured outcome

The existing `team board label define|edit|delete` commands SHALL offer an opt-in `--json` result from the same command and write path as their default output. The result MUST distinguish confirmed success, definite refusal and an unconfirmed write. This does not redefine `Project labels are managed by name beside the board`; default output, exit status and `label ls` remain unchanged.

#### Scenario: Opting into a result does not opt into a different write

- **GIVEN** an accepted project-label catalog and a task that uses one of its definitions
- **WHEN** a definition is saved, a duplicate name or invalid field is submitted, an edit names a now absent label, or an in-use definition is deleted, each with `--json`
- **THEN** stdout yields one UTF-8 object with `result` equal to `ok` on confirmed success or `rejected` on a definite refusal, with `reason` equal to `duplicate`, `invalid_field`, `not_found`, `in_use`, `read_failed` or `not_written` as applicable; `invalid_field` supplies `field` (`name`, `color` or `weight`), and `in_use` supplies a `task_ids` array of blocking task IDs as strings
- **AND** the existing exit status still agrees with success or failure, and the bytes resulting from each operation agree with the same operation without `--json`; consumers need not parse a diagnostic sentence or split a list of IDs from that sentence

#### Scenario: Unconfirmed publication is not a definite refusal

- **WHEN** a write using `--json` has replaced the catalog but cannot confirm persistence
- **THEN** it gives a nonzero status and `result: "unconfirmed"` without claiming that the prior bytes were restored; a separate `label ls` can report what is currently visible without converting the earlier attempt into a confirmed success
