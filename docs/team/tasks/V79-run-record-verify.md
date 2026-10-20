# V79 · P339 的独立验收：登记的生命周期从它可见那一刻起算

task: V79
agent: verify
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 门禁登记的退出清理
deltas: -
branch: task/V79-run-record-verify

## 受检与它治的病

候选 `1eaeafd1`（实现 `11a81632`，`smoke.sh` +26/−8），报告 `docs/team/reports/P339-dev3.md`。

作者查明 §34b⑫ 的时红时绿是**真竞态**：运行登记在 `:678` 写出、删除它的 EXIT trap 到 `:1393` 才装好，中间七百行（临时根、运行指纹、段落守卫、tmux 隔离）里落一个 TERM/INT，进程按默认动作退出、登记再没人删。它的受控探针很干净：**早发信号 5/5 留下、晚发信号 5/5 消失**（同一现场只改发信号时刻）。

改法两处：登记**之前**先武装一个只删自己那条的最小 EXIT trap（`cleanup` 装好后调同一个函数，幂等）；§34b⑫ 的判据从「等 300 秒」改成「`wait` 返回后即时检查，容差 5 秒」。

## 必须自己做的

1. **受控探针（承重）**：自己写一个探针，对一次 `--select 34b`（或更小的 `--select 34c`）的进程在**前导窗口内**（登记已写出、`cleanup` 还没装）发 TERM，然后看 `<lock>.runs/` 里那条登记的去向。对**候选**与**`main`** 各跑 3～5 次：`main` 应当留下（复现），候选应当 0 留下。贴每次的 `left=` 与 pid 存活读数。
2. **一个坑要点名**：自检出口（`SMOKE_LOCK_SELFTEST_CHILD`）现在显式把 `SMOKE_LOCK_RECORD=0`，**故意**留下登记，因为 §34b② 要读「顶层运行也在 `.runs/` 登记自己那条」。请确认这个「故意」不会把 ⑫ 弄成假绿（即 ⑫ 的现场里不会有那条故意留下的登记），并跑一次 `--select 34b` 的 ② 与 ⑫ 两条断言，贴读数。
3. **判据没有放宽**：读 ⑫ 的新判据，确认它等的仍是「`.runs/` 里一条不剩」，只是把「等 300 秒」换成「`wait` 返回后即时检查 + 5 秒容差」；**不许**出现「最终会消失就行」这种写法。
4. **红侧**：在私有副本里把 `_smoke_lock_drop_run_record` 改成 `return 0` → ⑫ 必须**稳定红**（连跑两次）；还原必须绿。
5. **稳定性**：`--select 34b` 连跑五遍（顺序、自有 `TMPDIR`、私有锁），五遍全绿，贴五次段尾。
6. **没有波及别的锁段**：`--select 34,34c,34d` 一次全绿（作者读数 `✓191 ✗0`），你自己跑一遍。
7. 轻量收口：`bash -n`、`section-select.sh --check`、账本禁令固定验收行、`git diff --check`。

跑之前 `ps` 确认没有别人的 `smoke.sh`；不要跑整套、不要跑容器、不要抢机器级门禁锁。

## 边界与交付

只读代码、只写 `docs/team/reports/V79-verify.md` 与自己的线程；不改实现、不合并、不 push。结论先写 PASS/PARTIAL/FAIL。local 模式。
