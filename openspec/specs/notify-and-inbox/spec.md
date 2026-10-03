# notify-and-inbox Specification

## Purpose

The asynchronous channel between workers and the PM: a worker's turn end lands in the inbox and (optionally) knocks
on the PM's window, and the PM's one-line messages reach a running agent's TUI or fall back to the inbox. Why
delivery must be verifiable and never touch a shell prompt: `references/protocol.md` (safety model) and
`references/philosophy.md`.
## Requirements
### Requirement: A turn-end notification appends one inbox line and knocks once

The Pi notify extension SHALL append one line to `docs/team/inbox/<agent>.md` (timestamp, agent, summary) and knock
on the PM window; the same summary MUST be deduplicated inside `TEAM_NOTIFY_DEDUP_SEC` (default 20 s) so a
repeated settle does not spam the PM. The inbox is a local artifact and MUST be gitignored.

`<agent>` SHALL be the sender the extension resolves from its runtime context by the same rule
`notify-and-inbox#A manual notification is attributed to its sender, not its recipient` defines: a session
running in a worktree under the main worktree's worktrees directory is that worktree's name. The tmux window
name MUST NOT override the runtime directory, and a disagreement MUST be written to the extension's log.

The knock goes through the delivery guard: the knock text is typed only while the PM's input box is free, otherwise
it is held in the same outbox; the inbox line is written either way, and the knock text MUST NOT be appended to a
draft.

The notification SHALL name the revision it describes whenever the sender has one: the durable inbox line and the
knock payload SHALL carry the task identifier and a revision stamp (`task=<ID> tip=<12-hex>`), derived in the
sender's worktree at send time, with the summary text itself unchanged. The tip SHALL be the first twelve
characters of the full commit id, truncated by the tool itself; it MUST NOT be a Git abbreviation whose width
follows `core.abbrev` or the object count, so the same HEAD has one spelling in every sender. The identifier MUST
let a receiver decide staleness from its own ledger without checking out the sender's worktree: a notice whose task
is `done`/`closed` on the board, or whose `(task, tip)` pair names the same revision as the HEAD recorded in
`docs/team/reviews/<ID>.md`, is stale; any other notice names a revision the receiver has not judged and is not
stale. The recorded HEAD and the tip name the same revision when one is a prefix of the other: the tool writes nine
hex today and a hand-written record may carry the full id, while the twelve-wide wire form is what keeps the
comparison stable across Git settings. The receiver MAY compare the tip with the worktree's current tip when it has
access, but acting on a notice MUST NOT require that access.

The stamp SHALL only describe a task the sender can prove: the worktree's branch is `task/<ID>-…` and the ID exists
in the sender's `state/<agent>.env` (`task=<ID>`), on the board, or as a task brief. A seat branch (`agent/<seat>`),
a protected-branch or detached worktree, an unproven ID and a worktree-less manual `team notify` SHALL stamp
nothing — an identifier MUST NOT be invented from a branch name or a seat name.

#### Scenario: One summary, one line

- **WHEN** the notify extension runs once with the summary `T1.1 done: parser shipped`
- **THEN** `docs/team/inbox/dev.md` gains exactly one line containing that summary

#### Scenario: A repeated settle inside the dedup window is dropped

- **GIVEN** the same summary was notified less than `TEAM_NOTIFY_DEDUP_SEC` seconds ago
- **WHEN** the extension runs again with it
- **THEN** the inbox file does not gain a second line for that summary

#### Scenario: A dirty PM input box turns the knock into a queued entry

- **GIVEN** the PM window's input box holds a draft and `TEAM_NOTIFY_TMUX=1`
- **WHEN** the notify extension delivers a summary
- **THEN** the inbox line is written, the PM's draft is unchanged, and `state/outbox/` holds one entry for the PM
  window whose payload is the knock text

#### Scenario: The worktree, not the window, names the sender

- **GIVEN** a session whose working directory is `<main>/.worktrees/dev2` while its tmux window is named `dev`
- **WHEN** a turn settles
- **THEN** the line is appended to `docs/team/inbox/dev2.md` with `agent:dev2`, `docs/team/inbox/dev.md` is
  unchanged, and the extension's log names the ignored window

#### Scenario: The line and the knock name the revision

- **GIVEN** a worktree on branch `task/P9-parser` at tip `abc1234def56` whose session settles a turn
- **WHEN** the turn-end notification is delivered
- **THEN** the inbox line and the knock payload each contain `task=P9` and `tip=abc1234def56`, and the summary text
  after them is byte-identical to the summary the sender produced

#### Scenario: One HEAD, one spelling, whatever Git's abbreviation settings are

- **GIVEN** a worktree on `task/P9-parser` and the same HEAD notified once with `core.abbrev=7` and once with
  `core.abbrev=12`
- **WHEN** both notices are delivered
- **THEN** the two `tip=` values are byte-identical, twelve hex characters wide, and equal to the first twelve
  characters of the full commit id — the width does not follow the sender's Git configuration

#### Scenario: A notice for an already-judged revision is stale

- **GIVEN** `docs/team/reviews/P9.md` recording HEAD `abc1234def56`, an inbox line carrying
  `task=P9 tip=abc1234def56`, and another carrying `task=P9 tip=def5678abc12`
- **WHEN** each line's identifier is compared with the review record's HEAD and the board row
- **THEN** the first is stale (it names exactly the revision the review already covers) and the second is not stale,
  and the comparison reads only the inbox line and the review record — the recorded HEAD and the tip name the same
  revision whenever one is a prefix of the other, so a nine-wide record (what `team review` writes today) and a full
  commit id decide alike — no worktree checkout; the same verdict follows when the board row for `P9` is `done`

