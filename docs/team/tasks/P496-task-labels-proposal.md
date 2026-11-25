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

## V195 首轮定点返修

首轮 `docs/team/reports/V195-dev3.md`（`8ad125a8`）判 REWORK。保留已认可的单文件、CLI 写入、Pulse 只读和旧看板默认行为。原任务、分支、模型与会话继续；不重新探索。集中修以下五处及直接自洽的两份 delta、design/tasks 与本人报告：

1. **排序反例**：保留同一套数据，正常结果必须直接看到 T2=8，改成取最大值后必须实际读到 T2=5；首轮的 ID 顺序恰好没变，删掉所有会变的说法。反例只调用一次同一条分数查询，不重新跑 smoke 或界面。
2. **逐行确认归属**：同 ID 的任务表外行即便状态合法也不能继承标签或被标签筛选命中。交互看板生成原始行时就辨认任务表成员，并让这个身份进入详情，之后才按 ID 取分。保留旧默认行、现有机器输出和原行出现次序；两张真的同 ID 任务卡共用标签但分别可选。用相同 ID、合法状态的表外行做反例，覆盖带筛选的列表、Pulse 筛选及详情；不要靠清洗旧行造通过。
3. **验收接真数据**：看板交互使用同一私有项目的真实 board 读取；无文件详情用真实 detail 或明示为空文件夹具。权重、颜色、错误恢复走同一运行中的界面刷新，不用另起固定画面冒充刷新。59 列同一卡片及点击目标只需同份有/无标签数据；默认导航回到默认顺序检查，不把旧次序套在新排序上。选段不另外拉入 §38、不重测旧整组。
4. **标签失败与看板分开**：文件缺失表示尚无标签，不启动标签读取程序。真实标签错误返回已有看板内容加明确的不可用状态，不丢整个看板或沿用旧分。不为读错文件另配小超时或新增进程；保留一次确实损坏文件的正常/坏/恢复对照，删掉专门模拟替换后同步出错的测试替身（产品仍如实报内容可能已可见）。用已存在的写入保护，不新增权限规则。
5. **名称与按键**：精确标签名须能跨 CLI、面板读取、显示和实际选择；选一种最少改动的方式解决 `sanitizeDeep` 会改对象键和值的碰撞，不能按裁短后的名称匹配。普通 `o`/`t` 仅在看板适用，不抢 `Ctrl+o`；选择列表打开时只操作列表。

只补必要的本 change strict、spec-refs 和提交短检查，真实回执指向返修提交；不重复任何行为测试。作者交新提交后只由原 V195 审阅者复看这五处，不重开方案。

### V195 复看后仅剩一处

读主检出 `docs/team/reports/V195-dev3.md` 的 `ab412192` 复看段（报告 `5fa01e5c`）。其余四项及静态表外行区分已关闭。只修详情刷新：从工作页或看板打开详情时记住当时来源是否属于任务表；表外来源本次打开期间始终不取标签。任务表来源刷新时仍须确认当前引用指向任务表内行。保留现有按 ID 的文件读取、行焦点规则及存储方式，不引入持久行号。把已有表外行的验收接到同一私有场景：从工作页打开表外详情，任务表增加同 ID 行后用 `r` 刷新，仍不显示标签；原看板三行检查保留。不新开场景批次。只改直接相关 design、panel delta、tasks 和本人报告；只补 change strict 与必要差异检查，不重新跑规格引用或行为检查。
