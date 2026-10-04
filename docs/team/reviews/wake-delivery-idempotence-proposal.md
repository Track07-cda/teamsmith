# wake-delivery-idempotence · PM proposal review

time: 2026-09-22T20:2xZ · reviewer: pm · verdict: **ACCEPTED**

```
change:  wake-delivery-idempotence（P71，propose=verify）
tip:     （P71-propose）· validate 29/29
firsthand: D45 追记的三次现场（PM 自己被一条 2 小时前的 nudge 叫醒两次；.seen 里已有该文本；
           巡逻未再生成、outbox 未再发送、spool 截断后 rescan `deliver=0`）
```

## Findings

1. **投递日志 = 唯一 durable 权威**（`state/inbox-watch/<key>.deliver`，append-only），**绝不用进程内存** ✓
2. **顺序与 fail-closed**：`read`（记行身份 + 将要投递的材料 + 偏移/大小/头指纹）→ `intent` → `sent`/`failed`；
   **`intent` 没写成就绝不许发**；日志写不进去 → **什么都不发**、账本记 `deliver blocked`、行留作未读 ✓
   —— 方向选对了：**宁可晚投，不许无据投递**。
3. **重启后的三态判定**（正是我现场的形状）：`read` 无 `intent` → **允许且只允许一次**恢复投递（记 `recovery`）；
   `intent` 无 `sent`/`failed`（**含损坏的尾记录**）→ **永不重投**、记一次 `inflight assumed n=<n>`（至多一次）；
   `sent` → 永不重投 ✓
4. **`failed`**（API 拒绝）→ 允许重试，**每拍至多一次**，且**不得越过新鲜度地平线** ✓
5. **不可证明 ⇒ 不唤醒**：身份早于日志的淘汰下限 → **永不重投**，记 `unprovable` ✓（fail-safe，不是 fail-open）
6. **收件方可自证**：唤醒必须**点名它的源行**（我要求的那条）✓；日志本身**有界且可审计** ✓
7. **delta**：`notify-and-inbox` ADDED ×3（5/2/3 场景）+ MODIFIED ×2（base 3→4、3→5，**一条没丢**）✓
   两条 MODIFIED 正是我要的"旧行只进收件箱不唤醒"与"账本区分新流量与恢复"。

## 结论

**ACCEPTED**。apply 排队（等席位）；apply 时逐条兑现：fail-closed、三态、`failed` 的重试上限、
`unprovable` 的不唤醒、以及"源行点名"；红/绿两侧都要有原始输出（尤其"杀掉投递进程后重启"的形状）。
