---
id: A17
title: 同步已验证的新项目初始化要求并收尾
agent: dev2
deps: P500,V198
category: docs
phase: opsx-archive
change: quick-init-model-defaults
specs: init-skill
deltas: -
branch: task/A17-archive-quick-init-model-defaults
---

# A17 · 只同步这次已验收的初始化要求

作者 dev-bob；V198 非作者 dev3 的 `646acbe7` 接受合并产品 `ef2e832c5eb746d0044ec553372df50c7d8b168b`：候选 100/0、短反例成功、合并 19 个文件一致且实际预览无写入。PM 依据 D241 的窄确认已在 D268 落盘，5/5；本单仅同步正式规格，不等其他变更，不发布。读 AGENTS、本人线程、任务书与 OWNERSHIP，再按原生 archive 流程用 `$HOME/.bun/bin` 上的 OpenSpec 1.16 核对根、规划和 5/5。

只在本人任务分支实际运行一次 `openspec archive -y quick-init-model-defaults`。不使用手工同步、目录移动、硬链接或跳过参数。唯一允许产品文档改动是五份已批准规划文件逐字移入此次归档目录（`tasks.md` 已 5/5）及正式 `openspec/specs/init-skill/spec.md` 中 delta 点名的四个要求替换；其它要求、场景次序、非模型确认、迁移和发布授权保持。以 Git 对象对照同一分支入档前、已接受 delta 和入档后；如原生工具改变边缘空行，准确列出位置、字符和字节差异，不改写以凑结果；出现其它内容差异或工具拒绝就保持现场并报阻塞。不改变任何可执行文件、模板、运行状态或其他 change。

执行普通 `openspec validate --all`、`bash skills/teamsmith/tests/spec-refs.sh --check`、账本隐私检查与 `git diff --check` / `git diff --cached --check`。记录实际工具版本、命令输出与退出值，不把旧长规格导致的 strict 警告当新失败或已通过；不为收尾重跑行为、首轮 100 项、模型、发布、安装或全量测试。唯一另写本人 `docs/team/reports/A17-dev2.md`，本地小步提交（A17，`Agent: dev2`），不推送、不合并。原件保留至 PM 接收，不碰他人临时根。