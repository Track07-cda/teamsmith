# P81 · wake-delivery-idempotence apply（投递日志 + 至多一次 + fail-closed）

```
task:   P81
agent:  dev2
branch: task/P81-apply（local 模式：不 push；PM 复验后本地合并）
change: wake-delivery-idempotence（phase: apply；proposal review 已 ACCEPTED）
deltas: notify-and-inbox（3 ADDED + 2 MODIFIED，逐 scenario 兑现见下）
status: DONE（验收命令全部实际运行；等 PM 独立复验）
budget: 一个工作块
```

**一句话**：唤醒的**门铃**现在是至多一次（at-most-once），durable 收件箱行仍是恰好一次（消息）；
每一次投递都在发送**之前**落进 `state/inbox-watch/<key>.deliver`，重启后的判定只从这份日志读
（进程内存不再有任何权威），写不进去就**什么都不发**；每条唤醒点名它的源行（序号 + 绝对时间 + 身份）。

## Deliverables

| 路径 | 内容 |
|---|---|
| `skills/teamsmith/extension/team-inbox-watch.ts` | 投递日志（`read`/`intent`/`sent`/`failed`/`start`/`floor`）、写前顺序、fail-closed、三态重启判定、恢复/重试、新鲜度、压缩与 `floor`、`replay suppressed`/`unprovable`/`inflight assumed`/`deliver blocked`/`torn tail`/`baseline swallowed` 计数、唤醒文本点名源行；`.seen` 只被一次性导入 |
| `skills/teamsmith/scripts/lib/outbox.sh` | spool 行追加第 6 字段 = 发送方自己的 durable 记录名（outbox 条目名，与 `delivered.log` 的 `name` 列同串） |
| `skills/teamsmith/tests/team-inbox-watch-harness.mjs` | S11/S13/S21 迁到日志；新增 S25j/S25g/S25r/S25z/S25a/S25b/S25c/S25d/S25e/S25f/S26 与**子进程崩溃运行器**（`--child` + `TEAM_INBOX_WATCH_ABORT_AFTER`） |
| `skills/teamsmith/tests/fixtures/p71-incident/{dev2.wake,dev2.seen,pm-nudges.wake,README.md}` | 事故字节夹具（1929 B/9 行、1701 B/8 行、690 B/3 行），逐字副本 + 来源与大小 |
| `skills/teamsmith/tests/flip-p71.sh` | 翻转包：红树（pre-P81）+ 绿树 + 四个定点变异，exit 0 |
| `skills/teamsmith/tests/smoke.sh` | 12b-pi 段追加 P81 的 20 条 pin；S13 的说明从 `<key>.seen` 改成 `<key>.deliver`（append-only 之外只改这一句） |
| `skills/teamsmith/references/agent-adapters.md` | §4a.1 改成「日志/offset/rescan/caps」；新增 §4a.1c：记录形状、写前顺序、三态、计数器、界与 floor、单向 `.seen` 导入、两个 env-only 旋钮 |
| `skills/teamsmith/references/troubleshooting.md` | §20 重写为「同一条被叫两次 / 『投过没有』怎么从文件回答」，含逐计数器读法（§号锚点未动） |
| `docs/team/reports/P81-dev2/` | 证据：`harness-full.log`、`flip-p71.log`、`incident-classes.txt`、`fast-smoke.*`、`full-smoke.*` |

## Requirement → item → evidence map

