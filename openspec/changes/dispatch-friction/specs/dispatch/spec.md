## ADDED Requirements

### Requirement: A refused dispatch hands over every blocker, once, with a fix that runs

Before any window is opened — and for `--print` as well — `team dispatch` SHALL judge every pre-launch guard it can
decide without side effects in one pass, and it SHALL report **one** refusal listing every blocker it found. A
refused dispatch MUST NOT open a window, switch a branch, write state or change any board status.

The set judged this way is the guards that today refuse one after another: the brief's header rules (`change:`
shape, the change-less anchor, `deltas:` shape and single-writer, verification independence), the task and
worktree state (more than one brief for the id, an unfinished previous task, a missing worktree, a dirty worktree,
the branch identity), and the launch preconditions (the capacity floor, model concurrency, the session-vs-window
check, the agent executable). A guard that cannot be judged because its precondition is missing SHALL say so in
the report and MUST NOT be reported as passed.

The refusal opens with the first blocker's own first line (there is no separate banner) and ends with a line
stating how many blockers were found. Each blocker is one item that names the artifact it is about (brief path,
worktree, seat, model or session), the reason, and at least one fix printed on its own line:

- `修法：<command>` — a command the PM can paste and run, with concrete values (a worktree path, a branch name, a
  task id), never a placeholder;
- `改行：<exact line>` — the exact brief header line to write, for blockers whose fix is a header value.

`--force` keeps each guard's own semantics: with `--force`, a blocker that guard allows to be overridden is
printed as a warning and yields exactly one audit line in `state/watchdog.log` — written only after a launch
really happened, and never for `--print`; a blocker with no override still refuses. Without `--force`, an
overridable blocker is a refusal item like any other. Runtime failures after the preflight (no launch proof, an
adapter exiting non-zero) stay governed by `dispatch#A dispatch proves the agent started, or fails loudly`.

#### Scenario: Every known blocker is handed over in one refusal

- **GIVEN** a brief whose `deltas:` value is malformed, a worktree parked on another task's branch, an unfinished
  previous task recorded for the seat, and a board row for the task
- **WHEN** `team dispatch dev P200 <brief>` runs
- **THEN** the single invocation exits non-zero and its output names all three blockers, each with its artifact
  and reason, ends with a line counting 3, and carries at least one `修法：` or `改行：` line per blocker
- **AND** no window was requested, `state/<agent>.env` is unchanged and the board row is unchanged

#### Scenario: Applying the printed fixes in one pass clears the refusal

- **GIVEN** a fixture whose blockers are all clearing routes: a malformed `change:` line, a malformed `deltas:`
  line and a worktree parked on another task's branch
- **WHEN** every printed `改行：` line is written into the brief and the printed `git switch` command is run inside
  the fixture
- **THEN** the next `team dispatch dev P200 <brief>` exits 0 and none of those blockers is reported

#### Scenario: `--print` prints the same refusal and no prompt

- **GIVEN** the same three-blocker fixture
- **WHEN** `team dispatch dev P200 <brief> --print` runs
- **THEN** it exits non-zero, prints the same three blockers and no `=== 提示词 ===` section

#### Scenario: `--force` keeps the audit contract under several blockers

- **GIVEN** a fixture whose only blockers are overridable (a change-less brief with no anchor, a delta
  single-writer conflict and an unfinished previous task)
- **WHEN** `team dispatch dev P200 <brief> --force` really starts the worker (the record-only tmux shim the smoke
  suite uses)
- **THEN** it proceeds with one warning per overridden blocker and `state/watchdog.log` gains exactly one line
  per overridden blocker
- **AND** the same command with `--print --force` writes no audit line

#### Scenario: An unjudgeable guard is named, not reported as passed

- **GIVEN** the same fixture with the worktree directory removed while an unfinished previous task is recorded
- **WHEN** the dispatch runs
- **THEN** the refusal carries the missing-worktree blocker with its `git worktree add` fix and says the branch
  identity could not be judged, instead of claiming the branch was checked

