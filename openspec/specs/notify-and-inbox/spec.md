# notify-and-inbox Specification

## Purpose

The asynchronous channel between workers and the PM: a worker's turn end lands in the inbox and (optionally) knocks
on the PM's window, and the PM's one-line messages reach a running agent's TUI or fall back to the inbox. Why
delivery must be verifiable and never touch a shell prompt: `references/protocol.md` (safety model) and
`references/philosophy.md`.
## Requirements
### Requirement: A turn-end notification appends one inbox line and knocks once

The Pi notify extension SHALL record a turn-end notification as one line in `docs/team/inbox/<agent>.md`
(timestamp, agent, summary) and knock on the PM window, except where the merge rules below fold it into the
run already at the end of that file; the same summary MUST be deduplicated inside `TEAM_NOTIFY_DEDUP_SEC` (default 20 s) so a
repeated settle does not spam the PM. The inbox is a local artifact and MUST be gitignored.

The settle SHALL also write one **pointer line** for that notice into the PM's inbox
(`docs/team/inbox/pm.md`) whenever the resolved sender is not the PM, so that a notice does not exist only in a file
no reader of the notice opens. The pointer line SHALL name the sender, the task identifier and the state class, the
record it points at (`see=docs/team/inbox/<agent>.md`) and the outcome of the knock
(`knock=enqueued` or `knock=skipped:<class>`); `enqueued` means the notice was handed to the delivery guard and MUST
NOT be read as delivered, and a skipped outcome names exactly one class of the closed set
`notify-and-inbox#A notice whose knock was skipped is recorded with its reason and named by digest` defines. It
SHALL be derived from the line the sender records, so that both carry the same merge key, and it MUST NOT carry the
last-message summary, the `branch=`/`uncommitted=`/`unpushed=` fields or the `⚠ 未提交` prefix — it is a pointer,
and the PM's line count is the PM's pending count. The record line itself, its merge, its
detail record and its knock payload MUST stay byte-identical to what the rules of this requirement produce: the
pointer is a second, independent write. A pointer line MUST NOT append to the detail file, so a run's `×N` still
equals its record count. `knock=` is a run-scoped field like `×N` and `first=`: extending a run SHALL keep the value
the run's first event wrote, and the extending event MUST NOT rewrite it. A failed pointer write MUST NOT suppress,
delay or duplicate the knock, MUST NOT be reported as if the PM's inbox held the line, and SHALL leave a
`pointer=failed` record in the notice ledger
(`notify-and-inbox#A notice whose knock was skipped is recorded with its reason and named by digest`).

Consecutive turn-end notifications from one seat that describe the same run SHALL be summarised in one line instead
of appending a new one. Two notifications describe the same run when their merge keys are equal: the key is the tuple
(seat, task, state class, `awaiting` set), where the seat is the resolved sender, the task is the line's `<ID>` token
(the string the `task=` stamp carries when the stamp exists, and a value of its own when the line has no task
identifier), the state class is the line's tag (`delivered` for `[auto]`, `suspended` for `[auto·suspended]`,
`interrupted` for `[auto·interrupted]`), and the `awaiting` set is the ids of the `awaiting=` field, deduplicated and
compared without regard to their order; an absent `awaiting=` field and an empty one are different values. A
notification whose key differs from the run already at the end of the seat's inbox SHALL start a new line, and a run
SHALL only be extended while its line is the last line of that file — any other line appended in between ends it.
The line the first notification of a run writes SHALL be byte-identical to the line today's rules produce for a
single event; once a run summarises more than one event, its line SHALL carry the count and the run's window
(`×N first=<ISO> last=<ISO>`) in the field block before ` :: `, and its `branch=`, `uncommitted=`, `unpushed=` and
`tip=` fields SHALL be the values of the last event — the `last=` timestamp names that event — never an averaged,
maximum or otherwise synthesised value. The inbox line is the run's summary; the raw events are the detail file
`notify-and-inbox#A turn-end notification's raw events stay in a bounded detail file` defines.

`<agent>` SHALL be the sender the extension resolves from its runtime context by the same rule
`notify-and-inbox#A manual notification is attributed to its sender, not its recipient` defines: a session
running in a worktree under the main worktree's worktrees directory is that worktree's name. The tmux window
name MUST NOT override the runtime directory, and a disagreement MUST be written to the extension's log.

