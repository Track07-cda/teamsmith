---
id: A20
title: 同步已验收的任务标签和优先级规则
agent: dev2
deps: P497,V196
category: docs
phase: archive
change: task-labels
specs: board-and-status, panel
deltas: -
branch: task/A20-archive-task-labels
---

# A20 · 同步原任务标签变更

作者 dev；原非作者 verify 的候选 `9b491f07` 与合并 `5471a6f3` 已接受 `c9fbb5e705e15763048c803adee9187ca18cfef5`，见 `docs/team/reviews/V196.md` 及 D267 收尾。候选 46/0、合并只比同一性和一次正向排序，本单不验产品。原四轮 FAIL 已保留。PM 依 D241 只确认将已批准、仅 Git 文档、可撤回的五条要求同步到正式规格。先读本项目 AGENTS、线程、归属、archive 说明和原生 change；清单 6/6，`team change status task-labels` 仅允许显示 A20 自身一项未完成。

用自己在 `/var/tmp` 建的试做根先执行原生 `openspec archive -y task-labels`。只应移动六份现存规划文件（含 `.openspec.yaml`、两个 delta，无当前阻塞说明），把 `board-and-status` 的三个新增要求以及 `panel` 的一个新增、一个修改要求同步；以原方案和同名块对照，保留其他要求、Purpose、既有场景和同一能力内正文。空间行差异须另列准确位置/字节并交 PM，其他差异先停。试做符合范围再在本人任务分支执行同一个原生命令一次；正式与试做树比对一致。别手工搬文件或修工具，不碰并行 `project-label-management`、产品或真实运行状态。

仅执行 `openspec validate --all`、`bash skills/teamsmith/tests/spec-refs.sh --check`、Git 差异及已配置的账本隐私检查。记录实际次数和退出码、原件同一性、未执行全仓严格或产品验证；原文件已保全不重跑验收。只另写 `docs/team/reports/A20-dev2.md`，按 A20 / `Agent: dev2` 本地提交，不推送、不合并、不发布。私有根等 PM 核收再清理。
