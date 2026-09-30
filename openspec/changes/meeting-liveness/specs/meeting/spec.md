## MODIFIED Requirements

### Requirement: Meetings are bounded

A meeting SHALL carry a TTL (`TEAM_MEETING_TTL_HOURS`, default 72) and a per-side message cap
(`TEAM_MEETING_MAX_TURNS`, default 20); `team meeting say` MUST refuse further messages once the cap is reached, and
`team meeting close` SHALL be the only way to end a meeting. `--ttl` SHALL accept a positive integer number of hours
only; a value above 8760 SHALL be clamped to 8760 with a warning, and a stored value that is missing or not a
positive integer SHALL fall back to the documented default instead of granting immortality.

Expiry is a derived state, not a rewrite of the record: a meeting whose TTL has passed SHALL be reported as
`expired` (never as `open`), it stays read-only — every command except `read` and `close` refuses it — and
`team meeting close <slug>` SHALL succeed on it, so an expired meeting can always be closed (the current deadlock,
where the only way out refuses it, MUST NOT come back). `team meeting close --stale` SHALL close every expired
meeting of this project that is not closed and MUST NOT touch a meeting that is not expired; when no meeting of this
project is expired it SHALL exit non-zero, close nothing and say so. `team status` and `team digest` SHALL each
print one line naming every expired meeting of this project that is not closed, together with the
`team meeting close --stale` command, and MUST print no such line when there is none.

#### Scenario: The turn cap refuses the next message

- **GIVEN** this project already wrote `TEAM_MEETING_MAX_TURNS` messages in the meeting
- **WHEN** `team meeting say <slug> --intent info "one more"` runs
- **THEN** it exits non-zero and names the cap

#### Scenario: An expired meeting is reported as expired and stays readable

- **GIVEN** a meeting of this project whose `OPENED_EPOCH` is older than its TTL, with one turn in the transcript
- **WHEN** `team meeting list`, `team meeting read <slug>` and `team meeting say <slug> --intent info "…"` run
- **THEN** the list row's state is `expired` (not `open` or `open(过期)`), the read exits 0 and prints the turn, and
  the say exits non-zero naming the TTL

#### Scenario: An expired meeting can be closed

- **GIVEN** the same expired meeting
- **WHEN** `team meeting close <slug> --summary "leftovers: none"` runs
- **THEN** it exits 0, `state.env` carries `STATUS=closed`, and `team meeting list` no longer reports the meeting as
  expired

#### Scenario: `close --stale` closes exactly the expired meetings

- **GIVEN** two meetings of this project, one expired and one not
- **WHEN** `team meeting close --stale` runs
- **THEN** the expired meeting's `state.env` carries `STATUS=closed`, the non-expired meeting's `state.env` is
  byte-unchanged and still `STATUS=open`, and the output names both meetings and their outcome

#### Scenario: `close --stale` is refused when nothing is stale

- **GIVEN** only non-expired meetings of this project
- **WHEN** `team meeting close --stale` runs
- **THEN** it exits non-zero, says that no meeting is expired, and no `state.env` changed

#### Scenario: The project surfaces name the expired-unclosed meeting

- **GIVEN** an expired meeting of this project that is not closed
- **WHEN** `team status` and `team digest` run
- **THEN** each prints exactly one line containing the meeting's slug and the `team meeting close --stale` command
- **AND** with every meeting closed or unexpired, neither output contains that line

## ADDED Requirements

### Requirement: A per-project read position defines unread turns

Every meeting SHALL keep one read position per participating project (`read/<project>.seq`, the number of the last
turn that project has read). The unread turns of a project SHALL be the transcript turns after its position, and the
project's own turns MUST NOT count as unread (`team meeting say` advances the writer's own position). `team meeting
read` SHALL advance the reader's position unless `--peek` is given, and `team meeting inbox` and `team meeting list`
SHALL count unread turns from that position for the meetings of this project that are not closed (a closed meeting
freezes its transcript and is not counted). Reading a turn MUST NOT depend on a knock: the transcript is the source
of truth and the knock is only a notification on top of it.

#### Scenario: A peer turn is unread until it is read

- **GIVEN** a meeting with one peer turn and this project's read position at 0
- **WHEN** `team meeting list` and `team meeting inbox` run
- **THEN** the list row reports 1 unread and the inbox names the meeting; after `team meeting read <slug>` the
  position equals that turn's number and the next `team meeting inbox` reports no pending reply

#### Scenario: A project's own turn advances its own position

- **GIVEN** a meeting where `team meeting say <slug> --intent info "…"` just wrote turn 3
- **WHEN** the meeting's `read/<project>.seq` is read and `team meeting inbox` runs
- **THEN** the position is 3 and the inbox reports nothing new

#### Scenario: A peek does not advance the position

- **GIVEN** a meeting with an unread peer turn
- **WHEN** `team meeting read <slug> --peek` runs
- **THEN** the turn is printed and `read/<project>.seq` is byte-unchanged

### Requirement: Each participant registers its own PM window

