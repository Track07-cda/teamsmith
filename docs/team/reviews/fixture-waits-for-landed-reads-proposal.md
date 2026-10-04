# fixture-waits-for-landed-reads · PM proposal review

time: 2026-09-22T17:2xZ · reviewer: pm · verdict: **ACCEPTED（附一条 apply 条件）**

```
change:  fixture-waits-for-landed-reads（P62，propose=dev-bob）
tip:     （P62-propose 分支）· validate 25/25
firsthand: D43（CI 那条 choices 红的归因）· D44 的 F2/F4
```

## Findings

1. **等待"数据态"而不是代理**（我 D43 的裁定逐条落地）：断言前必须**观察到那个状态本身**
   （例如设置行已显示手改后的值），**骨架标记不算证据**、**固定 `sleep` + 单次采样不算证据**；
   上限与**归因**要**点名等的是哪个数据态**（不止"等超时了"）；耗尽后**不许**下断言、**不许**报绿；
   红/SKIP 的分派交给 D33 那条既有 requirement（健康机上静态 → 红；超前提 → 可见 SKIP）✓
2. **不许变成性能红线**：等待上限**不是**墙钟/CPU 阈值（慢但落在界内必须绿），
   且**上限要连同它据以推导的实测延迟带一起记在夹具旁边** ✓ —— 这正是我要的"可复核的常数"
3. **F4 也有了自己的 requirement**：量测夹具必须量**固定的中性目标**，并把"量的项目根"与"被测的 bundle"
   **两个名字都印出来**；从两个不同工作树跑必须**同一个结论**（调用者的 cwd 不许改变被测对象）✓
4. **⚠️ apply 条件（一条）**：第一条 requirement 里引用了
   `verification#Every wait in the gate is bounded and attributes at its cap` —— 这条 requirement
   **目前还只存在于未合并的 `gate-section-accounting`（P56）**。apply 时必须二选一：
   **① 等到 P56 落地后引用它**，或 **② 改写成引用 base 里已有的**
   `verification#The correctness gate judges correctness only`（D33）——**不许留一条指向不存在 requirement 的引用**
   （这正是 D40 那条纪律的推论）。

## 结论

**ACCEPTED**（apply 时执行上面第 4 条）。
