# behavior-focused-ci · verification（delta）

Base text: `openspec/specs/verification/spec.md`. The change's own scope is the product floor in CI, the probe's
repeated nesting and the `gate-self-check` declaration (`A changed-path list selects the sections to run, or the
full suite`, `CI runs the two gates separately and performance does not block`, `A gate that cannot judge says
so`). The other blocks record what the code already does and the spec did not: three requirements are retired and
re-added with the reference-only contract that replaced their performance judgments (a `MODIFIED` block cannot
drop a scenario the base still lists, so the retirement is the block's own `**Reason**`/`**Migration**` record),
and the requirements that cited them are carried over word for word except for the sentences named in that
retirement.

## REMOVED Requirements

### Requirement: The correctness gate judges correctness only

**Reason**: half of this block described instruments the code no longer has — a load premise whose readings over a
ceiling produced a visible `SKIP`, and a hard per-section budget derived from a committed measured band
(`section-budgets.tsv`). They were removed from the gate with the performance judgments, so six of the block's
scenarios can no longer be exercised, and a `MODIFIED` block cannot drop a scenario the base still lists.

**Migration**: the promise is carried by `The correctness gate judges correctness only, and a duration is a reading` (added by this change): no duration decides green or red, an
exhausted wait is a failure that names the wait and the state, and the one clock left is a per-section hang cap
that trips on the absence of progress. What each retired scenario promised and what replaced it: the frame-budget
scenario became the guard's planted-comparison and slow-but-correct scenarios; the three premise-`SKIP` scenarios
retired with the premise; the knob-integrity scenario now pins the section-guard knobs the gate still has.

### Requirement: The performance suite is separate, self-describing and non-blocking

**Reason**: this block stated the suite's red lines, the premise factors (0.75 / 0.25), the median-of-five and
samples-of-three rules, the visible `SKIP` and the judging exit statuses `2`/`4`. The suite now measures and
prints reference readings with exit statuses `0`/`3` only, so the text promised judgments the code refuses to
make and its scenarios cannot fail.

**Migration**: `The performance suite is separate, self-describing, and its numbers are reference-only` (added by this change) keeps the discoverability, the environment self-description, the
suite's own lock and "never part of a review", and replaces the red lines with readings that cannot move an exit
status. The pre-release recording of its numbers moves with it to the release record.

### Requirement: Every gate section accounts for itself, and a stuck section is named

**Reason**: the bound in this block was a per-section budget taken from a committed table of measured bands; the
table is gone, the start line no longer carries a budget, and the stopping condition is a stall in progress rather
than an elapsed time over a bound.

**Migration**: `Every gate section accounts for itself, and a section that stops making progress is named` (added by this change) keeps the accounting, the progress lines, the scene, the watchdog and
the stop-at-first-trip contract, and names the one constant hang cap as the only clock. The retired
`--budget-check` scenario became the scenario that pins the cap's constant default and the knobs' fixture
gating.

### Requirement: A load experiment signals only the processes it started

**Reason**: this block's guard test is `skills/teamsmith/tests/load-experiment.sh`, which no longer exists: the
load experiment and its premise were deleted with the performance judgments (P316), and the user deleted the
laboratory itself, not just its thresholds. Every scenario here would need a fixture that is gone, so the text
pins a file that is not in the tree.

**Migration**: the generic rule this block carried — signal only a process you started and whose identity you
verified, never a target selected by name or by a command-line pattern, and pair every `SIGSTOP` with a release
trap — is an existing contract: `boundary#Signals go to a recorded pid, never to a name or a pattern`,
`boundary#Scripts select processes by recorded pid, and the lint keeps it that way` and
`boundary#The signal gate's calls are recorded, and its refusals outlive the call log's rotation`, whose guard
tests are `tests/signal-gate.sh` and `tests/team-bg-stop.sh` (both still shipped and still run by §58). What
leaves with this block is the whole-machine-load and freeze experiment, whose purpose was the retired premise;
no laboratory is restored and nothing takes over its load-generating scenarios.

## ADDED Requirements

### Requirement: The correctness gate judges correctness only, and a duration is a reading

The project's correctness gate — `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`, the
pair configured in `TEAM_GATES` and run by `team review` — SHALL contain no wall-clock or CPU-share performance
red line. No assertion in it may fail because a correct operation took longer than a threshold, and no fixture it
runs (transitively) may make such a judgment; slower-but-correct behaviour MUST stay green. The gate's sources
SHALL carry a pure-logic guard that fails when a duration comparison against a threshold reappears in the gate's
sources, when the gate names a measuring fixture, or when a reading script gains a judging exit code (`2`/`4`). The one shared gate lock and its accounting (`TEAM_SMOKE_LOCK`, `TEAM_SMOKE_LOCK_WAIT`, the
`queued`/`ran`/`limit` record) are unchanged, and the gate keeps the time-independent knob-integrity check of
`panel#Frame assembly is asynchronous, cached and never blocks input`.

A fixture that waits for a real process to reach a state SHALL treat its wait horizon as a **failure detector,
never as a judgment**: when the horizon runs out, the verdict MUST be attributed from evidence collected at that
moment — whether the scene is still changing — and an exhausted wait is a **failure** that names the wait and the
state it waited for. There is no load premise and no machine-attributed `SKIP` exit: a busy machine cannot turn a
red into a skip, so a skip cannot hide a regression, and a scene whose wait runs out is never reported as a pass.
While the scene is still changing the fixture SHALL be allowed to extend its polling beyond the base horizon (a
bounded factor) so a merely slow machine is still judged. A knob that paces or injects a wait is honoured only
under the fixture switch, and the injected values are printed as ignored; the numbers behind a horizon are
recorded as documentation next to the fixture. Nothing here adds a wall-clock or CPU-share red line: no assertion
may fail because a correct operation was slow.

A section's per-section hang cap (`verification#Every gate section accounts for itself, and a section that stops
making progress is named`) is a **liveness detector, not a performance judgment**, and the promise above holds
inside it: the cap is
one constant with a stated default, it trips on the absence of progress rather than on elapsed time, a section
that finishes inside its cap MUST stay green however slow the machine is, and the only thing its clock can decide
is that the section stopped making progress — a trip names the section and is always a red, never a skip and
never a silent pass. The timing record the gate writes is not a verdict: no other assertion in the gate may
compare a measured duration to a threshold, and the pure-logic guard SHALL keep that true (a duration comparison
reappearing in the gate's sources, beside the markers above, turns it red).
#### Scenario: A duration judgment cannot come back unnoticed

- **GIVEN** the correctness gate's sources and a scratch copy of the tree whose `smoke.sh` gains a wall-clock
  comparison (`[ "$elapsed" -gt 5 ] && bad …`), then a second copy whose section body names
  `skills/teamsmith/tests/perf.sh`
- **WHEN** `bash skills/teamsmith/tests/gate-guard.sh` runs in the clean tree and in each copy
- **THEN** the clean tree is green, and each copy is red naming the file it found the marker in — restoring the
  file makes that copy green again

#### Scenario: A reading script cannot gain a judging exit code

- **GIVEN** the clean tree and a scratch copy of `skills/teamsmith/tests/perf.sh` that exits `2` when a reading
  comes out high
- **WHEN** `bash skills/teamsmith/tests/gate-guard.sh` runs in each
- **THEN** the clean tree is green and the copy is red naming the judging exit code — the reference readings
  cannot turn into a failure

#### Scenario: A correct operation that takes longer is recorded, not judged

- **GIVEN** a scratch copy of the tree whose §0c body gains `sleep 25` before its existing assertions (a non-zero
  cost that is still a correct operation), the section running under the constant default hang cap
- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 0c` runs there
- **THEN** it exits 0 with no failing assertion, the section's closing line records the elapsed time as a
  reference reading, and no timeout line appears

#### Scenario: The fixture knobs are ignored outside the fixture switch

- **GIVEN** `TEAM_SMOKE_SECTION_HANG_CAP` (and the other section-guard knobs) set with the fixture switch **off**
- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 0e` runs
- **THEN** every injected knob has an ignore line printed, the section runs under the constant default cap, and
  the run's accounting shows the default source rather than the injected value

### Requirement: The performance suite is separate, self-describing, and its numbers are reference-only

`bash skills/teamsmith/tests/perf.sh` (fronted by `team perf`) SHALL **measure and print reference readings** —
the interactive first frame (median of three independent spawns), the uncached frame assembly line (median of five
fixture-repo runs) and the steady-state pane CPU (median of a three-way split of one sampling window) — and it
SHALL NOT judge them: no threshold, no load premise, no `SKIP` conclusion, and no exit status that a measured
number can move. It SHALL print an **environment self-description** before its readings: whether it runs on the
host or in the pinned image (a host run is labelled "not the reference environment"), the visible logical cores,
the CPU quota when one is set, the load average, the JS runtime and tmux versions, and the revision under test.
Each reading line SHALL carry the numbers it rests on.

Its exit status SHALL carry only setup outcomes: **0** the readings were printed, **3** a setup failure (a
required tool or the panel bundle is missing, or a `--in-container` run cannot prove it runs in the pinned image)
or the performance lock could not be taken. There is no `2` and no `4`: a slow reading, a busy machine or a missing
engine never turns the suite red and never blocks anything. It SHALL be runnable on the host and inside the pinned
`ci/Containerfile` image (`team perf --container`, or the equivalent documented container invocation), and it SHALL
take its own lock (`TEAM_PERF_LOCK`) so two readings do not overlap, printing one line when exclusivity was broken
rather than changing the exit status. It MUST NOT take the correctness gate's lock and MUST NOT be invoked by the
correctness gate or by `team review`: a performance reading never changes a review verdict.

#### Scenario: A slow reading is printed, not failed

- **GIVEN** `TEAM_PERF_LOADAVG` and `TEAM_PERF_CORES` injected to describe a machine that would once have been
  judged over the premise (`TEAM_PANEL_CPU_LOADAVG` / `TEAM_PANEL_CPU_CORES` are stripped, as retired knobs)
- **WHEN** `bash skills/teamsmith/tests/perf.sh --host` runs
- **THEN** it exits 0, every reading line carries its measured number, and the environment block names the injected
  load and core count — no `SKIP`, no red verdict and no `2`/`4` exit

#### Scenario: The environment self-description is printed with the readings

- **WHEN** the suite runs, on the host and (once) in the pinned image
- **THEN** the output names the environment (host/container or the explicit "not the reference environment" label),
  the visible cores, the CPU quota or its absence, the load average, the runtime and tmux versions, and the
  revision, and each reading line carries its measured numbers

#### Scenario: The suite is not part of a review

- **GIVEN** a checkout whose performance readings would be far above the reference numbers
- **WHEN** `team review <ID> --dir <checkout>` runs the gates
- **THEN** the verdict comes from the correctness gate alone, and `docs/team/reviews/<ID>.md` contains no
  performance reading

#### Scenario: Two performance runs serialize instead of measuring each other

- **GIVEN** one performance run holding `TEAM_PERF_LOCK`
- **WHEN** a second `bash skills/teamsmith/tests/perf.sh` starts with `flock` available
- **THEN** it prints the holder and queues (bounded by a wait cap) instead of measuring concurrently, and the
  correctness gate's lock was never taken by either run

### Requirement: Every gate section accounts for itself, and a section that stops making progress is named

A run of `skills/teamsmith/tests/smoke.sh` SHALL account for itself section by section. Before a section's body
runs, the run SHALL print one start line carrying, in this order, the token `#<N>` with the run's monotone section
number (the first section is `#1`, one number per section, no gaps), the section's id as the sources spell it, and
an ISO-8601 start timestamp (for example `== #7 4c · 看板重复 ID（M48）… == 2026-09-22T12:34:56+00:00`). When a
section finishes, the run SHALL print a closing line carrying the same `#<N>`, its elapsed time in seconds
tokenised as a reference reading (`· 参考 用时 <n>s`) rather than a verdict, and the section's pass/fail/skip
counts; it SHALL also append the section to a machine-readable timing record (a header line and one row per
started section: number, id, ISO-8601 start, elapsed seconds, progress ticks) in the run's temp root.

Every section SHALL run under a **hang cap**, and the run SHALL stop at the first section that stops making
progress under it. The cap is **one constant** with a stated default (1800 s) — a liveness bound, not a budget
derived from a measured band, because time decides nothing in the gate (`verification#The correctness gate judges
correctness only`) — and it trips when a section's progress ticks have not moved for the cap, not when a
section's elapsed time passes it. The run SHALL self-report while it runs, so that a run an outer clock kills is
still attributable: while a section is in progress, one bounded progress line SHALL be printed every
`SMOKE_PROGRESS_INTERVAL` seconds (default 60) carrying that section's `#<N>`, its id, how long it has been
running, the cap and the slowest sections so far. The progress report MUST NOT stop a run or turn a section red —
the hang cap is the only clock that can — and the outer timeouts (`TEAM_REVIEW_TIMEOUT`, the CI job's) remain the
outermost backstops.

When a section stops making progress under its cap the run MUST stop and report it as a **red that names the
section**: the line SHALL carry `#<N>`, the section's id, its cap, the stalled time and its elapsed time, the run
SHALL write the section's scene (below), and the run SHALL exit non-zero with status 2. No later section may run,
no result line may be printed, and the trip MUST NOT be reported as a skip, as a pass, or as a run that continued —
a trip is never an attribution that turns the machine into a green.

The watchdog that enforces the cap SHALL be a child that is not in the suite's job table (a bare `wait` in the
suite MUST return without waiting for it), SHALL be reclaimed when the run ends normally, SHALL poll with a
bounded interval, and MUST NOT signal a process group: it stops the stuck section's descendants and the suite
itself, escalating `TERM` to `KILL`, so that a caller that shares the suite's process group (`team review`, the CI
step, the session that started the gate) is never signalled. The suite SHALL also check the trip at its own safe
points (a section boundary and every assertion), so that a section whose child was killed cannot quietly continue.
The fixture knobs (`TEAM_SMOKE_STUCK_SECTION`, `TEAM_SMOKE_SECTION_HANG_CAP`, `TEAM_SMOKE_PROGRESS_INTERVAL`,
`TEAM_SMOKE_GUARD_POLL`) SHALL be honoured only under the fixture switch (`TEAM_SMOKE_FIXTURE=1`) and SHALL be
printed as ignored otherwise (naming the injected value and the `override=[]` that took effect), so an inherited
environment cannot weaken the bound.

