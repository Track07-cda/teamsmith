---
name: teamsmith-init
description: teamsmith-init is the new-project entry point of the teamsmith toolkit — organize multiple agents into a team, set up an agent collaboration protocol, and bootstrap this skill into a new project. It walks the questions to settle with the user first (dependencies, session and roster, per-agent models, gates, VCS mode, install command, and the project's ROADMAP/OWNERSHIP/AGENTS.md red lines), then runs the one command that writes `.pi/team/config.sh` + the `docs/team/` skeleton + the `AGENTS.md` protocol section and starts the pulse, and finally hands day-to-day operation to the `teamsmith` skill. Use when the user wants to bootstrap teamsmith into a new repository, set up a brand-new team, organize multiple agents into a team, or set up an agent collaboration protocol where none exists yet.
license: MIT
metadata:
  version: "1.42.0"
---

# teamsmith-init · bring a new project to "ready to dispatch"

You are the first session in a repository that has no team yet. Three beats: settle the questions below with the
user, run one command, then hand day-to-day operation to the **`teamsmith`** skill.

The single CLI is `team` and it lives in the daily skill — `bash <teamsmith>/scripts/team help` must work before you
start. Everything that follows the setup (dispatch, the pulse, review, merge) belongs to the daily skill; this one
only brings the project up.

## 1. Settle these with the user, in this order

1. **Preconditions.** A git repository with at least one commit, `tmux` in the room, and `team doctor` green
   (magic-context, OpenSpec, a JS runtime for the console, bash ≥ 4). Fix what doctor reports *before* writing
   config — a missing required dependency is a hard failure later, not a warning now.
2. **Identity and a minimal starting roster.** The tmux session name (`TEAM_SESSION` must match the session the PM
   lives in — the pulse and every notification are delivered inside it), the PM window name, the roster
   (`TEAM_AGENTS`), each agent's model (`TEAM_AGENT_MODELS`, or `TEAM_DEFAULT_MODEL` for all of them) and
   `TEAM_MODEL_LIMITS` when a provider quota is tight. **Start the roster minimal — one `dev` plus one `verify` is
   plenty**; `team add-agent <name>` adds more at any time, so the roster grows and shrinks with the work actually
   on the board rather than with a guess made today. (A PM-only start is legal too — `team doctor` only warns;
   dispatch is what refuses when there is no agent to dispatch to.)
3. **Gates, install command, VCS mode, patrol rhythm.** `TEAM_GATES` is the command that decides pass/fail during
   every verification (it must run from a clean checkout of a task branch); `TEAM_INSTALL_CMD` runs after a worktree
   is created; `TEAM_VCS` is a label for the wording (`local` = no forge, the PM squash-merges locally);
   `TEAM_PULSE_INTERVAL` is the patrol rhythm (default 15 minutes).
4. **Pi version and installed plugins.** Check Pi against the floor `README.md` states (Pi ≥ 0.76.0 — the
   `--session-id` criterion `team doctor`'s `pi` row fails on), then let `team doctor` report the plugins this
   project already has (`已装插件 packages`: the names, and whether each is project- or user-level). That row is
   information only: **teamsmith never asks the user to install a third-party plugin** — the team's own background
   lane ships with the skill (`team-bg`), and the only package worth recommending is a teamsmith requirement such as
   magic-context, which `doctor` already checks. A long task can also always fall back to a
   background tmux window plus `team notify`; both lanes are in `references/troubleshooting.md` §17 of the daily skill.
5. **The project's own documents** — the PM writes these, the tool does not: `docs/team/ROADMAP.md` (the goal,
   milestones with **executable** exit criteria, and explicit non-goals), `docs/team/OWNERSHIP.md` (which directory
   belongs to which agent; everything unlisted belongs to the PM), and the project-specific red lines in
   `AGENTS.md` (the protocol section itself is injected automatically).
6. **Then run it.** Show the plan first — it writes nothing:

   ```bash
   bash <teamsmith>/scripts/team bootstrap --print      # the plan: detect / config / docs / worktrees / pulse
   bash <teamsmith>/scripts/team bootstrap [--agents "dev verify"]
   bash <teamsmith>/scripts/team doctor                  # re-check after bootstrap
   openspec init --tools pi                              # required dependency: spec root + the five phase commands
   ```

   `bootstrap` is idempotent (a rerun fills in what is missing and leaves the rest alone) and it **prints** the
   `git worktree add` command for each agent — git stays with the PM (`--create-worktrees` delegates creation).
   The command's own behaviour is in `references/bootstrap.md`; a prompt you can hand to a new project's PM is
   `templates/bootstrap-prompt.md.tmpl`.
7. **The first task.** `team task T1.1 --title "…" --agent dev` → edit the brief until it is self-contained →
   `team dispatch dev T1.1 docs/team/tasks/T1.1-*.md`. From here the daily loop takes over.

## 2. Handoff

Day-to-day operation lives in the **`teamsmith`** skill: the PM loop, dispatch, independent verification, merging,
the pulse, updates and the troubleshooting guide are all there — read `skills/teamsmith/SKILL.md` and follow it.
The three commands that answer "what now?": `team digest` (pending work), `team pulse status` (patrol and PM
liveness), `team doctor` (environment).

The handover itself is three steps, and the middle one is the one people skip:

1. **Bootstrap.** `bash <teamsmith>/scripts/team bootstrap [--agents "dev verify"]` — it prints the plan first
   with `--print`, and a rerun is idempotent.
2. **Leave the room — or prove you are the PM.** `team up` starts the PM in this project's tmux session, and the
   PM is a *different* conversation from this one. Exit this session once bootstrap is done (keep it only if this
   session already lives in the PM window).
3. **Start the PM.** `bash <teamsmith>/scripts/team up [--fresh-pm]`. By default `up` continues **the last
   conversation in this directory** (`pi -c`) — which is *this init conversation*, so the PM wakes up with the
   init history. Add `--fresh-pm` to start the PM on a clean conversation instead (the old session file stays in
   history as the kickoff record); it wins over `TEAM_PM_SESSION_ID` / `TEAM_PM_RESUME_ARGS` for that one launch
   and is not written into the config. `team up --print` shows the decision and the exact command.

   If step 3 prints `检测到同目录 … 还有 … 活着的 … 会话`, a session started in this directory is still running:
   exit it first, or rerun with `--fresh-pm` — continuing one session from two processes at once would have both
   write the same session file.
