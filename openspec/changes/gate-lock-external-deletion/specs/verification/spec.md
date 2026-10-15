## MODIFIED Requirements

### Requirement: A fixture's temp root resolves TMPDIR, carries an owned name, and is reclaimed

Every fixture under `skills/teamsmith/tests/**` that creates a temp root SHALL create it as a directory directly
under the resolved temp root — `${TMPDIR:-/tmp}`, with no fixture hardcoding `/tmp` in the template — and SHALL
name it inside the one owned family **and** carry the project it belongs to: `teamsmith-<kind>-<ns>.XXXXXX` for a
fixture's own root, `review-<ID>` for the PM's independent checkout. The namespace token SHALL be derived from the
repository the skill lives in, resolved to its **main** checkout, so that every worktree of one project shares one
namespace and two projects installed on the same machine cannot collide; it SHALL be stable across runs and
readable to a human reading the shared temp root, and the owner marker and the run ledger SHALL both carry it
(`ns=<token>`), beside the repository identity they already carry. The owned family is declared in exactly one place
(`skills/teamsmith/tests/lib/tmp-root.sh`), and that helper is the only creator: it writes the owner marker inside
the root (the creating pid, that process's start time, the kind, the run id and the namespace) and appends the root
to the run ledger. Nothing a run creates for itself SHALL land directly under the resolved temp root under a name
another project's cleanup would plausibly claim: every per-run artifact created directly there is either
dot-prefixed (the run ledger, the pid file, the incident diagnostics) or carries this project's namespace (roots,
the queue markers, the section-filter copy). The root SHALL be reclaimed on normal exit **and** on `INT`/`TERM`; it
SHALL survive only when the caller asked for it (`TEAM_TMP_KEEP=1`, which prints the path). A fixture that spawns a
process outliving its own step (an anchor tmux session, a `sleep`) SHALL record that pid at spawn time and, in
cleanup, signal only recorded pids — never a process matched by name or command line (why:
`references/protocol.md` on the safety model, and D37 in `docs/team/DECISIONS.md`).

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

#### Scenario: The root carries the project's namespace, and no artifact of the run is inside the flat family's reach

- **GIVEN** a run on a machine where another installed project's cleanup is written against the pre-change flat
  family — a name-prefix pattern of the resolved temp root, the shape that deleted a live run's root and lock
- **WHEN** the run creates its root and its per-run markers, and a fixture lists the entries it created directly
  under the resolved temp root
- **THEN** the root's name carries this project's namespace beside its kind, the marker and the run ledger carry
  the same namespace, every other entry the run creates for itself directly there — its queue marker, its
  section-filter copy, its ledger and its diagnostics — is dot-prefixed or namespaced, and none of them matches
  that flat-family pattern
- **AND** the one entry the run still creates under the published family name, the gate's published lock path, is
  the exception the lock requirement governs: its loss is reported and recorded rather than silent, and the mutex
  the run rests on is the dot-prefixed companion instead
- **AND** with the fixture-mode shadow that creates the root under the pre-change flat name, that pattern matches
  the run's own working root and the assertion fails naming the path; restoring the namespaced template makes it
  pass again, so the check judges the naming rule rather than a hardcoded string

#### Scenario: One project's namespace is not another's, and a worktree shares its project's

- **GIVEN** the same skill checked out twice — two worktrees of one repository, and a second repository beside them
- **WHEN** each of the three computes its namespace and creates one root
- **THEN** the two worktrees produce the same namespace and the second repository a different one, each root's
  marker carries the namespace it was created with, and `--status` attributes the second repository's root to a
  foreign repository rather than to this project's candidates

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
will reclaim — path, size, file count, with the total — SHALL be printed before the first deletion. The gate's lock
paths MUST never be candidates or deletions: the published lock path (what `TEAM_SMOKE_LOCK` names, by default
`${TMPDIR:-/tmp}/teamsmith-smoke.lock`), the machine lock the run actually holds (the dot-prefixed companion of
that path), and the run records beside the companion. `--status` SHALL list them with the role each one plays, so
that an operator reading the shared temp root can tell the run's mutex from its compatibility claim, and a root
attributed to another repository SHALL stay visible and untouched rather than being mistaken for this project's.

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

