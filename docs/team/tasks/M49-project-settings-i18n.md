# M49 · 项目设置的 key 要 i18n：列表显示人话标签，不显示裸 `TEAM_*`

```
task:   M49
agent:  verify
issue:  
change: console-project-settings     # 该 change 尚未归档 → 本次同时改它的 delta（见下）
specs:  panel
phase:  apply                        # 在已验收的 change 上做一次有记录的收口返工
deps:   P22（同一 change 的 apply，已合并）· P20（字符串表与编辑键位）
status: todo
budget: 一个工作块
```

> 本地模式：不 push，任务分支留在 `.worktrees/verify`。

## 用户要求（原话）

「项目设置的 Key 需要 i18n，不要显示原始的 key」

现状（自己核一遍）：`openspec/changes/console-project-settings/specs/panel/spec.md` 的
「The console shows the project contract …」里明写每行给出 **the key name**（裸 `TEAM_*`），
而 `panel/src/strings/{zh,en}.ts` 里 **一条 `TEAM_` 都没有**（0 命中）。

## Deliverables

1. **标签进字符串表**：给 schema 里**每个键**一条 zh 与 en 标签（例如
   `TEAM_PULSE_INTERVAL` → zh「巡检周期」/ en「Patrol interval」）。标签是**人话**，不是把键名拆词。
   继承既有规则：可见文本一律来自外部字符串表；两张表的键集必须一致且非空。
2. **列表渲染改成人话标识**：
   - 行的主标识 = 本地化标签（+ 当前值 + 生效类 + 该行自己的行尾注释，这几样照旧）；
   - **裸 `TEAM_*` 不再作为行的主文本**；
   - 但**操作上必须能对齐 CLI**：编辑提示、以及「要执行哪条命令」的文案里仍然点名原始键
     （用户要照着敲 `team config set TEAM_PULSE_INTERVAL 300`）——这条要写清并测试；
   - **schema 不认识的键**（文件里有、schema 没有）没有标签可用 → 回退显示原始键，并在报告里说明这是刻意的。
3. **搜索匹配三种输入**：标签、原始键、值（会敲 `TEAM_` 的人也能搜到）。
4. **完整性断言（可证伪）**：schema 的每个键在 zh/en 两张表里都有非空标签；**没标签就红**。
   翻转：删掉任一条标签 → 断言红。
5. **delta 同步**（这个 change 还没归档）：把 `specs/panel/spec.md` 里那条 requirement 改成
   「行的人话标签来自字符串表；原始键只在需要与 CLI 对齐处出现；未知键回退显示原始键」，
   并补对应的 scenario（含「按原始键搜索仍能找到」与「未知键回退」两条）。
   **改动只加在这份 delta 上**；PM 会在你交付并通过复验后走归档。

## Boundaries

- 不改 schema 的键名/语义、不改写入门面（`team config set` 的参数仍是原始键）。
- 面板性能契约不变（<1% 单核、首帧 <2s）；标签是静态查表，别在渲染路径上读文件。
- 别碰 M47（CI 可移植性，dev2）与 M48（重复 ID 聚焦，dev3）动过的文件区域；`panel.js` 改了要**重建**。
- 测试纪律照旧（私有 tmux socket、破坏性调用进容器）。

## Acceptance (must actually be run)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 手工实录：打开项目设置视图，贴一段真实帧（zh 与 en 各一段），证明行里是标签、命令里是原始键
```

## Report

`docs/team/reports/M49-verify.md`。
