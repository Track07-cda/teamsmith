---
id: V150
title: 无额度 PM 提醒工具独立复验
agent: dev3
category: verify
phase: opsx-verify
change: agent-self-reminder
specs: agent-self-reminder pm-lifecycle watchdog
anchor: openspec/changes/agent-self-reminder/tasks.md
deltas: -
branch: task/V150-remind-tool-verify
---

# V150 · 非作者复验 P442

冻结候选 `bfa88aef`，作者 dev2。你未参与实现。阅读 change、P442 报告和实际 diff；作者数字不是结论。本片只验 2.1.2、2.2.2、3.3，不表示整个 change 可归档。

## 独立验证

1. 在自己的私有 Pi/tmux 和证据根运行 `remind-tool-real.sh`：PM add/list/show/cancel、活动 key 原 ID/due、实际观察后同 key 新 ID、无 key 两个 ID、64 KiB+末尾换行；ordinary/worker/forged/reload 零状态读写；doctor not-running/unknown/error/ready。
2. 在自己的源码副本做反向改坏：删除 execute 身份验证、截断工具正文、恢复 8 条上限或 5 秒间隔，必须按对应行为变红；恢复后绿。不得只引用作者翻转。
3. 运行 `remind-tool-node.mjs`、`remind-cli.sh`、`remind-delivery.sh` 和 `smoke.sh --select 3,6i,65,66,67`，保留完整日志；检查九条同批、无等待下批、超过旧 active 数量不拒绝。
4. 检查 `team_pm_pi_args` 是唯一 PM 注入入口，worker 和 `/team` 未接入；没有新配置键或替代额度；30 秒逾期与终态保留未误删；未做的恢复/AC 未勾。
5. 给出 Completeness/Correctness/Coherence、CRITICAL/WARNING/SUGGESTION/Final assessment，明确本片是否可合并及未验证范围。

## 交付

`docs/team/reports/V150-dev3.md`，先给 PASS / NEEDS-CHANGES，附自己的命令、原始输出和日志路径。只提交报告，不改实现或规划，不合并、不归档、不发布；不跑全量/夜间/61b，不使用真实模型自主创建。
