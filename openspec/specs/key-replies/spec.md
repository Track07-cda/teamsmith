# key-replies Specification

## Purpose
Let users return to complete answers that an Agent explicitly chooses to preserve, without searching chat history. Keep this project-local publication and read surface separate from message delivery, patrol work, and any Pi session reader.
## Requirements
### Requirement: Key replies are explicitly published from bounded stdin
The system SHALL provide `team reply post --from <label> --title <title> --stdin`. The body MUST come only from stdin, never inferred from chats, task reports, or Pi history. The publisher label MUST be an explicit, self-declared flat identifier of 1–48 ASCII letters, digits, dots, underscores or hyphens, not an authenticated identity or a claim about the currently running seat. The title MUST be nonblank, single-line UTF-8 of at most 160 Unicode codepoints, without terminal controls or bidi/invisible formatting controls. The body MUST be nonempty valid UTF-8, without NUL, and at most 131072 bytes. Other body controls MUST remain in the original stored bytes but not in safe displays. Invalid input MUST be refused without publishing; oversized stdin MUST be detected using a bounded read rather than unbounded buffering. No overwrite, edit, deletion, automatic deduplication or automatic import command SHALL be introduced.

#### Scenario: Explicit body rather than chat inference
- **WHEN** an Agent submits a title, its declared label and stdin body containing markdown, CJK text and a trailing newline
- **THEN** one new reply preserves that exact body and the explicit metadata
- **AND** no session/history/report reader or notification sender is invoked

#### Scenario: Input boundary is enforced before publication
- **WHEN** input has a missing or unsafe label, blank/multiline/overlong/controlled title, empty body, invalid UTF-8, NUL, or 131073 body bytes
- **THEN** the command exits 2 with a bounded diagnostic and no published reply
- **AND** a valid 131072-byte body is accepted without truncation

#### Scenario: Repeated submissions are distinct
- **WHEN** identical valid input is explicitly posted twice
- **THEN** two distinct replies are published rather than silently deduplicated or overwritten

### Requirement: Saved replies have stable concurrent numbers and atomic visibility
Successful publications SHALL receive a project-local positive decimal `no` in strictly increasing commit order, starting at 1 and bounded by 999999999999. A committed number MUST remain stable across restarts and MUST NOT be reused or overwritten. Concurrent publishers MUST serialize commits without lost bodies or duplicate numbers. A publication MUST become visible to summary, list and show readers only as a complete entry whose original body is already durable. Readers MUST NOT wait for the writer lock or consume temporary/uncommitted bodies. A reader concurrent with a publication SHALL see either the earlier committed snapshot or the complete new entry, not half metadata/body.

#### Scenario: Simultaneous publishers preserve both bodies
- **WHEN** two isolated processes post different valid bodies at the same time
- **THEN** both successful publications have distinct ordered numbers and exact retrievable originals
- **AND** repeated list/show reads never observe an entry with a partially saved body

#### Scenario: Restart retains numbering
- **WHEN** publishers and readers restart after several successful posts
- **THEN** prior numbers still address the same bodies and the next successful post uses the next number
- **AND** number exhaustion is diagnosed as storage unavailable rather than wrapping or overwriting

### Requirement: Publication receipts distinguish saved failed busy and unconfirmed
`post` SHALL return exit 0 and a body-free JSON receipt `{outcome:"saved",no,title,from,at,bytes,sha256}` only after durable publication. Usage/input failure SHALL return 2, unavailable/corrupt storage SHALL return 4, and writer-lock contention SHALL return 5 after at most 2000 ms of lock waiting. The end-to-end command is not claimed to have a 2000 ms filesystem I/O deadline. A failure after visibility whose durability cannot be confirmed SHALL return 6 with `outcome:"unconfirmed"` and `candidate_no`, never a saved receipt; automatic retry MUST NOT occur. Failure diagnostics MUST NOT echo body text. A killed process need not emit a receipt, and lack of a receipt MUST NOT be interpreted as proof that nothing was committed.

#### Scenario: Unwritable directory does not produce false success
- **WHEN** the reply directory cannot be created or written
- **THEN** post returns 4 and a bounded stderr reason, without a saved receipt or claims of delivery/screen refresh
- **AND** it does not depend on writing an audit file in that same directory or elsewhere to report the failure

#### Scenario: Bounded lock contention
- **WHEN** another live publisher holds the writer lock beyond 2000 ms
- **THEN** the contender returns 5 without a published reply or deletion of the live writer's lock
- **AND** list and show remain usable without acquiring that lock

