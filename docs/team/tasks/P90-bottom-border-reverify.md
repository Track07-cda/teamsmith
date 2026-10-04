# P90 · bottom-border-candidate-selection 重新验证（F1 修复后·换人）

```
task:   P90
agent:  dev2
issue:
change: bottom-border-candidate-selection
specs:  delivery-guard#The bottom border is the lowest qualifying rule row below the cursor
phase:  verify
anchor: change
deltas: delivery-guard
grant:  docs/team/reports/P90-dev2.md · docs/team/reports/P90-dev2/**（只写报告与证据，不改实现）
deps:   P78（propose，verify）· P80（apply，dev3）· **P86（F1 修复，dev）**——三位都不是你
status: todo
budget: 一个工作块
```

> 本地模式：不 push。

## 要对抗性验证的（**自造**帧；不要只跑它存的）

1. **F1 已修**：混宽度帧（光标框一种宽度、下方另有一对**自成配对**的规则行）→ 框**必须仍含光标行**、判 `NOT-EMPTY`；
   自己造三种变体（等宽对 / spinner 作上边框 / 更窄的对）。
2. **准入条件**：候选配到的上边框**严格在光标行之上**；不满足 → 跳过并继续找**更近**的候选；
   **框总是包含光标行**（对**全部**已存帧加断言）。
3. **单调性**（P84 的 F1 曾把它证伪）：现在对**全部已存帧**（含 P86 新存的三份）逐帧对比旧/新 →
   **没有 BUSY→EMPTY**；用**你自己的**对比脚本。
4. **边界形状（P86 已申报、我裁定接受）**：`rule(A)/空行(光标)/rule(A)/空行/rule(B)/文本/rule(B)` →
   判 `EMPTY`（**这是更正**：光标所在的 A 框确实是空的那个；P80 时代的 BUSY 来自不相交的 B 框）。
   **核对它确实如我裁定**（不是别的形状）。
5. **一处实现**：生产提取与夹具判定同源；影子成"最近优先" → 对应断言红。
6. **零回归**：`openspec validate` + FAST + 全量 smoke（当前 main 零红）。

## 至少三条变异（红→绿原始输出，只在 scratch 副本上）

- 去掉准入条件（回到"最低优先、不查含光标"）→ F1 帧红；
- 把准入条件放宽成"框与光标框有交集即可" → 边界/混宽度断言红；
- 让两处判据分叉 → 同源断言红；
- 还原后实现树干净。
