# tmp-root-on-disk · watchdog（delta）

Base text: `openspec/specs/watchdog/spec.md`.

## MODIFIED Requirements

### Requirement: `team doctor` reports the temp root's headroom

`team doctor` SHALL print one row for each filesystem a worker will write to — the temp root (**the path the one
resolver returns**, with the source it resolved it from, not a default computed here) and the worktrees root
(`TEAM_WORKTREES_DIR`; one row when both resolve to the same filesystem) — carrying the
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

The temp root's row SHALL name its resolution source. A resolved default that does not exist yet SHALL NOT be
reported as unreadable: the row SHALL say the directory does not exist yet, name the nearest existing ancestor it
measured, and MUST NOT create anything. When the gate's published lock path lies on a filesystem no judged row
already covers, the doctor SHALL add one **warning-only** row for that filesystem, naming the lock path and its
figures — a full lock filesystem stops a gate from taking its lock, and it MUST NOT refuse a dispatch, so that row
is a warning and never a dispatch floor.

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

#### Scenario: The temp root's row says how the path was resolved

- **GIVEN** a run with the project's pin selected and another with the platform default selected
- **WHEN** `team doctor` prints its temp root row in each
- **THEN** each row names the resolved path and its source, and the two rows differ exactly in path and source

#### Scenario: A not-yet-created default is reported through its ancestor, not as unreadable

- **GIVEN** the resolved default directory absent, its parent writable
- **WHEN** `team doctor` runs
- **THEN** the row names the resolved path, says it does not exist yet and names the ancestor it measured, creates
  nothing, and is not reported as "cannot read" and not as healthy — it carries the ancestor's verdict

#### Scenario: A full lock filesystem warns and refuses no dispatch

- **GIVEN** a resolved temp root and a worktrees root above both floors, and a `TEAM_DISK_STATS_FILE` whose row for
  the published lock path's filesystem is far below the floor
- **WHEN** `team doctor` runs and then `team dispatch dev T1.1 <brief> --print` runs
- **THEN** the doctor prints a warning row naming that filesystem and the lock path, still exits 0, and the dispatch
  is not refused for it
