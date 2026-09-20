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
   └─ enqueue into <root>/.pi/team/state/outbox/ (one immutable entry) and drain it
```

Guards and limitations:
- It only fires when the cwd is under `<worktrees>/`; when the window name equals the PM window name it is skipped (to
  prevent a self-triggering loop).
- **In a linked worktree Pi does not auto-discover the project-local `.pi/extensions/`**, so `team dispatch` must load
  it explicitly with `-e <skill>/extension/team-notify.ts` (measured on CEP).
- **The knock goes through the delivery guard** (`delivery-guard`, see `troubleshooting.md` §3): the extension calls
  `team outbox enqueue --dedup <its own key>` + one `team outbox flush` instead of typing, so a notice can no longer
  be concatenated with what the human is typing. On a dirty PM box the entry waits in `state/outbox/`; the extension
  never falls back to `send-keys`, and a failed enqueue is logged while the inbox line stays.
- The inbox is transient state (gitignored); the durable record is still the report + verification + decision log.
- The same briefing is sent once per `TEAM_NOTIFY_DEDUP_SEC` seconds: Pi may settle several times inside one stretch
  of work.
- For a proactive notification (blocked, someone else's bug) use `team notify <agent> "<one line>"`, which arrives
  earlier than the automatic one.
- The **other** injected extension is `extension/team-bg.ts` (M27) — not notification, but the team's own
  background lane: `team_bg_run` starts a detached job (bounded `state/bg/<id>.log`), `team_bg_wait <id>` harvests
  it, a harvested job stays silent, several finishing jobs arrive as one message, and every turn end appends
  `settled-with-unharvested=<n>` to `state/bg.log` (runbook: `workflows.md` §E2).

## 5. Task briefs: written for "a weak model without context"

The default development model is a cheap, fast one (e.g. `deepseek/deepseek-flash`). It **will not correct an
ambiguous requirement on its own**, so a brief has to be self-contained:

- Background: why this is being done, where the relevant docs are (do not paste large chunks of code).
- Deliverables: file paths plus key signatures/behaviour, item by item.
- Boundaries: spell out what **not** to do (this prevents more drift than saying what to do).
- Acceptance: **copy-pasteable commands**, plus the report requirements.
- A fixed report format (deliverables/evidence/deviations/next steps), so the PM can read it mechanically.

## 5b. The change is the assignment unit (four dispatch guards)

`1 change : N tasks` — the change (proposal, design, delta, tasks, archive) is the dispatch unit, and a task is one
batch or one phase inside it; several briefs, agents or apply batches may share a change. The brief's header is the
foreign key, and `team dispatch` reads it **before it opens a window**:

1. **One change id.** `change:` holds exactly one token (or `-`). A comma list, two whitespace-separated ids or a
   second `change:` line is refused with the offending line; there is **no override** — a task that implements two
   changes is a mis-dispatch, not a preference, and the old "silently use the first line" behaviour is what this
   rule removes.
2. **A change-less brief declares its anchor.** With `change: -` the brief must either name a `specs:` entry that
   resolves (`<capability>[#<requirement>]` in `openspec/specs/<capability>/spec.md`) or say out loud
   `anchor: none (infra) — <reason>`. An unresolvable capability, a missing requirement or a bare `none (infra)` is
   refused with both accepted forms and the path that was looked for; `--force` proceeds with a warning and one
   audit line. This is policy B: disagreement with a rule is expressed by anchoring it, not by silence.
3. **One delta file, one writer.** Two unfinished tasks of the same change must not write the same
   `openspec/changes/<change>/specs/<capability>/spec.md`. A brief declares what it will write with `deltas:`
   (comma-separated capabilities, `-` for none); **an absent line is not "none"** — it is read as the whole delta
   set, so silence can never be used to slip past the guard. The refusal names the sibling, its board status, the
   shared file and both declarations; `--force` overrides with one audit line. `team change status <id>` prints the
   declared and the actually-touched files per task, so a declaration that lies is visible.
4. **The verifier is not an author.** A `verify` dispatch is refused when its agent also authored an `apply` task
   of the same change (mapped tasks whose board status is `dropped` are excluded and named). `--force` proceeds
   with a warning that the verification is no longer independent. A mapped task whose brief cannot be read or whose
   header has no `agent:` is a **missing signal**: the guard says which signal is missing and proceeds — an
   unknowable author is never reported as a clean one. The same predicate puts `self-verify: <agent>` on the task
   in `team change status`.

All four run before the stack guard and before any window or board write, so a refusal leaves the task's status
exactly as it was. The readiness view and the archive gate share one predicate (`team change status <id>` exits 0
iff at least one task is mapped and every mapped task is finished): an `archive` task cannot be set `done` while a
sibling of its change is unfinished, and the existing `TEAM_BOARD_DONE_FORCE=1` override still records itself.

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

The pulse (called `watchdog` before v1.36.0 — the old command/window/variable names still work as aliases and
fallbacks until v2.0.0) is not a keep-alive heartbeat but a **metronome**: on a timer it asks "is there work for
the PM right now".

- Every 15 minutes by default (`TEAM_PULSE_INTERVAL=900`, 300~3600 recommended) it computes the pending work: unread
  notifications / reports awaiting verification / board todo·wip / blocked / agents with an unfinished task that
  stopped.
- **Pending work** → wake the PM (nudge it if it is running; if not, start it with `pi -c` and the kick-off prompt
  `@state/pm-prompt.md`); **nothing pending** → do not wake it, do not start it — the PM is not required to run
  continuously, and being quiet is a valid state.
- **Who resumes a stopped agent** (the one question this paragraph exists to settle): **the pulse never
  does.** A stopped agent with an unfinished task is *reported* as pending work; starting it is the PM's call
  (`team resume --agent <a>`, or `team resume` for all). The single exception is a human's rescue command:
  `team up` recovers the PM window and, **only with `--agents`**, also resumes the agents that stopped with an
  unfinished task (that is why a session restore can bring workers back without the PM asking). The watchdog
  spec pins the pulse half of this as a scenario ("A stopped agent is not resumed") — if you ever see a resumed
  worker you did not ask for, look for a `team up --agents` / `team resume` in the log, not in the patrol.
- **"The PM is running" is a proof, not an inference**: either `state/pm.pid` (recorded by the start path) points at
  a live process whose cwd is inside the project, or the process in the PM window is the configured agent binary and
  its cwd is in the project. A window occupied by anything else is `foreign:<cmd>` (another project's cwd — not
  overwritten without `TEAM_REPLACE_FOREIGN_PM=1`) or `unknown:<cmd>` (in-project cwd, but not the agent). `unknown`
  never suppresses starting the PM: a freshly created, empty pane is not a running PM, and claiming otherwise is how
  `team up` once printed "PM is running" while starting nothing (M6.5).
- **`starting` is a state of its own (M7.2)**: between `respawn-pane` and the moment a start's evidence lands, the PM
  pane is a shell running the start command — in-project, but not the agent. While that start is in flight the tool
  keeps `state/pm.pid.starting` (epoch, starter pid, target; fresh for `TEAM_PM_START_WAIT + 5s`) and every surface
  reports `starting:<age>`: it is not "running" (there is no proof yet) and it is **not** "no PM" either. A tick that
  sees it neither nudges nor starts a second PM — a second `respawn-pane` would kill the PM that is just coming up,
  and the restart quota would count one start twice. A stale marker (the starter crashed) is ignored: it is evidence,
  never a lock.
- **One tick, one state read**: the patrol derives every conclusion (nudge / start / stay quiet) from a single
  `team_pm_state` read, and `state/pm-restarts.log` records **real restarts only** — the quota is checked before
  starting, the line (epoch, timestamp, evidence) is written after a successful start. Every attempt is recorded in
  `state/pm-start-attempts.log` with the evidence, and the quota counts both files (`TEAM_PULSE_MAX_RESTARTS` per
  hour), so a start loop that spawns but never confirms cannot run away while "the PM was restarted N times in the
  last hour" stays a fact and not a count of attempts. A failed or timed-out attempt is logged in
  `state/watchdog.log` as not counted. `pulse status`, `digest`, `ps` and the monitor panel print the same state
  and name the evidence behind it (`state/pm.pid=<pid> proof=spawn|argv`, the starting marker, the empty prompt, the
  occupant).

What each liveness state means and what the PM should do:

| state | meaning | what to do |
|---|---|---|
| `running:<pid\|cmd>` | proof: the recorded pid is alive with an in-project cwd (`proof=spawn` / `proof=argv`), or the window's process is the configured agent binary | nothing; a nudge means "there is pending work" |
| `starting:<age>` | a start is in flight (fresh `state/pm.pid.starting`) | nothing — the tick will not start a second PM; wait for `running` (the marker expires after `TEAM_PM_START_WAIT + 5s`) |
| `idle:<shell>` | empty prompt | `team up`, or let the pulse start it when there is pending work |
| `unknown:<cmd>` | in-project occupant that is not the agent (fresh pane, `sleep`, editor) | `team up` replaces it; it never suppresses a start |
| `foreign:<cmd>` | occupant whose cwd belongs to another project | close that window, or `TEAM_REPLACE_FOREIGN_PM=1 team up` |
| `missing` | the PM window does not exist | `team up`; `TEAM_PULSE_REBUILD_TMUX=1` lets the pulse rebuild it |

`busy` is not a liveness state of its own: a pane whose foreground process is the agent is `running`, and a pane that is
merely busy with something else in this project (the pre-`exec` start command, a `sleep`, an editor) is `unknown:<cmd>`
— it does not suppress starting the PM. The internal pane-busy probe is only used to tell an empty prompt (`idle`) from
an occupant (`unknown`).
- The PM can stand down deliberately: `team standby on --reason "…"` (nothing to do / a human has to step in), after
  which it is not woken; a backlog is still logged; once a human has dealt with it, `team standby off`.
- Repeated reminders for the same batch are limited by `TEAM_PULSE_NUDGE_GAP`; a PM that is busy can simply ignore a
  reminder.
- Division of labour with instant notifications: the notification at the end of an agent's turn is **instant** (the
  notify extension: write the inbox + knock on the PM window); the pulse's reminder is a **timed fallback**: as
  long as that batch is unread/unhandled, the next round (or a change in pending work) raises it again.
