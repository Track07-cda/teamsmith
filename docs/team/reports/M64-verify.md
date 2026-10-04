# M64 · perf-suite-split independent verification

agent: verify   status: **PASS — F1/F3 closed; M73 closes every in-scope F2 accidental-misuse shape**   time: 2026-09-22
branch: `task/M64-perf-suite-split-ci`   PR/MR: - (local mode)

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/M64-verify/pkg/run.sh` | Reproducible independent verification package; every mutation works only on a `/tmp` copy. |
| `docs/team/reports/M64-verify/pkg/{10,20,30,40,45,50}-*.sh` | R1–R5 adversarial checks, final M73 protected-main F2 follow-up, and acceptance-gate harnesses. |
| `docs/team/reports/M64-verify/pkg/logs/` | Raw command output, including historical F2 failures and the final M73 mounted-marker flip. |

No implementation path was modified.  Copy-based mutations use a private tmux server; the full smoke gate is deliberately **not** wrapped, because `smoke.sh` must snapshot the caller and prove its own `TMUX_TMPDIR` isolation.  `perl skills/teamsmith/tests/tmux-lint.pl` reports `红 0 条` for the resulting evidence package.

## Verification scorecard

| Dimension | Result | Evidence |
|---|---|---|
| Completeness | 29/29 change tasks checked; 5 delta requirements examined | `openspec instructions apply --change perf-suite-split --json` reports `total: 29, complete: 29`; `openspec validate` is green. |
| Correctness | **PASS** | R1 passes under injected slow frames and F1/F3 remain closed.  M73 rejects missing/altered ENV or marker values and the adversarial foreign-image + exact mounted-token shape before any measurement; the genuine image remains green. |
| Coherence | **PASS (documented boundary)** | M73 makes the accidental-misuse boundary explicit: the process rejects host/old/tampered/mounted shapes, while a caller deliberately controlling the runtime and baking the public token into a self-built image is explicitly out of scope and must be reviewed through the emitted environment self-description. |

### Delta and scenario coverage

| Delta requirement / scenarios | Independent evidence | Result |
|---|---|---|
| `verification` · correctness-only gate: slow-correct, marker return, knob integrity | static scan; `pkg/10-guard-and-knobs.sh`; canonical `pkg/40-slow-correct-full-gate.sh` | PASS: three mutations reject/restore correctly; canonical slow full gate is `2703/0`, emits no performance judgment, and retains the `9/0` knob check. |
| `verification` · separate self-describing perf suite: red, visible skip, host/container, own lock | `pkg/30-perf-modes-and-red.sh`; final protected-main `pkg/45-f2-merged-main.sh` | PASS: red/visible-SKIP/public-container paths remain visible; missing/changed ENV and marker values refuse; M73's foreign-image + caller-mounted exact-token flip is exit 3, names the mounted marker, and emits no reference label. |
| `verification` · CI independently non-blocking and pre-release record | `pkg/20-ci-docs-doctor.sh`; read-only `main@1576653` recheck | CI structure PASS; F1 release-record scenario now PASS on `main`. |
| `verification` · discovery and doctor next step | `pkg/20-ci-docs-doctor.sh` | PASS: `team help` lists `perf`; docs name the split; missing `tests/perf.sh` produces an actionable doctor warning. |
| `panel` · measurement moved, knobs stay fixture-only | guard mutations plus `panel-knobs.sh` | PASS: `panel-knobs.sh` is time-independent and reports `✓ 9 ✗ 0`; the guard rejects its removal. |

## Verification evidence (commands actually run)

### R1/R3 — static split, both guard directions, and retained knob integrity

```text
$ bash docs/team/reports/M64-verify/pkg/run.sh --only 10
prechange-27d-returned (rc=1)
  ✓ R3 mutation 1: returning the pre-change §27-d judge is named as a smoke.sh violation
perf-marker-removed (rc=1)
  ✓ R3 mutation 2: missing perf marker is named and F1 contradictory ok text stays absent
panel-knobs-removed (rc=1)
  ✓ R3 mutation 3: missing panel-knobs.sh is named
panel-knobs-restored (rc=0)
== 结果 ==  ✓ 9  ✗ 0
== M64-10 结果 ==  ✓ 13  ✗ 0 finding 0
== M64 package result == PASS

$ bash skills/teamsmith/tests/gate-guard.sh
ok: smoke.sh 里没有性能判定标记、时长/份额比较，也没有测量夹具的点名
ok: panel-knobs.sh 存在且走 panel-cpu.sh 的 premise-only 模式
ok: panel-knobs.sh 不驱赶测量夹具
ok: perf.sh 带着帧预算 / CPU 份额 / 前提系数的命名单源标记
gate-guard: 三向都过（门禁无判定、旋钮助手在岗、性能套件带标记）
[gate-guard rc=0]
```

Raw output: `pkg/logs/10-guard-and-knobs.log`.

### R2 — self-description, numeric red, and visible reference-image downgrade

```text
$ bash docs/team/reports/M64-verify/pkg/run.sh --only 30
--container: 模式 : container（参考环境：钉死镜像）
  ① 交互首帧 ... → OK
  ② 帧装配线 ... → OK
  ③ 稳态窗格 CPU ... → OK
