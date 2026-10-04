# M48 · 看板重复 ID：光标卡死 + `board add` 不设防（用户实测）

```
task:   M48
agent:  dev3
issue:  
change: -            # 若 design 认为要动 panel 规格（只读/聚焦语义），在报告里点名
specs:  -
phase:  -
deps:   -            # 与 M47（CI 可移植性）不重叠：那个改 .github 与可移植性
status: todo
budget: 一个工作块
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev3`。

## 现象（用户实测，2026-09-20 06:0x）

看板页里出现**两个 M39**；光标选中 M39 时**两行左侧都亮**，而且**光标无法继续向下移动**。
PM 已确认数据面：`docs/team/BOARD.md` 里确实曾有两条 `| M39 | …`（PM 先用 `team task M39 --title …`
建了行、随后又 `board add M39 …` 加了一遍；PM 已删掉重复行并提交）。
但**产品面三个缺陷仍在**（这才是本任务）：

1. **聚焦是按 ID 的**：`layout.ts` 里 `focusId = view.focus.id if … order.includes(id)`，
   行的 `focused = r.id === focusId` —— 同 ID 的多行**同时**被判为聚焦；
   `App.tsx:resolveFocus(rows, focusRef.current)` 也按 ID 找「当前行」，重复 ID 时永远解析到第一条
   → `moveFocus` 走不动（用户看到的「卡住」）。
2. **`team board add` 不检查 ID 已存在**：重复行能直接写进去（PM 就是这么造出来的）。
3. **没有任何地方报告重复 ID**：digest / doctor / `board ls` 都不说，重复只能靠肉眼。

## Deliverables

1. **聚焦改成「行身份」而不是裸 ID**：光标按**绘制顺索引**移动（↑/↓ 逐行、不跳行、不卡死），
   高亮**只落在当前那一行**；同一 ID 出现多次时，两行都要能各自被选中。
   跨帧保持（刷新/换页/详情返回）继续可用：把焦点存成 `(state, id, index)` 这类可判别形式，
   找不到时按既有规则回退（例如落到第一条绘制行），**不许**因为重复而卡死。
2. **`team board add <id>` 拒绝重复 ID**：点名已存在的那一行的状态与标题，给出两条出路
   （改 ID 里程碑编号 / 确实要两条就显式加旗标如 `--allow-dup` 并写进审计）。
   与既有 `board set` 的「未知 id 不写」风格一致：**拒绝时必须不落盘**。
3. **重复可见**：`team board ls` / `team digest` / `team doctor` 至少一处报告
   「BOARD 有重复 ID：M4.3 ×2、M6.3 ×2、V1.1 ×2」（这三个是**历史遗留**：不同任务共用 ID，
   按现状保留数据，只要求**能被看见**，不要求 PM 改名）。
4. **测试**（每条都能红）：
   - 夹具 BOARD 里放两行同 ID → 面板里 ↑/↓ 能逐行走过两行、各自高亮、不卡死（翻转：改回 ID 比较 → 红）；
   - `board add` 重复 ID → 拒绝、退出码非 0、**文件未变**（翻转：去掉检查 → 红）；
   - `board ls`/digest 对重复 ID 有可见输出（翻转：去掉提示 → 红）。
5. **文档**：troubleshooting 增一条「看板/焦点相关：重复 ID 的症状与处置」。

## Boundaries

- **不改 BOARD.md 的历史数据**（M4.3/M6.3/V1.1 的共用 ID 保留；PM 已自行删掉 M39 那条）。
- 不动 M47 的 CI 可移植性工作；`panel.js` 改了要**重建**并提交。
- 面板性能契约不变（<1% 单核、首帧 <2s）；聚焦改动不得引入每帧全表扫描。
- 测试纪律照旧（私有 tmux socket、破坏性调用进容器）。

## Acceptance (must actually be run)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 手工实录：在真实面板里对「同 ID 两行」按 ↑/↓（贴文字帧或 tmux cursor 位置证据）
```

## Report

`docs/team/reports/M48-dev3.md`。

---

## PM 追加（用户追问「为什么一开始就允许重复」后的定性）

根因不是「没人想到」，而是**两条写入路径不对称**：

- `team task <ID> --title …`（cmd-docs.sh:31）**有**守卫：`if [ -z "$(team_board_row "$id")" ]; then … add` —— 已有行就不加；
- **`team board add <ID> …` 完全没有唯一性检查**（`team_board_add` 无条件追加），而它正是
  **分派评审/指派 agent** 那条被文档提倡的用法 —— 于是「给已有行指派 agent」只能靠再加一行，
  重复 ID 就是这么进来的（PM 这次就是这么造的）。

所以修法里要**同时**满足这两件事（缺一不可）：

1. `board add` 对已存在的 ID **拒绝**（不落盘、点名已存在行、给 `--allow-dup` 审计逃生门）；
2. **指派 agent 要有正确的入口**，不能逼人用 `board add` 去撞：提供 `team board assign <ID> <agent>`
   （或 `board set <ID> --agent …`），写进帮助与文档；M48 的测试里要有一条
   「给已有行指派 agent → 只改那一行的 agent 列，行数不变」。

## 中断与续跑说明（PM 追加，2026-09-20 12:0x）

**你在 09:55 的 tmux 会话重建里被中断**，且旧会话已超模型窗口（无法复用）——本次用**新会话**续跑。
工作全部在磁盘上，先做三件事再动手：

1. `git log --oneline main..HEAD` 看**你自己**的提交（当前 3 个：重复序号的单帧构建、文档与翻转、pty 守卫测试）；
2. `git status --porcelain` 看未提交改动（当前：`M skills/teamsmith/tests/panel-b3.sh` + 未跟踪的报告 `docs/team/reports/M48-dev3.md`、`docs/team/reports/M48-dev3/`）；
3. `git diff` 读它们，然后**接着做完**，不要重做已完成批次。

注意（新守卫）：M48 的 brief 早于 D31（`change: -` 且无锚点），PM 已用 `--force` + 审计行放行；
锚点会在后续的回填 change 里补，**你不必**改本文件的头字段。
