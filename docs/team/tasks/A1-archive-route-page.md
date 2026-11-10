---
id: A1
title: 归档 route-page-check-determinism
agent: dev2
category: code
phase: archive
change: route-page-check-determinism
specs: dispatch verification
anchor: openspec/changes/route-page-check-determinism/proposal.md
deltas: -
branch: task/A1-archive-route-page
---

# A1 · 在自有工作树归档帮助页变更

## 决策与前置

用户已授权 PM 按验证流程决定归档（D241），实际归档由你执行，PM 不亲自运行。

已核：实现 P430、独立复验 V132、最终 openspec-verify V136；merged-revision 证据成立，tasks 8/8，无 CRITICAL。V136 的 WARNING 由 PM 决定接受并记录：未按字面跑改前/改后 FAST，但真实走查255行清单一致且受影响文件相同；其它段通过数没有本轮实测，不声称全覆盖。父级计数 −2 来自三项旧检查合并。

## 执行

1. 阅读 change、V136 报告、实现与 merged 证据。`team change status route-page-check-determinism` 允许只剩本任务 `A1 · archive` 自身行；任何其它 blocker 必须停止并报告。
2. 在 `/var/tmp` 创建本次私有副本，先运行 `openspec archive -y route-page-check-determinism` 试归档并检查结果；只清理该确切目录，不碰真树。
3. 确认试归档后，在**自己的任务分支**运行同一命令真实归档。不要手改 delta、正式规格或 Purpose。
4. 检查归档目录、正式规格同步和任务清单；运行：

```bash
openspec validate --all
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file <主检出名单>
git diff --check
```

5. 写 `docs/team/reports/A1-dev2.md`：先给结果，列出实际改变文件、WARNING 处置、试归档与真实归档证据、未跑范围。提交本地分支并通知 PM；不合并、不推送。

## 边界

只做这个 change 的归档，不做 reply-observer、delegate 或 panel 的归档；后序任务必须等本结果合并后再开始。
