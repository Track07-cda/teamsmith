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

