## MODIFIED Requirements

### Requirement: The ledger read path stays inside a git-call budget and its cache is an equivalence-checked view

On the gate's counting fixture — a repository with 12 board rows in the main worktree, two agent worktrees of 12
tasks each, three review records, and one untracked record inside one of the worktrees — `team board row <ID>`
MUST invoke `git` at most once (also when called from a subdirectory of the repository), and `team digest` MUST
invoke it at most 50 times; the same fixture with the cache disabled (`TEAM_SCAN_CACHE=0`) MUST invoke it more
than 50 times, so a passing count cannot come from a fixture too small to exercise the old shape. The
per-worktree record scan's `git status` calls are part of that count, and the scan MUST stay inside the same
budget. These budgets are asserted as call counts, not as a wall-clock threshold.

A cached or derived read MUST be a view over the same data, never a second source of truth: with the cache on and
off, `digest`, `status` and `__panel-data` MUST produce byte-identical output apart from live fields — the
timestamps, the capacity line and the orphan seat-process census that
`seat-visibility#The reading is additive, bounded and read-only` defines — and the gate SHALL assert that
equality by filtering exactly those fields. The census is a host reading, never a cached view: it is read
directly in both runs and MUST NOT enter the scan cache. Any future derived index MUST keep both properties — the
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

#### Scenario: The census is filtered as a live field, and is never cached

- **GIVEN** a `team status` run whose output carries the orphan seat-process census, and a counting wrapper around
  the census's `/proc` reads
- **WHEN** the same command runs with the cache and with `TEAM_SCAN_CACHE=0`
- **THEN** the two outputs are identical once the timestamps, the capacity line and the census block are filtered,
  and both runs read the census directly (the census did not come from, and did not write to, the scan cache)
