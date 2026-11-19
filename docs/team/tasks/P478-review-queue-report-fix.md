---
id: P478
title: 修复复验报告把已运行的检查记成排队超限
agent: dev2
category: code
phase: opsx-apply
change: -
specs: verification#The hard timeout covers the gate run, not the queue
deltas: -
branch: task/P478-review-queue-report-fix
---

# P478 · 只修复验的准备与计时记账

先读 AGENTS、本人线程、OWNERSHIP、`docs/team/reviews/P476.md`、`docs/team/reports/P476-verify.md` 和规格的排队/显式临时目录两处。原件已确认：调用者显式目录不存在，工具丢掉准备/计时文件错误，仍执行子命令，最后用读不到文件误判排队超限。原剪贴板首轮有另一项确实失败，历史记录不重写。

写集只含 `skills/teamsmith/scripts/lib/cmd-review.sh` 和本人报告。复用现有 `team_tmp_root_prepare` 的路径、原因和修法；准备不成立在取锁和执行前非零退出，避免把旧记录/日志改成一次未发生的运行。核对 review 的计时文件没有外部读者后，用同一 shell 的实际开始时刻/状态取代该文件和对应吞错分支；排队超限只认已经存在的 `lock_cap_hit`。分别保留排队时间、运行时间、退出码、原有硬超时及互斥入场/运行中丢失的判定；不挪锁路径、不改 smoke 的记录、等待机制或其它入口，不新增状态词、回落目录或测试框架。

作者跑 `bash -n skills/teamsmith/scripts/lib/cmd-review.sh`、`git diff --check`，按本地小提交交代码和 `docs/team/reports/P478-dev2.md`，不先跑行为矩阵；长作业在后台。报告标出旧文件各生产/消费引用是否都在 review 内，以及正常、排队超限、真实子命令退出和互斥拒绝的控制路径。非作者用独立检出和短命令验证有效目录下的真实退出 0 与 1、外部确实持锁到等待上限、显式目录缺失能报准备错误/不执行/不改旧记录；选用既有可短切的硬超时或互斥例子保留必要覆盖。不重跑剪贴板、整段34或其它全量，不写真实项目状态、不推送、不合并、不发布。
