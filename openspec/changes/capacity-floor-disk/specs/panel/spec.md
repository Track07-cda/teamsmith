## ADDED Requirements

### Requirement: The disk floor's keys are contract rows the console carries

The capacity floor's two thresholds SHALL be rows of the project contract's schema — `TEAM_TMP_MIN_FREE_MB`
(kind `mb`, default `1024`) and `TEAM_TMP_MIN_FREE_INODES` (kind `int`, default `100000`), both class `apply` and
group `delivery` — and the disk fixtures' seam `TEAM_DISK_STATS_FILE` SHALL be a `refuse` test-knob row, so the
settings view carries all three without a code change: the two thresholds as editable `apply` rows rendering their
zh/en label and, while the file is silent, the schema's default, and the seam as a `refuse` row that opens no
editor. `team config list --json` SHALL report the same classes, defaults and group, and both tables SHALL carry a
non-empty `label_<KEY>` for each of the three (the string-table gate checks those in both directions and within
the row's label column).

#### Scenario: The three keys reach the view and the machine read

- **GIVEN** a fixture project whose contract does not carry the three keys and a JS runtime
- **WHEN** `team config list --json` runs and the settings view renders in a fixture pane
- **THEN** the two thresholds' records carry class `apply`, defaults `1024` and `100000` and group `delivery`, the
  seam's record carries class `refuse`, and each of the three rows' main text is that key's label in the active
  language (no row reads `TEAM_…`), with the seam's row opening no editor

## MODIFIED Requirements

### Requirement: The status band answers "who is in charge" and "is there work"

The status band SHALL carry, in this order: the project name, the timestamp, the patrol interval, the standby state,
the PM state, the pending counts (unread notifications, task reports awaiting review, blocked board rows and their
total), the deferred-delivery counts, and the capacity figures (RAM available in MB, swap free in MB, the agent
estimate, and for the filesystems a worker will write to — the temp root and the worktrees root — their available
bytes and free inodes, with a figure that cannot be read rendered as `—`, and a mini chart built from the tail of
`state/capacity.log`). The zram physical figure SHALL leave the panel and stay available in `team watchdog status`.
The same fields SHALL appear in `--json` under `panel.pm`, `panel.pending`, `panel.capacity` and `panel.standby`
with the PM state in a closed vocabulary (`running`, `starting`, `absent`, `foreign`, `unknown`) and standby as
`{on, reason}`; `panel.capacity.disk` SHALL be one entry per judged filesystem carrying its path, its available
bytes and free inodes, or `null` for a figure that cannot be read.

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
