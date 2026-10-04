# M18 · cmd-status.sh:463 team_watchdog_state_text 未定义（P8 改名漏网）

```
task:   M18
agent:  dev3
issue:  
change: -            # OpenSpec change id this brief implements (`openspec list`, e.g. add-agent-timeout); "-" if no requirement changes
specs:  -            # requirements/scenarios it must satisfy, e.g. `dispatch: a brief is self-contained`; "-" if none
phase:  -            # OpenSpec pipeline phase this brief runs: explore|propose|apply|verify|archive ("-" for work outside the pipeline); one phase = one brief = one owner
deps:   -
status: todo
budget: 半小时以内；超出就交 PARTIAL 报告
```

> 本地模式：不 push，把任务分支留在 `.worktrees/dev` 工作树即可，PM 复验后本地合并。

## Context

P8（watchdog → pulse 改名，v1.36.0）把状态函数改成 `team_pulse_state_text`（定义在 `skills/teamsmith/scripts/lib/cmd-watch.sh:1181`），但 `skills/teamsmith/scripts/lib/cmd-status.sh:463` 仍调用旧名 `team_watchdog_state_text`（全仓库已无此定义）。结果：`team digest` 每次都把一行 shell 错误打到输出中间：

```
PM ● 在运行（pi）…/cmd-status.sh: line 463: team_watchdog_state_text: command not found
 ｜ watchdog 
```

smoke 没拦住（digest 输出里出现 `command not found` 没有任何断言）。同一行的标签还是旧词 `watchdog`，应随改名显示 `pulse`。

## Deliverables

1. `skills/teamsmith/scripts/lib/cmd-status.sh` — 463 行改调 `team_pulse_state_text`（用法参照 `cmd-project.sh:452`），行内标签 `watchdog` 改 `pulse`。
2. `skills/teamsmith/tests/smoke.sh` — 加一条断言：跑 `team digest`，输出不得含 `command not found`，且 pulse 状态字段非空。该断言必须修前红、修后绿（翻转证据）。

## Boundaries (do not do)

- 只改上述两个文件 + `docs/team/reports/M18-dev.md`；不动 cmd-watch.sh，不动其他 watchdog→pulse 别名兜底逻辑（v2.0.0 才清理）。
- 不新增依赖。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh   # 快模式也必须绿
bash skills/teamsmith/scripts/team digest 2>&1 | grep -c 'command not found'   # 必须是 0
```

翻转证据：报告给出修复前 digest 的报错行（红）与修复后输出（绿），并演示把函数名临时改回旧名时新 smoke 断言变红（证明断言不是剧场）。

## Report

Write it to `docs/team/reports/M18-dev.md` (format: `docs/team/PROTOCOL.md` or the skill's
`templates/report.md.tmpl`). It must contain: deliverables, the real commands with output tails, anything not
verified / risks, deviations from this brief, and next-step suggestions.
