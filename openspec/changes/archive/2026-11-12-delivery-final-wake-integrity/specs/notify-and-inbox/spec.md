# Spec Delta

## MODIFIED Requirements

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
(seat, task, state class, `awaiting` set, delivered revision), where the seat is the resolved sender, the task is the
line's `<ID>` token (the string the `task=` stamp carries when the stamp exists, and a value of its own when the line
has no task identifier), the state class is the line's tag (`delivered` for `[auto]`, `suspended` for
`[auto·suspended]`, `interrupted` for `[auto·interrupted]`), and the `awaiting` set is the ids of the `awaiting=`
field, deduplicated and compared without regard to their order; an absent `awaiting=` field and an empty one are
different values. For a delivered line, the delivered revision is its twelve-character `tip=` value or a distinct
no-revision value when no stamp can be proven, so a different delivered tip SHALL start a new line while repeated
delivered events at one tip and otherwise equal keys SHALL merge. For suspended and interrupted lines this component is empty: their progress
tips MAY merge without changing the existing wake rules. A notification whose key differs from the run already at
the end of the seat's inbox SHALL start a new line, and a run SHALL only be extended while its line is the last line
of that file — any other line appended in between ends it.
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
that directory. Only a job the settling session itself started SHALL count: a current record belongs to the session
when its `session_cwd` resolves, through symlinks and trailing slashes, to the session's own working tree or working
directory; the command's execution `cwd` MAY name an independent checkout and MUST NOT replace that initiating
identity. A record with an empty, relative or unresolvable `session_cwd`, or one resolving to another session's
directory, SHALL NOT make the turn suspended and MUST NOT fall back to `cwd`. Only for a legacy record with no
`session_cwd` field, `cwd` SHALL establish ownership when it resolves exactly to the settling seat's worktree; an
independent checkout, a subdirectory, another seat or an invalid path belongs to no seat. The ownership check fails
closed rather than guessing. A record SHALL count as running only while
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
  live-verified record whose `session_cwd` names its own worktree and whose `cwd` names an independent checkout
- **WHEN** each session ends a completed turn
- **THEN** each line carries `awaiting=` with only the job its own session started — the other seats' jobs
  are neither named nor counted, so each seat's turn reports exactly its own parked work

#### Scenario: An independent-checkout job becomes one final delivery wake

- **GIVEN** a seat's live-verified job record whose `session_cwd` names that seat and whose `cwd` names an independent checkout
- **WHEN** the seat first ends a completed turn while the job runs, then harvests the finished job, commits its final report at a new tip and ends delivered
- **THEN** the first line is suspended and enqueues no wake, the final delivered tip starts a new line and enqueues exactly one wake, and no other seat names or adopts that job

#### Scenario: An idle seat is not suspended by another seat's job

- **GIVEN** a live-verified record whose `session_cwd` names the `dev` worktree and whose `cwd` names `dev2`, while the
  `dev2` and `dev3` sessions share the same lane state directory and hold no record of their own
- **WHEN** each of the two idle sessions ends a completed turn
- **THEN** each notification keeps the `[auto]` shape with no `awaiting=` field, and neither session falls back to the execution `cwd`

#### Scenario: A record with no owning directory does not suspend

- **GIVEN** live-verified current records whose `session_cwd` is empty, relative, unresolvable or names another seat,
  plus legacy records without that field whose `cwd` names an independent checkout, a seat subdirectory or another seat
- **WHEN** a completed turn ends
- **THEN** the notification keeps the `[auto]` shape with no `awaiting=` field — the ownership check fails
  closed instead of guessing, and only a legacy `cwd` resolving exactly to this seat's worktree is accepted

#### Scenario: An explicit state directory is the lane's directory

- **GIVEN** a session whose `TEAM_STATE_DIR` points at a fixture directory holding one live-verified record,
  while the notify extension's own project root holds a different live-verified decoy record
- **WHEN** a completed turn ends
- **THEN** the notification is suspended on the record in `TEAM_STATE_DIR` and does not name the decoy — the
  directory the lane wrote is the only source for this verdict, and the fixture's red side (an implementation
  reading a directory of its own choosing) fails this scenario

#### Scenario: A run of same-key notifications is one line with its window

- **GIVEN** three turn-end notifications from the `dev` worktree, all on branch `task/P9-parser` at the same delivered
  tip, each ending a completed turn with nothing running and each carrying a different summary text
- **WHEN** the three settles run
- **THEN** `docs/team/inbox/dev.md` holds exactly one line for them, its field block carries `×3` with `first=` and
  `last=` naming the first and the third event's timestamps, and `state/notify.log` holds three records — one per
  event — while a settle that always appended would leave three lines and be caught by this scenario

#### Scenario: The merged line carries the last event's values

- **GIVEN** three same-run suspended notifications whose `uncommitted` counts are 4, 2 and 0, whose `branch=` and
  `awaiting=` values are the same, and whose `task=P9 tip=` stamps name three different revisions, followed by two
  same-run interrupted notifications with the same `awaiting=` set and two different tips
- **WHEN** the suspended and interrupted settles run in their respective runs
- **THEN** the suspended line carries `×3`, `uncommitted=0`, the third event's `tip=` and `last=`, all three raw
  records remain, and no wake is enqueued; the interrupted pair also forms one `×2` line and enqueues only its
  initial wake — an implementation splitting either non-delivered class by tip or taking an averaged value is caught here

#### Scenario: Each delivered revision starts a new line and wakes once

- **GIVEN** three consecutive delivered notifications for one task whose `tip=` values name three different revisions
- **WHEN** the three settles run
- **THEN** the seat inbox and PM pointer inbox each hold three separate lines, each delivered line enqueues exactly one
  wake, and an implementation merging across delivered tips fails this scenario

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

- **GIVEN** a delivered run whose first notification already knocked and whose later events keep the same `tip=`
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

- **GIVEN** a merged suspended-progress line whose last tip is the revision `docs/team/reviews/P9.md` already records,
  and a second such line for `P9` whose last tip is a revision no record covers
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

- **GIVEN** three same-key delivered settles from one seat at the same `tip=`
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
