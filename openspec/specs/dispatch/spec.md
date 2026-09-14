# dispatch Specification

## Purpose

Hand one work slice to one worker agent: a self-contained brief, its own git worktree and tmux window, and the
guards that stop a dispatch from corrupting another task's work or the machine. Why each guard exists:
`references/protocol.md` (safety model) and `references/philosophy.md` (verifiability, capacity awareness).

## Requirements

### Requirement: A brief is self-contained and names its evidence

`team task <ID> --title <title> --agent <a>` SHALL render `templates/task.md.tmpl` into
`docs/team/tasks/<ID>-<slug>.md` carrying the task id, the agent, deliverables, explicit boundaries, copy-pasteable
acceptance commands and the report path; `team dispatch` SHALL reference that file in the prompt instead of
inlining the work.

#### Scenario: A generated brief carries the contract

- **WHEN** `team task T1.1 --title "first task" --agent dev` runs in an initialised project
- **THEN** `docs/team/tasks/T1.1-*.md` exists and contains the acceptance section and the report path
  `docs/team/reports/T1.1-dev.md`

#### Scenario: The prompt points at the brief

- **GIVEN** a brief at `docs/team/tasks/T1.1-first-task.md`
- **WHEN** `team dispatch dev T1.1 docs/team/tasks/T1.1-first-task.md --print` runs
- **THEN** the rendered prompt contains that path as the single source of scope

### Requirement: A dispatch never mixes two tasks in one worktree

`team dispatch` SHALL refuse to start when the agent's worktree contains uncommitted changes whose recorded task is
a different task; it SHALL proceed when those changes belong to the task being dispatched (resume). The refusal
MUST name the worktree, the number of dirty files and the previous task id.

#### Scenario: Dirty worktree from another task is refused

- **GIVEN** agent `dev`'s worktree has one uncommitted file and teamsmith recorded `dev`'s current task as `T1.0`
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** the command exits non-zero, prints the dirty file count and `T1.0`, and starts no window

#### Scenario: The same task resumes with uncommitted work

- **GIVEN** the same dirty worktree, but teamsmith recorded `dev`'s current task as `T1.1`
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it proceeds and reports that the uncommitted changes belong to the current task

### Requirement: The capacity floor protects the host

`team dispatch` SHALL refuse to start a worker when the host is below a capacity floor: RAM+swap
(`TEAM_MIN_TOTAL_MB`, default 512 MB), MemAvailable (`TEAM_MIN_AVAIL_MB`, default 1024 MB) or **disk** swap free
(`TEAM_MIN_FREE_SWAP_MB`, default 1024 MB). zram MUST be excluded from the swap floor (its pages live in RAM);
zram occupancy above `TEAM_ZRAM_WARN_PCT` (default 85) is a warning only.

#### Scenario: Low free disk swap refuses the dispatch

- **GIVEN** `TEAM_MEMINFO_FILE` points at a fixture with 8000 MB MemAvailable and 300 MB free disk swap
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it exits non-zero and the reason names the free disk swap
- **AND** the same command with `TEAM_MIN_FREE_SWAP_MB=0` no longer refuses for that reason

#### Scenario: zram pages are not counted as headroom

- **GIVEN** `TEAM_SWAPFILE_PATH` points at a fixture whose free swap comes from `/dev/zram0` only
- **WHEN** `team ps` prints the capacity line
- **THEN** the disk-swap figure it uses for the floor is 0, and zram is reported separately as a warning

### Requirement: Model concurrency limits are enforced before dispatch

`team dispatch` SHALL refuse to start a worker when the number of running agents on the same model has reached the
limit set in `TEAM_MODEL_LIMITS` (`<provider>/<model>=<n>`, `*` wildcards supported, `0` = unlimited) and MUST name
the model, the limit and the current count.

#### Scenario: The limit is reached

- **GIVEN** `TEAM_MODEL_LIMITS='kimi-coding/k3=1'` and one running agent already on `kimi-coding/k3`
- **WHEN** a second dispatch on the same model runs
- **THEN** it exits non-zero and prints the model, the limit and the running count

#### Scenario: Zero means unlimited

- **GIVEN** `TEAM_MODEL_LIMITS='kimi-coding/k3=0'` and one running agent on that model
- **WHEN** another dispatch on the same model runs
- **THEN** the model guard does not refuse the dispatch

### Requirement: The adapter template contract is enforced, not guessed

A configured `TEAM_AGENT_CMD` SHALL be expanded for `{cwd}`, `{session_id}`, `{model}`, `{provider}`,
`{prompt_file}`, `{prompt}`, `{skill_dir}`, `{notify_ext}`, `{extra_args}`. An unknown or malformed `{...}` token,
a whitespace-only template and a multi-line template MUST fail the dispatch with an actionable message; a rendered
command MUST contain no leftover `{`. The prompt MUST travel out of band (`{prompt}` is the harness' `argv[0]`), so
its size never lands in the window command line.

#### Scenario: An unknown placeholder fails with the supported set

- **WHEN** `TEAM_AGENT_CMD='myagent {sessionid} {prompt}' team dispatch dev T1.1 <brief> --print` runs
- **THEN** the command exits non-zero and names `{sessionid}`, the supported placeholders and the config key

#### Scenario: A malformed placeholder is not silently passed through

- **WHEN** `TEAM_AGENT_CMD='myagent --dir { cwd } {prompt}' team dispatch dev T1.1 <brief> --print` runs
- **THEN** the command exits non-zero instead of rendering `{ cwd }` into the window command

#### Scenario: A multi-line template cannot become a script

- **GIVEN** a template whose second line is `touch <sentinel>`
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it exits non-zero, explains that the second line would be executed as a new command, and the sentinel
  file does not exist

#### Scenario: A long prompt does not enter the command line

- **GIVEN** a brief larger than 100 KB
- **WHEN** a worker is dispatched with an adapter whose template uses `{prompt}`
- **THEN** the process receives the whole prompt as one argument, byte-for-byte identical to the prompt file, and
  the rendered window command stays short

### Requirement: One task branch per task

With the default `TEAM_BRANCH_MODE=task`, each task SHALL run on `<TEAM_TASK_BRANCH_PREFIX>/<ID>-<slug>` cut from the
protected branch; the PM creates the worktree and branch with git, and `dispatch` only checks the state (it never
switches or rebases anything itself).

#### Scenario: The branch identity is visible

- **GIVEN** a dispatched task `T1.2` in task-branch mode
- **WHEN** `team roster` runs
- **THEN** the agent's row shows the branch `task/T1.2-*`, and `team status T1.2` shows the agent, worktree and
  branch recorded for that task

#### Scenario: A dirty worktree blocks a branch switch

- **GIVEN** `dev`'s worktree has uncommitted changes from `T1.0` and the next task is `T1.1`
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** the dispatch is refused rather than silently switching to the new task's branch
