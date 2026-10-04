# P58 · ledger-and-gate-noise 尾单：pm 席位行与启动解析同源 + R5 场景文字改正

```
task:   P58
agent:  dev-bob
issue:
change: ledger-and-gate-noise
specs:  memory-and-deps#Every machine read is a JSON document, and an empty value is a value
phase:  apply
anchor: change
deltas: memory-and-deps
grant:  skills/teamsmith/scripts/lib/cmd-config.sh · skills/teamsmith/scripts/lib/common.sh · openspec/changes/ledger-and-gate-noise/specs/memory-and-deps/spec.md · skills/teamsmith/tests/config-cli.sh · skills/teamsmith/tests/smoke.sh（append-only）
deps:   P47（apply，已合并）· P54 的 F1（PM 裁定；此尾单落地后该 change 才可归档）
status: todo
budget: 小（一个提交组）
```

> 本地模式：不 push。

## 要做的两件事（PM 裁定，见 `docs/team/reviews/P54.md`）

1. **代码**：**pm 席位行**读的模型必须与 PM 的启动解析**同源**——空 `TEAM_DEFAULT_MODEL` 时
   PM 启动解析得到 schema 默认（`deepseek/deepseek-flash`），而当前席位行给 `""`。改成同源（空 → 回退），
   并**加一条断言**：空默认角落里 **pm 行 == 启动解析用的模型**（防再次分叉）。
2. **文字**：delta（`memory-and-deps`）里 R5 那条场景 *「An empty model is still a value」* 现在要求
   dev 行 `"model":""`，**与实现（也与你自己的设计意图：空值解析到回退）相反** → 把该场景的期望改成回退值；
   **不许**为了迁就文字去改 loader（loader 的语义是对的）。

## 必给的翻转（红→绿原始输出）

- 把 pm 行的回退去掉 → 新断言红；还原绿；
- `config-cli.sh json` 与 FAST smoke 绿；**全量 smoke 的 §31b2 红与本任务无关**（P54 的 F2，另立任务）；
  若全量因它变红，在报告里**点名区分**、不要当成你的回归。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/config-cli.sh
```
