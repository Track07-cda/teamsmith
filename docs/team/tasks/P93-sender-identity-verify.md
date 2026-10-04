# P93 · notify-sender-identity 独立验证（verify 阶段）

```
task:   P93
agent:  dev3
issue:
change: notify-sender-identity
specs:  notify-and-inbox#A manual notification is attributed to its sender, not its recipient / notify-and-inbox#A turn-end notification appends one inbox line and knocks once
phase:  verify
anchor: change
deltas: notify-and-inbox
grant:  docs/team/reports/P93-dev3.md · docs/team/reports/P93-dev3/**（只写报告与证据，不改实现）
deps:   P72（propose，verify）· **P82（apply，dev-bob）**——两位都不是你
status: todo
budget: 一个工作块
```

> 本地模式：不 push。

## 要对抗性验证的（**自造**项目与路径；不要只跑它的夹具）

1. **未解析 = 拒绝**：无 worktree 形态、无 `--from` → **非零 + 零收件箱行 + 零 knock**，输出点名 `--from`；
   **反向**：把拒绝改成静默退回 `pm`（scratch）→ 断言红。
2. **运行时目录解析**：① 主工作树 → `agent:pm`；② `<main>/<worktrees>/dev2` → `agent:dev2`；
   ③ **在该 worktree 的子目录里跑** → 仍是 `agent:dev2`；④ 显式 `--from X` → `agent:X`，且**与目录不一致时 stderr 点名**。
3. **`TEAM_AGENT` 不压过**：设一个撒谎的 `TEAM_AGENT` → 发送者仍是运行时目录，且**点名被忽略的值**。
4. **三处同名**：同一夹具里核对**收件箱行**、**knock 文本**、**outbox 条目 `from:`** 三处一致。
5. **两条路同源（扩展侧）**：在一个**窗口名撒谎**的场景里跑扩展的 settle → `[auto]` 行的 `agent:<name>`
   必须与 CLI 侧同一运行时目录的结果**一致**（自己造窗口名与目录名不同的现场）。
6. **零回归**：`openspec validate` + FAST + 全量 smoke（当前 main 零红）。

## 至少三条变异（红→绿原始输出，只在 scratch 副本上）

- 发送者退回**收件人** → 断言红；
- 未解析静默退回 `pm` → 断言红；
- 扩展回到 `window || basename(cwd)` → `[auto]` 那条断言红；
- 还原后实现树干净。
