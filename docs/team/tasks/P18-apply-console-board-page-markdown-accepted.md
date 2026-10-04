# P18 · apply: console-board-page（看板页+markdown 详情+有界帧；提案已 ACCEPTED）

```
task:   P18
agent:  dev3
issue:  
change: console-board-page
specs:  panel: The console composes four pages and remembers the position; panel: The board page is a kanban over the board's states; panel: A focused card opens a read-only markdown detail view; panel: A bounded frame fills the pane; panel: Every key affordance is also a mouse target
phase:  apply
deps:   P17          # 提案评审 ACCEPTED：docs/team/reviews/console-board-page-proposal.md
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev3`。

## Context

规划产物已在主线 `openspec/changes/console-board-page/`（四件套），PM 评审 ACCEPTED。
**按 change 目录里的 tasks.md 逐条执行打勾**；下面只是 PM 边界与提醒：

- **顺手修提案 nit**：proposal.md「Spec home」行的 ADDED×3/MODIFIED×2 改成实际口径
  ADDED×4/MODIFIED×1/REMOVED×1（评审记录里写了，以 delta 为准）。
- **有界帧红线是用户亲口要的**（页脚钉最后一行、内容区吃满剩余高度、旧三页同修）；
  `--height 40` 前后对比翻转证据必须进报告。
- **性能红线 <1% 单核**（`tests/panel-cpu.sh`）与帧签名纪律（时钟不进签名）不许破；
  详情数据块只在打开时构建。
- panel.js 是 bundle：改 `panel/src/**` 后按 troubleshooting §16 的流程重建并提交 bundle；
  重建要网络 + Bun ≥1.3，本机满足。
- markdown 渲染自写子集（提案已定，零新依赖）；128KiB 上限与截断标记要有断言。

## Deliverables / Boundaries / Acceptance / Report

按 `openspec/changes/console-board-page/tasks.md`；边界：只读（不引入新写操作）、不改 BOARD.md 格式、
不动 pulse 巡检语义。验收（实跑贴输出）：

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
bash skills/teamsmith/tests/panel-cpu.sh    # CPU 红线
# + tasks.md 每条的验证命令；kanban/详情/钉底的翻转实录
```

报告 `docs/team/reports/P18-dev3.md`。