The scene SHALL be written **before** the stop signals and SHALL outlive the run: it SHALL be a dot-prefixed
directory under the **resolved temp root** — the one `scripts/lib/common.sh`'s `team_tmp_root` answers (`TMPDIR`
first, then `TEAM_TMP_ROOT`, then the on-disk default) — and outside the run's own temp root, so the suite's
normal cleanup (and its failure path, which deletes the temp root) cannot take it. Getting it out of a container
is the collection step's contract, not the suite's: the CI names the scene as one of its families to
`ci/collect-scene.sh`, which stages it out of the stopped container and fails the step when no family arrived
(the step's prefix table and staging path own the mechanics, so a change to the temp root or to the collector
does not need a second copy of that rule here). It SHALL hold, bounded in lines and bytes: the section's
number, id, cap and elapsed time; the last progress reading; the suite's descendant process tree and a bounded
process-table snapshot; the tail of every fixture log the run wrote under its temp root during that section; the
last lines of every pane on the run's private tmux server when one exists; and the partial timing record. A normal
run SHALL NOT create it.

#### Scenario: A section that never returns is named, stops the run, and leaves a scene

- **GIVEN** a nested `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` whose fixture switch is on,
  whose stuck-section knob names an early section, and whose hang-cap override is a few seconds
- **WHEN** that run executes the named section, which does not return
- **THEN** the run exits 2, its output carries one line naming that section's `#<N>`, its id, its cap and its
  elapsed time, no result line and no later section appear, and the line is within the last lines of the output
  (the tail `team review` records)
