# P42 · settings-view-groups 独立验证（覆盖 P30 + P32 修订）

```
task:   P42
agent:  dev
issue:
change: settings-view-groups
specs:  panel#The settings view groups the contract by the functional group the command reports / panel#The settings view fills the pane it is given and its row window grows with it / panel#Every key affordance is also a mouse target / memory-and-deps#The machine read reports each row's group
phase:  verify
anchor: change
deltas: panel, memory-and-deps
grant:  docs/team/reports/P42-dev.md · docs/team/reports/P42-dev/**（只写报告与证据，不改实现）
deps:   P29（propose）· P30（apply）· P31（verify P30 的那一轮，dev2）· **P32（修订：标题分节线 + 用满高度 + F1 接线，dev-bob）**
status: todo
budget: 一个工作块（只写复验证据与报告，不改实现）
```

> 本地模式：不 push。**apply 的作者是 dev-bob（P30 与 P32）→ 你来验（D31）。**
> P31 已验过 P30 的那一轮；**本任务的重点是 P32 的修订面**，但要对整个 change 负责。

## 要对抗性验证的（每条给可复现命令 + 原始输出）

1. **标题可辨识（P32）**：分组标题是**分节线**（键行不带）；**组间有可见分隔**（由标题承担）；
   ⚠️ 别只看文本——**断言"标题行匹配分节线、键行不匹配"**，并给出**反向**（把标题的规则去掉 → 断言红）。
2. **用满窗口高度（P32）**：在 **45 / 33 / 30 / 25** 四档**真渲染**（pty + 真 bundle），
   断言"内容到键栏之间 **≤1 行**空白"、"45 比 30 的可见行数差 **≥8**"、`↑/↓` 计数与窗口行数对账一致；
   **自己算一遍**（不要复述别人的表）。
3. **功能域分组（P30）**：标题是**功能域**名（12 个 slug，不是 apply/restart/refuse）；组内保持**读的顺序**；
   无 group / 未知 token → 可见降级；**视图不硬编码**（把某键的 group 改到别的域 → 归属跟着变）。
4. **词 + tone（P30）**：行级 class 是**词** + tone；只留 tone 的变体必须让断言红。
5. **滚轮（P30）**：设置视图自己的 offset + **事件消费**（不穿透到背后页面）；b3 的三处 wheel 不回归。
6. **F1 接线（P32 的收口）**：`smoke.sh` 的 `38-f`：**FAST 下可见 SKIP**（带原因）、全量里对
   `panel-p21.sh groups settings wheel` **硬断言**；自己跑一次三场景并**计时**（报告称 148s / 增量 ≈2.5 分钟）。
7. **基线未被碰**：已归档 `settings-choice-editors` 的直写/零读取/危险值例外「其他」路径——**抽查两条**。

## 至少两条变异（红→绿原始输出）

- 去掉标题的分节线规则 → 可辨识断言红；
- 把"用满高度"的算术退回旧值（或注入 16 行空白）→ 空白断言红；
- 还原后 `git status --porcelain` 干净。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/panel-p21.sh groups settings wheel
bash skills/teamsmith/tests/panel-b3.sh
```

## Boundaries

- **不改实现**（`scripts/**`、`tests/**`、`openspec/**` 一律不改）；缺陷写清楚交回 PM；
- 变异只在临时副本；不 push；不改 `docs/team/**` 里 PM 的文件。
