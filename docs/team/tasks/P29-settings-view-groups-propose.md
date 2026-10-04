# P29 · settings-view-groups：设置视图按功能分组 + 重启类用颜色 + 鼠标滚轮（propose）

```
task:   P29
agent:  dev-bob
issue:
change: settings-view-groups
specs:  -
phase:  propose
anchor: change
deltas: panel, memory-and-deps
deps:   settings-choice-editors（已归档：直写交互与读一遍是基线）
status: todo
budget: 一个工作块（只出提案包；不写实现）
```

> 本地模式：不 push。**只 propose。**

## 用户的三条反馈（2026-09-22，在控制台实际使用后）

1. **设置页面没法用鼠标滚轮**（board/kanban 页有 wheel，设置页没有）；
2. **设置选项的分组要考虑**——现在**按生效类分三组**（`apply`/`restart`/`refuse`），用户明确说
   **不要按"是否需要重启"分组**；
3. **用颜色代表是否需要重启**（行级），但**分组按别的维度**（功能域）。

## 提案要解决的设计问题

1. **功能分组的来源与形状**：PM 建议 **schema 加第 10 列 `group`**（封闭 token，直接沿用 schema 现有
   `# ---- 身份与账本布局 ----` 等分节名；**单一真源仍是 schema**，与第 9 列 `suggest` 同一先例）；
   `team config list --json` 带上它；视图按 group 分节、组标题不可聚焦、组内保持 schema 序；
   未知 group token → 走查红。**你可以提出替代方案**（例如解析现有分节注释），但必须论证
   "单一真源"与"新增键零改动"两个性质；给出取舍。
2. **行级重启标识**：每行保留**文字徽章**（`立即生效`/`重启生效`/`只读`）并用 tone 上色
   （restart=警告色、apply=正常、refuse=暗）——**颜色不得是唯一通道**（panel spec 既有红线）。
3. **鼠标滚轮**：设置视图滚动（复用 board 页 wheel 模式：滚动窗口 + 两端"还有 N 条"计数）；
   顺带检查 kanban/详情页滚轮是否一致。
4. **规模**：预计 2–4 条 requirement、8–15 条 scenario；别膨胀。

## 必须写成可证伪的验收（apply 阶段用，提案里先定判据）

- pty：组标题是**功能域**名（不是 apply/restart/refuse）；wheel 滚动后窗口移动且边缘计数正确；
  每行徽章 + tone 都在；**删除某键的 group → 走查红**；**把某键改到别的 group → 视图跟着变**（证明不硬编码）。

## 边界

- 不碰写入路径（`team config set` 的校验/CAS/审计/直写语义是刚验证过的基线，不许动）；
- 不碰 `settings-choice-editors` 已归档的行为（直写、零读取、危险值例外、「其他」路径）；
- 不写实现（`scripts/**`、`tests/**` 一律不改）；发现矛盾 → `BLOCKED:` 交回 PM。

## Deliverables

- `openspec/changes/settings-view-groups/{proposal.md,design.md,tasks.md}`
- `openspec/changes/settings-view-groups/specs/{panel,memory-and-deps}/spec.md`
- 报告 `docs/team/reports/P29-dev-bob.md`

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```
