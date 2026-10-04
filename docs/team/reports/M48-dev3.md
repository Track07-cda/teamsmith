# M48 · 看板重复 ID：光标卡死 + `board add` 不设防（用户实测）

agent: dev3   status: DONE   time: 2026-09-20T14:40Z
branch: `task/M48-id-board-add`（实现/测试/文档 9 个提交：`c9f1a00` … `eb70659`；报告与证据包：`395492a`；其后仅本报告的笔误级小修订）   PR/MR: -（local 模式：不 push；分支留在 `.worktrees/dev3`，PM 复验后本地合并）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/panel/src/types.ts` | 焦点身份从裸 ID 变成 `FocusRef {lane, id, nth}`（`nth` = 该 id 在 BOARD 顺序里的第几条，缺省 0 = 兼容旧值）；`Action.focus` 带 `nth`；`ViewState.focus` / `Frame.boardOrder` 用行引用 |
| `skills/teamsmith/scripts/panel/src/layout.ts` | `dupOrdinals`（每帧一趟 O(n) 建 `行对象→nth`）、`focusRow`（按 id+nth 精确定位行对象）、`focusRefOf`；看板/工作页的绘制与 `laneWindow` 的跟随都改成**行对象**匹配（`card === target`，O(1)）；`resolveFocus` 的回退链保持原样（精确行 → 该 id 第一行 → 同车道第一张 → 第一条非空车道） |
| `skills/teamsmith/scripts/panel/src/App.tsx` | 看板 `↑`/`↓` 改成位置行走（`inLane.indexOf(row)`，同 ID 两行是两步）；工作页 `boardOrder` 带 `nth`（不再 `indexOf(id)`）、Enter 按行打开；点击/`←`/`→` 都带 `nth` |
| `skills/teamsmith/scripts/panel/panel.js` | bun 重建（本树重新构建后与提交逐字节一致；性能证据见下） |
| `skills/teamsmith/scripts/lib/common.sh` | `team_board_duplicate_ids` / `team_board_duplicate_line`（只数**任务表**，占位行 `—` 与风险表不算）；`team_board_add`：已存在的 ID 拒绝（点名状态+标题+两条出路+指派入口，不落盘），`--allow-dup` 显式放行并往 `state/watchdog.log` 写审计；`team_board_write` 拆出参数化的 `team_board_write_col`；新增 `team_board_assign`（原地改 agent 列，未知 id / 缺参数不落盘） |
| `skills/teamsmith/scripts/lib/cmd-docs.sh` | `board add [--allow-dup]` 参数解析（裸 `-` 仍是 deps，「未知 `--` 旗标」照旧拒绝）；新增 `board assign <ID> <agent>`（用法错误走 `team_usage_die`，不再是 bash 参数展开报错）；`board ls` 打印重复行 |
| `skills/teamsmith/scripts/lib/cmd-status.sh` | `team digest` 打印重复行 |
| `skills/teamsmith/scripts/lib/cmd-project.sh` | `doctor` 新增「BOARD 重复 ID」检查（有重复 warn、没有 pass，**不** fail）；help 行含 `assign` 与 `--allow-dup` |
| `skills/teamsmith/tests/panel-b3.sh` | board 场景新增重复 ID 夹具与 16 条断言：↑/↓ 逐行走过两条同 ID 行（各只剩一个光标、高亮真的在两行之间移动、之后还能到 M48、↑↑ 走回第一条）、刷新（`r`）/详情（Enter）/返回（Escape）后焦点仍在**第二条**同 ID 行；工作页同样走一遍；`focused_row` 帮手（多个光标时输出 `AMBIGUOUS-CURSOR:n`，子串断言不能靠「两行都亮」蒙混） |
| `skills/teamsmith/tests/smoke.sh` | §4c（42 条）：拒绝（非 0 / 点名 / 两条出路 / 文件逐字节未变 / 不多行）、拒绝文案给出 `board assign`、未知旗标仍拒、`--allow-dup` 写入 + 审计、**`board assign` 原地指派（行数不变、两行 agent 列同改、其余列逐字节未变）**、未知 id / 缺参数的 assign 不落盘、`board set` 的 ID 寻址语义、board ls/digest/doctor 三处可见、两条负对照（无重复不刷行；空模板的占位行与风险表不算重复），段末还原 BOARD.md |
| `skills/teamsmith/tests/flip-m48.sh` | 三个翻转包：`focus`（临时 src 副本把焦点匹配/行走改回裸 ID 比较 → 重建 bundle → panel-b3 board 红 10 条）、`add`（skill 临时副本去掉 `team_board_add` 的重复检查 → §4c 红 17 条）、`assign`（临时副本把 `team_board_assign` 换成「再 add 一行」→ §4c 红 8 条）；真源码一个字节不落盘改动 |
| `skills/teamsmith/references/troubleshooting.md` | §23「同一 ID 两行 / 光标卡死」：症状、成因、现在的行为（含 `board assign`）、两条处置路线 |
| `skills/teamsmith/references/protocol.md` | §8d 增一条：行身份是 `(id, nth)`；`board add` 拒绝新重复；`board set` / `board assign` 按 **ID** 寻址、写**所有**同 ID 行（修正了旧文里「只写第一条」的错误说法） |
| `skills/teamsmith/SKILL.md` / `templates/BOARD.md.tmpl` | `board assign` 进命令表与看板头部提示 |

## Verification evidence (must have actually been run)

### 门禁（全量 smoke + openspec，最终提交 `eb70659`）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
✓ spec/watchdog
Totals: 15 passed, 0 failed (15 items)
…
== 4c · 看板重复 ID（M48）：add 拒绝 / --allow-dup / 三处可见 ==
  ✓ M48：重复 ID 被拒（非 0）
  ✓ M48：拒绝时给出「指派 agent」的正确入口（不许逼人用 add 撞）
  ✓ M48：被拒时 BOARD 逐字节未变
  ✓ M48：审计落在 state/watchdog.log
  ✓ M48：board assign 给已有行指派成功
  ✓ M48：assign 后行数不变（不是又加一行）
  ✓ M48：assign 只改 agent 列（两行其余列逐字节未变）
  ✓ M48：board set 也是 ID 寻址（同 ID 的两行状态一起变）
  ✓ M48：未知 id 的 assign 不落盘
  ✓ M48：board ls / digest / doctor 三处都报重复
  ✓ M48（负对照）：没有重复时 board ls 不刷重复行
  ✓ M48：段落结束把 BOARD.md 还原
  （§4c 共 42 条断言全绿）
…
== 结果 ==  ✓ 2404  ✗ 0
smoke 全绿
```