- **AND** a timeout line is not accompanied by any `SKIP` attribution for that section, and the run's exit status
  is not 0

#### Scenario: The scene survives the run and carries the section's evidence

- **GIVEN** the timed-out run of the previous scenario, whose stuck command is a sleeping process that ignores
  `TERM`
- **WHEN** the run has ended and its temp root is gone (the default, no `--keep`)
- **THEN** the scene directory still exists under the resolved temp root, its summary names the section and the
  cap, and its process evidence names the stuck command (the watchdog's `KILL` escalation is recorded)
- **AND** the scene carries the last progress reading and the tail of the fixture log the section had written, so
  the incident can be read without a rerun

#### Scenario: A normal run is unaffected, and every section is accounted for

- **GIVEN** a clean tree and `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` (no fixture knob)
- **WHEN** it runs
- **THEN** it exits 0, no trip line and no scene directory appear, each section printed exactly one start line
  with a strictly increasing `#<N>` and one closing line with its elapsed time and counts, and the timing record
  has exactly one row per section that started

#### Scenario: The cap is a constant, and a knob cannot weaken it outside the fixture switch

- **GIVEN** `TEAM_SMOKE_STUCK_SECTION=0c TEAM_SMOKE_SECTION_HANG_CAP=3` set with the fixture switch **off**, then
  the same pair with `TEAM_SMOKE_FIXTURE=1`
- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 0e` runs in each setting
- **THEN** the first run prints the ignore line for each injected knob and reports `stuck-cap=1800
  source=default`, while the second reports `stuck-cap=3 source=fixture` for the named section and
  `other-cap=1800 source=default` for another one — there is no committed budget table to weaken

#### Scenario: A run that an outer clock kills can still say where it was

- **GIVEN** the fixture switch on, a small progress interval, and a section that runs longer than that interval
- **WHEN** the run is in that section
- **THEN** progress lines carry the section's `#<N>`, its id, its running elapsed time, its cap and the slowest
  sections so far, and none of them stops the run or turns anything red — the cap remains the only clock that can
- **AND** a section that finishes inside the interval prints no progress line for itself

## MODIFIED Requirements

### Requirement: CI runs the two gates separately and performance does not block

The CI workflow SHALL run the correctness gate and the performance suite as separate steps or jobs with
independent conclusions and logs, and a failing performance run MUST NOT turn the correctness conclusion red or
block a merge. The correctness step SHALL run the **product floor** — every section the table does not declare a
gate self-check (`verification#A changed-path list selects the sections to run, or the full suite`) — together
with the sections the push's own changed paths claim, so what the project delivers is judged on every run while a
heavy or structural self-check runs when its own sources change or in a full run — including a fixture
meta-mutation (the routing flip matrix) whose subject is the fixture's teeth rather than delivered behaviour, and
whose recorded cost is 4946 s, which is why it may not sit in the ordinary entry. The workflow SHALL obtain the
changed paths from the push's base and tip as a **NUL-separated listing** (`git diff --name-only -z`, read into a
bash array) and pass them as arguments to the suite (the existing `--paths`), never through a per-line file and
never re-derived inside the container: a path may itself contain a newline, and git's default listing C-escapes
quotes and backslashes. The workspace mount is read-only, so the paths travel as arguments rather than as a file
written into the checkout. An unclaimed path or an unresolvable base SHALL give the full suite rather than a
narrower run. The performance suite SHALL be run once before a release, in the pinned image, and the reference
numbers it prints SHALL be recorded in that release's record.

