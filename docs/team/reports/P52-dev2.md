# P52 · pty-fixture-load-premise 独立验证

```
task:   P52（verify；apply=P48 由 dev3 做 —— 本任务不是它的作者）
change: pty-fixture-load-premise
specs:  panel#The project-settings pty fixture judges under a machine premise（ADDED）
        verification#The correctness gate judges correctness only（MODIFIED）
        verification#A load experiment signals only the processes it started（ADDED）
branch: task/P52-pty（本地模式，不 push）· 验证基线 tip: 764ccfc（P48 apply b8fa1ad 在其历史里）
机器:   nproc=32 · 本块期间 ambient loadavg 约 2.9–13（同机还有 dev-bob / verify / dev3 席位的门禁在跑）
```

## 结论

**PASS —— 变更本身没有发现缺陷。** 四条承诺都独立成立：

1. **前提行是真读数**（loadavg/核数/代码无关探针与机器逐值一致），注入旋钮在真路径被忽略并打印，
   只在 `TEAM_SMOKE_FIXTURE=1` 下生效；
2. **延长有界**（`base × PTY_EXT_FACTOR`），**静态场景一点不延长**，耗尽那一刻按**机器读数**归因；
3. 超前提 = 一行可见 **SKIP + rc 4**；门禁判定表把 rc 4 记成 `SKIP（条件不满足）`（`SKIP_N=1`、`FAIL=0`）
   —— 不是 pass、不是红；把 rc 4 映射成 `ok` 的变异会被记账断言当场抓住（假绿形状）；
4. **D37**：非自有目标在发信号前被拒（status 2），破坏归属检查后非自有进程**真的**收到 `SIGSTOP`
   （现场 `state=T`），还原后拒绝且目标没被动过；全量跑完无 `T` 残留、无私有 server 残留、无 `/tmp` 新增。

5. **PM 追加（延长的硬上限 + CI 2 核红，2026-09-22）**：单次等待硬上限 = 站点 base × 3
   （实测 120/120、240/240；“仍在绘制”判据恒真的变异也不越界）。CI 那条 `✓108 ✗3` 在 2 核配额下
   **5/5 复现**，归属为**设置视图读取新鲜度的节奏**（视图打开时的 force 读是异步的，夹具没等它落定就
   开了选择器，而选择器条目是一次成形的快照）——**不是** P48 的前提/延长（5× 视界仍红）。详见“P52 追加”。

同时报四条**不在本变更路径上**、但 PM 独立复验时会撞到的环境/邻居夹具问题（**不是**对本变更的 finding）：

- **F1（两次复现）** 全量门禁 `31b2 容器里跑真 pi 体检` 必红：容器里的 pi 弹 **workspace 信任对话框**
  （容器 `--rm` 且不挂 `$HOME`，没有 `trust.json`），输入框体检拿不到“空闲空框”。
- **F2** `panel-b3.sh` 的 `collapse` 段用固定 `sleep 5` + 单次 `capture-pane`；本块 6 次执行里红 4 次、绿 2 次
  （红在两条不同等待上）。本变更不碰 panel-b3、它也不 source `pty-wait.sh`。
- **F3** 包环境里那次全量门禁的 `12b-h` 出现 64 条“私有 server 没了”的级联；同一分支干净环境下 `12b-h` 全绿。
- **F4（可复现）** `panel-cpu.sh` 量的是**调用工作树**的面板首帧：本工作树 3683ms / 全新根 391ms，
  超过该夹具 ~3s 的轮询预算 → rc=2。本变更不碰面板源与 `panel-cpu.sh`。

## 怎么验的（独立性与隔离）

- **不碰实现**：`skills/teamsmith/**` 一个字节没改（各节自己断言 `git status`）；所有变异都在
  `pkg/out/scratch/` 的副本或临时树上。
- **自己的判据**，不复用实现的 `--self-test` 场景：
  - `pkg/fake-pane.sh` + `pkg/extension-harness.sh`：我自己的假 pane，五种现场（慢但绘制 / 静态 /
    永远绘制 / 静态+超前提 / 静态+前提之内）独立判延长、有界、归因；
  - `pkg/gate-verdict-harness.sh`：把 `smoke.sh` 的 `ok`/`bad`/`cond_skip`/`fast_skip`/`p38_verdict`
    **按行区间原样抽出**再跑（抽出函数 sha256 打在日志里），喂真实 rc=4 夹具日志与变异日志；
  - `pkg/25-wheel-regression.sh`：scratch 树删掉设置视图的滚轮消费 + **重建 bundle**，跑真 `wheel` 场景拿红侧。
