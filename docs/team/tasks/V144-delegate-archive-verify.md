---
id: V144
title: delegate-openspec-archive 实现及合并后独立验证
agent: dev2
category: verify
phase: opsx-verify
change: delegate-openspec-archive
specs: verification
anchor: openspec/changes/delegate-openspec-archive/tasks.md
deltas: -
branch: task/V144-delegate-archive-verify
---

# V144 · 同一 verifier 的合并前/合并后验证（tasks 3.1–3.3）

你未参与实现。候选 `ebfc8bd6`，作者 dev3。PM 已准备独立 checkout `/var/tmp/p439-review-ebfc8bd6`。本任务第一次按新规则使用真实 `team review` 执行者记录。

## 阶段 A：合并前

1. 阅读 change 全部规划、P439 报告、实际 diff 和十二文件映射。完成 openspec-verify 的 Completeness/Correctness/Coherence、CRITICAL/WARNING/SUGGESTION/Final assessment；不得把 shell PASS 当成完整 OpenSpec 评估。
2. 从你的 V144 工作树使用候选工具执行（只允许工具写主检出的 `docs/team/reviews/P439.md` 与 `P439-verify.log` 及既有运行簿记）：

```bash
TEAM_GATES='openspec validate --all && bash skills/teamsmith/tests/smoke.sh --select 10,10b,19,12j </dev/null' \
  bash skills/teamsmith/scripts/team review P439 --dir /var/tmp/p439-review-ebfc8bd6
```

- 记录必须写实际执行者 dev2、候选 SHA、真实命令与结果，不得写 PM 执行。
- 核对 10/10b/19/12j 的真实 verifier、写集、红/绿/还原、归档前置和自身 phase；既有 strict 全量20失败要披露，不能说全绿。
- 检查十二文件54命中没有相反默认口径，`cmd-review.sh` 身份来自运行时目录，report 模板固定严重级，Purpose 未改。
- 独立检查至少一条反向改坏：恢复 PM 执行者署名或允许缺合并后验证必须红；可由选段已有变异证据加你自己的副本复核。

3. 写 `docs/team/reports/V144-dev2.md`，先给 **PASS / NEEDS-CHANGES**，明确无 CRITICAL 与否、WARNING、未验证项和“可/不可合并”。只提交报告，不改实现或规划。通知 PM 后结束本阶段，**不要自行合并或归档**。

## 阶段 B：PM 合并后

PM 会告知合并 SHA 并准备 `/var/tmp/p439-review-merged`。你作为**同一 verifier**续跑：

```bash
TEAM_GATES='openspec validate --all && bash skills/teamsmith/tests/smoke.sh --select 10,10b,19,12j </dev/null' \
  bash skills/teamsmith/scripts/team review P439 --dir /var/tmp/p439-review-merged --branch <合并SHA>
```

- 确认记录绑定合并 SHA、实际执行者仍为 dev2；比较合并差异未改变候选行为。
- 在同一报告追加 merged-SHA 结果和最终 OpenSpec readiness，通知 PM。通过前 PM 不 set done、不进入 archive。

## 边界

不跑全量/夜间/61b，不做真实归档，不改 Purpose，不推 main。当前 change 自身归档仍需后续用户确认和独立 archive 席位。