#### Scenario: An idle seat branch stamps nothing

- **GIVEN** a worktree on branch `agent/dev` with no `state/dev.env`, no task brief and no board row for `dev`
- **WHEN** the turn-end notification is delivered
- **THEN** the inbox line and the knock payload each contain no `task=` identifier, and the summary text is
  unchanged — a seat name is not a task

### Requirement: `--from-file` delivers the summary byte for byte

`team notify <agent> --from-file <path>` SHALL treat the file's content as data: shell metacharacters, quotes,
backticks and literal brace tokens MUST reach the inbox unchanged, newlines and carriage returns MUST be folded to
one line, and nothing in the content MUST be executed. A missing or blank file MUST fail the command and MUST NOT
write to the inbox.

#### Scenario: A hostile summary is delivered, not executed

- **GIVEN** a file containing `$(touch <sentinel>)` and `x"; touch <sentinel>; echo "`
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the inbox line contains that text byte for byte and `<sentinel>` does not exist

#### Scenario: A missing summary file fails loudly

- **WHEN** `team notify pm --from-file /nonexistent/summary.md` runs
- **THEN** it exits non-zero and the inbox file is not modified

#### Scenario: Multi-line summaries become one line

- **GIVEN** a summary file with `first line\nsecond line`
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the inbox line contains `first line second line` and no newline inside the line

### Requirement: Messages to a stopped agent fall back to the inbox

`team say <agent> "<one line>"` SHALL type into the agent's TUI only while the agent process is running; when the
agent is not running (empty prompt) the message MUST be appended to `docs/team/inbox/<agent>.md` instead, and the
command MUST say that this is what happened.

While the agent is running but its input box holds a draft the message MUST NOT be typed: it is held in
`state/outbox/` and delivered when the box clears, and the command MUST report it as queued rather than delivered
(`delivery-guard` specifies the guard, the queue and the drain). A draft is any text visible in the box, a
**single line** included: on Pi 0.87.0 the box's own status row moved below the box, so a one-line human draft
sits on the row the guard used to skip, and this command MUST judge it a draft — no key, held in
`state/outbox/`, reported `queued` — instead of typing over it (measured before the fix: the delivery path judged
that box `EMPTY`).

#### Scenario: Offline delivery is visible

- **GIVEN** the agent's window exists but its CLI process has exited
- **WHEN** `team say dev "check the failing test"` runs
- **THEN** the message appears in `docs/team/inbox/dev.md`, the output states that it went to the inbox, and no text
  is typed into the window's shell prompt

#### Scenario: A draft in the target's input box is not disturbed

- **GIVEN** `dev`'s window runs a TUI whose input box holds `half a sentence`
- **WHEN** `team say dev "check the failing test"` runs
- **THEN** the pane still shows exactly that draft, the message text does not appear in the pane, and `state/outbox/`
  holds exactly one entry for `dev` whose payload is that message

#### Scenario: A single-line draft queues the message

- **GIVEN** `dev`'s window runs Pi 0.87.0 whose input box holds the single line `half a sentence` with the cursor
  on it (the shape of the captured single-line-draft frame shipped at
  `skills/teamsmith/tests/frames/pi-0.87.0-one-line-draft.txt`)
- **WHEN** `team say dev "check the failing test"` runs
- **THEN** the pane still shows exactly that line, no key was sent, the output contains `queued`,
  `state/outbox/` holds exactly one entry for `dev` whose payload is that message, and the text does not appear in
  the pane

### Requirement: Cross-session targets are refused

The skill MUST NOT type into windows that do not belong to the team session. With `TEAM_GUARD_FOREIGN_TARGET=1` (the
default), `team say`/`team notify`/`team meeting knock` MUST refuse a foreign session target, MUST name the refused
target and the guard, and MUST explain how a human authorizes it.

#### Scenario: A foreign window is not touched

- **GIVEN** another tmux session `other` with a window `pm`
- **WHEN** `team say other:pm "hi"` (or a meeting knock aimed at it without registration) runs
- **THEN** the command exits non-zero, the refused target is printed, and the other session's pane content is
  unchanged

### Requirement: A meeting knock requires both sides' consent and a registered peer

A meeting knock (`team meeting say … --knock`, `team meeting knock <slug>`) SHALL only reach the peer's PM window
when `TEAM_MEETING_KNOCK=1` and the peer's `session` is registered via `team meeting peer <slug> <project>:<session>`;
the window SHALL be the peer project's own row in the meeting's per-participant window map (`meeting`: *Each
participant registers its own PM window*). The notice SHALL be submitted through the guarded automated delivery
path (`delivery-guard`: *An automated send never types into a non-empty input box*): a busy peer box queues the
notice instead of receiving it, and the command MUST report `queued` rather than `knocked`. Without the switch or the
registration the message MUST still land in the shared transcript and the command MUST say that the knock was
skipped. A knock that is enqueued or skipped MUST NOT change the shared area at that moment, and the transcript
stays the source of truth either way. When a queued notice is later delivered by the outbox drain, the same turn
SHALL be recorded in `knocks.log` at that moment (`meeting`: *A knock names the turn it announces*), so the
receiver's ledger names the turn whether the knock was typed immediately or drained later; a notice still sitting
in the queue MUST NOT appear in the ledger.

