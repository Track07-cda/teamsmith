# tmp-root-on-disk · verification（delta）

Base text: `openspec/specs/verification/spec.md`. Every block below replaces exactly one requirement with the
same title; the sentences a change does not need are carried over word for word.

## MODIFIED Requirements

### Requirement: A fixture's temp root resolves TMPDIR, carries an owned name, and is reclaimed

Every fixture under `skills/teamsmith/tests/**` that creates a temp root SHALL create it as a directory directly
under **the one resolved temp root** — the path the product library's single resolver returns (see
`One resolution decides every temp path, and it says how it decided`), with no fixture and no product call site
computing a base of its own — and SHALL
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

The resolved root's own directory in the resolver's default leg belongs to the project: the creator makes it
(mode `0700`) when it is absent, and it is the only directory the creator MAY make. A root selected explicitly
(`TEAM_TMP_ROOT` in the project contract, or `TMPDIR` in the environment) MUST already exist and be a writable
directory; when it does not, the failure SHALL name that path, the reason it is unusable and the `修法：` line that
fixes it, and MUST NOT fall back to any other root — a silent fall back to the platform default is the failure this
requirement forbids, not the failure it tolerates.

Every surface that prints the resolved root SHALL print how it was resolved (`source=tmpdir`, `source=config`,
`source=default`), and when both `TMPDIR` and `TEAM_TMP_ROOT` are set to different paths it SHALL say once which one
won and that the other was not used: a divergence between a project's pin and the invoking process's own choice is
allowed, being silent about it is not.

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

#### Scenario: With nothing set, the default root is on disk and not on the memory-backed filesystem

- **GIVEN** a host whose `/tmp` is memory-backed and whose `/var/tmp` is a writable directory on disk, and an
  environment and a contract that set neither `TMPDIR` nor `TEAM_TMP_ROOT`
- **WHEN** a fixture creates its root and its cleanup runs
- **THEN** the root lay under `/var/tmp/teamsmith-<ns>` while it ran, it is gone afterwards, and every surface that
  printed it said `source=default`
- **AND** nothing of the run was created under `/tmp`

#### Scenario: The process's own TMPDIR wins, and the pin's loss is printed rather than silent

- **GIVEN** a contract carrying `TEAM_TMP_ROOT=P` and an environment carrying `TMPDIR=D` with `P` and `D` two
  different directories
- **WHEN** a fixture creates its root and the surface prints the resolution
- **THEN** the root is under `D` and the line says `source=tmpdir` while naming `P` as configured but not used
- **AND** with `TMPDIR` unset, the same contract puts the root under `P` with `source=config`

#### Scenario: An unusable selected root fails by name, and nothing falls back

- **GIVEN** `TEAM_TMP_ROOT` naming a path that does not exist, and then a path that exists but is not writable
- **WHEN** a fixture creates its root
- **THEN** each run fails naming that path, the reason it is unusable and a `修法：` line, nothing was created under
  `/tmp` or under the platform default, and no line claims the run used a different root

### Requirement: Killed-run residue is identifiable and reclaimable through one entry

