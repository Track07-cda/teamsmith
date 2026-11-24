---
id: P493
title: 确认提醒诊断为何看不到仍运行的 PM
agent: dev-bob
category: analysis
phase: opsx-explore
change: -
specs: agent-self-reminder#PM tool availability is honestly diagnosed
deltas: -
branch: task/P493-ci-reminder-pm-recognition-explore
---

# P493 · 确认提醒诊断为何看不到仍运行的 PM

读独立诊断 `docs/team/reports/V191-verify.md`，GitHub run 45318204605 的日志与已保存制品位置见本席位线程。已发布的 0.4.8 标签与 npm 包保持不变。

按 V191 §67 先只复现原 `pm`、`noentry`，使用 c34e1468 的源和 CI 同样的 npm Pi 1.6.0 布局，私有 HOME、prefix、tmux、受控 loopback；不用真实账号/模型。不更新用户安装、不重建共享镜像、不写实际项目、待命或会话。原夹具绕开正式登记；在同一隔离布局用受支持的正式启动登记作对照，保留同刻进程父子、argv/cwd、pane PID、正式 pm.pid、spawn 回执及 doctor 输出，区分额外 shell、npm 路径与真实产品误报，保留 ready/unknown/not-running 本义。已有原件足够则不再下载；只允许上述具名样本和已说明的正式对照，不跑其它组或全量。仅提交查因及最小建议，不改代码、测试、规格或 CI，不先宣布提醒发送有缺陷。

交 `docs/team/reports/P493-dev-bob.md`（真实命令、结果、覆盖和未运行范围），仅本地提交，不推送、不发布、不中断其他任务。