#### Scenario: Unregistered peer means no knock

- **GIVEN** `TEAM_MEETING_KNOCK=1` and a meeting with no registered peer session
- **WHEN** `team meeting say <slug> --intent info "…" --knock` runs
- **THEN** the transcript gains the message, the output says the peer session is unknown, and no tmux text is typed
  anywhere

#### Scenario: A busy peer box queues the knock

- **GIVEN** `TEAM_MEETING_KNOCK=1`, a registered peer session and a peer PM pane whose input box holds a draft
- **WHEN** `team meeting say <slug> --intent info "…" --knock` runs
- **THEN** the transcript holds the turn, no key was sent to the peer pane (the draft is unchanged), the sender's
  `state/outbox/` holds one entry whose payload is the meeting notice, the ledger names no turn yet, and the command
  reports `queued`

#### Scenario: A drained queued knock records the turn then

- **GIVEN** the queued notice of the busy-box case, with the peer's box now clear
- **WHEN** the sender runs `team outbox flush`
- **THEN** the notice is typed once into the registered `session:window`, the queue no longer holds the entry, and
  `knocks.log` gains exactly one line naming the turn the payload announces

#### Scenario: A free peer box knocks once

- **GIVEN** the same registration with an empty peer PM input box
- **WHEN** the same command runs
- **THEN** the notice is typed once into the registered `session:window` and the command reports it as knocked

### Requirement: Reading the inbox is explicit and reversible

`team inbox [<agent>] [--ack] [--all]` SHALL print unread lines and, with `--ack`, mark exactly those lines as read
so that `team digest` no longer counts them as pending; without `--ack` the unread count MUST be unchanged.

#### Scenario: Ack clears the pending count

- **GIVEN** one unread line in `docs/team/inbox/pm.md` and `team digest` reporting it as pending
- **WHEN** `team inbox --ack` runs and then `team digest` runs again
- **THEN** the line is no longer counted as pending work

### Requirement: A watcher registration failure is recorded with its cause

When the inbox-watch extension cannot register its `fs.watch` watcher for the session's target, it SHALL record the
failure in two places instead of the bare line it writes today:

- one `state/inbox-watch.log` line of the form
  `watch unavailable: errno=<E> watches=<used>/<max> poll_ms=<n> fallback=polling`, where `<E>` is the error code
  (`ENOSPC`, …), `<max>` is `/proc/sys/fs/inotify/max_user_watches`, `<used>` is the user's current inotify watch
  usage only when a complete same-UID scope can be established and `unknown` otherwise, and `<n>` is the effective
  poll interval; a failure
  forced by the fixture knob (`TEAM_INBOX_WATCH_FORCE_FAIL=<E>`) MUST additionally carry `forced=1`;
- a durable KEY=VALUE record `state/inbox-watch/<key>.degraded` carrying `version=1`, `target`, `key`,
  `reason=watch-unavailable`, `errno`, `watches=<used>/<max>`, `poll_ms`, `forced`, `since`, `pid`, `cwd` and
  `heartbeat`.

The record SHALL be believed only while its `pid` is alive and its `cwd` is inside the project (the same evidence
rule `.reg` and `.skip` already use) and MUST be removed when a later registration for the same target succeeds or
the session shuts down. The failure MUST NOT delete or replace the target's `.reg`: senders keep routing to the
inbox-watch spool and MUST NOT be pushed back to the input-box paste path by this degradation. Why a second record
next to `.reg`/`.skip`, and why the usage is best-effort: `references/troubleshooting.md`.

#### Scenario: A dry host leaves both traces

- **GIVEN** a session whose watcher registration fails with `ENOSPC` and whose user holds `65312` of `65536` watches
- **WHEN** `session_start` completes
- **THEN** `state/inbox-watch.log` holds one line containing `watch unavailable: errno=ENOSPC`, `watches=65312/65536`
  and `fallback=polling`
- **AND** `state/inbox-watch/<key>.degraded` exists and carries `reason=watch-unavailable`, `errno=ENOSPC`,
  `watches=65312/65536`, `poll_ms=`, a live `pid` and a `cwd` inside the project

#### Scenario: An uncountable quota still names the failure

- **GIVEN** the same failure while the usage cannot be counted
- **WHEN** the failure is recorded
- **THEN** both traces carry `watches=unknown/65536` and the `errno` is still named

#### Scenario: The forced knob is marked as forced

- **GIVEN** `TEAM_INBOX_WATCH_FORCE_FAIL=ENOSPC`
- **WHEN** a session starts
- **THEN** the ledger line and the record carry `errno=ENOSPC` and `forced=1`, and the record's `watches` field has
  the `<used>/<max>` shape

#### Scenario: Success clears the stale record and keeps the registration

- **GIVEN** a live `<key>.degraded` record left by a previous session for the same target
- **WHEN** a session registers its watcher successfully
- **THEN** that record no longer exists
- **AND** the target's `.reg` is present, so `team_inbox_watch_route` still resolves the target

### Requirement: Delivery continues on the polling fallback while watching is unavailable

While the watcher registration has failed, a spool line appended for the target MUST still produce exactly one wake
within three effective poll intervals of its append, the wake MUST keep the shape a live-watcher session sends (one
`team-inbox` message, `triggerTurn` and `deliverAs: followUp`, the inbox path and a truncated preview, no payload
dump), and the ledger MUST name the fallback mode on the failure line and the delivery on its wake line. The
fallback MUST NOT change the default poll interval (`TEAM_INBOX_WATCH_POLL_MS`, default 5000), MUST NOT reorder or
alter spool semantics (`notify-and-inbox` owns them unchanged), and MUST NOT be reported as a delivery failure.

