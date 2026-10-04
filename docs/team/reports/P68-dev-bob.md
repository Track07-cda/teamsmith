# P68 · fixture-waits-for-landed-reads apply

```
task:   P68（apply；propose=P62 由 dev-bob 做，本任务同一个席位继续）
change: fixture-waits-for-landed-reads
specs:  verification#A fixture observes a data-derived state before it asserts it（ADDED）
        verification#A measuring fixture measures a fixed tree, not the caller's worktree（ADDED）
deltas: verification
branch: task/P68-apply-ci（本地模式，不 push）
base:   775b9dd4（merge-base HEAD main；前形状夹具从这里取）
机器:   nproc=32 · 本块期间 ambient loadavg 约 4–12（同机还有 PM 与别的席位的门禁在跑）
```

## 结论

三个批次全部落地，验收命令实跑：B1 `panel-p21.sh` 的设置视图等待改成「先观察那一行本身」、
B2 `panel-b3.sh` 的 collapse 从固定 `sleep` + 单次采样改成有界观察、B3 `panel-cpu.sh` 量夹具自己
的中性项目并把两个根都印出来。翻转证据（红侧来自 git base 的 scratch 副本，注入两侧完全一样）
在 `pkg/out/`：

| 配方 | 红侧（前形状） | 绿侧（改后） | 永不落定 |
|---|---|---|---|
| A settings 读 | **`✓108 ✗3`（P52 §C 同款三条红）** | **`✓110 ✗0`** | **`等待超时：数据态 … 30/30`，rc=1** |
| B 控制台首帧 | **`✓2 ✗6`**（P52 F2 的两条红） | **`✓8 ✗0`** | **`✓2 ✗9`**（`缺 [teamsmith pulse]`） |
| C 量测目标 | 同一命令两个树两个根 | 两个调用都量中性根、同一结论 | —— |

验收（brief 的四条）里两条绿、两条红且都点名归属（不是本变更的缺陷）：

- **红 1（既有 finding）**：`TEAM_SMOKE_FAST=1` 的 40 lint 报 fpcheck finding
  （`container-tmux.sh:159/215`、`fixtures/p55/flip-p49.sh:29`）—— P60 已归属 P53/P47 集成、派给 P64，
  本变更没碰那三个文件（`git diff --name-only 775b9dd4..HEAD` 可证）；除此之外 FAST smoke 是 `✓2366 ✗1`。
- **红 2（环境，F-P68-4）**：host 上 `panel-cpu-premise.sh` 的用例 c 判红（首帧 3288ms）：本机
  `health` 块（`team doctor` 的 inotify 扫描）3.8s，首帧对**任何**根都过不了 3.1s 轮询预算；门禁镜像
  同一条夹具 `✓18 ✗0`、首帧中位 1441ms。**2-CPU 容器复核**（P52 的 CI 触发）`✓110 ✗0`。

**全量门禁与容器复核**的原始日志见「门禁」一节。

## 交付明细（对应 change 的 tasks.md，全部 `- [x]`）

### B1 · `panel-p21.sh`（1.1–1.4）

- **1.1** 手改 `TEAM_NOTIFY_TMUX=true` → 等**那一行本身**（`走 tmux 投递 … true · 立即生效`）出现在稳定帧上，
  再按 Enter 开选择器。原路径的组标题骨架 + `sleep 0.5` 不再是证据。等待是 `wait_row`
  （`tests/lib/pty-wait.sh` 的引擎，settled frame + 轮数 + 上界 + 归因）。
- **1.2** 上界 30 轮（≈13–20s）与实测延迟带记在**文件头**（P52 §C：0s 绿 / 2s → 1 红 / 3s → 7 红 /
  6s → 9 红；自然读 <1s），`wait_row` 旁也有指针；耗尽打一行 `等待超时：数据态：…（轮数 n/30；缺 […]）`
  且不报绿、退出非 0。
- **1.3** census：**28 处** `sleep N` + 单次采样 + **2 处**「`sleep` 后直接按键开快照」（`bool-set-row` /
  `bool-spelling-row`，后者就是 CI 那条红的主目标），共 30 处全部转成有界等待（表在「census」一节）；
  输入节奏的 `sleep` 原样保留并说明。
