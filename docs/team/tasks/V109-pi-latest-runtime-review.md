# V109 · Independent review of the latest-Pi test runtime change

task: V109
agent: verify
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — independent verification of runtime freshness and no silent fallback
deltas: -
branch: task/V109-pi-latest-runtime-review

## Candidate

`ec85b375` on `task/P380-pi-latest-test-runtime` (the code/report candidate is `279560e02979` plus a final evidence-revision commit). Report: `docs/team/reports/P380-dev3.md`.

P380 removes the old `0.86.0` gate-image pin and the `0.99.2` delivery-truth verdict-runtime pin. It resolves one version per CI run, passes it to all shards, checks the actual `pi --version`, and resolves/installs the latest runtime for the delivery fixture. It also found a separate product stderr-leak defect, now assigned to P381; do not treat that separate defect as a reason to weaken P380's runtime checks.

## Required independent evidence

Use your own clean clone and private directories. Do not alter main or the candidate.

1. Inspect the runtime inventory: no real invocation still silently requires `0.86.0` or `0.99.2`; replay/fake fixtures are clearly distinct.
2. CI resolution: run `bash ci/resolve-pi-version.sh` and inspect the workflow. Verify one `resolve-pi` output feeds every shard's build and `PI_EXPECT_VERSION`. Run `bash skills/teamsmith/tests/workflow-entry.sh`; its version assertions must pass. Use a private copy to remove the version handoff and confirm the relevant assertion fails.
3. Build/readback: if practical, run `CONTAINER_ENGINE="distrobox-host-exec podman" bash ci/build-image.sh -t teamsmith-gates:v109` and confirm the image's `pi --version` equals the resolved value. Run the gate's version check with a deliberately wrong expected value and confirm a named non-zero failure. If the full build is not practical, use the existing image/build logs plus a smaller direct check and say exactly what you did not rerun.
4. Delivery-truth: run `bash skills/teamsmith/tests/delivery-truth.sh --section judge --mutations`. Confirm the new version-related red sides are real. Inspect the runtime resolver/install path: registry failure must be non-zero and must not create a scene or fall back to an old version.
5. Latest-vs-old behavior: use P380's recorded A/B/C evidence and, if useful, rerun only the default latest case after P381's product fix is available. Do not accept `P163_BRANCH_UPSTREAM=1` as proof that the default no-upstream case works.
6. Static checks: `bash -n` for changed shell files, `python3 -m py_compile` for the judge, `node --check` for the new JS helper, `section-select.sh --check`, ledger ban and `git diff --check`. No full gate.

## Delivery

Write `docs/team/reports/V109-verify.md`, starting with PASS, PARTIAL or FAIL. Separate runtime-freshness verdict from the independently handled product defect. Include exact commands and output tails, and state any coverage you did not exercise (especially GitHub Actions itself). Do not merge, push or publish.

## Second round after rework

Candidate after the first-round findings: **`779d9d32`** (includes implementation `af73b9e8`, parser rework `69369593`, and the final both-routes test update `00363e27`). The earlier `ffb378f0` was frozen before the final test/report commit and is superseded; use `779d9d32` for the second round. The first-round FAIL and its evidence remain in your report; append a `## Second round` section, do not rewrite it.

Recheck only the changed points and any directly affected evidence:

1. Both resolvers now select a complete version line before trimming. Re-run your real/stub `1.4.0 + notice` cases against both `ci/resolve-pi-version.sh` and `run-case.sh`; old behavior must be red, new behavior must print exactly `1.4.0` with rc=0. No-version and registry-failure cases must remain loud and must not create a scene.
2. `workflow-entry.sh` ④ now calls the same executable `ci/check-pi-version.sh` and runs it in a sandbox with a controlled `pi`. Verify equal expected/observed returns 0, mismatch returns named non-zero, and the shadow with the comparison removed lets the mismatch through. Repeat the two workflow mutations from your first round (delete the comparison, delete only the fallback handoff): both must now be red. `check_pi_branch` must run for both changed-path and full-suite branches.
3. Inspect the new `ci/check-pi-version.sh`: it must reject non-concrete expected values, select complete observed version lines, and return 3 for a mismatch. It must not silently fall back or accept `latest` as the expected value.
4. Re-run `workflow-entry.sh`, `delivery-truth.sh --section judge --mutations`, the parser checks and the static checks. Reuse your first-round image/readback evidence if the image did not change; state precisely what you did and did not rerun.

Give the final PASS/PARTIAL/FAIL first, with exact commands and output tails. Keep the P381 product defect separate; it is not part of this candidate.

## Third round after Rework 4

The new frozen candidate is **`47df9a76d5ef0519ef890e3175c596718d7fa355`**, whose implementation parent is `6004e822d4a2cc0c3ee0c7d397742b9510f99e49`; the tip adds the Rework 4 report. It supersedes `779d9d32`. Preserve the first- and second-round FAIL records verbatim and append `## Third round`; put this round's PASS/PARTIAL/FAIL at the start of that section. The PM is starting a fresh verifier session because the previous session exceeds its model window; the task, candidate history and evidence all remain on disk.

Recheck the changed points independently, using your own clean clone and controlled commands rather than only the author's runner:

1. Reproduce the old defect first: `bash ci/check-pi-version.sh 1.4.0 "$(pi --version)"` with a controlled `pi` that prints `1.4.0` and exits 42 still prints a successful comparison and returns 0. Then execute the **actual extracted command prefix from each workflow branch** at the new candidate. Both must stop before comparison, name the failure, return 42 and omit the success line. Only successfully obtained output may reach the checker; mismatch rc=3 and equal rc=0 must remain intact.
2. `workflow-entry.sh` ④ must now total 21 green / 0 bad. Independently mutate each branch back to the inline command-substitution shape and confirm branch-named red results. Confirm the new status-shadow really lets the exit-42 case through when the status guard is removed; a green assertion that does not execute this contrast is not evidence.
3. Check the same class in `ci/build-image.sh`: a controlled engine/runtime that prints the expected version and exits 42 must produce a named non-zero refusal before comparison and preserve the printed runtime output. Successful readback and version mismatch behavior must remain unchanged. You may reuse the existing fake-engine route; no new image build is required if the image itself is unchanged.
4. Re-run `workflow-entry.sh`, `delivery-truth.sh --section judge --mutations`, affected parser/static checks and `git diff --check`. Verify yourself that `git diff af73b9e808ca..47df9a76 -- skills/teamsmith/tests/fixtures/ skills/teamsmith/scripts/` is empty before reusing the earlier real-runtime A–E evidence; otherwise rerun the affected runtime case. No full gate and no GitHub rerun.
5. Complete the previously blocked ledger check on this final candidate with the real names file: `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"`. Record `names=ok`, `user=resolved`, hit count and rc. A missing names file or SKIP is not a pass.
