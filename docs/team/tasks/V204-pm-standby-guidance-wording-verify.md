---
id: V204
title: 独立核对实施后的待命指令与巡检文案
agent: verify
deps: P508,V201
category: verify
phase: verify
change: clarify-pm-standby-guidance
specs: init-skill
deltas: -
branch: task/V204-pm-standby-guidance-wording-verify
---

# V204 · 只核实现的文字、范围与授权边界

排在 V202 完成验收与合并后核对之后。作者 dev-bob。冻结交付 `efe923d16c9e59c052a6590888b4e3d7e7cea429`，只读 `/var/tmp/p510-review-efe923d1.WXoGCS`，产品候选 `ddc39ac8f23b7b132437df27246a0a87e15a959c` 与交付提交只多作者报告，实际基线 `a3f80d3fdca3400d4cfdc0a187c23e3ae9ffab89`。读 AGENTS、本人线程、归属、D270、P510 及已接受方案。只做 `openspec/changes/clarify-pm-standby-guidance/tasks.md` 2.2（合并后再单独核 2.3）。报告 `docs/team/reports/V204-verify.md`，冻结源、原任务及勾选均不动。

- 从冻结检出逐处比受审设计的九处指令及一行巡检消息；对照实际文字核无工作但仍有自动结果、只等人、由人决定的项目、可自行进入但不能自行关闭、人工维护与匹配的定时提醒例外。核唯一默认规则在生成 AGENTS，保留三种回合结尾、后台结果和升级授权；看已有文字检查仍能匹配，不跑它们。现有项目要明确采用、不因重启 Pulse 生效；不写当前已生成文件或当前状态。
- 比对 `common.sh` 原文与候选整文件：唯一变化应为 `team_nudge` 这一行删去查看详情之后的尾句，无新文字。检查前缀、摘要、语言与其它代码逐字节不变，并列出唯一许可写集的实际 Git 输出。用 `git diff --check` 和只读前后比对给可核实证据。复用作者已有单变更严格校验与语法回执，不重跑全仓或另起任何测试。
- 结论写实际命令、退出码、未运行范围和可证据定位的最小问题/通过。仅本地小提交 V204 / `Agent: verify`。不运行模型、会话读取、生成模板、真实会话或 Pulse，不启停待命、不改/推/合并候选或恢复 V196。通过后仍同一人按 PM 的合并提交，对比已验收文本字节并复核一次范围，不运行产品。