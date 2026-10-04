# pm-skills · 目录归属（Ownership）

> **只改属于你的目录。** 需要跨目录改动 → 在报告里写 `BLOCKED:` 说明谁该改什么，交回 PM 协调。
> 没有列出的目录 = PM 独占。

| 路径 | Owner | 说明 |
|---|---|---|
| `skills/teamsmith/tests/**` | agent:dev | 测试与门禁脚本（本阶段只在此处动刀） |
| `docs/team/reports/**`、`docs/team/threads/**` | agent:* | 报告与线程（只写自己的报告文件） |
| `docs/team/tasks/**`、`docs/team/BOARD.md`、`docs/team/ROADMAP.md`、`docs/team/DECISIONS.md`、`docs/team/OWNERSHIP.md` | PM | 任务书与看板 |
| `skills/teamsmith/scripts/**`、`extension/**`、`panel/**`、`SKILL.md`、`references/**`、`templates/**` | apply 阶段任务书**明授**的 agent（默认 PM） | 实现；未获授权 → `BLOCKED:` 交回 PM |
| `.pi/**`、`AGENTS.md`、`README.md`、`docs/**`（除上面列出的） | PM | 团队协议与配置 |

## 名册

| Agent | 模型 | 长期 worktree | 负责范围 |
|---|---|---|---|
| dev | `kimi-coding/k3-256k` | `.worktrees/dev` | 任务书授权的实现路径 + `skills/teamsmith/tests/**` |
| dev2 | 默认 | `.worktrees/dev2` | 任务书授权的实现路径 + 报告 |
| dev3 | 默认 | `.worktrees/dev3` | 任务书授权的实现路径 + 报告 |
| dev-bob | 默认 | `.worktrees/dev-bob` | 任务书授权的实现路径 + 报告 |
| verify | `openai-codex/gpt-5.6-terra:xhigh` | `.worktrees/verify` | **对抗性复验：只写报告与复验证据，不改实现**（2026-09-21 起恢复严格执行） |

> **实现路径的授权方式（2026-09-21 明确，取代早期"实现一律 PM 独占"的写法）**：
> apply 阶段的 agent 可以改**它的任务书在 `deps:`/`Boundaries` 里逐条列出的实现路径**；
> 任务书没列的路径 = 不能碰 → 在报告里写 `BLOCKED:` 交回 PM。
> `verify` 席位例外：**无论任务书怎么写，都不改实现**（它的价值在于独立）。

## 变更流程

1. 需要新目录归属 → PM 改本文件（并在任务书里引用）。
2. 临时借用 → 必须在任务书里写明 **临时** 与移交条件。
3. 复验收到的 finding 由 PM 决定是改实现（PM 自己改）还是派回 agent（写进线程）。
| `openspec/specs/**` · `openspec/config.yaml` | PM | 规格与配置是账本的一部分 |
| `openspec/changes/<change>/**` | 该 change 当前阶段的 owner（任务书明授） | propose 归提案者；apply 归实现者；archive 由 PM 执行 |
