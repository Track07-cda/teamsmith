# P367 · 两处小修：`panel-choices.sh` 的 flip 树缺 SKILL.md、选段表 `13` 行缺 `needs: 5`

task: P367
agent: dev3
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 夹具与选段表
deltas: -
branch: task/P367-fixture-and-table-fixes

## 依据（P366 的归因，`docs/team/reports/P366-dev3.md`）

1. **`38-a panel-choices.sh` 红不是整套独有**：宿主与容器各跑 `--select 38,57` 都是同三条红；夹具直跑（更早的树）
   同样 `✓2 ✗3`。根因：**flip 树没有 `SKILL.md`**，于是 `team init` 在 `cmd-init.sh:307/313` 直接拒绝源。
2. **`13` 行缺 `needs: 5`**：`--select 13` 会红，`--select 5,13` 是 `✓67 ✗0`；项目自带的逐键审计工具同样判
   `bad 13`。这不是本次改动引入，但**表本身错了**，红是它的正确反应。

## 要做的

1. **`skills/teamsmith/tests/panel-choices.sh`**：让 flip 树按 `team init` 今天的要求带上 `SKILL.md`（照源派生，
   不要写死一份拷贝；`team init` 的拒绝理由就在 `cmd-init.sh:307/313`）。改完 `--select 38` 里 `38-a` 必须绿。
   **不许**改断言、不许跳过着三条、不许把 `team init` 的拒绝放宽。
2. **`skills/teamsmith/tests/section-paths.tsv` 的 `13` 行**：补 `needs: 5`（按该表既有列格式）。改完
   `--select 13` 与 `--select 5,13` 的读数应一致（贴两者）。
3. **红侧（各一条）**：① 把 flip 树里的 `SKILL.md` 再拿掉 → `38-a` 必须重新红并点名；② 把 `needs: 5` 去掉 →
   逐键审计工具与你写的 `--select 13` 对照必须重新不一致。

## 验收命令

`--select 38`、`--select 13`、`--select 5,13` 各一次（贴读数与 rc）、`section-select.sh --check`（含逐键审计）、
`bash -n`、`--loop-check`、账本禁令、`git diff --check`。不跑整套。

## 边界

写集：`skills/teamsmith/tests/panel-choices.sh`、`skills/teamsmith/tests/section-paths.tsv`、本任务报告。
不改产品、不改 `cmd-init.sh` 的拒绝判据、不新增段。
