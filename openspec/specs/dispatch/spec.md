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

#### Scenario: A brief outside the project is refused, `--print` included

- **GIVEN** a brief at `/tmp/outside-brief.md` and the project's main worktree at `<root>`
- **WHEN** `team dispatch dev T1.1 /tmp/outside-brief.md --print` runs
- **THEN** it exits non-zero, names `<root>`, and does not describe the path as repo-relative
- **AND** the same command without `--print` exits non-zero before any window is opened

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

### Requirement: The capacity floor protects the host

`team dispatch` SHALL refuse to start a worker when the host is below a capacity floor: RAM+swap
(`TEAM_MIN_TOTAL_MB`, default 512 MB), MemAvailable (`TEAM_MIN_AVAIL_MB`, default 1024 MB), **disk** swap free
(`TEAM_MIN_FREE_SWAP_MB`, default 1024 MB), or the disk/inode leg below. zram MUST be excluded from the swap floor
(its pages live in RAM); zram occupancy above `TEAM_ZRAM_WARN_PCT` (default 85) is a warning only.

The disk/inode leg SHALL judge, before any window is opened and for `--print` as well, the free bytes and the free
inodes of the filesystems the worker will write to: the temp root (`${TMPDIR:-/tmp}`) and the worktree filesystem
(the agent's worktree for a dispatch; the worktrees root `TEAM_WORKTREES_DIR` where no target is resolved). It
SHALL refuse when the free bytes are below `TEAM_TMP_MIN_FREE_MB` (default 1024) or — only when the filesystem
reports an inode table — when the free inodes are below `TEAM_TMP_MIN_FREE_INODES` (default 100000); a
non-numeric threshold falls back to its default, and `0` disables that leg, the same escape shape as
`TEAM_MIN_AVAIL_MB=0`. The refusal MUST name the path, the measured figures, the threshold crossed and a
`修法：<command>` line — for the temp root the ownership-proven
`bash skills/teamsmith/tests/tmp-hygiene.sh --status`, then `--sweep`; for the worktree filesystem, freeing that
path — and MUST print the explicit override (`TEAM_TMP_MIN_FREE_MB=0` / `TEAM_TMP_MIN_FREE_INODES=0`).

A figure that cannot be read (`df` fails, a column is missing or non-numeric) and a filesystem that does not
report an inode table SHALL NOT refuse and SHALL NOT warn: that leg is not judged, no number is invented for it,
and the visible reading says the figure could not be read. When both paths resolve to one filesystem it SHALL be
judged once. The measurement MAY be replaced by a fixture (the `TEAM_MEMINFO_FILE` idiom) through
`TEAM_DISK_STATS_FILE` — rows `path<TAB>total_kb<TAB>avail_kb<TAB>itotal<TAB>ifree`, longest matching path prefix
wins, a path with no row is unreadable — so the leg is testable without a second filesystem.

The two thresholds and the fixture seam SHALL be rows of the project contract's schema (the `memory-and-deps`
`team_config_schema()` table): `TEAM_TMP_MIN_FREE_MB` class `apply`, kind `mb`, default `1024`;
`TEAM_TMP_MIN_FREE_INODES` class `apply`, kind `int`, default `100000`; both in the `delivery` group carrying the
`0` danger note their sibling floors carry, and `TEAM_DISK_STATS_FILE` a `refuse` test-knob row. The escape MUST be
reachable through the audited writer — `team config set <KEY> 0 --allow-danger` writes the contract, leaves its one
`result=ok` audit line and needs no hand-edit — and the `0` behind it SHALL keep the meaning the environment form
has today (that leg off, the other still judged).

When the floor passes, `team dispatch` SHALL print one capacity line carrying the measured readings — the RAM/swap
figures it judges plus, for each judged filesystem, its path and its available bytes and free inodes — in the
pre-launch phase and in `--print`.

#### Scenario: Low free disk swap refuses the dispatch

