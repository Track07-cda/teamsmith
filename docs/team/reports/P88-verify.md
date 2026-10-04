# P88 · 独立验证：P75（尾部现场裁剪）· P79（digest 段号）— 交付报告

agent: verify   status: delivered（**P79 PASS**；**P75 任务书范围 PASS，但带 finding F1**——它要求 PM 处置，见 §5）
time: 2026-09-22T23:12:00Z
branch: `task/P88-infra-p75-p79`（local 模式：分支留在 `.worktrees/verify`，不 push）   PR/MR: -
change: -（无 change：两件 infra 修正确认）
brief: `docs/team/tasks/P88-infra-fixes-verify.md`
verified revision: 实现树 = main `abfc060e`（`git -C .worktrees/verify diff main -- skills/` 为空）。P75 的修改在 main 里由 `1638433f` 落地（同一内容在任务分支上是 `c8cc375f`；`c8cc375f^` = `2bd1e982` 是 main 历史里的 P75 任务书提交，我用它做 pre-P75 回放）；P79 的修改是 `3637e17c`（在 main 历史里）。apply 作者分别是 dev3 / dev，都不是我。

## 0. 一句话

按任务书自造夹具复核了 P75 的四条边界与「第一/第二层来源未变」、P79 的段号唯一性与 `[7]→[6]` 红侧，并跑了 openspec + FAST + 全量 smoke；**任务书点名的每一项都成立**。对抗过程中另外发现 **F1**：P75 新引入的读取器在 `TEAM_AGENT_SCENE_LINES=0` 时会把整个 `team status` 用 SIGPIPE 中止（rc=141）并吞掉「来源在但没有画面内容」——这是 P75 引入的行为回归，窄但真实（默认 40 不受影响），详见 §5。

## 1. 我自己的证据 vs 引用

| 类别 | 内容 |
|---|---|
| **我自己的证据（本报告数字的来源）** | `docs/team/reports/P88-verify/pkg/`：5 个段落、**96 条断言**、每段自建夹具（真 CLI + 私有 tmux server；不使用 apply 作者的夹具与断言）。`logs/` 里是原始输出（status/digest 文本、expected 文件、diff、gate 日志）。另外：git 历史溯源（`[5]×2` 的出处）、`git diff` 的改动面检查、pre-P75 代码回放（`c8cc375f^`）。 |
| **引用（我重跑过，但断言/夹具不是我写的）** | dev3 的 smoke §43（P75 守卫）、dev 的 smoke §41 P79 断言行、`P75.md`/`P79.md` 与 `P79-dev.md` 里的数字。全量 smoke 会执行它们（§6）。 |
| **没有原样采信** | apply 报告里的任何结论都没有直接写进本报告；§3/§4 的每条都以我自己的夹具或 git 命令重做了一遍。 |

## 2. 任务书逐项

| # | 任务书要求 | 结果 | 证据（我的） |
|---|---|---|---|
| 1① | 内容 + 尾部多个空行，`SCENE_LINES=3` → 必须有 3 行内容 | ✓ | §3.1 `10-c1`（逐字节 = C1-2/3/4） |
| 1② | 只有空行 → 明确「没有可读内容」（不是静默空块） | ✓ | §3.1 `10-c2`（措辞 + 0 行画面；且不落进另一个空形状的措辞） |
| 1③ | 行数不足 N → 给现有全部 | ✓ | §3.1 `10-c3`（2 < 3 → 两行逐字节） |
| 1④ | 中间空行必须保留 | ✓ | §3.1 `10-c4a/4b/4c`（含纯空白行）；改实现 → 判据翻红见 §3.3 |
| 1⑤ | 第一/第二层来源语义未变（自查代码 + 一例） | ✓ | §3.2：cmd-agents.sh 与 pre-P75 一字未动；层1 真遗体、层2 真 pane-dead 文件各一例；层1 还做了 pre-P75 与 HEAD 的逐字节对照 |
| 2 | `team digest \| grep '^\['` 段号逐行唯一（唯一豁免历史 `[5]×2`，自查它确实是历史） | ✓ | §4.1（`1 2 3 4 5 5 6 7`，重复只有 5）+ §4.2（`[5]` 的出处溯源到初始提交与 `40bbad6a`） |
| 2 | 把 `[7]` 改回 `[6]`（scratch）→ 该断言红 | ✓ | §4.3（变异副本 → 重复段号 `5 6`） |
| 2 | `[1]–[7]` 顺序与既有段语义未变 | ✓ | §4.4（pre-P79 代码回放：段头差异恰好一行；死 pane 段正文逐字节相同；源码里只有一对段头增删） |
| 3 | 零回归：openspec + FAST + 全量 smoke | ✓ | §6：openspec 30/0 · FAST 2619/0 · 全量 3285/0，三件都 exit 0 |
| 4 | 报告写清自有/引用；发现不一致点名交回 | ✓ | §1 + §5（F1 点名文件与命令） |