The knock goes through the delivery guard: the knock text is typed only while the PM's input box is free, otherwise
it is held in the same outbox; the inbox line is written either way, and the knock text MUST NOT be appended to a
draft.

A knock SHALL announce an **actionable** line, not a settle: exactly one knock is enqueued when a settle writes a
new line whose tag is `[auto]` or `[auto·interrupted]`, and a settle that extends an existing run enqueues nothing
and types nothing — count churn inside a run stays visible in the line and its raw records but MUST NOT wake the PM.
A state-class change is a key change and therefore always starts a new line, but a line tagged `[auto·suspended]`
SHALL NOT enqueue anything: a suspended turn is a designed state (the seat started long-running jobs and ended its
turn correctly to wait for their wake-up), so it is recorded — inbox line, raw record, panel and digest — without
waking the PM, and the failure surface for a seat that dies while suspended (a job that never completes, a lost
completion wake-up) belongs to the patrol's unfinished-task check rather than to this notice. The knock's dedup
identity SHALL be the identity of the line it announces (seat, merge key, first event time), so two distinct lines
with byte-identical text are not conflated and a re-notified run cannot knock a second time. A settle whose durable
inbox write failed MUST NOT enqueue a knock that asserts the line exists — the same rule
`notify-and-inbox#A manual notification is attributed to its sender, not its recipient`
states for a failed manual write.

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

A receiver SHALL judge a merged line by that same rule applied to its last event: the line's `task=`/`tip=` name the
revision at `last=`, so a merged line whose last tip is the revision a review record already covers (or whose board
row is `done`/`closed`) is stale, and any other merged line is not. The fields of a merged line describe the event at
`last=`, and a receiver MUST NOT read them as a claim about the seat's current state; the earlier events of the run
are read from the detail file.

The stamp SHALL only describe a task the sender can prove: the worktree's branch is `task/<ID>-…` and the ID exists
in the sender's `state/<agent>.env` (`task=<ID>`), on the board, or as a task brief. A seat branch (`agent/<seat>`),
a protected-branch or detached worktree, an unproven ID and a worktree-less manual `team notify` SHALL stamp
nothing — an identifier MUST NOT be invented from a branch name or a seat name.

A completed turn that ends while background jobs its own session started are still running SHALL be told apart
from both a delivery and an interruption: the inbox line SHALL carry the tag
`[auto·suspended]` and an `awaiting=<id>[,<id>…]` field naming the running jobs, and the dirty-tree warning flag
SHALL be omitted for a suspension (the `uncommitted=<n>` field stays) — a suspension is not a delivery claim and
MUST NOT wear the alarm shape of one, and (per the scope addition of 2026-10-15) **a suspension SHALL NOT knock**:
the tag and its fields reach the inbox and the detail record, while the wake-up path carries nothing for it. The running set SHALL be read from the same `state/bg/` directory the lane
writes its records to, located by the lane's own rule — an explicit `TEAM_STATE_DIR` first, else the lane's
project-root rule (a session whose working tree carries the project's config resolves to that working tree, one
without it to the main worktree) — and the notify extension MUST NOT substitute its own project root for
that directory. Only a job the settling session itself started SHALL count: a record belongs to the
session when its recorded `cwd` — the working directory the job was started in, which is the owning
seat's working tree — resolves, through symlinks and trailing slashes, to the session's own working
tree or working directory. A record with a missing, relative or unresolvable `cwd`, or one resolving
to another session's directory, SHALL NOT make the turn suspended — the ownership check fails closed
rather than guessing. A record SHALL count as running only while
its recorded `(pid, start-time)` identity verifies live, the same identity rule
`boundary#\`team bg\` stops a job by the pid it recorded, and prints what it signalled` applies: a dead pid, a
reused pid and an unreadable or malformed record MUST NOT make a turn "suspended", and a failure in the check
itself MUST fall back to the non-suspended shapes. An interrupted turn keeps the `[auto·interrupted]` tag and
SHALL carry the same `awaiting=` field while jobs are running, so a real interruption and its still-running jobs
stay visible as what they are; a completed turn with nothing running is byte-identical to what it is today.

A merged line is one line to every line-counting reader: `team digest`'s pending count and the panel's inbox block
count it once, and `team inbox --ack` marks that one line read — a later event extending an already-read line does
not make it unread again. `[manual]`, `[draft]` and `[nudge]` notifications and the pulse's own inbox lines are not
turn-end events: they never merge, never enter the detail file, and their wake behaviour is unchanged.

