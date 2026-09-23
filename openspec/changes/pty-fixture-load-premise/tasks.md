# Tasks: `pty-fixture-load-premise`

Planning only — nothing in this file is executed by the propose task (P44). **One apply brief** (two verifiable
batches, landed in order) plus **one independent verify brief** (a different agent). The change touches two
capabilities: `verification` (the gate's premise rule, **MODIFIED**) and `panel` (the fixture's own premise,
**ADDED**).

Coverage map (requirement → items): **verification#The correctness gate judges correctness only** → 1.1–1.7,
2.1–2.3, 3.1–3.3; **verification#A load experiment signals only the processes it started** → 2.5–2.6, 3.2;
**panel#The project-settings pty fixture judges under a machine premise** → 1.1–1.7, 2.1–2.4, 3.1–3.3. Every item
names the capability it moves; no item is an orphan.

Batches: **B1** — the engine and the fixture (1.x), observable from
`bash skills/teamsmith/tests/panel-p21.sh choices|groups|wheel` on a quiet host; **B2** — the gate wiring and
the calibration (2.x); **B3** — the gate run and the evidence (3.x). 1.x must land before 2.x (the gate maps an
exit status the fixture does not yet produce otherwise).

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/tests/panel-p21.sh` and
`skills/teamsmith/tests/lib/pty-wait.sh` are `agent:dev`'s; `skills/teamsmith/tests/smoke.sh` is the **gate
file** and needs an explicit grant in the brief; `skills/teamsmith/scripts/**` and
`skills/teamsmith/references/**` are PM-owned and are **not** needed by this change; `openspec/**` stays with the
phase's owner; `docs/team/**` stays PM-owned.

Fixture notes: every fixture keeps clearing inherited team identity; the pty fixture keeps its private tmux
server and its argv-logging wrapper; the premise's injection knobs are honored **only** under
`TEAM_SMOKE_FIXTURE=1` and are printed as ignored otherwise (the `tests/panel-cpu.sh` precedent); the
calibration runs use the report's scripts (`storm.sh`, `burn.sh`, `probe.sh` — verbatim in
`docs/team/reports/P44-dev3.md`) and are never required for a gate run to pass.

Documented residual (design §2, not fixed here): a machine-side stall that is **static** for longer than the
extended ceiling **and** leaves the load/probe readings under their premise still produces a red; the change
prints the readings and the frozen scene for it, and the coarse guard covers the gross-overload half. Items
below must **not** widen the premise to swallow that case silently.

## 1. B1 — the fixture judges under a premise (`panel` ADDED)

- [x] 1.1 `tests/lib/pty-wait.sh`: the horizon gains its extension — while the masked capture changed within the
  last `PTY_STALL_ROUNDS` (default 8) rounds, keep polling up to `PTY_EXT_FACTOR` (default 3) × the base; the
  timeout report carries the fields the attribution needs (rounds used, elapsed time, still-painting yes/no).
  Verify: `bash skills/teamsmith/tests/lib/pty-wait.sh --self-test` stays green **and** gains two `--break=`
  stages — `noext` (extension disabled → a painting scene times out at the base horizon) and `alwaysext` (a
  *static* scene extended → the self-test's static case must fail) — both red tails in the report.
- [x] 1.2 `tests/lib/pty-wait.sh`: the attribution — at the ceiling the engine calls the caller's premise hook;
  over the premise → a `skip` outcome (one visible line, no failure, no later assertion of that scenario); under
  it → the existing failure with the M59 scene. Verify: the self-test's two injected cases report `SKIP 1 ✗ 0`
  and `✗ 1` respectively (tails in the report).
- [x] 1.3 `tests/panel-p21.sh`: the premise line before every scenario's first assertion — the real
  `loadavg_1m`/`loadavg_5m`, the core count (`nproc`, else `getconf _NPROCESSORS_ONLN`), the code-independent
  probe value in ms (fixed micro-workload: `python3 -c pass`, `bash -c true`, `git rev-parse`), and both
  ceilings. Verify: `bash skills/teamsmith/tests/panel-p21.sh choices` prints one premise line per scenario with
  the real values; with `TEAM_SMOKE_FIXTURE=1 TEAM_P21_PREMISE_PROBE_MS=999` the injected value is honored; with
  the switch **off** the injected value is printed as ignored and the real one is used.
- [x] 1.4 `tests/panel-p21.sh`: the skip accounting and the exit status — a skipped scenario stops at that wait,
  is counted in `== 结果 ==`, prints one `SKIP` line naming the wait, its rounds, its elapsed time, the readings
  and the scene, and the fixture exits **4** with no failure (1 with a failure, 0 green, 3 setup — unchanged).
  Verify: the over-premise injection → exit 4 with a non-zero skip count and no `✗`; without it → exit 0.
- [x] 1.5 `tests/panel-p21.sh`: the coarse entry guard (`TEAM_P21_PREMISE_LOAD_FACTOR`, default 2.0) skips before
  the first wait of a scenario and prints the same premise line. Verify: with `TEAM_SMOKE_FIXTURE=1
  TEAM_P21_PREMISE_LOAD_FACTOR=0.01` the scenario skips at entry and exits 4.
- [x] 1.6 `tests/panel-p21.sh`: the wheel regression stays a **red**, not a skip, on a quiet host. Verify: in a
  scratch tree whose panel sources lost the wheel consumption, with the bundle rebuilt there,
  `bash skills/teamsmith/tests/panel-p21.sh wheel` exits 1 and names the failing assertion; the same command
  against the unmodified tree exits 0 — both tails in the report (the flip).
- [x] 1.7 The FAST/full split and the load-independent pins are untouched. Verify: `TEAM_SMOKE_FAST=1 bash
  skills/teamsmith/tests/smoke.sh </dev/null` still prints §38-b and §38-f as visible skips with their reasons,
  and §38-d/§38-e still run (and their `--break`/flip sides still fail).

## 2. B2 — the gate maps it, and the calibration lands (`verification` MODIFIED)

- [x] 2.1 `tests/smoke.sh` §38-b/§38-f: map the fixture's exit status — 0 → the all-green line (as today),
  1 → the failure line (as today), **4 → a visible `SKIP（条件不满足）` line carrying the fixture's reason and
  readings**, 3 → a setup failure (as today); a skipped scenario must never be printed as all-green. Verify: the
  over-premise injection makes the section print `SKIP` and leaves the gate green; forcing the fixture's exit to
  1 prints the failure line (both tails in the report).
- [x] 2.2 The gate's own promise stays honest: no wall-clock or CPU-share judgment is added anywhere and the
  sections keep their split. Verify: `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` green
  plus `bash skills/teamsmith/tests/gate-guard.sh` green (the perf-marker guard).
- [x] 2.3 The calibration table, produced with the report's scripts **through the safe harness of 2.5** (owned
  load, owned freezes, private roots): a quiet row, at least one load row (`storm`/`burn`) and at least one
  over-premise row — each with the readings, the result, the wall time and, for a red row, which wait exhausted
  its horizon. Re-derive `PTY_PREMISE_PROBE_MS` and
  `PTY_PREMISE_LOAD_FACTOR` from the measured bands by the design's method (the constant sits **outside** the
  band where the fixture judges) and state the bands next to the constants. Verify: the table with its raw tails
  is in the report, the constants match the table's bands, a band-below run exits 0 and an over-premise run
  exits 4.
- [x] 2.4 The premise's reason, its constants and their bands, and the reproduction recipe are documented where
  the fixture lives (`tests/panel-p21.sh` and `tests/lib/pty-wait.sh` headers). Verify: `grep -n 'premise'
  skills/teamsmith/tests/panel-p21.sh skills/teamsmith/tests/lib/pty-wait.sh` shows constants plus bands plus
  the recipe (and copies no requirement text).
- [x] 2.5 `tests/load-experiment.sh` (dev) — the safe experiment primitives every calibration uses: a freeze that
  targets **only the owner's process subtree** (it walks `/proc/<pid>/stat`'s ppid chain and refuses any
  target that is neither the owner nor a descendant of it, printing the refusal and exiting 2 **before** a
  signal; there is no code path that selects targets by name/command-line pattern), an interruptible hold
  (`sleep & wait`, because a foreground `sleep` defers bash's traps) and an `EXIT`/`INT`/`TERM` trap that
  `CONT`s every PID it stopped; plus owned-load helpers (spin processes) and the private-root/socket
  convention. Verify: `bash skills/teamsmith/tests/load-experiment.sh --guard-test` green with the ten sides of
  `docs/team/reports/P44-dev3/blackout-guard.selftest.sh` (owned target freezes and releases; `TERM` mid-hold
  releases; an unowned PID and a pattern-shaped target are refused with the target's state unchanged) — paste
  the tail.
- [x] 2.6 `tests/smoke.sh` (gate grant) — one cheap section that runs `load-experiment.sh --guard-test`, so the
  rule is falsifiable on every gate run (FAST included; the section starts only its own `sleep` children and
  touches no other process). Verify: `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` green
  with the section's line, and a scratch copy whose freeze loses its ownership check makes that section red.

## 3. B3 — gate and evidence

- [x] 3.1 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` and `TEAM_SMOKE_FAST=1 bash
  skills/teamsmith/tests/smoke.sh </dev/null`, then the **full** gate once (the slow pty sections) — paste the
  tails; `git status --porcelain` clean.
- [x] 3.2 Trial archive on a scratch copy (`cp -r openspec /tmp/trial && (cd /tmp/trial && openspec archive -y
  pty-fixture-load-premise)`) — proves the MODIFIED `verification` requirement kept its three base scenarios and
  the ADDED `panel` block merges without a name collision (the open `settings-view-groups` change carries `panel`
  deltas too).
- [x] 3.3 The report's evidence: the delta→requirement map, the requirement→item and scenario→fixture maps, the
  calibration table with its tails, the flips (extension, skip, wheel regression) and the statement that no
  wall-clock/CPU-share red line entered the gate.

## 4. V — independent verification (a different agent)

- [x] 4.1 Rerun, out of tree and on the apply's tip: the calibration table's rows (one quiet, one over-premise),
  the wheel flip, `openspec validate --all --strict` and the full gate; record every scenario of both deltas as
  exercised with red/green evidence in `docs/team/reviews/<ID>.md` (a PASS carrying findings is rework).

> **PM 勾选说明（2026-09-22）**：propose=P44 · apply=P48（dev3）· verify=P52（dev2，PASS；并给出 CI 那条 choices 红的决定性归因）—— 全部任务项落实。