#### Scenario: Durability uncertainty after publication
- **WHEN** publication has become visible but the final durability confirmation fails
- **THEN** the command returns 6 and the candidate number without claiming saved or automatically posting again
- **AND** the caller can check that number with show before deciding on an explicit later post

### Requirement: Interrupted publication is recoverable without reader writes
Readers SHALL ignore uncommitted body artifacts and an incomplete index tail, report an incomplete-tail warning, and continue serving earlier committed entries. The next publisher, under exclusive serialization, SHALL recover only a provably incomplete uncommitted tail before appending; it MUST NOT silently discard or rewrite a fully sized corrupt committed slot. Stale writer ownership from a killed local process SHALL be recoverable by a later publisher; unknown or demonstrably live ownership MUST NOT be stolen. Reader commands and the panel MUST NOT perform recovery writes or garbage collection.

#### Scenario: Killed before the visibility point
- **WHEN** a publisher is killed after staging the original but before a complete committed entry is visible
- **THEN** readers expose no new reply and preserve old numbers/bodies
- **AND** a later publisher can recover the incomplete operation without exposing or overwriting an old committed reply

#### Scenario: Killed after the visibility point
- **WHEN** a publisher is killed after durable publication but before printing its receipt
- **THEN** readers can find the complete committed reply under its stable number
- **AND** the next publication neither duplicates that operation automatically nor reuses its number

#### Scenario: Complete corrupt tail is not erased as an interruption
- **WHEN** the last fully sized committed index slot is corrupted
- **THEN** readers diagnose it and a later post refuses with exit 4 rather than truncating that slot as uncommitted

### Requirement: Bounded pages keep every older committed number reachable
`team reply list [--before <no>] [--json]` SHALL return the newest numbered slots first, at most 50 per page, with metadata but no bodies. `before` SHALL be a positive decimal exclusive cursor; absent cursor means newest snapshot. Results SHALL include `next_before` when earlier slots exist, and SHALL include an unavailable placeholder for a corrupt slot instead of losing its number or cursor position. An empty/missing store SHALL return exit 0 with an explicit empty result. Source-level permission/path failures SHALL return 4 with an explicit unavailable result; individual corrupt slots SHALL remain numbered unavailable rows in an otherwise successful page. Invalid cursors SHALL exit 2. Paging MUST progress toward older slots even when every slot in a page is corrupt. Total slot count MUST NOT be described as a verified count of readable replies. Concurrent new posts MUST NOT cause an older-page cursor to repeat/skip preexisting slots.

#### Scenario: More than one page is actually accessible
- **WHEN** 123 replies exist and the caller follows list cursors from newest to oldest
- **THEN** the pages cover numbers 123 through 1 exactly once in descending order, without reading their bodies
- **AND** the final page has no older cursor

#### Scenario: All corrupt page still advances
- **WHEN** one entire 50-slot page has invalid records but older valid replies exist
- **THEN** unavailable numbered rows and a usable older cursor are returned
- **AND** following that cursor reaches the older valid replies rather than an endless empty page

#### Scenario: New posts do not disturb older continuation
- **WHEN** a new publication occurs after the caller obtained the first page
- **THEN** continuing with that page's cursor still reaches every earlier slot without duplicates
- **AND** an explicit newest refresh discovers the new publication

### Requirement: Numbered show preserves originals and provides safe exports
`team reply show <no> [--json|--raw]` SHALL address only a committed numbered entry. Default text and JSON SHALL sanitize terminal controls while keeping surrounding visible text and markdown content; JSON SHALL identify its body as safe display text and include original byte length and SHA-256. `--raw` SHALL export the exact stored bytes only to non-TTY stdout, with no implicit newline, without executing text, following links or invoking an editor. `--raw` on a TTY and invalid number/option combinations SHALL exit 2. Missing, invalid, oversized, substituted or unreadable committed bodies SHALL exit 4 with a body-free reason, never an apparent complete but truncated success. The bounded body read MUST check both stored byte length and hash.

#### Scenario: Byte-exact export and safe visible text
- **WHEN** an original contains CRLF, a trailing newline, OSC/CSI/BEL and visible text before and after those controls
- **THEN** non-TTY raw export hashes identically to the input
- **AND** default/JSON output preserves the surrounding visible text but contains no executable controls and is labelled as a display representation

#### Scenario: Broken body is not silently abbreviated
- **WHEN** a body is missing, hash-mismatched, invalid UTF-8 or larger than 131072 bytes
- **THEN** show returns 4 and the panel can mark that number unavailable
- **AND** no truncated body is passed off as the saved answer

