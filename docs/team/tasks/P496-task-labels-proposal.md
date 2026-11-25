---
id: P496
title: 任务多标签与优先级排序方案
agent: dev2
deps: P495
category: analysis
phase: opsx-propose
change: task-labels
specs: board-and-status, panel
deltas: board-and-status, panel
branch: task/P496-task-labels-proposal
---

# P496 · 把已接受的任务标签方向写成可实施方案

D267、`docs/team/reviews/P495.md` 与 `docs/team/reports/P495-dev2.md` 是本次范围及技术依据。不重做探索；按本仓原生 OpenSpec 指引写 `task-labels` 的 proposal、design、两个 delta 与 tasks，供另一人独立审阅；本单不改产品、模板、测试、现有正式规格或当前团队配置。

## 指定工作

- 用 P495 的单文件、CLI 写入、Pulse 看板只读方向定稿。CLI 以一套 `team board` 命令完成定义及贴标签，界面利用既有任务详情和看板控件；给中英文短文案和正常/窄屏草图。默认视图与显式筛选、排序的差异写进原生规格。不要硬编码示例名称或权重，也不另做任务编辑页、项目设置页或 GitHub 同步。
- 用实际仓库行为约束方案：保留既有看板文件、不迁移、不影响 `board ls` 无选项及历史卡片；写清无任务书、重复任务 ID、同分、首次写入、改名、颜色、改权重、删除以及错误时原数据如何保留。名字使用者无需记内部编号；只防并发写与写半文件等本地实情，不用额外权限位拒绝正常布局。明确底层同一处算分，巡检只预留复用，不写任何巡检规格或代码。怎么筛选/切换排序与焦点如何保持，应有一个完整的用户操作例子。
- 核实际 `panel` 规范里全卡片显示、分栏/焦点及历史从最新开始的条款；仅修改与可选视图冲突之处，其余保留。按 P495 的真实 fixture 对照，清楚说明预定替换哪些弱断言、保留了哪些行为；非作者统一跑一次必要的短行为验证。全量不跑；如果发现确实必须修改另一个能力规格，说明具体冲突留给 PM，不自行扩大 delta。性能数字只作参考，不加一套测试框架。

## 交付与短检查

唯一写集：`openspec/changes/task-labels/` 中原生规划文件（仅上述两份 delta）和 `docs/team/reports/P496-dev2.md`。提交前实际运行并逐项记录输出和退出值：

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
openspec status --change task-labels --json
openspec validate task-labels --type change --strict --no-interactive
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
git diff --cached --check
```

报告先写推荐操作路径、保留了什么、验证覆盖会怎样变，再附真实短检查。按原生工件依赖核齐，小步提交（含 P496、`Agent: dev2`）后交付。无模型行为、真实项目 Pulse、全套或打包测试；不推送、合并或归档，不改真实看板、当前运行进程和通知规则。独立审阅接受前无实施授权。
