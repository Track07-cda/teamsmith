# P102 · 模型 id 的形状：provider 段不带 `/`，**model 段可以带**（OpenRouter 风格）

```
task:   P102
agent:  （等席位）
issue:
change: model-id-shape
specs:  memory-and-deps#（模型 id 的 `provider/model` 形状与三处写入器的校验）
phase:  propose
anchor: change
deltas: memory-and-deps
grant:  openspec/changes/model-id-shape/**
deps:   用户 2026-09-28 在面板里输入 `opencode-go/deepseek/deepseek-v4.1-flash` 被拒（多段被挡）；
        Pi 的 openrouter 目录里模型 id **本来就带斜杠**
status: todo（等席位；**先 propose**）
budget: 一个提案包
```

> 本地模式：不 push。**本任务只 propose。**

## 事实（我实测/核过）

1. **Pi 接受多段 id 并且真能用**：

```
$ pi --model openrouter/amazon/nova-lite-v1 -p "Reply OK"      → rc=0，模型正常回答
$ pi --model openrouter/nope/nope-nope  -p "Reply OK"          → 400 not a valid model ID（对照：真判错）
```

2. **Pi 自带目录里 openrouter 的 id 就带斜杠**：`amazon/nova-lite-v1`、`aion-labs/aion-2.0`、`amazon/nova-micro-v1` …
   （在 `dist/bundle/chunks/*.js` 里以 `"<vendor>/<model>":{… provider:"openrouter"}` 形式存在）
3. **我们的校验器拒绝它们** ✗：`cmd-config.sh` 三处（`model` kind 的 `*/*/*)` → 「恰好一个 /」·`pairlist` 里每个
   `seat=model` token · `set-agent-model`）都把"≥3 段"当非法 → **合法配置被挡**（用户就是这样撞上的）。

## 正确的规则（提案要写清并给反例）

- **provider = 第一段**：非空、**不含 `/`**。
- **model = 其余全部**：非空、**可以含 `/`**（OpenRouter 风格）。
- **`:思考档` 后缀**（如 `openai-codex/gpt-5.6-terra:xhigh`）必须继续工作 —— 写清是先剥后缀再判形状还是相反，
  并用夹具钉住两种写法（`provider/vendor/model:high` 也要能过）。
- **仍然拒绝**：无 `/` · `/x` · `x/` · 空段（`a//b`）· 含空白/换行。
- 错误措辞要**准确**（现在说"恰好一个 /"是错的）：例如「provider 段不能含 `/`；model 段可以」并点名拒的是哪一段。
- **一处实现**：`team config set`（model kind + pairlist token）· `set-agent-model` · 面板（面板只显示 owner 命令的
  错误 —— 现状如此 ✓）→ 证明"改一处，三处同时正确"。
- **窗口解析必须继续对多段 id 正确**：`team_model_window` 现为 `prov=${want%%/*}` / `model=${want##*/}` ✓，
  `TEAM_MODEL_WINDOWS` 的匹配 `"$pat"|*/"$pat"` ✓ —— 要有断言钉住（例如给
  `TEAM_MODEL_WINDOWS='openrouter/amazon/nova-lite-v1=300000'` → 解析出 300000）。
- **面板的模型选择器**（`known[]` / `choices.values`）遇到多段 id 不崩、能显示、能选中。

## 可证伪（提案里列成 §场景）

1. 三段真模型（如 `openrouter/amazon/nova-lite-v1`）**被接受**，并在席位行/`config list --json`/面板里正常显示；
2. `a//b` · `/a` · `a/` · `a` · `a b/c` **仍被拒**，措辞点名是哪一段错；
3. `kimi-coding/kimi-for-coding:high` 与 `openrouter/amazon/nova-lite-v1:high` 两种写法都能过；
4. **反向**：把校验放宽成"只要有一个 `/` 就过" → `a//b` 必须变红（证明断言真的在管形状）。

## Non-Goals

- 不改 Pi 的解析、不改 `TEAM_MODEL_WINDOWS` 的语法；
- 不动当前默认模型（`opencode-go/deepseek-v4.1-flash`，2026-09-28 用户设定）；
- 不引入"从 Pi 目录自动补全 provider"这类新能力。