One notice is counted once across the two files. A turn-end line whose `agent:` token names the inbox file's own seat
is that seat's **record** and MUST NOT be counted as unread traffic of that file, while the pointer line in the PM's
inbox is counted — so one settle adds exactly one to the pending count, never two, and `team_inbox_new`'s predicate
is the single implementation the digest's pending count, the panel's inbox block and `team inbox`'s unread listing
share. An upgrade SHALL NOT synthesise pointer lines for record copies already on disk: a pointer written after the
fact would invent a delivery and a knock outcome nobody observed.

When the raw event could not be appended to the detail file, the settle SHALL NOT extend an existing run — a count
no record explains would hide the event — and SHALL append a line whose field block carries `detail=unavailable`,
with the failure named in the extension's log. A line carrying that marker is not a run's anchor either: a following
same-key event SHALL start a new line, so the missing record stays visible and the count never absorbs it.

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

#### Scenario: A suspended turn is tagged, not alarmed

- **GIVEN** a worktree session whose state directory holds one job record whose `(pid, start-time)` identity
  verifies live, and a completed turn ending with uncommitted files
- **WHEN** the turn-end notification is delivered
- **THEN** the inbox line carries `[auto·suspended]` and an `awaiting=<id>` field naming that job, the
  `uncommitted=<n>` field is present, the dirty-tree warning flag does not appear, and `state/outbox/` gains no entry
  for the PM window — the turn is recorded and the PM is not woken
- **AND** the same holds when the suspended line extends a run (`×N` grows and its records land in the detail file):
  a run that never became actionable wakes nobody, and the wake-up still happens for the delivered or interrupted
  line the seat writes after it

#### Scenario: A dead or reused pid does not suspend

- **GIVEN** a worktree session whose state directory holds one job record whose recorded pid is dead, and a second
  record whose pid is alive but whose start-time fingerprint does not match (a reused pid)
- **WHEN** a completed turn ends
- **THEN** the notification carries `[auto]` (and the dirty-tree warning flag when the tree is dirty), with no
  `awaiting=` field — the same shape as without any records

#### Scenario: An interruption with running jobs names them

- **GIVEN** a worktree session with one live-verified job record and a turn that ends without completing
- **WHEN** the turn-end notification is delivered
- **THEN** the line keeps the `[auto·interrupted]` tag and carries the `awaiting=<id>` field

#### Scenario: A worktree carrying its own config uses its own lane records

- **GIVEN** the worktree-with-config shape (a linked worktree that carries `.pi/team/config.sh`), whose lane
  state directory holds one live-verified record, while the main worktree's state directory holds a different
  live-verified decoy record
- **WHEN** a completed turn ends
- **THEN** the notification is suspended on the worktree's own record and does not name the decoy — and the
  fixture's red side (an implementation resolving the main worktree's state directory, the way the notify
  extension's own project root does) fails this scenario

#### Scenario: Seats, one job each

- **GIVEN** three linked worktrees whose seat sessions share one lane state directory, each holding one
  live-verified record whose `cwd` names its own worktree
- **WHEN** each session ends a completed turn
- **THEN** each line carries `awaiting=` with only the job its own session started — the other seats' jobs
  are neither named nor counted, so each seat's turn reports exactly its own parked work

#### Scenario: An idle seat is not suspended by another seat's job

- **GIVEN** a live-verified record whose `cwd` names the `dev` worktree while two other seat sessions
  (`dev2` and `dev3`) share the same lane state directory and hold no record of their own
- **WHEN** each of the two idle sessions ends a completed turn
- **THEN** each notification keeps the `[auto]` shape with no `awaiting=` field

#### Scenario: A record with no owning directory does not suspend

- **GIVEN** live-verified records whose `cwd` is absent, relative, or a path that no longer resolves, in a
  session whose own worktree is known
- **WHEN** a completed turn ends
- **THEN** the notification keeps the `[auto]` shape with no `awaiting=` field — the ownership check fails
  closed instead of guessing

#### Scenario: An explicit state directory is the lane's directory

- **GIVEN** a session whose `TEAM_STATE_DIR` points at a fixture directory holding one live-verified record,
  while the notify extension's own project root holds a different live-verified decoy record
