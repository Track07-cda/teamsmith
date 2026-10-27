# P383 · Root-cause and repair the key-replies mouse scroll clamp failure

task: P383
agent: dev-bob
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — repair a reproduced live-terminal failure without changing the contract or CI schedule
deltas: -
branch: task/P383-key-replies-mouse-scroll-cla
deps: P379 supplies reproduction logs only; P382 owns ledger-claim.sh and does not touch this fixture

## Evidence

P379 independently reproduced the same current-main failure three times: host `key-replies-pty.sh --all`, host `--select mouse`, and `localhost/teamsmith-gates:ci --select mouse`, each rc=1. The failing assertion is:

```text
✗ mouse：滚 40 格到底被夹住（最旧的 #1 进入窗口，不换页）
== P234 key-replies-pty 结果 == ✓13 ✗1 SKIP0   # standalone mouse
== P234 key-replies-pty 结果 == ✓78 ✗1 SKIP0   # all groups
```

The following assertions say the newest entry is no longer in the window and the panel remains alive, so do not assume this is simply “the wheel did nothing”. Inspect the actual frames and scroll state. Evidence:

- `.worktrees/dev2/docs/team/reports/P379-dev2/log-kr-pty-mouse-reproductions.log`
- `.worktrees/dev2/docs/team/reports/P379-dev2/log-kr-pty-all-red.log`
- `.worktrees/dev2/docs/team/reports/P379-dev2/measure-run.sh`

The explorer reports the fixture, committed bundle and `cmd-reply.sh` are byte-identical to frozen green run `d8a21c03`. That does **not** prove the container is identical: the current `localhost/teamsmith-gates:ci` image id is `91fa9dab310641a6f4dca892520a31a3cd9d3699fb34919c468ad22d929df793` (created 2026-10-27), while another older local image exists. Record image ids and runtime versions for every A/B claim; a mutable tag is not a frozen image.

## Required work

1. Reproduce the red on a clean current-main checkout in both the host and the pinned-container shape before changing anything. Preserve the complete logs and frames on a host-bind-mounted path under `$HOME/.cache/`. Compare against `d8a21c03` and/or the frozen release log `$HOME/.cache/release034/full.log` only with matching tree and image identities.
2. Root-cause the mechanism: distinguish a product scroll/clamp regression, a changed terminal/Pi runtime behavior, and a fixture read/wait assumption. Use actual frames, event/scroll state and controlled A/B runs. Do not “fix” it by moving the leg to nightly, deleting or weakening the assertion, adding a fixed sleep, increasing a timeout, or accepting a SKIP.
3. Make the smallest repair supported by that mechanism. If it is a fixture wait, wait for a concrete data/frame state with a bounded condition. If it is product code, preserve the existing mouse/page contract and rebuild generated artifacts with the pinned toolchain. If the cause is outside the authorized paths below, stop with `BLOCKED:` and name the exact path/evidence rather than expanding scope.
4. Provide red-before/green-after evidence for the same behavior and a mutation that restores the defect and turns the assertion red again. Run `bash skills/teamsmith/tests/key-replies-pty.sh --all` and `bash skills/teamsmith/tests/smoke.sh --select 63` on the final candidate in the pinned container. If panel source changes, rebuild with `bun install --frozen-lockfile && bash build.sh` in `skills/teamsmith/scripts/panel` and also run `bash skills/teamsmith/tests/smoke.sh --select 26,63` so the committed bundle/source equality is checked. No full gate.
5. Run applicable `bash -n`, `bash skills/teamsmith/tests/section-select.sh --check`, the real-names `ledger-ban.sh`, and `git diff --check`. State exactly what was not rerun (including GitHub Actions).

## Authorized write set and boundaries

- `skills/teamsmith/tests/key-replies-pty.sh`: temporary borrow from dev for this task.
- `skills/teamsmith/tests/smoke.sh`: temporary borrow from dev, only the §63 wiring or its directly related labels; no rescheduling and no assertion weakening.
- `skills/teamsmith/scripts/panel/src/**` and `skills/teamsmith/scripts/lib/cmd-reply.sh`: only if the proven root cause is here.
- `skills/teamsmith/scripts/panel/panel.js`: generated only through the pinned build, never hand-edited.
- `docs/team/reports/P383-dev-bob.md`: your report.

Do not change the CI workflow, section floor/schedules, OpenSpec, other tests, the 60-minute ceiling, or P379's exploration. Do not merge, push, retry public CI or release. Use `distrobox-host-exec podman` from distrobox, never bare `podman`.

## Delivery

Commit the minimal fix and `docs/team/reports/P383-dev-bob.md`. Lead with the root cause and what it changed; include exact tree/image/runtime identities, commands, output tails, before/after and mutation evidence, the final selected-gate counts, and any remaining boundary. Independent verification follows separately.
