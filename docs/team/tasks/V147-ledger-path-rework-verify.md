---
id: V147
title: 账本路径生成两项返修定点复核
agent: dev3
category: verify
phase: verify
change: -
specs: verification
anchor: openspec/specs/verification/spec.md
deltas: -
branch: task/V147-ledger-path-rework-verify
---

# V147 · V146 原审阅者定点复核

冻结返修候选 `ff83ee5f`；上一候选 `2dfaa44e`。你是 V146 原审阅者，只核 W1/W2，不重开其它已通过的 init 形状和生成行为。

## 必做

1. 用真实 `team review` 验证 main-root 的兄弟前缀路径（例如 `pm-skills-ledger`）逐字保留，不被改成不存在的占位拼接；root 本身与 root/子路径仍正确净化。
2. 验证 HOME 下 checkout 的显示形态为 `<home>/…`，原始终端/执行仍用真实路径，绿侧不再依赖 `/var/tmp`。
3. 红侧必须先证明变异体真实 review `rc=0`、记录存在且判定 PASS，再只因绝对 main/home 路径判红；记录缺失或其它断言失败不得冒充翻转证据。
4. 独立运行 `smoke.sh --select 10,10b`，保留完整日志；检查其它原已通过断言没有因新边界规则丢失。可补结构检查，不重跑 init 三种形状或全量。
5. 明确最终 PASS / NEEDS-CHANGES；若仍拒绝，给返修后仍成立的具体反例。

## 交付

`docs/team/reports/V147-dev3.md`，附自己的命令、真实记录和日志路径。只提交报告，不改实现，不合并、不发布；不跑全量/夜间/61b。
