# P126 · `team_model_window` 认不出 `:思考档` 后缀（顺带修 09-21 那个"要写 TEAM_MODEL_WINDOWS"的痛点）

```
task:   P126
agent:  dev-bob
issue:
change: -                        # 无 change：既有工具的解析修复（anchor: none (infra)）
specs:  -
phase:  apply
anchor: none (infra) — 只改模型窗口解析，不动派单守卫的语义与阈值逻辑
deltas: -
grant:  skills/teamsmith/scripts/lib/common.sh（`team_model_window*`）· skills/teamsmith/tests/**（新增/追加夹具）· docs/team/reports/P126-dev-bob.md · docs/team/reports/P126-dev-bob/**
deps:   P102/P114（模型 id 形状：`provider/model` + 可选 `:思考档`）· 现场（2026-09-29 PM 给 verify 设 `openai-codex/gpt-6-sol:high`）
status: todo
budget: 小
priority: 中（每次"解析不到窗口"都要人去写 `TEAM_MODEL_WINDOWS` 兜底 ✓）
```

> 本地模式：不 push。**CI 不再作为判据**（D54）。

## 现场（PM 实测）

```
team_model_window openai-codex/gpt-6-sol        → 272000   ✓（Pi 的 models-store 里就有）
team_model_window openai-codex/gpt-6-sol:high   → 空       ✗✗
team_model_window kimi-coding/kimi-for-coding   → 1048576  ✓（TEAM_MODEL_WINDOWS 提供）
```
后果：`cmd-agents.sh:343` 的会话体积守卫**取不到窗口** ✗ → 退回 `TEAM_SESSION_WARN_TOKENS`（默认 200000 ✓），
比真实窗口（272000 ✓）**保守** → 会**过早**警告/拒绝 ✗。这正是 09-21 那次"不得不写 `TEAM_MODEL_WINDOWS` 才派得动"的同一根因 ✓。

## 要做

1. **`team_model_window` 支持 `:思考档` 后缀** ✓：先按**原样**匹配 ✓，匹配不到再**去掉一个闭集后缀**重试 ✓；
   闭集 = P102 定下的那些档（`minimal|low|medium|high|xhigh|max` ✓）—— **不许**把任何 `:` 后缀都砍掉 ✗✗：
   `openai/gpt-6-sol-pro:batch` 是**真实模型 id** ✓（`models-store.json` 里就有 ✓）→ 它**必须**按原样匹配 ✓。
2. `TEAM_MODEL_WINDOWS` 的匹配用同一口径 ✓（一条实现 ✓，别两处 ✓）。
3. **证据**（双向 ✓ + 反例 ✓）：
   - `openai-codex/gpt-6-sol` / `…:high` / `…:xhigh` → **同一个值** ✓（都能解析 ✓）；
   - `openai/gpt-6-sol-pro:batch` → **按原样**（不被砍 ✓；若目录里有它，取它自己的窗口 ✓）；
   - `TEAM_MODEL_WINDOWS='x/y=123'` 时 `x/y:high` → 123 ✓（显式覆盖也吃后缀 ✓）；
   - **红侧**：把"去后缀"逻辑影子成"任意 `:` 都砍" → `:batch` 那条必须**红** ✓；影子成"完全不去" → `:high` 那条红 ✓。
4. `openspec validate --all --strict` ✓ + **FAST 全绿** ✓ + 一次全量（若你判断必要 ✓）。
