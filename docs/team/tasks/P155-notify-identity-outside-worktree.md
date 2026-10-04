# P155 · 小核查：在工作树之外的目录里 `notify` 会不会被解析成 `pm`

```
task:   P155
agent:  dev2
issue:
change: -
specs:  -
phase:  verify
anchor: none (infra) — 只诊断与复现，不改实现
deltas: -
grant:  docs/team/reports/P155-<agent>.md · docs/team/reports/P155-<agent>/**
deps:   P82/P93（notify 发送者身份 ✅ 已实现并验证 ✅）· D72 附带的疑点 ✅
status: wip
budget: 小而准
priority: 中
```

## 要回答的

今天 dev-bob 的事故自报进了 PM 收件箱，但那一行标成 `agent:pm` ✗（内容是 dev-bob 写的 ✅）。P82 的规则是：
`--from` > **运行目录**（主检出→`pm` ✅、`.worktrees/<name>`→该名 ✅）> 判不出来就**拒** ✅。

**问题**：一个 **worker**（在自己的会话/窗口里 ✅）如果 cwd 落在主检出 ✅（例如去主树里跑 `team notify` 或从主树起的命令 ✅），
会不会被**自信地**记成 `pm` ✗（而不是拒 ✗ 或按窗口会话名 ✗）？

**要求**：
1. 在**当前 main** 上自造三种场景并给出原始输出：① 从 `.worktrees/<name>` 里 notify ✅ ② 从主检出里、但**会话/窗口是 worker 的** ✅
   ③ 从主检出里、无任何会话线索 ✅ —— 各自记成什么 ✅？是否与文档一致 ✅？
2. 若②被记成 `pm` ✗：判断这是**缺陷**（身份应结合会话/窗口或**拒绝** ✅）还是**已声明的边界** ✅（文档写了"按目录判" ✅）——
   给出你的结论与理由 ✅，并写成**可直接派单**的缺陷描述 ✅（若成立 ✅）。
3. **不改实现** ✅（这是诊断任务 ✅）；报告给出最小复现步骤 ✅。
