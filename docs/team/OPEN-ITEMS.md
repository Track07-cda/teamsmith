# Open items · 2026-10-27 handover

## Waiting on workers / verification (no user decision needed)

1. **0.3.4 public CI is not green.** Run `40433391806` finished `cancelled`; shard 1/2 succeeded, shard 3/4 were cancelled, and the coverage job failed. The reason has not been diagnosed. Next: read the saved GitHub logs, distinguish cancellation from a real failure, and record the cause before any release claim. Registry install itself was verified.
2. **P380 latest-Pi runtime** is at candidate `779d9d32` on `task/P380-pi-latest-test-runtime`; `V109` second round is **FAIL** at `81a56088`. The first two defects are fixed, but both workflow branches still swallow a non-zero `pi --version` exit status when the command prints a valid version. Preserve the subprocess status before calling `ci/check-pi-version.sh`, add the red side, then re-review. Do not merge before that.
3. **P381 notify git-stderr leak** is delivered at `9d7b6482` on `task/P381-notify-git-stderr-leak`, report `docs/team/reports/P381-dev-bob.md`. The real Pi 1.4.0 default no-upstream case now receives the second `say` once, while a human draft remains queued. Independent verification is the next step.
4. **P379 gate simplification** is delivered as an exploration at `aa03cf6e` on `task/P379-gate-simplification-explore`, with `docs/team/reports/P379-dev2.md`; PM review is pending. It is not an approved implementation and no wholesale test deletion is authorized.
5. **V109's ledger-ban names check is not a pass** in the verifier clone because the names file is absent there. PM must run it with the actual `.pi/team/forbidden-names.txt` before treating the check as complete.

## Waiting on the user

- No unanswered direct user question at handover. The user explicitly invoked the handover skill; this file is the continuity record, not a request for another confirmation.
- A future release after these fixes is not authorized yet; ask only after the current work has verified evidence.
