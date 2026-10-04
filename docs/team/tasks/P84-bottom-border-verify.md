# P84 · bottom-border-candidate-selection 独立验证（verify 阶段）

```
task:   P84
agent:  dev
issue:
change: bottom-border-candidate-selection
specs:  delivery-guard#The bottom border is the lowest qualifying rule row below the cursor
phase:  verify
anchor: change
deltas: delivery-guard
grant:  docs/team/reports/P84-dev.md · docs/team/reports/P84-dev/**（只写报告与证据，不改实现）
deps:   P78（propose，verify）· **P80（apply，dev3）**——两个作者都不是你
status: todo
budget: 一个工作块
```

> 本地模式：不 push。

## 要对抗性验证的（给可复现命令 + 原始输出）

1. **下边框 = 最低合格行**（自己造帧，不要只用它存的八份）：① 草稿在光标下方画**等宽**横线 → 框**含**它并判 `NOT-EMPTY`；
   ② **更宽**横线（TUI 裁剪形态）→ 同；③ **spinner 形状**行 → 同；④ **光标自身是整行规则行** → 不算候选（严格下方找）；
   ⑤ 草稿在光标**中间**（上下都有草稿行）→ 全在框内。
2. **单调性（写死的一条）**：对**全部已存帧**逐帧对比"旧顺序（最近优先）"与"新顺序（最低优先）"的判定 →
   **没有任何帧从 BUSY 翻成 EMPTY**。用**你自己**的对比脚本（不要只跑它的断言）。
3. **代价边界**：框**下方**若有整行规则行 → 框撑大 → `NOT-EMPTY`（保守方向）；用**你自己**的帧造出来。
4. **一处实现**：生产提取与夹具判定共用；把其中一个影子成最近的旧顺序（scratch）→ 断言红。
5. **真帧不回退**：Pi 0.85.1 / 0.87.0 的已存真帧判定**逐帧不变**（自己跑一遍旧/新两侧）。
6. **零回归**：`openspec validate` + FAST + 全量 smoke。

## 至少三条变异（红→绿原始输出，全部在 scratch 副本上）

- 改回"最近候选" → 同族帧红；
- 让下边框候选包含**光标行自身** → 对应断言红；
- 让夹具判定与生产提取分叉 → 同源断言红；
- 还原后实现树干净。
