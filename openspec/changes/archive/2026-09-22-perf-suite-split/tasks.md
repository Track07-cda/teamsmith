# Tasks: `perf-suite-split`

Planning only — nothing here is executed by the propose task. The batches below become **three apply briefs**:
**A1 = B1 + B2** (the suite exists and the gate stops judging: `tests/**` — every requirement's behavior change
lands here), **A2 = B3 + B4** (entry, docs, doctor and CI: `scripts/**`, `SKILL.md`, `references/**`,
`.github/workflows/**`, `docs/team/PUBLISH.md`), then **B5** is the PM's gate/trial-archive step. B1 → B2 is a
hard order (the guard in B2 asserts markers B1 creates); B3/B4 depend on B1 only for the command name.

Coverage map (requirement → items): R1 (the correctness gate judges correctness only) → 2.1–2.3, 5.1; R2 (the
performance suite) → 1.1–1.8, 3.1, 3.2, 5.2, 5.4; R3 (correctness coverage kept) → 2.1, 2.2, 5.3; R4 (CI) →
4.1–4.2; R5 (docs/doctor) → 3.3–3.6; R6 (frozen semantics) → 1.1, 1.4, 1.7, 5.4. Every guard needs a red →
restore-green flip in its apply report; the perf suite's own self-tests are the evidence that its judgment did
not turn vacuous.

Path grants an apply brief must state (OWNERSHIP): `skills/teamsmith/tests/**` is `agent:dev`'s;
`skills/teamsmith/scripts/**`, `SKILL.md` and `references/**` are **PM-owned** and need an explicit per-brief
grant (A2); `.github/workflows/**` and `docs/team/PUBLISH.md` are PM-owned (A2; the PM may edit PUBLISH.md
itself instead of granting it); `openspec/changes/perf-suite-split/**` belongs to the phase's owner;
`openspec/specs/**` and the rest of `docs/team/**` stay PM-owned.

Fixture notes: every new fixture clears inherited team identity (`TEAM_*`, `TMUX`, `TMUX_PANE`, `TMUX_TMPDIR`),
writes only inside its scratch dir, and uses a private tmux socket (`-L`) for anything that starts a pane. The
container path reuses the pinned image (`ci/Containerfile`); a missing engine or image is a printed reason plus a
visible SKIP, never a silent host run presented as the reference.

## 1. B1 — the performance suite (`verification` R2/R6, `panel` R6)

- [x] 1.1 `tests/perf.sh` (new): the three judgments move in verbatim — interactive first frame (< 2000 ms,
  premise 0.25, median of three, all samples printed), frame assembly line (≤ 2000 ms, premise 0.75, median of
  five `team monitor --print --no-activity` samples), steady-state pane CPU (< 1 %, premise 0.25, median of
  three sub-windows) — with the thresholds as named single-source constants (`PERF_FRAME_BUDGET_MS=2000`,
  `PERF_CPU_MAX_PCT=1`, the factors) and no change to any number. Verify: `bash skills/teamsmith/tests/perf.sh`
  prints the three verdict lines.
- [x] 1.2 `tests/perf.sh`: the environment self-description before the verdicts (host/container, visible cores
  with any override named, `cpu.max` quota or its absence, loadavg, JS runtime and tmux versions, `git rev-parse
  --short HEAD`). Verify: the header block on a host run and a container run.
- [x] 1.3 `tests/perf.sh`: exit codes 0 / 2 / 3 / 4 with red dominating skip, and a summary table naming every
  judgment's verdict, median, samples and premise; a skip is counted and printed, never reported as green.
  Verify: the self-tests of 1.4.
- [x] 1.4 `tests/perf.sh` self-tests (falsifiability): `TEAM_PERF_FIXTURE=1` with `TEAM_PERF_FRAME_DELAY_MS`
  → red; with `TEAM_PERF_LOADAVG` above the premise → visible SKIP; the premise boundary cases (`== factor ×
  cores` holds, `+0.1` does not); real path ignores every injected knob and prints the notice. Verify: the
  self-test tails (all four), and that the suite is not always green.
- [x] 1.5 `tests/perf.sh`: own lock `TEAM_PERF_LOCK` (same `flock --close -w` + holder pattern, wait cap
  `TEAM_PERF_LOCK_WAIT`), never `TEAM_SMOKE_LOCK`; a read-only non-blocking probe of the smoke lock prints the
  holder and a notice when the correctness gate is running. Verify: two concurrent runs serialize (second prints
  the holder), and a held smoke lock does not block the perf run.
- [x] 1.6 `tests/perf.sh`: container mode — `--container` runs the same script inside the `ci/Containerfile`
  image through an available engine (honoring an engine override for the distrobox case); a missing engine or
  image prints the reason and the exact build/run command and produces a visible skip (exit 4), never a silent
  host run labelled as the reference; `--host` runs locally and labels the run as not the reference. Verify: one
  `--container` run and one `--host` run, both tails pasted.
