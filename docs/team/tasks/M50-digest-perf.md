# M50 · 读操作的 O(文件) × 子进程扇出：`team digest` 89 秒（实测）

```
task:   M50
agent:  dev
issue:  
change: -
specs:  -
phase:  -
deps:   -
status: todo
budget: 一个工作块
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev`。

## 实测（PM 在 main 上量的，复现命令写在下面）

```
$ wc -lc docs/team/BOARD.md            → 141 行 / 13808 字节      # 台账本身极小
$ du -sh docs/team/reports docs/team/reviews → 16M / 13M          # 证据语料 29M、约 400 个 md
$ time team board ls                    → 1.25s
$ time team digest                      → 88.8s   ← 痛点
$ time team __panel-data                → 3.22s
$ time team board row M48               → 94ms，期间 git 调用 5 次（全是 rev-parse）
# 用 PATH 里的 git 包装器数调用：
$ team digest → git 调用 1620 次，其中 rev-parse 1523 次、for-each-ref 80 次
```

**根因**：不是 markdown 慢，而是**每次辅助调用都重新解析仓库根（~5 次 `git rev-parse`，~94ms）**，
而 digest 对每个报告/复验记录（约 300+ 份）各起一个 `team` 子进程 → 约 1500 次 rev-parse → 89 秒。
`for-each-ref` 80 次也在同一族（每个子进程各列一次 refs）。

## Deliverables

1. **一次解析**：`team` 启动时的仓库根解析从「5 次 rev-parse」降到**名副其实的 1 次**（或从
   `$PWD` 上溯 + `.pi/team/config.sh` 推导，git 只在必要时兜底），且同一进程内**缓存**（供 lib 反复问）。
   判据：`team board row <ID>` 的 git 调用数 ≤ 1（现在是 5），并给它一条断言。
2. **消灭逐文件的子进程扇出**：digest / status / 面板数据**不再**「每个报告/记录起一个 `team`」——
   在**单个进程**内完成扫描（内部函数调用，不是子进程）。
   判据：`team digest` 的 `git` 调用数从 1620 降到 **≤ 50**（一条断言），且报告/复验的判定逻辑**逐条不变**
   （用既有 fixture 对照旧实现的输出，逐字节或逐字段比对）。
3. **派生索引（可选但推荐）**：`state/board-index.json`（ID → 状态/agent/报告文件/复验判定/是否已并入），
   只在 HEAD 或相关文件 mtime 变化时重建；digest 与面板优先读它。
   **硬约束：索引是派生物，不是第二真源** —— 一条测试断言「索引 == 直接解析 BOARD + 文件扫描」的结果。
4. **性能门槛写进守卫**：给 digest 与 `__panel-data` 设一条**本机可测**的墙钟上限断言
   （例如 digest < 5s、panel-data < 1.5s，在 CI/容器里可放宽但必须有值），并在 doctor 里报告当前耗时，
   让「慢」是**可见**的而不是靠体感。
5. **报告**：给出改造前后的实测（git 调用数 + 墙钟）、以及你为了不变语而做的对照证据。

## Boundaries

- **不改**任何判定语义（状态枚举、复验判定、待收尾规则、报告/记录的发现规则一个字不变）。
- 不引入常驻进程、不引入数据库；索引必须是纯派生 + 可验证（人类仍可 `grep` 全部 md）。
- 别碰 M47（CI 可移植性）、M48（重复 ID 聚焦）、M49（设置键 i18n）动过的区域；
  `smoke.sh` 只追加自己的段落，别重排。
- 测试纪律照旧（私有 tmux socket、破坏性调用进容器）。

## Acceptance (must actually be run)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 复现基线与改造后对照（把两条都贴进报告）：
#   PATH=/tmp/gitshim:$PATH bash skills/teamsmith/scripts/team digest    # 数 git 调用
#   /usr/bin/time -f '%e' bash skills/teamsmith/scripts/team digest
```

## Report

`docs/team/reports/M50-dev.md`。

## 中断与续跑说明（PM 追加，2026-09-20 12:0x）

**你在 09:55 的 tmux 会话重建里被中断**，且旧会话已超模型窗口（无法复用）——本次用**新会话**续跑。
工作全部在磁盘上，先做三件事再动手：

1. `git status --porcelain` 看未提交改动（当前：`M skills/teamsmith/scripts/lib/cmd-status.sh`、`M skills/teamsmith/scripts/lib/common.sh`，约 472 行增量）；
2. `git diff` 读它们，确认已做到哪一步（根解析一次 + 进程内扫描的雏形）；
3. **接着做完**，不要重做已完成部分。

注意（新守卫）：M50 的 brief 早于 D31（`change: -` 且无锚点），PM 已用 `--force` + 审计行放行；
锚点会在后续的 `read-cost-budgets` 回填 change 里补，**你不必**改本文件的头字段。

## 重切范围（PM 决定，2026-09-20T17:0x）——**只做 A，B 留给后续任务**

**背景**：dev 的上一轮（新会话）空转约 2 小时、0 提交；PM 已停掉它，并把它工作树里的
**836 行改动原样提交**为 `wip(M50)`（`b3afe08`，六个文件 `bash -n` 全过，PM 未改动内容）。
你**接着这个提交往下做**，不要重推演它已经做了的事。

**A（本次必交，做完就交）**
1. `git show --stat b3afe08` + `git show b3afe08 -- <关键文件>` 先读懂它做了什么；
2. 补齐并**验证**这条主修：**仓库根一次解析 + 进程内缓存**（`team board row` 的 git 调用 ≤ 1）
   与 **digest/status/panel-data 单进程扫描**（`team digest` 的 git 调用 ≤ 50，且逐字段与直接解析对照一致）；
3. 用 `gitshim`（最前 PATH 放一个记录 argv 的 `git` 包装）数**改造前/后**的 git 调用次数，两个墙钟数一起写进报告；
4. 按逻辑拆 **2–3 个小提交**（先提交再继续；中断不丢工作）；
5. 门禁：`openspec validate --all --strict` + `TEAM_SMOKE_FAST=1 smoke` ＋ 相关段落的全量 smoke（如果时间允许）。

**B（本次不做，别开）**：`state/board-index.json` 派生索引、性能门槛断言（digest<5s / panel-data<1.5s）、
doctor 报告耗时 —— 留作下一个任务（我另立 ID）。**若你早于 50% 上下文完成 A，把 A 交掉即可**，
不要顺手把 B 也做了再一起交。
