# notify-sender-identity · PM proposal review

time: 2026-09-22T21:1xZ · reviewer: pm · verdict: **ACCEPTED**

```
change:  notify-sender-identity（P72，propose=verify）
tip:     （P72-notify-sender-pm-propose）· validate 30/30
firsthand: 我实测的 55 行 `[manual] agent:pm · …`（活是 worker 干的）+ 三个 worker 的
           `TEAM_AGENT` 都为空、`TEAM_ROOT` 指向各自 worktree
```

## Findings

1. **解析顺序正确且 fail-closed**：显式 `--from`（与运行时目录不一致时 **stderr 点名分歧**）→ **运行时目录**
   （主工作树 → `pm`；`.worktrees/<name>` 下的 worktree → **它自己的目录名**，**在子目录里跑也算**）→ **未解析** ✓
2. **未解析 = 拒绝**：非零退出、**不写收件箱、不入队 knock**，输出点名 `--from` ✓
   —— **不许静默退回 `pm`**，并在设计里引用了 `references/philosophy.md`（**假绿比没有更糟**）作为理由 ✓
3. **继承的 `TEAM_AGENT` 不许压过运行时目录**（分歧要在 stderr 点名）——与 M40/D36 同一套身份哲学 ✓
4. **一处解析、两处使用**：`[auto]` 与 `[manual]` 走**同一条**规则；解析出的名字必须同时出现在
   **durable 收件箱行**、**knock 文本**、以及 **outbox 条目里的 `from:`** ✓（我要求的三条）
5. **delta**：ADDED ×1（7 场景）+ MODIFIED ×1（base 3 → 4，**一条没丢**）✓ —— MODIFIED 正是"回合通知"那条，
   把两条路钉在同一个解析上。

## 结论

**ACCEPTED**。apply 排队（等席位）；apply 时逐条兑现：拒绝路径（非零 + 零写入 + 零入队）、
子目录解析、`TEAM_AGENT` 分歧点名、以及"收件箱行 / knock / outbox `from:` 三处同名"。