- **1.4** 无性能判定：等待上界是存活探测（D33），没有把耗时/CPU 份额和阈值比较；`TEAM_SMOKE_FAST`
  门禁 + `gate-guard.sh` 绿（门禁/守卫一节）。

### B2 · `panel-b3.sh`（2.1–2.4）

- **2.1** `scn_collapse` 的 `console.txt` / `restored.txt`：`wait_console` 轮询 `teamsmith pulse` 的
  稳定帧（默认 75 轮 ≈ 32s；带宽：安静 <1s、旧固定窗口 5s、P52 F2 负载下 6 次红 4 次、确定性 8s 注入
  在 43–44 轮 ≈19s 落地），`sleep 5` / `sleep 6` + 单次采样删掉。
- **2.2** 同一场景的其余证据：`wait_file_has`（`pulse up` 的日志、`pulse status`/`up2`）、
  `wait_pane_args`（q 收起后的 `--headless` 重生）、`wait_capacity_growth`（capacity.log 行数真的长过
  基线）——全是计数轮 + 上界 + 一行归因；耗尽是红（场景仍在绘制时是引擎的可见 SKIP，D33）。
- **2.3** collapse 之前不 source `pty-wait.sh`；现在显式 source 同一份引擎（不造第二套），并接上
  `pty_cap`/`pty_keys`/`pty_pane_state`（失败现场不再把未知状态说成「窗口不在」）。
- **2.4** census 覆盖本文件：collapse 的 4 处固定延迟转换；**pages/settings/queue/mouse 链**里同形状的
  9 处也一并转换（`wait_cap_has`/`wait_cap_not`/`wait_file_has`）；workdetail/board/detail/resize 的
  交互节奏按分类保留，另记 finding（见文末）。

### B3 · `panel-cpu.sh`（3.1–3.4）

- **3.1** 量测目标 = 夹具自己用 `tests/lib/tmp-root.sh` 建的**中性项目**（`teamsmith-panel-cpu-target.*`
  + 真 `team init`），不再拿 `--root` 指调用者的工作树；输出同时点名
  `== measured project root: …` 与 `== console bundle under test: …`（`--tree` 仍点被测代码树）。
- **3.2** 驱动器不变：`panel-cpu-premise.sh` 的四个期望、`perf.sh --tree` 点名代码树、套件的环境自述
  照旧（`panel-cpu-premise.sh` 实跑见门禁一节）。
- **3.3** 两个工作树对照（工作树 cwd vs 全新项目 cwd）→ 两个中性根、同一结论（证据见 C 表格）。
- **3.4** 阈值与退出码一个没动：2000ms / 1% / 0.25 / 中位规则、0/2/3/4 全部原样；`git diff` 只含
  目标与打印（`pkg/30-cpu-target.sh` 的 C5 断言）。

### B4 · 门禁与证据（4.1–4.4）

见「门禁」与「证据包」。

## 翻转证据（flip）

### A · settings 读延迟（`pkg/10-race-settings.sh`）

注入：scratch 夹具的 wrapper 在**手改之后的那一次** `__panel-data --block settings` 前睡 N 秒
（marker 文件保证只付一次，其余时间正常速度）。两侧注入逐字相同，只有夹具形状不同。

- **A1 前形状 + 6s**：rc=1，`✓108 ✗3`：
  `✗ 非规范 bool 的选择器没有打开`、`✗ 非规范拼写的手改值原样显示成当前条目`、
  `✗ 非规范拼写不许被贴成规范值的标签` —— 与 P52 §C 的 CI 形状逐条一致。
- **A2 改后 + 6s**：rc=0，`✓110 ✗0`；trace 里那条等待是
  `wait 数据态：设置行显示手改后的值 true rounds=N settled=1`（等待落在稳定帧上，不是熬预算）。
- **A3 改后 + 45s（超出上限）**：rc=1，一行归因：
  `等待超时：数据态：设置行显示手改后的值 true` / `轮数 30/30 … 缺 [走 tmux 投递 true · 立即生效]`，
  且没有任何 `✓110 ✗0` 的结果行。

### B · 控制台首帧延迟（`pkg/20-collapse.sh`）

注入：`TEAM_B3_SLOW_JS=<慢启动的 JS runner>`（走产品自己的 `TEAM_JS_BIN` 缝；见「决定与偏差」）。