- **隔离**：私有短路径 `TMUX_TMPDIR=/tmp/p52v-<uid>-<pid>/t` + 私有 `TMPDIR` + `unset TMUX TMUX_PANE`；
  全量门禁显式指共享锁 `/tmp/teamsmith-smoke.lock`（不破坏“一台机器一次一套全量”）。
  **踩过的坑（写进包注释）**：私有 socket 路径太深会撞内核 108B 上限 → tmux `error connecting … File name too long`，
  pty 夹具会整片假红；私有根必须放 `/tmp` 下的短路径。
- **隔离纪律**：所有夹具的 socket/临时目录都在本包私有根里；快照对比证明默认 server 的会话一个没少。

## 运行清单（可复现的原始日志都在 `docs/team/reports/P52-dev2/pkg/out/`）

| 运行 | 命令要点 | 产物 |
|---|---|---|
| 干净环境全量门禁 | `bash skills/teamsmith/tests/smoke.sh </dev/null`（不带任何包旋钮） | `61-full-smoke-standalone.log`（`✓ 2857 ✗ 1`） |
| 包环境全量门禁（P48 注入之外的对照） | 包第 60 节第一次跑，共享锁排队 | `60g-full-smoke.log`（`✓ 2782 ✗ 64`） |
| 官方整包跑（第一次） | `bash docs/team/reports/P52-dev2/pkg/run.sh` | `final3-run.log`（10/20/25/30/40/65 绿；60 见 F4；90 见下） |
| 官方整包跑（第二次，含两处 harness 修正） | `PKG_ONLY=60,90 PKG_SMOKE_LOG=<干净全量日志> PKG_SMOKE_RC=1 …` | `final4-run.log`（60/90 的最终判定） |
| 归因实验 | 面板首帧手测（本工作树 vs 全新根）、容器 pi 体检复现 | `65a-container-pi.log`、本报告 §F4 |

（本块的 harness 中途修过两处——快照解析把 `default` 之类的内容行当作段结束、以及 FAST 跳过行带颜色时
固定串不匹配；两次修正后重跑了受影响的 60/90 节，日志就是上面两份。除此之外没有改任何被测文件。）

### Acceptance（brief 列的四条，全部实跑）

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict          # Totals: 20 passed, 0 failed (20 items) · rc=0
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null     # ✓ 2328 ✗ 0 · rc=0  （60f）
bash skills/teamsmith/tests/panel-p21.sh choices                      # ✓ 110 ✗ 0 SKIP 0 · rc=0（60a）
bash skills/teamsmith/tests/load-experiment.sh --guard-test           # ✓ 17 ✗ 0 SKIP 0 · rc=0（40a）
```

交付时工作树（本地模式，不 push）：`git status --porcelain` 为空；分支 `task/P52-pty` 上三个提交
（`ad2318a` 包、`50702e9` 证据日志、`ff822f3` 本报告）。

## 证据（brief 的六条判据）

### 1）前提行是真读数；注入不漏进真路径

```sh
# 真路径（开关关）+ 两个旋钮注入
TEAM_P21_PREMISE_ONLY=1 TEAM_P21_PREMISE_PROBE_MS=1 TEAM_P21_PREMISE_LOAD_FACTOR=0.01 \
  bash skills/teamsmith/tests/panel-p21.sh choices                       # rc=0
TEAM_P21_PREMISE_PROBE_MS=1 TEAM_P21_PREMISE_LOAD_FACTOR=0.01 \
  bash skills/teamsmith/tests/panel-p21.sh wheel                         # rc=0（✓ 23 ✗ 0 SKIP 0）
# 夹具开关打开 → 注入被采信
TEAM_SMOKE_FIXTURE=1 TEAM_P21_PREMISE_ONLY=1 TEAM_P21_PREMISE_PROBE_MS=999 \
  TEAM_P21_PREMISE_LOAD_FACTOR=0.01 bash skills/teamsmith/tests/panel-p21.sh choices wheel  # rc=0
```

真路径前提行（`10a`，与 `/proc/loadavg`、`nproc` 逐值相同）：

```
  忽略 TEAM_P21_PREMISE_PROBE_MS=1（只有 TEAM_SMOKE_FIXTURE=1 时夹具旋钮才生效；真实路径读真值）
  忽略 TEAM_P21_PREMISE_LOAD_FACTOR=0.01（…同上…）
