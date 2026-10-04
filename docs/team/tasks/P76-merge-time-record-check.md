# P76 · 合并时机也要查"未入账记录"（今天丢了 5 次，其中 3 次 PM）

```
task:   P76
agent:  （等席位）
issue:
change: -                        # 无 change：合并/收尾流程的自检（infra），不改契约
specs:  -
phase:  apply
anchor: none (infra) — 给 PM 的合并流程加一道"未入账记录"检查（不改变任何既有判定语义）
deltas: -
grant:  skills/teamsmith/scripts/lib/cmd-review.sh（或新增小函数）· skills/teamsmith/scripts/lib/cmd-agents.sh · skills/teamsmith/SKILL.md（合并流程一节）· skills/teamsmith/references/protocol.md · skills/teamsmith/tests/smoke.sh（append-only）
deps:   D45（今天的 5 次现场）· M31/P47（digest 侧的同类警告）· P42/P65/P67 的补提交记录
status: todo（等席位）
budget: 小到中
```

> 本地模式：不 push。

## 要做的

1. **合并前的检查**：给 PM 一条**一条命令**可跑的自检（例如 `team review <ID> --pre-merge` 或新动词
   `team merge-check <agent>` 或 `team close` 里的一段），对**指定 agent 的 worktree** 打印：
   - `docs/team/**` 下**未跟踪**的文件（`??`）；
   - `docs/team/**` 下**已改未提交**的文件（` M`）；
   - 每条给 `<agent>: <path>` 与修法（`git -C <worktree> add … && git commit`）。
   有未入账记录时**非零退出**（让它能当合并门用），没有则安静。
2. **同步文档**：合并流程（SKILL/PROTOCOL）里加这一步，并写明**为什么**（squash 只带已提交内容）。
3. **不许越界**：**不要**自动替 agent 提交（那会让"谁提交的"失真）；PM 手工提交时按今天的样子带 trailer。
4. **可证伪**：fixture worktree 里放一个未跟踪报告 → 命令**非零**并点名路径；提交后 → 归零；
   只有无关的脏文件（如 `state/`）→ **不受影响**；**反向**：把"未入账"检查删掉 → 对应断言红。
5. **零回归**：`team review` 的既有语义（跑门禁 + 写记录）**不变**；当前 main 上可能有已知红
   `12b-j`（P73）——点名区分。
