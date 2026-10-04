# P9 · Propose: `pulse-tui-panel`（面板重写，D19 第一步的提案阶段）

```
task:   P9
agent:  dev2
phase:  propose
change: pulse-tui-panel
deps:   E4（已接受：DECISIONS D24）
```

> Phase 2。你手里有 E4 的实测上下文，D24 已接受。只写规划产物——不写代码、不动 `openspec/specs/**`。

## 提案要覆盖的（E4/D24 已定的方向，不许重开）

1. Ink + TSX 新前端层（`scripts/panel/` 或你论证出的目录），数据仍走 `monitor.mjs --json`（契约不动）；
   `bun build` 单文件提交进仓库（构建命令写进规格场景：干净容器里 `node panel.js --once` 必须跑通）。
2. 布局按 E4 §5 的线框：现有字段的保留/折叠/升级逐个落进场景；为第二步的可视化段留位置但不实现。
3. 降级：`--print`/非 TTY 不走 TUI 渲染器（机器可读契约）；`doctor` 缺 Node/Bun 即失败 + `TEAM_REQUIRE_JS=0`
   逃生键；`TEAM_MONITOR_*` 键的保留与默认值变更逐键写进 delta。
4. 显示安全：控制字符净化链路（M3.3 的 sanitize + Ink 自带净化）要有场景：敌意文本进面板 → 不执行、不截断内容。
5. 规格形态：delta 大概率落在 `watchdog`（面板是它的窗口）与新 capability（`pulse-panel`？名字你论证）之间——
   注意改名 change `rename-watchdog-to-pulse` 还没实施，本 change 的文本要用**旧名**写（改名是另一个 change 的事，
   顺序上它在 P6 之后），并在 design.md 里写明与改名 change 的衔接。
6. 与 D20 的接口：outbox 排队数作为面板字段（只读 outbox 目录）。

## 给 PM 审查的证据

- `openspec change show`、`openspec validate --all --strict`、`spec-lint.sh` 全绿（change 在场）；
  scratch 副本上 `openspec archive -y pulse-tui-panel` 恰好做出承诺的操作。
- `docs/team/reports/P9-dev2.md`：需求 → 场景 → 证伪器映射；哪些场景必须真 tmux 舞台（标出来，它们进慢速套件）；
  你刻意不做的（理由）。

## 边界

只写 `openspec/changes/pulse-tui-panel/**` + 你的报告。不动代码、不动 main 的规格、不动账本；不派单、不归档。

## 验收

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/spec-lint.sh
git status --porcelain   # 只有 change 目录 + 报告
```