### Requirement: Reply readers remain bounded as history grows
Latest-summary reads SHALL examine only the latest committed index slot; an invalid latest slot SHALL be shown as unavailable rather than silently replaced by an older answer labelled latest. Each list request SHALL examine at most 50 index slots, and each show SHALL examine one slot and at most one 131072-byte body plus a one-byte overflow check. These reads MUST NOT enumerate all body files or scan the full index/history, regardless of stored reply count, and MUST NOT spawn session/history readers. The latest summary SHALL carry metadata or an explicit empty/unavailable state, never body text.

#### Scenario: Large history does not turn every refresh into a scan
- **WHEN** a fixture holds 100000 numbered slots and the user requests summary, one list page and one show
- **THEN** observed storage reads stay within the respective slot/body bounds rather than increasing with history size
- **AND** unopened bodies are never read

#### Scenario: Latest metadata cannot be validated
- **WHEN** the newest committed index slot is malformed or unreadable
- **THEN** the latest summary reports unavailable for that slot
- **AND** a valid older title is not labelled as the latest reply

### Requirement: Reply storage paths and declared identity are untrusted data

Storage SHALL use only this project's resolved state directory and validated flat internal record names. Readers and publishers MUST reject symlink/nonregular index, lock or body artifacts, path traversal, foreign-root substitution and unsafe directory ancestry instead of following them. No read API SHALL accept an arbitrary file path. Publisher labels SHALL be displayed exactly as the record carries them — the label itself, with no qualifier about whether it was verified — and that display rule is the same for the panel and for the human output of `team reply list` / `team reply show`, while every machine output (`--json`, the raw store read) keeps the label byte for byte and the record keeps the label the publisher wrote. Displaying the label as recorded MUST NOT be read as a verification: the tool authenticates nothing, the label is what the caller wrote, and no output may claim a check that did not happen (the sentences that say so belong in the documentation and in this requirement, not as a suffix on the label). Markdown links/images and embedded commands MUST remain inert text; display MUST NOT fetch content, read local linked files, send terminal hyperlinks or execute shell syntax. Safe displays SHALL sanitize every external string, including corruption diagnostics.

#### Scenario: Traversal and nonregular sources are refused
- **WHEN** a selector contains traversal or the store/index/body is replaced by a symlink, FIFO, directory or foreign path
- **THEN** the operation rejects without reading the target or blocking on the FIFO
- **AND** outside-root files and processes remain untouched

#### Scenario: Declared label and hostile markdown remain data
- **WHEN** a reply claims another seat's label and contains shell syntax, local links, remote images and terminal controls
- **THEN** the label is displayed as the record carries it (the label alone, no qualifier beside it) and the body is only safely rendered
- **AND** no shell, network fetch, local-link reader or delivery operation runs

#### Scenario: The recorded label is what the reader sees
- **GIVEN** a reply posted with `--from pm` and a body the publisher wrote
- **WHEN** the panel shows its latest summary, a list row and the open body, and `team reply list` / `team reply show <no>` run
- **THEN** every human output names the label `pm` exactly as the record carries it and adds no qualifier about verification, and the machine outputs still carry `from` with the same bytes
- **AND** a scratch copy of the display that renders a qualifier beside the label makes the display fixture red, while the store, the readers and the refusal rules are untouched by that flip

### Requirement: Publication does not gate the normal answer or create work

Publishing is a standing duty of the PM that travels with the tool rather than a recollection of one project or one
machine, and its trigger is decided by the **reader**: a reply written for the user MUST be published — the complete
reply, not a summary of it — with `team reply post --from pm --title '<short single line>' --stdin`, and then sent
in the conversation as the same body. Answering a question the user asked, reporting status or progress, giving a
conclusion or a ruling, asking the user to decide, and summarising a delivery or a verification are all replies
written for the user, and so is any other reply whose reader is the user: length never decides, and neither does
the size of the topic. A reply that is not written for the user is not published: coordination with the patrol,
with another seat or with another project's PM stays in its own channel, and a tool-generated receipt is not a
reply at all. The boundary is one question — who is this reply written for? — and a reply whose reader cannot be
settled is treated as written for the user. A reply written for the user is never held back because of what kind of
reply it is: a status or progress report, a delivery summary and a decision request are published exactly as a
conclusion is, and no reply becomes unpublishable by reading like process rather than like a conclusion. What the
page carries is the reply's substance — the body the user needs to read — rather than a play-by-play of the work. A
batch of user-facing replies MAY be one reply. The Agent workflow
SHALL attempt explicit publication of the reply it chose, then send the same reply normally whether publication
succeeds, fails, is busy or remains unconfirmed. A saved receipt SHALL mean only project-local durable
publication, not user delivery, approval, read status or a refreshed Pulse screen. Key replies MUST NOT increment
pending work, affect BOARD tasks/outbox/inbox, wake the PM, or introduce a confirmation/reminder/approval
lifecycle. No new project configuration key SHALL be required for this capability. The surfaces that carry this
duty wherever the tool is installed, and the correctness gate that holds them, are specified by
`key-replies#The key-conclusion duty is shipped on its instruction surfaces and held by the gate`.

