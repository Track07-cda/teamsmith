# P44 · pty 夹具的负载前提（propose）— proposal package + the measurements behind it

agent: dev3   status: DONE   time: 2026-09-22T09:40Z
branch: `task/P44-pty-propose`   PR/MR: - (local mode: no push, the branch stays local)

Phase: **propose** (planning only — no `scripts/**`, `tests/**`, `references/**` or `openspec/specs/**` change).
Change: `pty-fixture-load-premise` · deltas: `verification` (MODIFIED) + `panel` (ADDED).
Base revision: `6f3482a` (the P44 brief commit).

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/pty-fixture-load-premise/proposal.md` | why · what changes · the flip · boundaries · acceptance commands · the evidence the apply report must carry |
| `openspec/changes/pty-fixture-load-premise/design.md` | the failure class; the measured table; the three candidate policies and the decision; the constants with their measured bands; the reproduction recipes; the delta placement (policy B); the D33 mapping; coverage/boundaries |
| `openspec/changes/pty-fixture-load-premise/tasks.md` | one apply brief in three batches + one independent verify brief; coverage map (three requirements); path grants; the documented residual; the safe-harness items 2.5–2.6 |
| `openspec/changes/pty-fixture-load-premise/specs/verification/spec.md` | **MODIFIED** `The correctness gate judges correctness only` — the gate-premise rule for fixtures that wait on a real process: attribution at the horizon, visible SKIP, never a pass and never a red for an unattributable exhaustion, the premise is not an escape, the readings are real on the real path (all three base scenarios kept verbatim + four new ones). **ADDED** `A load experiment signals only the processes it started` — the 09:12 rule the brief's append asked for (ownership-based targets, refusal before any signal, no pattern selection, a `CONT` release on `EXIT`/`INT`/`TERM`, reclaimable load, private fixtures) with four scenarios |
| `openspec/changes/pty-fixture-load-premise/specs/panel/spec.md` | **ADDED** `The project-settings pty fixture judges under a machine premise` — the premise line, the progress-aware extension, the attribution, exit status 4, the smoke §38-b/§38-f mapping, the FAST/full split, the injection knobs (fixture switch only) |
| `docs/team/reports/P44-dev3.md` | this report: the raw measurement runs, the scripts, the acceptance tails, the residual risk and the interference note |

## The brief's five questions, answered

1. **Shape of the premise.** Both, in one rule, with the *decision* taken **at the exhaustion** rather than at
   entry (design §2, D-C): the horizons stay failure detectors; while the scene is still painting the wait is
   extended (×`PTY_EXT_FACTOR`); at that ceiling the fixture attributes — still painting / probe over its ceiling
   / load over the coarse guard → a **visible SKIP** (counted, exit 4, nothing after it judged); static scene +
   healthy readings → a **red** with the M59 scene. Trade-off stated in design §2 including the residual: an
   unattributable *static* machine stall with healthy readings still reds, and it is *documented* (the
   alternative — skipping every unattributable exhaustion — would disarm the fixture's ~40 state-reachability
   assertions, which is the false *green* the brief's item 3 forbids).
2. **Where k comes from.** It does not exist, and that is a measured result, not an opinion: the PM's red sample
   (`loadavg ≈ 11`) lies **inside** the band of every green run measured here (2, 8.4–11.3, 12.5–20.0,
   10.5–20.5, 15.7–42.4 = up to 1.33 × cores, with all 32 cores saturated and a fork storm on top — table
   below). No monotone threshold separates them, so the design does **not** use a load-average premise; the load
   line is printed as context and used only by a deliberately coarse guard (`×2.0` cores, outside the measured
   band). The premises that ship are the in-run ones (progress + the code-independent probe) and their bands are
   measured (probe 12–34 ms; ceiling 120 ms) — the probe's *red* side is an explicit calibration item for the
   apply (design §3, tasks 2.3), because no composition in this block reached it.
3. **A regression must stay red.** The reverse fixture is the brief's own example (the view's wheel consumption
   removed in a scratch tree, bundle rebuilt there → the `wheel` scenario exits 1 and names the assertion), and
   it is a *scenario* of both deltas ("A machine under the premise still reds a real regression" /
   "The premise is not an escape from a real regression"). The load-independent nets (§38-d/§38-e pins) stay in
   FAST; a skip is counted and printed and can never be reported as all-green.
4. **FAST/full split.** Unchanged, and a scenario of the `panel` delta pins it: the pty scenarios stay full-gate
   only, FAST keeps its visible skip for them, and the gate's load-independent pins stay in FAST.
5. **D33's terms.** Unchanged: no wall-clock or CPU-share red line enters the gate; the horizons are exactly what
   they were; the premise *removes* machine speed from the verdict (a skip, not a green and not a red); the
   performance suite and its thresholds are untouched (design §5, and tasks 2.2 keeps `gate-guard.sh` green).

## The measured table (the brief's "实测表", as far as this host allowed)

Every row is `bash skills/teamsmith/tests/panel-p21.sh choices` with the **unchanged** knobs unless noted;
`probe` is the code-independent machine probe (`python3 -c pass` + `bash -c true` + `git rev-parse`, 5 rounds,
ms). `nproc=32`, `node v24.19.0`, this worktree's committed `panel.js`, private tmux server per run. The raw
artifacts (fixture logs, per-run metas, 5 s load/procs/iowait/probe samples, the scripts) are committed next to
this report in `docs/team/reports/P44-dev3/`; the probe was added to the sampler from M6 on, so M1/M5 carry
load/procs/iowait only.

| run | composition | loadavg_1m min/mean/max | probe ms | result | wall | artifacts |
|---|---|---|---|---|---|---|
| PM-1 | quiet host (PM, ×2) | ≈ 2 | – | `✓110 ✗0` | – | `docs/team/tasks/P44-…`, `M74-…` |
| PM-2 | busy host (PM, ×3, identical counters) | ≈ 11 | – | `✓48 ✗89` | – | `docs/team/tasks/M74-settings-choice-verify.md:37` |
| M74 | quiet host (verify seat) | 0.9–2.6 | – | `✓110 ✗0` | – | `docs/team/reports/M74-dev.md:236` |
| M1 | ambient team work | 8.41 / 10.00 / 11.12 | 12 | `✓110 ✗0` | 97 s | `docs/team/reports/P44-dev3/m1-default-ambient.log` |
| M5 | **two** sections in parallel | 9.03 / 9.65 / 11.31 | 12–16 | `✓110 ✗0` ×2 | 97 s each | `…/m5a-parallel1.log`, `…/m5b-parallel2.log` |
| M6 | + 8-worker `git`+`python3`+`bash` storm | 12.51 / 17.92 / 20.02 | 13–16 | `✓110 ✗0` | 104 s | `…/m6-storm.log` |
| M7 | + 24 CPU burners (32 cores saturated) | 15.71 / 35.50 / 42.44 | 19–34 | `✓110 ✗0` | 114 s | `…/m7-cpu30.log` |
| M10 | ambient + another tree's live fixture | 10.54 / 15.36 / 20.53 | 13–27 | `✓110 ✗0` | 99 s | `…/m10-trace.log` |
| M11 | ambient, `TEAM_P21_TRACE=1` (rounds histogram) | 6.12 / 8.24 / 9.47 | 11–15 (one 37) | `✓110 ✗0` | 96 s | `…/m11-trace.log` |

Raw tails:

```
# M1 (panel-p21 choices, default knobs)
== 结果 ==  ✓ 110  ✗ 0        rc=0  wall=97s  loadavg min=8.41 median~10.00 max=11.12
# M5 (two concurrent runs, each its own private server)
== 结果 ==  ✓ 110  ✗ 0   (×2)  rc=0  wall=97s each  loadavg min=9.03 mean=9.65 max=11.31
# M6 (storm.sh 8 workers, 300 s)
== 结果 ==  ✓ 110  ✗ 0        rc=0  wall=104s  loadavg min=12.51 mean=17.92 max=20.02
# M7 (burn.sh 24, 420 s)
== 结果 ==  ✓ 110  ✗ 0        rc=0  wall=114s  loadavg min=15.71 mean=35.50 max=42.44
# M10
== 结果 ==  ✓ 110  ✗ 0        rc=0  wall=99s   loadavg min=10.54 mean=15.36 max=20.53
# M11 (TEAM_P21_TRACE=1 — 53 waits traced, rounds needed: 42×1, 8×2, 1×4, 1×6 [the scenario's own negative
#      fixture, whose budget is 6], 1×20 [the panel's cold first frame, budget 80])
== 结果 ==  ✓ 110  ✗ 0        rc=0  wall=96s   loadavg min=6.12 mean=8.24 max=9.47
```

(The `PTY_TRACE=0` line in the M11 meta file is my wrapper printing its own `PTY_TRACE` rather than the
fixture's `TEAM_P21_TRACE`; the trace lines themselves are in the log.)

The horizon's measured slack: with a 40-round base and 1–4 rounds needed for every state wait, a machine would
have to slow the panel by 10–40× before the base horizon even comes close — which is why the design's extension
and attribution, not a bigger constant, is the answer.

The one `等待超时` line that appears in **every** green log above is the scenario's own negative fixture
(`wait_picker_quick TEAM_DEFAULT_MODEL '这条目不存在-硬线自检'`, 6 rounds, deliberately timed out) — not a
machine-driven timeout. Distinguishing it from a real one is exactly why the change's skip line names the wait.

**What the table rules out** (design F1–F3): (a) a load-average premise has no measured crossing — the only red
sample sits inside the green band; (b) the fixture tolerates full CPU saturation with a 10–40× horizon slack
(53 traced waits needed 1–4 rounds against a 40-round base; the probe only rises 12 → 34 ms), so the PM's red was
not a busy-CPU composition; (c) the four reproduction shapes tried here (parallel sections, fork storm, CPU burn,
another fixture's live run) all stayed green, so this block could **not** reproduce the PM's `✓48 ✗89` shape —
stated plainly rather than papered over.

**Where this conflicts with the brief, and why it is not a `BLOCKED:`** — the brief presupposes a load crossing
and asks for a table at load 2/5/11/20 plus a `k` from it. The table exists and its answer is "no crossing on
this host": the red sample sits inside the band of every green run. That is a *negative result about the
instrument*, not a missing dependency, an upstream bug or a boundary violation — and the brief's own question 1
offers the three shapes, so the package is still deliverable: question 2 gets its measured table, and the design
carries the replacement instrument (in-run attribution + the code-independent probe) with the apply's calibration
item (tasks 2.3) as the place where a red side and a final constant are expected. The PM may of course decide the
replacement is not what they want — that is a decision for the proposal review, not a reason to hand the task
back with no artifact.

## Scripts (verbatim, for the apply's calibration and the verify's red sides)

```bash
# probe.sh <tree> [rounds] — the code-independent machine probe (ms per round of python3+bash+git)
n="${2:-6}"; t0=$(date +%s%N)
for _ in $(seq 1 "$n"); do
  python3 -c 'pass' >/dev/null 2>&1; bash -c 'true' >/dev/null 2>&1
  git -C "$tree" rev-parse --quiet HEAD >/dev/null 2>&1
