# verification Specification

## Purpose

The PM's independent check of an agent's claim: gates run on a checkout the agent never touched, a hard timeout, and
a written record that future readers can audit. Why a report is only a claim and the review is the evidence:
`references/philosophy.md` (principle 1, "a false green is worse than nothing") and `references/protocol.md`.
## Requirements
### Requirement: Reviewing needs an independent checkout

`team review <ID> --dir <path>` SHALL run only against a checkout the PM prepared and SHALL refuse when `--dir` is
missing. The command MUST NOT run git operations itself, and it MUST write its verdict record to
`docs/team/reviews/<ID>.md`.

#### Scenario: A review without a checkout is refused

- **WHEN** `team review T1.1` runs without `--dir`
- **THEN** it exits non-zero and the message states that the PM must prepare an independent checkout

#### Scenario: The record lands in the ledger

- **WHEN** `team review T1.1 --dir /tmp/review-T1.1` finishes (any verdict)
- **THEN** `docs/team/reviews/T1.1.md` exists in the main worktree
- **AND** the main worktree has no new changes outside `docs/team/` and `.pi/team/`

### Requirement: A dirty or mismatched checkout is refused

The checkout MUST be clean and MUST be at the branch under review. A checkout with uncommitted changes MUST be
refused unless `TEAM_REVIEW_ALLOW_DIRTY=1`; a checkout whose HEAD is not the reviewed branch MUST be refused unless
`TEAM_REVIEW_ANY_DIR=1` (together with `--branch <rev>`), and the message MUST say which of the two it is.

#### Scenario: Uncommitted changes block the review

- **GIVEN** a review checkout with one uncommitted file
- **WHEN** `team review T1.1 --dir <checkout>` runs
- **THEN** it exits non-zero, the message names the uncommitted changes, and it prints the
  `TEAM_REVIEW_ALLOW_DIRTY=1` override
- **AND** the same command with `TEAM_REVIEW_ALLOW_DIRTY=1` proceeds

#### Scenario: A detached checkout of the wrong revision is refused

- **GIVEN** a detached checkout whose HEAD is not the tip of the task branch
- **WHEN** `team review T1.1 --dir <checkout>` runs
- **THEN** it exits non-zero and states that the checkout and the branch do not match
- **AND** `TEAM_REVIEW_ANY_DIR=1 team review T1.1 --dir <checkout> --branch <sha>` proceeds

### Requirement: Gates run under a hard timeout

The verdict SHALL come from running `$TEAM_GATES` inside the checkout under a hard timeout
(`TEAM_REVIEW_TIMEOUT`, default 1800 s; `timeout` and `lsof` are optional helpers). On timeout the verdict MUST be
`TIMEOUT`, the record MUST say the run was killed by the hard timeout, and the command MUST exit non-zero (a timeout
is never a pass).

#### Scenario: A hanging gate becomes TIMEOUT, not a hang

- **GIVEN** `TEAM_GATES='sleep 60'` and `TEAM_REVIEW_TIMEOUT=2`
- **WHEN** `team review T1.1 --dir <checkout>` runs
- **THEN** the command returns within a few seconds, exits non-zero, and `docs/team/reviews/T1.1.md` records the
  verdict `TIMEOUT` with the hard-timeout explanation

#### Scenario: A failing gate fails the review

- **GIVEN** `TEAM_GATES='bash -c "echo boom; exit 7"'`
- **WHEN** `team review T1.1 --dir <checkout>` runs
- **THEN** the verdict is `FAIL`, the tail of the gate output (including `boom`) is in the record, and the command
  exits non-zero

### Requirement: The record states what was verified

`docs/team/reviews/<ID>.md` SHALL name the verified revision (the checkout's HEAD), the branch, the gate command and
its timeout, the diffstat against the protected branch, the commits and the file list, the tail of the gate output
and the verdict. When the agent's report is missing from the branch, the record MUST say so explicitly instead of
omitting the section.

#### Scenario: The record pins the revision and the evidence

- **GIVEN** a task branch with two commits and a report committed on it
- **WHEN** `team review T1.1 --dir <checkout>` runs
- **THEN** the record contains the checkout's HEAD sha, the gate command string, both commit subjects, the changed
  file list and the gate output tail

#### Scenario: A missing report is recorded as a problem

- **GIVEN** a task branch with no `docs/team/reports/T1.1-<agent>.md`
- **WHEN** `team review T1.1 --dir <checkout>` runs
- **THEN** the record states that the agent report is missing

### Requirement: Strong review records flip and independent evidence

With `--strong`, the review SHALL check the agent's report for defect-fix flip evidence ("red before → green after",
or "break the implementation → the guard must fail") and for an independent verification package, and SHALL record
both findings in the record. Missing evidence MUST be reported as missing and warned about; it MUST NOT be silently
presented as satisfying the strong review.

#### Scenario: Flip evidence is found

- **GIVEN** a report containing "red before → green after" and a note that the guard test fails when the fix is
  reverted
- **WHEN** `team review T1.1 --dir <checkout> --strong` runs
- **THEN** the record's strong-review section reports the destructive evidence as present

#### Scenario: Missing evidence is not a false pass

- **GIVEN** a report that only describes the implementation
- **WHEN** `team review T1.1 --dir <checkout> --strong` runs
- **THEN** the record marks the flip evidence as missing, the command warns, and the warning names the strong-review
  checklist

### Requirement: Verdicts are explicit, including the "not run" cases

The review SHALL distinguish `PASS`, `FAIL`, `SKIPPED` (`--no-gates`) and `UNKNOWN` (no `TEAM_GATES` configured),
and only a `PASS` MUST be treated as evidence that the gates were green; `SKIPPED` and `UNKNOWN` MUST NOT be
presented as a passing gate run.

#### Scenario: Skipping the gates is visible in the record

- **WHEN** `team review T1.1 --dir <checkout> --no-gates` runs
- **THEN** the verdict line says `SKIPPED` and the record does not claim that the gate suite ran

### Requirement: The hard timeout covers the gate run, not the queue

When gates are configured, `team review` SHALL serialize the gate run on the shared gate lock
(`${TEAM_SMOKE_LOCK:-${TMPDIR:-/tmp}/teamsmith-smoke.lock}`) **before** the hard-timeout clock starts, so the
queue wait is never counted against `TEAM_REVIEW_TIMEOUT`. While waiting it MUST print the holder recorded in
`<lock>.holder`; the queue wait MUST be bounded by `TEAM_SMOKE_LOCK_WAIT` (default 1800 s). When that cap is
exceeded the verdict MUST be `FAIL` with the record stating that the gate did not run and naming the holder —
the queue MUST NOT produce a `TIMEOUT` verdict. When the environment already records that an ancestor holds the
gate lock, the review MUST NOT queue again. When no queue mechanism is available (no `flock`), the review MUST
print that the queue is not enforced instead of degrading silently.

The record SHALL account for the two intervals separately (`queued Ns / ran Ns / limit Ns`) and SHALL name the
outcome distinguishably: `PASS` (gates ran, exit 0), `FAIL` (gates ran and failed, or the queue cap was
exceeded), `TIMEOUT` (the run was killed by the hard timeout, whose record MUST carry the run duration as
`ran=Ns`). The verdict line MUST keep the closed token (`PASS|FAIL|TIMEOUT|SKIPPED|UNKNOWN`), so
`team_review_verdict` still parses the record.

#### Scenario: A long queue does not consume the run budget

