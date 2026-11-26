---
id: P504
title: 核对 PM 待命指令冲突及最小修订范围
agent: dev-bob
category: analysis
phase: opsx-explore
change: clarify-pm-standby-guidance
specs: init-skill
deltas: -
branch: task/P504-pm-standby-guidance-explore
---

# P504 · PM 待命指令只说一种意思

用户已要求修复现有指导的矛盾。已确认 v0.4.8 及当前模板的 `AGENTS.section.md.tmpl` 和 `pm-prompt.md.tmpl` 开头把整个 `standby on|off` 交给人，PM 开场后段又要求 PM 无事可推进或等人时执行 `standby on`。直接从这一发现开始，别重新分析模型、排查他项目或启动真人/模型会话。

在现有产品文档及引用间核对最小写集和 OpenSpec 应修改的已有要求，交英文可直接采用的精简措辞。方向：尊重项目自己的授权；允许 PM 自行进入待命时，确认没有能推进的事、没有在等运行中任务/验证/后台自动回来的结果，才主动进待命并说明原因；不要把空看板等同待命。项目规定由人决定则按其规定；不授权 PM 自行解除待命，不改已经存在的明确人工解除和实际定时提醒例外。普通待命仍是抑制 Pulse 唤醒，不改变提醒实现、开关、默认状态或会话。不新增配置、逻辑、模型行为测试或「是否读到了」的测试；沿用原发布前文字审阅约束。请指出哪些入口应只引用共同规则，不再给另一套解释；核一眼现有逐字文案断言是否会受影响，保留可保留的原句结构，不加新检查。

本阶段只改 `docs/team/reports/P504-dev-bob.md`，附准确文件/行、冲突原文、名单、建议文字及已有项目指引如何生效（不会自动改本项目、`spider_api` 或现有会话）。只做 Git 差异检查及报告账本检查，小步本地提交，不实现、不运行工具写指令、不合并、不推送。