== 前提 choices：loadavg_1m 2.89 / loadavg_5m 5.01 · 逻辑核 32 · 代码无关探针 11ms（顶 120ms）· 粗闸门 64.00 = 2.0×32 核 ==
```

- 前提行在第 5 行、第一个断言在第 9 行（**在第一个断言之前**）；探针与包自己的探针同量级；
- 真路径 + 注入仍 `✓ 23 ✗ 0 SKIP 0` rc=0 —— 若 `TEAM_P21_PREMISE_LOAD_FACTOR=0.01` 泄漏，入口粗闸门会
  跳过整个场景，实际没有；
- 开关打开：每个场景一行前提、注入探针 `999ms（顶 120ms）` 与 `0.01×32 核` 被采信、**没有**忽略行。

### 2）延长有界、静态不延长、耗尽按机器归因

**(a) 实现自带自检及其破坏档**：base `✓ 15 ✗ 0 SKIP 1` rc0；`noext` `✓ 14 ✗ 1` rc1（点名
`延长没有生效`）；`alwaysext` `✓ 11 ✗ 4` rc1（点名`静态场景被延长或没红`）；`noskip` `✓ 15 ✗ 1` rc1；
`alwaysskip` `✓ 11 ✗ 4` rc1。

**(b) 我自己的假 pane（独立）**：`ok 5 bad 0` ——

```
慢但仍在绘制：等到第 9 轮（基础 6 之上）判绿，rc=0
静态场景：基础视界 6 轮用满即红（rc=1），延长一点没给
永远在绘制：在第 18 轮（=6×3）停住，rc=3 可见跳过（延长有界）
静态 + 机器超前提：rc=3 可见 SKIP（一行，带等待名与读数）
静态 + 前提之内：rc=1 红并带 M59 现场（SKIP 不是逃逸门）
```

**(c) 真夹具里的静态负例**：`choices` 的 `wait_picker_quick` 硬化钉（等一个不存在的条目）用满 6 轮
在 stderr 打 M59 现场（`轮数 6/6`、`画面已静止`），夹具把它当预期负例而**不是** SKIP——
静态场景没有被延长（否则会走满 18 轮）、也没有被机器前提吞掉。

### 3）超前提 = 可见 SKIP + rc 4；门禁记账不假绿

**(a) 夹具侧**（注入探针 999 > 顶 120）：

```
SKIP 等待耗尽但归因于机器（既不是通过也不是失败）：面板首帧（choices） · 轮数 80/240 · 耗时约 21s
     · 场景已静止 · 缺 [◊P48-注入：状态永不到来◊] · 归因：loadavg_1m 2.73 vs 粗闸门 64.00（2.0×32 核）；探针 999ms vs 顶 120ms
