# M22 · 移除 skills/pi-team 兼容软链（用户拍板提前结束别名期）

```
task:   M22
agent:  verify
issue:  
change: -            # OpenSpec change id this brief implements (`openspec list`, e.g. add-agent-timeout); "-" if no requirement changes
specs:  -            # requirements/scenarios it must satisfy, e.g. `dispatch: a brief is self-contained`; "-" if none
phase:  -            # OpenSpec pipeline phase this brief runs: explore|propose|apply|verify|archive ("-" for work outside the pipeline); one phase = one brief = one owner
deps:   M20          # 同一文件 smoke.sh，等 M20 合并后再开工，避免撞车
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，把任务分支留在 `.worktrees/dev2` 工作树即可，PM 复验后本地合并。

## Context

v1.13.0 改名时留了 `skills/pi-team → teamsmith` 兼容软链，承诺到 v2.0.0。**用户 2026-09-17 拍板提前移除**(<crm-project> 已全部转用 teamsmith 路径）。PM 已盘点依赖：

- `~/.agents/skills/pi-team`（本机 skill 安装路径）链到仓库的 `skills/pi-team`——**PM 会先把它改成指向 `skills/teamsmith` 的 `~/.agents/skills/teamsmith`，再撤旧链**（这步 PM 已做/或自己做，worker 不动家目录）。
- smoke.sh 三处钉着软链：约 3735 行（软链在位断言）、4861 行附近注释、4974-75 行（软链目标断言）。
- 文字承诺散在：`README.md`（两处）、`skills/teamsmith/SKILL.md`（Name and compatibility 一节）、`skills/teamsmith/references/migration.md`、`skills/teamsmith/CHANGELOG.md`（历史条目不动，只加新条目）。
- 风险留痕：其它老项目若仍有 config 写死 `skills/pi-team` 绝对路径，移除后它们的 `team` 调用会断——用户已知悉并拍板；迁移指引要写清「把路径里的 `skills/pi-team` 换成 `skills/pi-team`→`skills/teamsmith`」。

## Deliverables

1. 删除 `skills/pi-team` 软链（`git rm`）。
2. `skills/teamsmith/tests/smoke.sh` — 移除/改写三处钉软链的断言与注释；若有「老路径能用」的正向用例，改为「旧路径不存在时报可懂的错」或不测（说明理由）。
3. 文档同步：`README.md`、`SKILL.md`（兼容段改写：软链已移除，`/pi-team-reload` 命令别名保留到 v2.0.0——那是扩展命令名，与路径无关）、`references/migration.md`（加条目：软链何时移除、老项目怎么改路径）、`CHANGELOG.md` 顶部加一条。
4. 检查 `skills/teamsmith/` 内是否还有指向 `skills/pi-team` 的**功能性**引用（extension、install 脚本、模板里的默认路径），一并改掉；历史文档（reports/reviews/CHANGELOG 旧条目）不改。

## Boundaries (do not do)

- 不动 `~/.agents/skills/`（PM 属地）；不动其它项目。
- 不删 `/pi-team-reload` 命令别名（命令名兼容期到 v2.0.0，与路径是两回事）。
- 不改 CHANGELOG 的历史条目。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
test ! -e skills/pi-team && echo removed
grep -rn "skills/pi-team" skills/teamsmith/SKILL.md README.md skills/teamsmith/scripts/ skills/teamsmith/extension/ skills/teamsmith/templates/  # 应为空（migration.md/CHANGELOG 的说明性提及除外，逐个列出）
```

## Report

Write it to `docs/team/reports/M22-dev2.md` (format: `docs/team/PROTOCOL.md` or the skill's
`templates/report.md.tmpl`). It must contain: deliverables, the real commands with output tails, anything not
verified / risks, deviations from this brief, and next-step suggestions.
