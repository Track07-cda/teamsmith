# M52 · inotify 配额耗尽：让"快速唤醒"的失效**可见、可降级、被测出来**（propose）

```
task:   M52
agent:  verify
issue:
change: watch-degradation
specs:  -
phase:  propose
anchor: change
deltas: notify-and-inbox, watchdog, panel
deps:   -
status: todo
budget: 一个工作块（只出提案包：proposal / design / delta / tasks.md）
```

> 本地模式：不 push。**只 propose**。

## 事故（2026-09-21，PM 与 M50b 双方独立复现）

**症状**：smoke 的 `12b-pi` 扩展夹具 6 条红（`fs.watch` 唤醒全不成立、`TEAM-IW-CASE FAIL S12/S13 :: seen=0`），
最初被误判为 M50 合并回归 —— 实际是**宿主机的 inotify watch 配额被耗尽**：

```
$ cat /proc/sys/fs/inotify/max_user_watches      → 65536
$ 宿主机按进程统计 inotify watch（PM 实测）
   64737  /bin/syncthing
     106  /app/share/codium/com.vscode…
   …合计 ≈ 65312–65361 / 65536        ← 只剩 ~200 条余量
$ node -e 'require("fs").watch("/tmp/x",()=>{})'  → 失败：ENOSPC（PM 实测）
```

**为什么这件事重要（不是测试小问题）**：我们的**快速唤醒通道就是 `fs.watch`**（`team-inbox-watch.ts`）。
配额耗尽时，**新起的 PM / worker 进程注册不了 watcher** → 只能靠巡检的 15 分钟兜底 → 用户看到的就是
**"消息没有自动发出来 / 不唤醒"**（正是历史上反复出现的症状族）。已注册的旧进程（例如当前 PM）不受影响 ——
这解释了"为什么有的会话能收到、有的收不到"。

## 要提案化的内容（每条 requirement + 可证伪 scenario）

1. **降级必须可见且带原因**：`fs.watch` 注册失败（`ENOSPC` 等）时，扩展必须写一行明确日志
   （含 errno 与当时的**配额用量**，如"watches 65312/65536"），不得静默；`team doctor` 也要能报出这条状态。
2. **降级后必须有兜底投递**：`fs.watch` 不可用时，唤醒通道必须落到**轮询**（或等价机制）并**在账本里记明**
   （"polling fallback"），且**投递仍然发生**（可以慢，但不能不投）；给出可证伪的夹具：
   人为让 `fs.watch` 失败 → 新的 spool 行仍在 N 秒内投递一次唤醒，且账本写明走的是兜底。
3. **测试要能分辨"环境配额耗尽"与"代码坏了"**：`12b-pi` 的 fs.watch 专用用例在**配额不足**时必须
   **可见 SKIP（打印实测用量 + 原因）**，而不是判红；同时保留**严格模式**（夹具旋钮 / CI 环境）
   继续真正测 fs.watch 路径；不许把断言改成"永远不红"。
4. **`team doctor` 增加 inotify 余量一行**：读 `/proc/sys/fs/inotify/max_user_watches` 与**本用户当前用量**
   （能读就报数；读不到就说明读不到），余量低于阈值（例如 <1024）时给**警告 + 修法**
   （`fs.inotify.max_user_watches` 提到 524288；Syncthing/VSCode 是常见占用者）。
5. **文档**：`references/troubleshooting.md` 增加一节"消息不唤醒/唤醒变慢"的排查顺序：
   先看扩展日志的 `watch unavailable`，再看 doctor 的 inotify 余量，最后才是代码问题。

## design 要顺带裁决

- **规格的家**：唤醒通道的语义在 `notify-and-inbox`（已 6 条 requirement）、巡检职责在 `watchdog`、
  降级可见性在 `delivery-guard` —— 给出 ADdED/MODIFIED 的具体落点与理由（不许大段重写既有 requirement）；
- **与 P28/M46 既有规则的关系**：M46 已要求"skip 要可见"、P28 已实现 `stale/unparsable` 记账；
  本 change 只补"**watcher 不可用**"这一类，文本不得与之冲突或重复；
- **不要做的事**：不改默认轮询周期、不改唤醒消息格式、不动 outbox/投递守卫、不改 `standby` 语义。

## Deliverables

- `openspec/changes/watch-degradation/{proposal.md,design.md,tasks.md}`
- `.../specs/<capability>/spec.md`（delta，明确 ADDED/MODIFIED）
- 报告 `docs/team/reports/M52-verify.md`

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```

## Boundaries

- 只 propose：不改 `extension/**`、`scripts/**`、`tests/**`（apply 阶段）。
- **不许**在提案里做"提高系统配额"这种需要特权的动作（那是用户/运维的动作，写进文档即可）。