== 结果 ==  ✓ 0  ✗ 0  SKIP 1            rc=4
```

**(b) 一个场景跳过、其余照判**（探针顶注入成 1ms；`choices` 的负例等待因此归因给机器）：

```
[30b-mixed] rc=4   结果行：== 结果 ==  ✓ 179  ✗ 0  SKIP 1
```

**(c) 门禁判定表**（原样抽出的 `p38_verdict`，sha256 `d72e501bf2ea…`）：

| 夹具 rc | 判定表输出 | PASS/FAIL/SKIP_N |
|---|---|---|
| 4 | `SKIP（条件不满足） 38-b panel-p21 fixture —— SKIP 等待耗尽但归因于机器…` | 0/0/1 |
| 0 | `✓ 38-b panel-p21 fixture 全绿（ ✓ 23 ✗ 0 SKIP 0）` | 1/0/0 |
| 1 | `✗ 38-f panel-p21 fixture 有失败` + 前 8 条 ✗ | 0/1/0 |
| 3 | `✗ 38-b panel-p21 fixture 搭建失败（exit 3）` | 0/1/0 |

**(d) 变异：rc=4 映射成 `ok`**：一个被跳过的夹具被印成 `… 全绿（ ✓ 0 ✗ 0 SKIP 1）`、`SKIP_N=0`；
还原后回到 `SKIP（条件不满足）`。

**(e) 端到端**：P48 报告 §3.1③ 有注入的全量门禁（§38-b/§38-f 都打 SKIP、门禁 `✓ 2850 ✗ 0`）；
本块按 brief 允许的“读代码 + 单测证明”用**真函数 + 真 rc=4 日志**独立钉住这一环（PM 可重跑，见下）。

### 4）D37：实验只对自己 spawn 的进程发信号

真树 `load-experiment.sh --guard-test` → **`✓ 17 ✗ 0 SKIP 0`**（自有子进程 hold 期间 `T`；正常结束 /
`TERM` / `INT` 中途被杀都释放回 `S`；非自有目标 status 2 拒绝并点名归属；模式形状/空列表/空 PID/自信号全拒）。

我自己的独立检查：实现里 `pgrep|pkill|killall|pidof` **0 命中**（自己另写 grep）；`trap le_cleanup EXIT INT TERM`、
`le_ppid`、`sleep "$secs" & wait` 都在；真父子进程可冻结并释放，**反向（owner=子、目标=父）被拒**。

**破坏归属检查**（scratch 副本 `le_is_owned` 直接 `return 0`）：

```
变异 freeze：rc=0，非自有目标在 hold 期间的 state=T     ← 信号真的发出去了（红侧证据）
变异版自己说给非自有目标发了信号（froze [pid]）；退出后由它自己的陷阱释放（不再是 T）
还原后 freeze：rc=2 · refusing <pid> — not the owner (<pid>) nor a descendant of it
还原后非自有进程没被动过（state 不是 T）
```

### 5）零残留

`90-residue.sh`（final4）在整节 60 的夹具跑完前后各取一次全机快照（`residue-{before,after}.txt`）：

```
T 进程：before=0 after=0            ok 全机没有 T 状态进程（直接测量 0）
包私有 socket 目录残留：0 个         ok
私有临时根里的夹具残留：0 个         ok
tmp_panel_p21 / tmp_load_experiment / tmp_pty_wait_selftest：before=after，新增 0
默认 tmux server 上原有的会话一个没少（after 4 个名字，均在 before 里）· 默认 server 还活着
→ == 90 零残留 结果 == ok 13 bad 0（唯一 finding：另一个已结束包厢的空壳 p52v 根，收尾已清）
```

收尾直接测量（`14:2x`）：`T` 进程 0；本包的 `/tmp/p52v-*` 全部清掉（整包跑的私有根由 run.sh 收尾）；
`/tmp/panel-p21.p3KLmI` 是**别的席位**正在跑的活夹具（mtime 14:19、有 4 个 panel 进程），不是本包留下的。

### 6）零回归

| 命令 | 结果（final4 / 61 日志） |
|---|---|
| `panel-p21.sh choices` | `✓ 110 ✗ 0 SKIP 0` rc=0 |
| `panel-p21.sh groups settings wheel` | `✓ 102 ✗ 0 SKIP 0` rc=0（三行前提） |
| `panel-b3.sh` | `✓ 155 ✗ 0` rc=0（见 F2：同一夹具本块 6 次执行里红 4 次，都是 `collapse` 的单采样等待） |
| `panel-cpu.sh` | **rc=2**（首帧 never；复跑也 rc=2）→ 见 F4：本工作树首帧 3683ms vs 全新根 391ms |
| `gate-guard.sh` | rc=0（三向都过） |
| `TEAM_SMOKE_FAST=1 smoke.sh` | `✓ 2328 ✗ 0` rc=0；§38-b/§38-f 带原因可见 SKIP；§38-d/§38-e/§38-g①/② 照跑 |
| 全量 `smoke.sh`（干净环境） | `✓ 2857 ✗ 1` rc=1 —— **唯一顶层红 = 31b2 容器真 pi 体检（F1）**；§38-b `✓ 110 ✗ 0`、§38-c `✓ 15 ✗ 0 SKIP 1`、§38-f `✓ 102 ✗ 0` 全绿 |
| 全量 `smoke.sh`（包环境那次） | `✓ 2782 ✗ 64` —— 31b2（F1）+ `12b-h` 级联（F3，干净环境复跑全绿） |

## Flip evidence（红 → 绿原始输出）

1. **延长上限改回“不延长”**（第 20 节）：`ok 5 bad 0` → `ok 3 bad 2`（`慢但仍在绘制没有被等到判绿`、
   `永远在绘制没有被有界停住`）→ 还原 `ok 5 bad 0`。
2. **rc=4 在 `p38_verdict` 里映射成 `ok`**（第 30 节）：`SKIP（条件不满足）`/`SKIP_N=1` →
   `全绿（ ✓ 0 ✗ 0 SKIP 1）`/`SKIP_N=0` → 还原回到 SKIP。
3. **破坏 freeze 的归属检查**（第 40 节）：非自有进程真的变 `T`（信号已发）→ 还原 rc=2、state 不变。
4. **真回归翻转**（第 25 节，`panel#…`“前提不是逃逸门”场景）：scratch 树删滚轮消费 + 重建 bundle →
   `panel-p21.sh wheel` `✓ 19 ✗ 4` rc=1（点名滚轮断言、`SKIP 0`）；同一命令原树 `✓ 23 ✗ 0 SKIP 0` rc=0。
