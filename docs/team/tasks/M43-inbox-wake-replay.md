# M43 · inbox 唤醒重放：42 条「新消息」被投递两次（通知通道保真）

```
task:   M43
agent:  dev
issue:  
change: -
specs:  -
phase:  -
deps:   -            # 与 M40/P20 不重叠（那些动 identity/panel；本任务动 extension/team-inbox-watch.ts）
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev`。

## 现象（PM 实录，2026-09-19T16:59Z）

PM 在 6 秒内收到**两条一模一样的唤醒**：「42 new team message(s)」+ 同一份 42 行列表 +「… and 37 more」。
但 PM 的 durable 收件箱当时**只有 1 条真新增**（M40 的交付 knock，游标 17→18），投递器日志也确认。

证据（全部在仓库里可复核）：

```
$ grep -n "n=42" .pi/team/state/inbox-watch.log
118:2026-09-19T16:59:43.940Z wake n=42 total=52 inbox=pm kinds=nudge,nudge,knock,knock,knock,nudge,knock,nudge,nudge,nud…
119:2026-09-19T16:59:49.945Z wake n=42 total=94 inbox=pm kinds=nudge,nudge,knock,knock,knock,nudge,knock,nudge,nudge,nud…
120:2026-09-19T16:59:55.250Z wake n=1  total=95 inbox=pm kinds=knock
$ f=.pi/team/state/inbox-watch/teamsmith_pm-*.wake; wc -l < $f        # → 43 行（首行 1789735731784 ≈ 13:15Z）
$ ls -l $f                                                            # → 13087 字节，远低于 128KiB 上限
```

要点：同一份 42 行在 6 秒内被读了两次（`seen` 52→94 每次 +42），随后又只报 1 条 —— 说明 offset 被重置过，
且重置后**重放了整个 spool**，而不是「把还没投过的尾部再叫一次」。

## 需要你查的（嫌疑点已在代码里点名，别只看现象）

1. `readNewLines()`（extension/team-inbox-watch.ts:177-198）：`size < offset → offset = 0` 是**重放**入口；
   **什么事件让 size 变小**？spool 是追加写（`outbox.sh:761` 用 `>>`），`trimSpool()`（:209-231）只在
   `size > maxBytes()（默认 128KiB）` 时才裁剪 —— 13KB 的文件不该触发。请实证（不是推断）是哪条路径。
2. `flush()`（:313-321）里 `trimSpool` 之后 `offset = trimmed`；`reset`/重注册路径（:368 `baselineOffset`、
   :391 `offset = 0`）分别什么时候跑？有没有可能在同一会话内**跑两次**（例如扩展重载 / 双实例 / 重新注册）？
3. 若确认是「无法避免的重放」（例如外部工具重写了该文件），**修法必须是**：
   把「重放」变成**有界且可解释**的行为 —— 例如 offset 用**持久化 + 行内单调序号**而不是纯字节偏移、
   或重放时只投递**最近 N 条**并在文本里说明「已跳过更早的 M 条」，且**不得重复投递同一条**
   （同一条 = 同一 `(epoch_ms, kind, from, preview)` 元组）。
4. **计数器语义**：`seen`（ledger 的 `total=`）与唤醒文本里的 `N` 必须与「真实新增」一致；
   重放/跳过都必须写进 ledger 一行（可审计），不能让 `total` 被重放灌水。

## Deliverables

- 根因（用实测证据写清：哪条路径、什么条件下触发；能复现的给出最小复现脚本）
- 修复：重放有界 + 去重（同一元组不重复叫）+ 计数与文本一致 + ledger 记录跳过/重放
- smoke/extension 测试：**同一元组重复出现只叫一次**、**spool 被截断（变短）时不重放超过 N 条**、
  `total` 只随真实新增增长；每条都要有翻转（破坏实现 → 断言红）
- 文档：`references/troubleshooting.md` 或 `references/agent-adapters.md` 里补一段「投递语义：offset/重放/上限」

## Boundaries

- 只动 `skills/teamsmith/extension/team-inbox-watch.ts` + 对应测试/文档；**不要**改 durable 收件箱格式、
  outbox 守卫、`team notify` 契约（M17/M24/M30/M40 的语义保持）。
- 别碰 `.worktrees/dev3`（M40 正在被复验）与 `.worktrees/dev2`（P20 在飞）；`smoke.sh` 只追加自己的段落。
- 测试纪律：私有 tmux socket / 破坏性夹具进容器；不要用绝对路径调 tmux。

## Acceptance (must actually be run)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 最小复现（你的修法必须让它不再重放）：构造 spool 被截断/重写的场景，观察唤醒与 ledger 计数
```

## Report

`docs/team/reports/M43-dev.md`。
