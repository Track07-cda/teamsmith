---
id: P477
title: 用上次完整计时查剩余最慢测试的重复工作
agent: dev3
category: analysis
phase: opsx-explore
change: -
specs: verification#A gate that cannot judge says so
deltas: -
branch: task/P477-full-test-slowest-explore
---

# P477 · 不重跑，先用现成耗时定位下一项可减的工作

读 `docs/team/reports/V174-verify.md` 的逐段耗时及 PM 已存 V174 原日志。只查最慢的四项（设置、用法与实际入口、关键回复界面、关键回复保存与 CLI）：沿每段找到反复建环境、启动进程或无结果等待，核对设置精简与已经完成的五批去重有没有覆盖它，别把旧记录当成新实测。给出按预期收益和风险排列的最多两处明确可删的重复工作或可合并的准备步骤、原有行为如何保留，并标出建议只验证哪一小组。无法从现有日志归因的耗时明确写未知；不要估算整套新耗时。

不运行任何业务检查、不重跑全量、不改产品、测试或现有设置；不顺带整理提醒测试临时目录（另项）。唯一写集本人 `docs/team/reports/P477-dev3.md`；短静态 diff 检查后本地提交（P477 / Agent: dev3），不推送。