- **GIVEN** a fixture that holds the gate lock for 3 s, `TEAM_REVIEW_TIMEOUT=5` and a gate that needs 3 s
- **WHEN** `team review T1.1 --dir <checkout>` runs
- **THEN** the verdict is `PASS` and the record shows `queued 3s / ran 3s / limit 5s` as separate intervals —
  counting the queue inside the timeout is what turns the same run into a `TIMEOUT`

#### Scenario: A queue beyond its cap fails loudly and names the holder

- **GIVEN** the gate lock held by a fixture whose holder record names it, and `TEAM_SMOKE_LOCK_WAIT=2`
- **WHEN** `team review T1.1 --dir <checkout>` runs
- **THEN** it exits non-zero, the verdict is `FAIL` (not `TIMEOUT`), and the record states that the gate never
  ran and names the fixture holding the lock

#### Scenario: A gate that really runs past the limit is still TIMEOUT

- **GIVEN** `TEAM_GATES='sleep 60'` and `TEAM_REVIEW_TIMEOUT=2`
- **WHEN** `team review T1.1 --dir <checkout>` runs
- **THEN** the verdict is `TIMEOUT`, the record carries the run duration (`ran=2s`), and `team_review_verdict
  T1.1` returns exactly `TIMEOUT` — the added accounting does not break the verdict parser

#### Scenario: A gate that already holds the lock does not queue again

- **GIVEN** a review invoked inside a gate that holds the gate lock, with the wrapped marker in its environment
- **WHEN** `team review T1.1 --dir <checkout>` runs
- **THEN** it does not wait on the lock, the record accounts for it as already held, and the nested run
  completes instead of deadlocking against its own ancestor

#### Scenario: Without a queue mechanism the degradation is printed

- **GIVEN** the same review with no `flock` on `PATH`
- **WHEN** `team review T1.1 --dir <checkout>` runs
- **THEN** the run proceeds without a queue and prints that the gate queue is not enforced

### Requirement: The gate refuses tracked files that still hold conflict markers

The gate SHALL search the tree under test for conflict-marker lines — `<<<<<<<` with or without a label,
`=======` (seven or more `=`), and `>>>>>>>` — at the start of a line, in every **tracked** file, in the working
tree **and** in the index, and it MUST turn red when it finds any, naming each hit as `<file>:<line>`. It MUST look
only at tracked line-oriented text: an untracked file, a copy under another worktree (`.worktrees/**`) or a binary
file containing a NUL byte MUST NOT produce a hit, so a documentation example or a third party's worktree cannot
fail the gate. A tree without markers MUST stay green.

#### Scenario: A committed or uncommitted marker block is found

- **GIVEN** a fixture repository whose tracked file carries a `<<<<<<<` / `=======` / `>>>>>>>` block (the shape a
  `git merge --squash` leaves behind when a commit is made without resolving it)
- **WHEN** the gate's marker check runs
- **THEN** it reports red and prints `tracked.txt:2` (the file and the line of the first marker); the same check on
  a clean checkout reports green instead of printing anything

#### Scenario: A staged marker block that the working tree no longer shows is found

- **GIVEN** a file whose marker block was `git add`-ed and whose working tree copy was then rewritten clean
- **WHEN** the gate's marker check runs
- **THEN** it reports red and names that `file:line`, because the next commit would still carry the marker

#### Scenario: Untracked, worktree and binary files are out of scope

- **GIVEN** marker text in an untracked file, in a force-tracked file under `.worktrees/other/`, and after a NUL
  byte in a tracked binary file
- **WHEN** the gate's marker check runs
- **THEN** all three produce no hit and the check stays green

### Requirement: The correctness gate judges correctness only

The project's correctness gate — `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`, the
pair configured in `TEAM_GATES` and run by `team review` — SHALL contain no wall-clock or CPU-share performance
red line. No assertion in it may fail because a correct operation took longer than a threshold, and no fixture it
runs (transitively) may make such a judgment; slower-but-correct behaviour MUST stay green. The gate's sources
SHALL carry a pure-logic guard that fails when a perf judgment marker (a frame-budget comparison, a CPU-share
comparison, or an invocation of the measuring fixtures) reappears in the gate or disappears from the performance
suite. The one shared gate lock and its accounting (`TEAM_SMOKE_LOCK`, `TEAM_SMOKE_LOCK_WAIT`, the
`queued`/`ran`/`limit` record) are unchanged, and the gate keeps the time-independent knob-integrity check of
`panel#Frame assembly is asynchronous, cached and never blocks input`.

A fixture that waits for a real process to reach a state SHALL treat its wait horizon as a **failure detector,
never as a judgment**: when the horizon runs out, the verdict MUST be attributed from evidence collected at that
moment — whether the scene is still changing, and the machine's own readings (`loadavg_1m`/`loadavg_5m`, the
logical core count, and a code-independent probe that measures how long this machine needs to start processes).
A machine over the premise MUST produce a **visible SKIP** for that wait and the rest of its scenario: the line
names the wait, its elapsed time and the readings, the run's summary counts it as a skip, it is never reported as
a pass and never as a failure, and the gate still exits 0 — a fixture that cannot be judged SHALL say so instead
of turning the machine into a red. A machine under the premise whose scene is static MUST still fail: a
regression is a code verdict and the premise MUST NOT become an escape. While the scene is still changing the
fixture SHALL be allowed to extend its polling beyond the base horizon (a bounded factor) so a merely slow
machine is still judged rather than skipped. The readings MUST be real on the real path — an injection knob is
honored only under the fixture switch, and the injected values are printed as ignored — and the numbers that
decide SHALL be calibrated from measurement with their measured bands stated next to the fixture. Nothing here
adds a wall-clock or CPU-share red line: the horizons themselves are unchanged, and no assertion may fail
because a correct operation was slow.

A section's per-section hard budget (`verification#Every gate section accounts for itself, and a stuck section is
named`) is a **liveness detector, not a performance judgment**, and the promise above holds inside it: the budget
is derived from a recorded measured band with a stated factor and floor, it MUST NOT be tightened below that band,
a section that finishes inside its bound MUST stay green however slow the machine is, and the only thing its clock
can decide is that the section did not terminate — a trip names the section and is always a red, never a skip and
never a silent pass. The timing record the gate writes is not a verdict: no other assertion in the gate may
compare a measured duration to a threshold, and the pure-logic guard SHALL keep that true (a duration comparison
reappearing outside the guard module, beside the frame-budget/CPU-share markers, turns it red).

#### Scenario: A slow-but-correct console keeps the correctness gate green

- **GIVEN** the assembly-delay fixture knob set in fixture mode
  (`TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_FRAME_DELAY_MS=2600`), which makes every sampled frame exceed the 2000 ms
  budget
- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` runs
- **THEN** it exits 0 with no failing assertion, and its output contains no frame-budget or CPU-share judgment —
  the same knob on the pre-split gate is the red side of that flip

#### Scenario: A wall-clock judgment cannot come back unnoticed

