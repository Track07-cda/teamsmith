---
id: P447
title: 排查交付通知漏达与 PM 等待引导
agent: dev2
category: analysis
phase: opsx-explore
change: -
specs: notify-and-inbox pm-lifecycle
anchor: openspec/specs/notify-and-inbox/spec.md
deltas: -
branch: task/P447-delivery-notify-guidance
---

# P447 · 通知漏达与 PM 等待策略：只探索

## 现场

V153 在 19:48 已提交 PASS（4f0f6d1d），PM 收件箱只有 19:33 的旧自动回执和 19:51 的 `knock=skipped:merged`，没有手工交付通知。PM 因提示词“等通知、不要轮询”持续按未完成等待，用户发现后追问。

这不是第一次发生提示后仍等待的情况。

## 要回答的

1. 对照 V153 与最近正常手工交付（P446、V152 等）的通知路径：worker 是否调用 `team notify`，CLI 是否入 inbox/outbox，watcher 是否收到/去重/合并，交付日志具体停在哪一步。只读，不重放真实团队消息。
2. 自动回执的 tip、报告提交、手工通知三者在这次分别是什么；为什么自动回执不能代表“未完成”。
3. PM 提示词哪几句促成了无限等待；给出最小替代文案，要求：
   - 通知优先，但通知缺失时用 digest/BOARD/report/git log 对账；
   - 自动回执只表示回合结束，不证明任务未完成；
   - 席位停住或一段时间没有新证据时，主动读磁盘，不靠猜；
   - 仍不要求 PM 反复读取席位屏幕或重跑验证。
4. 通知链缺陷与提示词修正各自最小落地范围和可证伪验收。不要先造新通知系统或定时轮询服务。

## 交付

`docs/team/reports/P447-dev2.md`：先给根因分层和推荐最小修法，附 V153 的实际记录、对照案例、提示词差异和验收建议。只写报告，不改产品、提示词、规格或通知状态。PM 审阅后再决定提案与实施。