完整日志：`pkg/gate-full.out`。

### 快模式自检

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 1915  ✗ 0
smoke 全绿
```

完整日志：`pkg/gate-fast.out`。

### 真面板实录（私有 tmux server、真 keystroke、120×32）

夹具三行：`M39/重复的第一条(dev1)`、`M39/重复的第二条(dev2)`、`M48/第三条(dev3)`（两行同 ID 用不同 agent 在窄车道里区分）。

```
$ TEAM_B3_KEEP=1 bash skills/teamsmith/tests/panel-b3.sh board
  ✓ M48 重复 ID：初始焦点在第一行 M39
  ✓ M48 重复 ID：焦点光标恰好一个（不是两行都亮）
  ✓ M48 重复 ID：高亮落在第一条（按行身份，不是裸 ID）
  ✓ M48 重复 ID：↓ 后仍只有一个光标
  ✓ M48 重复 ID：↓ 走到同 ID 的第二行（不卡死）
  ✓ M48 重复 ID：刷新（r）后焦点仍在第二条同 ID 行
  ✓ M48 重复 ID：Enter 打开的是焦点那一行的详情
  ✓ M48 重复 ID：详情返回后焦点仍在第二条同 ID 行
  ✓ M48 重复 ID：再 ↓ 走到 M48（同 ID 两行之后继续前进）
  ✓ M48 重复 ID：↑↑ 回到第一行 M39
  ✓ M48 重复 ID：↑ 逐行经过第二条，回到第一条
  ✓ M48 重复 ID（工作页）：初始焦点在第一绘制行 M39
  ✓ M48 重复 ID（工作页）：焦点光标恰好一个
  ✓ M48 重复 ID（工作页）：高亮落在第一条
  ✓ M48 重复 ID（工作页）：↓ 走到第二条同 ID 行
  ✓ M48 重复 ID（工作页）：再 ↓ 走到 M48

== 结果 ==  ✓ 33  ✗ 0
panel-b3 全绿
```

帧（每帧只截当前光标行；`pkg/panel-b3-frames.out` 是完整片段）：

```
# dup-1
  4| │ › · M39 dev1 a… │ …
# dup-2（↓ 一次：走到同 ID 的第二行）
  5| │ › · M39 dev2 a… │ …
# dup-refresh（r 刷新后仍在第二行）
  5| │ › · M39 dev2 a… │ …
# dup-detail（Enter：打开的是这一行）
  3| ╭─ 详情 M39 ─────…╮
