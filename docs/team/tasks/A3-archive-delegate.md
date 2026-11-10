---
id: A3
title: 归档 delegate-openspec-archive 并更新 verification Purpose
agent: dev2
category: code
phase: archive
change: delegate-openspec-archive
specs: verification
anchor: openspec/changes/delegate-openspec-archive/proposal.md
deltas: -
branch: task/A3-archive-delegate
---

# A3 · 归档委派规则，随后单独提交 Purpose 文档修正

## 前置

A1/A2 已合并，依赖顺序正确。实现 P439、V144 对 merged SHA `fd202853` 的复验通过：选段 ✓328/0，无 CRITICAL/WARNING，tasks 12/12。D240/D241 已授权本归档及 native archive 后的 Purpose-only 文档提交。全量/夜间未跑，严格全量仍有既有20项失败，必须保留此边界。

## 1. Native archive

- `team change status delegate-openspec-archive` 只允许剩 A3 自身 archive 行；其它 blocker 停止。
- 在 `/var/tmp` 私有副本先试 `openspec archive -y delegate-openspec-archive`，检查后只清理该目录。
- 在自己的任务分支真实执行同一命令。保持现有 Purpose 不变，完成归档提交。

## 2. 单独的 Purpose-only 文档提交

native archive 后，**仅**把 `openspec/specs/verification/spec.md` 的 Purpose 改为：

```text
The assigned non-implementer verifier's independent check of an agent's claim: the PM prepares a clean checkout,
the verifier runs the gates and records the actual executor and reviewed revision, and the PM separately accepts
that evidence. A report is only a claim; verification is executed by the verifier, never attributed to the PM merely
because the PM prepared the checkout or accepted the result. See `references/philosophy.md` (principle 1) and
`references/protocol.md`.
```

不改任何 requirement/scenario，不改其它 spec。单独提交并给 before/after diff。

## 3. 验收与交付

```bash
openspec validate --all
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file <主检出名单>
git diff --check
```

报告 `docs/team/reports/A3-dev2.md`：归档文件、Purpose 独立提交、验证与未跑范围。提交本地分支并通知 PM；不合并、不推送。A4 等本结果合并后开始。
