# P157 · `delivery-truth` 独立验证（换人：实现是 dev）

```
task:   P157
agent:  verify
issue:
change: delivery-truth
specs:  delivery-guard#Queue impediments are factual, bounded and recoverable
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P157-<agent>.md · docs/team/reports/P157-<agent>/**
deps:   合并提交 `feat(teamsmith): P147 …`（在 main）· 实现自述 `docs/team/reports/P147-dev.md`（**是主张，不是证据**）· PM 的复验 `docs/team/reviews/P147.md` · 容器配方 `docs/team/reports/P147-dev/pkg/` · D31
status: wip
budget: 一次对抗性验证
priority: 高（改了投递主路径：几何判定 / 队列终态 / notify 命名）
```

## 必须自己造的对抗（**不要复用作者夹具的输出**；判据自己写）

1. **几何闭集**：自己造"框外另有一对规则行"的帧（含**混合宽度**：光标框窄、下方另一对更宽）→ 必须判成 **BUSY / NOT-EMPTY** ✓；
   造一份**不属于任何闭集形状**的帧 → 必须走"不可信几何"路径 ✓（`held/geometry-untrusted` ✓，**不许**承诺投递 ✓）。
2. **队列终态**：三次可信空读之后 → **必须**出现可见的 `held`/`queue-stalled` 结论 + 非零退出 + 恢复命令 ✓；
   **反向**：输入框里真有草稿 / 目标正在工作 → **不许**被标成 stalled ✓（两个方向各留原始输出 ✓）。
3. **notify 三处同名**：`notify <agent>` 之后，durable 行所在文件 / outbox 的 `--inbox-written` / wake 全文路径**指向同一个真实存在的文件** ✓（自己造一个收件人，逐个核实 ✓）；
   **写失败**（把 inbox 目录设成只读 ✓）→ 必须**非零退出、不敲门、不写声明** ✓。
4. **夹具自身的可重复性（PM 实测的坑）**：作者的 case 目录**跨次累积** ✗（我连跑出现 1→2→3→4）→
   你的复验必须**每次清空现场** ✓，并在报告里写明这一点 ✓（这也算一条 findings：夹具未自清会误导复验者 ✓）。
5. **真实红侧**：用 `pkg/run-case.sh` + `judge-second.py` 在**修复前版本**上跑出红 ✓（`second_received=0` ✓ —— PM 已复现，你可以照做以确认配方可用 ✓），
   再在**当前 tip** 的清空现场上跑出绿 ✓（期望 `second_received=1 backend=1` ✓）。
6. **门禁**：`openspec validate --all --strict` ✓ + 你在独立检出上跑 `--select 0c,0d,57,12b-pi` ✓ + **FAST** ✓；
   报告写清原始输出、你**没有**测到什么（真窗口/其它适配器 ✓）。
