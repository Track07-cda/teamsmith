# V89 · P354 的独立验收：删掉的 13 个真的一个都跑不到吗

task: V89
agent: dev
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 夹具处置
deltas: -
branch: task/V89-dead-fixture-disposal-verify

## 受检

候选 `0256880c`（19 个文件、`+259/−2793`），报告 `docs/team/reports/P354-dev3.md`。删 13 个夹具文件、改 `signal-gate.sh` 一处注释、把 5 个改成「人工验收工具」并写进文档、同步循环清单（86→82 行）。

## 判据（写死）

**只要有一个被删文件今天仍能被执行到，就是 FAIL。**

## 要自己做的

1. **自己重扫可达性**（别抄它的表）：对那 13 个被删文件名，在**当前候选树**上找有没有任何执行路径：
   - `smoke.sh` 段正文的调用（含变量拼接、`--select` 生成的脚本）；
   - `.github/workflows/*.yml` 里的内联命令串；
   - 任何保留下来的 `.sh`/`.mjs`/`package.json` 脚本对它们的调用（要追到根：那个调用者自己有没有执行路径）。
   给出一句话结论 + 你用的命令。
2. **墓碑表核对**：13 个逐个核「守什么 → 今天谁守 → 删在哪个提交」，抽 4 个验证「今天谁守」那一列是否成立（能指出具体段号并通过 `--select` 看到那段真的跑那条断言/探针）。
3. **没多删、没少删**：`git diff --name-status main 0256880c` 里删除的恰好是那 13 个；`tests/*.sh` 计数从 64 到多少与报告一致；`panel-b3.sh` 与五个保留项逐字节未变（给 blob 或 `git diff` 空）。
4. **自检没被删坏**：`section-select.sh --check`、`section-guard.sh --loop-check`（82/82）、`bash -n` 对保留夹具、以及 `--select 40` 一次（约 4 分钟）。贴读数与 rc。
5. **残留指针**（作者自报的 BLOCKED）：`smoke.sh` 8 行 + `extension/team-inbox-watch.ts` 2 行仍指向已删文件。核这个事实（数出确切行号与原文），并判断它属于「假指针必须修」还是「历史叙述可以保留」。

## 边界

只读代码、只在 `/var/tmp` 私有副本里造破坏、只写 `docs/team/reports/V89-dev.md` 与自己的线程；不改实现、不合并、不 push。不跑整套。结论先写 PASS/PARTIAL/FAIL。local 模式。