A meeting's PM windows SHALL be per participant, stored in `state.env` as `PM_WINDOWS=<project>=<window>;…` — one
row per project, never one field shared by both directions. `team meeting open` SHALL record the opener's own window
(`TEAM_PM_WINDOW`, else `pm`), and `team meeting peer <slug> <project>:<session> [--window <name>]` SHALL register
one project's session and window, defaulting the caller's own project to its `TEAM_PM_WINDOW` (else the current tmux
window when the caller runs inside one, else the documented default). A knock SHALL resolve the peer's window as the
peer project's `PM_WINDOWS` row, else the legacy `PM_WINDOW` value, else `pm`, and both its success line and its
failure diagnostic SHALL name the resolved `session:window` and the registration command. Writing one project's row
MUST NOT change another row.

#### Scenario: A peer window that is not `pm` is knocked

- **GIVEN** a meeting whose rows are `alpha=pm;beta=pi` and a live TUI in the peer session's `pi` window
- **WHEN** alpha runs `team meeting say <slug> --intent info "…" --knock` with `TEAM_MEETING_KNOCK=1`
- **THEN** the notice is typed into `<beta-session>:pi` and the success line names that target

#### Scenario: Each row belongs to its own project

- **GIVEN** rows `alpha=pm;beta=pi` and both sessions live
- **WHEN** alpha registers its own row as `alpha=<alpha-session> --window new`
- **THEN** alpha's knock still targets `<beta-session>:pi`, beta's knock targets `<alpha-session>:new`, and the
  `PM_WINDOWS` row `beta=pi` is byte-unchanged

#### Scenario: A meeting opened before the map still knocks

- **GIVEN** a `state.env` with no `PM_WINDOWS` line and `PM_WINDOW=pi`
- **WHEN** a knock runs
- **THEN** the target is `<peer-session>:pi` (the legacy field is read, not ignored)

#### Scenario: An unresolved window is named, not guessed silently

- **GIVEN** a registered peer session whose resolved window is not running a TUI
- **WHEN** a knock runs
- **THEN** the knock types nothing, the diagnostic names the resolved `session:window`, and it prints the
  `team meeting peer <slug> <project>:<session> --window <name>` command

### Requirement: A participant is recognized by its recorded names, not by one spelling

`state.env` SHALL record every participant with both the tmux session it is reached at (`PEER_SESSIONS`) and the
name of its repository — the basename of its main worktree — in a per-participant record
(`PARTICIPANT_REPOS=<project>=<basename>;…`): `team meeting open` writes the opener's own repository name, and
`team meeting peer <slug> <project>:<session> [--window <name>] [--repo <name>]` records a project's own row
(session, window, repository name; a missing `--repo` for the caller's own project defaults to the basename of its
main worktree). The membership test used by
`team meeting read`/`say`/`inbox`/`list`/`peer` SHALL accept a project when any of its identifiers matches the
meeting record — its declared project name (`TEAM_PROJECT`) or the basename of its main worktree matching a
recorded participant name, or its `TEAM_SESSION` equal to the session recorded for a participant — and it MUST NOT
assume that a participant's recorded name equals its repository basename. A project none of whose identifiers
matches MUST be refused exactly as today, and `team meeting inbox` MUST NOT name a meeting for it.

#### Scenario: A project invited by its session name still reads and writes

- **GIVEN** a meeting recording the participant `<peer>` with session `<peer>`, and a project whose main
  worktree basename is `<peer-project>`, whose `TEAM_PROJECT` is `<peer-project>` and whose `TEAM_SESSION` is `<peer>`
- **WHEN** `team meeting read <slug>`, `team meeting say <slug> --intent report "…"` and `team meeting inbox` run
- **THEN** all three exit 0 — the read prints the transcript turns, the say writes the next turn, the inbox counts
  the unread turns — and after `team meeting peer <slug> <peer-project>:<peer> --repo <peer-project>` `state.env` carries
  the repository name `<peer-project>` for the participant alongside its session

#### Scenario: A third project is still refused

- **GIVEN** the same meeting and a project whose declared name, repository basename and session are all unrecorded
- **WHEN** `team meeting read <slug>`, `team meeting say <slug> --intent info "…"` and `team meeting inbox` run
- **THEN** read and say exit non-zero naming the meeting's participants, the transcript gains no entry, and the
  inbox names no meeting

### Requirement: A knock names the turn it announces

The knock payload SHALL carry the meeting slug and the transcript turn number it announces
(`[meeting:<slug>#<N>] <sender> 有新发言（intent=<intent>）→ …`), and `knocks.log` SHALL record the same turn
number. The identifier SHALL let a receiver decide staleness from the shared area alone: the notice is stale when
the receiver's `read/<project>.seq` is greater than or equal to that turn number. A knock MUST NOT be sent for a
turn that is not in the transcript.

#### Scenario: A knock names the turn it announces

- **GIVEN** a meeting whose newest transcript turn is `0004` and a registered peer session
- **WHEN** `team meeting knock <slug>` runs (or `team meeting say <slug> --intent info "…" --knock`)
- **THEN** the payload sent to the peer (and reported on success) contains `[meeting:<slug>#4]`, and the
  `knocks.log` line names the same turn number

#### Scenario: A stale knock is decidable from the shared area

- **GIVEN** a knock for `#4` and a receiver whose `read/<project>.seq` is `3`
- **WHEN** the receiver checks the notice against its read position
- **THEN** the notice is not stale and `team meeting read <slug>` prints turn `0004`; with the position at `4` the
  same notice is stale and the read prints no turn after `0003` — the check reads only the transcript and the
  `read/<project>.seq` file, not any repository

