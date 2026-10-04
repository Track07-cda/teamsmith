# P10 · Apply: `pulse-tui-panel`（Ink 面板重写）

```
task:   P10
agent:  dev
phase:  apply
change: pulse-tui-panel
deps:   P9 提案 ACCEPTED（docs/team/reviews/pulse-tui-panel-proposal.md），已并入主线（v1.37.0 之后）
```

## 范围

按 `openspec/changes/pulse-tui-panel/tasks.md` 顺序执行。关键边界（提案审查时钉死的）：

- **数据层不动**：`monitor.mjs --json` 的契约逐字节保留；新前端只消费它。
- **单文件 bundle**：构建产物是一个提交进仓库的单文件（现在约 826KB），无安装步骤、离线可跑；
  重建必须可复现（锁定依赖）。
- **`--print`/非 TTY 输出保持机读**（现有脚本在吃它）；TSX/Ink 只管 TTY 渲染。
- 净化（OSC/控制序列剥离）沿用现有实现并入新前端。
- `TEAM_REQUIRE_JS=0` 逃生门在两处生效（依赖检查与运行时降级）。
- 改名已落地（v1.37.0）：新代码一律用 pulse 命名，不引入 watchdog 新引用。

## 边界

`skills/teamsmith/scripts/monitor*`、`panel/**`（新目录按提案结构）、`tests/smoke.sh`（自己的段）、
`references/monitor*` 文档、变更目录、你的报告。不动派发/巡检/outbox 逻辑、不动账本、不归档。

## 验收

```sh
openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 另：在干净容器里 bash monitor 入口（提案要求的"无环境也能跑"证据）
```

报告 `docs/team/reports/P10-dev.md`：每条的完成证据 + bundle 的可复现构建（两次构建哈希一致）+
无 Node 环境的降级行为实测。