#### Scenario: The workflow carries two independent conclusions

- **WHEN** `.github/workflows/gates.yml` is read
- **THEN** the correctness step runs `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
  --floor --keep </dev/null --paths "$@"` inside the pinned image with the push's changed paths as that command's
  own arguments, with no FAST and no `continue-on-error`, the performance command is a separate step inside the
  same pinned image, and that step is tolerated (`continue-on-error: true`) so its failure is visible in the log
  without failing the correctness conclusion

#### Scenario: A path with a newline, a quote or a backslash survives the hand-in

- **GIVEN** a scratch checkout with a tracked file whose name contains a double quote and a backslash, and a tree
  with a file whose name contains a newline
- **WHEN** the workflow's changed-path step is run against a push that touched it, and the selector is asked for
  that path
- **THEN** the path arrives byte-for-byte (the selector answers `RUN` or `FULL` for the path the tree really has,
  not a quoted or escaped variant), the section that declares it is selected, and a shape that read the paths
  line-by-line instead loses the newline case and breaks on the escaped one

#### Scenario: The correctness step says what it ran and what it left out

- **GIVEN** a push whose changed paths claim one product row and no gate self-check, and the run of the previous
  scenario
- **WHEN** the last 25 lines of its output are read
- **THEN** they carry the selection header (`decision=`, the number of sections run and the keys it did not run),
  the selected-run token `== 选段结果 ==`, and no `smoke 全绿` — the floor run is disclosed as a selection and is
  never presented as the full gate

#### Scenario: The pre-release run is named

- **WHEN** the project's release checklist and the release records it requires are read
- **THEN** the checklist names the performance reading command to run before a release (the pinned image) and
  the release record is where its printed numbers are pasted

### Requirement: A changed-path list selects the sections to run, or the full suite

`skills/teamsmith/tests/section-paths.tsv` SHALL be the one place a path→section claim lives, with comment
header lines documenting the exempt path class, the prologue keys, the matcher's semantics and the **gate
self-checks** (one `# gate-self-check:` line naming the keys of the sections whose subject is the gate's own
machinery — including a fixture meta-mutation whose purpose is to prove another section's assertions bite: that
is a statement about the fixture, not about what the project delivers),
and one row
per section carrying the section's key, its id as the sources spell it, the repo-relative patterns it
covers, the keys of the sections that must run before it, and the basis of the claim. Every section that line
does not name is part of the **product floor** — the sections that judge what the project delivers — and the
floor is the default, so a section nobody declared is in it. `bash
skills/teamsmith/tests/section-select.sh --paths <path>…` SHALL answer with `decision=FULL|NONE|RUN` and
exit 0 without running the suite and without calling git (the caller supplies the paths, for example from
`git diff --name-only <base>...HEAD`):

- **`NONE`** — every given path is in the declared exempt class (`docs/**`, the team ledger) and no row
  claims it: no gate section needs to run, and the output says so.
- **`RUN`** — every given path is claimed: the answer lists the keys whose patterns match, always including
  the prologue keys and the transitive closure of the rows' `needs` keys, and names the paths behind each
  key.
- **`FULL`** — at least one given path is claimed by no row and is not exempt: the answer names those paths
  and prescribes the full suite (running more is always safe; running too little is not).

`bash skills/teamsmith/tests/section-select.sh --floor [--paths <path>…]` SHALL answer the
same way with one addition: the selection always carries the prologue, every floor section and the closure of
their `needs` keys, with the path-claimed keys added when paths are given — so a client can ask for “the product
plus whatever this change touches” in one decision. The paths are the existing `--paths` interface and nothing
else: there is no per-line file reader, because a path may itself contain a newline, and the caller still
supplies them (the selector calls no git). A floor with no product section SHALL exit non-zero naming the empty
floor rather than running the prologue alone.

