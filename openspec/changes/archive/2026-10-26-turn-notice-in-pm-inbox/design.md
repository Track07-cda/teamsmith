# turn-notice-in-pm-inbox · design

判据一句话：**一次 settle 写两份东西，两个名字，两个读者** —— 发送者收件箱里那行是记录（逐字节不变），PM 收件箱里那行是
**指针**（谁、任务、状态类、明细在哪、这次叫醒的结果）。敲门只是提醒，指针才是记录。

## 1 · 两份副本，各自的读者与不变量

| | 记录行 | 指针行 |
|---|---|---|
| 文件 | `docs/team/inbox/<seat>.md` | `docs/team/inbox/pm.md` |
| 读者 | 该席位（历史）、任何按席位查的人 | PM（`team inbox pm` / `team digest` / 面板） |
| 内容 | 今天的行，一个字节不变（含 `⚠ 未提交`、`:: <末消息>`、`branch=/uncommitted=/unpushed=/tip=`） | 身份 + 状态类 + `see=` + `knock=` |
| 明细 | 每个事件一条进 `state/notify.log` | **不进**明细（否则 `×N` 与记录数分家） |
| 合并 | 今天的键与合并规则 | 同一个键、同一个合并器，结果只落在 `pm.md` |
| 计数 | **不**算该席位的未读流量（见 §3） | 算 PM 的未读流量 |
| 敲门 | 敲门文本从它派生（不变） | 敲门结果写在它的 `knock=` 上 |

不变量（apply 的判据）：记录行在「指针开 / 指针关」两种实现下的字节应当完全一致 —— 指针行是**旁路写入**，
不参与记录行的任何判定。

## 2 · 指针行的形状

```
- <ISO> [<tag>] agent:<seat> · <ID> · knock=<outcome> · see=docs/team/inbox/<seat>.md[ · task=<ID> tip=<12hex>][ · awaiting=<ids>][ · detail=unavailable]
```

合并后（同一个合并器）：

```
- <firstISO> [<tag>] agent:<seat> · <ID> · knock=<run 首个事件的值> · see=docs/team/inbox/<seat>.md · task=<ID> tip=<12hex> · ×N first=<ISO> last=<ISO>
```

规则的每一条都有为什么：

- **由写入侧从记录行派生，而不是在扩展里另拼一份。** 行 → 合并键的解析、`task=` 的兜底 token、`awaiting=` 集合归一化
  都在 `team_notify_line_key` 里；如果指针行在 TS 里重新拼一次，就有两份「什么算同一个 run」的实现，指针与记录会在
  边界上分叉（缺字段、awaiting 顺序、`⚠` 前缀）。派生变换只有三条：删掉 `⚠ 未提交` 前缀、在字段区插入
  `knock=… · see=…`、删掉 ` :: <末消息>` 尾巴。
- **不带摘要。** 指针的职责是指路；摘要在记录行与敲门载荷里各有一份（敲门载荷本来就被守卫限长）。把摘要也抄进
  `pm.md` 会让 PM 的收件箱变成第二份正文，而 `pm.md` 的行数是 PM 的待办数。
- **不带 `branch=/uncommitted=/unpushed=`。** 它们是事件级字段（语义是「`last=` 那一刻的值」），而指针行是 run 级
  摘要；把它们抄进来只会在合并行里显示一个过期瞬间，而 PM 要判断这些时读的是记录行（`see=` 指的就是它）。
- **`knock=` 是 run 级字段。** 叫醒只发生在 run 的第一个事件：`state=new` 才入队，`state=extended` 一律不入队。
  因此合并时**保留已有行的 `knock=`**，不让扩展事件改写它（`×N`、`first=` 已经是同一类 run 级字段）。实现上这是
  `team_notify_line_merge` 的一条附加规则：「若两行都带 `knock=`，取已存在那一行的值」。记录行从不带 `knock=`，
  所以这条规则对记录行的输出逐字节无影响。
- **取值只有两种**：`knock=enqueued`（已交给投递守卫）与 `knock=skipped:<类>`。`enqueued` **不表示已送达** ——
  送达与否由 `state/outbox/delivered.log` 记账，指针行不许声称送达（脏输入框时它是排队）。
- **`detail=unavailable` 标记跟着抄过来**：`team_notify_line_anchor_ok` 因此对指针行同样成立，一个「记录没落盘」的
  事件在 `pm.md` 里也不会被下一个事件吸收掉。
- **`see=` 是常量**（发送者自己的收件箱），所以合并时不需要特殊处理；它同时也是人对得上的那半句话。

