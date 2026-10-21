# V86 · P346 的独立验收：切片真的无损吗，并集断言真的有牙吗

task: V86
agent: dev
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — CI 分片
deltas: -
branch: task/V86-shard-parallel-verify

## 受检

候选 `1a54477c`（五个提交），报告 `docs/team/reports/P346-dev2.md`。改动：`section-select.sh`（`--slice k/N` + `--check ⑨`）、`smoke.sh`（参数透传与选段头，约 30 行）、新文件 `tests/slice-coverage.sh`（coverage 作业的逻辑）、`.github/workflows/gates.yml`（矩阵 + coverage 作业）。

它自报的两个风险：**第 4 片估算 45.4 分（离 60 分上限只剩 15 分）**，以及**矩阵在本仓从没真跑过**（`strategy.job-total` 等是 GitHub 文档行为）。

## 要回答的五件事

1. **并集真的无损**：自己算四片的 own key 集合，与 `--floor` 逐字比对（给 `comm` 空输出与 128/128 计数）。**再自己挑两个 N**（例如 3 与 6）重复一次——规则说它对任意 N 成立，你要验这句。
2. **`--check ⑨` 的三条断言有牙**：在私有副本里把哈希退化成「全落第 1 片」→ 必须红并点名；再让切片依赖段号（位置）→ 也必须红（证明它守的是「规则只依赖 key」）。
3. **coverage 作业真的会红**：`slice-coverage.sh` 在「某片清单缺失」「某片清单被收窄一段」「某片作业失败/取消」三种情形下各跑一次 → 都必须 rc≠0 并逐个 `::error::` 点名缺的段。这是整个方案最承重的一层，别只看代码。
4. **`smoke.sh` 只加管线没改断言**：diff 里不该出现任何段内断言的增删改；`slice`/`all` 不算「改动直接点到」这一点要核（它关系到地板不被意外拉长）。
5. **两个自报风险的判断**：45.4 分这个估算你认可吗（按同一份段账本自己加一遍）；「矩阵没真跑过」在第一次真跑时可能怎么坏（给三条：作业数不是 4、`needs` 语义、失败分片是否阻止 coverage 判定）。

## 边界

只读代码、只在 `/var/tmp` 私有副本里造破坏、只写 `docs/team/reports/V86-dev.md` 与自己的线程；不改实现、不合并、不 push、**不触发远程 CI**。跑选段可以（FAST 档），但不要跑整套。结论先写 PASS/PARTIAL/FAIL，并对「45.4 分是否可接受 / N 该不该改」给一句建议。local 模式。
