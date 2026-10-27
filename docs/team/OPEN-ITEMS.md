# Open items · 2026-10-27 handover

## Waiting on workers / verification (no user decision needed)

1. **0.3.4 public CI is not green.** Run `40433391806` finished `cancelled`; shard 1/2 succeeded, shard 3/4 were cancelled, and the coverage job failed. The reason has not been diagnosed. Next: read the saved GitHub logs, distinguish cancellation from a real failure, and record the cause before any release claim. Registry install itself was verified.
2. **P380 latest-Pi runtime** is at candidate `779d9d32` on `task/P380-pi-latest-test-runtime`; `V109` first round was FAIL, rework is complete, second-round review is pending. Do not merge until that review passes.
3. **P381 notify git-stderr leak** has implementation `df6339c1` on `task/P381-notify-git-stderr-leak`; the real latest-Pi default no-upstream delivery case and independent verification are still pending. `P380`'s A/B evidence is in `docs/team/reports/P380-dev3.md`.
4. **P379 gate simplification** is an exploration, not an approved implementation. Its report is not yet on `main`; `p379-measure` is the background measurement job to harvest. No wholesale test deletion is authorized.

## Waiting on the user

- No unanswered direct user question at handover. The user explicitly invoked the handover skill; this file is the continuity record, not a request for another confirmation.
- A future release after these fixes is not authorized yet; ask only after the current work has verified evidence.
