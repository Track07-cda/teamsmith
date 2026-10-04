# P116 · `model-id-shape` 独立验证（换人）

```
task:   P116
agent:  verify
issue:
change: model-id-shape            # 已在 main（propose=P102 dev · apply=P114 dev）——你不是 dev
specs:  memory-and-deps#（模型 id 的形状：单段 provider + 可含 `/` 的 model）
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P116-verify.md · docs/team/reports/P116-verify/**（只写报告与证据）
deps:   P114（apply，已合并）· `scripts/lib/cmd-config.sh`（三处写入器）· `scripts/lib/common.sh`（窗口解析）
status: todo
budget: 一个验证包
priority: 中（归档前的门）
```

> 本地模式：不 push。**验证对象 = main 上已合并的实现**。**CI 不再作为判据**（D54）——本地门禁才是决定性证据 ✓。

## 必须自己动手（**自建 scratch 项目**，绝不碰本仓库的真配置/真名册）

1. **接受侧**：`openrouter/amazon/nova-lite-v1`（三段 ✓）· `opencode-go/deepseek/deepseek-v4.1-flash`（三段 ✓）·
   `kimi-coding/kimi-for-coding:high`（后缀 ✓）——在**三条写入路**（`config set TEAM_DEFAULT_MODEL` ·
   `TEAM_AGENT_MODELS='seat=…'` · `set-agent-model`）**各自**都要过，并贴三路输出 ✓；
2. **拒绝侧**：无 `/` · 前导 `/` · 尾随 `/` · 空段 `a//b` · 含空白 —— 每种**非零**，并**逐条核对措辞是否点名了哪一段**
   （provider 缺失 / provider 为空 / model 有空段 ✓）——不许只说"拒绝成功"✗；
3. **"一处判定"**（proposal 的核心承诺）：证明三路走的是**同一个**判定（例如同一畸形值在三路得到**同一句话** ✓，
   或从代码/调用图上指出唯一入口 ✓）——**不许**只引用它的说明 ✗；
4. **窗口与切分**：`TEAM_MODEL_WINDOWS='openrouter/amazon/nova-lite-v1=300000'` → 解析出 **300000** ✓；
   **红侧**：把切分改成**最后一个** `/`（scratch 影子）→ 该条必须红 ✓；
5. **拒绝集的红侧**：把规则放宽成"只要有一个 `/` 就过"（scratch 影子）→ `a//b` 必须**被接受**，于是"拒绝空段"那条断言红 ✓；
6. **真实值零回归**：本仓库当前在用的两个值（`opencode-go/deepseek-v4.1-flash` · `kimi-coding/kimi-for-coding:high`）仍须可用 ✓；
7. **零回归**：`openspec validate --all --strict` + `routes.sh` + `config-cli.sh` + **FAST 全绿**（+ 一次全量，若你判断必要）；
8. 报告写清"哪些是你自己的证据、哪些是引用"，附**红/绿原始输出**。