done
printf '%s\n' $(( ($(date +%s%N) - t0) / 1000000 / n ))
```

```bash
# storm.sh <workers> <seconds> [tree] — the "team is working in parallel" shape: each worker loops
# git status + python3 + bash (the same spawn shape the gates produce)
work() { local n=0; while [ $(( $(date +%s) - start )) -lt "$secs" ]; do
    git -C "$tree" status --porcelain >/dev/null 2>&1
    python3 -c 'import json;json.dumps([1,2,3])' >/dev/null 2>&1
    bash -c 'true' >/dev/null 2>&1; n=$((n+1)); sleep 0.02; done; printf '%s\n' "$n"; }
# (8 workers raised loadavg from ~10 to ~18 with ~300 processes; full script in /tmp/p44-load/storm.sh)
```

```bash
# burn.sh <n> <seconds> — n CPU burners; 24 of them took this 32-core host to loadavg 42–48
# (their loop shells out to `date`, which is why the load runs above n)
```

```bash
# blackout.sh <freeze_s> <owner_pid> <pid>… — SIGSTOP/SIGCONT on the fixture's panel: the machine-side
# stall with healthy readings. The compliant version (in docs/team/reports/P44-dev3/blackout.sh):
#   · targets are given, never matched — a pattern-shaped, empty or non-numeric target is refused (exit 2)
#     before any signal is sent;
#   · every target must be the owner or a descendant of it (the ppid chain from /proc/<pid>/stat);
#   · the hold is `sleep & wait` (a foreground sleep defers bash's traps) and an EXIT/INT/TERM trap CONTs
#     every PID this run actually stopped, so nothing is left in state T.
# Its ten-sided guard test: bash docs/team/reports/P44-dev3/blackout-guard.selftest.sh   # ✓ 10 ✗ 0
```

## Interference note (my own, reported in full) and the rule it produced

The first `blackout.sh` run (M8) froze **three** panel processes for 60 s because its pattern matched every
fixture run on the host, not just mine — two of them belonged to other worktrees (`/tmp/p42-mut` = the PM's P42
verification, and the main worktree's fixture). Up to the point where I stopped that run its own section read
`✓70 ✗0` with no wait timeout (so the freeze did not produce the red it was meant to bound), and every
process was verified afterwards as `S` (none left `T`/stopped). I notified the PM
(`team notify pm` at 2026-09-22T09:13Z) naming the affected PIDs and saying that a `panel-p21 groups/wheel` red
in that window (loadavg 27, probe 13 ms) would have been my interference and should be re-run. The script is
killed, and the residual-risk statement in `design.md` §2/§4 now says the stall shape is **unmeasured**, because
this attempt did not complete.

The PM then appended the rule to the brief (09:12 append) and required it as a **falsifiable requirement** in the
proposal — it is `verification#A load experiment signals only the processes it started` (design §4b, tasks 2.5–2.6),
and the compliant script and its guard test ship in this bundle:

