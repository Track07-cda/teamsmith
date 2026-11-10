---
id: A2
title: 归档 reply-observer-skip-focus
agent: dev2
category: code
phase: archive
change: reply-observer-skip-focus
specs: key-replies verification
anchor: openspec/changes/reply-observer-skip-focus/proposal.md
deltas: -
branch: task/A2-archive-reply-observer
---

# A2 · 在 A1 合并后的基线上归档缺观测器变更

## 前置与决策

A1 已合并。用户通过 D241 授权 PM 决定归档；本任务由你执行，PM 不亲自运行。

实现 P434、独立复验 V135、最终 openspec-verify V137 已完成；tasks 9/9，无 CRITICAL。PM 接受两条 WARNING：原始完整 §62 日志已清理，现有证据为复验报告、PM 验收、实现 blob 同一性与最终短入口/反例；CI strict 旧描述与实际非 strict 是既有文档漂移，另留修正，不在本归档偷改。

## 执行

1. 阅读 change、V137 报告和 merged 证据。`team change status reply-observer-skip-focus` 只允许剩 `A2 · archive` 自身；其它 blocker 停止。
2. 在 `/var/tmp` 的本次私有副本先运行 `openspec archive -y reply-observer-skip-focus` 并检查结果；只清理该目录。
3. 在自己的任务分支真实执行同一命令。不得手改 delta、正式规格或 Purpose。
4. 验证归档目录、正式规格与 tasks 9/9，运行：

```bash
openspec validate --all
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file <主检出名单>
git diff --check
```

5. 写 `docs/team/reports/A2-dev2.md`：结果、实际改变文件、WARNING 处置、试归档与真实归档证据、未跑范围。提交并通知 PM；不合并、不推送。

## 边界

只归档此 change；A3 必须等本结果合并后再开始。
