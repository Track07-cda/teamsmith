## MODIFIED Requirements

### Requirement: Reply readers remain bounded as history grows
Latest-summary reads SHALL examine only the latest committed index slot; an invalid latest slot SHALL be shown as unavailable rather than silently replaced by an older answer labelled latest. Each list request SHALL examine at most 50 index slots, and each show SHALL examine one slot and at most one 131072-byte body plus a one-byte overflow check. These reads MUST NOT enumerate all body files or scan the full index/history, regardless of stored reply count, and MUST NOT spawn session/history readers. The latest summary SHALL carry metadata or an explicit empty/unavailable state, never body text. Verification MUST distinguish unavailable read-volume evidence from a satisfied bound and from a product failure; absence of an observer MUST NOT relax these reader bounds.

#### Scenario: Large history does not turn every refresh into a scan
- **WHEN** a fixture holds 100000 numbered slots and the user requests summary, one list page and one show
- **THEN** observed storage reads stay within the respective slot/body bounds rather than increasing with history size
- **AND** unopened bodies are never read

#### Scenario: Latest metadata cannot be validated
- **WHEN** the newest committed index slot is malformed or unreadable
- **THEN** the latest summary reports unavailable for that slot
- **AND** a valid older title is not labelled as the latest reply

#### Scenario: Missing read-volume evidence is not a satisfied bound
- **GIVEN** the reply fixture cannot read the process I/O observer, including its existing test-only forced-absence input
- **WHEN** its bounded read-volume check and full_scan negative control reach their normal absence paths
- **THEN** each is named as skipped with the unavailable observer and reason, neither earns a pass or a product failure, and the fixture exits 0 if no other assertion fails
- **AND** latest-slot corruption, non-enumeration, unreadable bodies and other observer-independent assertions are demonstrated once by the normal bounded run, before it invokes the shared observation entry
- **AND** the focused absence sample calls that same entry and proves it returns before observer-specific preparation; it does not claim to repeat the independent file assertions

#### Scenario: Available read-volume evidence still detects a full scan
- **GIVEN** a working process I/O observer and the existing independent 60-slot and 100000-slot stores
- **WHEN** the normal full_scan mutation changes one-page reading into a full-index scan and the clean source is then restored
- **THEN** the real kernel read-volume comparison rejects the mutated source and accepts the restored source with its original 65536-byte delta bound and source-hash restoration evidence
- **AND** the other eight original mutation controls retain their real bad-source and restored-source executions; a missing-observer sample does not replace them
