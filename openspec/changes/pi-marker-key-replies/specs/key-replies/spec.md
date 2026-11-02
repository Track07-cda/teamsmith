## MODIFIED Requirements

### Requirement: Key replies are explicitly published from bounded stdin

The system SHALL provide `team reply post --from <label> --title <title> --stdin` for manual publication, backfill and recovery. Its body MUST come only from stdin, never inferred from chats, task reports or historical Pi messages. The only automatic capture exception SHALL be an explicitly marked live assistant message of the directed PM extension's current activity, or recovery of that same source's durably eligible, never-attempted operation under `key-replies#A marked source earns one automatic attempt only after final settlement`. The extension MUST pass the complete sanitized body through the existing stdin writer into the same reply store; no historical import command or session scan to infer missing publication SHALL be introduced. The publisher label MUST remain an explicit, self-declared flat identifier of 1–48 ASCII letters, digits, dots, underscores or hyphens, not an authenticated identity or a claim about the currently running seat. The title MUST be nonblank, single-line UTF-8 of at most 160 Unicode codepoints, without terminal controls or bidi/invisible formatting controls. The body MUST be nonempty valid UTF-8, without NUL, and at most 131072 bytes. Other body controls MUST remain in the original stored bytes but not in safe displays. Invalid input MUST be refused without publishing; oversized stdin MUST be detected using a bounded read rather than unbounded buffering. No overwrite, edit, deletion, body-content deduplication or automatic import command SHALL be introduced. Source-attempt serialization MUST NOT deduplicate different entries or explicit manual posts.

#### Scenario: Explicit body rather than chat inference
- **WHEN** an Agent submits a title, its declared label and stdin body containing markdown, CJK text and a trailing newline
- **THEN** one new reply preserves that exact body and the explicit metadata
- **AND** no session/history/report reader or notification sender is invoked by the manual publication

#### Scenario: Input boundary is enforced before publication
- **WHEN** input has a missing or unsafe label, blank/multiline/overlong/controlled title, empty body, invalid UTF-8, NUL, or 131073 body bytes
- **THEN** the command exits 2 with a bounded diagnostic and no published reply
- **AND** a valid 131072-byte body is accepted without truncation

#### Scenario: Repeated submissions are distinct
- **WHEN** identical valid input is explicitly posted twice
- **THEN** two distinct replies are published rather than silently deduplicated or overwritten

#### Scenario: Directed capture is the only automatic exception
- **WHEN** an eligible marked PM source is published and an ordinary unmarked answer or an arbitrary old session entry is observed
- **THEN** only the eligible source is passed to the existing writer, whose raw body equals the full answer minus recognized control-line ranges
- **AND** the old entry and unmarked answer cause no publication; Pulse still reads only the existing numbered store

### Requirement: Publication does not gate the normal answer or create work

Publishing is a standing PM duty that travels with the tool, and its selection criterion SHALL remain the reader: a reply written for the user MUST be explicitly marked for publication in the normal answer, including answers, status or progress, conclusions, rulings, decision requests and delivery or verification summaries regardless of length or whether they read like process. A reply whose reader cannot be settled SHALL be treated as written for the user. Coordination with the patrol, another seat or another project's PM stays in its own channel; a tool receipt is not a reply. The complete substance the user needs to read, not a summary or work play-by-play, SHALL be the published body; a batch of user-facing replies MAY be one reply. The default workflow SHALL be a marked normal answer followed by extension publication, not a temporary file/heredoc, a manual post followed by repeating its body, or an automatic fallback to that old workflow. Unmarked normal answers MUST NOT be published by inference. `team reply post` SHALL remain available for explicit human-directed backfill or recovery.

The normal answer MUST remain available with recognized complete control lines removed whether publication succeeds, fails, is busy, remains unconfirmed or cannot obtain journal eligibility. Failure notices MUST be separate from the answer; writer failure MUST NOT withhold, replace or request a model retry of that answer. A saved receipt SHALL mean only project-local durable publication, not user delivery, approval, read status or a refreshed Pulse screen. Key replies MUST NOT increment pending work, affect BOARD tasks/outbox/inbox, wake the PM, or introduce a confirmation/reminder/approval lifecycle. No new project configuration key SHALL be required. The shipped instruction duty and its honest verification limit SHALL be held by `key-replies#The key-conclusion duty is shipped on its instruction surfaces and held by the gate`.

