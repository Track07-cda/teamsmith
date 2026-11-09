---
id: P435
title: delegate-openspec-archive 默认流程提案
agent: dev2
category: analysis
phase: opsx-propose
change: delegate-openspec-archive
specs: verification
anchor: openspec/specs/verification/spec.md
deltas: verification
branch: task/P435-delegate-archive-proposal
---

# P435 · 把 verify/archive 委派写成 teamsmith 默认规则

## 用户裁定

“verify 和 archive 不要 PM 亲自做”，且这是 **teamsmith 产品默认规则**，不是 pm-skills 项目特例。

现状：teamsmith 已要求非作者 verify；但 AGENTS/SKILL/workflows/openspec 参考仍写 PM 执行 archive。需要提出最小修正，不保留两套互相矛盾的口径。

## 提案要覆盖

1. `opsx-verify` 由非实现者执行；归档前完成 openspec-verify，CRITICAL 清零，WARNING 与未验证项如实记录。
2. `opsx-archive` 由独立 archive 席位在**自己的工作树和任务分支**执行；席位不得直接写主检出或推 main。
3. PM 保留审阅、独立核对、合并与用户沟通职责，但不亲自运行 verify/archive。用户归档确认仍是前置条件。
4. 两个有依赖的 change 串行 archive：前一个归档结果合并后，后一个才基于新 main 执行，避免完整 MODIFIED 块互相覆盖。
5. 最小更新面：`templates/AGENTS.section.md.tmpl`、`templates/pm-prompt.md.tmpl`、`templates/PROTOCOL.md.tmpl`、`templates/OWNERSHIP.md.tmpl`、`SKILL.md`、`references/workflows.md`、`references/openspec.md`，以及实际引用这些职责的测试。不得新增另一套流程或状态机。
6. `verification` delta 明确角色、前置证据、工作树边界和串行依赖；给出至少一条反例：把模板改回 PM archive 或允许未验证归档必须红。

## 交付与边界

只写 `openspec/changes/delegate-openspec-archive/` 的 proposal/design/tasks/delta 和 `docs/team/reports/P435-dev2.md`，不实施模板或测试修改。运行结构校验，通知 PM；之后非作者审阅，接受前不 Apply。

不阻碍当前已按用户指示派出的 V136 验证；当前两个变更的 archive 也将另派席位执行。