- **GIVEN** the correctness gate's sources
- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` runs
- **THEN** its guard asserts that the gate's files carry no frame-budget/CPU-share marker and invoke no measuring
  fixture, and that the performance suite carries the same marker — reintroducing the old judgment into the gate,
  or deleting it from the suite, makes the guard red

#### Scenario: The knob-integrity check stays in the gate, without a measurement

- **GIVEN** the fixture knobs set with the fixture switch off
- **WHEN** the gate runs the panel fixture's premise-only mode
- **THEN** the gate asserts the ignore notices for every injected knob and that the premise line carries the real
  load and core count, and it judges no duration

#### Scenario: A machine over the premise skips visibly, and the gate is not red

- **GIVEN** the pty fixture's premise readings injected over their ceiling under the fixture switch
  (`TEAM_SMOKE_FIXTURE=1 TEAM_P21_PREMISE_PROBE_MS=999`), i.e. the machine reads as unable to deliver a frame in
  the fixture's budget
- **WHEN** `bash skills/teamsmith/tests/panel-p21.sh choices` runs and `TEAM_SMOKE_FAST=1 bash
  skills/teamsmith/tests/smoke.sh </dev/null` runs the section that drives it (§38-b)
- **THEN** the fixture exits `4`, prints a `SKIP` line naming the wait that hit its horizon, its elapsed time,
  the probe value and the load, counts the skip in its summary, and reports no failure — and the gate's section
  prints the same reason and still exits 0, so no review verdict turns red for it

#### Scenario: The premise is not an escape from a real regression

- **GIVEN** a scratch tree whose panel sources lost the wheel consumption the `wheel` scenario and the gate's
  §38-e structural pin assert (a real regression), the bundle rebuilt there, and the machine readings under
  their premise
- **WHEN** `bash skills/teamsmith/tests/panel-p21.sh wheel` runs against that tree
- **THEN** the wheel assertions fail (not skip), the fixture exits `1`, and the failure names the assertion — the
  same run against the unmodified tree is green, which is the flip

#### Scenario: A skipped fixture is never reported as a passing one

- **GIVEN** the over-premise injection of the first scenario
- **WHEN** the gate's section for the pty fixture runs
- **THEN** its line reads `SKIP` with the reason and the readings, the all-green line for that section does not
  appear, the run's skip count is non-zero, and the gate's output tail that `team review` records carries the
  same line

#### Scenario: The premise's readings stay real on the real path

- **GIVEN** `TEAM_P21_PREMISE_PROBE_MS=999` (and the other premise knobs) set with the fixture switch **off**
- **WHEN** the pty fixture runs
- **THEN** its premise line carries the real load, core count and probe value, the injected values are printed as
  ignored, and the verdict comes from the real readings — the same promise the knob-integrity scenario makes for
  the panel's measurement knobs

#### Scenario: A section that is slowed on purpose still stays green under its bound

- **GIVEN** the correctness gate's sources and `TEAM_SMOKE_FIXTURE=1` with the assembly-delay knob of the first
  scenario set, which slows the section that drives the pty fixture in this run
- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` runs
- **THEN** it exits 0, every section's start line carries its budget and its closing line carries the elapsed
  time, and no timeout line appears — the slower section's duration is recorded, not judged

### Requirement: The performance suite is separate, self-describing and non-blocking

`bash skills/teamsmith/tests/perf.sh` (fronted by `team perf`) SHALL judge the panel's performance red lines — the
interactive first frame (under the unchanged 2000 ms budget), the uncached frame assembly line (the unchanged
2000 ms budget) and the steady-state pane CPU (under the unchanged 1 % of one core) — with the premise factors
(0.75 / 0.25), the median-of-five/samples-of-three rules, the visible SKIP and the thresholds exactly as they are
today. It SHALL print an **environment self-description** before its verdicts: whether it runs on the host or in a
container, the visible logical cores, the CPU quota when one is set, the load average, the JS runtime and tmux
versions, and the revision under test. A verdict line SHALL carry the measured numbers it rests on.

Its exit status SHALL distinguish the outcomes: **0** every judgment ran and was green, **2** at least one
judgment was red, **4** no red but at least one judgment visibly skipped (or the environment lacks a tool or an
engine a measurement needs — the reason and the measured values printed), **3** a setup failure. A skip MUST NOT be
reported as green, and a red MUST NOT be hidden behind another judgment's skip. It SHALL be runnable on the host
and inside the pinned `ci/Containerfile` image (`team perf --container`, or the equivalent documented container
invocation), and it SHALL take its own lock (`TEAM_PERF_LOCK`) so two performance runs do not overlap. It MUST NOT
take the correctness gate's lock and MUST NOT be invoked by the correctness gate or by `team review`: a failing
performance run never changes a review verdict.

#### Scenario: A slow frame is red with its numbers

- **GIVEN** the suite's fixture switch and an injected first-frame delay
- **WHEN** `bash skills/teamsmith/tests/perf.sh` runs
- **THEN** it exits 2, the failing judgment prints its median and the samples behind it, and the summary names
  that judgment red

#### Scenario: A busy machine skips visibly instead of passing

- **GIVEN** an injected load reading above the premise factor, with a delay that would otherwise be red
- **WHEN** the suite runs
- **THEN** the affected judgment prints `SKIP` with the measured values and the load, the suite exits 4 (no
  conclusion) and its own exit status is not 0 — the run is never presented as green

#### Scenario: The environment self-description is printed with the verdicts

- **WHEN** the suite runs, on the host and (once) in the pinned image
- **THEN** the output names the environment (host/container), the visible cores, the CPU quota or its absence,
  the load average, the runtime and tmux versions, and the revision, and each judgment's line carries its measured
  numbers

#### Scenario: The suite is not part of a review

- **GIVEN** a checkout whose performance suite would be red
- **WHEN** `team review <ID> --dir <checkout>` runs the gates
- **THEN** the verdict comes from the correctness gate alone, and `docs/team/reviews/<ID>.md` contains no
  performance judgment

#### Scenario: Two performance runs serialize instead of measuring each other

- **GIVEN** one performance run holding `TEAM_PERF_LOCK`
- **WHEN** a second `bash skills/teamsmith/tests/perf.sh` starts with `flock` available
- **THEN** it prints the holder and queues (bounded by a wait cap) instead of measuring concurrently, and the
  correctness gate's lock was never taken by either run

### Requirement: CI runs the two gates separately and performance does not block

The CI workflow SHALL run the correctness gate and the performance suite as separate steps or jobs with
independent conclusions and logs, and a failing performance run MUST NOT turn the correctness conclusion red or
block a merge. The performance suite SHALL be run once before a release, in the pinned image, and its measured
numbers SHALL be recorded in the release checklist.

#### Scenario: The workflow carries two independent conclusions

- **WHEN** `.github/workflows/gates.yml` is read
- **THEN** the correctness command is the unchanged
  `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null`, the performance command
  is a separate step inside the same pinned image, and that step is tolerated (`continue-on-error: true`) so its
  red is visible in the log without failing the correctness conclusion

#### Scenario: The pre-release run is named

- **WHEN** the release checklist (`docs/team/PUBLISH.md`) is read
- **THEN** it names the performance command to run before a release and the place its measured numbers are
  recorded

### Requirement: The two gates are discoverable, and the doctor names the next step

`skills/teamsmith/SKILL.md` and `references/protocol.md` SHALL state the division between the two gates —
correctness on every change (`team review` and the delivery gate), performance separately and before a release —
and SHALL give the copy-pasteable command for each. `team doctor` SHALL report the performance suite's presence,
and when `tests/perf.sh` is absent it SHALL name an actionable next step instead of staying silent.

#### Scenario: The docs name both gates and their division

- **WHEN** `grep -n 'team perf' skills/teamsmith/SKILL.md skills/teamsmith/references/protocol.md` runs
- **THEN** both files name the performance command, and the protocol's gate section states that the correctness
  gate judges no wall-clock performance line

#### Scenario: A missing performance suite is a next step, not silence

