# M60 · settings-choice-editors 独立验证（verify 阶段）

```
task:   M60
agent:  dev
issue:
change: settings-choice-editors
specs:  panel#The console offers the schema's choice set wherever there is one, and degrades visibly / panel#The console writes a project setting only through team config set, after validation / memory-and-deps#The machine read reports each key's choice set, and the schema is its only source / memory-and-deps#A seat's model is read and written as a seat, never by composing the pair list in the caller
phase:  verify
anchor: change
deps:   M54（已合并，propose）· M55（已合并，apply）
status: todo
budget: 一个工作块（只写复验证据与报告，**不改实现**）
```

> 本地模式：不 push；只写 `docs/team/reports/M60-dev.md`（+ `docs/team/reports/M60-dev/` 证据目录）。

**为什么是你**：这条 change 的 apply 由 **dev3** 做（M55，已合并 `78fc880`），按 D31「不许自己验自己（按 change 判定）」，
验证必须换人——你与这条 change 无任何 apply 关系。**你只写报告与证据，不改实现**。

## 要对抗性验证的四条（每条给可复现命令 + 原始输出）

1. **反硬编码判据（本 change 的核心卖点）**：往 `team_config_schema()` **临时新增一个 enum 键**
   → 控制台**零代码改动**就给出它的选项；**去掉该键的 constraints** → 编辑器**可见地**退回自由文本**并写明原因**。
   两条都要有原始帧证据；做完把临时改动**还原**并证明工作树干净。
2. **"读给出的值 = 校验器接受的值"**：`team config list --json` 的 `choices` **每一项**都要能被 `team config set` 接受；
   构造一个"选项里有、写入却拒绝"的组合（若能）→ 必须是**门禁失败**而不是静默。
   并独立复核一致性闸门本身**不是恒真**（把某一项的校验放宽/收紧 → 闸门应变红；给翻转输出）。
3. **模型词汇表是本项目的，不是机器的**：证明选择器里的模型条目**不含**机器目录里的其它 provider
   （提示：本机历史上有过一个端点已下线的 provider；现在是 ollama/deepseek/openrouter + `openai-codex`），
   并证明 `known` 集里**包含 `pm` 席位**的模型。
4. **写入路径没被绕开**：视图写入仍走 `team config set`（唯一写入者）、两步确认、CAS 指纹、
   危险值二次确认、审计可从视图与 CLI 两处读；`unset` **没有**被偷偷加（未设键首条目是"保持未设"，取消不写、不留审计）。

## 已知噪声（别误判）

- **§38-b 的 pty 夹具在负载下会"中间帧 + 裸 Escape 清理"级联出大量假红**（M55 第一次复验遇到 62 条，
  同一份夹具随后连跑 3 次全绿）。**M59 正在修这个机制**（dev3）。你若遇到 §38-b 大面积红：
  **先单独重跑** `bash tests/panel-p21.sh choices`，并在报告里写清"是级联还是真失败"（给两次输出）。
- 全量门禁在机器忙时可能排队（`flock`）；**批量阶段用 `TEAM_SMOKE_FAST=1`**，全量套件只在交付前跑一次。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/smoke.sh </dev/null                 # 全量复验（贴结果行）
bash skills/teamsmith/tests/panel-choices.sh                    # 一致性闸门
bash skills/teamsmith/tests/panel-flip-m54.sh F-B               # 翻转（红→绿）
bash skills/teamsmith/tests/panel-flip-m54.sh F-C
```

## Boundaries

- **不改实现**（`scripts/**`、`extension/**`、`tests/**` 一律不改）；发现缺陷 → 写清楚交回 PM。
- 需要新夹具才能验证时，写在**你的证据目录**里（`docs/team/reports/M60-dev/`）。
- 不 push；不改 `docs/team/**` 里 PM 的文件。
