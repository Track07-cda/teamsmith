# turn-notice-merge · 设计

## Context

动机、用户口径与范围见 proposal 与任务书（`docs/team/tasks/P250-turn-notice-merge-propose.md`，C-1 已由用户
2026-10-14 采纳）。以下是本轮读取的基线事实（均为当前磁盘状态，不是待实现能力）：

- **通知的写入点**：`skills/teamsmith/extension/team-notify.ts` 的 `agent_settled` 路径。去重键在 `:517`
  （`agent|tag|summary|revStamp|len:fp`，窗口 `TEAM_NOTIFY_DEDUP_SEC`，`isDuplicate` 在 `:360`）；行文本在
  `:530` 生成、`:534` 用 `appendFileSync` 直接追加；knock 在 `:558-565` 经 `outbox enqueue --kind knock
  --dedup <key>` 入队、`:577` 做一次有界 flush。扩展没有「上一条同类行」的概念。
- **未读数 = 行数**：`team_inbox_new`（`scripts/lib/cmd-status.sh:31`）= 总行数 − sidecar `state/<seat>.inbox`
  的 ack 基线；`team_cmd_inbox`（`:925`）按行打印与 ack；`team digest` 的 `[2] 待处理通知`
  （`:770-777`）逐收件人计数并印 `tail -3`；面板的 `team_panel_inbox_json`（`cmd-watch.sh:1121`）用
  `grep -c .` 数行、mtime 做年龄、尾行做摘要。**合并行天然只算一行**，这些读者不需要改计数口径。
- **手工路径**：`team_inbox_append`（`scripts/lib/cmd-agents.sh:1646`）是 `printf … >> "$dir/$1.md"` 的朴素
  追加；`team notify`/`team say` 的 `[manual]`、草稿与 pulse 的行都从这里落盘。它是唯一与扩展并列的
  收件箱写入者，因此合并的原子性要与它协商（决策 4）。
- **既有合同**：`openspec/specs/notify-and-inbox/spec.md:10` 的
  `A turn-end notification appends one inbox line and knocks once` 已经定下：一行一事件、去重窗口、
  `task=<ID> tip=<12-hex>` 修订标识、陈旧判据（`:123`、`:138` 的场景）、`[auto·suspended]` 与
  `awaiting=`（P230/long-job-suspend 刚加的）。本变更只改它，并把原始事件明细立成一条新要求。
- **叫醒键的教训**：P174（`openspec/changes/archive/2026-10-03-pulse-nudge-key`）把巡检提醒的键从
  「计数向量」改成「稳定的类别集合」，计数抖动不再叫醒、类别变化立刻叫醒。本变更的叫醒判据照抄这个方向，
  但键不同：这里的分量是（席位、任务、状态类、`awaiting` 集合）。
- **夹具落点**：通知面的现成入口是 `skills/teamsmith/tests/bg-ledger.sh` 与 `bg-ledger-harness.mjs`
  （`--notify <extension/team-notify.ts>`，`newNotify().settle(cwd, stopReason, text)` 直接驱动真扩展，
  `inboxLine()`/`makeBase()`/`writeRecord()` 造现场），挂起面的 `suspend-shape`/`owner-scope` 与 `flip`
  组正在用同一套机制。合并/明细/叫醒三组加在这里，复用它的身份隔离、反向守卫与 scratch 变异翻转。

## Goals / Non-Goals

**Goals**：把「同一 run 的重复通知合成一行、原始事件一条不丢」写成可证伪的合同；让合并对既有读者
（未读计数、面板、ack、陈旧判据）**零改写**；让叫醒只跟着「行」走而不是跟着 settle 走；让明细的
缺失/轮转/写失败都可见。可观察边界只在本 change 的两条 delta 里定义。

**Non-Goals**：不改敲门的传输与投递守卫；不改巡检叫醒键；不改派单/路由/账本写入与 `team reply`；
不做读侧合并（那既不缩小文件也不降低未读数，见决策 1 的替代方案）；不新增页面；不改 `--print`/`--json`。