```
$ bash docs/team/reports/P44-dev3/blackout-guard.selftest.sh
== 1 · green side: the experiment freezes its own child, and the trap releases it ==
  ✓ own child is stopped while the experiment holds it (643191 → 643198)
  ✓ released when the hold ends (state 'S')
== 2 · the hold is interruptible: SIGTERM mid-hold still releases (nothing left in T) ==
  ✓ own child is stopped mid-hold (state T)
  ✓ TERM released it (state 'S')
== 3 · red side: a process the experiment did not start is refused before any signal ==
  ✓ refused with status 2
  ✓ the refusal names ownership: blackout: refusing 653876 — not the owner (653874) nor a descendant of it; this experiment signals only what it started
  ✓ the foreign process is untouched (state 'S')
== 4 · red side: a target shaped like a pattern, an empty list and self are refused ==
  ✓ a pattern-shaped target is refused (status 2, no host-wide matching exists)
  ✓ an empty target list is refused (status 2)
  ✓ signalling itself is refused (status 2)
== 结果 ==  ✓ 10  ✗ 0
```

The apply grows the same primitives into `skills/teamsmith/tests/load-experiment.sh` with a `--guard-test` wired
into a cheap smoke section (tasks 2.5–2.6), so the rule is checked on every gate run rather than by convention.

