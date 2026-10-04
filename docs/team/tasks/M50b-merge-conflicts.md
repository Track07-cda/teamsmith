# M50b · 把 main 并进 M50 分支并解决冲突（合并结果必须自己跑绿）

```
task:   M50b
agent:  dev2
issue:
change: -
specs:  -
phase:  -
anchor: none (infra) — 只做合并与冲突解决（不改语义）；M50 的性能契约锚点由后续 read-cost-budgets 回填 change 提供
deps:   M50（实现）+ M50a（报告）都在 `task/M50a-m50`（tip ff244b3）
status: todo
budget: 一个工作块（冲突解决 + 在**合并结果**上跑门禁）
```

> 本地模式：不 push。

## 背景：PM 试着合并，撞了三处冲突（都在一起改同一批文件）

`task/M50a-m50` 的基点早于 **P24 / P26 / P27 / P28 / M48 / M51** 的合并，所以 `git merge main` 有 **3 个文件冲突**：

| 文件 | 冲突形状 |
|---|---|
| `skills/teamsmith/scripts/lib/common.sh` | M48 新增 `team_board_duplicate_ids()`（重复 ID 可见性）与 M50 的扫描缓存层在同一片区域；另有一处 `board add --allow-dup` 的审计行 vs `team_scan_invalidate board` |
| `skills/teamsmith/scripts/lib/cmd-review.sh` | P27 的 `queue_marker` 清理 vs M50 的 `team_scan_invalidate review` |
| `skills/teamsmith/tests/smoke.sh` | **段号撞车**：main 已有 `34·门禁锁`（P26/G1）、`35·性能前提`、`36·panel-cpu`，M50 的 `34·读路径性能` 必须**改名 37**；且它的收尾 `fi` 与 main 的 `if/else` 共用了一行，别丢 |

**PM 的失败尝试**（别重犯）：把两侧原文直接拼接 → `bash -n` 立刻报"unexpected end of file from `{`/`if`"
（共享的收尾行只能属于一侧）。请**按语义**合并，而不是按行拼接。

## 要求

1. `git switch task/M50a-m50`（或从它切 `task/M50b-merge`）→ `git merge main`；
2. 解决三处冲突，**两侧语义都要保留**：M48 的重复 ID 可见性 + P27 的排队记账 + M50 的扫描缓存/失效调用；
   smoke 里 M50 的段号改 **37**，并确保它自己的 `fi` 收尾存在（`bash -n` 必须过）；
3. **在合并结果上**跑门禁（这是唯一有效的验收对象）：
   `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null`；
4. **必须单独证明这三条没被吃掉**（贴原始输出）：
   - `team digest` 里仍有一行 `!   BOARD 有重复 ID：…`（M48）；
   - `team review` 的记录/日志里仍有排队记账（P27：`排队 …s；实际运行 …s` 或 `queued/ran`）；
   - M50 的性能数字在**合并后**仍然成立（`digest` 的 git 调用 ≤ 50、`board row` ≤ 1；用你的 gitshim 探针）；
5. **解释或修好 12b-pi 的那 5 条红**：M50a 的复验（在**旧基点**上跑）报了
   `12b-pi …（piw-harness.log 中找不到 …）`、`TEAM-IW-CASE FAIL S12/S13`（`seen=0`、`total … 0 -> 0`）。
   合进 main（含 P28/M51 的 inbox-watch 修正）后**要么变绿**，要么给出证据说明真因；
   不许把它当"已知问题"放过 —— 它出现在我要盖章的交付上。

## Boundaries

- 只允许改动：冲突解决所需的上述三个文件 + 你的分支元数据 + 报告；
  **不要**顺手重构、不要改 M50 的算法语义（缓存层的行为必须与 M50a 一致）。
- 不改 `docs/team/DECISIONS.md`、不改别人的 brief、不 push。
- 若冲突涉及你判断不了的两侧语义，**停下来在报告里写 `BLOCKED:` 并点名文件与行**，由 PM 裁决。

## Acceptance / Report

`docs/team/reports/M50b-dev2.md`：三处冲突各自的解决方式（贴解决后的关键行）、合并结果的**全量门禁原始结果行**、
上面第 4 条的三个证据、第 5 条的结论（绿了 / 根因 + 证据）、以及合并后 git 调用数。
