# P15 · propose: split-teamsmith-init-skill（E7 轻拆形态，用户拍板直接拆）

```
task:   P15
agent:  dev
issue:  
change: split-teamsmith-init-skill  # 本任务只产规划产物；apply 等 PM 提案评审 ACCEPTED
specs:  -
phase:  propose      # 纯规划：openspec/changes/<id>/ 四件套，不写码
deps:   E7           # 探索报告已验收（D27）
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev`。

## Context

E7（探索报告 `docs/team/reports/E7-dev.md`，PM 已验收，D27）回答了「拆不拆」；**用户拍板：直接拆，且 CLI 工具必须保持统一不分叉**（用户原话）。E7 报告给出了「轻拆」形态与本任务所需的全部盘点数据（§Q1 逐节分类、§Q4 版本机制、§Q6 代价表）——提案必须把报告读透，下面只是定调：

**轻拆 = 拆「指引与入口」，不拆「工具与代码」**:
- 新建 `skills/teamsmith-init/`：自己的 SKILL.md（≤100 行：交互式初始化问答清单 → 跑 bootstrap → 交接句「日常运转读 teamsmith」）；迁入 `references/bootstrap.md`、`templates/bootstrap-prompt.md.tmpl`。
- 日常 `skills/teamsmith/SKILL.md`：删 §New project + §30-second start 两节，留一行指路；description 删 3 个 init 短语（实测 1000 字符贴 1024 上限）、加 init 指路句。
- 共享不分叉：`scripts/`（唯一 team CLI)、templates、extension、tests 全部留在日常 skill；版本号两边共用 `TEAM_VERSION`,CHANGELOG 一份；`team_skill_hash` 指纹仍只算日常 SKILL.md + extension（init 文本变化不吵醒在跑的 PM——E7 §Q4 第 2 条）。
- 安装:`~/.agents/skills/` 加一条软链（形态 A，E7 §Q5）。
- 已知代价：smoke 约 130 处引用重排（E7 §A.8：SKILL.md 24 / references 74 / bootstrap 32）、`metadata.version` 断言改「两边相等」、新增「两条 description 无 init 词交叉污染」断言、`tests/skill-load.mjs` 对两个目录各跑一遍。

## Deliverables（全部是规划文档，零代码）

1. `openspec/changes/split-teamsmith-init-skill/proposal.md` — 为什么（E7 的三条修正后的论点）、拆/不拆边界、轻拆形态、触发式拆分的三条 D27 触发条件作废说明。
2. `specs/` delta — 自行判定挂在哪个/哪些 capability（留意 pm-lifecycle、bootstrap 无现成 spec 可能要新增 capability），每条 requirement 带可证伪 scenario。
3. `design.md` — 目录形态、安装软链、版本/指纹机制、smoke 重排清单（逐类列出）、迁移期承诺（存量项目零改动）、回滚。
4. `tasks.md` — 实施任务分解（每步可验收、可独立复验），含「init SKILL.md 的问答清单内容」草稿大纲（收编 E7 §Q3 找到的 5 个散点：bootstrap-prompt.md.tmpl §2 / config.sh.tmpl 注释 / bootstrap.md / SKILL.md §New project / workflows.md §A）。

## Boundaries (do not do)

- 不写任何实现代码、不改 SKILL.md/scripts/tests（apply 相的事）。
- 不创建第二个 CLI、不分叉 scripts/（用户红线）。
- 不给 init skill 设计对 pulse/派单的任何所有权（它只管初始化）。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict   # 含新 change 必须绿
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
```

## Report

`docs/team/reports/P15-dev.md`：四件套路径清单、关键取舍（capability 归属等）的理由、与 E7 报告的出入（如有）。