- **WHEN** a completed turn ends
- **THEN** the notification is suspended on the record in `TEAM_STATE_DIR` and does not name the decoy — the
  directory the lane wrote is the only source for this verdict, and the fixture's red side (an implementation
  reading a directory of its own choosing) fails this scenario

#### Scenario: A run of same-key notifications is one line with its window

- **GIVEN** three turn-end notifications from the `dev` worktree, all on branch `task/P9-parser`, each ending a
  completed turn with nothing running and each carrying a different summary text
- **WHEN** the three settles run
- **THEN** `docs/team/inbox/dev.md` holds exactly one line for them, its field block carries `×3` with `first=` and
  `last=` naming the first and the third event's timestamps, and `state/notify.log` holds three records — one per
  event — while a settle that always appended would leave three lines and be caught by this scenario

#### Scenario: The merged line carries the last event's values

- **GIVEN** three same-run notifications whose `uncommitted` counts are 4, 2 and 0, whose `branch=` is the same, and
  whose `task=P9 tip=` stamps name three different revisions
- **WHEN** the three settles run
- **THEN** the merged line's `uncommitted=` is 0 and its `tip=` is the third event's tip, and `last=` names the
  third event — an implementation taking a maximum, an average or the first event's value is caught here

#### Scenario: A state-class change starts a new line

- **GIVEN** a suspended notification for a run, then a delivered notification for the same task with no jobs running,
  then a suspended notification carrying the same `awaiting` set as the first
- **WHEN** the three settles run
- **THEN** the inbox holds three lines — the two suspensions are not merged across the delivered line — and exactly
  one knock entry was added for the PM window: the delivered line's, since neither suspended line knocks

#### Scenario: A different task or awaiting set starts a new line

- **GIVEN** two consecutive suspended notifications from one seat whose `task=` values differ, and then two whose
  `awaiting=` sets differ
- **WHEN** the settles run
- **THEN** each key change appends a new line and the earlier line is not touched — an implementation merging across
  tasks or job sets is caught here
- **AND** the same holds across seats: each seat's file holds only that seat's run, and no run is ever written into
  another seat's file

#### Scenario: The awaiting set's order does not split a run

- **GIVEN** the run's line at the end of the seat's inbox carrying `awaiting=<id-b>,<id-a>`, and a following settle of
  the same run that resolves the same two jobs in the order `<id-a>,<id-b>`
- **WHEN** the second settle runs
- **THEN** the two notifications share one line with `×2` — the set, not its spelling, is the key — while a
  byte-comparison of the `awaiting=` values is caught here

#### Scenario: Count churn does not wake

- **GIVEN** a delivered run whose first notification already knocked
- **WHEN** three more same-key settles extend the line
- **THEN** the line carries `×4`, `state/outbox/` gains no new entry from those settles, and no text was typed into
  the PM window — an implementation enqueueing one knock per settle is caught here

#### Scenario: A suspended run records without waking

- **GIVEN** a suspended notification for a run with no knock entry enqueued for it
- **WHEN** two more same-key suspended settles extend that line
- **THEN** the line carries `×3` with its three records in the detail file and `state/outbox/` holds no entry for any
  of the three settles — the run is recorded and the PM was never woken
- **AND** when the seat's next turn ends delivered or interrupted, that new line enqueues exactly one knock entry

#### Scenario: Each new line wakes once

- **GIVEN** an inbox with no unacknowledged lines for the seat
- **WHEN** a delivered run starts, the seat's next turn ends suspended, and the one after it ends interrupted
- **THEN** the PM's outbox gains exactly one knock entry for the delivered line and exactly one for the interrupted
  line — the suspended line in between records without enqueueing anything — and a settle inside any line's dedup
  window enqueues nothing

#### Scenario: A notice appended between two events ends the run without touching the notice

- **GIVEN** a run's line as the last line of a seat's inbox
- **WHEN** a `[manual]`, `[draft]` or `[nudge]` notification is appended to that file and then the same run settles
  again
- **THEN** that notice is byte-identical to what its own writer wrote, the run's earlier line is not rewritten, and
  the new event starts a new line — an implementation rewriting the middle of the file or absorbing the notice into
  the run is caught here

#### Scenario: A merged line is judged by its last event, not as current state

- **GIVEN** a merged line whose last tip is the revision `docs/team/reviews/P9.md` already records, and a second
  merged line for `P9` whose last tip is a revision no record covers