perf: 三条判定全绿 → exit 0

TEAM_PERF_FIXTURE=1 TEAM_PERF_FRAME_DELAY_MS=2600 ... --container
  ② 帧装配线：... 中位 3045ms ≤ 2000ms ... → RED
perf: 1 条红 → exit 2

TEAM_PERF_IMAGE=teamsmith-gate:definitely-missing-m64 ... --container
!!! 参考环境不可用，本次为宿主判定，结论不作为验收依据（exit 4）!!!
perf: 没有红，但有 3 条可见 SKIP → exit 4（没结论；不是通过）
== M64-30 结果 ==  ✓ 8  ✗ 0 finding 0
```

The exact acceptance host command also ran.  Its exit 2 is a valid host measurement, not a correctness-gate failure:

```text
$ bash skills/teamsmith/tests/perf.sh --host
模式 : host（--host：非参考环境）（非参考环境：结论不作为验收依据）
① 交互首帧 ... median 2387 ... → RED
② 帧装配线 ... 中位 393ms ... → OK
③ 稳态窗格 CPU ... → RED
perf: 2 条红 → exit 2
```

Raw outputs: `pkg/logs/30-perf-modes-and-red.log` and `pkg/logs/acceptance-perf-host.log`.

### R4/R5 — CI, release checklist, discovery and doctor

```text
$ bash docs/team/reports/M64-verify/pkg/run.sh --only 20
jobs=gates,perf
correctness command unchanged and separate
perf step continue-on-error=true
  ✓ R4 workflow structure has independent correctness/perf jobs
  ✓ R5 team help lists the perf command
  ✓ R5 absent perf suite has an actionable next step
  ✗ R4 release checklist does not name a pre-release perf --container run or where to record its numbers
== M64-20 结果 ==  ✓ 13  ✗ 1 finding 0
== M64 package result == FAIL
```

`gates.yml` has independent `gates` and `perf` jobs; the perf step is `continue-on-error: true`, so its red is visible but does not turn the correctness job red.  The workflow is only `main` push/manual dispatch, so it does not add a PR merge block.

The raw package run above predates PM's F1 fix.  I independently read the protected-branch fix rather than treating the PM report as proof:

```text
$ git show 1576653:docs/team/PUBLISH.md
0. 发版前性能记录（perf-suite-split R4，M64 F1）：... 必须在钉死容器里跑一次并记录数值
... bash -c 'bash skills/teamsmith/tests/perf.sh --in-container --tree /work'
判读：exit 0 = 三条红线都过；exit 2 = 有红（不要发）；exit 4 = ... 不作为通过
```

This closes F1 on `main`; the historical pre-fix output remains retained for audit.  Raw output: `pkg/logs/20-ci-docs-doctor.log`.

### OpenSpec and full correctness-gate acceptance

```text
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 18 passed, 0 failed (18 items)
[openspec rc=0]

$ TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_FRAME_DELAY_MS=2600 \
    bash skills/teamsmith/tests/smoke.sh </dev/null
== 35 · 门禁只判正确性：性能判定守卫 + 旋钮完整性（M58 · perf-suite-split） ==
  ✓ 35 守卫：门禁无性能判定标记、无测量夹具点名；旋钮助手与性能套件标记两侧都在
  ✓ 35 旋钮完整性（时间无关）： ✓ 9 ✗ 0
  ✓ M28 容器自检：容器内裸 tmux 开窗/杀 server 正常，宿主 server 指纹逐字节不变
== 结果 ==  ✓ 2703 ✗ 0
smoke 全绿
[rc=0]
== M64-40 结果 ==  ✓ 4 ✗ 0 finding 0
```

The two prior red full-gate runs were caused by this verification package placing `private_tmux` (a forced `-L`) around the **whole** gate.  That overrode smoke's own `TMUX_TMPDIR` fixture server and made the resulting §12b-h cascade invalid as implementation evidence.  I removed the wrapper from both full-gate package sections, preserved the normal caller environment, and reran §40 for 858.5 seconds.  The canonical run above is green, contains no assembly/CPU verdict, retains §35, and also passes M28.  A separate immediate `container-tmux.sh --selftest` also passed with byte-identical before/after host fingerprints.

Raw outputs: `pkg/logs/40-slow-correct-full-gate.log` and `pkg/logs/m28-container-selftest-after-standard.log`.

After M73, `main` received an unrelated M68 static smoke segment.  Rather than treating the prior full run as current by assertion, I reran the standard protected-main command after that merge:

```text
$ (cd <protected-main> && bash skills/teamsmith/tests/smoke.sh </dev/null)
== 35 · 门禁只判正确性：性能判定守卫 + 旋钮完整性 ==
  ✓ 35 守卫 …；✓ 35 旋钮完整性： ✓ 9 ✗ 0
  ✓ M28 容器自检 … 宿主 server 指纹逐字节不变
  ✓ 38-d … 交互路径没有 awaited 读取（M68 新增静态段）