- **GIVEN** `TEAM_MEMINFO_FILE` points at a fixture with 8000 MB MemAvailable and 300 MB free disk swap
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it exits non-zero and the reason names the free disk swap
- **AND** the same command with `TEAM_MIN_FREE_SWAP_MB=0` no longer refuses for that reason

#### Scenario: zram pages are not counted as headroom

- **GIVEN** `TEAM_SWAPFILE_PATH` points at a fixture whose free swap comes from `/dev/zram0` only
- **WHEN** `team ps` prints the capacity line
- **THEN** the disk-swap figure it uses for the floor is 0, and zram is reported separately as a warning

#### Scenario: A full temp root refuses the dispatch with its figures and its fix

- **GIVEN** `TEAM_DISK_STATS_FILE` gives the temp root 120 MB free of 15 GB with 40000 free inodes, and its row for
  the worktree is above both floors
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** it exits non-zero, names the temp root path, the free bytes and free inodes the fixture holds, and the
  thresholds they crossed, and prints a `修法：` line carrying `tmp-hygiene.sh --sweep`
- **AND** the same command with `TEAM_TMP_MIN_FREE_MB=0 TEAM_TMP_MIN_FREE_INODES=0` no longer refuses for that
  reason

#### Scenario: Plenty of disk allows the dispatch and prints the readings

- **GIVEN** the fixture holds 5 GB free and 2900000 free inodes for both the temp root and the worktree
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** it exits 0 and its capacity line names both paths with those measured availabilities and inode figures

#### Scenario: An unreadable filesystem is silent and never refuses

- **GIVEN** the fixture holds no row for the temp root while the worktree row is above both floors
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** it exits 0, no refusal or warning names a disk shortfall, and the capacity line does not print a number
  for the temp root (it says the figure could not be read)

#### Scenario: A filesystem without an inode table is judged on bytes only

- **GIVEN** the worktree row reports `itotal=0` with 5 GB free
- **WHEN** the dispatch runs
- **THEN** it exits 0 and the capacity line prints no inode figure for that filesystem
- **AND** with the same row's free bytes below the floor, the refusal names the bytes threshold and not the inode
  threshold

#### Scenario: The floor's escape hatch is reachable through the audited writer

- **GIVEN** a fixture contract that does not carry `TEAM_TMP_MIN_FREE_MB`, and a `TEAM_DISK_STATS_FILE` whose
  temp-root row is below the 1024 MB floor while its inode figure is above the inode floor
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs, then
  `team config set TEAM_TMP_MIN_FREE_MB 0 --allow-danger --yes` runs, then the same dispatch runs again
- **THEN** the first dispatch exits non-zero for the free-bytes floor, the write exits 0 and leaves the contract
  parseable with exactly one `result=ok` line in the config audit log, and the second dispatch exits 0 with that
  leg off while the inode leg is still judged

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

### Requirement: A dispatch proves the agent started, or fails loudly

`team dispatch` SHALL report success only when the window harness recorded **this round's** launch proof: the file
`state/dispatch-<agent>.spawn` MUST begin with the nonce minted for this attempt and the pane shell's pid, so a
record left behind by an earlier round never counts. "The harness came up" MUST NOT be reported as "the agent is
running": the agent's exit MUST be read from the event file `state/dispatch-<agent>.exit`, written by the harness
after the agent returns and carrying the same nonce, never from sampling the pane. When no proof arrives the
dispatch SHALL retry once, kill the leftover window (no half-started window may outlive the failure) and exit
non-zero naming the missing evidence. On the custom-adapter path an agent that exits non-zero within
`TEAM_DISPATCH_ALIVE_SEC` (default 1 s) SHALL fail the dispatch with the real `exit=<code>` and MUST leave
`state/dispatch-<agent>-launch-failed.log` holding the rendered command, the resolved binary, the exit code and the
window tail, without writing a task record; the built-in Pi path keeps its older contract, where a short-lived
`TEAM_PI_BIN` is reported honestly instead of failing the dispatch. Why each piece is evidence and not inference:
`references/agent-adapters.md` §3 and `references/troubleshooting.md`.