| delta requirement | tasks 条目 | 实现点 | 证据（harness case → 账本/文件行） |
|---|---|---|---|
| #A wake is at most once（写前记录、跨重启） | 1.1–1.4, 2.1–2.3, 3.1–3.3, 5.2, 5.3 | `journalAppend`/`sendWake` 写前顺序；`loadJournal` 三态；`runRecoveryTick`/`runRetryTick`；`deliver blocked` 不推进 offset | S25j（`start,read,intent,sent`）、S25a（`recovery n=1` + 重启零重投）、S25b（`inflight assumed n=1`）、S25c（`wake failed`×2 + 重试一次；`deliver blocked` 后恰好一次；`retry stale=1`）、S25r（恢复过期 → `stale=1` 非 `recovery=`） |
| #A wake names its source line | 2.1–2.4, 3.3, 5.3 | `lineIdentity`（`id=` 或 sha1）、`wakeText`（`#seq · ISO`、每行 `src … id …`、日志路径） | S26（序号 1→2、绝对时间、身份、日志路径存在）、S25d（逐字相同两行的两行文本不同）、S10（id 在 `delivered.log` 恰好命中 1 次且唤醒文本印出） |
| #The delivery journal is the only dedup memory（有界、可审计） | 1.2, 4.1–4.3, 5.3 | `loadJournal`/`compactJournal`/`maybeCompact`；`importSeen`；`classify` | S25j（记录形状/顺序/ISO、过期不写记录）、S25e（`.seen` 一次性导入 + 删掉不改判定；撕裂尾 `torn tail` + `inflight assumed`；压缩 ≤24 记录 + `floor=`；保留 `replay suppressed`、淘汰 `unprovable`）、S11/S13/S21（重写静默、`deliver=0`、`total` 不动） |
| #Only fresh lines wake（MODIFIED） | 3.2, 5.3 | `freshnessOf` 用于普通/重扫/**恢复**/重试四条路径 | S25r（`recovery candidates=1 fresh=0 stale=1`）、S20a/S20b/S20c（既有，未放宽）、S25c（`retry stale=1`） |
| #The ledger separates new traffic from recovery（MODIFIED） | 1.3, 3.3, 4.2, 5.3 | 账本各计数器；`wake … seq= ids=`；`rescan … deliver=0` 与 `dup=` 并存 | S9（wake 行带 `seq=`/`ids=`；`baseline swallowed` 在）、S25g（`baseline swallowed n=1` 且 `started … baseline=<size>` 不变）、S25f（`rescan lines=0/12 … deliver=0` + `dup=` + `stale=1`） |

## Scenario → case → evidence map（delta 的每个 scenario）

| scenario | case | 观测到的证据（原始行节选） |
|---|---|---|
| Killed after the read → exactly one recovery | S25a | 子进程 `status=null signal=SIGKILL`；`read` 无 `intent`；重启 `wake n=1 … seq=2 ids=sha1:… recovery n=1`；跨重启重写 `replay suppressed` |
| Killed after the intent → never sent twice | S25b | `inflight assumed n=1`；`the restart sends no wake at all`；删掉 `.seen` 后重读仍 `replay=1`、`total=0` |
| Raising API + unwritable journal | S25c | `wake failed seq=1/2`、`sent=0`、重试成功 `total=1`；目录形态的日志 → `deliver blocked`、`messages=0`、恢复可写后恰好 1 次 |
| Rewrite of journaled lines suppressed and named | S11/S13/S21/S25d/S25f | `replay suppressed n=N reason=rescan` + `rescan … deliver=0`；`total` 不动 |
| Below the eviction floor | S25e(c) | `unprovable n=1`、`messages=0`、`rescan lines=2 dup=1 … deliver=0` |
| Identical text, two lines | S25d | 两行 `[nudge]` 文本相同，`(src … · id sha1:5ca8… )` 与 `id sha1:9252…` 不同 |
| Identity cross-references the sender's record | S10 | spool 第 6 字段 `1790109797116-0001-m30s:pm.msg`；`delivered.log` 命中 1 次 |
| Upgrade imports `.seen` once | S25e(a) | `seen import n=1`；`sent … imported=1`；删 `.seen` 后重写仍沉默 |
| Torn tail is unknown, not "not sent" | S25e(b) | `torn tail`、`inflight assumed n=1`、重写 `messages=0` |
| Compaction stays under the bound | S25e(c) | `records=22 ≤ 24`；`journal compacted … kept=21 floor=sha1:bc32… evicted=1` |
| A recovered line gone stale is counted, not woken | S25r | `recovery candidates=1 fresh=0 stale=1 unparsable=0`（无 `recovery n=`） |
| Dedup-only / stale-only rescan keeps total | S21a/S21b | `rescan lines=… dup=… deliver=0`；`total` 不动 |
| Real delivery grows total by the wake's size | S21c | `wake n=2 … total=…`，`total` +2 |
| Unknown outcome at startup named, not guessed | S25b | `inflight assumed n=1`；重写不加 `total=` |
| Lines nobody read are counted, not woken | S25g | `baseline swallowed n=1`；`baseline=44` = 当前 spool 末尾 |

## 事故重放（S25f）—— 逐条分类

