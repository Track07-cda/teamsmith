# P222 · 公开检出 CI 转绿：把"机器生成面"单列一类 + 扩展现有救生通道 + 更正一句假文档

```
task:   P222
agent:  dev
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 形状判据与两处救生通道
deltas: -
grant:  skills/teamsmith/tests/** · skills/teamsmith/references/openspec.md · README.md · docs/team/reports/P222-dev.md · docs/team/reports/P222-dev/**
deps:   **用户已决定 A（修到绿）**；现场由 **P214**（dev 你自己写的只读诊断）给出，且已在 /tmp 副本上试过效果
status: todo
budget: 中
priority: 高（公开仓的 Actions 现在每次都是红的；这是我们刚写进 CONTRIBUTING 的"套件是契约的牙齿"能不能成立的问题）
```

## 现场（P214 的结论，你要自己复核一遍）

公开仓的检出**不是产品面、也不是标准内部检出，而是混合形状**：账本可读层与 `openspec/changes`、`AGENTS.md`、`SCOPE.md` 都在（→ 判 `internal`），而 `.pi/prompts/**`、`.pi/skills/**`（机器生成、被忽略）与证据包（刻意不进仓库）不在。于是 16 条断言红：

| 段 | 条数 | 根因 |
|---|---|---|
| 19 | 10 | 相位命令 `opsx-{explore,propose,apply,verify,archive}` 与相位 skill `openspec-*` 不在位 |
| 31 | 1 | M28 真树 tmux lint 的**豁免清单**指向 `docs/team/reports/*/pkg/**`（刻意不进的证据层） |
| 36 | 4 | `checkout-shape-probe.sh` 的内部树控制与选择器 `--check`（`AGENTS.md` 回来后前提变了） |
| 58 | 1 | `signal-lint` 的豁免清单同上 |

## 要做的（四件，缺一不可）

1. **第三类形状**：在 `tests/lib/checkout-shape.sh` 里把 **`.pi/prompts/**` 与 `.pi/skills/**` 单列为"机器生成面"**（它们由 `openspec init --tools pi` 在本机生成、被 `.gitignore` 忽略，**任何 CI 检出都不可能自带**）。这类面的缺失必须是**可见跳过**（点名缺的是哪一个），而不是判红。
2. **扩展救生通道**：`smoke.sh` 里 P148 的那条通道现在的门槛是 `[ "$CHECKOUT_SHAPE" = "product-only" ]`；把"**形状是 internal 但豁免清单指向不存在的证据层**"也纳入 —— 条件要**可证伪**（清单文件在位且指向存在的文件时，**必须照旧判定**，不许一并放过）。
3. **§36 的探针**：`checkout-shape-probe.sh` 里那些"内部树控制"的期望要与新语义一致（`AGENTS.md` 回来后前提已变）；**牙齿不许丢**——往产品面文件里植入一个真问题，探针必须仍然红。
4. **更正一句假文档**：`references/openspec.md` 与 `README.md` 现在写着五个相位命令"由 `openspec init --tools pi` 生成"，而钉住的 openspec **1.8.0 只有 `core` profile，生成不出 `verify` 那一对**（P214 实测：`openspec config profile expanded` 报 Unknown preset，`init --tools pi` 只生成 6 个 prompt + 6 个 skill，没有 `opsx-verify` / `openspec-verify-change`）。改成实话（哪些是生成的、哪些不是、拿不到时怎么办）。

## 验收（必须可证伪，自己造现场）

1. **造一个"混合形状"夹具**（有账本/`openspec/changes`/`AGENTS.md`/`SCOPE.md`，无 `.pi/prompts`、`.pi/skills`、无证据包）：§19 从 ✗10 变成 **可见 SKIP 且点名缺的面**；§31/§58 变成**点名清单**的可见跳过；选择器 `--check` 通过（该行是声明的 SKIP）。
2. **反向（本仓库这个标准内部检出）**：`.pi/prompts` 在位的树里，§19 的十条**照旧判定**（不许变成跳过）；豁免清单指向的**文件都在**时，§31/§58 照旧判定。
3. **牙齿**：往产品面文件里植入一个真问题（例如把某个段依赖的产品字面量改掉）→ 探针/断言**必须红**；把判据改成"永远跳过"的影子 → 第 1 项必须红。
4. **门禁**：`openspec validate --all --strict`；容器内跑**受影响段**（19、31、36、58 与探针自己的段）并把 ✓/✗/SKIP 逐段抄进报告；**说明你跑了什么、没跑什么**（没跑全量就写明）。
5. 报告要能让**另一个 agent**照着重跑（命令 + 夹具构造步骤 + 期望数字）。
