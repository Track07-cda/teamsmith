# Protocol: why a Pi agent team is organised this way

This document is the "why" behind the team protocol section of `AGENTS.md`. The rules themselves are short; the
reasons are what stop a future you (and future agents) from treating them as bureaucracy to route around.

> **The belief layer lives in [philosophy.md](philosophy.md)** (8 judgement standards plus their failure modes). This
> file explains "why the rules are what they are", that one explains "why this role should think this way". When the
> two disagree the creed wins, and the rule gets fixed afterwards.

---

## 1. Roles: the PM is not "a smarter agent", it is the only role allowed to merge

| | PM (orchestrator) | worker agent |
|---|---|---|
| Context | long-lived, across tasks, holds the roadmap and the decision history | one stretch per task, focused on implementation |
| Output | briefs, decision log, verification records, merges | code, tests, reports, PR/MR |
| Authority | the protected branch, forge writes, repository settings | its own task branch |

Splitting "writing code" from "judging whether the code is acceptable" across different sessions is what creates
**independent verification**: the agent's report is a **claim**, the gate results the PM obtains on an independent
worktree are **evidence**.

> A real CEP lesson: a report claimed 28/28 tests passing, the PM re-ran it and 4 specs failed (the cause was a value
> import used to import a pure type under `verbatimModuleSyntax`). Conclusion: a report ≠ evidence, verification has
> to be institutionalised.

## 2. The evidence model (three layers, each more trustworthy than the last)

1. **Claim**: the conclusion an agent writes in its report (least trustworthy).
2. **Checkable artefact**: commits, test files, log files, diffs.
3. **Independent verification**: the result the PM gets by running the same commands on **another checkout** (most
   trustworthy).

Any "passes/done" has to land in layers 2 and 3. The acceptance commands in a brief plus the PM's `team review` are
the implementation of that chain.

## 3. Isolation: worktree + branch + a long-lived cwd

- **One worktree per agent** (long-lived), with a new branch per task inside it.
- Why long-lived: a Pi session is keyed by **cwd**. Move the worktree path and the old session cannot be found again
  (CEP has been there).
- Why not "one worktree per task": sessions fragment, and both follow-up questions and resuming from a checkpoint get
  harder; a long-lived worktree lets the agent keep its memory.
- The main worktree (main) belongs to the PM alone: merges, verification and documentation happen there, so nobody
  fights an agent over the workspace.

## 4. The wake-up loop: an asynchronous agent must be able to wake the PM by itself

The PM cannot poll (wastes context, high latency) and should not wait for the user to relay things. The mechanism
(`extension/team-notify.ts`):

```
agent turn ends (Pi's agent_settled: the point where it will not continue on its own)
   ├─ append <root>/<docs>/inbox/<agent>.md      ← durable, the PM can read it at any time
   └─ tmux send-keys -t <session>:<pm-window>    ← submitted to the PM session as a user message, which wakes it
```

Guards and limitations:
- It only fires when the cwd is under `<worktrees>/`; when the window name equals the PM window name it is skipped (to
  prevent a self-triggering loop).
- **In a linked worktree Pi does not auto-discover the project-local `.pi/extensions/`**, so `team dispatch` must load
  it explicitly with `-e <skill>/extension/team-notify.ts` (measured on CEP).
- The notification text lands in the PM's input line; if the user is typing at that moment it can be concatenated with
  their input (a known side effect).
- The inbox is transient state (gitignored); the durable record is still the report + verification + decision log.
- The same briefing is sent once per `TEAM_NOTIFY_DEDUP_SEC` seconds: Pi may settle several times inside one stretch
  of work.
