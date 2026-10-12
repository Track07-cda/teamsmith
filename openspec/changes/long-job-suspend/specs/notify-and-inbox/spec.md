## MODIFIED Requirements

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

A completed turn that ends while background jobs its own session started are still running SHALL be told apart
from both a delivery and an interruption: the inbox line and the knock payload SHALL carry the tag
`[auto·suspended]` and an `awaiting=<id>[,<id>…]` field naming the running jobs, and the dirty-tree warning flag
SHALL be omitted for a suspension (the `uncommitted=<n>` field stays) — a suspension is not a delivery claim and
MUST NOT wear the alarm shape of one. The running set SHALL be read from the same `state/bg/` directory the lane
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
- **THEN** the inbox line and the knock payload carry `[auto·suspended]` and an `awaiting=<id>` field naming that
  job, the `uncommitted=<n>` field is present, and the dirty-tree warning flag does not appear

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
