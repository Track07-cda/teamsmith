---
id: P494
title: 让两项提醒诊断测试走正式 PM 启动登记
agent: dev-bob
category: code
phase: opsx-apply
change: -
specs: agent-self-reminder#PM tool availability is honestly diagnosed
deltas: -
branch: task/P494-ci-reminder-formal-test-launch
---

# P494 · 只改两项测试的启动方式

P493 `17172b39` 在相同 npm Pi 1.6.0 容器确认：原 `pm`/`noentry` 两例的 Pi 是两层 shell 后的孙进程且未正式登记，两项诊断 0/2；用产品 `team_pm_start` 登记后两项 2/0，停止仍报 `not-running`。读 `docs/team/reports/P493-dev-bob.md`，已保存原件见线程。

只改 `skills/teamsmith/tests/remind-tool-real.mjs` 内 `pm`、`noentry` 启动测试数据和必要的共用小段，沿用现有 `team_pm_start` 调用方式与真实私有 tmux/loopback。无入口样本仍真实缺少提醒扩展；不凭空补 PID、证据或 doctor 输出，不让测试通过改变产品识别、加入生产开关或接受 `sh`。保留现有 ready、无入口 unknown、真实停止 not-running 和消息/工具所有断言；其它场景仍用现有路径。保留子进程启动、失败、中断及清理既有行为，使用现有 PID/回执机制。不要顺手改其它测试、配置、正式规格或当前实际项目。

作者做静态范围和语法检查，不重复 P493 实验。独立验收者后续一次验证原两个样本及其中的停机检查，查实登记、相同 Pi 布局与私有进程回收，不跑整套。交 `docs/team/reports/P494-dev-bob.md`，仅本地提交，不临时改全局安装、不碰已发标签和包、不重触发 CI。