### Requirement: A dispatch warns before a seat that burned its last round

Whenever `team dispatch` reaches its pre-launch phase for a resolved seat — `--print` included — it SHALL print a
visible, non-blocking warning when either leg of the seat's last round is judgeable and bad:

- the seat's latest death record, read through `agent-death-reason`'s reader, is classified `quota` or `balance`:
  the warning names the category, its source and its time, and the raw evidence line when one is readable;
- the seat's recorded previous round produced no session content: the warning names that round and its session
  file, and uses the tool's own coarse vocabulary (`0 bytes ≈ 0 tokens`).

The zero-output leg is judged from a record the previous launch wrote: the seat's session id and the session
file's size at launch, recorded in `state/<agent>.env`. On the next dispatch for that seat, the same session
file's current size equal to the recorded size is the evidence; a missing record, a missing or unreadable file,
or a value that cannot be parsed means the leg is not judged.

The warning MUST NOT change the exit status, block the dispatch, open a window by itself or be repeated as a
refusal, and when neither leg can be judged the dispatch SHALL print nothing about the seat's last round — silence,
never a guess. The dispatch proceeds to its normal preflight and launch in every case.

#### Scenario: A quota death is named before the launch

- **GIVEN** `state/deaths.log` holds a `quota` record for `dev` (pane source, raw line
  `weekly usage limit exceeded (403)`) and the fixture is otherwise dispatchable
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** the output names `quota` and the raw line, and still prints the prompt (the warning did not refuse)

#### Scenario: A round that produced nothing is named

- **GIVEN** `state/dev.env` records the previous round's session id and `sid_bytes=N`, and that session file is
  exactly N bytes
- **WHEN** the dispatch runs
- **THEN** the output says the previous round produced 0 bytes (≈ 0 tokens) and names the session file
- **AND** appending one byte to the file before the dispatch makes that warning disappear

#### Scenario: Silence when the evidence is missing

- **GIVEN** no `quota`/`balance` death record and no parseable round record (and, in a second fixture, a recorded
  session file that no longer exists)
- **WHEN** the dispatch runs
- **THEN** the output carries neither the death warning nor the zero-output warning

#### Scenario: The warning never blocks the launch

- **GIVEN** the quota record of the first scenario
- **WHEN** `team dispatch dev T1.1 <brief>` really starts the worker (the record-only tmux shim)
- **THEN** the window is requested, the launch proof path is unchanged and the command exits 0

#### Scenario: A normal death and a productive round do not warn

- **GIVEN** a death record classified `window` and, in a second fixture, a session file larger than the recorded
  `sid_bytes`
- **WHEN** the dispatch runs
- **THEN** neither warning is printed

## MODIFIED Requirements

### Requirement: A dispatch never mixes two tasks in one worktree

`team dispatch` SHALL refuse to start when the agent's worktree contains uncommitted changes whose recorded task is
a different task; it SHALL proceed when those changes belong to the task being dispatched (resume). The refusal
MUST name the worktree, the number of dirty files and the previous task id.

The guard covers the unfinished-task leg of the same rule too: when teamsmith's recorded task for the agent is a
different task that has not finished, and the worktree is still on that task's branch, `team dispatch` SHALL
refuse to start, naming the previous task, its board status, why it is unfinished, the worktree and the branch.

Both legs SHALL be judged before any window is opened and SHALL join the single pre-launch refusal
(`dispatch#A refused dispatch hands over every blocker, once, with a fix that runs`): each prints both of its
routes — `team resume --agent <agent>` and `team dispatch … --force` — as pasteable commands, and when other
blockers exist they are items of the same one refusal rather than a second round-trip.

#### Scenario: Dirty worktree from another task is refused

- **GIVEN** agent `dev`'s worktree has one uncommitted file and teamsmith recorded `dev`'s current task as `T1.0`
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** the command exits non-zero, prints the dirty file count and `T1.0`, and starts no window

#### Scenario: The same task resumes with uncommitted work

