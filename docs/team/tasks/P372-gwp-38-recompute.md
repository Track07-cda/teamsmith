# P372 · `gate-waiter-patience` 3.8：「每轮重算」的可证伪验证（不用墙钟）

task: P372
agent: dev2
phase: apply
category: code
change: gate-waiter-patience
specs: verification#A waiter's patience follows the holder's heartbeat, not a budget nobody publishes
anchor: none (infra) — change 自带 delta
deltas: verification
branch: task/P372-gwp-38-recompute

## 这是清单里唯一一条「实施阶段未解决」的缺口

`openspec/changes/gate-waiter-patience/tasks.md` 的 `3.8`：合同要求等待者**每轮重算**耐心，而「排队时缓存一次」
是错误实现；V68 审阅当时把它记成「实施阶段解决」，P338 交付时给了喂值证据（`§34b` 的 12 条分支表），
但**清单里这条仍空着**——因为还缺一条**针对「缓存」这个错误实现**的反例：让实现真的缓存，断言必须红。

## 要做的（一处，最小）

1. 在既有夹具里（`§34b` 的 stalled 现场形状，**不新建夹具**）加一条**直接针对缓存实现**的反例：
   拿同一份「等待状态」在两个不同的「现在时刻」求值，中间让心跳内容更新一次 →
   - 每轮重算：后一次给出的截止**更晚**；
   - 排队时缓存：两次相同 → **这条断言必须红**。
2. **红侧承重**：在私有副本里把 `gate_lock_patience` 改成「第一次算完就缓存」→ 你新加的那条必须红并点名；
   还原必须绿。**不许**用秒数或 `sleep` 做判据（这是本 change 反复强调的）。
3. 把它登记进 `tasks.md` 的 `3.8`（**不要**自己勾，勾由 PM 做；只把证据写进报告）。

## 验收

`--select 34,34b`（逗号）在候选上全绿；`--check`、`--loop-check`、`openspec validate`、`spec-refs`、账本禁令、`git diff --check`。
不跑整套、不跑容器、不抢机器级门禁锁。

## 边界

写集：`skills/teamsmith/tests/smoke.sh`（只在 `§34b` 已有的分支表/现场里加，**不新增段**）、报告。
不改 `gate-lock.sh` 的产品实现（除了在私有副本里做红侧）。
