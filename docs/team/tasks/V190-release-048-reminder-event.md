---
id: V190
title: 0.4.8 最后补验一个提醒事件场景
agent: verify
category: verify
phase: verify
change: -
specs: agent-self-reminder#Reminder wake may clear only its provably bound Standby generation once
deltas: -
branch: task/V190-release-048-reminder-event
---

# V190 · 在 v0.4.8 固定源只跑已有 event-after

用户明确选 A：本版用 V174 旧全量（5139/2/19，失败保持）+ 后续独立验证 + 本次原场景；不重跑整套。V186 `229475be` 独立核定提醒调用差异：P473 的两步观察与新一轮待命保持判据未变，P486 改 shell/Node 交接和测试时序，需要最后一个实际样本。非作者 verify 在 PM 提供的干净固定源 `c34e1468ea2ab76bdff9cd2bbef0db650604d151` 独立执行；核 `v0.4.8^{commit}` 与 HEAD 相同。

在新私有 `/var/tmp` 证据目录后台启动：实际 Pi、私有 tmux、现有 loopback 模型（不访问真实模型或账号）；使用 `TMPDIR=/var/tmp P442_EVIDENCE=<本次私有记录> P442_KEEP=1 P442_PI=<真实 Pi 绝对路径> bash <固定源>/skills/teamsmith/tests/remind-tool-real.sh --select=adversarial-event-after </dev/null`，干净环境、私有 HOME，命令完整输出和实码分文件保留。这个已有 shell 入口实际走 prepare/run、Node 和原测试，不改任何文件来筛选；不要走默认给入多个组的 `remind-adversarial-real.sh`。项目真实提醒、待命、会话、配置和用户安装不动；用现有范围的只读前后证据说明隔离边界，不加代码或新检查。执行一次，只接受原场景具名通过、`passed=1 failed=0` 与实码 0，同时核保存的事件和 `receipt.json`：确有 `custom_start/team-reminder`，最终 `observed`、`generation-ambiguous`，G2 仍 on、代数 2。仅有成功退出或无样本不算通过。

交 `docs/team/reports/V190-verify.md`，记录源码、命令、外层/测试退出码、实际日志和结果原件位置；不覆盖失败，若失败只报告并保留现场，不自行重试。不运行其它场景、自检、全量、新模型行为测试，不改实现/清单/标签、不推送、不暂存或发布。原件留待 PM 收取后再清理。