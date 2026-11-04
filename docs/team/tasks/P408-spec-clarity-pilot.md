---
id: P408
title: 长需求拆分试点：先在三份小规格上跑通"改法 + 归档 + strict 转绿"的完整套路
agent: dev
category: code
phase: apply
change: spec-clarity-burn-down
specs: writing-discipline, extension-slash, help-surface
anchor: none (prose-only rewrite) — 只拆长需求、不改任何行为语义
deltas: writing-discipline, extension-slash, help-surface
branch: task/P408-spec-clarity-pilot
---

# P408 · 先证明套路，再谈 240 条

OpenSpec 1.16 把"需求文本 > 500 字符"升为 warning、`--strict` 判失败。本仓现有 **240 条**命中，分布在 20 份规格里（最重的 `panel` 41、`verification` 28、`dispatch` 21、`notify-and-inbox` 20）。

不要一次改完。**本片只做三份最小的规格**，目的是把"怎么改、怎么归档、怎么证明没改行为"的套路跑通，产出可以复制给剩余 17 份：

- `writing-discipline`（5 条）
- `extension-slash`（6 条）
- `help-surface`（6 条）

## 改法（必须守的三条）

1. **只动措辞结构，不动行为语义**：把长需求里的举例、边界、枚举挪进该需求已有的（或新增的）**场景**，必要时把"一条需求讲两件事"拆成两条需求。需求的**标题**尽量不改（其他文档按标题/ID 引用它们），拆出来时新标题要能自成一句。
2. **场景必须是 1.16 认的列表格式**：`- **WHEN** …` / `- **THEN** …`（缺步骤在 1.16 下也告警）。
3. **走 change，不直接改 canonical spec**：新建 `openspec/changes/spec-clarity-burn-down/`，用 `MODIFIED Requirements` 覆盖这三份规格里被改写的需求；`proposal.md` 写清"这是可读性改写，行为不变"，`tasks.md` 列这三份规格的复选框。**不要**建 `skip_specs` 的空壳。

## 硬约束（会红的那种）

- `bash skills/teamsmith/tests/spec-refs.sh --check` 必须仍是 `undeclared 0`：改需求标题会让 `docs/team/**` 里按标题的引用断掉。若某条必须改标题，把引用一并更新，并在报告里列出来。
- `openspec validate writing-discipline --strict`、`… extension-slash --strict`、`… help-surface --strict` 三份**各自**必须 0 warning。
- `openspec validate --all --strict` 的总数必须从 240 **严格下降**（报告里贴改前改后的数）。
- 行为零改动要有证据：这三份规格里被改写的需求，其判定文字（"系统必须/不得…"）逐条对照，报告里给一张"改前一句 → 改后哪几行"的表，任何语义漂移都算缺陷。

## 验收（自己跑，贴 rc 与输出尾）

- 三份规格各自的 `--strict` 结果、全局 warning 计数前后、`spec-refs --check`
- `openspec validate spec-clarity-burn-down --strict`（change 自身要合法）
- `section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- **不要**归档这个 change（归档要用户确认）；只交付 change 目录本身
- 报告 `docs/team/reports/P408-dev.md`，含"给剩余 17 份规格的可复制做法"（不超过 10 行），提交推分支，通知 PM

## 边界

- 只改 `openspec/changes/spec-clarity-burn-down/**`；**不**直接编辑 `openspec/specs/**`。
- 不改产品代码、不改测试、不跑全量 smoke、不合并/归档/发布。
