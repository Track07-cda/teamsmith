---
id: V160
title: P453 元套件三处修复独立复验
agent: dev3
category: verify
phase: verify
change: -
specs: verification
anchor: none (infra) — 非作者复验既有测试修复
deltas: -
branch: task/V160-meta-red-verify
---

# V160 · 非作者复验 P453

候选 `918d13e6`，作者 dev2。PM 准备 `/var/tmp/p453-review-918d13e6`。你未参与修复。

## 验证

1. 循环清单新增行与真实 `remind-pulse.sh:50` 有界等待一致；删行红、还原绿，0e 两个负对照仍执行。
2. 空生成面真实计数 32 的来源可解释，10 红/0 SKIP 独立语义仍成立；不能只接受改数字。
3. 两个提醒对抗脚本全部临时模板符合 TMPDIR/owned 家族；故障矩阵 12/12，lint 无豁免。
4. 独立运行 `TEAM_META=1 smoke.sh --select 0e,36,40`、P451 §26,66、故障矩阵与静态检查。使用当前 OpenSpec 1.16 普通 `--all`；作者用 1.8 strict 的结果不作为当前发布口径。
5. 报告 `docs/team/reports/V160-dev3.md` 给 PASS/NEEDS-CHANGES、红绿和未跑范围。通过后 PM 合并，再由你在 merged SHA 上复核同一选段。

不重跑完整 61b/全量/夜间，不合并、不发布。