== 结果 ==  ✓ 2804 ✗ 0
smoke 全绿
[rc=0]
```

Final protected-main raw output: `pkg/logs/40-final-protected-main-full-smoke.log`.

### F2 — direct `--in-container` finding and M66/M69/M73 protected-main follow-ups

```text
$ bash skills/teamsmith/tests/perf.sh --in-container
模式 : container（参考环境：钉死镜像）（参考环境）
JS 运行时 : <home>/.local/bin/node v24.19.0
 tmux      : .../skills/teamsmith/scripts/shim/tmux tmux 3.7b
① 交互首帧 ... median 3408 ... → RED
② 帧装配线 ... 中位 389ms ... → OK
③ 稳态窗格 CPU ... → RED
perf: 2 条红 → exit 2
```

No engine/image was invoked in this direct command, yet it calls the development-host node and tmux shim while declaring itself the pinned reference container.

M66 closed only the absent/mismatched-ENV shape.  Its first protected-main follow-up proved the remaining host-export bypass shown above, so M69 added the byte-exact rootfs marker.  The next independent flip then proved that a caller could bind-mount that public token, which led to M73.

The final `pkg/45-f2-merged-main.sh` run exercised protected `main@311fe6023fbd`, which contains M73 `e43c7a2` and the exact reviewed `perf.sh`, `Containerfile`, and §24 troubleshooting bytes.  It uses uniquely tagged temporary images and changes neither checkout:

```text
bare host --in-container, no ENV                         → exit 3; names missing proofs; no mode header
host ENV=0                                               → exit 3; names incorrect ENV; no mode header
host ENV=1 + fake engine                                 → exit 3; names missing /etc/teamsmith-gate-image; no mode header
fresh actual image, ENV overwritten to 0                 → exit 3; names incorrect ENV; no mode header
fresh actual image, wrong marker bind-mounted            → exit 3; names byte-exact mismatch and mounted marker; no mode header
foreign fixture, baked marker removed                    → exit 0 (fixture validity)
foreign fixture + caller-mounted exact token + ENV=1     → exit 3; names identity proof ③ and “标识文件是挂载的”; no mode header
fresh M73 image + public --container                     → /usr/local/bin/node, /work, 3 green, exit 0
--host                                                    → explicitly non-reference; exit 2 on this host's visible red measurement
TEAM_SMOKE_FAST=1 bash smoke.sh </dev/null               → 2294/0, exit 0
```

M73's in-scope adversarial flip is the original failing shape: a **foreign** image derived from the fresh image has `/etc/teamsmith-gate-image` removed (separately verified with `test ! -e`), then the caller bind-mounts a new file containing the exact public bytes `teamsmith-gate:1\n` and exports the ENV signal.  M73 reads `/proc/self/mounts`, refuses it before setup with exit 3, names the mounted marker, and never prints a reference label.  This resolves the concrete F2 false self-description.

The independently checked §24 documents the agreed trust boundary: accidental host/export/stale/tampered/mounted shapes are in scope and refused; a runtime owner deliberately baking the public token into a self-built image (or falsifying the mounts table) is explicitly out of scope.  That residual is a reviewability boundary, not an unrecorded pass claim: every verdict prints the execution environment.

The final package result is `✓ 40 ✗ 0 finding 0` / `PASS`.

Raw outputs: `pkg/logs/acceptance-perf-in-container.log` (historical original finding) and `pkg/logs/45-f2-merged-main.log` (final M73 mounted-marker closure).

## Flip evidence

This task is a verify task, not a defect-fix task.  Its independent mutation evidence is in `pkg/10-guard-and-knobs.sh`: restore pre-change §27-d → guard red, remove the perf marker → guard red, remove `panel-knobs.sh` → guard red; each restoration returns green.  The R2 slow-frame injection is separately red with its measured median and exit 2; the absent-image mutation is visible exit 4 rather than a silent host pass.

## Decisions and deviations

- No implementation was changed; all mutations use copied files under `/tmp` and are restored before the package exits.
- The brief's direct `--in-container` acceptance command was run exactly and exposed F2.  M66 fixed the missing-ENV shape, M69 fixed the bare-host export plus mismatched marker values, and M73 independently closes the foreign-image + caller-mounted exact-token shape; §24 explicitly records the remaining deliberate runtime-owner exclusion.
- The prior private-tmux wrapper was a verifier-harness defect, not an implementation finding.  Full-gate sections 40 and 50 now leave `smoke.sh` to own its documented isolation; §40's injected slow correctness run is canonical green, and the final protected-main standard full rerun is `2804/0`.

## Suggested next steps

- **PASS: PM may merge this evidence and close M64.**  The final scope is the documented accidental-misuse boundary: bare host, exported ENV, stale/missing marker, altered marker, and caller-mounted marker are all visibly refused.  A runtime owner who deliberately bakes the public token into a self-built image (or forges mounts) is explicitly outside that boundary; review any suspicious result through its emitted environment self-description.
- F1 and F3 remain closed by the protected-branch PUBLISH recheck, canonical slow §40 `2703/0`, and final protected-main full smoke `2804/0`; final M73 F2 is closed by `pkg/45` `40/0`.