# dup-back（Escape 返回后仍在第二行）
  5| │ › · M39 dev2 a… │ …
# dup-3（继续 ↓：走过两行同 ID 之后到 M48）
  6| │ › · M48 dev3 a… │ …
# dup-4（↑↑ 回第一条 M39）
  4| │ › · M39 dev1 a… │ …
# dup-work-1 / dup-work-2 / dup-work-3（工作页同样逐行走）
  5| │ › · M39       dev1    待办    重复的第一条 …
  6| │ › · M39       dev2    待办    重复的第二条 …
  7| │ › · M48       dev3    待办    第三条 …
```

回归（同一改动碰了绘制与窗口跟随）：

```
$ bash skills/teamsmith/tests/panel-b3.sh workdetail     # ✓ 28  ✗ 0
$ bash skills/teamsmith/tests/panel-snapshots.sh         # ✓ 52  ✗ 0
```

### CLI 实录：指派不再靠「再加一行」

`pkg/assign-demo.out`（临时仓库、本分支的 skill、真实命令与输出）：

```
$ team board add T1.1 "重复的一条" dev -          # 已有行的 ID：拒绝（不落盘）
✗ BOARD 里已经有 T1.1（状态 todo · 「Smoke task」）：没有改动
✗   同 ID 多行会让面板焦点/状态/报告指错行。改 ID 里程碑编号，或确实要两条时显式允许：
✗   team board add T1.1 <标题> --allow-dup   （会往 state/watchdog.log 落一条审计）
✗   只是要给已有行指派 agent → team board assign T1.1 <agent>（只改那一行，行数不变）

$ team board assign T1.1 reviewer
✓ board assign T1.1 → reviewer
# 行数 6 → 6（不变），其余列逐字节未变；agent 列 dev → reviewer
# （`board set` 同语义：按 ID 寻址，同 ID 的多行一起改 —— 这条语义本次没有改动，smoke §4c 钉住）

$ team board assign NOSUCH dev          # 未知 ID：拒绝且不落盘
✗ BOARD 里没有 NOSUCH：没有改动
md5 unchanged = yes

$ team board assign T1.1                # 缺 agent：拒绝且不落盘
✗ board: usage: board assign <ID> <agent>
md5 unchanged = yes
```

### 真实看板上的可见性（只读）

```
$ team board ls / team digest / team doctor
!   BOARD 有重复 ID：V1.1 ×2、M4.3 ×2、M6.3 ×2（board set / assign 按 ID 寻址，同 ID 的多行一起改；board add 会拒绝新重复）
  BOARD 重复 ID          ! V1.1 ×2、M4.3 ×2、M6.3 ×2 （同 ID 多行：焦点按行身份走，但状态/报告按 ID 指行；team board ls）
