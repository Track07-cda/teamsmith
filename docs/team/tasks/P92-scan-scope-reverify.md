# P92 · gate-isolation-scan-scope 重新验证（F1 修复后·换人）

```
task:   P92
agent:  （等席位：dev/dev-bob/verify 任一 —— **不得**是 dev2（P77 apply）或 dev3（P87 rework apply））
issue:
change: gate-isolation-scan-scope
specs:  verification#The fixture-trace scan covers the ledger, not the gate's own call record / boundary#The gate's actions are logged, and no window carries a fixture's trace
phase:  verify
anchor: change
deltas: verification, boundary
grant:  docs/team/reports/P92-<agent>.md · docs/team/reports/P92-<agent>/**（只写报告与证据，不改实现）
deps:   P73（propose，dev）· P77（apply，dev2）· **P87（F1/F2 返工，dev3）**
status: todo（等席位）
budget: 一个工作块
```

> 本地模式：不 push。

## 要对抗性验证的（**自造**植入点；不要只跑它的夹具）

1. **确切路径语义（五个腿）**：`docs/team/inbox/bg/leak.md` · `.pi/team/state/nested/bg/leak.md` ·
   `.pi/team/state/tmux-calls.log.1` · `docs/team/inbox/leak.md` · `.pi/team/state/phantom.log` → **全部点名**；
   `.pi/team/state/bg/gate.log` · `.pi/team/state/tmux-calls.log` → **静默**。
   **反向腿**：把 bg 的排除放宽成 basename → 前两条变**静默** → 断言红（证明约束被守着）。
2. **审计日志语义**：真调一次 tmux（私有 socket）→ 该调用**必须**进 `state/tmux-calls.log`；
   而扫描**不得**因此变红（这正是原症状）。反向：把它从排除里去掉 → `12b-j` 红。
3. **轮转**：2100 行 → 首行严格形状的 marker、**不含 `act=`**（自己全表核对闭集四值）；**唯一 1000 条**调用行保留；
   第二次轮转累计；**读不出 N** 的那次**不参与累计**（F2）。
4. **反向控制仍在**：`12b-j` / M16 的正向腿照旧能红。
5. **零回归**：`openspec validate` + FAST + 全量 smoke（当前 main 零红）。

## 至少三条变异（红→绿原始输出，只在 scratch 副本上）

- 去掉审计日志排除 → `12b-j` 红；
- bg 的排除改成 basename → 两个 bg 腿红；
- marker 写入时带上 `act=` → 闭集词表断言红；
- 还原后实现树干净。
