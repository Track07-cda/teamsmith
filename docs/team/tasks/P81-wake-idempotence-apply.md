# P81 · wake-delivery-idempotence apply（投递日志 + 至多一次 + fail-closed）

```
task:   P81
agent:  （等席位）
issue:
change: wake-delivery-idempotence        # 提案已验收：docs/team/reviews/wake-delivery-idempotence-proposal.md
specs:  notify-and-inbox#A wake is at most once: the delivery record is written before the send and survives a restart / notify-and-inbox#A wake names its source line so a recipient can prove what it is / notify-and-inbox#The delivery journal is the only dedup memory, and it is bounded and auditable / notify-and-inbox#Only fresh lines wake the session; stale lines stay silent and countable / notify-and-inbox#The ledger separates new traffic from recovery
phase:  apply
anchor: change
deltas: notify-and-inbox
grant:  skills/teamsmith/extension/team-inbox-watch.ts · skills/teamsmith/scripts/lib/{outbox,common}.sh · skills/teamsmith/tests/team-inbox-watch-harness.mjs · skills/teamsmith/tests/smoke.sh（append-only）· skills/teamsmith/references/{agent-adapters,troubleshooting,config}.md
deps:   P71（propose，已合并）· P28（偏移/重放/新鲜度的前一轮，已归档）· P76（合并前查未入账记录，并行中，注意别撞文件）
status: todo（等席位）
budget: 一个工作块
```

> 本地模式：不 push。**真源 = `openspec/changes/wake-delivery-idempotence/{design.md,tasks.md}`。**

## 硬要求（验收逐条查）

1. **fail-closed**：`intent` 没写成就**绝不许发**；日志写不进去 → **什么都不发** + 账本 `deliver blocked` + 行保持未读。
2. **三态判定**（重启后）：`read` 无 `intent` → **恰好一次** `recovery`；`intent` 无 `sent`/`failed`
   （**含损坏尾记录**）→ **永不重投** + 记一次 `inflight assumed n=<n>`；`sent` → 永不。
3. **`failed`**：每拍至多一次重试，且**不得越过新鲜度地平线**。
4. **`unprovable`**：早于日志淘汰下限的身份 → **永不唤醒**，计数可见。
5. **源行点名**：每条唤醒都带它的源行身份（收件方可自证"这是哪一条"）。
6. **红/绿两侧**：① 投递后立刻 `SIGKILL` → 重启 → **恰好一次恢复**（不是两次）；② `intent` 后 `SIGKILL` → 重启 → **零重投**；
   ③ 日志不可写 → 零投递 + `deliver blocked`；④ 旧行（>900s）→ 不唤醒但可计数；⑤ 真新消息照常唤醒。
7. **零回归**：`openspec validate` + FAST + 全量 smoke；不得放宽既有投递守卫（M24/M30/M45/P28 的断言）。