- **GIVEN** the same dirty worktree, but teamsmith recorded `dev`'s current task as `T1.1`
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it proceeds and reports that the uncommitted changes belong to the current task

#### Scenario: The unfinished-task leg joins the one refusal with its routes

- **GIVEN** a brief whose `change:` line is malformed and an unfinished recorded task `T1.0` whose branch the
  worktree is still on
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** the one invocation prints both blockers; the unfinished-task item names `T1.0`, its board status, the
  reason it is unfinished and the worktree branch
- **AND** the output carries `team resume --agent dev` and a `dispatch … --force` command as its printed routes

### Requirement: One task branch per task

With the default `TEAM_BRANCH_MODE=task`, each task SHALL run on `<TEAM_TASK_BRANCH_PREFIX>/<ID>-<slug>` cut from the
protected branch; the PM creates the worktree and branch with git, and `dispatch` only checks the state (it never
switches or rebases anything itself).

The branch a task must run on SHALL have one declared name, resolved in this order: `dispatch`'s `--branch <name>`
argument, else the brief's `branch:` line when present, else the derivation from the task's title. `team dispatch`
SHALL print the resolved name and the source it came from (`--branch`, the brief's `branch:` line, or the title)
before the launch — for `--print` as well — together with the exact `git -C <worktree> switch …` command when the
worktree is not already on it. `team task` SHALL write the task's derived name into the brief as its `branch:`
line, so the name is visible before any worktree exists and a later title change does not move it.

`--branch <name>` SHALL be accepted (the help line prints it), and a name that does not belong to this task —
anything other than `<prefix>/<ID>-<slug>` in task-branch mode, or `agent/<agent>` in agent mode — SHALL be
refused before any window is opened. When `--branch` is given, the worktree MUST be on exactly that name: another
branch — even one of the same task — is refused naming both and the fixing command, because the explicit
declaration wins. Without `--branch`, the worktree check stays a check: it refuses a worktree parked on **another
task's** branch (naming that branch, the required one and the fixing command) and SHALL proceed when the worktree
is on **this task's** branch even if its slug differs from the resolved name, printing both names — the branch
still belongs to the task, and the slug is a display detail, not the identity of the work.

#### Scenario: The branch identity is visible

- **GIVEN** a dispatched task `T1.2` in task-branch mode
- **WHEN** `team roster` runs
- **THEN** the agent's row shows the branch its worktree is on (`task/T1.2-*`) next to the task recorded for it
- **AND** `team status T1.2` prints that same row together with the task's board row and its report path

#### Scenario: A dirty worktree blocks a branch switch

- **GIVEN** `dev`'s worktree has uncommitted changes from `T1.0` and the next task is `T1.1`
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** the dispatch is refused rather than silently switching to the new task's branch

#### Scenario: A worktree parked on another task's branch is refused

- **GIVEN** `dev`'s worktree is checked out on `task/T8.8-other` and the dispatch is for `T1.1`
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it exits non-zero, names that branch and the required `task/T1.1-*`, and prints the
  `git -C <worktree> switch <branch>` command that fixes it
- **AND** no dispatch happens, and the same task resumed on an earlier slug of its own branch stays allowed

#### Scenario: A same-task branch with another slug is accepted, not refused

- **GIVEN** `dev`'s worktree is checked out on `task/T1.1-legacy`, which belongs to `T1.1`, while the resolved
  name would be `task/T1.1-first`, and no unfinished task is recorded for `dev`
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it proceeds and prints both names (the checked-out one and the resolved one)
- **AND** the pre-change shape is its red side: the same fixture was refused with
  `✗ … 停在不属于本任务（T1.1）的分支上` (measured)

#### Scenario: The resolved name and its source are printed

- **GIVEN** a brief whose header carries `branch: task/T1.1-first` while the title would derive
  `task/T1.1-second`
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** the output names `task/T1.1-first` and states it came from the brief's `branch:` line
- **AND** with the `branch:` line removed, the output names the title-derived name and states it came from the
  title

#### Scenario: A generated brief carries its branch

- **WHEN** `team task T1.1 --title "first task" --agent dev` runs in an initialised project
- **THEN** the brief header carries a `branch:` line equal to the name `team dispatch` derives for that title
- **AND** renaming the task's title afterwards leaves that line and the dispatch's expectation unchanged

#### Scenario: `--branch` names the expected branch for this task

- **GIVEN** `dev`'s worktree is checked out on `task/T1.1-pm-named`
- **WHEN** `team dispatch dev T1.1 <brief> --branch task/T1.1-pm-named --print` runs
- **THEN** it is not refused, and the printed plan names that branch and its `--branch` source

#### Scenario: A declared `--branch` is not silently swapped for another same-task branch

- **GIVEN** `dev`'s worktree is checked out on `task/T1.1-legacy` while the dispatch declares
  `--branch task/T1.1-pm-named`
- **WHEN** `team dispatch dev T1.1 <brief> --branch task/T1.1-pm-named` runs
- **THEN** it exits non-zero, names both branches and prints the `git -C <worktree> switch task/T1.1-pm-named`
  command that fixes it, and opens no window

#### Scenario: `--branch` from another task is refused

- **GIVEN** `--branch task/T9.9-other` for a dispatch of `T1.1`
- **WHEN** `team dispatch dev T1.1 <brief> --branch task/T9.9-other` runs
- **THEN** it exits non-zero, names the branch, the task and the accepted shape (`task/T1.1-*`), and opens no
  window

### Requirement: A brief names at most one change id

The brief header's `change:` line SHALL carry exactly one change id — a single token matching
`[A-Za-z0-9][A-Za-z0-9._-]*` — or `-` for a task that belongs to no change. A brief with more than one `change:`
line, or a value that is not a single token (a comma list, two whitespace-separated ids, an id plus `-`, an id with
trailing text), MUST be refused by `team dispatch` before any window is opened, and by `--print` as well, so no
printed plan looks right while the brief is wrong. The refusal MUST print the offending line and both accepted
forms, and MUST NOT change the task's board status.

The refusal's first line — the line that opens this field's diagnosis — SHALL carry both a legal example
(`change: <one id>`, or `change: -`) and the specific reason the value was refused, so one line, not two reads, is
enough: a comma or whitespace list is "more than one id"; trailing text after an id names the characters outside
the id; a second line is "two `change:` lines". When this is the only blocker, that line is the first line of the
refusal's output.

#### Scenario: Two change ids in one brief are refused

- **GIVEN** a brief whose header reads `change: alpha, beta` (and a second one reading `change: alpha beta`)
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it exits non-zero, prints the offending line and the accepted forms (`one id` or `-`), and requests no
  tmux window

#### Scenario: A second `change:` line is refused

- **GIVEN** a brief with two `change:` lines (`alpha` and `beta`)
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it exits non-zero and names both lines, instead of silently using the first one

#### Scenario: `--print` refuses the same brief

- **WHEN** `team dispatch dev T1.1 <brief> --print` runs on the two-id brief
- **THEN** it exits non-zero and prints no prompt

#### Scenario: One id, and `-`, are allowed

- **GIVEN** a brief whose header reads `change: alpha` and one whose header reads `change: -` (with a declared anchor)
- **WHEN** each dispatch runs with `--print`
- **THEN** neither is refused for its `change:` value and the printed prompt names the brief path

#### Scenario: A refused dispatch leaves the board alone

- **GIVEN** a board row `| T1.1 | … | todo |`
- **WHEN** the dispatch of the two-id brief is refused
- **THEN** `team board row T1.1` still reports `todo`

#### Scenario: Trailing text is named with an example on the first line

- **GIVEN** a brief whose header reads `change: panel（说明）` and a seat whose only blocker is this line
- **WHEN** `team dispatch dev P1 <brief>` runs
- **THEN** the first line of the output carries a legal example (`change: panel` or `change: -`) and names
  `（说明）` as text outside the change id
- **AND** the pre-change shape is its red side: the same fixture's first line was
  `拒绝派单：P1 的任务书 change: 行不合法（一个任务最多属于一个 change）`, which shows no example and blames the
  wrong reason (measured)

#### Scenario: A list's first line carries the example and the reason

- **GIVEN** a brief whose header reads `change: alpha, beta`
- **WHEN** `team dispatch dev P1 <brief>` runs
- **THEN** the first line of the output names `alpha, beta` as more than one id and carries `change: alpha` as the
  legal example

### Requirement: Two unfinished tasks of one change do not write the same delta file

`team dispatch` SHALL refuse to start a task whose delta targets intersect those of another unfinished task of the
same change. A brief's `deltas:` value SHALL be a comma-separated list of the change's capabilities whose delta
file the task will write, or `-` for a task that writes none; **when the `deltas:` line is absent, the task MUST be
treated as targeting every delta file of its change**. The refusal MUST name the sibling task, its board status, the
shared delta file(s) and both declarations, MUST NOT change any board status, and MUST come before any window is
opened (and for `--print` as well). `--force` MUST proceed with a warning and append exactly one audit line naming
both tasks and the shared file.

A malformed `deltas:` value MUST be refused before any window is opened, for `--print` as well. The refusal's
first line SHALL carry both a legal example (`deltas: <capability>, <capability>`, or `deltas: -`) and the reason
the value was refused: a separator the syntax does not accept (`·`, `;`, whitespace) MUST be named as such — and
not read as one long capability token — and a trailing comma MUST be named as an empty item.

#### Scenario: Two tasks declaring the same delta are refused

- **GIVEN** an unfinished sibling task `M1` of change `alpha` whose brief declares `deltas: panel`, and a new brief
  for `alpha` declaring `deltas: panel`
- **WHEN** `team dispatch dev M2 <brief>` runs
- **THEN** it exits non-zero and names `M1`, its board status, `openspec/changes/alpha/specs/panel/spec.md` and both
  declarations

#### Scenario: A task that writes no delta proceeds

- **GIVEN** the same sibling `M1` and a new brief for `alpha` declaring `deltas: -`
- **WHEN** `team dispatch dev M2 <brief> --print` runs
- **THEN** it is not refused, and the output states which declarations were compared

#### Scenario: A missing declaration is treated as the whole delta set

- **GIVEN** a sibling task of the same change whose brief has no `deltas:` line
- **WHEN** a new brief for that change declares `deltas: panel` (or has no `deltas:` line either)
- **THEN** the dispatch is refused, and the message says the missing line was read as "every delta file of the
  change"

#### Scenario: Different changes are never compared

- **GIVEN** an unfinished task of change `alpha` declaring `deltas: panel` and a brief for change `beta` declaring
  `deltas: panel`
- **WHEN** `team dispatch dev B1 <brief> --print` runs
- **THEN** it is not refused, because the two delta files live in different change directories

#### Scenario: A finished sibling does not block

- **GIVEN** a sibling task of the same change whose board status is `done`
- **WHEN** a new brief declaring the same delta is dispatched
- **THEN** it is not refused

#### Scenario: `--force` proceeds with one audit line

- **GIVEN** the conflicting pair of the first scenario
- **WHEN** `team dispatch dev M2 <brief> --force` runs
- **THEN** it proceeds, prints the shared file as a warning, and appends exactly one line to `state/watchdog.log`
  naming `M1`, `M2` and that file

#### Scenario: A malformed list's first line teaches the comma syntax

- **GIVEN** a brief whose header reads `deltas: panel · verification` and a seat whose only blocker is this line
- **WHEN** `team dispatch dev P1 <brief>` runs
- **THEN** the first line of the output carries a legal example (`deltas: panel, verification` or `deltas: -`) and
  names `·` as a separator the syntax does not accept
- **AND** the pre-change shape is its red side: the same fixture was refused with the whole value reported as one
  token (`deltas: 的值是 `panel · verification` —— `panel · verification` 不是 capability token`) and no example
  (measured)

#### Scenario: A trailing comma and a space list are named

- **GIVEN** a brief whose header reads `deltas: panel,` and one reading `deltas: panel verification`
- **WHEN** each dispatch runs
- **THEN** the first line of each refusal carries the legal example and names the trailing empty item / the
  whitespace separator as the reason

#### Scenario: The example shape really works

- **GIVEN** a brief whose header reads `deltas: panel, verification` and no conflicting unfinished sibling
- **WHEN** `team dispatch dev P1 <brief> --print` runs
- **THEN** it is not refused for its `deltas:` value

### Requirement: The printed route is a route that works

The project's correctness gate SHALL carry a route-sincerity walk (`bash skills/teamsmith/tests/routes.sh`, run by
the correctness gate's `smoke.sh` and runnable standalone) that judges the CLI's printed surface against the CLI's
real one:

- For every usage line of `team help`, every `--flag` the line prints MUST be accepted by that command's own
  parser: the walk runs the command with that flag in a fixture project and fails, naming the command and the
  flag, when the parser answers with the tool's unknown-parameter refusal (for a command that only execs another
  program, the walk reads that program's own argument table instead — declared with the file and the reason). A
  flag only a sibling command accepts MUST NOT satisfy the line. A usage line the walk cannot attribute to a
  command and its flags MUST fail naming the line — an unparsable line is never skipped.
- For every command whose line prints at least one flag, an unknown flag (`--frobnicate-probe`) MUST be refused:
  a command that swallows unknown arguments fails naming the command. This is the walk's non-vacuity control —
  without it, a printed flag that is quietly ignored reads as accepted.
- For every schema note that names a `team` command, that command MUST resolve in the CLI, and the sentence's
  promise MUST really happen in the fixture through a declared promise probe; the set of keys needing a probe is
  derived from the schema, not from a hand-kept list, so a note naming a command with no probe fails naming the
  key, and a named command the CLI does not carry fails naming the key and the command. The probes assert
  effects, not exit codes: the roster's probe changes `TEAM_AGENTS` and writes its audit line, a seat's probe
  writes the model token, the pulse window's probe makes the backend's recorded window call carry the key's value,
  and the model keys' probes make the next spawn's rendered command carry the new model.
- For every refusal route the CLI prints (`修法：<command>` and `改行：<exact line>`), the walk SHALL apply the
  printed route in a fixture and re-run the command that refused. A clearing route — a `改行：` line, or a command
  that removes the condition (a `git switch`, a `git worktree add`) — MUST make that blocker disappear; an
  override route (`--force`, `--fresh`, a configuration knob) MUST be honored: the re-run proceeds under that
  route's own contract (its warning, and for a real launch its audit line), so a printed route can never be a
  line the tool itself refuses. A route that no longer clears its blocker, or is no longer honored, fails naming
  the family and the route. The families the walk exercises are declared in the walk itself (fixture → expected
  blocker → printed route kind → expected effect); a `修法：`/`改行：` family with no entry fails naming the
  family, so no printed route can go quietly unexercised. A `改行：` route is applied by writing that exact line
  into the brief header; a `修法：` route is applied by running it, inside the fixture, under the walk's recording
  `tmux` shim and its hard timeout.

The walk MUST NOT touch anything outside its own scratch fixtures: every command it runs runs in a fresh git
repository under `$TMPDIR` with a recording `tmux` shim first on `PATH`, `TEAM_MEETINGS_DIR` inside that fixture,
`stdin` from `/dev/null` and a hard timeout; it removes every directory it creates; it prints one line per usage
line, per probe and per refusal route (never a silent skip) and exits 0 only when every line, control, probe and
route is green.

#### Scenario: The committed tree is green

- **WHEN** `bash skills/teamsmith/tests/routes.sh` runs on this tree, and the correctness gate runs
  `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`
- **THEN** both exit 0, the walk prints one `ok` line per usage line it parsed, one per probe and one per refusal
  route (never a silent skip), and no `bad` line

#### Scenario: The field defect is caught, with the command and the flag named

- **GIVEN** a scratch tree whose `add-agent` help line prints `[--model m]` while the parser refuses it (this
  change's red side, measured: `✗ add-agent: 未知参数 --model`, exit 2)
- **WHEN** the walk runs against it
- **THEN** it exits non-zero and names `add-agent` and `--model`, and the other usage lines stay green

#### Scenario: A sibling command's flag does not satisfy the line

- **GIVEN** a scratch tree whose `add-agent` help line prints `[--fresh]` — a flag `dispatch` really accepts,
  `add-agent` does not
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming `add-agent` and `--fresh`

#### Scenario: A command that swallows unknown flags fails the control

- **GIVEN** a scratch tree whose `ps` parser no longer refuses unknown arguments (today's measured shapes are
  `version` and `meeting list`, which accept them and run)
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming `ps`

#### Scenario: A command-block line the walk cannot attribute is a failure

- **GIVEN** a scratch tree whose command block carries a line at column 0 that no command owns while it prints a
  flag (the pre-fix `board add|assign|set|row|ls … [--allow-dup]` shape — measured: `cmd-project.sh:32` is not
  indented, so an indentation-based parse would skip it and leave `--allow-dup` unjudged)
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming that line instead of skipping it

#### Scenario: A schema route naming a command that does not exist fails

- **GIVEN** a scratch tree whose `TEAM_GATES` note names `team frob off`
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming `TEAM_GATES` and `team frob`

#### Scenario: A schema note naming a command without a promise probe fails

- **GIVEN** a scratch tree whose schema gains a key whose note names `team config set-agent-model` while no probe
  entry covers that key
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming the added key as a note that names a command without a promise probe, naming
  no other key

#### Scenario: A broken promise is a failure, not a warning

- **GIVEN** a scratch tree whose roster registration no longer changes `TEAM_AGENTS` (the write path is broken
  while the command still exits 0)
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming `TEAM_AGENTS`'s probe — the probes assert the effect, so a command that
  reports success without doing the sentence's work cannot pass

#### Scenario: The walk leaves the caller alone

- **WHEN** the walk finishes
- **THEN** no directory it created remains under `$TMPDIR`, the caller's project (`docs/team`, `.pi/team/state`,
  `git status`) is unchanged, and the real tmux session was never its target (every tmux call came from its shim)

#### Scenario: The new flag is a printed route like any other

- **GIVEN** the committed tree's `dispatch` usage line prints `--branch <name>` (the pre-change line did not, and
  the pre-change parser answered `✗ dispatch: 未知参数 --branch`, measured)
