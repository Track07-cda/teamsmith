# P98 · gate-runtime-budget apply（分段账本 + 路径选段）

```
task:   P98
agent:  （等席位）
issue:
change: gate-runtime-budget        # 提案已验收：docs/team/reviews/gate-runtime-budget-proposal.md
specs:  verification#The run reports each section's outcome counts and its slowest sections / verification#A changed-path list selects the sections to run, or the full suite / verification#A selected run says what it did not run
phase:  apply
anchor: change
deltas: verification
grant:  skills/teamsmith/tests/smoke.sh · skills/teamsmith/tests/section-paths.tsv（新）· skills/teamsmith/tests/section-select.sh（新）· skills/teamsmith/tests/*（受影响的断言/夹具）· skills/teamsmith/references/protocol.md（一句用法）· skills/teamsmith/references/troubleshooting.md（一句）
deps:   P97（propose，已合并）· D33（性能不入正确性门禁）· M23（一套一次）· P26/P27（排队账本）
status: todo（等席位）
budget: 一个工作块
priority: **高**（用户指定：门禁效率）
```

> 本地模式：不 push。**真源 = `openspec/changes/gate-runtime-budget/{design.md,tasks.md}`。**

## 硬要求（验收逐条查）

1. **红标不被污染**：新增行**绝不**出现 `  \033[31m✗\033[0m`；用**既有 `flip-m33.sh`** 证明红标计数**与之前一致**。
2. **账本自查**：段增量之和 **==** 结果行总数；最后一段的收口行**在**结果行之前。
3. **`FULL` 兜底真的会兜**：给一个**未被任何行覆盖**的路径 → `decision=FULL` 并点名该路径；给 `docs/**` → `NONE`。
4. **`--check` 能红**：在段正文里塞一个**没声明**的路径 token（scratch）→ 红并点名 token 与行号；
   给一个**不存在**的字面模式 → 红。
5. **无 flag = 行为完全不变**（全套、退出码、既有断言）；`--select` 未知 key → 非零且什么都不跑。
6. **选择运行必须自述**"这次没跑哪些段"（可机读 + 人话各一）。
7. **零回归**：`openspec validate` + FAST + （交付时一次）全量；**不新增任何性能红线**。
