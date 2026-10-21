# P349 · 接线：`panel-b3.sh` 也不在任何门禁段里（第二个这样的夹具）

task: P349
agent: dev3
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 夹具接线
deltas: -
branch: task/P349-wire-panel-b3
deps: P346 已并入 main（它改 `smoke.sh` / `section-select.sh`；单写者）

## 事实（P348 第 3 轮报出，`docs/team/reports/P348-dev-bob.md` §5）

`skills/teamsmith/tests/panel-b3.sh`（断言密度第三高的测试文件）**不在任何门禁段里**：`section-paths.tsv` 没有行声明它，`--paths` 指到它不会选中任何跑它的段。它守的是 pty 面（真按键、鼠标、resize、`q` 收起）。

这是今晚第二个这样的夹具——前一个是 `panel-b2.sh`，已按同一手法接进 §38（P327）。**处置不是删，是接线。**

## 要做的

1. 读 P327 的落地（`git show 72ad49fa --stat` 与 `docs/team/reviews/P327.md`），照**同一形状**接：找它真正的归宿段（跑同族 pty 夹具的那一段）、加一条腿、成功给一条带它自己结果行的 `ok`、失败 `bad` 并打印尾部。
2. **不进地板**：先测它单次全场景要多久；若 > 60 s，就照 `38-h` 的方式只在「完整门禁 / 显式选到 / 改动路径命中」时跑，并在 `--floor` 单跑时给具名跳过。给出「地板里跳过 vs 跑」两个用时读数。
3. **选段块不能靠整串匹配**（P327 的第一版就错在这：`floor, needs:63` 被当成直接点到）；照它修好的逐 token 判。
4. **反例**：私有副本里改坏它的一条关键断言 → 同一次选段必须 `rc=1` 并点名那一条。
5. 断言与场景一条不改：`panel-b3.sh` 相对 main **逐字节相同**（给 blob 哈希）。
6. `section-select.sh --check` 段数不变（不新增段）；轻量收口 `bash -n`、账本禁令固定验收行、`git diff --check`。

## 边界

写集：`skills/teamsmith/tests/smoke.sh`（选段块 + 那一条腿）、`skills/teamsmith/tests/section-paths.tsv`（归宿段那一行 patterns）、报告。不改 `panel-b3.sh` 本身、不新增段。
