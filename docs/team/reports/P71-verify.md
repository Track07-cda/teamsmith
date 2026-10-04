# P71 · inbox 唤醒重复投递 · `wake-delivery-idempotence`（propose）— 交付报告

agent: verify   status: delivered（propose 完成，等 PM 提案审查；本阶段不写实现）
time: 2026-09-22T19:55Z
branch: `task/P71-propose`（local 模式：分支留在 `.worktrees/verify`，不 push）   PR/MR: -
change: `wake-delivery-idempotence`（phase=propose，owner=verify；deltas=`notify-and-inbox`）
brief: `docs/team/tasks/P71-inbox-wake-idempotent.md`
tip: `aa9001b0` 为本报告的父提交（`9dacaf4e` delta → `ced1c02b` design → `381b2860` proposal+tasks → `aa9001b0` 取证包 → 本报告）

## Deliverables

| Path | 内容 |
|---|---|
| `openspec/changes/wake-delivery-idempotence/specs/notify-and-inbox/spec.md` | delta：**3 条 ADDED** —— ① *A wake is at most once: the delivery record is written before the send and survives a restart*（append-only journal `start/read/intent/sent/failed/floor`、写前记录、三态重启判定、`recovery`、`unprovable`）；② *A wake names its source line so a recipient can prove what it is*（`#seq` + 绝对源时间 + identity + 发送方记录的 id）；③ *The delivery journal is the only dedup memory, and it is bounded and auditable*（一条一记录、torn tail = 未知、`TEAM_INBOX_WATCH_JOURNAL_MAX` 压实 + `floor=`、`.seen` 一次性导入后退役）。**2 条 MODIFIED**（全文重述）—— *Only fresh lines wake…*（paths 增补 journal recovery + 过期恢复行只计数）、*The ledger separates new traffic from recovery*（新增 `replay suppressed` / `inflight assumed` / `recovery` / `unprovable` / `deliver blocked` / `torn tail` / `baseline swallowed`，每条 wake 带 `seq=` 与 identity） |
| `openspec/changes/wake-delivery-idempotence/design.md` | 事故逐条取证（真实 id 与账本行）、两条推断的证伪、四个真洞、决策 D1–D7（含「至多一次的门铃 / 恰好一次的消息」论证、journal 格式、三态算法、基线口径不变的取舍、`deliverAs` 保持 followUp 的残余）、夹具方案 S25a–S26（子进程崩溃跑法）、残余清单 |
| `openspec/changes/wake-delivery-idempotence/proposal.md` | 提案：Why / What Changes / Capabilities（唯一另一个 open 的 `notify-and-inbox` delta 动的是另一条 requirement，可组合）/ Impact / Acceptance / the flip / Boundaries / 报告证据清单 |
| `openspec/changes/wake-delivery-idempotence/tasks.md` | 一个 apply brief（B1 journal 与写前顺序 → B2 身份进文本与 spool 行 → B3 三态重启与恢复 → B4 账本/压实/`.seen` 退役 → B5 事故重放与门禁）+ 覆盖表 + 路径授权 + 夹具纪律 + 四条 break-it 变异 + 一个独立 verify brief |
| `docs/team/reports/P71-verify/pkg/{lib.sh,10-forensics.sh,run.sh}`、`logs/10-forensics.log` | 只读取证包：报告里每个数字都能重算（不开 tmux、不跑 pi、不写 state） |

## 验收命令（真跑）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
...（29 项逐条 ✓）
✓ change/wake-delivery-idempotence
✓ spec/notify-and-inbox
Totals: 29 passed, 0 failed (29 items)          # exit 0

$ PATH="$HOME/.bun/bin:$PATH" openspec validate wake-delivery-idempotence --strict
Change 'wake-delivery-idempotence' is valid      # exit 0

