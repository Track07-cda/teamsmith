## ADDED Requirements

### Requirement: The wake reader's offset advances by the bytes it read, never past the file end

`team-inbox-watch`'s spool reader SHALL advance its offset by the byte length of the complete lines it actually
read — the byte position of the last `\n` in the buffer it read, bounded by `readSync`'s return value — and MUST NOT
derive that advance from a decoded string, from the requested buffer length, or through any character-set round
trip. After every read the offset MUST be less than or equal to the file's size at read time. A line whose bytes are
not valid UTF-8 MUST still be delivered (its preview may render U+FFFD), bytes belonging to an incomplete trailing
line MUST NOT be counted as consumed, and a read that starts inside a line MUST NOT deliver the fragment: the bytes
up to the next `\n` are skipped and the skip is recorded in the ledger.

#### Scenario: A byte-clipped preview does not push the offset past the end

- **GIVEN** a spool whose last line carries a preview cut in the middle of a multi-byte character (the file is not
  valid UTF-8) and which ends with `\n`
- **WHEN** the watcher starts and records its baseline
- **THEN** `state/inbox-watch.log`'s `started … baseline=<n>` names exactly the file's byte size and the ledger
  gains no `spool shrink` line

#### Scenario: The next line after a byte-clipped line arrives intact

- **GIVEN** the watcher has delivered the byte-clipped line
- **WHEN** a new complete line is appended
- **THEN** exactly one wake names that line, its preview is the appended text byte-complete (no leading fragment of
  another line), and the wake's `total=` grows by one

#### Scenario: An idle spool produces no ledger movement

- **GIVEN** a spool that has been read to its end
- **WHEN** three poll ticks pass with no writer
- **THEN** the ledger gains no `spool shrink`, `rescan` or `wake` line

### Requirement: A size regression is repaired or rescanned only with evidence, and recovery converges

When the spool is smaller than the watcher's offset, the watcher SHALL compare the file's head (a bounded prefix)
with the head recorded when the offset was last established and SHALL distinguish a repair from a rewrite. An
unchanged head with a regression no larger than `TEAM_INBOX_WATCH_CLAMP_BYTES` (default 64 bytes) MUST be repaired
by setting the offset to the current size, recorded as one `offset clamp` ledger line, and MUST NOT trigger a
rescan or a wake. A changed head, or a larger regression, MUST be handled as a rewrite by the existing bounded,
deduplicated rescan. After any repair or rescan the offset MUST be no larger than the current size, and an
identical (size, head) observation MUST NOT trigger a second rescan: it is recorded as `shrink repeat` and clamped.

#### Scenario: A one-byte regression with an unchanged head is repaired, not rescanned

- **GIVEN** a spool whose delivered lines are in the dedup memory
- **WHEN** its last byte is removed and the head is unchanged
- **THEN** the ledger gains exactly one `offset clamp` line, gains no `spool shrink`, `rescan` or `wake` line, and
  a line appended afterwards wakes exactly once

#### Scenario: A rewrite with a changed head is recovered once and converges

- **GIVEN** the spool has been replaced by a shorter file whose head differs (a genuine truncate and rewrite)
- **WHEN** the next tick runs, and then the tick after it
- **THEN** the first tick records one `spool shrink` line and one
  `rescan lines=… dup=… skipped=… deliver=…` line, the second tick records neither, and already-delivered lines
  produce no wake

#### Scenario: The same (size, head) state is never rescanned twice

- **GIVEN** a regression that was already handled for a given (size, head)
- **WHEN** the watcher observes the same (size, head) again
- **THEN** it records a `shrink repeat` line, records no `rescan` line, sends no wake, and its offset is still no
  larger than the file size

#### Scenario: A read that starts inside a line never delivers a fragment

- **GIVEN** the offset was clamped into the middle of a line
- **WHEN** the watcher reads the remaining bytes of that line
- **THEN** the fragment produces no wake, the ledger records the skipped bytes, and the next complete line is
  delivered intact

### Requirement: Only fresh lines wake the session; stale lines stay silent and countable