- [x] 1.7 `tests/panel-cpu.sh`: add the premise-only mode (`TEAM_PANEL_CPU_PREMISE_ONLY=1`): print the premise
  line and the ignore notice for every injected `TEAM_PANEL_CPU_*` knob, exit 0, start no tmux/node/JS. Verify:
  the mode's output with all three knobs set and with the fixture switch off contains the three notices and a
  premise line with the real readings; `timeout 10` wrap shows it starts no pane.
- [x] 1.8 `tests/panel-cpu-premise.sh` stays the driving fixture of the measurement cases, invoked by
  `tests/perf.sh` (its four expectations, its finding→exit-4 semantics and its anti-backdoor assertions
  unchanged). Verify: the suite's tail shows the fixture's `== 结果 ==` line.

## 2. B2 — the correctness gate stops judging and gains the guard (`verification` R1/R3)

- [x] 2.1 `tests/smoke.sh` §27-d: delete the sample loop, the median, `p27_assembly_judge`, its self-check, the
  injection knob and the 0.75 premise block — i.e. every marker of the perf judgment; **keep** the JSON-shape
  assertion and every §27-a/b/c section byte-for-byte. Verify: `grep -n '2000\|p27_assembly\|TEAM_SMOKE_FRAME_DELAY_MS'` finds no judgment left, and the kept sections' tails are unchanged.
- [x] 2.2 `tests/smoke.sh` §35/§36: replace the judgment fixtures with the time-independent knob-integrity check via a
  new `tests/panel-knobs.sh` (sets the three `TEAM_PANEL_CPU_*` knobs with the fixture switch off, runs
  `panel-cpu.sh` in premise-only mode, asserts the three ignore notices and the real premise readings, judges no
  duration); the measuring fixtures are no longer invoked by the gate, and `smoke.sh` never names them. Verify:
  the rewritten section's tail, plus a run with `TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_FRAME_DELAY_MS=2600` staying green.
- [x] 2.3 `tests/smoke.sh`: a new pure-logic guard section (runs in FAST and full) asserting all three directions —
  the gate's own file carries no perf marker (`PERF_FRAME_BUDGET_MS`, `PERF_CPU_MAX_PCT`, a budget/CPU-share
  comparison) and invokes no measuring fixture (`panel-cpu.sh`, `panel-cpu-premise.sh`, `perf.sh`);
  `tests/panel-knobs.sh` exists and invokes the premise-only mode (not `panel-cpu-premise.sh`); and
  `tests/perf.sh` carries the markers. Verify: the guard's tail, and its red under each break (5.1).
- [x] 2.4 Keep the FAST/full classification and the 14c self-audit consistent (a removed section is no longer in
  the skip lists; the new guard runs in both modes; the guard section does not break `SKIP_N` accounting).
  Verify: `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` green with a coherent skip list.

## 3. B3 — entry, docs and doctor (`verification` R2/R5)

- [x] 3.1 `scripts/lib/cmd-docs.sh`: `team perf` front door next to `team_cmd_smoke` (passes `--host` /
  `--container` through), `team help` listing the command. Verify: `team perf --help` (or the equivalent) and
  `team help | grep perf`.
- [x] 3.2 `scripts/lib/cmd-project.sh`: `team doctor` gains a `perf suite` check — present → `pass` with the
  command; absent → `warn` with the actionable next step; never a hard failure. Verify: the doctor tail in a
  full tree and in a scratch tree with `tests/perf.sh` removed.
- [x] 3.3 `SKILL.md`: the command table and the deeper-reading row name `team perf`; one paragraph states the
  division (correctness on every change, performance separately and before a release) with both copy-pasteable
  commands. Verify: `grep -n 'team perf' skills/teamsmith/SKILL.md`.
- [x] 3.4 `references/protocol.md` §9b-2: rewrite the gate paragraph — the correctness gate judges no wall-clock
  line; the three numbers, their premise and the medians belong to the performance suite; its lock is
  `TEAM_PERF_LOCK` and it never takes the gate lock; the gate lock accounting is unchanged. Verify:
  `grep -n 'team perf\|TEAM_PERF_LOCK' skills/teamsmith/references/protocol.md`.
- [x] 3.5 `references/workflows.md`: the runbook names the two commands in their places (everyday gate;
  pre-release performance run). Verify: `grep -n 'perf' skills/teamsmith/references/workflows.md`.
- [x] 3.6 `docs/team/PUBLISH.md` (PM-owned; PM edits or grants): the release checklist names the performance
  command with the container invocation and where its measured numbers are recorded. Verify:
  `grep -n 'perf' docs/team/PUBLISH.md`.

