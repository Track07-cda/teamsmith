# V59 · 临时根四个缺口的定点复检（决定性：doctor 必须真的只读）

task: V59
agent: dev3
phase: verify
category: verify
change: tmp-root-on-disk
specs: verification
deltas: -
branch: task/V59-tmp-root-gaps-verify
deps: P314（已交付，冻结 tip 见**收据文件** `reviews/V59/freeze-receipt.txt`）｜P312 的留空项（`docs/team/reports/P312-dev2.md`）

## 四处的决定性检验

1. **`team doctor` 只读**（最重要）：把 `TEAM_TMP_ROOT` 指向一个**不存在**的目录 → 跑 doctor → ① 该目录**仍不存在**；② 输出里说清「尚未创建」并说明何时创建；③ 状态目录全树哈希**不变**。
   **红侧自己造**：让 doctor 真的建目录（可以改副本）→ 你那条断言必须红并点名。
2. **§40 的 band**：核它按**实测**重填（同一套系数规则），provenance 里写明「改动前树 / 本分支」两次读数与当时的负载；你自己在**当前负载**下跑一次 §40，读数落在带内或带**在噪声范围内**（D192：过载时计时不作判据，但要写明负载）。
3. **开跑行印来源**：跑一次 `smoke.sh --select <小段>` → 开跑行必须含解析出的根与 `source=`；**红侧**：把打印去掉（副本上）→ 必须红。
4. **文档**：`references/troubleshooting.md` 与 `references/migration…`里不得再出现旧的 `${TMPDIR:-/tmp}` 与「15 GB tmpfs」的**残留 token**；用稳定 token 核对，并把「回退到 `/tmp` 的方法」真跑一遍（`TEAM_TMP_ROOT=/tmp` → 根确实变了）。
5. **全量**：核它确实跑过一次完整套件（报告的 rc 与结果行）；既有红按 D198 只记录。
6. 计时类按 D192；容器里先 `mkdir -p` 再设 `TMPDIR`（D189）；`/tmp` 与 `/var/tmp` 根数前后对比；受检 tip 以收据为准（D196）。

## 交付

`docs/team/reviews/V59.md`（抬头含 `判定: **PASS**` / `判定: **FAIL**`；逐条命令 + rc；doctor 只读的三条证据与红侧；§40 的实测与带；文档 token 核对与回退实跑）；不改候选、不合并、不推送。
