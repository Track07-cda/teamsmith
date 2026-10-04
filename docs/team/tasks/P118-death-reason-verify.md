# P118 · `agent-death-reason` 独立验证（换人）

```
task:   P118
agent:  dev2
issue:
change: agent-death-reason        # 已在 main（propose=P101 verify · apply=P113 dev3）——你不是其中任何一位
specs:  watchdog#（闭集分类 / 当前一次死亡 / 可见面）· notify-and-inbox#（异常死亡恰好一次 knock）· panel#（agents 块带 cause）
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P118-dev2.md · docs/team/reports/P118-dev2/**（只写报告与证据）
deps:   P113（apply，已合并）· `lib/cmd-death.sh` · `tests/death-cause.sh`（作者的夹具——**可以读，不许只跑**）
status: todo
budget: 一个验证包
priority: 中高（用户点名的功能：额度用完时能不能**看见原因** ✓）
```

> 本地模式：不 push。**验证对象 = main 上已合并的实现**。**CI 不再作为判据**（D54）。

## 必须自己动手（**自造场景**，不许只跑作者的 §52）

1. **分类矩阵（你自己的行）**：五类各至少一条**你写的**帧 ✓；**两条反例**各一条（"看起来像 auth 的额度帧"→ 仍 `quota` ✓；
   **散文**（只是提到某个词）→ **不分类 → `unknown`** ✓）；**缺证据**（空/不可解析）→ `unknown` ✓；
2. **标签属于"当前这次启动"**：在 scratch 项目里造**上一代**死亡的证据（旧 `started` / 旧 nonce ✓）→
   重启后**不得**继承 ✓；再造**同一代**的第二次死亡 → 必须是**新**死亡 ✓；
3. **恰好好处**：一次异常死亡跑**三个 tick** → **恰好一条** knock ✓；**正常退出**（干净 `exit 0`）→ **静默** ✓；
   **standby** 时顺延**不丢** ✓；无来源可读 → 点名**但只一条** ✓；
4. **可见面**：`team status` / `team digest` / 面板 agents 块（`cause*`）三处都要**亲自看一眼**（贴原始输出 ✓）；
   并确认**运行中的席位不带 cause** ✓；原始证据行**不外溢**到别的输出行 ✓；
5. **对抗**：至少**两条你自己的红侧**（例如把分类器影子成"永远 unknown" → 额度场景必须变 unknown ✓；
   把去重去掉 → 三次 tick 变三条 ✓）；**还要**试一次"让它撒谎"的方向（例如一条**只有词、没有错误形状**的行 ✓）；
6. **零回归**：`openspec validate --all --strict` + **FAST 全绿**（+ 一次全量，若你判断必要）；
7. 报告写清"哪些是你自己的证据、哪些是引用"，附**红/绿原始输出**；**不改实现**（要改 → `BLOCKED:` 交回 PM ✓）。
