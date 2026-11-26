---
id: A21
title: 同步项目设置管理任务标签的正式说明
agent: dev2
deps: P511,V206,A20
category: docs
phase: archive
change: project-label-management
specs: board-and-status, panel
deltas: -
branch: task/A21-archive-project-label-management
---

# A21 · 同步项目设置中的任务标签说明

先读 AGENTS、个人线程、本书、归属、归档说明及现有 OpenSpec 变更。作者 dev-bob；独立 V206 在 `3fd44aac` 实测 49/0、`5a0f6bde` 定点布局通过、合并 `80bcf2eb` 284 个技能文件一致且实际打开与返回通过；`7d8914d7` 为最终报告。按 D241，PM 只确认用 Git 可撤回、已审阅且经候选和合并核对的文档同步。清单 8/8；先确认 `team change status project-label-management` 只剩 A21 自己。未实跑的未确认回复、读取失败和看板新旧请求相遇仍只源码核对；作者全仓 strict 5/17 的旧失败不改判。

用 `/var/tmp` 中本人唯一私有副本先试 `openspec archive -y project-label-management`。预期六份规划文件原样移入唯一原生日目录；`board-and-status` 新增命令写入结果一条，原 A20 标签定义及场景必须逐字不变；`panel` 新增一个条款并更新三个同名条款。用原规格和受审变更逐项核，保留未点名条款、场景、Purpose、顺序。原生额外空行若有，列出准确位置/字节且只空行才可保留，超出即停止。私有试做符合后，在自己的任务分支执行一次同一个原生命令，核试做与正式 `openspec/` 树同一。不要手工改程序、手搬目录或掩盖未验证项。

只跑 `openspec validate --all`、`bash skills/teamsmith/tests/spec-refs.sh --check`、Git 差异及项目账本隐私检查。记录命令、退出、实测范围和未执行项，不跑全仓 strict、产品、构建或当前 Pulse。只另写 `docs/team/reports/A21-dev2.md`，小步本地提交（A21、`Agent: dev2`），不推送或发布。原始文件待 PM 收取，不提前删本人私有根。
