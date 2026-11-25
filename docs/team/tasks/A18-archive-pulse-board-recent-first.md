---
id: A18
title: 同步已验证的 Pulse 看板更新时间排序要求
agent: dev2
deps: P503,V200
category: docs
phase: archive
change: pulse-board-recent-first
specs: panel,board-and-status
deltas: -
branch: task/A18-archive-pulse-board-recent-first
---

# A18 · 只同步这次已接受的看板排序要求

P503 实施 dev-bob。V200 的两轮独立记录与 `3e28c820` 的合并版 `862733ea56cefea3c359dbbd35703fca07e9b52d` PASS 已接受。D269 记录的 D241 窄确认只覆盖原生同步此变更。清单全部完成，候选旧命令与折叠报告/最终真实排序与单帧证据各有绑定，不冒称同一提交完整重跑。读 AGENTS、本人线程、任务与 OWNERSHIP；仅在自己的任务工作树按原生 `openspec-archive-change`、现有 OpenSpec 1.16 核 root、工件和 7/7，再执行一次 `openspec archive -y pulse-board-recent-first`。不手工同步/移动，不用硬链接、跳过参数，不运行应用或真正写任务。

只准六份规划原样入档、正式 `board-and-status` 与 `panel` 规格同步各 delta 指定的两条和一条要求，以及本人报告 `docs/team/reports/A18-dev2.md`。保留 Purpose、目标外正文、要求/场景顺序和其它已验行为；不更新暂停的 `task-labels` 草案、不把排序写入它的候选，不改代码、测试、项目看板或现场。用 Git 对象比较入档前后的工件和目标范围；原生工具空行有变化则单列位置及字节，不用宽松 diff 代替，也不手改归档结果。发生其它差异或工具拒绝即停并报明证据。

只做普通 `openspec validate --all`、`bash skills/teamsmith/tests/spec-refs.sh --check`、账本隐私检查与 `git diff --check` / `git diff --cached --check`；记录命令、退出码和旧警告边界。不跑 strict 全仓、产品、模型、发布、全量或已接受的行为。只本地小步提交（A18，`Agent: dev2`），不推送、不合并、不删除别人的原始记录。