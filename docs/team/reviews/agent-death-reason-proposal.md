# agent-death-reason · PM proposal review

time: 2026-09-28T16:1xZ · reviewer: pm · verdict: **ACCEPTED**

```
change:  agent-death-reason（P101，propose=verify；用户 2026-09-28 批准「2 可以」）
tip:     8935bc10（task/P101-propose）· validate 16/16 ✓
```

## 与我任务书的对照（逐条）

| 要求 | 提案 |
|---|---|
| **闭集，绝不编造** | `quota · balance · rate_limit · window · auth · normal · unknown` ✓；requirement 原文即「**an unknown death is never given one**」✓ |
| **只读有界尾部 + 供应商错误形状**（拒绝"正文偶然提到"） | 三条场景把两侧都钉住：合成额度帧 → `quota` ✓；**看起来像 auth 的供应商帧仍归 quota** ✓；**仅仅提到某个词的散文不算分类** ✓ |
| **缺证据即 unknown** | "No readable evidence is an unknown death, never a guess" ✓ |
| **只对当前这次死亡生效**（不粘） | 四条场景：重启不继承旧因 ✓ · 同一次死亡跨 tick 保持同一身份 ✓ · 重启后的第二次死亡是新死亡 ✓ |
| **可见面** | `status` 给分类 + **来源** + **原始行** ✓ · `digest` 在计数旁点名分类 ✓ · 面板 agents 块带 cause ✓（运行中的席位**不带** cause ✓） |
| **一次通报** | 三条 tick 同一次死亡 → **恰好一次** knock 与一条记录 ✓ · 垃圾帧 → **以 unknown 报一次**（不假装知道 ✓）· 正常退出 → **静默** ✓ · **standby 时顺延而不是丢** ✓ · 无来源可读 → 点名而不重复 knock ✓ |
| **Non-Goals** | 明文：**M6.5 存活判据一字不改** ✓ · **不做自动 fallback**（那是另一个 change ✓）· 不动 `[auto·interrupted]` ✓ · 不碰其他项目 ✓ · **不许放松任何断言** ✓ |

## 结论

**ACCEPTED**。提案把 P101 的核心（"停了的 agent 到底为什么停"）做成了**可证伪的闭集 + 两条侧面的反例**，
并把"不猜、不粘、不重复叫醒、不碰存活判据、不做 fallback"都写成了约束 ✓。
apply = **P113**（作者不得是 verify 席位的 proposer；verify 阶段再由第三方做 ✓）。
