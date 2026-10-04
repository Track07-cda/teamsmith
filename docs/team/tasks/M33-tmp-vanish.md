# M33 · 调查：smoke 运行中 $TMP 写入瞬时 ENOENT（bg6 的 50 红，串行复跑不复现）

```
task:   M33
agent:  dev2
issue:  
change: -            # "-" if no requirement changes
specs:  -
phase:  -
deps:   M23 M31 M32  # 全部已合并
status: todo
budget: 一个工作块；查不到根因也要留下结论与防线
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev2`。

## Context（全部实证，PM 已做过的分析可直接复用）

2026-09-18 ~14:0x，`team review P18`（分支 tip 6b54bdb，树=main@cut+P18 文档）在 26-j 段 50 条红，
签名：`/tmp/teamsmith-smoke.EloKhO/p10-noqueue.json: No such file or directory`（对 $TMP 的**重定向**报
ENOENT，目录级）、find/wc 读出 0/空（队列夹具的文件不见了）。**前后段落（26-i 之前、26-k..26-m 之后）
都绿**——像 $TMP 被删了一阵子又被 `mkdir -p` 重建。

- 同 tip 串行复跑（锁空闲 + stdin=/dev/null）**PASS 零红**；
- 该树同代码此前三次 PASS（bg1/bg4/bg5）；
- bg6 当时机器上另有活动：dev2 你正在跑 M32 的验收（工作树全量/FAST smoke，均带 M23 锁）；
- 日志全文已存证：`docs/team/tasks/M33-evidence-bg6.log`。

**任务**：查出 $TMP（或其子目录）在运行中被删/移走的机制，然后让这类事故**不可能再无声发生**。

## 调查清单（建议顺序）

1. 全文过一遍 bg6 日志，定位**第一条**失败断言与它的上一条成功断言之间的窗口；该窗口内的每个
   重定向/文件操作列出来。
2. 查 26-j 夹具（`P10_OBOX`、`P10_HOME`、`p10m/p10c` helper）里所有 `rm -rf`/`mv`/symlink 操作，
   逐个问「这个变量有没有可能解析成 $TMP 或其父目录」。
3. 查 smoke 里所有会动 `$TMP` 之外的清理（cleanup trap、26-m 真 pane 段、子 fixture 的 trap——
   **EXIT trap 在子 shell 也会触发**，有没有没加 `[ "${BASHPID:-$$}" = "$$" ]` 守卫的）。
4. 复现尝试：故意制造「并发 smoke + 高速 26-j 循环」的跑法看能否再现；不能复现也要写下尝试记录。
5. **无论根因查到与否，交付防线**：smoke 每次写 $TMP 失败时要**当场点名**（而不是静默级联 50 条），
   即 assert_has/重定向失败路径加上「$TMP 消失？」的诊断；另外把 `$TMP` 的存活性检查做成一个
   `tmp_alive()` 哨兵段（26-j 开头写一次、结尾断言仍在——红时直接给出「临时目录中途消失」而不是
   一堆下游假红）。

## Boundaries (do not do)

- 只动 smoke.sh 与 tests/；不动 cmd-*.sh 产品代码（除非根因确凿在那里，先报告再动）。
- tmux 纪律照旧（#1250/#1255）：一切 tmux 调用私有 socket + env -u。
- 不删证据文件 `docs/team/tasks/M33-evidence-bg6.log`（验收后随本任务一并入库）。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 防线断言的翻转证据：把「tmp 存活性哨兵」打坏（中途删 $TMP）→ 一条点名红而不是 50 条级联红 → 还原
```

## Report

`docs/team/reports/M33-dev2.md`（格式见 `templates/report.md.tmpl`）。
