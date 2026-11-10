---
id: V151
title: 提醒恢复与生命周期独立复验
agent: dev3
category: verify
phase: opsx-verify
change: agent-self-reminder
specs: agent-self-reminder pm-lifecycle watchdog
anchor: openspec/changes/agent-self-reminder/tasks.md
deltas: -
branch: task/V151-remind-recovery-verify
---

# V151 · 非作者复验 P443

冻结候选 `ef87d229`，作者 dev。你未参与实现。阅读 change、P443 报告和实际 diff；作者数字不是结论。本片不覆盖 5.x 或真实模型自主创建。

## 独立验证

1. 在自己的私有 Pi/tmux 与证据根运行 `remind-recovery-real.sh`：启动参数含通常 resume/PM 扩展、无 `@pm-prompt` 或替代提示；提醒先于普通 backlog；session 连续；new/fork 后工具和 doctor 立即不再 ready。
2. 运行 `remind-pulse.sh`：两种真实 Pulse 形状、长巡检期间入队、每批每轮至多一次恢复、无重叠、停止后子进程回收。独立做一个优先级/重复恢复反向改坏，证明普通巡检不会饿死。
3. 运行 lifecycle、recovery-unit、CLI、delivery、remind-tool-real 和相关选段 `smoke.sh --select 3,6i,7,11b,26,65,66,67,68`，保留完整日志与未跑键。
4. 核查 running/busy/already-starting 不重复启动，quota/capacity/identity/missing extension/unsupported adapter/failed send 不假成功；cancel-vs-intent、pruned late event、JSON 拒绝和 Standby 代次保持正确。
5. 在自己的副本至少做三类反向改坏：恢复普通启动提示、丢掉 unknown、结构化拒绝退回人读行；对应断言必须红，恢复后绿。
6. 给出 OpenSpec assessment 和本片是否可合并；明确 5.x、全量、真实自主性未验证。

## 交付

`docs/team/reports/V151-dev3.md`，先给 PASS / NEEDS-CHANGES，附自己的命令、原始输出和日志。只提交报告，不改实现或规划，不合并、不归档、不发布；不操作真实团队 PM/Pulse/Standby。
