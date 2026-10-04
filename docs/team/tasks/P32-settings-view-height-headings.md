# P32 · settings-view-groups 修订：分组标题可辨识 + 视图用满窗口高度（apply + delta 修订）

```
task:   P32
agent:  dev-bob
issue:
change: settings-view-groups        # 未归档 change 的修订（apply 之后、verify 正在跑）
specs:  panel#The settings view groups the contract by the schema row's domain
phase:  apply（含本 change 的 delta 修订）
anchor: change
deltas: panel
grant:  scripts/panel/src/layout.ts · scripts/panel/src/strings/{zh,en}.ts · scripts/panel/panel.js（build 重建）· openspec/changes/settings-view-groups/**（delta 修订）· tests/panel-p21.sh（groups/settings 段）· skills/teamsmith/CHANGELOG.md（如需要）
deps:   P30（apply 已合并）· P31（verify 正在进行——本任务与它错峰，见下）
status: todo
budget: 半个工作块；做不完交 PARTIAL
```

> 本地模式：不 push。**P31（verify）正在跑**：你只在自己的 worktree 里改（和它互不影响）；
> 但它验的是**本修订之前**的 delta 与 tip——所以本任务的**修订内容会再走一轮独立验证**（PM 安排）。

## 用户的两条反馈（2026-09-22，实际使用后；PM 已在 120×45 的 pty 上复现并量了数）

```
 4|  身份与账本布局                          ← 标题与行几乎同形（只是缩进 + 色调）
 5|› 项目名                 pm-skills · 只读  …
17|  分支与 forge
18|  分支命名模式           task · 只读  …
22|  ↓101
23| 只读：手改 .pi/team/config.sh 里的 TEAM_PROJECT
24| 审计（最近）                             ← 之后 28–43 行全空（16 行没用上）
44| m 写信 · f 冲刷 · …
```

1. **分组标题要和选项行有区分**（或各组之间加分隔）——现在标题 `身份与账本布局` 与行 `项目名 …` 视觉上几乎一样；
2. **视图没有用满窗口高度**——45 行的面板里，内容到第 27 行就结束了，**28–43 共 16 行空白**。

## 硬要求

1. **先测后改（M65 的纪律）**：在 design 里写清"那 16 行去哪了"——逐项列出尾部块（hidden 计数 / 只读提示 /
   CLI 提示 / 审计块 / 空行）与 `SETTINGS_FOOTER_ROWS`（`layout.ts:1166`）各预留多少、算式是什么、
   为什么实际渲染短于预算。**先给数字，再改**；改完给 45 / 33 / 25 三种高度的前后对照（同一 fixture）。
2. **验收判据（可证伪）**：
   - 45 行面板：**内容结束到 footer 之间 ≤1 行空白**（现在是 16）；33/25 行同理按比例；
   - **窗口高度随面板高度增长**（45 vs 30 的行数差 ≥ 8）；
   - 分组标题**可辨识**：标题行与键行在渲染上有明确区分（分隔线/前导符号/色调组合，任选其一），
     并有 pty 断言（例如标题行匹配 `─` 分节或专用前缀，且键行不匹配）；
   - 各组之间有**可见分隔**（或标题自身承担分隔）——选一种并写成断言；
   - 行数记账仍诚实：`↓N` 与窗口行数一致（P30/D5 的 `units` 成本模型要跟着更新，**别让它再错算**）。
3. **delta 修订**：把"标题可辨识/组间分隔"与"窗口用满可用高度、随面板高度增长"写进 `panel` delta
   （在既有 requirement 上补 scenario，或新增一条——按语义选），**不许删 base scenario**；
   在 `design.md`/`proposal.md` 各加一段修订说明（日期 + 原因 + 用户反馈引用）。
4. **不许回退已验收的行为**：功能域分组（P30/D1-D3）、行级词+tone（D4）、滚轮自己的 offset 与消费（D5）、
   `panel-b3` 的三处 wheel、已归档的直写/零读取基线——一个字不动。
5. 小步提交；每批 `TEAM_SMOKE_FAST=1 bash tests/smoke.sh </dev/null` 绿；交付前全量一次。
6. **F1（P31 的 finding，PM 裁定必须一起收口）**：design D7 与 `smoke.sh` 的 38-e 注释都宣称
   `panel-p21.sh settings/groups/wheel` 三个场景**在完整门禁里跑**——**实际没有任何调用点**。
   把三个场景接进完整门禁（新增 38-f；**FAST 下可见 SKIP**，慢段只在全量跑；照 38-b 的写法），
   **并实测报出全量门禁时长的增量**（改前/改后各一次完整跑）。
   若增量过大（>3 分钟），给出数字与替代方案（例如只接 groups+wheel，或把 settings 段并入 38-b 同一次 server 启动）
   再交回 PM 裁决——**不许用"改成永远 SKIP"或删掉断言来糊过去**（FAST 的 skip 必须可见且带原因）。

## 必给的翻转（红→绿原始输出）

- 把"用满高度"的算术改回旧值 → 空白行断言红；
- 去掉标题的区分标记 → 标题可辨识断言红；
- 去掉组间分隔 → 分隔断言红；
- 还原后 `git status --porcelain` 干净、bundle 两次构建字节一致。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/panel-p21.sh groups settings wheel
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
```

## Deliverables

- 实现 + delta 修订 + 翻转证据 + 报告 `docs/team/reports/P32-dev-bob.md`
  （含"16 行去哪了"的算式、三档高度的前后对照表、每条翻转的原始输出）。
