---
id: V199
title: 独立审阅 Pulse 看板更新时间倒序方案
agent: dev3
deps: P501
category: verify
phase: opsx-verify
change: pulse-board-recent-first
specs: panel,board-and-status
deltas: -
branch: task/V199-pulse-board-recent-first-proposal-review
---

# V199 · 核近期排序的范围和可验收性

作者 dev2；固定 `60a73655424a5130b9dbba41cfc67ae3396e2b8a`，独立检出 `/var/tmp/p502-review-60a73655.g8yCh6`。读 AGENTS、本人线程、归属、D269、P501 已接受报告、P502 和固定工件。产品方向已定；审阅给 ACCEPTED 或最少修订，只写本人 `docs/team/reports/V199-dev3.md`，不改候选。

- 逐行比两个能力中被修改的需求/场景，确认只改 D269 必需的范围。首先检查 `common.sh` 中已有列定位、任务表边界、`team_board_add`/`team_board_write_col` 以及同 ID 和表外记录实际行为；要能为确实改动的任务保存时间，旧板、自定义列、旧行缺末格和实际日期仍按计划可读可改。不能用手工编辑、Git、整份文件或故意停顿制造历史时间。保持原操作的成功、拒绝和办结/重复审计。其中旧 `board ls/row` 原样展示，可见额外专用列，是已记录影响。
- 核实是否用最少代码即可让原业务字段与可选时间一起替换：无需第二份数据、逐行外部进程或额外安全规则。重点核 `team_with_lock` 的子进程和锁顺序/路径、锁内重读、成功后上层缓存失效。检查锁失败和原命令保持原判据，不允许用本次扩大或减少旧行寻址。同一锁根和手改的边界只需如实给出，不要求另造系统。若现有源码显示方案触及比排序更大的行为，给更窄做法。
- 核对两种屏幕布局、历史首窗、滚动和同一任务焦点从原行到实际点击/方向键/Enter 的单一顺序；工作页和命令行维持各自原顺序，核 `--print --page 4`/`--json` 与实景看板实际走哪条投影，发现矛盾据源码说明。确认未落地的 `task-labels` 重叠条款有将来明确对齐步骤，本轮不动标签/巡检/快速按键阻塞。
- 用 `tests/panel-b3.sh`、本地替身和 M48 实际入口核 §3 是否既可跑又足够短。优先替换原场景的适用检查，保留其他覆盖；对真正读写局部真源、受控时钟、同一项排序反例给证据。不为一个比较函数重新跑全套或另加通用框架；对计划触动的 `fold` 和 M48 要分别诚实写清如何短核、不把 `board` 的成功冒充它们跑过。指出可以删掉的重复场景，不为增加检查加篇幅。

只在固定检出 `PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0 openspec validate pulse-board-recent-first --type change --strict --no-interactive` 一次；来源/引用检查可读作者回执。报告实际输出、退出码、具体文件/函数证据与结论，Git 差异检查并小步本地提交（V199，`Agent: dev3`）。不写产品、不运行板写命令、Pulse、行为、构建或全量，不改别的任务；不推、不合并。

## 定点复看 P502 修订

原 V199 会话与分支继续。冻结 `5f36ab4b5d8b5019e63301e5bb080f8e501cc86a`，干净检出 `/var/tmp/p502-review-5f36ab4b.kTZNNb`。只看 `60a73655..5f36ab4b` 的方案差异，核原 R1–R3：时间识别不改旧写入落点和返回语义；明确窄、宽的滚动边界及原行选择；现有 `board fold` 与 `4c` 是确实能执行的少量验收，反例只检一帧。复用前轮已有源码核对和作者引用回执，不重开其它设计、不评价尚未执行的行为；对新固定提交只补一次指定的单变更 strict，追加明确结论和证据。