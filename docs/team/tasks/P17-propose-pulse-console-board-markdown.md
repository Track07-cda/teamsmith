# P17 · propose: pulse-console 看板页 + 条目详情（kanban → 渲染 markdown 详情）

```
task:   P17
agent:  dev
issue:  
change: console-board-page  # 本任务只产规划产物；apply 等 PM 提案评审 ACCEPTED
specs:  panel               # 提案自行判定挂 panel 还是新 capability
phase:  propose
deps:   -
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev`。

## Context

用户两条原话，合成一个需求：

1. 「pulse 中间需要有能够查看 board 详情和中间条目详情内容的功能……直接在 pulse 中打开查看相关的文件，
   markdown 能够正常渲染。」
2. 「你需要一个独立的 board 页面，最好能是一个 kanban」

**需求形态：控制台新增独立看板页（第四页）**——kanban 布局（按 BOARD.md 状态分列：todo / wip /
blocked / done…，每列卡片=条目，卡上 ID+标题+agent+阶段），卡片可聚焦（键盘 + 鼠标），Enter/点击打开
**详情视图**（关联文件：任务书/交付报告/复验记录，markdown 正常渲染），Esc 返回。

控制台现状参照 `openspec/specs/panel/` 与 `skills/teamsmith/scripts/panel/`：三页 + 设置浮层，鼠标/键盘/
i18n/降级布局，B3 视觉语言（卡片/芯片/列计划），**性能红线 <1% 单核**（`tests/panel-cpu.sh`）、帧签名
排除时钟（frameSignature）、data.ts 的 TTL 异步数据块模式。

## 提案必须回答

1. **kanban 布局**：列的集合与排序（BOARD.md 状态枚举）；列宽分配与降级（120x29 正常 / 60x8 下 kanban
   怎么退化——单列纵向？）；卡片内容字段与截断；滚动（列内条目多过可视高度）；空列显不显示。
2. **导航与焦点**：页间切换现有键位怎么扩（1/2/3 → 加 4？）；列间移动（←→/Tab）与列内移动（↑↓）；
   鼠标点击卡片=聚焦、双击或 Enter=打开；焦点态的视觉（边框/反色——B3 视觉语言内）。
3. **详情视图**：浮层还是整页替换；关联文件怎么发现（`<ID>-*.md` 任务书、`reports/<ID>-*.md`、
   `reviews/<ID>.md`、ROADMAP 里程碑段）；markdown 渲染选型（marked+marked-terminal / 窄自写 /
   Ink 现成件）与缓存（data.ts TTL 模式）；代码块/表格/标题在终端的保真度目标；Esc/q 返回；只读。
4. **性能契约不破**：详情文件读取与渲染走异步数据块，不进每拍热路径；打开详情的耗时目标；kanban 页
   的帧签名设计（卡片集合变化才重绘）。
5. **规格挂点**：panel capability 扩还是新开；逐条 requirement + 可证伪 scenario（含降级形态与性能）。

## Deliverables

`openspec/changes/console-board-page/` 四件套（proposal/design/tasks/specs delta）。

## Boundaries

- 零代码；不改现有三页行为语义（看板页是增量）；不引入新写操作；不改 BOARD.md 存储格式。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
```

## Report

`docs/team/reports/P17-dev.md`。
