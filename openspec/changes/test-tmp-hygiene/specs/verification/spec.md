## ADDED Requirements

### Requirement: A fixture's temp root resolves TMPDIR, carries an owned name, and is reclaimed

Every fixture under `skills/teamsmith/tests/**` that creates a temp root SHALL create it as a directory directly
under the resolved temp root — `${TMPDIR:-/tmp}`, with no fixture hardcoding `/tmp` in the template — and SHALL
name it inside the one owned family: `teamsmith-<kind>.XXXXXX` for a fixture's own root, `review-<ID>` for the PM's
independent checkout. The owned family is declared in exactly one place (`skills/teamsmith/tests/lib/tmp-root.sh`),
and that helper is the only creator: it writes the owner marker inside the root (the creating pid, that process's
start time, the kind and the run id) and appends the root to the run ledger. The root SHALL be reclaimed on normal
exit **and** on `INT`/`TERM`; it SHALL survive only when the caller asked for it (`TEAM_TMP_KEEP=1`, which prints
the path). A fixture that spawns a process outliving its own step (an anchor tmux session, a `sleep`) SHALL record
that pid at spawn time and, in cleanup, signal only recorded pids — never a process matched by name or command line
(why: `references/protocol.md` on the safety model, and D37 in `docs/team/DECISIONS.md`).

#### Scenario: The root resolves TMPDIR and is gone after the run

- **GIVEN** an empty private directory `D` and the inventory `bash skills/teamsmith/tests/tmp-hygiene.sh --status` taken before the run
- **WHEN** `TMPDIR=D bash skills/teamsmith/tests/config-cli.sh` finishes
- **THEN** the run's root existed under `D` while it ran, `D` holds no `teamsmith-config-cli.*` directory after it, and the `/tmp` inventory gained no new root

#### Scenario: SIGTERM reclaims the root and the fixture's own processes

- **GIVEN** a fixture started with `TMPDIR=D` whose root exists and that has recorded an anchor pid
- **WHEN** the fixture is sent `TERM` mid-run
- **THEN** the root is gone within the fixture's grace period and the recorded anchor pid no longer exists

#### Scenario: A kept root is printed, never silently kept

- **WHEN** `TEAM_TMP_KEEP=1 TMPDIR=D bash skills/teamsmith/tests/config-cli.sh` finishes
- **THEN** the root is still under `D`, the run printed its path, and `--status` lists it as kept rather than as a leak

#### Scenario: Only recorded pids are signalled

- **GIVEN** a fixture whose anchor `sleep` pid is recorded, and an unrelated `sleep` started by the caller whose command line carries the same argument
- **WHEN** the fixture's cleanup runs
- **THEN** the recorded pid was signalled, and the caller's unrelated `sleep` is still alive — the cleanup matched no command line

### Requirement: Killed-run residue is identifiable and reclaimable through one entry

