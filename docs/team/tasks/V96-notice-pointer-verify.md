# V96 · P364（A1）的独立验收：指针行真的落进 PM 读的地方，且一条通知只数一次

task: V96
agent: verify
phase: verify
category: verify
change: turn-notice-in-pm-inbox
specs: notify-and-inbox#A turn-end notification appends one inbox line and knocks once
anchor: none (infra) — change 自带 delta
deltas: notify-and-inbox
branch: task/V96-notice-pointer-verify

## 受检

候选 `c1a0f6d5`（报告 `docs/team/reports/P364-dev2.md`）。它声称三件事都落地：发送者那行**逐字节不变**；PM 收件箱
多一条指针行（`agent:` · 任务 · `knock=` · `see=` · 修订戳）；`knock=` 是 run 级字段；一条通知**只数一次**。

自跑读数：`--select 6,7,13,25` = `271 ✓ / 0 ✗`；`--select 60,12f,26,27,47,51` = `356 ✓ / 0 ✗`。
它另报一条 `BLOCKED`：任务书的 `--select 7,13,25` 在 §13 红，**基树 `9170e36f` 上同样红**——声称是选段表
`13 needs 2` 的既有缺口（§13 夹具无条件要求 `$REPO/.worktrees/dev`，只有 §6 创建它）。

## 要回答的四件事

1. **到达性（本 change 存在的理由）**：自己造一次 settle（`TEAM_NOTIFY_TMUX=0`），读三个地方：发送者收件箱
   **多且只多一行**、`pm.md` **多一条指针行**且带 `see=`、`state/notify.log` **恰好一条记录**。然后 `team digest`
   的待办数 **= 1**（不是 2），`team inbox pm --ack` 能清掉它。**这一条是整个变更的承重**。
2. **记录行逐字节不变**：同一场景下，把候选的记录行与 `main` 产出的记录行 `cmp`（同输入）；
   再按 R2 反向——让派生顺手往记录行里塞 `see=` → 断言必须红。
3. **一份计数没有把我自己的收件箱算错**：`team inbox`（不带参数）在**席位自己**那份上仍能显示它有记录
   （记录不是隐形的），但**不算未读流量**；`team digest` 的合计与 `team inbox pm` 一致。
4. **那条 BLOCKED 站得住吗**：自己核 `--select 13` 在**基树**（`git show 9170e36f` 的检出或你直接 checkout 那个提交）
   上是否同样红、红的是不是同一族行；若是，判定「不是本改动引入」成立，并**指出修法该落在哪**（选段表补 `needs`）。
   若基树上其实绿，那么候选引入了一处真回归，必须点名。

## 边界

只读代码、破坏只在 `/var/tmp` 私有副本、只写 `docs/team/reports/V96-verify.md` 与自己的线程。**不跑整套**；
`--select` 只跑点名的那几段 + §13 的对照。结论先写 PASS/PARTIAL/FAIL，并单列「必须修」与「记录在案」。