## 3. P75

### 3.1 四条边界（CLI 级，自建夹具；`logs/pkg-10.log`）

命令（可复跑）：

```sh
bash docs/team/reports/P88-verify/pkg/run.sh 10
```

① 4 行内容 + 5 行尾空行、`TEAM_AGENT_SCENE_LINES=3`（原始输出 `logs/10-c1.status`）：

```
  座位 p88w：无窗口
  现场（来源：…/dispatch-p88w-tail.txt（agent 退出时 harness 自抓的尾屏） · 记录时间：… · 最后 3 行（去尾空行））：
    | P88-C1-2
    | P88-C1-3
    | P88-C1-4
```

② 只有空行（`logs/10-c2.status`）：

```
  现场：（来源里没有可读内容——没有非空行）来源=…/dispatch-p88w-tail.txt（agent 退出时 harness 自抓的尾屏）
```

③/④/⑤：不足 N 给全部、中间空行（含纯空白行）逐字节保留、N=2/N=40 的窗口下界与真实规模（200 行内容 + 40 行尾空行 → 恰好最后 40 行）都逐字节比对通过。段落尾部另有 ⑥：N=0 的两种结果（文档措辞 / F1 中止）——见 §5。

### 3.2 第一/第二层来源未变（`logs/pkg-20.log`）

- **代码面**：`git diff c8cc375f^..HEAD -- skills/teamsmith/scripts/lib/cmd-agents.sh` 为空 → `team_agent_corpse_scene`（层1 读取器）从 P75 前到 HEAD 一字未动；层2 的读取表达式 `sed -n '/^--- scene ---/,$p' | tail -n +2 | tail -n "$n"` 在两边逐字节相同。
- **行为面**：私有 server 上真 SIGKILL 出遗体（`pane_dead=1`、`signal=9`、`remain-on-exit=on`）→ 层1 赢过同时存在的层2/层3 文件，画面 = capture 的最后 3 行（B/C/D 逐字节，`Pane is dead (…)` 被过滤）；无窗口 + pane-dead 文件 → 层2 赢过层3，字面取尾 N 行（中间空行保留）。**HEAD 与 pre-P75 对同一具夹具的现场块逐字节相同**。
- 观察（非缺陷，附证据）：层2 的尾随空行由命令替换 `$( )` 吞掉（P75 前就如此），所以层2 的「字面 tail」在*可见输出*上表现为最后一条非空行；与 pre-P75 逐字节对照一致。

### 3.3 翻转证据（P65 的 F1：红 → 绿，`logs/pkg-40.log`）

- **红侧（改前代码）**：同一具夹具（4 行内容 + 5 行尾空行、`SCENE_LINES=3`）换上 `c8cc375f^` 的 `cmd-status.sh`：

```
  现场：（来源在但没有画面内容）来源=…/dispatch-p88w-tail.txt（agent 退出时 harness 自抓的尾屏）
```

  ——一行画面都给不出（0 行），正是 P65 的 F1。
- **绿侧（HEAD）**：同一夹具打出 §3.1 ① 的三行内容（`logs/40-p75-green.log`）。
- **判据敏感性（改实现 → 断言必须红）**：把读取器换成 `grep -v '^$' | tail -n`（只删空行、不区分位置）的变异副本 → ④a 的判据翻红：现场变成 `P88-F4-2 / F4-4 / F4-5`，中间空行被吃掉（`logs/40-midblank-mutant.scene`）。

## 4. P79

### 4.1 段号唯一（`logs/pkg-30.log`、`logs/30-digest-now.log`）

真死 pane 夹具（私有 server）下 `team digest` 的段头：

