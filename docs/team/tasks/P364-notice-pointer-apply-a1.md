# P364 · apply A1：记录行拆两步 + PM 指针行 + 一份计数

task: P364
agent: dev3
phase: apply
category: code
change: turn-notice-in-pm-inbox
specs: notify-and-inbox#A turn-end notification appends one inbox line and knocks once
anchor: none (infra) — change 自带 delta
deltas: notify-and-inbox
branch: task/P364-notice-pointer-a1
deps: 提案已 ACCEPTED 并进 main（`reviews/turn-notice-in-pm-inbox-proposal.md`）；P363 已关闭

## 只做 A1（A2 是 P365，别越界）

照 `openspec/changes/turn-notice-in-pm-inbox/` 的 `proposal.md` §1、`design.md` §1–§5、`tasks.md` 段 0 + 段 1 实现：

1. **写入面**：`team_inbox_write_locked` 拆出 `team_inbox_merge_or_append`，让「记录行」与「派生行」走同一段合并逻辑。
2. **指针行**：发送者不是 `pm` 时，除记录行之外往 `docs/team/inbox/pm.md` 写一条指针行（`agent:`/任务 token/
   `knock=<outcome>`/`see=`），**记录行逐字节不变**（形状、合并键、`:: 摘要`、`⚠ 未提交`、明细文件全部照旧）。
3. **一份计数**：`team_inbox_new` / `team_inbox_since` 共用同一判据 —— auto 类行的 `agent:` 指向该收件箱自己的席位时，
   它是记录不是未读流量。一次交付让待办 +1。
4. `knock=` 是 run 级字段（run 被扩展时保留首事件的值）。

## 必须交的证据

（`tasks.md §3` 的红侧总表 R1–R6 各给一条读数；下面是最低要求）

1. **R2 承重**：让派生顺手改记录行 → 记录行字节对照红；还原绿。
2. **R4**：改成取新事件的 `knock=` → `enqueued` 的 run 被扩展后显示 `skipped:merged`，必须红。
3. **R6**：记录判据改回去 → 「一次交付 +1 而不是 +2」那条红。
4. 实跑：`--select 7,13,25`（`§13` 的 F17 同 run 三事件、`§25` 的手工通知计数必须**不变**）。
5. 一次真 settle 的前后现场：`pm.md` 多一条指针行、`<seat>.md` 一行、`state/notify.log` **恰好一条**、`team digest`
   待办 = 1、`team inbox pm --ack` 清掉它。
6. 轻量收口：`bash -n`、`--loop-check`、`section-select.sh --check`、`openspec validate --all --strict`、
   `spec-refs.sh --check`、账本禁令、`git diff --check`。

## 边界（从 change 抄来，落地时不要靠记忆）

- **不修敲门本身的可靠性**：不改任何敲门分支的判据，只让每次 settle 的结果可读。
- **不回填历史指针行**；历史 `[auto]` 行升级后不再计入该席位的未读。
- 身份守卫之前被拒的 settle **不进账本**（那不是通知）。
- `enqueued` **不是**「已送达」（投递仍由 `state/outbox/delivered.log` 记账）。
- **不新增配置键**（沿用 `TEAM_NOTIFY_DETAIL_MAX`）；若实施中发现必须新增，**停下来报 PM**（那是四面登记，不在本 change）。
- 不碰 `§12f`/`§51` 的既有字面量与白名单；不碰产品面板以外的 UI 文案。