- **GIVEN** a skill tree whose `skills/teamsmith/tests/perf.sh` is absent
- **WHEN** `team doctor` runs
- **THEN** it reports the performance suite as absent together with the command that restores it, and it does not
  fail the doctor for it

### Requirement: The container self-test's host fingerprint is stable state, and only a real host change moves it

`bash skills/teamsmith/tests/container-tmux.sh --selftest` SHALL decide that the container touched nothing on the
host by comparing a fingerprint of the host's tmux state taken before and after the container run, and that
fingerprint MUST be built only from facts that a real host change moves: for each socket in scope — the caller's
socket and the host's default socket paths — the socket's on-disk identity, the server's own session table for
that socket, and, when a server answers there, that server's process id. No other process may be able to move the
value: running `tmux` clients, the gate shim, a `team` command, or any process whose command line merely mentions
tmux SHALL leave the value byte-identical, and servers, sessions and processes outside the sockets in scope (for
instance another project's private fixture server on this host) MUST NOT enter it. Reading the fingerprint MUST
be read-only — it MUST NOT start a server — and the self-test SHALL print both values and MUST exit non-zero when
they differ.

`container-tmux.sh --fingerprint` SHALL print the fingerprint for the current environment (honouring `TMUX` and
`TMUX_TMPDIR`) without starting a container, and `container-tmux.sh --fingerprint-check` SHALL run the fixture of
the scenarios below and exit 0 only when the client storm left the value byte-identical **and** killing a server
on an in-scope socket changed it.

#### Scenario: A client storm is not a false red

- **GIVEN** a live private server on an in-scope socket (`TMUX_TMPDIR` and `TMUX` pinned to a private directory)
- **WHEN** `container-tmux.sh --fingerprint` runs, a bounded storm of `tmux list-sessions`/`display-message`
  clients and shells whose command line names the tmux binary runs, and the command runs again
- **THEN** the two values are byte-identical and `container-tmux.sh --fingerprint-check` exits 0 — on the
  pre-change fingerprint the same storm moves the value (that red side is in the delivery report)

#### Scenario: Killing a server on an in-scope socket is red

- **GIVEN** the same fixture with the server alive and the first fingerprint recorded
- **WHEN** the server is killed and `container-tmux.sh --fingerprint` runs again
- **THEN** the two values differ, and `container-tmux.sh --fingerprint-check` exits non-zero naming both values
  while the same fixture with the server left alive exits 0

#### Scenario: A real session change is red by contract

- **GIVEN** a live server on an in-scope socket and the first fingerprint recorded
- **WHEN** a session is created on that server and the fingerprint is read again
- **THEN** the two values differ — the premise is host tmux state, so a genuine host-side change is a change

#### Scenario: The read never starts a server

- **GIVEN** a private `TMUX_TMPDIR` with no server running
- **WHEN** `container-tmux.sh --fingerprint` runs twice
- **THEN** both runs exit 0, print the same value, and no socket file appears under that directory

### Requirement: A fixture's input-box judgement distinguishes an unexpected overlay

Fixtures that judge a TUI pane's input box from a captured frame — the real-pane fixture
`skills/teamsmith/tests/pm-box-real.sh` and the frame-level judgement it shares with the correctness gate — SHALL
distinguish an **unexpected overlay** from a non-empty input box. An overlay is a whole-pane modal that has
replaced the TUI's normal input state; the measured case is Pi's project-trust prompt (`Trust project folder?` …
`Do not trust`), drawn for a project whose `.pi/skills/` the fixture's own `team init` installed. A fixture MUST
NOT report an overlay as `idle-read=NOT-EMPTY`: that token asserts that the input box holds text, and the measured
prompt holds none — the frame made the judgement locate no box below the pane's cursor (so the fixture's
`EMPTY`-only check called it a draft), and with the cursor inside the prompt it paired the prompt's own rule rows
and read the question and options as box content.

The fixture's readiness wait SHALL release only on the TUI's real input state — an input box the judgement
locates whose text is empty — and not on the first full-rule row in the pane, because the prompt's frame carries
rule rows that satisfy a bare rule-row wait. When the wait expires with an overlay present, the fixture MUST name
the overlay in its output, keep the last frame for the report, and exit non-zero **without typing anything into
the overlay**: the payload steps MUST NOT run on a pane whose input box was never located.

The real-pane fixture SHALL reach that empty input box in a project `team init` provisioned with `.pi/skills/`
installed, with no interactive trust decision and with no trust decision written to Pi's store. It MUST NOT remove
the project-local install to dodge the prompt (that would drop the shape the fixture exists to exercise), and it
MUST NOT answer the prompt by hand; the trust override it starts Pi with applies to the single run and leaves Pi's
trust store untouched. The overlay classification SHALL be exercised by a stored real frame (the
`skills/teamsmith/tests/frames/` convention) with a visible red side: with the overlay predicate disabled, the
same frame MUST be judged a draft (never `EMPTY`), so the classification is falsifiable rather than vacuous.

#### Scenario: The stored trust-prompt frame is an overlay, not a draft

