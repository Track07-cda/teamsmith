# V105 · Independent review of the 34d companion-lock fixture fix

task: V105
agent: verify
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — test-only fixture repair
deltas: -
branch: task/V105-34d-lock-shape-review

## Question

P374 changes `skills/teamsmith/tests/smoke.sh` so the expected companion-lock path is derived from the same input instead of hard-coding `.teamsmith-smoke.lock.machine`. Candidate: `f62c14fc` on `task/P374-34d-lock-shape`. The author was interrupted before writing a report. Verify the implementation, not the missing report.

The reported defect was a false red when a reviewer used a private `TEAM_SMOKE_LOCK`: the previous assertion expected the default name even after explicitly accepting a private input.

## Required independent checks

Work in your own clean clone on disk. Do not modify the candidate or main.

1. Run `bash skills/teamsmith/tests/smoke.sh --select 34d` twice in the candidate:
   - without `TEAM_SMOKE_LOCK`, using a private disk `TMPDIR`;
   - with `TEAM_SMOKE_LOCK=<your-private-dir>/7-1.lock` and the same private disk `TMPDIR`.
   Both must be green. Give the exact commands, result lines and exit codes.
2. Reproduce the old failure on the old implementation (checkout `main` or extract just the old `smoke.sh`) with the same private lock input. The default-name assertion must fail while the candidate is green. This proves the fixture repair has a real before/after effect.
3. In a private copy, break `gate_lock_companion_path` (for example, move the companion under the temporary root or remove the leading dot). The new shape assertions must fail and name the problem; restore and confirm green. Do not change the real product implementation.
4. Check that the default-input case still asserts the exact default companion name, and that the private-input case derives its expected name from the private path without introducing a double dot.
5. Run `bash -n skills/teamsmith/tests/smoke.sh`, `bash skills/teamsmith/tests/section-select.sh --check`, `bash skills/teamsmith/tests/section-guard.sh --loop-check`, and `git diff --check`. Give the final readings. Do not run the full suite.

## Delivery

Write only `docs/team/reports/V105-verify.md` and your own thread. Start with PASS, PARTIAL or FAIL. Separate required fixes from observations. If the candidate itself is defective, do not repair it; report the exact failing input and assertion.

No full gate, no container run, no new fixtures or guards, no push, no archive.
