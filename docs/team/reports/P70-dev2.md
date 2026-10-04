# P70 · gate-section-accounting apply（每段自述 + 硬超时 + 现场）

agent: dev2   status: delivered   time: 2026-09-28T10:20:00Z
branch: `task/P70-apply`   PR/MR: -（local 模式：不 push，分支留在本地，PM 复验后本地合并）
change: `gate-section-accounting`   phase: apply   deltas: `verification`（MODIFIED）
base: `main` @ `66d74e4d`

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/lib/section-guard.sh` | 段落守卫模块（新，681 行）：双重 fork 看门狗、内建写心跳、trip 标记、现场写入、子孙树遍历、TERM→KILL 升级、有界等待助手 |
| `skills/teamsmith/tests/section-guard.sh` | `--budget-check` / `--loop-check`（新，231 行）：预算表算术/覆盖检查、循环清单配平检查（纯逻辑，无进程、无 tmux） |
| `skills/teamsmith/tests/section-budgets.tsv` | 110 段的实测带 + `budget_s = max(ceil(band×4), 60)` 推导 + 来源（新） |
| `skills/teamsmith/tests/loop-inventory.tsv` | 69 个 `while`+`sleep` 的清单：`cap=<上限字面量>` 或 `bound=<结构约束理由>` + 逐字符锚点（新） |
| `skills/teamsmith/tests/lib/loop-scan.awk` | 循环探针（新，110 行） |
| `skills/teamsmith/tests/smoke.sh` | `section()`/`ok()`/`bad()`/等待轮次的安全点与自述、`0e/0f/0g/14d` 四段（238+/2-） |
| `skills/teamsmith/tests/gate-guard.sh` | 第四向：时长阈值比较只许在 `lib/section-guard.sh`（26+/1-） |
| `openspec/changes/gate-section-accounting/specs/verification/spec.md` | delta 重写到 `pty-fixture-load-premise` 归档后的 base（D40 条件，见下） |
| `docs/team/reports/P70-dev2/{logs,measure,scripts}/` | 本报告的全套证据（翻转日志、逐段实测值、可重跑脚本） |

**Brief 的 grant 之外没有改动**：`perf.sh` / `panel-cpu.sh` / `panel-cpu-premise.sh` 逐字未动（`git diff --stat main...HEAD -- <这三个>` 为空），`.github/workflows/gates.yml` 与 `ci/Containerfile` 未动（D39 渠道不改），`references/**` 未动（任务书明确不属于本 change）。

## 硬要求 → 证据

### 1. 每段自述 + 每段硬超时（brief 1）

- 开跑行：`== #<N> <id> == <ISO-8601> · 预算 <B>s`（`SG_SEC_NO` 单调计数）；上一段在下一段开跑前打印结束行 `#<N> 用时 <E>s · ticks <T>`，并把同样内容追加进 `$TMP/sections.tsv`（`no id start elapsed_s ticks`）。
- 硬超时不是 `timeout` 包段落（92 段共享 shell 状态，拆函数会丢状态、还会让下一段接着跑半成品 —— 设计 D1 记录了这个否决的理由），而是**双重 fork 的心跳看门狗** + **trip 标记**三通道：① 安全点（`section()`/`ok()`/`bad()`/每条 `assert_*`/有界等待的每一轮）检查标记后 `exit 2` 并点名；② 看门狗先写现场，再从 `/proc/<pid>/task/*/children` 走子孙树 `TERM`→`KILL`，然后对套件本体 `TERM`→`KILL`（**从不发进程组信号**）；③ 脚本级 `trap … TERM` 兜底。
- 演示（交付树 FAST 验收运行的片段）：

```
== #5 0e · 段落自述：看门狗 / 预算表 / 循环清单（P70） == 2026-09-28T09:12:44+00:00 · 预算 176s
  ✓ P70 看门狗：活着但不在作业表里（双重 fork）
  ✓ P70 看门狗：心跳指向当前段落（#5）
  ...
  #5 用时 40s · ticks 23
