# P362 · 按证据勾两份 change 的任务清单（只动 tasks.md，不改代码）

task: P362
agent: dev3
phase: apply
category: docs
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 账本勾选
deltas: -
branch: task/P362-tick-checklists
deps: 两个 change 的实现与复验都已 done（见 `team change status`）

## 要做的只有一件事

两个 change 的 `tasks.md` 里有未勾项，而它们的实现与复验都已结束并存有证据。**按事实勾，不是按想勾**：

- `openspec/changes/behavior-focused-ci/tasks.md`：**9 项**未勾；
- `openspec/changes/gate-waiter-patience/tasks.md`：**34 项**未勾。

对每一项，规则（沿用本仓既有做法）：

1. **能拿出证据的点** → 勾上，并在该项里写证据指针（`— 见 reviews/P326.md §… / 提交 <sha> / 选段读数 ✓x ✗0`）。
   证据必须**今天在磁盘上还能读到**（报告、复验记录、提交、规格文本）。
2. **拿不出证据、或它要的是「未来做某事」** → **留空**，并在该项里写一句「未做/无证据：<它要什么>」。
   **不许为了关单而勾**。过去三次（P151 F3、P175 F3、P206 F1）都是这么漏的，所以这条比数量重要。
3. **PM/复验项**（例如「PM 在合并后的树上重跑」「用户确认」）**一律留空**，由我按事实勾。
4. 只勾**真正被完成**的；如果某条要的东西其实**没做**（例如某个定点证据从来没跑过），就如实留空 + 写明缺什么。

## 边界与交付

- 写集：`openspec/changes/behavior-focused-ci/tasks.md`、`openspec/changes/gate-waiter-patience/tasks.md`、`docs/team/reports/P362-dev3.md`。
- **不改产品、不改测试、不改 delta 正文**；不动 `tasks.md` 的条目文字（只把 `- [ ]` 改成 `- [x]` 并**追加**证据后缀）。
- 收口：`openspec validate --all --strict`、`team change status <id>`（贴两份输出，让我看还剩几项）、账本禁令、`git diff --check`。
- 报告先给一张表：change / 总项 / 勾了几项 / 留空几项 / 留空的每一行要什么。
