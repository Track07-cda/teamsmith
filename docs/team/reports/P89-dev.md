# P89 · wake-delivery-idempotence 独立验证（verify 阶段）

```
task:   P89
agent:  dev（apply=P81 dev2、propose=P71 verify —— 两位都不是本席位）
change: wake-delivery-idempotence
specs:  notify-and-inbox#A wake is at most once: the delivery record is written before the send and survives a restart
        notify-and-inbox#A wake names its source line so a recipient can prove what it is
        notify-and-inbox#The delivery journal is the only dedup memory, and it is bounded and auditable
        notify-and-inbox#Only fresh lines wake the session; stale lines stay silent and countable（MODIFIED）
        notify-and-inbox#The ledger separates new traffic from recovery（MODIFIED）
phase:  verify
anchor: change
deltas: notify-and-inbox
branch: task/P89-p89（本地模式，不 push）
verified revision: 2aa97d0b（P81 分支 tip；实现提交 b14157b1）
tree:   3642fd07（复验跑的树 = 本分支的合并提交；其后的提交只加 `docs/team/reports/P89-dev/**`；
        `git diff --stat b14157b1 -- skills/ openspec/` 为空）
main@delivery: 0670bba3（复验期间 main 又前进了 P88/P90/P97 等落地；其中
        `extension/team-inbox-watch.ts`、`tests/team-inbox-watch-harness.mjs`、`tests/flip-p71.sh`
        相对 b14157b1 逐字未变——被验的仍是 P81 的树）
extension sha256: 2eb6bfe6123f5ca3af8f4cd25bdb6a7c69a0779c44bf1a179999bd3dc8381a0b
机器:   nproc=32 · node v24.19.0（本机 node **没有** TypeScript 支持）· bun 1.3.14
```

## 结论

**delta 的契约全部成立：验收全绿、零回归。** 八个攻击组（三个崩溃窗口、fail-closed、旧行、
可自证、`.seen` 退役、事故重放、逐字相同的两行、日志界与地板）共 **86 条断言**在 **bun** 与
**node（生产运行时形状）** 两种运行时下各跑一遍，全部 ✓；在 **out-of-tree 的 `2aa97d0b` 干净
副本**上再跑一遍同样 86 ✓ 0 ✗；
5 个定点变异各自让命名断言变红（红→绿，只在 `/tmp` scratch 副本上）；门禁
`openspec validate --all --strict`（30/0）、apply 自己的 harness（214 PASS / 0 FAIL）、
`flip-p71.sh`（exit 0，6 条预期）、FAST smoke（✓ 2641 ✗ 0）与**全量 smoke（✓ 3308 ✗ 0）**全绿。
实现树没有被本任务改动（扩展文件 sha256 前=后，`skills/` 的 `git diff` 为空）。

两条交给 PM 的记录（都不是 delta 契约的失败）：

1. **F-P89-1（文档缺口，brief 第 6 条的后半句只在一半文档里成立）**：apply 为 Bun 的目录 watcher 坑加了
   `armFileWatcher` 兜底（`team-inbox-watch.ts` 内注释写明），P81 的**任务报告**也写了「Bun 的目录 watcher
   在 spool 创建后会静默丢失逐文件事件」与「生产 Pi 走 node、夹具走 bun」；但**运维/维护读的那两份参考**
   （`references/agent-adapters.md` §4a.1c 与 `references/troubleshooting.md` §20）**没有一行**提到它，
   也没写生产/夹具的运行时差异。delta 没有任何 requirement 要求它，所以不是契约失败；另：本报告的
   跨运行时验收（`bun build --target=node` + node 跑同一套 86 条）把 apply 申报的那半条残余关掉了。
   **建议**：补一行文档（路径在我的 grant 之外，`skills/teamsmith/references/**` 属 apply/PM），
   或由 PM 记成已接受残余。
2. **方法记录（我自己的夹具缺陷，已修，非实现缺陷）**：变异段第一版让 5 个变异共用同一个
   `P89_TMP`，夹具仓库残留串味（第二次变异的日志里出现上一次的 `start/read/intent/sent`）。
   已修为「每个变异一个独立夹具根」+ `makeRepo` 先清目录，重跑后每个变异的红都是它自己的现场。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P89-dev.md` | 本报告 |
| `docs/team/reports/P89-dev/pkg/lib.sh` | 隔离（清 `TEAM_*`/`TMUX*`、私有 tmux `-L` shim、私有 `TMUX_TMPDIR`）、结论协议、**被验扩展的 sha256 钉** |
| `docs/team/reports/P89-dev/pkg/cases.mjs` | 自造夹具：假 Pi 宿主 + 夹具仓库 + **自写日志解析器**；八组 86 条断言 |
| `docs/team/reports/P89-dev/pkg/p89-child.mjs` | 崩溃子进程（真 SIGKILL；把每次被接受的发送写进 `pi-sends.log`） |
| `docs/team/reports/P89-dev/pkg/mutations.mjs` | 5 个定点变异（锚点必须恰好命中一次，否则报错退出） |
| `docs/team/reports/P89-dev/pkg/{10-cases,11-node,20-gates,21-full-smoke,30-mutations}.sh`、`run.sh` | 编号段 + 入口（`== N 结果 ==` 聚合，findings 不影响 exit 0） |
| `docs/team/reports/P89-dev/logs/**` | 全部原始输出（下面每段 tail 的来源） |

复现：

```bash
bash docs/team/reports/P89-dev/pkg/run.sh          # 10 11 20 30
bash docs/team/reports/P89-dev/pkg/run.sh 21       # 全量 smoke（长）
P89_TREE=/path/to/2aa97d0b bash docs/team/reports/P89-dev/pkg/run.sh 10   # out-of-tree 复跑
```

`run.sh` 把被验扩展的 sha256 钉成 `P89_EXPECT_EXT_SHA`，每段先核对——**换一棵树就会红**，不会
悄悄验别的东西。

## 怎么验的（手法与隔离）

- **不复用被验者的证据包**：apply 的 harness / flip 只作为**对照**跑（第 6 段），本任务的注入、
  夹具、日志解析全部自己写、自己跑。日志解析器（`journalRecs`）按 delta 的 D2 记录形状独立实现，
  不 import 实现里的任何函数；三个崩溃态里有两个是**手写日志字节**（不靠实现的注入点），
  第三个用真子进程 SIGKILL（真崩溃，`status=null signal=SIGKILL`）。
- **隔离**：夹具仓库全部是 `mktemp -d` 下的临时 git 仓库（`.pi/team/config.sh` + `git init`），
  `TEAM_*`/`SMOKE_*`/`TMUX*` 一律先清；tmux 走 `-L` 私有 socket shim 且 `TMUX_TMPDIR` 指向已存在
  的私有目录（memory #1250 的两种陷阱都避开）。**门禁段（20）反过来剥掉 shim**：workshop 套件
  自己管 tmux 隔离，smoke 第一条就断言它——第一版带着 shim 跑，smoke 的 socket 探针落到本包的
  私有 server 上，那条自检直接红（`✗ tmux 隔离：私有 socket 没生效`）。这与 M64 的教训一致，
  已固化成脚本注释。
- **不改实现**：变异只打在 `/tmp` 副本上；段 30 前后核对扩展 sha256 与 `git diff --stat -- skills/`。
- **两种运行时**：本机 node 不能加载 `.ts`（`ERR_NO_TYPESCRIPT`，`process.features.typescript=false`），
  所以 node 侧用 `bun build --target=node` 把**同一份源码**打成 42 KB JS 再由 node 执行——
  这正是 apply 报告里申报的「node 侧同形验证留待复验」那条残余，本任务把它补上。

## 1 至多一次（brief ①：三个崩溃窗口，自己造）

### 1.1 投递后、`intent` 前 SIGKILL → 恰好一次恢复

`p89-child.mjs` 是**另一个进程**，注入点被 SIGKILL 后留下 `read` 无 `intent`：

```
  ok     A1 the child is a real separate process SIGKILLed at the read injection point :: status=null signal=SIGKILL
  ok     A1 no send happened before the kill (the crash window is real) :: sends=[]
  ok     A1 the journal holds a read record and no intent for the line :: records=start,read
  ok     A1 the restart sends exactly one recovery wake (not two) :: messages=1
  ok     A1 the ledger records it as recovery n=1 with its seq ::
           … wake n=1 total=1 inbox=pm kinds=say seq=2 ids=sha1:a8d3… recovery n=1
  ok     A1 the recovery closed the batch with sent (terminal from now on) :: records=…,intent,sent
  ok     A1 the recovery wake names the source line identity and the journal file ::
           [teamsmith] inbox wake #2 · 2026-09-22T23:22:24.722Z | - [say] … id sha1:a8d3…  …
  ok     A1 a second restart wakes nobody (sent is terminal) :: messages=0
  ok     A1 a later rewrite of the same bytes produces no second wake :: messages=0
           rescan lines=0 … deliver=0 + replay suppressed n=1 reason=normal
  ok     A1 the rewrite leaves total unchanged ::  wake n=1 total=1  ->  wake n=1 total=1
```

### 1.2 `intent` 后、`sent` 前 SIGKILL → 零重投（`inflight assumed`）

```
  ok     A2 the child is a real separate process SIGKILLed at the intent injection point :: status=null signal=SIGKILL
  ok     A2 no send happened before the kill :: sends=[]
  ok     A2 the child left a complete read+intent and no sent/failed :: records=start,read,intent
  ok     A2 the restart sends no wake at all (inflight assumed) :: messages=0
  ok     A2 the ledger records exactly one inflight assumed n=1
  ok     A2 no recovery wake is invented for the unknown outcome
  ok     A2 the durable inbox line is still readable
  ok     A2 total did not move
  ok     A2 a later rewrite of those bytes adds no wake and no total :: messages=0
  ok     A2 the same bytes coming back are suppressed and named, not re-sent
```

### 1.3 手写半截尾记录 → 同一条处理（零重投）

两发都是**手写日志字节**（不经实现的注入点）：① 尾部 `intent seq=1` 没有收尾换行（写到一半崩溃）；
② 尾部是一条完整但不可解析的记录。两者都读到「结果未知」：

```
  ok     A3 a torn trailing record is named in the ledger ::
           2026-… torn tail inbox=pm（日志尾部有半截记录：结果未知，绝不重投）
  ok     A3 a torn tail is treated as inflight assumed ::
           2026-… inflight assumed n=1 inbox=pm（intent 无 sent/failed：结果未知，永不重投）
  ok     A3 the torn-read line is never woken :: messages=0
  ok     A3 a later rewrite of a torn-read line stays silent :: messages=0
  ok     A3 a second restart does not recover it either :: messages=0
  ok     A3b an unparsable trailing record is named torn and never re-sent :: messages=0
  ok     A3b the unparsable tail leaves the read entry unknown (inflight assumed)
```

注意 1.3 的第二条是 delta 里那句「a torn or unparsable trailing record MUST be read as this state
（intent without sent）」的**反向证明**：半截 `intent` 不因「没写全」而被当成「还没发过」。

## 2 fail-closed（brief ②）

两种不可写形状各造一次现场：**日志路径被换成目录**（`appendFileSync` → EISDIR）与
**watch 目录 0500**（创建新文件 → EACCES）：

```
  ok     F1 the ledger records deliver blocked while the journal cannot be written :: messages=0
           deliver blocked seq=1 inbox=pm（投递日志写不进去 → 按失败关闭：一条都不发，行保持未读）
  ok     F1 nothing is sent while the journal is unwritable :: messages=0
  ok     F1 the line is delivered exactly once when the journal becomes writable again :: messages=1
  ok     F1 the blocked attempt left no read record (the line stayed unseen) :: reads=1
  ok     F1 the delayed delivery is a normal wake, not a recovery
  ok     F2 a read-only journal directory blocks the wake (deliver blocked) :: messages=0
  ok     F2 the line is delivered exactly once after the journal becomes writable :: messages=1
```

「行保持未读」的判据是**同一会话内**恢复可写后 offset 仍指回那一行：只有一次 `read`（不是两次）、
账本有 `wake n=1` 而没有 `recovery n=`。

## 3 旧行（brief ③）

```
  ok     S1 an old line produces no wake :: messages=0
  ok     S1 the stale line is counted apart from total :: classify stale=1 unparsable=0
  ok     S1 a fresh line after a stale one wakes exactly once :: messages=1
  ok     S1 the wake names only the fresh line
  ok     S1 total grows by exactly one ::  wake n=1 total=1
  ok     S1 the stale line stays in the spool with its bytes
  ok     S2 the recovery pass counts the stale line instead of waking it ::
           recovery candidates=1 fresh=0 stale=1 unparsable=0 inbox=pm
  ok     S2 the stale recovery is not counted as a recovery wake
  ok     S2 total stays 0
  ok     S2 the durable inbox copy is untouched
  ok     S3 a line inside the horizon wakes while the older one does not :: messages=1
```

S2 就是 MODIFIED requirement 新增的那条 scenario（**恢复路径也要先过新鲜度**）：手写一条 `read`
无 `intent`、但 `src` 是 1 小时前的日志，重启后数是 `stale=1` 而不是 `recovery n=1`，不唤醒。
S3 是地平线两侧（1000 s 旧=stale，800 s 内=fresh，默认 900 s）。

## 4 可自证（brief ④：逐条核对一条真消息）

一条**真** `team notify pm --from-file`（真 CLI、真 outbox、真 durable 收件箱、真 spool）：

```
  ok     I1 the real `team notify pm` exits 0 :: ✓ notified pm: P89-IDENTITY: real cli wake with a sender record id
  ok     I2 the CLI reports the pi watch channel (not a paste, not a tmux gate) :: pi 监视通道：收件箱已写…
  ok     I3 the durable inbox line exists exactly once :: lines=1
  ok     I4 the spool line carries the sender record id in its 6th field :: fields=6 id=1790121456254-0001-p89s:pm.msg
  ok     I5 the id resolves to exactly one delivered.log record :: hits=1
  ok     I6 the wake text prints that same identity
  ok     I7 the wake text names the journal file the identity was recorded in
  ok     I8 the journal read record uses the identity the wake text printed ::
           journal=1790121456254-0001-p89s:pm.msg spool=1790121456254-0001-p89s:pm.msg
  ok     I9 the read record names the durable inbox line the recipient can read
  ok     I10 the wake text prints the line's absolute source time, not a relative age :: src=2026-09-22T23:57:36.301Z
  ok     I11 the wake points at the durable inbox path
```

四份文件串成一条链：spool 第 6 字段 = wake 文本印的 id = 日志 `read id=` = `delivered.log`
里**恰好一条** name 列记录，并且 wake 文本点名 durable 收件箱路径与日志路径。

## 5 `.seen` 不再被读（brief ⑤）+ 事故重放

```
  ok     E1 the first start imports .seen once :: seen import n=2
  ok     E2 the journal stores both identities as imported sent records :: sent … imported=1 ×2
  ok     E3 an imported (already-delivered) line wakes nobody :: messages=0
  ok     E4 deleting .seen changes no decision (the rewrite stays silent) :: messages=0
  ok     E5 a .seen written after the import suppresses nothing (the journal is the only memory) :: messages=1
  ok     E6 the import ran exactly once :: imports=1
  ok     E7 a corrupted .seen does not suppress an already-delivered rewrite :: messages=0
  ok     E8 a corrupted .seen does not swallow a fresh line either :: messages=1
```

E5/E8 是这一组里最咬人的两条：导入**之后**再往 `.seen` 写一条与将要投递的行**逐字相同**的记录，
正确实现照投（`.seen` 不再是记忆）；E8 再证明损坏的 `.seen` 也不会吞掉新行。E6 证明导入只发生一次。

事故重放用**归档字节**（`tests/fixtures/p71-incident/{dev2.wake,dev2.seen,pm-nudges.wake}`，
9+8+3 行）重放 2026-09-22 的现场，自己播种 3 条 nudge 的交付事实：

```
  ok     X1 the archived fixture matches the incident record (dev2=9 lines, .seen=8, nudges=3)
  ok     X2 the incident spool wakes nobody at startup :: messages=0
  ok     X3 the first start imports the archived .seen (its 8 delivery facts) :: seen import n=8
  ok     X4 the journal covers 11 of the 12 incident lines and only the undelivered one is swallowed ::
           baseline swallowed n=1
  ok     X5 no incident line is woken from the journal :: messages=0
  ok     X6 the rewrite of the journaled incident lines is rescanned and suppressed, deliver=0 ::
           rescan lines=11 dup=11 skipped=0 deliver=0 stale=0 unparsable=0 total=0 inbox=pm
           replay suppressed n=11 reason=rescan inbox=pm
  ok     X7 the delivered-but-unrecorded line is counted stale and never woken :: messages=0
  ok     X8 total is untouched by the incident replay
```

与事故记录的两条形状一致：截断那一拍 `rescan … deliver=0`，写回的字节逐条被
`replay suppressed` 压掉；唯一没进过任何记忆的那条（`.seen` 里缺的 `1789810336525`）只计数、不唤醒。

## 5b 逐字相同的两行（delta 的另一条点名 scenario）

两条 payload 逐字相同、id/时间不同的 nudge（事故里那两条的原样文本），然后外部重写其中一条：

```
  ok     D1 the two byte-identical lines are one wake listing two rows :: messages=1 rows=2
  ok     D2 the two rows differ by source time and identity ::
           - [nudge] from pulse :: [pulse] 待办：未读通知 7 · 待复验 4  (src …14.062Z · id 1790093637236-0001-pm.msg)
           - [nudge] from pulse :: [pulse] 待办：未读通知 7 · 待复验 4  (src …14.063Z · id 1790094537381-0001-pm.msg)
  ok     D3 the printed identities are exactly the two spool lines' identities
  ok     D4 both identities are recorded in the journal
  ok     D5 total counts both lines ::  wake n=2 total=2
  ok     D6 the rewrite of one of them produces no wake and is named replay suppressed reason=rescan ::
           rescan lines=1 dup=1 skipped=0 deliver=0 stale=0 unparsable=0 total=2 inbox=pm
  ok     D7 the journal file the identities were recorded in is named in the wake text
  ok     D8 both lines coming back are still not re-woken :: messages=1
```

## 5c 日志界与淘汰地板（delta 的 bounded / below-the-floor 两条）

`TEAM_INBOX_WATCH_JOURNAL_MAX=16` 下投递 8 条，压缩发生，重启后让**被淘汰**与**被保留**的身份
各回来一次：

```
  ok     B1 the journal compacted under the bound (16 records) :: records=16
  ok     B2 compaction recorded its floor :: floor id=sha1:b50f96f0… ts=1790123115234 evicted=1 kept=13
  ok     B3 the compacted journal kept some identities and evicted at least one :: kept=5 evicted=1
  ok     B4 a retained identity is still suppressed on a rewrite ::
           rescan lines=2 dup=1 skipped=0 deliver=0 … | replay suppressed n=1 reason=rescan
  ok     B5 the evicted identity is counted unprovable and never woken :: messages=0
           … unprovable n=1（身份早于日志淘汰下限：日志已不能证明它没投过 → 永不唤醒）
  ok     B6 the rescan reads deliver=0 while counting both
```

## 6 零回归（brief ⑥）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
    Totals: 30 passed, 0 failed (30 items)                       # exit 0
$ ~/.bun/bin/bun skills/teamsmith/tests/team-inbox-watch-harness.mjs …/team-inbox-watch.ts
    TEAM-IW-HARNESS OK (skipped=0)                               # PASS=214 FAIL=0
$ TEAM_FLIP_BASE=e71acbe6… bash skills/teamsmith/tests/flip-p71.sh
    flip-p71: 全部预期成立（red / green / 四个变异）              # exit 0，6 条预期
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
    == 结果 ==  ✓ 2641  ✗ 0                                      # smoke 全绿
$ bash skills/teamsmith/tests/smoke.sh </dev/null
    == 结果 ==  ✓ 3308  ✗ 0                                      # 全量 smoke 全绿（logs/gate-full-smoke.log）
```

### 全量 smoke 的三次尝试（一次队列超时、一次已归因的机器形状、一次验收跑）

**尝试 1（排队超时，未跑）**：门锁在别的席位手里，1800s 排队上限内没轮到 → 当时段脚本还把它记成红；
现在的段脚本把它报成可见 SKIP（「未跑」——不是红、也不是绿）。

**尝试 2（未加 anchor）**：`✓ 3233 ✗ 63`——63 条红**全部**落在两个真 pane 段（`12b-h` 与 `31c`），
第一条现场就是基础设施：

```
no server running on /tmp/teamsmith-smoke.9eZG6Z/tmux/tmux-1000/default
  ✗ 12b-h ① 真 pane：脏框 → queued（… ob-h-say.log 中找不到 [queued]）
  ✗ 12b-h ① 真 pane：草稿不见了
  …（后面全是级联；12b-h0/0b/0d/0c 的纯帧判据全 ✓）
```

这个形状有档：P52-dev2 F3 记过一次 `✓ 2782 ✗ 64`、64 条全在 12b-h、首行同一条
`no server running`，同分支单独重跑 12b-h 全绿；M53 报告也记过「并发负载下 12b-h 段级联红，干净重跑绿」。
我另外把机制量了下来（私有 socket 上）：

```
杀掉私有 server 上唯一的 session                → “no server running”（server 随最后一个 session 退出）
先建一个 anchor（sleep 60）再杀另一个 session → server 还活着（anchor: 1 windows）
```

套件自己只在「调用者来自 tmux」时建这个 anchor（`SMOKE_CALLER_HAD_TMUX=1` 才走那段）：本包为了隔离
把 `TMUX` 清掉了，于是裸跑没有 anchor，任何一段杀掉最后一个 session 后，后面的真 pane 段就级联红。
验收跑改为向套件要同一份身份（`SMOKE_CALLER_HAD_TMUX=1`：套件在它自己的私有 server 上建 anchor、
把 `TMUX`/`TMUX_PANE` 指向它）——这正是正常交付环境（agent 从 tmux 窗口跑门禁）的形态；其余隔离不动。
失败那次的原件留在 `logs/gate-full-smoke.flake-12bh.log`（判责用；不是被验树的红）。

**尝试 3（验收，带 anchor）**：队列 62 分钟后跑，`== 结果 == ✓ 3308 ✗ 0`，`smoke 全绿`（`logs/gate-full-smoke.log`）。

`flip-p71.sh` 的默认红树是 `git merge-base HEAD main`——在**验证分支**（main 已含 P81）上这个
merge-base 已经不是修复前，脚本自己会拒绝（这是它正确的自我保护）。所以显式钉
`TEAM_FLIP_BASE=e71acbe6c50398e69e4795205be45c50a54504c3`（P77，P81 报告点名的红树；
本树里该提交存在且扩展里 `journalAppend` 出现 0 次）。红侧原始行：

```
✓ 红树（e71acbe6…）复现成功：S25a/b/d/e 全红
  red: TEAM-IW-CASE FAIL S25a exactly one recovery wake is sent for the crashed line :: messages=0
  …
✓ 绿树（本 worktree）目标用例全绿（S25a/b/d/e）
✓ 变异 A/B/C/D：命名断言红，rc=1
```

**跨运行时**（本任务补上 apply 申报的残余）：`bun build --target=node` 同一份源码，由 node 执行
同一套 86 条断言：

```
== 11 结果 == ✓86 ✗0 · findings=0 · skip=0
```

**零改动的核对**：`git diff --stat b14157b1 -- skills/ openspec/` 为空；out-of-tree 的
`2aa97d0b` 干净副本上再跑一遍段 10 → `P89-TOTAL ✓86 ✗0`（`logs/pkg-10-pristine-tip.log`）。

**既有断言没有被放宽**（对 apply 的 diff 做逐条审计）：harness 只改了两条——S11 的
`dedup: skipped` → `replay suppressed`（谓词不变：shrink 行 ≥1 且抑制行 ≥1），S13 的
`<key>.seen exists` → `<key>.deliver is the journal`（并多了一次真重启），没有删除或放宽任何判据；
smoke 只删了一条**段标题字符串**（`…（<key>.seen 持久化）`），新增 49 条 pin。

## 变异（红 → 绿，scratch 副本）

各变异只打在 `/tmp` 副本上；绿基线就是上面的段 10（同一批断言 ✓）。红侧原始行：

| 变异（定点破坏） | 红的命名断言（原始行） |
|---|---|
| `send-before-write`：先发、后写 `intent` | `✗ A2 no send happened before the kill :: sends=[{…"at":1790121401169…}]` · `✗ A2 the restart sends no wake at all (inflight assumed) :: messages=1` |
| `intent-is-not-started`：重启把 `intent` 读成「还没开始」 | `✗ A2 the restart sends no wake at all (inflight assumed) :: messages=1` · `✗ A2 the ledger records exactly one inflight assumed n=1` |
| `journal-fail-open`：日志写不进去也照发 | `✗ F1 nothing is sent while the journal is unwritable :: messages=1` · `✗ F1 the ledger records deliver blocked …` |
| `torn-tail-fail-open`：半截尾不再当未知（回恢复队列） | `✗ A3 the torn-read line is never woken :: messages=1` · `✗ A3 a torn tail is treated as inflight assumed` |
| `seen-reread`：每次启动都重读 `.seen` | `✗ E5 a .seen written after the import suppresses nothing :: messages=0` · `✗ E6 the import ran exactly once :: imports=2` |

```
  ok     the reviewed extension file is byte-identical after all mutations
  ok     no tracked file under skills/ changed while mutating
```

## 决定与判断

1. **分支对齐**：派单把 P86 的分支改名成本任务分支，P86 内容已被 main 以 squash 收编且
   P86 已完成；为了让复验门禁跑在**被验的那棵树**上，我把 main 合进本分支（`3642fd07`）。
   唯一冲突 `skills/teamsmith/references/troubleshooting.md` 取 **main 一侧**（P86 已过复验的措辞），
   被丢掉的是我自己未合并的 P86 follow-up 措辞——合并后 `git diff --stat main` 为空
   （本报告之前）。这一步没有改实现。
2. **被验 revision**：`2aa97d0b`（P81 分支 tip）与 `b14157b1`（实现提交）的 `skills/`/`openspec/`
   逐字一致；本分支同内容。所有命令都在 `P89_EXPECT_EXT_SHA` 钉住扩展文件的前提下跑。
3. **findings 与 PASS 的关系**：段 10–30 的 86+7 条判据零 ✗；F-P89-1 是**文档缺口**（brief 的
   核对项），不是 delta 契约失败。若 PM 按「带 findings 的 PASS = rework」处理，最小修复是往
   `references/agent-adapters.md` §4a.1c 或 `troubleshooting.md` §20 加一行
   （Bun 目录 watcher 坑 + `armFileWatcher` 兜底 + 生产 node / 夹具 bun），路径不在我的 grant 内。
4. **两个 MODIFIED 与其他 open change 不撞车**（我自己的复查）：`grep -rl` 那两条 base
   requirement 名，排除本 change 后无输出；另一份 open delta `notify-sender-identity` 改的是
   `A turn-end notification appends one inbox line and knocks once`，`one-line-draft-judgement`
   改的是 `Messages to a stopped agent fall back to the inbox`，都与本 change 的五条无关。
5. **段 20 的原始输出**：`logs/pkg-20.log` 与 `gate-*.log` 来自 2026-09-22T23:40Z 那次运行
   （FAST 2641/0；flip exit 0）。其后段脚本只修了一处 ANSI 计数显示（那次打印 `0 预期行`），
   原始 `gate-flip-p71.log` 里 6 条预期逐条在案。全量 smoke 三次尝试的记录（队列超时→未跑、
   无 anchor 的 12b-h 级联、带 anchor 的 `✓3308 ✗0`）在 §6 与 `logs/gate-full-smoke.flake-12bh.log`；
   全程不 `TEAM_SMOKE_NO_LOCK=1` 抢跑（两个全量互相撞会让别人的红变假）。

## 已知限制

- `deliverAs: followUp` 的**会话侧演示延迟**没有 ack API：本包证明的是「入队至多一次 + 唤醒文本
  可自证」，不是「会话已经演示过」（apply 设计 §5 的残余，我接受）。
- node 侧用的是 `bun build --target=node` 的同一份源码（本机 node 无 TS 支持），验的是运行时无关的
  状态机；不是另一份独立编译产物。
- `.seen` 组用的是夹具形状的 `.seen`；事故原件的 `dev2.seen` 在事故重放组里逐字使用。
- 崩溃注入点用的是扩展自带的夹具缝（`TEAM_INBOX_WATCH_ABORT_AFTER`，仅 `TEAM_SMOKE_FIXTURE=1`
  生效）；另外两个崩溃态是手写日志字节，所以「重启判定」不依赖这条缝本身。

## Suggested next steps

- PM 复验（`team review P89 --strong`），重点按本报告核对 F-P89-1 的裁决：补一行文档 or 记残余。
- 若补文档：建议由获 `references/**` 授权的 agent 加一行，内容要点「生产 Pi 走 node；夹具/本机
  走 bun；Bun 1.3 的目录 watcher 在 spool 创建后会静默丢逐文件事件，故有文件级 watcher 兜底」。
- 归档前按 house 规则确认：本报告的两条记录（F-P89-1、方法记录）已被 PM 处置。
