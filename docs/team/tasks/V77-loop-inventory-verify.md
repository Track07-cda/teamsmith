# V77 · P337 的独立验收（轻量）：一条登记的对齐，判据仍是源码

task: V77
agent: dev-bob
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 循环清单的一行登记
deltas: -
branch: task/V77-loop-inventory-verify

## 受检

候选 `1db1bc0c`（实现 `1cda2e4a`），报告 `docs/team/reports/P337-dev3.md`。改动只有 `skills/teamsmith/tests/loop-inventory.tsv` **一行**。

作者指出我任务书的一处编号错：我写的「清单第 30 条」其实是文件第 30 行，而 `--loop-check` 报的「第 30 行」是按文件内出现顺序的第 30 个 `smoke.sh` 循环（文件第 47 行）。它按守卫实际点名的那一行改。**请核这一点**：改的必须是被点名的那一条，文件第 30 行那条不该动。

## 必须自己做的（都很短）

1. `bash skills/teamsmith/tests/section-guard.sh --loop-check`：必须绿，且仍是「85 行清单 / 85 个 while+sleep 循环，配平 85 个」。贴原始输出。
2. `git diff main 1db1bc0c -- skills/teamsmith/tests/loop-inventory.tsv`：确认**只有一行**、改的是文件第 47 行那条、文件第 30 行（`smoke.sh 4688`，`${4:-50}`）**未动**；并确认 `smoke.sh`、`section-guard.sh`、扫描面相对 main **逐字节未变**。
3. **红侧**：在私有副本里把那行锚点再改错一处 → `--loop-check` 必须重新红并点名 `smoke.sh:6392`；还原后必须绿。
4. `--select 0e` 在候选上必须全绿（改前是 `✓42 ✗3`），贴读数与 rc。
5. 轻量收口：账本禁令固定验收行、`git diff --check`。

不要跑整套、不要跑容器、不要抢机器级门禁锁；只在自己的磁盘副本里造破坏。

## 边界与交付

只读代码、只写 `docs/team/reports/V77-dev-bob.md` 与自己的线程；不改实现、不合并、不 push。结论先写 PASS/PARTIAL/FAIL。local 模式。
