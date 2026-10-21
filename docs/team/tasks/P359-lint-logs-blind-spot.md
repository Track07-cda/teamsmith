# P359 · `tmux-lint` 把任何含 `/logs/` 的路径整段跳过（我今晚踩到的坑，也是真盲区）

task: P359
agent: dev2
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 一条扫描排除规则
deltas: -
branch: task/P359-lint-logs-blind-spot

## 事实（PM 今晚两次踩到，已复现）

`skills/teamsmith/tests/tmux-lint.pl:111`：

```perl
return if $p =~ m{/(__pycache__|node_modules|logs|snapshots)/};
```

它按**路径里有没有 `logs` 这一段**排除。后果有两个：

1. **我今晚把临时根挂到容器里的 `/logs`**（为了保住现场），于是 37 个自检夹具的路径全都含 `/logs/`，全部被跳过 → `--selftest` 报 19/37 不符、真树判「干净（扫描 0 个脚本）」。**一次四小时的整套门禁因此作废**（我停掉了它）。
2. 更一般的：任何仓库文件只要落在**任意名为 `logs` 的目录**下（例如 `docs/team/reports/<X>/logs/probe.sh`、或某个证据包的 `logs/` 子目录），就**永远不会被这条纪律扫描**，而且不打印任何跳过理由——正是「跳过被当成通过」。

## 要做的（最小）

只改**排除的范围**，不改判定：

- 把「任意 `/logs/`」收窄成它真正想排除的东西。今天的用法只有两类：证据包里的日志目录（`docs/team/reports/*/logs/`）与夹具偶发的 `logs/`；请你**先量一遍**（`rg` 一遍仓库里真实的 `logs/` 目录），再决定是
  - 按**文件名后缀**排除（`.log`/`.out` 本来就不在 `@EXTS` 里，可能根本不需要这条），或
  - 保留目录排除但限定在证据包内（`docs/team/reports/` 之下），或
  - 保留通用排除但**打印一行**「跳过 N 个位于 logs/ 下的脚本」，让读者看得见。
  **选哪个都行，但必须能回答**：`tests/logs/probe.sh` 里写一条裸 `tmux kill-server`，今天会不会红？改后必须红。
- 同样的 `snapshots` 段请一并判（是不是同一类过宽）。

## 必须交的

1. **红侧**：在私有副本里造 `tests/logs/probe.sh`（内容 `tmux kill-server`）→ 修后必须红并点名；修前必须「干净」——两棵树都贴读数。
2. `--selftest` 在**三种 TMPDIR** 下都是 37/37：`/var/tmp/x`、`$HOME/.cache/x`、以及一个**含 `/logs/` 的路径**（例如私有副本里的 `.../logs/x`）。
3. 真树读数不变：默认扫描范围下改前改后的 `--list` 与判定结果**逐字节相同**（把两次输出 diff 出来）。
4. 轻量收口：`bash -n`/`perl -c`、账本禁令、`git diff --check`。

## 边界

写集：`skills/teamsmith/tests/tmux-lint.pl`、`docs/team/reports/P359-dev2.md`。不改信号 lint、不改段、不新增夹具、不放宽任何判定。禁止将「含 /logs/ 就跳过」保留为静默行为。