- For a proactive notification (blocked, someone else's bug) use `team notify <agent> "<one line>"`, which arrives
  earlier than the automatic one.

## 5. Task briefs: written for "a weak model without context"

The default development model is a cheap, fast one (e.g. `deepseek/deepseek-flash`). It **will not correct an
ambiguous requirement on its own**, so a brief has to be self-contained:

- Background: why this is being done, where the relevant docs are (do not paste large chunks of code).
- Deliverables: file paths plus key signatures/behaviour, item by item.
- Boundaries: spell out what **not** to do (this prevents more drift than saying what to do).
- Acceptance: **copy-pasteable commands**, plus the report requirements.
- A fixed report format (deliverables/evidence/deviations/next steps), so the PM can read it mechanically.

## 6. Model strategy: cheap models do the work, a different family does the adversarial verification

| Use | Selection principle |
|---|---|
| Implementation/tests/docs | a cheap model without concurrency limits; a good brief is enough |
| Independent verification/adversarial analysis | switch model families (to avoid the same blind spots), e.g. the grok family |
| Heavy review/hard problems | subscription quota is tight → cap concurrency with `TEAM_MODEL_LIMITS`, run one at a time |
| Long-context hard problems | slow and concurrency-limited; only when the PM explicitly asks |

`team dispatch` checks `TEAM_MODEL_LIMITS` and capacity before dispatching: the rules (from two OOM incidents on CEP,
one of which hit RAM and zram bottom at the same time):

| Line | Default | Meaning |
|---|---|---|
| `TEAM_MIN_AVAIL_MB` | 1024 | **hard line**: refuse to dispatch below this `MemAvailable` (that CEP machine sets 4096) |
| `TEAM_MIN_FREE_SWAP_MB` | 1024 | **hard line**: refuse to dispatch below this much free **disk swap** (**zram excluded**) |
| `TEAM_MIN_TOTAL_MB` | 512 | hard line: `MemAvailable + free disk swap` |
| `TEAM_WARN_AVAIL_MB` | 4096 | warn only: RAM is tight, slowness is allowed |
| `TEAM_ZRAM_WARN_PCT` | 85 | warn only: zram usage is too high (zram pages live in RAM, so it is a source of slowness, not a safety net) |

Why zram is looked at separately: the "free space" of `/dev/zram0` is really compressed pages in RAM, and once full it
stays essentially full; counting it towards the concurrency budget systematically overestimates the headroom, and when
an OOM happens RAM and zram bottom out together.

## 7. Security red lines (non-negotiable)

- A token is injected only when the PM **calls a real tool** (e.g. `GH_TOKEN="$(< .gh-pat)" gh …`); it is never echoed
  and never lands in a project file or a log.
  The skill is fully decoupled from forges: it does not probe gh/glab, does not read tokens and does not open PR/MRs
  for you (v1.12.0).
- Agents may not: push the protected branch, force-push, merge, rebase/delete someone else's branch, change repository
  settings.
- Agents may not read credential/account files (such as `~/.pi/agent/auth.json`).
- Any operation that changes shared/remote state needs `--yes` (explicit user authorization). The skill never decides
  for the user.

## 8. Periodic patrol: no "watch everything", only waking people up

The watchdog is not a keep-alive heartbeat but a **metronome**: on a timer it asks "is there work for the PM right
now".

- Every 15 minutes by default (`TEAM_WATCH_INTERVAL=900`, 300~3600 recommended) it computes the pending work: unread
  notifications / reports awaiting verification / board todo·wip / blocked / agents with an unfinished task that
  stopped.
- **Pending work** → wake the PM (nudge it if it is running; if not, start it with `pi -c` and the kick-off prompt
  `@state/pm-prompt.md`); **nothing pending** → do not wake it, do not start it — the PM is not required to run
  continuously, and being quiet is a valid state.
- The PM can stand down deliberately: `team standby on --reason "…"` (nothing to do / a human has to step in), after
  which it is not woken; a backlog is still logged; once a human has dealt with it, `team standby off`.
- Repeated reminders for the same batch are limited by `TEAM_WATCH_NUDGE_GAP`; a PM that is busy can simply ignore a
  reminder.
- Division of labour with instant notifications: the notification at the end of an agent's turn is **instant** (the
  notify extension: write the inbox + knock on the PM window); the watchdog's reminder is a **timed fallback**: as
  long as that batch is unread/unhandled, the next round (or a change in pending work) raises it again.
