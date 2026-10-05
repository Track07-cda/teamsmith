# P226 · 形状探针的 scratch 树必须**不吃环境**（完整内部树里 4 条假红）

```
task:   P226
agent:  dev
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 修 `checkout-shape-probe.sh` 的夹具隔离
deltas: -
grant:  skills/teamsmith/tests/checkout-shape-probe.sh · skills/teamsmith/tests/lib/checkout-shape.sh · skills/teamsmith/tests/smoke.sh · docs/team/reports/P226-dev.md · docs/team/reports/P226-dev/**
deps:   P225（verify）发现、**PM 已独立复现**；apply=你（P222 的作者）
status: todo
budget: 小到中
priority: 中高（假红会让"完整内部树"这条路径永远红；而且它是"夹具吃环境"这一族）
```

## 现场（PM 自己跑的，两步可复核）

```bash
# ① 造一棵"完整内部树"：分支树 + 从仓外归档复原两个清单注册的 17 个文件
cp -a <branch-clone> /tmp/shape-d && cd /tmp/shape-d
# 逐条按 tmux-lint-legacy.txt / signal-lint-legacy.txt 的路径从
#   $LEDGER/team/reports/<pkg>  (LEDGER = 仓外账本归档) 拷回，sha256 应 17/17 相符
# ② 跑探针（容器内）
bash skills/teamsmith/tests/checkout-shape-probe.sh
```

结果（PM 与 verify **各自**跑出同一组）：

```
bad: ⑨ 内部树 + 清单文件都在 → --select 31 退出 0（照旧判定）（期望 [0]，实际 [1]）
bad: ⑨ 内部树 + 清单文件都在 → M28 照旧带清单跑（1 个历史豁免文件）（…）
bad: ⑩ 内部树 + 清单文件都在 → --select 58 退出 0（照旧判定）（期望 [0]，实际 [1]）
bad: ⑩ 内部树 + 清单文件都在 → signal-lint 照旧逐条核对（LEGACY 打印）（…）
== 检出形状探针 == ok 134 bad 4 skip 0
```

**根因**：⑨/⑩ 用"内部树 + 清单文件都在 + 只放**一条**注册文件"来证明"有一条在位就不许跳过"。但那棵 scratch 树**继承了环境里的证据层**（另外 16 个注册文件也在），于是嵌套跑的 lint 按合成清单逐条核对，发现 16 个脚本**没被豁免** → 判红。也就是说：**夹具的 scratch 树吃了环境**（今天的默认状态是证据层不在，所以平时不暴露）。

## 要做的

1. **scratch 树必须自洽**：⑨/⑩（以及所有会复制仓库的用例）在构造时**显式排除环境里的证据层**（`docs/team/reports/*/pkg/**`），只放用例自己声明的那一条注册文件。做法你选，但要写明为什么。
2. **两个环境状态都要绿**（这是判据）：
   - **证据层不在**（今天的默认）→ 探针全绿；
   - **17 个注册文件都在**（按上面 ① 复原）→ 探针全绿（现在是 `ok 134 bad 4`）。
3. **牙齿不许丢**（每条都要有断言）：
   - "有一条注册文件在位 → 该段**判定**、不跳过"（⑨/⑩ 的原意）；
   - 影子：删掉"逐条内部面判据" → 同一条产品面缺失被吞、§58 判绿（现有影子保留）；
   - 产品面文件里的 `pkill -f` / 裸 `tmux kill-server` 照旧判红并点名 `file:line`；
   - **空面不算缺席**：`.pi/prompts` 与 `.pi/skills` 建成**空目录**时，§19 必须判红（`✓16 ✗10`，不是 SKIP10）—— verify 在 P225 里量过这条，请把它固化成断言。
4. **门禁**：`openspec validate --all --strict` + 容器内 §36（含探针，约 12 分钟）+ 上面两个环境状态各跑一次探针；报告点名"哪些自己跑、哪些引用 P225"；**换人复验**。
