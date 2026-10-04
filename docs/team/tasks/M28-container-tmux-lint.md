# M28 · tmux 接触型测试进 podman 容器 + 裸 tmux 调用 lint

```
task:   M28
agent:  dev2
issue:  
change: -            # "-" if no requirement changes
specs:  -
phase:  -
deps:   M23 M24 M25 M27 M30   # 全部已合并
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev2`。

## Context

五次 tmux server 死亡的结案根因：`TMUX` 环境变量优先级高于 `TMUX_TMPDIR`（记忆 #1250）。**用户拍板：
tmux 接触型测试在 podman 容器里跑**（已实测链路可用：`distrobox-host-exec podman run --rm alpine`，
容器内建/杀 tmux 全程宿主侧不动）。拓扑事实（记忆 #1251）：我们在 apx-vso-native 容器里，podman 在
真宿主（Vanilla OS），经 `distrobox-host-exec` 到达；distrobox 共享宿主 D-Bus 导致 tmux pane 派生向宿主
systemd 要 scope（「Couldn't move process」噪声）——容器内起 tmux 前清 `DBUS_SESSION_BUS_ADDRESS`。

## Deliverables

1. `skills/teamsmith/tests/container-tmux.sh`（或等价物）：一条命令把「镜像准备（alpine+tmux+bash+git，
   本地无则构建/拉取并缓存镜像名）+ 挂载仓库只读副本 + 容器内跑给定测试命令」打包；从容器内调用时
   经 `distrobox-host-exec podman`，并探测在真宿主直跑的情形（`command -v podman` 直接可用则直跑）。
   容器内环境：`env -u TMUX -u TMUX_PANE -u DBUS_SESSION_BUS_ADDRESS`。
2. 把至少一类现成的 tmux 接触型测试搬进容器跑通（建议：`tests/pm-box-real.sh` 真 pi 体检——它是最
   危险的那类；pi 二进制可 bind-mount 进去或容器内用假 pi，取舍写报告）。
3. **lint 断言**（进 smoke.sh，FAST 也跑）：扫描 `tests/`、`docs/team/reports/*/pkg/` 里所有 tmux 调用，
   凡 `kill-server|kill-session|kill-window|new-session|new-window` 这类变更命令**不**带
   `env -u TMUX`/已 unset 的（smoke.sh 自身 42 行式 unset 白名单）→ 红。翻转证据：塞一条裸调用 → 红 → 删。
4. 文档：troubleshooting.md 加一节「tmux 实验为什么必须在容器里」（五次事故时间线一句话版 +
   TMUX>TMUX_TMPDIR 机制 + 容器命令）；PM 手工实验的纪律写进 pm 提示词模板一句。

## Boundaries (do not do)

- 不把 smoke 全量搬容器（本任务只开先河：一类真进程测试 + lint + harness）；容器不可用时降级跳过并
  打印 skip 理由（门禁在无 podman 的机器上不许红）。
- 不动 M30 刚换道的投递逻辑；不动 pulse。
- 镜像层不许写任何 token/密钥；挂载仓库用只读。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
bash skills/teamsmith/tests/container-tmux.sh --selftest   # 容器内 tmux 生死 + 宿主 server 前后指纹不变
# lint 翻转实录进报告
```

## Report

`docs/team/reports/M28-dev2.md`（格式见 `templates/report.md.tmpl`）。
