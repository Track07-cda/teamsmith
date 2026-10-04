# P137 · references 的"常见被拒与修法"反面清单（纯文档）

```
task:   P137
agent:  dev-bob
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 只改 references 文档，零行为改动
deltas: -
grant:  skills/teamsmith/references/** · docs/team/reports/P137-dev-bob.md · docs/team/reports/P137-dev-bob/**
deps:   D66 第 2/3 条（对方只能靠报错学分支命名与 change 行格式 ✅）· M4.1 英文不变量 ✅ · M71 的「`team review` 必须带 `--dir`」用法不变量 ✅
status: todo
budget: 小
priority: 中高（零风险、直接减少使用方的重试 ✅）
```

## 要加的内容（一处成节，写进最合适的 references 文档）

一节「**Common rejections and how to fix them**」✅，至少覆盖：

1. **分支命名**：期望名怎么推导（按任务书 `phase`/ID ✅，写清实际规则 ✅）、不匹配时**可直接粘**的修复命令
   （`git -C <worktree> switch -c <期望名>` ✅）、以及"停在别的任务分支上"为什么必须拒 ✅。
2. **任务书头部行**：`change:` / `deltas:` / `specs:` / `anchor:` 的**合法与非法**对照 ✅ —— 含两个真实撞过的形状：
   `change: panel（说明）`（括号说明非法 ✅）与 `deltas:` 的**逗号分隔**语法（用 `·` 会被拒 ✅）。
3. **复验**：一段"一条命令搭好独立复验"的配方 ✅ —— 独立 checkout（`git clone` 或 `git worktree` ✅，写明**容器场景不要挂 worktree** ✅）+
   `team review <ID> --dir <checkout>`（门禁 + 证据目录一次完成 ✅）。**每个示例都必须带 `--dir`** ✅（M71 的用法不变量）。

## 约束与证据

- **正文英文** ✅（`references/**` 的英文不变量：行内代码里的中文 CLI 输出串不算 ✅）；
- 跑相关文档检查段 ✅（不用全量 ✅）—— 报告里给出**前后对照**：这两个形状以前只能靠报错学 ✅，现在文档里有 ✅；
- 若发现某条规则**只在报错里、文档里确实没有** ✅ 那就正是要补的 ✅（在报告里点名）。
