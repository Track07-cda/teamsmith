# P80 · bottom-border-candidate-selection apply（下边框取最低候选）

```
task:   P80
agent:  （等席位；**不得派给 verify 席位**——OWNERSHIP：verify 不改实现）
issue:
change: bottom-border-candidate-selection   # 提案已验收：docs/team/reviews/bottom-border-candidate-selection-proposal.md
specs:  delivery-guard#The bottom border is the lowest qualifying rule row below the cursor
phase:  apply
anchor: change
deltas: delivery-guard
grant:  skills/teamsmith/scripts/lib/outbox.sh · skills/teamsmith/tests/lib/box-judge.sh · skills/teamsmith/tests/frames/（新增 p78-* 帧）· skills/teamsmith/tests/pm-box-real.sh · skills/teamsmith/tests/smoke.sh（append-only）· skills/teamsmith/references/troubleshooting.md（§3 的代价段）
deps:   P78（propose，已合并）· P67（上一轮：顶边框取最高 + 邻行按内容读）
status: todo（等席位）
budget: 一个工作块
```

> 本地模式：不 push。**真源 = `openspec/changes/bottom-border-candidate-selection/{design.md,tasks.md}`。**

## 硬要求（验收逐条查）

1. **下边框 = 光标下方最低的合格整行规则行**；**不是最近的**；**光标自身是规则行时不算候选**（严格在光标下方找）。
2. **单调性**：**任何帧的判定都不许从 `BUSY` 变成 `EMPTY`**（写一条断言：对已存真帧与自造帧逐个对比旧/新判定）。
3. **一处实现**：生产提取与夹具判定共用同一个判定；红侧用既有影子机制（`M24_SHADOW_CHROME`/`M45_NO_STRIP` 模式）
   把它影子成**旧的最近优先**顺序 → 对应断言红。
4. **代价段**：`references/troubleshooting.md` §3 写"框下方的整行规则行会把框撑大 → 读忙 → 投递等待"，
   并附**实测**（两种已存真布局里不可达）。
5. **真帧不回退**：Pi 0.85.1 / 0.87.0 的已存帧判定**逐一不变**（用 §4 的清单）。
6. **红/绿两侧原始输出**（按 design 的证伪计划）+ `openspec validate` + FAST + 全量 smoke。
