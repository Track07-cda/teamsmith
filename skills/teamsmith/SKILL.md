---
name: teamsmith
description: teamsmith gives one agent real ownership of a project — it plans, writes self-contained task briefs, dispatches worker agents into their own tmux windows and git worktrees, verifies their work on an independent checkout, merges, and keeps an auditable ledger (BOARD/reviews/threads/DECISIONS). A watchdog window wakes the owner only when there is pending work, and the owner can deliberately stand down. Works with Pi today and is designed to adapt to any TUI agent. Use when the user wants an agent to own a project end to end, organize multiple agents into a team, dispatch tasks to worker agents, run agents in parallel in tmux with git worktree isolation, act as a PM/orchestrator over other agents, set up an agent collaboration protocol, review an agent's work independently, bootstrap this skill into a new project, run the watchdog as a tmux window, wake the PM only when there is pending work, or resume and coordinate a multi-agent project.
license: MIT
metadata:
  version: "1.20.0"
---

# teamsmith · one agent that actually owns the project

teamsmith turns "one PM session + several worker agents" into a one-command setup: the PM writes task briefs and
dispatches them, workers implement in parallel inside their own worktrees, the PM verifies on an independent
checkout, then merges. **You usually are that PM**: when the user asks to "set up a team / dispatch tasks /
run agents in parallel", follow the PM loop below.

```
PM(this session, tmux <session>:pm)     worker agents(each in .worktrees/<agent>)
   task / dispatch ──────────────────▶  pi --session-id <s>-<a>  (interactive, watchable)
   digest / inbox  ◀── auto-notify on turn end ── extension/team-notify.ts → inbox + tmux wake-up
   review(independent checkout, run gates) ──▶  reports/<ID>-<a>.md + PR/MR
   merge / close   ──────────────────▶  BOARD → done
```

## New project: one command

```bash
cd <your project>                 # must be a git repo with at least one commit
bash <skill>/scripts/team bootstrap
```

`bootstrap` idempotently brings a project to "ready to dispatch": detect the current tmux session/window →
write `.pi/team/config.sh` + the `docs/team/` skeleton + the `AGENTS.md` protocol section + `.gitignore` →
**print** the `git worktree add` command for each agent (git stays with the PM; add `--create-worktrees` to have
it create them) → start the watchdog (a `watchdog` window in the same session) → print next steps.
See [references/bootstrap.md](references/bootstrap.md); you can also hand
`templates/bootstrap-prompt.md.tmpl` to a new project's PM and let it follow along.

## Name and compatibility (former name: pi-team)

- Renamed from **`pi-team`** to **`teamsmith`** in v1.13.0 (repo name included).
- **Contracts unchanged**: the command is still **`team`**; project config is still **`.pi/team/config.sh`**;
  env vars are still **`TEAM_*`**; team docs are still **`docs/team/**`**. Existing projects need no changes.
- The old path `skills/pi-team` is kept as a **compatibility symlink** to `skills/teamsmith`, so older
  absolute paths keep working.
- An `AGENTS.md` section marked `<!-- pi-team:begin -->` is migrated in place to the new marker by the next
  `team init`/`bootstrap`.
- Hot-reload command in Pi: `/teamsmith-reload` (the old `/pi-team-reload` stays registered as an alias).

## 30-second start

```bash
SKILL=~/.agents/skills/teamsmith                     # this skill's directory
TEAM="bash $SKILL/scripts/team"                      # single-entry CLI (`team help` lists everything)

cd <your project>                                    # must already be a git repo with commits
$TEAM init --session myproj --agents "dev verify"    # config + docs skeleton + AGENTS.md section
$TEAM doctor                                         # environment self-check

tmux new -s myproj -n pm                             # PM session (notifications are typed into this window)
$TEAM task T1.1 --title "first task" --agent dev      # generate a task brief
$EDITOR docs/team/tasks/T1.1-*.md                     # make it self-contained
$TEAM add-agent dev --create                          # --create builds the worktree (default prints the git command)
$TEAM dispatch dev T1.1 docs/team/tasks/T1.1-*.md
```

## Command table

