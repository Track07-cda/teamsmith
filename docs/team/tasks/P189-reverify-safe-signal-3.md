# P189 · `safe-signal-discipline` **第三轮复验**（P187 之后，换第四个人）

```
task:   P189
agent:  dev
issue:
change: safe-signal-discipline
specs:  boundary#Signals go to a recorded pid, never to a name or a pattern
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P189-<agent>.md · docs/team/reports/P189-<agent>/**
deps:   第一轮 `docs/team/reports/P166-verify.md`（F1/F2/F3 ✓）· 第二轮 `docs/team/reports/P175-dev3.md`（枚举项 PASS + F1' 目录软链 ✓）· 返工 P169/P187（在 main ✓）· PM 评审 `docs/team/reviews/P166.md` / `P175.md` ✓ · D31
status: todo
budget: 一次对抗性验证
priority: 高（它是该 change 归档的**唯一**前置；机制已被绕过两轮 ✓）
```

## 要独立证明或证伪的

1. **F1 边界（枚举 + 目录）** ✅：穿越/绝对/空/带 `/` 的 id ✓、bg 内软链→别处 ✓、**bg 目录自身软链→项目外** ✓（P187 新增 ✓）→ 都要**拒** ✓ 且**诱饵进程仍然活着** ✓；
   **反向**：正常目录 + 正规记录 → 照常收 ✓。
2. **F2 一致 fail-closed** ✅：畸形 pid/pgid ✓、非数字 ✓、缺字段 ✓、FIFO/目录/不可读 ✓ → rc=4 + 诊断 + 有界 ✓。
3. **新 scenario 与实现同源** ✅：delta 里那条新 scenario 的措辞与实现行为**逐条对齐** ✓（例如它点名两个路径 ✓）；影子：把"目录在项目内"检查去掉 → 该 scenario 的用例必须红 ✓。
4. **读侧一致** ✅：`bg list` 与 `bg stop` **同一规则** ✓（不许一个拒一个放 ✓）。
5. **不许放松** ✅：模式选择仍 64 ✓、lint 双向 ✓。
6. **门禁**：`openspec validate --all --strict` ✓ + 容器内 `--select 58` ✓ + 容器内 FAST ✓；报告写清原始输出与**没有**测到什么 ✓。
