# turn-notice-in-pm-inbox · 通知落在 PM 会读的地方，叫醒只是提醒

## Why

用户报的缺陷是「子任务做好了没有自动通知 pm」。它不是敲门那次按键偶尔丢，而是**记录写进了一个 PM 不读的文件**：

| 现场（本仓，2026-10-22） | 读数 |
|---|---|
| `docs/team/inbox/pm.md` | 3 行，全部 `[manual]`；历史 `[auto]` 仅 2 行 |
| 各席位自己的收件箱 | 当天新增 `[auto]`：`dev3.md` 8 行、`verify.md` 4 行 |
| P362 样本 | `2026-10-22T05:42:38Z` 的 `[auto] agent:dev3 · P362 …` 写在 **`dev3.md`**，同一刻 PM 投递日志有 `sent seq=1275`（那次敲门到了）；**同一条不在 `pm.md`** |

代码位置：`skills/teamsmith/extension/team-notify.ts` 的 settle 调 `team __inbox-write --agent <发送者>`，写入侧
（`skills/teamsmith/scripts/lib/cmd-agents.sh` 的 `team_inbox_write_locked`）把行追加进**发送者自己**的收件箱
（`550005fc` 之前的老实现是同一个判断：`appendFileSync(join(dir, agent + '.md'))`）。

两个后果，合起来才是缺陷：

1. **到达性等于敲门。** 敲门到了 PM 就看得见；敲门被跳过 —— `suspended`、`writeState != new`（合并）、20 秒去重、
   `pane_current_command` 不是 pi、PM 窗口不在、入队失败、以及「回合未完成 + 本轮有 lifecycle 事件」—— 行仍然在磁盘上，
   但它落在**没有任何读者会去捞**的文件里。`team digest` 的「待复验」只能捞回**有报告**的任务，捞不回没有报告的中间进展。
2. **跳过原因只写在内存盘里。** 那些分支只写扩展日志，默认 `TEAM_NOTIFY_LOG=/tmp/teamsmith-notify.log`；本机 `/tmp`
   是内存盘且已被清过，**今天一行都没有** —— 因此「今天跳过了几次、为什么跳」事后无法回答。这不是「日志级别不够」，
   而是证据落在了一个不跨重启的位置。

用户裁定走 **B · 把记录放对地方**：通知与叫醒解耦 —— 敲门只是提醒，记录必须落在 PM 会读的地方。

## What Changes

### 1 · PM 的收件箱里留一条**指针行**，发送者那份逐字节不变

每条 turn-end 通知（发送者不是 `pm` 时）除今天那条记录行之外，还往 `docs/team/inbox/pm.md` 写**一条指针行**：
谁（`agent:<seat>`）、任务（`task=<ID>`/任务 token）、状态类（`[auto]` / `[auto·suspended]` / `[auto·interrupted]`）、
明细在哪（`see=docs/team/inbox/<seat>.md`），以及**这次叫醒的结果**（`knock=enqueued` 或 `knock=skipped:<原因类>`）：

```
- 2026-10-22T05:42:38Z [auto] agent:dev3 · P362 · knock=enqueued · see=docs/team/inbox/dev3.md · task=P362 tip=1a2b3c4d5e6f
```

- 指针行由**写入侧**从记录行派生（同一段代码解析同一行），所以两边的合并键天然一致；合并不变 —— 同一个 run 仍是一行，
  `×N first= last=` 照旧，`knock=` 和 `see=` 不参与键。
- **`knock=` 是 run 级字段**：run 被扩展时保留首个事件写下的值（`×N`/`first=` 已经是这种角色）。理由见 `design.md` §2：
  叫醒只发生在 run 的第一个事件上，让扩展事件把它改写会让这一行说谎。
- 记录行（`inbox/<seat>.md`）**一个字节都不动**：形状、合并键、`:: <末消息>` 摘要、`⚠ 未提交` 标记、`state/notify.log`
  的「一事件一记录」全部照旧。指针行不进明细文件，所以 `×N` 仍然等于该 run 的明细记录数。

### 2 · 「一条通知算一次」：记录是记录，指针才是要读的那条

