## ADDED Requirements

### Requirement: `team change status <id>` reports a change's readiness

`team change status <id>` SHALL print every task whose brief declares `change: <id>`, each with its phase, agent,
board status and evidence (the review record's verdict, the phase-specific evidence, or what is missing), the
change's delta files with the tasks that declared each and the tasks whose branch touched it, and one readiness
line. It MUST exit 0 when at least one task is mapped and every mapped task is finished, and MUST exit non-zero
otherwise, naming each blocking task and its missing evidence. The command MUST NOT write any file and MUST NOT
change any board status. `--json` MUST print the same data as one JSON object carrying `id`, `ready`, `tasks`,
`deltas` and `blockers`. A verify task whose agent also authored an apply task of the same change MUST be marked
`self-verify: <agent>`. An id that matches neither a brief nor a change directory MUST exit non-zero and say both
facts.

#### Scenario: A change whose tasks are all finished is ready

- **GIVEN** a fixture project whose briefs map an apply task (board `done`, review record `PASS`) and a verify task
  (board `done`, review record `PASS`) to change `alpha`, and whose `openspec/changes/alpha/` exists
- **WHEN** `team change status alpha` runs
- **THEN** it exits 0, prints both tasks with their verdicts and the readiness line says ready

#### Scenario: One unfinished sibling blocks the readiness

- **GIVEN** the same project with an additional mapped task whose board status is `wip`
- **WHEN** `team change status alpha` runs
- **THEN** it exits non-zero, the blockers section names that task, its `wip` status and its missing evidence, and
  no file or board status changed (`git status --porcelain` in the fixture is unchanged)

#### Scenario: An unknown id says so

- **WHEN** `team change status no-such-change` runs
- **THEN** it exits non-zero and names both the missing briefs and the missing change directory

#### Scenario: The JSON view carries the same facts

- **WHEN** `team change status alpha --json` runs in the not-ready fixture
- **THEN** the output parses as one JSON object with `ready: false`, a `tasks` entry per mapped task, and the
  unfinished task in `blockers`

#### Scenario: A self-verifying assignment is visible

- **GIVEN** a change whose verify task's `agent:` is also the agent of one of its apply tasks
- **WHEN** `team change status <id>` runs
- **THEN** the verify task's line carries `self-verify: <agent>` and names the apply task it authored

### Requirement: A change's tasks are grouped in the digest and the panel

`team digest` SHALL carry one section that groups tasks by change: one line per non-archived change with its task
tokens (`<ID> <board-status>`), a ready/not-ready mark, and a bounded list (`+N` beyond the bound). A change
directory with no task pointing at it and a task pointing at a missing change directory MUST each be visible rather
than silent. The console's changes block SHALL carry the same grouping per change, bounded to a fixed number of
task tokens, and the `--print`/`--json` machine exits MUST be unchanged by that block. The new section MUST NOT
renumber the existing digest sections.

#### Scenario: The tokens agree with the change status command

- **GIVEN** a fixture project with change `alpha` mapped to one `done` apply task and one `wip` apply task
- **WHEN** `team digest` runs
- **THEN** the change section contains a line naming `alpha`, both task ids with their board statuses, and the
  not-ready mark, matching `team change status alpha`'s task list

#### Scenario: The list is bounded

- **GIVEN** a change mapped to more tasks than the section's bound
- **WHEN** `team digest` runs
- **THEN** the section prints the bound and a `+N` tail, and the existing sections `[1]`–`[5]` keep their numbers

#### Scenario: Nothing to show collapses

- **GIVEN** a fixture project whose briefs declare no change
- **WHEN** `team digest` runs
- **THEN** the change section prints its single empty marker and no task token

#### Scenario: The panel block is console-only

- **GIVEN** the same fixture project
- **WHEN** `team monitor --print` and `team monitor --json` run, and `team __panel-data --block changes` runs
- **THEN** the two machine exits are byte-identical to their output before this change (apart from the timestamp)
  while the changes block's JSON carries the per-change task tokens

### Requirement: An archive waits for every task of the change

A task whose `phase:` is `archive` SHALL NOT be set to `done` while any other task mapped to the same change is
unfinished: `team board set <ID> done` MUST refuse and name the unfinished task(s) with their board status and
missing evidence, using the same readiness predicate as `team change status`. The refusal MUST leave the board row
unchanged. The existing explicit override (`TEAM_BOARD_DONE_FORCE=1` together with a written reason) and its audit
record MUST keep working.

#### Scenario: An unfinished sibling blocks the archive task's done

- **GIVEN** a fixture project with an archive-phase task `A1` for change `alpha` whose archived directory exists,
  and another mapped task whose board status is `wip`
- **WHEN** `team board set A1 done` runs
- **THEN** it exits non-zero, names the `wip` task and its missing evidence, and `team board row A1` still reports
  its previous status

#### Scenario: All finished, the archive task may be done

- **GIVEN** the same project with every mapped task finished
- **WHEN** `team board set A1 done` runs
- **THEN** it succeeds and appends the evidence line to `docs/team/reviews/A1-done.md`

#### Scenario: The override still records itself

- **GIVEN** the unfinished sibling of the first scenario
- **WHEN** `TEAM_BOARD_DONE_FORCE=1 TEAM_BOARD_DONE_REASON="sibling accepted by the user" team board set A1 done`
  runs
- **THEN** the command succeeds, the audit line says `FORCED`, and the reason is recorded

#### Scenario: One predicate, two consumers

- **GIVEN** the not-ready fixture of the first scenario
- **WHEN** `team change status alpha` and `team board set A1 done` both run
- **THEN** both name the same unfinished task as the blocker, and after that task's evidence lands both flip to
  ready/`done` without any other change
