---
id: P458
title: 只读查明本项目到期提醒未投递
agent: dev2
category: analysis
phase: opsx-explore
change: -
specs: agent-self-reminder
anchor: none (infra) — 诊断本团队运行进程与既有提醒记录，不修改产品或真实状态
deltas: -
branch: task/P458-local-reminder-queue-explore
---

# P458 · 查旧Pulse与当前投递链，不先猜新版有缺陷

## 已知事实与问题

0.4.7已正式发布，真实自主性和发布验证已经通过。本任务不是重做验收，也不能拿旧进程当作0.4.7实测。

本项目两条真实进度提醒均到期入队但没有batchId/intentAt：
- seq2/rem-204735f4-5535-466d-b0e2-05a4fb869088-2，11-13T08:49:52Z queued，11-16T01:15仍queued。
- seq3同前缀-3，11-16T01:35:10Z queued，02:26取消时仍queued。

V161结束后PM用原生工具取消两条，终态保留全文与时间，没有手改state。2026-11-16T02:28的pulse status报进程已运行508111秒，明确提示scripts/lib已更新而进程没重启；standby仍on，原因是过时文字。watchdog.log没有对应提醒投递记录。上述只是事实，不构成“必定只是旧进程”的证明。

只回答：从queued到批次/投递的哪一步没运行，当前能否证明是旧Pulse，还是当前代码另有缺陷？最小恢复操作是什么、会影响什么？

## 范围

- 写入只允许自己的报告 `docs/team/reports/P458-dev2.md`，在自己的worktree/分支小步提交；可只读本项目主根state、相关journal/diagnostics/watchdog日志、原先两条提醒记录、Pulse与其子进程身份及当前调用链。引用正式agent-self-reminder/watchdog规格和已归档变更，不建立新change或第二份设计。
- 不读取凭据文件，不整份导出进程环境；如必要只读取与这条链有关的TEAM_ROOT/TEAM_STATE_DIR/启动路径等非秘密字段。公开报告不抄提醒全文、真实家目录、用户名、他项目名或原始敏感日志。
- 不重启/停止Pulse、PM或任何现有进程，不改standby/state/config，不新建真实提醒，不在别的项目试，不加日志/守卫/重试/服务，不运行smoke、meta、61b、真实模型或完整提醒验收。
- 允许读取现存证据/源码并离线推演；不要为了证据制造完整沙盒或另一轮大基线。无新代码或测试交付；不要执行无关结构门禁。

## 交付判据

结论先行：具体已证根因，或尚不能证明的最小缺口。逐项连接“实际运行进程/入口→是否调用到期处理→读取哪份权威状态→为什么无批次”，每条结论给现成记录或代码位置。mtime重启提示只证明进程早于更新，不能冒充已知内存加载版本。

给一个最小下一步及影响：若只需 `team pulse restart`，说明它是否保留standby状态、是否会投递其它现有提醒/恢复PM，PM再决定真实操作；若需代码修复，定位函数和行为差异，另走提案，不在本任务实施。不因缺证据追加保护层。

报告写出实际只读命令、未观察边界及“本次改变了什么/没有改变什么”。报告暂存后仅运行自己的ledger-ban与diff-check以防公开泄漏，原件仅留本机。通知PM，不合并或推送，不中途等待确认。
