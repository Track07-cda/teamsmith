# bottom-border-candidate-selection · PM proposal review

time: 2026-09-22T18:5xZ · reviewer: pm · verdict: **ACCEPTED**

```
change:  bottom-border-candidate-selection（P78，propose=verify）
tip:     （P78-propose）· validate 28/28
firsthand: P74 的 F1（规格钉了顶边框取最高，没钉下边框）
```

## Findings

1. **规则与顶边框镜像**：下边框 = 光标**下方最低**的合格整行规则行（**不是最近的**），
   且"合格"沿用既有配对规则（等宽整行 / spinner 形状），**光标自身是规则行时不算候选**（严格在光标下方找）✓
2. **单调性论证（我最看重的一条）**：相对"最近候选"，框**只可能变大** → **任何帧的判定都不许从 `BUSY` 变成 `EMPTY`**
   —— 即这次改动**只会往安全的一侧动**（不会把"忙"读成"空"），并且这条被写成 requirement 里的一条硬约束 ✓
3. **不可分辨性被证明**（这条漂亮）："草稿正好是一行规则行"与"会话在空框正下方画了一行规则行"**是同一串字节**
   （sha256 `e463c80c…f5053a6`）→ **原理上不可区分**，所以只能取**不会粘进草稿**的那一种读法 ✓
4. **代价写出来且**有**实测**边界**：**框下方若有整行规则行会把框撑大 → 读忙 → 投递等待（保守方向）；
   并且在**已存真帧**（Pi 0.85.1 / 0.87.0）里，面板**最低的整行规则行就是框自身的下边框**（实测），
   所以在两种实测布局里这个代价**不可达** ✓
5. **唯一实现 + 红侧**：与既有 requirement 的"一处实现"要求一致，红侧用既有的影子机制（`M24_SHADOW_CHROME`/`M45_NO_STRIP` 模式）✓
6. **ADDED 而非 MODIFIED**（9 条 scenario），base 零改动 ✓

## 结论

**ACCEPTED**。apply 由**不是 verify** 的席位做（OWNERSHIP：verify 不改实现）；apply 时逐条兑现：
最低候选、光标严格下方、单调性断言（无 `BUSY→EMPTY`）、一处实现 + 影子红侧、真帧判定不变、troubleshooting §3 的代价段。