$ bash docs/team/reports/P71-verify/pkg/run.sh   # 只读取证（日志：logs/10-forensics.log）
== 10 结果 == ✓35 ✗0 · findings=0 · skip=0
== run 结果 == all-sections-exit-0               # exit 0

$ git status --porcelain
（本报告提交前：干净；见 tip 下方的提交序列）
```

`proposal.md` 里列的 apply 期验收（harness / `flip-p71.sh` / FAST+全量门禁）**本阶段不存在实现，故未跑**，已在任务书 5.x 逐条写成 verify 命令。

## 事故取证：三个现场分别是什么

> 每条都能用 `bash docs/team/reports/P71-verify/pkg/run.sh` 重算；下面括号里是包内断言。

**① dev2 报的「14:09 那条重复投递」。** 账本对那条 identity（`1790086196029`）**只有一次**发送
（`2026-09-22T14:09:56.190Z wake n=1 total=4 inbox=dev2 kinds=say`），14:09:56.190 之后 dev2 的
`wake` 行数为 **0**，`.seen` 里有它，spool 里也只有一份，durable 收件箱 `docs/team/inbox/dev2.md:82`
只有一份。→ **第二次呈现不是 watcher 的发送路径**（可判：watcher 每次 `wake()` 都先写账本）。
同一对文件里真正的洞是另一个：`.wake` 9 行 / `.seen` 8 行，缺的正好是**最老那条已投递行**
（`1789810336525`，09-19T09:32:16.682Z 投过一次）——**去重记忆并不是投递的完整记录**，900s 内发生外部重写就会再叫一次。

**② PM 的「同一条旧 nudge 两次 / 截断后还在重放」。** 备份 spool（76100 B / 247 行）里三条 nudge 是
**三个不同的 id**：`1790093637236`（16:13:56Z）、`1790094537381`（16:28:56Z）文本逐字相同
（`nudges.log` 里 `未读通知 7 · 待复验 4` 恰好两条），`1790095437514`（16:43:56Z，`9 · 4`）；每条在 spool 里
各出现一次，账本对 16:13/16:28/16:43 各只有一次 nudge 唤醒（`total=85/86/89`），**16:43:57.763 到 19:45:38.901
之间没有任何 `kinds=nudge` 唤醒**。17:46:49 的截断恢复是 `rescan lines=0 … deliver=0`；截断后 spool 的 8 条
id 每条都在 ±2s 内对应一条唤醒。→ 三次「重现」是那三次**已发送**的 `followUp` 在 PM 长回合的回合边界被
依次呈现；不是重放、也不是偏移没落盘。

**③ `total=1`（14:33:07 inbox=dev）。** `total` 是**该会话**累计唤醒行数（不是 spool 行数）；那条被唤醒的是
`docs/team/inbox/dev.md:82` 的 `14:33:07Z [say] P55 提醒…`（新鲜、追加即投），该 dev 会话 `started … baseline=1958`
在 11:46:36.930，14:33:07 之前 dev 没有第二次启动；日志里紧邻它的 `14:32:59.391/.414` 是 **dev3** 的启动行
（同一账本混排所有 target）。→ 标签没错、没有从头读过 spool。

## 两条推断的证伪（brief 要求「证实/证伪」）

1. **「唤醒路径读完 spool 后没把偏移持久化 → 同一条旧行每一轮都被重新读出并投递，`.seen` 不被咨询」——证伪。**
   偏移在内存里且每次读都推进；若真的每轮重读并投递，每轮都会留下一条 `wake` 行；被 `.seen` 挡住会留下
   `dedup:` 行。16:43 之后两者都没有；`.seen` 里三条 nudge 都在（PM 自己 grep 到 3 条，正是三个不同 id）。
   （包内断言：16:43:58–19:45:38 之间 nudge 唤醒数 = 0。）
2. **「`total=1` 说明某 spool 被从头读了一遍 / 标签写错」——证伪**（见 ③）。`total` 的语义在代码里是
   `seen += lines.length` 的会话计数，`inbox=dev` 是该 watcher 自己的收件箱名。

## 真正破的地方（提案收口的两侧）

- **写前/写后方向**：`wake()` 的顺序是 `markDelivered(lines)` → `appendLedger('wake …')` → `pi.sendMessage(...) catch {}`。
  于是「账本说 wake + `.seen` 说投过」只证明**试过**；`pi.sendMessage` 抛异常被吞（Pi 的
  `pi.sendMessage(message, options?)` 返回 void，没有 ack/取消 API）→ 静默丢一次唤醒；反向，`.seen` 的
  tmp+rename 写失败也被吞 → 投了没记 → 重写即重放。两个方向今天都无法从落盘文件判读。
- **身份缺失**：唤醒文本没有行 id、没有源时间、没有序号 → 迟到的队列副本与「又发了一次」不可区分，
  两条文本相同的行不可区分（PM 的 16:13/16:28 就是生产形状）。

提案对这两侧的收口：**至多一次的门铃 + 恰好一次的消息**（D1）、append-only delivery journal 写前记录
（D2）、三态重启判定与 `recovery`（D3）、基线口径不动但把吞掉的行**计数**出来（D4）、身份/绝对源时间/`#seq`
进唤醒文本（D5）、发送方把 `delivered.log` 的条目 id 写进 spool 行（D6）、`deliverAs` 保持 `followUp` 并把
「迟到呈现」写成有据可查的残余（D7）。

