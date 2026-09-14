# Runbook

Every section is a command sequence you can copy as is. By default `team` means `bash <skill>/scripts/team` (once it
is on PATH or symlinked, just `team`).

---

## 0. The spec layer (OpenSpec): idea → change → tasks → archive

What the tool **must hold** is written as OpenSpec requirements; a task brief is one work slice that satisfies some
of them (reasoning and guidance stay in `references/` — see [openspec.md](openspec.md)).

```bash
openspec list --specs                    # capabilities and their requirement counts
openspec new change <name>               # open a change: proposal + delta specs + tasks
openspec change show <name>              # what the change proposes (proposal / deltas / tasks)
openspec validate --all --strict         # fast structural gate — the first step of TEAM_GATES
bash skills/teamsmith/tests/spec-lint.sh # falsifiability: every requirement has a scenario, every scenario a WHEN+THEN
openspec archive -y <name>               # after the code landed and reviews/<ID>.md exists
```

Flow: idea → `openspec new change <name>` (fill `proposal.md`, `specs/<capability>/spec.md`, `tasks.md`) →
the PM writes briefs that name the change id and the scenarios they satisfy → dispatch → verify → merge →
`openspec archive -y <name>`, which merges the deltas into `openspec/specs/` and moves the change to
`changes/archive/`. A change that needs more than one work block stays open across several tasks.

## A. Assembling a team in a new project

```bash
# 0) prerequisites: a git repository, tmux and pi are present; the repository has at least one commit
bash <skill>/scripts/team init --session myproj --agents "dev verify" --vcs local
#   → writes .pi/team/config.sh, creates the docs/team/ skeleton, appends the protocol section to AGENTS.md, updates .gitignore

# 1) PM session: run pi inside tmux (notifications are typed into this window)
tmux new -s myproj -n pm          # then start: pi

# 2) edit .pi/team/config.sh: gates, install command, models and concurrency limits
bash <skill>/scripts/team doctor
```

## B. Dispatching the first task

```bash
# one-command setup (recommended): bash <skill>/scripts/team bootstrap
# github mode: create the issue first (optional but recommended: the issue is the requirement, the brief is the execution)
printf '# skeleton and quality gates\n\n## DoD\n- ...\n' > /tmp/issue.md
# create the issue your own way: gh / curl against the API / the web UI (the skill neither takes part nor assumes a forge)
gh issue create --title "[T1.1] skeleton and quality gates" --body-file /tmp/issue.md

bash <skill>/scripts/team task T1.1 --title "skeleton and quality gates" --agent dev --issue 12
$EDITOR docs/team/tasks/T1.1-*.md      # write background/deliverables/boundaries/acceptance commands

bash <skill>/scripts/team add-agent dev --create   # only --create creates the worktree (the default prints the git command)
bash <skill>/scripts/team dispatch dev T1.1 docs/team/tasks/T1.1-*.md
bash <skill>/scripts/team dispatch dev T1.1 docs/team/tasks/T1.1-*.md --print   # just want to see the prompt
```

Dispatch does this: guards (memory, model concurrency, **session size vs the model window**) → builds the prompt
(scope, red lines, delivery process) → starts an interactive pi in `<session>:dev` (`--session-id <session>-dev`,
`-e` loading the notify extension, `--skill` loading this skill) → **waits for launch proof**: the pane harness
writes a per-attempt nonce right before it execs the agent, and only that proof is reported as success (the line
says the launch was verified). No proof → the window is killed, one retry is made, and the command reports a clear
failure ("the dispatch was sent but the launch could not be confirmed") with what to check. A dispatch never claims
success for a command that never ran.

Resuming: dispatch the same agent for the same task and the session is reused; `--fresh` starts a new one
(`<session>-<agent>-<timestamp>`; the old history stays in its own file). Use `--fresh` when the task is new and the
session carries a long history from an earlier task, when you switch model family/provider, or when the session is
wedged (the `Context full` / connection-error loop — troubleshooting §4a).