With `--check` the selector SHALL verify its own basis in pure logic: every section in the gate's sources
has exactly one row and every row's key resolves to exactly one section; a literal pattern (one without a
wildcard) exists in the tree, except for a specifically attributed absent internal prerequisite in a product-only
checkout under `verification#A gate that cannot judge says so`; the exempt class is claimed by no row; every `needs` key exists and
refers to a section that appears earlier in the sources; the `gate-self-check` header names keys that each
resolve to exactly one row, repeats none, and names no prologue key (a key the line does not name is a floor
section, so a misspelt or stale key would quietly move a self-check into CI or a product section out of it); and a real-tree path token named inside a section's
own text (under the documented normalizer for the suite's path variables) is covered by that row's
patterns — a section that reads a path it does not declare is red and names the token and its line. An
unknown key, a path outside the repository, or a malformed row SHALL exit non-zero with the reason and run
nothing.

A skipped internal literal's existence check MUST print `SKIP（条件不满足）` with its row key and exact path,
and the selector's summary MUST count it separately from `ok` and `bad`. A `--check` with only such skips and
no failed integrity check SHALL exit 0; any missing product literal, unknown or misspelled internal path,
corrupt mapping, or missing internal literal in an internal/partial checkout MUST still fail. The exception MUST
NOT remove mapping rows, narrow their patterns, exempt product paths, skip token coverage or alter
`FULL|NONE|RUN`, the needs closure, coupling, or copy syntax checks. Embedded invocations in smoke MUST relay
the skip attributions and account for them rather than converting their exit 0 into evidence that the missing
files were checked successfully.

`bash skills/teamsmith/tests/smoke.sh --paths <path>…`, `bash skills/teamsmith/tests/smoke.sh --floor
[--paths <path>…]` and `bash skills/teamsmith/tests/smoke.sh --select
<key>[,<key>…]` SHALL run the selection: the prologue, the selected sections and their `needs` closure, in
source order, with the unselected sections not executed; an unknown key exits non-zero and runs nothing. A
run without any of these flags SHALL behave exactly as before (every section runs) — the full suite stays the
default and the delivery/review/archive gate, and a selection is a batch filter that never changes what a
selected section asserts. Checkout-prerequisite attributions obey the same rules in selected and full runs;
the selected-run disclosure and result-token rules remain unchanged.

#### Scenario: A docs-only diff needs no section, and a run that selects says so

- **WHEN** `bash skills/teamsmith/tests/section-select.sh --paths docs/team/BOARD.md
  docs/team/reports/P97-dev3.md` runs, and then `bash skills/teamsmith/tests/smoke.sh --paths
  docs/team/BOARD.md` runs
- **THEN** the selector prints `decision=NONE` and states that no section needs to run, and the suite run
  prints that no section was affected, starts no section (no `== <id> ==` header appears), prints no result
  line, prints no `smoke 全绿`, and exits 0

#### Scenario: A product path selects the sections that cover it, and their prerequisites

- **WHEN** `bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/outbox.sh`
  runs, and the resulting selection is run with `--select`
- **THEN** the decision is `RUN`, the listed keys include every key whose row declares that path (the data
  file is the authority) plus the prologue and the closure of their `needs` keys, and the selected run's
  output contains their section headers and none of the unselected sections'

#### Scenario: A section's prerequisites run with it instead of being assumed

- **GIVEN** the selector's data declares that section `17` needs `15b` (the gate's own comment says `17`
  reuses the fake settings/spec tree `15b` builds)
- **WHEN** `bash skills/teamsmith/tests/smoke.sh --select 17` runs
- **THEN** the output carries `15b`'s header before `17`'s, and `17`'s closing line reports the same counts
  as in a full run of the same tree (a selection must not turn its assertions into a vacuous pass)

#### Scenario: A path no row claims falls back to the full suite

- **WHEN** `bash skills/teamsmith/tests/section-select.sh --paths ci/some-new-thing` runs
- **THEN** the decision is `FULL`, the output names that path as unclaimed, and the run it prescribes is the
  full suite — the fallback cannot be reached by claiming too little

#### Scenario: A weakened or incomplete table is red, not silently narrow

- **GIVEN** the clean tree, then a scratch tree whose table loses one section's row, then a scratch tree
  whose row for one section no longer covers a path that section's own text names
- **WHEN** `bash skills/teamsmith/tests/section-select.sh --check` runs in each
- **THEN** the clean tree is green, both scratch trees exit non-zero and name the offending section (and, in
  the second, the token and its line), and restoring either makes it green again

#### Scenario: Missing planning literals are visible but product literals still fail

- **GIVEN** a clean product-only export and a scratch copy whose mapping also claims the nonexistent product
  literal `skills/teamsmith/tests/p98-no-such-literal.md`
- **WHEN** `bash skills/teamsmith/tests/section-select.sh --check` runs on each
- **THEN** the export exits 0 with separate skip counts and row/path attributions for `AGENTS.md`, `SCOPE.md`,
  `.pi/skills` and `openspec/changes/archive`, but the mutated copy exits 1 and names the missing product literal
- **AND** an internal checkout missing one of those internal literals exits 1, and a product-only table naming
  the nonexistent `openspec/changes/typo-planning-file.md` exits 1 rather than getting a blanket prefix exemption

#### Scenario: Public selector integrity and selection stay live

- **GIVEN** a product-only export and separate scratch copies with a missing row, narrowed pattern, unknown
  needs key, claimed exempt path, or undeclared product token
- **WHEN** `section-select.sh --check` runs against each copy, and the clean export runs the existing
  `--paths`, `--select` and `--verify-copies` checks
- **THEN** each corruption exits non-zero and names its original reason despite internal-literal skips;
  the clean export retains the same selection decisions/closure as the corresponding internal tree and all
  generated copies pass `bash -n`

#### Scenario: The floor is every section nobody declared a gate self-check

- **GIVEN** the clean tree, then a scratch copy of the table whose `gate-self-check` line loses one key, and a
  second copy whose line gains a key that no row carries
- **WHEN** `bash skills/teamsmith/tests/section-select.sh --floor` runs in the clean tree and in each copy, and
  `--check` runs on both copies
