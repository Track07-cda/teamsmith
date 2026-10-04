# P96 · 独立验证：合并流程的两道检查（P76 合并前 / P91 合并后）

```
task:   P96
agent:  verify
issue:
change: -                        # 无 change：两件 infra 工具的独立复核（作者都不是你）
specs:  -
phase:  verify
anchor: none (infra) — 复核 `team review --pre-merge` / `--post-merge` 两个动词，不改实现
deltas: -
grant:  docs/team/reports/P96-verify.md · docs/team/reports/P96-verify/**（只写报告与证据，不改实现）
deps:   P76（apply=dev-bob）· P91（apply=dev-bob）
status: todo
budget: 小
```

> 本地模式：不 push。

## 要对抗性验证的（**自造**分支与工作树；不要只跑它的夹具）

1. **`--pre-merge`**：造一个 agent worktree，里面 ① 未跟踪报告 → **非零 + 点名 + 可粘贴修法**；
   ② 已改未提交的报告 → 同样点名；③ 只有 `state/` 脏 → **不误报**；④ 定位不到工作树/`--dir` 混用 → **exit 2**。
2. **`--post-merge`**：① 合并后分支只多了记录 → **exit 0 + "记录有更新：取它"**；
   ② 分支多了**代码** → **非零 + "必须重新合并"**；③ 已完全合并（无差异）→ 0；
   ④ 未合并的分支 → 明确措辞（不是静默 0）。
3. **两者的互斥与既有语义**：`--pre-merge` 不会跑门禁、不写记录；`--dir` 的既有语义不变。
4. **已知的误报边界（P91 的注意）**：squash + 手工解冲突后"两边都动过" → **核对它确实报非零**（现状如此），
   并在报告里写明这条**是既有行为**（P95 会细化基准）。
5. **零回归**：`openspec validate` + FAST + 全量 smoke。