- **B1 前形状 + 8s**：rc=1，`✓2 ✗6`，两条红正是 P52 F2 的 `pulse 窗口里是控制台` /
  `恢复后同一窗口里又是控制台`。
- **B2 改后 + 8s**：rc=0，`✓8 ✗0`（等待在第 43–44 轮放行）。
- **B3 改后 + 永不落定**：rc=1，`等待超时：pulse 窗口里的控制台首帧 … 缺 [teamsmith pulse]`，不绿。
- **B4 开关关着**：注入被忽略并打印，场景照旧全绿（旋钮纪律）。

### C · 量测目标（`pkg/30-cpu-target.sh`，ok 11 bad 0 finding 1）

| 运行 | 量测根（输出点名） | bundle | 首帧 | 结论 |
|---|---|---|---|---|
| C1 前形状 `tree=工作树` | 工作树（源码 `--root '$tree'`） | 工作树 | never ×3 | rc=2 |
| C2 前形状 `tree=全新树`（完整 skill 拷贝） | 全新树 | 全新树拷贝 | never ×3 | rc=2 |
| C3 改后 cwd=工作树 | **夹具中性根 A** | 工作树 bundle | never ×3 | rc=2 |
| C4 改后 cwd=全新项目 | **夹具中性根 B** | 工作树 bundle | never ×3 | rc=2 |

- C3/C4 的输出都同时点名 `== measured project root: /tmp/.../teamsmith-panel-cpu-target.*` 与
  `== console bundle under test: <工作树>/skills/teamsmith/scripts/panel/panel.js`，两个中性根里都**没有**
  调用者的树（C3/C4 的断言）。两个调用者的 cwd 不同、量的东西相同、结论相同（都是 rc=2，同一句归因）。
- 前形状的红侧是 P52 F4 记录的：同一命令在两个树上 3683ms vs 391ms、一个 rc=2（本机今天两组都 >3.1s，
  见下一条）。C1/C2 的源码面同样成立：`--root '$tree'`，量的就是调用者给的树。
- **F-P68-4（环境，不是本变更）**：面板首帧要等 `health` 块，`health` 跑 `team doctor`，而 M53 起 doctor
  里有 inotify 余量扫描（`team_inotify_used_watches`，逐 pid 逐 fd 的 `readlink/stat`）：本机
  （distrobox 容器，fd 很多）实测 `__panel-data --block health` = **3819ms**，门禁镜像里同一次测量
  = **57ms**（容器 /proc 只有 4 个 pid）。所以本机上 C1–C4 的首帧都被这个底嗓压过 3.1s 轮询预算 →
  全部 `never`/rc=2，**与量的根无关**；`panel-cpu-premise` 用例 c 在本机也因此判红（见「门禁」的
  D5 host 与 E2 容器两行）。P52 F4 的 391ms 是 M53 之前的数字。

## census（D6，设计 §3 D6）

### `panel-p21.sh` —— 28 处 `sleep N` + 单次采样、2 处 `sleep` + 开快照的按键（全部转换）

前形状行号来自 git base；「转换」列是改后文件里的替换（`wait_row` = 等那一行本身在稳定帧上，
`wait_line_gt` = 等聚焦行号超过阈值，同样计数轮 + 上界 + 归因）。

