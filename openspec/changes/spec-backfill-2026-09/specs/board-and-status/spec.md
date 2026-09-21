# board-and-status delta · 2026-09 回填：duplicate ids and the read budget (M48/M50)

## ADDED Requirements

### Requirement: A duplicate board id is refused by default and visible wherever the board is read

`team board add <ID> <title> …` MUST refuse an id that already names a row: it exits non-zero, names the existing
row's status and title, and names the two ways forward — a different id, or the explicit `--allow-dup` flag — plus
`board assign` as the entry for fixing an existing row's agent. A refused add MUST write nothing: the board file
MUST be byte-identical afterwards. With `--allow-dup` the row SHALL be appended and one audit line naming the id
and the flag SHALL be appended to `state/watchdog.log`.

Wherever the board is read, a duplicate MUST be visible: `team board ls`, `team digest` and `team doctor` SHALL
name the duplicated id with its row count (`×N`), and `doctor` SHALL keep checking for duplicates (reporting none)
on a board without them. The `init` template's placeholder rows and the risk table are not task rows and MUST NOT
be counted as duplicates.

#### Scenario: The refusal names the existing row and writes nothing

- **GIVEN** a board row `| T1.1 | Smoke task | dev | - | - | todo |`
- **WHEN** `team board add T1.1 "重复的一条" dev -` runs
- **THEN** it exits non-zero, prints the existing status `todo`, its title, `--allow-dup` and `board assign`, and
  the board file's checksum and its number of `T1.1` rows are unchanged

#### Scenario: The explicit flag writes a second row and an audit line

- **WHEN** the same command runs with `--allow-dup`
- **THEN** the board holds two `T1.1` rows and `state/watchdog.log` gained a line naming `T1.1` and `allow-dup`

#### Scenario: All three readers surface the duplicate, and only while it exists

- **GIVEN** a board holding two `T1.1` rows
- **WHEN** `team board ls`, `team digest` and `team doctor` run, and then the duplicate row is removed and they run
  again
- **THEN** the first three outputs name `T1.1 ×2` (doctor in its `BOARD 重复 ID` check), and the second three no
  longer report a duplicate while `doctor` still reports having checked it

#### Scenario: A freshly initialised board is not a duplicate report

- **WHEN** a project is initialised and `team board ls` runs on the empty board
- **THEN** no duplicate line appears (the template's placeholders and the risk table are not task rows)

### Requirement: The board addresses rows by id, and the agent column has its own entry

`team board assign <ID> <agent>` SHALL change only the agent column of every existing row carrying that id, keep
the row count and every other column unchanged, and MUST refuse an id that names no row or a missing agent without
writing. `team board set <ID> <status>` keeps addressing by id: every row carrying that id takes the new status —
historical duplicates included — so the two commands agree on what an id addresses.

#### Scenario: Assigning changes the agent column and nothing else

- **GIVEN** a board holding two `T1.1` rows
- **WHEN** `team board assign T1.1 reviewer` runs
- **THEN** both rows carry `reviewer` in the agent column, the row count is unchanged, and every other column is
  byte-identical to before

#### Scenario: An unknown id or a missing argument writes nothing

- **WHEN** `team board assign NOSUCH dev` and `team board assign T1.1` run
- **THEN** both exit non-zero naming the unknown id (or the missing argument) and the board file is unchanged

#### Scenario: Set still addresses every row with the id

- **GIVEN** the same two-row board
- **WHEN** `team board set T1.1 blocked` runs
- **THEN** both `T1.1` rows report `blocked`

### Requirement: The ledger read path stays inside a git-call budget and its cache is an equivalence-checked view

On the gate's counting fixture — a repository with 12 board rows in the main worktree, two agent worktrees of 12
tasks each, and three review records — `team board row <ID>` MUST invoke `git` at most once (also when called from
a subdirectory of the repository), and `team digest` MUST invoke it at most 50 times; the same fixture with the
cache disabled (`TEAM_SCAN_CACHE=0`) MUST invoke it more than 50 times, so a passing count cannot come from a
fixture too small to exercise the old shape. These budgets are asserted as call counts, not as a wall-clock
threshold.

A cached or derived read MUST be a view over the same data, never a second source of truth: with the cache on and
off, `digest`, `status` and `__panel-data` MUST produce byte-identical output apart from live fields (timestamps
and capacity), and the gate SHALL assert that equality. Any future derived index MUST keep both properties — the
call budget and the equality with the direct parse.

#### Scenario: Board row makes at most one git call and really reads the row

- **WHEN** `team board row M50P1` runs from the repository root and again from `docs/team`
- **THEN** the counting wrapper records at most one `git` invocation in each run, and the output names `M50P1`

#### Scenario: Digest stays inside the budget and the fixture is not vacuous

- **GIVEN** the counting fixture
- **WHEN** `team digest` runs, and then the same command with `TEAM_SCAN_CACHE=0`
- **THEN** the cached run records at most 50 `git` invocations and really lists a report that exists only in a
  worktree; the direct run records more than 50, so the fixture would catch the old shape

#### Scenario: The cache is a view, not a source of truth

- **WHEN** `team digest`, `team status` and `team __panel-data --no-activity` run with the cache and with
  `TEAM_SCAN_CACHE=0`
- **THEN** each pair's outputs are identical after filtering their live fields (timestamp, capacity)