## Decisions

### 1. 合并发生在**写入侧**，明细是兜底

通知的写入者（扩展）在追加前决定「扩展末尾的同类行」还是「新起一行」，同时把**每条**原始事件追加到
`state/notify.log`。为什么不是读侧合并（digest/面板渲染时折叠）：未读数是**文件行数**的函数
（决策 Context），读侧折叠不会缩小文件与未读数；ack 基线是行号，读侧折叠会立刻把 ack 语义搞成
「折叠键的已读状态」，且文件仍会无限增长。写入侧合并 + 明细文件同时解决了「噪声」与「证据」两件事。

### 2. 合并键的四个分量与规范化

| 分量 | 取值 | 规范化 |
|---|---|---|
| 席位 | 解析出的发送者（`agent:<name>`，也是收件箱文件名） | 逐字；不同席位天然不共文件，键里仍保留它（跨席位不合并是**定义**的一条） |
| 任务 | 行里的 `<ID>` token（有 `task=` 戳时就是戳里的 ID） | 逐字；没有任务标识的行取「无任务」这个独立值（不与任何 `task=` 值相等） |
| 状态类 | 标签：`[auto]`→`delivered`、`[auto·suspended]`→`suspended`、`[auto·interrupted]`→`interrupted` | 由标签派生，不读摘要、不读 `⚠` 前缀 |
| `awaiting` 集合 | `awaiting=` 字段的 ids | 按 `,` 切、去空白、去重、排序（顺序不改变键）；**字段缺失**与**空集**是不同的值 |

键是本变更唯一的「同类」判据；`branch`/`tip`/`uncommitted`/`unpushed` **不进键**（它们变化只更新显示值），
`⚠` 前缀也不是键的一部分。

### 3. 合并行的形状

- 首条事件：与今天逐字节相同的行（没有 `×`、`first=`、`last=`）。这一条是兼容性承诺：不打断挂起面
  既有夹具与读者的任何断言。
- 汇总 ≥2 条后：**取最后一条事件的行**，只做两处修改 —— ① 行首时间戳换成 run 的首事件时间（行的身份与
  年龄稳定，knock 的行身份也用它）；② 在 ` :: ` 之前的字段区插入 `×N first=<ISO> last=<ISO>`。
  于是 `branch=`/`uncommitted=`/`unpushed=`/`tip=` 与 `⚠` 前缀**自动**是最后一条的值，不需要另一套
  「取最后一条」的代码路径，也不会有合成值。
- `×N` 是给人看的显示（用户口径「显示 ×N」），`first=`/`last=` 给机器解析；三者都只出现在汇总行上。

### 4. 尾行锚 + per-recipient 锁

合并只认收件箱的**最后一行**：键相同才重写它，否则追加新行。理由：

- 重写文件中间的行要么整文件重写（与并发追加抢尾巴 → 可能吞掉别人的行），要么复杂化锚的定位；
- 尾行锚让「重写」退化成「截掉最后一行再追加」，落点单一、可证明；
- 代价是 `[manual]`/别的 run 的行一旦插在中间就结束本 run（多一行），原始事件仍在明细里，
  `--detail` 仍能把两条同键 run 各自的窗口分开列出。

原子性由**每收件人一把锁**保证：收件箱的两个写入者（`team_inbox_append` 与合并路径）都在同一把锁内
做「读尾行 → 判定 → 截尾/追加」；扩展不自己 `flock`（Node 没有原生 flock），走 `scripts/lib` 的写入入口，
锁与写在一起。写入失败/锚校验不过时**追加新行**（fail-safe，绝不重写不是自己的尾巴）。

### 5. 明细文件

- 格式：一行一事件，内容就是该事件在单发形状下的收件箱行（`- <ISO> <flag><tag> agent:<seat> · …`），
  便于 `grep` 与对照；不含合并装饰。
- 顺序：**先明细、后合并判定**。于是「`×N` = 该 run 在明细里的记录数」是不变量；明细写失败时该事件
  不参与合并（决策 8）。
