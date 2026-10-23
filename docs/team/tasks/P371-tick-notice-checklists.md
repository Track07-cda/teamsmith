# P371 · 按证据勾两份通知类 change 的清单（只动清单与报告）

task: P371
agent: dev3
phase: apply
category: docs
change: turn-notice-in-pm-inbox
specs: notify-and-inbox#A turn-end notification appends one inbox line and knocks once
anchor: none (infra) — 勾选
deltas: -
branch: task/P371-tick-notice-checklists

## 做什么

`turn-notice-in-pm-inbox`（39 项未勾）与 `notice-fulltext-and-asks`（32 项未勾）的实现与验收**都已经完成并并入 main**
（P364/P365/P368/P370 + V96/V98/V99/V100），只差按事实勾清单。

**规矩（这个仓踩过四次，逐条守）：**

- 每条勾选必须**指出今天磁盘上还读得到的证据**（命令 + 读数，或 `docs/team/reviews/<ID>.md` 的章节号）；
  **拿不出就不勾**，在条目下写明「缺什么、要做到什么才算」。
- **不许为了归档而勾**。`openspec/changes/*/tasks.md` 的空复选框是归档的唯一门槛，它红了才是对的。
- **PM/复验项留给 PM**：凡是「独立复验」「复验记录」「不重跑已有证据」这类条目，**一律留空**由 PM 勾。
- 条目正文不许改写；**允许**在条目下追加一行事实（这条是上一轮 V94 与 PM 共同的裁定）。
- 写集：两份 `tasks.md` + 报告。**不碰产品代码、不碰 tests、不碰别的 change。**

## 交付

报告 `docs/team/reports/P371-dev3.md`：两份 change 各勾了多少、留空多少并**逐条列**留空项「缺什么」。
`openspec validate --all --strict` 与 `spec-refs.sh --check` 收口。