#### Scenario: A wedged window is a failure, not a success

- **GIVEN** a tmux whose `new-window` returns success but never runs the command (the process wedges before reading
  its input)
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it exits non-zero, states that the start could not be confirmed instead of printing a success line, and
  retries exactly once
- **AND** the leftover window is really killed, so the window's final state is "does not exist"

#### Scenario: A stale exit record is not this round's evidence

- **GIVEN** `state/dispatch-dev.exit` holds a record from an earlier dispatch whose nonce is not this round's
- **WHEN** the agent of this round is still running
- **THEN** the dispatch does not report that the agent already exited, and only an exit record carrying this
  round's nonce yields `exit=<code>`

#### Scenario: The exit code comes from the event file, not from the pane

- **GIVEN** a built-in Pi fixture whose CLI exits 3 right after the launch proof
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** the dispatch still reports success (the launch proof is real) and states the observed exit code 3 and
  that the agent has already exited
- **AND** `state/dispatch-dev.exit` exists and carries this round's nonce and that code

#### Scenario: An adapter that exits non-zero fails the dispatch with diagnostics

- **GIVEN** a `TEAM_AGENT_CMD` whose CLI prints an error and exits 7
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it exits non-zero, prints `exit=7`, and names `state/dispatch-<agent>-launch-failed.log`
- **AND** that file holds the rendered command, the resolved binary, the exit code and the CLI's own error text
- **AND** no task record is written for the failed dispatch

### Requirement: A dispatch refuses a session the model's window cannot hold

When a dispatch would resume an existing session, `team dispatch` SHALL compare the session's estimated size
(JSONL bytes ÷ 4 — a deliberately coarse estimate) against the selected model's context window and MUST refuse to
start when the estimate exceeds it, naming the session file, the estimate and the window. `--fresh` (a new,
timestamped session id) and `--allow-overflow` (an explicit, loud override) SHALL be the two ways through, and the
guard MUST also run for `--print` so no window is planned around a session that cannot fit. The window SHALL be
resolved from `TEAM_MODEL_WINDOWS` (`<provider>/<model>=<tokens>`, matching either the full name or the bare model
name) first and from the model catalogue second; when neither resolves it, the guard MUST use the conservative
threshold `TEAM_SESSION_WARN_TOKENS` (default 200000) and say that the window could not be resolved. `team roster`
and `team ps` SHALL show the estimate next to the model as `used/window`. Why reuse is the dangerous case (a
361k-token session under a 272k window wedges while `roster` still shows a running agent): `references/protocol.md`.

#### Scenario: A big session with a small-window model is refused

- **GIVEN** a session whose file size estimates ~400k tokens and a model `sub2api/gpt-5.6-sol` with a 272000-token
  window
- **WHEN** `team dispatch dev T1.1 <brief> --model sub2api/gpt-5.6-sol` runs
- **THEN** it exits non-zero, names the estimate and `272000`, explains the estimate (`JSONL bytes ÷ 4`) and offers
  both `--fresh` and `--allow-overflow`
- **AND** the same command with `--print` is refused by the same guard before printing a plan

#### Scenario: A wider window may reuse the same session

- **GIVEN** the same session and a model whose window is larger than the estimate
- **WHEN** the dispatch runs for that model
- **THEN** it proceeds and reuses the same session id

#### Scenario: An unresolvable window falls back to the conservative threshold, and says so

- **GIVEN** a model that neither `TEAM_MODEL_WINDOWS` nor the model catalogue resolves, and a session larger than
  `TEAM_SESSION_WARN_TOKENS`
- **WHEN** the dispatch runs
- **THEN** it exits non-zero and says the window could not be resolved, printing the conservative threshold it used

#### Scenario: `--fresh` and `--allow-overflow` are the two explicit ways out

