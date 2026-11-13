---
id: V159
title: P452 停止 PM 恢复夹具独立复验
agent: dev3
category: verify
phase: verify
change: -
specs: pm-lifecycle
anchor: openspec/specs/pm-lifecycle/spec.md
deltas: -
branch: task/V159-reminder-recovery-verify
---

# V159 · 非作者复验 P452

候选 `917e1bd1`，作者 dev。PM 准备 `/var/tmp/p452-review-917e1bd1`。你未参与修复。

## 验证

1. 独立复现同一场景：修复只同步夹具 `TEAM_PI_BIN` 环境覆盖，产品源码零差异。真实 argv 无普通 `@pm-prompt`，session 延续，Reminder 先于普通 backlog；不是只生成了 argv 文件。
2. 删除新增同步行必须红，恢复后绿；运行 `remind-tool-real.sh`、`remind-recovery-real.sh`、恢复单元和 `smoke.sh --select 67,68`。
3. OpenSpec/spec-refs/section-select/账本禁令/diff check；空 change 目录若只在作者工作树存在，不算候选红。
4. 报告 `docs/team/reports/V159-dev3.md` 给 PASS/NEEDS-CHANGES、真实命令和未跑范围。通过后 PM 合并，再由你在 merged SHA 上跑 §67/68 定点复核并更新报告。

不跑全量/夜间/61b，不合并、不发布。
