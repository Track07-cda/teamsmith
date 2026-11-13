---
id: P452
title: 修复停止 PM 恢复场景 argv.bin 缺失
agent: dev
category: code
phase: opsx-apply
change: -
specs: pm-lifecycle
anchor: openspec/specs/pm-lifecycle/spec.md
deltas: -
branch: task/P452-reminder-recovery-argv
---

# P452 · 发布门禁 P443 停止恢复失败归因与修复

冻结发布门禁 main `572856a3` 的 §68 唯一产品面失败：`remind-tool-real.mjs` 的 stopped PM recovery 场景 rc=1，读取 `/var/tmp/p442-real-evidence-1794540132695/recovery/argv.bin` ENOENT。其余 5139 项通过；元套件过期另处理。

原始现场 `/var/tmp/p442-real-evidence-1794540132695/` 与 `/var/tmp/rel47-first-order.log` 保留。先读日志、恢复目录、真实 Pi/tmux 状态和测试启动链，独立复现后确定产品还是夹具根因。

## 约束

- 保留真实要求：停止的 PM 只因有效 Reminder 恢复，不带普通启动提示，Reminder 先于普通积压。
- 不得删除/跳过该场景、伪造 argv.bin、延长时间或加固定 sleep 来消红；若产品没有启动，必须修启动或如实保留失败。
- 不碰真实团队 PM/Pulse/Standby；只在隔离项目与私有 HOME/tmux 复现。
- 若根因在 P450/P451 的配置或锁诊断，按最小范围修；不顺手改其它提醒语义。

## 验收

- 同一场景改前红、改后绿，保留真实启动 argv/session/state 证据；再跑 §68、`remind-tool-real.sh`、相关恢复与 §67 选段。
- 至少一条反向改坏证明失败没有被吞；OpenSpec/spec-refs/section-select/账本禁令/diff check。
- 不跑全量/夜间/61b，不合并、不发布。

报告 `docs/team/reports/P452-dev.md` 先给根因与结论，附原始错误、修复前后、红侧与未跑范围。通知 PM 后由非作者复验。