```
[1] 容量与存活
[2] 待处理通知
[3] 待复验 …
[4] 待收尾 …
[5] 任务板
[5] 建议
[6] change 归组
[7] 死 pane 席位（窗口是遗体：现场可读；死 pane 不是投递目标，消息已换道收件箱）
```

段号表 `1 2 3 4 5 5 6 7`，重复集合 = `5`（唯一豁免）；`[7]` 段头恰好一行，正文是 P55 的原文；多一个死 pane 时段头仍只印一次、两条 `!` 行都在。

### 4.2 `[5]×2` 确实是历史（我自己溯源）

`git show <初始提交>:skills/pi-team/scripts/lib/cmd-status.sh` 里 `[4] 任务板` + `[5] 建议`；`git show 40bbad6a` 的 diff 是 `-[4] 任务板` / `+[5] 任务板`（2026-09-11，HEAD 的祖先）。即：建议段生来是 `[5]`，任务板后来被搬到 `[5]` → 重复发生在两个时代，与本次修正无关；按任务书不改无关段。

### 4.3 `[7]→[6]` 红侧（`logs/pkg-40.log`、`logs/40-p79-mutant.log`）

scratch 副本（只把 `printf` 行的 `[7] 死 pane` 改成 `[6]`）→ 段号表回到 `1 2 3 4 5 5 6 6`，重复 `5 6`，我的「逐行唯一」断言翻红；段正文与 HEAD 逐字节相同（被改的只有段号）。

### 4.4 顺序与语义未变（pre-P79 回放）

把 `3637e17c^` 的 `cmd-status.sh` 放进 scratch 技能副本，在**同一具**夹具上跑 digest：

- 段头清单的差异恰好一行：`[6] 死 pane …` → `[7] 死 pane …`；其余段头逐字节不变。
- 死 pane 段正文 pre/HEAD 逐字节相同。
- 源码 diff 里只有一对 `printf` 段头增删（`[6]→[7]`，且都带「死 pane 席位」），没有别的段头被顺手改。

## 5. Finding F1（P75 引入；窄但真实）

**症状**：`TEAM_AGENT_SCENE_LINES=0` 时，`team status <ID>` 会以 **rc=141（SIGPIPE）**中止，席位段的现场块（以及其后若有的一切）丢失。
**文件/位置**：`skills/teamsmith/scripts/lib/cmd-status.sh:1171-1177`（`team_status_tail_scene` 的 `awk … | tail -n "$n"`；P75 引入；CLI 跑在 `set -euo pipefail` 下）。
**机制（实测）**：`tail -n 0` 不读 stdin 就退出 → `awk` 收到 SIGPIPE；`PIPESTATUS` 实测为 `141 0`；`pipefail` 把 141 传出，`set -e` 中止整个脚本。P75 之前这一层是单条 `tail -n 0`（`logs/50-layer3-pre75.log`，rc=0 + 那句措辞），没有管道。

**确定性复现**（文件 560 KB > 64 KB 管道缓冲；整套可复跑：`bash docs/team/reports/P88-verify/pkg/run.sh 50`）：

```sh
$ awk '{print}' big.txt | tail -n 0; echo "PIPESTATUS=${PIPESTATUS[*]}"
PIPESTATUS=141 0

$ TEAM_AGENT_SCENE_LINES=0 bash skills/teamsmith/scripts/team status T9.88   # tail 文件 560 KB
rc=141，输出没有「来源在但没有画面内容」（logs/50-layer3-head.log）
# 同一夹具换成 pre-P75 的 cmd-status.sh：rc=0 且打出那句措辞（logs/50-layer3-pre75.log）
```

真实规模（harness 的 tail 文件 ≤ ~250 行）下同一中止是概率性的：300 行文件、40 次里 1–5 次 rc≠0（`logs/pkg-50.log` 的 note 行，多次运行记录在 `logs/probe-run-*.log`）。因此现有门禁（smoke 用 2/3/40）抓不到它。

**边界**：层1（`team_agent_corpse_scene`）与层2 有同形状的 `… | tail -n "$n"`，但**它们在 P75 之前就有**（pre-P75 与本 tip 都是 141，见 §3.2/`logs/pkg-50.log` 的 D 组），不属于 P75 的改动面；F1 是「P75 把这口子扩到了层3」。
**建议**：让 `awk` 自己取最后 N 行（去掉管道，如 `awk -v n="$n" '…'`），一次修掉三层的同形状；或至少给这条管道兜底。是否现在就修、还是记成已知限制，请 PM 决定（按纪律：带 finding 的 PASS 不等于可以归档）。