- **GIVEN** the real frame `skills/teamsmith/tests/frames/pi-0.87.0-project-trust-prompt.txt` (Pi 0.87.0, private
  tmux socket, 120×30 pane, `--no-session`; provenance and cursor row recorded in that directory's README) and the
  fixture's frame-level judgement
- **WHEN** `bash skills/teamsmith/tests/pm-box-real.sh --frame
  skills/teamsmith/tests/frames/pi-0.87.0-project-trust-prompt.txt --cursor <row>` runs
- **THEN** it exits 0, prints `overlay=trust-prompt`, and does not print `idle-read=NOT-EMPTY`
- **AND** with the overlay predicate disabled (`M24_OVERLAY_DETECT=0` in the same command) it exits non-zero and
  prints `idle-read=NOT-EMPTY` — the red side proving the predicate is what changes the verdict, not the frame

#### Scenario: A real pane reaches the empty box in a provisioned project

- **GIVEN** a project provisioned by `team init` (`<main worktree>/.pi/skills/teamsmith` installed) and a real Pi
  in a private tmux socket, with Pi's trust store not carrying a decision for the project
- **WHEN** `bash skills/teamsmith/tests/pm-box-real.sh --idle-secs 3` runs, and `bash
  skills/teamsmith/tests/container-tmux.sh --with-pi --cmd "bash skills/teamsmith/tests/pm-box-real.sh --idle-secs 3"`
  runs it again in the pinned image whose HOME carries no trust store
- **THEN** both runs exit 0, both print `M45 idle-read=EMPTY ok` and `RETRACT=ok`, and neither frame carries the
  `Trust project folder?` overlay
- **AND** the project-local `.pi/skills/teamsmith` entry is still installed after the run, and the container run
  created no `trust.json` under its HOME — the prompt was neither dodged by removing the install nor answered

#### Scenario: An overlay stops the fixture before it types

- **GIVEN** the same fixture in its documented overlay mode, which starts Pi without the single-run trust override
  so the project-trust prompt is on screen
- **WHEN** `bash skills/teamsmith/tests/pm-box-real.sh --idle-secs 3 --expect-overlay` runs
- **THEN** it exits 0 after printing `overlay=trust-prompt`, and its output carries no payload step
  (`deliver_text_lines=` does not appear) and no `idle-read=NOT-EMPTY` — nothing was typed into the prompt

### Requirement: The verification seat does not implement

The independence of verification has two sides: the agent that authored a change's work does not verify it, and the
seat a project reserves for verification does not implement at all. A project SHALL identify that seat by name with
`TEAM_VERIFY_SEAT`; unset or empty resolves to `verify`, so the default protects the conventional verification seat
and blanking the value cannot switch the boundary off. `team dispatch` MUST refuse implementation work for that
seat, under the refusal, `--print` and `--force`-with-one-audit-line contract specified by
`dispatch#A verification seat is never dispatched implementation work`. Verification work itself MUST stay allowed
for the seat: the `explore`, `propose`, `verify` and `archive` phases, and undeclared-phase briefs whose `grant:`
names only `docs/team/` or `openspec/` paths — the seat writes proposal reviews and reconnaissance there. The
verification seat's row in `docs/team/OWNERSHIP.md` MUST state the boundary and point at the guard, so the roster
table and the tool agree.

#### Scenario: The ownership row states the boundary and points at the guard

- **WHEN** `docs/team/OWNERSHIP.md` is read
- **THEN** the verification seat's row states that the seat does not implement and names the `team dispatch`
  refusal, so a reader learns the rule from the table itself

#### Scenario: The configured seat replaces the default, and a blank value does not switch it off

- **GIVEN** a project whose roster carries a `checker` seat as well as the conventional `verify`
- **WHEN** `TEAM_VERIFY_SEAT=checker` is configured and an apply brief is dispatched to `checker`
- **THEN** it is refused, while the same brief dispatched to `verify` proceeds
- **AND** with `TEAM_VERIFY_SEAT` unset or empty, an apply brief dispatched to `verify` is refused

#### Scenario: Verification work stays allowed for the seat

- **GIVEN** a brief with `agent: verify`, `phase: verify` and `grant: docs/team/reports/V1-verify.md ·
  openspec/changes/alpha/specs/`
- **WHEN** `team dispatch verify V1 <brief> --print` runs
- **THEN** it proceeds, so the guard never blocks the seat's reviews and reconnaissance

### Requirement: The verifier of a change is not one of its authors

When `team dispatch` starts a task whose `phase:` is `verify` for change `C`, it SHALL refuse when that task's
`agent:` is also the `agent:` of a task mapped to `C` whose `phase:` is `apply` or undeclared, excluding mapped
tasks whose board status is `dropped`. The refusal MUST name the change, the agent and the apply tasks it found,
MUST NOT change any board status, and MUST come before any window is opened (and for `--print` as well). `--force`
MUST proceed with a warning and append exactly one audit line naming the agent, the change and the authored tasks.
When a mapped task has no resolvable brief, or its header records no `agent:`, the guard MUST print which signal is
missing and proceed — an unknowable author is never reported as a clean one.

#### Scenario: One agent's apply task blocks its own verification

- **GIVEN** a change `alpha` with an apply task `M1` whose `agent:` is `dev`, and a verify task `V1` for `alpha`
  whose `agent:` is also `dev`
- **WHEN** `team dispatch dev V1 <verify-brief>` runs
- **THEN** it exits non-zero and names `alpha`, `dev` and `M1`, and opens no window

#### Scenario: A different agent verifies

- **GIVEN** the same change and a verify brief whose `agent:` is `verify`
- **WHEN** `team dispatch verify V1 <verify-brief> --print` runs
- **THEN** it is not refused and prints the prompt

#### Scenario: A dropped apply task does not block

- **GIVEN** the same change, with `M1`'s board status `dropped`
- **WHEN** `team dispatch dev V1 <verify-brief>` runs
- **THEN** it is not refused, and the message names the dropped task as excluded

#### Scenario: A missing signal is loud, not silent

- **GIVEN** a change whose apply task's brief cannot be resolved (or whose header carries no `agent:`)
- **WHEN** the verify dispatch runs
- **THEN** it proceeds and prints which signal was missing

#### Scenario: `--force` records the override

- **GIVEN** the first scenario's pair
- **WHEN** `team dispatch dev V1 <verify-brief> --force` runs
- **THEN** it proceeds, warns that the verification is no longer independent, and appends exactly one line to
  `state/watchdog.log` naming `dev`, `alpha` and `M1`

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
that scenario green. Whether the exhaustion is a **failure** or a **visible SKIP** is decided by
`verification#The correctness gate judges correctness only`: a scene that stays static while the machine's
readings are under their premise is a regression and stays red, and a machine over the premise takes the visible
skip — never a pass.

The bound MUST NOT be a wall-clock or CPU-share performance red line
(`verification#The correctness gate judges correctness only`, D33's rule): a read that lands slowly but inside the
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
  the scenario is not green, and the exit status is not 0; on a machine under the premise the scene is static and
  the run is a **failure**, and where the machine reads over the premise it is the visible `SKIP` of
  `verification#The correctness gate judges correctness only` — in neither case a timeout reported as a pass

#### Scenario: The collapse scene's single sample becomes a bounded observation

- **GIVEN** `bash skills/teamsmith/tests/panel-b3.sh collapse` and a console whose first frame lands later than
  the fixed window the scene samples today — a delayed bundle injected through the fixture's own `TEAM_B3_PANEL`
  hook, or the loaded host on which 4 of 6 runs were red
- **WHEN** the scene runs
- **THEN** it observes the console's own title (`teamsmith pulse`) on a settled frame by polling inside a bound
  and is green, while the pre-change shape — `sleep 5` then one `capture-pane`, and `sleep 6` then one capture for
  the restore — is red with `pulse 窗口里是控制台` and `恢复后同一窗口里又是控制台` unmet; the scene's other
  evidence waits (`pulse up`'s log naming the window, `capacity.log` gaining rows) follow the same rule, and a
  title that never appears is attributed at the cap by the previous scenario's rule

#### Scenario: No duration judgement enters the fixture

- **GIVEN** the fixtures' sources after this change
- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` and the gate's guard
  (`verification#The correctness gate judges correctness only`) run
- **THEN** no assertion in these fixtures compares an elapsed time or a CPU share to a threshold — the waits'
  caps are liveness bounds recorded with their measured band — and a run in which the read landed slowly inside
  the bound is green; a fixture that turned such a bound into a duration verdict is the red side of that flip

### Requirement: A measuring fixture measures a fixed tree, not the caller's worktree

A fixture whose number is a verdict — `skills/teamsmith/tests/panel-cpu.sh`, driven by
`tests/panel-cpu-premise.sh` and the performance suite — SHALL measure a **fixed measurement target**: a neutral
reference project the fixture fixes itself, not the caller's current worktree. The tree under test, whose console
bundle the run reports as the revision under test, SHALL stay the tree the fixture was invoked against, so that
the code being judged and the data being measured are two separate, named things.

The output SHALL name both: the project root that was measured and the console bundle that was run. This is
separate from the performance suite's environment self-description
(`verification#The performance suite is separate, self-describing and non-blocking`), which names the environment
and the revision under test; this requirement fixes and names the **measurement target**. Invoking the same
command from two different worktrees SHALL measure the same project root and reach the same conclusion — the
caller's working directory MUST NOT change what is measured, and a checkout's own accumulated data (its
`state/`, its worktrees, its reports) MUST NOT be what the number describes.

#### Scenario: Two worktrees, one measured target

- **GIVEN** a large checkout (this repository's worktree, with its accumulated state) and a fresh project with
  almost no data, and the same console bundle under test
- **WHEN** `bash skills/teamsmith/tests/panel-cpu.sh` runs with default arguments from each
- **THEN** both runs measure the fixture's fixed project root, name it in their output, and reach the same
  conclusion — both green, both red, or both visibly skipped with the same attribution; the pre-change shape
  measures the caller's tree instead — measured as 3683 ms from a large checkout against 391 ms from a fresh
  project, one of the two past the fixture's ~3 s polling budget and therefore red — the red side of this flip

#### Scenario: The measured root and the revision under test are named

- **WHEN** `bash skills/teamsmith/tests/panel-cpu.sh` runs
- **THEN** its output carries the project root it measured and the console bundle it ran, neither implicit, so a
  reader can tell what the number describes without reading the fixture's source; the printed root is the
  fixture's own fixed project, and a caller that names another tree explicitly for diagnostics sees that tree
  named in the output instead of it being measured silently

### Requirement: The fixture-trace scan reads ledger state, not traffic records

The gate's fixture-trace scan — the shared assertion behind every isolation claim that the fixtures wrote nothing
into the caller's real project — SHALL search the caller's ledger state only: the files under the invoking project's
`docs/team/inbox/**` and `.pi/team/state/**`, resolved from the invoking checkout's git common directory so that a
gate run inside a task worktree still scans the project's main roots, and it SHALL report each hit by path so the
failing assertion can name it.

Exactly three paths SHALL be out of scope, because they are **traffic records** — their content is what some caller
did or printed, so a fixture's own name appearing there is their intended function, not state written into the
project:

- `.pi/team/state/bg/**` — the gate's own background-job logs;
- `.pi/team/state/tmux-calls.log` — the tmux call audit log, whose own contract is
  `boundary#The gate's actions are logged, and no window carries a destructive-call grant`;
- `.pi/team/state/tmux-calls.log.forensics` — the long-retention copy of the gate's destructive-call records,
  whose own contract is `boundary#A destructive call's record outlives the call log's rotation`.

All three exclusions MUST be by exact path. Every other file under the two roots MUST stay in scope, including a
file in a subdirectory, a file that merely shares the audit log's name, and a directory that merely shares the
excluded job-log directory's name, and a trace planted in any of them MUST be reported.

The scan MUST stay falsifiable: a fixture trace planted in the ledger — `docs/team/inbox/**` or any file under
`.pi/team/state/**` other than the three excluded paths — MUST be found and reported by the same scan. The positive
and negative controls of the isolation sections are part of this requirement, so a green isolation assertion can
never come from a scan that stopped scanning.

#### Scenario: A trace in the audit log is not a leak

- **GIVEN** a scratch project root whose `.pi/team/state/tmux-calls.log` holds a line carrying a fixture's session
  name and argv, in the shape the gate records a private-socket `new-window`/`kill-session` call
- **WHEN** the fixture-trace scan runs over that root
- **THEN** it reports no hit and the isolation assertion stays green — on the pre-change scope the same line is
  reported, which is the sticky red this change removes (that red side is in the delivery report)

#### Scenario: A trace in the retention file is not a leak

- **GIVEN** a scratch project root whose `.pi/team/state/tmux-calls.log.forensics` holds the gate's record of a
  refused call — a line carrying the caller's own session name and argv
- **WHEN** the fixture-trace scan runs over that root
- **THEN** it reports no hit and the isolation assertion stays green — the file is the gate's traffic record, the
  same way the audit log is

#### Scenario: A trace in ledger state is still a leak

- **GIVEN** the same scratch root, with the trace planted in `docs/team/inbox/leak.md` and in
  `.pi/team/state/phantom.log`
- **WHEN** the scan runs
- **THEN** both files are reported by path — the negative control still turns red, so the exclusion above cannot
  be mistaken for a scan that went quiet

#### Scenario: The exclusion is an exact path, not a name

- **GIVEN** the same trace planted in `.pi/team/state/tmux-calls.log.1` and in
  `.pi/team/state/nested/tmux-calls.log`
- **WHEN** the scan runs
- **THEN** both files are reported, because the exclusion covers `.pi/team/state/tmux-calls.log` only

#### Scenario: The retention exclusion is an exact path too

- **GIVEN** the same trace planted in `.pi/team/state/tmux-calls.log.forensics.1` and in
  `.pi/team/state/nested/tmux-calls.log.forensics`
- **WHEN** the scan runs
- **THEN** both files are reported by path, because the exclusion covers `.pi/team/state/tmux-calls.log.forensics`
  only

#### Scenario: The background-job logs stay out of scope

- **GIVEN** the same trace planted in `.pi/team/state/bg/gate.log`
- **WHEN** the scan runs
- **THEN** the file is not reported (the job logs record what a caller asked a background job to print), while the
  positive control planted beside it is still reported

#### Scenario: The background-job exclusion is exact too

- **GIVEN** the same trace planted in `docs/team/inbox/bg/leak.md`, in `.pi/team/state/nested/bg/leak.md` and in
  `.pi/team/state/bg/gate.log`
- **WHEN** the scan runs
- **THEN** the first two are reported by path — a directory named `bg` anywhere but the exact excluded path is
  ledger state — and only `.pi/team/state/bg/gate.log` is not reported

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

### Requirement: A load experiment signals only the processes it started

A test, fixture or calibration that applies a machine-side perturbation (a `SIGSTOP`/`SIGCONT` freeze, a CPU-share
throttle, a whole-machine load) SHALL target only processes it started itself: it records the owner it spawned
(or the PIDs it spawned) and MUST refuse every target outside that set, printing the refusal and exiting non-zero
**before** any signal is sent — selecting a signal target by command line, name or any other host-wide pattern
MUST NOT be used, because such a pattern's boundary can never be shown to exclude another seat's process (the
2026-09-22 incident: a `pgrep`-based pattern froze the panel of the PM's P42 verification fixture). Every
`SIGSTOP` SHALL be paired with a release: the script MUST carry a `CONT` trap for `EXIT`, `INT` and `TERM` that
resumes every PID it actually stopped, and its hold SHALL be interruptible, so a script killed mid-freeze leaves
no process in state `T`. Whole-machine load SHALL come from processes the experiment owns and can reclaim (spin
processes, `stress-ng`, …), never from freezing another seat's processes, and the experiment's fixtures SHALL use
their own temporary root and their own tmux socket/server name so two seats' experiments coexist. A guard test
SHALL exercise all of it: the owned target freezes and is released, a `TERM` mid-hold resumes it, and a target the
experiment did not start (and a pattern-shaped target) is refused with nothing signalled.

#### Scenario: A target the experiment did not start is refused before any signal

- **GIVEN** an experiment that spawned its own fixture (its owner PID recorded) and a second process of the same
  shape started outside that subtree
- **WHEN** the experiment's freeze script is asked to stop the second process's PID
- **THEN** it exits non-zero, prints that the target is neither the owner nor one of its descendants, the second
  process's state is unchanged (`ps -o stat=` shows no `T`), and the same script with its own owner's PID stops
  and then resumes it

#### Scenario: A pattern-shaped target is refused, because no pattern can be proven to exclude another seat

- **GIVEN** the same script and a target given as a command-line pattern (for example
  `panel.js.*--root /tmp/panel-p21`) or an empty target list
- **WHEN** it runs
- **THEN** it exits non-zero with a printed reason and signals nothing — there is no code path that selects
  targets by matching host-wide process names

#### Scenario: A freeze that is killed mid-hold leaves nothing stopped

- **GIVEN** the experiment's own fixture frozen by the script
- **WHEN** the script receives `TERM` (and, in a second run, `INT`) while the freeze is still on
- **THEN** it resumes every PID it stopped before exiting — a `T` left behind is a failure — and its own guard
  test asserts this for both signals

#### Scenario: Whole-machine load is owned load, and the fixtures stay private

- **GIVEN** an experiment asked for whole-machine load while another seat's fixture is running
- **WHEN** the load starts and both experiments run to completion
- **THEN** the load comes from processes the experiment itself started, it signalled no process outside its own
  set, and its fixtures used their own temporary root and tmux socket name, so the other seat's run is unaffected

### Requirement: Every gate section accounts for itself, and a stuck section is named

A run of `skills/teamsmith/tests/smoke.sh` SHALL account for itself section by section. Before a section's body
runs, the run SHALL print one start line carrying, in this order, the token `#<N>` with the run's monotone section
number (the first section is `#1`, one number per section, no gaps), the section's id as the sources spell it, an
ISO-8601 start timestamp, and the budget the section runs under as `<B>s` (for example
`== #7 4c · 看板重复 ID（M48）… == 2026-09-22T12:34:56+00:00 · 预算 120s`). When a section finishes, the run SHALL
print a closing line carrying the same `#<N>` and its elapsed time in seconds, and SHALL append the section to a
machine-readable timing record (a header line and one row per started section: number, id, ISO-8601 start,
elapsed seconds, progress ticks) in the run's temp root.

Every section SHALL run under a **hard per-section budget**, and the run SHALL stop at the first section that
exceeds it. The budgets SHALL come from one committed table (`skills/teamsmith/tests/section-budgets.tsv`) whose
derivation is recorded in the file: the measured band for that section — the worst observed time on the reference
host and in the pinned gate container, with the load of each measurement (the CI column is recorded beside them
once a CI run has produced it) — multiplied by a stated factor, with a stated floor. Every section in the sources SHALL have a row; a section the table does not list yet SHALL still get
the bounded default (never no bound) and its start line SHALL say the budget came from the default. The run SHALL
also self-report while it runs, so that a run an outer clock kills is still attributable: while a section is in
progress, one bounded progress line SHALL be printed every `SMOKE_PROGRESS_INTERVAL` seconds (default 60) carrying
that section's `#<N>`, its id, how long it has been running and the slowest sections so far, and a section that
closes above its recorded band SHALL print one warning line. Neither line is a verdict: the progress report MUST
NOT stop a run or turn a section red — the per-section budget is the only clock that can — and the outer timeouts
(`TEAM_REVIEW_TIMEOUT`, the CI job's) remain the outermost backstops.

When a section exceeds its budget the run MUST stop and report it as a **red that names the section**: the line
SHALL carry `#<N>`, the section's id, its budget and its elapsed time, the run SHALL write the section's scene
(below), and the run SHALL exit non-zero with status 2. No later section may run, no result line may be printed,
and the timeout MUST NOT be reported as a skip, as a pass, or as a run that continued — a timeout is never an
attribution that turns the machine into a green.

The watchdog that enforces the budgets SHALL be a child that is not in the suite's job table (a bare `wait` in the
suite MUST return without waiting for it), SHALL be reclaimed when the run ends normally, SHALL poll with a
bounded interval, and MUST NOT signal a process group: it stops the stuck section's descendants and the suite
itself, escalating `TERM` to `KILL`, so that a caller that shares the suite's process group (`team review`, the CI
step, the session that started the gate) is never signalled. The suite SHALL also check the trip at its own safe
points (a section boundary and every assertion), so that a section whose child was killed cannot quietly continue.
The fixture knobs (`TEAM_SMOKE_STUCK_SECTION`, `TEAM_SMOKE_SECTION_BUDGET`, `TEAM_SMOKE_PROGRESS_INTERVAL`,
`TEAM_SMOKE_GUARD_POLL`) SHALL be honoured only under the fixture switch (`TEAM_SMOKE_FIXTURE=1`) and SHALL be
printed as ignored otherwise, so an inherited environment cannot weaken the bounds.

The scene SHALL be written **before** the stop signals and SHALL outlive the run: it SHALL be a dot-prefixed
directory under the resolved temp root (`${TMPDIR:-/tmp}`), outside the run's own temp root, so the suite's normal
cleanup (and its failure path, which deletes the temp root) cannot take it, and so the CI's existing collection
(`docker cp <container>:/tmp/.`) carries it out unchanged. It SHALL hold, bounded in lines and bytes: the section's
number, id, budget and elapsed time; the last progress reading; the suite's descendant process tree and a bounded
process-table snapshot; the tail of every fixture log the run wrote under its temp root during that section; the
last lines of every pane on the run's private tmux server when one exists; and the partial timing record. A normal
run SHALL NOT create it.

#### Scenario: A section that never returns is named, stops the run, and leaves a scene

- **GIVEN** a nested `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` whose fixture switch is on,
  whose stuck-section knob names an early section, and whose budget override is a few seconds
- **WHEN** that run executes the named section, which does not return
- **THEN** the run exits 2, its output carries one line naming that section's `#<N>`, its id, its budget and its
  elapsed time, no result line and no later section appear, and the line is within the last lines of the output
  (the tail `team review` records)
- **AND** a timeout line is not accompanied by any `SKIP` attribution for that section, and the run's exit status
  is not 0

#### Scenario: The scene survives the run and carries the section's evidence

- **GIVEN** the timed-out run of the previous scenario, whose stuck command is a sleeping process that ignores
  `TERM`
- **WHEN** the run has ended and its temp root is gone (the default, no `--keep`)
- **THEN** the scene directory still exists under `${TMPDIR:-/tmp}`, its summary names the section and the
  budget, and its process evidence names the stuck command (the watchdog's `KILL` escalation is recorded)
- **AND** the scene carries the last progress reading and the tail of the fixture log the section had written, so
  the incident can be read without a rerun

#### Scenario: A normal run is unaffected, and every section is accounted for

- **GIVEN** a clean tree and `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` (no fixture knob)
- **WHEN** it runs
- **THEN** it exits 0, no timeout line and no scene directory appear, each section printed exactly one start line
  with a strictly increasing `#<N>` and a budget and one closing line with its elapsed time, and the timing record
  has exactly one row per section that started

#### Scenario: The budget table has a measured basis, and a weakened budget is red

- **GIVEN** `bash skills/teamsmith/tests/section-guard.sh --budget-check` over the committed sources and table
- **WHEN** it runs on the clean tree, and then in a scratch tree whose table entry for one section is lowered
  below its recorded band × the stated factor (and, in a second scratch tree, whose table loses one section's row)
- **THEN** the clean tree is green, verifying for every row that the budget is at least the recorded band times
  the factor and at least the floor and that the measurement's provenance (host, container and revision) is
  recorded, while both scratch trees are red and name the offending section — restoring either makes it green

#### Scenario: A run that an outer clock kills can still say where it was

- **GIVEN** the fixture switch on, a small progress interval, and a section that runs longer than that interval
- **WHEN** the run is in that section
- **THEN** progress lines carry the section's `#<N>`, its id, its running elapsed time and the slowest sections so
  far, and none of them stops the run or turns anything red — the budget remains the only clock that can
- **AND** a section that finishes inside the interval prints no progress line for itself

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
settled-frame discipline and its premise/attribution semantics are the model for a bounded wait and are unchanged
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

### Requirement: The run reports each section's outcome counts and its slowest sections

A run of `skills/teamsmith/tests/smoke.sh` SHALL report, once per started section and no later than the
line that closes it, the section's elapsed time in seconds and the outcome counts accumulated while it ran:
the number of `✓` assertions, the number of `✗` assertions, and the number of `SKIP` attributions, in a
form the section's own line carries (for example `12b · … · 41.2s · ✓37 ✗0 SKIP1`). It SHALL print the
closing line for the last started section before the run's result line, so every started section is
accounted for. At the end of the run it SHALL print one summary of the **slowest N sections** (N = 5, a
fixture-only knob may change it), each with its id, its seconds and its counts.

The counts SHALL be deltas of the run's own counters: summed over the closing lines they SHALL equal the
totals the run's result line prints, so the accounting can be checked against the run itself.

This accounting SHALL be a **report and never a verdict**: no line it adds may carry the colour-red mark the
gate's red-line counting matches (`  \033[31m✗\033[0m`), no duration it reports may be compared to a
threshold by it, a section that is merely slow MUST stay green, and neither the closing lines nor the
summary may change the run's exit status or suppress a subsequent section. A run that selects sections
(`verification#A changed-path list selects the sections to run, or the full suite`) numbers the sections it
actually starts from 1 and obeys the same rule.

#### Scenario: A green run accounts for every section and closes with the slowest ones

- **WHEN** `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` runs on a clean tree
- **THEN** it exits 0, every started section has exactly one closing line carrying its `✓`/`✗`/`SKIP` counts
  and its seconds (including the last section, whose closing line precedes `== 结果 ==`), the sums of the
  per-section counts equal the totals in `== 结果 ==`, and a slowest-N summary naming at most five sections
  with their seconds is printed before the run ends

#### Scenario: The accounting is not a red line and does not disturb the existing red-line counters

- **GIVEN** the gate's sources with one section made slower on purpose under the fixture switch (no
  assertion, threshold or skip rule changed)
- **WHEN** the run finishes and `bash skills/teamsmith/tests/flip-m33.sh` runs
- **THEN** the slower section's line carries its measured seconds, no closing line carries the red mark
  `  \033[31m✗\033[0m` (a count of `✗` assertions is plain text, not the marker), the run stays green, and
  `flip-m33.sh` reports the same red-mark counts and the same full-run token expectations as before

#### Scenario: A failing section is described, not decided, by the counts

- **GIVEN** a run in which one section's assertion fails
- **WHEN** that section closes and the run ends
- **THEN** its closing line reports at least one `✗`, the run's exit status is the same as it was before the
  accounting existed, and the sections after it still run

### Requirement: A changed-path list selects the sections to run, or the full suite

`skills/teamsmith/tests/section-paths.tsv` SHALL be the one place a path→section claim lives, with comment
header lines documenting the exempt path class, the prologue keys and the matcher's semantics, and one row
per section carrying the section's key, its id as the sources spell it, the repo-relative patterns it
covers, the keys of the sections that must run before it, and the basis of the claim. `bash
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

With `--check` the selector SHALL verify its own basis in pure logic: every section in the gate's sources
has exactly one row and every row's key resolves to exactly one section; a literal pattern (one without a
wildcard) exists in the tree, except for a specifically attributed absent internal prerequisite in a product-only
checkout under `verification#A gate that cannot judge says so`; the exempt class is claimed by no row; every `needs` key exists and
refers to a section that appears earlier in the sources; and a real-tree path token named inside a section's
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

`bash skills/teamsmith/tests/smoke.sh --paths <path>…` and `bash skills/teamsmith/tests/smoke.sh --select
<key>[,<key>…]` SHALL run the selection: the prologue, the selected sections and their `needs` closure, in
source order, with the unselected sections not executed; an unknown key exits non-zero and runs nothing. A
run without either flag SHALL behave exactly as before (every section runs) — the full suite stays the
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

### Requirement: A selected run says what it did not run

A run that selects sections SHALL NOT be mistakable for a full run: before its first section it SHALL print
one header naming the decision, how many of the gate's sections it will run and which keys it will not, its
result line SHALL use a distinct token (`== 选段结果 ==`, never `== 结果 ==`) and the run MUST NOT print the
full-run token `smoke 全绿` in any selection mode. The not-run list SHALL appear within the last lines of
the run's output, so the output tail that `team review` records
(`verification#The record states what was verified`) carries it without a rerun. A report whose evidence is
a selected run SHALL name the sections that did not run and MUST NOT present the run as a full-suite run;
`PASS` for a selected run means the sections it ran were green, never that the gate ran.

#### Scenario: The selection is visible in the run and in the recorded tail

- **WHEN** `bash skills/teamsmith/tests/smoke.sh --select 12b` runs and the last 25 lines of its output are
  read
- **THEN** the header names the decision and the unselected keys, the last 25 lines contain the not-run list,
  the result line reads `== 选段结果 ==`, `smoke 全绿` appears nowhere in the output, and the exit status
  reports only the sections that ran

#### Scenario: A run with no affected section runs nothing and claims nothing

- **WHEN** `bash skills/teamsmith/tests/smoke.sh --paths docs/team/BOARD.md` runs
- **THEN** it prints that no section is affected, prints no result line at all, prints no `smoke 全绿`, runs
  no section, and exits 0 — the message is a decision, not a green gate

#### Scenario: An unknown selection is refused before anything runs

- **WHEN** `bash skills/teamsmith/tests/smoke.sh --select no-such-section` runs
- **THEN** it exits non-zero, names the unknown key, and starts no section

### Requirement: A gate that cannot judge says so

The correctness gate SHALL distinguish a product-only checkout, which deliberately contains the published product and `openspec/specs/` but none of this development repository's internal surfaces (`docs/team/`, `openspec/changes/`, `AGENTS.md`, `SCOPE.md`, `.pi/prompts/`, `.pi/skills/`), from an internal or partially populated checkout. Classification MUST inspect the checkout under test before creating fixture data; inherited project identity, CI environment, and a fixture-created ledger MUST NOT decide it. An empty, unreadable, malformed or partially populated internal surface MUST NOT be treated as absent. No production environment override SHALL turn a missing product or internal-checkout file into a prerequisite skip.

Only a check whose named prerequisite is one of those deliberately absent internal surfaces SHALL skip on a product-only checkout. Each such attribution MUST print `SKIP（条件不满足）`, the affected check and missing prerequisite, be counted as a skip rather than a pass, and reach the gate's output and per-section/run accounting. Missing product files, unavailable required tools, a failed executed assertion, and corruption of a present internal surface MUST retain their existing failure/degradation rules; the checkout classification MUST NOT swallow them. An executed check's verdict MUST rest on evidence the subject itself carries: when the call's command word is the wrapped command itself (`tmux`), an isolation wrapper defined in one file MUST NOT certify a mutation call made by another file, while a dedicated wrapper name defined alongside the caller MAY keep its directory-level meaning; a check MUST NOT be reported as satisfied on evidence the subject does not have. A run with prerequisite skips and no failures SHALL exit 0, without claiming the skipped checks passed; a real failure alongside skips MUST still exit non-zero.

The same correctness command SHALL run on both shapes, with no second public suite. The product's static checks, skill loading, published-spec validation, container-build checks and every ledger-independent fixture MUST remain eligible exactly as before (including the existing FAST/full and tool-premise rules). A fixture that provisions its own ledger MUST still run in the product-only checkout. For an internal checkout, every pre-existing assertion MUST still execute with its original verdict and at least its pre-change per-section pass count under identical run settings; replacing an existing assertion with a new one MUST NOT satisfy that coverage comparison. CI's correctness step MUST retain its command and blocking failure semantics.

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
- **THEN** the command remains `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh --keep </dev/null`, without FAST or correctness `continue-on-error`, and succeeds when all applicable checks succeed
- **AND** a failing applicable product assertion makes that same command fail; performance remains a separate non-blocking conclusion

