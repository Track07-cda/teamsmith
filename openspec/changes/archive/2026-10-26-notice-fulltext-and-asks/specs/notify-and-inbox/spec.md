# notice-fulltext-and-asks · notify-and-inbox delta

本 change **不改任何既有 requirement 的一个字**，只新增两条。原因写在 `design.md` §1 之前的那一段判断里：
同一条标题（`A turn-end notification appends one inbox line and knocks once`）正被未归档的
`turn-notice-in-pm-inbox` 以 MODIFIED 占用，第二份 pending MODIFIED 会让有效文本取决于归档顺序，两种顺序都会丢文本。
契约是并集，所以新增条目既不覆盖任何人，也不受归档顺序影响；wake 的 *truncated preview* 语义因此从构造上未被碰过。

## ADDED Requirements

### Requirement: The record keeps the whole message, and only a preview is truncated

A turn-end notification's record SHALL keep the message it quotes in full: the line appended to
`docs/team/inbox/<agent>.md` and the per-event record appended to `state/notify.log` SHALL carry the whole flattened
last assistant message, and no display budget may bound them. A preview budget (`TEAM_INBOX_MAX_CHARS` for the knock
payload, `TEAM_INBOX_WATCH_PREVIEW` for the wake's per-line preview, the spool preview's byte bound) SHALL apply only
to the copies that are typed or shown, never to a file. Flattening is not truncation: every run of whitespace
becomes one space because the inbox is a line-oriented file, and no character is dropped by it.

One safety bound SHALL exist for pathological output and SHALL be a constant rather than a configuration key: a
message larger than 65536 bytes (UTF-8, measured after flattening) SHALL be kept up to that bound on a character
boundary, and its line's field block (before ` :: `) SHALL carry
`truncated=hard-limit:<kept>/<total>B`, with `<kept>` the bytes kept and `<total>` the bytes the message had. That
marker MUST NOT carry a `full=` locator, because the rest of that message exists nowhere on disk — the absence of
`full=` is how a reader tells "the original is gone" from "the original is elsewhere". A cut on the record path
that is not marked MUST NOT happen.

Every copy that is truncated SHALL say so in itself, in one shape:
`truncated=preview:<shown>/<total>B`, followed by `full=<path>[:<line>]` naming the file that holds the untruncated
text and, when the writer knows it, the 1-based line number in it. `<shown>` and `<total>` are UTF-8 byte counts of
the copy and of the text it was cut from, so a byte count taken with `wc -c` reads the same numbers. Where the marker
sits is part of the shape: in a payload or a rendered line it follows the text it annotates, and in a spool line it
SHALL be an additional tab-separated field, so that the spool's preview field keeps the shape
`notify-and-inbox#The sender clips the spool preview on a character boundary, under LC_ALL=C as well` requires — the
longest whole-character prefix no longer than the byte bound, with the marker outside the bound. The marker SHALL be
written by the code that performs the cut — the knock payload's preview by the notify extension, the spool preview
by `team_inbox_watch_deliver`, the wake's per-line preview by the watcher — so that no copy is silently short, and a
marker MUST be appended by every layer that cuts, not inherited from a layer above it. A marker without `full=` while
the untruncated text is still readable on disk is a defect, not a variant.

The knock payload SHALL name the record it previews: it SHALL carry `full=docs/team/inbox/<agent>.md:<line>`, where
`<line>` is the line number the inbox writer reports for the line it appended or extended — the same critical section
that holds the write counts it, so the number cannot disagree with the file. `truncated=` and `full=` SHALL appear
only when the copy was actually cut, so that a message within the preview budget produces the payload and the record
line this capability's other rules already produce, byte for byte.

Nothing in this requirement changes the wake's bounded-preview semantics: the wake still carries a one-line pointer
per listed line, never a payload dump, and the spool preview is still cut on a character boundary under `LC_ALL=C`
(`notify-and-inbox#The sender clips the spool preview on a character boundary, under LC_ALL=C as well`); this
requirement adds the marker and lengthens no preview.

For a merged run the record line's text is the last event's message (the field block describes the event at `last=`),
while the earlier events' whole messages stay in the detail file; the detail file is therefore the locator for the
events a merge summarised, and `team inbox <agent> --detail` reads them.

#### Scenario: A long delivery is stored whole and shown short

- **GIVEN** a settled turn whose last message is 3000 characters long and a `TEAM_INBOX_MAX_CHARS` of 150
- **WHEN** the turn-end notification is delivered
- **THEN** the line in `docs/team/inbox/<agent>.md` and the raw record in `state/notify.log` each contain all 3000
  characters, the typed knock payload contains the first 150 characters followed by `…`, and the payload carries
  `truncated=preview:` with byte counts and `full=` naming the agent's inbox file and the line number it is on

#### Scenario: The locator resolves to the whole message

- **GIVEN** the knock payload of the previous case
- **WHEN** the reader takes the `full=` path and line number from it and prints that line
- **THEN** the printed line is the record line and the text after its ` :: ` is the whole 3000-character message

#### Scenario: Nothing is cut, so nothing is added

- **GIVEN** a settled turn whose last message fits the preview budget
- **WHEN** its record line and its knock payload are read
- **THEN** neither carries a `truncated=` field, and both are byte-identical to what the rules of
  `notify-and-inbox#A turn-end notification appends one inbox line and knocks once` produce for that turn

#### Scenario: Pathological output is bounded and named, not silently cut

- **GIVEN** a last message of 200000 bytes
- **WHEN** its record line is written
- **THEN** the message text it carries is exactly 65536 bytes ending on a character boundary, its field block carries
  `truncated=hard-limit:65536/200000B`, no `full=` locator is present, and the event's `state/notify.log` record
  carries the same cut and the same marker

