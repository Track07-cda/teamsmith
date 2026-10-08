# E14 · Task-model routing proposal

task: E14
agent: verify
phase: propose
category: analysis
change: task-model-routing
specs: dispatch, memory-and-deps, panel, agent-adapters, pm-lifecycle, init-skill, watchdog
deltas: dispatch, memory-and-deps, panel, agent-adapters, pm-lifecycle, init-skill, watchdog
branch: task/E14-task-model-routing-propose
deps: E13

## Accepted input and phase boundary

The user approved the direction in D101 and the PM accepted E13 (task-model routing impact exploration) in `docs/team/reviews/E13.md`, with refinements recorded in D102. Read the collected original report and the separate review in full. Settled breaking-compatibility, model-use and Pi-boundary decisions are not open questions.

You are the same explorer, now owning **proposal artifacts only**. Write the formal change and its task decomposition; do not edit implementation, canonical base specs, runtime configuration or shared installation. The current tool still selects models by the old rules. This planning task is manually dispatched as `openai-codex/gpt-6.1-sol:high` in a fresh session; the category header is a declaration, not evidence that automatic routing exists.

## Reading and workflow

1. `AGENTS.md`, your newest `docs/team/threads/verify.md` entry, this brief, `docs/team/OWNERSHIP.md`.
2. `docs/team/DECISIONS.md` D101/D102, `docs/team/reports/E13-verify.md`, and `docs/team/reviews/E13.md`.
3. `skills/teamsmith/references/openspec.md`, the current base specs behind the impact map, and current relevant source/test entry points.
4. The actual `/opsx-propose` instructions if generated here. If absent, read the installed 1.8.0 workflow at `$HOME/.bun/install/global/node_modules/@fission-ai/openspec/dist/core/templates/workflows/propose.js` and its store-selection cross-reference. Do not generate commands by reinstalling or running init.