- **WHEN** each line's identifier is compared with the review record and the board row
- **THEN** the first is stale and the second is not, exactly as for a single-event line — the verdict comes from the
  line alone, applied to the event the `last=` timestamp names — and the earlier events of the run stay judgeable
  from their own records in the detail file rather than being treated as the seat's current state

#### Scenario: Line-counting readers count a merged line once

- **GIVEN** a seat's inbox holding one merged line summarising three events
- **WHEN** `team digest` and the panel's inbox block read the file, and then `team inbox --ack` marks the seat read
- **THEN** the pending count for that seat is one line and the tail shows the merged line with its `×3`; after a
  further same-key settle the line is still read, because the total line count did not change

#### Scenario: A single-event line keeps today's shape

- **GIVEN** one settle with nothing running and no same-key run at the end of the seat's inbox
- **WHEN** the notification is delivered
- **THEN** the line contains no `×`, `first=` or `last=` token and is byte-identical to the line the previous rules
  produce for it

#### Scenario: A failed detail write is visible and never merged

- **GIVEN** a settle whose raw record cannot be appended to the detail file while a same-key run is at the end of the
  seat's inbox
- **WHEN** the notification is delivered
- **THEN** the run is not extended, a new line carries `detail=unavailable` in its field block, the extension's log
  names the failed write, a following same-key event starts another new line rather than absorbing the marker, and
  no event is hidden behind a count no record explains — an implementation that merges anyway is caught here

#### Scenario: A settle leaves a pointer line where the PM reads

- **GIVEN** a seat worktree settling a delivered turn with `TEAM_NOTIFY_TMUX=0`
- **WHEN** the settle runs
- **THEN** `docs/team/inbox/<agent>.md` gains its one line as before, and `docs/team/inbox/pm.md` gains one pointer
  line carrying `agent:<agent>`, the task identifier, `knock=skipped:notify-off` and `see=docs/team/inbox/<agent>.md`

#### Scenario: The pointer line is not a second record

- **GIVEN** the same settle
- **WHEN** both inboxes and the detail file are read
- **THEN** the PM's line carries no `:: ` summary, no `branch=`/`uncommitted=`/`unpushed=` field and no `⚠ 未提交`
  prefix, `state/notify.log` holds exactly one record, and the record line is byte-identical to the line the
  single-event shape produces — an implementation that rewrites the record line or records the event twice is caught
  here

#### Scenario: Same run, one pointer line

- **GIVEN** three same-key settles from one seat
- **WHEN** the settles run
- **THEN** `docs/team/inbox/pm.md` holds exactly one pointer line carrying `×3` with `first=` and `last=`, its merge key
  equals the record line's, `team inbox pm --detail` reconciles both, and `state/notify.log` still holds three records
  — an implementation that appends a pointer line per event, or that also records the pointer as detail, is caught here

#### Scenario: The extending event does not rewrite the run's knock

- **GIVEN** a run whose first event enqueued a knock and two further same-key events that enqueue nothing
- **WHEN** the run is read
- **THEN** the pointer line still carries `knock=enqueued` while `state/outbox/` holds exactly one entry for the run

#### Scenario: One settle adds one to the pending count, never two

- **GIVEN** no unacknowledged lines for the seat or for the PM
- **WHEN** a delivered settle runs
- **THEN** the pending notification total is 1, the PM's inbox reports one unread line, the seat's own file reports
  none, and `team inbox pm --ack` clears that one

#### Scenario: A skipped knock is named on the pointer line, and a failed pointer write is not hidden

- **GIVEN** a suspended settle and, separately, a settle whose PM inbox cannot be written
- **WHEN** the settles run
- **THEN** the first writes a pointer line carrying `knock=skipped:suspended` with no outbox entry, and the second
  still enqueues its knock, writes no pointer line, and leaves a `pointer=failed` record in the notice ledger that
  `team digest` names

#### Scenario: A notice appended while a run is being extended is not lost

- **GIVEN** a merge path held inside its critical section by the fixture's control and a manual notification appended
  to the same file meanwhile
- **WHEN** the merge completes
- **THEN** the manual line is present and byte-identical, the run's line is readable, the file contains no partial
  line, and the append path and the merge path did not lose each other's write

---

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

### Requirement: A turn-end notification's raw events stay in a bounded detail file

