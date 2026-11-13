---
id: P453
title: 修复元套件循环清单、空生成面计数与临时目录红
agent: dev2
category: code
phase: opsx-apply
change: -
specs: verification
anchor: none (infra) — 既有二阶段测试的清单、预期与临时目录纪律修复
deltas: -
branch: task/P453-meta-red-attribution
---

# P453 · 0.4.7 元套件三处红归因与修复

冻结元套件 `54b39af2`，日志 `/var/tmp/rel47-meta-suite.log` 与 `.pi/team/state/meta-suite/2026-11-13T03-25-59Z.log`。61b 与 51m 等通过；以下三处共五条红。

## 逐项

1. **0e 循环清单**：85 行清单 / 86 个 while+sleep，循环及两个还原对照红。找出新增循环，按现有格式登记真实用途与属主；不得删循环或放宽配平，负对照仍须红。
2. **36⑧ 空生成面**：探针期望 `⑤d 空生成面的 §19 账本计数 = ✓20 ✗10 SKIP0（不是 SKIP10）` 但找不到。先取得当前真实输出并核对 §19 的既有语义与 P451 新增断言，确认是预期滞后还是行为回归；不得只改数字凑绿。
3. **40 临时根 lint**：`tests/remind-adversarial-faults.sh:10` 的 `mktemp -p` 使用相对/非临时根模板。按既有 TMPDIR/owned 家族规则修正，保留隔离与故障场景，不用豁免 lint。

## 验收

- `TEAM_META=1 bash skills/teamsmith/tests/smoke.sh --select 0e,36,40 </dev/null`；各项改前红、改后绿，至少一条反向改坏恢复。
- P451 的权威/paths/doctor 行为不后退；61b 已通过，不重跑完整 61b/全量/夜间。
- OpenSpec/spec-refs/section-select/账本禁令/diff check；不直接伪造 GREEN 记录。

报告 `docs/team/reports/P453-dev2.md` 先给根因和结论，附当前输出对照、红绿恢复与未跑范围。通知 PM 后由非作者复验；不合并、不发布。