- **THEN** the clean tree's floor lists every section except the ones the line names, the first copy's floor gains
  exactly that section (the declaration is the only way out of the floor), and the second copy's `--check` exits
  non-zero naming the unknown key — restoring the line makes each green again

#### Scenario: A floor and a changed path answer in one decision

- **WHEN** `bash skills/teamsmith/tests/section-select.sh --floor --paths
  skills/teamsmith/tests/section-select.sh` runs, and then `--floor --paths ci/some-new-thing`
- **THEN** the first decision is `RUN` and its keys are the floor plus the `36` row and its `needs` closure, the
  second is `FULL` (an unclaimed path still prescribes the whole suite, floor or not), and neither invocation runs
  a section

### Requirement: A gate that cannot judge says so

The correctness gate SHALL distinguish a product-only checkout, which deliberately contains the published product and `openspec/specs/` but none of this development repository's internal surfaces (`docs/team/`, `openspec/changes/`, `AGENTS.md`, `SCOPE.md`, `.pi/prompts/`, `.pi/skills/`), from an internal or partially populated checkout. Classification MUST inspect the checkout under test before creating fixture data; inherited project identity, CI environment, and a fixture-created ledger MUST NOT decide it. An empty, unreadable, malformed or partially populated internal surface MUST NOT be treated as absent. No production environment override SHALL turn a missing product or internal-checkout file into a prerequisite skip.

Only a check whose named prerequisite is one of those deliberately absent internal surfaces SHALL skip on a product-only checkout. Each such attribution MUST print `SKIP（条件不满足）`, the affected check and missing prerequisite, be counted as a skip rather than a pass, and reach the gate's output and per-section/run accounting. Missing product files, unavailable required tools, a failed executed assertion, and corruption of a present internal surface MUST retain their existing failure/degradation rules; the checkout classification MUST NOT swallow them. An executed check's verdict MUST rest on evidence the subject itself carries: when the call's command word is the wrapped command itself (`tmux`), an isolation wrapper defined in one file MUST NOT certify a mutation call made by another file, while a dedicated wrapper name defined alongside the caller MAY keep its directory-level meaning; a check MUST NOT be reported as satisfied on evidence the subject does not have. A run with prerequisite skips and no failures SHALL exit 0, without claiming the skipped checks passed; a real failure alongside skips MUST still exit non-zero.

The same correctness command SHALL run on both shapes, with no second public suite. The product's static checks, skill loading, published-spec validation, container-build checks and every ledger-independent fixture MUST remain eligible exactly as before (including the existing FAST/full and tool-premise rules). A fixture that provisions its own ledger MUST still run in the product-only checkout. For an internal checkout, every pre-existing assertion MUST still execute with its original verdict and at least its pre-change per-section pass count under identical run settings; replacing an existing assertion with a new one MUST NOT satisfy that coverage comparison. CI's correctness step MUST retain its blocking failure semantics, and it SHALL run the product floor the way `verification#CI runs the two gates separately and performance does not block` states: a failing applicable product assertion in that step fails the job, and the selection it makes is disclosed in the output tail rather than presented as the full gate.

#### Scenario: The release export skips only unavailable internal checks

- **GIVEN** a clean product-only tree exported from committed HEAD by `bash docs/team/tools/publish-public.sh`, with the gate's required tools available
- **WHEN** `openspec validate --all --strict && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` runs there
- **THEN** it exits 0 with no failing assertions, missing internal prerequisites are named on counted `SKIP（条件不满足）` lines, and all FAST-eligible product sections execute
- **AND** the section counts sum to the run totals and no skipped prerequisite is counted as a pass

#### Scenario: A public checkout still exercises the product checks and their negative controls

- **GIVEN** the same exported tree, then independent scratch copies with a missing product literal `skills/teamsmith/tests/skill-load.mjs` and with CJK prose injected into `skills/teamsmith/references/protocol.md`
- **WHEN** the first copy runs `bash skills/teamsmith/tests/section-select.sh --check` and the second runs the gate's English-prose check
- **THEN** both fail and name the damaged product path, despite their other internal prerequisites being skipped
- **AND** the unmodified export executes skill loading, reference scanning, installer tests, five-phase product-document contract checks and their sandbox negative controls, rather than skipping §18, §19 or §36 wholesale

#### Scenario: A sibling file's wrapper does not certify a planted product mutation

- **GIVEN** a product-only scratch tree (whose sibling fixture `smoke.sh` defines the same-named `tmux()` wrapper) with a bare `tmux kill-server` appended to a product file (`skills/teamsmith/tests/tmp-hygiene.sh`), a second copy of that tree whose lint has the same-directory rule restored, and a third copy where the same call is instead exempted through the lint's own frozen-hash exemption list
- **WHEN** §31's tmux-isolation lint runs in each tree (the internal-only exemption list attributed as a prerequisite skip in the first)
- **THEN** the first tree is red and names the planted file — a wrapper defined in another file is not evidence of isolation for that call — and the second and third trees are green, so the red judgment is demonstrably attached to §31's lint verdict and to the attribution rule itself rather than to an unrelated failure
- **AND** the unmodified product-only tree keeps the lint's green verdict, so the product check is not made red unconditionally

#### Scenario: The signal lint's frozen ledger is an internal prerequisite, not a product one

- **GIVEN** a product-only scratch tree whose P159 signal lint carries its frozen exemption ledger for `docs/team/reports/**`, a copy whose ledger also names an absent product file (`skills/teamsmith/scripts/p176-no-such-product-file.sh`), and a third copy whose per-entry attribution is relaxed so that any absent ledger entry is skipped
- **WHEN** §58's signal-discipline lint runs in each tree (the internal-only ledger attributed as a prerequisite skip in the first)
- **THEN** the first tree exits 0 with the ledger's absence printed as a counted `SKIP（条件不满足）` naming `docs/team/reports/**` while the lint's own verdict still executes, the second is red and names the missing product path, and the third is green — the skip is attributed to the internal surface, not to absence as such
- **AND** a name-selected signal call planted in a product file still makes the same check red in the product-only tree, so attributing the ledger as a prerequisite does not disarm the lint

