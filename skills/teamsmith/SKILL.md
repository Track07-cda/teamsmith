---
name: teamsmith
description: teamsmith gives one agent real ownership of a project — it plans, writes self-contained task briefs, dispatches worker agents into their own tmux windows and git worktrees, verifies their work on an independent checkout, merges, and keeps an auditable ledger (BOARD/reviews/threads/DECISIONS). A pulse window (the periodic patrol) wakes the owner only when there is pending work, and the owner can deliberately stand down. Works with Pi; the launch/notify seam is an internal seam (frozen) reserved for a possible future non-Pi adapter, with no compatibility promise. Use when the user wants an agent to own a project end to end, dispatch tasks to worker agents, run agents in parallel in tmux with git worktree isolation, act as a PM/orchestrator over other agents, review an agent's work independently, run the patrol (`pulse`) as a tmux window, wake the PM only when there is pending work, or resume and coordinate a multi-agent project. To start a new project, use the teamsmith-init skill.
license: MIT
metadata:
  version: "1.42.0"
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
   long gate: team_bg_run → turn ends → woken once → team_bg_wait   (extension/team-bg.ts, both sides)
   review(independent checkout, run gates) ──▶  reports/<ID>-<a>.md + PR/MR
   merge / close   ──────────────────▶  BOARD → done
