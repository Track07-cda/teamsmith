# board-and-status Specification

## Purpose

The ledger the PM runs on: what the board statuses mean, when a task may become `done`, and how `digest`/`status`
surface work that was delivered but not verified or not wrapped up. Why status is a promise:
`references/philosophy.md` (principle 2) and `references/protocol.md`.
## Requirements
### Requirement: The board status vocabulary is closed

`team board set <ID> <status>` SHALL accept only `todo`, `wip`, `review`, `done`, `blocked` and `dropped`; any other
word MUST be rejected with the allowed set and MUST leave the row unchanged.

#### Scenario: A typo cannot invent a status

- **GIVEN** a board row `| T1.1 | first task | dev | - | - | todo |`
- **WHEN** `team board set T1.1 shipped` runs
- **THEN** the command exits non-zero, prints the allowed statuses, and `team board row T1.1` still reports `todo`

#### Scenario: A legal status is written to the row

- **WHEN** `team board set T1.1 review` runs
- **THEN** `team board row T1.1` reports `review` and the rest of the columns are unchanged

### Requirement: `done` means landed and pushed

A task SHALL be marked `done` only after the review record says `PASS` **and** the task branch is an ancestor of the
protected branch **and** the protected branch is pushed. The PM verifies this with git (`git merge-base
--is-ancestor <branch> <protected>` must exit 0; `git status -sb` must not be ahead of the upstream) — status is not
evidence by itself.

#### Scenario: An unmerged branch cannot be done

- **GIVEN** task branch `task/T1.1-*` whose commits are not in the protected branch
- **WHEN** `git merge-base --is-ancestor task/T1.1-* <protected-branch>` runs
- **THEN** it exits 1, so the task must stay `review` (or `wip`) and must not be closed as `done`

#### Scenario: A merged and pushed branch may be done

- **GIVEN** the same branch after `merge --squash` + commit + push to the protected branch, and a review record with
  `PASS`
- **WHEN** `git merge-base --is-ancestor <the squash commit> <protected-branch>` runs and the branch is pushed
- **THEN** it exits 0 and `team board set <ID> done` may be used

### Requirement: Delivered-but-unverified work is detected

`team digest` SHALL list real task reports that have no review record as pending verification, and it MUST NOT list
non-task reports (milestone or closure notes) as pending work.

#### Scenario: A task report without a review is pending

- **GIVEN** `docs/team/reports/T1.1-dev.md` exists and `docs/team/reviews/T1.1.md` does not
- **WHEN** `team digest` runs
- **THEN** the pending-verification section names `T1.1`

#### Scenario: A milestone note is not pending work

- **GIVEN** `docs/team/reports/P2-closure.md` exists with no matching review record and no board row
- **WHEN** `team digest` runs
- **THEN** it is not counted as pending verification

### Requirement: Unfinished work is visible as pending wrap-up

`team status` (and the same data in `team digest`) SHALL report an agent's work that is not wrapped up — a dirty
worktree, commits not pushed, or a task whose report is missing — instead of reporting the agent as idle and done.

#### Scenario: A dirty worktree is pending wrap-up

- **GIVEN** an agent worktree with uncommitted changes and a recorded task
- **WHEN** `team status` runs
- **THEN** the agent appears in the pending-wrap-up section naming the worktree state

### Requirement: A failed step does not leave a false status

A dispatch that is refused (guards, capacity, model limit, template contract) MUST NOT set the task to `wip`, and a
review whose verdict is not `PASS` MUST NOT lead to `done`; the status a task had before the failed step MUST remain
observable on the board.

#### Scenario: A refused dispatch leaves the board alone

- **GIVEN** board row `| T1.1 | … | todo |` and a dispatch that the model-concurrency guard refuses
- **WHEN** `team board row T1.1` runs afterwards
- **THEN** the status is still `todo`

#### Scenario: A failing review is not a pass

- **GIVEN** a review whose gate output exits non-zero
- **WHEN** `team review T1.1 --dir <checkout>` has finished
- **THEN** the record's verdict is `FAIL`, the command exited non-zero, and the board row is not `done`

### Requirement: Closing a task hands the git step back to the PM

`team close <ID> [--status <s>] [--keep-window]` SHALL close the agent's window (unless `--keep-window`), clear the
recorded task for that id, write the requested status through the same closed vocabulary, and, when the worktree is
still on a task branch, MUST print the exact `git switch --detach <protected>` command for the PM instead of
touching git itself.

#### Scenario: Close releases the window and keeps the evidence

- **GIVEN** a dispatched agent window `dev` and `docs/team/reviews/T1.1.md`
- **WHEN** `team close T1.1` runs
- **THEN** the window `dev` is gone, the review record still exists, and the board row is `done`

#### Scenario: The leftover branch is reported, not switched

- **GIVEN** the agent worktree is still on `task/T1.1-*`
- **WHEN** `team close T1.1` runs
- **THEN** the output contains a `git ... switch --detach <protected-branch>` command to run, and the worktree's
  branch is unchanged by the command

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