5. 工作树干净：`skills/teamsmith/**` 无改动（各节各自断言；`git status` 见报告尾）。

## 覆盖映射（delta → requirement 场景 → 证据）

| delta | 场景 | 证据 |
|---|---|---|
| panel（ADDED）· 夹具按机器前提判定 | 超前提 → 可见 SKIP | 30a/30b/30c |
| | 前提之内仍红真回归 | 25（重建 bundle 的真回归）+ 20b（静态红） |
| | 静态失败不延长不跳过 | 20b/20c + 60a 的 `wait_picker_quick` 现场 |
| | 真路径读数保持真 | 10a/10b/10c |
| | 门禁把跳过印成可见 SKIP | 30c/30d/30e + 30g 变异 |
| | FAST 不进 pty、钉子还在 | 60f |
| verification（MODIFIED）· 门禁只判正确性 | 慢但正确仍绿 | 20b 延长 + 60f 全绿 + 60g 里 §38-* 全绿 |
| | 墙钟判定不能悄悄回来 | 60e（gate-guard 三向） |
| | 旋钮完整性（不测量） | 10a + 60f §38-g② |
| | 超前提跳过、门禁不红 | 30a + 30c |
| | 前提不是真回归的逃逸门 | 25 + 20b |
| | 跳过绝不被印成通过 | 30c + 30g |
| | 真路径读数不假 | 10a/10c |
| verification（ADDED）· 实验只对自有进程发信号 | 非自有目标发信号前被拒 | 40a + 我的父子实验 |
| | 模式形状被拒（无主机级匹配） | 40a + 独立 grep |
| | 中途被杀不留 `T` | 40a（TERM/INT） |
| | 负载是自有负载、夹具私有 | 40a side 6 + 90 |

## P52 追加（PM 12:24–13:14）：延长的硬上限 + CI 2 核红的复现与归属

三条追加问题各自的答案与计数证据；命令、原始日志（`pkg/out/70-*`、`pkg/out/71-*`）都可复跑。**实现一行未动。**

### A · 延长有没有硬上限：有，单次等待 = 站点 base × 3（最大 240 轮）

- 边界在 `skills/teamsmith/tests/lib/pty-wait.sh:218-229`：`base=${PTY_WAIT_ITERS:-40}`、`extf=${PTY_EXT_FACTOR:-3}`、
  `ceiling=$((base*extf))`、`while [ "$i" -lt "$ceiling" ]` —— 轮数计数到顶就退出，没有第二条轮询路径。
- 站点覆盖（`panel-p21.sh`）：292 行 `wait_panel` base 80 → 240；319 行 `wait_cap` 30 → 90；368 行 `open_view` 40 → 120；
  402/412 行 `filter_to`/`filter_clear` 8 → 24；452 行 `wait_picker_quick` 6 → 6（6 < 稳定窗口 8，不满足“已观察 ≥8 轮”，永不延长）。
- `pkg/ceiling-probe.sh`（我自己的假 pane，真常数）：

```
  A 永远绘制（真节奏 0.35/0.25）：rc=3 rounds=120/120 耗时 43093ms
  B 恒真仍绘制 + 静态现场（变异 `_pty_painting_recent(){ return 0; }`）：rc=3 rounds=120/120
  C 静态场景（真引擎）：rc=1 rounds=40/120
  D 站点 base=80：rc=3 rounds=240/240
== ceiling-probe 结果 == ok 6 bad 0
```

  B 就是 PM 担心的形状（“仍在绘制”判据恒真）：**仍然停在 120 轮**，没有无限轮询；A 是真实节奏下的单次上限实测（43s；
  库注释的 ~78s 是加上更慢 capture 的保守值——界由轮数给，不由钟表给）。
- 真实夹具的计数：5 次 2 核配额跑每次 **53 个等待**（trace 行数），**max_rounds=40** —— 唯一耗尽的就是那条静态 picker
  等待（`轮数 40/40，耗时约 14s`），没有任何等待超过自己的 base。
- 结论：CI 那轮偏慢不是无限轮询（PM 已更正为 runner 排队；作业本身 21m28s、与 P48 无关），本项只需记入“硬上限有实测边界”。

### B · CI 红的 2 核复现：5/5 全红，形状与 CI 一致

配方（`pkg/70-cpu-quota-repro.sh`；配额证明 = 每次容器内 `cpu.max` 打印）：

