## MODIFIED Requirements

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

When the holder record publishes the run's expected upper bound, the queue cap SHALL be judged against the
holder's expected remaining time instead of against a flat `TEAM_SMOKE_LOCK_WAIT`: the waiter SHALL wait up to
`clamp(remaining + 60 s, TEAM_SMOKE_LOCK_WAIT, 4 × TEAM_SMOKE_LOCK_WAIT)`, where
`remaining = expected − (now − started)`, and it SHALL print that arithmetic together with the three numbers.
When the record publishes no bound (an older writer, or an unreadable record) the cap SHALL remain
`TEAM_SMOKE_LOCK_WAIT` exactly as before. Whenever the cap is exceeded, the failure text SHALL say in one line
which kind of run holds the lock (`top` or `nested`), which seat and worktree it belongs to, how long it has
run, and its expected bound — so that a nested fixture run reads as a nesting artefact rather than as a broken
gate. This added accounting MUST NOT add a verdict token, MUST NOT change the closed token set, and MUST NOT
change the verdict parser's behaviour.

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

- **GIVEN** a fixture holding the gate lock whose holder record publishes `started` 10 s ago and
  `expected=400 s`, and a waiter whose `TEAM_SMOKE_LOCK_WAIT=2`
- **WHEN** the waiter runs
- **THEN** it waits for the published remaining time (about 390 s plus the margin) instead of failing at 2 s,
  and its queue line prints the arithmetic with `remaining`, the computed cap and `TEAM_SMOKE_LOCK_WAIT`
- **AND** a holder whose record publishes no `expected` still fails at `TEAM_SMOKE_LOCK_WAIT` seconds, with the
  failure line naming whatever fields the record does carry and `?` for the ones it does not

## ADDED Requirements

### Requirement: The gate lock's holder record names its kind, its owner, its elapsed time and its bound

The record a waiter reads while the shared gate lock is held SHALL describe the run that holds it instead of
naming the suite alone. The lock's holder record and one record per live run (a top-level run and every nested
run inside it) SHALL carry the same fields: the run kind (`top` or `nested`), the seat and the worktree the run
belongs to, the run's start time, its expected duration and its bound (the sum of the section table's measured
band and of its per-section budgets over the sections the run will execute), the number of sections counted, and
whether the run took the lock or opted out of it. A nested run's record SHALL additionally name its ancestor.
The seat and the worktree SHALL be derived from the runtime directory by the same rule that resolves the sender
of `team notify`, never from a tmux window name; when the runtime directory cannot be resolved the record SHALL
say so instead of guessing. Only the process that actually holds the lock SHALL write and remove the lock's
holder record: a run that merely inherited the wrapped marker MUST NOT overwrite it and MUST NOT remove it, so a
waiter never reads a process that does not hold the lock and never reads `holder unknown` while the real holder
is alive. A waiter SHALL print this record when it starts queueing and again when it hits its cap, and SHALL
derive `elapsed` from the recorded start time. Records whose process is gone SHALL be reported as stale and
ignored; the gate MUST NOT remove records it did not write.

#### Scenario: A nested run holding the lock is named as nested, with its seat and its elapsed time

- **GIVEN** a scene where the shared lock is held and a nested run is registered inside the holder, with its own
  seat, worktree, start time and expected bound
- **WHEN** a second gate run queues and prints the holder
- **THEN** its line names the run as `nested`, names the seat and the worktree, prints how long that run has been
  going and its expected bound, and never prints `holder unknown`
- **AND** removing the nested registration makes the same line lose the `nested` fields and the assertion fails
  naming the missing field, and restoring it makes the line complete again

#### Scenario: A nested run does not overwrite or delete the real holder's record

- **GIVEN** a fixture that holds the lock and writes its own holder record, and a run that starts inside it with
  the wrapped marker in its environment
- **WHEN** that inner run finishes while the fixture is still holding the lock
- **THEN** the holder record still names the fixture, and it is still present after the inner run exits

### Requirement: A nested run does not queue on the machine lock, and its work stays inside the section that spawned it

The machine lock SHALL serialize top-level gate runs only. A run that is nested inside a run holding the lock —
proved by walking the process ancestry to the recorded holder and matching its start time, not by an inherited
marker that a fixture may clear — SHALL NOT queue on the lock, because queueing there hands the machine's single
shared resource to a fixture and can deadlock against its own ancestor. It SHALL instead register itself in the
lock's run records with its kind, its owner, its start, its expected duration, its bound and its ancestor, so a
waiter can attribute what it is waiting for. A run that cannot prove a live ancestor holding the lock SHALL be
treated as a top-level run and queue exactly as before, so skipping the queue is never unconditional. A nested
run SHALL be bounded by the section that spawned it: its own section guard SHALL be armed with a deadline taken
from the ancestor's currently armed section (the holder record publishes the section guard's heartbeat, and the
nested run reads the ancestor's armed budget from it), falling back to its own table budget when that heartbeat
is unavailable. When the deadline passes, the nested run's own watchdog SHALL name the section and the bound,
stop the run and leave its scene — it MUST NOT keep occupying anything silently — and its registration SHALL be
gone afterwards. A fixture that leaves a registered nested run alive after its spawning section has closed SHALL
be reported in one visible line naming that run, and only pids the fixture registered may be signalled. The
residual window in which two seats' nested runs could overlap is the explicit opt-out (`TEAM_SMOKE_NO_LOCK=1`,
no `flock`, or the fast mode, which runs no real-process section); the record SHALL mark that window, and the
documented discipline SHALL state it, so it is observable rather than assumed away. Without `/proc` the
ancestry cannot be proved and every run SHALL be treated as top-level.

#### Scenario: A nested run skips the queue and registers itself

- **GIVEN** a top-level run that holds the lock, and a second run started inside its process tree
- **WHEN** the inner run reaches the lock block
- **THEN** it does not queue, it prints and records that it is nested with its ancestor, and a third run arriving
  meanwhile still queues on the lock and names the holder

#### Scenario: A run that cannot prove its ancestor queues like a top-level run

- **GIVEN** a run whose environment carries the wrapped marker but whose process ancestry contains no live
  recorded holder
- **WHEN** it reaches the lock block
- **THEN** it queues on the lock and is recorded as `top`, so clearing the marker cannot be used to skip the queue

#### Scenario: A nested run past its bound is named and stopped instead of occupying silently

- **GIVEN** a nested run armed with a short deadline derived from the section that spawned it, and a fixture
  section that never returns
- **WHEN** the deadline passes
- **THEN** one line names the section and the bound, the run is stopped at the suite's own safe point, its scene
  is kept, its registration is gone, and the lock it may have taken is free again
- **AND** removing the deadline leaves the run occupying silently and the same assertions fail

#### Scenario: A nested run that outlives its section is reported, not hidden

- **GIVEN** a fixture that starts a registered nested run in the background and closes its section before that
  run ends
- **WHEN** the section closes
- **THEN** the gate prints one visible line naming the surviving nested run, and only the pids the fixture
  registered are signalled
