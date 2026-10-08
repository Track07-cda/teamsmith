# E13 · Task-model routing impact exploration

task: E13
agent: verify
phase: explore
change: -
specs: dispatch#Model concurrency limits are enforced before dispatch
deltas: -
branch: task/E13-task-model-routing-explore
deps: -
budget: one focused work block; report a genuine blocker rather than widening scope

## Background

The user approved task-category model routing and a breaking replacement of the old seat-model configuration. The approved direction, model-use policy and authorization stop are recorded in `docs/team/DECISIONS.md`, D101. Read that entry in full; do not reopen its settled choices. This task is the focused technical exploration before a separate `opsx-propose` brief, not implementation and not a general model benchmark.

Teamsmith owns guidance, project policy and dispatch/resume orchestration. Pi owns inference, reasoning blocks, message conversion and provider/API compatibility. The user explicitly rejected moving Pi responsibilities into Teamsmith.

Run this exploration with the explicitly dispatched strong model in a fresh session. The existing tool does not implement the new routing policy yet; the PM is selecting that model manually for this planning task.

## Reading order

1. `AGENTS.md`, your newest `docs/team/threads/verify.md` entry, and this brief.
2. `docs/team/DECISIONS.md` D101 and `skills/teamsmith/references/openspec.md`.
3. Read the relevant capability specs before inspecting implementations: `dispatch`, `memory-and-deps`, `panel`, `pm-lifecycle`, `init-skill`, and `agent-adapters`. Include `boundary`, `capacity` and `verification` if the impact map reaches their contracts.
4. Inspect the project configuration schema/writer, dispatch/model argument rendering, resume and patrol recovery, PM launch, console settings, initialization templates and PM/worker guidance. Locate the real paths; do not assume the earlier source summary is still the entire impact surface.

This checkout may not contain machine-generated `/opsx-explore` commands. Use the exploration phase described in the teamsmith OpenSpec reference; the installed OpenSpec 1.8.0 exploration template is also at `$HOME/.bun/install/global/node_modules/@fission-ai/openspec/dist/core/templates/workflows/explore.js`. Missing generated commands do not justify installation or skipping the phase.

## Work and deliverables

Write `docs/team/reports/E13-verify.md`, containing:

- A concrete impact map (capability requirement titles, production paths, existing tests and fixture assumptions). Identify contracts that need MODIFIED or REMOVED deltas rather than duplicate new requirements. Cover configuration CLI and console settings, PM model independence, category selection, explicit overrides, concurrency, preview/source reporting, startup templates, guidance and recovery entry points.
- One proposal-ready recommendation within D101. Describe the smallest category vocabulary and initial mapping using existing configured models, a project-owned configuration shape, and a feasible apply/independent-verify split. Separate the PM's task-selection guidance from deterministic tool enforcement. Do not add a classifier model, automatic cross-model retries or a compatibility matrix.
- Evidence for current model and SID resolution: normal dispatch, an explicit model override, fresh dispatch, and same-task resume. Attempt bounded isolated reproductions of the reported override/fresh recovery defects using a recording agent/tmux stub, not live LLM calls. Cite exact commands, captured arguments and outputs. If a case is not reproduced, label it source-only rather than promoting it to an observed defect.
- Breaking-update consequences: every old seat/default-model reader and writer that would remain if only dispatch changed; how callers receive an actionable old-config error; whether the canonical config writer remains usable for a deliberate upgrade; how bootstrap and the local project configuration adopt the new structure without overwriting governance records. A migration path must not mean retaining the old routing semantics.
- A proposed acceptance strategy with existing command front doors, red/green cases and no-state-change refusals. Cover model-switch/new-session restrictions, exact model/SID recovery, configuration changes versus an already assigned task, manual and patrol resume, CLI/console effects, and preserved concurrency guards. This is a test plan, not a claim that the new behavior exists.
- Effort, material risks and any genuine decision still missing. Do not ask the user to reapprove breaking compatibility or the Pi boundary.

A report is evidence and recommendation, not a parallel specification system. Do not write a separate requirement catalogue or put formal promises in this brief/report in place of the future OpenSpec deltas.

## Boundaries and ownership

- The only versioned path you may write is `docs/team/reports/E13-verify.md`. Do not modify product scripts, schemas, tests, console code, templates, guides, project configuration, AGENTS, board, decisions, ownership or review records.
- Do not create an OpenSpec change or write proposal/design/delta/task artifacts yet. The PM reviews this report and dispatches a separate propose task to the same explorer after accepting the approach.
- Probe code and logs belong outside the public repository in `pm-skills-ledger/team/reports/E13-verify/`, resolved from the main checkout's parent using git's common directory, not from this worktree's parent. This exact evidence directory is temporarily authorized to you. Keep paths in the committed report relative and reproducible; do not commit probe bundles, session content, machine paths or private project material.
- Fixtures must have their own git repository, configuration and disposable state, recording tmux/agent stubs, input from `/dev/null`, and hard timeouts. Do not target real team windows or the default tmux socket. Use no name/pattern process termination, unscoped cleanup or real provider calls. Never read credentials or Pi session histories.
- Do not install or update Pi/OpenSpec, extensions, dependencies or shared skills. Do not touch other projects, services, remote state or meetings. No pushes, PR/MRs, merges or releases: this is a local-only planning task.
- Do not implement reasoning bridges, inspect/transform hidden thinking, rewrite Pi context, or build a model/API compatibility matrix. Ordinary Teamsmith-owned launch arguments and its own dispatch metadata are the boundary.
- A full smoke run is not required for this report-only task. Run the records-only commands below and your scoped probes, and state explicitly that smoke product sections and real-model quality were not tested.

## Acceptance (actually run and record outputs)

Run these from your worktree with a stable tree:

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/smoke.sh --paths docs/team/reports/E13-verify.md
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
```

Also run every bounded probe claimed in the report. Include commands and output summaries, distinguish measurements from proposed behavior, and identify unrun tests. `decision=NONE` is a report-path selection result, not a full-suite pass. The privacy scan uses the main checkout's ignored name list without printing its contents; if it returns 3, record the visible skipped leg as partial coverage, not a complete pass. Return codes 1, 2 and 4 are failures, not permitted skips.

Use small Conventional Commits containing E13 and an `Agent: verify` trailer. Commit the report and verify that the task branch is clean before finishing. Record your final commit and the external evidence location. Do not end with unharvested background jobs.

If genuinely blocked, append evidence to your own PARTIAL report and notify the PM. The dispatch template currently prints an incorrect self-recipient example: the correct command from your worktree is `bash skills/teamsmith/scripts/team notify pm "E13 (task-model routing impact exploration): <one-line blocker>"`. Do not notify `verify` or widen scope to fix that unrelated template defect.