Before resuming, dispatch compares the session's size with the selected model's window (estimate = session JSONL
bytes ÷ 4, crude on purpose; the window comes from `TEAM_MODEL_WINDOWS`, otherwise from Pi's model directory,
otherwise a conservative `TEAM_SESSION_WARN_TOKENS`) and **refuses** when the history does not fit. Two ways out:
`--fresh` (recommended) or `--allow-overflow` (you accept the risk; the refusal becomes a loud warning).
`team roster` and `team ps` show the same numbers next to the model (`used/window`, `?` when the window cannot be
resolved), so the mismatch is visible before dispatching; `--print` is guarded the same way.

## C. Watching / asking / steering

```bash
tmux attach -t myproj            # watch directly (Ctrl-b d to leave)
bash <skill>/scripts/team say dev "hands off packages/api for now, that is api's directory"   # one-line message (for multi-line, write a file for the agent to read)
bash <skill>/scripts/team thread dev "add an RLS test to T1.1 acceptance" --from pm --re T1.1
```

**Be specific when asking**: name the failing command, expected vs. actual, and require a reproduction before the fix.

## D. The PM loop (every 10~30 minutes)

```bash
bash <skill>/scripts/team digest          # pending work: new notifications + reports to verify + board + capacity/liveness
bash <skill>/scripts/team inbox --ack     # read and mark as read
bash <skill>/scripts/team roster          # who is running, branch, dirty files, ahead of the protected branch, unpushed commits
bash <skill>/scripts/team ps              # capacity (RAM/swap/how many more fit) + model concurrency + PM/watchdog liveness
bash <skill>/scripts/team up              # one-shot repair: session/PM/agents that stopped without delivering
```

`digest` §[4] measures the push state **against `@{upstream}`** (`git rev-list --count @{upstream}..HEAD`), never
against the protected branch: a branch that was pushed and then squash-merged stays "1 ahead of main" forever, and
treating that as "unpushed" sent the PM after a task that was already finished. `roster` therefore prints two
different columns — `ahead` (vs the protected branch) and `unpushed` (vs `@{upstream}`, where `-` means there is no
upstream at all, so the push state **cannot be judged**). §[4] only asks for a push when there really are unpushed
commits, says `no upstream (cannot judge unpushed)` when there is none, and keeps "ahead of main" as its own label.

A **squash-merged** branch is recognised instead of being reported as pending wrap-up: when the branch tip's tree
equals the tree of one of the last `TEAM_SQUASH_LOOKBACK` commits on the protected branch, `roster`/`digest` say
"already merged (squash, same content)" and stop suggesting a push. It is a documented heuristic (one tree
comparison); a squash older than that window, or one that changed something else as well, falls back to the honest
`ahead N` — the safe direction.

§[3] only points the PM at `team review <ID>` when the report is **committed on the task branch**, because the
reviewer reads the report from a checkout of that branch. A report that still lives only in an agent's working tree
is listed as "report not committed yet — wait for the agent to deliver" instead (the line stays visible; nothing is
silently dropped).

When a "turn ended" notification arrives, look at `git -C .worktrees/<a> log --oneline -5` and `status` first, then
decide: dispatch the next task, send it back, or verify. After a long absence (end of day, machine reboot): **run
`team up` first**.

## E. Verification (the PM's independent check, never skipped)

```bash
git -C <root> worktree add --detach /tmp/review-T1.1 task/T1.1-*   # the PM prepares an independent checkout
bash <skill>/scripts/team review T1.1 --dir /tmp/review-T1.1      # runs gates only + writes the verification record
bash <skill>/scripts/team review T1.1 --dir /tmp/review-T1.1 --no-gates   # manual review only
```

Artefact `docs/team/reviews/T1.1.md`: HEAD, diffstat, commit list, file list, tail of the gate output, verdict
checklist. When the gates fail the command returns non-zero — do not ignore it.

**The PM also has to read the diff**: gates only prove "the existing tests did not fail", not "the implementation
matches the brief".

## F. Merging and wrapping up

**Without a PR (local mode)**:

