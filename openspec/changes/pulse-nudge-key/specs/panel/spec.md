## MODIFIED Requirements

### Requirement: The status band answers "who is in charge" and "is there work"

The status band SHALL carry, in this order: the project name, the timestamp, the patrol interval, the standby state,
the PM state, the pending counts (unread notifications, task reports awaiting review, blocked board rows, unread
meeting turns and their total), the deferred-delivery counts, and the capacity figures (RAM available in MB, swap
free in MB, the agent estimate, and for the filesystems a worker will write to — the temp root and the worktrees
root — their available bytes and free inodes, with a figure that cannot be read rendered as `—`, and a mini chart
built from the tail of `state/capacity.log`). The zram physical figure SHALL leave the panel and stay available in
`team watchdog status`. The same fields SHALL appear in `--json` under `panel.pm`, `panel.pending` (whose counts
object carries the unread-meeting count as `meetings` and includes it in `total`), `panel.capacity` and
`panel.standby` with the PM state in a closed vocabulary (`running`, `starting`, `absent`, `foreign`, `unknown`) and
standby as `{on, reason}`; `panel.capacity.disk` SHALL be one entry per judged filesystem carrying its path, its
available bytes and free inodes, or `null` for a figure that cannot be read.

The pending counts, their total and their human-readable text SHALL reflect the current pending snapshot rather
than the last reminded snapshot, even when a count-only change was suppressed by `TEAM_PULSE_NUDGE_GAP`. The
existing pending JSON fields (`inbox`, `reports`, `todo`, `wip`, `review`, `blocked`, `stopped`, `meetings`, `total`,
`text`) SHALL retain their count/text meanings: a category-only wake identity MUST NOT replace counts with
booleans. `team monitor --print`, `team monitor --json` and `team __panel-data --block pending` MUST remain
read-only and MUST NOT advance, clear or create reminder state. Rationale for observer modes and pending-only
patrols: `skills/teamsmith/references/config.md` and `skills/teamsmith/references/workflows.md` §I.

#### Scenario: The band mirrors the measured state

- **GIVEN** a fixture project with no PM window, one unread inbox line, two task reports without review records, one
  `blocked` board row, three queue entries and 40 `capacity.log` samples
- **WHEN** `team monitor --print` and `team monitor --json` run
- **THEN** `panel.pm.state` is `absent`, the pending counts are 1, 2, 1 and 4, `panel.outbox.queued` is 3, and
  `panel.capacity.ram_avail_mb` equals the last sample's value while `panel.capacity.spark` has at least two samples
- **AND** the printed status band contains the queue count and the PM state token, and carries no zram physical MB

#### Scenario: The disk readings reach the band and the JSON

- **GIVEN** `TEAM_DISK_STATS_FILE` holds figures for the temp root and the worktrees root
- **WHEN** `team monitor --print` and `team monitor --json` run
- **THEN** `panel.capacity.disk` holds one entry per judged filesystem with its path, available bytes and free
  inodes, and the printed band names each path with its measured availability

#### Scenario: A filesystem that cannot be read is not assigned a number

- **GIVEN** the temp root's figures cannot be read (no fixture row and no readable `df` result)
- **WHEN** `team monitor --print` and `team monitor --json` run
- **THEN** its `panel.capacity.disk` entry carries no availability number, and the printed band renders `—` for it
  rather than a value

#### Scenario: Standby is visible where the wake-ups are decided

- **GIVEN** a fixture project where `team standby on --reason "waiting for the user"` has run
- **WHEN** `team monitor --json` runs
- **THEN** `panel.standby.on` is true and `panel.standby.reason` is that reason, and the printed status band shows
  the reason on the title or PM line

#### Scenario: The band carries unread meeting turns

- **GIVEN** a fixture project with no unread inbox lines, no reports, no blocked rows and two unread peer turns
  across its meetings
- **WHEN** `team monitor --print` and `team monitor --json` run
- **THEN** `panel.pending.meetings` is 2, `panel.pending.total` is 2, `panel.pending.text` contains `未读会议 2`,
  and the printed band shows `未读会议 2`

#### Scenario: A suppressed reminder does not freeze the displayed counts

- **GIVEN** a running fixture PM reminded for one unread notification, `TEAM_PULSE_NUDGE_GAP=3600`, and a later
  tick inside that gap after the count becomes four without another pending category
- **WHEN** `team monitor --print`, `team monitor --json` and `team __panel-data --block pending` run
- **THEN** the JSON and pending block carry `inbox=4`, `total=4` and text containing `未读通知 4`, and the print
  shows the current unread count rather than one
- **AND** file contents and timestamps under `state/` remain the same across these observer reads, with no
  additional `state/nudges.log` line, new outbox entry or reminder-state update
