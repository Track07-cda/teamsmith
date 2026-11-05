---
name: teamsmith
description: teamsmith gives one agent real ownership of a project — it plans, writes self-contained task briefs, dispatches worker agents into their own tmux windows and git worktrees, verifies their work on an independent checkout, merges, and keeps an auditable ledger (BOARD/reviews/threads/DECISIONS). A pulse window (the periodic patrol) wakes the owner only when there is pending work, and the owner can deliberately stand down. Works with Pi; the launch/notify seam is an internal seam (frozen) reserved for a possible future non-Pi adapter, with no compatibility promise. Use when the user wants an agent to own a project end to end, dispatch tasks to worker agents, run agents in parallel in tmux with git worktree isolation, act as a PM/orchestrator over other agents, review an agent's work independently, run the patrol (`pulse`) as a tmux window, wake the PM only when there is pending work, or resume and coordinate a multi-agent project. To start a new project, use the teamsmith-init skill.
license: MIT
metadata:
  version: "0.4.4"
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
   review(independent checkout, run gates) ──▶  reports/<ID>-<a>.md  (local branch; remote on the PM's route)
   merge / close   ──────────────────▶  BOARD → done
```

## Starting a new project: use the `teamsmith-init` skill

Initialization lives in its own skill: read **`teamsmith-init`**'s SKILL.md for the install, the ordered questions to
settle with the user, `bash <teamsmith>/scripts/team bootstrap` and the handoff back here. Everything below is the
daily loop, which starts once the project is up.

## Name and compatibility (former name: pi-team)

Renamed from **`pi-team`** in v1.13.0; the contracts did not move (command `team`, `.pi/team/config.sh`, `TEAM_*`,
`docs/team/**`). The `skills/pi-team` alias is **gone**, so a hard-coded old path must become `skills/teamsmith`; an
`AGENTS.md` carrying the legacy `<!-- pi-team:begin -->` marker is converted in place by an **explicit `team init`**
(an existing valid config's `team bootstrap` does not refresh it). Renames, removed commands, dependency changes and
the upgrade recipe: [references/migration.md](references/migration.md) §§1b–4/6.

## Command table

| Goal | Command |
|---|---|
| Init / self-check | `team init [--session s] [--agents "a b"] [--vcs local\|remote] --task-models '<category=provider/model …>' --pm-model '<provider/model>' [--copy\|--no-skills]` (fresh projects must pass both model inputs; installs both skills into the project's `.pi/skills/`), `team doctor` (reports that install, warns on drift) |
| Observe | `team roster` (windows/branch/dirty/ahead), `team status [ID]`, `team ps` (capacity + model limits + PM/pulse liveness), `team digest` (PM's pending work) |
| Inbox | `team inbox [agent] [--ack] [--all]` |
| Key replies | **The outlet for replies written for the user** (a landed milestone, a ruling, a conclusion, an answer, a status or progress report, a decision you ask the user for, a delivery or verification summary — however short, and never held back because it reads like process rather than like a conclusion): write the complete reply — the substance the user needs to read, not a play-by-play — in the normal answer and end it with the final control line `[[team-reply]]` (or `[[team-reply:<short title>]]` for a title you choose); the directed PM extension publishes that message's sanitized body to the reply page, and your answer goes out with only that line removed. No temp file or heredoc, and no post-then-repeat: `team reply post --from <seat> --title "<short>" --stdin` is the **manual** publication, backfill and recovery entry only, and an unmarked answer is never published by inference. A batch of user-facing replies may be one reply. A reply written to the patrol, to another seat or to another project's PM, and a tool receipt, are not for the user and stay out. Distinct from the internal channels: `say`/`notify` carry one-line coordination to a seat or the PM, not the reply itself. A saved receipt means project-local durable publication only — never user delivery, approval, read status or a refreshed console. `team reply list [--before <no>] [--json]`, `team reply show <no> [--json\|--raw]` (readers are observation-only: no mkdir, no writes, no lock; `--raw` exports the original bytes and refuses a TTY). The console's page 5 shows the latest reply plus the numbered history. See `references/protocol.md` §4b |
| Document contracts | `team task <ID> --title ... --agent a`, `team board add\|assign\|set\|ls`, `team change status <id> [--json]` (readiness view: tasks/evidence, declared vs touched delta files, blockers; exit 0 iff every mapped task is finished), `team thread <a> "..." --from pm --re <ID>`, `team report <ID> <a>` |
| Dispatch | `team add-agent <a> [--register] [--create] [--no-install] [--print]`, `team dispatch <a> <ID> <taskfile> [--model m] [--branch <name>] [--fresh] [--allow-overflow] [--force] [--print]` (a new dispatch selects the brief's `category:` model from `TEAM_TASK_MODELS` unless `--model` overrides; same-task recovery keeps the committed model/SID; all pre-launch guards are judged in **one pass**: one refusal lists every blocker, each with a paste-able `修法：<command>` or `改行：<exact line>` and a final count line; `--force` overrides only the guards that carry an override, printed as a warning and logged after a real launch) |
| Collaborate | `team say <a> "<one-line message>" [--no-verify]` (prefers a live inbox watcher: durable inbox + wake spool, zero keys; with no usable watcher it makes one audited immediate attempt typed straight into the window, even over a draft — an attempt, not a model receipt — and falls back to the inbox when the agent is not running), `team notify <a> "<one line>" [--from <sender>]` (agent → PM; the sender comes from the runtime directory — an unresolved sender is refused, never recorded as `pm`) |
| Draft / deferred delivery | `team draft [pm]` opens an editor window on `state/draft-pm.md` (nothing automated ever types into it; save+quit enqueues through the guarded path and prints the ack there), `team draft send [<file>] [--now]` (headless form), `team outbox [list]` (what is waiting, with `held` reasons), `team outbox flush [--now]`, `team outbox drop <n\|all>`. Protected senders (notify knocks, wake lines, meeting knocks, ordinary `draft send`, ordinary queued pane delivery) refuse to type into an input box that already holds a draft: the message is queued in `state/outbox/` and reported as `queued`. Default `team say` is the named exception: watch first, otherwise one audited immediate attempt even over a draft (`state/outbox/forced.log`), never a receipt; a `geometry-untrusted` read (the supported Pi layout cannot be established) or three trusted-empty drains with no progress (`queue-stalled`) hold the entry durably with its reason and **exit non-zero**, never promising an automatic delivery. `draft send --now` / `outbox flush --now` remain the audited human overrides that type anyway (`state/outbox/forced.log`). See `references/troubleshooting.md` §3 |
| Long gate (background job) | **tool calls in the session** (not `team` subcommands): `team_bg_run` starts a detached job (id + pid at once, `state/bg/<id>.log`), `team_bg_wait <id>` harvests it (exit code + log tail inline). One merged wake-up per finished batch, silence once harvested, one `settled-with-unharvested=<n>` line per turn end in `state/bg.log`. Injected on both built-in Pi paths; a custom template opts in with `{bg_ext}`. The lane's records are readable and stoppable from the CLI: `team bg list` (one row per record, signals nothing), `team bg stop <id>` (signals only the recorded job — the `(pid, start-time)` pair is the identity, a reused pid is refused). Inside a window `pkill`/`killall` are the signal gate and refuse every name/pattern selection with exit 64. See `references/workflows.md` §E2 |
| Verify | `team review <ID> --dir <PM-prepared independent checkout> [--no-gates] [--strong] [--allow-unresolved-branch]` → `reviews/<ID>.md` (runs gates + writes evidence; refuses a dirty or `.gitignore`d checkout / an unresolvable `--branch` unless the matching `TEAM_REVIEW_ALLOW_*` override is used and recorded; `--strong` structurally checks flip evidence + a path to an independent package) |
| Wrap up | `team close <ID> [--keep-window]` (BOARD/state/window only, never git), `team teardown --agent a [--purge] [--register]` (explicit cleanup; `--register` removes the seat from the roster through the audited writer first) |
| Bootstrap | `team bootstrap [--agents "dev verify"] --task-models '<map>' --pm-model '<model>' [--print]` (recommended; both model inputs are required on a fresh project, a valid policy is kept on re-entry, a legacy config is refused before any side effect and points at `team config upgrade-models`), `team init`, `team doctor` |
| Patrol (pulse) | `team pulse up\|down\|restart\|status\|logs` (a `pulse` window in the same session runs the monitor + periodic patrol; single backend). Renamed from `watchdog` in v1.36.0: `team watchdog …`, `watchdog-status`, `install-watchdog`, `uninstall-watchdog` still work as aliases until v2.0.0 (they print a one-line deprecation notice first). `team watch [--once]` (foreground patrol) |
| Monitor | `team monitor [--once] [--activity]` (**serves the current tmux session only**: who is running / tasks / pending / capacity; `--activity` adds per-agent activity streams, off by default), `team panel` reuses it. The TUI's own preferences live in `state/panel.conf` (language, page, activity, mouse, density, theme) — runtime state, not project config, and `--print`/`--json` never read it |
| Project settings | `team config list [--json]` / `team config set <KEY> <VALUE> [--dry-run] [--fingerprint <sha256>] [--actor <name>] [--allow-danger]` / `team config log [N]` / `team config set-task-model <category> <model>` / `team config upgrade-models --task-models '<map>' --pm-model '<model>' [--dry-run\|--yes]`: the only writer of `.pi/team/config.sh` (comment/order preserving, single-quote form, value validation, danger list, sha256 CAS, one audit line per attempt in `state/config.log`). Model policy is the task-category map plus the independent PM model; the retired seat front doors (`set-agent-model`, `add-agent --model`) refuse and point here. The console's project-settings view (settings overlay → `项目设置`) lists every key with its effect class (`apply`/`restart`/`refuse`) and edits through this command; see `references/config.md` §5 |
| PM/agent lifecycle | `team up [--agents]` (recover the PM), `team resume` (PM's tool: continue stopped agents), `team standby on\|off` (PM deliberately stands down) |
| Cross-project meetings | `team meeting open/say/read/list/inbox/propose/agree/close` (PM-to-PM peer exchange: interface work, advice, problem reports; **not a command channel** — consensus needs both sides) |
| Updates | `team mark-loaded` (record the version at session start), `team version --check` (should I reload?), `team changelog [--since X]`, `team reload` |
| Diagnostics | `team paths` (resolved paths/session), `team smoke` (end-to-end self-test; `TEAM_SMOKE_FAST=1 team smoke` = **fast mode**, pure-logic sections only, ~10s, skipped process sections print `SKIP (FAST mode)`; the **full** run is for delivery/review and queues on the gate lock — `TEAM_SMOKE_LOCK` / `TEAM_SMOKE_LOCK_WAIT`, the mutex is a pair (published `<lock>` + dot-prefixed companion `<lock>.machine`, the holder recorded in `<companion>.holder`; neither file is ever unlinked, and losing the companion mid-run stops the run loudly), and `team review` takes the same pair before its timeout so the record's `queued`/`ran` are separate; the gate judges **correctness only** — its panel section keeps the time-independent knob check), `team version` |
| Performance | `team perf [--host \| --container]` (**separate from correctness**: it only measures and prints reference readings — interactive first frame, frame assembly, steady-state pane CPU — and names the environment it measured in; the exit codes are `0` (a reading was taken) and `3` (setup failed, or the perf lock was unavailable), with no thresholds, no premise factor and no `2`/`4`; its own lock `TEAM_PERF_LOCK`, never the gate lock; default = the pinned `ci/Containerfile` image, `--host` is labelled **not the reference**) |

The two gates answer different questions and are run at different times. **Correctness, on every change:**
`openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null` (the pair `team review` runs;
`team smoke` is the suite's front door). **Performance, separately and before a release:**
`bash skills/teamsmith/tests/perf.sh` (front door `team perf`; the reference environment is the pinned
`ci/Containerfile` image, `team perf --host` is explicitly *not* the reference). Its numbers are reference-only
and it has no verdict to give (exit `0` = a reading was taken, `3` = it could not measure), so a performance run
never changes a review verdict and never blocks a merge.

## Read the creed first, then the process
The PM's judgement standard lives in [references/philosophy.md](references/philosophy.md) (8 principles, each with
its failure mode): **deliverables must be independently verifiable · status is a promise · govern less to be
reliable · failure is information (a false green is worse than nothing) · repeated problems must become
mechanisms · everything must be handover-ready · long-termism and budget awareness · authority comes from
evidence and authorization, not from a title**. The loop below is just how those principles are implemented;
when they conflict, the creed wins and the process gets fixed.

## The PM loop (what you actually do)

> On start (or after a wake-up): `team digest` → `team inbox --ack` → `team resume --dry-run` → `team pulse status`.
> Bring the pulse up (`team pulse up`) when it is not running and you are not on standby; on standby, leave it alone.

1. **Model the work**: `team doctor`, `init` if needed; milestones in `ROADMAP.md`, and each task as a **self-contained
   brief** (context / deliverables / boundaries / copy-pasteable acceptance commands / report requirements) — a
   routine category usually runs a fast model that will not repair a vague request.
2. **Dispatch**: `team dispatch <a> <ID> <taskfile>`, after `team ps` (memory / model concurrency). The brief's
   `category:` picks a new dispatch's model; dispatching again to the same agent resumes its session, and `--fresh` is
   the explicit new-session route. The `change:`/`specs:`/`anchor:`/`deltas:` header is checked **before the window
   opens**, and a refusal names the offending line, the sibling and the fix.
3. **Wait for notifications**: when a worker's turn ends it appends to `inbox/<agent>.md` and knocks on your window.
   Do not poll agent screens; read `team inbox --ack` and `team digest`.
4. **Verify (never skip)**: `team review <ID> --dir <checkout>` runs the gates on a clean, independent checkout and
   writes `reviews/<ID>.md`. **A report is a claim; your verification is the evidence.** Re-read the diff against the
   brief, and read each finding for what it changed.
5. **Land the records, then merge**: `team review <ID> --pre-merge` first — it lists every `docs/team/**` file the
   task's worktree has **not committed**, and a squash carries only committed content (an untracked report dies with
   the reused worktree). Commit them yourself with the `Agent: <agent>` trailer, then run git yourself: squash-merge
   (with a PR: merge it, then `fetch && merge --ff-only`) → `team board set <ID> done` → `team close <ID>`. A late
   delivery after the merge goes through `team review <ID> --post-merge` before you take anything.
6. **Wrap up / report**: update `BOARD.md`, record decisions in `DECISIONS.md` with rationale and impact, and report to
   the user as "delivered + where the evidence is + next step".

Stop and ask the user only for **shared-state changes** (merge/push — the skill expresses authorization with `--yes`),
scope changes, and decisions that need their call (dispatch a research task first, then write `DECISIONS.md`). Exact
sequences: [references/workflows.md](references/workflows.md) §§B–F; patrol: protocol §8, workflows §§D/§I; the gate and
its queue: protocol §9b-2.

## Specs (OpenSpec)

What the product **must hold** lives in `openspec/specs/<capability>/spec.md` as requirements with falsifiable
scenarios; teamsmith keeps the **evidence** (briefs, reports, reviews, decisions) in `docs/team/`. Do not grow a second
spec system: a product promise goes into a spec, reasoning or guidance into `references/`.

A change runs as **five phases, one brief each, one owner each**: `opsx-explore` (an explorer) → `opsx-propose` (the
same explorer, planning only) → `opsx-apply` (a dev) → `opsx-verify` (a **different** agent) → `opsx-archive` (the
PM). Two hard rules: **an `apply` brief starts only after the PM's proposal review is ACCEPTED**
(`docs/team/reviews/<change>-proposal.md`), and **the PM never archives without independent verification and the
user's confirmation**. **One change : N tasks** — the change is the dispatch unit and the brief's header maps the task
to it (`team dispatch` refuses more than one `change:` id, a change-less brief without a resolvable anchor, two
unfinished tasks writing one delta file, and a verifier who authored the change; `team change status <id>` reports
readiness). `openspec validate --all --strict` is part of `TEAM_GATES`. Phase table, gates and the PM's ten-point review
checklist: [references/openspec.md](references/openspec.md); the four guards: protocol §5b.

## Getting skill updates (loaded text vs. the CLI)

`scripts/**` is read from disk on every call, so a CLI change needs nothing. Text is different: `/reload` refreshes the
skill list/descriptions and extensions, but **text already read into this conversation does not change** — re-read
`SKILL.md` after reloading (the extension sends a follow-up prompt that triggers that re-read). Extensions passed with
`-e` are startup arguments, so a changed `team-notify.ts`/`team-bg.ts` needs a process restart (`team up` for the PM,
`team resume <agent>` for a worker); `/team` is installed in the project's `.pi/extensions/` and follows `/reload` (a
worker worktree has none). `team mark-loaded` once per session, `team version --check` to see whether the loaded version
is current, `team changelog` for history. Upgrade and reload steps:
[references/migration.md](references/migration.md) §6 step 4; why `-e` needs a restart: troubleshooting §22.

## git and forge: the PM uses the tools; the skill does not wrap them

The skill **does not run** and **does not print recipes for** git/forge operations — that would wrap tools that already
exist. The PM uses `git` and whatever forge tooling fits (`gh`, `glab`, `tea`, `curl`, the web UI) and decides the
route: it prepares the worktree and the independent review checkout, merges, and advances the protected branch only on
the user's authorization. Tokens stay in the project's token files (`TEAM_TOKEN_FILE` / `TEAM_GITLAB_TOKEN_FILE`) and
are injected only when the PM calls a real tool (`GH_TOKEN="$(< .gh-pat)" gh …`): never echoed, never logged, never
committed. Exact preparation, merge and wrap-up steps: [references/workflows.md](references/workflows.md) §F; landed
state: protocol §8e; the boundary: protocol §8h.

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
- **Never claim something passed without having run it.** Reports carry the real commands and output tails; the PM
  re-runs independently.
- **Mark the reply — publication is a standing duty.** Whenever the answer is written for the user — an answer, a status
  or progress report, a conclusion or a ruling, a delivery or verification summary, a decision you ask the user for,
  however short — write the complete reply as the normal answer and end it with the final control line `[[team-reply]]`
  (or `[[team-reply:<short title>]]`); the directed PM extension publishes the sanitized body and the answer goes out
  with only that line removed. A batch may be one reply; patrol/seat/other-project traffic and tool receipts stay out;
  a saved receipt is project-local publication, not user delivery, approval or read status. No temp file or heredoc, and
  no post-then-repeat: `team reply post --from <seat> --title "<short>" --stdin` is the manual publication, backfill
  and recovery entry only. `references/protocol.md` §4b.
- Agents only touch directories they own (`OWNERSHIP.md`); cross-directory needs → write `BLOCKED:` in the report.
- Agents must not push the protected branch, force-push, merge PR/MRs, or rebase/delete other people's branches.
- Tokens live in the project's token files and are injected by the PM when calling real tools: **never echoed, never
  written, never committed**.
- Operations that change shared state need the user's authorization (`--yes`); git/forge writes do not go through the
  skill — the PM executes them, and they need authorization too.
- One long-lived worktree per agent: **do not move it** (sessions are keyed by cwd). Default `TEAM_BRANCH_MODE=task`:
  one branch per task (`task/<ID>-<slug>`), the unit of verification, merge and rollback.
- **The pulse is a metronome, not a daemon**: it wakes you only when work is pending and never manages tmux layout,
  agents or quota — a stopped worker is pending work, not an automatic resume (`team resume` is your call). Nothing to
  do or a human needed: `team standby on --reason "…"` stands you down until a human runs `team standby off`.
  Mechanism and boundaries: protocol §8; patrol steps: workflows §§D/§I.
- **Four separate adoption gates** — changing the project's contract, launching a fresh PM, landing source on a shared
  branch/skill path, and adopting a shared source: preview the exact command and get authorization per operation.

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
| `handover` skill | This session has run long and is losing shape (no reasoning, answers from the transcript's surface, facts re-derived that disk already holds)? `skills/handover/SKILL.md`: land the state, write `docs/team/HANDOVER.md` (pointers only, ≤60 lines), then stand this session down so the document cannot go stale |
| `references/migration.md` | The project was set up with an older version (or with the former name `pi-team`): renames, removed commands, new required dependencies, behaviour changes, the upgrade recipe and rollback |
| `references/workflows.md` | End-to-end runbook: bootstrap, dispatch, verify, merge, patrol/pulse, scaling, blockers |
| `references/openspec.md` | The OpenSpec pipeline: five phases, their owners, the gate before each next phase, and the PM's proposal-review checklist |
| `references/troubleshooting.md` | Notifications not arriving, lost sessions, worktree conflicts, forge 403, dishonest reports |
| `templates/` | Copy when you need to hand-write a brief/report/board |
| `scripts/team`, `scripts/lib/*.sh` | When changing behaviour (use `team <cmd> --print` to see what it generates) |
| `tests/smoke.sh`, `tests/perf.sh`, `tests/skill-load.mjs` | To confirm the tooling works here: `team smoke` (end-to-end in a temp repo, never touches this project). **Fast mode**: `TEAM_SMOKE_FAST=1 team smoke` runs only sections that need no real tmux stage or agent process — good for day-to-day gates before dispatch/verification; it **does not cover** dispatch actually launching an agent, the non-Pi agent end-to-end segment, window/close behaviour, the pulse waking the PM, standby/monitor, real agent resume, cross-session guards, offline `say` delivery, or knock probing (those print `SKIP (FAST mode)`); run the full suite before changing those paths or cutting a release. The full run is the machine's **one** shared gate resource: it queues on `TEAM_SMOKE_LOCK` up to `TEAM_SMOKE_LOCK_WAIT`, and `team review` takes the same lock *before* its hard timeout (so the record's `queued`/`ran` are separate and a long queue is a loud `FAIL`, never a `TIMEOUT`). The **performance** readings live in `tests/perf.sh` (`team perf`), not in the correctness gate (there are no performance red lines left to run there — the suite prints reference readings, names the environment it measured in, and cannot fail a run): correctness on every change, one performance reading before a release |

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
  prints that the reading was not taken (exit `0`) instead of judging).