#### Scenario: Normal answer survives every publication result
- **WHEN** a fixture Agent obtains saved, input-error, storage-error, busy or unconfirmed from its publication attempt
- **THEN** it still emits the same normal answer minus recognized control lines and any failure notice is separate from that answer
- **AND** no new pending item, outbox/inbox message, task or patrol wake is created by reply publication

#### Scenario: An unmarked answer is not silently imported
- **WHEN** the PM emits an unmarked answer or the capture path is unavailable
- **THEN** the answer remains a normal conversation reply and no inferred publication or automatic default CLI backfill runs
- **AND** a later explicit manual post remains possible without turning that post into a source recovery attempt

### Requirement: The key-conclusion duty is shipped on its instruction surfaces and held by the gate

The PM prompt template, protocol reference and skill command table SHALL ship the same reader-based duty described by `key-replies#Publication does not gate the normal answer or create work`: write a normal complete answer and mark its final control line; the directed PM extension publishes its sanitized body; `team reply post` is manual/backfill only. Each surface SHALL distinguish replies written for the user from patrol/seat/other-PM coordination and tool receipts, allow a batch of user-facing replies as one, and retain failure non-blocking and saved-is-not-delivered meanings. The three surfaces MUST change together with an executable capture path; instructions MUST NOT promise capture before injection exists. Literal marker examples SHALL be protected as code or otherwise explicitly quoted. The correctness gate SHALL replace its old default post-then-repeat guide judgement with marker-example behaviour against the product parser and capture/writer path, retaining real CLI checks for the manual example. Removing a duty or reader criterion SHALL fail naming the affected surface and missing criterion; the judgement MUST NOT demand byte-identical prose, tone, sentence shape or particular examples. An unknown flag added to a manual example MUST still be refused by the real CLI. A broken marker example MUST fail rather than vacuously pass. The gate MUST NOT claim that a live model obeys the duty, that a particular reply's reader is known, that all conclusions were marked or that controlled-model tests measure real-model compliance. No automatic inference of which replies deserve a marker SHALL be promised.

#### Scenario: A surface that loses the duty names itself
- **WHEN** the duty section is removed from the prompt template, the duty statement is removed from the protocol reference, or the command table stops presenting the user-facing outlet
- **THEN** the correctness gate fails and names the surface that lost it
- **AND** restoring that surface makes the gate pass again

#### Scenario: A surface that loses the reader criterion names itself
- **WHEN** the reader criterion is removed from the prompt template, the protocol reference or command table while the other anchors remain
- **THEN** the gate fails naming the surface and missing criterion rather than demanding particular wording
- **AND** restoring the criterion makes the gate pass

#### Scenario: The printed example command is a command the CLI accepts
- **WHEN** the printed manual/backfill example is run against the real CLI in a fixture project
- **THEN** the parser accepts its command words and flags and the exact body can be retrieved
- **AND** the same probe with an unknown flag is refused; the example is not described as the daily default

#### Scenario: The marked example exercises publication rather than prose alone
- **WHEN** the shipped default marker example is processed through the product parser and eligible fixture capture path
- **THEN** the real writer saves the full sanitized answer once, and an invalid marker mutation makes that assertion fail
- **AND** neither matching text in a document alone nor a fake receipt counts as that evidence

#### Scenario: What the gate cannot prove stays stated
- **WHEN** the shipped surfaces and gate are read
- **THEN** they state that no tool verifies live-agent obedience and the gate judges shipped duty and working examples only
- **AND** no output claims to have checked which conclusions a PM actually published

## ADDED Requirements

### Requirement: Complete control lines are removed without rewriting answer content

The directed extension SHALL recognize only case-sensitive, column-zero standalone lines `[[team-reply]]` or `[[team-reply:标题]]`, with no trailing spaces. The explicit title is the raw substring after the colon and before the final `]]`, without an escape syntax or an internal `]]`; an empty explicit title is invalid, not omitted. LF and CRLF SHALL both be supported. A publishable marker MUST be the last nonblank logical line, followed only by blank lines containing spaces/tabs. All complete recognized control lines outside protected code SHALL be removed at every assistant terminal state independently of eligibility, title validity or journal success. No complete lines means no mutation; multiple lines mean ambiguous, one nonfinal line means misplaced, and either case means no publication. Whitespace-only sanitized bodies and invalid explicit titles mean no publication. Malformed/incomplete prefixes and protected examples MUST remain literal rather than being guess-deleted.

