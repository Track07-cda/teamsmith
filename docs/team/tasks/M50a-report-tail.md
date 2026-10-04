# M50a · M50 的收尾：把已经完成的活写成报告与证据（不改代码）

```
task:   M50a
agent:  dev2
issue:
change: -
specs:  -
phase:  -
anchor: none (infra) — 只写报告与证据；M50 的性能契约锚点由后续 read-cost-budgets 回填 change 提供（PM 已用 --force 放行）
deps:   M50（同一实现，dev 三次空转未交付报告，PM 停掉它）
status: todo
budget: 一个工作块（只写报告 + 跑证据，**不许改实现**）
```

> 本地模式：不 push。

## 背景（为什么是你在做这件事）

M50 的实现**已经在磁盘上**（分支 `task/M50-digest-89s`，tip `d46fd4e`，6 个提交，工作树干净），
但作者（`dev`）三轮会话都没能交付报告：最后一轮它的 todo 与实际不符、回合末空转，PM 已把它停掉。
**你只做"把已完成的活写成可复验的报告"**，不重新实现、不改 `skills/**` 的实现文件。

## 起点（照做）

```sh
cd <你的 worktree>
git fetch . task/M50-digest-89s        # 或 git switch -c task/M50a-report d46fd4e
git switch -c task/M50a-report d46fd4e
git log --oneline main..HEAD           # 看这 6 个提交都做了什么
```

## 报告必须包含（这是唯一的交付物）

`docs/team/reports/M50-dev.md`（文件名沿用 M50 的约定）：

1. **覆盖表**：brief 的 A 段四条（根解析一次 / 进程内扫描 / gitshim 前后数字 / 门禁）逐条对照"做了没有 + 证据在哪"；
2. **前后实测数字**（用你自己的 `gitshim` 探针，最前 PATH 放一个记录 argv 的 `git` 包装；同一条命令在
   **main** 与 **本分支** 各跑一次，贴原始行）：
   - `team board row M48` / `team board ls` 的 **git 调用数 + 墙钟**；
   - **`team digest` 的 git 调用数 + 墙钟**（这是核心指标；PM 侧已量到 1708→37 次、63.5s→3.44s，你要独立复现）；
   - **内容一致性**：两版 digest 输出**逐行对照**（去掉时间戳/RAM 类行后 diff）。**已知并需解释**：
     M50 分支基点早于 M48，因此分支输出少一行「BOARD 有重复 ID …」——这是基点旧，不是回归；
     你只需在报告里写明这一点（PM 会在合并后另跑一次确认该行仍在）；
3. **门禁输出**：`PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` 与 `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh`；
   以及 smoke 第 34 段（`root-resolved-once + single-process scan`）的实际结果行；
4. **未完成项**：明确写清 B 段（派生索引 `board-index.json`、性能门槛断言、doctor 耗时）**未做**，以及原因；
5. **结论**：全交 / PARTIAL —— 由你根据上面几条自己判断并写出来。

## Boundaries

- **不许改** `skills/teamsmith/**` 的任何实现文件（`scripts/**`、`tests/**` 一律不动）；只允许新增/修改
  `docs/team/reports/M50-dev.md` 与 `docs/team/reports/M50-dev/`（证据目录）。
- 不许改 M50 的 brief、不碰 BOARD/DECISIONS（PM 的事）。
- 若你在复现中发现**实现有问题**（不是报告问题）：不要自己修，把证据写进报告并在报告顶部标 `BLOCKED:`，
  然后正常交付通知我。

## Acceptance

```sh
git -C .worktrees/dev2 status --porcelain     # 只应有报告相关改动
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
```

## Report

交付时用 `team notify pm --from-file <摘要文件>`；摘要里写清：报告路径、digest 的 before/after 两个数、结论（全交/PARTIAL）。