## Acceptance (real output)

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/pty-fixture-load-premise
Totals: 19 passed, 0 failed (19 items)
```

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null; echo rc=$?
  SKIP（FAST 模式） 38-b·panel-p21-choices —— panel-p21.sh choices 要真 tmux 场地 + 真 bundle（慢段 ~2.5 分钟）
  ✓ 38-c pty-wait 自检全绿（ ✓ 12 ✗ 0；中间帧注入 + 清理守卫 + 失败现场）
  ✓ 38-d 交互路径没有 awaited 读取（App.tsx 只在 settle 后用 refreshSettingsSoon）
  ✓ 38-e 滚轮消费：设置视图的分支在页面滚动之前（scrollSettings 先于 updateScroll，不穿透）
  ✓ 38-e 翻转：删掉 scrollSettings(delta) → pin 红（滚轮会落回页面滚动）
  SKIP（FAST 模式） 38-f·panel-p21-settings-groups-wheel —— panel-p21.sh groups/settings/wheel 要真 tmux 场地 + 真 bundle（慢段 ~2 分钟）
== 结果 ==  ✓ 2315  ✗ 0
FAST 模式：跳过 29 个真进程段落（…|38-b·panel-p21-choices|38-f·panel-p21-settings-groups-wheel）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿
rc=0
```

