---
id: V156
title: delivery-final-wake-integrity 实现与 merged-SHA 独立复验
agent: dev3
category: verify
phase: opsx-verify
change: delivery-final-wake-integrity
specs: notify-and-inbox background-jobs pm-lifecycle
anchor: openspec/changes/delivery-final-wake-integrity/tasks.md
deltas: -
branch: task/V156-final-wake-verify
---

# V156 · 非作者复验 P449（tasks 4.1/4.2）

冻结候选 `9bd9286d`，作者 dev。你未参与实现。PM 准备 `/var/tmp/p449-review-9bd9286d`。分合并前与合并后两阶段。

## 阶段 A

1. 独立运行 owner-scope/merge/wake/flip，验证独立 clone suspended→最终 delivered 一次唤醒、不同 delivered tip 各一次、同 tip 合并、suspended/interrupted 边界、其他席位与无戳行为。删除发起身份或 tip 边界必须红，恢复后绿。
2. 运行 §13c 与 §12b-pi，核对真实通知 read/intent/sent；sent 不等于 PM 已读。
3. 阅读真实 PM 两场景 session/tools/final：报告已提交时识别交付且不代跑；作业活着时不误报。不要重放真实团队消息。
4. 在干净检出执行：

```bash
TEAM_GATES='openspec validate --all && bash skills/teamsmith/tests/bg-ledger.sh --select owner-scope,merge,wake,flip && bash skills/teamsmith/tests/smoke.sh --select 13c,12b-pi </dev/null' \
  bash skills/teamsmith/scripts/team review P449 --dir /var/tmp/p449-review-9bd9286d
```

5. 给 OpenSpec assessment、CRITICAL/WARNING、是否可合并。报告 `docs/team/reports/V156-dev3.md` 阶段 A，通知 PM。

## 阶段 B

PM 合并并提供 `/var/tmp/p449-review-merged` 与 SHA。你作为同一 verifier 用同一 TEAM_GATES 执行 `team review P444` 的实际目标 **P449**：

```bash
TEAM_GATES='openspec validate --all && bash skills/teamsmith/tests/bg-ledger.sh --select owner-scope,merge,wake,flip && bash skills/teamsmith/tests/smoke.sh --select 13c,12b-pi </dev/null' \
  bash skills/teamsmith/scripts/team review P449 --dir /var/tmp/p449-review-merged --branch <mergedSHA>
```

核对 merged SHA、执行者 dev3、行为未漂移，更新最终报告与 4.1/4.2。通过前 PM 不 set done、不归档。不跑全量/夜间/61b。