#### Scenario: Normal answer survives every publication result
- **WHEN** a fixture Agent obtains saved, input-error, storage-error, busy or unconfirmed from its publication attempt
- **THEN** it still emits the same normal answer and any failure notice is separate from that answer
- **AND** no new pending item, outbox/inbox message, task or patrol wake is created by reply publication

### Requirement: Read operations do not create or repair storage
List, show and summary readers SHALL be observation-only: they MUST NOT create directories, write logs/caches/locks, repair index/body files, modify drafts/preferences or invoke patrol. A missing store SHALL remain absent after reads. Ordinary TUI navigation retains only its preexisting allowed page/preference persistence; reading replies adds no storage writes. On read errors, explicit diagnostics MUST distinguish empty from unavailable.

#### Scenario: Missing and damaged stores remain unchanged by observation
- **WHEN** CLI list/show, panel summary/list/detail and machine exits observe absent or damaged reply storage
- **THEN** before/after filesystem hashes and existence checks show no reader writes
- **AND** absence is reported as empty while damage/permission failure is reported as unavailable

### Requirement: The key-conclusion duty is shipped on its instruction surfaces and held by the gate

The duty to publish what is written for the user SHALL travel with the tool. The prompt template the PM is started
from SHALL carry a short section stating the duty: that the reader decides whether a reply is published (answers,
status and progress reports, conclusions, rulings, decisions requested from the user, delivery and verification
summaries), that replies written to the patrol, to another seat, to another project's PM or generated by a tool are
not published, the publication command whose body is the complete reply and arrives over `--stdin`, that the same
body is then sent in the conversation, and that a batch of user-facing replies MAY be one reply. The protocol
reference SHALL state the same duty as the PM's standing obligation in the same vocabulary, and the command table
SHALL present `reply` as the outlet for what is written for the user, distinguished from the internal `say` and
`notify` channels. The correctness gate SHALL hold these surfaces instead of relying on care: it MUST fail, naming
the surface that lost the duty, when the section is missing from the prompt template, when the duty statement is
missing from the protocol reference, or when the command table stops presenting `reply` as the user-facing outlet;
it MUST also fail, naming the surface and the criterion it lost, when any of the three surfaces stops carrying the
reader criterion beside the other anchors of the duty. That judgement SHALL be about presence and behaviour only:
the gate judges the criterion being carried and the example command working, and MUST NOT assert wording, tone,
sentence shape or the examples chosen for the criterion's two poles. The gate SHALL also judge the example command
printed as the way to publish: the command words and flags it shows MUST be accepted by the real CLI instead of
being refused as unknown, and that judgement MUST NOT be vacuous — an unknown flag added to the same probe MUST be
refused by the real parser. The gate MAY assert stable phrases and MUST NOT require byte-identical prose across
the surfaces. The shipped text SHALL keep its honest limit: no tool can verify that a live agent follows the duty,
that a given reply was written for the user, or which conclusions a PM published, and no surface SHALL promise that
a reply is marked automatically; the gate claims only that the duty is shipped and that its example command works.

#### Scenario: A surface that loses the duty names itself
- **WHEN** the duty section is removed from the prompt template, the duty statement is removed from the protocol reference, or the command table stops presenting the user-facing outlet
- **THEN** the correctness gate fails and names the surface that lost it
- **AND** restoring that surface makes the gate pass again

#### Scenario: A surface that loses the reader criterion names itself
- **WHEN** the reader criterion is removed from the prompt template, the protocol reference or the command table while the rest of the duty text stays in place
- **THEN** the correctness gate fails, naming that surface and the criterion it lost, in a message that can be read as a missing criterion rather than as a demand for particular wording
- **AND** restoring the criterion makes the gate pass again, so that assertion is not vacuous

#### Scenario: The printed example command is a command the CLI accepts
- **WHEN** the command words and flags of the printed publication example are run against the real CLI in a fixture project
- **THEN** the real parser accepts them instead of answering with its unknown-flag refusal
- **AND** the same probe with an unknown flag added is refused by the real parser, so a silently ignored flag cannot read as accepted

#### Scenario: What the gate cannot prove stays stated
- **WHEN** the shipped surfaces and the gate are read
- **THEN** they state that no tool verifies a live agent's obedience and that the gate judges only the shipped duty and the working example
- **AND** no gate output claims to have checked which conclusions a PM actually published

