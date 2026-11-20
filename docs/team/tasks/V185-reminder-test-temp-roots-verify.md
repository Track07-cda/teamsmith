---
id: V185
title: 独立验证两份提醒测试的清理、保留和中断
agent: verify
category: verify
phase: opsx-verify
change: reminder-test-temp-root-ownership
specs: verification
deltas: -
branch: task/V185-reminder-test-temp-roots-verify
---

# V185 · 在固定版本集中验证这次改动

P486 实施者 dev-bob，固定候选 `f7db9e776f8a1ad8c118c522517a67755a5d5485`，PM 干净检出 `/var/tmp/p486-review-f7db9e77.dmzBCK`，只读。作者交付 `a4904676` 只多报告，五份测试及规格与候选逐字节相同。读任务与 OpenSpec 工件、`P486-dev-bob.md` 和已接受的 V184 判据；按固定检出 `openspec/changes/reminder-test-temp-root-ownership/tasks.md` 的 2.1–2.5 执行一次。不得改候选、实现或勾任务清单。结果必须区分准备错误、具名失败和业务通过。

仅允许原生 `team review P486 --dir /var/tmp/p486-review-f7db9e77.dmzBCK --branch f7db9e776f8a1ad8c118c522517a67755a5d5485` 写中央 `docs/team/reviews/P486.md` 和 `P486-verify.log`，由本席位后台作业执行；使用专属隔离环境、适用锁与 `TEAM_GATES` 指向本次 `/var/tmp` 定点验收脚本，`OPENSPEC_TELEMETRY=0`。只操作隔离副本、私有 Pi、私有 tmux 和已有本地替代服务；真实提醒、模型、实际团队、性能、整套 smoke 一律不运行。不可用默认共享终端。保留实际 stdout/stderr/rc、工作和证据位置、进程退出记录；两个中断按方案给出顺序，故障中断必须有写入已完成、驱动自己停止且未进入下一步的外部记录，不以父进程非零代替。路径回执从真实参数/目录选择后取，不另造正确路径。只测方案指定的真实短成功、具名故障、两种不同中断及短路径回执；未改入口和三处外层调用只读核。若一项需补验，只补该项，其余沿用未受影响的原件。

验收结束用现有 OpenSpec 1.16 单变更 strict 及短差异检查，按完整性、正确性、一致性报告，区分 1.x 现有勾选与 2.x 实际证据；其余未验明确列出。`docs/team/reports/V185-verify.md` 写真实命令、原始输出路径、未通过事项或独立结论，本地提交不推送，私有原件待接受后清理。通过合并后仍由你核合并版同一性、语法及接入，不重跑上述场景。