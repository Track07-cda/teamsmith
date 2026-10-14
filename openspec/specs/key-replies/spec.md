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
Storage SHALL use only this project's resolved state directory and validated flat internal record names. Readers and publishers MUST reject symlink/nonregular index, lock or body artifacts, path traversal, foreign-root substitution and unsafe directory ancestry instead of following them. No read API SHALL accept an arbitrary file path. Publisher labels SHALL be displayed as declared, not verified. Markdown links/images and embedded commands MUST remain inert text; display MUST NOT fetch content, read local linked files, send terminal hyperlinks or execute shell syntax. Safe displays SHALL sanitize every external string, including corruption diagnostics.

#### Scenario: Traversal and nonregular sources are refused
- **WHEN** a selector contains traversal or the store/index/body is replaced by a symlink, FIFO, directory or foreign path
- **THEN** the operation rejects without reading the target or blocking on the FIFO
- **AND** outside-root files and processes remain untouched

#### Scenario: Declared label and hostile markdown remain data
- **WHEN** a reply claims another seat's label and contains shell syntax, local links, remote images and terminal controls
- **THEN** the label is visibly self-declared and the body is only safely rendered
- **AND** no shell, network fetch, local-link reader or delivery operation runs

### Requirement: Publication does not gate the normal answer or create work
The Agent workflow SHALL attempt explicit publication of a chosen key answer, then send the same answer normally whether publication succeeds, fails, is busy or remains unconfirmed. A saved receipt SHALL mean only project-local durable publication, not user delivery, approval, read status or a refreshed Pulse screen. Key replies MUST NOT increment pending work, affect BOARD tasks/outbox/inbox, wake the PM, or introduce a confirmation/reminder/approval lifecycle. No new project configuration key SHALL be required for this capability.

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

