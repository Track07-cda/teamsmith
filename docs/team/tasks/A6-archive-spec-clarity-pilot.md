---
id: A6
title: 归档 spec-clarity-burn-down 三份试点
agent: dev3
category: code
phase: archive
change: spec-clarity-burn-down
specs: writing-discipline extension-slash help-surface
anchor: openspec/changes/spec-clarity-burn-down/proposal.md
deltas: -
branch: task/A6-archive-spec-clarity-pilot
---

# A6 · 归档三份小规格长需求改写

## 前置

P408 已合并为 `28d21bdc`，V157 merged-SHA 复验通过。43/43 原场景逐字保留，三份试归档 strict 均 0 warning，全局长需求 239→224。D241 授权 PM 决定归档，实际归档由你执行。

全局 strict 仍有其它 224 条长需求与既有 Purpose，不声称全仓 strict 通过；全量/夜间/61b 未跑。

## 执行

1. `team change status spec-clarity-burn-down` 只允许剩 A6 自身 archive 行。
2. 在 `/var/tmp` 私有副本运行 `openspec archive -y spec-clarity-burn-down` 并检查；只清理该目录。
3. 在自己的任务分支真实执行同一命令，不手改 delta 或正式规格。
4. 三份 canonical spec 各自 `openspec validate <id> --strict` 必须 rc=0、0 warning；普通全仓校验、引用、选段、账本禁令、diff check 通过。
5. 写 `docs/team/reports/A6-dev3.md`，附归档变化、三份 strict、计数和未跑范围。提交并通知 PM；不合并、不推送。
