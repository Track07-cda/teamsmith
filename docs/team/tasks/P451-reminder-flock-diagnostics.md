---
id: P451
title: 完成 flock 路径、doctor 诊断与迁移回滚收尾
agent: dev
category: code
phase: opsx-apply
change: agent-self-reminder
specs: memory-and-deps reminders
anchor: openspec/changes/agent-self-reminder/tasks.md
deltas: memory-and-deps, reminders
branch: task/P451-reminder-flock-diagnostics
---

# P451 · 只完成 1.3.2

V158 merged-SHA 已证明其它实现与真实自主性通过；唯一未闭合项是 `tasks.md` 1.3.2。阅读该任务、`memory-and-deps` delta、P422/V128 证据及当前 `team paths` / doctor / migration 实现。

## 必做

1. `team paths` 输出实际解析到的 `flock_runner`，与状态事务使用的是同一解析结果，不另造第二份路径逻辑。
2. `team doctor` 在 flock 缺失或不可执行时给出具体错误与修复方式；文件系统不支持排他锁时明确失败，不得无锁降级或假装可用。没有 Reminder 的项目使用 Standby 也同样诊断。
3. 完成迁移文档：缺锁的新错误、静止迁移失败时的状态、回滚导出的实际操作；与真实命令一致，不写不存在的恢复能力。
4. 在隔离项目验证：缺 flock、不可执行 flock、实际锁失败、迁移失败保持原状态、回滚导出可恢复。不得操作真实团队的 standby/state。

## 验收

- `state-authority.sh`、`remind-delivery.sh`、相关 paths/doctor/init/migration 选段；每类新行为至少一条反向改坏，恢复后绿。
- 缺 flock 不只是 PATH 空壳导致其它命令先失败；锁不支持要证明失败来自实际 locking，不是模拟成功。
- OpenSpec/spec-refs/section-select/账本禁令/diff check；不跑全量/夜间/61b。
- 只勾 1.3.2 及父项在证据完整后；由 V158 最终复验，不自行宣布整个 change 可归档。

## 交付

小步提交，`docs/team/reports/P451-dev.md` 先给结论，附缺锁/锁失败/迁移回滚的真实命令、红绿恢复和未跑范围。通知 PM 后交 V158；不合并、不归档、不发布。
