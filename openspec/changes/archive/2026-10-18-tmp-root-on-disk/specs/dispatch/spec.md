# tmp-root-on-disk · dispatch（delta）

Base text: `openspec/specs/dispatch/spec.md`.

## MODIFIED Requirements

### Requirement: The capacity floor protects the host

`team dispatch` SHALL refuse to start a worker when the host is below a capacity floor: RAM+swap
(`TEAM_MIN_TOTAL_MB`, default 512 MB), MemAvailable (`TEAM_MIN_AVAIL_MB`, default 1024 MB), **disk** swap free
(`TEAM_MIN_FREE_SWAP_MB`, default 1024 MB), or the disk/inode leg below. zram MUST be excluded from the swap floor
(its pages live in RAM); zram occupancy above `TEAM_ZRAM_WARN_PCT` (default 85) is a warning only.

The disk/inode leg SHALL judge, before any window is opened and for `--print` as well, the free bytes and the free
inodes of the filesystems the worker will write to: the temp root — **the path the one resolver returns**, not a
default computed here (`verification`'s requirement `One resolution decides every temp path, and it says how it
decided`) — and the worktree filesystem
(the agent's worktree for a dispatch; the worktrees root `TEAM_WORKTREES_DIR` where no target is resolved). It
SHALL refuse when the free bytes are below `TEAM_TMP_MIN_FREE_MB` (default 1024) or — only when the filesystem
reports an inode table — when the free inodes are below `TEAM_TMP_MIN_FREE_INODES` (default 100000); a
non-numeric threshold falls back to its default, and `0` disables that leg, the same escape shape as
`TEAM_MIN_AVAIL_MB=0`. The refusal MUST name the path, the resolution source the resolver reported for it, the
measured figures, the threshold crossed and a
`修法：<command>` line — for the temp root the ownership-proven
`bash skills/teamsmith/tests/tmp-hygiene.sh --status`, then `--sweep`; for the worktree filesystem, freeing that
path — and MUST print the explicit override (`TEAM_TMP_MIN_FREE_MB=0` / `TEAM_TMP_MIN_FREE_INODES=0`).

Before the headroom is judged, the leg SHALL refuse a dispatch whose temp root cannot be used: an explicitly
selected root (`TEAM_TMP_ROOT` from the contract, or `TMPDIR`) that does not exist, is not a directory, or is not
writable is a blocking finding that names that path, its source and the `修法：` line (create the directory, fix its
mode, or select a usable root) — the dispatch MUST NOT proceed and MUST NOT silently use another root. A resolved
**default** root that does not exist yet is not a refusal: the leg SHALL judge its nearest existing ancestor, and
the capacity line SHALL name both the resolved path and the ancestor it measured. The lock's filesystem is
deliberately not judged here: a full `/tmp` can stop a gate from taking its lock, but it MUST NOT refuse a
dispatch, so that leg is a warning on `team doctor`, not a dispatch floor.

A figure that cannot be read (`df` fails, a column is missing or non-numeric) and a filesystem that does not
report an inode table SHALL NOT refuse and SHALL NOT warn: that leg is not judged, no number is invented for it,
and the visible reading says the figure could not be read. When both paths resolve to one filesystem it SHALL be
judged once. The measurement MAY be replaced by a fixture (the `TEAM_MEMINFO_FILE` idiom) through
`TEAM_DISK_STATS_FILE` — rows `path<TAB>total_kb<TAB>avail_kb<TAB>itotal<TAB>ifree`, longest matching path prefix
wins, a path with no row is unreadable — so the leg is testable without a second filesystem.

The two thresholds and the fixture seam SHALL be rows of the project contract's schema (the `memory-and-deps`
`team_config_schema()` table): `TEAM_TMP_MIN_FREE_MB` class `apply`, kind `mb`, default `1024`;
`TEAM_TMP_MIN_FREE_INODES` class `apply`, kind `int`, default `100000`; both in the `delivery` group carrying the
`0` danger note their sibling floors carry, and `TEAM_DISK_STATS_FILE` a `refuse` test-knob row. The escape MUST be
reachable through the audited writer — `team config set <KEY> 0 --allow-danger` writes the contract, leaves its one
`result=ok` audit line and needs no hand-edit — and the `0` behind it SHALL keep the meaning the environment form
has today (that leg off, the other still judged).

When the floor passes, `team dispatch` SHALL print one capacity line carrying the measured readings — the RAM/swap
figures it judges plus, for each judged filesystem, its path, its resolution source where it is the temp root, and
its available bytes and free inodes — in the
pre-launch phase and in `--print`.

#### Scenario: Low free disk swap refuses the dispatch

- **GIVEN** `TEAM_MEMINFO_FILE` points at a fixture with 8000 MB MemAvailable and 300 MB free disk swap
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it exits non-zero and the reason names the free disk swap
- **AND** the same command with `TEAM_MIN_FREE_SWAP_MB=0` no longer refuses for that reason

#### Scenario: zram pages are not counted as headroom

- **GIVEN** `TEAM_SWAPFILE_PATH` points at a fixture whose free swap comes from `/dev/zram0` only
- **WHEN** `team ps` prints the capacity line
- **THEN** the disk-swap figure it uses for the floor is 0, and zram is reported separately as a warning

#### Scenario: A full temp root refuses the dispatch with its figures and its fix

- **GIVEN** `TEAM_DISK_STATS_FILE` gives the temp root 120 MB free of 15 GB with 40000 free inodes, and its row for
  the worktree is above both floors
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** it exits non-zero, names the temp root path, the free bytes and free inodes the fixture holds, and the
  thresholds they crossed, and prints a `修法：` line carrying `tmp-hygiene.sh --sweep`
- **AND** the same command with `TEAM_TMP_MIN_FREE_MB=0 TEAM_TMP_MIN_FREE_INODES=0` no longer refuses for that
  reason

#### Scenario: Plenty of disk allows the dispatch and prints the readings

- **GIVEN** the fixture holds 5 GB free and 2900000 free inodes for both the temp root and the worktree
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** it exits 0 and its capacity line names both paths with those measured availabilities and inode figures

#### Scenario: An unreadable filesystem is silent and never refuses

- **GIVEN** the fixture holds no row for the temp root while the worktree row is above both floors
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** it exits 0, no refusal or warning names a disk shortfall, and the capacity line does not print a number
  for the temp root (it says the figure could not be read)

#### Scenario: A filesystem without an inode table is judged on bytes only

- **GIVEN** the worktree row reports `itotal=0` with 5 GB free
- **WHEN** the dispatch runs
- **THEN** it exits 0 and the capacity line prints no inode figure for that filesystem
- **AND** with the same row's free bytes below the floor, the refusal names the bytes threshold and not the inode
  threshold

#### Scenario: The floor's escape hatch is reachable through the audited writer

- **GIVEN** a fixture contract that does not carry `TEAM_TMP_MIN_FREE_MB`, and a `TEAM_DISK_STATS_FILE` whose
  temp-root row is below the 1024 MB floor while its inode figure is above the inode floor
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs, then
  `team config set TEAM_TMP_MIN_FREE_MB 0 --allow-danger --yes` runs, then the same dispatch runs again
- **THEN** the first dispatch exits non-zero for the free-bytes floor, the write exits 0 and leaves the contract
  parseable with exactly one `result=ok` line in the config audit log, and the second dispatch exits 0 with that
  leg off while the inode leg is still judged

#### Scenario: The floor judges the resolved root, never a path it computed itself

- **GIVEN** a resolved temp root on a roomy filesystem and a `TEAM_DISK_STATS_FILE` whose row for the platform's
  `/tmp` is far below the floor
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** it exits 0, the capacity line names the resolved root and its source, and no refusal names `/tmp`
- **AND** with the fixture-mode shadow that points the floor back at the fixed `/tmp`, the same input refuses and
  names `/tmp` — so the check judges which path the floor read

#### Scenario: An unusable selected root is refused by name

- **GIVEN** a contract whose `TEAM_TMP_ROOT` names a path that does not exist, and then one that exists without
  write permission
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** it exits non-zero, names that path and its source, says why it is unusable and prints the `修法：` line,
  and it did not substitute the platform default

#### Scenario: A default root that does not exist yet is judged through its ancestor

- **GIVEN** the resolver's disk-backed default, with the directory absent and its parent's filesystem above the
  floors
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** it exits 0, the capacity line names the resolved default path, says it does not exist yet, and names the
  ancestor whose filesystem was measured
