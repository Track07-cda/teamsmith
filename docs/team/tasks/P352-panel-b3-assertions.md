# P352 · 修 `panel-b3.sh` 那 8 条：判行为，不判列宽

task: P352
agent: dev
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 夹具断言
deltas: -
branch: task/P352-panel-b3-assertions
deps: 只改 `tests/panel-b3.sh`（单写者：P329/P346 不碰它）；接线是 P349，等 P346 落地

## 依据（P351 的归因，`docs/team/reports/P351-dev.md`）

8 条红全是**夹具假设**，产品行为按规格是对的：

- 7 条拿「`已放弃` 标签在场」当「看板页在场」的判据。而规格（`panel/spec.md:2410-2424`）明写：并排档里折叠车道是**三列小框**、**框里放不下标签**，标签只在**聚焦时**才在卡片那对位置显示。P125（`a78473ae`，09-29）改的就是这个形态，而它只更新了自己的 `fold` 场景，这个文件又不在任何门禁段里，于是红着留到现在。
- 1 条把卡片点击的列号写死成 `--click-col 25`；P125 让未折叠车道 19→22 列、卡片内容列 23→26，25 落在内边距那一列。

## 要做的

1. 7 条：判据改成「**六条车道目标按图例顺序在场**」（或规格里同义的、判行为而非判某条标签在不在的判据）。**不许**改成「等到 `已放弃` 出现」这种把等待上界加长的写法，也不许删场景。
2. 1 条：列号**从帧里取**（先画、读回、定位那张卡的列），不写死；行同理。
3. 红线：改完 `bash skills/teamsmith/tests/panel-b3.sh --all` 必须 **✓231 ✗0**（或你实测的数字，说明变化原因）。
4. **红侧**：私有副本里把产品改一处，让「六车道在场」不再成立（例如让某车道不出现在看板上）→ 那 7 条必须红；把卡片内容列改坏 → 第 8 条必须红。各给读数。
5. 顺带报一个数：这个夹具现在单次全场景多少秒（接线时要用它决定要不要进地板）。

## 边界

写集：`skills/teamsmith/tests/panel-b3.sh`、`docs/team/reports/P352-dev.md`。不改产品、不改规格、不碰 `smoke.sh`/`section-paths.tsv`（那是 P349）。