- **GIVEN** the over-large session of the first scenario
- **WHEN** the dispatch runs with `--fresh`
- **THEN** it proceeds with a new, timestamped session id, so the reused history is not what the agent loads
- **AND** with `--allow-overflow` it proceeds under a loud warning that the over-large session was explicitly
  allowed, instead of passing silently

#### Scenario: `TEAM_MODEL_WINDOWS` overrides the catalogue

- **GIVEN** `TEAM_MODEL_WINDOWS` that gives the selected model a window larger than the estimate
- **WHEN** the dispatch runs
- **THEN** the guard accepts the session even though the catalogue would have refused it

#### Scenario: roster and ps show the estimate against the window

- **GIVEN** the same over-large session and a configured window of 272000
- **WHEN** `team roster` and `team ps` run
- **THEN** both show the agent's estimate as `400k/272k`, and `roster` explains that the figure is
  "estimated tokens / model window"

### Requirement: A verification seat is never dispatched implementation work

`team dispatch` SHALL refuse to start implementation work for the project's verification seat — the agent named by
`TEAM_VERIFY_SEAT`, so a project that reserves a differently named seat is covered instead of being silently
unprotected. The brief runs implementation when its `phase:` is `apply`, or when its `phase:` is undeclared (no
line, `-`, or a value outside `explore|propose|apply|verify|archive`) and its `grant:` names at least one
implementation path. A `grant:` entry counts as an implementation path unless it is `docs/team`, `openspec`, or lies
under `docs/team/` or `openspec/`; the refusal MUST print the entries it read that way, so a false positive is
visible instead of silent. The declared phases `explore`, `propose`, `verify` and `archive`, and an undeclared phase
whose `grant:` names only `docs/team/`/`openspec/` paths (or has no `grant:` line), MUST proceed.

The refusal MUST name the seat, the verification row of `docs/team/OWNERSHIP.md` (the boundary the seat may not
cross) and two ways out — dispatch the work to a seat that may implement, or keep the seat and make the task
verification-only (`phase: verify`) — MUST come before any window is opened and for `--print` as well, and MUST NOT
change the task's board status. `--force` MUST proceed with a warning and append exactly one audit line to
`state/watchdog.log` naming the task, the seat and the signal that triggered the guard (an `apply` phase or the
implementation paths); `--print` writes no audit line. Why the seat's independence includes not implementing, and
which work stays allowed: `verification#The verification seat does not implement` and `references/protocol.md` §5b.

#### Scenario: Apply work for the verification seat is refused

- **GIVEN** a brief with `agent: verify` and `phase: apply`, and a board row for its task
- **WHEN** `team dispatch verify T1.1 <brief>` runs
- **THEN** it exits non-zero, names `docs/team/OWNERSHIP.md`, the seat and both ways out
- **AND** it requests no tmux window and leaves the task's board row unchanged

#### Scenario: `--print` refuses the same brief

- **WHEN** `team dispatch verify T1.1 <brief> --print` runs on the same brief
- **THEN** it exits non-zero and prints no prompt

#### Scenario: An undeclared phase with implementation grants is refused, and says why

- **GIVEN** a brief with `agent: verify`, no usable `phase:` value and
  `grant: skills/teamsmith/scripts/lib/cmd-agents.sh · scripts/lib/common.sh · extension/team-bg.ts`
- **WHEN** `team dispatch verify T1.1 <brief>` runs
- **THEN** it exits non-zero, prints those three entries as the implementation paths it read, and states that the
  phase was undeclared

#### Scenario: Ledger and reconnaissance work proceeds without a phase

- **GIVEN** a brief with `agent: verify`, no usable `phase:` value and
  `grant: docs/team/reports/V1-verify.md · openspec/changes/alpha/`
- **WHEN** `team dispatch verify V1 <brief> --print` runs
- **THEN** it proceeds and reports no implementation path

#### Scenario: A seat that may implement is not affected