```bash
git -C <root> status                    # the main worktree must be clean and on the protected branch
git -C <root> merge --squash <branch>    # conflict handling: see protocol.md §8e
git -C <root> commit -m "T1.1: <title>"
git -C <root> push origin <protected-branch>
bash <skill>/scripts/team board set T1.1 done   # only mark done once it is really in the protected branch
bash <skill>/scripts/team close T1.1            # close the window, clear the task
```

> After a squash merge the branch still holds its own commits, so it stays "ahead of main" (and, with a forge,
> may even look "unpushed"). `roster`/`digest` recognise the usual case (same content) and say "already merged
> (squash)" — see section D for the heuristic and its limits. `board set <ID> done` + `close <ID>` is what actually
> finishes the task.

**With a PR/MR (forge-first: merge the PR, then fast-forward locally)**:

```bash
gh pr merge --squash --delete-branch <PR>                  # GitLab: glab mr merge <iid> --squash
git -C <root> fetch origin <protected-branch> && git -C <root> merge --ff-only FETCH_HEAD
bash <skill>/scripts/team board set <ID> done
```

> The order matters: **pushing locally first makes the PR unmergeable right away** (equivalent content, different
> commits), while the error is often misread as "the PAT lacks pull-requests:write". Merging the PR first avoids the
> whole problem.
> For a forge without a CLI (Gitea/self-hosted): use `tea` or the web UI, same order.

When the whole change (not just this task) is done, close the spec side too:

```bash
openspec archive -y <change>        # merges the deltas into openspec/specs/ and archives the change (see §0)
```

## G. Scaling up / down

```bash
bash <skill>/scripts/team add-agent api            # new agent (new worktree + branch)
bash <skill>/scripts/team ps                       # check remaining capacity and model concurrency before dispatching
bash <skill>/scripts/team dispatch api T2.1 <taskfile>
bash <skill>/scripts/team teardown --agent api     # close the window (keep the worktree)
bash <skill>/scripts/team teardown --all --purge --force   # delete the worktrees too (careful)
```

Sizing rule of thumb: **parallel agents ≈ min((RAM+free swap)/one-agent footprint, strong-model concurrency limit,
the verification bandwidth you actually have)**.
Memory no longer limits you so tightly (the floor is "do not fill swap"), but the PM's verification bandwidth is
usually the real bottleneck — dispatching too fast just builds a queue of reports waiting to be verified.
Tune the estimate with `TEAM_AGENT_MEM_MB` (default 6144); `team ps` tells you directly "how many more fit".

## H. Blockers, conflicts, boundary crossings

- An agent is blocked: it calls `team notify` + writes a PARTIAL report. The PM's move: extend the brief → `team say`
  to wake it up and let it continue.
