# P25 · 收件箱投递：假缩容、重扫与过期唤醒（propose）

```
task:   P25
agent:  dev2
issue:
change: inbox-spool-resilience
specs:  -
phase:  propose
anchor: change
deltas: openspec/changes/inbox-spool-resilience/specs/notify-and-inbox/spec.md
deps:   -
status: todo
budget: 一个工作块（只出提案包：proposal / design / delta / tasks.md）
```

> 本地模式：不 push；任务分支留在 `.worktrees/dev2`。**只 propose，不写实现。**

## 事故现场（2026-09-20 06:42–06:44，全部有账本可查）

PM 的收件箱 watcher 在 06:42:39 settle 时把基线算成 **19635**，而 spool 实际 **19634** 字节：

```
06:42:39 started target=teamsmith:pm inbox=pm spool=…/teamsmith_pm-d59ea631.wake baseline=19635
06:42:44 wake n=20 total=20 … rescan[dup=…]      ← 66 行被当成「从未投递」，分四批投递
06:42:59 wake n=6  total=66 … rescan[dup=60 skipped=0]
06:43:14 spool shrink: size fell below offset=19635 → bounded rescan from 0
06:43:19 spool shrink: … → rescan lines=66 dup=66 deliver=0      ← 每 5 秒一次，永不收敛
06:44:16 spool shrink: … → rescan lines=0 dup=0 deliver=0        ← PM 手工清空 spool 才停
```

现场文件：`.pi/team/state/inbox-watch.log`（第 171–224 行）、`state/inbox-watch/<key>.{wake,seen,reg}`、
`skills/teamsmith/extension/team-inbox-watch.ts`。

**PM 的初步判断（你要自己复核，不要照抄）**：`readNewLines()` 的 offset 是按**缓冲区长度**推进的，
不是按 `readSync` **实际读到的字节数** —— 只要 `statSync` 与 `readSync` 之间有写入方动过文件，
offset 就可能**越过文件末尾**（19635 > 19634）；而 `flush()` 的缩容规则（`size < offset` ⇒ 外部重写 ⇒ 重扫）
**不夹 offset、也不收敛**，于是永久误判；重扫路径又把「去重记忆（`.seen`）里没有的行」当新行投递
（记忆默认上限 512 条，且跨重启由 `.seen` 恢复）——这就是四批过期唤醒的来源。

## 要提案化的不变量（每条 requirement + 可证伪 scenario）

1. **offset 永不越过 size**：基线计算与每拍推进之后都必须 `offset ≤ size`（按实际读到的字节数推进，
   不按缓冲区长度）；`offset > size` 这种状态在实现里不存在。
2. **重扫必须收敛**：任何一次重扫结束时 offset 必须等于当前文件末尾；对同一份文件连续重扫必须
   **幂等**（第二拍不得再判一次缩容、不得再投一次）。
3. **缩容要有证据**：1 字节的差值**不构成**"被截断/重写"；只有大小明显回退（或头部指纹变化）才触发重扫。
   给出判据的**具体形式**（阈值/指纹/两者）与理由。
4. **过期行不唤醒**：重扫发现的"从未投递"行若早于 N 分钟（默认 15，可配），只写进 durable 收件箱
   （`docs/team/inbox/<agent>.md`，保证连续性），**不触发唤醒**；唤醒只用于新鲜行。
5. **账本说真话**：`total` 只随真新增增长；重扫/去重/跳过的行数**分列记录**，
   让"20 条旧消息把我叫醒"这种形状在账本上一眼可辨（并说明 `wake n=` 的语义是否要随之改）。
6. **可复现的夹具**（design 给出形状，apply 实现）：① spool 大小比 offset 少 1 字节 → **不得**重扫、**不得**唤醒；
   ② 文件真被重写（头部变了）→ 有界重扫 + 全程去重；③ 重扫遇到 >15 分钟的行 → 写 durable、**不唤醒**；
   ④ 连续三拍对同一文件 → 只有第一拍可能投递。

## 顺带请你在 design 里裁决

- **规格的家**：`notify-and-inbox`（现有 6 条 requirement）里 ADDED 还是 MODIFIED？给理由；
  注意 P27（backfill）之后也会写同一份文件，**本 change 的 delta 要能被后续增量叠加**（别大段重写现有 requirement）。
- **与 M43/M46 已落地规则的关系**：M43 的不重放、M46 的降级可见已经在 smoke 里有断言；
  本 change 的文本必须与那些断言**一致**（别写比断言更强的承诺），并指出哪些断言需要新增（红→绿）。
- **不做的**：不改唤醒通道（inbox-watch 的 fs.watch + `sendMessage`）、不改 outbox 的写入路径、
  不改 `.seen` 的持久化形式（除非有证据表明它是根因之一，那就写进 proposal 的 Impact）。

## Deliverables

- `openspec/changes/inbox-spool-resilience/{proposal.md,design.md,tasks.md}`
- `.../specs/notify-and-inbox/spec.md`（delta，明确 ADDED/MODIFIED）
- 报告 `docs/team/reports/P25-dev2.md`（含：你复核后的根因链，哪一条与 PM 的判断不同及证据）

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict    # 必须全绿
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain                                          # 干净
```

## Boundaries

- 不改 `skills/teamsmith/extension/**`、`scripts/**`、`tests/**`（那是 apply 阶段）。
- 不碰 `docs/team/DECISIONS.md`；不 push；不 merge。
- 与在飞任务不重叠：M48（dev3，看板/面板）· M50（dev，读性能）· P24（dev-bob，change 纪律）。