- **GIVEN** the published lock path, its machine-lock companion and the companion's run records, alongside a stale
  `teamsmith-smoke.*` directory
- **WHEN** `--status` and `--sweep --age 0` run
- **THEN** all three still exist, each printed as not being a root and with its role (published claim, run mutex,
  run records), and only the stale directory is reclaimed

### Requirement: The fixtures' temp-root ownership rule is enforced by a static check

`bash skills/teamsmith/tests/tmp-hygiene.sh --lint` SHALL check every temp-root template under `skills/teamsmith/**`
that resolves directly under the resolved temp root (`${TMPDIR:-/tmp}`) and exit `1` naming `<file>:<line>` when a
template hardcodes an absolute directory other than the resolved temp root, when a root template names its root
outside the owned family or without this project's namespace, or when a per-run template creates an entry directly
under the resolved temp root whose name is neither dot-prefixed nor namespaced. The rule the check enforces is the
one that keeps a foreign project's cleanup from matching a live run, so it covers the fixtures **and** the
product's own temp templates, not only the fixtures; the check SHALL skip its own source and any nested root
created inside an existing root (`$TMP/…`). The check SHALL run inside the correctness gate, and the gate SHALL go
red when a hardcoded, foreign-named or namespace-free template reappears: the red side is a fixture-mode copy of a
source with one template rewritten to a literal `/tmp/…` path, and a second copy whose template keeps the family
name but drops the namespace.

#### Scenario: A hardcoded root is a finding, at its line

- **GIVEN** a copy of a fixture whose root template was rewritten to `mktemp -d /tmp/whatever.XXXXXX`
- **WHEN** `--lint` runs against that copy
- **THEN** it exits 1 and the finding names the file and the line of the template

#### Scenario: A template that cannot be attributed to a project is a finding

- **GIVEN** a copy of a source whose template keeps the owned family's prefix but carries no namespace, and a copy
  of a source whose per-run template sits directly under the resolved temp root with neither a namespace nor a
  leading dot
- **WHEN** `--lint` runs against each copy
- **THEN** both exit 1, and each finding names the file and the line and says whether the name is outside the
  family or not attributable to a project

#### Scenario: The migrated tree is clean

- **WHEN** `bash skills/teamsmith/tests/tmp-hygiene.sh --lint` runs on the tree this change lands in
- **THEN** it exits 0 and prints how many templates it checked

## ADDED Requirements

### Requirement: The gate's lock is identified, and losing it stops the run loudly

The run SHALL be able to recognise the lock it holds, and it SHALL notice when the file at that path is no longer
that lock. The mutex is the **machine lock**: a companion derived from the published lock path — the
same directory, a leading dot, the published base name plus `.machine`, so the default published
`…/teamsmith-smoke.lock` gives `…/.teamsmith-smoke.lock.machine` — which puts the mutex out of reach of a cleanup
written against the published family. The claim SHALL take the published path first and the companion second, in that order and in every
implementation, so that a writer predating this rule, which takes only the published path, still serialises with
the run and the run with it. The claim SHALL record the identity of the file it holds — the `dev:ino` of the
descriptor it locked when it can read it from the process that holds it, and otherwise the identity of the path it
resolved, saying which of the two it used — SHALL refresh the companion's modification time, and MUST NOT remove or
rename a lock file it holds: a waiter blocked on an inode that is unlinked goes on to "acquire" a lock nobody else
can see, which is the failure this requirement exists to prevent. Lock files therefore persist, and the
compatibility claim on the published path is re-established by the next claim rather than cleaned up.

While it runs, the run SHALL verify the two premises it stands on — its working root is alive, and the companion is
still the file at its path — on the same bounded cadence and through the same one-named-line-and-stop path the
fixture-root sentinel already uses. When the companion is gone it SHALL say the lock is gone; when the path holds a
different file it SHALL say the lock was replaced and name both identities. Either way it SHALL write the evidence
outside the working root (the moment, the expected and the observed identity, the last section reached, and the
observed holders of the lock paths), keep the scene, and stop the run at a safe point with the documented "the gate
stopped itself" status — the run MUST NOT go on to print a judgement on the code, and a lost lock MUST NOT be
reported as a pass. Losing the published path costs only the pre-change compatibility: it SHALL be named and
recorded without stopping the run, because the mutex is the companion.

