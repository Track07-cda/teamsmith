# V107 · Independent review of the single 61b flip-arm repair

task: V107
agent: verify
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — independent verification of a fixture/flip-contract repair
deltas: -
branch: task/V107-routing-bootstrap-flip-review

## Candidate

`42064b9d` on `task/P377-routing-bootstrap-flip` (test change `ca112db6`). Report: `docs/team/reports/P377-dev.md`.

The frozen 0.3.4 full gate had exactly one outer failure: `flip-init-legacy-proceeds-bootstrap`. The author reports that the mutation scratch lacks `SKILL.md` and sibling skills, so bootstrap still exits 1 for an unrelated installation error. The old flip assertion expected `FAIL init-legacy-bootstrap-refused`, which therefore never appeared. The repair retargets the flip to `FAIL init-legacy-bootstrap-derived`, `FAIL init-legacy-bootstrap-startup-route`, and `FAIL init-legacy-print-refused`.

## Required independent evidence

Use your own private copies. Do not rerun the full flip suite or full gate.

1. Reproduce the single arm exactly as in `docs/team/tasks/P377-routing-bootstrap-flip-diagnosis.md` and the report:
   - unmutated candidate control: `bash skills/teamsmith/tests/task-model-routing.sh --select init` is green;
   - `init-legacy-proceeds` mutant: read the actual `bootstrap --no-pulse --agents dev` output in `init-cmds.log` and confirm it passes the model gate but fails at the missing-`SKILL.md` installation source;
   - confirm the old `FAIL init-legacy-bootstrap-refused` is absent for that reason, while the three new expected failures are present.
2. Prove the repaired flip is not a rubber stamp:
   - on the mutant, all three new checks find their intended failure lines;
   - on the unmutated real tree, those three lines are absent;
   - on an unmutated same-shape scratch, they are also absent (the unrelated fresh-bootstrap failure is not mistaken for this arm).
3. Inspect the diff: only the `init-legacy-proceeds` case changes. The real-tree `init-legacy-bootstrap-refused` assertion at the original location remains intact; product code is unchanged. Confirm the change replaces a non-discriminating expectation rather than weakening the contract.
4. Run `bash -n skills/teamsmith/tests/task-model-routing.sh`, ledger ban and `git diff --check`. No full suite.

## Delivery

Write `docs/team/reports/V107-verify.md`, starting with PASS, PARTIAL or FAIL, and include exact commands/output tails. Do not repair the candidate, merge, push or run the full flip.
