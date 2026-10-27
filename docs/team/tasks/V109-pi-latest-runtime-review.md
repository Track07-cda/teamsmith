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
