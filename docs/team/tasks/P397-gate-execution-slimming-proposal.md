# P397 · Propose less repeated gate work, then balanced CI slicing

task: P397
agent: dev2
phase: propose
category: analysis
change: gate-execution-slimming
deltas: verification
branch: task/P397-gate-slimming-proposal
deps: P379 exploration d54b7692fe07 accepted in docs/team/reviews/P379.md; user continuation 2026-10-30; D217

## Assignment and authority

Planning-only Propose, owned by the P379 explorer. Read AGENTS, your thread, OWNERSHIP, this brief, the generated OpenSpec propose workflow, references/openspec.md and the existing verification spec in full before writing deltas. You are not the eventual implementer. Write only `openspec/changes/gate-execution-slimming/{proposal.md,design.md,tasks.md,specs/verification/spec.md}` and `docs/team/reports/P397-dev2.md` in your own worktree. If another capability truly needs a delta, report the exact conflict to PM before editing it. Do not modify product/tests/workflow/canonical specs/live state, old reports, other proposals or other worktrees. No merge/push/archive/CI run/release.

Use a fresh session with one-launch `openai/gpt-6.1-sol:xhigh` (explicit PM route, verified with the configured absolute Pi binary); do not change project model config or credentials. P395's accepted proposal/report remains intact at `0e557f47` on `task/P395-openspec`; its phase is closed, not merged. This task starts from main, not P395, and must not carry unrelated proposals.

## Reuse evidence; do not repeat Explore or full smoke

Read the accepted report with `git show d54b7692fe07:docs/team/reports/P379-dev2.md`, plus `docs/team/reviews/P379.md` (second review). Old raw evidence, when present, is read-only under `$HOME/.cache/release034/` and the ignored P379 evidence directory in your worktree. Missing evidence is a named gap, not permission to invent or rerun it.

Current P396 full-gate evidence is read-only at `$HOME/.cache/P396/full-gate/{before.txt,smoke.log}`. On 2026-10-30 PM observed 127 completed sections totaling 5369s: help/routes 1037s, selector self-check 964s, settings 718s, routing normal 566s; the routing mutation section was still running after 4500s. These are observations of an unfinished run, not a green baseline. Preserve the log bytes; terminal output can contain invalid UTF-8. Do not wait for this run to complete; no result from it gates writing this proposal.

No smoke.sh, key-replies, routing matrix, container build or costly fixture run during Propose. Use source inspection, existing logs and read-only selector commands. This is a documentation lane alongside the one shared running gate, not a second gate lane. Do not interrupt or harvest another session's job.

## Settled direction to translate into one minimal change

Priority order for ordered Apply slices: (1) reduce repeated routing-mutation execution in 61b, (2) remove demonstrably duplicate setup/work in 36/51/38, (3) balance CI shards by measured cost. Keep the current gate/selector/workflow entry points; no second framework, daemon, database or new gate about this process. A new check must replace an old check or state why product behavior cannot carry it; no word-count or timing threshold gates.

All 31 current routing mutations retain falsifiable, named detection plus green control/restoration. Do not equate “each mutation still has one red assertion” with preservation of everything its old full-group run observed. Map assertions/behaviors/setup to retained, shared, or explicitly redundant observations; any lost observation is named as a trade-off, not silently called equivalent. Critical incidents, silent-failure checks, installation-after-packaging behavior and distinct CLI/terminal/dispatch paths stay covered. Narrow a mutation's selected cases only with that mapping and independent reviewer acceptance; do not automatically retire unclassified observations.

Inspect the existing verification contract, especially changed-path/floor/full fallback, product-only versus internal shapes, per-existing-assertion count wording, per-section accounting, nested-run budgets, and CI coverage. Explicitly MODIFY real conflicting requirements instead of adding a parallel escape clause. Count decreases may follow proven duplicate removal; raw pass totals are not the coverage argument. Preserve true failure/SKIP/invalid distinctions, unknown-path FULL fallback and the exact selected union/needs closure.

Do not assume more CI jobs or move heavy tests to nightly. Price total runner time as well as wall time, setup and green baselines; shared preparation must not make independent runners rely on unverified mutable state. Distinguish separate runners from same-host containers with shared PID/process view. Keep the current 60-minute job limit; no timeout increase, duration-based pass/fail, same-host parallel full gates, deletion of failing tests, or rescheduling reds as a fix.

The prior 63.1→31.2 minute ordinary-change shard projection is not a promise; routing-fixture changes remain ~112 minutes if 61b is not actually reduced/split. Treat unmeasured savings as estimates. Current P396 startup/panel reds are separate defects, not evidence for deleting their checks.

## Deliverables and review inputs

Produce concise proposal/design/spec delta/tasks, not a new catalogue/manual. Include:

- Concrete retained/shared/removed-work table with exact source symbols/commands and coverage witnesses, including all routing arms and any incidental observations lost by narrowing.
- Ordered, independently verifiable implementation slices under this one change; prioritize reduced aggregate work before CI parallelism. Identify files and dependencies, including pending P380/P383/P386/P393/P396 test edits without importing them or requiring P396 to finish before planning.
- Baseline/proposed cost matrix for docs-only, ordinary product, routing-fixture and selector-self-check changes, plus local full regression. Show measured/derived/projected separately; no unconditional ≤30-minute claim.
- Acceptance recipes using existing or explicitly proposed commands: same environment before/after costs (reference-only), selected behavioral union/ownership, each mutation's named red/control/restore, real failures/skips/invalid runs, clean candidate fingerprint and independent non-author verification. Full acceptance is later, once per frozen candidate, not at Propose or every small repair.
- Minimal rollback to previous selector/matrix/workflow behavior; no production/live-team adoption in Apply. State separate authorization for protected merge/push/CI changes.

## Planning acceptance and handoff

Use the configured absolute OpenSpec binary if it does not resolve in the login shell; report exact executable/commands and output tails:

```bash
openspec status --change gate-execution-slimming --json
openspec validate gate-execution-slimming --strict
openspec validate --all --strict
openspec instructions apply --change gate-execution-slimming --json
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
```

The names file must be the real project's file, not missing in a disposable clone; missing prerequisites are not PASS. In an owned directory created with `mktemp -d -p /var/tmp`, rehearse archive only on a disposable spec copy and validate/inspect the resulting requirements and unchanged scenarios. Do not archive the real change. No full gate for proposal validation.

Report answer first: exact proposed subtraction, preserved/lost observations, cost evidence/unknowns, validation/trial results, next implementation slice. Commit in small Conventional Commits with P397 and `Agent: dev2`, leave branch clean, notify PM with final tip. PM formal review plus independent substantive review must ACCEPT the exact proposal before any Apply dispatch. Do not stop for routine confirmation or broaden the task into a new exploration.