`bash skills/teamsmith/tests/tmp-hygiene.sh` SHALL be the fixtures' single temp-root entry: `--status` (a read-only
inventory: per root the path, size, file count, age, recorded owner and occupancy, plus the resolved temp root's
free and total bytes and inodes), `--lint` (the static ownership check of the fixtures' sources) and `--sweep`
(the reclaim). `--status` SHALL also list the owned family's entries that are not directories — the product's own
`teamsmith-inotify-probe.*` and `teamsmith-review-queue.*` leftovers, and the gate's dot-prefixed incident
diagnostics — as *not a root*, so no entry in the family is invisible; none of them is ever a `--sweep` candidate.
Residue that outlives a killed run SHALL be identifiable without guessing: the root's base name is
in the owned family, and a root created through the shared helper carries the owner marker inside it.
`--sweep` SHALL reclaim a root only when it is older than the age threshold (`--age <minutes>`, default 30,
`TEAM_TMP_SWEEP_AGE`) **and** no process holds it (see the next requirement); `--dry-run` SHALL print the same
inventory and delete nothing. Exit status: `0` — every candidate reclaimed or skipped by a printed rule; `3` —
refused, nothing deleted, because a safety precondition could not be established. Dot-prefixed diagnostics (the
smoke's incident files) are evidence: `--status` lists them with their age and `--sweep` never deletes them.

#### Scenario: A SIGKILLed run's residue is listed and reclaimed

- **GIVEN** a fixture run with `TMPDIR=D`, killed with `KILL` once its root exists, so the root survives it
- **WHEN** `TMPDIR=D bash skills/teamsmith/tests/tmp-hygiene.sh --status` and then `--sweep --age 0` run
- **THEN** `--status` lists that root with its size, file count and recorded owner and does not count it as occupied, and `--sweep --age 0` removes it, printing the reclaimed total

#### Scenario: A young root is skipped, not deleted

- **GIVEN** a root under `D` created a minute ago, with the default age
- **WHEN** `--sweep` runs
- **THEN** the root is intact and printed as skipped for its age

#### Scenario: A proof that cannot be established deletes nothing

- **GIVEN** the occupancy scan made unavailable (the fixture-mode knob, with no `lsof` on `PATH`)
- **WHEN** `--sweep --age 0` runs
- **THEN** it exits 3, every candidate is intact, and the message names the mechanism that could not be used

#### Scenario: Family entries that are not roots are visible and never swept

- **GIVEN** a `teamsmith-inotify-probe.*` file, a `teamsmith-review-queue.*` file and a dot-prefixed
  `.teamsmith-smoke-diag.*` file beside a stale `teamsmith-smoke.*` directory in the resolved temp root
- **WHEN** `--status` and then `--sweep --age 0` run
- **THEN** `--status` lists all four, naming the three files as not a root, the sweep removes only the stale
  directory, and the three files are still there afterwards

### Requirement: The sweep proves occupancy and touches this project's own roots only

`--sweep` SHALL consider only directories whose base name starts with `teamsmith-` or `review-`; any other path,
and any dot-prefixed name, MUST NOT be a candidate. For every candidate it SHALL first prove that no process holds
the root — no live process whose current directory, an open file or its executable lies inside it, established by
scanning the running processes (`/proc` on Linux; `lsof` as an available cross-check) — and a root that is held
MUST be skipped and printed as occupied whatever its age. A candidate that is a git worktree registered with the
main repository MUST NOT be removed with `rm -rf`: the sweep SHALL print the exact
`git -C <root> worktree remove --force <path>` command instead — the skill runs no git write operations
(`references/protocol.md`) — and for a registration whose directory no longer exists it SHALL print the
`git -C <root> worktree prune` remedy. A `review-<ID>` root is a checkout, not evidence: before reclaiming it the
sweep SHALL print `docs/team/reviews/<ID>.md` and its committed state in the main worktree, and MUST refuse
(exit 3, nothing deleted) when that record is untracked or has uncommitted changes. The inventory of everything it
will reclaim — path, size, file count, with the total — SHALL be printed before the first deletion, and the gate's
own lock `${TMPDIR:-/tmp}/teamsmith-smoke.lock` and its `.holder` MUST never be candidates or deletions.

#### Scenario: An occupied root is skipped, whatever its age

- **GIVEN** a fixture started with `TMPDIR=D` whose root exists and whose process is alive
- **WHEN** `TMPDIR=D bash skills/teamsmith/tests/tmp-hygiene.sh --sweep --age 0` runs
- **THEN** the root is intact, printed as occupied with the holder's pid, and the exit status is 0

#### Scenario: A live orphan is occupancy, not a free root

- **GIVEN** a root whose recorded owner pid is dead and whose only holder is a process with its current directory inside the root (the shape a killed run leaves)
- **WHEN** `--sweep --age 0` runs
- **THEN** the root is skipped and printed as occupied, and it is not deleted

#### Scenario: A registered worktree is never removed by the sweep

- **GIVEN** a scratch repository with a worktree registered at `D/review-T1.1` whose directory exists
- **WHEN** `--sweep --age 0` runs
- **THEN** the directory is still there, its registration is unchanged, and the output carries the `git -C … worktree remove --force …` line

#### Scenario: A review checkout without a committed record is refused

- **GIVEN** a `D/review-T1.1` root and `docs/team/reviews/T1.1.md` missing (or modified but uncommitted) in the main worktree
- **WHEN** `--sweep --age 0` runs
- **THEN** it exits 3, nothing was deleted, and the message names the record path and its state

#### Scenario: The gate lock is reported, never swept

- **GIVEN** `${TMPDIR:-/tmp}/teamsmith-smoke.lock` and its `.holder` alongside a stale `teamsmith-smoke.*` directory
- **WHEN** `--status` and `--sweep --age 0` run
- **THEN** the lock and its holder still exist (reported as not being roots), and only the stale directory is reclaimed

### Requirement: The gate reports its own temp-root usage and asserts nothing it created outlives it

`bash skills/teamsmith/tests/smoke.sh` SHALL print, at its start and again with its result summary — also when the
run fails — one line carrying its own root's path, its size and its file count, and it SHALL assert that every root
the run created is gone: the fixtures' roots are recorded in a run ledger outside the roots, and at the end of the
run (FAST mode included) a surviving root that the run did not declare kept SHALL be a failing assertion naming
that path and its size. A root kept on purpose (`TEAM_TMP_KEEP=1`) SHALL be printed as kept and MUST NOT be
presented as reclaimed. The assertion SHALL be falsifiable: with the fixture-mode knob set, a nested fixture skips
its own cleanup, and the gate MUST then report that root as a failure — the same knob is a red side in
`tmp-hygiene.sh --self-test`.

#### Scenario: A clean round prints its usage and leaves nothing behind

- **GIVEN** the inventory taken before the run
- **WHEN** `TMPDIR=D TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` finishes green
- **THEN** the start and end lines name the run's root with its size and file count, and the inventory taken after the run holds no root that the run created

#### Scenario: A leaked nested root is a red assertion

- **GIVEN** the fixture-mode knob that makes a nested fixture skip its cleanup
- **WHEN** the gate runs
- **THEN** it fails, and the failure names the surviving root's path and its size instead of reporting a clean round

#### Scenario: A kept root is declared, not claimed as reclaimed

- **WHEN** the gate runs with `TEAM_TMP_KEEP=1`
- **THEN** the output prints the root as kept, and no line claims the round left nothing behind

### Requirement: The fixtures' temp-root ownership rule is enforced by a static check

`bash skills/teamsmith/tests/tmp-hygiene.sh --lint` SHALL check every `mktemp -d` root template in
`skills/teamsmith/tests/**` and exit `1` naming `<file>:<line>` when a template hardcodes an absolute directory
other than the resolved temp root (`${TMPDIR:-/tmp}`) or names its root outside the owned family; a nested root
created inside an existing root (`$TMP/…`) is exempt. The check SHALL run inside the correctness gate, and the gate
SHALL go red when a hardcoded or foreign-named root reappears: the red side is a fixture-mode copy of a fixture with
one template rewritten to a literal `/tmp/…` path.

#### Scenario: A hardcoded root is a finding, at its line

- **GIVEN** a copy of a fixture whose root template was rewritten to `mktemp -d /tmp/whatever.XXXXXX`
- **WHEN** `--lint` runs against that copy
- **THEN** it exits 1 and the finding names the file and the line of the template

#### Scenario: The migrated tree is clean

- **WHEN** `bash skills/teamsmith/tests/tmp-hygiene.sh --lint` runs on the tree this change lands in
- **THEN** it exits 0 and prints how many root templates it checked
