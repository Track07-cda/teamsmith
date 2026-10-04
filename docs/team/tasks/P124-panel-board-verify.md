# P124 · `panel-board-cards` 独立验证（换人：作者是 dev3、提案是 dev2）

```
task:   P124
agent:  verify
issue:
change: panel-board-cards        # 已在 main（propose=P121 dev2 · apply=P123 dev3）——你不是其中任何一位
specs:  panel#A lane folds from its header, and empty lanes fold by default · panel#The board page is a kanban over the board's states · panel#Every key affordance is also a mouse target
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P124-verify.md · docs/team/reports/P124-verify/**（只写报告与证据）
deps:   `openspec/changes/panel-board-cards/` 已归档?（未 ✓：等你的结论）· 面板 CLI：`panel.js --snapshot --page 4 --width N --height N [--state-dir D]` · 测试库 `tests/lib/pty-*`、`tests/panel-b3.sh`（**可读，不许只跑**）
status: todo
budget: 一个验证包
priority: 中高（用户点名的界面改动；归档前最后一道门）
```

> 本地模式：不 push。**验证对象 = main 上已合并的实现**。**CI 不再作为判据**（D54）。

## 必须自己动手（**不许只跑作者的夹具**）

1. **降级序**（核心承诺）：**你自己**在 **190 / 120 / 99 / 59** 四档出帧 ✓，逐档证明 **标题是最后一个被截的** ✓
   （agent/阶段**永远**不会挤掉标题 ✓）；窄档若走单列合并，也要证明标题仍在 ✓。要贴**每档的原始帧** ✓。
2. **折叠与键位**：用**真 pty** 按 `c` ✓（不是调 `panel.conf` ✗ —— 我 PM 只验了"读 conf"这一半 ✓，**写 conf 那一半归你** ✓）：
   折叠后**卡片行 0 条** ✓、头部一行带计数 ✓；**重启面板进程后仍折叠** ✓；**显式展开会粘住** ✓；页脚里有 `c` 的提示 ✓、中英双语 ✓。
3. **空车道默认折叠**：默认下空车道 = 一行 ✓；`boardEmptyFold=0` 时**不**折叠 ✓（两个方向 ✓）。
4. **机器出口不受折叠影响** ✓：`--print` / `--json` 在两种折叠配置下**除时间戳外逐字节相同** ✓
   （**注意**：别直接 `cmp` ✗ —— 时间戳会变 ✓；要按字段/去掉时间戳比 ✓—— PM 第一次就栽在这 ✓）。
5. **有界帧与成本**：在**长历史**下出帧 ✓，帧仍在窗内（底部页脚是最后一行 ✓）、折叠车道**不建卡片行** ✓；给出一条可复算的量 ✓。
6. **对抗**：自己**造两个**红侧 ✓（例：把卡片行改回含 agent → 降级序断言必须红 ✓；把折叠的"不渲染"去掉 → 有界/卡片计数断言必须红 ✓）；
   再从它的 `panel-flip-p123.sh` 六条里**抽两条**复跑 ✓。
7. **零回归**：`openspec validate --all --strict` + 面板相关段落（`panel-*`）+ **FAST 全绿**（+ 一次全量，若你判断必要 ✓）。
8. 报告写清"哪些是你自己的证据、哪些是引用" ✓，附**红/绿原始输出** ✓；**不改实现**（要改 → `BLOCKED:` 交回 PM ✓）。
