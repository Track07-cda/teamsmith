# P108 · `gate-section-accounting` 独立验证（换人）

```
task:   P108
agent:  dev-bob
issue:
change: gate-section-accounting            # 已在 main（apply=P70 dev2；propose=P56 verify 席位）——你不是其中任何一位
specs:  verification#（门禁的段落账目/预算/超时点名）
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P108-dev-bob.md · docs/team/reports/P108-dev-bob/**（只写报告与证据）
deps:   P70（apply，已合并）· `tests/lib/section-guard.sh` · `tests/section-budgets.tsv` · `tests/loop-inventory.tsv` · `tests/smoke.sh` 的 0e/0f/0g/14d
status: todo
budget: 一个验证包
priority: 中（归档前的门）
```

> 本地模式：不 push。**验证对象 = main 上已合并的实现**。

## 必须自己动手（**不许**只跑作者的夹具）

1. **静态三面**（我做过三种，你要做**至少四种**，含一种我没做的）：
   - 删预算行 / 把预算改到低于 `max(ceil(band×4), 60)` / 塞一个未登记的 `while+sleep` / **你自己想一个**（例如 `needs` 指向不存在的 key、或让某段读了没声明的路径）；
   - 每种都要：**非零 rc** + **点名**（段号或行号）——把原始输出贴进报告；
2. **运行时那一条（关键，别只信文档）**：在**scratch 副本**里造一个**真的会卡住**的段（超预算但仍活着）→ 门禁必须
   **点名该段并停掉它**（给出现场），**而不是**无限等；同时**反向**确认 **D33 的口径**：
   一个"**只是慢、但没卡**"的段（在预算内）**必须保持绿** ✓ —— 这是"预算 = 存活上界，不是性能红线"的可证伪证明；
3. **等待归属（0g）**：造一个"等待到顶"的形状 → 必须**归因**（ticks/归因行），不许静默；
4. **循环清单完整性**：清单里的每个 `cap=`/`bound=` 至少抽 5 个**逐条核对**代码（数字/结构是否真的存在）；
   再证明"新增一个循环 → 红" ✓；
5. **零回归**：`openspec validate --all --strict` + FAST（+ 一次全量，若你判断必要；**CI 现在被账号层挡着**，本地就是决定性证据）；
6. 报告写清"哪些是你自己的证据、哪些是引用"，并给**红/绿原始输出**。