#### Scenario: A forced failure still wakes within the poll cadence

- **GIVEN** a session started with `TEAM_INBOX_WATCH_FORCE_FAIL=ENOSPC` and `TEAM_INBOX_WATCH_POLL_MS=200`
- **WHEN** one spool line is appended for the target
- **THEN** within 600 ms the session has received exactly one wake naming that line
- **AND** the ledger holds the failure line with `fallback=polling` and a `wake n=1 …` line for it
- **AND** the target's `.reg` is present

#### Scenario: The fallback wake is not a new message shape

- **GIVEN** the same forced-failure session
- **WHEN** the wake arrives
- **THEN** its `customType` is `team-inbox`, `opts.triggerTurn` is true and `opts.deliverAs` is `followUp`, the body
  names `docs/team/inbox/<inbox>.md`, and the payload text appears only inside the truncated preview

### Requirement: The inbox-watch gate measures an unavailable watcher visibly and has a strict path

Before judging assertions that require a working `fs.watch`, the inbox-watch harness SHALL measure one registration
on a private temporary directory and print `TEAM-IW-PREREQ watch=ok` or a line naming the errno, quota observation
and strict state. An explicit `TEAM_INBOX_WATCH_FORCE_FAIL=<E>` fixture control SHALL exercise that same unavailable
premise without registering a real watch and SHALL mark the premise `forced=1`; otherwise the preflight MUST attempt
the real registration. The harness SHALL clear inherited `TEAM_*`, `TMUX` and `TMUX_PANE` identity, then restore only
its fixed fixture-control allowlist (`TEAM_INBOX_WATCH_FORCE_FAIL`, `TEAM_IW_REQUIRE_WATCH`, `TEAM_IW_ONLY` and
`TEAM_IW_KEEP`).

When the measured premise is unavailable, every explicitly marked watcher-dependent case SHALL print
`TEAM-IW-CASE SKIP <case> :: <reason>` and count as neither PASS nor FAIL; the harness and smoke section SHALL name
the skipped cases and measured reason, rather than silently passing. Cases that prove the polling fallback SHALL still
run. With `TEAM_IW_REQUIRE_WATCH=1`, the same watcher-dependent cases MUST instead print `FAIL` naming the premise
and the harness MUST exit non-zero. The strict switch MUST NOT be inferred from `CI`, and no assertion, threshold or
red line may be weakened or made unconditionally green.

#### Scenario: A forced unavailable premise skips only the watcher path

- **GIVEN** `TEAM_INBOX_WATCH_FORCE_FAIL=ENOSPC` and `TEAM_IW_ONLY=S2,S22,S23`
- **WHEN** the harness runs
- **THEN** its prerequisite line names `ENOSPC` and `forced=1`, S2 prints `SKIP`, and the polling-fallback S22/S23
  cases print `PASS`
- **AND** the harness exits 0 and the smoke section reports S2 as skipped with that premise

#### Scenario: Strict mode refuses the same unavailable premise

- **GIVEN** the same forced premise with `TEAM_IW_REQUIRE_WATCH=1` and `TEAM_IW_ONLY=S2`
- **WHEN** the harness runs
- **THEN** S2 prints `FAIL` naming the watch premise and the harness exits non-zero

#### Scenario: A real available watcher keeps its coverage

- **GIVEN** an environment where the private preflight watch registers and no force control
- **WHEN** the harness runs
- **THEN** the prerequisite line is `watch=ok` and each watcher-dependent case reports its normal PASS or FAIL
  verdict, never `SKIP`

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
wake on any path — startup baseline, ordinary read, bounded rescan or the delivery journal's recovery path. Stale
lines MUST be counted separately in the ledger (`stale=<n>`) and MUST NOT be counted by `total=` or by a `wake n=`.
Their readable copy is the durable inbox line the sender writes before the spool line (for `say`, `notify` and
`draft`) or the sender's own log (for the pointer-only `knock` and `nudge` lines), and the spool file keeps their
bytes. A line whose timestamp cannot be parsed MUST be delivered and counted (`unparsable=<n>`), never silently
dropped; the `unprovable` rule of
`notify-and-inbox#A wake is at most once: the delivery record is written before the send and survives a restart`
applies only to identities with a parsable timestamp.

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

#### Scenario: A recovered line that has gone stale is counted, not woken

- **GIVEN** a journal with a `read` record and no `intent` for a line whose timestamp is now older than the
  stale horizon
- **WHEN** a new session starts and runs its recovery pass
- **THEN** no wake is sent, the ledger counts it `stale=1` (not `recovery=`), and the line's durable inbox
  copy is untouched

### Requirement: The ledger separates new traffic from recovery

The watcher's ledger SHALL let an operator tell whether a wake came from new traffic or from a recovery, and
whether a line was dropped by a delivery rule rather than delivered: `total=` MUST grow only with lines that were
actually woken about, a `wake n=` MUST count only the lines that wake carries and MUST name the wake's `seq=`, and a
rescan MUST print its own breakdown (`lines=` lines read, `dup=` already delivered, `skipped=` over the replay
bound, `stale=` older than the horizon, `deliver=` woken). A repair (`offset clamp`) and a repeated regression
(`shrink repeat`) MUST each be their own ledger line, so a `spool shrink` repeating with `deliver=0` is visible as a
defect rather than as news.

