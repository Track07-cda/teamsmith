# M59 · pty 夹具的等待与清理：把"假红级联"变成机制（infra）

```
task:   M59
agent:  dev3
issue:
change: -
specs:  -
anchor: none (infra) — 测试夹具自身的等待/清理健壮性；不改产品契约，不改门禁语义（不新增 requirement）
phase:  -
deltas: -
grant:  skills/teamsmith/tests/panel-p21.sh · skills/teamsmith/tests/panel-choices.sh · skills/teamsmith/tests/panel-flip-m54.sh · skills/teamsmith/tests/lib/**（若无则新建 pty 助手）· skills/teamsmith/tests/smoke.sh（仅 §38 的调用声明）
deps:   M55（已合并；事故现场 = 第一次复验的 §38-b 62 条红）
status: todo
budget: 一个工作块；做不完交 PARTIAL
```

> 本地模式：不 push。分支留在 `.worktrees/dev3`。

## 事故（已定性，附证据）

- **现场**：PM 第一次复验（tip `78dcbcb`）§38-b 结果行 `✓ 33 ✗ 62`；夹具最后一次改动是 `625b4bd`（更早）；
  `78dcbcb` 之后**没有任何测试改动**。同一份夹具在 `1c5f9c4` 上连跑 3 次 `choices` → **每次 `✓ 74 ✗ 0`**；
  全量门禁第二次复验 **PASS**。
- **机制**（dev3 §11.3，PM 已认可）：夹具只等**标题行**；Ink **逐行**写帧 →
  "标题已到、条目未到"的**中间帧**被放行 → 紧随的条目断言红 → 随后**裸 `keys Escape` 清理**
  打在还开着的选择器上 → 关掉整个设置视图 → **之后每段都在错的视图里跑 → 级联 62 条**。

## 要做的四件事（每条都要可证伪）

1. **等待必须是"稳定帧"，不是"标题出现"**：目标条件满足后**再确认一次**（两次连续相同的 capture，或
   等到条目行与标题同时可见）；任何"只看标题"或"只看单帧"的等待都要改掉。
   **判据**：注入一个**人为中间帧**（例如让夹具先只渲染标题、隔一拍再渲染条目）→ **旧逻辑必须放行（演示红）**，
   **新逻辑必须不放行**（这一对翻转要给原始输出）。
2. **清理按键必须先确认当前状态**：任何 `Escape`/清理键发出前，先验证"现在确实在选择器里"（标题在场）；
   不在就不发。裸清理键**不得**再有机会关掉整个设置视图。
   **判据**：构造"清理时视图早已关闭"的现场 → 清理**不发**键、断言不受影响（给输出）。
3. **失败必须自带现场**：断言失败时打印**观察到的 pane 状态**（最后 N 行 capture）、**哪个等待超时 / 等了多久**、
   以及"这是一次**孤立**失败还是**级联**"（例如：失败后立即再 capture 一次并打印）。
   **判据**：故意让一个等待超时 → 输出里能看到上面的三类信息（贴原始输出）。
4. **不许用"加预算"当修法**：等待可以改成**自适应轮询**（条件成立即返回），但**不得**只是把固定
   `sleep` 或超时数字调大当作修复；报告里要写明"哪一处是条件化、哪一处保留固定等待、为什么"。

## 边界

- 只碰 `grant:` 列出的路径。**不改产品代码**（`panel/src/**`、`scripts/lib/**`、`extension/**`）；
- **不放宽任何断言**：这条任务的目标是"假红不再级联"，**不是**"让它更容易过"——新逻辑必须能抓住**真**失败；
- 不动 `TEAM_P21_*` / `TEAM_SMOKE_*` 的**语义**（可新增夹具用的诊断开关，但要在报告里登记）；
- 不 push；不改 `docs/team/DECISIONS.md`。

## Acceptance（真跑，贴原始输出）

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
for i in 1 2 3 4 5; do bash skills/teamsmith/tests/panel-p21.sh choices 2>&1 | tail -1; done   # 连跑 5 次全绿
bash skills/teamsmith/tests/panel-flip-m54.sh F-B
bash skills/teamsmith/tests/panel-flip-m54.sh F-C
```
外加上面四条判据的**原始输出**（尤其"中间帧注入"那对红→绿）。

## Report

`docs/team/reports/M59-dev3.md`：四条判据逐条 + 翻转原始输出 + 连跑 5 次的末行 + 改了什么/没改什么。