Use the existing Bun/OpenSpec CLI, without installation:

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" context --json
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" new change task-model-routing
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" status --change task-model-routing --json
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" instructions proposal --change task-model-routing --json
# Obtain specs/design/tasks instructions as each becomes ready, following their dependency order.
```

Resolve context before creating the change and verify that its planning root and artifact paths are inside this allocated worktree. Do not silently write a global/default store or another checkout. If the CLI selects a different root, record BLOCKED and notify the PM rather than changing shared store settings. The repository currently has no `openspec/config.yaml`; retain the existing/default spec-driven schema rather than inventing a project-wide config.

Produce the complete transitive planning artifact set, including design because the configuration/recovery transaction decisions are material. Re-read dependency artifacts from disk. Stop after planning even if the generated workflow mentions apply readiness.

## Deliverables

Within `openspec/changes/task-model-routing/` write the generated metadata, proposal, design, delta specs and task checklist. Put every formal observable promise in the delta specs, not this brief or another requirement catalogue. Write your own `docs/team/reports/E14-verify.md` with the final artifact inventory, concrete design choices, executed commands, scope audit, unrun checks and clean local branch/commit identity.

The accepted E13 impact map is the starting point, not permission to keep stale contracts. Replace/retire the seat-model and console-seat-model contracts; use MODIFIED/REMOVED for supersession. Close task-to-scenario coverage in both directions, with independently falsifiable red/green cases. Keep formal specs self-contained; do not add ledger-reference exceptions or a parallel checker to make them validate.

Carry the PM refinements in the E13 review into the design:

- Initial mapping has routine/analysis/verify, but valid category names come from project configuration. Three initial labels are not an engine-wide closed vocabulary. Decide a simple token shape and uniqueness/value checks; reject a brief category absent from the project mapping. The PM chooses by guidance; no classifier, model compatibility matrix or natural-language difficulty logic.
- State precisely where category is declared, how overrides and same-task recovery resolve, and how a complete model/launch identity is committed. Define interruption/refusal/preview behavior, thinking-suffix treatment and metadata provenance. Keep the original selection source distinguishable from assignment-based recovery.
- Keep model/SID safeguards within Teamsmith-owned launch/resume paths. They do not detect every later Pi-internal manual model change and do not transform, inspect or replay reasoning/message blocks. Independent PM model handling belongs in the existing PM launcher, not a second recovery system. Existing concurrency policy is worker-scoped; preserve safety without promising a subscription-wide budget.
- Keep diagnostics and the canonical config writer usable when retired keys are present. Choose the smallest safe explicit editing/upgrade front door; atomicity, quoting, CAS and audit remain. Do not preserve old routing, auto-infer categories from seat presets, write a general bash parser or fix init identity/force behavior in this change. Complex ambiguous source assignments can be refused with an actionable manual correction.
- Cover CLI and console settings, templates/bootstrap guidance, PM/worker guidance, model/source displays and SID-related readers within the mapped capability boundaries. Selected/last-launched model must not be confused with the policy for the next new task. A live byte count must not be replaced with the launch-time snapshot. Synthetic fixtures may contain fake session files; no real user history reads.
- Name execution slices, ordering, file owners and delta owners. Shared scripts/common fixtures must have one writer or a serialized handoff. Do not create three parallel briefs that all need to edit `smoke.sh` or the same delta. The proposer does not implement; a future verifier must not be an apply author. Planned agents/paths are recommendations, not actual apply assignments.
- Separate local source/config rollout from shared installation and other-project adoption. No automatic live config update, process restart or installer invocation. The user must see planning artifacts before apply starts; runtime-affecting operations retain the existing explicit authorization boundaries.

Show copy-pasteable future acceptance commands using existing test front doors where possible. Clearly label proposed new interfaces and tests as not implemented/not run, rather than asserting they already execute. Include real TUI verification in the future apply/verify plan and real captured launch arguments/record effects for recovery. Planning checks below do not prove those future scenarios.

## Ownership and prohibitions

The PM temporarily grants you only:

- `openspec/changes/task-model-routing/**` for this propose phase, per OWNERSHIP's phase-owner rule;
- `docs/team/reports/E14-verify.md`;
- external `pm-skills-ledger/team/reports/E14-verify/` for trial copies and command evidence, resolved from the main checkout's parent through git's common directory.

No other versioned paths may change. In particular: no `openspec/specs/**`, OpenSpec root config, product scripts/tests/console/templates/docs, project config, AGENTS, team board/decisions/reviews/ownership, shared tools or other projects. Do not alter the spec-ledger-reference registry, validators or skip controls.

No LLM benchmark, real provider calls outside this agent's own planning work, session-history inspection, install/update, services, pushes, PR/MRs, merges, live archive or apply. Preserve historical reports and code. Existing E13 evidence belongs to its author; copy what a trial needs into your own evidence area without overwriting their fixtures/logs.

## Acceptance — run and report exact results

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" status --change task-model-routing --json
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate task-model-routing --strict
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
```

Also copy the OpenSpec tree to a disposable directory **inside your authorized external evidence area**, explicitly ensure CLI context points to that copy, and execute a trial `archive task-model-routing -y` with the existing Bun CLI, followed by `validate --all --strict` and spec reference checking on the projected base. Use OpenSpec's machinery to catch wrong MODIFIED titles and ADDED collisions now, not a custom semantic checker. Do not bypass validation or spec updates, change actual task completion boxes, or archive the real change. If the tool reports incomplete planning checklists, distinguish that from a semantic delta failure and retain the warning/output; do not fake implementation completion.

This planning-only brief intentionally does not require product smoke or the complete suite. Run no full gate for unchanged production code. State that limitation and leave all implementation checklist items unticked.

Use small Conventional Commits with E14 and an `Agent: verify` trailer. Commit all planning artifacts and your report; final tree must be clean on the allocated branch. Record artifact paths, final commit and external evidence location. Harvest any background jobs before ending.

If hard-blocked, write your own PARTIAL report and notify **pm**, not yourself: `bash skills/teamsmith/scripts/team notify pm "E14 (task-model routing proposal): <one-line blocker>"`. The generated prompt still has the unrelated self-recipient defect; do not follow or fix it. The PM reviews this proposal separately in `docs/team/reviews/task-model-routing-proposal.md`; this assignment grants no apply authorization.
