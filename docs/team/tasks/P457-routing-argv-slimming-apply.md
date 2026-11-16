---
id: P457
title: 删除模型路由的三处重复执行
agent: dev-bob
category: code
phase: opsx-apply
change: routing-argv-check-slimming
specs: verification
deltas: -
branch: task/P457-routing-argv-slimming-apply
---

# P457 · 按已接受的三处精简实施

提案已在 `docs/team/reviews/routing-argv-check-slimming-proposal.md` ACCEPTED（源候选8f244edc，独立V162/dev3，0 CRITICAL/WARNING）。你未参与提案与审阅。用户已要求精简完整测试、不要过度防御，并于11-16要求继续；本任务授权实现，不授权合并/归档/发布。

先读本线程、OWNERSHIP、change的proposal/design/specs/tasks，按OpenSpec status/instructions apply确认root与待办。需求仅在change，不另造要求表。已有worker/PM短样本与原始故障见P454/P455/V162报告，不重新收集完整旧基线。

## Boundaries（临时借用，冻结交付后归还）

- `skills/teamsmith/tests/task-model-routing.sh`
- `skills/teamsmith/tests/lib/model-routing-expansion.sh`
- `skills/teamsmith/tests/section-paths.tsv`仅61b行
- change `tasks.md`：只勾本席位实际完成的项；独立verify/合并后任务3.3不提前勾。
- 自己的`docs/team/reports/P457-dev-bob.md`。

不写其他delta、主spec、smoke.sh、变异器、产品、config、README或版本；不扩大到另外五条boundary、正常61或测试框架，不新增永久自证层/slow备用入口。不改P456的发布清理；本变更留任务分支，**不进入0.4.7冻结发布对象**。

## 执行与证据

按现有tasks实施两个短入口和父级接线，真删第二CORE。先用短样本调试及一次性父级接线反例，不每个提交重跑整个矩阵，不用产品自比当期望，不stub真实PM guard。

最终可执行字节冻结后，只跑一次完整 `TEAM_META=1 TEAM_SMOKE_FAST=0 bash skills/teamsmith/tests/smoke.sh --select 61b --keep </dev/null`，后台启动后结束回合，完成唤醒后收割。共享门禁优先给P456/V161的发布短补验；若会冲突，先通知PM协调，不起第二轮完整矩阵或在回合里等待。

照tasks做当前change严格结构、索引、循环清单、ledger-ban及diff检查；只登记已有helper，不引入新清单机制。性能只记录真实新用时，不设目标阈值，不拿历史1419s当已省。报告给旧三处删除、新短入口/父级检查、保留CORE与29臂的实际清单及计数变化；不称完整一阶已变快。

小步提交，最终报告真实命令/rc/原日志/短样本与翻转证据，明确所选61b及未运行范围。完成后由非实现者独立验证；不自行改验证记录、关闭看板、不push/merge/tag/npm。不碰主检出，也不把运行记录复制成跟踪的.log证据。