- Boundaries: it does not manage tmux layout (`TEAM_WATCH_REBUILD_TMUX=0`, a lost state is only reported), does not
  manage agents (the PM's job), does not manage model quota and never merges automatically. Runaway protection: the
  auto-start quota of 5 per hour plus the watchdog's own pid lock.

Why the boundaries are drawn this narrow: an "everything-managing" daemon would manipulate tmux layout, agent
lifecycles and model quota at the same time, and when something breaks nobody can tell who corrupted the state;
furthermore, the more "keep-alive" it does, the easier it is to silently paper over something that should have needed
a human.

## 8b. Branch model: one branch per task (default)

- `TEAM_BRANCH_MODE=task` (default): `dispatch` cuts `task/<ID>-<slug>` off the protected branch inside the agent's
  long-lived worktree; `review/merge/close` all operate on that task branch → **the verification scope is one task's
  diff**, the rollback granularity is one task, and the PR description is a reference to the brief. After a task is
  `close`d the worktree returns to `detached@protected branch`, so the next task starts clean.
- `TEAM_BRANCH_MODE=agent`: one long-lived branch `agent/<name>` per agent (fits long refactors, or a team where each
  agent only ever does one thing).
- When the worktree is dirty, switching branches is refused (otherwise the previous task's changes leak into the new
  task); that is a hard rule, not a reminder.

## 8c. The watchdog's scope: it serves the current tmux session only

- The watchdog (`team monitor` in the `watchdog` window) only answers questions about this session: who is running,
  what task they are on, what is pending, how the capacity looks; it **never digs through another agent's session
  content** (that is what the PM reads via `inbox`/reports/`digest`).
- The session activity stream is opt-in: `team monitor --activity` (and it only lists live windows in this session).
  It is off by default for a very practical reason: 6 agents ≈ ~9MB of JSONL read per render (measured 7MB→67MB RSS,
  refreshed every 3s), and the noise covers up the state you actually needed to see.
- The panel refreshes every 5s by default while the patrol beat stays `TEAM_WATCH_INTERVAL` (900s by default).
- **What counts as "pending work"**: unread notifications / reports awaiting verification / a `blocked` row / agents
  that stopped (with a task that was never delivered).
  The board's `todo/wip` **do not count by default** — a backlog is always there and knocking every 15 minutes would
  be pure noise; to include the backlog in reminders set `TEAM_WATCH_PENDING_BOARD=1` (the panel and the digest always
  show them anyway).

## 8d. Board and report parsing must tolerate human edits

Three places CEP hit in practice, all of which now have explicit tolerance rules:

- **BOARD column count**: `ID/task/Agent/branch/dependency/status` are located **by header name**, so columns may be
  inserted by hand (e.g. an `Issue` column); `board ls` reports a "non-standard column layout" but keeps working;
  `team board set` only writes the status column and never touches a column you added; new rows are aligned to the
  existing column count (unknown columns stay empty). Parsing used to be positional, and after adding a column it
  would read a `—` as the title.
- **The pending-report heuristic**: a file under `reports/*.md` only counts as awaiting verification when its
  file-name prefix is a task ID **and** its title is `# <ID> · …` **and** that ID is on the BOARD (or has a brief);
  the PM's own milestone/closure reports (`P2-closure.md` and the like) are grouped by `digest` under "ignored
  non-task reports" — not silently dropped, and not nagged about either.
- **merge conflicts**: on failure the unmerged files are listed directly (`UU/AA/DD/AU/UA/DU/UD`) together with a hint
  about `--no-renames` (add/add is often git's rename detection pairing `reports/<ID>-x.md` with `reviews/<ID>.md`).
  It no longer just drops a "conflict/failed" on you to re-run by hand.

## 8e. A BOARD status only becomes done after the code really reached the protected branch

CEP has been there: on a failed conflict path the BOARD had already been marked `done` while the code never reached
`main` (the PR was still open) — a status contradicting the facts is more dangerous than the failure itself. The
current order and the closing move:

1. verify the branch exists (a mistyped `--branch` is not misreported as a "conflict");
2. `merge --squash` → `commit` → **`push` (when `--push`/`--pr`)** all succeed;
3. only then `board set <ID> done`.

If any step fails (conflict / failed commit / failed push): **the BOARD keeps its pre-merge state** (usually
`review`), and `done` is not set — code that never reached the protected branch is not finished.

Conflict handling (the PM runs all of this itself):

```bash
git -C <root> merge --abort                                  # want to give up and start over
git -C <root> status --porcelain | grep '^U'                 # list the conflicted files (UU/AA/…)
# lockfile-style conflicts (pnpm-lock.yaml and friends): take the branch side, then reinstall
git -C <root> checkout --theirs -- pnpm-lock.yaml && (cd <root> && pnpm install --lockfile-only)
git -C <root> add -A && git -C <root> commit -m "<ID>: <title>"
```

A trap: an add/add conflict is often git's rename detection pairing two different paths (e.g. `reviews/<ID>.md` and
`reports/<ID>-<agent>.md`). Retry with `git -c merge.renames=false merge --squash <branch>` and it goes away.

## 8f. Template rendering and dispatch traps (measured on erp)

- **Rendering must not go through sed**: `&` inside the replacement string means "the matched text", so
  `TEAM_GATES="pnpm test && pnpm lint"` was written out as `pnpm test {{GATES}}{{GATES}} pnpm lint`. `team_render` now
  uses bash parameter expansion and explicitly disables bash 5.2+'s `patsub_replacement` (which likewise treats `&`
  in the replacement as the matched text).
  `init` also escapes gate values containing `$ \` \ "` before writing them into the config, so sourcing it back
  yields the same value as the input (and is never executed).
