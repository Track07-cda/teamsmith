# P87 · 修 F1/F2：`bg` 排除改**确切路径**（+ marker 累计口径）

```
task:   P87
agent:  dev3
issue:
change: gate-isolation-scan-scope        # 返工：P83 的 F1（requirement 的 MUST 未落地）+ F2（低）
specs:  verification#The fixture-trace scan covers the ledger, not the gate's own call record / boundary#The gate's actions are logged, and no window carries a fixture's trace
phase:  apply
anchor: change
deltas: verification, boundary
grant:  skills/teamsmith/tests/smoke.sh · skills/teamsmith/scripts/shim/tmux · skills/teamsmith/tests/*（受影响断言）· skills/teamsmith/references/troubleshooting.md
deps:   P77（apply，同 change）· **P83 的 F1/F2**（`reviews/P83.md`，含 10 个植入点的表格与原始输出）
status: todo
budget: 小
priority: **中高**（安全扫描的漏报面）
```

> 本地模式：不 push。

## 要做的

1. **F1（必修）**：`real_ledger_hits` 的 `bg` 排除从 `--exclude-dir=bg`（**basename**）改为**确切路径**
   （只排 `<root>/.pi/team/state/bg` 这一棵），于是：
   ① `docs/team/inbox/bg/leak.md` → **点名**；② `.pi/team/state/nested/bg/leak.md` → **点名**；
   ③ `<root>/.pi/team/state/bg/**` → 仍静默（M30 口径不变）。
2. **F2（顺手）**：marker 首行**读不出 N**（`dropped=abc`）时的累计口径写清楚并实现
   （例如"按可读部分重算"或"读不出则按 0 起点重算并保持累计单调"）；**不许**静默写一个与 spec 不符的数。
3. **可证伪的红/绿两侧**（原始输出）：
   - 红侧（当前 HEAD `c3b8caf2`）：上面两个 `bg` 植入点**漏报**；
   - 绿侧：修后**点名**，同时 `<root>/.pi/team/state/bg/**` 仍静默；
   - 反向腿：把 bg 的排除**放宽成 basename** → 断言红（证明这条约束真的被门禁守着）。
4. **零回归**：`openspec validate` + FAST + 全量 smoke；P77 的既有四条腿与轮转断言照旧。
