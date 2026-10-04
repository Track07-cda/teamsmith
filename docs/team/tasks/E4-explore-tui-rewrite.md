# E4 · Explore: the pulse panel TUI rewrite (D19 step 1)

```
task:   E4
agent:  dev2
phase:  explore
deps:   D19 (Node/Bun 升为必需 + 现有面板用 TUI 框架整体重写); D22 (名字定为 pulse，改名先行)
```

> D19 的第一步是"把**现有内容**的前端整体重新设计与实现"（顶部团队状态 + 每 agent 活动块 + 容量行 + 巡检态），
> 新增可视化段落放到第二步。本任务只探索、不写代码：选型要拿实测说话。

## 要回答的问题（全部带证据）

1. **框架选型**：候选 Ink+TSX（Bun 原生）vs blessed-contrib（组件现成）vs 其它你调研到的。比较维度：
   真实渲染一个"双栏 + 表格 + 迷你图"的原型各一个（截图/转存文本贴进报告）；宽字符（CJK/emoji）对齐实测；
   终端高度不足时的行为；键盘交互（可滚动？）；包体积与启动耗时（`time` 实测）。
2. **分发**：`bun build` 打成**单文件提交进仓库**（离线可用、装即用——我倾向这个）vs 使用方自装依赖。
   各做一个原型，报单文件体积与启动耗时；单文件方案要验证它在干净机器上直接 `bun run`/`node` 能跑。
3. **现有内容的重新设计**：盘点 `monitor.mjs` 现在展示的每一个字段（用 `team monitor --once` 的真实输出做清单），
   给出新的布局线框（ASCII 线框即可）；哪些字段保留、哪些折叠、哪些升为一级——每个决定给一句理由。
   为第二步（board/reports/OpenSpec/sparkline 中段）预留位置但不实现。
4. **与延后投递（D20）的接口**："N 条消息因输入框占用而排队"将成为面板的一等字段（E3 §4.4）——数据从
   outbox 目录读；探索阶段只需确认数据可得住（列出要读的字段）。
5. **降级语义**：Node/Bun 变必需后（D19 另一半），`doctor` 的行为变更、`TEAM_MONITOR_*` 键的去留、以及
   "非 TTY/无 tmux 时的 --print 输出"怎么保持机器可读（管道用法不能断）。

## 边界

- 只写 `docs/team/reports/E4-dev2.md` + 可跑的原型脚本（放报告目录 `E4-dev2/proto/` 下）。不改 `monitor.mjs`、
  不动 `openspec/**`、不派单。
- 原型用一次性 tmux 会话演示（用完即杀）；不得向 `teamsmith:*` 任何窗格发按键。

## 验收

```sh
git status --porcelain   # 只有报告与原型目录
```
