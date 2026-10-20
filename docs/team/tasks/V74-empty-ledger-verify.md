# V74 · P333 的独立验收：空清单不再假装「无法裁决」，跳过分枝仍有影子

task: V74
agent: verify
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 门禁里一行提示与它的影子
deltas: -
branch: task/V74-empty-ledger-verify

## 受检

候选 `3291bf05`（4 个提交），报告 `docs/team/reports/P333-dev3.md`。改动只有两处：`smoke.sh` §58 的条件（多一条「登记条数 ≥ 1」）与注释；`checkout-shape-probe.sh` ⑩ 的两条断言翻成新期望，另加一条影子 `po10shadow`。

要回答三件事：**（一）空清单时那行假提示真的没了、判定仍照跑？（二）跳过分枝还有没有影子钉着？（三）这次改动有没有顺手把别的断言放松？**

## 必须自己做的

1. **空清单形状**：私有磁盘目录里的独立检出（`git clone` 或 copytree，`TMPDIR` 指到磁盘、私有锁），把 `signal-lint-legacy.txt` 置成**只有注释、零条登记**，跑一次 `bash skills/teamsmith/tests/smoke.sh --select 58`。要求：**不出现** `SKIP（条件不满足） 58 lint 真树`、**出现** `✓ 58 lint 真树：…（0 个历史豁免文件…）`、段尾 SKIP 计数不含那一条、整段 rc=0。贴原始尾部。
2. **跳过分枝的影子还在（关键）**：同一棵树，往清单里加**一条**「落在内部面且不在检出里」的登记 → 再跑同一次 `--select 58`：必须**重新出现**那行 SKIP 并点名冻结的证据层。**这一条不过就是假绿**：说明退役时把整条分支一起丢了。
3. **牙齿还在**：私有副本里在 `tests/` **之外**种一条 `pkill -f v74-planted`（`tests/**` 的违规必须真修，不许豁免），清单置零条 → §58 必须**红**并点名 `file:line`。
4. **反例（证明新断言会咬人）**：在私有副本里把 `smoke.sh` 那条条件改回旧写法（不加「登记条数 ≥ 1」）→ 探针 ⑩ 的新断言必须**变红**。可以只跑探针（见下），或直接判读 `--select 58` 的输出差异，按你能做到的最小代价做，并说清你用的是哪一种。
5. **探针读数**：跑**一次** `bash skills/teamsmith/tests/checkout-shape-probe.sh`（作者记录 657.7 s、`ok 147 bad 0 skip 0`；你要自己跑，别抄）。若机器负载 > 0.75×核数就先等或换时机并在报告里写清环境——那是**前提**，不是判据。
6. **没有顺手放松**：`git diff main 3291bf05 -- skills/teamsmith/tests/checkout-shape-probe.sh` 里逐条核对：⑩ 只应有你看到的「两行翻新 + 一条影子」，其余断言（`--select 58` 退出 0、lint 照跑、红数为 0、内部树 LEGACY、牙齿三例）**逐字未动**；`smoke.sh` 只应有 §58 的条件、计数变量与注释。
7. 轻量收口：`bash -n`、`section-select.sh --check`、`openspec validate --all --strict`、账本禁令固定验收行、`git diff --check`。

全程只在自己的磁盘目录里造破坏；跑之前 `ps` 确认没有别人的 `smoke.sh` 在跑；不要抢机器级门禁锁、不要跑整套门禁、不要碰别人的现场。

## 边界与交付

只读代码、只写 `docs/team/reports/V74-verify.md` 与自己的线程；不改实现、不合并、不 push。结论先写 PASS/PARTIAL/FAIL，再给命令、rc、原始尾部；没跑的如实写「未验」。local 模式，PM 合并与关单。
