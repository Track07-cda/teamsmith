# M39 · 6k④ 夹具竞态：断言前等窗口成型 + 失败自带现场

agent: verify   status: done   time: 2026-09-19T12:40Z
branch: `task/M39-6k④`   PR/MR: -（local 模式，分支留在 `.worktrees/verify`）
code commit: `1131891`（只动 skills/teamsmith/tests/smoke.sh）

**一句话**：6k④ 的假红不是「窗口没建起来」，而是**建窗后 pane_pid 还是没 exec 完的壳**时判据被调用了一
次 —— 判据 `team_proc_is_agent_bin` 在**一次判定里读了两次命令行**（先查 `dispatch-*.spawn` 排除，再逐词
比对 agent 可执行文件）；`exec` 正好落在两次读之间时，第一次读到「壳」（排除不生效）、第二次读到已经
exec 完的 bash（命令行里 agent 路径已可见）→ 判成 alive。已按简报只动 6k 段夹具：断言前**有界等窗口成型**
（条件具体：pane_pid 可读 **且** 完整命令行里出现本段的夹具标记）+ 断红时**自带现场**。同一套 25 次探针：
修前 M34/main 两棵树 23/175 次假红（≈13%），修后 0/75 次。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/smoke.sh` | 6k 段：新增 `m37_pane_args` / `m37_wait_shape` / `m37_diag` / `m37_assert_verdict`；④③ 建窗后先等成型再断言；①②③④⑤ 断红时打印现场 |
| `docs/team/reports/M39-verify/pkg/repro-6k-race.sh` + `repro-6k-race.patch` | 独立复现包：把 ④ 从一次断言放大成 N 次探针（并记录判据两次读到的现场），PM 可在任意修前 checkout 上复现这个假红 |

只改了 `skills/teamsmith/tests/smoke.sh`；判据（`common.sh` 的 `team_agent_alive_in_pane` /
`team_proc_is_agent_bin`）**一个字没动**（简报边界）。

## 现场与机制（为什么 main/M37 绿、M34 红）

### 1. 建窗后有一小段「还没 exec 完」的现场

`tmux new-window` 返回时，pane 的进程已经 fork 出来但可能还没 `execve` 完；这期间
`/proc/<pid>/cmdline` = **tmux server 自己的 argv**。实测（本轮私有 server）：

```
R1 pid=2746034 bytes=76  has_marker=NO  args=[tmux new-session -d -s teamsmith-smoke-anchor-2507556 -n anchor sleep 100000]
```

### 2. 判据在一次判定里读两次命令行 → exec 落在两次读之间就是假红

`team_proc_is_agent_bin`：读一次判 `dispatch-*.spawn` 排除，再让 `team_proc_cmdline_is_bin` 读第二次逐词比对
agent 可执行文件。同一个 pid、相隔 **4.4 ms** 的两次读（实锤，`hunt-main-3.log`）：

```
1789820987.075896 R1 pid=2746034 bytes=76  has_marker=NO  args=[tmux new-session -d -s teamsmith-smoke-anchor-2507556 -n anchor sleep 100000]
1789820987.080305 R2 pid=2746034 bytes=123 has_marker=yes args=[bash -c sleep 600 && true  # 派单 harness 形状：/tmp/…/fake-bin/m37-agent … dispatch-m37w.spawn]
```

→ 第一次读：排除标记没出现 ⇒ 排除放行；第二次读：命令行里 `…/m37-agent` 已可见 ⇒ 命中 ⇒ `alive`。
两次读都是「壳」或都是「完整命令行」时都判 stopped（同一次运行里两种对照组都有）——**只有跨 exec 的这一次
是假红**，所以它是概率性的（这也是 PM 看到「断言报 alive、同一条检查立刻重跑变 stopped」的原因：重跑时两次
读都看到完整命令行）。命中现场（`team_pane_proc_tree_pid` 里打的 trace，完整命令行已经就位）：

```
MATCH-PANE target=teamsmith-smoke-1666369:m37-start pane=1723387 ppid=1666391 \
  args=[bash -c sleep 600 && true  # 派单 harness 形状：/tmp/…/fake-bin/m37-agent … dispatch-m37w.spawn]
```

### 3. 概率实测（同一套 25 次探针，修前）

| 树 | 运行 | 探针 | 判成 alive（假红） |
|---|---|---|---|
| M34 `71ce86f` | hunt-b1 / hunt-c1 / hunt-d1 | 25×3 | 2 / 4 / 2 |
| main `b9f50b1` | hunt-main1 / hunt-main2 / hunt-main3 | 25×3 | 1 / 5 / 4 |
| main（`pkg/repro-6k-race.sh` 在全新 checkout 上） | pkgtest-1 | 25 | 5 |

合计 **23/175 ≈ 13%**（M34 8/75=10.7%、main 15/100=15%）。另外一次「只跑一次 ④ 断言」的整段跑
（`hunt-a1`，M34 树）正好命中：

```
[M39] ④ first verdict=alive
  ✗ 6k ④ 启动中的 harness（命令行里有 agent 路径但没有 agent 进程）判停（期望 [stopped]，实际 [alive]）
```

### 4. 结论：与 M34 的改动无关

`git diff main..task/M34-work` 只碰 panel（`panel.js`/`layout.ts`/`panel-snapshots.sh`/`flip-m34.sh`）；
6k 夹具与判据代码在两棵树上**逐字节相同**（`diff` 过 6k 段落）。**main 树上同样的假红率（15%）**，所以
「M34 红 / main 绿」是**单次断言撞上 13% 窗口**的运气差（复验时那台机器上还并跑着别的门禁，负载越高窗口
越宽）。换句话说：这不是「M34 的回归」，是 M37 引入 6k 段时就带着的夹具竞态，只是它在 M34 复验时才被撞上。

## 修法（只动 6k 段夹具）

1. **断言前有界等窗口成型**（`m37_wait_shape`，最多 5s，0.1s 一跳）：
   `m37_wait_shape <target> <标记>` = 目标窗口的 `pane_pid` 可读 **且** 它的完整命令行里出现本段的夹具标记。
   标记写在命令行**尾巴**上（④ = `dispatch-m37w.spawn`，③ = `# 6k③对照形状`），看见它就等于「已经 exec 完」
   → 之后判据的两次读都会看到完整命令行，排除稳定生效。等待用 `ps -o args= -ww`（不限宽）：这里问的是
   「exec 完了吗」，不该被 `ps` 的输出宽度截断干扰。等不到就**响亮报红**并打印现场命令行（不当创可贴）。
2. **断红自带现场**（`m37_diag`）：`pane_pid` / pane 完整命令行 / 直接子进程 / 同 server 的所有窗口 /
   `team_pane_agent_pid` 命中的 pid + 它的命令行 + cwd + `team_proc_is_agent_bin` 判定 / 判据用的 agent
   可执行文件。①②③④⑤ 都套了 `m37_assert_verdict`（断言 + 红时打印现场），一次红就能定位。
3. ①② 原本就有 `m37_wait_child`（等 agent 子进程）——同一条纪律，未改；③ 是负向断言，额外等成型是为了
   不让断言落在「还没 exec 完」的现场上（那种现场同样判停，会把 ③ 变成一次空跑）。

## Verification evidence (must have actually been run)

### (a) 验收 1：分支上的全量门禁（openspec + 全量 smoke）

```
$ PATH="$HOME/.bun/bin:$PATH" bash -c 'openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh' </dev/null
== 结果 ==  ✓ 2091  ✗ 0
smoke 全绿                            rc=0（用时 ~580s）
```

（`openspec validate --all --strict` 通过无输出；2091 = 修前 2089 + 新增的 2 条夹具现场断言。）

### (b) 验收 2：FAST 模式

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1648  ✗ 0
FAST 模式：跳过 21 个真进程段落（… 6k·worker 存活判据（M37）…）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿                            rc=0
```

### (c) 验收 3：在 `task/M34-work`（M34 树 + 本补丁）上连跑 3 次，6k 段 0 红

三次**并行**跑（同机并发 = 修前假红率最高的条件），每次跑到 6k 段结束就截断（后面的段落与本断言无关，
整套的等价证据见 (a)：同一份夹具代码 + 同一批后续段落）：

```
$ TEAM_SMOKE_NO_LOCK=1 bash skills/teamsmith/tests/smoke.sh      # ×3，/tmp/m39-m34-fixed
== 6k · worker 存活：看 pane 进程树，不看 pane_current_command（M37） ==
  ✓ 6k ① 夹具现场：pane_pid=2147309 cmd=bash（agent 子进程 2147425）
  ✓ 6k ① 字面形状（bash 父 + agent 子）判活
  ✓ 6k ② 夹具现场（事故形状）：pane_pid=2147995 cmd=bash（agent 子进程 2148101）
  ✓ 6k ② 事故形状（交互 bash + set +m）判活
  ✓ 6k ② 待办：有任务但在跑的 agent 不算「停了的 agent」
  ✓ 6k ④ 夹具现场：pane_pid=2149281 cmd=bash（命令行已成型，含 dispatch-m37w.spawn）
  ✓ 6k ④ 启动中的 harness（命令行里有 agent 路径但没有 agent 进程）判停
  ✓ 6k ⑤ 不存在的窗口（display-message 回退陷阱）判停
  ✓ 6k ③ 夹具现场：pane_pid=2149768 cmd=bash（bash 里没有 agent 子进程，命令行已成型）
  ✓ 6k ③ 对照（bash 里没有 agent 子进程）判停
  ✓ 6k ③ 对照：待办把它算成「停了的 agent 1」
```
（另两次 run 的 6k 段逐条相同，只有 pid 不同：2156058/2156344/2157033/2157378 与
2350347/2351543/2353325/2354012。）

### (c2) 同一棵 M34+补丁 树上的 **3 次整套全量**（带 25 次放大探针）

```
$ TEAM_SMOKE_NO_LOCK=1 M39_PROBE_N=25 bash skills/teamsmith/tests/smoke.sh   # ×3，/tmp/m39-m34-fixedprobe
run 1/2/3：探针 25 次，判成 alive 0 次；等成型 TIMEOUT 0 次
== 结果 ==  ✓ 2091  ✗ 0        （三次都是，整套跑完，不是截断版）
```

### (c3) 修后 **在最新 main**（`dee06c1`，含 M36 的 runtime tmux shim）上的复核

分支的基线是 `37b72a7`（M36 合并进 main 之前），所以另外在 `main + 本补丁`（cherry-pick `1131891`）上复核：

```
$ TEAM_SMOKE_NO_LOCK=1 M39_PROBE_N=25 bash skills/teamsmith/tests/smoke.sh   # /tmp/m39-main-fixprobe
run 1：探针 25 次，判成 alive 0 次；等成型 TIMEOUT 0 次；6k 段 11 条断言全 ✓
$ PATH="$HOME/.bun/bin:$PATH" bash -c 'openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh' </dev/null
   # /tmp/m39-main-fix —— 见下（结果行）
```

### (d) 修后的放大探针（同一套 25 次探针）

| 树 | 运行 | 探针 | 判成 alive | 等成型 TIMEOUT | 整套结果 |
|---|---|---|---|---|---|
| M34 + 本补丁 | fixprobe-1/2/3 | 25×3 | **0** | 0 | 三次都是 `✓ 2091 ✗ 0` |
| 最新 main `dee06c1` + 本补丁 | mainfix-probe-1 | 25 | **0** | 0 | 6k 段 0 红（截断变体） |

- Verdict: **pass**
- Notes: (1) 「判成 alive」的探针是**夹具侧**放大出来的（把 ④ 的「建窗→断言」循环 25 次），不是验收
  命令本身；验收命令是 (a)(b)(c)（(c2) 的 3 次是整套全量 + 探针）。(2) (c) 的 3 次跑的是「跑到 6k 段
  截断」的变体（每次省 ~4 分钟），(c2) 的 3 次是**整套全量**（同一棵树），两者的 6k 段都 0 红。
  (3) 三次 (c) 与三次 (c2) 都是**并行**跑的（同机并发 = 修前假红率最高的条件），不是安静环境下的顺跑。

## Flip evidence（red before → green after）

**red（修前，M34 树 `71ce86f`，整套跑到 6k）**：

```
$ bash skills/teamsmith/tests/smoke.sh          # 手上这份是加了探针的 scratch 树（复现包在 pkg/）
== 6k · worker 存活 … ==
[M39] ④ first verdict=alive
[M39DIAG] pane_pid=1137371
1137371 1066695 bash -c sleep 600 && true  # 派单 harness 形状：/tmp/…/fake-bin/m37-agent … dispatch-m37w.spawn
1137450 1137371 sleep 600
[M39DIAG] apid=none bin=/tmp/…/fake-bin/m37-agent          ← 重查时判据不再命中（exec 已完成）
  ✗ 6k ④ 启动中的 harness（命令行里有 agent 路径但没有 agent 进程）判停（期望 [stopped]，实际 [alive]）
```

**green（修后，同一棵树 + 本补丁，3 次并行 + 3 轮放大探针 75 次）**：

```
$ TEAM_SMOKE_NO_LOCK=1 bash skills/teamsmith/tests/smoke.sh     # /tmp/m39-m34-fixed
  ✓ 6k ④ 夹具现场：pane_pid=2149281 cmd=bash（命令行已成型，含 dispatch-m37w.spawn）
  ✓ 6k ④ 启动中的 harness（命令行里有 agent 路径但没有 agent 进程）判停
$ M39_PROBE_N=25 bash skills/teamsmith/tests/smoke.sh           # ×3（/tmp/m39-m34-fixedprobe）
run 1/2/3: 探针 25 次，判成 alive 0 次；等成型 TIMEOUT 0 次
```

**机制侧的翻转（判据读到的两次现场，`hunt-main-3.log`）**：

```
R1 pid=2746034 bytes=76  has_marker=NO  args=[tmux new-session -d -s teamsmith-smoke-anchor-2507556 -n anchor sleep 100000]
R2 pid=2746034 bytes=123 has_marker=yes args=[bash -c sleep 600 && true  # 派单 harness 形状：…/m37-agent … dispatch-m37w.spawn]
   ↑ 修前：exec 落在两次读之间 ⇒ 假 alive（探针 #8）
   修后：夹具先等到「命令行含 dispatch-m37w.spawn」才断言 ⇒ 两次读都看到完整命令行，排除稳定生效（0/75）
```

复现包（PM 独立复验用）：`docs/team/reports/M39-verify/pkg/repro-6k-race.sh`（在一个全新的 `main`
checkout 上实测复现：`合计：alive 5 / 探针 25`）。

## 发现（超出本任务边界，未改，请 PM 决定）

1. **判据的两次读不原子**（本次假红的直接成因）：`team_proc_is_agent_bin` 读一次判排除，再让
   `team_proc_cmdline_is_bin` 读第二次。建议把第一次读到的命令行**传进去**（一次读、两处用），这样两次读之
   间的 exec 就不会造成假 alive。改动很小，但在 `common.sh`（本简报边界外）。
2. **`ps` 宽度截断会让 `dispatch-*.spawn` 排除静默失效**（第二个、与本次无关的成因）：`ps -o args=` 在
   `COLUMNS` 被设置时会截断（本机 procps-ng 4.0.6 实测；tty 宽度不截断、管道输出不截断，只有 `COLUMNS`
   会）。④ 的夹具命令行长度 123 字节，其中 agent 路径在 53–99 字节、`dispatch-` 从第 104 字节起 ——
   `COLUMNS` ∈ [100,114] 时排除标记被砍掉、agent 路径还看得见 ⇒ 判成 alive。自包含复现：
   `bash docs/team/reports/M39-verify/pkg/shows-ps-truncation.sh`（一键给出 5 种宽度下读到多少字节、排除
   生效还是失效）；把它合进 6k④ 的夹具形状（`COLUMNS=105` 跑同一段夹具）时 ④ 红、不设 `COLUMNS` 时绿。这不是 PM 这次
   撞上的成因（PM 的 diag 里命令行是完整的），但生产上等同一次假 alive。建议判据里那两处 `ps -o args=`
   改成 `-ww`（或读 `/proc/<pid>/cmdline`）。

## Decisions and deviations

- 只动 `smoke.sh`（简报边界）；`common.sh` 的两个脆弱点以「发现」形式报告，没有顺手改。
- ③ 的夹具命令行尾巴加了一个成型标记注释（`# 6k③对照形状`）——形状语义不变（bash 里没有 agent 子进程），
  只是让「等成型」有个具体条件；④ 的命令行字符串与原来**逐字节相同**（只是把标记提成变量）。
- 新增 2 条夹具现场断言（③、④ 各一条 `ok`），所以 smoke 的总断言数 +2（这棵树 2089 → 2091）。
- 三次 M34 树验收（(c)）跑的是「6k 之后截断」的变体（省下的时间是每轮 ~4 分钟）；同一棵树上另有三次
  **整套全量**（(c2)，带 25 次放大探针，`✓ 2091 ✗ 0`）。
- 本分支的基线是 `37b72a7`（晚于 M37、早于 M36 合并进 main）；因为 main 已经前进到 `dee06c1`，另外在
  `main + 本补丁`（cherry-pick）上复核了 6k 段与整套门禁（(c3)），两棵树的 6k 段落逐字节相同。
- 修好后仍有 2 个已知非本任务问题：判据两次读不原子、`ps` 宽度截断（见「发现」）。两者都不影响本补丁的
  结论：夹具不再是概率性红的。

## 验收日志

三段验收命令的真实输出尾部都直接抄在上面 (a)(b)(c)/(c2) 里（不是概述，是原样粘贴的结果行）；
复现包用法见 (d) 下面的说明与 `pkg/repro-6k-race.sh` 头部注释。

## Suggested next steps

- 若 PM 认同「发现 1」，建议另开一个小任务：`team_proc_is_agent_bin` 一次读、两处用（并让
  `team_proc_cmdline_is_bin` 支持传入已读到的命令行）——它能把 M37 判据的最后一点竞态关掉。
- 若 PM 认同「发现 2」，建议在同一个小任务里把判据的两处 `ps -o args=` 改成 `-ww`。
- 本任务的 6k 段现在也覆盖 ③ 的成型（负向断言不再可能空跑）。
