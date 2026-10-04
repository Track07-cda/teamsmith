# P2 · Apply: `spec-delta-gate` (C0)

```
task:   P2
agent:  dev
phase:  apply
change: spec-delta-gate
deps:   P1 (proposal ACCEPTED — `docs/team/reviews/spec-delta-gate-proposal.md`)
```

> Pipeline phase 3 (`opsx-apply`). The proposal was reviewed and **ACCEPTED** with conditions; implement exactly that
> change. The review record is the contract — where this brief and the change disagree, the change wins and you say so
> in the report.

## What to implement

`openspec/changes/spec-delta-gate/` (proposal, delta spec, tasks.md, design.md) — implement the tasks in order. The
delta-applicability check goes into `skills/teamsmith/tests/spec-lint.sh` with the six rule codes the delta names, one
`<file>:<line>: <rule>: <detail>` line per defect, exit 1; exit 2 for an unusable root unchanged. The comparison must
mirror `openspec archive` (names trimmed, scenario names exact and multiplicity-aware, fenced code ignored, an absent
`REMOVED` and an already-applied `RENAMED` tolerated) so that a delta archive accepts stays green.

## Conditions from the proposal review (all binding)

1. **Grant of the doc edit**: you may edit `skills/teamsmith/references/openspec.md` for tasks 4.1 only (it is
   PM-owned; the grant is this sentence). Nothing else under `references/`.
2. **`openspec/specs/**` must not change.** Archive is the phase that writes there; touching it here would bypass the
   change's own audit trail.
3. **All three gates green on your branch**: `openspec validate --all --strict`,
   `bash skills/teamsmith/tests/spec-lint.sh`, `bash skills/teamsmith/tests/smoke.sh` — including tasks 2.3, the two
   §16 real-tree count assertions that the proposal branch shows red (`1157 ✓ / 2 ✗`). Leaving them red is a delivery
   failure, not a known issue.
4. **The guard must not be theatre** (tasks 3.3): with the new rules removed from a *copy* of the checker, the red
   fixtures must actually fail — put the transcript in the report. The verify agent will reproduce this
   independently, so a fixture that passes for the wrong reason will be caught.
5. If the checker and `openspec archive` disagree about a tolerated case, **report it** rather than relaxing the rule.

## Evidence the report must contain

- The three gates' result lines, on the final revision you deliver.
- The red fixtures (one per rule code) and the green controls (including a delta `openspec archive` accepts, and this
  change's own delta staying green while active), as commands with output tails.
- The CLI probe matrix result (before/after): the name-typo class fails the gate **now**, at gate time, instead of at
  archive time.
- `git diff --stat` of your branch and an explicit statement that `openspec/specs/**` is untouched.

## Boundaries

- Files you own: `skills/teamsmith/tests/spec-lint.sh`, `skills/teamsmith/tests/smoke.sh` (your own area; the §16
  section), `skills/teamsmith/references/openspec.md` (granted above), `openspec/changes/spec-delta-gate/**` (only if
  the implementation forces a clarification inside the change — never `openspec/specs/**`).
- Do not touch `cmd-*.sh`, the meetings code, the doc-invariant scanner, or `docs/team/**` besides your report.
- Do not run `openspec archive`; do not push `main`.

## Acceptance

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/spec-lint.sh
bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
```

## Report

`docs/team/reports/P2-dev.md`