- 上界与轮转：`TEAM_NOTIFY_DETAIL_MAX`（默认 2048 事件）。越界时把当前文件搬到 `state/notify.log.1`
  （覆盖上一代，只留一代），新文件首行写轮转头（轮转时间 / `state/notify.log.1` / 搬走事件数）。
  轮转同时记进扩展日志（`TEAM_NOTIFY_LOG`）。
- 读面：`team inbox <agent> --detail` 打印当前代中该席位的原始记录 + 读到的文件路径与是否轮转代，
  并对该席位每条合并行核对 `×N` 与找到的记录数；缺文件或记录不全 → 点名缺口与 `state/notify.log.1`、
  非零退出。该标志只读，不 ack。**为什么不新造一个命令**：明细是收件箱行的证据，读它的人已经在
  `team inbox` 上。
- 局部性：`state/` 是本地被忽略的账本区，明细文件不进收件箱、不发布、不是唤醒源。

### 6. 叫醒：跟着「行」走

- 判定顺序：扩展先做今天的守卫（非 worktree/PM 窗口/发送者解析）与去重窗口；通过后调用写入入口。
  写入入口返回「新行」还是「扩展」；**只有「新行」才入队 knock 并做一次有界 flush**。
- 合并的 settle **不入队、不敲字**：计数抖动看得见（行与明细）但不叫醒。
- 状态类变化是键变化 → 必然新行 → 必然叫醒（用户口径「状态类一变立刻新起一条并叫醒」）。
- knock 的去重身份 = **行身份**（席位、合并键、首事件时间）。今天用的是「摘要指纹 + 修订戳」，两条
  文本相同但不同的行会被它吞掉；换成行身份后，独立的行不会互吞，而同一个 run 的重复 settle 也绝不会
  二次敲门（此时它连条目都不入队）。
- 写盘失败的 settle 不叫醒：这是手工路径既有的规则（`notify-and-inbox` 的
  `A manual notification is attributed to its sender, not its recipient`：写失败不得授权唤醒）在扩展路径上的
  对齐，不是新语义。它同时避免「敲门声称有一行、行却不在」的假绿。

### 7. 既有读者与陈旧判据

- **未读计数/digest/面板/ack**：合并行是一行。`team digest` 的 `[2]` 印的是行本身（含 `×N`），
  面板尾行同理；`--ack` 记的是行数，所以「已读行被后续同类事件扩展」不会重新变成未读（行数没变）。
  这三处**不改一行代码**，由 delta 的场景钉住行为。
- **陈旧判据**：合并行的 `task=`/`tip=` 是最后一条事件的，`last=` 点名它；判据照旧（board done/closed 或
  reviews 记录的 HEAD 与 tip 互为前缀）。行的字段**只描述最后一条事件**，不是席位当前状态 ——
  更早的事件去明细里读。这一条把「合并行不得冒充当前状态」写成可证伪的判据。

### 8. 与去重窗口、挂起判定、手工路径的关系（明确不动）

- `TEAM_NOTIFY_DEDUP_SEC` 窗口内的重复 settle 仍是**同一事件**：既不进明细、也不推进 `×N`、也不叫醒。
  写入顺序是「守卫 → 去重 → 明细 → 合并」，窗口的语义逐字不变。
- 挂起判定（P230/P236 的车道目录、活体指纹、`cwd` 归属）与 `awaiting` 的**取值**逐字不变；`awaiting`
  只是被额外用进键。
- `[manual]`/`[draft]`/`[nudge]`/pulse 行：不合并、不进明细、叫醒照旧；它们插在中间时只是结束 run
  （决策 4），本人不被改写。
- 明细写失败时行上的 `detail=unavailable` 是**新增字段**，旧读者不认识也无妨；它只出现在单事件行上
  （失败的事件不合并，且这个标记本身也不做后续事件的锚 —— 否则下一次成功的事件会把失败的标记从行上
  抹掉，缺口就不可见了）。

### 9. 被否决的替代方案