`bash skills/teamsmith/tests/tmp-hygiene.sh` SHALL be the fixtures' single temp-root entry: `--status` (a read-only
inventory: the resolved root **with its resolution source**, per root the path, size, file count, age, recorded
owner and occupancy, plus the resolved root's
free and total bytes and inodes, or a statement that a figure cannot be read, plus — when the resolved root is not
the previous default `${TMPDIR:-/tmp}` — how many family directories remain directly under that previous default and
the one command that reclaims them, printed and never executed), `--lint` (the static ownership check of the
fixtures' sources) and `--sweep`
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
One invocation of `--sweep` SHALL work on exactly one base — the resolved root it prints — so reclaiming the
residue of a previous default is that same command with the previous default selected explicitly, never a second
candidate rule and never a second sweep implementation.

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

#### Scenario: Residue under the previous default is visible and one command away

- **GIVEN** a stale `teamsmith-smoke.*` directory directly under `${TMPDIR:-/tmp}` while the resolved root is the
  disk-backed default, so the sweep's base is not that directory's base
- **WHEN** `--status` runs, and then `--sweep --age 0` runs against the resolved base
- **THEN** `--status` counts that directory, names the previous default and prints the exact command that reclaims it
  (`TMPDIR=/tmp bash skills/teamsmith/tests/tmp-hygiene.sh --sweep …`), the sweep against the resolved base does
  not touch it, and the printed command reclaims it when run

### Requirement: The fixtures' temp-root ownership rule is enforced by a static check

`bash skills/teamsmith/tests/tmp-hygiene.sh --lint` SHALL check every temp-root template under `skills/teamsmith/**`
that resolves directly under the resolved temp root (the path the one resolver returns) and exit `1` naming
`<file>:<line>` when a
template hardcodes an absolute directory other than the resolved temp root, when a root template names its root
outside the owned family or without this project's namespace, or when a per-run template creates an entry directly
under the resolved temp root whose name is neither dot-prefixed nor namespaced. It SHALL also exit `1`, naming
`<file>:<line>`, when a template or a path expression derives the temp root itself instead of calling the one
resolver — `${TMPDIR:-/tmp}`, `${TMPDIR}`, a JS runtime's equivalent of the same fallback, or a `mktemp` template
built from a literal `/tmp/…` — because a second derivation is a second answer, and two answers is how a cleaner and
a gate come to disagree about the base. The resolver's own definition and the creator's delegation to it are the
only exemptions; the check SHALL skip its own source and any nested root
created inside an existing root (`$TMP/…`). The rule the check enforces is the
one that keeps a foreign project's cleanup from matching a live run, so it covers the fixtures **and** the
product's own temp templates, not only the fixtures; the check SHALL run inside the correctness gate, and the gate
SHALL go red when a hardcoded, foreign-named, namespace-free or self-computed template reappears: the red sides are
a fixture-mode copy of a
source with one template rewritten to a literal `/tmp/…` path, a second copy whose template keeps the family
name but drops the namespace, and a third copy that computes the base inline beside the resolver.

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

#### Scenario: A second derivation of the base is a finding

- **GIVEN** a copy of the tree in which one product call site resolves its own base with `${TMPDIR:-/tmp}` while the
  resolver answers the disk-backed default
- **WHEN** `--lint` runs against that copy
- **THEN** it exits 1 and the finding names that file and line as a self-computed temp root, and the untouched tree
  exits 0

#### Scenario: The migrated tree is clean

- **WHEN** `bash skills/teamsmith/tests/tmp-hygiene.sh --lint` runs on the tree this change lands in
- **THEN** it exits 0 and prints how many templates it checked

## ADDED Requirements

### Requirement: One resolution decides every temp path, and it says how it decided

The order that decides the temp root SHALL be implemented once, in the product library
(`skills/teamsmith/scripts/lib/common.sh`), and every surface that needs the root SHALL call it: the fixtures'
creator, the gate's own work root and its incident diagnostics, the cleaner's base, the dispatch floor's judged path
and that path's label and remedy line, `team doctor`'s headroom row, the console's data read, and every per-run
template that lands directly under the root. The order SHALL be: `TMPDIR` when the invoking process sets it to a
non-empty value, else `TEAM_TMP_ROOT` when the project's contract sets one, else the platform's persistent default —
`/var/tmp/teamsmith-<ns>` where `/var/tmp` is a writable directory, `/tmp` otherwise — and no second implementation
of that order MAY exist. The platform default SHALL be a directory on a filesystem that survives the run's memory
pressure: on the maintainer host `/tmp` is a 15 GB memory-backed filesystem (78 % full: 3.3 GB and the inode table
itself were what ran out during the incident behind the `test-tmp-hygiene` change) while `/var/tmp` sits on the disk
with 228 GB free, so a fixture writing under `/tmp` spends the same pool the OOM killer reads. A surface that prints
the root SHALL print its source, and a read-only surface that meets a not-yet-created default SHALL judge the
nearest existing ancestor, name it, and create nothing; the creator and the dispatch floor, which write, SHALL
refuse by name instead (why: `skills/teamsmith/references/troubleshooting.md`, and the `test-tmp-hygiene` change's
`design.md` for the measured incident).

#### Scenario: Every surface reports the same base and the same source

- **GIVEN** one contract and environment, and a run that creates a root
- **WHEN** the creator, the cleaner's `--status`, the gate's start line and `team doctor` each report the root
- **THEN** all four name the same path and the same source, and the run ledger, pid file, queue marker,
  section-filter copy and incident diagnostics all lie directly under that path

#### Scenario: A surface that composed its own base is caught by the disagreement

- **GIVEN** the fixture-mode shadow in which one of those surfaces derives `${TMPDIR:-/tmp}` itself while the
  resolver answers the disk-backed default
- **WHEN** the check compares the reported bases
- **THEN** it fails naming both paths and the surface that disagreed, and with the shadow reverted it passes — so the
  check judges agreement between surfaces, not a hardcoded path

#### Scenario: A not-yet-created default is judged through its ancestor and never created by a read

- **GIVEN** a resolved default root that does not exist yet
- **WHEN** `team doctor`, `--status` and the console's data read report it
- **THEN** each names the resolved path, says the directory does not exist yet and which existing ancestor's
  filesystem was judged, invents no figure, creates nothing, and no dispatch is refused for it