今天的计数把发送者自己那份 `[auto]` 行也算成「该席位的新通知」（`dev3 · 8 条新`），这就是 PM 侧看到的噪声。改判据：
**一条 auto 类行的 `agent:` 指向该收件箱自己的席位时，它是这个席位的记录，不是它的未读流量**；要 PM 处理的那一份是
`pm.md` 里的指针行。判据只实现一次（`team_inbox_new` / `team_inbox_since` 共用），因此 `team digest` 的待处理通知、
面板的 inbox 块、`team inbox` 的未读清单、`--ack` 的语义**同一个读数**：一次交付让待办 +1，不是 +2。

### 3 · 敲门丢了也要看得见：项目内的结果账 + digest 的两行

- 每次 settle 往 `state/notify-knock.log` 追加**一条**结果记录（ISO、席位、任务、状态类、`outcome=enqueued|skipped:<类>`、
  `pointer=ok|failed`、行身份）。跳过原因是**闭集分类**，未知类原样打印而不是丢弃。文件有界（上限沿用
  `TEAM_NOTIFY_DETAIL_MAX`，越界轮转到 `state/notify-knock.log.1`，只留一代，轮转在扩展日志里点名）——
  与 `state/notify.log` 同一个轮转器，不新增配置键。
- `team digest` 的 `[2] 待处理通知` 多两行（为 0 时不打印）：
  - `未敲门 N 条已记录的通知没有叫醒 PM（suspended 2 · no-tmux 1）` —— 从 `pm.md` 里**尚未 ack 的指针行**里读
    `knock=skipped:<类>`。所以它是「还没被回答」的量：读了并按 `--ack` 标记就消失，不需要第二个已读通道。
  - `指针缺失 M 条通知没有写进 PM 收件箱（pointer-write-failed）` —— 从结果账的**当前代**读。这一档是**唯一**
    不会自己消失的：它意味着指针行没落盘，只能靠账本点名。
- 这两行**只显示**，不进入巡检的待办计数 —— 否则「挂起只记录不叫醒」（用户 2026-10-14 的裁定）会被这条显示反悔。
  理由与前一个边界见 `design.md` §5。

### 4 · 敲门语义不动

`suspended` 只记录不叫醒；交付与中断照旧敲门；去重窗口、合并键、`:: <末消息>` 摘要、`⚠ 未提交` 标记、投递守卫
（脏输入框入队而非打字）、`state/outbox/delivered.log` 的记账全部不变。本次**没有**新增叫醒路径，也没有让任何
被跳过的通知变得会叫醒。

## 选项与取舍

**B 已由用户选定**，下面是同一目标下真正被考虑过、又被否掉的四条，以及两条我必须在提案里定下来的口径。

| 选项 | 做法 | 为什么否 |
|---|---|---|
| A · 扩展再调一次 `team notify pm` | 把同一条摘要投给 `pm.md` | 同一条通知有两条独立写者与两个敲门身份：`pm.md` 行会因 `TEAM_NOTIFY_DEDUP_SEC` 与自己的敲门去重打架（要么重复敲门、要么其中一份被吞），而且它把「记录」变成「又一条手工通知」，`[auto]` 的合并与明细都会分叉 |
| C · digest 合成一个 PM 视图 | 扫所有 `inbox/*.md` 的 `[auto]` 行，在 `[2]` 里汇总成一段 | 记录仍不落在 PM 读的文件里；`--ack` 要跨文件发明语义（哪一份已读？），面板与巡检各要一份同样的合成逻辑 —— 等于用显示层掩盖写入层 |
| D · 让 `pm.md` 指向发送者的文件 | 软链 / 硬链 | 同一行内容 `agent:<seat>` 会指向错的那个席位，`--ack` 的基线成了共享行号；硬链还让「逐字节不变」不成立 |
| E · 只把跳过日志从 `/tmp` 搬到 `state/` | 修第 2 个后果，不修第 1 个 | 记录仍然不在 PM 读的地方；一个没人主动去查的日志不能替代「打开收件箱就看得见」 |

**口径 1 · 数哪一份**：两份候选是「数发送者那份记录，指针行显式标成不计数」与「数指针行，记录不计数」。选后者：
计数应该回答「**我要处理的东西**」，而席位自己那份记录不是它要处理的任何事（`dev3 · 8 条新` 今天就是这么来的）；
反过来，PM 的未读数直接就是指针行数，`--ack` 一次回答一条 run。代价必须写明：升级后历史 `[auto]` 行不再计数
（它们本来也不是流量），**不回填**历史指针行 —— 补写等于伪造从未发生过的落点与叫醒结论（`design.md` §3）。

