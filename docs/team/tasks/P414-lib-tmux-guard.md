---
id: P414
title: 搬进 lib 的 PM 窗口助手用的是裸 tmux，静态隔离 lint 判红（公开 CI shard 1）
agent: dev
category: code
phase: apply
change: -
specs: boundary
anchor: openspec/specs/boundary/spec.md
deltas: -
branch: task/P414-lib-tmux-guard
---

# P414 · 新 lib 里的裸 tmux 调用

## 现场（公开 CI，run 41955864643、shard 1 job 127010543339，`✓1893 ✗1`）

```
✗ M28 真树有未隔离的 tmux 变更命令（见 …/m28-lint.log）
   RED  skills/teamsmith/tests/lib/pm-window.sh:90  tmux new-window -t $SESSION -n keep -d -c $REPO
   RED  skills/teamsmith/tests/lib/pm-window.sh:92  tmux new-session -d -s $SESSION -n keep -c $REPO
   RED  skills/teamsmith/tests/lib/pm-window.sh:96  tmux kill-window -t $wid
```

这三行是 P413 从 `section "11b"` 段体搬出来的助手（原先在 `smoke.sh` 里，静态 lint 认它，因为那一侧装了 `tmux()` 壳函数；而按 P173，**通用名 `tmux` 不给同目录别的文件背书**，所以搬进 `lib/` 之后就成了"裸调用"）。

运行时它们其实被 `tmux_iso_install_suite_guards` 装的壳拦住——**判据没有错，是这个文件的写法没有携带隔离证据**。不要靠运行时的壳给它背书。

## 要做的

1. `tests/lib/pm-window.sh` 里的 tmux 调用改成经**专用名**的隔离包装（`tests/lib/tmux-iso.sh` 提供的那套），或就地带上 lint 认的隔离证据（`-L <私有名>` / `env -u TMUX` + 私有 `TMUX_TMPDIR`）。选你认为最小、最不易被误用的一种，并在文件头一行说明"为什么不裸调"。
2. **不要**把 `lib/pm-window.sh` 加进任何白名单、不要改 lint 判据、不要用 `command tmux` 绕过。
3. 红侧：在同一文件里放回一条裸 `tmux kill-window` → `tmux-lint` 必须红并点名该行；改回包装 → 绿。

## 验收（自己跑，贴输出）

- `bash skills/teamsmith/tests/smoke.sh --select 31 </dev/null` → 绿
- `bash skills/teamsmith/tests/smoke.sh --select 11b4 </dev/null` → 绿（搬走后功能不能坏）
- `bash skills/teamsmith/tests/tmux-lint.pl`（或该段用的入口）在改前/改后各一次输出
- `section-select.sh --check` 与 `--self-sufficient`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 报告 `docs/team/reports/P414-dev.md`，提交推分支，通知 PM

## 边界

只改 `skills/teamsmith/tests/**`。不跑全量 smoke、不改产品代码、不合并/归档/发布。
