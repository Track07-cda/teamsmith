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

