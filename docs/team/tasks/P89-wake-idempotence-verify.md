# P89 · wake-delivery-idempotence 独立验证（verify 阶段）

```
task:   P89
agent:  dev
issue:
change: wake-delivery-idempotence
specs:  notify-and-inbox#A wake is at most once: the delivery record is written before the send and survives a restart / notify-and-inbox#A wake names its source line so a recipient can prove what it is / notify-and-inbox#The delivery journal is the only dedup memory, and it is bounded and auditable / notify-and-inbox#Only fresh lines wake the session; stale lines stay silent and countable / notify-and-inbox#The ledger separates new traffic from recovery
phase:  verify
anchor: change
deltas: notify-and-inbox
grant:  docs/team/reports/P89-dev.md · docs/team/reports/P89-dev/**（只写报告与证据，不改实现）
deps:   P71（propose，verify）· **P81（apply，dev2）**——两位都不是你
status: todo
budget: 一个工作块
```

> 本地模式：不 push。

## 要对抗性验证的（给可复现命令 + 原始输出；**自造**夹具，不要只跑它的）

1. **至多一次（自己造崩溃）**：① 投递后、`intent` 写入**前** `SIGKILL` → 重启 → **恰好一次**恢复唤醒（不是两次）；
   ② `intent` 写入后、`sent` **前** `SIGKILL` → 重启 → **零重投**（记 `inflight assumed`）；
   ③ 手写一条**半截尾记录**（`intent` 行被截断）→ 重启 → 按同一条处理（零重投）。
2. **fail-closed**：让日志目录**不可写** → **零投递** + 账本 `deliver blocked` + 行保持未读（下拍仍可投）。
3. **旧行**：比 `TEAM_INBOX_WATCH_STALE_SEC` 更旧的行 → **不唤醒**、可计数；真新行照常唤醒。
4. **可自证**：唤醒文本里的**源行身份**能从日志与 spool 对上（逐条核对一条真消息）。
5. **`.seen` 不再被读**：删掉/清空/损坏 `.seen` → **不改变任何决定**；首次导入只发生一次。
6. **零回归**：FAST + 全量 smoke；并核对生产路径（Pi/node）与 harness（bun）的差异**已在文档里写明**。

## 至少三条变异（红→绿原始输出，只在 scratch 副本上）

- 把"写 intent 后再发"改成"先发后写" → 崩溃恢复断言红；
- 让 `intent`-无-`sent` 的身份**允许**重投 → 至多一次断言红；
- 让不可写的日志**照常投递** → fail-closed 断言红；
- 还原后实现树干净。
