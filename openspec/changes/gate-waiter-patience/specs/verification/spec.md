## MODIFIED Requirements

### Requirement: The hard timeout covers the gate run, not the queue

When gates are configured, `team review` SHALL serialize the gate run on the shared gate lock
(`${TEAM_SMOKE_LOCK:-${TMPDIR:-/tmp}/teamsmith-smoke.lock}`) **before** the hard-timeout clock starts, so the
queue wait is never counted against `TEAM_REVIEW_TIMEOUT`. While waiting it MUST print the holder recorded in
`<lock>.holder`; the queue wait MUST be bounded by `TEAM_SMOKE_LOCK_WAIT` (default 1800 s), extended to `4 ×`
that while the live run's heartbeat keeps moving (below). When that cap is exceeded the verdict MUST be `FAIL` with
the record stating that the gate did not run and naming the holder — the queue MUST NOT produce a `TIMEOUT`
verdict. When the environment already records that an ancestor holds the gate lock, the review MUST NOT queue
again. When no queue mechanism is available (no `flock`), the review MUST print that the queue is not enforced
instead of degrading silently.

The record SHALL account for the two intervals separately (`queued Ns / ran Ns / limit Ns`) and SHALL name the
outcome distinguishably: `PASS` (gates ran, exit 0), `FAIL` (gates ran and failed, or the queue cap was
exceeded), `TIMEOUT` (the run was killed by the hard timeout, whose record MUST carry the run duration as
`ran=Ns`). The verdict line MUST keep the closed token (`PASS|FAIL|TIMEOUT|SKIPPED|UNKNOWN`), so
`team_review_verdict` still parses the record.

The queue cap SHALL follow the running gate's heartbeat instead of a projection of the record's expected
duration. The waiter SHALL read the heartbeat from **any** live record of that lock — the holder record or a run
registration — because a run whose holder record carries no heartbeat (a review whose gate is a child process, or
a top-level suite whose holder record names the locking wrapper) is only visible through the registration that
does move. A published heartbeat file counts as **usable** only while its last movement is less than
`TEAM_SMOKE_LOCK_WAIT` ago; a heartbeat whose last movement is at least `TEAM_SMOKE_LOCK_WAIT` ago counts as no
usable heartbeat, so the boundary belongs to “not usable” and every value of the silence is classified. While a
usable heartbeat moves, the waiter SHALL keep waiting and its cap SHALL be `4 × TEAM_SMOKE_LOCK_WAIT`; when no
usable heartbeat exists — an older writer, a record whose `heartbeat=` is `-`, a published path whose file is
gone, or a silence of at least `TEAM_SMOKE_LOCK_WAIT` — the cap SHALL be `TEAM_SMOKE_LOCK_WAIT` exactly as
before, so a stalled holder is waited out for at most `TEAM_SMOKE_LOCK_WAIT`. The waiter SHALL re-evaluate this on
every round of its poll and SHALL print both bounds together with the heartbeat's state; when the cap is exceeded
the failure SHALL name the holder and say whether the heartbeat had been silent or had never been published.
`expected` and `bound` SHALL stay in the record and be printed, and they MUST NOT decide patience. A moving
heartbeat MUST NOT extend the wait past `4 × TEAM_SMOKE_LOCK_WAIT`, so no cap can make a waiter wait without a
bound.

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

#### Scenario: The cap follows the holder's published remaining time

- **GIVEN** a fixture holding the gate lock whose live run publishes `started` 10 s ago and `expected=400 s`, a
  heartbeat that has not moved for longer than the wait, and a waiter whose `TEAM_SMOKE_LOCK_WAIT=2`
- **WHEN** the waiter runs
- **THEN** it fails once its own wait reaches `TEAM_SMOKE_LOCK_WAIT` instead of waiting out the published remaining
  time, its queue line still prints the record's `expected` and `bound`, the failure line names the holder and the
  silent heartbeat, and the cap no longer follows the published remaining time — the scenario name records the
  field that is still printed, not a bound that still decides

#### Scenario: The queue waits while the holder's heartbeat keeps moving

- **GIVEN** a fixture holding the gate lock whose live run publishes a heartbeat file that keeps moving, and a
  waiter whose `TEAM_SMOKE_LOCK_WAIT=2`
- **WHEN** the waiter runs
- **THEN** it is still waiting after its own `TEAM_SMOKE_LOCK_WAIT` has elapsed, its queue line prints the
  heartbeat's state together with both bounds, and it takes the lock as soon as the holder releases it — a cap that
  ignores the heartbeat fails that waiter at `TEAM_SMOKE_LOCK_WAIT`, which is the failure this requirement removes

#### Scenario: A heartbeat that stops moving ends the wait at the flat cap

- **GIVEN** a fixture holding the gate lock whose live run published a heartbeat that has not moved since,
  `TEAM_SMOKE_LOCK_WAIT=2`, and a waiter that starts after the heartbeat went silent
- **WHEN** the waiter runs
- **THEN** it fails once its own wait reaches `TEAM_SMOKE_LOCK_WAIT`, naming the holder and the silent heartbeat,
  and it does not wait out a bound projected from the record

#### Scenario: A moving heartbeat cannot buy an unbounded wait

- **GIVEN** a fixture holding the gate lock whose heartbeat keeps moving for longer than
  `4 × TEAM_SMOKE_LOCK_WAIT`, and a waiter
- **WHEN** the waiter runs
- **THEN** it does not fail before its own wait reaches `4 × TEAM_SMOKE_LOCK_WAIT`, fails once it does and names
  the holder, and never waits beyond that ceiling however long the heartbeat keeps moving

#### Scenario: An older record with no heartbeat keeps today's patience

- **GIVEN** a holder record that publishes no heartbeat field, and a waiter whose `TEAM_SMOKE_LOCK_WAIT=2`
- **WHEN** the waiter runs
- **THEN** it fails once its own wait reaches `TEAM_SMOKE_LOCK_WAIT` exactly as before, its failure line names the
  holder and prints `?` for the fields the record does not carry, and its output does not claim a moving or stalled
  heartbeat — “no heartbeat was ever published” is an observable fact, not an invented state

#### Scenario: A review's holder record without a heartbeat follows the run it spawned

- **GIVEN** a `team review` holding the gate lock whose own record publishes `heartbeat=-` and whose gate spawned a
  suite that registered itself with a heartbeat that keeps moving, and a waiter whose
  `TEAM_SMOKE_LOCK_WAIT=2`
- **WHEN** the waiter runs
- **THEN** the waiter is still waiting after its own `TEAM_SMOKE_LOCK_WAIT` has elapsed because the live
  registration's heartbeat is moving, it names that state in its queue line, and it takes the lock when the review
  releases it
