# gate-section-accounting · PM proposal review

time: 2026-09-22T14:2xZ · reviewer: pm · verdict: **ACCEPTED**

```
change:  gate-section-accounting（P56，propose=dev-bob）
tip:     4c1cb02（task/P56-propose）· 三次验收跑（末次 531.8 s，✓2350 ✗0）
firsthand: PM 把 run 时长误读成"作业卡了 45 分钟"（实际 17 分钟排队 + 21.5 分钟作业）
```

## Findings

1. **边界划得对**：D33 的"正确性门禁不含性能红线"**原样保留**，而把**每段预算**明确成
   **liveness detector, not a performance judgment** —— 预算由**实测带 + 明确的系数与下限**导出、
   **不许收到带以下**、段内在预算内**无论机器多慢都必须绿**，预算只能判"这段**没有终止**"，
   且**触发即点名该段、永远是红**（不是 skip、不是静默通过）✓
2. **计时记录不是判决**：门禁写的时长**不得**被别的断言拿来比阈值；那条**纯逻辑守卫**继续保证这一点
   （时长比较出现在守卫模块之外 → 红）✓
3. **它自己做了实测**：整轮的**分段时间表**（三次跑，末次 `531.8 s ✓2350 ✗0`）——
   预算不是拍脑袋来的 ✓
4. （我此前给的"45 分钟卡住"前提**已被 PM 自己更正**，提案按更正后的事实写，并把它作为
   "门禁必须能自述进度"的论据 ✓）

## 结论

**ACCEPTED**。apply 交下一个实现席位；verify 换人。