## brief 的问题 → 提案的位置

| brief 项 | 落在哪 |
|---|---|
| ① 先记后备 vs in-flight+三态（要论证） | design D1+D2+D3：两者在这里合流成「至多一次」；选三态是因为它还能恢复「确实没开始发」的那一态，且 torn tail 保守判为未知 |
| ② 账本要能看出重放 | MODIFIED *The ledger separates new traffic from recovery*：`replay suppressed`/`inflight assumed`/`recovery`/`unprovable`/`deliver blocked`/`torn tail`/`baseline swallowed` + `seq=` |
| ③ 收件方要能自证 | ADDED *A wake names its source line…*：`#seq` + 绝对源时间 + identity（发送方 id ↔ `state/outbox/delivered.log`）+ 唤醒文本点名 journal 文件 |
| ④ `total=1` 的日志 | 已证伪（上面 ③/证伪 2），无缺陷 |
| ⑤ 可证伪夹具（杀进程→重启不重放；新消息仍唤醒；SIGKILL 不重放旧行） | tasks 3.1–3.4（子进程崩溃跑法 + S25a/S25b/S25e）、2.3（同文本两行）、1.4（过期恢复行只计数） |
| 追加一（更旧行只进 durable、绝不唤醒） | MODIFIED *Only fresh lines…* 把 journal recovery 列入 paths + 新增 scenario「A recovered line that has gone stale is counted, not woken」 |
| 追加二（② 偏移持久化与投递原子化/可自愈、③ 旧行不唤醒、④ 账本区分重放） | D2（写前 intent、`deliver blocked`）/ D3（三态）/ D4（基线+计数）/ MODIFIED 账本；偏移持久化的用途与「不从它续读」的取舍写在 D4 |
| 追加三（投递确认落到唯一 durable 记录、同文本不得重叠、旧文本不得在任何后续路径重现） | D2（`sent` 是唯一的接受记录、一条 identity 至多一个 `intent`）/ D5（身份可证）/ design §5 残余 1（队列呈现不可取消——无 ack API，改为可证伪） |

## 覆盖表（requirement → tasks item）

| Requirement（delta） | tasks 项 |
|---|---|
| ① A wake is at most once… | 1.1–1.4, 2.1–2.3, 3.1–3.3, 5.2, 5.3 |
| ② A wake names its source line… | 2.1–2.4, 3.3, 5.3 |
| ③ The delivery journal is the only dedup memory… | 1.2, 4.1–4.3, 5.3 |
| ④ Only fresh lines wake…（MODIFIED） | 3.2, 5.3 |
| ⑤ The ledger separates new traffic from recovery（MODIFIED） | 1.3, 3.3, 4.2, 5.3 |

