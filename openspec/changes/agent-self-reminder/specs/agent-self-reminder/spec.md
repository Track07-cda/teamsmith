## Purpose

Let a project PM arrange a durable one-shot reminder, observe its delivery honestly, and resume work at a later time without adding another scheduler service.

## ADDED Requirements

### Requirement: PM Reminders share a project-scoped authority and preserve complete input

The system SHALL provide `team remind add/list/show/cancel` and a PM-only `team_remind` tool backed by the same versioned project-state authority. The owner SHALL be the verified project PM, and creator/source SHALL distinguish CLI from PM tool. Neither API SHALL accept a caller-selected project, owner or recipient. A successful create SHALL return a stable non-reused ID and its persisted actual due time. A project-scoped active key SHALL return the existing ID and fixed due for the same normalized request, and SHALL reject a conflicting request; after observed or cancelled the key is released. A retry after release is a new creation, not an exactly-once guarantee.

`at` SHALL be an unambiguous valid ISO 8601 date-time with explicit offset or `Z`; `after` SHALL be a positive integer number of seconds, minutes or hours. Exactly one is accepted. The first creation SHALL reject past times and intervals shorter than 30 seconds, with an explicit reason. Text SHALL be valid nonempty UTF-8 without NUL and SHALL be stored, shown and delivered in full; oversize input is rejected, never truncated. Active count and message byte limit SHALL be configurable, with defaults 100 and 16,384 bytes. A rolling limit of 20 successful creates per 60 seconds SHALL reject rather than truncate, and an idempotent active-key hit SHALL not consume a create slot.

#### Scenario: Relative retry keeps the first due instant

- **GIVEN** an active PM Reminder created with key `check`, `after 1m` and text `review`
- **WHEN** another process submits the identical request later or concurrently
- **THEN** both return the same ID and first persisted due, and exactly one active Reminder exists

#### Scenario: Conflicting key, bad time and oversize text are explicit

- **GIVEN** an active Reminder with key `check` and a configured message-size bound
- **WHEN** a caller changes the request under that key, supplies both time forms, an offset-free or past instant, an interval under 30 seconds, or a message above the bound
- **THEN** the call is rejected with the applicable reason and no partial or truncated Reminder is created

#### Scenario: Owner and project are not caller-selected

- **GIVEN** two isolated projects and a worker session that changes its cwd to the PM checkout
- **WHEN** the worker, an ordinary Pi session, or a request with forged identity tries to use the PM tool
- **THEN** the tool is hidden or rejects before state access, and neither project's Reminder authority is modified

### Requirement: Pulse durably queues one-shot Reminders without a full-patrol frequency increase

When Pulse is running, its lightweight due detection SHALL commit each eligible Reminder's queue identity, order and enqueue time in the authority independently of PM availability or Standby. `due` is a time-derived view and is not `queued`. Admission order SHALL be due time then stable ID order, with no duplicate queue entry from repeated scans. An item whose due predates the current Pulse instance's start or whose admission lags due by over 30 seconds SHALL be marked overdue; normal polling delay SHALL NOT be labeled overdue. Normal healthy operation SHALL target enqueue within 30 seconds of due, not model start or completion. Pulse being stopped, blocked storage or lock, abnormal clock or insufficient scheduling resources are outside that target and SHALL be visible rather than presented as a passed timing guarantee.

Both existing console and headless Pulse shapes SHALL keep due detection live during a long full patrol, prevent overlapping full patrols and coalesce a missed Reminder recovery recheck to run when the in-flight operation ends. They SHALL stop and reap their own scheduling work on shutdown. No Reminder SHALL cause an extra model turn or a higher-frequency full project scan.

#### Scenario: A due Reminder is queued during a long patrol

- **GIVEN** a full patrol is already running and Pulse's lightweight timer is healthy
- **WHEN** a Reminder becomes due before that patrol finishes
- **THEN** the same authority records it queued within the stated normal target, no second full patrol overlaps, and one coalesced Reminder-only recovery recheck follows the patrol

