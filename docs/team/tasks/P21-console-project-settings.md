# P21 · propose: 控制台里配置项目设置（`config.sh` 的可编辑子集）

```
task:   P21
agent:  dev-bob
issue:  
change: console-project-settings
specs:  panel, memory-and-deps      # 若 design 判定要动第二个 capability，在 tasks/delta 里说明
phase:  propose
deps:   P20（panel-ergonomics，已合并）——本提案基于它的设置浮层与字符串表
status: todo
budget: 一个工作块；只做 explore/propose，不写实现
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev-bob`。

## Context（用户原话）

「Pulse 需要能够配置 teamsmith 项目的设置」——现在改项目设置只能手编 `.pi/team/config.sh`
（`TEAM_*` 共 47 个键、18 行注释），而 pulse 控制台是 PM/用户最常看的界面。用户希望**在控制台里改**，
不想开编辑器。

现状（实现前先自己核一遍）：

- 面板已有**设置浮层**（`skills/teamsmith/scripts/panel/src/settings.ts`：语言/主题/密度/默认页，
  存 `state/panel.conf`）——那是**面板自己的**设置，不是项目设置；
- 项目设置 = `.pi/team/config.sh` 的 `TEAM_*`：身份（`TEAM_PROJECT/TEAM_SESSION/TEAM_PM_WINDOW`）、
  名册（`TEAM_AGENTS/TEAM_AGENT_MODELS`）、门禁与安装（`TEAM_GATES/TEAM_INSTALL_CMD`）、
  目录（`TEAM_DOCS_DIR/TEAM_WORKTREES_DIR`）、分支与远端（`TEAM_*_BRANCH*`、`TEAM_REMOTE/TEAM_VCS`、
  GitLab 键）、容量阈值、复验超时、通知去重、**pulse 一族**（`TEAM_PULSE_WINDOW/INTERVAL/NUDGE_GAP/
  REBUILD_TMUX/MAX_RESTARTS/PENDING_BOARD`）、模型（`TEAM_DEFAULT_MODEL/TEAM_PM_MODEL`）等；
- 已有一个写入口 `team_config_set_in_file`（`cmd-bootstrap.sh`），bootstrap/`team init` 用它改文件。

## 提案必须回答的问题（design.md 里逐条给结论）

1. **哪些键可以在面板里改、哪些不能**——按**生效语义**分三类，每类给出判据与界面行为：
   - `apply-now`（下次读配置即生效，如 pulse 周期/去重/容量阈值/门禁串）；
   - `needs-restart`（要重启 pulse 或重建窗口才生效，如 `TEAM_PULSE_WINDOW`；
     用户明确点头才写，并在界面写清「何时生效、怎么生效」）；
   - `refuse`（身份/名册/目录类：`TEAM_PROJECT/TEAM_SESSION/TEAM_PM_WINDOW/TEAM_AGENTS/
     TEAM_WORKTREES_DIR/TEAM_DOCS_DIR` 等 —— 改了会让窗口/工作树/看板对不上；界面**只显示、不可编辑**，
     并给出正确的命令（如 `team add-agent`）作为出路）。
2. **写文件的安全语义**（这条是重点，别糊过去）：
   - 保留**注释与未改动的键及其顺序**（`team_config_set_in_file` 的既有语义，先核清它到底保留什么）；
   - **并发/覆盖保护**：打开编辑器时记下文件指纹（mtime+sha256），提交前复核；文件被别处改过 → 拒绝写入并
     提示重新加载（不允许静默覆盖别人的改动 —— 与 M40 的「身份不许静默赢」同一原则）；
   - 写入失败/语法破坏（`bash -n config.sh`）→ 回滚并报错，不得留下坏配置；
   - 值校验（布尔/整数/枚举/路径存在性）与**危险值**（如 `TEAM_PULSE_INTERVAL=0`）的拒绝或警告规则。
3. **交互**：放在现有设置浮层里做「项目设置」分区，还是独立页？键位（与 P20 的编辑键位一致）、
   长值/多值（`TEAM_AGENTS` 是空格分隔的多值）怎么编辑、如何搜索/过滤 47 个键、
   `refuse` 类的展示方式。给**可证伪的 scenario**（不改就是红）。
