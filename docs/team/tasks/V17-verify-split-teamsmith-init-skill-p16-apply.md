# V17 · verify: split-teamsmith-init-skill（P16 apply 的独立验证）

```
task:   V17
agent:  verify
issue:  
change: split-teamsmith-init-skill
specs:  init-skill 全部 6 条 requirement（见 openspec/changes/split-teamsmith-init-skill/specs/init-skill/spec.md）
phase:  verify       # 你与 propose(dev)/apply(dev3)都无关，独立验证
deps:   P16
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/verify`。**验证对象是 main 已合并后的树**（P16 已合进 main，tag v1.40.0 已打）。分支从 main 切，报告与证物落在 `docs/team/reports/V17-verify*`。

## Context

P16 把 teamsmith 拆成两个 skill（日常 + init），已合并主线并随 v1.40.0 发布（apply 的 PM 复验 PASS）。按管线还要一次**独立验证**（verify 相，由没碰过 propose/apply 的你做），通过后才由 PM 归档 change。

提案四件套在 `openspec/changes/split-teamsmith-init-skill/`；apply 交付报告 `docs/team/reports/P16-dev3.md`；PM 复验 `docs/team/reviews/P16.md`。

## 要验证的（按 spec 的 6 条 requirement 逐条对账，给出 scenario 级别的证据）

1. init skill 存在、≤100 行、三拍（清单→bootstrap→交接句）、两个迁移文件只有新家；
2. 日常 SKILL.md 无 `## New project`/`## 30-second start`、有指路行、description 无 3 条 init 短语且有 `teamsmith-init`；
3. 两条 description 互不串词（三+三短语口径）、都 ≤1024；两个目录都能被 Pi 解析器加载（`tests/skill-load.mjs`）;
4. 单一 CLI：scripts/extension/tests 只在日常侧；工具引用 `teamsmith-init` 为零（grep 口径）;
5. 版本四处相等（TEAM_VERSION=两个 metadata.version=CHANGELOG 顶部）；init 无 CHANGELOG；**指纹范围不变**（改 init SKILL.md 指纹不变、改日常变——翻转）;
6. 存量项目零改动：fixture 项目 init/doctor/dispatch --print 与拆前一致；模板无 init 引用。

## 还要主动攻击（验证者职责，不止对账）

- smoke §18b 的新断言是不是剧场：随机挑 ≥3 条做翻转（改坏→断言红→还原）;
- init SKILL.md 的问答清单是否真的收编了 5 个散点（对照 tasks.md 附录 A 逐条勾）;
- 跨 skill 相对链接在仓库内是否全部可解析（逐个打开）;
- 装好的软链 `~/.agents/skills/teamsmith-init` 穿链加载（只读验证，不动它）。

## Boundaries

- 只产报告与证物（`docs/team/reports/V17-verify.md` + `V17-verify/`），不改 `skills/**`、`openspec/**`。
- 发现问题：写进报告分级（bad=违反 spec；finding=留痕），不许顺手修。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# + 上面每条验证的命令与输出进报告；翻转实录进证物目录
```

## Report

`docs/team/reports/V17-verify.md`（格式见 `templates/report.md.tmpl`），含明确判定：PASS / FAIL + findings 清单。