Every recorded turn-end notification SHALL be appended to `state/notify.log` — one line per event, the same
`- <ISO-8601> <flag><tag> agent:<seat> · …` line the single-event inbox shape defines and without the merge
decoration — before the settle decides whether to extend a run, so an inbox `×N` count never summarises events that
no record holds. The file is a local state artifact: it MUST NOT be appended to any inbox, and recording an event in
it MUST NOT enqueue a knock.

The file SHALL be bounded by `TEAM_NOTIFY_DETAIL_MAX` events (default 2048): when an append would take it past the
bound, the file SHALL be moved to `state/notify.log.1` — replacing any earlier generation, so exactly one rotated
generation is kept — and the new file SHALL begin with exactly one header line naming the rotation time, the rotated
path and the number of events moved. Every rotation SHALL also be named in the extension's log.

`team inbox <agent> --detail` SHALL print the current generation's raw records for that agent together with the path
it read and whether that generation is post-rotation, and for every merged line of that agent it SHALL compare the
line's `×N` count with the records of that line's own merge key — a pointer line in the PM's inbox carries the
sender's key, not the file's seat, and MUST be reconciled against the sender's records instead of being reported as
a gap. The command MUST NOT print an empty or partial listing as if the record
were complete: when a merged line's records are unavailable — the file is missing, or a rotation has taken earlier
events out of the current generation — it SHALL name the gap and `state/notify.log.1` and exit non-zero. The flag is
read-only: it SHALL NOT change the unread count and SHALL NOT acknowledge a line.

#### Scenario: A run's count and its records agree

- **GIVEN** a settle with nothing running and then two same-key settles
- **WHEN** the run is read
- **THEN** `docs/team/inbox/<agent>.md` holds one line carrying `×3` and `state/notify.log` holds three lines, one
  per event in the single-event shape — an implementation that merges without a record, or records without a merge,
  is caught here

#### Scenario: A rotated generation names where the older events went

- **GIVEN** a detail bound of two events and a run that grows past it
- **WHEN** the next event is recorded
- **THEN** `state/notify.log` begins with a header line naming the rotation time, `state/notify.log.1` and the number
  of events moved, the file's remaining lines are the newest events, the rotated file holds the older generation, and
  the extension's log names the rotation

#### Scenario: The bound holds as the file grows

- **GIVEN** a detail bound and a series of recorded events longer than several times that bound
- **WHEN** the series has run
- **THEN** the current file never holds more events than the bound, exactly one rotated generation exists, and no
  append failed silently

#### Scenario: A missing or rotated record is named, not silent

- **GIVEN** a merged line in an agent's inbox with a detail file that is missing, and separately one whose current
  generation no longer holds the whole run
- **WHEN** `team inbox <agent> --detail` runs in each case
- **THEN** the output names `state/notify.log` and the gap — with `state/notify.log.1` as where the older events went
  in the rotated case — the command exits non-zero, and it never prints an empty listing as if the records were
  complete

#### Scenario: A pointer line's records are its own run's

- **GIVEN** the PM's inbox holding a merged pointer line for a seat's three-event run
- **WHEN** `team inbox pm --detail` runs
- **THEN** it matches the line's `×3` against that run's three records (the line's own merge key, not the file's seat),
  reports no gap and exits zero — while a line whose records really are missing still names the gap and exits non-zero

#### Scenario: Detail reading does not acknowledge

- **GIVEN** an unread merged line and its records in `state/notify.log`
- **WHEN** `team inbox <agent> --detail` runs
- **THEN** the records are printed and the unread count is unchanged — only `--ack` marks lines read

#### Scenario: The detail file is not traffic

- **GIVEN** a recorded turn-end event
- **WHEN** it is written
- **THEN** `docs/team/inbox/<agent>.md` gains no extra line from it and `state/outbox/` gains no entry — the record
  is evidence a reader can fetch, never a wake

---

### Requirement: A notice whose knock was skipped is recorded with its reason and named by digest

Every settle that resolved a sender SHALL append exactly one record to `state/notify-knock.log` — the durable,
project-internal answer to "why was the PM not woken". The extension's own log (`TEAM_NOTIFY_LOG`, `/tmp` by
default) MAY stay as a debug log but MUST NOT be the only place a skipped knock is recorded. The record SHALL be one
`- <ISO>` line carrying the seat, the task identifier (or `-`), the state class (or `-`), the knock outcome, the
pointer result and the notice identity (`line|<merge key>|<first event time>`, or `-` when no line was written).

