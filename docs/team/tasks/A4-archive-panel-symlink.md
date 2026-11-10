---
id: A4
title: 归档 panel-symlink-inside-project
agent: dev2
category: code
phase: archive
change: panel-symlink-inside-project
specs: panel
anchor: openspec/changes/panel-symlink-inside-project/proposal.md
deltas: -
branch: task/A4-archive-panel-symlink
---

# A4 · 归档软链详情变更

## 前置

A1/A2/A3 已合并。实现 P424 已在 merged SHA `d5a65d53` 由 V145 最终 openspec-verify：选段 ✓426/0、CRITICAL 0、WARNING 0、tasks 6/6。D241 授权 PM 决定归档。

一条非阻塞 SUGGESTION 已记 OPEN-ITEMS：发现后被并发替换为非普通文件时可能返回空正文而不点名类型，后续单独修，不在归档中改产品。

## 执行

1. 阅读 change、V145 报告与 merged 证据。`team change status panel-symlink-inside-project` 只允许剩 A4 自身 archive 行；其它 blocker 停止。
2. 在 `/var/tmp` 私有副本先运行 `openspec archive -y panel-symlink-inside-project` 并检查；只清理该目录。
3. 在自己的任务分支真实执行同一命令，不手改 delta、正式规格或 Purpose。
4. 检查归档目录、正式规格和 tasks 6/6，运行：

```bash
openspec validate --all
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file <主检出名单>
git diff --check
```

5. 写 `docs/team/reports/A4-dev2.md`：结果、实际文件、验证、SUGGESTION 处置和未跑范围。提交并通知 PM；不合并、不推送。

## 边界

只归档此 change，不做其它归档或产品修复。