- **Dispatch writes absolute paths**: the window shell's PATH/rc may not be ready yet, so exec'ing `pi` directly ends
  in `command not found` (reproduced twice on erp). Dispatch now resolves pi's absolute path first, writes it into the
  window command, and checks that it exists before dispatching (a missing binary fails immediately instead of being
  discovered inside the window).
- **GitLab API headers and bodies must match**: if `--data-urlencode` is the form body, then
  `Content-Type: application/x-www-form-urlencoded` must go with it; setting `application/json` gets rejected by
  GitLab (`{"error":"Invalid JSON format"}`, and the PR/MR never opens). A JSON body (`--data/--data-binary`) still
  uses `application/json`.

## 8g. Across projects: you may talk, you may not command

- **Normal conversation between projects is allowed**: how an interface connects, advice with its basis, problem
  reports with reproductions, scheduling a joint test window.
  **Not allowed**: telling another PM/agent what to do, deciding on the other side's behalf, impersonating a human to
  issue instructions, changing the other side's repository or state.
- The mechanism makes "wanting to command but being unable to" real: the `intent` whitelist of `team meeting` has
  **no command/order**; `--as-user` only works from a human terminal (+ `TEAM_MEETING_ALLOW_USER_ID=1`), so an agent
  process writing it is refused; consensus requires **both sides to agree separately**; the meeting only writes the
  shared area and has zero write permission in the peer's repository.
- Division of labour: **workers do not attend** (cross-project communication goes through the PM); a worker that needs
  outside cooperation writes `BLOCKED:` in its report.