Protected regions SHALL include fences opened after at most three spaces with at least three matching backticks or tildes, closed only by the same type with at least the opener length and a whitespace-only suffix; a backtick fence's opening info string cannot contain a backtick. Unclosed fences protect through end of message. Outside fences, only successfully paired maximal backtick runs of exactly equal length SHALL protect an inline span, including across logical lines and text blocks. An unmatched opener MUST remain literal and MUST NOT hide the rest of the answer; other opener lengths MUST still be considered. Outside a span, backslash escapes MUST be consumed before forming maximal opener runs: odd backslash parity escapes only the first following tick, so an unescaped suffix can open a span; even parity does not escape that tick. An unescaped maximal run MUST NOT be split. Inside an open span backslashes are ordinary content and an exact-length closer still closes. This SHALL be a narrow lexical contract, not a promise to infer arbitrary Markdown list/quote continuation or an author's intent. Explicit quote/list prefixes, indentation, escapes and fenced/paired-inline examples are not column-zero control lines; an otherwise bare reserved line remains an opt-in even when introduced as an example in prose.

Removal MUST delete only original control-line character ranges and their own LF/CRLF, retaining preceding line endings, trailing blank lines, empty text blocks, original block order, all non-text content and metadata. Adjacent text blocks SHALL be scanned in order without inserted separators and removal projected onto original offsets without merging blocks or splitting Unicode codepoints. The published UTF-8 bytes MUST equal concatenated original text bytes with only those ranges removed. An omitted title SHALL derive from the first nonblank sanitized text line, ignoring a leading Magic Context `§<decimal integer>§` and adjacent spaces/tabs in the title view only, continuing to the next line when that leaves no text. That view SHALL trim whitespace, remove unsafe title controls, take at most 160 complete Unicode codepoints and fall back to `关键回复` when needed; the body MUST NOT be changed by title derivation. An explicit title SHALL instead pass existing writer validation unchanged. Existing body limits MUST fail explicitly, never truncate, split or retry automatically.

Streamed control text MAY be temporarily visible with no fixed latency bound; raw stream events and terminal bytes already emitted are not retroactively erased. Finalized Pi transcript, final print stdout and subsequent model history SHALL contain no recognized complete control lines, as SHALL stored/Pulse current and historical bodies. Literal protected examples and incomplete aborted prefixes are not control metadata and remain visible.

#### Scenario: Exact grammar and invalid placement do not guess intent
- **WHEN** ordinary, malformed, indented, quoted, escaped, multiple, misplaced, empty-title and empty-body cases are parsed
- **THEN** only complete unprotected control lines are removed, and only one valid final line with a nonblank valid body/title can become a candidate
- **AND** a bare reserved final line introduced by prose still counts, while a code-protected example does not

#### Scenario: An escaped first tick leaves a suffix opener
- **GIVEN** the following literal input, whose first line has one backslash and two backticks and whose last line has one backtick:

