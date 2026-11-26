---
id: P510
title: 统一默认 PM 待命指令并删掉巡检的相反提示
agent: dev-bob
deps: P508,V201
category: code
phase: apply
change: clarify-pm-standby-guidance
specs: init-skill
deltas: -
branch: task/P510-pm-standby-guidance-apply
---

# P510 · 只实施独立审阅接受的待命文字

方案固定 `defb5f1b8472`、审阅 `a95ac8bea0e7`，`docs/team/reviews/clarify-pm-standby-guidance-proposal.md` 已接受。读 AGENTS、本人线程、D270、归属和 change 工件；按 `/opsx-apply clarify-pm-standby-guidance` 的现有选取/检查方式，不在主检出写入。所有规则和准许的落点以已接受的 `design.md` 和 `tasks.md` 为准，不另补需求。现有项目显式采用不在本单范围。

只写设计中九个文字文件、`skills/teamsmith/scripts/lib/common.sh` 里 `team_nudge` 的那一行消息、`openspec/changes/clarify-pm-standby-guidance/tasks.md` 中作者真正已做的条目，以及本人报告。完整待命条件只放共用 AGENTS 模板；其余只保留原指引或引用。普通巡检保留前缀、摘要、原语言和 `digest 看详情`，删掉后缀，不动其它消息、逻辑、发送、计数、队列、唤醒、恢复或既有提醒。升级、既有授权、后台与项目规则不变；不编辑测试、正式规格、运行文件或对当前项目生效的指令。

作者短检查：`PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0 openspec validate clarify-pm-standby-guidance --type change --strict --no-interactive`、`bash skills/teamsmith/tests/spec-refs.sh --check`、`bash -n skills/teamsmith/scripts/lib/common.sh`、相对实际 apply 基线的 `git diff --check` 和精确写集核对。报告 `docs/team/reports/P510-dev-bob.md` 写实际命令、结果、基线、候选及未运行范围。第 2.2 / 2.3 留给非作者；不用模拟模型、会话读取测试、真实会话、模板生成、升级、Pulse、待命切换、全套测试。改动分步、仅本地提交（P510 / `Agent: dev-bob`）；不推送、不合并或发布。