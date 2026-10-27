# P382 · Make the ledger-selection fixture deterministic under GitHub's numeric UID

task: P382
agent: dev
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — repair an existing CI fixture's environment assumption; no product contract change
deltas: -
deps: skills/teamsmith/tests/ledger-claim.sh
branch: task/P382-public-ci-ledger-claim

## Evidence and scope

Public release run `40433391806` (`db0bea987e73e26d4d287c88505e588bfbea01cb`) has a real red in shard 3 before that shard was cancelled at the 60-minute job ceiling. The saved log is `$HOME/.cache/release034/run-40433391806-job-121956221892.log` around lines 2508–2522:

- `ledger-claim` case ③ (clean report) returns rc=3 instead of rc=0;
- case ⑥ (old markdown-only false-green control) also returns rc=3 instead of rc=0;
- both print `SKIP user —— 本机用户名解析不出来` even though their fixture names file is configured;
- the final visible count is `== ledger-claim == ✓ 13 ✗ 2`, followed by outer `P239 归属与红侧有失败（rc=1）`.

The workflow runs Docker with `--user "$(id -u):$(id -g)" -e HOME=/tmp` and does not set `USER`/`LOGNAME`. The numeric UID has no passwd entry, so `ledger-ban.sh`'s normal `id -un → USER/LOGNAME → HOME tail` resolution is empty. `ban_run` deliberately returns rc=3 for a clean scan with a skipped subcheck. `ledger-claim.sh` is not testing username auto-resolution, but its direct scanner calls omit the existing fixture-only `--user` input; only the two clean arms therefore turn red. This is a fixture environment dependency, not evidence that the scanner missed a leak.

Fix only `skills/teamsmith/tests/ledger-claim.sh` and your own report. Make the fixture's user explicit and deterministic through the existing fixture-only interface (or an equally narrow environment arrangement); do not change `ledger-ban.sh`, its rc=3 skip contract, the workflow, the 60-minute ceiling, section scheduling, or any other test. The timeout/cost work stays with P379 and is not this task.

## Required evidence

1. Reproduce the two-red baseline at `db0bea987e73e26d4d287c88505e588bfbea01cb` in the pinned gate image using a numeric UID with no passwd entry and `HOME=/tmp`, matching the public workflow. Use `localhost/teamsmith-gates:ci` (image id observed by PM: `91fa9dab3106`) or rebuild that exact frozen tree if the image no longer matches. Record image id, tree tip, command and output; do not claim host-only reproduction is enough.
2. In the same numeric-UID container shape, the repaired candidate must run `TEAM_SMOKE_FIXTURE=1 bash skills/teamsmith/tests/ledger-claim.sh` with all cases green. Run the same before/after fixture on the host as a compatibility check. Removing the new explicit-user arrangement in a private candidate copy must reproduce the named two reds under the numeric-UID environment.
3. Run `bash skills/teamsmith/tests/smoke.sh --select 60` on the repaired candidate in that pinned container. The real-tree names/user checks may remain visible SKIP when their inputs are genuinely absent; do not convert those SKIPs into claimed passes or suppress them. The P239 fixture itself must be green.
4. Run `bash -n skills/teamsmith/tests/ledger-claim.sh`, `bash skills/teamsmith/tests/section-select.sh --check`, and `git diff --check`. Do not run the full gate and do not rerun the expensive timeout sections.

For container execution inside distrobox, use `distrobox-host-exec podman`; never invoke `podman` directly inside the container. Keep logs and any kept scene on a host-bind-mounted path under `$HOME/.cache/`, not only in a container `/tmp`.

## Delivery

Commit the small fix and `docs/team/reports/P382-dev.md` with exact before/after commands, image/tree identities and output tails. State explicitly that the two cancelled shards and the coverage failure are outside this small fix's scope. No merge, push, release, CI retry or full gate.
