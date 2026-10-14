# P256 · 启动时自愈（`team up` 自动完成老项目的机械升级）

task: P256
agent: dev2
phase: propose
category: analysis
change: startup-self-heal
specs: init-skill
deltas: init-skill
branch: task/P256-startup-self-heal-propose
deps: 用户 2026-10-14 的要求（原文）：「升级不应该这么手动，在启动时应该自动升级」

## 用户遇到的现实（这是本变更的动机，务必读）

一个 0.1.2 的项目升到 0.2.0，今天要人做四件事：① 升工具（npm + `install.sh`）；② 迁移配置（`config upgrade-models`）；③ 处理 PM 启动身份记录（缺记录时 `team up` 直接拒绝）；④ 重启会话；然后才 `team up`。用户在 ③ 撞墙并说「升级不该这么手动」。

**PM 的立场**（你要在 design 里正面回应，可反驳但要给依据）：启动路径要做到「**升完工具，`team up` 就够了**」——机械的部分自动做，需要判断的部分明确声明，**不许静默改值**。

## 要解决的两类「升级」，各自可自动到什么程度

### 一类：机械的键形状迁移（今天的 `config upgrade-models` 要人手工推导映射）

现状：旧配置里 `TEAM_AGENT_MODELS='<席位>=<模型> …'` + `TEAM_DEFAULT_MODEL=<模型>`，新契约是 `TEAM_TASK_MODELS='<类别>=<模型> …'` + `TEAM_PM_MODEL`。今天的拒绝要求用户**自己**推导那张映射。

可自动的规则（**值一个都不许改**，只改键形状与名字）：
- 旧 `TEAM_AGENT_MODELS` 的每个 `席位=模型` → **同名 `类别=模型`**（席位名要先过新校验的形状 `[a-z][a-z0-9-]*`；不合法时规范化并**在报告里说明原名**）；
- 旧 `TEAM_DEFAULT_MODEL` → 一个显式的兜底类别（建议名字 `default`，撞名则**报错并拒绝自动迁移**，不许悄悄换名）；
- 旧 `TEAM_PM_MODEL` → 新 `TEAM_PM_MODEL`（原样）；旧键为空或缺失时按今天的语义取值并在报告里说明；
- **两次写**：先写一份备份（`.pi/team/config.sh.pre-<版本>` 或 `state/` 下，你选并说明），再原子写配置，写一行审计（既有审计通道）。报告要打印**逐键的 before → after**（值原样可见）与备份路径。
- **仍拒绝的情况**（不许自动）：配置文件形状不可定位（注释/多行/变量展开/重复键——`upgrade-models` 今天已经会拒的形状）、兜底类别名撞车、旧键的值解析不出模型、或项目同时带着两者互相矛盾的值。拒绝时保留今天的手工路线（`--dry-run` 预览 + 手工修）。

### 二类：PM 启动身份记录（今天缺记录就拒绝 `team up`）

现状：`state/pm-launch.env` 缺失 → `team_pm_identity_guard` 拒绝，要求 `--fresh-pm`（= 新对话）。用户不想新开对话。

要点：**缺记录 ≠ 记录不一致**。缺记录时工具并没有关于过去的主张，它只是在为「这次启动」写主张。所以：
- **缺记录** → **默认自愈**：按**本次实际解析**（`team_pm_model_resolve` / `team_pm_resume_key`）写出记录，并在 `team up` 的输出里**显式一行**说明：`此前没有启动记录；已登记本次启动身份：model=… resume_key=… mode=continued`；若用户其实想换 PM 模型，那一行要提示「换模型必须 `--fresh-pm`」。
- **记录存在但不一致** → **仍然拒绝**（这是 R6/OBS1 的合同：不许把用模型 A 开的对话当成模型 B 续下去），但信息要分清两种情形、打印两边的值（并写明 suffix）、给出两条出路的后果——这部分今天的信息不合格（用户原话：「这个报错也很难懂」）。
- 补一个显式入口 `team up --adopt-pm-identity[--yes]`（或等价名），用于「我确认按当前解析续跑」；默认自愈只发生在**记录缺失**时，存在但不一致时必须显式。

### 三类：工具版本的**提示**（用户 2026-10-14 裁定 **A**，只提示不安装）

用户的问题原文是「升级不应该这么手动，在启动时应该自动升级」；我问的是「工具本身要不要自动 `npm i -g`」，用户选 **A：只检查并提示，不自动安装**。理由（写进 design）：自动安装是**全局**动作 + 联网，会同时影响同一台机器上其他正在跑的项目；升级时机应由使用者决定。

