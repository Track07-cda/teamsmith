---
id: V149
title: 自我提醒无额度提案修订独立审阅
agent: dev3
category: verify
phase: verify
change: agent-self-reminder
specs: agent-self-reminder pm-lifecycle
anchor: openspec/changes/agent-self-reminder/proposal.md
deltas: -
branch: task/V149-remind-proposal-revision-review
---

# V149 · 非作者定点审阅 P441

冻结候选 `bb1bf144`，作者 dev。你未参与修订。只审 proposal/design/两个 delta/tasks 和报告，不实施。

## 必查

1. 七类额度及两个配置键是否真正删除，没有换名或替代额度；已落地代码仍存在 BATCH_LIMIT/BATCH_SPACING_MS 是否被明确留给 Apply，未把文档当产品已改。
2. 周期提醒语义是否成立：活动中同 key 同请求返回原 ID 和原 due；观察后释放 key，再用同 key 获得新单调 ID；无 key 的相同正文不猜重。
3. 有效未来时间、非空完整 UTF-8、状态一致、结果未知不盲重发、单批未定不阻止新创建，是否与删除额度一致。
4. PM-only 工具、每次身份核验、worker/ordinary/forged/reload 零状态访问、doctor 诚实证据没有被削弱。
5. tasks 的 9 完成/25 未完成是否与 P406/P409/P422/P423 证据一致；未做的工具、恢复、AC 不得误勾。
6. change strict 当前 6 条长需求失败是否为基线既有而非新增；不得把它说成通过，也不要求本任务顺手拆全规格。

## 交付

`docs/team/reports/V149-dev3.md`，先给 ACCEPT / NEEDS-CHANGES；每项附具体文件/场景和最小修法。可重跑结构检查，不跑产品或长测试，不合并、不归档。通知 PM。