夹具用**原始字节**（`tests/fixtures/p71-incident/`，来源/大小见 README）建 spool，从 `.seen` 的 8 条
与 PM 三条 nudge 的交付事实播种日志；未被记忆覆盖的最老 dev2 行（`1789810336525`，M35）不播种。
逐 id 分类见 `docs/team/reports/P81-dev2/incident-classes.txt`（12 行 = 9 dev2 + 3 PM）：

```
spool ts        identity                                            seed
1789810336525   sha1:07d2070a43b4885740768ad9ab2d4d0edd03c5e6       unrecorded          → stale=1（永不唤醒）
1789868089384   sha1:23201a4eb2f675ac746f11f8441837051abd1d48       seeded sent (.seen) → replay suppressed
…（另外 7 条 dev2 .seen 行同上）
1790093637236   sha1:e0a92f775d24c5ce52203de1162552ed396c8fd3       seeded sent (nudge) → replay suppressed
1790094537381   sha1:c45b0cb08300766d4ad9a7ea3b5496e403632099       seeded sent (nudge) → replay suppressed
1790095437514   sha1:f4d6508321b465006b7757226af7b2612c6ebd4c       seeded sent (nudge) → replay suppressed
```

运行结果（harness 原始行）：

```
TEAM-IW-CASE PASS S25f the incident spool produces zero wakes at startup :: messages=0
TEAM-IW-CASE PASS S25f the recorded truncation reads deliver=0 (the incident shape) ::
   rescan lines=0 dup=0 skipped=0 deliver=0 stale=0 unparsable=0 total=0 inbox=pm
TEAM-IW-CASE PASS S25f every seeded identity is replay-suppressed, none is woken ::
   replay suppressed n=11 reason=normal inbox=pm（外部重写带回了日志里已有记录的行）
TEAM-IW-CASE PASS S25f the one delivered-but-unrecorded line is counted stale and never woken ::
   classify stale=1 unparsable=0 inbox=pm（过期行不唤醒；时间戳不可解析的行照投）
TEAM-IW-CASE PASS S25f a one-shot truncate+rewrite is rescanned, classified and silent ::
   rescan lines=12 dup=11 skipped=0 deliver=0 stale=1 unparsable=0 total=0 inbox=pm || messages=0
TEAM-IW-CASE PASS S25f total is untouched by the incident replay :: total=0
```

两次形状与事故记录一致：截断那一拍 `rescan lines=0 … deliver=0`（现场 `rescan lines=0 … total=92`），
写回的字节走普通路径被 `replay suppressed` 压掉、没进过记忆的那条只计数；一次写到底时重扫逐条分类
（`dup=11` + `stale=1`）。

## Flip evidence（required）

`bash skills/teamsmith/tests/flip-p71.sh` → **exit 0**；完整原始输出：
`docs/team/reports/P81-dev2/flip-p71.log`（尾部 `flip-p71.tail.txt`）。

```
✓ 红树（e71acbe6c50398e69e4795205be45c50a54504c3）复现成功：S25a/b/d/e 全红
  red: FAIL S25a exactly one recovery wake is sent for the crashed line :: messages=0
  red: FAIL S25a the recovery is recorded in the journal as sent :: sent records=0
  red: FAIL S25a a later rewrite of the same bytes produces no second wake :: messages=0 replay=0
  red: FAIL S25b the child left a complete read+intent and no sent/failed
  red: FAIL S25b the ledger records exactly one inflight assumed n=1 :: (none)
  red: FAIL S25d the two rows differ by source time and identity :: 两行逐字相同
  red: FAIL S25e an identity below the eviction floor is unprovable, never woken :: (none)
✓ 绿树（本 worktree）目标用例全绿（S25a/b/d/e）
✓ 变异 A：恢复唤醒跳过写前记录（read/intent）→ 重启后重复恢复唤醒
  A: FAIL S25a a restart after the recovery wakes nobody again :: messages=1
  A: FAIL S25a a later rewrite of the same bytes produces no second wake :: messages=1 replay=1
✓ 变异 B：把 intent 读成「还没开始」→ 结果未知的行被重投
  B: FAIL S25b the restart sends no wake at all :: messages=1
  B: FAIL S25b the ledger records exactly one inflight assumed n=1 :: (none)
✓ 变异 C：唤醒文本拿掉身份 → 两条相同文本不可区分
  C: FAIL S25d the two rows differ by source time and identity
  C: FAIL S25d the wake names each line's absolute source time and its identity
✓ 变异 D：去掉淘汰下限规则 → 被淘汰的身份 fail-open 重唤醒
  D: FAIL S25e an identity below the eviction floor is unprovable, never woken :: (none)
  D: FAIL S25e compaction cannot resurrect a delivery :: messages=1 total=0->1
flip-p71: 全部预期成立（red / green / 四个变异）
```