## 4. B4 — CI as two independent conclusions (`verification` R4)

- [x] 4.1 `.github/workflows/gates.yml`: keep the correctness job's command byte-for-byte; add a separate
  `perf` job that runs `bash skills/teamsmith/tests/perf.sh` in the same pinned image on its own runner, with
  the perf step marked `continue-on-error: true` so its red is visible in the log without failing the
  correctness conclusion; no merge-blocking path is added. Verify: reading the workflow (the delta's scenario)
  plus `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/gates.yml'))"` (syntax).
- [x] 4.2 The pre-release record of 3.6 names the container run; the apply report pastes one real container
  suite tail (the numbers that would be recorded). Verify: the report's tail.

## 5. B5 — flips and independent evidence (apply report; verify phase re-runs them)

- [x] 5.1 Guard flip: reintroduce the §27-d judgment into `smoke.sh` → guard red; remove the markers from
  `perf.sh` → guard red; restore both → green. Verify: all six tails in the report (three red, three green).
- [x] 5.2 R1 flip: on the pre-change revision `TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_FRAME_DELAY_MS=2600
  TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh` is red at 27-d; on the branch the same command exits 0
  and the same injection through `TEAM_PERF_FIXTURE=1 TEAM_PERF_FRAME_DELAY_MS=2600 bash
  skills/teamsmith/tests/perf.sh` is red (exit 2) with the numbers. Verify: the four tails.
- [x] 5.3 R3 flips (one at a time, restore after each): delete the knob-ignore assertion → gate red; delete a
  §27-b block-isolation assertion → gate red; delete §34's queue-accounting scenario → gate red. Verify: each
  red/green pair.
- [x] 5.4 R6 check: diff the three thresholds, the two factors and the exit-4 semantics against the pre-change
  tree (`git diff fd4fcf6 -- skills/teamsmith/tests/ | grep -n '2000\|0\.75\|0\.25\|exit 4'`) and show that only
  their location changed. Verify: the diff tail and the suite's own flips (1.4).
- [x] 5.5 Environment evidence: one `--host` run and one `--container` run on the branch, with the
  self-description and verdict lines pasted (the design's §1 table is the pre-change form). Verify: the tails.

## 6. B6 — gates, trial archive and the ledger (PM)

- [x] 6.1 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` and the full
  `bash skills/teamsmith/tests/smoke.sh </dev/null` on the branch — green; paste the tails. Then
  `git status --porcelain` (clean, apart from intentional scratch).
- [x] 6.2 Trial archive on a scratch copy (`cp -r openspec /tmp/trial && (cd /tmp/trial && openspec archive -y
  perf-suite-split)`) — proves the MODIFIED requirement keeps every base scenario and the ADDED requirements do
  not collide with the base `verification` spec. Verify: the trial output.
- [x] 6.3 Independent `opsx-verify` by a different agent: every scenario of both deltas exercised with red/green
  evidence, the two flips of 5.1/5.2 reproduced on an untouched checkout, and the environment evidence read.
- [x] 6.4 The report's evidence: the delta→requirement map for `panel` and `verification`, the
  requirement→item and scenario→fixture maps, every flip's red/green tail, and one line stating that the
  thresholds, the premise factors, the gate lock accounting, `exit 4` and the `refuse`/CAS/write paths were not
  touched.

> **PM 勾选说明（2026-09-21）**：实现/夹具/CI 由 **M58（dev2，squash `7135095`）** 交付；
> PM 复验（`docs/team/reviews/M58.md`，PASS，tip `3968e9c1f`）：全量门禁 `✓2701 ✗0`（643s，性能判定已移出，读数因此比之前少）。
> PM 独立三向翻转：把判定塞回门禁 → 红并点名 `file:line`；把 `perf.sh` 的标记改名 → 红；摘掉 `panel-knobs.sh` → 红；还原 → 绿。
> 复验发现的 F1（`gate-guard.sh` 缺标记时同时打印 `bad` 与 `ok`）已由 dev2 返工修复，修复后 PM 复跑同一翻转确认只剩 `bad`。
> **verify 阶段仍须由另一 agent 完成**（apply = dev2）。

> **PM 勾选说明（2026-09-22）**：apply = **M58（dev2，squash `7135095`）**；
> verify = **M64（verify 席位，`00387fe`）** —— PASS：F1（PUBLISH 发版前性能记录，PM 补 `1576653`）、
> F3（验证侧 harness 误包整个门禁，标准姿势重跑 `✓2703 ✗0` 关闭）、
> F2（`--in-container` 自述可信，三轮修复 M66/M69/M73 + 信任边界 §24）全部关闭。
> 期间由 verify 发现、PM 派单落地的 apply 返工：**M66**（环境信号）、**M69**（镜像标识文件）、**M73**（标识不得是挂载点）。
