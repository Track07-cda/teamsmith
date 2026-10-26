# P377 · Diagnose the single failing 61b arm in the 0.3.4 frozen gate

task: P377
agent: dev
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — targeted diagnosis and minimal fixture repair if the evidence supports it
deltas: -
branch: task/P377-routing-bootstrap-flip

## Evidence

The final frozen candidate before the npm-scope repair is `d8a21c03`. Its pinned-container full gate ran 14363.7s and ended **5058 passed / 1 failed**. All 134 sections closed; the only red is:

```
✗ 61b 路由翻转变异有失败（rc=1；RESULT pass=200 fail=1 selected=flip）
```

The flip harness has exactly one own failing assertion:

```
FAIL flip-init-legacy-proceeds-bootstrap
```

Other lines such as `FAIL monitor-missing-A-unavailable`, `FAIL pm-publication-failure-stops-uncommitted`, `FAIL heal-bootstrap-shape-number`, `FAIL updatecheck-print-cache-unchanged` are inner failures expected by their corresponding flip checks; do not count them as five separate product failures.

The mutation is `init-legacy-proceeds` in `skills/teamsmith/tests/lib/model-routing-flips.py`: it short-circuits `team_config_legacy_model_keys` and `team_init_model_policy_resolve`. The flip check expects the mutated tree's `--select init` run to contain `FAIL init-legacy-bootstrap-refused`. It did not. The outer log is `$HOME/.cache/release034/tmp/teamsmith-smoke-work-0c9a453f.sBd9jn/p238-routing-flip.log`; the per-arm evidence directory was not retained, so do not invent the missing bootstrap output.

## Required work

1. Reproduce only this arm in your own private directory, not the whole 82-minute flip suite:
   - make a private copy of the candidate source;
   - run `python3 skills/teamsmith/tests/lib/model-routing-flips.py <scratch> init-legacy-proceeds`;
   - run `TEAM_ROUTING_TREE=<scratch> TEAM_ROUTING_EVIDENCE=<private evidence dir> bash skills/teamsmith/tests/task-model-routing.sh --select init`;
   - read the captured `init-cmds.log` and the exact `bootstrap` rc/output. Also run the unmutated candidate `--select init` as the control.
2. Determine the exact reason `FAIL init-legacy-bootstrap-refused` is absent:
   - did bootstrap succeed, so the old refusal assertion should have failed but was not printed?
   - did bootstrap still refuse for another reason, so the named refusal assertion stayed green and the flip expectation is wrong?
   - did the fixture fail before reaching bootstrap?
   Give the actual output, not a hypothesis.
3. If this is a fixture/flip-contract defect, make the smallest repair in `skills/teamsmith/tests/task-model-routing.sh` and/or `skills/teamsmith/tests/lib/model-routing-flips.py`, with before/after evidence and a flip-side control. Do not weaken the named behavior assertions or turn a missing refusal into a skip.
4. If the evidence shows a real product defect in init/bootstrap legacy refusal, stop at `BLOCKED:` with the reproduction and the minimal product change you recommend; do not expand into product code yourself.

## Acceptance

- The single-arm baseline and mutant reproductions, exact rc/output, and your classification.
- If repaired: the same failing arm is now caught correctly, the unmutated control is green, and the old incorrect flip expectation (if applicable) is shown to fail for the intended reason.
- Run only the affected routing selection(s), `bash -n`, ledger ban and `git diff --check`. No full gate.

Report `docs/team/reports/P377-dev.md`. Do not merge, push, tag or publish.
