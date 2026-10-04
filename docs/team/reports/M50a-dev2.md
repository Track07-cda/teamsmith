# M50a · M50 的收尾：报告 + 证据（本文件是精简版，全文见 M50-dev.md）

agent: dev2   status: DONE   time: 2026-09-21T02:12:00Z
branch: `task/M50a-m50`（= M50 分支 tip `d46fd4e` ＋ 报告与证据；实现零改动）   PR/MR: -

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/M50-dev.md` | **完整交付报告**（覆盖表 / 前后实测 / 逐行对照 / 门禁 / 未完成项 / 结论） |
| `docs/team/reports/M50-dev/pkg/run.sh` | 独立复现包入口（base/main/after × 同语料；gitshim 计数 + 墙钟 + 逐行对照；可一键重跑） |
| `docs/team/reports/M50-dev/evidence/` | 原始输出：复现包运行全文、git argv 汇总、digest 三份全文与 diff、FAST/full smoke 全文、smoke 34 结果行、openspec 输出 |

## Verification evidence

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 15 passed, 0 failed (15 items)              # rc=0
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 1890  ✗ 0                             # rc=0（报告提交后的 tip）
$ bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2379  ✗ 0                             # rc=0（全量，tip d46fd4e）
$ bash docs/team/reports/M50-dev/pkg/run.sh
== 总结果 == ✓12 ✗0 finding 2（脚本级失败 0）        # rc=0，2026-09-21T02:05Z
```

真语料前后（同一语料、同一台机器、三条实现树用 `git archive` 取出）：

| 命令 | main（旧） | M50 分支 | 
|---|---|---|
| `team board row M48` | 3 次 git / 0.04s | **1 次 / 0.06s** |
| `team board ls` | 3 次 / 1.28s | **1 次 / 0.14s** |
| `team digest` | **1692 次 / 62.55s** | **36 次 / 3.37s** |

语义：M50 分支的 digest 与基点 `5060604`（M50 之前）**逐字节一致**；与 `main` 的差异**只有** 1 行
`!   BOARD 有重复 ID：…`（M48 引入、分支基点旧，非回归）。

## Flip evidence（判据非空转）

```
red   ：main 旧实现 1692 次 > 50 · TEAM_SCAN_CACHE=0（旧形状）1690 次 > 50 · smoke 34 夹具 cache-off 260 次 > 50
green ：M50 缓存开 36 次 ≤ 50（墙钟 3.37s）· smoke 34 夹具 19 次 ≤ 50 · board row 1 次 ≤ 1（旧实现 3 次）
```

## 未完成项与结论

- **B 段未做**（按 PM 重切范围留后续任务）：`state/board-index.json` 派生索引、性能门槛断言
  （digest<5s / panel<1.5s）、doctor 耗时报告；dev 快照里做过的 doctor 块保留在 `b3afe08`。
- **结论：PARTIAL** —— M50 A 段全交且经独立复现验证；B 段按重切范围未做；M50a 的报告交付完成，
  未发现实现问题，无 `BLOCKED:`。

## Decisions and deviations

- 全文写在 `docs/team/reports/M50-dev.md`（brief 指定沿用 M50 约定）；本文件是为了
  `team review M50a` / `team_find_report` 按任务名前缀取报告而写的精简版，结论与全文一致。
- 复现不复用 dev/PM 留在 `/tmp` 的现场；`pkg/run.sh` 自建 shim、`git archive` 取实现树。
