---
id: P448
title: delivery-final-wake-integrity 正式 OpenSpec 提案
agent: dev2
category: analysis
phase: opsx-propose
change: delivery-final-wake-integrity
specs: notify-and-inbox background-jobs pm-lifecycle
anchor: openspec/specs/notify-and-inbox/spec.md
deltas: notify-and-inbox, background-jobs, pm-lifecycle
branch: task/P448-final-wake-proposal
---

# P448 · 通知归属、最终新提交唤醒与 PM 对账提案

## 已接受探索

`docs/team/reports/P447-dev2.md` 与 `docs/team/reviews/P447.md`。V153 证明：独立 clone 作业被误归 delivered；最终新提交 merged 而没有新唤醒；PM 缺少无新通知时的磁盘对账触发。

## 提案必须覆盖

1. **作业身份分离**：`.job` 同时保留发起会话身份与执行 cwd；归属只看发起身份并继续验证 pid/starttime，执行 cwd 可为独立 clone。旧记录缺少发起身份时，仅在与席位目录明确匹配时按 legacy 接受，否则不归任何席位，不把别人的作业接过来。
2. **最终新提交可唤醒**：最终 delivered 的不同 tip 必须形成新行/新唤醒；suspended 的进度 tip 可合并不唤醒；同 tip 重复 delivered 仍合并去重；suspended→delivered 必须新行。明确替换现有跨 tip 一律合并的场景，不能只改扩展强制 sendWake。
3. **PM 指引**：同步 `templates/pm-prompt.md.tmpl`、`SKILL.md`、`references/workflows.md`：通知优先、文件为准；旧 tip/无新通知/merged 不证明未完成；准备重复同一等待状态前用 digest/BOARD/任务分支报告/git log/status 对账；不要求读屏或由 PM 重跑验证。
4. **比例性**：复用 `team-bg.ts`、`team-notify.ts`、`cmd-agents.sh` 合并边界与 `bg-ledger-harness.mjs`，不新增通知系统、定时轮询服务或人工双发步骤。

## 验收设计

- 独立 clone 作业在跑时 suspended 且不唤醒；完成并提交报告后 delivered 新 tip 且唤醒一次；其他席位作业不受影响。
- 不同 delivered tip 各唤醒一次，同 tip 重复仍一次，suspended 进度不敲；删除发起身份区分或 tip 边界必须按名变红。
- 真实 watcher 保持 read/intent/sent 一致；不拿 API sent 冒充 PM 已读。
- 指引用一次性隔离 PM 场景验证：报告已提交但唤醒缺失时能读文件识别交付；作业仍运行时不误报完成。旧提示若也正确处理，不能伪称反向证明。
- 结构校验、受影响选段与真实通知路径；不跑全量/夜间/61b。

## 交付

只写 change 的 proposal/design/tasks/三个 delta 和 `docs/team/reports/P448-dev2.md`，不实施。运行结构检查后通知 PM；由非作者独立审阅，接受前不 Apply、不合并、不归档。
