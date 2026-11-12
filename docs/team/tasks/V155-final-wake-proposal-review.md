---
id: V155
title: delivery-final-wake-integrity 提案独立审阅
agent: dev3
category: verify
phase: verify
change: delivery-final-wake-integrity
specs: notify-and-inbox background-jobs pm-lifecycle
anchor: openspec/changes/delivery-final-wake-integrity/proposal.md
deltas: -
branch: task/V155-final-wake-proposal-review
---

# V155 · 非作者审阅 P448

冻结候选 `feb4c911`（规划 `83e7072e`），作者 dev2。你未参与探索或提案。阅读 change 全部工件、P447/P448 报告及真实 `team-bg.ts`、`team-notify.ts`、`cmd-agents.sh` 合并边界与现有 harness。

## 必查

1. `session_cwd` 与执行 cwd 是否真正分离；旧记录 legacy 接受是否会把独立 clone 或他人作业错认给席位；pid/starttime 是否仍是必要证据。
2. delivered-only tip 分量是否准确实现：不同 delivered tip 各唤醒一次，同 tip 重复仍合并，suspended 进度不敲，suspended→delivered 新行；有没有让普通提交噪音翻倍或让最终提交再次无唤醒。
3. 是否完整修改原有跨 tip 合并/Count churn 场景而不是保留两套相反约定；watcher 是否仍由新行驱动，不是强制 sendWake。
4. PM 指引三处是否可执行且不夸大：不把旧 tip/merged 当未完成，不要求读屏或由 PM 重跑验证；真实一次性 PM 验证是否可证伪。
5. 8 项 Apply 是否能在现有扩展/CLI/harness 内完成，测试是否替换旧断言而不是叠加第二层守卫。
6. 是否引入不必要的新系统、配置、定时服务或人工双发。

## 交付

`docs/team/reports/V155-dev3.md`，先给 ACCEPT / NEEDS-CHANGES，每项附具体反例和最小修法。可跑结构检查，不实施、不跑全量/夜间/61b、不合并、不归档。通知 PM。
