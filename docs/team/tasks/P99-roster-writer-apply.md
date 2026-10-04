# P99 · `roster-writer-and-route-truth` apply（名册写入路径 + 用法诚实性检查）

```
task:   P99
agent:  dev
issue:
change: roster-writer-and-route-truth        # 提案已验收：docs/team/reviews/roster-writer-and-route-truth-proposal.md
specs:  memory-and-deps#（名册的唯一授权写入路径）· init-skill#（初始化不问 harness，只问 Pi 与插件）/ dispatch#（用法诚实性）
phase:  apply
anchor: change
deltas: memory-and-deps, init-skill, dispatch
grant:  skills/teamsmith/scripts/lib/{cmd-agents,cmd-config,cmd-project,common}.sh · skills/teamsmith/scripts/team · skills/teamsmith/SKILL.md · skills/teamsmith/references/*.md · skills/teamsmith/tests/smoke.sh（append-only）· skills/teamsmith/tests/*（棋盘/名册夹具）· **openspec/changes/roster-writer-and-route-truth/specs/{init-skill,dispatch,memory-and-deps}/spec.md（delta 重写，见下）**
deps:   P46 的 propose（已合并）· **`npm-cli-and-project-init` 的归档**（PM 已在本地完成：它给 `init-skill` 的同一 requirement 加了场景 → 你的 MODIFIED delta **必须重写**，带上完整 requirement 与**全部**场景，见 D40）
status: todo（dev）
budget: 一个工作块
```

> 本地模式：不 push。**真源 = `openspec/changes/roster-writer-and-route-truth/{design.md,tasks.md}`。**

## 硬要求

1. **名册的唯一授权写入路径**：`team add-agent <name> --register` → 校验 → 经**审计写入器**改 `TEAM_AGENTS` →
   再建/提示工作树；**没有 `--register` 就拒绝**，并给**两条真实出路**（手改 `config.sh` / 加 `--register`）——
   **不许**再打印那句"名册：team add-agent / team teardown"（它今天就是假的）。
2. **对称移除**：`team teardown --agent X --register`（或 `team roster remove X`）；同样审计一行。
3. **`set-agent-model` 对"尚未入册的席位"的裁定**：给**可执行**的答案（要么先生效、要么明确拒绝并给一条路），别留"未知席位"死胡同。
4. **`--model`**：`team help` 里 `add-agent <a> [--model m]` 要么**真的支持**，要么**从 help 与所有提及处删掉**（同步）。
5. **用法诚实性检查（关键，可证伪）**：
   ① 逐条走 `team help` 的用法行 vs 各解析器**实际接受**的参数（不一致 → 红）；
   ② 走 schema 注释里**点名的命令**，在夹具里断言"该命令存在且能做到那句话承诺的事"（做不到 → 红）。
   反向：把 `--model` 从解析器里删掉但留在 help → 红。
6. **delta 重写（D40）**：`init-skill` 的 MODIFIED 块要按**归档后**的 base 重写（含 npm 加进来的场景），
   并带上你自己的新要求；`dispatch`/`memory-and-deps` 同理**不许丢 base 场景**。
7. **`TEAM_AGENTS` 仍是 `refuse` 类**（新东西是"显式 CLI 入口"，不是"把键改成可写"）。
8. **零回归**：`openspec validate` + FAST + （交付时一次）全量。
