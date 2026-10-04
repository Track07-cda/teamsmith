# P111 · `gate-section-accounting` 复验（P110 返工后·换人）

```
task:   P111
agent:  （等席位）
issue:
change: gate-section-accounting            # 已在 main（apply=P70 dev2 · 返工=P110 dev2）——你必须不是 dev2
specs:  verification#（门禁的段落账目 / 预算 / 超时点名）
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P111-*.md · docs/team/reports/P111-*/**（只写报告与证据，不改实现）
deps:   P108（上一轮独立验证 PARTIAL，两条 finding）· P110（返工，已合并）· `tests/lib/section-guard.sh` 的自检（含 decimal / f1 两个内置红侧）
status: todo（等席位）
budget: 一个验证包
priority: 中（归档前的门）
```

> 本地模式：不 push。**验证对象 = main 上已合并的实现**（不要只看 P108/P110 的报告）。
> **CI 不再作为判据**（D54：用户额度被高频推送烧光）——**本地门禁才是决定性证据** ✓。

## 必须自己动手

1. **静态面（≥4 种，含一种你自己想的）**：删预算行 / 预算低于 `max(ceil(band×4),60)` / 未登记的 `while+sleep` /
   `needs` 指向不存在的 key / 段读了未声明的路径 —— 每种：**非零 + 点名**，贴原始输出；
2. **运行时面**：scratch 副本里造一个**真卡住**的段 → 必须**点名并停掉**（给现场），不许无限等；
   **反向**（D33）：一个"只是慢、没卡"的段**必须保持绿** ✓；
3. **P110 的两处返工，你要自己复现**：
   - **F2**：一个**小数 band** 被真实超过 → 必须出现「超过实测带」那一行（**记录**，不改退出码 ✓）；
     再把比较还原成整数守卫（scratch）→ 必须**不再出现**（红侧）；
   - **F1**：`--desc-grace` 下**响应 TERM** 的子进程 → escalation 行**不得**声称"子孙忽略 TERM"（红侧：还原旧措辞 → 变红）；
4. **循环清单抽样**：清单里抽 ≥5 个 `cap=`/`bound=` **逐条核对**代码，数字/结构要真的存在；再证明"新增循环 → 红"；
5. **零回归**：`openspec validate --all --strict` + `--budget-check`（112/112）· `--loop-check` · `gate-guard.sh` · **FAST 全绿**（+ 一次全量，若你判断必要）；
6. 报告写清"哪些是你自己的证据、哪些是引用"，附**红/绿原始输出**。