- **GIVEN** the apply brief of the first scenario with `agent: dev` instead
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** it proceeds — the guard is about the seat, not about the `apply` phase

#### Scenario: `--force` proceeds with exactly one audit line

- **GIVEN** the apply brief of the first scenario
- **WHEN** `team dispatch verify T1.1 <brief> --force` really starts the worker (the record-only tmux shim the
  smoke suite uses)
- **THEN** it proceeds with a warning naming the seat and the task, and `state/watchdog.log` gains exactly one line
  naming them
- **AND** the same command with `--print` writes no audit line

### Requirement: An agent window outlives its pane and keeps a bounded scene

`team dispatch` and `team resume` SHALL create the window they dispatch into with tmux's
`remain-on-exit` enabled **before** that window's command can exit: the window is created holding a
placeholder command, the option is set and read back, and only then does the real harness take the
pane. The option SHALL be enabled for the windows `dispatch`/`resume` create and MUST NOT be added to
the PM window or to the pulse window — their shape is unchanged — while the draft window keeps the
setting it already has. When the pane's process exits for any reason, a signal included, the window
SHALL remain with `pane_dead=1`, its last output SHALL stay readable through `tmux capture-pane` on
that window read **with its scrollback** (`-S -`; the visible screen alone can lose the last line —
measured), and tmux's exit evidence (`pane_dead_status`, `pane_dead_signal`, `pane_dead_time`)
SHALL be readable from it. Retention SHALL be bounded without a timer: at most one retained pane per
seat window (the seat's next `dispatch`/`resume` replaces it, after capturing its scene), the retained
scrollback stays bounded by the host's `history-limit` (a session-wide option this change neither
raises nor narrows), and the copy the tool captures or prints is bounded by `TEAM_AGENT_SCENE_LINES`
(default 40; a non-numeric value falls back to the default). A live seat SHALL be unaffected by the
option: the launch proof, the exit-event file and the recorded-task semantics stay exactly as
`dispatch` defines them. Reading a retained pane — the four seat conditions, where the scene comes
from, what `status=`/`signal=` mean, and why the PM window deliberately has no retention — is
documented in `skills/teamsmith/references/troubleshooting.md` §11b.

#### Scenario: A killed pane leaves a readable corpse instead of an empty window list

- **GIVEN** a dispatched seat `<agent>` whose window was created by `team dispatch`, holding a fixture
  agent that printed a marker line which has appeared in the pane (polled for, not assumed)
- **WHEN** the pane's process group is killed with SIGKILL and then
  `tmux list-panes -t <session>:<agent> -F '#{pane_dead} #{pane_dead_signal}'` and
  `tmux capture-pane -p -S - -t <session>:<agent>` are read
- **THEN** the window still exists, `pane_dead` is `1`, `pane_dead_signal` is `9`, and the capture
  still contains the fixture agent's marker line
- **AND** `tmux kill-window -t <session>:<agent>` still removes it (the retained window is not a
  window that cannot be cleaned up)

#### Scenario: The option is on for agent windows only, and a normal exit keeps its meaning