```sh
distrobox-host-exec podman run --rm --cpus=2 --cgroups=enabled --userns=keep-id \
  -e HOME=/tmp -e TMPDIR=/out -e TEAM_P21_KEEP=1 -e TEAM_P21_TRACE=1 \
  -v "$PWD:/work:ro" -v <hostdir>:/out -w /work localhost/teamsmith-gate:local \
  bash -c 'cat /sys/fs/cgroup/cpu.max; bash skills/teamsmith/tests/panel-p21.sh choices'
```

| run | `cpu.max` | 前提行（节选） | 结果 |
|---|---|---|---|
| 1 | `200000 100000` | `loadavg_1m 4.81 / 5.26 · 32 核 · 探针 14ms（顶 120ms）· 粗闸门 64.00` | `✓ 108 ✗ 3` |
| 2 | `200000 100000` | `loadavg_1m 5.02 / 5.26 · 32 核 · 探针 11ms` | `✓ 108 ✗ 3` |
| 3 | `200000 100000` | `loadavg_1m 6.40 / 5.56 · 32 核 · 探针 11ms` | `✓ 108 ✗ 3` |
| 4 | `200000 100000` | `loadavg_1m 4.76 / 5.23 · 32 核 · 探针 11ms` | `✓ 108 ✗ 3` |
| 5 | `200000 100000` | `loadavg_1m 6.95 / 5.79 · 32 核 · 探针 11ms` | `✓ 108 ✗ 3` |

每次的三条红完全一样（PM 的现场同款）：

```
✗ 非规范 bool 的选择器没有打开
✗ 非规范拼写的手改值原样显示成当前条目（…/bool-spelling.txt 里找不到 [true · 当前]）
✗ 非规范拼写不许被贴成规范值的标签（不该出现 [关（0） · 当前]）
```

超时现场（run 1，`pkg/out/70-scenes/run1/pty-scene-*.txt`）：`wait picker TEAM_NOTIFY_TMUX (40 rounds / ~14s)`、
`缺 [true · 当前]`、pane 上 `› 关（0） · 当前`（选择器开着、行是旧值）——与 PM 留在 `/var/tmp/p21-fail-scene/` 的形状一致。
5 次里 premise 全部**在前提之内**（粗闸门 64.00），所以是判红而不是 SKIP。

### C · 归属：设置视图读取新鲜度的节奏（②），不是 P48 的前提/延长（①）

代码链（三条）：

1. `src/main.tsx:788-793`：打开设置视图（`setSettingsOpen(true)`）会 **force 读一次** settings
   （`cache.refresh({force:true, only:['settings']}).then(adopt)`）——读是异步的，视图可以先画出来。
2. `src/App.tsx:1251-1258`（`openSettingsRow`）：选择器的条目 = `buildChoiceEntries(key)` **一次成形**，存进
   `choicePicker` 状态；之后 settings 数据 adopt **不会**重建它 —— 从旧块打开的选择器，**任何视界都不会**出现新值。
   （这是 M65/D11 的既定语义：“编辑器开在屏上已有的 settings 块上，按键到帧之间没有读”。）
3. 夹具 `panel-p21.sh:862-880`：手改 `=true` → `reopen_view`（等的标记是分组标题，骨架也能出）→ `filter_to` +
   `sleep 0.5` + Enter 开选择器 → `wait_picker … 'true · 当前'`。**没有任何一步在等第 1 条那次强制读落定。**

决定性实验（`pkg/71-race-injection.sh`；只在 scratch 夹具的 wrapper 里给面板的 `__panel-data --block settings`
加 `sleep`，实现在真树里一行未动）：

```
A 延迟 0s：            ✓ 110 ✗ 0
B 延迟 6s：            rc=1（bool 家族 9 条红）
C 延迟 6s + 200 轮视界：rc=1（那条等待 200/200、约 75s，仍然缺 [true · 当前]）→ 视界不是解药
调参：delay 2s → ✓ 110 ✗ 1（红挪到 esc 块）；delay 3s → ✓ 106 ✗ 7；delay 6s → ✓ 104 ✗ 9
```

- A→B 是同一夹具、同一台机器的翻转：**慢在 settings 读上就红**；C 证明把视界放大 5 倍也没用（快照冻结）。
- 配额 5 连跑的 `choices-argv.log`（`pkg/out/70-scenes/run1/`）里记录了 9 条 settings 读；延迟注入的 B 跑
  （`pkg/out/keep-race-71b-race-delay6/choices-argv.log`）里有 8 条：**读发生了、也落定了**，只是已开的选择器
  不消费后来的数据——与代码链一致。
