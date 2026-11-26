---
id: V205
title: 只复核任务标签接入最近更新看板的修订
agent: dev3
deps: P496,V195,P509,V202
category: verify
phase: verify
change: task-labels
specs: board-and-status, panel
deltas: -
branch: task/V205-task-labels-recent-order-review
---

# V205 · 定点核对两项已批准行为能否共存

排在 V203 交付后。原 P496 方案和 V195 原结论继续有效；只审 PM 写的兼容修改 `7a62eab4..a0911dfe6b0faa237a504c6b5045f151541f2816`。固定只读 `/var/tmp/task-labels-recent-order-review.tVySLq`。P497/V196 和原证据都保持暂停，不改任何产品和规划。读 AGENTS、本人线程、归属、D271、原方案及 A18、P509/V202 的相关正式要求/证据。

逐份只看五份规划差异。对照正式 `panel` 的完整 kanban 要求，确认最新的八个场景逐文保留，默认同栏仍按最近更新时间、无时间沿现行顺序；标签过滤保持所选顺序，仅显式优先级按分数，等分原表序，至少一个案例的时间顺序与同分原表序相反。检查工作页、机器输出、卡片内容、焦点和 P509 一批多键保持现状；核已有孤立测试能在同一已批准测试中证明发生，没取消不相关检查。`board-and-status` 确认七个业务字段、空 Issue、右侧可选时间与原写入行为并存，不把旧六/七列读写基准声明成全局固定列数。CLI 向量、精确算分、表外同号及标签读写约定不变。不复审原范围或 P507，不扩新设置或巡检。

从固定检出核 `git diff --check 7a62eab4..HEAD` 和 `PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0 openspec validate task-labels --type change --strict --no-interactive`；只静态读方案和原有测试联系，尚无接入代码，不跑产品、模型、构建、屏幕或全量。只提交 `docs/team/reports/V205-dev3.md`，给 ACCEPTED 或精确待修处，记录实际结果和未执行项。本地提交 V205 / `Agent: dev3`，不推送、合并。