- **GIVEN** a project whose PM window exists (started with `team up`) and one dispatched seat
- **WHEN** the option is read from both windows and the fixture agent of a second seat exits `0`
- **THEN** the agent window's `remain-on-exit` reads `on`, while the PM window carries no
  window-level setting for it (its effective value stays tmux's default, `off`)
- **AND** the exited agent's window still exists with a live pane (no `pane_dead`), `team roster`
  reports it as the exited condition rather than the dead one, and `team resume --agent <agent>`
  starts the same recorded task again leaving exactly one window for that seat

### Requirement: A dead pane is never a live seat, and reuse keeps its evidence

A pane whose `pane_dead` is `1` MUST NOT be treated as a live seat or as a message delivery target.
The fallback itself is `notify-and-inbox`'s (*Messages to a stopped agent fall back to the inbox*);
what this requirement fixes is the evidence that decides it, because with a retained corpse the
foreground command name can still look like a running CLI and tmux's `send-keys` returns success into
a dead pane while the text reaches nothing. The key-sending paths (`team say`, and a `team notify`
knock against that seat) SHALL therefore decide on the pane being dead, MUST NOT report delivery to
it, and SHALL leave the recipient's message durable in `docs/team/inbox/<agent>.md` while the output
names the seat as dead together with its exit evidence when that evidence is known. Before `dispatch`,
`dispatch --fresh` or `resume` replaces a dead pane's retained window, the tool SHALL capture the pane
into `state/dispatch-<agent>-pane-dead.txt`, holding the seat, the window, the timestamp, the exit
evidence and the last `TEAM_AGENT_SCENE_LINES` lines of the scene, and the dispatch output SHALL say
the previous pane is dead instead of the wording used when a live round is being interrupted. Reuse
SHALL remain a reuse: those three commands over a dead-pane seat leave exactly one window for the
seat, and the ordinary launch-proof rules are unchanged (this round's nonce decides; a record left by
a previous round is not evidence for this round). `teardown --agent` SHALL remove the retained window
like any other.

#### Scenario: A message to a dead seat is queued durably, never reported as delivered

- **GIVEN** a seat with an unfinished recorded task whose pane is dead (`pane_dead=1`,
  `pane_dead_signal=9`) and whose last screen holds a marker line
- **WHEN** `team say <agent> "P49 dead-pane probe"` runs
- **THEN** the output contains no delivered confirmation and names the seat as dead with `signal=9`
- **AND** `docs/team/inbox/<agent>.md` gained the `P49 dead-pane probe` line, and the dead pane's
  screen is byte-identical to what it was before the command

#### Scenario: Reuse captures the scene before it replaces the corpse, and stays one window

- **GIVEN** the dead-pane seat of the previous scenario with at least three marker lines on its
  retained screen and `TEAM_AGENT_SCENE_LINES=3`
- **WHEN** `team dispatch <agent> <ID> <brief>` (and then, in an equivalent fixture,
  `dispatch <ID> --fresh` and `resume --agent <agent>`) runs
- **THEN** `state/dispatch-<agent>-pane-dead.txt` exists before the window is replaced, carries the
  exit evidence and at most three scene lines including the fixture's marker line
- **AND** the output states that the previous pane was dead, exactly one window exists for that seat
  afterwards, its `remain-on-exit` is `on`, and the normal launch proof for the new round holds
- **AND** `team teardown --agent <agent>` removes that window, after which `team roster` reports the
  seat as having no window

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

### Requirement: A change-less brief declares its spec anchor

A brief whose `change:` value is `-` (or whose header has no `change:` line) SHALL declare its anchor in one of two
forms: a non-empty `specs:` value naming a capability that resolves to `openspec/specs/<capability>/spec.md` — and,
when a `#<requirement>` name is given, a requirement heading in that file — or `anchor: none (infra)` followed by a
non-empty reason. `team dispatch` MUST refuse — before any window is opened, and for `--print` as well — when
neither form is present or malformed, or when a named capability or requirement does not resolve, MUST name both
accepted forms and the path it looked for, and MUST NOT change the task's board status. `--force` MUST proceed with
a warning and one audit line naming the task and the missing anchor.

#### Scenario: Neither form is refused

- **GIVEN** a brief with `change: -`, `specs: -` and no `anchor:` line
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it exits non-zero, prints both accepted forms (`specs: <capability>#<requirement>` and
  `anchor: none (infra) — <reason>`), and opens no window

#### Scenario: `anchor: none` without a reason is refused

- **GIVEN** a brief with `change: -` and `anchor: none (infra)`
- **WHEN** the dispatch runs
- **THEN** it exits non-zero and says the reason after the marker is required

#### Scenario: An honest infra anchor proceeds

- **GIVEN** a brief with `change: -` and `anchor: none (infra) — CI runner environment and test portability`
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** it is not refused for this reason and prints no anchor warning

#### Scenario: A resolving requirement anchor proceeds

- **GIVEN** a brief with `change: -` and
  `specs: panel#The board page is a kanban over the board's states`
- **WHEN** `team dispatch dev T1.1 <brief> --print` runs
- **THEN** it is not refused and the printed prompt keeps the anchor line

#### Scenario: An unresolvable anchor is refused

- **GIVEN** a brief with `change: -` and `specs: no-such-capability#…`, and another with
  `specs: panel#A requirement that does not exist`
- **WHEN** each dispatch runs
- **THEN** it exits non-zero and names the `openspec/specs/…` path it looked in

#### Scenario: `--force` records the override

- **GIVEN** the anchor-less brief of the first scenario
- **WHEN** `team dispatch dev T1.1 <brief> --force` runs
- **THEN** it proceeds, warns that the anchor is missing, and appends exactly one line to `state/watchdog.log`
  naming the task and the missing anchor

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

### Requirement: The roster changes only through an explicitly authorized registration

`team add-agent <agent> [--register] [--model <provider/model>|-] [--create|--no-install|--print]` SHALL be the
only CLI route that grows `TEAM_AGENTS`, and `team teardown --agent <agent> --register` the only one that shrinks
it. Both SHALL write through the project contract's one writer, with the roster key's value rule, its fingerprint
CAS and its audit (`memory-and-deps`: "The project contract has exactly one writer, and it preserves what it does
not change"), and `TEAM_AGENTS` SHALL keep class `refuse`. `team add-agent <agent>` for a seat the roster does not
carry and without `--register` SHALL exit 5, name the two routes that really work (hand-editing
`.pi/team/config.sh`, or re-running with `--register`), and MUST NOT open a window, create a worktree, write state
or touch the contract. `--register` for a seat the roster already carries SHALL be a visible no-op (exit 0, no
write, no audit line) — and, because the value rule is not waived by the no-op path, a roster whose current value
violates that rule (a hand-edited duplicate or an illegal token) SHALL instead exit 4 naming the offending token
before any worktree or state is touched. `team teardown --register` SHALL require `--agent` (`--all --register` is a usage error,
exit 2) and SHALL refuse a seat the roster does not carry (exit 5 naming the roster, nothing written). Both
entries SHALL accept `--fingerprint <sha256>` with `team config set`'s semantics, and their own read-modify-write
SHALL pass the fingerprint of the bytes they read. A seat name the roster's value rule refuses (whitespace, `/`,
`pm`) SHALL exit 4 **before any write** — the roster byte-identical and no `result=ok` line — never a written
roster with a later worktree failure. `--model <m>` SHALL be validated before any write and SHALL set
that seat's configured model through the same writer and the same pairlist serializer
`team config set-agent-model` uses (`-` removes the override), and SHALL refuse exactly like the roster case when
the seat is outside the roster and `--register` was not given. Whatever that same command records about the seat's
model afterwards SHALL be read from the configuration the write just produced, not from the value resolved before
it — a record that contradicts a configured override is a lie the read surface cannot label away. The roster write SHALL come first (`team add-agent`
cannot build a worktree for a seat the tool does not know), and the command SHALL state what it wrote and what it
did not when the second write does not land. `team help`'s `add-agent` line SHALL print `--register`, `--model`,
`--create`, `--no-install` and `--print`, and `teardown`'s line SHALL print `--register`.

#### Scenario: `--register` grows the roster as one audited write

- **GIVEN** a fixture project whose roster line is `TEAM_AGENTS="dev verify"` among comments and other keys
- **WHEN** `team add-agent api --register --no-install` runs
- **THEN** it exits 0, `diff` shows exactly one changed line reading `TEAM_AGENTS='dev verify api'` (the
  writer's canonical single-quoted form), `bash -n`
  exits 0, and `<state>/config.log` gained exactly one `result=ok actor=cli` line naming `TEAM_AGENTS`
- **AND** the printed worktree step is the one `add-agent api --no-install` prints for a seat already in the roster

#### Scenario: The flagless refusal names two routes, and both work

- **GIVEN** the same contract and the sha256 recorded
- **WHEN** `team add-agent api` runs
- **THEN** it exits 5, the message carries `--register` and `.pi/team/config.sh`, the sha256 is unchanged, and no
  window, worktree or state record for `api` exists
- **AND** hand-editing the roster line to `TEAM_AGENTS="dev verify api"` makes `team add-agent api --no-install`
  print the worktree step instead of refusing — the hand edit is the second route, not a fallback that also fails

#### Scenario: Re-registering is a no-op and a stale fingerprint refuses

- **GIVEN** the contract of the first scenario after `api` joined, and its sha256
- **WHEN** `team add-agent api --register` runs again
- **THEN** it exits 0, prints that `api` is already in the roster, the sha256 is unchanged and `config.log` gained
  no line
- **AND** GIVEN a fingerprint read before another writer changed the file, `team add-agent api2 --register
  --fingerprint <stale>` exits 3, names the changed file, writes nothing and appends one `result=conflict` line

#### Scenario: Teardown removes a seat through the writer, and only on request

- **GIVEN** the same contract with `api` in the roster and `api`'s window and state present
- **WHEN** `team teardown --agent api --register` runs
- **THEN** the roster line reads `TEAM_AGENTS='dev verify'` with every other byte unchanged, one `result=ok`
  `actor=cli` line names `TEAM_AGENTS`, and the window/state cleanup of a plain `teardown --agent api` happened too
- **AND** `team teardown --agent api` (no flag) leaves the roster byte-identical (today's behaviour is the default),
  `team teardown --all --register` exits 2 without touching anything, and `team teardown --agent nosuch --register`
  exits 5 naming the roster with the sha256 unchanged; a name that is only a concatenation of two roster tokens
  (`api 1` where the roster carries `api` and `1`) is not a seat either — exit 5, byte-identical, no `result=ok`
  line (the pre-change membership test matched it across tokens and reported a successful removal of nothing)

#### Scenario: `--model` is the seat's configured model, not a per-run choice

- **GIVEN** the same contract and a seat `dev` in the roster
- **WHEN** `team add-agent dev --model vendor/m2 --no-install` runs
- **THEN** the `TEAM_AGENT_MODELS` line carries `dev=vendor/m2`, exactly one audit line names that key,
  `team config list --json` reports the seat with that model and `"override":true`, and the state record the
  command leaves (if any) agrees with the configuration — the pre-change command copied the model resolved before
  the write into the record, so the row showed an old model while reporting the override
- **AND** `team config set-agent-model dev vendor/m3` afterwards produces the same line with `vendor/m3` (the two
  routes are the same write), `team add-agent dev --model -` removes the token, and `team add-agent api
  --model vendor/m2` without `--register` exits 5 naming `--register` with nothing written

#### Scenario: A predictable model error writes nothing, and a retry completes

- **GIVEN** the same contract, whose sha256 is recorded
- **WHEN** `team add-agent api --register --model deepseek-flash` runs
- **THEN** it exits 4 naming the accepted `provider/model` shape, the roster still reads `dev verify`, the sha256
  is unchanged and no audit line was written — the model value is judged before the first write
- **AND** re-running with `--model vendor/m2` registers `api` first and then writes its model, in that order in
  `config.log`, and both keys read back as requested

#### Scenario: The help lines print the register route

- **WHEN** `team help` runs
- **THEN** the `add-agent` line carries `--register`, `--model`, `--create`, `--no-install` and `--print`, and the
  `teardown` line carries `--register`
- **AND** the pre-change lines are this check's red side: `add-agent` printed `[--model m]` (a flag the parser
  refused) and neither line mentioned registration at all

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