- Two agents touched the same file: merge whoever delivered first, then `dispatch` the other to rebase/redo
  (never have an agent rebase someone else's branch).
- An agent finds someone else's bug: write `BLOCKED:` in the report; the PM decides whether to insert a new task or
  have the original owner fix it.
- Facts do not match the report: paste the failure evidence into the thread, send it back; if it keeps happening,
  switch model families for the independent verification.

## H2. Branches and merging (task mode)

```bash
git -C .worktrees/dev branch --show-current      # task/T1.2-api-health
git -C <root> worktree add --detach /tmp/review-T1.2 task/T1.2-api   # the PM prepares an independent checkout
bash <skill>/scripts/team review T1.2 --dir /tmp/review-T1.2 --strong # gates with a hard timeout + structural strong-verification checks
gh pr merge --squash --delete-branch 17 && git -C <root> fetch origin main && git -C <root> merge --ff-only FETCH_HEAD
bash <skill>/scripts/team board set T1.2 done        # only mark done once it is confirmed in main
```

`review` **fails closed** on evidence that does not describe what it stamps: an unresolvable `--branch` (the old code
skipped the branch guard, so any clean checkout could be stamped with a branch name that does not exist), a dirty
checkout, or a checkout containing `.gitignore`d artefacts the gates can read but the commit does not. Each refusal
names the matching `TEAM_REVIEW_ALLOW_DIRTY` / `TEAM_REVIEW_ALLOW_IGNORED` / `TEAM_REVIEW_ALLOW_UNRESOLVED_BRANCH`
override and, when used, the record states the truth (`checkout dirty: 3 files (override)`, `ignored artifacts: 2`,
`branch-unresolved (override)`). `--no-gates` writes `SKIPPED` and is **not** evidence: the record carries `gates: none`
and `digest` keeps listing the task as awaiting verification. A record is bound to the revision it verified, so once
the branch moves on, `digest`/`team status` flag it again (`stale: verified <A>, branch now <B>`).

- Task branches come off the protected branch; when the worktree is dirty, `dispatch` refuses to switch branches (so
  two tasks never end up in one diff).
- After `close T1.2` the worktree is normally still on `task/T1.2-*`: `close` **prints** the exact
  `git -C .worktrees/dev switch --detach main` command to run (`TEAM_TASK_BRANCH_RESET=1`; `0` silences it) and never
  runs git itself, so the next task starts clean only after the PM runs that command. See protocol.md §8e for the
  `done` gate that sits in front of `close`/`board set … done`.

## I. Periodic patrol and the PM's rhythm (the watchdog only does this one thing)

The problem: the PM (a pi process) stopped or went to sleep, an agent sent a notification, and nobody handled it.
The framing: **the watchdog is not a keep-alive heartbeat, it asks on a timer "is there work right now"** — if there
is, it wakes the PM; if not, it stays quiet (the PM is not required to be running). Starting, stopping and resuming
agents is still the PM's job.

```bash
bash <skill>/scripts/team watchdog-status      # patrol interval, standby, pending work, PM state, capacity
bash <skill>/scripts/team standby on --reason "waiting for the user to pick a stack"   # the PM stands down (no more wake-ups)
bash <skill>/scripts/team standby off         # resume wake-ups
bash <skill>/scripts/team up                  # manual rescue: build the tmux stage + start the PM (agents untouched)
bash <skill>/scripts/team up --agents         # also resume agents that have a task but no window
bash <skill>/scripts/team resume --dry-run    # the PM looks for itself: which agents should be resumed
bash <skill>/scripts/team watch --once        # run one patrol tick (one watchdog tick, equivalently)
```

### Three deployment shapes (weakest to strongest)

| Shape | Command | What it survives | Fits |
|---|---|---|---|
| **tmux window (default)** | `team watchdog up` | the PM crashing/sleeping, as long as the tmux server lives | everyday: one window is both the watchdog and the **status monitor** |
| watchdog window | `team watchdog up` | the tmux server / window disappearing | there is only this one backend (no container dependency) |
| manual | `team up` / `team watch --once` | whenever you notice yourself | troubleshooting |

```bash
bash <skill>/scripts/team watchdog up          # default: a watchdog window in this session runs the monitor + patrols
bash <skill>/scripts/team watchdog logs        # look at the monitor screen (a pane snapshot)
bash <skill>/scripts/team watchdog status      # window/period/standby/pending work/PM liveness/capacity
bash <skill>/scripts/team watchdog down        # close the window
bash <skill>/scripts/team monitor --once       # one screenful by hand (only the current session's state)
bash <skill>/scripts/team monitor --activity   # opt in to each agent's session activity stream (off by default)
bash <skill>/scripts/team watchdog up --print                # show which window/period it would use (without doing it)
```

The monitor serves **the current tmux session only**: whether windows are running, what the task is, pending work and
capacity.
Each agent's session activity stream is off by default (`TEAM_MONITOR_ACTIVITY=0`) — reading other people's sessions
is both noisy and expensive (6 agents ≈ ~9MB of JSONL per refresh, measured RSS 7MB→67MB); turn it on with
`--activity` when you need it, and even then only live windows in this session are listed.

```
teamsmith monitor · myproj                       2026-09-11T16:52:03Z  (refresh every 3s, patrol every 900s)
  patrol      900s (pending work wakes the PM) ｜ backend tmux
  standby     off
  PM          ● running (pi)
  pending     1 unread notification · 2 to verify
  capacity    RAM available 6850MB ｜ swap free 57779/80424MB ｜ about 10 more agents fit
  dev         ● pi running ｜ T1.2
  verify      ○ pi exited ｜ -

agent activity
🟢 active dev          [task/T1.2-api*]  running 12m04s · idle 8s · events 57
     16:51:22 🔧 bash
     16:51:40 💬 implementation done, running the acceptance commands…
🟡 quiet verify        [agent/verify]  running 3h02m · idle 44m10s · events 128
     16:07:03 🔧 read
```

The watchdog *is* the `watchdog` window in the same session: it runs `team monitor` (the status panel) and patrols on
`TEAM_WATCH_INTERVAL`. It is decoupled from the PM's **value dependencies** (it only looks at on-disk state and tmux
panes) but does not try to leave tmux behind — since v1.12.0 it no longer needs podman/images/sockets.