| base 行 | sleep | 采样的东西 | 转换（改后行） |
|---|---|---|---|
| 857 | `sleep 0.5` | bool 写入后重开：`keys Enter` 从（可能还没重读的）旧块开快照 | `wait_row bool-set-row`（等行显示 `0 · 立即生效`） |
| 876 | `sleep 0.5` | **手改 true → 重开视图 → `keys Enter`**（CI `✓108 ✗3` 的形状） | `wait_row bool-spelling-row`（等行显示 `true · 立即生效`） |
| 673 | `sleep 1` | `cap_to overlay-back` | `wait_row overlay-back` L690 |
| 713 | `sleep 0.5` | `cap_to scratch-key` | `wait_row scratch-key` L730 |
| 717 | `sleep 0.5` | `cap_to scratch-class` | `wait_row scratch-class` L734 |
| 814 | `sleep 0.5` | `cap_to bool-row` | `wait_row bool-row` L832 |
| 910 | `sleep 0.5` | `cap_to defer-row` | `wait_row defer-row` L928 |
| 1050 | `sleep 0.8` | `cap_to click-move` | `wait_row click-move` L1069 |
| 1069 | `sleep 0.9` | `cap_to picker-esc` | `wait_row picker-esc` L1089 |
| 1191 | `sleep 0.5` | `cap_to zzz-row` | `wait_row zzz-row` L1211 |
| 1216 | `sleep 0.5` | `cap_to zzz-row2` | `wait_row zzz-row2` L1236 |
| 1411 | `sleep 0.5` | `cap_to seats-verify` | `wait_row seats-verify` L1431 |
| 1415 | `sleep 0.5` | `cap_to seats-dev2` | `wait_row seats-dev2` L1435 |
| 1419 | `sleep 0.5` | `cap_to seats` | `wait_row seats` L1439 |
| 1791 | `sleep 0.4` | `cap_to group-order` | `wait_row group-order` L1830 |
| 1809 | `sleep 0.4` | `cap_to tone-apply; cap_e_to tone-apply-e` | `wait_row tone-apply` L1848 |
| 1814 | `sleep 0.4` | `cap_to tone-restart; cap_e_to tone-restart-e` | `wait_row tone-restart` L1854 |
| 1819 | `sleep 0.4` | `cap_to tone-refuse; cap_e_to tone-refuse-e` | `wait_row tone-refuse` L1860 |
| 1825 | `sleep 0.4` | `cap_to hand-added` | `wait_row hand-added` L1867 |
| 1873 | `sleep 0.5` | `cap_to zzz-group` | `wait_row zzz-group` L1915 |
| 1878 | `sleep 0.5` | `cap_to gates-moved` | `wait_row gates-moved` L1920 |
| 1897 | `sleep 0.5` | `cap_to gates-fallback` | `wait_row gates-fallback` L1939 |
| 1934 | `sleep 0.7` | `cap_to page-scrolled` | `wait_row page-scrolled` L1977 |
| 1969 | `sleep 0.5` | `cap_to wheel-push` | `wait_row wheel-push` L2013 |
| 1975 | `sleep 0.5` | `cap_to wheel-push-back` | `wait_row wheel-push-back` L2021 |
| 1994 | `sleep 0.6` | `cap_to picker-wheel-after` | `wait_line_gt picker-wheel-after` L2041 |
| 2003 | `sleep 0.8` | `cap_to picker-closed` | `wait_row picker-closed` L2051 |
| 2024 | `sleep 0.6` | `cap_to seat-wheel-after` | `wait_line_gt seat-wheel-after` L2072 |
| 2033 | `sleep 0.8` | `cap_to seat-closed` | `wait_row seat-closed` L2082 |
| 2040 | `sleep 1` | `cap_to page-back` | `wait_row page-back` L2092 |

其余 `sleep`（本文件约 90 处）都是**输入节奏**（按键间隔、`for` 走位里的 0.01–0.05s、`type_text` 前后的
0.3/0.4s、`filter_to` 的托盘节奏），按 D6 的「只 pacing 输入、不是证据」保留。

### `panel-b3.sh`

collapse 场景（转换）：

| base 行 | sleep | 采样的东西 | 转换 |
|---|---|---|---|
| 605 | `sleep 5` | `up.log` 的 `巡检已在` + `console.txt` 单次 capture | `wait_file_has` + `wait_console` |
| 612 | `sleep 3` | `wins_after` 与窗格进程 `ps --headless` | `wait_pane_args`（`--headless` 重生） |
| 625 | `sleep 5` | `capacity.log` 行数 c1 → c2 比较 | `wait_capacity_growth`（行数真的长过基线） |
| 635 | `sleep 6` | `status-headless.log` / `up2.log` 断言 + `restored.txt` 单次 capture | `wait_file_has` ×2 + `wait_console` |
| 221/227/232/240/249 | `sleep 1`/`0.5` | `scn_pages`：p2/p2-compose/p3/p3-compose/p1-again 的 `cap_has` | `wait_cap_has` |
| 260/264 | `sleep 0.8` | `scn_settings`：overlay / lang-en 的 `cap_has` | `wait_cap_has` |
| 271/276 | `sleep 0.8`/`0.6` | `scn_settings`：`panel.conf` 的 mouse/density 断言 | `wait_file_has` + 原断言 |
| 279 | `sleep 0.5` | `scn_settings`：浮层关掉的 `cap_not` | `wait_cap_not` |
| 294 | `sleep 0.5` | `scn_settings`：defaultPage 循环的 `page=` 断言 | `wait_file_has` + 原断言 |
| 335/341/346 | `sleep 1`/`0.8`/`0.4` | `scn_queue`：list / view / back 的 `cap_has` | `wait_cap_has` |
| 523 | `sleep 0.6` | `scn_mouse` 链：点击 `m` 后的 compose 行 | `wait_cap_has` |

