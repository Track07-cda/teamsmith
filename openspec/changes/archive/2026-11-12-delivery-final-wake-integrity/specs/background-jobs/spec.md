# Spec Delta

## ADDED Requirements

### Requirement: A job record separates its initiating session from its execution directory

The lane SHALL write the absolute initiating session directory as `session_cwd` and the command's execution directory as `cwd` into each new `.job` record before returning the job id. The execution override SHALL NOT replace initiator identity; existing record-write failure handling, process identity, log and restart evidence SHALL remain unchanged.

#### Scenario: An independent checkout preserves both directories

- **GIVEN** a session running in a seat worktree starts a background job whose `cwd` override names an independent checkout
- **WHEN** the `.job` record is written
- **THEN** `session_cwd` resolves to the initiating seat session directory, `cwd` resolves to the independent checkout, and the record retains the job's `(pid, start-time)`, log and command fields

#### Scenario: A missing override keeps the existing execution location

- **GIVEN** a session starts a background job without a `cwd` override
- **WHEN** the record is written
- **THEN** `session_cwd` and `cwd` both identify the session's execution directory, and the job id is returned only after the record write is attempted as before

#### Scenario: An explicit foreign initiator does not fall back to the execution directory

- **GIVEN** a live record with a valid `session_cwd` belonging to another seat and a `cwd` that happens to name this seat
- **WHEN** ownership is evaluated
- **THEN** the record is not adopted by this seat; the presence of an explicit initiator disables legacy inference from `cwd`

#### Scenario: Legacy ownership is limited to an exact seat-worktree match

- **GIVEN** live legacy records without `session_cwd`, whose `cwd` values respectively name the seat worktree through a symlink or trailing slash, an independent checkout, a subdirectory below the seat worktree, another seat, or a missing or relative path
- **WHEN** ownership is evaluated
- **THEN** only the record resolving exactly to the seat worktree is eligible as that seat's legacy job, and every other record belongs to no seat rather than being inferred from a shared state directory or process identity alone