```

## Starting a new project: use the `teamsmith-init` skill

Initialization lives in its own skill: load the **`teamsmith-init`** skill and read its SKILL.md — install the CLI
(`npm install -g teamsmith`) and run `team init`, which writes the config, the `docs/team/` skeleton and both skills
into the project's **`.pi/skills/`** — then the ordered questions to settle with the user,
`bash <teamsmith>/scripts/team bootstrap`, and the handoff back here. A machine-global install (`pi install …`,
`~/.agents/skills` via `install.sh`, or a settings `skills` entry) is the alternative route to the same skill;
everything below is the daily loop, which starts once the project is up.

## Name and compatibility (former name: pi-team)

- Renamed from **`pi-team`** to **`teamsmith`** in v1.13.0 (repo name included).
- **Contracts unchanged**: the command is still **`team`**; project config is still **`.pi/team/config.sh`**;
  env vars are still **`TEAM_*`**; team docs are still **`docs/team/**`**. Existing projects need no changes.
- The old path `skills/pi-team` **no longer exists**: the compatibility symlink was removed (M22, the alias period
  ended early by the user's call). A project or `settings.json` that hard-codes the old absolute path must change it
  to `skills/teamsmith` (or to the installed `~/.agents/skills/teamsmith`) — see `references/migration.md` §2.
- An `AGENTS.md` section marked `<!-- pi-team:begin -->` is migrated in place to the new marker by the next
  `team init`/`bootstrap`.
- Hot-reload command in Pi: `/teamsmith-reload` (the old `/pi-team-reload` stays registered as an alias — the
  alias is a **command name**, unrelated to the removed path).

## Command table

| Goal | Command |
|---|---|
| Init / self-check | `team init [--session s] [--agents "a b"] [--vcs local\|remote] [--copy\|--no-skills]` (installs both skills into the project's `.pi/skills/`; `--copy` for an ephemeral source, `--no-skills` to skip), `team doctor` (reports that install, warns on drift) |
| Observe | `team roster` (windows/branch/dirty/ahead), `team status [ID]`, `team ps` (capacity + model limits + PM/pulse liveness), `team digest` (PM's pending work) |
| Inbox | `team inbox [agent] [--ack] [--all]` |
| Document contracts | `team task <ID> --title ... --agent a`, `team board add\|assign\|set\|ls`, `team change status <id> [--json]` (readiness view: tasks/evidence, declared vs touched delta files, blockers; exit 0 iff every mapped task is finished), `team thread <a> "..." --from pm --re <ID>`, `team report <ID> <a>` |
| Dispatch | `team add-agent <a> [--register] [--model m] [--create] [--no-install] [--print]`, `team dispatch <a> <ID> <taskfile> [--model m] [--branch <name>] [--fresh] [--allow-overflow] [--force] [--print]` (all pre-launch guards are judged in **one pass**: one refusal lists every blocker, each with a paste-able `修法：<command>` or `改行：<exact line>` and a final count line; `--force` overrides only the guards that carry an override, printed as a warning and logged after a real launch) |
| Collaborate | `team say <a> "<one-line message>" [--no-verify]` (verifies delivery; falls back to the inbox when the agent is not running), `team notify <a> "<one line>" [--from <sender>]` (agent → PM; the sender comes from the runtime directory — an unresolved sender is refused, never recorded as `pm`) |
| Draft / deferred delivery | `team draft [pm]` opens an editor window on `state/draft-pm.md` (nothing automated ever types into it; save+quit enqueues through the guarded path and prints the ack there), `team draft send [<file>] [--now]` (headless form), `team outbox [list]` (what is waiting, with `held` reasons), `team outbox flush [--now]`, `team outbox drop <n\|all>`. Every automated sender refuses to type into an input box that already holds a draft: the message is queued in `state/outbox/` and reported as `queued`; a `geometry-untrusted` read (the supported Pi layout cannot be established) or three trusted-empty drains with no progress (`queue-stalled`) hold the entry durably with its reason and **exit non-zero**, never promising an automatic delivery. `--now` is the audited override that types anyway (`state/outbox/forced.log`). See `references/troubleshooting.md` §3 |
| Long gate (background job) | **tool calls in the session** (not `team` subcommands): `team_bg_run` starts a detached job (id + pid at once, `state/bg/<id>.log`), `team_bg_wait <id>` harvests it (exit code + log tail inline). One merged wake-up per finished batch, silence once harvested, one `settled-with-unharvested=<n>` line per turn end in `state/bg.log`. Injected on both built-in Pi paths; a custom template opts in with `{bg_ext}`. See `references/workflows.md` §E2 |
| Verify | `team review <ID> --dir <PM-prepared independent checkout> [--no-gates] [--strong] [--allow-unresolved-branch]` → `reviews/<ID>.md` (runs gates + writes evidence; refuses a dirty or `.gitignore`d checkout / an unresolvable `--branch` unless the matching `TEAM_REVIEW_ALLOW_*` override is used and recorded; `--strong` structurally checks flip evidence + a path to an independent package) |
| Wrap up | `team close <ID> [--keep-window]` (BOARD/state/window only, never git), `team teardown --agent a [--purge] [--register]` (explicit cleanup; `--register` removes the seat from the roster through the audited writer first) |
| Bootstrap | `team bootstrap [--agents "dev verify"] [--print]` (recommended), `team init`, `team doctor` |
| Patrol (pulse) | `team pulse up\|down\|restart\|status\|logs` (a `pulse` window in the same session runs the monitor + periodic patrol; single backend). Renamed from `watchdog` in v1.36.0: `team watchdog …`, `watchdog-status`, `install-watchdog`, `uninstall-watchdog` still work as aliases until v2.0.0 (they print a one-line deprecation notice first). `team watch [--once]` (foreground patrol) |
| Monitor | `team monitor [--once] [--activity]` (**serves the current tmux session only**: who is running / tasks / pending / capacity; `--activity` adds per-agent activity streams, off by default), `team panel` reuses it. The TUI's own preferences live in `state/panel.conf` (language, page, activity, mouse, density, theme) — runtime state, not project config, and `--print`/`--json` never read it |
| Project settings | `team config list [--json]` / `team config set <KEY> <VALUE> [--dry-run] [--fingerprint <sha256>] [--actor <name>] [--allow-danger]` / `team config log [N]` / `team config set-agent-model <seat> <model\|->`: the only writer of `.pi/team/config.sh` (comment/order preserving, single-quote form, value validation, danger list, sha256 CAS, one audit line per attempt in `state/config.log`). The console's project-settings view (settings overlay → `项目设置`) lists every key with its effect class (`apply`/`restart`/`refuse`) and edits through this command, seats included; see `references/config.md` §5 |
| PM/agent lifecycle | `team up [--agents]` (recover the PM), `team resume` (PM's tool: continue stopped agents), `team standby on\|off` (PM deliberately stands down) |
| Cross-project meetings | `team meeting open/say/read/list/inbox/propose/agree/close` (PM-to-PM peer exchange: interface work, advice, problem reports; **not a command channel** — consensus needs both sides) |
| Updates | `team mark-loaded` (record the version at session start), `team version --check` (should I reload?), `team changelog [--since X]`, `team reload` |
| Diagnostics | `team paths` (resolved paths/session), `team smoke` (end-to-end self-test; `TEAM_SMOKE_FAST=1 team smoke` = **fast mode**, pure-logic sections only, ~10s, skipped process sections print `SKIP (FAST mode)`; the **full** run is for delivery/review and queues on the gate lock — `TEAM_SMOKE_LOCK` / `TEAM_SMOKE_LOCK_WAIT`, holder in `<lock>.holder`, and `team review` takes the same lock before its timeout so the record's `queued`/`ran` are separate; the gate judges **correctness only** — its panel section keeps the time-independent knob check), `team version` |
| Performance | `team perf [--host \| --container]` (**separate from correctness**: the wall-clock/CPU red lines — interactive first frame, frame assembly, steady-state pane CPU — with the unchanged thresholds (2000 ms / 2000 ms / < 1 %), premise factors (`0.75` / `0.25`), medians, visible `SKIP` and exit codes `0`/`2`/`4`/`3`; its own lock `TEAM_PERF_LOCK`, never the gate lock; default = the pinned `ci/Containerfile` image, `--host` is labelled **not the reference**) |

The two gates answer different questions and are run at different times. **Correctness, on every change:**
`openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null` (the pair `team review` runs;
`team smoke` is the suite's front door). **Performance, separately and before a release:**
`bash skills/teamsmith/tests/perf.sh` (front door `team perf`; the reference environment is the pinned
`ci/Containerfile` image, `team perf --host` is explicitly *not* the reference). A red performance run never
changes a review verdict and never blocks a merge.

## Read the creed first, then the process
The PM's judgement standard lives in [references/philosophy.md](references/philosophy.md) (8 principles, each with
its failure mode): **deliverables must be independently verifiable · status is a promise · govern less to be
reliable · failure is information (a false green is worse than nothing) · repeated problems must become
mechanisms · everything must be handover-ready · long-termism and budget awareness · authority comes from
evidence and authorization, not from a title**. The loop below is just how those principles are implemented;
when they conflict, the creed wins and the process gets fixed.

## The PM loop (what you actually do)

> On start (or after being woken): `team digest` → `team inbox --ack` → `team resume --dry-run` → `team pulse status`.
> If the pulse is not running and you are not on standby, bringing it up (`team pulse up`) is part of your job; on standby, leave it alone.
> Division of labour: **the pulse is a metronome** ("is there work?" every 15 minutes by default): it wakes you
> only when there is pending work, stays silent otherwise, and does not require you to keep running. Starting,
> stopping and resuming agents, verification and merging are all yours.
> If you have nothing to push or need a human decision: `team standby on --reason "…"` to stand down
> (you will not be woken again until someone runs `team standby off`).

1. **Model the work**: `team doctor`, `init` if needed; break the user's request into milestones in `ROADMAP.md`
   and write each task as a **self-contained brief** (context / deliverables / boundaries / copy-pasteable
   acceptance commands / report requirements) — the default worker model is cheap and will not fix vague requests.
2. **Dispatch**: `team dispatch <a> <ID> <taskfile>`. Check `team ps` (memory / model concurrency) first.
   One long-lived worktree per agent; dispatching again to the same agent resumes its session, use `--fresh` for a
   new one. The brief's `change:`/`specs:`/`anchor:`/`deltas:` lines are checked **before the window opens**: one
   change id per task (no override), a change-less brief must declare a resolvable anchor, two unfinished tasks of
   one change cannot write the same delta file, and a verifier must not be an author of the change — the last three
   have `--force` + one audit line, the first does not. A refusal names the offending line, the sibling and the fix;
   `team change status <id>` shows the same facts read-only.
3. **Wait for notifications**: when a worker's turn ends it appends to `inbox/<agent>.md` and knocks on your
   window. Do not poll agent screens; read `team inbox --ack` and `team digest`.
4. **Verify (never skip)**: `team review <ID> --dir <checkout>` — run the gates on a clean, independent checkout
   and write `reviews/<ID>.md`. **A report is a claim; your verification is the evidence.** Re-read the diff
   yourself against the brief.
5. **Land the records, then merge** → `team review <ID> --pre-merge` lists every `docs/team/**` file the
   task's worktree has **not committed** and exits non-zero while any exist: `git merge --squash` carries only
   committed content, so an untracked report would silently stay behind and die with the reused worktree (D45 —
   the same shape happened five times in one day). Commit them yourself with the `Agent: <agent>` trailer (the
   tool never commits for you). Then run git/forge yourself: squash-merge (with a PR:
   `gh pr merge --squash --delete-branch <PR>` first, then `git fetch && git merge --ff-only`) →
   `team board set <ID> done` → `team close <ID>`.
   **If a late delivery arrives after the merge** (the author lands commits on the branch afterwards), run
   `team review <ID> --post-merge` before taking anything: records-only → take them with the printed
   `git checkout <branch> -- …`; code (anything outside `docs/team/**`) → it exits non-zero: re-merge and
   re-run the gates — the records alone are not enough.
   **Fail** → `team thread <a> "<failure evidence + expectation>"` + `team say <a> "<one-line instruction>"` (if the target's input box holds a draft the instruction is queued instead of typed — `team outbox list` shows it, and it is delivered once the box clears).
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

A change runs as **five phases, one brief each, one owner each**: `opsx-explore` (an explorer) → `opsx-propose` (the
same explorer, planning only) → `opsx-apply` (a dev) → `opsx-verify` (a **different** agent) → `opsx-archive` (the
PM). Two hard rules: **an `apply` brief starts only after the PM's proposal review is ACCEPTED**
(`docs/team/reviews/<change>-proposal.md`), and **the PM never archives without independent verification and the
user's confirmation**. **One change : N tasks** — the change is the dispatch unit and the brief's header maps the
task to it (`team dispatch` refuses more than one `change:` id, a change-less brief without an anchor, two
unfinished tasks writing one delta file, and a verifier who authored the change; `team change status <id>` reports
readiness and exits 0 only when every mapped task is finished). `openspec validate --all --strict` is part of
`TEAM_GATES`; the phase table, the gates and the PM's review checklist are in
[references/openspec.md](references/openspec.md), the four guards in [references/protocol.md](references/protocol.md) §5b.

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
| `extension/team-notify.ts`, `extension/team-bg.ts`, `extension/team-inbox-watch.ts` | **Restart the process** — the launch paths pass the extensions with `pi -e`, and `-e` modules are read at process start (`/reload` hot-reloads only extensions from Pi's auto-discovery locations, `~/.pi/agent/extensions/` and `.pi/extensions/`). PM: `team up`; worker: `team resume <agent>`. `team version --check` fingerprints them |

Rationale: Pi's `/reload` rediscovers skills, rebuilds the system prompt and re-imports extensions from its
auto-discovery locations; extensions passed with `-e` (which is how the team launch paths load them) are a
startup argument, so adding or changing one needs a process restart. When `team version --check` says your
session is stale, follow the table above.

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

# 3b) Pre-merge: the branch's worktree may hold records that were never committed (`merge --squash` carries
#     only committed content — an untracked report stays behind and dies with the reused worktree; D45)
team review <ID> --pre-merge       # non-zero + per-file fix command while <docs>/** is uncommitted; silent when clean

# 3c) Post-merge: the author may keep committing after the merge (`merge --squash` froze the branch at that
#     moment — P82's two record-only commits never reached main; D49)
team review <ID> --post-merge      # records → take them (checkout fix); code → non-zero: re-merge + re-run gates

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

## Agent adapters (Pi; the seam is internal and frozen)

Pi is the promised worker. The four keys below are an **internal seam (frozen)**: reserved for a possible future
non-Pi adapter, no compatibility promise, not a public extension point (the new-project questionnaire never asks
about them). They stay writable so the seam can be maintained and diagnosed; to use another CLI set them in
`.pi/team/config.sh` (**all empty = Pi behaviour byte-for-byte unchanged**):

| Key | Purpose | When empty |
|---|---|---|
| `TEAM_AGENT_CMD` | launch template for the agent CLI | built-in Pi command |
| `TEAM_AGENT_NOTIFY_CMD` | how a worker tells the PM its turn ended (`{summary_file}` — the summary is data, never interpolated) | Pi notify extension (inbox + knock) |
| `TEAM_AGENT_LOG_GLOB` | which logs `team monitor --activity` reads (`{agent}` = agent name) | Pi session files |
| `TEAM_AGENT_BIN` | binary for the window-readiness wait and existence checks | first word of `TEAM_AGENT_CMD`, else `TEAM_PI_BIN` |

- Template placeholders: `{cwd}` `{session_id}` `{model}` `{provider}` `{prompt_file}` `{prompt}` `{skill_dir}` `{notify_ext}` `{bg_ext}` `{extra_args}`;
  an unknown `{...}` **fails the dispatch** with the supported list, and `team dispatch … --print` renders the command first.
- team-bg: the team background lane (`team_bg_run` / `team_bg_wait` for long gates) is **not** an adapter feature —
  the built-in Pi paths load `extension/team-bg.ts` with `-e`, and a custom Pi-shaped template opts in with
  `{bg_ext}`; a CLI without a Pi extension API has no background lane (use a tmux window instead).
- `team doctor` / `team paths` print the resolved adapter (`built-in (Pi)` or `custom: …`); only a *configured*
  adapter whose binary cannot be resolved fails.
- Contract, the frozen seam's placeholder tables, worked codex/opencode examples (seam documentation, not a support promise), a verification checklist and the intentionally unsupported list:
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
- **The pulse is configured by the PM**: `team pulse up` runs `team monitor` in a `pulse` window **in the
  same tmux session** and patrols every 15 minutes (configurable) for pending work. `status` / `logs` / `down` are
  supported. There is exactly one backend (the tmux window) — no container, no systemd: fewer moving parts is more
  reliable, and if the tmux server dies the PM is gone too, so `team up` rebuilds both.
  The name: it was called `watchdog` until v1.36.0 — the old command names, the `watchdog` window name and the
  `TEAM_WATCH_*` variables keep working as aliases/fallbacks until v2.0.0 (`team pulse status` names every legacy
  variable still in effect; a still-running `watchdog` window is recognized as the backend and `team pulse restart`
  swaps it for a `pulse` window). The `state/watchdog.*` file names stay unchanged during the alias period —
  never run two patrols side by side.
- **The PM does not need to run continuously**: you are only needed when there is work. Patrols default to every
  15 minutes (`TEAM_PULSE_INTERVAL=900`, 300–3600 recommended): pending work wakes you (if you are not running it
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
| `references/agent-adapters.md` | The internal seam (frozen) for launch and notify: the contract, placeholder tables, worked codex/opencode examples, a verification checklist |
| `references/meeting.md` | Cross-project meetings: boundaries, shared area, commands, knocking, guards |
| `teamsmith-init` skill | New project? `skills/teamsmith-init/SKILL.md` is the entry point: the questions to settle, `team bootstrap`, then the handoff back to this skill |
| `references/migration.md` | The project was set up with an older version (or with the former name `pi-team`): renames, removed commands, new required dependencies, behaviour changes, the upgrade recipe and rollback |
| `references/workflows.md` | End-to-end runbook: bootstrap, dispatch, verify, merge, patrol/pulse, scaling, blockers |
| `references/openspec.md` | The OpenSpec pipeline: five phases, their owners, the gate before each next phase, and the PM's proposal-review checklist |
| `references/troubleshooting.md` | Notifications not arriving, lost sessions, worktree conflicts, forge 403, dishonest reports |
| `templates/` | Copy when you need to hand-write a brief/report/board |
| `scripts/team`, `scripts/lib/*.sh` | When changing behaviour (use `team <cmd> --print` to see what it generates) |
| `tests/smoke.sh`, `tests/perf.sh`, `tests/skill-load.mjs` | To confirm the tooling works here: `team smoke` (end-to-end in a temp repo, never touches this project). **Fast mode**: `TEAM_SMOKE_FAST=1 team smoke` runs only sections that need no real tmux stage or agent process — good for day-to-day gates before dispatch/verification; it **does not cover** dispatch actually launching an agent, the non-Pi agent end-to-end segment, window/close behaviour, the pulse waking the PM, standby/monitor, real agent resume, cross-session guards, offline `say` delivery, or knock probing (those print `SKIP (FAST mode)`); run the full suite before changing those paths or cutting a release. The full run is the machine's **one** shared gate resource: it queues on `TEAM_SMOKE_LOCK` up to `TEAM_SMOKE_LOCK_WAIT`, and `team review` takes the same lock *before* its hard timeout (so the record's `queued`/`ran` are separate and a long queue is a loud `FAIL`, never a `TIMEOUT`). The **performance** red lines live in `tests/perf.sh` (`team perf`), not in the correctness gate: correctness on every change, performance separately and before a release |

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
> the PM prompt, `extension/team-bg.ts`), and the pulse only wakes the PM. See
> [references/agent-adapters.md](references/agent-adapters.md).

- **No forge dependency**: the skill never probes or calls `gh`/`glab`/`tea` and never reads tokens; opening a
  PR/MR is the PM's job via `git` plus `curl`/any CLI/web UI (`TEAM_VCS` is only a wording label).
- **No container dependency**: the pulse is a `pulse` window in the same tmux session (`team pulse up`).
- What to remember, what belongs on disk instead, and what happens when the memory dependency is missing:
  [references/memory.md](references/memory.md).
- Optional helpers: `timeout` (hard timeout for gates; degrades with a warning), `lsof` (needed only where
  `/proc` is unavailable), `/usr/bin/time` (GNU time, not bash's `time` keyword: `tests/panel-cpu.sh` wraps the
  console with it to read the tree CPU figure — the gate image pins it, and where it is missing that fixture
  prints why and reports a visible SKIP (its own exit status) instead of judging, as does the `panel-cpu-premise`
  segment that drives it).
