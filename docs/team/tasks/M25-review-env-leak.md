# M25 · 复验基建：TEAM_REVIEW_* 覆盖项泄漏进门禁环境 + 后台窗口跑 review 必挂 6i

```
task:   M25
agent:  dev2
issue:  
change: -            # "-" if no requirement changes
specs:  -
phase:  -
deps:   M23          # 同族基建，排在其后
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev2`。

## Context

2026-09-17 复验日的两个基建洞（PM 实跑记录都在）：

1. **环境泄漏**:`TEAM_REVIEW_ANY_DIR=1 team review …` 时，覆盖项继承进门禁子进程；smoke 夹具里
   「拿错 checkout 必须拒绝」的用例被泄漏的 override 放行 → 三条断言红（现场：`docs/team/reviews/V16-verify.log`
   首次 FAIL）。smoke 只清 `TEAM_*` 身份变量，不清 `TEAM_REVIEW_*`。
   修法（报告里取舍）：cmd-review.sh 跑门禁时 `env -u` 掉全部 `TEAM_REVIEW_*`（治本，护所有调用方），
   和/或 smoke 夹具自清（对齐既有身份变量清理）。
2. **后台窗口里跑 `team review` 必挂**：矩阵实锤——前台+review 包装 绿 4/4（343–353s）;
   后台 tmux 窗口+review 包装 在 6i 段第 27 条断言后卡死到超时 3/3；后台窗口+裸跑门禁 绿。
   现场日志：`docs/team/reviews/M20-verify.log`（TIMEOUT）等。诊断方向：TERM 被忽略说明有 trap/子进程
   卡住；6i 第 27 条后是裸名字解析区（`pm_probe`/`bash -lc`）；后台窗口与前台 bash 工具调用的环境差
   （PM 派单后台化的前提——PM 不该被 6 分钟门禁堵回合——就卡在这题上）。

## Deliverables

1. 泄漏修复 + 翻转证据（夹具里故意设 override → 门禁内夹具行为不受其影响）。
2. 后台挂起的根因报告（实测定位到具体调用），修复或给 BLOCKED 证据交回 PM。
3. 修后验收：后台窗口跑 `team review` 全程绿。

## Boundaries

- 不降低门禁判定力；不动 review 记录的格式契约。
- `skills/teamsmith/scripts/lib/cmd-review.sh` / `tests/smoke.sh` 之外不动。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 后台窗口实测：tmux 新窗口里 team review <ID> --dir … 全程绿
```

## Report

`docs/team/reports/M25-dev2.md`（格式见 `templates/report.md.tmpl`）。
