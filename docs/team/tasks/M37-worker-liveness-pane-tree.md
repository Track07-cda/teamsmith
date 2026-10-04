# M37 · worker 存活探测：看 pane 进程树而不是 pane_current_command（假「停了」告警）

```
task:   M37
agent:  verify
issue:  
change: -            # "-" if no requirement changes
specs:  -
phase:  -
deps:   -            # 与 M35/M36 无依赖；dev3 手头有 M34，本任务给 verify
status: todo
budget: 半个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev3`。

## Context（2026-09-19 实测两次假告警）

worker 的存活探测把**正在干活的 agent 判成「停了」**：

```
pane_pid=2301923 (bash)          # 派单的窗口 harness：bash 起 pi
  └─ 2302022 pi                  # pi 是 bash 的子进程，活着、在跑
tmux display-message -p -t teamsmith:dev '#{pane_current_command}'  →  bash
```

`pane_current_command 报 bash`（不是 pi）→ 探活认为窗口里没有 agent → pulse 的
「停了的 agent N」告警两次误报（dev/ M36、dev2/ M35 都在干活时被点名），
`team ps`/digest 里也会把人看成 idle/停止。

对照：PM 存活判据（M6.5，#1057）**已经是**「pane_pid 或其直接子进程命令行按 basename 命中
agent 可执行文件」——worker 侧要的就是同一套判据（同源，别再写第二份）。

## Deliverables

1. worker 存活判据与 M6.5 的 PM 判据**同源**：看 pane 的 `pane_pid` 及其子进程的命令行
   （basename 命中 `TEAM_AGENT_BIN` > `TEAM_AGENT_CMD` 首词 > `TEAM_PI_BIN`），cwd 在本项目内；
   `pane_current_command` 只作旁证不作唯一依据。
2. 找出所有用「当前命令」判 worker 活着/停了的地方（`team ps`、digest 的「停了的 agent」、
   `resume --dry-run`、doctor、面板 agents 块等），统一到同一个函数；实现放 common.sh，
   带注释指向 #1057。
3. smoke 断言：夹具窗口用 `bash -c 'pi …'` 形状（bash 是 pane_pid、pi 是子进程）**必须判活**；
   对照：bash 里没有 agent 子进程 → 判停。**翻转**：把判据改回只看 pane_current_command → 断言红。

## Boundaries

- 不动 M6.5 的 PM 判据本身（只复用）；不改窗口启动命令的形状（那是另一件事）。
- tmux 纪律照旧（#1250）；测试用私有 socket/会话。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 真形状夹具判活/判停 + 翻转实录 + 现场：对当前 teamsmith:dev / dev2 窗口跑 team ps，两边都该判「在跑」
```

## Report

`docs/team/reports/M37-dev3.md`。
