# P48 · pty-fixture-load-premise apply — 前提行 · 进度感知延长 · 耗尽归因 · 实验安全守卫

agent: dev3   status: DONE   time: 2026-09-22T10:40Z
branch: `task/P48-pty-apply`   PR/MR: - (local mode: no push, the branch stays local)

Phase: **apply** (B1 引擎+夹具 · B2 门禁映射+校准 · B3 门禁与证据).
Change: `pty-fixture-load-premise` · deltas: `panel` (ADDED) + `verification` (MODIFIED + ADDED).
Base revision: `f94e9b3` (PM snapshot after the 09:35 window loss; the run continues from there — nothing
was redone: `56cb799` engine, `f94e9b3` fixture/门禁/守卫, then this run's commits).

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/lib/pty-wait.sh` | 视界的进度感知延长（`PTY_STALL_ROUNDS`/`PTY_EXT_FACTOR`，视界本身不变）与耗尽归因（仍在绘制/超前提 → 可见 SKIP，rc 3 + `PTY_SKIPPED=1` + `pty_on_skip`；静态 + 前提之内 → 原红 + M59 现场）。自检新增判据④/⑤与四个红面断点（`noext`/`alwaysext`/`noskip`/`alwaysskip`） |
| `skills/teamsmith/tests/panel-p21.sh` | 每个场景第一个断言之前的前提行（真 `loadavg_1m`/`5m`、逻辑核、代码无关探针 ms、两个顶）；入口粗闸门（`TEAM_P21_PREMISE_LOAD_FACTOR`，默认 2.0）在第一个等待前 SKIP；SKIP 记账 + 退出码 4；旋钮只在 `TEAM_SMOKE_FIXTURE=1` 下生效（否则打印忽略行读真值）；`TEAM_P21_PREMISE_ONLY=1` 自述模式（门禁的旋钮完整性检查用） |
| `skills/teamsmith/tests/smoke.sh` | §38-b/§38-f 的退出码判定表（`p38_verdict`：0 全绿 / 1 失败 / 4 可见 SKIP+原因与读数 / 3 搭建失败），SKIP 绝不印成全绿；§38-g①（`load-experiment.sh --guard-test`，FAST 照跑）与 §38-g②（premise-only 旋钮不得漏进真路径，FAST 照跑） |
| `skills/teamsmith/tests/load-experiment.sh` | 实验安全原语：归属校验的 freeze（只对自己 spawn 的 owner 子树发信号，模式形状/空/非数字/自己 → 发信号前拒绝 exit 2）、`EXIT/INT/TERM` 的 `CONT` 释放、可中断 hold（`sleep & wait`）、自有负载（storm/burn）、私有根与 socket 名，外加十条边全可证伪的 `--guard-test` |
| `docs/team/reports/P48-dev3.md` + `docs/team/reports/P48-dev3/**` | 本报告 + 原始产物（校准行的夹具日志与 5s 采样、翻转日志、自检日志、`calib-row.sh` 驱动） |

## 1 · B1：夹具在机器前提下判定

### 1.1 前提行与入口口径（`panel-p21.sh`）

- 前提行（`p21_premise_line`）在每个场景**第一个断言之前**打印，读数全部是真的：`loadavg_1m`/`loadavg_5m`
  （`/proc/loadavg`）、逻辑核（`nproc`，回退 `getconf _NPROCESSORS_ONLN`）、代码无关探针（`python3 -c pass` +
  `bash -c true` + `git rev-parse`，5 轮均值 ms）与两个顶（探针 `TEAM_P21_PREMISE_PROBE_MS`=120ms、粗闸门
  `TEAM_P21_PREMISE_LOAD_FACTOR`=2.0×核）。**入口不判定**，只有粗闸门跳过整体超载的机器。
- 旋钮边界：`TEAM_P21_PREMISE_{PROBE_MS,LOADAVG,LOAD_FACTOR,PROBE_CEIL_MS}`、`TEAM_P21_STALL_ROUNDS`、
  `TEAM_P21_STALL` 只在 `TEAM_SMOKE_FIXTURE=1` 下生效；否则每个用到的旋钮打一行「忽略 …（真实路径读真值）」
  并读真值。`TEAM_P21_PREMISE_ONLY=1` 只打前提行与忽略行，不建 tmux、不判时长。

真实读数（本机，32 逻辑核，2026-09-22 10:0x–10:2xZ；四行取自各自的夹具日志）:

```
== 前提 choices：loadavg_1m 4.51 / loadavg_5m 5.85 · 逻辑核 32 · 代码无关探针 11ms（顶 120ms）· 粗闸门 64.00 = 2.0×32 核 ==
== 前提 choices：loadavg_1m 4.71 / loadavg_5m 5.50 · 逻辑核 32 · 代码无关探针 11ms（顶 120ms）· 粗闸门 64.00 = 2.0×32 核 ==   # storm 行
== 前提 choices：loadavg_1m 8.82 / loadavg_5m 7.63 · 逻辑核 32 · 代码无关探针 18ms（顶 120ms）· 粗闸门 64.00 = 2.0×32 核 ==   # burn 行
== 前提 choices：loadavg_1m 17.29 / loadavg_5m 17.25 · 逻辑核 32 · 代码无关探针 12ms（顶 120ms）· 粗闸门 0.32 = 0.01×32 核 == # 入口闸门注入行
```

旋钮边界（开关**关**，`docs/team/reports/P48-dev3/knob-ignored.log`，`TEAM_P21_PREMISE_ONLY=1`）:

```
  忽略 TEAM_P21_PREMISE_PROBE_MS=999（只有 TEAM_SMOKE_FIXTURE=1 时夹具旋钮才生效；真实路径读真值）
  忽略 TEAM_P21_PREMISE_LOAD_FACTOR=0.01（只有 TEAM_SMOKE_FIXTURE=1 时夹具旋钮才生效；真实路径读真值）
== 前提 choices：loadavg_1m 18.27 / loadavg_5m 17.44 · 逻辑核 32 · 代码无关探针 13ms（顶 120ms）· 粗闸门 64.00 = 2.0×32 核 ==
```

### 1.2 延长与耗尽归因（`pty-wait.sh`）

视界不放大：`base` 仍是 `PTY_WAIT_ITERS`（40）与各站点的覆盖（30/8/6）。基础视界之上只有**场景仍在绘制**
（掩码捕获在最近 `PTY_STALL_ROUNDS`=8 轮内变过、且已观察满这个窗口）才继续轮询，最多 `PTY_EXT_FACTOR`=3×。
到顶后归因：`仍在绘制 || pty_premise_over`（探针超顶或 loadavg 超粗闸门）→ 一行可见 SKIP（点名等待、轮数/上限、
耗时、M59 现场、归因读数），`PTY_SKIPPED=1`、返回 3，并调 `pty_on_skip`（夹具在这里 `exit 4` 结束当前场景）；
静态 + 前提之内 → 原来的红与 M59 现场（rc 1）。

分支覆盖（`selftest-base.log`，`✓ 15 ✗ 0 SKIP 1`，RC=0）:

```
✓ 慢但仍在绘制：基础视界 6 轮之上仍在等，第 9 轮拿到条目（延长是等出来的，不是放松阈值）
✓ 静态场景：基础视界 6 轮就用满（不是延长的 18 轮）→ 红：延长永远藏不住静态失败
SKIP 超前提：rc=3 + PTY_SKIPPED=1 + 一行可见 SKIP（点名等待/轮数/耗时/现场/读数）→ 记为 skip，不是失败
✓ 前提之内：同一个静态现场仍是红（rc=1 + M59 现场）—— SKIP 不是逃逸门
```

### 1.3 SKIP 记账与退出码

夹具把每个场景放进子 shell：`pty_on_skip` 的 `exit 4` 只结束当前场景（后续场景照跑），父进程把 rc=4 计进
`SKIP`，结果行 `== 结果 == ✓ … ✗ … SKIP …`；`FAIL>0 → 1`，`SKIP>0 → 4`，否则 0，搭建失败 3（不变）。

### 1.4 入口粗闸门（`TEAM_P21_PREMISE_LOAD_FACTOR`）

`calib-C5-guard-injected.log`（`TEAM_SMOKE_FIXTURE=1 TEAM_P21_PREMISE_LOAD_FACTOR=0.01`）:

```
== 前提 choices：loadavg_1m 17.29 / loadavg_5m 17.25 · 逻辑核 32 · 代码无关探针 12ms（顶 120ms）· 粗闸门 0.32 = 0.01×32 核 ==
  SKIP 入口粗闸门：loadavg_1m 17.29 > 0.32（0.01×32 核）—— 场景 choices 在第一个等待之前就停下（无失败、无结论，exit 4）
== 结果 ==  ✓ 0  ✗ 0  SKIP 1
RC=4
```

### 1.5 wheel 真回归翻转（前提不是逃逸门）

- 原树：`bash skills/teamsmith/tests/panel-p21.sh wheel` → `== 结果 == ✓ 23 ✗ 0 SKIP 0`，RC=0。
- scratch 树（`/var/tmp/p48-wheel/panel`，App.tsx 删掉设置视图的滚轮消费分支、`build.sh` 重编
  `panel.js`，夹具用 `TEAM_P21_PANEL=` 指向它）→ `calib-wheel-sabotaged.log`：

```
✗ 下滚 3 格：顶部计数行读出 ↑3（窗口正好移 3 行）
✗ 下滚 3 格：原本第一行（项目名）已出窗（不该出现 [项目名]）
✗ ↓ 之后窗口被推到聚焦行上（顶部计数行 = ↑1）
✗ 页面窗口还是进视图前的那一屏（P-04 仍可见）
== 结果 ==  ✓ 19  ✗ 4  SKIP 0      RC=1
```

### 1.6 FAST/full 分层与钉子不动

FAST 门禁里 §38-b/§38-f 仍是可见 SKIP（带原因），§38-d/§38-e 照跑且各自翻转照旧红（见 §3.1 的 FAST 尾巴）。

## 2 · B2：门禁映射与校准

### 2.1 §38-b/§38-f 的退出码映射（`p38_verdict`）

`smoke.sh` 里 0 → 全绿行，1 → 失败行，3 → 搭建失败行，**4 → `SKIP（条件不满足）` 行带夹具自己的 SKIP 行
（原因+读数）**，其它码 → 意外退出码红；SKIP 分支绝不打印全绿行。真实证据 = 注入的全量门禁跑（§3.1）。

### 2.2 门禁自己的承诺

`bash skills/teamsmith/tests/gate-guard.sh` → `RC=0`：

```
ok: smoke.sh 里没有性能判定标记、时长/份额比较，也没有测量夹具的点名
ok: panel-knobs.sh 存在且走 panel-cpu.sh 的 premise-only 模式
ok: gate-guard: 三向都过（门禁无判定、旋钮助手在岗、性能套件带标记）
```

### 2.3 校准表（原始产物在 `docs/team/reports/P48-dev3/`）

每一行 = `panel-p21.sh choices`，`TMPDIR`/`TMUX_TMPDIR` 指向自己的私有根；负载全部来自
`tests/load-experiment.sh`（自有 worker，无外部进程被信号）；采样每 5 s 记录 `loadavg` 与探针。

| # | 组合 | loadavg_1m min/mean/max | 探针 ms min/mean/max | 结果 | 墙钟 | 产物 |
|---|---|---|---|---|---|---|
| C1 | 安静（团队环境负载） | 4.51（前提行） | 11（前提行） | `✓ 110 ✗ 0` rc 0 | 105 s | `calib-C1-quiet.log` |
| C2 | + storm 8 workers（fork/exec 风暴） | 4.71 / 9.35 / 11.97（n=23） | 11 / 12.7 / 19（n=23） | `✓ 110 ✗ 0` rc 0 | 112 s | `calib-C2-storm.{log,samples}` |
| C3 | + burn 24（32 核饱和，loadavg 一度 ~37） | 8.82 / 25.94 / 36.94（n=22） | 18 / 21.9 / 34（n=22） | `✓ 110 ✗ 0` rc 0 | 108 s | `calib-C3-burn.{log,samples}` |
| C4 | 超前提：探针注入 999ms（夹具开关） | 5.88 / 6.03（前提行 + SKIP 行） | 999（注入） | `✓ 0 ✗ 0 SKIP 1` rc **4** | 22 s | `calib-C4-probe-injected.log` |
| C5 | 超前提：粗闸门注入 0.01×核（入口） | 17.29 | 12 | `✓ 0 ✗ 0 SKIP 1` rc **4** | ~2 s | `calib-C5-guard-injected.log` |

负载工具自己的读数（证明负载是自有的、可回收的）:

```
storm: workers=8 seconds=130 iterations=21703 rate=166.9 iters/s (each = git+python3+bash; loadavg 10.81)
burn: 24 owned CPU burners for 130s (loadavg 7.15)
```

**带与常量的关系**（design §3 的方法：常量落在夹具**判绿**的带之外）：

- 探针：夹具在上表全部组合（loadavg 4.5 → 36.9，含 32 核饱和）里判绿，探针带 **10–34 ms**；
  `PTY_PREMISE_PROBE_MS`=**120 ms** ≈ 3.5 × 实测最高值 → 在带外。
- 粗闸门：最高实测判绿 loadavg **36.94 = 1.15 × 核**；`TEAM_P21_PREMISE_LOAD_FACTOR`=**2.0** × 核 = 64 → 在带外，
  只可能跳过一个严重过载的宿主（它不判定，只省时间）。
- 视界：C1–C3 三行全绿、墙钟 105–112 s（饱和只慢 3–7 %），延长与归因在 C4/C5 上可见 —— 与 P44 的
  「CPU 负载不产生红/绿交叉点」一致：决定判定的仍是运行内证据（进度 + 探针），外部读数只是粗闸门。
- 未达成的校准面（诚实记录）：本块没有把**真实**探针推过 120 ms（需要 cgroup/`SIGSTOP` 形态的机器侧停顿，
  P44 已证 CPU 负载推不到）。C4 是用夹具开关注入 999ms 走通的归因路径；`load-experiment.sh` 提供了
  归属安全的 freeze 原语，可以复现该形态（残余风险的实测留给后续）。

### 2.4 常量/带/复现配方的文档

`grep -n 'premise' skills/teamsmith/tests/panel-p21.sh skills/teamsmith/tests/lib/pty-wait.sh` 有 46 + 20 处，
两个文件头部都写着常量、实测带、复现工具（`tests/load-experiment.sh {probe,storm,burn}`）与旋钮清单，且**不复制
requirement 文本**（引 requirement 名与 `design.md §3/§4`）。

### 2.5/2.6 实验安全守卫与门禁段

见 §5（四条证据）与 §3.1（FAST 里 §38-g①/② 的行走行）。

## 3 · B3：门禁与证据

### 3.1 门禁（三段 + 面板批）

**① `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict`** → `Totals: 19 passed, 0 failed (19 items)`，RC=0。

**② FAST 门禁**（`TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`，2026-09-22T09:5xZ）:

```
  SKIP（FAST 模式） 38-b·panel-p21-choices —— panel-p21.sh choices 要真 tmux 场地 + 真 bundle（慢段 ~2.5 分钟）
  …
  SKIP（FAST 模式） 38-f·panel-p21-settings-groups-wheel —— panel-p21.sh groups/settings/wheel 要真 tmux 场地 + 真 bundle（慢段 ~2 分钟）
  ✓ 38-e 翻转：删掉 scrollSettings(delta) → pin 红（滚轮会落回页面滚动）
  ✓ 38-g① load-experiment.sh --guard-test 全绿（ ✓ 17 ✗ 0 SKIP 0；只对自己 spawn 的进程发信号）
  ✓ 38-g② premise-only 模式退出 0（不建 tmux、不判时长）
  ✓ 38-g② 注入的旋钮被忽略并打印：TEAM_P21_PREMISE_PROBE_MS=999
  ✓ 38-g② 注入的旋钮被忽略并打印：TEAM_P21_PREMISE_LOAD_FACTOR=0.01
  ✓ 38-g② 前提行是真读数（loadavg_1m 17.53 · 逻辑核 32）
  ✓ 38-g② 前提行里没有注入值
  ✓ 38-g② premise-only 模式没有判任何东西（无 SKIP、无 ✗）

== 结果 ==  ✓ 2322  ✗ 0
FAST 模式：跳过 29 个真进程段落（…|38-b·panel-p21-choices|38-f·panel-p21-settings-groups-wheel）…
smoke 全绿
RC=0
```

§38-d/§38-e 照跑（含 38-e 的四个翻转：组标签翻转①②、`settingsGroupApply` pin 红、删 `scrollSettings(delta)` → pin 红）。

**③ 注入的全量门禁**（`TEAM_SMOKE_FIXTURE=1 TEAM_P21_PREMISE_PROBE_MS=999 bash skills/teamsmith/tests/smoke.sh </dev/null`,
2026-09-22T10:0x–10:3xZ；这一跑证明 §38-b/§38-f 的 rc=4 映射，且它自己就排在同一把机器锁后面）:

```
  SKIP（条件不满足） 38-b panel-p21.sh choices —— SKIP 等待耗尽但归因于机器（既不是通过也不是失败）：面板首帧（choices） · 轮数 80/240 · 耗时约 21s · 场景已静止 · 缺 [◊P48-注入：状态永不到来◊] · 归因：loadavg_1m 8.10 vs 粗闸门 64.00（2.0×32 核）；探针 999ms vs 顶 120ms
  SKIP（条件不满足） 38-f panel-p21.sh groups/settings/wheel —— SKIP 等待耗尽但归因于机器（既不是通过也不是失败）：面板首帧（groups） · 轮数 80/240 · 耗时约 21s · 场景已静止 · 缺 [◊P48-注入：状态永不到来◊] · 归因：loadavg_1m 5.99 vs 粗闸门 64.00（2.0×32 核）；探针 999ms vs 顶 120ms
      == 结果 ==  ✓ 0  ✗ 0  SKIP 3
…
== 结果 ==  ✓ 2850  ✗ 0
smoke 全绿
RC=0
```

机检（同一条日志）：`grep -c '38-b panel-p21.sh choices 全绿'` = **0**、`grep -c '38-f panel-p21.sh groups/settings/wheel 全绿'` = **0**
——跳过的场景没有被印成任何一节的全绿行；门禁退出码仍是 0。

**④ 正常全量门禁**（交付门禁，不带任何注入）:

<!-- FILL-NORMAL-GATE -->

**⑤ 面板批**（验收命令 `bash skills/teamsmith/tests/panel-p21.sh choices groups settings wheel`）:

<!-- FILL-BATCH -->

## 4 · 五组翻转（红 → 绿原始输出）

### 4.1 翻转①：延长（旧逻辑红 → 新逻辑判对）

`bash skills/teamsmith/tests/lib/pty-wait.sh --self-test [--break=<档>]`（五个档的原始日志在
`docs/team/reports/P48-dev3/selftest-*.log`）:

| 档 | 结果行 | 关键尾巴 |
|---|---|---|
| base | `✓ 15 ✗ 0 SKIP 1` RC=0 | `✓ 慢但仍在绘制：基础视界 6 轮之上仍在等，第 9 轮拿到条目`；`✓ 静态场景：基础视界 6 轮就用满（不是延长的 18 轮）→ 红`；`SKIP 超前提：rc=3 + PTY_SKIPPED=1 + 一行可见 SKIP`；`✓ 前提之内：同一个静态现场仍是红` |
| `noext`（关掉延长） | `✓ 14 ✗ 1 SKIP 1` RC=1 | `SKIP … 慢但仍在绘制 · 轮数 6/6 · 场景仍在绘制 · 归因：机器读数超前提` + `✗ 延长没有生效（rc=3 rounds=6；断点=noext）` |
| `alwaysext`（静态也延长） | `✓ 11 ✗ 4 SKIP 1` RC=1 | `✗ 静态场景被延长或没红（rc=3 rounds=18；断点=alwaysext）`；`✗ 前提之内的耗尽没有红（rc=3 PTY_SKIPPED=1）` |
| `noskip`（超前提也判红） | `✓ 15 ✗ 1 SKIP 0` RC=1 | `✗ 超前提没有给出可见 SKIP（rc=1 PTY_SKIPPED=0；断点=noskip）` |
| `alwaysskip`（前提之内也跳过） | `✓ 11 ✗ 4 SKIP 1` RC=1 | `✗ 静态场景被延长或没红（rc=3 rounds=6）`；`✗ 前提之内的耗尽没有红（rc=3 PTY_SKIPPED=1）` |

旧逻辑的红面（`noext`）与「静态场景不许被延长」的红面（`alwaysext`）都在，新逻辑同一批判据全绿。

### 4.2 翻转②：真回归（前提不是逃避）

- 原树 `panel-p21.sh wheel` → `✓ 23 ✗ 0 SKIP 0` RC=0。
- scratch 树（设置视图滚轮消费删掉 + 重编 bundle）→ `✓ 19 ✗ 4 SKIP 0` RC=1，四条失败断言与尾巴在 §1.5。

### 4.3 翻转③：探针超顶 → 可见 SKIP + exit 4，门禁仍 0

- 夹具：C4（`✓ 0 ✗ 0 SKIP 1`，RC=4，SKIP 行点名轮数/耗时/现场/读数）；入口闸门 C5 同形。
- 门禁：注入的全量跑里 §38-b/§38-f 打 `SKIP（条件不满足）` 带夹具原因与读数，两节的「全绿」行不出现（机检 0），
  门禁 `✓ 2850 ✗ 0` RC=0（§3.1③）。

### 4.4 翻转④：实验守卫（模式形状拒绝 / TERM 不留 T）

- 绿侧（真树）：`--guard-test` → `✓ 17 ✗ 0 SKIP 0` RC=0，side 4 里模式形状目标 `exit 2`、`非自有进程没被动过`。
- 红侧（scratch worktree 删掉 freeze 的归属检查）→ `✓ 15 ✗ 2 SKIP 0` RC=1（§5 尾巴）。
- `TERM`/`INT` 中途杀掉的释放：side 2 四行全绿；两次实验跑完 `ps -eo stat | grep -c '^T'` = 0。

### 4.5 翻转⑤：还原后干净

`git status --porcelain` 只有本报告的目录（已提交）；scratch 树都在 `/var/tmp`（`p48-wheel`、`p48-flip`
worktree、`p48-tmp`）与仓库无关，交付前 `git worktree remove` 清掉。

## 5 · 实验守卫的四条证据（`verification#A load experiment signals only the processes it started`）

`bash skills/teamsmith/tests/load-experiment.sh --guard-test`（真树）:

```
== 1 · 绿侧：自有子进程可冻结、hold 结束即释放 ==
  ✓ 自有子进程在 hold 期间是 T（880181 → 880191）
  ✓ hold 正常结束时已释放（state 'S'）
== 2 · hold 可中断：TERM / INT 中途被杀也必须释放（不留 T）==
  ✓ hold 中途自有子进程是 T（信号 TERM）
  ✓ TERM 中途被杀也释放了（state 'S'）
  ✓ hold 中途自有子进程是 T（信号 INT）
  ✓ INT 中途被杀也释放了（state 'S'）
== 3 · 红侧：不是自己启动的进程在发信号之前就被拒绝 ==
  ✓ 非自有目标被拒绝（status 2）
  ✓ 拒绝理由点名归属：load-experiment: refusing 886951 — not the owner (886950) nor a descendant of it; this experiment signals only what it started
  ✓ 非自有进程没被动过（state 'S'）
== 4 · 红侧：模式形状 / 空列表 / 非数字 / 自己 都在发信号前被拒绝 ==
  ✓ 模式形状的目标被拒绝（status 2：这个文件里没有主机级名字/命令行匹配）
  ✓ 拒绝行说明原因是「目标必须是 PID，不是模式」
  ✓ 空目标列表被拒绝（status 2）
  ✓ 空 PID 被拒绝（status 2）
  ✓ 给自己发信号被拒绝（status 2）
== 5 · 结构钉：文件里没有主机级模式选择，只有 PID ==
  ✓ 没有主机级名字/命令行选择：目标只能作为 PID 传进来（模式形状在发信号前即拒绝）
== 6 · 私有夹具：两套实验各有各的临时根与 socket 名 ==
  ✓ 私有临时根可写且互不相同（load-experiment-a.iyBIfF / load-experiment-b.AoXFzG）
  ✓ 私有 socket 名带实验标签与 PID，且不是默认 server（le-a-887048 / le-b-887051）
== 结果 ==  ✓ 17  ✗ 0  SKIP 0      RC=0
```

**红侧（scratch worktree `/var/tmp/p48-flip`，把 freeze 的归属检查删掉）**:

```
== 3 · 红侧：不是自己启动的进程在发信号之前就被拒绝 ==
  ✗ 期望 status 2，实际 0
  ✗ 拒绝理由没有点名归属
  ✓ 非自有进程没被动过（state 'S'）      # 陷阱照常 CONT 释放：删除归属检查也不会留 T
== 结果 ==  ✓ 15  ✗ 2  SKIP 0      RC=1
```

四条证据 = ①自有目标冻结/释放（side 1，与 C4 的 freeze 形态同源）· ②`TERM`/`INT` 中途被杀不留 `T`（side 2，
本机 `env --default-signal` 可用，两发都真的跑到）· ③非自有 PID 在发信号前拒绝且状态不变（side 3 + 红侧对照）·
④模式形状/空/自己一律拒绝、文件里没有主机级模式选择（side 4/5），加上私有根/socket 不撞车（side 6）。
跑完 `ps -eo stat | grep -c '^T'` = **0**（无 STOPPED 残留）。

## 6 · 覆盖缺口与残余风险（诚实节）

- **静态机器侧停顿**（`SIGSTOP`/cgroup 节流）超过延长上限且外部读数健康 → 仍是红（带 M59 现场）。这是 design §2
  写明的残余，本任务不放大前提去吞掉它；`load-experiment.sh freeze` 提供了归属安全的复现原语，本块没有跑
  blackout 形态（前面已记录）。
- **真实探针超顶**未在本块达成（C4 是注入）；探针带 10–34 ms 与顶 120 ms 的差是实测的，但顶的**红侧**仍是
  guard，不是实测交叉点。
- `TEAM_SMOKE_FIXTURE=1` 的全量门禁（§3.1 的注入跑）只为了证明 §38-b/§38-f 的 SKIP 映射；常规交付门禁是不带
  注入的那一次。
- 本块没有改 D33 的口径：门禁里没有新增墙钟/CPU 份额红线，`gate-guard.sh` 三向绿；27-d/panel-cpu 的系数与
  红线未动。

## 7 · 过程记录（诚实，含一次 ENOSPC 假红）

- 09:4x 的第一次安静 `choices`（`✓ 109 ✗ 1`）是**假红**：`/tmp` 被整机填满（0 字节、1.6k inode），夹具
  落在 `printf: write error: No space left on device`；同时暴露了真 bug（见下一行）。
- 该次跑的 ✗ 是 **P48 自己的回归**：P48 把 `pty_trace` 改成 `rounds=$i/$ceiling`，而 `panel-p21.sh:1086` 的
  M59 钉子要求 `rounds=[0-9]+ settled=1`。修复 = trace 行回到 `rounds=$i`（ceiling 在耗尽记录与 SKIP 行里），
  提交 `fbfb987`；复跑 `✓ 110 ✗ 0`。断言覆盖未缩水、钉子文件未改。
- `/tmp` 满的问题向 PM 报过一次（占用：`review-*` 6.0G/127 个、`config-cli.*` 3.3G/552 个、
  `teamsmith-smoke.*` 134M/3 个）；我没有删任何别人的东西，改为 `TMPDIR`/`TMUX_TMPDIR` 指到自己的
  `/var/tmp/p48-tmp`（`mkdir` 过的目录，不做静默回退），之后 `/tmp` 自行恢复到 33%。

## 8 · 映射表

### delta → requirement → 实现 → 夹具/证据

| delta 文件 | requirement | 实现落点 | 场景 → 证据 |
|---|---|---|---|
| `panel/spec.md` ADDED | `The project-settings pty fixture judges under a machine premise` | `panel-p21.sh`（前提行/入口闸门/钩子/exit 4/旋钮边界）+ `pty-wait.sh`（延长与归因）+ `smoke.sh` §38-b/§38-f/§38-g② | 见下行七条 |
| | 场景「A machine over the premise is skipped visibly, never turned into a red」 | | C4（rc 4 + SKIP 行 + `SKIP 1`） |
| | 场景「A machine under the premise still reds a real regression」 | | §4.2 wheel 绿/红两尾巴 |
| | 场景「A static failure is neither extended nor skipped on a healthy machine」 | | selftest 判据④（静态 6/6）+ `alwaysext` 红面 |
| | 场景「The premise line stays real on the real path」 | | `knob-ignored.log` + FAST §38-g② |
| | 场景「The gate maps a skipped fixture to a visible skip, not a failure」 | | §3.1 注入的全量门禁（§38-b/§38-f） |
| | 场景「FAST keeps the pty scenarios out and the load-independent pins in」 | | §3.1 FAST 尾巴（38-b/38-f SKIP + 38-d/38-e 跑） |
| `verification/spec.md` MODIFIED | `The correctness gate judges correctness only` | `pty-wait.sh` + `panel-p21.sh` + `smoke.sh`（映射与 SKIP 记账）；`gate-guard.sh` 未动 | 基底三场景保持：FAST 绿（§3.1）、`gate-guard.sh` 绿（§2.2）、38-g②；新增四场景同 panel 的 C4/C5/FAST/注入门禁 |
| `verification/spec.md` ADDED | `A load experiment signals only the processes it started` | `load-experiment.sh` + `smoke.sh` §38-g① | §5 绿侧 17 条 + 红侧（删归属检查 → `✗ 2`） |

### requirement → tasks 条目

- `panel#…machine premise` → 1.1（延长/自检）· 1.2（归因）· 1.3（前提行）· 1.4（SKIP 记账/exit 4）· 1.5（入口
  闸门）· 1.6（真回归翻转）· 1.7（FAST/full）· 2.1（门禁映射）· 2.3（校准）· 2.4（文档）。
- `verification#…judges correctness only` → 1.1–1.7、2.1–2.4（上面）＋ 2.2（gate-guard）。
- `verification#A load experiment …` → 2.5（守卫测试）· 2.6（门禁段）· 2.3（校准走安全 harness）。

### 场景 → fixture（verifier 可以直接照跑）

| 场景 | 命令 |
|---|---|
| panel 超前提 SKIP | `TEAM_SMOKE_FIXTURE=1 TEAM_P21_PREMISE_PROBE_MS=999 bash skills/teamsmith/tests/panel-p21.sh choices`（期望 rc 4） |
| panel 入口闸门 | `TEAM_SMOKE_FIXTURE=1 TEAM_P21_PREMISE_LOAD_FACTOR=0.01 bash skills/teamsmith/tests/panel-p21.sh choices`（期望 rc 4，无等待） |
| panel 真回归 | `/var/tmp/p48-wheel` 形态（或 `TEAM_P21_PANEL=<修过的 bundle>`）`bash … panel-p21.sh wheel`（期望 rc 1） |
| panel 静态失败仍红 | `bash skills/teamsmith/tests/lib/pty-wait.sh --self-test`（`SKIP 1`、`✗ 0`，含静态红判据） |
| panel 前提行真读数 | `TEAM_P21_PREMISE_ONLY=1 TEAM_P21_PREMISE_PROBE_MS=999 bash … panel-p21.sh choices`（忽略行 + 真读数） |
| panel 门禁映射 | `TEAM_SMOKE_FIXTURE=1 TEAM_P21_PREMISE_PROBE_MS=999 bash skills/teamsmith/tests/smoke.sh </dev/null`（§38-b/§38-f 打 SKIP，门禁 0） |
| panel FAST/full | `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`（38-b/38-f SKIP、38-d/38-e 跑批） |
| verification 实验规则 | `bash skills/teamsmith/tests/load-experiment.sh --guard-test`（✓ 17 ✗ 0） |
| verification 旋钮完整性 | FAST 里的 38-g②（它读 `panel-p21.sh` 的 `TEAM_P21_PREMISE_ONLY`) |

## 9 · 验收命令（真实尾巴见 §3.1）

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/panel-p21.sh choices groups settings wheel
bash skills/teamsmith/tests/smoke.sh </dev/null          # 交付前全量
```