上表的 pages/settings/queue/mouse 链是同形状的扩展（本变更一并转换，见 finding F-P68-1 的前半）；
**保留**的是 workdetail / board / detail / resize 的 `keys X; sleep N; wcap` 序列：断言的是按键效果与
几何（焦点、页签、宽度档），不是异步读落定 —— 归类为交互节奏。其中 detail/board 的**内容**确实来自
读，它是 finding F-P68-1 的后半（值得单独排一个同族任务）。

### `panel-cpu.sh`

没有 `sleep N` + 断言型采样：`sleep 8` 是**测量协议的 warm-up**（Ink 启动 / 首轮装配 / 第一个 TTL），
`sleep 0.1`（首帧轮询 20 轮）与 `sleep 0.5`（kill 循环 20 轮）是**有界轮询**，`sleep 0.4/1` 是窗口
创建/最后一次机会的节奏，view/detail/compose 旋钮里的 `sleep 0.3–3` 是给按键的节奏（判定是 CPU/首帧
数值，不是帧内容断言）——全部保留，理由如上。

## 证据包（`docs/team/reports/P68-dev-bob/pkg/`）

```
lib.sh              隔离（私有 TMUX_TMPDIR/TMPDIR、unset TMUX/TMUX_PANE）+ 断言 + scratch 夹具工具
10-race-settings.sh A：前/后/超上限（同一注入）
20-collapse.sh      B：前/后/永不落定/旋钮关
30-cpu-target.sh    C：前形状两树 + 改后两调用（+ 阈值未动的 diff 断言）
40-gates.sh         验收命令（validate / FAST / gate-guard / choices / cpu-premise / pty self-test）
run.sh              bash pkg/run.sh [10 20 30 40]
out/*.plain         每段的原始输出（去 ANSI）；out/*.rc 退出码
```

复现前形状：`PKG_BASE=$(git merge-base HEAD main)`（=775b9dd4）的 scratch 副本，**不改动仓库**。

参考环境（门禁镜像，两个额外证据，日志 `out/E*.plain`）：

```
E1  --cpus=2 面板 p21 choices      == 结果 ==  ✓ 110  ✗ 0  SKIP 0    （P52 的 CI 形状 `✓108 ✗3` 5/5 红 → 现在绿）
E2  无配额  panel-cpu-premise      == 结果 ==  ✓ 18  ✗ 0 finding 0   （首帧中位 1441ms < 2000ms 预算）
E3  --cpus=2 panel-cpu-premise     == 结果 ==  ✓ 18  ✗ 1 finding 1   （2 核下首帧 3288ms：配额饥饿，M51/D43 的已知形状）
```

E1 的命令：

```sh
distrobox-host-exec podman run --rm --cpus=2 --cgroups=enabled --userns=keep-id \
  -e HOME=/tmp -e TMPDIR=/out -v "$PWD:/work:ro" -v <outdir>:/out -w /work \
  localhost/teamsmith-gate:local bash -c 'cat /sys/fs/cgroup/cpu.max; bash /work/skills/teamsmith/tests/panel-p21.sh choices'
```

## 门禁

