---
id: V136
title: route-page-check-determinism 归档前 openspec-verify
agent: dev3
category: verify
phase: opsx-verify
change: route-page-check-determinism
specs: dispatch verification
anchor: openspec/changes/route-page-check-determinism/proposal.md
deltas: -
branch: task/V136-route-page-final-verify
---

# V136 · 按 openspec-verify-change 规则做最终验证

用户明确要求 verify/archive 由席位执行，PM 不亲自做。你只负责本 change 的验证，不归档。

## 输入与既有证据

- change：`openspec/changes/route-page-check-determinism/`；
- 实现验收：`docs/team/reviews/P430.md`；
- 独立行为复验：`docs/team/reports/V132-dev3.md`；
- PM 只读状态：schema `spec-driven`，四种 artifacts 均 done，任务 8/8，delta specs 为 dispatch 与 verification。

## 必做

1. 按 `.pi/skills/openspec-verify-change/SKILL.md` 执行：读取 status、apply instructions、list 与所有相关 artifacts；不得把 apply state 当验证结论。
2. 从 **Completeness / Correctness / Coherence** 三维检查：任务完成、ADDED/MODIFIED requirements、每个 scenario 的实现与测试证据、design adherence、代码模式。
3. 复用 V132 的真实行为证据，但核对它与最终 main 上的实现和 tasks 8/8 一致；需要补查时只跑短命令，不重跑全量/51m/61b。
4. 报告必须包含 scorecard、CRITICAL/WARNING/SUGGESTION 分组、具体文件行号和最终评估。CRITICAL 必须先修才能归档；WARNING 明确记录；任何适用检查未验证都不得声称 ready。
5. 明确写出“是否无 CRITICAL、是否可进入 archive”。不要在验证任务里归档或同步规格。

## 交付

`docs/team/reports/V136-dev3.md`，只提交报告，不改实现、规划、任务或 specs。通知 PM。后续由另一席位执行 archive。
