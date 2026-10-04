# P83 · gate-isolation-scan-scope 独立验证（verify 阶段）

```
task:   P83
agent:  dev3
issue:
change: gate-isolation-scan-scope
specs:  verification#The fixture-trace scan covers the ledger, not the gate's own call record / boundary#The gate's actions are logged, and no window carries a fixture's trace
phase:  verify
anchor: change
deltas: verification, boundary
grant:  docs/team/reports/P83-dev3.md · docs/team/reports/P83-dev3/**（只写报告与证据，不改实现）
deps:   P73（propose，dev）· **P77（apply，dev2）**——两个作者都不是你
status: todo
budget: 一个工作块
```

> 本地模式：不 push。**apply 是 dev2、propose 是 dev → 你来验（D31）。**

## 要对抗性验证的（给可复现命令 + 原始输出）

1. **扫描作用域（自己造植入点，不要只用它的夹具）**：审计日志 `state/tmux-calls.log` 与 `state/bg/**` **静默**；
   **`state/tmux-calls.log.1`、`state/nested/tmux-calls.log`、`docs/team/inbox/*`、别的 state 文件**都必须**点名**。
   反向腿：把排除**放宽成 basename glob**（scratch 副本）→ `.log.1`/嵌套腿**变红**（证明按确切路径是真约束）。
2. **轮转自述**：造 2100 行 → 首行必须是**严格形状**的 `<ISO> · rotation · dropped=<N>`；
   **不含 `act=`**（闭集词表不被污染：自己全表 grep 一遍 `act=` 的取值集合必须仍是四个）；
   第二次轮转累计（`dropped` 递增）；**最新 1000 条调用行**保留且有序。
3. **不做分片/时间轮转**（`--help`/`config`/代码里 grep 不到分片或按时间轮转的实现）。
4. **反向控制仍在**：`12b-j` 与 M16 的正向腿照旧能红（自己植入真泄漏 → 红）。
5. **零回归**：`openspec validate` + FAST + 全量 smoke。

## 至少三条变异（红→绿原始输出，全部在 scratch 副本上）

- 去掉审计日志的排除 → `12b-j` 红（回到今天的原症状）；
- 把确切路径排除改成 basename → `.log.1`/嵌套腿红；
- 去掉轮转 marker（只留裁剪）→ 轮转断言红；
- 还原后实现树 `git status --porcelain -- skills/` 为空。