The recovery and suppression paths MUST be named by their own counters, each counted once and counted apart from
`total=`: `replay suppressed n=<n> reason=<normal|rescan>` for a line a journal record already covers,
`inflight assumed n=<n>` for an intent whose outcome was never recorded, `recovery n=<n>` for a wake issued by the
recovery pass, `unprovable n=<n>` for an identity below the eviction floor, `deliver blocked` when the journal
could not be appended to, `torn tail` for an unparsable trailing record, and `baseline swallowed n=<n>` for complete
lines written before the session started that no session has read. A `wake` line MUST name the identities it
carries, so that a wake in the ledger can be matched to the durable inbox line and to the sender's
`state/outbox/delivered.log` record.

#### Scenario: A dedup-only rescan does not move total

- **GIVEN** the ledger's last `total=` is N and the spool is rewritten with only already-delivered lines
- **WHEN** the rescan runs
- **THEN** its line reads `deliver=0` with a non-zero `dup=`, a `replay suppressed n=` line is recorded, no `wake`
  line is added, and the last `total=` is still N

#### Scenario: A stale-only rescan does not move total

- **GIVEN** the spool is rewritten with only lines older than the stale horizon
- **WHEN** the rescan runs
- **THEN** its line reads `deliver=0` with `stale=` equal to the number of lines read, no `wake` line is added, and
  `total=` is unchanged

#### Scenario: A real delivery grows total by the wake's size

- **GIVEN** the ledger's last `total=` is N
- **WHEN** two fresh lines are appended and merge into one wake
- **THEN** the wake line reads `n=2` with its `seq=`, and the last `total=` is N+2

#### Scenario: An unknown outcome at startup is named instead of guessed

- **GIVEN** a journal holding an `intent` without `sent` and a spool whose bytes still contain that line
- **WHEN** a session starts
- **THEN** the ledger records exactly one `inflight assumed n=1` line, no `wake` line is added, and a later
  rewrite of those bytes adds no wake either

#### Scenario: Lines nobody read are counted, not woken

- **GIVEN** a spool with complete lines written while no session watched
- **WHEN** a session starts and takes its baseline
- **THEN** the ledger records `baseline swallowed n=<n>` — the complete lines at that moment that no journal
  record covers — sends no wake, and the `started … baseline=<n>` line still names the current spool end, so the
  existing baseline contract of `notify-and-inbox#The wake reader's offset advances by the bytes it read, never
  past the file end` is unchanged

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

### Requirement: A manual notification is attributed to its sender, not its recipient

`team notify <recipient> …` SHALL attribute the message to the sender it resolves from the caller's runtime
context and MUST NOT use the recipient as the sender. The resolution SHALL be, in this order:

- an explicit `--from <name>` claim, recorded verbatim; when it disagrees with the runtime directory the
  disagreement MUST be named on stderr;
