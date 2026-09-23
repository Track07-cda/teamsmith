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
  on it (the shape of the real frame `docs/team/reports/P61-dev3/logs/15b-one-line-draft-frame.log`)
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
when `TEAM_MEETING_KNOCK=1` and the peer's `session` is registered via `team meeting peer <slug> <project>:<session>`.
Without the switch or the registration the message MUST still land in the shared transcript and the command MUST
say that the knock was skipped.

#### Scenario: Unregistered peer means no knock

- **GIVEN** `TEAM_MEETING_KNOCK=1` and a meeting with no registered peer session
- **WHEN** `team meeting say <slug> --intent info "…" --knock` runs
- **THEN** the transcript gains the message, the output says the peer session is unknown, and no tmux text is typed
  anywhere

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

### Requirement: A manual notification is attributed to its sender, not its recipient

`team notify <recipient> …` SHALL attribute the message to the sender it resolves from the caller's runtime
context and MUST NOT use the recipient as the sender. The resolution SHALL be, in this order:

- an explicit `--from <name>` claim, recorded verbatim; when it disagrees with the runtime directory the
  disagreement MUST be named on stderr;
- the runtime directory (`team`'s M40 identity): the project's main worktree resolves to `pm`, and a worktree
  under the main worktree's worktrees directory resolves to that worktree's own directory name, also when the
  process runs in one of its subdirectories;
- otherwise the sender is unresolved.

An inherited `TEAM_AGENT` MUST NOT override the runtime directory: when it disagrees, the runtime directory
wins and the ignored value MUST be named on stderr. An unresolved call MUST exit non-zero, MUST NOT write an
inbox line and MUST NOT enqueue a knock, and its output MUST name `--from` as the way to state the sender.

The resolved sender MUST be the name in the durable inbox line and in the knock text, in the
`[<tag>] agent:<name> · <text>` position the turn-end notification already uses, and the knock SHALL carry the
same name as the outbox entry's `from:` field, so the wake text and the delivery ledger name the sender too.
The recipient stays the inbox file (`docs/team/inbox/<recipient>.md`) and the knock target. The `[auto]` and
`[manual]` paths SHALL resolve the sender by this same rule, so one runtime context (working directory and
window) yields the same `agent:<name>` in both. Why a silent `pm` fallback is worse than a refusal:
`references/philosophy.md` (a false green is worse than nothing).

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

