# P196 · `safe-signal-discipline` **第四轮复验**（P195 之后，再换人）

```
task:   P196
agent:  verify
issue:
change: safe-signal-discipline
specs:  boundary#Signals go to a recorded pid, never to a name or a pattern
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P196-<agent>.md · docs/team/reports/P196-<agent>/**
deps:   第一轮 P166 ✓ / 第二轮 P175 ✓ / 第三轮 **P189**（F1 读侧不一致 ✓）· 返工 **P195**（在 main ✓）· PM 评审 `docs/team/reviews/P189.md` ✓ · D31
status: wip
budget: 一次对抗性验证
priority: 高（该 change 归档的唯一前置；机制已被绕过三轮，第四轮要盯"读面与写面同源"）
```

## 要独立证明或证伪的

1. **F1 闭合** ✅（自己造形状）：非平坦 id ✓、`pgid=0` ✓、实时组不符 ✓ 三种记录 →
   `bg list` **不许**显示"身份成立" ✗；它给出的原因必须与 `bg stop` **一致** ✓（逐字对照两者措辞 ✓）。
   **影子**：把 `list` 的校验改回"只看 pid 活着" → 三条必须红 ✓。
2. **同一函数** ✅：读面与写面**调同一份校验** ✓ —— 自己改那处校验（例如把"pgid 必须为正"去掉 ✓）→ **两侧同时变** ✓（这就是"同源"的实证 ✓）。
3. **反向不误伤** ✅：正常记录 ✓ → `list` 显示成立 ✓ 且 `stop` 能收 ✓。
4. **既有承诺抽查** ✅：模式选择 64 ✓、软链与目录边界（P169/P187 ✓）、lint 双向 ✓。
5. **门禁**：`openspec validate --all --strict` ✓ + 容器内 `--select 58` ✓ + 容器内 FAST ✓；报告写清原始输出与**没有**测到什么 ✓。
