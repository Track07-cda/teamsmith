# V91 · P349 的独立验收：夹具接进来了，且地板里真的没有它

task: V91
agent: dev
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 门禁接线
deltas: -
branch: task/V91-panel-b3-wiring-verify

## 受检

候选 `dee07d3b`（相对 main 三个文件：`smoke.sh` §38 新腿、`section-paths.tsv` 一行、报告），`docs/team/reports/P349-dev2.md`。`panel-b3.sh` 声称与 main 同 blob。

作者读数：`--select 38` → `38-i` 跑起来（1213 s）；`--floor` 单跑 → 具名 SKIP（381 s）；红侧改坏一条断言 → rc=1 点名那 7 条。

## 要回答的四件

1. **它真的会被跑到（这是整个任务的意义）**：`--select 38` 里 `38-i` 出现 ✓231 ✗0（或作者报告里的数字），贴段尾。**一次就够**，不要跑两遍。
2. **地板里没有它**：`--floor --select 38`（或作者给的等价调用）里必须出现 `38-i` 的**具名 SKIP（条件不满足）**，而不是执行它；贴那一行。**不要**跑整轮 `--floor`（那是 88 分钟）。
3. **夹具没被改、段数没涨**：`git rev-parse dee07d3b:skills/teamsmith/tests/panel-b3.sh` 与 main 同 blob；`section-select.sh --check` 段数仍 135、`--loop-check` 83/83；新增/改动的循环若有时限，必须在清单里。
4. **红侧（承重）**：私有副本里把那 7 条里的任意一条改坏（或删掉一个车道让判据不成立）→ 同一次选段必须 **rc=1 并点名**；还原必须绿。用 `P349_SUITE` 指向你的副本，**不要改源树**。

## 边界

只读代码、只在 `/var/tmp` 私有副本与私有 `TMPDIR`/锁里跑、只写 `docs/team/reports/V91-dev.md` 与自己的线程。不跑整套、不跑容器、不抢机器级门禁锁。注意 `38-i` 一次要 20 分钟上下。结论先写 PASS/PARTIAL/FAIL。
