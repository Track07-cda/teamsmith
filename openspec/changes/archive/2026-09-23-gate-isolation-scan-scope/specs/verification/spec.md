## ADDED Requirements

### Requirement: The fixture-trace scan reads ledger state, not traffic records

The gate's fixture-trace scan — the shared assertion behind every isolation claim that the fixtures wrote nothing
into the caller's real project — SHALL search the caller's ledger state only: the files under the invoking project's
`docs/team/inbox/**` and `.pi/team/state/**`, resolved from the invoking checkout's git common directory so that a
gate run inside a task worktree still scans the project's main roots, and it SHALL report each hit by path so the
failing assertion can name it.

Exactly two paths SHALL be out of scope, because they are **traffic records** — their content is what some caller
did or printed, so a fixture's own name appearing there is their intended function, not state written into the
project:

- `.pi/team/state/bg/**` — the gate's own background-job logs;
- `.pi/team/state/tmux-calls.log` — the tmux call audit log, whose own contract is
  `boundary#The gate's actions are logged, and no window carries a destructive-call grant`.

Both exclusions MUST be by exact path. Every other file under the two roots MUST stay in scope, including a file
in a subdirectory, a file that merely shares the audit log's name, and a directory that merely shares the excluded
job-log directory's name, and a trace planted in any of them MUST be reported.

The scan MUST stay falsifiable: a fixture trace planted in the ledger — `docs/team/inbox/**` or any file under
`.pi/team/state/**` other than the two excluded paths — MUST be found and reported by the same scan. The positive
and negative controls of the isolation sections are part of this requirement, so a green isolation assertion can
never come from a scan that stopped scanning.

#### Scenario: A trace in the audit log is not a leak

- **GIVEN** a scratch project root whose `.pi/team/state/tmux-calls.log` holds a line carrying a fixture's session
  name and argv, in the shape the gate records a private-socket `new-window`/`kill-session` call
- **WHEN** the fixture-trace scan runs over that root
- **THEN** it reports no hit and the isolation assertion stays green — on the pre-change scope the same line is
  reported, which is the sticky red this change removes (that red side is in the delivery report)

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
