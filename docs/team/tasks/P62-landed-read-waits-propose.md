# P62 · 夹具等"读已落定"的数据态（+ 邻居夹具的固定 sleep）（propose）

```
task:   P62
agent:  dev-bob
issue:
change: fixture-waits-for-landed-reads
specs:  -
phase:  propose
anchor: change
deltas: verification
deps:   P52 的决定性归因（D43）· D44 的 F2/F4 · M59/D33（等待是 liveness，不是性能阈值）
status: todo
budget: 一个提案包
```

> 本地模式：不 push。**只 propose。**

## 要写的（事实与证据都在 D43/D44/P52 的报告里）

1. **夹具等待"数据态"，不等骨架、不等固定 sleep**：
   - 已有病例：`panel-p21.sh` 的手改文件 → `reopen_view`（只等分组标题）→ `sleep 0.5` → Enter → 期望新值；
     2 核机器上后台强制读还没落定 → 三条红（5/5 复现，delay 注入 0s 绿 / 6s 红，**放大视界无效**）。
   - 要立成 requirement：**当夹具断言"由数据导出的状态"时，它必须先以有界等待观测到该数据态**
     （例如"那一行已显示新值"），**不许**用骨架标记或固定 `sleep` 当证据；
     等待必须有上限与归因（M59/D48 的引擎），且**不得**变成性能阈值（D33）。
2. **同类邻居**（D44 的 F2）：`panel-b3.sh` 的 `collapse` 段固定 `sleep 5` + 单次 capture（6 次红 4 次）——
   同一味儿，提案要把它一并纳入"等待口径"的适用范围（并给出可证伪的红侧）。
3. **F4**（`panel-cpu.sh` 量调用工作树的首帧）：提案要给一条**量测对象固定**的要求
   （量"中性树/参考树"的面板，而不是调用者当前工作树），否则同一命令在不同工作树给出不同结论。
4. **可证伪**：注入 settings 读延迟（scratch wrapper）→ 旧夹具红、新夹具**在延迟下落定后仍绿**；
   反向：数据永不落定 → 有界等待到顶、点名该等待（不是超时假绿）。

## 硬要求

- policy B：delta 落 `verification`；每条可证伪、MODIFIED 不删 base scenario；
- 每条 requirement 给复核方法；**不写实现**；矛盾 → `BLOCKED:` 交回 PM。
