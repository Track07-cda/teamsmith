---
id: A5
title: 归档 delivery-final-wake-integrity
agent: dev3
category: code
phase: archive
change: delivery-final-wake-integrity
specs: notify-and-inbox background-jobs pm-lifecycle
anchor: openspec/changes/delivery-final-wake-integrity/proposal.md
deltas: -
branch: task/A5-archive-final-wake
---

# A5 · 归档最终交付唤醒变更

## 前置

P449 已合并为 `3dd18692`，V156 对 merged SHA 复验通过：openspec 21/0、bg-ledger 215/0、smoke 765/0，tasks 4.1/4.2 已勾选。D241 授权 PM 决定归档，实际归档由你执行。

严格全量的既有长需求/Purpose 失败继续归 P408，不声称 strict 通过；全量/夜间/61b 未跑。

## 执行

1. `team change status delivery-final-wake-integrity` 只允许剩 A5 自身 archive 行；其它 blocker 停止。
2. 在 `/var/tmp` 私有副本先运行 `openspec archive -y delivery-final-wake-integrity` 并检查；只清理该目录。
3. 在自己的任务分支真实执行同一命令，不手改 delta、正式规格或 Purpose。
4. 检查归档目录、正式规格和 tasks，运行：

```bash
openspec validate --all
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file <主检出名单>
git diff --check
```

5. 写 `docs/team/reports/A5-dev3.md`：结果、实际改变文件、验证、strict 边界和未跑范围。提交并通知 PM；不合并、不推送。