| Goal | Command |
|---|---|
| Init / self-check | `team init [--session s] [--agents "a b"] [--vcs local\|remote]`, `team doctor` |
| Observe | `team roster` (windows/branch/dirty/ahead), `team status [ID]`, `team ps` (capacity + model limits + PM/watchdog liveness), `team digest` (PM's pending work) |
| Inbox | `team inbox [agent] [--ack] [--all]` |
| Document contracts | `team task <ID> --title ... --agent a`, `team board add\|set\|ls`, `team thread <a> "..." --from pm --re <ID>`, `team report <ID> <a>` |
| Dispatch | `team add-agent <a>`, `team dispatch <a> <ID> <taskfile> [--model m] [--fresh] [--print]` |
| Collaborate | `team say <a> "<one-line message>" [--no-verify]` (verifies delivery; falls back to the inbox when the agent is not running), `team notify <a> "<one line>"` (agent → PM) |
| Verify | `team review <ID> --dir <PM-prepared independent checkout> [--no-gates] [--strong] [--allow-unresolved-branch]` → `reviews/<ID>.md` (runs gates + writes evidence; refuses a dirty or `.gitignore`d checkout / an unresolvable `--branch` unless the matching `TEAM_REVIEW_ALLOW_*` override is used and recorded; `--strong` structurally checks flip evidence + a path to an independent package) |
| Wrap up | `team close <ID> [--keep-window]` (BOARD/state/window only, never git), `team teardown --agent a [--purge]` (explicit cleanup) |
| Bootstrap | `team bootstrap [--agents "dev verify"] [--print]` (recommended), `team init`, `team doctor` |
| Watchdog | `team watchdog up\|down\|restart\|status\|logs` (a `watchdog` window in the same session runs the monitor + periodic patrol; single backend), `team watch [--once]` (foreground patrol) |
| Monitor | `team monitor [--once] [--activity]` (**serves the current tmux session only**: who is running / tasks / pending / capacity; `--activity` adds per-agent activity streams, off by default), `team panel` reuses it |
| PM/agent lifecycle | `team up [--agents]` (recover the PM), `team resume` (PM's tool: continue stopped agents), `team standby on\|off` (PM deliberately stands down) |
| Cross-project meetings | `team meeting open/say/read/list/inbox/propose/agree/close` (PM-to-PM peer exchange: interface work, advice, problem reports; **not a command channel** — consensus needs both sides) |
| Updates | `team mark-loaded` (record the version at session start), `team version --check` (should I reload?), `team changelog [--since X]`, `team reload` |
| Diagnostics | `team paths` (resolved paths/session), `team smoke` (end-to-end self-test; `TEAM_SMOKE_FAST=1 team smoke` = **fast mode**, pure-logic sections only, ~10s, skipped process sections print `SKIP (FAST mode)`), `team version` |

## Read the creed first, then the process

The PM's judgement standard lives in [references/philosophy.md](references/philosophy.md) (8 principles, each with
its failure mode): **deliverables must be independently verifiable · status is a promise · govern less to be
reliable · failure is information (a false green is worse than nothing) · repeated problems must become
mechanisms · everything must be handover-ready · long-termism and budget awareness · authority comes from
evidence and authorization, not from a title**. The loop below is just how those principles are implemented;
when they conflict, the creed wins and the process gets fixed.

## The PM loop (what you actually do)

> On start (or after being woken): `team digest` → `team inbox --ack` → `team resume --dry-run` → `team watchdog-status`.
> Division of labour: **the watchdog is a metronome** ("is there work?" every 15 minutes by default): it wakes you
> only when there is pending work, stays silent otherwise, and does not require you to keep running. Starting,
> stopping and resuming agents, verification and merging are all yours.
> If you have nothing to push or need a human decision: `team standby on --reason "…"` to stand down
> (you will not be woken again until someone runs `team standby off`).

1. **Model the work**: `team doctor`, `init` if needed; break the user's request into milestones in `ROADMAP.md`
   and write each task as a **self-contained brief** (context / deliverables / boundaries / copy-pasteable
   acceptance commands / report requirements) — the default worker model is cheap and will not fix vague requests.
2. **Dispatch**: `team dispatch <a> <ID> <taskfile>`. Check `team ps` (memory / model concurrency) first.
   One long-lived worktree per agent; dispatching again to the same agent resumes its session, use `--fresh` for a
   new one.
3. **Wait for notifications**: when a worker's turn ends it appends to `inbox/<agent>.md` and knocks on your
   window. Do not poll agent screens; read `team inbox --ack` and `team digest`.
4. **Verify (never skip)**: `team review <ID> --dir <checkout>` — run the gates on a clean, independent checkout
   and write `reviews/<ID>.md`. **A report is a claim; your verification is the evidence.** Re-read the diff
   yourself against the brief.
5. **Pass** → run git/forge yourself: squash-merge (with a PR: `gh pr merge --squash --delete-branch <PR>` first,
   then `git fetch && git merge --ff-only`) → `team board set <ID> done` → `team close <ID>`.
   **Fail** → `team thread <a> "<failure evidence + expectation>"` + `team say <a> "<one-line instruction>"`.
6. **Wrap up / report**: update `BOARD.md`, record key decisions in `DECISIONS.md` (with rationale and impact),
   and report to the user as "delivered + where the evidence is + next step". Users want conclusions and risk,
   not a command log.

The only reasons to stop and ask the user: **shared-state changes** (merge/push — the skill expresses
authorization with `--yes`), scope changes, and decisions that need the user's call (dispatch a research task
first, then write `DECISIONS.md`).

