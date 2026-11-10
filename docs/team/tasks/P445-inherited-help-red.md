---
id: P445
title: 修复 teamsmith-init 行数与 remind-recover 帮助声明
agent: dev
category: code
phase: apply
change: -
specs: help-surface init-skill
anchor: openspec/specs/help-surface/spec.md
deltas: -
branch: task/P445-inherited-help-red
---

# P445 · 两处继承的测试红（不是提醒回归）

V152 在 merged `c6b3453e` 全量中复现，并在基线 `ead61815` 同样复现：

1. §39 `teamsmith-init/SKILL.md` 为 101 行，判据要求 ≤100；
2. §51 dispatcher 的 `__remind-recover` 未登记进 `help-surface.sh` 声明清单。

## 最小修复

- `skills/teamsmith-init/SKILL.md` 收回到 ≤100 行，只删重复或合并表述，不丢模型、初始化、门禁和交付义务；
- `help-surface.sh` 把真实存在的 `__remind-recover` 纳入正确声明，使声明与实际命令一致；不改 Reminder 行为；
- 两处各保留反向改坏：恢复 101 行/删除声明必须红，不得以删断言或豁免通过。

## 验收

运行 §39、§51 及相关选段、`openspec validate --all`、`spec-refs`、`section-select --check`、账本禁令、diff check。不跑全量/夜间/61b。

报告 `docs/team/reports/P445-dev.md`，附改前改后行数、真实命令/声明对照和红绿证据。提交本地分支并通知 PM，由非作者复验；不合并、不发布。
