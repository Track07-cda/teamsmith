# P337 · 循环清单漂红：P326 改写了 11c 的轮询，清单没跟着登记

task: P337
agent: dev3
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 循环清单的登记与源码对齐
deltas: -
branch: task/P337-loop-inventory-drift

## 现状（PM 已在 main 上实测）

`bash skills/teamsmith/tests/section-guard.sh --loop-check` 在**当前 main** 上红一条：

```
bad: smoke.sh:6392 的 while 行与清单第 30 行的锚点不符
ok: 扫描 85 行清单 / 85 个 while+sleep 循环，配平 85 个
```

条数配平（85/85），但**第 30 条登记的锚点对不上了**。原因是 P326 把 11c 的轮询重写了（原来的 `while … ! team roster | grep -qF …` 因为 `grep -q` 早退触发 SIGPIPE、被 `pipefail` 判成失败，改成「整份输出落变量 + bash 自己匹配」），**循环数量没变**（旧循环被替换），所以配平不报警，但锚点漂了。

## 要做的（只对齐登记，不改行为）

1. 确认这件事属实：看清第 30 条登记的锚点（`cap="$i" -lt "${4:-50}"`）与现在第 30 个循环（`smoke.sh:6392` 那个 roster 轮询）确实不是同一个东西，并在报告里贴两边原文。
2. 把**那一条**登记的锚点改成源码里真实的锚点（按清单既有的列格式：`file<TAB>line<TAB>bound<TAB>anchor`）。`line` 列是文档用的，可以顺手改成今天的行号，但**配对是按文件内出现顺序、不按行号**（清单头注已写明），别指望行号救你。
3. 改完 `bash skills/teamsmith/tests/section-guard.sh --loop-check` 必须绿，且仍是 `85 行清单 / 85 个循环`。
4. **不要**为了让清单变绿去改循环本身、也不要放宽扫描或加豁免。如果读完发现某个循环真的**不该**带 `sleep`（即它是个不受限的空转），那是另一件事：写进报告点名叫 PM 立单，本任务不动它。
5. 红侧（一条就够）：在私有副本里把那条第 30 条的锚点再改错（例如把 `while [ "$R_WAIT" -lt "$R_MAX" ]` 改成别的字），`--loop-check` 必须**重新红并点名**；还原后必须绿。证明你把它登记成了「真会咬人」的形状，而不是把判据放宽。
6. 轻量收口：`openspec validate --all --strict`、账本禁令固定验收行、`git diff --check`；另跑一次 `--select 0e`（现在是 `✓42 ✗3`，期望改成全绿，贴读数）。

## 边界

- 写集：`skills/teamsmith/tests/loop-inventory.tsv`（**只有第 30 条那一行**）、`docs/team/reports/P337-dev3.md`。
- 不碰 `smoke.sh`、不碰 `section-guard.sh`、不碰扫描面与匹配规则、不改任何时限与预算、不新增门禁段。
