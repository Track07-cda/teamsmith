---
id: P419
title: 指令类消息用 steer 投递，通知类保持 followUp
agent: dev2
category: code
phase: apply
change: notify-and-inbox
specs: notify-and-inbox
anchor: openspec/specs/notify-and-inbox/spec.md
deltas: -
branch: task/P419-say-steer
---

# P419 · `team say` 要能插进正在跑的那一轮

## 现状（PM 实测）

`extension/team-inbox-watch.ts:1106` 固定用
`pi.sendMessage(..., { triggerTurn: true, deliverAs: 'followUp' })`。Pi 对 `followUp` 的定义是
“等 agent 没有更多工具调用时投递”——所以 `team say` 永远排在这一轮之后，插不进去。

Pi 的三种模式：`steer`（本次工具调用结束后、下一次模型请求之前投递）、`followUp`（本轮结束前）、`nextTurn`（不打断）。

## 要做的

按**消息类别**选择投递模式，不看批量大小：

- 批次里只要有一条 `kind=say`（PM 给席位的指令）→ `deliverAs: 'steer'`，这一批用一次投递；
- 其余（`notify`、`nudge`、`knock`、`draft` 回执等）→ 保持 `deliverAs: 'followUp'`；
- `triggerTurn: true` 不变；草稿保护不变（仍然不写目标输入框）。

## 规格与断言

- `openspec/specs/notify-and-inbox/spec.md` 里那条把 `deliverAs` 钉成 `followUp` 的场景要按类别改写，并新增一条场景：**指令用 `steer`、通知用 `followUp`**，两者都在同一个监视通道里可观察。
- 夹具要能证明：同一批只含 notify → `followUp`；含一条 say → `steer`；混合批只投一次且用 `steer`。红侧：把类别判定删掉（恒 `followUp`）→ 含 say 那条断言必须红。

## 边界

- 只改 `extension/team-inbox-watch.ts`、`openspec/specs/notify-and-inbox/spec.md`、相关夹具。
- **不要**改 `team interrupt`（那是硬停，另一条路），不要改 say 的队列与直投判据，不要打输入框。
- 已知极限写进报告：`steer` 只能在两次工具调用之间落地，席位卡在一个长工具调用里时仍要等那次返回。

## 验收（选段）

- `bash skills/teamsmith/tests/smoke.sh --select <按你改到的路径选>`（含 inbox-watch 面）
- `openspec validate --all`、`spec-refs.sh --check`、`section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 报告 `docs/team/reports/P419-dev2.md`，提交推分支，通知 PM。目标 1 小时内。