## Flip 证据（本阶段是 propose，故只有 red 侧）

本任务是 **propose**：仓库里没有实现，**不存在**实现级 red→green 翻转证据；flip 由任务书 5.2 交 apply 阶段
（`flip-p71.sh` 的四条 break-it 变异：去掉 `intent` 写 → S25a 出现第二次唤醒；把 `intent` 读成「未开始」→ S25b
第二次投递；去掉文本里的 identity → S25d 两行不可区分；去掉 `floor` 规则 → 3.4 重放）。若 PM 认为 propose 也
必须给出实现级翻转，请回派（那等于要求本阶段写实现，与任务书「**不写实现**」冲突）。

本阶段可用的 red 侧现成证据（都来自落盘文件，`pkg/run.sh` 可重算）：dev2 `.wake(9) > .seen(8)` 且缺的是最老
已投递行；`.seen` 写失败被吞、发送失败被吞的代码事实；唤醒文本无 id/无时间；17:46 的 `deliver=0` 与后来 8 条
id 的一一对应（说明现有口径在**没有重放**时也判不出「重放」）。

## 边界与残余

- **边界遵守**：只写 `openspec/changes/wake-delivery-idempotence/**`、`docs/team/reports/P71-verify/**` 与本分支提交；
  未改 `skills/**`、`docs/team/tasks/**`、`BOARD.md`、`OWNERSHIP.md`；未 push、未合并；未读会话文件（`~/.pi/agent/sessions/**`）
  与任何其他项目。
- **取证只读**：`pkg/**` 只读 `.pi/team/state/**`、`docs/team/inbox/**`、`/var/tmp/P71-pm-wake-spool-1746.bak`
  与源码；不写 state、不开 tmux、不跑 pi。
- **残余（design §5，本提案不修）**：`deliverAs: followUp` 的迟到呈现与会话侧队列副本（无 ack/取消 API，改为
  可证伪）、pulse 每 `TEAM_PULSE_NUDGE_GAP` 重发的同文本 nudge（有意为之，现在可区分）、
  `TEAM_INBOX_WATCH_STALE`（发送侧注册活性 300s）与 `TEAM_INBOX_WATCH_STALE_SEC`（读侧行龄 900s）同名陷阱、
  `.seen`→journal 的迁移是单向的。
- **BLOCKED: 无**；未发现需要跨项目协调的依赖。

## 复核方法（PM 可自己跑）

```sh
# 1) 提案包结构与语义（本阶段门禁）
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
PATH="$HOME/.bun/bin:$PATH" openspec status --change wake-delivery-idempotence   # 4/4 artifacts

# 2) 报告里每个事故数字的重算（只读，不动 state）
bash docs/team/reports/P71-verify/pkg/run.sh          # 期望：✓35 ✗0 findings=0 skip=0

# 3) 逐条人工核对（各一条命令）
grep -c '2026-09-22T14:09:56.*inbox=dev2' .pi/team/state/inbox-watch.log        # 1（只有一次）
grep -n 'kinds=nudge' .pi/team/state/inbox-watch.log | sed -n '/16:43:57/,/19:45:38/p'   # 空
grep -c '未读通知 7 · 待复验 4' .pi/team/state/nudges.log                        # 2（两条不同 id）
wc -l .pi/team/state/inbox-watch/teamsmith_dev2-e88859f1.{wake,seen}             # 9 / 8

# 4) 与提案的对应：delta 的 requirement 名 → tasks 的覆盖表（tasks.md 顶部）；5.3 里 PM 还要求 apply grep
#    两个 MODIFIED requirement 名在其他 open change 的 delta 里是否出现（本报告已查：0 命中）
```