Every tick has three steps: ① append one capacity trend line to `state/capacity.log`; ② compute the pending work
(unread notifications / reports to verify / board todo·wip / blocked / agents with an unfinished task that stopped);
③ **only wake the PM when there is pending work** — while it is running, send one `[watchdog] pending: …` line (the
same batch is rate-limited by `TEAM_WATCH_NUDGE_GAP`), otherwise bring it up in its original window with `pi -c`;
**with nothing pending it does nothing at all**.
`team standby on --reason "…"` lets the PM stand down deliberately (the watchdog stops waking it; the backlog is still
logged).

### Boundaries (deliberate)

- **It does not manage tmux layout**: a missing session/window is only reported, never rebuilt
  (`TEAM_WATCH_REBUILD_TMUX=0`, the default).
  To let it recover from "the machine rebooted / the window was closed" by itself, set `TEAM_WATCH_REBUILD_TMUX=1`.
- **It does not manage agents**: an agent with a task whose window is gone is not resumed automatically — that is the
  PM's call (the PM runs `team resume --dry-run` at the start of its shift and decides; a human can do it in one shot
  with `team up --agents`).
- **It does not manage model quota and never merges**: those are the PM's job.
- **The PM is not required to run continuously**: between pending batches the PM may sit quietly (or not be running at
  all); the watchdog will not wake it just to "keep it alive".
- Runaway protection: a restart quota for the PM (`TEAM_WATCH_MAX_RESTARTS`, default 5 per hour) turns into a warning
  when exceeded; the watchdog itself holds a pid lock.

### Standby (the PM or a human deliberately stops)

```bash
bash <skill>/scripts/team standby on --reason "waiting for user authorization to merge"   # the watchdog stops waking it
bash <skill>/scripts/team standby status                        # see reason/start time/backlog
bash <skill>/scripts/team standby off                          # done, resume wake-ups
```

When it applies: there really is nothing to push forward, or a human has to step in (authorization/choice of stack/
outside information). Going on standby loses nothing: the backlog still lands in `state/watchdog.log` and
`team digest` still shows it.

### Why it can pick up again after a restart

All progress is on disk: `state/` (model/window/worktree/task/taskfile), `docs/team/` (briefs/reports/reviews/board/
threads), git branches and worktrees. When the PM is brought back it continues its original session with `pi -c` (no
history lost) and receives a kick-off prompt: run `team digest` → `team inbox --ack` → `team resume --dry-run`, and
then carry on.

### Maintenance downtime / shutting it down on purpose

```bash
bash <skill>/scripts/team standby on --reason "manual maintenance"   # temporarily: stop waking the PM
bash <skill>/scripts/team teardown --all                   # close every window (worktrees/branches/state are kept)
bash <skill>/scripts/team uninstall-watchdog --yes          # completely: the watchdog goes too
```

## J. Running for a long time (long projects)

- `BOARD.md` is the single source of truth; statuses are only todo/wip/review/done/blocked/dropped.
- At the end of every milestone: update the status in `ROADMAP.md` and write the decision into `DECISIONS.md`
  (with reasons/impact).
- Archive periodically: finished reports and verification records can move to `docs/team/archive/`; threads stay
  (append-only).
- Worktrees left around eat disk: check with `git worktree list` and clean unused ones with `teardown --purge`.
