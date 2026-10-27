# P380 · Stop pinning Pi in real test runtimes; resolve and record the latest version

task: P380
agent: dev3
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — test-runtime freshness for real Pi invocations, not replay fixtures
deltas: -
branch: task/P380-pi-latest-test-runtime

## User requirement

The tests that use real Pi must not stay pinned to an old version, or must update to the latest version each run. This is not permission to make the user's workstation upgrade itself.

## Current pins found by PM

- `ci/Containerfile`: `ARG PI_VERSION=0.86.0`, then installs `@earendil-works/pi-coding-agent@${PI_VERSION}`.
- `.github/workflows/gates.yml`: comment says the image pins `pi 0.86.0`; the actual image uses the Containerfile.
- `skills/teamsmith/tests/fixtures/delivery-truth-real/run-case.sh`: default runtime `0.99.2`, accepts only `0.99.2` as verdict mode, requires a preinstalled `.runtime` at that version, and `judge-second.py` treats other versions as observation-only.
- `skills/teamsmith/tests/fixtures/delivery-truth-real/README.md`: documents the pinned runtime.

By contrast, `slash-team-e2e.sh` and the `host` route use the current host Pi. Those should not auto-upgrade the host. Old `pi-0.xx` frame files and fake/recording Pi implementations are replay fixtures, not real runtime pins; leave them as historical replay and make the distinction explicit where necessary.

## Required behavior

1. **CI image/workflow**: remove the static old Pi pin. Resolve the latest published Pi version once at the start of a workflow run and use that same resolved version for every shard so a mid-run release cannot give different shards different runtimes. Local container builds without an explicit version should default to `latest`. Print `pi --version` in the actual gate environment. Avoid a design where `@latest` is hidden behind a stale Docker layer.
2. **Real delivery-truth fixture**: stop requiring `0.99.2` for verdict mode. Resolve/install the latest runtime per run (or per evidence run) and record the actual version. Update the judge to judge current behavior or to report a visible, named incompatibility — never silently fall back to the old pin and never call observation a pass.
3. **Host safety**: do not run `pi update`, `npm i -g …@latest` or equivalent on the user's workstation. Host mode remains observation-only unless the user separately chooses otherwise.
4. **No fake-green version handling**: if latest changes Pi behavior, update the judge from observed behavior or make the test visibly fail/skip with the exact reason. Do not relax assertions just to make latest pass.
5. Keep `PI_DIST`/skill parser loading working with the resolved package; if its path changed, resolve it from the installed package rather than hardcoding an old layout.

## Acceptance evidence

- Inventory every real Pi runtime path and show which static pins were removed. Replay-only fixtures may remain old-versioned, explicitly labelled replay.
- Show the workflow resolves one latest version and passes it consistently to all shards; show a real built/gate environment's `pi --version` output matching it.
- Show the delivery-truth fixture resolving and recording the latest version instead of requiring `0.99.2`; run its affected case(s) against that runtime or, if latest exposes a real incompatibility, deliver the exact observed failure and the judge change needed rather than reverting to the pin.
- Run only affected tests (`skill-load`, slash-team e2e if relevant, delivery-truth fixture, workflow/container static checks). No full gate.
- `bash -n`, `section-select.sh --check`, ledger ban and `git diff --check`.

## Delivery

Report `docs/team/reports/P380-dev3.md` with exact commands, versions and output. If a latest-Pi behavior change requires a larger judge redesign than this task can safely carry, write `BLOCKED:` with the evidence and the smallest next step; do not hide it behind an old-version fallback. No merge, push or publish.

## Rework required by V109 (2026-10-27)

V109 reproduced a blocking parser defect in **both** version resolvers:

- `ci/resolve-pi-version.sh`
- `skills/teamsmith/tests/fixtures/delivery-truth-real/run-case.sh`

Both currently run `tr -d '[:space:]'` **before** matching the version. If npm returns `1.4.0` plus a notice on another line, all lines are joined and the resolver rejects a valid answer. This breaks the exact latest-runtime path this task is meant to provide.

Required fix: select a complete version line first, then trim whitespace from that selected line (or use an equivalent structured parse). Do not merge all registry output before matching. Apply the same correction in both locations.

Required additional evidence before re-delivery:

1. A realistic npm stub/output containing `1.4.0` followed by an npm notice/warning line must return exactly `1.4.0` with rc=0 in **both** paths. Show the old implementation failing the same input and the repaired implementation passing it.
2. A multi-line answer with no valid version line must still fail loudly; registry failure must remain non-zero and must not create a scene.
3. Re-run `workflow-entry.sh`, `delivery-truth.sh --section judge --mutations`, the resolver's success/failure checks and the static checks. Do not rerun the full gate.

Keep the rest of the candidate frozen except these parser fixes and the report. V109 will perform a focused second-round review.
