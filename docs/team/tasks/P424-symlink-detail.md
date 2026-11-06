---
id: P424
title: 详情面把项目内的软链当攻击拒绝（ai_interview 的 docs/team 是软链）
agent: dev
category: code
phase: apply
change: -
specs: panel
anchor: openspec/specs/panel/spec.md
deltas: -
branch: task/P424-symlink-detail
---

# P424 · 项目内的软链不该被拒绝

## 现场

ai_interview 的 `docs/team` 是一个**指向项目内部**的软链：

```
docs/team → ai-interview-algo/docs/team        （同一项目内）
```

pulse 面板上打开任何条目的“详细”，显示 `来源不可用：软链拒绝：…`。原因在 `scripts/lib/cmd-watch.sh` 的详情块：
路径上任一段是软链就无条件拒绝（`[ -L "$f" ] && refused=1`，`reason="软链拒绝：$refused"`）。

判据本身是对的（不许顺着软链读到项目外），但它把**指向项目内**的软链也一起拒了 —— 这是用户自己的账本布局，
读它没有风险，代价却是详情面完全不可用。

## 要做的（一条规则，改到位）

详情**读**路径：解析真实路径后判断落点。

- 解析后仍在项目根内 → **允许**（照常读、照常报软链这一段的存在，方便排错但不当错误）；
- 解析后落在项目根外 → **仍然拒绝**并点名两个路径（真实路径 + 项目根），保持现有拒绝文案的形状；
- 非普通文件（FIFO、设备、目录当文件读）→ 仍然拒绝，不许阻塞（`O_NONBLOCK` 那套保留）。

覆盖 `cmd-watch.sh` 里所有详情块（changes / specs / decisions / reports / reviews 与 `team __panel-data --block detail` 一族），不是只修一条。

## 红侧（每条都要能红）

1. 项目内软链 → 详情可读，且**不再**报“来源不可用”；
2. 软链指向项目外（例如 `docs/team → /etc`）→ 仍被拒绝并点名；
3. FIFO 冒充详情文件 → 仍被拒绝且不阻塞；
4. 普通文件 → 行为不变；
5. 把判据改回“任一段是软链就拒” → 第 1 条必须变红。

## 验收（选段，不跑全量）

- 相关面板/详情选段（按你改到的路径选），以及 `bash skills/teamsmith/tests/smoke.sh --select <段>` 的结果行
- `bash skills/teamsmith/tests/panel-strings.mjs`（若触及文案）、`section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 报告 `docs/team/reports/P424-dev.md`，提交推分支，通知 PM

## 边界

只改详情读取的软链判据与其夹具；不改写面（写仍然不许穿软链）、不改面板布局、不跑全量 smoke、不合并/归档/发布。