#### Scenario: Restart catches up without replaying uncertain delivery

- **GIVEN** Pulse is stopped across the due time of an unsent Reminder
- **WHEN** Pulse restarts
- **THEN** the Reminder is queued once with its original ID and an overdue indication, while an existing intent or unknown is not queued for resend

### Requirement: One batch intent governs cancellation and all resend decisions

The watcher SHALL freeze at most eight queued Reminders into one message, write one durable batch intent containing every member before calling Pi, and submit at most one batch per five seconds. A Reminder that has not entered intent MAY be cancelled idempotently; after intent, cancellation SHALL report that withdrawal cannot be guaranteed. A crash before intent leaves a provably unsent item eligible; a crash, timeout, API return or error after intent without a correlated observation SHALL remain unknown and MUST NOT trigger a blind resend. An explicit `team remind resolve <batch-id> --ack-unknown` SHALL atomically close all members of an inspected unknown batch and burn its one remaining auto-off right, returning the affected IDs without claiming delivery or resending them.

The Reminder authority SHALL be the sole decider of its delivery and resend. The ordinary inbox delivery journal, its floor, Outbox, a cache or absence of an old record SHALL NOT independently authorize Reminder resend. Active and unknown records and unspent batch rights SHALL never be evicted by history compaction. Terminal records SHALL be retained for at most the newest 1,000 outcomes or 30 days, and audit for at most its newest 1,000 entries or 30 days, without dropping evidence needed by active or unknown batches. A durable issued-ID high-water SHALL provide an explicit `history-pruned` result for an absent issued ID. Late or duplicate events SHALL NOT recreate a pruned item or a consumed right.

#### Scenario: Cancel races the intent transaction

- **GIVEN** queued Reminders A and B are to be sent together
- **WHEN** cancelling B commits before their batch intent
- **THEN** B is cancelled and absent from the message; if intent commits first, cancellation reports in-flight and does not claim to withdraw B

#### Scenario: Crash after a whole-batch intent

- **GIVEN** A and B have one durable batch intent
- **WHEN** the process dies before, during or after the Pi call without a durable matching observation
- **THEN** both remain unknown, neither is automatically resent, and a restart cannot treat either as independently unsent

#### Scenario: One acknowledgment resolves an entire unknown batch

- **GIVEN** A and B share an unknown batch with an unspent automatic-off right
- **WHEN** an operator inspects the members and acknowledges the batch ID with `--ack-unknown`
- **THEN** A and B become resolved together, the returned result names both, and a late event neither resends either item nor clears a Standby generation

#### Scenario: A retained old active item outlives history compaction

- **GIVEN** an old unknown Reminder and enough newer terminal history to advance retention
- **WHEN** the history is compacted and an old event or scan arrives
- **THEN** the unknown and its right remain available, pruned IDs are reported as pruned, and no removed identity becomes sendable again

### Requirement: A correlated Pi message is the actual Reminder wake boundary

A verified PM watcher SHALL submit the complete batch as a Pi custom message using a non-interrupting follow-up. Actual wake SHALL mean the public `message_start` event for that custom message, with exact batch ID, nonce and member identities matching a durable intent and the verified PM session. For a busy PM this is the later follow-up turn; an unrelated existing run is not the wake. A Pi API return, `before_agent_start`, process start, queue entry, failed send or merely deferred action SHALL NOT be reported as an observed wake. An observed wake SHALL NOT claim session durability, a model request, a successful response or completed work.

#### Scenario: Busy PM receives a later full-text follow-up

- **GIVEN** a PM has an active unrelated turn and a user has a draft in the input editor
- **WHEN** a Reminder is submitted
- **THEN** the active turn is not forcibly interrupted, the draft is unchanged, and only the later `message_start` carrying the exact batch identity and complete text records the Reminder wake

#### Scenario: A call returning is not the wake

- **GIVEN** a batch intent has been written
- **WHEN** `sendMessage` returns but no matching message event is observed
- **THEN** the result remains intent/unknown, not observed, accepted or completed

