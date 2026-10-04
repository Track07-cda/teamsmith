# M23 · smoke 并发互相卡死：夹具改私有 tmux socket 或全量门禁互斥

```
task:   M23
agent:  dev2
issue:  
change: -            # OpenSpec change id this brief implements (`openspec list`, e.g. add-agent-timeout); "-" if no requirement changes
specs:  -            # requirements/scenarios it must satisfy, e.g. `dispatch: a brief is self-contained`; "-" if none
phase:  -            # OpenSpec pipeline phase this brief runs: explore|propose|apply|verify|archive ("-" for work outside the pipeline); one phase = one brief = one owner
deps:   M20          # 同文件 smoke.sh；且 M20 先落地，本任务在其后评估残余
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，把任务分支留在 `.worktrees/dev2` 工作树即可，PM 复验后本地合并。

## Context

2026-09-17 实锤：`team review` 的两轮门禁（M21、V16）先后在 **6i 段同一断言后卡死到 1800s 超时**（TERM 被忽略、KILL 才杀掉）；而**同一棵树**在无人并发时直接跑门禁 110s 就飞过 6i。三次现场：

- 09:05 M21 复验超时（dev3 同时在跑自己的 M21 验收门禁）;
- 10:33 V16 复验超时（dev2 当时在做 M20 实验）;
- 10:47 同一棵树绕过 review 直跑，畅通（最终 ✓1775 ✗1，红的是旧树的 11e 措辞断言，与本题无关）。

对照组早已存在：V15/V16 的对抗探针包用**私有 tmux socket**(`-L v16pkg-$$`,PATH shim 强制）从来不互相干扰（见 `docs/team/reports/V16-verify/pkg/lib.sh`)；而 smoke.sh 的夹具走**默认 server**。CPU/内存实测都不是瓶颈（smoke 进程 0.6% CPU)。

## Deliverables

1. 诊断坐实：用最小复现证明干扰通道（两个并发 smoke 是否在默认 tmux server 上互相卡住；是哪个夹具操作互相等）。报告里给实验设计 + 数据，不接受纯推理。
2. 修复（二选一或组合，报告给取舍）:
   a. smoke 的 tmux 夹具整体迁到私有 socket（对齐探针包的 PATH shim 方案）——治本；
   b. 全量门禁加互斥锁（同机第二套排队）——治标但便宜，且对「review 与 agent 验收并发」也有效。
3. smoke 里加一条防护/注释，让「并发跑两套」的行为可预期（要么互不干扰，要么明确排队）。
4. 翻转证据：修复前两个并发 smoke 必现卡死（或显著变慢）的实录；修复后同形并发不再互相影响。

## Boundaries (do not do)

- 不动 panel/ 与 scripts/lib/ 的产品行为；若诊断证明病根在 lib（如某个 tmux 调用没有 socket 隔离参数），在报告里写 BLOCKED 并交回 PM。
- 不降低任何断言的判定力。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 并发实验：两套全量 smoke 同跑，双双在预期时间内完成（修复前 vs 修复后数据）
```

## Report

Write it to `docs/team/reports/M23-dev2.md` (format: `docs/team/PROTOCOL.md` or the skill's
`templates/report.md.tmpl`)。