4. **生效与可观测**：写入后界面如何反映「已生效 / 需重启脉冲 / 需重建会话」；要不要提供显式的
   「重启脉冲」动作（若提供，它是对 `panel` 的只读契约的**第 N 个例外**，必须在 delta 里明确写出来，
   并把只读 requirement 的例外清单更新——现在写的是「三个命令」）。
5. **审计**：谁改的、改了什么、何时 —— 至少一行日志（`state/` 下），并能从面板回溯。

## Deliverables（propose 阶段）

`openspec/changes/console-project-settings/`：`proposal.md`（为什么/范围/影响面）、`design.md`（上面 5 条逐条结论，
含被否方案与理由）、`specs/panel/spec.md`（delta：至少一条 ADDED + 对既有「只读只三例」requirement 的 MODIFIED）、
`tasks.md`（apply 分批，每批自带夹具与翻转）、必要时 `specs/memory-and-deps/` 的 delta。
**不要写实现**。

## Boundaries

- 不改变 `.pi/team/config.sh` 的既有键名/语义；不引入第二份配置来源（面板只编辑这一个文件）。
- 不碰 `.worktrees/*` 里其他 agent 的东西；`smoke.sh` 若在示例里要提，只写不改。
- 规格写作遵守 `skills/teamsmith/references/openspec.md`（requirement/scenario 约定、MODIFIED 与 base 必须匹配）。

## Acceptance (must actually be run)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
PATH="$HOME/.bun/bin:$PATH" openspec show console-project-settings --json | head -40
```
另附：`team_config_set_in_file` 的**实测行为**（它保留注释吗？保留顺序吗？给一段真实输出）。

## Report

`docs/team/reports/P21-dev-bob.md`。

---

## 追加要求（用户 2026-09-20 01:1x）：**Agent 的模型配置**要一并覆盖

用户问「Agent 的模型配置？」——现状（自己核一遍，别照抄）：

- 三层解析：`TEAM_DEFAULT_MODEL`（全体默认）→ `TEAM_AGENT_MODELS="dev=provider/model verify=…"`
  （按席位覆盖，空格分隔的 `键=值` 对）→ 派单/续跑时的 `--model`（一次性）；
- **生效时机 = 窗口 spawn**（`dispatch`/`resume`）：正在跑的 agent 不会因为改了配置就换模型，
  它的窗口要重启才生效；
- 展示来源：`team_agent_model_src <agent>` 会标出当前展示的模型来自「配置 / 显式 / 历史记录」
  （`state/<agent>.env` 里的 model 只是"上次用了什么"的记录，不参与解析）——面板若要显示模型，
  必须把这三态如实标出来，不能只显示一个裸模型名。

因此本提案里模型一族要这样处理：

1. `TEAM_DEFAULT_MODEL` / `TEAM_AGENT_MODELS` / `TEAM_PM_MODEL` 一律归 **`needs-restart`** 类，
   界面必须写清「对谁生效、什么时候生效」（例：`dev` 下次派单/续跑时用新模型；`pm` 需重建 PM 进程）；
2. 交互上除了编辑 `TEAM_AGENT_MODELS` 那一行，**按席位编辑模型**要有独立入口（选席位 → 选模型 →
   写回配置），并把上面的三态来源一起显示；
3. 是否提供「**立即用新模型重启该席位**」的动作由你在 design 里裁决：若提供，它是对 `panel` 只读契约的
   **新例外**（和「重启脉冲」同类），必须在 delta 的只读 requirement 里逐个列出，并写清拒绝条件
   （例如该席位有未提交改动/正在跑任务时不给重启，或只允许 `--fresh`/`--allow-overflow` 二选一）。
4. scenario 至少覆盖：改 `TEAM_AGENT_MODELS` 后**运行中的席位不变**、下一次 spawn 生效、
   三态来源显示正确、`refuse` 类键（名册）不会被误写。