红树 = `git merge-base HEAD main` = `e71acbe6`（P77，pre-P81）。四个变异都是**定点**破坏（改一行，
不改语义周边）：A 只让恢复唤醒跳过 `read`/`intent` 两条写前记录；B 只让 `intent` 在载入时保持
「读」态；C 只从行模板里拿掉 `(src … · id …)`；D 只把 floor 判定换成 `false`。

## 验收命令（实际运行、尾部为真实输出）

### 1) OpenSpec 严格校验

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/wake-delivery-idempotence
Totals: 29 passed, 0 failed (29 items)
```

### 2) harness（本树扩展，214 条 case）

```
$ ~/.bun/bin/bun skills/teamsmith/tests/team-inbox-watch-harness.mjs skills/teamsmith/extension/team-inbox-watch.ts
TEAM-IW-HARNESS OK (skipped=0)
```

（完整日志：`docs/team/reports/P81-dev2/harness-full.log`；`TEAM-IW-CASE PASS` = 214，FAIL = 0。）

### 3) FAST 门禁

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2490  ✗ 0
FAST 模式：跳过 32 个真进程段落
smoke 全绿
```

### 4) 全量门禁

```
$ bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 3135  ✗ 0
smoke 全绿
```

完整日志：`docs/team/reports/P81-dev2/full-smoke.full.log`（尾部 `full-smoke.tail.txt`）。上面这一次是
**实现 tip**（`d8e603a6`）上的全量跑；之后只动了**夹具的等待**（把 P81 组里几处固定 `sleep` 换成
对账本状态的轮询；实现一行未动），最终 tip 上重跑了 harness（214 PASS / 0 FAIL，`harness-full.log`）
与 `flip-p71.sh`（exit 0，`flip-p71.log`）。

**最终 tip 上的全量重跑（四次尝试）都卡在共享门禁锁的排队窗口**（1800s 内没轮到；持有者是别的
worktree 的全量 smoke，22:14 起锁一直轮在别人手里，期间换了 3 个持有者）。没有用
`TEAM_SMOKE_NO_LOCK=1` 抢跑（那会让两个全量门禁互撞，别人的红会变成假红）。复验在新 checkout 上
重跑全量即可覆盖这一点。

### 5) 两个 MODIFIED requirement 与其它 open change 的 delta 不撞车

```
$ grep -rl "Only fresh lines wake the session" openspec/changes/*/specs/*/spec.md | grep -v wake-delivery-idempotence
（无输出）
$ grep -rl "The ledger separates new traffic from recovery" openspec/changes/*/specs/*/spec.md | grep -v wake-delivery-idempotence
（无输出）
```

## Refutations（design §1 的两条错判，用日志原件反驳）

1. **`total=1` 不是「从头读 spool」**：它是**本次会话**的累计投递数；`2026-09-22T14:33:07.285Z wake n=1
   total=1 inbox=dev kinds=say` 对应的是 `docs/team/inbox/dev.md:82` 那条新 `[say]` 行，而 dev 监视器的
   `started target=teamsmith:dev … baseline=1958` 在 `11:46:36.930` —— 基线之后的首次唤醒。实现里
   `seen = 0` 在每次 `session_start` 归零、`wake` 行只在真投递后 `seen += n`，与「读头」无关。
2. **读取 offset 没有失守**：`16:43:57` 之后的账本没有任何 `wake` 或旧 `dedup:` 行，`rescan lines=0 …
   deliver=0`；同一份 42 行没有被重读。PM 看到的三条其实是**三条不同的行**（`1790093637236` /
   `1790094537381` / `1790095437514`，前两条 payload 逐字相同），各自只投过一次（`total=85/86/89`）。
   真正的缺口是**演示延迟 + 文本没有身份**：D5 让每条唤醒点名源行，D1/D3 让「同一条再发一次」在文件上
   不可能 —— S25d 用这三条的原样文本作为夹具。

