# P114 · `model-id-shape` apply（model 段可以带 `/`：三处写入器共用一个判定）

```
task:   P114
agent:  dev
issue:
change: model-id-shape          # 提案已验收：docs/team/reviews/model-id-shape-proposal.md (ACCEPTED)
specs:  memory-and-deps#（模型 id 的形状：单段 provider + 可含 `/` 的 model）
phase:  apply
anchor: change
deltas: memory-and-deps
grant:  skills/teamsmith/scripts/lib/{cmd-config,common}.sh · skills/teamsmith/scripts/team（用法行若需同步）· skills/teamsmith/tests/smoke.sh（append-only）· skills/teamsmith/tests/**（夹具）· skills/teamsmith/references/{config,protocol,troubleshooting}.md（需要时一句）· openspec/changes/model-id-shape/specs/memory-and-deps/spec.md
deps:   P102（propose，已合并）· 现状三处校验器都在 `cmd-config.sh`（`model` kind / `pairlist` token / `set-agent-model`）
status: todo
budget: 一个小工作块
priority: 中（用户实测被它挡过：`opencode-go/deepseek/deepseek-v4.1-flash` 被拒；而 Pi 接受的 openrouter 风格 id 正是三段）
```

> 本地模式：不 push。**CI 不再作为判据**（D54）——本地门禁是决定性证据 ✓。
> 真源 = `openspec/changes/model-id-shape/{design.md,tasks.md}`（逐条兑现那 7 条场景）。

## 硬要求（与我给 propose 的口径一致）

1. **接受**多段 model：`openrouter/amazon/nova-lite-v1`（我实测 Pi 能解析并跑通 ✓）在**三处写入器**上都要能过：
   `team config set TEAM_DEFAULT_MODEL …` · `TEAM_AGENT_MODELS='seat=…'` · `team config set-agent-model <seat> …`；
2. **先剥 `:思考档` 后缀再判形状**、值里**保留**后缀 ✓（`provider/vendor/model:high` 也要能过 ✓）；
3. **拒绝集闭**：无 `/` · 前导 `/` · 尾随 `/` · 空段（`a//b`）· 含空白 ✓ —— 每种**非零退出**且**措辞点名是哪一段错** ✓；
4. **只有一处判定**：抽成一个共享 helper，三处调用它 ✓；证据：**同一输入经三条路得到同一裁决**（贴三种路的输出）✓；
5. **渲染器按第一个 `/` 切**（不是最后一个）✓：窗口解析对三段 id 正确 ✓（并证明 `TEAM_MODEL_WINDOWS='openrouter/amazon/nova-lite-v1=300000'` 能解析出 300000 ✓）；
6. **读面不崩**：`team config list --json` 的席位行、`known[]` / `choices.values`（面板的选择器）都要**带完整 id** ✓；
7. **红侧**（各自影子掉 → 必须红）：把规则放宽成"只要有一个 `/` 就过" → `a//b` 那条红 ✓；把切分改成**最后一个** `/` → 窗口解析那条红 ✓。

## 验收

- `openspec validate --all --strict` + **FAST 全绿** + 受影响段（可用 **`section-select.sh --paths skills/teamsmith/scripts/lib/cmd-config.sh`** 取段 ✓）+ 一次全量；
- 报告给**红/绿原始输出**；delta 只在措辞确实需要时改。
