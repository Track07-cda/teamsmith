---
id: V152
title: 自我提醒受控对抗与 merged-SHA 全量验证
agent: dev3
category: verify
phase: opsx-verify
change: agent-self-reminder
specs: agent-self-reminder verification watchdog
anchor: openspec/changes/agent-self-reminder/tasks.md
deltas: -
branch: task/V152-remind-adversarial-verify
---

# V152 · 非作者最终受控验收（5.1–5.3、5.5）

冻结候选 `a5d07303`，作者 dev2。你未参与实现。PM 准备 `/var/tmp/p444-review-a5d07303`。分两个阶段，5.4 真实自主性不在本任务内。

## 阶段 A：合并前

1. 独立运行 `remind-adversarial-faults.sh`、`remind-adversarial-real.sh`、`remind-delivery.sh`、`remind-lifecycle.sh` 和 §69；检查 12 个真实死亡点、A+B/G1G2/busy/foreign/member replay、进程和状态恢复。
2. 在自己的副本验证：批次/nonce 相同但成员不同必须 `member-mismatch`，不花权利、不清 Standby；删除成员校验必须红，恢复后绿。
3. 运行 `TEAM_GATES='openspec validate --all && bash skills/teamsmith/tests/smoke.sh --select 69 </dev/null' bash skills/teamsmith/scripts/team review P444 --dir /var/tmp/p444-review-a5d07303`，记录实际执行者与候选 SHA。
4. 阅读 P444 报告、change 与 diff，给 OpenSpec assessment、AC 映射、CRITICAL/WARNING、是否可合并。真实自主性和最终全量仍标未做。

提交 `docs/team/reports/V152-dev3.md` 阶段 A，通知 PM，不自行合并。

## 阶段 B：PM 合并后

PM 提供 `/var/tmp/p444-review-merged` 与 merged SHA。你作为同一 verifier：

1. 用 merged SHA 的干净检出执行最终独立全量：

```bash
TEAM_GATES='openspec validate --all && bash skills/teamsmith/tests/smoke.sh --snapshot </dev/null' \
  bash skills/teamsmith/scripts/team review P444 --dir /var/tmp/p444-review-merged --branch <mergedSHA>
```

2. 完整日志保留。若关键回复既有 reload 红或其它既有红复现，单独归因并给基线反证，不能删检查、放宽等待或称全绿。候选引入的问题必须 NEEDS-CHANGES。
3. 更新最终 OpenSpec assessment、5.5 是否完成、是否可进入真实自主性后续/归档。5.4 未授权仍不勾。

不跑夜间 meta/61b，不操作真实团队，不做真实模型自主创建，不归档、不发布。