#### Scenario: The spool preview names its own cut and stays a bounded prefix

- **GIVEN** a knock payload longer than the spool preview's byte bound whose cut falls inside a multi-byte character
- **WHEN** `team_inbox_watch_deliver` appends the spool line
- **THEN** the line's preview field is valid UTF-8, is the longest whole-character prefix no longer than the byte
  bound, and carries no marker of its own
- **AND** the line's marker field carries `truncated=preview:` with the byte counts of the payload and the prefix, and
  `full=` names the durable inbox line that still holds the payload whole
- **AND** the character-boundary repair of
  `notify-and-inbox#The sender clips the spool preview on a character boundary, under LC_ALL=C as well` is unchanged —
  no U+FFFD, no partial sequence

#### Scenario: The wake's own clip is marked where it happens

- **GIVEN** a spool preview longer than `TEAM_INBOX_WATCH_PREVIEW` delivered in one wake
- **WHEN** the wake text is read
- **THEN** that line's preview ends with `truncated=preview:` naming the byte counts of the preview it was given and
  `full=` naming the inbox file the line's durable field names, and the line still prints its source time and identity

### Requirement: A completion whose tail asks for a decision is countable

A turn-end notification SHALL carry a counted field `asks=<n>` (n ≥ 1) in its record line's field block, and the PM's
pointer line for it (the pointer line `notify-and-inbox#A turn-end notification appends one inbox line and knocks
once` defines) SHALL carry the same field, when the tail of the message it quotes contains one of the closed markers
below. The judged region SHALL be the last 400 characters of the flattened message, counted over the whole
message even when the copy was hard-limited, and a marker SHALL count only when all of its characters fall inside
that region. The field MUST be absent — not `asks=0` — when no marker is present, so that a message which asks nothing
keeps the line byte-identical to what the rules without this requirement produce.

The markers are a closed set. They SHALL NOT be extended by a punctuation test: a question mark is not a marker, and
a message made of questions that contains none of these phrases MUST be counted as asking nothing. Markers SHALL be
matched longest-first, leftmost and non-overlapping, with ASCII case folded, so `请你确认` counts once and does not
also count its substring `请确认`, while `Please Confirm` counts. The set is:

- `请裁决`, `待你裁决`, `等你裁决`, `请你裁决`, `请裁定`, `请定夺`, `请示下`
- `请你确认`, `需要你确认`, `待你确认`, `等你确认`, `请确认一下`, `请确认`
- `请你决定`, `需要你决定`, `需要你定`, `待你拍板`, `等你拍板`, `请你拍板`
- `是否需要我`, `要我继续`, `要不要我`
- `please confirm`, `please decide`, `awaiting your decision`, `your call`, `need your approval`, `needs your call`,
  `do you want me to`

`asks=` is an event-scoped field: a merged run's line carries the value of the event at `last=`, like `branch=` and
`tip=`, and the merge key is unchanged. It SHALL be copied onto the PM's pointer line, because the pointer line is
what the PM reads.

`team digest` SHALL print one line in its pending-notice section naming how many unread pointer lines carry an `asks=`
value and which notices they are — sender, task and count, at most three named and the rest summarised — and MUST
print nothing when that count is zero. The count SHALL follow the section's unread rule (`team inbox --ack` on the
PM's inbox clears it) and SHALL count one pointer line per run, never one per event. This line is a display surface:
it MUST NOT add itself to the reasons the patrol wakes the PM with, because the notice it counts is already unread
traffic in that reason set.

#### Scenario: A delivery that ends in a decision request is countable

- **GIVEN** a settled turn whose message ends with `两点请裁决：① … ② …`
- **WHEN** its record line and the PM's pointer line are read
- **THEN** both carry `asks=1`
- **AND** `team digest` names one unread notice that asks the PM something, with the sender, the task and the count

#### Scenario: Two distinct markers count twice and one overlap counts once

- **GIVEN** a tail containing `请你确认一下，另外等你拍板` in one case and `请你确认，请确认` in another
- **WHEN** each message is judged
- **THEN** the first line carries `asks=2` (`请你确认` and `等你拍板`) and the second also carries `asks=2`
  (`请你确认` and the remaining `请确认`), so `请你确认` is not counted as two markers

#### Scenario: A question mark is not an ask

- **GIVEN** a tail reading `这样行吗？那这样呢？还有别的问题吗？` with none of the closed markers
- **WHEN** its record line is written
- **THEN** the line carries no `asks=` field and `team digest` names no asking notice

#### Scenario: A marker outside the tail window does not count

- **GIVEN** a message whose only marker ends 400 characters or more before its end, followed by a plain report
- **WHEN** its record line is written
- **THEN** the line carries no `asks=` field

#### Scenario: A bounded message's marker is still counted

- **GIVEN** a message larger than the hard bound whose only marker sits in its last 400 characters
- **WHEN** its record line is written
- **THEN** the line carries `asks=<n>` for that marker although the marker's own text was outside the kept 65536 bytes

#### Scenario: Reading the inbox clears the count

- **GIVEN** one unread pointer line carrying `asks=1` that `team digest` counts
- **WHEN** `team inbox --ack` runs and then `team digest` runs again
- **THEN** the asking line is no longer printed

#### Scenario: A merged run is one asking notice

- **GIVEN** a run of three events whose last one asked a question, merged into one pointer line carrying `×3` and
  `asks=1`
- **WHEN** `team digest` reads it
- **THEN** its asking count is one, not three

#### Scenario: Asking does not change what wakes the PM

- **GIVEN** two projects whose PM inboxes hold the same unread pointer lines, one with `asks=` present
- **WHEN** the patrol computes its pending reasons in each
- **THEN** the two reason sets are identical — the asking line is a display surface only
