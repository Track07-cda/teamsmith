## MODIFIED Requirements

### Requirement: Unfinished work is visible as pending wrap-up

`team status` (and the same data in `team digest`) SHALL report an agent's work that is not wrapped up — a dirty
worktree, commits not pushed, or a task whose report is missing — instead of reporting the agent as idle and done.

`team digest` SHALL additionally report records that are on disk but in no commit, for the main checkout **and**
for every worktree under `$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR`: each untracked file under the configured
`<docs>/reports` or `<docs>/reviews` path SHALL be named individually as `<agent>: <record path>` — the worktree
directory's name attributes it, and a file inside a report package is named by its own path — carrying the same
task-name suffix rule as the other ledger lines. The check SHALL be a reminder only: it MUST NOT change any
command's exit status and MUST NOT block a merge, and it MUST NOT report a dirty file outside those two record
paths (a stray file, a build scratch directory or a gate temporary artifact inside a worktree is silent). The
worktree dimension extends the one warning rather than adding a second section: one count and one list, capped for
display as today.

#### Scenario: A dirty worktree is pending wrap-up

- **GIVEN** an agent worktree with uncommitted changes and a recorded task
- **WHEN** `team status` runs
- **THEN** the agent appears in the pending-wrap-up section naming the worktree state

#### Scenario: An uncommitted record inside an agent worktree is named with its agent

- **GIVEN** an untracked `docs/team/reviews/T9.md` and an untracked `docs/team/reports/T9-dev.md` (plus one file
  in its package directory) inside `.worktrees/dev`, and no untracked record in the main checkout
- **WHEN** `team digest` runs
- **THEN** the `记录未入账` line reports the total number of those files and names each one with its agent prefix:
  `dev: docs/team/reviews/T9.md`, `dev: docs/team/reports/T9-dev.md`, and the package file's own
  `dev: docs/team/reports/…` path

#### Scenario: A dirty non-record inside a worktree is silent

- **GIVEN** an untracked `junk.txt` and an untracked build scratch directory inside `.worktrees/dev`, and no
  untracked record anywhere
- **WHEN** `team digest` runs
- **THEN** no `记录未入账` line is printed and neither path is named

#### Scenario: The reminder blocks nothing

- **GIVEN** the worktree fixture of the scenario above
- **WHEN** `team digest` runs
- **THEN** it exits 0 and the records are named only in the pending-wrap-up section

### Requirement: The ledger read path stays inside a git-call budget and its cache is an equivalence-checked view

On the gate's counting fixture — a repository with 12 board rows in the main worktree, two agent worktrees of 12
tasks each, three review records, and one untracked record inside one of the worktrees — `team board row <ID>`
MUST invoke `git` at most once (also when called from a subdirectory of the repository), and `team digest` MUST
invoke it at most 50 times; the same fixture with the cache disabled (`TEAM_SCAN_CACHE=0`) MUST invoke it more
than 50 times, so a passing count cannot come from a fixture too small to exercise the old shape. The
per-worktree record scan's `git status` calls are part of that count, and the scan MUST stay inside the same
budget. These budgets are asserted as call counts, not as a wall-clock threshold.

A cached or derived read MUST be a view over the same data, never a second source of truth: with the cache on and
off, `digest`, `status` and `__panel-data` MUST produce byte-identical output apart from live fields (timestamps
and capacity), and the gate SHALL assert that equality. Any future derived index MUST keep both properties — the
call budget and the equality with the direct parse.

#### Scenario: Board row makes at most one git call and really reads the row

- **WHEN** `team board row M50P1` runs from the repository root and again from `docs/team`
- **THEN** the counting wrapper records at most one `git` invocation in each run, and the output names `M50P1`

#### Scenario: Digest stays inside the budget and the fixture is not vacuous

- **GIVEN** the counting fixture, whose report set includes one untracked record inside an agent worktree
- **WHEN** `team digest` runs, and then the same command with `TEAM_SCAN_CACHE=0`
- **THEN** the cached run records at most 50 `git` invocations, really lists a report that exists only in a
  worktree, and names the untracked worktree record with its agent prefix; the direct run records more than 50,
  so the fixture would catch the old shape

#### Scenario: The cache is a view, not a source of truth

- **WHEN** `team digest`, `team status` and `team __panel-data --no-activity` run with the cache and with
  `TEAM_SCAN_CACHE=0`
- **THEN** each pair's outputs are identical after filtering their live fields (timestamp, capacity)