## Decisions and deviations

1. **行身份用 `id=` 或整行 SHA-1**（不是整行原样）：spec 要求「唤醒文本印的就是日志用的那个串」，
   同时既有 S4/M30 断言要求唤醒**不得**带 payload 全文（旧夹具的整行里含 400 字符 payload）。
   取两者交集：无 `id=` 的行身份 = `sha1:<hex>`（有界、可写、两条逐字相同的 payload 因时间戳不同而
   不同）；生产路径（`outbox.sh`）现在总是带 `id=`，唤醒文本印的就是 outbox 条目名。设计 §2 D5 的
   「id <identity>」语义不变，只是身份串本身有界。
2. **Bun 的目录 watcher 在 spool 被创建后会静默丢掉逐文件事件**（本机 bun 1.3.14 实测：`.deliver`
   一落盘，之后对 `.wake` 的追加一个事件都不报；诊断用 harness S2/S3 + 事件日志定位）。修复：
   在目录 watcher 之外，**lazily arm 一个对 spool 的文件级 watcher**（spool 只被 `>>` 追加，inode 不变），
   每次 merge-tick 后重挂一次；目录 watcher 仍负责「文件还不存在」的创建事件，轮询兜底未动。
   生产 Pi 走 node，不受这条影响；`fileWatcher` 在 `stopAll` 里关闭（S7 照旧）。
3. **`.seen` 保留但不再被读**（除首次导入）：spec 要求「删掉/清空/损坏不改变任何决定」，没有要求删除
   文件；保留它让回滚方向（旧代码读到旧记忆）可解释，导入事实进日志（`sent … imported=1`）。
4. **两个新旋钮只进 env 文档、不进 `team config` schema**：`TEAM_INBOX_WATCH_JOURNAL_MAX` 与
   `TEAM_INBOX_WATCH_ABORT_AFTER` 在 `references/agent-adapters.md` §4a.1c 里写清；`team config` 的
   schema 在 `scripts/lib/cmd-config.sh`（不在本任务授权路径内），因此 `references/config.md` 的表格
   没有加行 —— 若要暴露成正式配置键，PM 派一行 schema 改动即可（不是本任务的阻塞项）。
5. **设计 §5.2 的变异 (a)** 表述为「drop the `intent` write → S25a reds with a second wake」；本实现里
   `sent` 本身已是终态，单丢 `intent` 不改变判定（更强的实现），所以变异 A 取「恢复唤醒跳过两条写前
   记录」—— 同一个「写前顺序」契约的定点破坏，红的是 S25a 的**重启后第二次恢复唤醒**（requirements
   要求的那种「一条门铃响两次」）。变异 B/C/D 与设计逐条一致。
6. **`sent record blocked`（发出去了但 `sent` 没写上）**：多一条自述账本行，沿用 `deliver blocked` 的
   fail-closed 原则（下一次启动按 inflight 处理、绝不重投）；不在 spec 的计数器清单里，但可审计。

## Verification evidence

- 结论：**全部实际运行**（证据文件在同一目录）。
- 未验证/已知风险：
  - `deliverAs: followUp` 的会话侧排队延迟与「已接受但未演示」仍是 design §5 的残余（无 ack API）；
    本任务只让它**可自证**（`#seq` + 源时间 + 身份 + 日志路径）。
  - 生产运行时 Pi 用 node；harness 在本机只能走 bun（node 未编译进 TypeScript 支持）。Bun 的 watcher
    行为差异已用文件级 watcher 兜住，但 node 侧的同形验证要等复验/真机。
- 伪造/幻觉检查：本报告所有账本行都来自实际运行的 harness/flip 日志（文件在报告目录）。

## Suggested next steps

- PM 独立复验（`docs/team/reviews/wake-delivery-idempotence-verify.md` 或 `team review P81 --strong`），
  重点：S25a/b 的子进程真 SIGKILL、S25c 的 fail-closed、S25f 的原始字节重放、flip-p71 的变异红。
- 若要 `TEAM_INBOX_WATCH_JOURNAL_MAX` / `TEAM_INBOX_WATCH_ABORT_AFTER` 进 `team config`：给
  `scripts/lib/cmd-config.sh` 加两行（`session` 组），并在 `references/config.md` 补两行 —— 本任务未授权该路径。
