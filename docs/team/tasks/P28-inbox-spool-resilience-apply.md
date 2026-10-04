# P28 · 收件箱投递韧性（apply）

```
task:   P28
agent:  dev2
issue:
change: inbox-spool-resilience           # 提案已验收并合并：docs/team/reviews/inbox-spool-resilience-proposal.md
specs:  notify-and-inbox#The wake reader's offset advances by the bytes it read, never past the file end / notify-and-inbox#A size regression is repaired or rescanned only with evidence, and recovery converges / notify-and-inbox#Only fresh lines wake the session; stale lines stay silent and countable / notify-and-inbox#The ledger separates new traffic from recovery
phase:  apply
anchor: change
deltas: openspec/changes/inbox-spool-resilience/specs/notify-and-inbox/spec.md
deps:   P25（propose，已合并）
status: todo
budget: 分批 B1…B5 + B6；做不完交 PARTIAL + 已完成批次清单
```

> 本地模式：不 push；分支留在 `.worktrees/dev2`。
> **本任务用新会话启动**（旧会话超窗）：开场先读 `openspec/changes/inbox-spool-resilience/{design.md,tasks.md}`——
> 那是本 change 的设计与实施计划（你自己上一轮写的），**不要重推设计**，直接照它实现。**计划就是 change 的 tasks.md（B1…B5）**，本任务书补 B6 与边界。

## B6（PM 新增，范围很小，别让它吃掉主轴）

把**生产者**也修掉：`scripts/lib/outbox.sh:1017` 的 `LC_ALL=C cut -c1-700` 是**按字节**裁切，
会把多字节字符截半 → 写进 spool 的行**不是合法 UTF-8**（这正是这次事故的触发器）。

- 实现：改成按**字符**裁切（例如先取进变量再用 bash 的 `${var:0:700}`；或任何在本机 `LC_ALL=C` 下也成立的写法），
  并**不要**顺手改三条发送路径（`say`/`notify`/`draft`）的其它逻辑；
- 新增 delta：`notify-and-inbox` 再加一条 requirement —— **本写入者追加的 spool 行必须是合法 UTF-8**，
  且 `LC_ALL=C` 环境下同样成立（scenario：多字节字符恰好跨 700 字节边界 → 行仍是合法 UTF-8，且**不**出现 U+FFFD 替换符）；
- 断言写在 smoke 的对应段里（红→绿：改回 `cut -c` 即红）；
- **如果**你发现它必须牵动三条发送路径的共性逻辑，**报 PARTIAL 交回来**，不要为 B6 破坏 B1–B5。

## PM 的两条审查要点（硬要求）

1. **R2 的收敛记忆**：头部指纹与"同一 `(size, head)` 不重扫两次"的记忆若是持久化，只能落在 `state/inbox-watch/`，
   **不得**变成第二份真源（真源仍是 spool 文件本身）；若只放进程内，要在报告里说明重启后的行为与理由。
2. **R3 的新鲜度**必须用 spool 行自带的 `team_epoch_ms` 字段判定，**不许**用文件 mtime、也不许用 `.seen` 里的顺序。

## Boundaries

- 只碰 `extension/team-inbox-watch.ts`（读者）、`scripts/lib/outbox.sh` 的**预览裁切那一处**（生产者）、
  以及 `tests/smoke.sh` / 对应夹具（追加段落，别重排他人段落）。
- 不改唤醒通道（`fs.watch` + `sendMessage`）、不改 outbox 的投递语义、不改 `.seen` 的格式与上限、不改 durable 收件箱格式。
- 不碰 M48（dev3，看板/面板聚焦）、M50（dev，digest 读路径）、P27（verify，门禁资源纪律）正在改的区域。
- 任何"恢复"路径都必须**可审计**：账本行要能一眼区分"修复/重扫/投递"三种结局。

## Acceptance (真跑，贴原始输出)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
```
外加**手工实录**（按 tasks.md 的 S18–S20 与 B6 的新场景）：
① 字节裁切的行（含跨边界多字节字符）→ 基线不再越界、不重扫、不唤醒；
② 末字节被删（头部不变）→ **一次修复**，不重扫；头部变化 → 一次有界重扫并收敛；同一 `(size,head)` 第二次不重扫；
③ 一小时前的未投递行 → 计入 `stale=`、写 durable、**不唤醒**；紧跟一条新行 → 仍只唤醒一次；
④ `total` 只随真新增增长（三种重扫场景各验一次）；
⑤ B6：`LC_ALL=C` 下裁切多字节预览 → 行仍是合法 UTF-8（`od`/`iconv -f utf-8 -t utf-8` 验证）。

## Report

`docs/team/reports/P28-dev2.md`：per requirement 覆盖表 + 每批翻转（红→绿）+ 独立包路径 + 你**实测**的账本行样本
（改造前后各一份，证明循环与过期唤醒都不再发生）。