**口径 2 · `knock=` 写在哪**：候选是「写在指针行的字段里」与「只写进结果账，digest 自己去对身份」。选字段：
PM 打开 `pm.md` 就能看到每条通知是否叫醒过，而 digest 的「未敲门」也因此只需要数**未 ack 的行**，
不需要把 `state/notify-knock.log` 的行身份与收件箱行做身份匹配（那需要另一套匹配规则和它的红侧）。
结果账仍然保留 —— 它是跨 ack、跨轮转之后唯一还能回答「今天跳过几次、为什么」的东西。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `notify-and-inbox#A turn-end notification appends one inbox line and knocks once` —— 增加指针行与「一份计数」判据；
  knock / suspend / 去重段落一字不改（delta 里未改的段落与基线逐字节相同）。
- `notify-and-inbox#A turn-end notification's raw events stay in a bounded detail file` —— 合并行的 `×N` 对账改为按
  **该行自己的合并键**（指针行属于发送者的 run，`team inbox pm --detail` 才验得动它，而不是报一个假缺口）。
- `notify-and-inbox#A notice whose knock was skipped is recorded with its reason and named by digest`（新增）。

## Impact

**改动的文件（apply 写集，逐条明授）**

- `skills/teamsmith/scripts/lib/cmd-agents.sh`：`team_inbox_write_locked` 拆成「明细 + 合并/追加」两步（行为不变），
  新增指针行派生与合并（复用 `team_notify_line_key` / `team_notify_line_merge` / `team_inbox_rewrite_last`），
  `team_notify_line_merge` 加一条只对指针行生效的 run 级字段规则（`knock=`），新增结果账写入（复用
  `team_notify_detail_append` 的轮转器），新增内部命令 `__notify-settle`。
- `skills/teamsmith/scripts/team`：内部命令分派一行（`__notify-settle`，不进 help）。
- `skills/teamsmith/scripts/lib/cmd-status.sh`：收件箱计数判据（记录 vs 流量，单一实现）、`[2]` 的两行、
  `team inbox <agent> --detail` 的按行键对账。
- `skills/teamsmith/extension/team-notify.ts`：把 settle 尾巴改成「先算叫醒结果，再交给 `__notify-settle` 记账并写指针」；
  指针写失败只记日志，不回退打字、不改变叫醒。
- `skills/teamsmith/references/protocol.md` §4：指针行、`knock=`、结果账与 digest 两行的生效口径（不留第二份）。
- `skills/teamsmith/tests/help-surface.sh`：内部命令白名单加 `__notify-settle`（`__` 命令不进 help 的那条清单）。
- `skills/teamsmith/tests/smoke.sh`：本 change 的红侧（见 `tasks.md` §3）。
- `openspec/changes/turn-notice-in-pm-inbox/**`（本文件、`design.md`、`specs/notify-and-inbox/spec.md`、`tasks.md`）。

**不做的事**

- 不新增配置键（结果账的上限沿用 `TEAM_NOTIFY_DETAIL_MAX`，理由见 `design.md` §6）、不新增叫醒路径、不改投递守卫、
  不改 `state/notify.log` 与合并键、不动 `--ack` 的基线格式、不回填历史指针行、不改面板布局与 `[2]` 的段头字面量。
- 不修「敲门的可靠性」本身：本次不改变任何敲门分支的判据，只让每次 settle 的结果可读。用户报的「没有自动通知」
  在本次之后仍然要靠「打开 `pm.md` 看得见 + digest 点名」被发现，而不是靠敲门保证 —— 这是解耦的本意。

**验收口径（propose 阶段）**：`openspec validate --all --strict`（本机门禁镜像）、
`bash skills/teamsmith/tests/spec-refs.sh --check`、`git diff --check`、`git status --short`。
apply 阶段的红侧逐条写在 `tasks.md`，每条都指明「破坏哪一处 → 哪条断言必须红」。

**顺序**：本 change 拆成两次 apply 派单（写入面 A1 → 结果账与显示面 A2），理由与序见 `tasks.md` 的 §0；verify 由
未写过 apply 的席位做定点执行，`spec-refs.sh --flips` 与本 change 的红侧表各跑一次。
