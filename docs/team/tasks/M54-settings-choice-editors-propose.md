# M54 · 设置视图：**有选择的地方就给选择**（propose）

```
task:   M54
agent:  dev-bob
issue:
change: settings-choice-editors
specs:  -
phase:  propose
anchor: change
deltas: panel, memory-and-deps
deps:   -
status: todo
budget: 一个工作块（只出提案包：proposal / design / delta / tasks.md）
```

> 本地模式：不 push。**只 propose**，不写实现。

## 用户原话（2026-09-21）

> 「pulse 项目配置不能全都是填空，如果是选择请配置好选择」

## 现状（PM 已核过的事实，你要复核）

- **schema 里已经有类型与约束**：`team_config_schema()`（`scripts/lib/cmd-config.sh`）每行是
  `KEY|class|kind|constraints|form|default|comment`；kind 分布（本项目实测）：
  `bool ×22`、`path ×18`、`text ×17`、`int ×13`、`seconds ×11`、`mb ×5`、`cmd ×5`、`bytes ×4`、
  `tpl ×3`、`enum ×3`（如 `TEAM_BRANCH_MODE=task,agent`、`TEAM_VCS=local,github,gitlab,other`）、
  `model ×2`、`winlist/pairlist/pattern/pct/list` 各 1；
- **但控制台的编辑路径是"填空"**：设置视图每行打开的是一个**纯文本编辑框**，两步确认后跑
  `team config set <KEY> <VALUE>`；`bool`/`enum` 也不例外；
- **`team config list --json` 目前不含"可选集合"**：只有
  `name/class/kind/form/value/default/set/comment/warning/route/known`（缺 choices）。

## 要提案化的内容（每条 requirement + 可证伪 scenario）

1. **选择集只有一个来源 = schema**：`kind` + `constraints` + `default` 决定可选项；
   `team config list --json`（或等价出口）**新增一个字段**把可选集合暴露出来，**CLI 与控制台共用同一份**；
   面板**不得硬编码任何选项表**。
2. **bool**：两选项（当前值 / 另一值）+ 默认值标注；不允许出现"手打 1/0"的空格。
3. **enum**：只列出 constraints 里的取值（例如 `task|agent`、`local|github|gitlab|other`），非法值不出现在选择里。
4. **model / pairlist / winlist**：给出**本项目已知的模型集合**（`TEAM_DEFAULT_MODEL`、`TEAM_AGENT_MODELS`/`TEAM_PM_MODEL`
   的现值、当前会话实际在用的模型），**不要把 Pi 的整个模型目录倒出来** ——
   证据：本机目录里有 `sub2api/*` 一个**端点已下线**的 provider（`<internal>` 连接被拒），
   把它作为可选项就是给用户挖坑。
5. **数值类**（`seconds`/`int`/`mb`/`bytes`/`pct`）：给出**建议值**（例如巡检周期 300/900/1800/3600）
   **并且**允许自由输入；越界时**点名区间**拒绝（沿用现有校验语义，不弱化）。
6. **未设键**：显示「未设 → 默认 X」**并**提供显式的「恢复默认（unset）」选项 —— 视图里**不出现空白填空**。
7. **refuse 类**保持只读（不提供编辑器），保留"该用哪条命令"的指引；**path** 类给「当前值 / 默认 / 清空」
   并按 `dir|file,opt` 校验存在性。
8. **降级可见**：当 schema 认不出这个键、或某个键没有可选集合时，编辑器**可见地**退回自由输入并写明原因
   （不许静默、不许假装有选择）。
9. **可证伪性（最重要的一条 flip）**：往 schema 里**新增一个 enum 键** → 控制台**零改动**就能给出它的选项；
   把该键的 constraints 去掉 → 编辑器**可见地**退回自由输入。两条都要有夹具。

## design 要顺带裁决

- `--json` 新增字段的形状（名字、每种 kind 的表达：字符串数组？区间？bool 的两个标签？）与兼容性；
- **写入路径不动**：仍然是两步确认 + CAS 指纹 + `team config set` 的唯一写入者（P22 的规则不许被绕过）；
- 数值建议值从哪来（schema 里加第 8 列？还是在 design 里给一张"kind → 建议值"表？）——给出理由；
- 面板交互：小键盘/鼠标两套操作都要能用（P20 的规则：每个键位都要有鼠标等价物）。

## Deliverables

- `openspec/changes/settings-choice-editors/{proposal.md,design.md,tasks.md}`
- `.../specs/panel/spec.md`、`.../specs/memory-and-deps/spec.md`（delta，明确 ADDED/MODIFIED）
- 报告 `docs/team/reports/M54-dev-bob.md`

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```

## Boundaries

- 只 propose：不改 `scripts/**`、`tests/**`、`extension/**`（apply 阶段由任务书授权路径）。
- 不动写入者语义（校验、CAS、审计、危险值清单）；不动 `refuse` 类的既有行为。
