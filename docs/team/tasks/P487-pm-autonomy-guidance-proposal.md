---
id: P487
title: 默认团队规则明确 PM 在授权范围内自行推进
agent: dev2
category: analysis
phase: opsx-propose
change: pm-autonomy-guidance
specs: init-skill
deltas: init-skill
branch: task/P487-pm-autonomy-guidance-proposal
---

# P487 · 将已讨论的短方案写入 OpenSpec

2026-11-23 用户要求解决 PM 把小执行问题都交给用户、先看方案，后来授权发布一个新版。规则适用所有 PM 模型，不是 GPT 专属开关。不要重新做探索。用 OpenSpec 1.16 原生 scaffold；规划限 `openspec/changes/pm-autonomy-guidance/` 和本报告，按现有 `init-skill` 指令组织要求作小 delta。

提案边界：默认 `skills/teamsmith/templates/AGENTS.section.md.tmpl` 在角色说明后给一条简短的授权内推进原则。已经明确目标与范围时，PM 自行查证、拆分、派工、处理小的可逆选择和返修、安排独立复核及收尾；已授权不反复问。遇到必须由用户作出的决定先推进不受影响部分，再给建议和具体影响。只提案不实施；新增产品取舍、超范围及未授权生产操作、合并、推送、发布不自行做。PM 启动提示的“四项逐项授权”明确只说工具源升级，保留授权本身，短指向默认规则。每日技能两处与该规则对齐，保留必须当面表述的授权边界，不另建规则副本。不改任何生成/加载、模型、权限、验收执行、现有项目或发布行为。新项目按现有入口生成；已有项目沿用显式刷新并保留原局部规则，不能写成自动升级或无其他写入。

用户明确不做模拟对话，不另起会话测试是否读到，不新增测试、不跑任何行为或产品套件。方案和最终差异均由非作者只做文字及权限边界复核；不要承诺提示词效果，实际效果留给用户在其他项目使用时判断。只做本 change 结构校验与 `git diff --check`，报告 `docs/team/reports/P487-dev2.md`，小步本地提交，不推送、不实现、不发版。此任务完结后独立审阅到位才另派实施。