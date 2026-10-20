# P346 · apply：地板切片并行（稳定哈希切分 + 三层并集断言）

task: P346
agent: dev2
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — CI 的分片
deltas: -
branch: task/P346-ci-shard-parallel
deps: P342、P344 已并入 main（它们都改 `smoke.sh`，单写者：等它们落地再派）

## 已被裁定的三件事（照做，不要重新设计）

1. **切片键 = 段 key 的稳定哈希**：`shard(key) = cksum(key) % N`。**不许**用段号/位置轮转（表里插一行会让「第 k 片」指不同的段）。
2. **N 只有一个来源**：workflow 矩阵长度（`strategy.job-total`），命令行写 `--slice ${{ matrix.slice }}/${{ strategy.job-total }}`；别处不许出现第二个字面量。
3. **「各片 own 的并集 == 地板」是 CI 里的一个独立作业**，不是文档里的一句话。

## 要实现的

- **选择器**（`skills/teamsmith/tests/section-select.sh`）：新开关 `--slice k/N`，与现有决策正交（`--floor`、`--paths`、无决策的全集都能加）。它做四件事：校验 `1 ≤ k ≤ N`、按规则算全部分片、把本片自己的段与「为 needs 从别片借来的段」分两类打印、把本片 key 清单（**own 的，不含借来的**）写到 `--out` 同级的一个 `.keys` 文件供 CI 收集。
- **`--check` 新一条**：对 `N ∈ {2,3,4,5,6,8,12}` 断言分片是地板的**精确划分**（无重复、无遗漏、无空片），并断言表里每行的 key 都能被哈希。这条与 N 无关，抓的是「哈希退化成全落一片」这类错误。
- **workflow**（`.github/workflows/gates.yml`）：把门禁作业改成矩阵（建议 4 片），每片跑 `--floor --slice k/4`；新增 `coverage` 作业 `needs: [gates]`、`if: always()`、**不** `continue-on-error`，它下载各片 `.keys`、与自己的重算逐字比对、断言并集 == 地板、缺的段逐个 `::error::` 点名、任一片失败或被取消就红。矩阵长度只写在矩阵里。
- **不动**：60 分作业上限、`61b`（D147 已把它留在合入/里程碑/发布的全量与自己的显式入口）、任何段的断言。

## 必须交的证据

1. 本地四片各跑通（`--floor --slice 1/4` … `4/4`）：四份 key 清单的并集与 `--floor` 的 key 集合**逐字相同**（给 `comm`/`diff` 的空输出 + 计数）。
2. 平衡读数：四片各多少段、按今天的实测时长估算各片分钟数（参考值，不设门槛）；某片明显偏重就说清偏多少、以及你为什么不改规则（平衡靠测量，不靠契约）。
3. `--check` 在 N∈{2,3,4,5,6,8,12} 全绿；**红侧**：把哈希换成「`% 1`」或按位置轮转 → `--check` 必须红并点名。
4. 负例：喂 `--slice 0/4`、`--slice 5/4`、`--slice 1/0` → 必须拒绝（rc≠0）并说清原因；`--slice` 与 `--paths` / 无决策组合各跑一次。
5. 一个「某片被取消」的模拟：让 coverage 作业的并集断言缺一片 → 必须红并点名缺的段（可以只在本地用桩验证那段逻辑，不必真跑 CI）。
6. 轻量收口：`bash -n`、`section-select.sh --check`（含新一条）、账本禁令固定验收行、`git diff --check`。

不跑整套门禁、不跑容器、不触发远程 CI（工作流只在本地改，推不推由 PM 定）。