- 关于 PM 的 ④（“前提测的是机器闲不闲，不是这份负载跑不跑得动”）：属实——前提读的是**宿主**（loadavg/nproc/探针），
  对 cgroup 配额盲；容器 `--cpus=2` 时宿主看着健康、夹具被饿着。但这不是这条红的成因，也不是解药（C 已证）：
  真因是“选择器快照 + 没等强制读落定”，把它判成 SKIP 反而会掩盖。剩下的是一个**独立观察**：探针若不在同一
  cgroup/容器里跑，就看不见配额饥饿（可作 P48 之后的独立课题，不是本变更的缺陷）。

**给 PM 的开单建议**：夹具侧——开选择器前先等视图行出现新值（或等一个“读已落定”的可等待信号）；产品侧是否让
settings adopt 后重建已开选择器的条目（M65/D11 的“用屏上的块”语义）由 PM 决定。

### 追加部分的原始输出

| Path | What |
|---|---|
| `pkg/ceiling-probe.sh` + `pkg/out/70-ceiling-probe.log` | 硬上限四例实测（120/120、240/240、恒真仍绘制、静态 40） |
| `pkg/70-cpu-quota-repro.sh` + `pkg/out/70-cpu-run{1..5}.{log,plain}` + `pkg/out/70-cpu-repro-summary.log` | 2 核配额 5 连跑（前提行 + 结果 + 53 个等待的 trace） |
| `pkg/out/70-scenes/run1/` | 红跑现场（`choices-argv.log` 8 条 settings 读、`bool-spelling.txt`、超时场景） |
| `pkg/71-race-injection.sh` + `pkg/out/71{a,b,c}-*.log` + `pkg/out/71b-choices-argv.log` | 延迟注入 A/B/C（0s 绿、6s 红、6s+5× 视界仍红） |

## 发现（都不落在本变更的路径上）

### F1 · 全量门禁的 31b2 容器真 pi 体检必红（环境，会复现）

- 两次独立全量跑的顶层红都只有这一条，且第 65 节能独立复现（`65a-container-pi.log`，rc=1）：

```
         11	   Do not trust
         12	   Do not trust (this session only)
         14	 ↑↓ navigate  enter select  escape/ctrl+c cancel
  M45 idle-read=NOT-EMPTY BAD
```

- pi 文档（`docs/security.md` §Project Trust / `docs/settings.md`）：项目里有需要信任的资源
  （本仓库有 `.pi/prompts`、`.pi/skills`）且没有保存过的决定时，交互式启动会问；该夹具
  `container-tmux.sh --with-pi` 用 `--rm` 容器、`HOME=/root` 且**刻意不挂 `$HOME`**，所以容器里
  永远没有 `~/.pi/agent/trust.json`，这一节拿不到“空闲空框”。
- 本变更的文件清单（`65-diff-files.txt`）只含 `pty-wait.sh` / `panel-p21.sh` / `smoke.sh` /
  `load-experiment.sh` + 报告；不含 `container-tmux.sh` / `pm-box-real.sh` / 面板源。
- 建议（PM 定夺）：给这条体检一个信任前提（容器 pi 传 `--no-approve`、或设 `defaultProjectTrust`，
  或在检测到信任对话框时可见 SKIP 并打印原因），否则每个席位在这台机器上的全量门禁都会红在这一条。

### F2 · `panel-b3.sh` 的 `collapse` 段是固定 sleep + 单次采样

- 本块 6 次执行里红 4 次、绿 2 次（红在不同等待、同一段）：

```
✗ pulse 窗口里是控制台（…/collapse/console.txt 里找不到 [teamsmith pulse]）
✗ 恢复后同一窗口里又是控制台（…/collapse/restored.txt 里找不到 [teamsmith pulse]）
```

- 源码 `panel-b3.sh:602-605`：`sleep 5` 后单次 `capture-pane`（无稳定帧、无轮询）；面板/巡检在负载下
  首帧落在 5s 之后。本变更不碰 `panel-b3.sh`，它也不 source `pty-wait.sh`。
- 这正是本变更在 `panel-p21.sh` 里修掉的同一类形状；建议排一个同族任务。

### F3 · 包环境里那次全量门禁的 12b-h 级联（并发/噪声）

- `60g-full-smoke.log`：`✓ 2782 ✗ 64`，64 条全在 `12b-h`，第一条现场
  `no server running on /tmp/teamsmith-smoke.g4b0CS/tmux/tmux-1000/default`（夹具私有 server 没了）→ 后面是级联。
- 同分支干净环境独立跑 `12b-h` 全绿（`61-full-smoke-standalone.log`）→ 判为机器/并发噪声；
  该段历史上就因固定 `sleep` 出过这个形状（M35 报告）。
