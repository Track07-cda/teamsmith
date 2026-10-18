# P313 · 夹具的心跳循环会**永不退出**（吞掉 12 GB 内存盘）；清扫器看不见「已删但仍被持有」

task: P313
agent: dev3
phase: apply
category: code
change: -
anchor: none (infra) — 夹具的生命周期缺陷；不改产品行为
deltas: -
branch: task/P313-heartbeat-orphans
deps: 无（PM 现场数据见下）

## 现场（PM 2026-10-18 实测）

`/tmp` 明明被清扫过仍显示 **100% 满（64 M）**；`du` 只算出 9 G，而 `df` 说用了 15 G。逐进程查「**已删除但仍被持有**」的文件：合计 **11.98 GB**，被 **78 个**同一形状的进程持有——

```
bash -c 'log="$1"; trap "" TERM; while :; do date +%s >> "$log"; sleep 0.2; done' _ <log>
```

它们**运行了 2 天以上**、写入的目标**早已被删除**（夹具的临时根被清理了），而循环**忽略 TERM、且从不检查父进程是否还在** → 任何一次被打断的夹具运行都会**永久泄漏**一个这样的进程（每个约 150–300 MB）。

**我按 argv 精确匹配 + 「目标已删除」判据结束了 78 个，`/tmp` 从 64 M 回到 5.6 G。**另一个目标未删的**没有动**（它可能仍在正常工作）。

## 要做什么

1. **夹具生命周期**（根因）：这个心跳循环（以及同族：任何 `while :` 的看门/轮询进程）必须：
   - **不再 `trap "" TERM`**（或用 `trap` 记录收到 TERM 后**退出**）；
   - **每轮检查父进程**：`while kill -0 "$PPID" 2>/dev/null; do …`——父进程没了就退出；
   - **有硬上限**（最大运行时间/最大写入字节），到点退出并留一行说明。
   **找出所有同族**（全树 grep `while :` / `trap "" TERM`），逐个改，并在报告里列出清单。
2. **清扫器**（可观测）：`tmp-hygiene.sh --status` 加一项 **「已删除但仍被持有」**：按 `/proc/*/fd` 找出指向临时根的 `(deleted)` 文件，报**合计字节 + 持有它们的进程数**（不点名别的项目的 pid，按既有口径只报总量）；`--sweep` 时对**能归属本项目**的这类进程给出「建议结束」的计划（仍要求显式 pid 才动手）。
3. **红侧**：① 把 `kill -0 "$PPID"` 去掉 → 必须能复现一个活过父进程的心跳（自造小现场，别真留两天）；② 把 `trap "" TERM` 放回去 → 必须红；③ 清扫器的「已删除但被持有」读数在有人持有已删文件时必须 **>0**，没有任何持有时必须 **0**（两个方向都要）。
4. **回归**：`tmp-hygiene.sh --self-test/all/flip` 全绿；相关选段贴结果。
5. 计时类按 D192；容器里先 `mkdir -p` 再设 `TMPDIR`（D189）；现在是 `/var/tmp` 默认（P309），别忘了在两个根上都验一遍。

## 验收

```bash
bash skills/teamsmith/tests/tmp-hygiene.sh --self-test
bash skills/teamsmith/tests/tmp-hygiene.sh --status
bash skills/teamsmith/tests/smoke.sh --select <闭包>
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
