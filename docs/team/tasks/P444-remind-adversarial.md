---
id: P444
title: 自我提醒：受控对抗验收与 AC 映射
agent: dev2
category: code
phase: opsx-apply
change: agent-self-reminder
specs: agent-self-reminder verification watchdog
anchor: openspec/changes/agent-self-reminder/tasks.md
deltas: agent-self-reminder, verification, watchdog
branch: task/P444-remind-adversarial
---

# P444 · 完成受控对抗验收（不含真实自主性）

## 范围

基于已合入的 P442/P443，执行 tasks 5.1、5.2、5.3 以及 5.5 的**开发期定向检查**。5.4 真实模型自主创建保持未做；最终独立全量验证由另一非作者执行，不由你勾选。

不重开产品设计；若发现缺陷，先保留反例，做最小修复并交独立复验。

## 必做

1. **G1/G2 与身份**：私有 tmux、隔离项目/state、真实 Pi + controlled model。暂停较早 handler，分别覆盖事件前后 off/on；断言真实代次、审计、歧义保留、手工 off/on 不等待 Pi、外部 session 拒绝。
2. **进程死亡与重放**：在 intent、Pi 调用、事件、观察/off/audit 原子提交与 rename/fsync 前后注入死亡；重启后核对快照、实际发送次数和未知处理。A+B 同批重放、fresh G2 后迟到回调只能记录，不得再花权利或清新 Standby。不得伪造回调或时间。
3. **AC 映射**：AC-01 创建触发、AC-03 停止恢复、AC-04 Pulse 重启、AC-05 逾期补发、AC-06 Reminder 例外及不可证明顺序边界、AC-07 busy follow-up、AC-08 重扫/重启、AC-10 取消、AC-11 身份隔离、AC-12 现有 dispatch/notify/review/standby/Pulse/Outbox/`/team` 回归。
4. **可证伪**：每个新检查有反向改坏与恢复；缺真实证据必须显式失败，不得 SKIP 后算通过。新夹具登记 section-paths。
5. 运行受影响选段、现有 remind/关键回复/dispatch/standby 相关回归、OpenSpec、spec-refs、section-select、账本禁令和 diff check。开发期不跑全量/夜间/61b。

## 交付

小步提交，`docs/team/reports/P444-dev2.md` 先给结论，附 AC 映射、原始时间线/状态/发送次数、红/绿/恢复和未跑范围。明确 5.4 未做、5.5 的最终独立全量验证待办。通知 PM 后由非作者复验；不合并、不归档、不发布。