- Boundaries: it does not manage tmux layout (`TEAM_PULSE_REBUILD_TMUX=0`, a lost state is only reported), does not
  manage agents (the PM's job), does not manage model quota and never merges automatically. Runaway protection: the
  auto-start quota of 5 per hour plus the pulse's own pid lock.

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

## 8c. The pulse's scope: it serves the current tmux session only

- The pulse (`team monitor` in the `pulse` window) only answers questions about this session: who is running,
  what task they are on, what is pending, how the capacity looks; it **never digs through another agent's session
  content** (that is what the PM reads via `inbox`/reports/`digest`).
- The session activity stream is opt-in: `team monitor --activity` (and it only lists live windows in this session).
  It is off by default for a very practical reason: 6 agents ≈ ~9MB of JSONL read per render (measured 7MB→67MB RSS,
  refreshed every 3s), and the noise covers up the state you actually needed to see.
- The panel refreshes every 5s by default while the patrol beat stays `TEAM_PULSE_INTERVAL` (900s by default).
- **What counts as "pending work"**: unread notifications / reports awaiting verification / a `blocked` row / agents
  that stopped (with a task that was never delivered).
  The board's `todo/wip` **do not count by default** — a backlog is always there and knocking every 15 minutes would
  be pure noise; to include the backlog in reminders set `TEAM_PULSE_PENDING_BOARD=1` (the panel and the digest always
  show them anyway).

## 8d. Board and report parsing must tolerate human edits

Three places CEP hit in practice, all of which now have explicit tolerance rules:

- **BOARD column count**: `ID/task/Agent/branch/dependency/status` are located **by header name**, so columns may be
  inserted by hand (e.g. an `Issue` column); `board ls` reports a "non-standard column layout" but keeps working;
  `team board set` only writes the status column and never touches a column you added; new rows are aligned to the
  existing column count (unknown columns stay empty). Parsing used to be positional, and after adding a column it
  would read a `—` as the title.
- **Duplicate ids**: a board row is identified by `(id, nth)` — the n-th row carrying that id — because a board
  may share an id between tasks. The console walks the focus positionally, so two rows with one id are two
  stops and each can be selected alone; `board add` refuses a second row for an existing id unless `--allow-dup`
  is passed (audited in `state/watchdog.log`), and `board ls` / `digest` / `doctor` report the duplicates
  (doctor warns, it does not fail). `board set <ID> <status>` and `board assign <ID> <agent>` address a row by
  **id** and write **every** row carrying it (that has always been the CLI's rule; the row-level identity above
  is the console's) — which is exactly why a *new* duplicate is refused at the door.
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

### The tool checks step 3 instead of trusting it

Since v1.20.0 `team board set <ID> done` (and `team close <ID>`, whose default status is `done`) **refuses** unless
it can point at something checkable at that moment:

- `<docs>/reviews/<ID>.md` exists and its verdict is not `FAIL`/`TIMEOUT` (`PASS`; `UNKNOWN`/`SKIPPED` are accepted
  as an explicit manual review and named as such in the output), **or**
- the task branch tip is already contained in the protected branch (`git merge-base --is-ancestor`, i.e. a real
  merge / fast-forward). A **squash** merge does not satisfy this — the branch commits are not ancestors — so in the
  usual squash workflow the review record is what unlocks `done`.

Every accepted transition appends what it checked to `<docs>/reviews/<ID>-done.md` (append-only; the forced case is
marked `FORCED`), so "what did it verify at that moment" survives the terminal:

```
- <timestamp> · `team board set M5.2 done` · OK：the evidence line for that moment
                                      (e.g. "review record <docs>/reviews/M5.2.md, verdict PASS")
```

If neither condition holds and the PM is sure anyway, the override has to carry a reason:

```bash
TEAM_BOARD_DONE_FORCE=1 TEAM_BOARD_DONE_REASON="hotfix pushed by hand; PR #12 is the record" \
  team board set <ID> done                 # or: team close <ID> --status done --force --reason "…"
```

A missing reason is refused, and the transition is recorded as `FORCED` together with the failed checks — an
override is allowed, a silent one is not. Nothing is written when the gate refuses.

### What the tool cannot check (the PM's own checklist)

The "pushed" half is the PM's:

- `git -C <root> merge-base --is-ancestor <branch> <protected>` exits 0, and `git -C <root> status -sb` shows the
  protected branch is not ahead of its upstream;
- `team review <ID> --dir <independent checkout>` recorded `PASS` on the revision you are about to merge
  (`--strong` for a milestone);
- only then `team board set <ID> done` and `team close <ID>`.

Conflict handling (the PM runs all of this itself):

```bash
git -C <root> merge --abort                                  # want to give up and start over
git -C <root> status --porcelain | grep '^U'                 # list the conflicted files (UU/AA/…)
# lockfile-style conflicts (pnpm-lock.yaml and friends): take the branch side, then reinstall
git -C <root> checkout --theirs -- pnpm-lock.yaml && (cd <root> && pnpm install --lockfile-only)
git -C <root> add -A && git -C <root> commit -m "<ID>: <title>"
```

**Conflict markers do not ride along**: `smoke.sh` §0d greps every tracked file for a line starting with
`<<<<<<<` / `=======` / `>>>>>>>` and fails with `file:line`, so a `git add -A && git commit` on top of an
unresolved `merge --squash` is caught by the next gate instead of reaching `main` (it did once).

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
  timeout is recorded as `TIMEOUT`, treated as FAIL and written into the verification record). The verdict is taken from
  the `timeout` **wrapper's exit code together with the elapsed time** (124 = TERM fired, 137 = the child ignored TERM
  and was KILLed), never from a substring of the gate's own log — otherwise a hung gate reads as a plain failure and a
  gate that merely *prints* “using timeout 5” reads as a timeout. Requiring **both** signals is what stops the opposite
  error: a gate that exits 124 by itself (or a suite whose inner test propagates 124) used to be recorded as "killed at
  the deadline"; it is now `FAIL` (a signal-terminated gate is recorded as `FAIL` with the signal named). Gate commands
  should carry their own `timeout` too (e.g. `timeout 900 pnpm test:unit`).
