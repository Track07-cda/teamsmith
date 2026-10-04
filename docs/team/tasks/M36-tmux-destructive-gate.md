# M36 · tmux-destructive-gate：包装器记录 + 拒绝打默认 server 的 kill

```
task:   M36
agent:  dev
issue:  
change: -            # "-" if no requirement changes
specs:  -
phase:  -
deps:   M28 M23      # lint（静态）已落地；本任务是运行时那一层（lint 管不到 ad-hoc 命令）
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev3`。

## Context

**事故第 5 次（2026-09-18T18:17:20Z）**：默认 tmux server 整台死亡，PM/pulse/worker 三进程同时被杀，
**其他项目（<peer-d>/<peer-c>/<peer-g>…）共用同一 server，一起陪葬**。取证：无 OOM（`oom_kill 0`）、无重启；
死亡瞬间机器上只有 dev2 的 M35 复验包在跑，但它 pkg/ 里所有 tmux 调用都查过是隔离形态（`env -u TMUX
-u TMUX_PANE TMUX_TMPDIR=<私有>`）——**肇事命令查不出来，因为默认 server 死亡不留任何日志**。

历史同族事故（#1250 记录）：M23 实验、M25 复验、dev3 探针各一次，都是「以为隔离了、实际打默认 server」
（`TMUX` 环境变量优先于 `TMUX_TMPDIR`；空 `-t` 打到当前会话）。M28 的 lint 只能静态管仓库脚本，
**管不到 agent 的 ad-hoc 命令**——这正是缺口。

## 交付物

**1. tmux 调用闸门（shim）**：一个包装脚本，由 teamsmith 在 **agent 会话（PM 与 worker 窗口）** 的
PATH 最前面注入（名字就叫 `tmux`）：

- **记录**：每次调用把 `时间 · 解析出的 socket · TMUX/TMUX_TMPDIR · 参数 · 调用者 pid/ppid/cwd` 追加到
  `state/tmux-calls.log`（默认 server 死亡后要能倒查「谁在什么时候打了什么」）。上限截断（如 2000 行）。
- **拒绝**：当**解析到默认 socket**（即 `TMUX` 指向默认 server，或 `TMUX`/`TMUX_TMPDIR` 都没指向私有目录）
  且子命令属于破坏性集合（`kill-server`/`kill-session`/`kill-window`/`kill-pane`）→ **不执行**，
  打印醒目一行（说明为什么、怎么放行）+ 记日志，`exit 64`。
- **放行**：显式 `TEAM_ALLOW_DESTRUCTIVE_TMUX=1` 或解析到私有 socket（`TMUX_TMPDIR` 非默认）→ 原样 `exec`
  真 tmux（用 `command -v` 找真实路径时注意别递归到自己）。
- **不拦只读命令**：`ls/list-*/display-message/capture-pane/send-keys` 等一律放行（只记录）。

**2. 注入点**：让 PM 与 worker 窗口的启动命令把 shim 目录放在 PATH 最前（对着现有 launch 渲染做，
`skills/teamsmith/scripts/lib/cmd-agents.sh` 的启动命令渲染是入口）。**不改变**别的启动语义。

**3. 测试**：smoke 新段（或并入 10c/26 段）：
- shim 在 PATH 前面时，裸 `tmux kill-server` 被拒（exit 64、日志有行）；
- `env -u TMUX -u TMUX_PANE TMUX_TMPDIR=<私有> tmux kill-server` 放行（私有 server 真的被收掉）；
- `TEAM_ALLOW_DESTRUCTIVE_TMUX=1 tmux kill-server` 放行（在**私有** server 上验证，绝不打默认）；
- 日志格式断言（含 socket 与 pid 字段）。
**翻转**：把 shim 移除 → 第一条断言必红（证明测的是 shim 本身）。

## Boundaries (do not do)

- 不动 `scripts/**` 的 tmux 调用语义、不动 M28 的 lint、不动 smoke 的私有 socket 机制。
- 任何测试**都不许**打默认 server（测试自己在私有 server 上做，`env -u TMUX -u TMUX_PANE` + 私有
  `TMUX_TMPDIR`，见 #1250）。跑门禁前先 `tmux ls` 记一笔，跑完再记一笔——若默认 server 死了，本任务自己
  就是第一现场，报告里如实写。
- 不顺手清理那 15 个泄漏的孤儿 server（另案）。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 三态断言 + 翻转实录 + state/tmux-calls.log 样例行 + 「默认 server 前后都活着」的探活记录
```

## Report

`docs/team/reports/M36-dev3.md`。
