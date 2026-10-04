# P77 · gate-isolation-scan-scope apply（审计日志按确切路径排除 + 截断自述）

```
task:   P77
agent:  （等席位）
issue:
change: gate-isolation-scan-scope     # 提案已验收：docs/team/reviews/gate-isolation-scan-scope-proposal.md
specs:  verification#The fixture-trace scan covers the ledger, not the gate's own call record / boundary#The gate's actions are logged, and no window carries a fixture's trace
phase:  apply
anchor: change
deltas: verification, boundary
grant:  skills/teamsmith/tests/smoke.sh · skills/teamsmith/tests/container-tmux.sh · skills/teamsmith/tests/lib/*（若需）· skills/teamsmith/scripts/lib/common.sh（审计写入路径）· skills/teamsmith/references/troubleshooting.md（一段）
deps:   P73（propose，已合并）· D45（三次现场）· M30/12b-j（既有反向控制）
status: todo（等席位）
budget: 一个工作块
```

> 本地模式：不 push。**真源 = `openspec/changes/gate-isolation-scan-scope/{design.md,tasks.md}`。**

## 硬要求（验收会逐条查）

1. **只按确切路径排除**：`.pi/team/state/tmux-calls.log` 与 `state/bg/**`；
   **`state/tmux-calls.log.1`、`state/nested/tmux-calls.log`、`docs/team/inbox/**`、别的 state 文件都必须仍被点名**。
2. **标记不是调用行**：首行 `ISO · rotation · dropped=<累计>`，**不带 `act=`**；既有的行解析器与闭集词表**零改动**。
3. **有界保留保持**（2000 → 最新 1000 行）；**不许**引入分片或按时间轮转。
4. **反向控制照旧能红**：`12b-j` 与 M16 的正向腿、以及"把排除放宽成 basename glob → `.log.1`/嵌套腿变红"的反向腿。
5. **红/绿两侧**都留原始输出（R1–R4，按 design 的证伪计划）。
6. **零回归**：`openspec validate` + FAST + 全量 smoke（当前 main 上若仍有 P71 类噪声红，点名区分）。
