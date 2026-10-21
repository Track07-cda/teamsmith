# V88 · P352 的独立验收：那 8 条改成判行为之后还有判别力吗

task: V88
agent: dev-bob
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 夹具断言
deltas: -
branch: task/V88-panel-b3-assertions-verify

## 受检

候选 `43208b54`（实现 `5fec9ff8` 之前的那次代码提交，报告 `docs/team/reports/P352-dev.md`）。改动只有 `tests/panel-b3.sh`：7 条「看板页在场」的判据从「某车道标签在帧上」改成产品自己的两条行为（`▾ 待办` 车道头 + `--snapshot --targets` 给出的六条车道按图例顺序），1 条点击列号改成从帧里读。

作者读数：`panel-b3.sh --all` **✓231 ✗0**（改前 ✓223 ✗8），WALL 211.4 s。

## 要回答的三件

1. **新判据不是换个姿势再写死一次**：读那两条新判据，判断它们是否**随产品布局变化而继续成立**（而不是又绑定到某一档/某个字形）。特别注意：`board_anchor="▾ 待办"` 这个锚也是一个具体字符——说明它在什么情况下会失效、以及失效时它是红（好）还是假绿（坏）。
2. **红侧（承重）**：**自己造**三个变异，打在 `/var/tmp` 副本里（不改源文件）：
   - 让看板页不再被画出来（例如让 `--page 4` 落到别的页）→ 7 条必须红；
   - 让某条车道缺失（例如把 `blocked` 从车道清单里去）→ 那 7 条里应有能抓到它的；
   - 把卡片内容列改坏 → 第 8 条点击必须红。
   各给读数与「红在哪一条」。
3. **没有顺手削弱**：`panel-b3.sh` 的断言总数（改前 223+8、改后 231）与场景数核对；改动的 8 条之外**没有别的断言被改**（diff 逐条核）。

## 边界

只读代码、只在 `/var/tmp` 私有副本里造破坏、只写 `docs/team/reports/V88-dev-bob.md` 与自己的线程；不改实现、不合并、不 push。`panel-b3.sh --all` 约 3.5 分钟，最多跑两遍（改前/改后各一），跑前 `ps` 确认没有别人的 `smoke.sh`。结论先写 PASS/PARTIAL/FAIL。local 模式。