(45-line tail + the §38 lines: `docs/team/reports/P44-dev3/smoke-fast-p44.tail.txt`. The two sections this
change touches are both *loaded* by the gate exactly as today — §38-c's self-test and the §38-d/§38-e pins run in
FAST, §38-b/§38-f skip visibly because the pty scenarios are full-gate-only.)

```
$ git status --porcelain            # after this report's own commits, on task/P44-pty-propose
(empty)
```

## Delta → requirement → fixture map

| delta | capability | requirement | op | review method (how a reviewer re-checks it) |
|---|---|---|---|---|
| `specs/verification/spec.md` | `verification` | `The correctness gate judges correctness only` | MODIFIED (3 base scenarios kept verbatim + 4 new) | inject the over-premise reading → `panel-p21.sh choices` exits 4 and §38-b prints SKIP with the gate still 0; remove the wheel consumption in a scratch tree → exit 1; run with the fixture switch off → the injected value is printed as ignored and the real one is used; `bash skills/teamsmith/tests/gate-guard.sh` stays green |
| `specs/verification/spec.md` | `verification` | `A load experiment signals only the processes it started` | ADDED (4 scenarios) | `bash docs/team/reports/P44-dev3/blackout-guard.selftest.sh` (✓10 ✗0): owned target freezes then releases, `TERM` mid-hold releases, an unowned PID and a pattern-shaped target are refused (status 2) with the target untouched; the apply version is `tests/load-experiment.sh --guard-test` inside a cheap smoke section (tasks 2.5–2.6) |
| `specs/panel/spec.md` | `panel` | `The project-settings pty fixture judges under a machine premise` | ADDED (6 scenarios) | run the fixture with the fixture switch and each knob and read its premise line / exit status / summary (0/1/4); run `tests/lib/pty-wait.sh --self-test` and its `--break=` stages for the extension and the static case; run `TEAM_SMOKE_FAST=1 smoke.sh` for the split and the pins |

Trial archive (checked here, before the PM's review): `cp -r openspec /tmp/trial/... && (cd /tmp/trial && openspec archive -y pty-fixture-load-premise)`
reports `verification: + 1 added / ~ 1 modified`, `panel: + 1 added`; in the trial copy
`openspec/specs/verification/spec.md` goes from 31 to 39 scenarios and 12 to 13 requirements (the three base
scenario names still appear exactly once each) and `openspec/specs/panel/spec.md` from 34 to 35 requirements /
163 to 169 scenarios. Note the layout the CLI needs: the spec root must be a directory **named
`openspec`** (`/tmp/trial/openspec/...`), not the contents of `openspec/` copied directly into `/tmp/trial` —
the latter answers "No active changes exist in this root".

## What the apply must not lose (the hand-off)

- The base horizons and their sites are **unchanged** (only the verdict handling around them moves).
- A skip is printed, counted, never all-green and never a failure; the gate's exit status is unaffected.
- The wheel regression stays red on a quiet host (the flip in both deltas).
- The FAST/full split and §38-d/§38-e's pins are untouched; `gate-guard.sh` stays green (no perf marker).
- The probe's ceiling ships **with its measured band**, and the calibration item (tasks 2.3) records the red
  side or says it is unmeasured — no constant is presented as calibrated without its band.
- Every calibration run goes through the safe harness (tasks 2.5–2.6): owned load, owned freezes, private roots,
  and `--guard-test` in the gate. The 09:12 shape (a pattern-matched `SIGSTOP` reaching another seat's fixture)
  must not be reachable from any script this change leaves behind.
