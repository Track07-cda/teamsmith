# P34 · pi-only-scope：把对外契约收成 Pi-only，适配层降为内部接缝（propose）

```
task:   P34
agent:  dev3
issue:
change: pi-only-scope
specs:  -
phase:  propose
anchor: change
deltas: agent-adapters, init-skill, memory-and-deps
deps:   M3.0/M3.2（适配层实现）· M8（适配器文档）· M26（harness/插件检测）
status: todo
budget: 一个工作块（只出提案包；不写实现）
```

> 本地模式：不 push。**只 propose。**

## 用户的决定（2026-09-22，原话）

> 「现在的问题是也没有用别的 agent 测试过，你也只做了 pi 的支持插件。**L2**，
> 未来有能力和时间肯定**预留**对其他 agent 的支持。」

已记录为 `docs/team/DECISIONS.md` **D35**。摘要：
1. **对外只承诺 Pi**；2. **4 个适配器键保留为内部接缝（frozen）**，不承诺兼容、不在 init 问卷里问；
3. **不删代码、不改 Pi 行为**；4. 路线图 M3/M8.1/C1 **推迟而非删除**（预留未来）。

## 提案要解决的设计问题

1. **契约怎么表述**（`agent-adapters`，现 3 requirement / 12 scenario）：
   - 把"any TUI agent can be a worker"改成"**Pi 是唯一被支持的 harness**；启动/通知接缝是**内部实现细节**"；
   - **既有 12 条 scenario 一条不许丢**（MODIFIED 规则）；要补的 scenario 至少覆盖：
     ① 文档/描述不承诺非 Pi harness（可证伪：文本里出现"any TUI agent/任意 agent"之类 → 红）；
     ② init 问卷不问适配器；③ 未知/不受支持的 `TEAM_AGENT_CMD` 不被描述成受支持路径；
     ④ Pi 默认路径（M27 起 `-e team-bg.ts` 等）逐字节不变。
   - **评估并说明**：现有的"模板契约强制/首词解析/PM 也是适配器"三条 requirement 是**保留原样**、
     还是**降级为内部事实**（若降级，给出理由与替代的证据面）——两条路都行，但必须论证。
2. **`init-skill`**：检测面收成 **Pi 版本（≥ 0.76.0 的既有口径）+ Pi 插件**；去掉"其它 harness"的措辞与分支；
   M26 的"报告已安装插件、只推荐 teamsmith 必要/用到的"行为**保留**。
3. **`memory-and-deps`**：4 个键在 schema/`references/config.md` 的描述加**内部接缝（frozen）**标注；
   说明"为将来的非 Pi 适配预留、不承诺兼容、不在 init 问卷里问"；**键的类别（apply）与行为不变**。
4. **规模**：预计 3–5 条 requirement 改动、10–18 条 scenario；别膨胀。

## 证据（提案要引用，不是重新发明）

- 面在哪：`README.md:5`、`skills/teamsmith/SKILL.md` 的 description 与 §Agent adapters、引用表一行；
  `skills/teamsmith-init/SKILL.md`；`references/agent-adapters.md`（34 处键引用）；
  `references/config.md`、`troubleshooting.md`；schema（`cmd-config.sh` 4 处）；模板 8 处；
  `common.sh` 35 / `cmd-agents.sh` 15 / `cmd-project.sh` 10 / `cmd-watch.sh` 3（**代码不动，只是说明面**）。
- ROADMAP：M3、M8.1、C1 三行（**PM 会自己改**，你只在 design 里写"路由图相应标注推迟"）。
- 先例：本仓库的"内部接缝"写法可参考 M67 的墓碑行（`refuse` 类 + 退役说明）——但**适配器键不是 refuse，
  它们仍可写**，只是不承诺。

## 硬要求

- **跨任务规则 + 对外承诺 → policy B 强制**：delta 落在 `agent-adapters`/`init-skill`/`memory-and-deps`，
  每条可证伪；MODIFIED 不得删 base scenario；
- 每条 requirement 在 design 里给"复核方法"（跑哪个脚本/看哪一段、期望什么）；
- **不写实现**（`scripts/**`、`tests/**`、`extension/**`、`references/**`、`README.md`、SKILL 一律不改）；
  发现现实与 D35 冲突 → `BLOCKED:` 交回 PM。

## Deliverables

- `openspec/changes/pi-only-scope/{proposal.md,design.md,tasks.md}`
- `openspec/changes/pi-only-scope/specs/{agent-adapters,init-skill,memory-and-deps}/spec.md`
- 报告 `docs/team/reports/P34-dev3.md`

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```
