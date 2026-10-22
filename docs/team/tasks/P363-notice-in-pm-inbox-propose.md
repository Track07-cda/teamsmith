# P363 · propose：让「通知」不再依赖「敲门」

task: P363
agent: dev2
phase: propose
category: analysis
change: turn-notice-in-pm-inbox
specs: notify-and-inbox#A turn-end notification appends one inbox line and knocks once
anchor: none (infra) — change 自带 delta
deltas: notify-and-inbox
branch: task/P363-notice-in-own-inbox-propose

## 用户报的缺陷（PM 已复现，证据在下面，不要重新论证"是不是问题"）

> 「我最近经常发现子任务做好了没有自动通知 pm 的情况。」

实测证据（都在本仓）：

- `docs/team/inbox/pm.md` 今天只有 **3 行，全是 `[manual]`**；历史 `[auto]` 行仅 2 行。
- 各席位**自己**的收件箱今天新增 `[auto]` 行：`dev3.md` 8 行、`verify.md` 4 行。
- 具体样本：P362 在 `2026-10-22T05:42:38Z` 生成了 `[auto] agent:dev3 · P362 …`，写在 **`dev3.md`**，
  PM 投递日志有 `sent seq=1275`（那一次敲门到了）；同一条通知**不在 `pm.md`**。
- 代码位置：`skills/teamsmith/extension/team-notify.ts` 写盘时调
  `__inbox-write --agent <发送者>` → 落在**发送者自己**的收件箱（`550005fc` 之前的老实现也是这样：
  `appendFileSync(join(dir, agent + '.md'))`）。
- 跳过路径（全部只写日志，不通知任何人）：`suspended`、`writeState != new`（合并或写盘失败）、
  `pane_current_command` 不是 pi、PM 窗口不在、20 秒去重、以及「回合未完成 + 本轮有 lifecycle 事件」。
- 那些日志默认写 `TEAM_NOTIFY_LOG=/tmp/teamsmith-notify.log`，而 `/tmp` 是本机内存盘、已被清 ——
  **现在一行都没有**，所以"今天跳过了几次、为什么跳"事后无法回答。

结论：**通知是否到达 PM，完全取决于那一次敲门有没有被跳过**；敲门丢了，行还在磁盘上，但不在 PM 读的地方。
`team digest` 的「待复验」能捞回**有报告**的任务，捞不回没有报告的中间进展。

## 这次要设计的东西（方向已定，细节你决定）

用户裁定走「B · 把记录放对地方」：**通知与叫醒解耦** —— 敲门只是提醒，记录必须落在 PM 会读的地方。

必须覆盖：

1. **`pm.md` 要有指针行**：每条 turn-end 通知在 PM 的收件箱里留下一行（谁、任务、状态类、以及"明细在哪"）。
   发送者自己那份 `inbox/<seat>.md` **保持逐字节不变**（现有合并规则、断言、面板、digest 全依赖它）。
2. **不许刷屏**：PM 的指针行必须跟发送者那份同一套「同类合并」语义（同 run 合并成一行，计数与窗口照旧），
   并且**不能**让 `team digest` 的「待处理通知」把同一条通知数两遍。数一遍的方案由你定（例如指针行带明确标记，
   digest 只认其中一份），但必须写清判据与它的红侧。
3. **敲门丢了也要看得见**：跳过原因写进**项目内**（`state/` 下、gitignored），并且 `team digest`（或 `doctor`）
   报一行「本轮有 N 条通知已记录但未敲门（原因分类）」。`/tmp` 不再是唯一落点。
4. **不改变已有的敲门语义**：`suspended` 只记录不叫醒（用户 2026-10-14 的裁定）照旧；交付与中断照旧敲门；
   去重窗口、合并键、`:: <末消息>` 摘要、`⚠ 未提交` 标记都不许动。

## 提案要交的

`openspec/changes/turn-notice-in-pm-inbox/`：`proposal.md`（问题、选项与取舍、为什么选这条）、
`specs/notify-and-inbox/spec.md`（delta：改哪条要求、新增哪条；**已有的 Knock/suspend/去重语义一字不改**）、
`design.md`（指针行的形状、合并与去重的判据、digest 怎么只数一遍、日志落点与轮转/上限）、
`tasks.md`（apply 的步骤，含每条的红侧）。

`openspec validate --all --strict` 必须绿；`spec-refs.sh --check` 通过。

## 边界

- **只规划，不写实现**（不碰扩展代码、不碰 `smoke.sh`、不碰 CLI）。
- 引用规格时用 `capability#Requirement` 的全名；证据引用用本任务书里的路径与时间戳，不要新增特权路径。
- 报告：`docs/team/reports/P363-dev2.md`，先给"我改哪几条要求、新增哪一条"，再给选项取舍。
