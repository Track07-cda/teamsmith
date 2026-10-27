# Open items · 2026-10-27 handover

## Waiting on workers / verification (no user decision needed)

1. **0.3.4 public CI is not green; the saved logs now separate one real red from the timeout.** Run `40433391806` shard 3 first reported `ledger-claim` ✓13/✗2: under the workflow's numeric UID plus `HOME=/tmp`, the fixture omitted its available explicit user and two clean arms returned the scanner's documented clean-with-SKIP rc=3. `P382` owns that narrow fixture repair. Shards 3 and 4 were then cancelled at about 60 minutes (`.github/workflows/gates.yml` keeps `timeout-minutes: 60`): shard 3's changed paths pulled §61b back into the run and it was still progressing after 2341s; shard 4 was still in §51 after 1140s. The coverage job failed afterwards because those two cancelled shards supplied no own-key lists, leaving 65 of 135 sections uncovered; it is not a third independent failure. Timeout/cost remediation remains part of the `P379` review, with no implementation approved yet. Raw logs: `$HOME/.cache/release034/run-40433391806-job-*.log`. Registry install itself was verified, but no green-CI or release claim follows from it.
2. **P380 latest-Pi runtime** is at candidate `779d9d32` on `task/P380-pi-latest-test-runtime`; `V109` second round is **FAIL** at `81a56088`. The first two defects are fixed, but both workflow branches still swallow a non-zero `pi --version` exit status when the command prints a valid version. Preserve the subprocess status before calling `ci/check-pi-version.sh`, add the red side, then re-review. Do not merge before that.
3. **P381 notify git-stderr leak** is delivered at `9d7b6482` on `task/P381-notify-git-stderr-leak`, report `docs/team/reports/P381-dev-bob.md`. The real Pi 1.4.0 default no-upstream case now receives the second `say` once, while a human draft remains queued. Independent verification is the next step.
4. **P379 gate simplification** is delivered as an exploration at `aa03cf6e` on `task/P379-gate-simplification-explore`, with `docs/team/reports/P379-dev2.md`; PM review is pending. It is not an approved implementation and no wholesale test deletion is authorized.
5. **V109's ledger-ban names check is not a pass** in the verifier clone because the names file is absent there. PM must run it with the actual `.pi/team/forbidden-names.txt` before treating the check as complete.

## Waiting on the user

- No unanswered direct user question at handover. The user explicitly invoked the handover skill; this file is the continuity record, not a request for another confirmation.
- A future release after these fixes is not authorized yet; ask only after the current work has verified evidence.
