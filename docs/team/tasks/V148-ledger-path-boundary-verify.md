---
id: V148
title: 账本路径边界简化定点复核
agent: dev3
category: verify
phase: verify
change: -
specs: verification
anchor: openspec/specs/verification/spec.md
deltas: -
branch: task/V148-ledger-path-boundary-verify
---

# V148 · 只复核 V147 的剩余反例

冻结候选 `823f3f4a`，作者 dev；你是 V147 原审阅者。此前已关闭的兄弟前缀、红侧前提和 init 形状不重开。

## 必做

1. `LC_ALL=C` 与正常 UTF-8 locale 下，中文冒号后的 root/HOME 都净化；`；！？、「」` 等标点两侧都正确；root/子路径、兄弟前缀仍各按预期。
2. `TMPDIR` 在 HOME 下运行相关真实 review 和 `smoke.sh --select 10`，门禁命令、兄弟 checkout 的期望不再写死原绝对路径。
3. 默认环境跑 `smoke.sh --select 10,10b`，保留完整日志；此前红侧前提仍成立，记录缺失/其它失败不能冒充翻转。
4. 明确 PASS / NEEDS-CHANGES；若仍拒绝，必须给这次实现仍成立的反例，不重开无关面。

交付 `docs/team/reports/V148-dev3.md`，只提交报告，不改实现、不合并、不发布；不跑全量/夜间/61b。
