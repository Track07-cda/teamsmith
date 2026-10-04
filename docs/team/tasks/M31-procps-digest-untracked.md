# M31 · 容器镜像补 procps + digest 警告未入账的复验/报告记录

```
task:   M31
agent:  dev2
issue:  
change: -            # "-" if no requirement changes
specs:  -
phase:  -
deps:   M28 V18      # F-V18-2 + F-V18-4 的系统性收尾
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev2`。

## Context

V18 独立验证的两条 finding 落给你：

1. **F-V18-2**：`tests/container-tmux.sh` 的镜像只有 BusyBox `ps`（不支持 `-o args= -p`），
   `tests/panel-b3.sh` 的 detail/collapse 两段在容器里必然假红 6 条；宿主上同夹具 ✓108 ✗0。
   修法：镜像加 procps（alpine: `apk add procps-ng` 或 `procps`），并加一条「容器内 ps 支持所需参数」
   的自检断言；容器内跑 panel-b3.sh 的两段从 skip/红转绿作证据。
2. **F-V18-4（系统性）**：`team review` 把复验记录写进主仓工作区但**没有任何机制保证它被提交**——
   PM 的 squash 合并只带分支内容，M22/M28/M30/P18 的 reviews 全部 untracked 悬置（我已手工补账）。
   修法（工具侧）：digest 的「待收尾」段加一条检查——`docs/team/reviews/` 与 `docs/team/reports/` 下有
   untracked 文件 → 显示一行警告（列出文件名），让 PM 在合并流里立刻看见。smoke 断言：造一个 untracked
   记录 → digest 显示警告；提交后消失（翻转）。

## Boundaries

- 不动 panel 代码（F-V18-1/报告尾巴在 dev3 处）；不动投递/巡检。
- digest 检查只读 git status，不写任何东西；性能：digest 热路径上最多一次 `git status --porcelain`
  （注意板面每拍都跑 digest 的数据块，别加重它——该检查挂 reviews/reports 的 TTL 块或独立低频块，
  实现前看一眼 data.ts 的缓存模式）。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
bash skills/teamsmith/tests/container-tmux.sh --selftest
# 容器内 panel-b3 detail/collapse 段转绿 + digest 警告翻转实录
```

## Report

`docs/team/reports/M31-dev2.md`（格式见 `templates/report.md.tmpl`）。
