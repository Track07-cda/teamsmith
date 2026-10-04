# watch-degradation · PM proposal review

time: 2026-09-21T03:5x:00Z · reviewer: pm · verdict: **ACCEPTED**

```
change:  watch-degradation
owner:   verify（propose，模型 openai-codex/gpt-5.6-terra:xhigh）
tip:     e5b35f3（task/M52-inotify-propose）
```

## Commands run

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict   → Totals: 17 passed, 0 failed
$ git -C .worktrees/verify status --porcelain | wc -l            → 0
```

## Findings

1. **事故被正确地一般化 — PASS。** 提案不是"给夹具打补丁"，而是把**"监视器注册不上"**当成产品状态建模：
   R1 失败要带 **errno + 配额用量（能读就读，读不到写 `unknown`）+ 轮询间隔** 落进**持久记录** `state/inbox-watch/<key>.degraded`
   （D2：不放进 `.skip`、也不靠解析账本 —— 真源唯一）；D3 规定账本行的**唯一形状**。
2. **兜底是"被证明的保证"，不是"碰巧还在跑" — PASS（这是本提案最关键的一条）。**
   D4 用**强制失败**（显式夹具旋钮，且**旋钮会把自己标记为 forced**，见 R1 的 scenario）证明：
   失败路径上**轮询计时器仍被安装**，新 spool 行在**一个轮询周期内**仍会唤醒一次；
   并断言这条兜底唤醒**不是新的消息形状**（不改变对外语义）。
3. **测试能分辨"环境"与"代码" — PASS。** R6：夹具打印**可见的 unavailable 前提**；
   同时**保留严格模式**（同一前提在 strict 下仍判红）→ 既不再把宿主配额耗尽误判成回归，也没有把断言改成恒真。
4. **可见性落到两个已有的消费者 — PASS。** `panel` 的投递警告覆盖"降级唤醒通道"，且**给这类单独措辞**
   （不与其它 warning 混同）；`watchdog` 要求 **`team doctor` + `team status`** 报出"活的降级通道"，
   并明确 **"陈旧记录不算证据"**、**"健康时保持安静"** 两条反向 scenario。
5. **`team doctor` 的 inotify 余量按探针判，不按计数猜 — PASS。** D5 + 四条 scenario：
   合法配额与探针结论都报；余量低时给**警告 + 修法**；**探针注册失败本身是可见警告**；
   **没有运行时时明确说"unavailable"，绝不报 ok**。
6. **边界守住了 — PASS。** Non-Goals 明写不动默认轮询周期/兜底节奏、消息形状、spool 格式与去重；
   提案里**没有**任何需要特权的动作（提高 `max_user_watches` 只写进文档，符合我的任务书要求）。
7. **delta 落点有表 — PASS。** D1 把 7 条 requirement 分派到 `notify-and-inbox` ×3、`watchdog` ×2、`panel` ×1、
   夹具那条并入 `notify-and-inbox`（`verification` 不再需要单独 delta）——与我任务书里的 `deltas:` 行一致。
8. **批次与翻转齐 — PASS。** B1（记录+兜底证明）/B2（doctor+status+面板措辞）/B3（余量探针）/B4（门禁前提与严格模式），
   每批带 S22/S23/S24… 与 F-A/F-B/F-E 一类**双向翻转**。

## 交 apply 时我会盯的三点

- **旋钮的自我标记**：forced 失败必须在账本/记录里标明是"强制"，否则未来的读者会把测试事故当成真实事故；
- **轮询兜底的可证伪性**：不许只在提案里承诺——apply 的夹具必须真的把轮询周期压到秒级并观测到一次唤醒；
- **doctor 的措辞**：降级 ≠ 故障，警告要给出**修法**（配额或探针），并且**不能**在健康时刷屏。
