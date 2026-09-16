## REMOVED Requirements

### Requirement: The adapter template contract is enforced, not guessed

**Reason**: the engine is shared by the worker and the PM side (`TEAM_PM_CMD` / `TEAM_PM_BIN` / `{resume_args}`),
so keeping it in `dispatch` would force a second copy of the placeholder list into any PM-side capability.

**Migration**: moved unchanged to `openspec/specs/agent-adapters/spec.md` — same requirement name, same four
scenarios, extended there by "The PM is an adapter too" and "The template's first word is resolved, not guessed".
No tool behaviour changes and no file outside this spec cites the requirement by name.

## MODIFIED Requirements

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

### Requirement: One task branch per task

With the default `TEAM_BRANCH_MODE=task`, each task SHALL run on `<TEAM_TASK_BRANCH_PREFIX>/<ID>-<slug>` cut from the
protected branch; the PM creates the worktree and branch with git, and `dispatch` only checks the state (it never
switches or rebases anything itself).

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

## ADDED Requirements

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
