---
id: P502
title: 编写 Pulse 看板按最近更新排序方案
agent: dev2
deps: P501
category: analysis
phase: opsx-propose
change: pulse-board-recent-first
specs: panel,board-and-status
deltas: panel,board-and-status
branch: task/P502-pulse-board-recent-first-proposal
---

# P502 · Pulse 看板页最近更新在前的 OpenSpec 方案

P501 `ef8260a9` 的探索已接受，直接复用 `docs/team/reports/P501-dev2.md` 与 D269，不重开来源研究。按 `openspec-propose` 只交付 `openspec/changes/pulse-board-recent-first/` 的原生规划四种工件和 `docs/team/reports/P502-dev2.md`。只调整正式 panel 和 board-and-status 中与本次排序/行写入相冲突的要求及必要场景，不另写一份需求，不写代码。

- 按 D269 规定的可选末列与真实变更，不补历史、不编时间。写清专用列名、格式与选择规则；用现有任务表定位、行新增及状态/负责人写入，字段与时间同一次替换、保留其它列和行序。旧表和手改表可以继续使用；同 ID 多行分别按是否真变化，其他表不带任务时间。无操作变化、拒绝和只改有关联的文件不改时间；不改变旧任务命令返回/审计。点名写入调用（包括 close、dispatch），说明现有并发保障和最小写入范围，不顺手重做整个看板写入；若两个真实写入竞争会造成新增的时间/字段丢失风险，只比较如何复用一个既有锁，不增通用并发设施。实际的本项目看板不迁移。
- 倒序只影响看板页的同栏显示与相应操作。工作页、CLI 原顺序和数据计数不变；说明 JSON/打印兼容面，别为了隐藏一个可选列再造数据源。明确已完成和放弃两栏有时间的首窗与无时间旧数据的兼容次序；已选同一原行刷新后仍指同一条，绘制/导航共用同一顺序（包括窄和宽两种布局），原有折叠及滚动继续。不得承诺跟踪人工交换两条完全同编号行的物理位置。标签仅记将来衔接点，现有 P497/V196 不改、不解阻；优先级显式选项与同分保留。
- 独立验收用一处原有看板行为场景替换/收拢（先核 `tests/panel-b3.sh board` 的选择方式和改用真实 board/detail 是否影响非看板场景）；用真正不同时间而不是靠 `sleep` 的时钟样本证明「较老创建但最后实际更新会上移，重复操作不会上移」，包含少量等时/无时间、历史首窗及从刷新后的界面打开正确任务的覆盖。必要的旧断言只排除新时间列，仍检查所有旧列且现有拒绝场景不丢；只用一个破坏排序的短反例，不重复整组，不新加测试框架/独立段或全量。

本单仅运行 `openspec validate pulse-board-recent-first --type change --strict --no-interactive`、`bash skills/teamsmith/tests/spec-refs.sh --check` 及报告所需账本隐私/Git 差异检查；保留实际命令与退出码。不要运行 Pulse、产品工具写入、测试选段、全量或安装。按项目规则本地小步提交（P502、`Agent: dev2`），不合并、不推送、不归档。等待另一席位审阅；未接受前不实施。