```

`pkg/real-board.out`。M4.3 / M6.3 / V1.1 的历史数据**一个字节没动**（brief 的边界）。

### 性能（板页是这次改动的路径）

契约：面板进程 <1% 单核、首帧 <2s。同一夹具（`panel-cpu.sh`，真 pane，`TEAM_PANEL_CPU_PAGE=4`）跑
M48 bundle 与 **M48 之前的 bundle**（base 树 `panel.js`，sha `119af6f9…`）作为控制组：

| 轮 | bundle | 首帧 | 面板进程 | 读进程树 | 判定 |
|---|---|---|---|---|---|
| 30s（load ≈ 16） | M48 | 2351ms | 1.331% | 44.0% | RED（首帧） |
| 30s（load ≈ 16） | 控制组 | 2147ms | 0.300% | 29.9% | RED（首帧） |
| 60s | M48 | 2198ms | 0.732% | 34.9% | RED（首帧） |
| 60s | 控制组 | 1576ms | 0.416% | 26.6% | OK |
| 60s（load 回落到 3.2） | M48 | 1571ms | 0.516% | 27.6% | OK |
| 60s | 控制组 | 1204ms | 0.516% | 21.7% | OK |

- 稳态两项两棵树同带（0.416–0.732% vs 0.516%，都 <1%）；**首帧的红在控制组同样出现**，负载回落后两棵树都进预算
  ⇒ 红线由机器负载主导，不是 M48 引入的（与 M49 独立复验时记录的现象一致）。
- 每帧成本的定向微基准（`layout()`，400 行、6×400 帧、焦点逐行走，两棵树同会话交替）：
  M48 `min 0.436 / median 0.467–0.490 ms`，base `min 0.357 / median 0.372–0.389 ms`。
  新增工作是**一趟 O(行数)** 的重复序号表（真实看板 125 行 ≈ +0.03ms/帧），没有「每张卡/每条车道重扫全表」
  的路径；绘制与窗口跟随都是行对象同一性比较（O(1)）。

完整输出：`pkg/panel-cpu.out`、`pkg/panel-bench.out`（微基准源码 `pkg/panel-bench.ts`）。

## Flip evidence (required for defect-fix tasks)

三个翻转都是「破坏实现 → 守卫测试必须红 → 恢复后绿」，破坏只发生在**临时副本**里，真源码一个字节没动：

1. **焦点（控制台）**：`App.tsx` 的 `↑`/`↓` 改回 `inLane.findIndex(id)` + 同 ID 提前返回、`layout.ts` 的
   `card === target` 改回 `card.id === target.id`（即「改回按 ID 比较」）→ 重建 bundle → `panel-b3.sh board`：
   **✗ 10 条**（含「焦点光标恰好一个」、`AMBIGUOUS-CURSOR` 使「↓ 走到同 ID 的第二行」变红、「再 ↓ 走到 M48」
   实际 `M39,M39`）；提交的 bundle 同一夹具 **✗ 0 条**。
2. **`board add` 守卫**：skill 临时副本把 `team_board_add` 的重复检查换成 `if false` → smoke §4c 探针
   **✗ 21 条**，首条就是 `✗ M48：重复 ID 的 board add 应当被拒`；真树同一探针 **✗ 0 条**。
3. **`board assign`（原地指派）**：skill 临时副本把 `team_board_assign` 的写口换成
   `team_board_add … --allow-dup`（即「指派 = 再写一行」，重复 ID 进来的老路）→ smoke §4c **✗ 8 条**
   （「assign 后行数不变」「T1.1 仍是两行」「只改 agent 列」三条守卫变红）；真树同一探针 **✗ 0 条**。

三个翻转的输出：`pkg/flip-focus.out`、`pkg/flip-add.out`、`pkg/flip-assign.out`。

## Decisions and deviations

- **焦点身份用 `(lane, id, nth)` 而不是全行索引**：`nth` 是「同 ID 行在 BOARD 顺序里的第几条」，在看板
  （按车道过滤）、工作页（折叠 done 后重排）两个绘制空间里都稳定——用「绘制顺索引」会在换页/折叠/刷新时漂。
  回退链保持原样，所以 P20/B5 的「按 id 跟踪、离开看板落到车道第一条」行为不变（`panel-b3 workdetail` 28/28）。
- **`nth` 可缺省**：旧焦点值、手写夹具不带 `nth` 时按第 0 条解析，不会因为升级而报错。
- **`board assign` 与 `board set` 同寻址语义**：都按 **ID** 找，同 ID 的多行一起写。写测试时发现旧文档里
  「`board set` 只改第一条」是**错的**（实测：两行都会变，merge-base 的 CLI 同样如此）——已改正 protocol §8d /
  troubleshooting §23 的说法，并让 smoke §4c 钉住这条真实语义。改「按行寻址」是产品决定，不在本任务范围内
  （见下）。
- **`--allow-dup` 审计落 `state/watchdog.log`**：与 dispatch `--force`、身份放行同一本账，面板「最近」栏也能看到。
- **不改 BOARD.md 历史数据**：M4.3/M6.3/V1.1 的共用 ID 原样保留，只是现在肉眼之外还能被三处工具看见。
- **`panel.js` 重建**：本树 `bun build` 后与提交逐字节一致（否则 smoke 26-a 会红）。

## Suggested next steps

- **规格跟进（PM 决定）**：`openspec/specs/panel/spec.md` 现在写的是「SHALL be tracked by entry id … the lane's
  first card SHALL take the focus」。M48 之后准确的说法是「焦点是行身份 `(lane, id, nth)`：同 ID 的多行是多个
  停靠点，只有当前行带光标；行消失时回退到该 id 的第一行、再回退到车道第一张」。`board add` 的拒绝 /
  `--allow-dup` / `board assign` 也应各有一条 spec（`specs/board-and-status` 目前只写 `board set` 的枚举）。
  本任务 `change: -`、没有提案复验，按流水线没有由 dev 改规格。
- **`board set` / `board assign` 是否改成按行寻址（`(id, nth)`）**：现在同 ID 多行一起改；历史共用 ID 的
  两个任务共享一个状态（也是事实上的现状）。要按行区分就得给 CLI 一个行选择器，这是一次单独的产品决定。
- 面板 `focused_row` 帮手与三个翻转脚本都是可复用的：以后凡是「按 ID 指行」的地方（详情、报告、复验记录）
  再出重复 ID 问题，可以从这三个夹具起手。
