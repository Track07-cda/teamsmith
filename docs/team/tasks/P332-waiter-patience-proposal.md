# P332 · 提案：合法的长时门禁不该让等待者失败

task: P332
agent: dev3
phase: propose
category: analysis
change: gate-waiter-patience
specs: verification#CI runs the two gates separately and performance does not block
deltas: verification
branch: task/P332-waiter-patience-proposal

## 问题（有实测，不是推测）

门禁的机器锁有三层耐心：等待者有一个上限 `W`（默认 30 分钟），持有者在记录里公布 `expected`（它预计还要跑多久），`gate_lock_cap` 用 `cap = clamp(expected − 已跑 + 60, W, 4W)` 把上限放宽。设计意图是：**合法的长时运行不该被等待者的固定上限误杀**。

`expected` 的生产者是 `gate_lock_expected`，它按预算表（`section-budgets.tsv`）求和。P316（`d92f0a17`）删掉了预算表——**顺便把 `expected` 的生产者也删了**，`smoke.sh:558/637` 现在传 `/dev/null`，于是 `expected` 恒为 0，`cap` 恒等于 `W`。

后果：一次合法的全量门禁（记录在案：一个席位曾持有锁 1 小时 16 分，路由变异 82 分钟，产品基线 35 分钟）会让**所有等待者按 30 分钟超时失败**。今天没撞上是运气——最近没有「长跑 + 有等待者」同时发生。P328 的清点把它找了出来（`docs/team/reports/P328-dev-bob.md` 动作 2）。

## 你要产出的东西

`openspec/changes/gate-waiter-patience/`（proposal / design / tasks / `specs/verification/spec.md` delta）。**只做规划，不写实现**。

## 方向（PM 已定，不许换成「把预算表接回来」）

等待者的耐心应当跟随**持有者的心跳**，而不是预算投影：

- 持有者已经每 N 秒写心跳（`heartbeat=` 字段，P281 落地）。**心跳新鲜 = 有进展** → 等待者继续等，上限抬到硬顶 `4W`。
- **心跳停止超过 `W`** → 判定持有者已卡死，等待者按今天的语义**大声失败并点名持有者**（保留 §34b①/⑦ 的行为与文案形状）。
- 没有任何心跳字段（旧写入者）→ 退回今天的 `W`，行为一字不改。
- 删掉 `expected`/`bound` 在 cap 计算里的角色（它们在记录里仍可写、仍可打印，只是不再决定耐心）。

## 规格要怎么改（只改一条）

`verification` 里与「排队 vs 运行」有关的 requirement（P281 那条：排队超时要与真正运行区分开）。请先用 `openspec instructions specs --change gate-waiter-patience` 看工具要求，**不要自己发明结构**；MODIFIED 块必须保留原场景（工具会拒绝丢场景，这是实测过的报错）。

## 硬约束

1. **净零**：这条变更必须**删掉** `expected` 在 cap 里的分支与它的合成断言（P329 只删了假的注释与几条自造数字断言），**不许**新增预算表、调度器、监测器、第二个等待机制。
2. **不许抬 `W` 或 `4W` 的默认值**；不许把 60 分钟的 CI 上限往上抬。
3. 红侧写进 tasks：心跳停 → 等待者必须失败并点名；心跳新鲜 → 等待者必须继续等（不许提前失败）；旧记录没有心跳 → 退回 `W`（逐字兼容）。
4. 与 P329 的写集冲突说明写进 design：P329 会先改 `gate-lock.sh` 的席位推导与 `smoke.sh` 的 cap 断言，本变更的 apply 排在它之后。

## 验收（propose 阶段）

```bash
openspec validate --all --strict          # 必须含本 change 且 20+1 通过
bash skills/teamsmith/tests/spec-refs.sh --check
git diff --check && git status --short
```
另外在**副本**上试归档一次（`/var/tmp` 下的 openspec 拷贝），证明归档后校验仍全过；把两条输出贴进报告。

报告 `docs/team/reports/P332-dev3.md`：先给结论（一个问题一句话），再给规格 delta 的四块（REMOVED/ADDED/MODIFIED/RENAMED 的取舍与理由），最后写「未知项」。PM 复核后才准实现。
