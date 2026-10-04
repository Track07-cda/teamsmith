# P68 · fixture-waits-for-landed-reads apply：夹具等数据态 + 量测固定目标

```
task:   P68
agent:  （等席位）
issue:
change: fixture-waits-for-landed-reads        # 提案已验收：docs/team/reviews/fixture-waits-for-landed-reads-proposal.md
specs:  verification#A fixture observes a data-derived state before it asserts it / verification#A measuring fixture measures a fixed tree, not the caller's worktree
phase:  apply
anchor: change
deltas: verification
grant:  skills/teamsmith/tests/panel-p21.sh · skills/teamsmith/tests/panel-b3.sh · skills/teamsmith/tests/lib/*（等待引擎）· skills/teamsmith/tests/panel-cpu.sh · skills/teamsmith/tests/panel-cpu-premise.sh · skills/teamsmith/tests/smoke.sh（append-only）
deps:   P62（propose，已合并）· D43（归因）· D44 的 F2/F4 · P48 的 pty-wait 引擎（复用它，别再造一套）
status: todo（等席位）
budget: 一个工作块（B1 settings 与 collapse 的等待口径 / B2 panel-cpu 的固定目标 / B3 夹具与翻转）
priority: **中高**（CI 那条红就是它要修的节奏问题）
condition: **apply 必须消解那条指向未合并 requirement 的引用**（改写为引用 base 里已有的 D33 那条，或等 P56 落地）
```

> 本地模式：不 push。**真源 = `openspec/changes/fixture-waits-for-landed-reads/{design.md,tasks.md}`。**

## 硬要求

1. **等数据态**：`panel-p21.sh` 的"手改文件 → 开选择器"那条路必须**等到那一行显示新值**（有界、可归因、
   点名等的是哪个数据态）；**不许**用骨架标记或固定 `sleep` 当证据；
   同一个口径覆盖 **D44-F2**（`panel-b3.sh` 的 `collapse` 固定 `sleep 5` + 单次 capture，6 次红 4 次）。
2. **复用 P48 的等待引擎**（`tests/lib/pty-wait.sh` 的进度感知/归因/rc=4），**不要**造第二套；
   上限**不是**性能阈值（D33），并把**实测延迟带**记在夹具旁边。
3. **量测固定目标**（D44-F4）：`panel-cpu.sh` 量**中性参考项目**（自己 fix 的那个根），
   输出**同时点名**"量的项目根"与"被测 bundle"；从两个不同工作树跑 → **同一根、同一结论**。
4. **红/绿两侧**：注入 settings 读延迟（scratch wrapper）→ **旧夹具红、新夹具在延迟下落定后仍绿**；
   **数据永不落定** → 有界等待到顶并点名（不是假绿）；`panel-cpu` 两工作树对照（积累态 vs 全新根）。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/panel-p21.sh choices
bash skills/teamsmith/tests/panel-cpu.sh --self-check 2>/dev/null || bash skills/teamsmith/tests/panel-cpu-premise.sh
```