- Acceptance commands in a brief should carry their own timeout as well; destructive experiment scripts must restore
  the scene with `trap 'git checkout -- …' EXIT`.

### 9b-2. The gate is the machine's one shared resource (queue, and the measurement premise)

The full gate — `openspec validate … && bash skills/teamsmith/tests/smoke.sh` — spends the machine's tmux servers,
node/bun processes and login shells, so it is serialised on **one gate lock**
(`${TEAM_SMOKE_LOCK:-${TMPDIR:-/tmp}/teamsmith-smoke.lock}`, holder recorded in `<lock>.holder`, wait capped by
`TEAM_SMOKE_LOCK_WAIT`, default 1800 s). Use `TEAM_SMOKE_FAST=1` for in-batch self-tests (pure-logic sections,
~10 s) and the **full** suite for delivery and review. `team review` takes that same lock **before** starting its
hard timeout: the queue is its own bounded phase, the record accounts it separately (`limit=Ns queued=Ns ran=Ns`),
a queue that exceeds the cap is `FAIL` with the holder named (never `TIMEOUT`), a run that really overruns is still
`TIMEOUT` with `ran=Ns`, and `SMOKE_LOCK_WRAPPED=1` tells a nested run that an ancestor already holds the lock (so
it does not queue again and cannot deadlock against its own suite). Without `flock` the degradation is printed.
The two panel numbers in the gate (an uncached frame ≤ 2000 ms, steady state < 1 % of one core) are verdicts about
the panel, so they are only judged when the machine is below the **load premise** `loadavg_1m ≤ factor × logical
cores` — `0.75` for the gate's five-sample median assembly assertion, `0.25` for `panel-cpu.sh`'s cold-start
first frame and sampled pane CPU (`TEAM_PANEL_CPU_PREMISE_FACTOR`), and both of those single-sample numbers are
the **median of three** with all three samples printed; above it the assertion prints the measured value(s) and the load and **skips visibly** (its own counter,
named in the run's summary; `panel-cpu.sh` uses exit 4 for the same reason) rather than reporting a red the machine
owes. The thresholds themselves are never scaled or relaxed, and the fixture knobs that substitute a load reading
(`TEAM_SMOKE_LOADAVG`, `TEAM_PANEL_CPU_LOADAVG`, …) only work under `TEAM_SMOKE_FIXTURE=1`. The contracts live in
the specs (`verification#The hard timeout covers the gate run, not the queue`,
`panel#Frame assembly is asynchronous, cached and never blocks input`); this section is the operational rule.

## 9c. Strong verification (adversarial package + finding flips, for milestones)

`team review <ID> --strong` checks two extra things and writes the conclusion into the verification record. The check is
**structural**, not a keyword grep (a report that merely *mentions* “flip evidence” or “independent package” does not
pass; an English-first report with real evidence does), the wording is the one this repo's own
`templates/report.md.tmpl` / protocol use, and the record shows what was looked for, what was found (file + line) and
which half is missing:

1. **Flip evidence**: a section whose heading names the flip (`flip`, `flip evidence`, `red before … green after`,
   “break the implementation”, `翻转`, `破坏`) **and** which contains both a failing (red) and a passing (green) result —
   “red before the fix → green after”, or “break the implementation → the guard test must fail”. A command line is
   recorded as an extra hint;
2. **Independent verification package**: a **path** in the report that points at the package/script — `…/pkg/run.sh`,
   `docs/team/reports/<ID>-<agent>/pkg/…`, a script (`.sh`/`.mjs`/`.js`/`.ts`/`.py`) or any *really existing* directory
   in the checkout. Bare words (“an independent package exists”) do not count. A statement of independence is recorded
   as a hint, and the record also says whether that path is actually present in the reviewed checkout.

The report is looked up in the reviewed checkout first and then in the PM's/agent's worktrees (a report that is not
committed in the verified revision is still read, and the record states that it was taken from outside the checkout).

A missing half is recorded as `不满足（不阻塞合并，但里程碑收口前应补齐）` and warns; it does not block the merge. The
sharper kind of flip — **deliberately break the implementation → the guard test must fail** — is exactly what a heading
like `## Flip evidence` with both outcomes is expected to contain.

It costs more, so it fits milestones and closure rounds; everyday tasks run the ordinary gates.

## 10. Decision log and research rules

- For a stack/technology choice (language, framework, library, storage, protocol) a **research agent gathers evidence
  first** (① measured on this machine > ② official documentation > ③ secondary sources; anything unmeasured must be
  marked as such), and the PM only writes a "decision" after verifying that evidence chain.
- Every decision must record its **reason** and its **impact**: a decision log with conclusions only is worth nothing
  six months later.
- An agent may overturn the PM's provisional judgement with its own evidence — that is by design, not overreach.

## 11. Talking to the user: a code never stands alone

The ledger is keyed by codes (`M12`, `P14`, `V15`, `T1.1`): the BOARD, the roadmap, briefs and review records all
use them, and after a few days the team reads them fluently. The user has no such index in their head — a report
that says "P14 needs a decision" sends them to the files to find out what P14 *is*, and the message that should
have informed them turns into homework.

So: **in user-facing output, a code never stands alone.** Every occurrence that names a task carries its short
human-readable name in the same place — `M12 (fix the smoke flake)` — and milestones and change ids work the same
way. A list is read row by row, so a code repeated on another line is named again there ("each row is a reading
unit"). The one exception is a copy-pasteable command (`team close M12`): there the code is a key, and rewriting
it would break the tool it calls.

The mechanism backs this up wherever the ledger already knows the name: `team digest` (pending review, the
board-skipped line, wrap-up, suggestions), `team status` and `team roster` print the name next to the code, resolving
it from the BOARD's task column first, then the task brief's H1, then the task's report H1. When no name is known the
code is printed alone — never a made-up name, and never a hidden code: the code is the key to the ledger.