### Requirement: Reminder wake may clear only its provably bound Standby generation once

A batch intent SHALL bind the current durable Standby generation, or off, before the Pi call. The matching wake SHALL atomically record observation, the one consumed batch right, automatic-off result and audit identifying the batch and every Reminder ID/source. If the bound on generation is still current, the wake SHALL switch it off once. If already manually off, the audit SHALL say so without inventing an automatic off. If a newer on generation exists and its ordering relative to the actual Pi event cannot be proven, it SHALL remain on and the ambiguity SHALL be visible. A later event, manual off/on, restart or lost response SHALL NOT grant that batch another right. Due, queued, intent, API return, failure or unknown without wake MUST NOT automatically turn Standby off.

#### Scenario: Normal bound generation exits on actual wake

- **GIVEN** Standby generation G1 is on when batch A+B is committed to intent
- **WHEN** its matching Pi message enters the PM run while G1 is still current
- **THEN** one atomic outcome records observed A+B, off G1 and one audit naming both IDs and sources

#### Scenario: A newer Standby survives an ambiguous event order

- **GIVEN** intent binds G1 and a different extension can delay the Reminder event handler
- **WHEN** G2 replaces G1 before that handler commits observation, whether Pi emitted the event before or after G2
- **THEN** G2 remains on and the outcome reports generation ambiguity rather than falsely claiming automatic off

#### Scenario: G2 is definitely bound before the wake

- **GIVEN** G2 replaces G1 before a batch is committed to intent
- **WHEN** its matching Pi message enters the run and G2 remains current
- **THEN** G2 is turned off once with the batch audit

#### Scenario: A duplicate after manual re-entry does not exit again

- **GIVEN** batch A+B has already observed its wake and exited G1, and a human then enters G2
- **WHEN** a duplicate or late event is received before or after restart
- **THEN** G2 remains on and no second automatic-off audit is produced

### Requirement: State mutation has one durable cross-process order

Standby on/off, Reminder create/cancel/admission, recovery eligibility, batch intent, observation, automatic off and their audit SHALL use one canonical project-state lock and atomic authority; the lock path SHALL NOT depend on `TMPDIR`. A successful mutation SHALL survive process restart and shall not expose partial state. On lock, identity, fsync or integrity failure the operation SHALL fail visibly without an unlocked fallback. Locking SHALL cover only short state transactions, never a Pi/model turn or a wait for its callback. Legacy Standby SHALL migrate without silently losing the existing reason or state, and old and new writers SHALL NOT run concurrently during migration.

#### Scenario: Different temporary roots still serialize

- **GIVEN** Bash and the PM's Node watcher belong to one verified project but have different `TMPDIR` values
- **WHEN** Standby on, cancel and intent compete
- **THEN** they use one canonical lock and each result reflects one total transaction order

#### Scenario: Process death at observation does not fabricate an off

- **GIVEN** a durable intent and an on generation
- **WHEN** the process dies at any point around the atomic observation/off/audit commit
- **THEN** restart sees either the previous unknown/on state or the committed observation/off/audit together, and replay never clears a newer generation

### Requirement: PM tool availability and limits are honestly diagnosed

The Reminder tool SHALL be injected only into the verified PM, check identity on every call, and be hidden when identity becomes invalid or a reload/switch invalidates it. `team doctor` SHALL distinguish a PM not running, missing/stale or mismatched evidence, explicit tool-load failure, and a fresh extension-reported registration. It MUST NOT claim to have queried another process's in-memory tool set or proved that the model currently sees or used the tool.

#### Scenario: Missing proof is not falsely reported as a load failure

- **GIVEN** a running verified PM whose tool evidence is absent or stale
- **WHEN** `team doctor` inspects Reminder availability
- **THEN** it reports availability unknown and the stale/missing evidence, not confirmed tool failure or success

#### Scenario: A switched session loses access

- **GIVEN** the tool was registered in a verified PM session
- **WHEN** the session switches to a worker or mismatched project identity
- **THEN** the tool is hidden and every attempted invocation refuses before mutation
