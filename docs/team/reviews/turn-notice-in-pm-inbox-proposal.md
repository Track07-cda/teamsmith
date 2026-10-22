# turn-notice-in-pm-inbox · PM proposal review

- 状态: **ACCEPTED**（附两条须在 apply 任务书里落地的要求，不影响提案本身）
- 提案: `openspec/changes/turn-notice-in-pm-inbox/`（P363 / dev2，报告 `docs/team/reports/P363-dev2.md`）
- 审查时间: 2026-10-22T07:1xZ · PM: pm

## Commands run (real output, not a promise)

```
$ cd .worktrees/dev2 && openspec validate --all --strict
Totals: 22 passed, 0 failed (22 items)

$ cp -r .worktrees/dev2/openspec /var/tmp/trial-p363/openspec && cd /var/tmp/trial-p363
$ openspec validate --all --strict && openspec archive -y turn-notice-in-pm-inbox
Totals: 22 passed, 0 failed (22 items)
Totals: + 1, ~ 2, - 0, → 0
Specs updated successfully.
Change 'turn-notice-in-pm-inbox' archived as '2026-10-22-turn-notice-in-pm-inbox'.
```

delta 结构：`MODIFIED` 两条（turn-end 通知的要求、原始事件明细文件的要求）+ `ADDED` 一条（敲门被跳过时的记录与 digest 点名）。
试归档投影 `+1 ~2 -0`，无退场要求。

## Findings (one line per checklist item)

1. **与已接受的问题一致** — 通过。提案的 Why 用的是 PM 实测的四条读数（`pm.md` 3 行全是 `[manual]`、`dev3.md` 当天 8 行 `[auto]`、P362 的 `sent seq=1275` 与「同一行不在 `pm.md`」、`/tmp` 日志已空），没有扩大也没有缩小。范围就是用户裁定的 B（记录放对地方），并把「不回填历史指针行」「不修敲门本身」写明。
2. **可观测** — 通过。新增 6 条 scenario 全部落在磁盘与命令上（`pm.md` 出现指针行、`state/notify.log` 恰好一条记录、待办总数为 1、`--ack` 清掉那一条、`pointer=failed` 进账并被 digest 点名）。每一条都能失败。
3. **覆盖闭合（两个方向）** — 通过。39 条任务项，段 1 对应 `MODIFIED` 第一条，段 2 对应新增要求，段 0/4 是共同前提与边界；没有孤立任务。红侧总表 `§3` 的 R1–R6 与 scenario 逐条对应。
4. **边界明确** — 通过（一处位置需改）。边界写在 `tasks.md §4` 而不是 `proposal.md`：不修敲门可靠性、不回填历史、身份守卫前被拒的不进账、`enqueued ≠ 已送达`、不新增配置键（因此无四面登记）。内容对，位置次优——**在 apply 任务书里把这一节抄进去**，别只留在 change 目录里。
5. **验收命令** — 通过。`openspec validate --all --strict`、`spec-refs.sh --check`、`--select 7,12f,13,13b,25,26,27,47,51` 都是既有命令；PM 已亲自跑过前两条与试归档。
6. **缺陷修复写出翻转** — 通过，且是本提案最强的一处：R1 到 R6 每条都写「把实现改坏 → 哪条断言必须红 → 还原」。特别是 R2（派生顺手改记录行 → 记录行字节对照红）与 R4（合并取新事件的 `knock=` → `enqueued` 的 run 被扩展后显示 `skipped:merged`），这两条正好守住了「记录行逐字节不变」与「run 级字段」这两个最容易糊掉的判据。
7. **与既有规格不冲突** — 通过，且我做了逐句比对：被 MODIFIED 的那条要求，主线里**每一行散文都逐字出现在 delta 里**（0 条丢失），delta 是超集（342 → 414 行、30 → 36 个 scenario，新增 6 个）。别处的平行陈述我也查了：`watchdog`/`dispatch`/`delivery-guard`/`meeting` 提到 knock 的地方都在讲别的语义（死亡席位、跨会话、会议敲门），没有与本 delta 冲突的平行要求。
8. **粒度** — 通过。它自己拆成 A1（写入面：记录行拆两步 + 指针行 + 一份计数）与 A2（结果账与显示面），顺序是 A1 → A2，verify 由非作者执行。两条 brief 各自可独立验收。
9. **一个任务一个 change** — 通过（待 apply 时落地）。提案声明了两条 brief 的写集；我会在 brief 里各写一行 `change: turn-notice-in-pm-inbox`，之后 `team change status` 必须把两者都列在这个 change 下、且不在别的 change 里。
10. **锚点存在** — 通过。两条 brief 都指向本 change（`change: turn-notice-in-pm-inbox`），delta token 为 `notify-and-inbox`（PM 已核：dispatch 只接受 capability token，`notify-and-inbox/spec.md` 会被拒——这是 P363 派单时当场撞到并改对的一处）。

## Required changes

无阻塞项。两条在 apply 时必须落地：

1. 两条 apply brief 各写**恰好一个** `change: turn-notice-in-pm-inbox`，并把 `tasks.md §4` 的边界抄进 brief（点 4 的位置问题）。
2. A2 改「一份计数」时要连带跑 `§25`（手工通知计数）、`§12f`（段头字面量）、`§51`（内部命令白名单）——提案已列，写进 brief 的验收命令，别让作者自己想起来。

## 为什么这份提案值得接受

它把「通知没到」这个模糊症状拆成了两个可判据的东西：**记录落在谁读的文件里**（到达性），和**跳过原因记在哪个盘上**（可追查性），并且刻意**不去修敲门本身**——因为敲门的可靠性受窗口状态影响，是环境，而记录的到达性可以是契约。这是这一轮里少见的「把契约放在能保证的地方」。
