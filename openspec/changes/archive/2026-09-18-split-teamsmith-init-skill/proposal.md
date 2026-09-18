# split-teamsmith-init-skill · proposal

## Why

初始化指引与日常运转指引混在一个 skill 里，三个论点经 E7 实测修正后仍然成立（E7 §Q6，D27 已验收）：
①「日常 agent 加载用不上的初始化指引」真实但体量小——常驻成本只有 description 里 3 个 init 短语的 113
字符（977/1024 已贴顶，日常能力再加词就要顶爆）；②「初始化是交互式的」不在工具里，是 PM↔用户的对话，
拆分改变的是指引的**集中度**——「要问用户什么」今天散在 5 处（bootstrap-prompt 模板 §2 / config.sh.tmpl
注释 / bootstrap.md / SKILL.md §New project / workflows.md §A），没有一份集中的问答清单；③「skill 不该
大而全」成立。**用户已拍板：现在直接拆，CLI 必须保持统一不分叉**——E7「先下沉、拆分留触发」的推荐随之
作废，D27 的三条触发条件（description 再顶上限 / 初始化长成多步向导 / init 独立分发）不再等待，本
change 即拆分本身。

## What Changes

轻拆 = 拆「指引与入口」，不拆「工具与代码」：

- 新建 `skills/teamsmith-init/`：`SKILL.md`（≤100 行：有序问答清单 → 跑 `team bootstrap` → 交接句
  「日常运转读 teamsmith」）；迁入 `references/bootstrap.md` 与 `templates/bootstrap-prompt.md.tmpl`
  （移动，不复制）。
- 日常 `skills/teamsmith/SKILL.md`：删 `## New project` 与 `## 30-second start` 两节，留一行指路；
  description 删 3 个 init 短语、加一句 init 指路；§Deeper reading 的 bootstrap.md 行改为指向 init skill。
- `workflows.md` §A（初始化命令序列，~14 行）缩成一行指路——超出 E7 最小清单的一项，理由：同一份
  初始化指引留两处必然漂移（design D2）。
- **不分叉**：`scripts/`（唯一 team CLI）、`templates/` 其余、`extension/`、`tests/` 全部留在日常
  skill；init skill 不含任何代码，不持有 pulse/派单/复验/合并的任何所有权。
- 版本与指纹：两个 SKILL.md 的 `metadata.version` 都跟随 `TEAM_VERSION`（单一来源不变），CHANGELOG
  一份；`team_skill_hash` 输入仍只是日常 SKILL.md + extension（init 文本变化不吵醒在跑的 PM，E7 §Q4.2）。
- 测试：smoke 重排 ~130 处引用（SKILL.md 24 / references 74 / bootstrap 32，E7 §A.8 与本树实测一致），
  版本断言从「common/SKILL/CHANGELOG 三处一致」（smoke.sh:3211）扩成「common/两个 SKILL/CHANGELOG 四处
  一致」，文档扫描段覆盖两个 skill，新增「两条 description 无交叉污染」「init 侧无代码」
  「指纹范围不变」断言，`tests/skill-load.mjs` 对两个目录各跑一遍。
- 安装：`~/.agents/skills/` 加一条软链（形态 A，E7 §Q5）；存量项目零改动（config/AGENTS 段/启动命令/
  指纹均不变）。

## Capabilities

### New Capabilities

- `init-skill`: 新项目初始化指引独立成 `teamsmith-init` skill，以及两个 skill 共存必须守住的不变量
  （单一 CLI 与版本来源、指纹范围不变、description 路由干净、存量项目零改动）。

### Modified Capabilities

（无：既有 12 个 capability 无一覆盖 SKILL.md 内容、description、版本元数据或指纹机制——grep
`openspec/specs/` 无命中，本 change 的承诺全部是新增。）

## Impact

- 代码零改动（CLI/scripts/extension 不动）；受影响的是文档与测试：`skills/teamsmith/SKILL.md`、
  `references/{bootstrap,migration,workflows}.md`、`templates/bootstrap-prompt.md.tmpl`、
  `tests/smoke.sh`（断言路径与扫描范围）、`skills/teamsmith-init/**`（新增）。
- 边界（不做）：不创建第二个 CLI、不复制 references/templates 到两侧、worker 与 opsx 不拆（E7 实测与
  skill 边界正交）、init skill 不碰 pulse/派单/复验/合并、不建多步向导（一份清单，不是向导框架）。
- 验收命令（apply 完成判据，逐字可跑）：

  ```sh
  PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
  bash skills/teamsmith/tests/smoke.sh
  ```

- apply 报告须含：两条门禁的输出尾部、每条新断言的翻转证据（改坏 → 断言红 → 还原）、安装软链的
  `readlink` 输出、既有 fixture 项目流程（init/doctor/dispatch --print）不变的对照。