| 方案 | 否决理由 |
|---|---|
| 读侧合并（digest/面板折叠显示） | 文件与未读数不变；ack 基线是行号，折叠键的已读语义要另立一套（决策 1） |
| 按时间窗合并（同席位数分钟内一律合并） | 会把状态类变化也吞掉，正是 P174 治过的病；合并没有语义依据 |
| 摘要文本拼接成多行 | 行会无限变长，读者要解析不定长正文；明细已经承担了全文 |
| 只保留计数、原始事件不进盘 | `×N` 没有任何记录可核对，写失败/轮转无从判定（proposal 的红侧正是冲它） |
| 计数放 sidecar、行上不显示 | 用户口径是行上「显示 ×N 加首末时间」；sidecar 还要处理丢失/漂移 |
| 穿行合并（重写非尾行） | 与并发追加抢尾巴，需要另一套原子协议；收益只是打断后少一行（决策 4 的裁定点 1） |
| 把 merge 逻辑放进 CLI、扩展不参与 | 叫醒决策需要立刻知道「新行还是扩展」，扩展才是 writer；键的解析若复制两份会漂移，所以写入入口由 CLI 侧实现、扩展只消费结果 |

### 10. 夹具与红侧的落点

- `bg-ledger-harness.mjs` 增三组：`merge`（键/形状/最后一条值/尾行锚/单事件逐字节）、`detail`
  （记录一致/轮转/上界/缺口可见/不进收件箱）、`wake`（新行恰好一条 knock/合并零条目/行身份去重/写失败零条目）。
  它们用现成的 `makeBase`/`writeRecord`/`newNotify().settle`，并需要两条夹具能力：
  ① 键的 `awaiting` 由**真实作业记录**产生（同一批 id 用不同枚举顺序的锚行由夹具预置）；
  ② 写入入口的临界区内可被夹具暂停（sentinel 文件 + 超时），用来证明并发追加不丢行。
- `bg-ledger.sh` 的 `flip` 组按现有 `flip_mut`/`expect_red` 机制逐条破坏：去掉键比较（必红：
  「A run of same-key notifications is one line with its window」）、跨类合并（「A state-class change…」）、
  取第一条的值（「The merged line carries the last event's values」）、每 settle 叫醒（「Count churn does
  not wake」）、静默失败的明细写（「A failed detail write is visible and never merged」）、`--detail`
  的空输出通过（「A missing or rotated record is named, not silent」）。变异文件必须与真扩展同深度
  （或让 harness 显式拿到 `scripts/team` 的路径），否则 knock 断言会因为找不到 CLI 而假红 —— 这一条
  写进 tasks 的前提检查。
- 单事件行的兼容性由既有 `suspend-shape`/`owner-scope` 与 smoke §13/§13b 的逐字节断言守着，不另造。

### 落点与任务书头字段

任务书头写 `specs: notify-and-inbox`、`deltas: notify-and-inbox`，本设计落在同一处：一条 MODIFIED
（通知的写入与叫醒要求）+ 一条 ADDED（明细文件）。`delivery-guard`、`panel`、`watchdog` 均不动 ——
叫醒的传输、面板的计数口径与巡检的提醒键都不变（决策 6/7）。

## Risks

- **合并掩盖单条摘要**：行只留最后一条摘要。这是用户口径（兜底是明细文件），明细与 `--detail` 是补偿；
  若 PM 需要「行上保留前几条摘要」，那是换合同，要重新走提案。
- **轮转丢更早的原始记录**：一代轮转的边界是设计选择（裁定点 2）；缺口被 `--detail` 点名，不静默。
- **锁的开销**：每次 settle 多一次 CLI 调用与一次锁；settle 频率是个位数每分钟，可忽略。
- **并发夹具的稳定性**：临界区暂停用 sentinel + 超时，跑不动时**响亮跳过并点名**（不许假绿），
  与 inbox-watch 的 `TEAM-IW-CASE SKIP` 同形。
- **误伤既有夹具的逐字节断言**：单事件行逐字节不变是第一优先；任何形状变化都要先在 smoke §13/§13b
  的既有断言上取证。