| 命令 | 结果 |
|---|---|
| `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` | rc=0 · `Totals: 26 passed, 0 failed (26 items)`（`out/D1-openspec.plain`） |
| `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` | rc=1 · `✓ 2366 ✗ 1`：唯一的 ✗ 是 **38 节前的 40 lint 既有 finding**（`container-tmux.sh:159/215`、`fixtures/p55/flip-p49.sh:29` 的临时名不在 owned 家族）。P60 的处置已把它归属 P53/P47 集成并派给 P64；`git diff --name-only 775b9dd4..HEAD` 里没有这三个文件 —— 本变更没碰它（`out/D2-smoke-fast.plain`） |
| `bash skills/teamsmith/tests/gate-guard.sh` | rc=0 · 三向都过（`out/D3-gate-guard.plain`） |
| `bash skills/teamsmith/tests/panel-p21.sh choices` | rc=0 · `✓ 110 ✗ 0 SKIP 0`（`out/D4-p21-choices.plain`） |
| `bash skills/teamsmith/tests/panel-cpu.sh --self-check 2>/dev/null \|\| bash skills/teamsmith/tests/panel-cpu-premise.sh` | host rc=1：唯一的 ✗ 是用例 c 的首帧红（**F-P68-4 的环境底嗓**，见 C 段）。门禁镜像同一条夹具（`out/E2`）`✓ 18 ✗ 0 finding 0`、首帧中位 **1441ms** —— 参考环境里验收绿 |
| `bash skills/teamsmith/tests/lib/pty-wait.sh --self-test` | rc=0 · `✓ 15 ✗ 0 SKIP 1`（SKIP 是它自己的超前提分支；`out/D6-pty-selftest.plain`） |
| 全量门禁 `bash skills/teamsmith/tests/smoke.sh </dev/null` | rc=1 · `✓ 2991 ✗ 1`：**唯一的 ✗ 仍是 40 lint 的同一条既有 finding**（逐字与 FAST 一致），其余全绿 —— 包含本变更路径上的 `38-b panel-p21-choices`、`38-f groups/settings/wheel`（`✓ 102 ✗ 0 SKIP 0`）、`38-c pty-wait 自检`、`38-g` 前提/旋钮段。日志 `out/D7-smoke-full.plain`（182 KB，去 ANSI） |
| `git status --porcelain` | 交付提交之后**空**（本报告、证据包、实现与 tasks 全在提交里；见下一节） |

**4.4 · 2-CPU 形状复核（P52 的 CI 触发）**：门禁镜像里 `--cpus=2` 跑 `panel-p21.sh choices`
（`out/E1-container-2cpu-p21-choices.plain`）：

```
200000 100000
== 结果 ==  ✓ 110  ✗ 0  SKIP 0
```

即 P52 记录的 5/5 `✓108 ✗3` 形状在改后夹具上 **5 条 bool 拼写断言全部转绿**（一次跑；命令见「证据包」）。

**容器里的 D5 对照**：无配额 `✓18 ✗0 finding 0`（首帧 1441ms）；`--cpus=2` 时
`✓18 ✗1 finding 1`（首帧 3288ms —— 2 核配额下的启动饥饿，M51/D43 的已知形状，不是本变更）。

## 决定与偏差

1. **apply 条件（悬空引用）**：delta 里指向 `gate-section-accounting`（P56，未合并）的
   `verification#Every wait in the gate is bounded and attributes at its cap` 已改成自含表述
   （计数轮 + 上界 + 归因，`tests/lib/pty-wait.sh` 为模型），红色/SKIP 分派仍引 base 的
   `verification#The correctness gate judges correctness only`（D33）；tasks.md 2.3 同步。P56 落地后
   若要回引，由归档阶段决定。P56 未合并期间没有新增对它的任何引用。
2. **recipe B 的注入缝**：design §3 D2 写的是 `TEAM_B3_PANEL=<slow bundle>`，但 collapse 场景走的是
   产品自己的 `team pulse up`，`TEAM_B3_PANEL` 只影响夹具 `start_panel` 起的面板，到不了那里。
   实际用的是 `TEAM_B3_SLOW_JS`（把产品自己的 `TEAM_JS_BIN` 指向慢启动 runner，`--version` 直通），
   只在 `TEAM_SMOKE_FIXTURE=1` 时生效、否则打印忽略。requirement 的场景允许「或负载主机」，这里是
   确定性的第三种形状；包脚本对前形状做同样的注入补丁，两侧注入逐字相同。
3. **中性目标是每轮一个 owned 临时项目**（不是写死的绝对路径）：`fixed` 解释为「夹具自己固定下来的
   中性参考项目，绝不继承调用者」，而不是「跨进程共享同一个目录」——共享目录会让两次并发门禁互相污染，
   而且会随着轮次积累数据、重新变成非中性。两个调用印出的路径不同、**性质与结论相同**，且调用者树
   不再被量（C 段有断言）。