**已知退化（写明接受）**：如果一个 run 的**首个事件**指针写失败（§4 的 `pointer=failed`），后续扩展事件写入时会
在一个不存在的锚上起新行，此时该行的 `knock=` 来自扩展事件，即 `knock=skipped:merged`。它不是谎话（PM 的收件箱里
确实没有这个 run 的叫醒记录），而且同一时刻结果账里有首事件的 `pointer=failed` 记录，digest 的两行会分别点名它们。
反向的自我约束：`knock=skipped:merged` **只可能**出现在这种缺口里 —— 正常路径下 `merged` 永远是结果账里的东西，
不是指针行上的值。

## 3 · 只数一遍：记录 vs 流量

判据（一条，唯一实现，放在 `cmd-status.sh` 的收件箱读面）：

> 一条 auto 类行（`[auto]`、`[auto·suspended]`、`[auto·interrupted]`）若其 `agent:<name>` 等于**该收件箱文件自己的席位名**，
> 它是这个席位的**记录**，不进入该文件的未读流量；否则它是流量（`[manual]`、`[draft]`、`[nudge]`、pulse 行一律是流量，
> 指针行因为 `agent:` 是发送者，也是流量）。

为什么是这个方向（而不是「数记录、指针行标成不计数」）：

- 未读计数的用途是回答「**我要处理什么**」。席位自己那份记录不是它要处理的任何事 —— 今天的 `dev3 · 8 条新` 就是
  这个错误判据的直接产物；把指针标成不计数只是给错误的数加一个洞。
- `--ack` 的语义不需要发明：PM 读 `pm.md`、`--ack` 一次标记该文件的行，计数跟着归零。跨文件去重也不需要任何
  身份匹配。
- 数量守恒：一次交付仍然让待办 +1（今天加在 `dev3.md`，之后加在 `pm.md`），巡检看到的 `未读通知 N` 大小不变，
  只是归属变成真的收件人。这条对巡检的唤醒理由没有副作用（`team_pending_text` 只是把各收件人的未读数求和）。

**迁移边界（接受，并写进 delta）**：升级后历史 `[auto]` 行不再计数 —— 它们本来就不是流量；它们仍可用
`team inbox <seat> --all` 读到，指针行**不回填**：补写等于伪造一个从未发生过的落点与一个无法判断的叫醒结论
（`knock=` 的值我们从没观测过），而伪造审计行比缺一行更坏。历史 `[manual]` 行与所有非 auto 行的计数完全不变。

## 4 · settle 的时序，与失败时的顺序

```
1. 扩展写记录行        __inbox-write（不变；返回 state= / first= / key=）
2. 扩展算叫醒结果      今天的六个分支 → outcome = enqueued | skipped:<类>
3. 扩展调              __notify-settle --agent <seat> --outcome <outcome> --record-from-file <同一份行文件>
                                          [--identity line|<key>|<first>] [--task <ID>]
   CLI 内部：  (a) 写/合并 pm.md 的指针行 → pointer=ok|failed
               (b) 追加结果账一行（带 pointer= 字段）
               (c) 打印 pointer=… ledger=…
```

- **先指针、后账本**：账本那一行的用处是「指针没落盘时留下证据」，所以它必须在指针尝试**之后**写，才带得上
  `pointer=failed`。反过来（先记账再写指针）就只能记一个 `pending` 假值或二次改写。两次写之间崩掉的代价只有一个：
  成功写的指针少一条账本记录 —— 而 `pm.md` 里的行本身就是成功的证据，没有任何东西被藏起来。
- **第 3 步失败不改变叫醒、不改变退出**：指针行是旁路，扩展只记扩展日志；绝不回退到 `send-keys`，也绝不因此抑制一次
  已经入队的敲门。
- **为什么指针与账本都由 CLI 写，而不是扩展直接 `appendFileSync`**：`pm.md` 有每收件人一把 `flock`，合并是**截尾重写**，
  两个席位并发 settle 时由 TS 直接写会与合并互相丢写（现有写入侧正是为这件事存在的）；结果账是**有界 + 轮转**的文件，
  轮转实现（`team_notify_detail_append`）已经在 bash 里，TS 再写一份就是第二个格式实现。代价是每次 settle 多一次
  `execFileSync`（毫秒级）；happy path 的进程数从 3 变 4。
- **没有记录行的三种 settle**（`dedup`、`turn-unfinished`、`write-failed`）也给 `--record-from-file` 之外的形态：
  只传 `--agent/--outcome/--task`，于是只写账本、不写指针（没有东西可以指）。`--identity` 传 `-`。
- **边界：在身份守卫之前返回的 settle 不进账本**（`!root`、cwd 不在 worktrees 下、窗口是 PM 窗口、会话不是本项目、
  解析不出席位）。它们不是通知，扩展日志已经点名原因。这条放宽必须写明，因为它是「今天为什么没有通知」的一个真实
  来源（比如席位进程从错误的 cwd 起来）。

