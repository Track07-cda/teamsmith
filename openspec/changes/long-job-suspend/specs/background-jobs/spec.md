## Purpose

The session-side background lane for long jobs: the team-bg extension's harness-facing tool surface, its
completion wake-up discipline, its own ledger (`state/bg.log`, in the lane's state directory), and the restart
evidence rule. The
CLI side (`team bg list` / `team bg stop`) is specified in `boundary`; the turn-end visibility of a suspension
is specified in `notify-and-inbox`.

## ADDED Requirements

### Requirement: The lane's tool surface teaches suspend-and-wake as the default

The team-bg extension's harness-facing text — `team_bg_run`'s description, prompt snippet and guidelines and
its start-result text, and `team_bg_wait`'s description — SHALL present ending the turn after a start as the
default and the job's completion wake-up as the normal harvest point. None of them SHALL demand a harvest
before the turn ends, and none SHALL frame the wake-up as a cost, a penalty or a loss. `team_bg_wait`'s surface
SHALL describe in-turn waiting as the bounded exception, permitted only when the job is expected to finish
within the inline-wait budget the text names, its result blocks the immediate next step, and no other task work
can advance meanwhile. The merged completion wake-up SHALL keep naming every finished unharvested job id and
pointing at `team_bg_wait` as the way to harvest it.

#### Scenario: The registered tool texts carry the suspend default

- **GIVEN** a fixture harness that loads `extension/team-bg.ts` and captures the registered tool definitions
- **WHEN** `team_bg_run`'s description, prompt snippet, guidelines and start-result text and
  `team_bg_wait`'s description are read
- **THEN** each presents ending the turn after a start as the default and the completion wake-up as the normal
  harvest point, `team_bg_wait`'s description names the three exception conditions and the inline-wait budget
  figure, and none of them contains a demand to harvest before the turn ends or frames the wake-up as a cost

#### Scenario: The old duty wording is gone

- **GIVEN** the same fixture
- **WHEN** the same texts are searched for the retired wordings `Harvest it with team_bg_wait before you end
  your turn` and `harvest every job with team_bg_wait before ending your turn`
- **THEN** there is no hit — and the fixture's red side, the same search against a scratch copy with the old
  wording restored, prints the offending file and fails

#### Scenario: The completion wake-up still names the harvest

- **GIVEN** a fixture session with two jobs that finish while unharvested
- **WHEN** the merged wake-up is delivered
- **THEN** its text names both job ids and names `team_bg_wait` as the way to harvest, and a harvested job in
  the same batch stays silent

### Requirement: The lane's ledger makes the wait pattern countable

The lane SHALL append to `state/bg.log` in the lane's own state directory — the directory its job records
live in (ISO-stamped like every existing line): one
`start id=<id> pid=<pid>` line per started job, appended before the job id is returned to its caller; and one
`wait id=<id> outcome=<harvested|running|interrupted> waited_s=<seconds>` line per `team_bg_wait` return,
where `waited_s` measures that call's own wait — never the job's age. The existing ledger lines —
`wake count=<n> ids=…`, `settled-with-unharvested=<n> jobs=…` per turn end, `spawn-error …`, and the CLI's
`stop …` — SHALL keep their shapes byte-for-byte. From the ledger alone a reader SHALL be able to distinguish
a job that was waited on inline (a `start` followed by a `wait outcome=harvested` whose `waited_s` tracks the
job's runtime, with no intervening `settled-with-unharvested` naming that id) from a suspension (a
`settled-with-unharvested` naming the id between its `start` and its harvest), and to audit inline waits
against the inline-wait budget the tool surface names.

#### Scenario: A start and its inline harvest are countable

- **GIVEN** a fixture session that starts a short job and harvests it with `team_bg_wait` in the same turn
- **WHEN** the wait returns
- **THEN** `state/bg.log` holds a `start id=<id> pid=<pid>` line appended before the id was returned and a
  `wait id=<id> outcome=harvested waited_s=<s>` line whose `waited_s` tracks the job's runtime, with no
  `settled-with-unharvested` naming that id between them

#### Scenario: A timed-out wait and an aborted wait are named apart

- **GIVEN** a fixture session with a job that outlives one wait's timeout, and another wait aborted by signal
- **WHEN** both waits return
- **THEN** the ledger gains one `wait id=<id> outcome=running waited_s=…` line for the first and one
  `wait id=<id> outcome=interrupted waited_s=…` line for the second, and neither marks the job harvested

#### Scenario: A suspension reads differently from an inline wait

- **GIVEN** a fixture session that starts a job, ends its turn while the job runs, is woken by the completion
  wake-up, and harvests in the woken turn
- **WHEN** the ledger is read
- **THEN** the `start` line is followed by a `settled-with-unharvested=1 jobs=<id>:running` line and a `wake`
  line naming the id, and the eventual `wait outcome=harvested` line's `waited_s` is near zero — and the red
  side (an implementation recording the job's age as `waited_s`) makes this scenario fail

### Requirement: A restart keeps the job's evidence but not the job table

Jobs are detached: a session restart or exit SHALL NOT signal them, and their `state/bg/<id>.job` records,
their log files and the ledger SHALL persist where the lane wrote them. The job table is per session: after a
restart, `team_bg_wait <id>` for a job a previous session started SHALL fail as unknown, naming the ids the
current session did start, and the extension MUST NOT re-adopt detached jobs into the new session's table;
the on-disk record and log are the way to read such a job's result, and the worker prompt's resume guidance
(`dispatch#The worker prompt makes suspension on background jobs a third legal turn end and teaches the lane
by purpose`) points at them.

#### Scenario: A restarted session refuses the old id and the evidence survives

- **GIVEN** a fixture session that started a long job, and a second session on the same worktree
- **WHEN** the second session calls `team_bg_wait` with the first session's job id
- **THEN** it fails naming the ids the second session started (possibly none), the job's record and log file
  are still on disk, and the job's process is unaffected

#### Scenario: The CLI reads the previous session's records

- **GIVEN** the same restarted setup
- **WHEN** `team bg list` runs against that worktree's state directory
- **THEN** the record appears with its identity verdict under the same rule
  `boundary#\`team bg\` stops a job by the pid it recorded, and prints what it signalled` defines

#### Scenario: Records are not re-adopted and not pruned

- **GIVEN** the same restarted setup
- **WHEN** the second session starts and settles a turn
- **THEN** its job table contains only jobs it started itself (the old id is neither harvestable nor
  re-woken), and the old records and logs are still on disk — the red side (an implementation that scans the
  records into the new table, or one that prunes them at session start) fails this scenario