4. **`panel-cpu.sh --self-check` 不存在**：brief 验收第 4 条写成 `--self-check || panel-cpu-premise.sh`，
   前者会把 `--self-check` 当树参数并以 exit 3 拒绝（stderr 被 `2>/dev/null` 吞掉），实际跑的是
   `panel-cpu-premise.sh`（D5）。没有为此新增旗标（不在本变更范围内）。
5. **`PTY_WAIT_ITERS` 的可见性**：`wait_frame` 自己 `local PTY_WAIT_ITERS=…`，所以调用方在调用前
   `local` 的同名变量会被覆盖（本包第一版实测：`wait_console` 的 50 轮被 `wait_frame` 的 30 轮吃掉）。
   现在上界经 `B3_FRAME_ITERS` 传入，`wait_console` 的旋钮是 `B3_CONSOLE_ITERS`。

## Findings（不在本变更路径上，交给 PM 排期）

- **F-P68-1 `panel-b3.sh` 其余场景的同形状等待**：`scn_workdetail:478/482/490/497/503/507/510/550/570`、
  `scn_board:652/684/688/693/698/717/723/730/734/737/741/744/753`、`scn_resize:553/558/568` 仍是
  `keys X; sleep N; wcap`（焦点/详情/页面/几何）。其中 detail/board 的**内容**从异步读来，值得排一个
  同族任务；resize 的几何判定是重绘节奏。
- **F-P68-2 其它夹具的同形状等待**：`panel-b2.sh` 约 49 处（`sleep N` + `cap_to` 断言）、
  `flip-m17.sh:113`、`flip-m45.sh:178`、`smoke.sh:6345`（`sleep` + `capture-pane` 采样）。
  D6 只说 census 覆盖本变更的三个文件，这些按 finding 报，不静默修、不静默丢。
- **F-P68-4 首帧的环境底嗓（inotify 扫描）**：见 C 段；本机 `health` 块 3819ms vs 门禁镜像 57ms。
  `panel-cpu.sh` 的首帧红线（2000ms）与 3.1s 轮询预算在本机对**任何**根都不可达；本变更的红侧证据里
  这一条归环境，归本变更的部分是「量的根不再随调用者变」与「两个根都被点名」。
- **F-P68-3 `references/openspec.md` §5 的 trial-archive 命令行**：`cp -r openspec /tmp/trial` 只有在
  `/tmp/trial` 已存在时才等价于 `mkdir -p /tmp/trial && cp -r openspec /tmp/trial/openspec`（CLI 解析
  最近的、含 `openspec/` 的祖先目录）。P62 的 tasks 4.2 已实测记录；文档属 PM，未改。

## 交付物

| 路径 | 说明 |
|---|---|
| `skills/teamsmith/tests/panel-p21.sh` | `wait_row`/`wait_line_gt` + 28 处转换 + 文件头的上界/带宽 |
| `skills/teamsmith/tests/panel-b3.sh` | source pty-wait + `wait_console`/`wait_frame`/`wait_cap_*`/`wait_file_has`/`wait_pane_args`/`wait_capacity_growth` + TEAM_B3_SLOW_JS 旋钮 |
| `skills/teamsmith/tests/panel-cpu.sh` | 中性测量目标 + 两个根的名字（+ 结论行带上目标） |
| `openspec/changes/fixture-waits-for-landed-reads/specs/verification/spec.md` | apply 条件：去掉悬空引用 |
| `openspec/changes/fixture-waits-for-landed-reads/tasks.md` | 2.3 同步 + 1.x–4.x 勾选 |
| `docs/team/reports/P68-dev-bob/pkg/**` | 证据包（脚本 + 原始日志，含容器 E1–E3） |
| `docs/team/reports/P68-dev-bob.md` | 本报告 |

## requirement → item → evidence 映射

| requirement（delta） | tasks 项 | 证据 |
|---|---|---|
| `verification#A fixture observes a data-derived state before it asserts it` | 1.1–1.4, 2.1–2.4, 4.1, 4.3, 4.4, 5.1 | A1（红侧 `✓108 ✗3`）/ A2（`wait 数据态 … settled=1`，`✓110 ✗0`）/ A3（`30/30` 归因、rc=1）/ B1–B3 / census / D2+D3+D6 / E1（2-CPU `✓110 ✗0`） |
| `verification#A measuring fixture measures a fixed tree, not the caller's worktree` | 3.1–3.4, 4.2–4.4, 5.1 | C1–C4（两个中性根 + 两个名字 + 同一结论）/ C5（阈值 diff 断言）/ E2（容器 `✓18 ✗0`，首帧 1441ms）/ D8（试归档） |

