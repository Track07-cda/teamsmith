---
id: A7
title: 归档 agent-self-reminder
agent: dev3
category: code
phase: archive
change: agent-self-reminder
specs: agent-self-reminder delivery-guard memory-and-deps notify-and-inbox pm-lifecycle verification watchdog
anchor: openspec/changes/agent-self-reminder/proposal.md
deltas: -
branch: task/A7-archive-agent-self-reminder
---

# A7 · 归档自我提醒完整变更

## 前置

- 最终 main `46482461`，P450/P451/V158 已关闭，tasks 未勾项为 0。
- V152：冻结快照 140 段 5131/0；V158：真实 `kimi-coding/k3.1-pro:max` 在默认 `team init` 配置下自主创建、两次醒后续排、停止后自取消且不再续建；P450/P451 merged-SHA 均通过。
- D241 授权 PM 决定归档，实际归档由你执行。
- 全仓 strict 仍有范围外长需求/Purpose，继续归后续 burn-down；V158 驱动有 Pulse 启动等待文字与 run.log 自哈希两条非产品 WARNING，必须在归档记录披露，不能写成驱动整体全绿。

## 执行

1. `team change status agent-self-reminder` 只允许剩 A7 自身 archive 行；其它 blocker 停止。
2. 在 `/var/tmp` 私有副本运行 `openspec archive -y agent-self-reminder` 并检查；只清理该目录。
3. 在自己的任务分支真实执行同一命令，不手改 delta 或正式规格。
4. 检查归档目录、tasks 全勾、正式规格；运行：

```bash
openspec validate --all
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file <主检出名单>
git diff --check
```

5. 写 `docs/team/reports/A7-dev3.md`：归档结果、实际改变文件、最终验证依据、两条 WARNING、strict 和未重跑范围。提交并通知 PM；不合并、不推送。
