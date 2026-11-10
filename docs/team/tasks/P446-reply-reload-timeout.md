---
id: P446
title: 修复关键回复两个 command reload 看门狗超时
agent: dev2
category: code
phase: apply
change: -
specs: key-replies
anchor: openspec/specs/key-replies/spec.md
deltas: -
branch: task/P446-reply-reload-timeout
---

# P446 · 既有 reload 失败定位与修复

V152 全量及 P444 开发期均复现：`lifecycle` 与 `noentry` 的真实 Pi `reload` 在 90 秒 fixture watchdog 超时；基线也同样复现，不是提醒引入。

## 要求

1. 在改动前基线与当前 main 分别用私有真实 Pi/tmux 复现，保留原始帧、进程和日志；确认卡在哪个 reload 动作与扩展生命周期。
2. 修产品或夹具的真实根因，不提高 90 秒上限、不删除 lifecycle/noentry、不把超时改 SKIP、不用静态文本检查代替真实 reload。
3. 验证两个原失败场景恢复，并保留正常 marker 清理、保存、身份和 doctor 行为；反向改坏应重新超时或按名失败。
4. 运行 `reply-capture-real.sh` 相关及全量、`key-replies.sh --select workflow`、相关选段、结构检查和账本禁令。不跑全量 smoke/夜间/61b。

报告 `docs/team/reports/P446-dev2.md`，先给根因，附改前/改后真实 Pi 证据、红绿恢复和未跑范围。提交本地分支并通知 PM，由非作者复验；不合并、不发布。
