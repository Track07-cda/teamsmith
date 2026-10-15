## MODIFIED Requirements

### Requirement: Publication does not gate the normal answer or create work

Publishing a key conclusion SHALL be a standing duty of the PM that travels with the tool rather than a
recollection of one project or one machine: before a milestone lands, before it issues a ruling, and before it asks
the user to decide, the PM MUST first publish the complete conclusion — the whole answer, not a summary of it —
with `team reply post --from pm --title '<short single line>' --stdin`, and then send that same body in the
conversation. A batch of conclusions MAY be one reply, and a reply carries conclusions rather than process
narration. The Agent workflow SHALL attempt explicit publication of a chosen key answer, then send the same
answer normally whether publication succeeds, fails, is busy or remains unconfirmed. A saved receipt SHALL mean
only project-local durable publication, not user delivery, approval, read status or a refreshed Pulse screen. Key
replies MUST NOT increment pending work, affect BOARD tasks/outbox/inbox, wake the PM, or introduce a
confirmation/reminder/approval lifecycle. No new project configuration key SHALL be required for this capability.
The surfaces that carry this duty wherever the tool is installed, and the correctness gate that holds them, are
specified by `key-replies#The key-conclusion duty is shipped on its instruction surfaces and held by the gate`.

#### Scenario: Normal answer survives every publication result
- **WHEN** a fixture Agent obtains saved, input-error, storage-error, busy or unconfirmed from its publication attempt
- **THEN** it still emits the same normal answer and any failure notice is separate from that answer
- **AND** no new pending item, outbox/inbox message, task or patrol wake is created by reply publication

## ADDED Requirements

### Requirement: The key-conclusion duty is shipped on its instruction surfaces and held by the gate

The key-conclusion duty SHALL travel with the tool. The prompt template the PM is started from SHALL carry a short
section stating the duty: when it applies (a landed milestone, a ruling, a decision requested from the user), the
publication command whose body is the complete answer and arrives over `--stdin`, that the same body is then sent
in the conversation, that a batch of conclusions MAY be one reply, and that the reply carries conclusions rather
than process narration. The protocol reference SHALL state the same duty as the PM's standing obligation in the
same vocabulary, and the command table SHALL present `reply` as the outlet for key conclusions to the user,
distinguished from the internal `say` and `notify` channels. The correctness gate SHALL hold these surfaces
instead of relying on care: it MUST fail, naming the surface that lost the duty, when the section is missing from
the prompt template, when the duty statement is missing from the protocol reference, or when the command table
stops presenting `reply` as the user-facing outlet. The gate SHALL also judge the example command printed as the
way to publish: the command words and flags it shows MUST be accepted by the real CLI instead of being refused as
unknown, and that judgement MUST NOT be vacuous — an unknown flag added to the same probe MUST be refused by the
real parser. The gate MAY assert stable phrases and MUST NOT require byte-identical prose across the surfaces. The
shipped text SHALL keep its honest limit: no tool can verify that a live agent follows the duty, and the gate
claims only that the duty is shipped and that its example command works.

#### Scenario: A surface that loses the duty names itself
- **WHEN** the duty section is removed from the prompt template, the duty statement is removed from the protocol reference, or the command table stops presenting the user-facing outlet
- **THEN** the correctness gate fails and names the surface that lost it
- **AND** restoring that surface makes the gate pass again

#### Scenario: The printed example command is a command the CLI accepts
- **WHEN** the command words and flags of the printed publication example are run against the real CLI in a fixture project
- **THEN** the real parser accepts them instead of answering with its unknown-flag refusal
- **AND** the same probe with an unknown flag added is refused by the real parser, so a silently ignored flag cannot read as accepted

#### Scenario: What the gate cannot prove stays stated
- **WHEN** the shipped surfaces and the gate are read
- **THEN** they state that no tool verifies a live agent's obedience and that the gate judges only the shipped duty and the working example
- **AND** no gate output claims to have checked which conclusions a PM actually published