A spool line whose timestamp is older than `TEAM_INBOX_WATCH_STALE_SEC` (default 900 seconds) SHALL NOT produce a
wake on any path — startup baseline, ordinary read or rescan. Stale lines MUST be counted separately in the ledger
(`stale=<n>`) and MUST NOT be counted by `total=` or by a `wake n=`. Their readable copy is the durable inbox line
the sender writes before the spool line (for `say`, `notify` and `draft`) or the sender's own log (for the
pointer-only `knock` and `nudge` lines), and the spool file keeps their bytes. A line whose timestamp cannot be
parsed MUST be delivered and counted (`unparsable=<n>`), never silently dropped.

#### Scenario: An old unseen line is counted, not woken about

- **GIVEN** a spool line older than the stale horizon that is not in the dedup memory, and the durable inbox line it
  names
- **WHEN** the watcher rescans the spool
- **THEN** no wake message is sent, the ledger's rescan line records `stale=1` with `deliver=0`, the last `total=`
  is unchanged, and the durable inbox line is still present

#### Scenario: A fresh line after a stale one still wakes once

- **GIVEN** the stale line above was skipped
- **WHEN** a line with a current timestamp is appended
- **THEN** exactly one wake names the fresh line, no stale line appears in that wake, and `total=` grows by one

#### Scenario: An unparsable timestamp is delivered, not swallowed

- **GIVEN** a spool line whose first field is not a number
- **WHEN** the watcher reads it
- **THEN** the line is delivered and the ledger records `unparsable=1`

### Requirement: The ledger separates new traffic from recovery

The watcher's ledger SHALL let an operator tell whether a wake came from new traffic or from a recovery: `total=`
MUST grow only with lines that were actually woken about, a `wake n=` MUST count only the lines that wake carries,
and a rescan MUST print its own breakdown (`lines=` lines read, `dup=` already delivered, `skipped=` over the replay
bound, `stale=` older than the horizon, `deliver=` woken). A repair (`offset clamp`) and a repeated regression
(`shrink repeat`) MUST each be their own ledger line, so a `spool shrink` repeating with `deliver=0` is visible as a
defect rather than as news.

#### Scenario: A dedup-only rescan does not move total

- **GIVEN** the ledger's last `total=` is N and the spool is rewritten with only already-delivered lines
- **WHEN** the rescan runs
- **THEN** its line reads `deliver=0` with a non-zero `dup=`, no `wake` line is added, and the last `total=` is
  still N

#### Scenario: A stale-only rescan does not move total

- **GIVEN** the spool is rewritten with only lines older than the stale horizon
- **WHEN** the rescan runs
- **THEN** its line reads `deliver=0` with `stale=` equal to the number of lines read, no `wake` line is added, and
  `total=` is unchanged

#### Scenario: A real delivery grows total by the wake's size

- **GIVEN** the ledger's last `total=` is N
- **WHEN** two fresh lines are appended and merge into one wake
- **THEN** the wake line reads `n=2` and the last `total=` is N+2

### Requirement: The sender clips the spool preview on a character boundary, under `LC_ALL=C` as well

`team_inbox_watch_deliver` SHALL bound the preview it appends to `state/inbox-watch/<key>.wake` without splitting a
multi-byte UTF-8 sequence: the clip applies to whole characters, so the line it writes is valid UTF-8 whenever the
payload is, and the clip MUST NOT introduce a U+FFFD replacement character. This MUST hold under `LC_ALL=C`, where
`cut -c`, `head -c` and bash's `${var:0:n}` are byte-oriented. Dropping the bytes of an incomplete trailing sequence
is the required repair; the durable inbox line keeps the full payload and is not affected by the clip.

#### Scenario: A multi-byte character lands exactly on the byte bound

- **GIVEN** a payload whose 700th byte falls inside a multi-byte character
- **WHEN** the sender writes the spool line for it
- **THEN** the appended line is valid UTF-8 (`iconv -f UTF-8 -t UTF-8` accepts it), it contains no U+FFFD, and its
  preview is the longest whole-character prefix no longer than the byte bound

#### Scenario: The durable inbox line still carries the full payload

- **GIVEN** the same payload
- **WHEN** the sender writes the durable inbox line and then the spool line
- **THEN** the inbox line contains the full payload and only the spool preview is clipped