The outcome SHALL be `enqueued` or `skipped:<class>`, and the classes SHALL be closed: `suspended` (a designed state
that wakes nobody), `merged` (the event folded into an already announced run), `dedup` (dropped inside
`TEAM_NOTIFY_DEDUP_SEC`), `turn-unfinished` (an unfinished turn with a lifecycle event), `write-failed` (the durable
inbox line could not be written), `notify-off` (`TEAM_NOTIFY_TMUX=0`), `no-pane` (the sender has no tmux pane),
`pm-not-running` (the PM pane does not run the CLI), `pm-window-missing` (the PM window is absent) and
`enqueue-failed` (the delivery guard did not take the entry). Every path that ends without an enqueued knock SHALL
map to exactly one class, and a reader MUST print an unknown class verbatim rather than dropping it. A settle
rejected before a sender is resolved is not a notice and SHALL NOT be recorded.

The file SHALL be bounded by `TEAM_NOTIFY_DETAIL_MAX` records: when an append would take it past the bound, the file
SHALL be moved to `state/notify-knock.log.1` — one rotated generation, replacing an earlier one — and the new file
SHALL begin with exactly one header line naming the rotation time, the rotated path and the number of records moved;
every rotation SHALL also be named in the extension's log.

`team digest`'s pending-notification section SHALL name, when non-zero, both of these, and neither MUST change any
count that decides a wake-up:

- the notices recorded in the PM's inbox whose knock was skipped, counted from the PM's **unacknowledged pointer
  lines** by their `knock=skipped:<class>` — one per run, grouped by class — so the line clears when the PM reads and
  acknowledges those lines, not through a second acknowledgement channel;
- the notices the pointer write could not deliver, counted from the current generation of the ledger
  (`pointer=failed`), naming the file and the fact that older generations are not counted.

The display SHALL stay out of the patrol's pending reason and out of every wake decision: a suspension is a designed
state that wakes nobody, and a pointer failure that cannot clear MUST NOT wake the PM once per tick. A pointer
failure does not lose the notice on its own — the knock path is independent of the pointer, so the PM is woken by the
knock when there is one.

#### Scenario: A suspension is recorded and named, and wakes nobody

- **GIVEN** a suspended settle and no other pending work
- **WHEN** the settle runs and then `team digest` reads the pending counts
- **THEN** `state/notify-knock.log` gains one line with `outcome=skipped:suspended`, `state/outbox/` gains no entry,
  `docs/team/inbox/pm.md` holds a pointer line carrying `knock=skipped:suspended`, and the digest's skipped line
  names `suspended 1` while the patrol's pending reason is unchanged

#### Scenario: Reading clears the skipped count

- **GIVEN** the same suspension, with the digest naming `suspended 1`
- **WHEN** `team inbox pm --ack` runs and then the digest runs again
- **THEN** the skipped line no longer names that notice — its pointer line is read — while the ledger keeps the record

#### Scenario: Every path that does not knock carries one class

- **GIVEN** settles that are dropped inside the dedup window, folded into an already announced run, refused by
  `TEAM_NOTIFY_TMUX=0`, and whose PM pane holds a shell
- **WHEN** the ledger is read
- **THEN** it holds one line per settle with `outcome=skipped:dedup`, `skipped:merged`, `skipped:notify-off` and
  `skipped:pm-not-running` respectively, and no settle is missing or carries two classes

#### Scenario: An unknown class is printed, not swallowed

- **GIVEN** a ledger line whose class is `skipped:something-new`
- **WHEN** the digest reads it
- **THEN** the class appears in the output verbatim and the line is not silently dropped

#### Scenario: The ledger is bounded and names its rotation

- **GIVEN** a bound of two records and four settles
- **WHEN** the fourth record is written
- **THEN** the current file begins with a header naming the rotation time, `state/notify-knock.log.1` and the number
  of records moved, the rotated file holds the older generation, and the extension's log names the rotation

#### Scenario: A pointer failure is named from the ledger

- **GIVEN** a settle whose pointer write failed
- **WHEN** the digest runs
- **THEN** it names one notice that did not reach the PM's inbox, read from the current generation of
  `state/notify-knock.log`, the knock entry for that settle exists in `state/outbox/`, and the pointer-failure line
  contributes nothing to the pending reason

