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

## Second round: focused F1 recheck

Candidate after rework: `5ff4b1de` (`7ce7fec5` is the code change; `7d2d561b` merges current main; `5ff4b1de` adds the report). The candidate's `smoke.sh` is byte-identical to `7ce7fec5`.

The first review's private-lock and two shape-mutation results stand. Do not repeat the whole first round. Verify only the F1 repair and that it did not break those results:

1. In your own clean clone, run ordinary `--select 34d` without setting `TEAM_SMOKE_LOCK`. It must be green, and the output must actually contain both new default-name assertions (default basename and exact default companion). A `TEAM_SMOKE_NO_LOCK=1` run is not accepted as the reachability proof.
2. Run `--select 34d` again with a private `TEAM_SMOKE_LOCK=<private>/7-1.lock`. It must be green and the derived companion must be `.7-1.lock.machine`.
3. In a private copy, change the default lock name. On an ordinary run, the new literal assertions must fail and name the mismatch while the input-derived assertions still pass. Restore and confirm green.
4. Inspect the delta from `f62c14fc` to the candidate: the previous companion-shape assertions must remain present, and the only new behavior must be the explicit `unset` default checks plus the current-path consistency check. Reuse the first round's two passing shape mutations; do not rerun them unless this delta touches them.
5. Append a `## Second round` section to your existing report; keep the original PARTIAL section verbatim. Give the final PASS or FAIL first, then the commands and result tails. Run the same static checks as round one; no full suite.
