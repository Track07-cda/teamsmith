## MODIFIED Requirements

### Requirement: Restart quota and capacity logging

The pulse SHALL start the PM at most `TEAM_PULSE_MAX_RESTARTS` times per hour (default 5). Beyond that it MUST
stop starting the PM and warn instead. Each tick MUST append one line to `.pi/team/state/capacity.log` carrying the
timestamp and the measured capacity readings — the RAM/swap figures and the agent estimate plus, for the temp root
and the worktrees root, the available bytes and free inodes — so capacity has a trend across the filesystem
dimension too, not just a current value.

#### Scenario: The quota refuses further restarts

- **GIVEN** the PM is not running and the restart log already shows `TEAM_PULSE_MAX_RESTARTS` starts in the last hour
- **WHEN** a tick with pending work runs
- **THEN** it does not start a PM process and logs a warning about the exceeded quota

#### Scenario: Capacity is recorded per tick

- **GIVEN** `TEAM_DISK_STATS_FILE` holds figures for the temp root and the worktrees root
- **WHEN** two patrol ticks run
- **THEN** `state/capacity.log` has two new lines, each carrying the timestamp, the memory/swap figures and both
  filesystems' available bytes and free inodes

### Requirement: `team doctor` reports the temp root's headroom

`team doctor` SHALL print one row for each filesystem a worker will write to — the temp root (`${TMPDIR:-/tmp}`)
and the worktrees root (`TEAM_WORKTREES_DIR`; one row when both resolve to the same filesystem) — carrying the
resolved path, the free and total bytes **and** the free and total inodes of its filesystem, or a statement that a
figure (or the filesystem's inode table) cannot be read, and a verdict. A row MUST warn — without making
`team doctor` exit non-zero — when the free bytes are below `TEAM_TMP_MIN_FREE_MB` (default 1024) or the free
inodes are below `TEAM_TMP_MIN_FREE_INODES` (default 100000; a non-numeric value falls back to the default), and
the warning MUST name the figures it measured, the threshold it crossed, that the next dispatch will be refused
and the remedy (`bash skills/teamsmith/tests/tmp-hygiene.sh --status`, then `--sweep`, for the temp root). When
the path or a figure cannot be read the row SHALL say so and MUST NOT report the headroom as fine. The rows MUST
read nothing inside the paths and MUST NOT delete anything; raising the headroom is an operator action (as with
the inotify quota, the sibling host-resource row). Why a full filesystem is a gate risk, and the measured floor
behind the defaults: the `test-tmp-hygiene` change's `design.md`, the `capacity-floor-disk` change's `design.md`
and `references/troubleshooting.md`.

#### Scenario: A healthy temp root is reported with its numbers

- **WHEN** `team doctor` runs with both figures above their thresholds
- **THEN** its temp root row names the resolved path, the free/total bytes and the free/total inodes, and the
  check passes — and the doctor's exit status is unchanged by this check

#### Scenario: A low temp root warns with its remedy and does not fail the doctor

- **GIVEN** `TEAM_TMP_MIN_FREE_MB` set above the free bytes actually measured
- **WHEN** `team doctor` runs
- **THEN** the row is a warning naming the measured figures, the threshold it crossed, that the next dispatch will
  be refused and the `tmp-hygiene.sh` remedy, and `team doctor` still exits 0

#### Scenario: A low worktrees filesystem warns with the same floor

- **GIVEN** `TEAM_DISK_STATS_FILE` holds a worktrees root row below `TEAM_TMP_MIN_FREE_INODES`
- **WHEN** `team doctor` runs
- **THEN** the worktrees root's row warns, names that path and the inode figure it measured, and `team doctor`
  still exits 0

#### Scenario: An unreadable temp root is never reported as healthy

- **GIVEN** a resolved temp root that does not exist
- **WHEN** `team doctor` runs
- **THEN** its row states that the figures could not be read and the check is a warning, not a pass, and it does
  not invent a number

#### Scenario: A filesystem without an inode table reports no inode verdict

- **GIVEN** the worktrees root's filesystem reports a zero inode table
- **WHEN** `team doctor` runs
- **THEN** its row says no inode figure is available for it and does not warn or pass on an inode number
