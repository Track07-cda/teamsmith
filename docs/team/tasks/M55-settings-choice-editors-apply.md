# M55 · settings-choice-editors 实施（apply）

```
task:   M55
agent:  dev3
issue:
change: settings-choice-editors              # 提案已验收：docs/team/reviews/settings-choice-editors-proposal.md（ACCEPTED）
specs:  panel#The console offers the schema's choice set wherever there is one, and degrades visibly / panel#The console writes a project setting only through team config set, after validation / memory-and-deps#The machine read reports each key's choice set, and the schema is its only source / memory-and-deps#A seat's model is read and written as a seat, never by composing the pair list in the caller
phase:  apply
anchor: change
deltas: panel, memory-and-deps
grant:  scripts/lib/cmd-config.sh · scripts/lib/cmd-status.sh · scripts/panel/src/** · tests/smoke.sh · tests/panel-*.sh
deps:   M54（propose，已合并）
status: todo
budget: 分批（见 change 的 tasks.md：两批 apply + 覆盖表 + 翻转）；做不完交 PARTIAL + 已完成批次
```

> 本地模式：不 push；分支留在 `.worktrees/dev3`。**计划就是 `openspec/changes/settings-choice-editors/tasks.md`**，
> 本任务书只补边界、PM 的三条重点与验收。

## PM 审查时点出的三条（硬要求）

1. **反硬编码判据必须真的这样做**：往 `team_config_schema()` **新增一个 enum 键** → 控制台**零代码改动**就给出它的选项；
   把 constraints 去掉 → 编辑器**可见地**退回自由文本并写明原因。两条都要夹具（这是本 change 的核心卖点）。
2. **"读给的值 = 校验器接受的值"**：`choices` 给出的每一项都必须能被 `team config set` 接受；
   出现"选项里有、写入却拒绝"的组合 = **门禁失败**（按 delta 的 scenario 写夹具；这条防的是编辑器与写入者各自漂移）。
3. **`unset` 不许偷偷加**：本 change **不做** `team config unset`（写入者没有这个操作，提案已裁定为 F1 后续项）。
   未设键的首个条目是"保持未设（取消 = 不写、不留审计）"；已设键把默认值当**普通写入**提供并在确认里说明——
   **视图永远不要声称它删掉了那一行**。

## Boundaries

- 只碰 `grant:` 列出的路径；其它一律不动（跨出 → `BLOCKED:` 交回 PM）。
- **不动写入者语义**：校验、CAS 指纹、两步确认、危险值清单、审计行格式、`refuse` 类行为一律保持；
  不要新增配置键；`suggest` 列是**可选第 9 列**，无建议的行保持 8 列（读者两形状都认）。
- 不动 `extension/**`、`references/**`、`SKILL.md`（除文档批若 tasks.md 明列，按它做）。
- 不 push；不改 `docs/team/DECISIONS.md`。

## Acceptance (真跑，贴原始输出)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/panel-p21.sh          # 设置视图的 pty 夹具（若 tasks.md 指定别的脚本，以它为准）
```
外加**手工实录**：① `team config list --json` 里 `bool`/`enum`/`model`/数值四类的 `choices` 实际形状各贴一条；
② 新增一个 enum 键（临时）→ 控制台出现它的选项（贴帧）→ 撤销；③ 去掉 constraints → 可见降级（贴帧）；
④ 未设键的编辑器首条目与"取消不写"的证据（`state/config.log` 不增行）。

## Report

`docs/team/reports/M55-dev3.md`：per requirement 覆盖表 + 每批翻转（红→绿）+ 独立包路径 + 上面四条手工实录。