## 5 · digest 的两行

放在 `[2] 待处理通知` 段内（段头字面量不动），为 0 时不打印：

```
  未敲门           2 条已记录的通知没有叫醒 PM（suspended 1 · no-tmux 1）—— 见 docs/team/inbox/pm.md 的 knock= 字段
  指针缺失         1 条通知没有写进 PM 收件箱（pointer-write-failed；state/notify-knock.log 当前代）
```

- **未敲门**：从 `pm.md` 里**尚未 ack 的行**里数 `knock=skipped:<类>`，按类分组。它因此是「还没被回答」的量：
  PM 读了并按 `--ack` 标记，数就归零，不需要第二个已读通道，也不需要把账本行与收件箱行做身份匹配。
  一条 run 一行，所以不会把同一条通知数两遍。
- **指针缺失**：账本的**当前代**里 `pointer=failed` 的记录数。它是唯一不随阅读消失的一档 —— 指针行本来就不在
  `pm.md` 里，PM 没有可读可 ack 的东西。轮转之后旧代不再计入（账本的窗口就是它的当前代，这一点在输出里写明）。
- **两行都只显示，不进待办计数。** 若「未敲门」进计数，`[auto·suspended]`（用户 2026-10-14 裁定：只记录、不叫醒）
  就会借这条显示行重新叫醒 PM —— 等于用显示层推翻裁定；若「指针缺失」进计数，一个不会自己消失的故障会让每一拍
  巡检都叫醒一次。指针写失败不丢通知的理由：敲门路径与指针无关，那一次敲门照旧发生（§4），所以 PM 被叫醒；
  如果敲门同时被跳过，结果账与 digest 会把两件事都点名。

## 6 · 结果账：落点、格式、上限

- 路径：`state/notify-knock.log`（`.pi/team/state/`，已在 `.gitignore` 里；`TEAM_STATE_DIR` 优先，与明细同一套解析）。
- 一行一次 settle，字段固定顺序，行首与明细同形（`- <ISO> …`）：
  ```
  - <ISO> seat=<seat> · task=<ID|-> · class=<delivered|suspended|interrupted|-> · outcome=<enqueued|skipped:<类>> · pointer=<ok|failed|none> · identity=<line|key|first|->
  ```
- **闭集**（`outcome` 的 `skipped:` 之后只可能是这些；读侧遇到未知类原样打印，不吞）：
  `suspended`、`merged`、`dedup`、`turn-unfinished`、`write-failed`、`notify-off`、`no-pane`、
  `pm-not-running`、`pm-window-missing`、`enqueue-failed`。
- **上限沿用 `TEAM_NOTIFY_DETAIL_MAX`**（默认 2048），越界把当前文件移到 `state/notify-knock.log.1`（只留一代），
  新文件首行是轮转头（时间、被移动的路径、事件数），轮转在扩展日志里点名。为什么不为它新增一个配置键：技能配置键有
  **四面**必须同时登记（schema 表、模板、`references/config.md`、面板标签），为一个没人会调的界值付这张账不划算；
  两份文件是同一族「本机有界的通知状态」，共用同一个上界与同一个轮转器，读起来也不会分叉。
- `/tmp` 上的 `TEAM_NOTIFY_LOG` **保留为调试日志**（人看现场用），它不再承担「跳过原因的唯一落点」。

## 7 · 不动的东西（逐条点名）

敲门分支与判据、交付守卫（脏框入队、`held`、`duplicate`）、去重窗口 `TEAM_NOTIFY_DEDUP_SEC`、合并键
`(seat, task, class, awaiting 集合)`、`×N first= last=` 的去向、`:: <末消息>` 摘要、`⚠ 未提交` 前缀、
`suspended` 不叫醒的裁定、`state/notify.log` 一事件一记录、`state/outbox/*` 与 `delivered.log`、`--ack` 的基线格式
（`state/<seat>.inbox` 里那个行数）、`[2]` 的段头字面量、面板布局。`team inbox <agent> --detail` 只有一处改动：
合并行的 `×N` 对账改为按**该行自己的合并键**（见 §8），缺口判据本身不放松。

## 8 · 边界与已接受的限度

1. **`team inbox pm --detail` 的对账**：今天的实现只收「属于该文件席位」的明细记录，于是 pm 里一条 `×N` 指针行
   会被判成缺口（假红）。改为按该行自己的合并键取记录（键里第一个分量就是发送者），缺口判据保持不变；「该席位的
   原始记录」那一行改成按文件里实际出现的键列出（每个键点名它的席位）。