````text
示例：\``
[[team-reply]]
`
````

- **WHEN** the product parser processes it alone, then with `答复。\n[[team-reply]]` appended (the latter `\n` denotes an actual LF)
- **THEN** the first case is entirely unchanged with no intent or writer; the second preserves the example and removes only the real final control line, leaving exactly one candidate
- **AND** treating the whole physical two-tick run as escaped makes this test fail

#### Scenario: Pairing obeys parity maximal runs and span closers
- **WHEN** odd/even backslash prefixes, backslashes before an in-span exact closer, differing run lengths, an unmatched opener followed by a valid pair, and cross-line/cross-block spans are parsed
- **THEN** only matched exact-length spans protect marker-looking lines; an unmatched opener does not protect to end, and an unescaped run is never split
- **AND** ignoring escapes entirely, ignoring the suffix of an escaped first tick, or treating backslashes as closer escapes each fails its respective control

#### Scenario: Offset deletion preserves CRLF and original blocks
- **WHEN** text blocks `甲\r\n[[team-` and `reply]]\r\n\r\n` are parsed alongside empty blocks, Unicode and non-text metadata
- **THEN** the corresponding blocks become `甲\r\n` and `\r\n`, with other fields unchanged, and the full published body is `甲\r\n\r\n`
- **AND** cross-block code examples retain their original bytes and no text blocks are merged or reordered

#### Scenario: Cleanup does not depend on successful publication
- **WHEN** a complete marker occurs in tool-use, length, error, aborted, invalid-title or journal-failure terminal messages
- **THEN** final messages omit its control range without publishing those ineligible sources or altering non-control content
- **AND** aborting at `[[team-` retains that literal incomplete prefix without publication

#### Scenario: Numbering is skipped only for a derived title
- **WHEN** a marked answer starts with a line containing only a Magic Context number and then a Unicode answer line, or carries an explicit unsafe title
- **THEN** the omitted title derives from the next nonblank line with no number and a codepoint-safe bound while the body retains every original number and whitespace
- **AND** the unsafe explicit title is rejected without being silently replaced by a derived title

### Requirement: A marked source earns one automatic attempt only after final settlement

Only the latest assistant message of an activity from prompt-start through final settlement SHALL be eligible. Each later assistant start, including ordinary, tool-use, error or aborted messages, MUST supersede earlier candidates; queued work, retry and before-settle continuation MUST NOT turn intermediate successes into publications. A marked message MUST first stage sanitized intent, then bind to its actual persisted message entry, then receive durable final-settlement eligibility for that same current activity. Its final state MUST be successful stop with no tool call, with one valid final control line and valid body/title; settlement MUST not be aborted. Missing/mismatched event identity or binding MUST NOT be inferred from the current leaf, time, body hash, earlier candidate or historical session scan. Source, activity start and settlement witness MUST remain on the current branch in valid ancestral order, with a null start leaf allowed for the first activity.

The stable source tuple SHALL be `(canonical project root, canonical state directory, Pi session UUID, canonical session file, messageEntryId)`. Each tuple SHALL have one operational record and at most one automatic writer attempt. Distinct entries with identical bodies SHALL remain distinct. Eligible and attempting transitions MUST be durable under shared source serialization; attempting MUST be persisted before spawning the existing writer. Duplicate events, duplicate loaded copies, concurrent processes, reload and later branch growth MUST NOT grant a second attempt. Automatic recovery SHALL consider only explicitly eligible, never-attempted records whose complete source and settlement witness still belong to the current session/branch; unbound/pending records, missing/corrupt journals, other branches/sessions and copied fork entries MUST NOT be promoted or reconstructed. Recovery SHALL not run old operations while a new activity is in progress.

Saved results MUST retain the real receipt number; unconfirmed results MUST retain only their candidate number and never be relabelled saved. Explicit input rejection, lock contention or proven process-not-started MAY be recorded as not-written, but still MUST NOT automatically retry. Missing/malformed/inconsistent receipts, signals, unknown process outcomes, journal-result failures and otherwise uncertain writes MUST NOT auto-republish, even if a page or body matches or does not match. An attempting record with a live owner SHALL not be stolen; a dead/unknown owner SHALL not re-earn execution rights. Old saved records beyond the newest page MUST remain attempt barriers. Local diagnostics SHALL identify the source and evidence path without body leakage; inability to write diagnostics MUST NOT block final cleanup or the normal answer. The operation record SHALL not be a second user-facing store, page, numbering or pending-work lifecycle. This is at-most-one automatic attempt per known source, not exactly-once delivery or guaranteed eventual saving.

#### Scenario: The final assistant supersedes earlier marked success
- **WHEN** an earlier marked stop is followed in the same activity by queued ordinary text, a tool round, error, length or abort, or by another final marked stop
- **THEN** only the last eligible marked stop can publish; otherwise none does, with no backward search for a marked success
- **AND** two separate successful marked activities may each publish once

#### Scenario: Crashes before durable settlement do not imply success
- **WHEN** execution stops around intent staging, Pi append, entry binding or the final eligibility transaction
- **THEN** only an actually durable eligible record can later recover; unbound/pending or failed eligibility writes cannot publish
- **AND** first-activity null start leaf is accepted, while mismatched entry, missing binding and changed branch/session are not guessed

#### Scenario: Attempt rights survive duplicate events and old pages
- **WHEN** the same source receives repeated end/turn/settled events, duplicate loaders, concurrent recovery or reload after more than 50 newer posts
- **THEN** at most one writer process is attempted for it regardless of newest-page contents
- **AND** two distinct eligible entries with equal full bodies/title each receive their own attempt and stable published number

#### Scenario: Uncertain outcomes are not automatic retries
- **WHEN** the real writer is busy, returns unconfirmed, is killed around commit/receipt, emits a missing or corrupt receipt, or a saved/unconfirmed result cannot be journaled
- **THEN** no automatic repeat occurs after reload/restart; saved retains no, unconfirmed retains candidate_no, and ambiguous cases remain uncertain without a saved claim
- **AND** an explicit later manual post is a new submission, not ownership reconciliation by content

#### Scenario: Branch and session changes do not import records
- **WHEN** the PM switches session, navigates to another branch, forks, reloads before eligibility, or has no persistent session file
- **THEN** incomplete activity associations are invalidated and only independently proven eligible sources of the exact current tuple and branch can recover
- **AND** historical/copy/hash inference never creates a new eligible record
