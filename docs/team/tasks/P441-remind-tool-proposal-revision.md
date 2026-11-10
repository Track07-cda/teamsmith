---
id: P441
title: 自我提醒：修订 PM 工具提案，取消额度限制
agent: dev2
category: analysis
phase: opsx-propose
change: agent-self-reminder
specs: agent-self-reminder pm-lifecycle
anchor: openspec/changes/agent-self-reminder/proposal.md
deltas: agent-self-reminder, pm-lifecycle
branch: task/P441-remind-tool-proposal-revision
---

# P441 · 只修订已有提案：工具保留，额度删除

## 用户最新决定

不要为 Reminder 工具设置多项额度。用户决定覆盖原 accepted proposal 中的固定限制，但不改变 PM-only 工具、真实投递、Standby 和恢复语义。

本任务只修订 `agent-self-reminder` 的 proposal/design/delta specs/tasks 与 P441 报告，**不实施代码**。

## 删除

- `TEAM_REMIND_MAX_ACTIVE`、`TEAM_REMIND_MAX_BYTES` 两个配置键及其 schema/template/reference/panel-label 实施面；
- 20 次/60 秒创建频率；
- 100 条 active/unknown 上限；
- 16 KiB 正文上限；
- 每批最多 8 条；
- 批次间隔 5 秒；
- 强制 30 秒最小延迟。

不得把这些限制改名后继续保留，也不得以“安全”名义新增替代额度。

## 保留并写清

- 时间必须有效且在未来；相对时间在同一创建事务计算一次；
- 正文非空、合法 UTF-8、无 NUL，完整保存/显示/投递，不截断；
- key 幂等与冲突处理、单调 ID、状态一致；
- 一个批次在结果未知时不盲目重发；确认/恢复不改变；
- PM-only `team_remind` add/list/show/cancel，每次调用重新验证身份，worker/ordinary/forged/reload 后隐藏或拒绝且零状态访问；
- 诚实 doctor 证据与现有 Pi/Pulse/Standby 行为。

## 同步修订

1. proposal/design 中把限额决策替换为“无额度的最小工具”，说明用户最新决定；
2. delta specs 删除额度场景，保留有效时间、完整正文、身份和恢复场景；
3. tasks 将 2.2 改为无配置键的最小输入校验，3.3 保持工具注入；按已有证据重整已完成勾选项，不把未做工作勾掉；
4. 明确本 revision 不影响已落地的 CLI、状态、Standby、最小投递代码；
5. 报告 `docs/team/reports/P441-dev2.md`，列出删除项、保留项和结构校验。

运行 `openspec validate --all`、change strict、`spec-refs --check`、`section-select --check`、账本禁令和 `git diff --check`。由非作者做定点审阅后再派 Apply；不跑长测试、不合并、不归档。