2. **`pm.md` 的 `--ack` 粒度是行**：一次 ack 会把当时所有未读指针行进已读，包括同一时刻新到的那条。这是既有语义
   （按行数记基线），本次不发明新的 ack 模型。
3. **两个 run 交错**：`pm.md` 的锚是该文件尾行，席位文件的锚是它自己的尾行。PM 收件箱里插入一条 `[manual]` 行会
   让下一个指针起新行（而记录行照旧合并），两边行数因此可能不同。这是**同一条规则在两个文件上的结果**，不是分叉；
   两个文件各自的自述（`×N` 与明细记录数）都仍然成立。
4. **指针行不保证与记录行同一时刻可见**：中间隔着一次敲门判定（毫秒级）。崩溃窗口里的形态是「记录行在、指针行不在」，
   由结果账的 `pointer=failed`（或压根没有第 3 步 → 也没有账本行）承担后果；本次不引入事务。
5. **历史不回填、计数方向改动的一次性效应**（§3）。
6. **账本不记录身份守卫之前被拒的 settle**（§4 末条）。

## 9 · 红侧（每条都指明「破坏哪一处 → 哪条断言必须红」）

| # | 要求 / 场景 | 红侧（破坏实现 → 断言红） |
|---|---|---|
| R1 | 一次交付在 `pm.md` 落一条指针行 | 删掉 `__notify-settle` 里的指针写入 → `pm.md` 行数为 0 → 红 |
| R2 | 记录行逐字节不变 | 让指针派生改写记录行（例如把 `see=` 也写进记录行）→ 记录行的字节对照红 |
| R3 | 指针行与记录行同一个键、同一套合并 | 指针行不带 `task=` 戳 → 键的 `task` 分量退化 → 两条同 run 事件在 `pm.md` 里变成两行（`×1 ×1`）→ 红 |
| R4 | `knock=` 是 run 级字段 | 合并时取新事件的值 → 首事件 `enqueued` 的 run 被扩展后显示 `skipped:merged` → 红 |
| R5 | 明细不多一条 | 指针写入也调明细追加 → `state/notify.log` 记录数 = 2 × 事件数 → `×N` 对账红 |
| R6 | 一条通知只数一次 | 删掉记录判据 → 一次交付后 `team_pending_text` 的未读通知 = 2 → 红 |
| R7 | 未读归属是 PM | 指针写进 `pm.md` 后 `team_inbox_new pm` 不增长 → 红（R6 的反向配对） |
| R8 | 未敲门分类可见 | 删掉 `suspended` 分支的账本写入 / 去掉 `knock=skipped:` → digest 的「未敲门」行缺失 → 红 |
| R9 | 被阅读就归零 | ack 后 `未敲门` 行消失 → 若不消失红（窗口判据） |
| R10 | 指针写失败被发现 | 把 `pm.md` 的写入改成失败（只读文件）→ 账本 `pointer=failed` + digest「指针缺失」行；删掉这条显示 → 红 |
| R11 | 敲门语义不变 | 既有断言（挂起不敲门、扩展不敲门、去重窗口、`::` 摘要、`⚠` 前缀、一次交付一个条目）原样跑绿；不做新断言 |
| R12 | `--detail pm` 验得动指针行 | 按文件席位取记录的实现下，`team inbox pm --detail` 对一条 `×N` 指针行报缺口 → 红 |

## 10 · 对既有断言的盘点（今天 grep 出来的，apply 要逐条复核）

- `smoke.sh` 的扩展夹具（§M6.3 F17 / M40 / P160）只断言 `docs/team/inbox/dev.md` 的字节与行数、`state/notify.log`
  的记录数 → 指针行写在 `pm.md`，不触及这些断言。夹具会顺手断言 `pm.md` 的指针行（新增，见 `tasks.md`）。
- `smoke.sh:11324`（M9.8-③）用 `team notify dev "…"`（`[manual]`，收件人是 `dev`）证「未读通知进入唤醒理由」→ 手工行
  不是记录，计数判据不变 → 这条断言不动。
- `smoke.sh:15928` 钉住的是 `^\[[0-9]+\]` 段头（`[1]`–`[6]`），`[2]` 段内的新行不影响它。
- `tests/help-surface.sh:815` 有内部命令白名单（`__inbox-write __panel-data`），加 `__notify-settle` 是夹具侧一行；
  它的覆盖检查要求每个内部命令都被点到，新命令必须带自己的那行断言。
- `tests/spec-refs.sh --check`：本 delta 引用的 `docs/team/inbox/pm.md` 与 `docs/team/inbox/<agent>.md` 都已在声明表里
  （`example` 与 `slot`），不需要改表。
