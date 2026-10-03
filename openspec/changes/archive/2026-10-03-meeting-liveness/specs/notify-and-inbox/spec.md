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

