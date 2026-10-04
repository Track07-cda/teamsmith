# P46 · roster-writer-and-route-truth：名册有可用的写入路径 + "印出来的路线必须真能用"（propose）

```
task:   P46
agent:  verify（**只 propose**：该阶段写的是 openspec/changes/** 与报告，不碰 skills/**；设计上的独立性不受影响——与 P36 那次"把 apply 派给 verify"不同）
issue:
change: roster-writer-and-route-truth
specs:  -
phase:  propose
anchor: change
deltas: memory-and-deps, init-skill, dispatch
deps:   D36/D37（本轮实测）· <ontology-project>（`do` 项目）的现场 · M48（`--allow-dup` 的先例）
status: todo（等席位）
sequencing: **必须排在 P43 的 apply 之后**（两者都写 memory-and-deps 的席位模型那条 requirement；delta 单写者）
budget: 一个工作块（只出提案包；不写实现）
```

> 本地模式：不 push。**只 propose。**

## 现场（`do`/<ontology-project> 项目的 PM 遇到的，PM 已逐环复现）

它的原话（session + `.pi/team/config.sh` 的提交）：

> 「扩充席位时发现团队工具的名册接口不一致：`config set` 拒绝修改名册，而它建议使用的 `add-agent`
> 又要求成员已在名册中。我会做最小的本地名册修正并记录原因，**不修改团队工具源码**。」

它最后手改了 `.pi/team/config.sh` 的 `TEAM_AGENTS`（带注释 + 一次 commit）——**处置正确**，
但我们**印出来的路线是假的**，而且 init skill 的承诺也不成立。

## 已复现的四条（都要在提案里引用，别重新发明）

| # | 位置 | 印出来的话 | 实际 |
|---|---|---|---|
| 1 | schema `TEAM_AGENTS`（`cmd-config.sh:43`）与 `:915` 的提示 | 「名册：**team add-agent / team teardown**」 | `add-agent` 走 `team_worktree_add` → **`team_require_agent`** → `未知 agent：…` 死掉；`teardown` **完全不碰** `TEAM_AGENTS`；全仓库只有 **bootstrap 的模板**写名册 → **只有手改 config.sh 能用** |
| 2 | `team config set-agent-model <不在名册的席位>` 的拒绝提示 | 「名册的键是 TEAM_AGENTS（只读）：**team add-agent / team teardown**」 | 同一条假路线；于是"给即将加入的席位预设模型"也做不了 |
| 3 | `team help` 的 add-agent 行 | `add-agent <a> **[--model m]**` | 解析器**不认** `--model`（只有 `--create/--no-install/--print`）→ `✗ add-agent: 未知参数 --model`（PM 实测） |
| 4 | `teamsmith-init` 的 SKILL | 「`team add-agent <name>` **adds more at any time**」 | 今天为假 |

## 提案要裁决的设计问题

1. **名册的写入路径**：给 `add-agent` 加**显式授权旗标**（如 `--register`，照 M48 `--allow-dup` 的先例：
   显式 + **一行审计**），写入走**配置写入器**（校验 + CAS + 审计），然后建/提示 worktree；
   不带旗标时**拒绝并给两条真能用的出路**（手改 config.sh / 加旗标）。
   **对称的移除**：`teardown --register`（或 `team roster remove`）——同样走写入器 + 审计。
   给出命名与语义的裁断（`--register` vs `team roster add|remove` vs 其它），并说明为什么。
2. **`set-agent-model` 与"即将加入的席位"**：要么允许未知席位（带可见警告 + 审计），要么让 `--register`
   能一次带上 `--model`；给出取舍（别留第二条假路线）。
3. **`--model`**：实现它，还是从 help 里删掉？（二选一，并**同步所有提到它的地方**）
4. **反例防复发（本任务的重点）**：加一个**可证伪的"路线真诚性"检查**——
   - 遍历 `team help` 的每条用法行 vs 各命令**解析器实际接受的旗标**（不一致 → 红，点名命令与旗标）；
   - 遍历 schema 里"点名命令"的注释（今天只有 `TEAM_AGENTS`/`TEAM_AGENT_MODELS`/`TEAM_PULSE_WINDOW` 少数几条），
     断言**被点名的命令存在**，且**在夹具里真的能做到那句话承诺的事**（做不到 → 红）。
   这条检查是"**印出来的路线必须真能用**"的机制化——`do` 那次就是被它该抓住的。
5. **文案同步**：schema 注释、`cmd-config.sh:915`、`team help`、init skill、`references/protocol.md`
   （各自写清"谁写名册、要不要授权、留什么审计"）。
6. **口径不变**：`TEAM_AGENTS` 仍**refuse 类**（控制台不得给自己扩权）——**新增的是"显式授权的 CLI 入口"**，
   不是把键改成可写；控制台侧仍然只读、仍指路。

## 硬要求

- **policy B**：delta 落 `memory-and-deps`（名册/契约语义）、`init-skill`（承诺修正）、
  以及 `dispatch` 或 `watchdog`（按语义选一个并说明）；每条可证伪、MODIFIED 不删 base scenario；
- 每条 requirement 给"复核方法"；
- **不写实现**（`scripts/**`、`tests/**`、`skills/**` 一律不改）；现实与上文冲突 → `BLOCKED:` 交回 PM。

## Deliverables

- `openspec/changes/roster-writer-and-route-truth/{proposal.md,design.md,tasks.md}`
- `openspec/changes/roster-writer-and-route-truth/specs/*/spec.md`
- 报告 `docs/team/reports/P46-<agent>.md`