## Specs (OpenSpec)

What the product **must hold** lives in `openspec/specs/<capability>/spec.md` as requirements with falsifiable
scenarios; teamsmith keeps the **evidence** (briefs, reports, reviews, decisions) in `docs/team/`. Do not grow a
second spec system: if a promise belongs to the product it goes into a spec, if it is reasoning or guidance it goes
into `references/`.

```bash
openspec list --specs                      # what the tool promises
openspec list                              # open changes (proposal → specs → tasks)
openspec validate --all --strict           # part of TEAM_GATES: an invalid spec fails the PM's review
openspec change show <change>              # what a change proposes
openspec archive -y <change>               # after the code landed and reviews/<ID>.md exists
```

Division of labour: a **change** is the requirement-level unit; a **task brief** is one work slice that names the
change id and the scenarios it must satisfy; the **report/review** pair is the evidence; **archive** closes the
change. A change too big for one brief becomes several tasks against the same change. Full details:
[references/openspec.md](references/openspec.md).

## Getting skill updates (three paths)

```bash
bash <skill>/scripts/team mark-loaded      # once per PM session: record the version this session loaded
bash <skill>/scripts/team version --check  # anytime: disk version vs session version + how to apply
bash <skill>/scripts/team changelog        # change history (--since v1.8.0 for recent only)
```

| Content | How it takes effect |
|---|---|
| `scripts/**` (CLI) | **Nothing to do**: every call reads from disk |
| `SKILL.md` / `references/**` / `templates/**` | Type **`/reload`** in Pi (or `/teamsmith-reload`, or let the model call the `reload_skills` tool). **Note**: `/reload` refreshes the skill list/descriptions (system prompt) and extensions; **text already read into the conversation history does not change**, so after reloading you must `read <skill>/SKILL.md` again (the extension sends a follow-up prompt that triggers that re-read) |
| `extension/team-notify.ts` | Same as above (`/reload` clears the extension cache and re-imports) |

Rationale: Pi's `/reload` rediscovers skills and rebuilds the system prompt, clears the extension module cache,
and re-resolves `--skill`/`-e` paths. When `team version --check` says your session is stale, follow the table
above; restarting the whole session is unnecessary (`-c` keeps history, but it is not needed).

## git and forge: the PM uses the tools; the skill does not wrap them

The skill **does not run** and **does not print recipes for** git/forge operations — that would be wrapping tools
that already exist. The PM uses `git` and whatever forge tooling fits:

```bash
# 1) Preparation (one long-lived worktree per agent)
git -C <root> worktree add -b <branch> <root>/.worktrees/<agent> <protected-branch>

# 2) Before work starts (dispatch only checks, never does it): worktree clean, not on the protected branch
git -C <root>/.worktrees/<agent> status --short

# 3) Verification (the PM prepares the checkout; the skill only runs gates and writes evidence)
git -C <root> worktree add --detach /tmp/review-<ID> <branch>
team review <ID> --dir /tmp/review-<ID> --strong

# 4) Merge (with a PR: merge the PR first, then fast-forward locally; without: squash locally)
gh pr merge --squash --delete-branch <PR>          # or glab mr merge, or a curl/HTTP call
git -C <root> fetch origin <protected-branch> && git -C <root> merge --ff-only FETCH_HEAD
# no PR: git -C <root> merge --squash <branch> && git -C <root> commit -m "<ID>: <title>"
git -C <root> push origin <protected-branch>

# 5) Wrap up: mark done only after the code really landed on the protected branch
team board set <ID> done
```

