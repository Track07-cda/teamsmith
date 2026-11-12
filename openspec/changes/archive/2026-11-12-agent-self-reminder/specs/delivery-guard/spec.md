## MODIFIED Requirements

### Requirement: Queue entries are immutable files under the team state directory

A held message SHALL be exactly one file under `$TEAM_STATE_DIR/outbox/` named `<epoch-ms>-<zero-padded seq>-<target>.msg`,
written atomically (temporary file + rename) so a reader never observes a partial entry and the name sorts in
enqueue order. The file SHALL start with the header fields `kind`, `target`, `from`, `created` and an optional
`dedup`, then a `---` line, then the payload verbatim; an entry MUST NOT be modified after it is written. The queue
location MUST follow `TEAM_STATE_DIR` alone, so a fixture that points it at a temporary directory writes nothing
into the repository.


These are ordinary Outbox entries. A PM self-Reminder's direct watcher delivery is not an Outbox entry and MUST NOT create a second copy or change ordinary Outbox admission, ordering, freshness, drain or explicit `flush --now` behavior.

#### Scenario: The entry carries the documented header and a verbatim payload

- **GIVEN** a dirty box and a message containing `$(touch <sentinel>)`, backticks and a newline
- **WHEN** the message is enqueued
- **THEN** the entry's header lines are `kind`, `target`, `from`, `created` and `dedup`, followed by `---` and the
  payload byte for byte, `<sentinel>` does not exist, and no `*.tmp` file remains in `outbox/`

#### Scenario: Entries drain in enqueue order

- **GIVEN** three messages enqueued in the order `one`, `two`, `three` while the box is dirty
- **WHEN** the box clears and `team outbox flush` runs
- **THEN** the pane shows `one`, then `two`, then `three` in that order and `outbox/` is empty

#### Scenario: TEAM_STATE_DIR moves the queue

- **GIVEN** a fixture project with `TEAM_STATE_DIR=<temp>`
- **WHEN** a message is enqueued
- **THEN** the entry exists under `<temp>/outbox/` and `<repo>/.pi/team/state/outbox/` does not exist

#### Scenario: A self-Reminder does not alter explicit ordinary delivery

- **GIVEN** one due self-Reminder and an independent ordinary Outbox message
- **WHEN** ordinary Outbox drain or an authorized `team outbox flush --now` is performed
- **THEN** that message follows its existing contract and no second Outbox entry is created for the self-Reminder