要求（可证伪，逐条配夹具）：
- **触发点只有 `team up`**（`doctor` 可顺手带，但**不要**每次命令都检查）；
- **来源**：npm 上的 `teamsmith` 最新版（`npm view teamsmith version --registry https://registry.npmjs.org`，**有界超时**，建议 ≤2s）；
- **缓存**：结果落 `state/`（本地、被忽略、不发布），带 TTL（建议 24h）；TTL 内不重复联网。缓存格式写清（检查时间 / 最新版本 / 检查时的本地版本）；
- **静默失败**：离线、npm 不存在、超时、registry 报错 → **一行都不打**（不噪音、不改 rc）；只有「本地版本 < 最新版本」时才打一行，形如
  `i 本地 teamsmith 0.2.0，npm 上已有 0.2.1：npm i -g teamsmith@0.2.1 --registry https://registry.npmjs.org && bash "$(npm root -g)/teamsmith/install.sh"`
  并明确「工具从不自己安装」；
- **不阻塞、不改 rc**：检查在启动决策之后做（或并行 + 有界等待），无论如何不影响 `team up` 的退出码与是否启动；
- **逃生舱**：环境变量 `TEAM_UPDATE_CHECK=0` 关闭检查（写进设计文档的键/环境变量表）；`--print` **不写缓存、不联网**（保持「只看不写」的合同），但要在预告里说明「本可检查版本，`--print` 下未检查」；
- **红侧**：桩 npm 分别答「有更新 / 相同 / 更旧 / 报错」→ 断言只有「有更新」时打那行、其余静默；断言那行**同时含**本地与最新版本号以及可粘贴的升级命令；断言检查失败时 rc 与启动行为**完全不变**；TTL 内不重复联网（夹具用旧缓存时间戳 + 桩计数）；`TEAM_UPDATE_CHECK=0` 时连联网都不发生。

### 明确**不**做（写进 design 的 Non-Goals，并说明理由）

- **工具自更新（安装）**：用户 2026-10-14 裁定 **A**——只做上面的版本**提示**，**不**自动 `npm i -g`（全局动作、影响其他项目、时机该由使用者定）。
- 在**别的会话**里重启 agent 会话（工具管不到），但可以在 `up` 的输出里提示「本项目有会话是用旧版本启动的」——若你能可靠判定（例如记录里存版本号），加一行提示；判不准就不做，别猜。
- 自动改**模型值**、自动改类别语义、自动把 `docs/pm` 搬成 `docs/team`（这些是判断，不是机械）。

## 你要产出的东西

一个 OpenSpec change（能力落点你定：`init-skill`/`dispatch`/新能力都行，但要在 proposal 里说明为什么），`openspec/changes/startup-self-heal/{proposal.md,design.md,tasks.md}` + 对应 delta。至少覆盖：

1. **迁移表与版本**：识别「这个项目是旧形状」的判据（哪些键/哪个 marker 版本）、支持从哪几个版本自动迁移、以及**未来如何加一条迁移**（版本表结构、谁写、怎么测）。要有一条「未知的更新形状」的守卫：既不静默放过，也不给出误导性的自动动作。
2. **两道自愈的触发点与顺序**：`team up`（以及 `bootstrap`/`init`？你评估）里先配置迁移、再身份登记、再建场地/拉 PM；失败时**回滚到可诊断状态**（备份在、配置半写不可能出现——原子写）。
3. **可见性**：`team up` 必须把「我自动做了什么」印成人话（逐键 before→after、备份路径、身份登记的一行、以及**为什么**这么做的一句话说明）；`--print` 下不得写盘，但要**如实预告**它将会自动做什么。
4. **逃生舱**：`--no-migrate`（本次不自动，只报告并拒绝，走手工路线）与 `--dry-run`/`--print`；另有一条「自愈后仍失败」的路径（信息里带备份与还原命令）。
5. **红侧**（每条给破坏/还原或前后对照）：旧配置 → `up` 自动迁移且**值逐键不变**（夹具比对迁移前后每个模型的字符串）；形状不可解析 → 拒绝且**一个字节都没写**；兜底类别撞名 → 拒绝；记录缺失 → 自动登记 + 那行说明；记录**存在但不一致** → 仍拒绝且信息含两边值；`--no-migrate` → 不写盘且拒绝；`--print` → 不写盘但预告正确；迁移后 `config list` rc=0 且 `dispatch --print` 能按类别选中模型。
6. **与既有合同的兼容**：`team config upgrade-models` 保留为手工入口（语义不变）；`team init`/`bootstrap` 的拒绝行为按新规则统一（能自愈的自愈、不能的老实拒绝）；审计与备份不破坏既有审计读取。

## 边界

- 只写提案；apply 与 verify 另行换人。
- 与在飞任务的分工：**P254**（拒绝信息说人话 + 显式 adopt 入口）与 **P253**（旧配置拒绝信息要打印推导命令）**内容并入本变更**（PM 会把它们的任务行标为 absorbed，你不要重复实现；把它们的要点吸收进本设计）；**P255**（升级文档重写）等本变更落地后按新行为写（PM 会同步改写它的任务书）；**P252**（help 分级 + 语言层）只碰 `cmd-project.sh` 的帮助段，你不要动那段。
- 不合并、不推送；做完 `team notify pm`。

## 验收（本阶段）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/P256-dev2.md
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