#### Scenario: The internal checkout loses no existing coverage

- **GIVEN** pre-change and post-change independent internal checkouts with identical tools and FAST settings
- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` runs in each
- **THEN** every pre-existing assertion is present in the post-change executed assertion inventory, each pre-existing section's pass count is at least its baseline, and no new checkout-prerequisite skip appears
- **AND** a scratch mutation that replaces an existing internal assertion with a prerequisite skip fails the inventory/count comparison, even if new assertions keep the aggregate pass total unchanged

#### Scenario: Partial internal trees and broken installs remain red

- **GIVEN** scratch internal trees with, respectively, `SCOPE.md` removed, one `opsx-apply.md` removed, one phase `SKILL.md` removed, or the archive directory removed while other internal surfaces remain
- **WHEN** their relevant smoke assertions and `section-select.sh --check` run
- **THEN** each damaged tree exits non-zero and names the missing path, not a product-checkout skip
- **AND** creating an empty internal directory in an otherwise product-only scratch checkout cannot turn its missing required files into successful assertions or absence-based skips

#### Scenario: A synthetic ledger does not change the subject's classification

- **GIVEN** a product-only checkout invoked with inherited `TEAM_ROOT`/`TEAM_MAIN_ROOT` pointing at an internal checkout
- **WHEN** its smoke gate runs and `team init` creates ledger and OpenSpec data in the gate's private fixture repository
- **THEN** the source checkout still gets the same prerequisite skips as without those inherited variables, while the fixture's ledger-dependent CLI assertions actually execute

#### Scenario: A real failure is not hidden by prerequisite skips

- **GIVEN** an exported scratch checkout with a failing product assertion and deliberately absent internal prerequisites
- **WHEN** the correctness gate runs
- **THEN** its summary carries both failure and skip counts, the failure names its assertion, and the gate exits non-zero

#### Scenario: Missing tooling is not attributed to the checkout shape

- **GIVEN** a product-only scratch checkout with `perl` unavailable
- **WHEN** its English-prose check runs
- **THEN** it retains the existing missing-perl failure and does not relabel it an internal-file prerequisite skip

#### Scenario: The public workflow remains a blocking correctness check

- **WHEN** `.github/workflows/gates.yml` is read and its correctness container command is run on an independent product-only checkout
- **THEN** the command is `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh --floor --keep </dev/null --paths "$@"` with the changed paths as its own arguments, without FAST or correctness `continue-on-error`, and it succeeds when all applicable checks succeed
- **AND** a failing applicable product assertion makes that same command fail; performance remains a separate non-blocking conclusion
- **AND** a changed-path list naming a fixture meta-mutation's own sources adds that self-check, one naming only product routing sources adds §61 and not the matrix, and the same command with no resolvable base runs the full suite instead of a narrower selection

### Requirement: A fixture observes a data-derived state before it asserts it

A fixture under `skills/teamsmith/tests/**`, and the fixtures those sources drive, that asserts a state the
console derives from an **asynchronous read** — the project-settings view's entry read, a contract re-read, the
panel's first frame, a log the tool writes — SHALL, before that assertion, observe **the state it is about to
assert**, on a settled frame and with a bounded wait: the value itself (for example the settings row already
showing the hand-edited value), not a proxy for it. A skeleton marker (a group heading, a loading or placeholder
line, an empty frame) MUST NOT be accepted as evidence that the data landed. An unconditional fixed delay followed
by a single sample (`sleep N` and one `capture-pane`/capture) MUST NOT be the evidence a data-derived assertion
rests on.

The wait SHALL be bounded and SHALL follow the counted-wait discipline of the gate's pty fixtures
(`skills/teamsmith/tests/lib/pty-wait.sh` is the model): it polls in counted rounds, carries a cap, and names
**which data-derived state** was expected in its attribution — not only that a wait expired — alongside the wait
itself and the rounds it used. When the wait runs out the fixture MUST NOT make the assertion and MUST NOT report
that scenario green: the exhaustion is a **failure** that names the wait and the state it waited for — never a
machine-attributed skip (`verification#The correctness gate judges correctness only, and a duration is a reading`), so a busy machine cannot
turn a regression into a skip.

The bound MUST NOT be a wall-clock or CPU-share performance red line
(`verification#The correctness gate judges correctness only, and a duration is a reading`, D33's rule): a read that lands slowly but inside the
bound MUST stay green, and no assertion in the fixture may fail because a correct read was slow. The bound SHALL
be recorded where the fixture lives together with the measured latency band it is derived from.

A fixed delay that only paces input (the interval between keystrokes) is not evidence and is not what this
requirement governs. What it governs is a fixed delay, or a skeleton frame, used as the evidence that data the
fixture is about to assert has landed.

#### Scenario: A read that lands later is observed, and the old shape is its red side

- **GIVEN** a scratch copy of `skills/teamsmith/tests/panel-p21.sh` whose CLI wrapper delays the settings block
  read (`__panel-data --block settings`) by a fixed delay that is inside the bounded wait (the attribution
  recipe: 0 s green, 6 s red, 6 s plus five times the horizon still red)
- **WHEN** the hand-edited-value scenario runs (the contract is edited by hand to `TEAM_NOTIFY_TMUX=true`, the
  view is reopened, the row is filtered to, and the picker is opened)
- **THEN** the fixture observes the derived state (the hand-edited value is in the picker's current entry) and the
  scenario is green, while the same run against the pre-change shape — a skeleton wait plus an unconditional
  `sleep` before Enter — is red with `非规范拼写的手改值原样显示成当前条目` unmet, the 2-core CI shape
  `✓ 108 ✗ 3`

#### Scenario: Data that never lands exhausts the wait instead of passing

- **GIVEN** the same scratch fixture with the settings read delayed past the wait's cap, or never completing
- **WHEN** the scenario runs
- **THEN** one attribution line names the wait and the state it waited for, the derived state is not asserted,
  the scenario is not green, and the exit status is not 0 — an exhausted wait is a failure however busy the machine
  is, never a skip and never a timeout reported as a pass

#### Scenario: The collapse scene's single sample becomes a bounded observation

- **GIVEN** `bash skills/teamsmith/tests/panel-b3.sh collapse` and a console whose first frame lands later than
  the fixed window the scene samples today — a delayed bundle injected through the fixture's own `TEAM_B3_PANEL`
  hook, or the loaded host on which 4 of 6 runs were red- **WHEN** the scene runs
- **THEN** it observes the console's own title (`teamsmith pulse`) on a settled frame by polling inside a bound
  and is green, while the pre-change shape — `sleep 5` then one `capture-pane`, and `sleep 6` then one capture for
  the restore — is red with `pulse 窗口里是控制台` and `恢复后同一窗口里又是控制台` unmet; the scene's other
  evidence waits (`pulse up`'s log naming the window, `capacity.log` gaining rows) follow the same rule, and a
  title that never appears is attributed at the cap by the previous scenario's rule

#### Scenario: No duration judgement enters the fixture

- **GIVEN** the fixtures' sources after this change
- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` and the gate's guard
  (`verification#The correctness gate judges correctness only, and a duration is a reading`) run
- **THEN** no assertion in these fixtures compares an elapsed time or a CPU share to a threshold — the waits'
  caps are liveness bounds recorded with their measured band — and a run in which the read landed slowly inside
  the bound is green; a fixture that turned such a bound into a duration verdict is the red side of that flip

### Requirement: A measuring fixture measures a fixed tree, not the caller's worktree

A fixture whose number is a reference reading — `skills/teamsmith/tests/panel-cpu.sh`, which the performance suite
drives — SHALL measure a **fixed measurement target**: a neutral
reference project the fixture fixes itself, not the caller's current worktree. The tree under test, whose console
bundle the run reports as the revision under test, SHALL stay the tree the fixture was invoked against, so that
the code being judged and the data being measured are two separate, named things.

The output SHALL name both: the project root that was measured and the console bundle that was run. This is
separate from the performance suite's environment self-description
(`verification#The performance suite is separate, self-describing, and its numbers are reference-only`), which names the environment
and the revision under test; this requirement fixes and names the **measurement target**. Invoking the same
command from two different worktrees SHALL measure the same project root — the
caller's working directory MUST NOT change what is measured, and a checkout's own accumulated data (its
`state/`, its worktrees, its reports) MUST NOT be what the number describes. What the numbers do is unchanged:
they are readings of a fixed target, and two runs of the same bundle are not promised to print identical values.

#### Scenario: Two worktrees, one measured target

- **GIVEN** a large checkout (this repository's worktree, with its accumulated state) and a fresh project with
  almost no data, and the same console bundle under test
- **WHEN** `bash skills/teamsmith/tests/panel-cpu.sh` runs with default arguments from each
- **THEN** both runs measure the fixture's fixed project root and name it in their output, so the same bundle is
  measured against the same data; the pre-change shape measures the caller's tree instead — measured as 3683 ms
  from a large checkout against 391 ms from a fresh project — which is the flip, and the number is a reading either
  way, never a verdict

#### Scenario: The measured root and the revision under test are named

- **WHEN** `bash skills/teamsmith/tests/panel-cpu.sh` runs
- **THEN** its output carries the project root it measured and the console bundle it ran, neither implicit, so a
  reader can tell what the number describes without reading the fixture's source; the printed root is the
  fixture's own fixed project, and a caller that names another tree explicitly for diagnostics sees that tree
  named in the output instead of it being measured silently

### Requirement: Every wait in the gate is bounded and attributes at its cap

A wait in the gate's sources (`skills/teamsmith/tests/**` and the fixtures those sources drive) that waits for a
real process or state to arrive SHALL carry a round count and a cap, SHALL poll in counted rounds, and SHALL
refresh the running section's progress reading on every round, so that a section that is legitimately waiting is
distinguishable from a section that is stuck. At its cap the wait SHALL print one attribution line — the wait's
own name, the rounds it used as `<n>/<cap>`, and what it observed (the state it was waiting for and the last
reading it got) — before it returns a non-green status; a wait MUST NOT return quietly having observed nothing.
An unbounded `while` loop that sleeps SHALL NOT exist in the gate's sources.

The gate SHALL carry a static check over its own sources: the `while`+`sleep` loops are inventoried in one place
with the cap each one carries or the structure that bounds it (a stop file, a deadline, the owner's lifetime), and
an uninventoried loop, or an inventoried loop that lost its cap, turns the check red. `tests/lib/pty-wait.sh`'s
settled-frame discipline and its attribution-at-the-cap semantics are the model for a bounded wait and are unchanged
by this requirement.

#### Scenario: An unbounded poll loop cannot appear unnoticed

- **GIVEN** the gate's sources and the static check running inside the gate (a pure-logic FAST section)
- **WHEN** the check runs on the clean tree, and then in a scratch tree that adds a new
  `while :; do sleep 1; done` loop to a fixture
- **THEN** the clean tree is green, the scratch tree is red and names the file and line of the new loop, and
  restoring the file makes it green again

#### Scenario: A wait that exhausts its cap says what it was waiting for

- **GIVEN** a fixture whose probe never reaches the waited-for state and whose cap is three rounds
- **WHEN** its wait runs
- **THEN** one line names the wait, prints `3/3`, and carries the last observed reading, the wait returns a
  non-green status, and the section's timing record shows its progress ticks advanced during the wait (the wait
  was polling, not stuck)

#### Scenario: The pty fixture's settled-frame waits are unchanged

- **WHEN** `bash skills/teamsmith/tests/lib/pty-wait.sh --self-test` and the gate's pty sections run
- **THEN** their existing semantics — settled frames, the bounded extension, and the attribution at the ceiling —
  are unchanged, and the new inventory names their loops rather than replacing them