```

### 2. 超时即现场（brief 2）

- 现场 = `${TMPDIR:-/tmp}/.teamsmith-smoke-scene.<pid>/`：点开头、在 run 自己的临时根**之外**（清理带不走）、写在**任何停止信号之前**；CI 现有的 `docker cp teamsmith-gates-run:/tmp/. .ci-artifacts/`（`include-hidden-files: true`）原样收得走 —— 工作流一个字节没改。
- 内容（逐件有界）：`summary.txt`（段号/id/预算/已运行/最后进度/mode/knobs/lock/机器读数 + 子孙进程树 + 进程表 tail-60）、`logs/tails.txt`（段窗口内动过的文件，**按 mtime 从新到旧**，最多 12 个、每个 tail-20 行）、`panes.txt`（本 run 私有 tmux server 每条 pane 的尾屏，有 pane 时）、`sections.tsv.partial`（部分计时记录）。
- pane 尾巴单独验过（`scripts/scene-panes-demo.sh`，私有 socket + `env -u TMUX -u TMUX_PANE`，只读抓屏）：`logs/scene-panes-demo.log` 绿色，现场 `panes.txt` 带 `PANE_MARKER-1` 尾屏；真实默认 server 前后都是 4 个 session（没碰）。
- 嵌套夹具（`0f`）对现场的断言（交付树 FAST 验收运行逐条绿）：点名段落 id、点名预算、最后进度读数、子孙树里有挂住的 `sleep 0.2`、记录了 KILL 升级、夹具日志尾巴、部分计时记录有前两段的行、现场在 TMPDIR 相对且点开头、**在 run 临时根之外**且活过临时根回收。

### 3. 预算有依据（brief 3）

- `section-budgets.tsv`：一行一段（`id / band_s / budget_s / host_s / host_load / container_s / container_load / ci_s / provenance`），`band_s = max(host_s, container_s, ci_s)` —— **最差观测值**，`budget_s = max(ceil(band_s × 4), 60)`。
- 实测来源（本 apply 的块内）：宿主全量 `full1`（tip `69d6041a`，2026-09-28 08:30:12–08:52:48Z，loadavg1 **10.5**/32 核，✓3531 ✗0）与固定镜像 `ctr1`（`localhost/teamsmith-gate:local` `a55ccdacb577`，tmux 3.7b / node 24.19.0 / bun 1.3.14 / openspec 1.8.0，08:46:47–09:09:33Z，loadavg1 **12.9**/32 核，✓3514 ✗2 —— 见下「容器测量」）；历史带保留 P56fast(10.6)/P56full(未记录负载)/FAST2(14.0)。逐段原始值在 `measure/{full1,ctr1,fast2}-section-times.tsv`。
- **无占位**：110/110 段都有实测带（`--budget-check` 打印 `110/110`）；本 apply 之前 20 段是 900s 占位（P70 自己 3 段 + P56 全量表没覆盖的 17 段），现在全部回填。
- **不许收紧到带以下**：`--budget-check` 逐行验 `budget ≥ max(ceil(band×4), 60)` + 表头有 factor/floor + 每段都有行；`0e` 段里还有两个在树内跑的翻转（降预算→红并点名；删行→红并点名；还原→绿），以及独立的 `scripts/evidence.sh` 版本（`logs/budget-check-*.log`）。
- **不是性能红线**：交付表下，任一实测段的用时最多只到预算的 **25 %**（4× 余量的定义），`38` 的 312s 对应 1248s 预算 —— 机器再慢 4 倍仍在界内必须绿；预算只能判「这段没有终止」。

### 4. 无界等待禁止（brief 4）

- 普查刷新：`tests/*.sh` + `tests/lib/*.sh` 里 **69** 个 `while`+`sleep` 全部进 `loop-inventory.tsv`，每个带 `cap=<上限字面量>`（清单会逐字符检查循环体里还有这个上限）或 `bound=<结构约束理由>`；三个历史无上限的（`smoke.sh` 的 M33 哨兵、`panel-cpu.sh` 的 CPU 采样、`flip-m7.2.sh` 的采集器）都用「停止位文件 / 计算出的 deadline」结构约束登记。
- `--loop-check` 纯逻辑：按文件内出现顺序配平「探到的循环 ↔ 清单行」、检查锚点、检查 `cap=` 还在不在；新循环一律红并点名 `file:line`（翻转见下）。
- `section_guard_wait`（有界等待助手）每轮刷新段落心跳（`ticks` 可见）、到顶打印一行归因（名字、`n/cap`、在等的状态、最后一次读数）并返回非 0；`0g` 段逐条断言（`3/3`、点名、最后读数 `reader-3`、`ticks` 精确 +3、第一行就是归因）。`lib/pty-wait.sh` 一字未动（P48 的引擎照旧）。

### 5. 可证伪（brief 5）

见下「Flip evidence」。注入 `TEAM_SMOKE_STUCK_SECTION=0c` + `TEAM_SMOKE_SECTION_BUDGET=3` 的嵌套 FAST 运行：退出码 2、恰好一条点名行、无 `== 结果 ==`、后面没有别的段落、不是 SKIP、有进度自述、现场齐全；正常跑不受影响（时长增量见下）。

### 6. 计时记录不是判决（brief 6）

- `gate-guard.sh` 第四向：`smoke.sh`/`panel-knobs.sh`/门禁其余来源里再出现「时长阈值比较」→ 红；`lib/section-guard.sh` 之外的时长比较就是违规（`logs/gate-guard-*.log`，含塞回 `[ "$elapsed" -gt 2000 ]` 的翻转）。
- `14d` 段反向断言：**段内跑完却打了进度行** → 红；另断言没有 `== 结果 ==` 之前的 trip、没有现场残留、`#N` 从 1 起严格递增、开跑行/结束行/记录行三段配平。

## Verification evidence（brief 的 Acceptance，逐条实跑）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
…
✓ change/gate-section-accounting
✓ spec/verification
✓ spec/watchdog
Totals: 18 passed, 0 failed (18 items)
```

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
…
== 结果 ==  ✓ 2866  ✗ 0
FAST 模式：跳过 33 个真进程段落（…）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿
# exit 0 · 110 段（14c 只在 FAST 存在）· 墙钟 727 s · 2026-09-28T09:12:37–09:24:44Z
```

```
$ bash skills/teamsmith/tests/smoke.sh </dev/null
…
== 结果 ==  ✓ 3531  ✗ 0
smoke 全绿
# exit 0 · 109 段 · 墙钟 1218 s · loadavg1 8.45/32 核 · 2026-09-28T09:35:56–09:56:14Z
```

三次运行都带上了 P70 自己的段落账目（`0e` 40–41 s / `0f` 5–6 s / `0g` 0–1 s / `14d` 0 s），`14d` 的配平断言（开跑行=结束行+1、每段一行记录、`#N` 严格递增、无现场残留、无「段内完成却打进度行」）全绿。

### 时长增量（brief 5 的「>3 分钟回 PM 报数」）

| 运行 | 段数 | 墙钟 | 结果 | 说明 |
|---|---|---|---|---|
| P56 全量（基线） | 91 | 1050.1 s | ✓2879 ✗1 | 提案块实测（`docs/team/reports/P56/full-section-times.tsv`） |
| 宿主全量 `full1`（测量用） | 109 | 1356 s | ✓3531 ✗0 | tip `69d6041a`，loadavg1 10.5/32 核 |
| **交付树全量（Acceptance）** | 109 | **1218 s** | **✓3531 ✗0** | tip `7db1546b`，loadavg1 8.45，exit 0 |
| 交付树 FAST（Acceptance） | 110 | 727 s | ✓2866 ✗0 | exit 0 |
| 固定镜像全量 `ctr1`（测量用） | 109 | 1366 s | ✓3514 ✗2 | loadavg1 12.9，两条红见「容器测量」节 |

拆解 `full1` 相对 P56 基线的 **+306 s**：① **+207 s** 是 P56 之后新增的段落（P56 全量表根本没量过）——其中 P70 自己的新段 `0e/0f/0g` = **48 s**（43+5+0）；② **+98 s** 是同一批 90 个老段在负载下变慢（1050→1148 s，+9 %）。也就是说 **P70 的门禁开销 ≈ 48 s（约 +4.6 %）**，其余是环境与别人交付的段。**增量 > 3 分钟，按 brief 报数。**

## Flip evidence

### A. 段落超时：注入永不返回 → 点名 + 停跑 + 现场（红/绿两侧都在 gate 内）

红侧就是 `0f` 里那个嵌套 FAST 运行（`TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_STUCK_SECTION=0c TEAM_SMOKE_SECTION_BUDGET=3`），它自己就是断言：

```
  ✗ 段落 #3（0c · 静态检查（函数结尾的 set -e 陷阱））超时：预算 3s，实际 3s，最后进度 0s → 停跑（exit 2），现场 /tmp/…/.teamsmith-smoke-scene.NNN
```

断言的绿侧（交付树运行逐条）：exit 2、恰好一条点名行、点名行在 `tail -25` 里、没有结果行、没有后续段落、不是 SKIP、超时前有进度自述、现场存在且 cleanup 带不走。

### B. 安全点标记被砸掉 → 模块自检必须红（break-it）

`0e` 段把 `_sg_check_trip` 里的 `_sg_exit_trip` 替换成 `:`（scratch 副本），模块自检从 **40 ✓ 0 ✗** 变成 **5 条 ✗**（停不下来），还原即绿 —— 证明停跑靠的是安全点里的标记检查，不是靠运气。

### C. 现场尾巴顺序：目录顺序会挤掉活证据 → 按 mtime 收（本 apply 自己抓到的真红）

**红（容器实测，ctr1 的 `0f`）**：`✗ P70 现场：带本段的夹具日志尾巴（…/tails.txt 中找不到 [fixture-stuck]）`；把现场抄出来看，12 个名额被 `.teamsmith-tmp` + `repo/.git/hooks/*.sample` 占满（`logs/ctr1-red-side.txt`）—— 挂住段落的活日志一条都没有。宿主 tmpfs 的目录顺序恰好「新文件在前」，所以这条只在容器里现形。

**修**（`1261d377`）：`_sg_scene_write` 改用 `_sg_recent_files`（`find -printf '%T@\t%p' | sort -rn | head -12`），正在被写的文件永远排最前；名额仍有界。自检里加了顺序断言（先建 live、再建 15 个目录顺序更靠前的旧文件 → live 必须在最前、只收 12 个）。

**绿（两侧）**：
- 宿主确定性翻转（`scripts/crowd-test.sh`，同一夹具、只换模块）：把收集改回 `find | head -12` → `RED: tails.txt 缺夹具日志；收进的文件：== old-15.txt …`（`logs/crowd-red.txt`，rc=1）；真模块 → `GREEN: tails.txt 带夹具日志（第一份：== fixture-stuck-1.log ==）`（`logs/crowd-green.txt`，rc=0）。
- **同一镜像里的翻转**（`scripts/ctr-scene-flip.sh`）：旧模块 `scene_has_fixture=no`（收 `.teamsmith-tmp`/`repo/.git/*`），新模块 `scene_has_fixture=yes`（第一份就是 `fixture-stuck-3.log`）（`logs/ctr-scene-flip.log`）。

### D. 预算表翻转（`0e` 段内 + standalone）

```
$ bash skills/teamsmith/tests/section-guard.sh --budget-check      # 干净树
ok: 预算表覆盖 110/110 个 section 且每行都满足 max(ceil(band×4), 60)   → rc=0
$ …（把「1 · doctor」的 budget 改成 10）
bad: 段落「1 · doctor（未初始化应失败）」budget_s=10 低于 max(ceil(band×4), 60)=60（不许收到实测带以下）→ rc=1
$ …（删掉那一行）
bad: 预算表没有段落「1 · doctor（未初始化应失败）」的行（每个 section 都要有行；未列出的新段落运行时用默认预算）→ rc=1
$ …（还原）→ rc=0
```

### E. 循环清单翻转

```
$ bash skills/teamsmith/tests/section-guard.sh --loop-check        # 干净树
ok: 扫描 69 行清单 / 69 个 while+sleep 循环，配平 69 个              → rc=0
$ echo 'while :; do sleep 1; done' > evil-fixture.sh
bad: evil-fixture.sh 的 while+sleep 循环数 1 ≠ 清单行数 0
bad: evil-fixture.sh:3 是未登记的 while+sleep 循环：while :; do sleep 1; x=$((x+1)); done → rc=1
$ rm evil-fixture.sh → rc=0
```

### F. D33 边界（历史判定不许回潮）

```
$ bash skills/teamsmith/tests/gate-guard.sh                        # 干净副本
ok: 门禁的时长只被记录、不被判定（lib/section-guard.sh 之外没有时长阈值比较）→ rc=0
$ printf '\nif [ "$elapsed" -gt 2000 ]; then :; fi\n' >> smoke.sh
bad: smoke.sh 里出现了性能判定标记 / 比较 / 测量夹具点名（14612:if [ "$elapsed" -gt 2000 ]…）→ rc=1
$ 还原 → rc=0
```

D33 的正向翻转（装配延迟夹具）见下方 `G` 节：**它在 main 上也是红的**，与 P70 无关。

### G. D33 正向翻转（装配延迟夹具）：既有红，归属不是 P70（两棵树对照实测）

`TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_FRAME_DELAY_MS=2600 TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`
在交付树上跑出 **✓2845 ✗21，exit 1**；21 条红**全部**落在 `12b-pi` 段，根因一条：

- `12b-pi` 的 M53 夹具（`team-inbox-watch-harness.mjs`）在**同一个进程**里装扩展，`S25z` 用例设 `TEAM_INBOX_WATCH_ABORT_AFTER=read` 并断言「没有 `TEAM_SMOKE_FIXTURE=1` 时该旋钮打印 ignored」。
- D33 命令**全局**开着 `TEAM_SMOKE_FIXTURE=1`，smoke 调 M53 夹具时没清掉它（`$TS_RUNNER "$M53_HARNESS" …` 直接继承环境）→ 扩展按设计**执行** abort 旋钮 → 在 read 之后 SIGKILL 自己（`Killed`，rc=137）→ 后面 19 条断言全成了「日志里找不到 `[TEAM-IW-CASE PASS …]`」的下游缺行。
- **对照实验（决定性）**：同一命令在 **main 树的普通 checkout**（`git clone`，`smoke.sh` 里 `section_guard_init` 出现 0 次，即完全没有 P70）上复跑 → **同样 ✓2856 ✗21、同样 21 条 12b-pi 缺行、同样 `Killed` rc=137**（`logs/d33-pre-existing.txt`）。`S25z` 在 main 的夹具里逐字存在（6 处），扩展的开关判据在 `extension/team-inbox-watch.ts:1361-1365`，smoke 的调用点没清开关。
- **P70 的边界本身完好**：该运行里 P70 四段全绿（0e/0f/0g 无 ✗）、0 条段落超时行（`0f` 的那条是夹具自己注入的、且预期如此）、0 行 frame-budget/CPU-share 判定；21 条红与预算、段落账目、时长判定都无关。

**归属与建议（给 PM）**：这是 **D33 命令与 M53 夹具的既有冲突**（D33 的 scenario 声称 exit 0，与今日行为不符），P70 既没引入也没加剧。我没改它（不在 brief 的 grant 里，且修法要动 smoke 的调用点或 M53 夹具语义 —— 例如给那次调用 `env -u TEAM_SMOKE_FIXTURE`）；建议单开一条 change，本报告的 `logs/d33-pre-existing.txt` 是可直接复用的现场。

## 容器测量（任务书 2.1 的固定镜像列）

- 命令（满足 rootless podman 的 cgroup 约束才拿到 `--pid=host` 的 SIGTTIN 语义，与 CI 一致）：
  `podman run --name p70-ctr1 --pid=host --cgroups=enabled --user 1000:1000 -e HOME=/tmp -v <worktree>:/work:ro -w /work localhost/teamsmith-gate:local bash -c 'bash skills/teamsmith/tests/smoke.sh --keep </dev/null'`
- 结果：**109 段，1366 s 墙钟，✓3514 ✗2，loadavg1 12.9**。两条红都不是预算/段落账目问题：
  1. `0d 冲突标记守卫`：把 **git worktree** 挂进容器时 `.git` 是文件、gitdir 在挂载外 → 「找不到受检的 git 工作树」。CI 用普通 checkout，这是测量挂载形状的产物，非回归。
  2. `0f 现场尾巴`：见 Flip C —— 已修 + 容器内翻转复验。
- `ci_s` 列留空（`-`）：本地模式不 push，本分支没有 CI 运行；表头写明了「首次 CI 运行后回填」。

## D40 / D7（两个 change 改同一条 requirement）

`pty-fixture-load-premise`（P44/P48）在本 apply 开始时**仍未归档**，而它的 delta 也 MODIFIED 同一条 `verification#The correctness gate judges correctness only`。按任务书 condition，本 change 的 delta 已重写到「它归档之后」的 base（把它加入的 4 个 scenario 与前提段**逐字带上**），所以：

- 试验一（在 scratch 副本里先归档 `pty-fixture-load-premise`）：`+2 added, ~1 modified`（`logs/trial-pty-first.txt`），`openspec validate --all --strict` → **17 passed, 0 failed**（`logs/trial-pty-first-validate.txt`）。
- 试验二（先归档本 change）：validate → **16 passed, 1 failed**（`✗ change/pty-fixture-load-premise`，它的待归档 delta 少了本 change 加的 scenario）（`logs/trial-gsa-first.txt` + `logs/trial-gsa-first-validate.txt`）。

**给 PM**：归档顺序只有一个安全解 —— **先归档 `pty-fixture-load-premise`**；若必须先归档本 change，pty 的 delta 必须在归档前按新 base 重写（这是 D7 记录的双向条件，不是本 apply 能代做的）。

## Decisions and deviations

- **不按字面用 `timeout` 包段落**（设计 D1 的否决记录：92 段共享 shell 状态、子进程/tmux pane 会活过 `timeout`、进程组信号会打到调用者）。改为心跳看门狗 + trip 标记 + 安全点，行为等价但可证伪。
- **没有 run 级预算**（设计 D3）：91 段预算之和远大于 `TEAM_REVIEW_TIMEOUT`(1800s) 与 CI 的 60 min，一个会「全段均匀变慢」时误红的 run 级红线正是 D33 禁止的形状；改为运行中的进度自述（每 60s 一行 + 超带警告行）。`0g`/`14d` 断言它只是记录。
- **三个无上限循环不重写**，登记结构约束（停止位/deadline）——普查里它们本来就有界，重写只会扩大 diff。
- **发现并修了一条自己引入的真缺陷**（Flip C 的现场尾巴顺序）：不是任务书预见到的，是容器测量跑出来的；修法、宿主与容器两侧翻转、自检断言都在上面。
- **容器列的 0d 红**保留在证据里、当成挂载形状的产物（不改产品来迁就测量装置）；若 PM 想复核，用 `git clone` 出来的普通 checkout 挂载即可消除。
- **ci_s 留空**：本地模式不 push，无法产生 CI 列；表头与 provenance 都写明了。
- **D33 场景的既有红不改**：`TEAM_SMOKE_FIXTURE=1` + 装配延迟旋钮的命令在 main 上同样 ✓✗21（见 G），根因是 M53 夹具 `S25z` 与那个全局夹具开关的冲突；不属本 change 的 grant，也没有低风险的就地修法（建议单开 change）。

## F1 返工（merge main 之后的段落账目补齐；PM 2026-09-28T10:27Z）

**要求**：① `git merge main`（按 PM 指定的解法解 `smoke.sh` 尾部冲突）；② main 新增的 §50（P95 合并基准）/§51（P99 用法诚实性）补实测 band/预算行；③ `--budget-check`（要 112/112）、`--loop-check`、FAST、`openspec validate --all --strict`；④ 提交 + 写进报告。**其余未动**（`perf.sh`/`panel-cpu*.sh`/`references/**`/`.github/**` 逐字未碰）。

### ① 合并与解冲突（`a021b339`）

- `main` 已前进 12 个提交；唯一冲突在 `skills/teamsmith/tests/smoke.sh` 尾部：两边都在 `section "15 · 完成"` 之前追加段落（本分支的 §14d ↔ main 的 §50/§51）。
- 按 PM 给定的解法：**保留 main 的 §50、§51，把 §14d 放在它们之后、§15 之前**（§14d 是整轮自述对账，语义上就该最后跑）。解冲突后的顺序（`logs/f1-section-order-after-merge.txt`）：

```
14578:section "50 · P95 合并基准 = 该任务的 squash 提交（解冲突不再假红）"
14827:section "51 · 用法诚实性：help 的每条承诺与名册的每条路线都有夹具兑现（P99）"
14857:section "14d · P70 本套自述对账（段落账目 + 无误判）"
14884:section "15 · 完成"
count = 112
```

- `comm` 对照：本分支合并前的 110 个 id 与 main 的 108 个 id，相对合并树**一个不丢**（110 + main 新增 2 = 112）。

### ② §50/§51 的实测行（表头 host/container/ci 三个来源写清）

| 段 | host | container | band | budget = max(ceil(band×4), 60) |
|---|---|---|---|---|
| 50 · P95 合并基准 | 2s | 2s / 2s | 2 | 60（floor） |
| 51 · 用法诚实性 | 118s / **121s** | 123s / **127s** | 127 | **508** |

- **host 全量 #1**（`full1m`）：tip `a021b339`，10:43:48–11:05:41Z，loadavg1 5.9→9.8/32 核，✓3594 ✗2（见下）。
- **固定镜像 ctr2m（干净形态，band 取这一轮）**：`localhost/teamsmith-gate:local` `a55ccdacb577`，11:31:41–11:54:58Z，loadavg1 7.1→6.5/32 核，✓3580 ✗1（只剩 0d 挂载形状产物）。命令与 D39 渠道一致：

```sh
distrobox-host-exec podman run --name p70-ctr3 --pid=host --cgroups=enabled --user 1000:1000 -e HOME=/tmp \
  -v <worktree>:/work:ro -w /work localhost/teamsmith-gate:local \
  bash -c 'bash skills/teamsmith/tests/smoke.sh </dev/null'
```

- `ci_s` 仍为 `-`（local 模式无 CI 运行，表头写明了回填时机）。

### ③ 可证伪：补行前的红正是机制在工作

补行之前，合并树上的 **§0e 自己就如实报了**（不是回归，是 `--budget-check` 该有的行为）：

```
✗ P70 预算检查：干净树绿（ 个 section）（期望 [0]，实际 [1]）
✗ P70 翻转（预算）还原：绿（期望 [0]，实际 [1]）
```

`logs/f1-budget-rows-flip.log` 的 standalone 红→绿翻转：删掉两行 → `bad: 预算表没有段落「50 · …」的行` + `bad: 预算表没有段落「51 · …」的行` + `110/112`，rc=1；还原 → `112/112` 全过。

### ④ 容器里多出来的红：两条都不是本分支的回归

- `0d 冲突标记守卫：找不到受检的 git 工作树` —— **git worktree 挂进容器**时 `.git` 是文件、gitdir 在挂载外；CI 用普通 checkout。三次容器运行都在（历史 ctr1 也在），是测量挂载形状的产物。
- `51 routes.sh 有失败` —— 只在 `--keep` 那一轮：`TEAM_TMP_KEEP=1` 让各翻转段的嵌套 run 保留自己的临时根，`routes.sh:837` 的收尾检查（`find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'teamsmith-routes.*' -newer "$tmp"`）就会数到它们。**无 `--keep` 的干净复跑里 §51 全绿（171 条断言、1 条可见跳过）**；属 P99 检查在 `--keep` 下的产物，按 F1 范围未动它。

### ⑤ Acceptance（补行后；FAST/全量在代码 tip `3f424e18` 上跑，check 在最终表上复跑）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict     # 17 passed, 0 failed（17 items）

$ bash skills/teamsmith/tests/section-guard.sh --budget-check       # 预算表覆盖 112/112…全过
$ bash skills/teamsmith/tests/section-guard.sh --loop-check         # 全过

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2931  ✗ 0 · smoke 全绿 · exit 0 · 墙钟 726s（11:55:31–12:07:37Z，load 7.3→4.9）

$ bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 3596  ✗ 0 · smoke 全绿 · exit 0 · 墙钟 1480s（12:07:37–12:32:17Z，load 4.9→4.8）
```

全量里 §50=2s / §51=121s（预算 60s / 508s；`#108/#109` 开跑行都带上了表里的预算）；§14d 的整轮对账（开跑/结束/记录行配平、`#N` 严格递增、无超时、无现场残留）逐条绿。相对交付那次全量（1218s，load 8.5）这次的 1480s 是 **+123s 新段（§50/§51）+ 机器/其他交付的波动**，不是 P70 机制的变化。

两个后续提交不动判定：`422638f2`（表头 provenance + §51 host 列 118→121，band/budget 仍 127s/508s）与 `9e9b4085`（本报告）。它们在最终表上复跑的 `--budget-check`（112/112）/`--loop-check`/`openspec validate`（17/0）都在 `logs/f1-final-acceptance.txt` 里。原始日志与逐段实测：`logs/f1-final-acceptance.txt` + `measure/f1-*-section-times.tsv`。

## Suggested next steps

- 复验（`opsx-verify`，另一个 agent）建议直接跑：`scripts/evidence.sh`（standalone 翻转）+ `scripts/crowd-test.sh` + `scripts/ctr-scene-flip.sh`，再按 brief 的三条 Acceptance 在独立 checkout 上复跑。
- 归档前提：**先归档 `pty-fixture-load-premise`**（见上），否则 validate 会红一条（`✗ change/pty-fixture-load-premise`）。
- **建议单开一条 change 修 D33 命令与 M53 夹具的既有冲突**（`logs/d33-pre-existing.txt`）：最简单的形状是 smoke 调 `$M53_HARNESS` 时 `env -u TEAM_SMOKE_FIXTURE`（或在夹具里显式断言自己只能看到清理过的环境）；修好之前，verify 阶段复跑 D33 翻转请带上 main 对照，别把它归到 P70 头上。
- CI 列：本分支合入并产生首次 CI 运行后，把 `gates` 作业 log 的逐段耗时回填 `section-budgets.tsv` 的 `ci_s` 列（重跑 `full1` 用的同一套解析脚本即可）。
