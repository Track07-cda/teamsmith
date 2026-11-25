---
id: P503
title: 实施 Pulse 看板按更新时间倒序
agent: dev-bob
deps: P502,V199
category: code
phase: opsx-apply
change: pulse-board-recent-first
specs: panel,board-and-status
deltas: -
branch: task/P503-pulse-board-recent-first-apply
---

# P503 · 实施已经独立审阅的看板最近更新排序

读本工作树 AGENTS、本人线程、任务、归属及原生 change `openspec/changes/pulse-board-recent-first/` 的全部工件。P502 `5f36ab4b5d8b5019e63301e5bb080f8e501cc86a` 已 ACCEPTED，独立证据 V199 `15a96588`。D269 决策与已接受工件为本单范围；不重新设计记录来源或给旧任务追填日期。

## 本次写集

- `skills/teamsmith/scripts/lib/common.sh` 的原看板 `add` 和 `write_col` 与用于判断是否记时的最小共用入口、`cmd-watch.sh` 的 board 批量数据。按方案优先原写法，锁内直读和同次替换，调用进程的原缓存成功后清理。先提交数据面；不能顺改任何其他调用者、项目、实时表、`task-labels` 分支或巡检。遇到因原兼容性或身份问题需要扩路径，保持现场并报告具体依据。
- `skills/teamsmith/scripts/panel/src/{layout.ts,App.tsx,types.ts}` 的第四页顺序和选择；仅必要的看板页类型或内部顺序辅助可就近落到该目录现有合适模块，避免复制第二套导航。`skills/teamsmith/scripts/panel/{panel.js,README.md}` 只做原构建和实际生成物对应更新；`package.json`/`bun.lock` 不改。机器打印和工作页保留原布局，不把新字段或文案展示到卡片或其他页。
- `skills/teamsmith/tests/{panel-b3.sh,panel-b3-stub.sh,panel-b3-pty-mouse.py,panel-b3-pty-tmux-mouse.py}` 仅为已批准的 `board` 条件真源和 `fold` 有关现有断言改必要处；`skills/teamsmith/tests/smoke.sh` 仅原 4c 中确需略过专用时间格的比较。不要加总入口、产品测试开关、第二套测试项目或耗时阈值。复用已有私有夹具。
- `openspec/changes/pulse-board-recent-first/tasks.md` 仅记录真正完成的实施项；§3 包含尚未执行的行为判据，不替独立验收勾选。`docs/team/reports/P503-dev-bob.md`；不改已审设计、需求或其它阶段的记录。

## 本阶段只构建和静态检查

用本仓提交的构建脚本及已锁 Bun/依赖重建 `skills/teamsmith/scripts/panel/panel.js`，不得修改全局包或启动真实 Pulse。作者运行改动面的 `bash -n`、实际改动 Python 时做解析检查、面板 `tsc --noEmit`（依赖使用本项目已有的锁定依赖；逐项报告工具版本、命令与退出值）、`git diff --check` / `git diff --cached --check` 和报告所需的账本检查。有新错误原样报告，不跳过或把断点混成通过。通常不跑 `panel-b3.sh board fold`、4c 或反例：定点行为留给非作者在 PM 固定检出一次集中执行；不跑完整测试、发布或实站开关。

分步本地提交：数据写/读、界面与构建、现有场景替换/报告。报告先给功能及兼容结论，产物与未运行面、实际命令与回执、已审 §3 未来验证可直接运行的本地设置；特别说明已有依赖、夹具可用性和独立反例如何只打开一帧。提交带 P503 和 `Agent: dev-bob`；不推送、合并、归档、发布或替换正在运行的 Pulse。

## V200 首轮失败，只修共享列名识别

候选 `78466b22` 的真实看板首帧未通过（独立报告 `1810f112`）。系统 mawk 在 `bt_candidate[name]=(name in bt_candidate ? -1 : i)` 求值时已创建左边元素，把首次见到的字段标为重复。新添加的卡片没有记时，表内本来已有的时间也没读出。只在 `common.sh` 的 `_TEAM_BOARD_TIME_AWK` / `bt_scan` 按先查是否存在、再赋值的方式修这处，同一列第二次出现的判定仍按已审规则；在修改的共享解析段扫同类表达式，若无不改其它地方。不能换 `awk`、添加例外/测试开关、改变等待、制造日期或重构。原 P503 分支、会话、模型继续，保留现有失败；不改其余实现、测试、构建或已审方案。短语法和 Git 检查、更新本人报告并本地提交即可，不运行既定行为。非作者将只补真实看板与未到达项；原 fold 不重跑，含首次写时间格的旧表路径会在候选私有样本短核。