- **WHEN** the walk runs
- **THEN** the `dispatch` line's `--branch` claim is probed against the dispatch parser and stays green, and the
  sibling-flag and unknown-flag controls still hold

#### Scenario: A printed fix that stops clearing its blocker fails the walk

- **GIVEN** a scratch tree whose branch-refusal route prints a `git switch` to a branch that belongs to another
  task (the fixed command no longer clears the branch blocker)
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming the refusal family and that route, while the other families stay green

#### Scenario: Applying every printed route clears the composite refusal

- **GIVEN** the committed tree's composite clearing fixture (a malformed `change:` line, a malformed `deltas:`
  line and a worktree on another task's branch)
- **WHEN** the walk applies every `改行：` line and every clearing `修法：` command the refusal printed
- **THEN** the re-run of the same dispatch no longer reports any of those blockers

#### Scenario: An override route is honored, not just printed

- **GIVEN** the unfinished-previous-task family, whose printed route is the re-dispatch with `--force`
- **WHEN** the walk applies that printed route
- **THEN** the re-run proceeds under the override's own contract (the warning naming the task it overrides), and
  the walk records the family as honored instead of as cleared

#### Scenario: A printed route family with no walk entry fails

- **GIVEN** a scratch tree whose refusal prints a `修法：` route for a family the walk has no entry for
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming that family instead of skipping it