## 6. 零回归门禁

```sh
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 30 passed, 0 failed (30 items)          # exit 0（logs/gate-openspec.log）
```

**第一次 FAST（`logs/gate-fast-m28-red.log`）：✗1，而且那一条正是我自己的证据包。** M28 的 tmux 隔离 lint（`tests/tmux-lint.pl`）扫到 `pkg/lib.sh` 的清理行 `/usr/bin/tmux -L $P88_TMUX_SOCK kill-server`——字面绝对路径在命令位一律红（M41：闸门看不到它），即使带私有 `-L`。这正是这条门禁该有的形状：它把我新加的包拦下了。修法：用 `$P88_TMUX_BIN` 变量（lint 的 REAL_TMUX 解析类例外）。修后直接跑 lint：红 0 条（36 条历史豁免是 M28 之前的旧证据包）；证据包仍 96/96 绿。

```sh
$ perl skills/teamsmith/tests/tmux-lint.pl
tmux-lint：红 0 条；另有 36 条落在**历史豁免**的 16 个文件里……
$ bash docs/team/reports/P88-verify/pkg/run.sh
== run 结果 == ✓96 ✗0 · findings=1 · skip=0      # exit 0
```

**第二次 FAST（修后，`logs/gate-fast.log`）：全绿。**

```sh
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2619  ✗ 0
smoke 全绿
FAST_EXIT=0
```

（断言数 2618 → 2619 的那一条正是 M28 真树检查：从红转绿。）

**全量 smoke（修后，`logs/gate-full.log`）：全绿**（在机器锁下排到 23:45 才轮到，跑完 `smoke 全绿`）。

```sh
$ TEAM_SMOKE_LOCK_WAIT=10800 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 3285  ✗ 0
smoke 全绿
FULL_EXIT=0
```

全量里包含任务书点名的两处守卫：**§43** 的 P75 断言（`P75 ①–⑤`，含影子红侧）与 **§41** 的 P79 三条（`[7]` 段头 + 段号逐行唯一 + 按序 `[1]–[7]`），以及 M28 真树 lint。

> 第一次提交的全量表赶上了机器锁队列（机器上另有 4 套全量表在排队）：我的排队实例（1800s 上限）还在等锁时就被我主动结束，换成 10800s 上限重跑（它前面还有 3–4 套，1800s 基本注定超时）。队列记录 `logs/gate-full-superseded-queue.log`，最终运行 `logs/gate-full.log`，两次都保留。

## 7. 限制与未覆盖

- 我没有改任何实现（`verify` 席位纪律），也没跑 P87/P86 等别人的门禁面；本报告的判定只覆盖任务书点名的两个函数与 digest 输出面。
- 全量 smoke 是别人的门禁套件 + 我这一套的执行；它在临时仓库里跑，不碰本项目工作树。
- F1 的「真实规模命中率」是时序性的，我给了多次独立测量的计数（1/40、3/40、4/40、5/40），不做断言；确定性判据用 560 KB 夹具。

## 8. 过程记录

- 证据包最初被我按绝对路径误建在**主工作树**的 `docs/team/reports/P88-verify/`（未跟踪、未提交）；发现后**整体移入**本任务工作树（`.worktrees/verify/…`），主工作树除了 PM 自己未提交的 `docs/team/BOARD.md` 外无我留下的内容。此后所有命令都在 `.worktrees/verify` 内跑。
- 全量 smoke 提交时机器上已有 4 套全量表在排队（机器锁 `TEAM_SMOKE_LOCK` 串行化）；FAST 在 FAST 模式下不参与该锁（慢是机器负载，不是排队）。我自己的第一次排队实例（1800s 上限）还在排队时就主动结束并换成 10800s 上限重跑（它前面还有 3–4 套全量表，1800s 基本注定超时）；两次记录都留在 `logs/`（`gate-full-superseded-queue.log` / `gate-full.log`）。
- 第一次 FAST 的 ✗1 是门禁抓到了**我自己的**证据包（M28，见 §6）；修掉后重跑。这属于「门禁有效」的正面证据，不是产品缺陷。
