# pm-skills · Collaboration protocol (teamsmith)

> **A short operational summary, not the rule book.** The shared constitution is the teamsmith section of
> `AGENTS.md`; detailed procedures live in the skill's `references/`. Tooling entry point:
> `bash /home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/scripts/team help`

## Roles

| Role | Where | Owns | Red lines |
|---|---|---|---|
| PM | tmux `teamsmith:pm` | Milestones/board/briefs/decisions; dispatch; evidence acceptance; merging; wrap-up | Never let an agent's own account replace evidence or execute verification/archive gates; never write tokens into any artifact |
| agent:<name> | `.worktrees/<name>` | Implementation + tests + report + the branch it was given | Never push the protected branch, force-push, merge, or change directories it does not own |

## Lifecycle of a task

1. **PM**: write the brief `docs/team/tasks/<ID>-<slug>.md` (context / deliverables / boundaries / acceptance commands / report requirements).
2. **PM**: `team add-agent <a>` for the long-lived worktree → `team dispatch <a> <ID> <taskfile>`.
3. **agent**: implement in the worktree; commit in small steps; run the acceptance commands; write the report
   `docs/team/reports/<ID>-<a>.md`; settle the branch (local: the commits stay on the task branch; remote: the
   PM's authorized push/PR route). The PM is notified automatically when the turn ends (inbox + tmux wake-up).
4. **PM**: `team digest` for pending work → prepare an independent checkout and dispatch a non-implementer verifier.
   **Verifier**: `team review <ID> --dir <checkout>` runs the gates and writes the named central record/log; the PM reads
   the evidence and diff without running the gates.
5. **Pass** → the PM runs git itself: squash-merge (with a PR, merge it first, then `fetch && merge --ff-only`) → the
   same verifier resumes on the merged SHA → the PM accepts passing evidence → `team board set <ID> done` →
   `team close <ID>`. **Fail** → send the concrete failure evidence back.

## Hard rules

1. Never claim the acceptance commands passed without having run them. The assigned verifier re-runs independently; the PM accepts the evidence; a false report fails the task.
2. One long-lived worktree per agent (sessions are keyed by cwd; moving the path makes them un-resumable); each task gets its own branch inside it.
3. Commit in small steps -- never one dump at the end; include the task ID and an `Agent: <name>` trailer.
4. Only change directories assigned to you in `docs/team/OWNERSHIP.md`; cross-directory needs → write `BLOCKED:` in the report.
5. Blocked, or you found a bug: `team notify <a> "<one line>"`, write a PARTIAL report, then end the turn.
6. Only the PM advances the protected branch (`main` by default); agents never push it, force-push, merge or rebase other branches.
7. Tokens are injected only when the PM calls a real tool (`GH_TOKEN="$(< .gh-pat)" gh …`); never echoed, never written into project files.

## Gates

- Project gates: `openspec validate --all && bash skills/teamsmith/tests/smoke.sh </dev/null`
- Verification uses an **independent checkout**: the PM prepares it (`git worktree add --detach`), then the assigned
  non-implementer verifier runs `team review <ID> --dir <checkout>` and the tool writes the named central record/log.
- A brief may require stricter commands than the project gates; the brief wins. A selected run says which sections it
  did not run instead of claiming the full suite.
- **Correctness on every change**: `openspec validate --all --strict && bash /home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/tests/smoke.sh </dev/null`.
  **Performance separately, before a release**: `bash /home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/tests/perf.sh` (front door `team perf`) — reference
  readings only, never part of a review verdict. Gate policy and its queue: `/home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/references/protocol.md` §9b-2.

## Model policy: task categories, not seats

- The contract maps **task categories** to models (`TEAM_TASK_MODELS`) and names one independent `TEAM_PM_MODEL`; a
  seat is a roster name, not a model identity.
- The brief's `category:` picks a **new** dispatch's model; a same-task recovery keeps the committed model/SID even if
  the category later leaves the map; a new task citing a dropped category is refused. Choose by the work and put the
  rationale in the brief when the choice is not obvious.
- Shared-token concurrency: strong models are the scarce resource (`TEAM_MODEL_LIMITS`); `team ps` shows occupancy.
- Changing the project's own contract, launching a fresh PM, landing source on a shared branch/skill path and adopting
  a shared source are **distinct gates**: preview the exact command and get authorization per operation.
- Full policy: `/home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/references/protocol.md` §6 and `references/config.md`.

## Specs (OpenSpec)

Specs and change proposals live in `openspec/` (required dependency). `openspec validate --all --strict` is part of the
gate. `openspec change show <id>` reads a proposal. The PM dispatches archive to a non-implementer worker only after
the same verifier's merged-revision evidence passes and the user confirms, or the PM records a proxy confirmation only
for a small, reversible change already covered by the approved approach. The worker runs `openspec archive -y <id>` on
its own authorized task branch. No parallel spec system: a
product promise goes into a spec, reasoning or guidance into `references/`.

A change runs as **five phases, one brief and one owner each**: `opsx-explore` (an explorer) → `opsx-propose` (the same
explorer, planning only) → `opsx-apply` (a dev) → `opsx-verify` (a **different** agent) → `opsx-archive` (a
non-implementer worker, possibly that verifier). Two hard rules: no `apply` brief before the PM's proposal review
(`docs/team/reviews/<change>-proposal.md`) is **ACCEPTED**, and no agent verifies its own work. The PM dispatches and
accepts archive only after the same verifier's merged-revision evidence and valid confirmation.
Phase table, gates and the PM's review checklist: `/home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/references/openspec.md`.

**The change is the assignment unit** (`1 change : N tasks`, `1 task : 0..1 change`): the brief's header is the
foreign key — `change:`, `specs:`/`anchor:` and `deltas:` — and `team dispatch` refuses more than one change id, a
change-less brief without a resolvable anchor, two unfinished tasks writing one delta file, and a verifier who
authored the change. `team change status <id>` shows readiness and exits 0 only when every mapped task is finished.

## Bootstrap and pulse

```bash
bash /home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/scripts/team bootstrap     # new project: config + docs skeleton + worktrees + pulse window
bash /home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/scripts/team pulse up      # the pulse window runs the monitor and patrols
```

- The pulse is a **metronome that wakes the PM**: every 15 minutes by default it checks for work and wakes the PM only
  when there is pending work. It never manages tmux layout, agents or quota — a stopped worker is pending work, not an
  automatic resume. Nothing to do, or a human is needed: `team standby on --reason "…"`; only a human clears it.
- **Capacity floor**: neither RAM nor disk swap may bottom out — the dispatch contract judges `MemAvailable`,
  RAM+swap, free disk swap (zram excluded), and the free bytes and inodes of the filesystem the worker writes to (the
  resolved temp root and the worktree), refusing below `TEAM_MIN_AVAIL_MB` / `TEAM_MIN_TOTAL_MB` /
  `TEAM_MIN_FREE_SWAP_MB` / `TEAM_TMP_MIN_FREE_MB` / `TEAM_TMP_MIN_FREE_INODES`, and refusing a temp root it cannot
  use. Model quotas are a separate limit. `team ps` shows the headroom; thresholds and overrides:
  `/home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/references/config.md` §2.
- Mechanism and boundaries: `/home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/references/protocol.md` §8; patrol steps:
  `/home/yikdata/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/references/workflows.md` §§D/§I.
