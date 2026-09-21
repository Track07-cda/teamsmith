## ADDED Requirements

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