- 与本变更无关：变更不碰 `12b-h` 路径。

### F4 · `panel-cpu.sh` 量的是调用工作树的面板首帧（可复现）

- `final3`/`final4`（前提成立时）连续 rc=2：`first frame: never never never -> median never`，
  面板进程 CPU 0.60% 正常。
- 干净环境（不带本包任何旋钮）复现：`66a-panel-cpu-clean1.log` → rc=2、同样的 `never`。
- 手测（同一 bundle、同一台机器、同一时刻）：

```
root=<本工作树>  first_frame=3683 ms
root=<全新空项目> first_frame= 391 ms
```

  该夹具轮询预算 ≈ 20×0.1s + 1s ≈ 3s（`panel-cpu.sh:188-201`），所以在本工作树上必红。
  把本包自己的 `state/bg` 与报告目录暂时移开后再测仍是 3.7s → 不是本包产物，是本工作树这个
  项目的面板首帧本身慢（夹具测的是**调用树**，不是夹具自己的临时项目）。
- 本变更不碰面板源与 `panel-cpu.sh`；建议 PM 复验时用干净/较小的树或把该夹具改成夹具根（同族任务）。

## 决定与偏差

- 门禁侧 rc=4 的映射用**原样抽出的真函数 + 真夹具日志**验证（brief 明确允许“读代码 + 单测证明”）；
  没有重复 P48 已跑的注入全量门禁（约 25 分钟 + 共享锁排队）。
- 全量门禁的官方证据用**干净环境**的一次独立跑（`61-full-smoke-standalone.log`），第 60 节的 60g
  复用这份日志（`PKG_SMOKE_LOG` / `PKG_SMOKE_RC`）；唯一红 F1 单独在第 65 节归因。
- 邻居夹具的红（F2/F4）按“已知单采样/前提形状 + 复跑”判定：只降级为 finding，且**报出原始红行**；
  复跑仍红的 F4 记为 bad 并单独归因（不是本变更的路径）。
- 变异只在临时副本与私有短路径临时根里；真树实现未改。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P52-dev2.md` | 本报告 |
| `docs/team/reports/P52-dev2/pkg/run.sh` | 独立复验包入口（`PKG_ONLY` / `PKG_SKIP_LONG` / `PKG_SMOKE_LOG` 可调） |
| `docs/team/reports/P52-dev2/pkg/lib.sh` | 隔离环境（私有短路径 tmux/TMPDIR、清身份、快照、原样抽函数） |
| `docs/team/reports/P52-dev2/pkg/{10,20,25,30,40,60,65,90}-*.sh` | 六条判据 + 归因分节 |
| `docs/team/reports/P52-dev2/pkg/{fake-pane.sh,extension-harness.sh,gate-verdict-harness.sh}` | 我自己的假 pane / 延长夹具 / 门禁判定表夹具 |
| `docs/team/reports/P52-dev2/pkg/out/**` | 全部原始日志（含干净全量门禁、包环境全量门禁、翻转与归因） |
| `pkg/{ceiling-probe.sh,70-cpu-quota-repro.sh,71-race-injection.sh}` + `pkg/out/70-*`、`71-*` | 追加部分：硬上限实测 / 2 核配额复现 / 读延迟注入（归属） |

## 下一步（给 PM）

1. 复验：`bash docs/team/reports/P52-dev2/pkg/run.sh`（约 25 分钟；60g 默认自己跑全量门禁走共享锁，
   也可用 `PKG_SMOKE_LOG` + `PKG_SMOKE_RC` 复用一份干净全量日志）。
2. 若要端到端重跑 P48 的注入全量门禁：
   `TEAM_SMOKE_FIXTURE=1 TEAM_P21_PREMISE_PROBE_MS=999 bash skills/teamsmith/tests/smoke.sh </dev/null`
   （期望：§38-b/§38-f 打 `SKIP（条件不满足）`、门禁 rc=0）。
3. F1 需要 PM 定夺（容器体检的信任前提）；F2/F4 建议排成把邻居夹具的固定采样/真实根改成条件轮询和
   夹具根的 M74 同族任务；F3 只是并发噪声（干净环境复跑绿）。
4. 追加部分（PM 12:24–13:14）：硬上限有实测边界（无需开单）；`✓108 ✗3` 的归属是设置视图读取新鲜度
   （M68/D11 的力读 + 夹具节奏 + 选择器快照），建议开一个夹具侧 change（开选择器前等新值/等读落定）。
5. 本任务结论：**PASS**。apply 是 dev3，本复验由 dev2 执行（满足“不复验自己工作”的硬规则）。