- the runtime directory (`team`'s M40 identity): a worktree under the main worktree's worktrees directory
  resolves to that worktree's own directory name, also when the process runs in one of its subdirectories; the
  project's main worktree resolves to `pm` only while no **seat clue** is present — with a seat clue the call is
  refused instead of resolved (below);
- otherwise the sender is unresolved.

A **seat clue** is a name of this project's roster (`TEAM_AGENTS`): a name outside the roster is not a clue, and
a clue MUST NOT become the sender — it only vetoes the main worktree's `pm`. The clues are the window name of
the caller's own tmux pane, read with `tmux display-message -p -t "$TMUX_PANE" '#{window_name}'` and only when
that pane's session is this project's `TEAM_SESSION`, and an inherited `TEAM_AGENT`. A window name read without
the caller's own pane answers the attached client's current window — an echo, not evidence — and a window of
the same name in another session is not this project's seat. A clue that names `pm` agrees with the directory
and is not a conflict.

A call from the main worktree that carries a seat clue MUST exit non-zero, MUST NOT write an inbox line and MUST
NOT enqueue a knock: the ledger records the author, so the directory's `pm` claim MUST NOT be recorded and the
clue MUST NOT be adopted. Its output MUST name the directory's `pm`, each clue with its source and its name, and
both ways out — state the sender explicitly with `--from <name>`, or run the command from the caller's own
worktree under the main worktree's worktrees directory.

An inherited `TEAM_AGENT` MUST NOT override the runtime directory: when it disagrees, the runtime directory wins
and the ignored value MUST be named on stderr — except that a roster name in `TEAM_AGENT` makes the main
worktree's call the seat-clue refusal above, where that value is named as the clue instead. An unresolved call
MUST exit non-zero, MUST NOT write an inbox line and MUST NOT enqueue a knock, and its output MUST name
`--from` as the way to state the sender.

The resolved sender MUST be the name in the durable inbox line and in the knock text, in the
`[<tag>] agent:<name> · <text>` position the turn-end notification already uses, and the knock SHALL carry the
same name as the outbox entry's `from:` field, so the wake text and the delivery ledger name the sender too.
The recipient stays the inbox file (`docs/team/inbox/<recipient>.md`); the manual notification knock still targets the PM. The inbox declaration carried through the outbox and the wake full-text path MUST identify that same recipient file, not infer a file from the PM knock destination. The declaration MUST be made only after a successful durable write. A failed write MUST exit non-zero without a wake that asserts the file was written; it MUST NOT be converted into success by a warning. The `[auto]` and
`[manual]` paths SHALL resolve the sender by this same rule, so one runtime context (working directory and
window) yields the same `agent:<name>` in both. Why a silent `pm` fallback is worse than a refusal:
`references/philosophy.md` (a false green is worse than nothing).

#### Scenario: A manual worker inbox and PM wake name the same full-text file

- **GIVEN** a real Pi PM inbox watcher and recipient `dev` in the roster, with no `docs/team/inbox/pm.md`, and explicit sender `pm`
- **WHEN** `team notify dev --from pm "pointer truth probe"` runs
- **THEN** exactly one durable line is appended to `docs/team/inbox/dev.md` naming `agent:pm`, the PM receives one wake, the outbox inbox-written declaration and wake full-text path both name `dev`, the referenced file exists and contains the full text, and no `pm.md` is fabricated merely to conceal a pointer mismatch

#### Scenario: The same pointer survives a queued PM knock

- **GIVEN** recipient `dev`, sender `dev2`, a PM draft, and then a cleared PM box
- **WHEN** `team notify dev --from dev2 "queued pointer probe"` runs and later `team outbox flush` drains its knock
- **THEN** `dev.md` holds one durable line, the queued entry's inbox-written declaration names `dev`, the PM draft receives no key before clearing, and the eventual knock points to that same existing full-text file with sender `dev2`

#### Scenario: A failed durable write cannot authorize a wake

- **GIVEN** an unwritable recipient inbox directory and a live PM watcher
- **WHEN** `team notify dev --from pm "write refusal probe"` runs
- **THEN** it exits non-zero and names the failed path, emits no wake asserting that the inbox was written, and creates no inbox-written declaration for a nonexistent line

#### Scenario: An inbox-only notification retains its named recipient

- **GIVEN** `TEAM_NOTIFY_TMUX=0`, recipient `dev` and explicit sender `pm`
- **WHEN** `team notify dev --from pm "inbox only probe"` runs
- **THEN** it writes one line to `dev.md` naming `agent:pm`, attempts no knock and creates no outbox entry

#### Scenario: A worker's notification names the worker

- **GIVEN** a project whose seat `dev2` has the worktree `<main>/.worktrees/dev2`, run from that directory
  with `TEAM_AGENT` unset and no tmux
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the command exits 0, `docs/team/inbox/pm.md` gains exactly one line matching
  `[manual] agent:dev2 · `, and no added line is attributed to `pm`

#### Scenario: The PM's own notification still names `pm`

- **GIVEN** the same project, run from the main worktree
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the new line matches `[manual] agent:pm · `

#### Scenario: An inherited `TEAM_AGENT` does not become the sender

- **GIVEN** the `dev2` worktree context above with `TEAM_AGENT=pm` exported
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the new line names `agent:dev2`, and stderr names the ignored `TEAM_AGENT` value

#### Scenario: An unclassifiable runtime directory refuses instead of claiming `pm`

- **GIVEN** a worktree of the same project outside `<main>/.worktrees/` (for example
  `git worktree add <tmp>/elsewhere`), run there with no `--from`
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the command exits non-zero, `docs/team/inbox/pm.md` is byte-identical to its previous content, and
  the output names `--from`

#### Scenario: `--from` is recorded as an explicit claim

- **GIVEN** the same unclassifiable worktree with `--from dev3`
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the command exits 0 and the new line matches `[manual] agent:dev3 · `

#### Scenario: The knock and its queued entry carry the same sender

- **GIVEN** the `dev2` worktree context with `TEAM_NOTIFY_TMUX=1` and a PM input box holding a draft
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** `state/outbox/` holds one entry whose `from:` field is `dev2` and whose payload contains
  `[manual] agent:dev2 · `

#### Scenario: Both paths name the same sender for one runtime context

- **GIVEN** the `dev2` worktree context, used once for `team notify pm --from-file <file>` and once for the
  turn-end extension's settle
- **WHEN** both lines are read
- **THEN** each line's `agent:<name>` token is `dev2`

#### Scenario: A seat clue in the main worktree refuses instead of claiming `pm`

- **GIVEN** the project's main worktree, run from a pane whose own window is named `dev` in this project's
  session, with `TEAM_AGENT` unset and no `--from`
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the command exits non-zero, `docs/team/inbox/pm.md` is byte-identical to its previous content,
  `state/outbox/` gains no entry, and the output names `pm` as what the runtime directory claims, names `dev`
  as the window-name clue, and names both ways out: `--from`, and the caller's own worktree

#### Scenario: The window clue is the caller's own pane, not the client's current window

- **GIVEN** the project's main worktree, run from a pane whose own window is named `dev2` in this project's
  session, with the attached client's current window named `pm`
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the command exits non-zero, no line is added to `docs/team/inbox/pm.md`, and the output names `dev2`
  as the window-name clue (a window name read without the caller's own pane answers the attached client's
  current window — an echo, not evidence)

#### Scenario: An inherited roster name refuses the main worktree's call

- **GIVEN** the project's main worktree with no tmux and `TEAM_AGENT=dev` exported
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the command exits non-zero, `docs/team/inbox/pm.md` is byte-identical to its previous content,
  `state/outbox/` gains no entry, and the output names `TEAM_AGENT` and `dev` as the clue

#### Scenario: A name outside the roster is not a clue

- **GIVEN** the project's main worktree with `TEAM_AGENT=nosuch` exported and no tmux
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the command exits 0 and the new line matches `[manual] agent:pm · `
- **AND** the same holds when the caller's window is named `nosuch` in this project's session, so an unknown
  name neither refuses the call nor becomes the sender

#### Scenario: Another session's window of the same name is not a clue

- **GIVEN** the project's main worktree, run from a pane whose own window is named `dev` in a session that is
  not this project's `TEAM_SESSION`
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the command exits 0 and the new line matches `[manual] agent:pm · `

#### Scenario: An explicit `--from` is still honoured with a seat clue present

- **GIVEN** the project's main worktree, run from a pane whose own window is named `dev` in this project's
  session
- **WHEN** `team notify pm --from dev3 --from-file <file>` runs
- **THEN** the command exits 0, the new line matches `[manual] agent:dev3 · `, and stderr names the
  disagreement with the runtime directory's `pm`

#### Scenario: A seat worktree is not refused by a roster clue

- **GIVEN** the `dev2` worktree context with `TEAM_AGENT=dev3` exported
- **WHEN** `team notify pm --from-file <file>` runs
- **THEN** the command exits 0, the new line matches `[manual] agent:dev2 · `, and stderr names the ignored
  `TEAM_AGENT=dev3` (the clue list vetoes the main worktree's `pm` only)

### Requirement: A wake is at most once: the delivery record is written before the send and survives a restart

The inbox watcher SHALL keep, per target, an append-only delivery journal
(`state/inbox-watch/<key>.deliver`) and SHALL treat it — never process memory — as the durable authority for
what may still be woken about. The journal SHALL record each session start (`start`, carrying the baseline
offset, the observed size and the head fingerprint) and, for every line the reader decides to wake about, in
this order:

- before it calls the session's message API it MUST have appended a `read` record naming the line's identity
  and the wake material it will carry (kind, from, durable inbox, preview) together with the byte offset the
  read consumed to, the observed size and the head fingerprint, and then an `intent` record for the batch;
- after the call returns it MUST append `sent`, or `failed` when the call raised or the session API refused
  the message.

A wake MUST NOT be sent unless its `intent` record was appended successfully. When the journal cannot be
appended to, the reader MUST NOT send anything, MUST record `deliver blocked` in the ledger, and MUST leave
the lines unseen so that a later tick can pick them up. The persisted offsets are the audit trail of where a
session's reader stood; this requirement does not change the session's own baseline, which stays the current
spool end as `notify-and-inbox#The wake reader's offset advances by the bytes it read, never past the file end`
defines it.

After a restart a line's identity MUST be judged from the journal, in exactly these three states:

- `read` without `intent` (the send never started): the line MAY be woken about exactly once by a later
  session, out of the wake material the `read` record already holds, and the wake MUST be recorded as
  `recovery`;
- `intent` without `sent` and without `failed` (the outcome is unknown, and a torn or unparsable trailing
  record MUST be read as this state): the line MUST NOT be woken about again; the reader MUST record
  `inflight assumed n=<n>` once and MUST treat it as delivered from then on;
- `sent`: the line MUST NOT be woken about again, ever.

A `failed` record means the message never entered the session: that line MAY be retried, at most once per
read tick and never after it has passed the freshness horizon of the requirement
`notify-and-inbox#Only fresh lines wake the session; stale lines stay silent and countable`. An identity older
than the journal's eviction floor MUST NOT be woken about again — the journal can no longer prove it was not
delivered — and MUST be counted as `unprovable`.

#### Scenario: Killed after the read, before the intent — one recovery, never two

- **GIVEN** a fixture that kills the watcher process (SIGKILL, a separate process) after it appended the
  `read` record for a fresh line and before any `intent` record
- **WHEN** a new session starts for the same target
- **THEN** exactly one wake is sent for that line, the ledger records it as `recovery`, and a later rewrite
  of the same bytes produces no second wake

#### Scenario: Killed after the intent, before the send — never sent twice

- **GIVEN** the same fixture killed after the `intent` record for a fresh line, with the durable inbox line
  already written by the sender
- **WHEN** a new session starts
- **THEN** no wake is sent, the ledger records `inflight assumed n=1`, the line's durable inbox line is still
  readable, and any later re-read of the line stays silent

#### Scenario: A send that raises is visible and retryable, and a journal that cannot be written blocks the wake

- **GIVEN** a session whose message API raises for one batch, and separately a session whose journal
  directory is not writable
- **WHEN** the reader flushes a fresh line in each case
- **THEN** the first case records `wake failed`, does not mark the line delivered, and retries it on the next
  tick exactly once (`total=` does not move before the retry succeeds); the second case sends nothing,
  records `deliver blocked`, and delivers the line exactly once when the journal becomes writable again

#### Scenario: A rewrite of journaled lines is suppressed and named

- **GIVEN** a spool whose earlier lines all have `sent` records in the journal, truncated and rewritten with
  the same bytes
- **WHEN** the bounded rescan runs
- **THEN** no wake is sent, the ledger records `replay suppressed n=<n> reason=rescan`, and the last `total=`
  is unchanged

#### Scenario: An identity below the eviction floor is not woken again

- **GIVEN** a journal that has been compacted, its `floor=` older than a line that comes back through an
  external rewrite
- **WHEN** the rescan reads that line
- **THEN** no wake is sent and the ledger counts it as `unprovable`

### Requirement: A wake names its source line so a recipient can prove what it is

Every wake SHALL carry, in its text: a monotonically increasing wake sequence number and the absolute send
time of the wake; and for each line it lists, that line's own absolute timestamp and its identity. When the
line carries a sender record id, the identity shown MUST be that id; otherwise it MUST be the same string the
delivery journal uses for that line. The sender SHALL write that id into the spool line (the id of its own
durable record for the message, i.e. the outbox entry name recorded in `state/outbox/delivered.log`).

Timestamps MUST be absolute (ISO-8601 UTC) and MUST NOT be relative ages, and the preview MUST stay bounded,
folded to one line per listed line, and MUST NOT carry the payload dump. The wake text MUST name the delivery
journal file the listed identities were recorded in, so the recipient can resolve an identity without guessing
which state file holds it. The purpose is that a recipient can
decide from durable files alone whether two wake texts are two lines or one line twice: two byte-identical
payloads from two distinct lines MUST be distinguishable by identity and source time, and a wake text that
repeats an identity is a replay the recipient can name.

#### Scenario: Identical text, two lines — distinguishable, and neither replayed

- **GIVEN** two spool lines whose payload text is byte-identical (the pulse's `未读通知 N · 待复验 M` nudge
  is written every `TEAM_PULSE_NUDGE_GAP` with unchanged counts, so this is the production shape) and whose
  ids and timestamps differ
- **WHEN** both are woken about and then one of them is rewritten into the spool
- **THEN** the two wake texts differ by the identity and the source timestamp they print, and the rewrite
  produces no wake at all

#### Scenario: The identity cross-references the sender's own record

- **GIVEN** a line delivered by the real CLI on the pi route
- **WHEN** the wake text's id is looked up in `state/outbox/delivered.log`
- **THEN** exactly one record for that message carries that id, and the spool line for it names the durable
  inbox line the recipient can read

### Requirement: The delivery journal is the only dedup memory, and it is bounded and auditable

The journal SHALL be human-auditable: one record per line, each ISO-stamped, carrying its record kind
(`start`, `read`, `intent`, `sent`, `failed`, `floor`), the line identity and the fields above. A torn or
unparsable trailing record MUST be treated as an unknown outcome (never as a licence to re-send) and MUST be
visible in the ledger as `torn tail`.

The journal MUST be bounded: past `TEAM_INBOX_WATCH_JOURNAL_MAX` records (default 1024) compaction SHALL
rewrite it under the bound and SHALL record its eviction floor (`floor=<oldest retained identity>`). A
compaction MUST NOT be able to resurrect a delivery, and the records it keeps MUST keep their state.

`state/inbox-watch/<key>.seen` SHALL be retired as the dedup memory. On the first start of a target it MAY be
imported once, additively, as already-delivered identities so that an upgrade does not replay; from then on
the journal MUST be the only memory, and deleting, emptying or corrupting `<key>.seen` MUST NOT change a
single delivery decision.

#### Scenario: An upgrade imports `.seen` once, and then `.seen` stops mattering

- **GIVEN** a target whose state holds a `<key>.seen` written by the previous code and no journal
- **WHEN** a session starts and an already-delivered line is rewritten into the spool
- **THEN** no wake is sent, the journal records the import, and after `<key>.seen` is deleted the same
  rewrite is still silent

#### Scenario: A torn tail is an unknown outcome, not evidence of "not sent"

- **GIVEN** a journal whose last record is cut mid-line (a crash while appending the `intent`)
- **WHEN** a new session starts and the line comes back through a rewrite
- **THEN** no wake is sent, the ledger names the `torn tail`, and the line is treated as delivered from then
  on

#### Scenario: Compaction stays under the bound and keeps every retained delivery

- **GIVEN** a journal that has grown past `TEAM_INBOX_WATCH_JOURNAL_MAX`
- **WHEN** compaction runs
- **THEN** the file is at or under the bound, one `floor=` line names the oldest retained identity, and every
  retained identity is still suppressed on a rewrite

### Requirement: A seat-death knock carries the seat, the cause and the raw evidence line, and never invents a cause

A seat-death knock SHALL be enqueued through the delivery guard as a `knock` entry — queued while the PM
window's input box is busy, never typed over a draft — with `--from pulse`, and it SHALL name the seat,
the classified cause, the source the cause was read from, and the raw evidence line, plus the command
that shows the scene (`team status <ID>`). For an `unknown` death the knock SHALL state that the cause
could not be determined and MUST NOT name any of the other categories; a knock for a `normal` exit MUST
NOT exist. The knock's dedup key SHALL be the death's identity
(`watchdog#A cause belongs to the current launch of a seat, never to a previous one`), so the delivery
guard's at-most-once delivery and the patrol's record agree on what "the same death" is.

#### Scenario: A quota knock carries the raw frame

- **GIVEN** the quota corpse fixture and an unreported `quota` death
- **WHEN** the patrol tick delivers the death knock
- **THEN** the delivered payload names the seat, `quota`, the source and the raw
  `Error: 403 permission_error: reached your weekly (7-day) usage limit` line, and it names
  `team status <ID>` as the scene command

#### Scenario: An unknown knock does not pretend

- **GIVEN** a death whose evidence is unreadable or matches no shape
- **WHEN** its knock is delivered
- **THEN** the payload carries `unknown` and a "cause could not be determined" wording, and it contains
  none of `quota`, `balance`, `rate_limit`, `window` or `auth` as a claimed category

#### Scenario: A busy PM input box queues the knock instead of gluing it

- **GIVEN** the PM window's input box holding a draft and an unreported abnormal death
- **WHEN** the patrol tick runs
- **THEN** the PM window still shows exactly that draft, the knock is one entry in the delivery queue
  (`team outbox list`), no text was typed into the PM window, and `state/deaths.log` holds the one record
  line for that death

