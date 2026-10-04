# P112 · `gate-runtime-budget` 独立验证（换人）

```
task:   P112
agent:  dev2
issue:
change: gate-runtime-budget                # 已在 main（propose=P97 dev3 · apply=P98 dev3）——你不是 dev3
specs:  verification#（分段账目 · 路径选段 · 选段运行自述）
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P112-dev2.md · docs/team/reports/P112-dev2/**（只写报告与证据）
deps:   P98（apply，已合并）· `tests/section-paths.tsv` · `tests/section-select.sh` · `smoke.sh --paths/--select`
status: todo
budget: 一个验证包
priority: 中（归档前最后一道门）
```

> 本地模式：不 push。**验证对象 = main 上已合并的实现**。**CI 不再作为判据**（D54）——本地门禁才是 ✓。

## 必须自己动手（不要只跑作者的夹具）

1. **选择器五态**（你自己的 scratch 项目/路径）：docs-only → `NONE`；产品路径 → `RUN`（列出键 + `needs` 闭包）；
   **未声明路径 → `FULL` 并点名它**；混合 → `RUN`；未知 key → 拒且**什么都不跑**；
2. **`--check` 可证伪**（≥2 种**你自己想的**坏）：例如把某行的 patterns 清空、或删掉一整行、或让 `needs` 指向不存在的 key
   → 必须**非零 + 点名**（贴原始输出）；还原 → 零；
3. **选段运行**：只跑选中段 + 闭包 ✓、**点名"这次没跑的段"** ✓、并给出"选段不是全套门禁"的免责声明 ✓；
   `--paths` 命中未声明路径时，运行头必须说**全套在跑**（不是"0/113 · 没跑 113" ✗）；
4. **分段账本**：
   - 每段收口行的**统一格式**（`#N id · 用时 Ns · ✓P ✗F SKIPk · ticks N`）——证明它同时满足两边既有的 pin
     （P70 的 §14d 形状 + 本 change 的账本解析）✓；
   - **增量之和 == 结果行** ✓（账本自查行）；**慢段汇总**存在 ✓；
   - **红标不被污染**：一个**有失败**的段，账本里记 `✗N`（纯文本 ✓）而门禁的红标计数**不变**（用既有 `flip-m33.sh` 或你自己的对照）；
5. **零回归**：`openspec validate --all --strict` + `routes.sh` + `--budget-check` + `--loop-check` + **FAST 全绿**（+ 一次全量，若你判断必要）；
6. 报告写清"哪些是你自己的证据、哪些是引用"，附**红/绿原始输出**。
