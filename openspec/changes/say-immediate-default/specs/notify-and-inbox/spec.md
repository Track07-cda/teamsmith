## MODIFIED Requirements

### Requirement: Messages to a stopped agent fall back to the inbox

`team say <agent> "<one line>"` SHALL prefer the existing valid live inbox-watch route. A successful handoff
SHALL persist the complete message in the durable inbox plus its wake spool, send zero tmux keys and leave both
clean and dirty editors untouched. Its acknowledgement SHALL describe that handoff, not confirmed model receipt.
The existing watcher identity/liveness/project checks remain in force. Invalid, stale, dead or foreign-project
registrations MUST NOT be credited as successful watch delivery or alone authorize typing.

Without a usable watcher, say SHALL attempt the existing forced direct-send behavior by default for a running,
permitted target, even if its editor contains a single-line or multi-line draft. The draft is no longer a reason
to queue this direct fallback. The direct attempt SHALL produce exactly one existing-format forced audit record,
no active queue entry, and an immediate-attempt acknowledgement that does not promise model receipt or automatic
queueing of transport failures. `--no-verify` suppresses only the existing snapshot/wait/extra-Enter behavior, not
route, recipient or target checks.

Before a direct attempt, existing recipient/`--any` and foreign-session protections MUST hold. With no usable
watcher, a missing window, a dead pane or an exited agent at an empty shell prompt MUST receive no key: the
message MUST instead be appended to `docs/team/inbox/<agent>.md` and the command MUST explain the offline/dead
outcome and existing recovery route. A watcher selected for this attempt whose persistence or route then fails
MUST NOT cause an unchecked fallback into that pane; retain the existing recoverable Outbox entry and report the
actual queued/held/failure outcome. If the initial watch entry cannot be persisted at all, the command SHALL
exit non-zero and name the persistence failure, with no keys and no claim of a queued entry or offline inbox
success. An ordinary later drain remains guarded, and explicit Outbox overrides keep their prior semantics.

`team say --now` SHALL be rejected through the existing unknown-flag path in either position before any delivery
side effect. Current help, command strings and active instruction/config/troubleshooting text SHALL describe
watch-first/default-direct say rather than promising that say waits for drafts; they MUST NOT present the retired
flag as an available say option. Other senders' draft-safety promises and existing explicit draft/Outbox escape
hatches remain intact.

#### Scenario: Offline delivery is visible

- **GIVEN** no usable watcher and an agent whose window is missing or whose CLI process has exited to an empty prompt
- **WHEN** `team say dev "check the failing test"` runs
- **THEN** the message appears in `docs/team/inbox/dev.md`, the output states that it went to the inbox, and no text or Enter is typed into the window's shell prompt
- **AND** no forced record is written, including with `--no-verify`

#### Scenario: A dead pane receives an inbox fallback with its evidence

- **GIVEN** no usable watcher and a dead target pane with existing exit evidence
- **WHEN** default say runs
- **THEN** no key is sent, the message is persisted in that recipient's inbox, output names the dead pane and recovery/evidence, and no forced record is written

#### Scenario: A single-line draft is part of the no-watch direct attempt

- **GIVEN** a permitted running Pi target, no usable watcher and the genuine single-line draft shape represented by `skills/teamsmith/tests/frames/pi-0.87.0-one-line-draft.txt`
- **WHEN** default say sends a different correction
- **THEN** it attempts the prior forced behavior without waiting for the draft to clear or a flush, with one forced line and no active queue entry
- **AND** real-Pi request/frame evidence distinguishes the submitted combined input from mere text on a pane; the CLI calls this an attempt, not confirmed model receipt

#### Scenario: An empty no-watch editor uses the same direct fallback

- **GIVEN** a permitted running target, no usable watcher and an empty editor
- **WHEN** default say sends a correction
- **THEN** it uses the same audited direct-attempt path without creating an active queue entry or claiming confirmed receipt

#### Scenario: A draft in the target's input box is not disturbed

- **GIVEN** a valid live watcher for a recipient, once with a clean editor and once with a genuine draft
- **WHEN** default say sends one correction in each independent run
- **THEN** each successful handoff has one durable inbox message plus its spool wake, zero keys and zero forced records, and preserves the editor
- **AND** each correction eventually appears once in actual model-request evidence, measured separately from the handoff acknowledgement

#### Scenario: Rejected registrations do not bypass no-watch safety

- **GIVEN** a dead, invalid, stale-heartbeat or foreign-project watcher registration, and separately a missing window, dead pane, empty shell and permitted running TUI
- **WHEN** default say evaluates the route and target
- **THEN** no rejected registration counts as watched delivery; unsafe/offline targets receive no keys and use the existing inbox fallback, and only the permitted running target may take the ordinary checked direct fallback

#### Scenario: A single-line draft queues the message

- **GIVEN** a running target holding a genuine single-line draft and a watch route accepted for this attempt but removed before entry processing, or an inbox/spool write failure
- **WHEN** the watch handoff is attempted
- **THEN** the payload remains recoverable in the existing Outbox, no key or forced record is created, and the result does not say watched success, confirmed receipt or that clearing a draft guarantees delivery
- **AND** the queue is caused by the failed watch handoff, not the mere existence of a single-line draft; a subsequent ordinary drain remains protected

#### Scenario: Recipient and verification options keep their boundaries

- **GIVEN** an unknown recipient and separately a known permitted running target without a watcher
- **WHEN** ordinary say, say with `--any`, and say with `--no-verify` are exercised in their existing supported forms
- **THEN** an unknown recipient is rejected before delivery unless `--any` is supplied, `--any` keeps its existing unknown-recipient audit without bypassing session or offline safety, and `--no-verify` affects only the direct snapshot/wait/extra-Enter behavior