Forge-agnostic: GitHub via `gh`, GitLab via `glab`/`curl`, Gitea via `tea`, or the web UI — **the PM decides**;
the skill assumes nothing. Tokens stay in the project's token files (`TEAM_TOKEN_FILE` /
`TEAM_GITLAB_TOKEN_FILE`) and are injected only when the PM calls a tool: never echoed, never logged.

## Agent adapters (any TUI agent can be a worker)

Pi is the default worker; to use another CLI set four keys in `.pi/team/config.sh` (**all empty = Pi behaviour
byte-for-byte unchanged**):

| Key | Purpose | When empty |
|---|---|---|
| `TEAM_AGENT_CMD` | launch template for the agent CLI | built-in Pi command |
| `TEAM_AGENT_NOTIFY_CMD` | how a worker tells the PM its turn ended (`{summary_file}` — the summary is data, never interpolated) | Pi notify extension (inbox + knock) |
| `TEAM_AGENT_LOG_GLOB` | which logs `team monitor --activity` reads (`{agent}` = agent name) | Pi session files |
| `TEAM_AGENT_BIN` | binary for the window-readiness wait and existence checks | first word of `TEAM_AGENT_CMD`, else `TEAM_PI_BIN` |

- Template placeholders: `{cwd}` `{session_id}` `{model}` `{provider}` `{prompt_file}` `{prompt}` `{skill_dir}` `{notify_ext}` `{extra_args}`;
  an unknown `{...}` **fails the dispatch** with the supported list, and `team dispatch … --print` renders the command first.
- `team doctor` / `team paths` print the resolved adapter (`built-in (Pi)` or `custom: …`); only a *configured*
  adapter whose binary cannot be resolved fails.
- Contract, worked codex/opencode examples, a verification checklist and the unsupported list:
  see [references/agent-adapters.md](references/agent-adapters.md).

## Cross-project boundary (you may talk; you may not command)

- **Allowed**: discussing interfaces, advice with evidence, problem reports with reproduction, scheduling a joint
  test window, each side taking its own half.
- **Not allowed**: commanding another PM/agent, deciding on their behalf, impersonating a human, modifying their
  repo or state.
- Cross-project discussion goes through `team meeting` (PM to PM, files are the source of truth, optional knock);
  **workers do not attend** (they write `BLOCKED:` in their report and the PM takes it up). The mechanism has no
  `command` intent, and `--as-user` only works from a human terminal.
- Details: [references/meeting.md](references/meeting.md).

## Non-negotiable rules (verified during review)
- **Never claim something passed without having run it.** Reports must include commands and output tails; the PM
  re-runs independently.
- Agents only touch directories they own (`OWNERSHIP.md`); cross-directory needs → write `BLOCKED:` in the report.
- Agents must not push the protected branch, force-push, merge PR/MRs, or rebase/delete other people's branches.
- Tokens live in project token files (`TEAM_TOKEN_FILE` / `TEAM_GITLAB_TOKEN_FILE`, gitignored) and are injected by
  the PM when calling real tools (`GH_TOKEN="$(< .gh-pat)" gh …`); **never echoed, never written, never committed**.
- Operations that change shared state require `--yes` (meaning the user authorized it): `team meeting open/close/agree`, etc.
  git/forge writes do not go through the skill — the PM executes them (they are shared-state changes too, so they need authorization).