Before it starts work, a run that acquired the lock SHALL check the live top-level registrations for that lock: a
live run recording a different identity for the same companion means mutual exclusion is already broken, and the
acquiring run SHALL name that run and both identities and MUST NOT run its suite. A waiter SHALL re-resolve the path
while it queues and SHALL print, with both identities, when the file it is waiting on is unlinked or replaced,
before it continues to wait; the holder record it prints is read from the companion's registrations, and a record
left by a pre-change writer — which names neither kind, seat, bound nor identity — SHALL be printed with the fields
it does carry, marked as an older version's, and `?` for what it does not. Every machine-level lock the suite takes
SHALL be claimed and watched this way, the performance suite's own lock included. None of this SHALL add a verdict
token or an exit status: the stop uses the status the queue and the fixture-root sentinel already use, and a review
whose gate run loses its lock SHALL record that the gate did not complete and MUST NOT report `PASS`.

#### Scenario: A deleted lock stops its holder loudly, and the shadow keeps it running

- **GIVEN** a run holding the companion lock with a fixture section that stays alive long enough to be observed
- **WHEN** the companion file is unlinked from outside the run
- **THEN** within the guard's bounded cadence the run prints one line naming the lock and saying it is gone, writes
  the evidence outside its working root carrying the expected and the observed identity, stops at a safe point with
  the "the gate stopped itself" status, and prints no line judging the code
- **AND** with the fixture-mode shadow that disables the guard the same run keeps going and prints no such line, so
  the assertions fail — restoring the guard makes them pass, which is what makes them evidence rather than a claim

#### Scenario: A replacement is caught as a replacement, with both identities

- **GIVEN** the same scene, and a lock file recreated at the companion's path — both by unlinking and recreating,
  and by renaming a fresh file over it
- **WHEN** the run's guard observes the path
- **THEN** the run names the lock as replaced, prints the identity it holds and the identity now at the path, and
  stops exactly as in the deletion case, distinguishable from it in the printed line and in the evidence
- **AND** the shadow without the guard keeps the run going, so the replacement assertion has a red side too

#### Scenario: A clean run claims no broken lock, and never unlinks the lock it holds

- **GIVEN** two runs in sequence on a private lock, with the second starting after the first has exited
- **WHEN** both finish normally
- **THEN** neither prints a lock-identity line, both carry their normal result line and exit status, the companion's
  file is the same file before and after each run (no holder removed or renamed the lock it held), and the
  published path still exists for a pre-change writer to take

#### Scenario: A second run refuses to start while a live run records a different identity

- **GIVEN** a run holding the companion whose registration records identity A, and the companion at that path
  replaced so the path now holds identity B
- **WHEN** a second run acquires the lock at the path
- **THEN** it names the live run, its seat and worktree, and both identities, states that mutual exclusion is
  broken, and does not run its suite — the "the gate stopped itself" status with no result line
- **AND** with the fixture-mode shadow that skips the registration check the second run runs its suite, so the
  refusal is the check's doing and not a coincidence

#### Scenario: A waiter whose lock path changes says so instead of waiting on a dead inode

- **GIVEN** a second run queued on a companion held by a first run
- **WHEN** the companion at that path is unlinked and replaced while the second run waits
- **THEN** the waiter prints both identities and that the file it was waiting on changed, then re-resolves and
  continues under the same bounded cap, and a record left only by a pre-change writer is printed as an older
  version's with `?` for the fields it does not carry rather than `holder unknown`

#### Scenario: A review whose gate loses its lock does not pass

- **GIVEN** `team review` running its gates while the companion it holds is removed from outside
- **WHEN** the run ends
- **THEN** its record states that the gate did not complete, naming the lost lock, the verdict is not `PASS`, and
  the queue accounting keys and the closed verdict token set are unchanged