- The shared area lives outside both projects (`~/.pi/team/meetings/<slug>/`) and the transcript is the only truth;
  knocking (nudging the peer PM's window) is off by default and only happens with `--knock` + `TEAM_MEETING_KNOCK=1`
  + a registered peer session.
- Boundary guard: cross-session typing is refused **by default without exception**; the single exception is knocking
  for a registered meeting — which is what stops "casually reaching into another project".

## 8h. git and forges belong to the PM: the skill neither performs nor wraps them

- The skill **does not perform** git writes (creating/switching branches, squash, push) or forge writes (open/merge a
  PR, comment, close a PR); **and it does not print "recipes"** either — that would be over-packaging tools that
  already exist. The PM uses the **real tools** directly: `git`, plus whatever forge access it has (`curl` against an
  API, `gh`/`glab`, the web UI).
- On git the skill does exactly three things (all read-only or bookkeeping):
  1. **Checks**: before `dispatch` it confirms the worktree is clean and not on the protected branch (otherwise it
     refuses and explains why);
  2. **Read-only observation**: `roster` / `digest` show the branch, dirty file count, commits ahead and a
     "waiting to be wrapped up" list;
  3. **Verification evidence**: `review <ID> --dir <the checkout the PM prepared>` runs the gates and writes
     `reviews/<ID>.md` (git is prepared by the PM).
- The conventions (written in SKILL.md and the project's PROTOCOL, for the PM to follow): one long-lived worktree per
  agent; task branches cut off the protected branch; verification on a detached independent checkout; merging =
  squashing into the protected branch (with a PR, merge the PR first and then `fetch + merge --ff-only`);
  **the BOARD is only marked done after the code has really reached the protected branch**.
- Forge-agnostic: GitHub/GitLab are not assumed; a token is read from the project's configured token file and injected
  only for the duration of a command, never echoed.

## 9. Capacity: the floor is that neither RAM nor disk swap bottoms out (zram does not count)

- There is only one condition for refusing a dispatch: free swap below `TEAM_MIN_FREE_SWAP_MB` (1024MB by default) or
  RAM+swap below `TEAM_MIN_TOTAL_MB`.
- Tight RAM (below `TEAM_WARN_AVAIL_MB`) only warns: slowness is acceptable, because slow is not broken; an OOM is the
  real accident.
- `team ps` / `team doctor` report from the same data source and add an estimate of "how many more agents fit"
  (`TEAM_AGENT_MEM_MB`).

## 9b. Tests and gates must have a timeout (non-negotiable)

- The fact: a deliberately broken implementation made a PG integration test wait for a connection forever (no pool
  timeout + a missing `--test-timeout` + bash `timeout` set to 1800000s) → the script hung for **85 minutes** with zero
  output.
- Therefore: `team review` **always wraps the gates in a hard timeout** (`TEAM_REVIEW_TIMEOUT`, 1800s by default; a
  timeout is recorded as `TIMEOUT`, treated as FAIL and written into the verification record). Gate commands should
  carry their own `timeout` too (e.g. `timeout 900 pnpm test:unit`).
- Acceptance commands in a brief should carry their own timeout as well; destructive experiment scripts must restore
  the scene with `trap 'git checkout -- …' EXIT`.

## 9c. Strong verification (adversarial package + finding flips, for milestones)

`team review <ID> --strong` checks two extra things and writes the conclusion into the verification record:

1. **Adversarial verification package**: the verifying agent writes tests in an **independent package** (not reusing
   the tested project's fixtures, which would be "using the object under test to verify itself");
2. **Finding flips**: the fixer turns the "finding test that recorded a defect" into a guard test and the report shows
   "red before the fix → green after"; the sharper version is **deliberately break the implementation → the guard test
   must fail** (proof that the test is not a performance).

It costs more, so it fits milestones and closure rounds; everyday tasks run the ordinary gates.

## 10. Decision log and research rules

- For a stack/technology choice (language, framework, library, storage, protocol) a **research agent gathers evidence
  first** (① measured on this machine > ② official documentation > ③ secondary sources; anything unmeasured must be
  marked as such), and the PM only writes a "decision" after verifying that evidence chain.
- Every decision must record its **reason** and its **impact**: a decision log with conclusions only is worth nothing
  six months later.
- An agent may overturn the PM's provisional judgement with its own evidence — that is by design, not overreach.