- One long-lived worktree per agent: **do not move it** (sessions are keyed by cwd; moving loses the agent's memory).
- Default `TEAM_BRANCH_MODE=task`: **one branch per task** (`task/<ID>-<slug>` cut from the protected branch); the task
  is the unit of verification, merge and rollback. Set `agent` for one long-lived branch per agent.
- **The watchdog is configured by the PM**: `team watchdog up` runs `team monitor` in a `watchdog` window **in the
  same tmux session** and patrols every 15 minutes (configurable) for pending work. `status` / `logs` / `down` are
  supported. There is exactly one backend (the tmux window) — no container, no systemd: fewer moving parts is more
  reliable, and if the tmux server dies the PM is gone too, so `team up` rebuilds both.
- **The PM does not need to run continuously**: you are only needed when there is work. Patrols default to every
  15 minutes (`TEAM_WATCH_INTERVAL=900`, 300–3600 recommended): pending work wakes you (if you are not running it
  starts you with `pi -c`), otherwise it does nothing. **When there is nothing to do or a human is needed,
  `team standby on --reason "…"` stands you down** — no further wake-ups; backlog still lands in
  `state/watchdog.log`, and a human runs `team standby off`. Patrols **do not manage tmux layout or agents**;
  resuming stopped agents is your call via `team resume`.

## Deeper reading (read on demand, not all at once)

| File | When |
|---|---|
| `references/philosophy.md` | **The PM creed**: judgement standards and their failure modes (read this first) |
| `references/protocol.md` | Why each rule exists (independent verification, wake-up loop, capacity floor, safety model) |
| `references/config.md` | Config keys, on-disk layout, env overrides (env beats config) |
| `references/memory.md` | What the PM's project memory is for, what belongs in it, what survives compaction/restart/`/reload`, and how to work without it |
| `references/agent-adapters.md` | To run workers with codex/opencode/any TUI agent: the contract, placeholder tables, worked examples, a verification checklist |
| `references/meeting.md` | Cross-project meetings: boundaries, shared area, commands, knocking, guards |
| `references/bootstrap.md` | New-project setup: what the one command does, what the PM does next |
| `references/workflows.md` | End-to-end runbook: bootstrap, dispatch, verify, merge, patrol/watchdog, scaling, blockers |
| `references/openspec.md` | Specs and the change workflow (OpenSpec): division of labour with the task ledger, the day-to-day commands, and what a PM does when a change is bigger than one task |
| `references/troubleshooting.md` | Notifications not arriving, lost sessions, worktree conflicts, forge 403, dishonest reports |
| `templates/` | Copy when you need to hand-write a brief/report/board |
| `scripts/team`, `scripts/lib/*.sh` | When changing behaviour (use `team <cmd> --print` to see what it generates) |
| `tests/smoke.sh`, `tests/skill-load.mjs` | To confirm the tooling works here: `team smoke` (end-to-end in a temp repo, never touches this project). **Fast mode**: `TEAM_SMOKE_FAST=1 team smoke` runs only sections that need no real tmux stage or agent process — good for day-to-day gates before dispatch/verification; it **does not cover** dispatch actually launching an agent, the non-Pi agent end-to-end segment, window/close behaviour, the watchdog waking the PM, standby/monitor, real agent resume, cross-session guards, offline `say` delivery, or knock probing (those print `SKIP (FAST mode)`); run the full suite before changing those paths or cutting a release |

## Requirements

**Hard dependencies**: `bash` ≥ 4, `git` (≥ 2.31, uses `--path-format=absolute`), `tmux`, an agent CLI
(the built-in Pi needs `--session-id`/`-e`/`--skill`), **magic-context** (the PM's cross-session memory:
`@cortexkit/pi-magic-context`) and **OpenSpec** (the spec layer: why a change happens and what it changes).
`team doctor` checks all of them and fails when one is missing, `dispatch` warns in one line without blocking, and
`bootstrap` prints the exact fix. No jq/python/node dependency.
> Odd environments can downgrade the two tooling dependencies explicitly — `TEAM_REQUIRE_MAGIC_CONTEXT=0` /
> `TEAM_REQUIRE_OPENSPEC=0` make `doctor` warn instead of failing; the keys, the spec dir and the CLI resolution
> (`TEAM_OPENSPEC_BIN`, `TEAM_SPEC_DIR`) are in [references/config.md](references/config.md).
> When only the *workers* move to another CLI: with `TEAM_AGENT_CMD` set, workers no longer need `pi`
> (`team doctor` judges by the configured adapter) — but **the PM side still runs Pi** (`pi -c` restarts,
> the PM prompt, `extension/team-notify.ts`), and the watchdog only wakes the PM. See
> [references/agent-adapters.md](references/agent-adapters.md).

- **No forge dependency**: the skill never probes or calls `gh`/`glab`/`tea` and never reads tokens; opening a
  PR/MR is the PM's job via `git` plus `curl`/any CLI/web UI (`TEAM_VCS` is only a wording label).
- **No container dependency**: the watchdog is a `watchdog` window in the same tmux session (`team watchdog up`).
- What to remember, what belongs on disk instead, and what happens when the memory dependency is missing:
  [references/memory.md](references/memory.md).
- Optional helpers: `timeout` (hard timeout for gates; degrades with a warning), `lsof` (needed only where
  `/proc` is unavailable).
