---
id: P486
title: 让两份提醒测试用现有临时目录管理
agent: dev-bob
category: code
phase: opsx-apply
change: reminder-test-temp-root-ownership
specs: verification
deltas: -
branch: task/P486-reminder-test-temp-roots-apply
---

# P486 · 只实施已独立接受的方向

读本人线程、OWNERSHIP、`docs/team/reviews/reminder-test-temp-root-ownership-proposal.md` 的 ACCEPTED 记录、P485/V184 报告及 `openspec/changes/reminder-test-temp-root-ownership/` 当前 OpenSpec apply 上下文和工件。按任务 1.1–1.2 实施。任务 2.x 由非作者一次验证，不得代跑或勾上；保留返修回执中的停止顺序和验收边界。

允许写 `skills/teamsmith/tests/remind-tool-real.{sh,mjs}`、`remind-adversarial-real.sh`、`remind-adversarial-faults.{sh,mjs}` 共五个测试文件，和自己的报告；提交静态证据后只勾本 change `tasks.md` 的 1.x。复用现有目录管理、PID 与私有终端工具，保留原有参数、退出结果、指纹检查及主动保留的证据路径。既有恢复入口、smoke、共用工具、提醒产品与正式规格不动。禁止引入进程组信号、扫描、通用监督器、测试框架或额外开关。若见现有接口不能满足已批准方案，留具体反例并回 PM，不自行扩大文件或修改规格。

作者检查仅受影响 shell 的 `bash -n`、两份 `.mjs` 的 `node --check`、写集、`git diff --check`；按现有工具核对 apply 进度。不运行 2.x 行为样本、真实 Pi、故障矩阵、整套、现场提醒或模型。分步本地提交；在 `docs/team/reports/P486-dev-bob.md` 写改动、实际命令/退出码、未运行范围及精确候选 commit，不推送、不发布。完成后停止修改，交非作者独立验收。