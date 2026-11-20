## ADDED Requirements

### Requirement: Reminder test evidence is distinct from disposable work

The real-Pi test SHALL preserve scene files written to a nonempty `P442_EVIDENCE` on success, failure
or interruption. Only with nonempty `P442_KEEP` SHALL it also preserve and report the original
`run-*` layout there. With no named evidence path, scene files belong to the managed work.
Nonempty `P444_KEEP` SHALL preserve and report the fault run's records in its work directory;
`P442_EVIDENCE` does not select that directory.

#### Scenario: Caller-owned real-Pi evidence stays at the named path

- **GIVEN** a named `P442_EVIDENCE` and a real-Pi scene that writes a record
- **WHEN** the run succeeds, fails or is interrupted after the record is written
- **THEN** the scene record remains in the named directory
- **AND** a nonempty `P442_KEEP` leaves and reports the private project files in the original `run-*` child,
  while a run without it does not leave private project files there

#### Scenario: Default scene output follows the real-Pi work

- **GIVEN** no named evidence directory
- **WHEN** a real-Pi scene writes its record
- **THEN** that record stays with the managed work, disappearing with unkept work or remaining with kept work

#### Scenario: Requested fault evidence names the retained work

- **GIVEN** nonempty `P444_KEEP` and a nonempty `P442_EVIDENCE` pointing elsewhere
- **WHEN** the fault run writes records and fails
- **THEN** it still reports failure and names the retained work directory containing the fault records,
  without using the real-Pi evidence path
