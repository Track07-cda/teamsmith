---
id: V137
title: reply-observer-skip-focus 归档前 openspec-verify
agent: dev3
category: verify
phase: opsx-verify
change: reply-observer-skip-focus
specs: key-replies verification
anchor: openspec/changes/reply-observer-skip-focus/proposal.md
deltas: -
branch: task/V137-reply-observer-final-verify
---

# V137 · 按 openspec-verify-change 规则做最终验证

用户明确要求 verify/archive 由席位执行，PM 不亲自做。你只负责本 change 的验证，不归档。

## 输入与既有证据

- change：`openspec/changes/reply-observer-skip-focus/`；
- 实现验收：`docs/team/reviews/P434.md`；
- 独立行为复验：`docs/team/reports/V135-dev3.md`；
- 只读状态：schema `spec-driven`，四种 artifacts 均 done，任务 9/9，delta specs 为 key-replies 与 verification。

## 必做

1. 按 `.pi/skills/openspec-verify-change/SKILL.md` 执行：status、apply instructions、list、所有相关 artifacts；不得把 apply state 当验证结论。
2. 从 Completeness / Correctness / Coherence 检查任务、ADDED/MODIFIED requirements、每个 scenario 的实现与测试、design adherence 和代码模式。
3. 复用 V135 的真实行为证据，但核对它与最终 main 上的实现和 tasks 9/9 一致；需要补查时只跑短命令，不重跑全量/完整 §62/61b。
4. 报告包含 scorecard、CRITICAL/WARNING/SUGGESTION、具体文件行号和最终评估。CRITICAL 必须先修；WARNING 明确记录；适用检查未验证不得声称 ready。
5. 明确写出“是否无 CRITICAL、是否可进入 archive”。不要归档或同步规格。

## 交付

`docs/team/reports/V137-dev3.md`，只提交报告，不改实现、规划、任务或 specs。通知 PM。后续由另一席位执行 archive。
