# P328 · 守卫清点（只读）：哪些归档变更在治理门禁自己，哪些在守产品行为

task: P328
agent: dev-bob
phase: analysis
category: analysis
change: -
anchor: none (infra) — 用户原话：「为了保证 Agent 不犯错，逐渐构建了一套复杂的软件系统来管理 Agent」
deltas: -
branch: task/P328-guard-inventory

## 为什么有这条

本会话归档 20 条变更，其中相当一部分在守我们自己的流程（锁卫生、锁抗外部删除、打断长回合、孤儿清理、身份作用域、门禁瘦身……），不是用户能直接感知的产品行为。产品 105k 行 / 测试 75k 行 / 门禁 135 段 / `|| true` 2.3 万处。**这条任务只做清点与减法建议，不新增任何东西。**

## 只读边界（硬）

- **不改**任何代码、测试、门禁、规格、模板、配置；不跑套件、不跑容器、不启动计时实验。
- 允许读：`docs/team/BOARD.md`、`docs/team/DECISIONS.md`、`docs/team/reviews/`、`docs/team/tasks/`、`openspec/changes/archive/`、`skills/teamsmith/tests/section-paths.tsv`、`skills/teamsmith/tests/smoke.sh`、`skills/teamsmith/SKILL.md`、`references/*.md`。用 `rg`/`git log` 取证就够。
- 产出**一个**报告：`docs/team/reports/P328-dev-bob.md`，**不超过 120 行**。

## 要回答的三件事

1. **分类**：本会话（2026-10-13 起）归档的每条变更，标 `product`（用户可感知的行为）或 `governance`（守我们自己的流程），一行一条；判据写一句话（例：它改了 `scripts/lib/*` 的对外行为 = product；它只改了门禁/夹具/流程文档 = governance）。
2. **守卫套守卫**：找出「同一件事被两层机制各自守一遍」的具体配对，给出证据（段键 + 文件行号 + 断言名）。已知候选（请自己验，不要照抄）：门禁锁卫生 vs 门禁锁抗外部删除；门禁段预算 vs 超时上限；`panel-p21` readonly vs `panel-b2` readonly（P318 已发现后者从不运行）；`signal-gate` 的夹具自检 vs 门禁里的 §58。
3. **可退役的最小清单**：按「删掉它，会失去什么」排序，给 **≤5 条**具体动作，每条写：**删/合并什么**（文件:行 / 段键 / 变更名）、**它现在守什么**、**谁已经守住了同一件事**（证据）、**删了会失去什么**（诚实写，包括「什么都失去不了」）。动作必须是可执行的删除或合并，不许写「考虑重构」「建议建立机制」。

## 不许做的事

- 不许提出新的检查器、预算表、分级机制、调度器、红线——这是减法任务；
- 不许用「场景数量」「断言条数」当质量证据；
- 不许重跑任何套件来支撑结论（要数字就读现有记录并点名出处）；
- 不许改规格或账本结构，也不许写「需要新增一条规格」。

## 验收

交付时报告在盘、树干净（只多这一份报告）、`git status --short` 干净、`openspec validate --all --strict` 仍 20/0。PM 按你的清单逐条裁定；**裁定前不许动任何文件**。
