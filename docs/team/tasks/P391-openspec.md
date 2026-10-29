# P391 · Propose instruction-context slimming with safe AGENTS refresh

task: P391
agent: dev3
phase: propose
category: analysis
change: instruction-context-slimming
deltas: init-skill
branch: task/P391-openspec
deps: accepted exploration P389 3a32f85f8f20; PM review docs/team/reviews/P389.md; D208

## Phase boundary

You explored this change and now own **planning-only Propose**. You will not implement it. Read `AGENTS.md`, your thread, this brief, OWNERSHIP, `references/openspec.md`, the complete P389 report (`git show 3a32f85f8f20:docs/team/reports/P389-dev3.md`), PM review and D208. Use the generated OpenSpec propose workflow.

Write only `openspec/changes/instruction-context-slimming/{proposal.md,design.md,tasks.md}`, the declared delta under `specs/init-skill/spec.md`, and `docs/team/reports/P391-dev3.md`. Do not edit canonical specs, product prompts, AGENTS, SKILL, dispatch code, tests, configuration or live project files. No Apply before formal PM proposal ACCEPTED and independent substantive proposal review.

## Accepted direction

1. AGENTS becomes the short shared cross-seat constitution/reading order; PM prompt keeps PM-only startup and essential evidence/boundary rules; worker dispatch remains self-contained on critical safety/delivery behavior; SKILL/references hold detailed procedures. No new rule registry, generator, database or prose-guard framework.
2. Keep short duplicated rules where a spec or self-contained worker launch requires them. Do not replace mandatory multi-surface duties with a bare link. A human rule-by-rule review and independent verifier, not a keyword/line-count/performance gate, judge preservation.
3. Reuse the existing `team init` managed-block replacement. No new migration command or AGENTS-only mode is needed. A normal existing project with Teamsmith markers can refresh without `--force`; old `pi-team` markers migrate. Existing-config bootstrap does not refresh AGENTS and must not be documented as the adoption path.
4. Live pm-skills adoption is outside this product change. Its 28 lines / 1,988 bytes of custom discipline at current `AGENTS.md:49–76` must later be moved outside markers with a separately previewed/authorized diff. Do not include those rules in the generic template merely to preserve one project's customization.

## Proposal decisions and coverage

- Turn P389's rule-ownership matrix into a concrete source-by-source edit plan: AGENTS, pm-prompt, worker dispatch, SKILL, protocol/workflows, generated PROTOCOL. Identify what is removed, compressed, retained or pointer-only and the canonical detailed destination. Keep the useful command index and role-specific startup self-containment.
- Resolve documented prose contradictions in favor of current authoritative behavior/specs: selected-versus-full gates with disclosed scope, local/remote settled delivery, actual `templates/report.md.tmpl`, pulse reporting but not auto-resuming workers, task category versus seat/model/SID, and real capacity contract rather than swap-only shorthand. Do not turn this into runtime lifecycle/threshold changes.
- The expected only delta is `init-skill`: describe role-specific instruction organization and observable existing-project AGENTS refresh behavior. If the actual wording changes any dispatch/writing-discipline/key-replies/watchdog/verification obligation, stop and report the additional required delta instead of hiding it under init-skill.
- `design.md` must distinguish product-template validation from later live adoption. Document marker shape assumptions, legacy/no-marker/missing/idempotent/no-skills behavior, init's other writes and non-transactional nature, default render parameters, and why `--force` is not used. Do not claim every non-AGENTS file is untouched or that bare init is safe for non-default projects.
- `tasks.md` must reuse existing install-shape/smoke/task-model-routing fixtures, not add a new migration framework or smoke section. Include behavior red/green mutations and independent human rule-coverage review. Measure before/after sizes as evidence, not blocking performance budgets.
- Live adoption steps, if mentioned, are explicitly future separate authorization: preserve the 28-line custom section outside markers, inventory init parameters/writes, private-copy preview, byte backup, exact execution, and separate PM reload. Do not mark them done in this change.

## Required fixture plan

Plan observable tests for: verbose old managed block with unique before/after custom text; preserved config and existing ledger documents; legacy marker; no marker; missing file; repeated init; `--no-skills`; force/bootstrap boundaries; non-default session/roster/docs parameters. Prove the file actually becomes shorter and the new managed block equals the rendered template, not just that a keyword exists. Mutations that stop replacement or overwrite outside custom text must fail. Worker prompt tests must prove local/remote and background/no-background variants retain applicable three-state and delivery rules.

## Acceptance and handoff

Before delivery run and record actual output in the real available environment (if a host CLI is missing, use the existing gate image with a read-only source mount as in P389 and state that boundary; do not install anything):

```bash
openspec status --change instruction-context-slimming --json
openspec validate instruction-context-slimming --strict
openspec validate --all --strict
openspec instructions apply --change instruction-context-slimming --json   # read-only planning inspection
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
```

Trial-archive only in a disposable copy outside the repository and validate all specs there; do not archive the real change. No full gate, live init, PM/worker restart, merge, push or release.

The report leads with the chosen structure, exact artifacts, every P389 correction/boundary, validation results and any added-delta concern. Commit with Conventional Commits + P391 + `Agent: dev3`, leave the branch clean and notify PM for formal review.
