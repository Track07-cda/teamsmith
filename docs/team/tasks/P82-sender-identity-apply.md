# P82 · notify-sender-identity apply（发送者按运行时目录解析，不许退回 pm）

```
task:   P82
agent:  （等席位）
issue:
change: notify-sender-identity        # 提案已验收：docs/team/reviews/notify-sender-identity-proposal.md
specs:  notify-and-inbox#A manual notification is attributed to its sender, not its recipient / notify-and-inbox#A turn-end notification appends one inbox line and knocks once
phase:  apply
anchor: change
deltas: notify-and-inbox
grant:  skills/teamsmith/scripts/lib/{outbox,cmd-agents,common}.sh · skills/teamsmith/scripts/team · skills/teamsmith/tests/smoke.sh（append-only）· skills/teamsmith/tests/*（通知/身份夹具）· skills/teamsmith/references/*（一句）
        · **PM 追加授权（2026-09-22T22:3xZ，针对 P82 的 BLOCKED 1/2）**：`skills/teamsmith/extension/team-notify.ts` ·
        `skills/teamsmith/SKILL.md`（commands 表那一行）· **`skills/teamsmith/scripts/lib/cmd-project.sh`（`team notify` 的 help 行）** · `skills/teamsmith/tests/flip-p72.sh`（第四对变异）
deps:   P72（propose，已合并）· M40（身份 = 运行时目录）· D36
status: todo（等席位）
budget: 小到中
```

> 本地模式：不 push。**真源 = `openspec/changes/notify-sender-identity/{design.md,tasks.md}`。**

## 硬要求

1. **未解析 = 拒绝**：非零退出、**零收件箱行、零 knock**，输出点名 `--from`；**绝不静默退回 `pm`**。
2. **运行时目录解析**：主工作树 → `pm`；`.worktrees/<name>` → **该目录名**（**含在子目录里跑**）。
3. **`TEAM_AGENT` 不许压过**运行时目录；分歧在 stderr 点名。
4. **三处同名**：收件箱行、knock 文本、outbox 条目 `from:`。
5. **两条路同源**：`[auto]` 与 `[manual]` 用同一解析（红侧：让它们分叉 → 断言红）。
6. **可证伪**：worker 环境跑 → `[manual] agent:<worker>`（当前是 `agent:pm` → 红）；主树跑 → `agent:pm`；
   无 worktree 且无 `--from` → 非零且零写入。
7. **零回归**：`openspec validate` + FAST + 全量 smoke。