| scenario（delta） | 项 | 证据 |
|---|---|---|
| A read that lands later is observed, and the old shape is its red side | 1.1 | `A1`（同注入红）/ `A2`（同注入绿） |
| Data that never lands exhausts the wait instead of passing | 1.2 | `A3`（一行归因 + rc=1 + 不报绿） |
| The collapse scene's single sample becomes a bounded observation | 2.1, 2.2 | `B1`（红）/ `B2`（绿）/ `B3`（`缺 [teamsmith pulse]`） |
| No duration judgement enters the fixture | 1.4, 2.3 | D2（FAST）/ D3（gate-guard）/ A2（界内慢读仍绿） |
| Two worktrees, one measured target | 3.1, 3.3 | `C3` vs `C4`（中性根 + 同一结论）；红侧 = P52 F4 的 3683/391ms |
| The measured root and the revision under test are named | 3.1, 3.2 | `C3`/`C4` 的 `measured project root:` / `console bundle under test:` 两行；`perf.sh --tree` 未改 |

## 原始尾巴（节选，完整日志在 `pkg/out/*.plain`）

```
A1（前形状 + 6s，rc=1）  == 结果 ==  ✓ 108  ✗ 3  SKIP 0
  ✗ 非规范 bool 的选择器没有打开
  ✗ 非规范拼写的手改值原样显示成当前条目（…/bool-spelling.txt 里找不到 [true · 当前]）
  ✗ 非规范拼写不许被贴成规范值的标签（不该出现 [关（0） · 当前]）

A2（改后 + 6s，rc=0）    == 结果 ==  ✓ 110  ✗ 0  SKIP 0
  · pty-wait: wait 数据态：设置行显示手改后的值 true rounds=N settled=1

A3（改后 + 45s，rc=1）   == 结果 ==  ✓ 57  ✗ 82  SKIP 0
  · 等待超时：数据态：设置行显示手改后的值 true
      轮数 30/30，耗时约 12s（轮询 0.4s + 稳定确认 0.25s）；缺 [走 tmux 投递 true · 立即生效]
      超时后立即再 capture：画面已静止（条件确实没到，不是中间帧）
  ✗ 手改后的设置行没有在预算内显示新值

B1（前形状 + 8s，rc=1）  == 结果 ==  ✓ 2  ✗ 6
  ✗ pulse 窗口里是控制台（…/console.txt 里找不到 [teamsmith pulse]）
  ✗ 恢复后同一窗口里又是控制台（…/restored.txt 里找不到 [teamsmith pulse]）

B2（改后 + 8s，rc=0）    == 结果 ==  ✓ 8  ✗ 0
B3（改后 + never，rc=1） == 结果 ==  ✓ 2  ✗ 9
  · 等待超时：pulse 窗口里的控制台首帧 … 缺 [teamsmith pulse]

C3/C4（改后，两个 cwd）   rc=2  panel-cpu: RED — the interactive first frame took 9999ms (budget 2000ms …)
                          (measured root /tmp/…/teamsmith-panel-cpu-target.* · bundle …/panel/panel.js)
E1（门禁镜像 --cpus=2）   == 结果 ==  ✓ 110  ✗ 0  SKIP 0
E2（门禁镜像，无配额）    == 结果 ==  ✓ 18  ✗ 0 finding 0 ；first_frame 1441 1440 1443 -> median 1441
```

## 交付状态

- 分支 `task/P68-apply-ci`（本地模式，不 push）：`950a1100`（spec 引用）、`333886be`+`d92fe371`（B1）、
  `93f2c383`（B2）、`e47232b3`（B3）、`f0a4731e`（报告+证据包）、本提交（tasks 勾选 + 全量门禁尾巴）。
- `git status --porcelain` 为空（PM 复验时 `git -C <本 worktree> status --porcelain` 应无输出）。
- 未推送、未合并：按本地模式留分支给 PM 复验后本地合并。
