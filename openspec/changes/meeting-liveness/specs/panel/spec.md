## MODIFIED Requirements

### Requirement: The status band answers "who is in charge" and "is there work"

The status band SHALL carry, in this order: the project name, the timestamp, the patrol interval, the standby state,
the PM state, the pending counts (unread notifications, task reports awaiting review, blocked board rows, unread
meeting turns and their total), the deferred-delivery counts, and the capacity figures (RAM available in MB, swap
free in MB, the agent estimate and a mini chart built from the tail of `state/capacity.log`). The zram physical
figure SHALL leave the panel and stay available in `team watchdog status`. The same fields SHALL appear in `--json`
under `panel.pm`, `panel.pending` (whose counts object carries the unread-meeting count as `meetings` and includes
it in `total`), `panel.capacity` and `panel.standby` with the PM state in a closed vocabulary
(`running`, `starting`, `absent`, `foreign`, `unknown`) and standby as `{on, reason}`.

#### Scenario: The band mirrors the measured state

- **GIVEN** a fixture project with no PM window, one unread inbox line, two task reports without review records, one
  `blocked` board row, three queue entries and 40 `capacity.log` samples
- **WHEN** `team monitor --print` and `team monitor --json` run
- **THEN** `panel.pm.state` is `absent`, the pending counts are 1, 2, 1 and 4, `panel.outbox.queued` is 3, and
  `panel.capacity.ram_avail_mb` equals the last sample's value while `panel.capacity.spark` has at least two samples
- **AND** the printed status band contains the queue count and the PM state token, and carries no zram physical MB

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

