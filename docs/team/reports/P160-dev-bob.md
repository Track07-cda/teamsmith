# P160 · `meeting-liveness` 返工：三条缺陷的红→绿（排队敲门补账本 / 标识固定 12 位 / 只有证明得了的任务分支才盖 `task=`）

agent: dev-bob   status: done   time: 2026-10-02
branch: `task/P160-rework`（local 模式：分支留在本地工作树，**未 push**）   PR/MR: -
change: `meeting-liveness`（phase `apply` 的返工；`deltas: notify-and-inbox`（主）、`meeting`（F1 那一行））
基线：`main@aa787487e3feb5462fd5509f153edc3aa1cfd359`（`git merge-base HEAD main`）→ 门禁证据对应 **978a453d**（代码 tip），报告与原始日志随后落在一个只动 `docs/team/reports/**` 的提交里

> 三条缺陷来自 `P153-verify` 的独立验证（F1/F2/F3）。PM 的裁断写在任务书里，其中 F2 **改掉了 P139 的
> 原裁断**：宽度固定 **12 位十六进制**（不是 7 位），两个发送方自己截、不受 `core.abbrev` 影响，接收方
> 按同一语义比较。F4（P153 提到的、与本变更无关的全量红）不在本任务范围，见 §7。

## 0. 交付物一览

| 缺陷 | 形状（红） | 修法 | 红→绿证据 |
|---|---|---|---|
| **F1** | 排队后由排水投递的敲门**没有** `knocks.log` 行 —— `cmd-meeting.sh` 只在「立即投递」分支写账本，`outbox.sh` 投递完只写通用投递日志 | 账本收敛成唯一写者 `team_meeting_knock_ledger_record`；条目带 `meeting-ledger:` 头（`<slug>\t<turn>\t<peer_proj>\t<intent>`），**投递确认后**由 `team_outbox_record_delivery_receipt` 补记同一轮次（三条投递路径各一处调用） | §56 三条 + flip 红面 2 条 ✗ |
| **F2** | `git rev-parse --short HEAD` 服从 `core.abbrev` 与对象数：同一个 HEAD 在 CLI 与扩展两处盖出 7 / 8 / 12 位不等的拼写，`(task, tip)` 字面相等不再能指认同一个 revision | 两个发送方都取**全量 HEAD 的前 12 个十六进制字符**（`cut -c1-12` / 扩展的 `TIP_WIDTH = 12`）；接收方判据写进规格：记录里的 HEAD 与 tip **互为前缀** = 同一个 revision（`team review` 今天写 9 位，手写记录可能记全 40 位） | §55 / §13 / §12b-i + flip 红面 4 条 ✗ |
| **F3** | 空闲席位分支 `agent/<seat>` 编造 `task=<seat> tip=<hash>` —— 通知把一个不存在的任务指成证据 | 只有 `task/<ID>-…` **且** ID 真的存在（`state/<agent>.env` 的 `task=`、看板行、任务书之一）才盖；推不出来（`agent/*`、保护分支、detached、工作树外的手工 notify、无证据的 ID）**什么都不盖** | §55 / §56 / §13 + flip 红面 3 条 ✗ |

## 1. Deliverables（改了什么）

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-meeting.sh` | 新增唯一写者 `team_meeting_knock_ledger_record <slug> <turn> <proj> <sender> <intent>`（会议目录不在就什么都不写）；`team_meeting_knock` 把轮次凭据交给投递层（`--meeting-ledger`），立即投递分支改调该写者 |
| `skills/teamsmith/scripts/lib/outbox.sh` | `--meeting-ledger` 字段入条目头；`team_outbox_record_delivery_receipt <entry>`（只有 `kind=meeting-knock` 且带凭据才动，账本写失败只 warn、不改投递结论）；三条**投递确认**路径（pi 监视通道 / 守卫 tmux 通道 / `--now` 强制）各调用一次 —— 排队、`held`、失败都不写 |
| `skills/teamsmith/scripts/lib/cmd-agents.sh` | `team_notify_task_proven <sender> <id>`（state/看板/任务书三处证据）；`team_notify_rev_stamp` 改成「`task/*` 分支 + 证据成立 → `task=<ID> tip=<全量 HEAD 前 12 位>`」，`agent/*` 一律不盖 |
| `skills/teamsmith/extension/team-notify.ts` | 同一契约的扩展侧：`TIP_WIDTH = 12`、`hasTaskEvidence()`（state/看板/任务书）、只认 `task/*` 分支 |
| `skills/teamsmith/references/protocol.md` §4 | 通知标识的规则：12 位 wire 形状、证据要求、接收方判据（互为前缀） |
| `skills/teamsmith/references/meeting.md` | 排队敲门的账本语义：投递确认时记同一轮次；入队不写共享区；接收方的 stale 判定两条路同源 |
| `openspec/changes/meeting-liveness/specs/notify-and-inbox/spec.md` | MODIFIED 需求 + 新增两个场景（同一 HEAD 两种 `core.abbrev` → 逐字节相同的 12 位；空闲席位分支不盖）；stale 场景改成「互为前缀」 |
| `openspec/changes/meeting-liveness/specs/meeting/spec.md` | MODIFIED 需求 + 新场景：排队后被排水投递的敲门在**投递时**记下同一轮次 |
| `openspec/changes/meeting-liveness/{design.md,proposal.md,tasks.md}` | D10 与 R2 行按裁断改写；tasks.md 新增 §8（三条缺陷各自的修法与红→绿证据） |
| `skills/teamsmith/tests/smoke.sh` | §47/§55/§56/§12b-i/§13 的夹具与断言（详见 §6） |
| `skills/teamsmith/tests/flip-p160.sh` | 翻转包：把本树的 smoke 前导段 + 55/56 段逐字节取出来，只把 `SKILL_DIR` 指向被测树；红面（基线树）必须红在 F1/F2/F3 上，绿面（本树）必须全绿 |

## 2. F1 · 排队后被投递的敲门补上同一轮次的账本

**形状（P153 的 F1）**：`knock` 在对方输入框有草稿时走 `queued`（这是对的：共享区零写入的承诺不破），
但排水真正投递之后没人补 `knocks.log` —— 接收方按 `read/<project>.seq` 判 stale 的那条路于是缺了一行，
P153 的 `priority-drain.txt` 直接量到「投递了但 `knocks.log` 不存在」。

**修法**：账本只有一个写者（`cmd-meeting.sh`），投递确认由投递层回执触发（`outbox.sh`）。
条目头里带 `<slug>\t<turn>\t<peer_proj>\t<intent>`，发送者取条目自己的 `from:` 字段，时间戳是**实际投递**
的时刻；`--now` 强制路径沿用既有 `delivered: forced` 的语义（那一条本来就在 `forced.log` 里留审计）。

**红→绿（原始输出）**

红（基线树，`flip-p160.sh` 红面；本节引的是首跑 `logs/50-flip-firstrun.log`，终跑的同一组行在 `pkg/red.log`，
哈希因夹具每次新建提交而不同）：

```text
      ✗ P160 F1 the delivered queued knock is recorded with the same turn（…/meetings/m-tmux/knocks.log 中没有匹配 [knocked beta by alpha intent=info \[meeting:m-tmux#1\]]）
      ✗ P160 F1 the queued knock is recorded exactly once（期望 [1]，实际 []）
```

绿（本树）：§56 里三条断言全绿，且入队那一刻仍然零写入：

```text
  ✓ P160 F1 enqueue writes the turn nowhere in the ledger (not yet delivered)
  ✓ P160 F1 the delivered queued knock is recorded with the same turn
  ✓ P160 F1 the queued knock is recorded exactly once
```

## 3. F2 · 标识宽度固定 12 位，接收方按同一语义比较

**形状（P153 的 F2）**：`cmd-agents.sh:1536` 与 `extension/team-notify.ts:299` 都用
`git rev-parse --short HEAD`；同一 HEAD 在 `core.abbrev=7` 与 `=12` 下盖出 `77a8fb9` 与 `77a8fb954c7e`
（P153 的 `notify-same-head.txt` 是原始证据，连本仓库默认的 `--short` 都返回 8 位）。

**修法**：两个发送方都 `rev-parse HEAD` 后自己截前 12 位（`cut -c1-12` / `TIP_WIDTH`），wire 形状与 Git
配置无关。接收方的判据（规格 + `protocol.md` §4）：记录里的 HEAD 与 tip **互为前缀**就是同一个 revision
—— `team review` 今天写 9 位、手写记录可能记全 40 位，两个方向都要认；12 位的 wire 形状让这条判定不再
随 Git 设置漂移。

> 复核过基线：`git show aa787487:skills/teamsmith/scripts/lib/cmd-agents.sh` 第 1542 行
> `rev-parse --short HEAD`（P153 记的 1536 是它当时的行号），扩展侧同一形状在 `team-notify.ts:299`。

> 取舍：没有顺手把 `team review` 记录里的 HEAD 也改成 12 位。那会动 M9.5 的「记录绑定」契约与它 10 余条
> 钉住 9 位形状的断言，而对判定本身没有增益（互为前缀的判据本来就覆盖 9 位记录）。规格因此**明写**
> 「记录可以是 9 位、也可以更长」，而不是让读者以为两边必须同宽。

**红→绿（原始输出）**

红（基线树；取自 `logs/50-flip-firstrun.log` / `pkg/red.log`）：

```text
      ✗ P160 F2 same HEAD under core.abbrev 7 and 12 yields a byte-identical tip（期望 [77a8fb954c7e]，实际 [77a8fb9]）
      ✗ P139 3.5 inbox 行带 task=<ID> tip=<12-hex>（…中找不到 [task=P9 tip=77a8fb954c7e]）
      ✗ P139 3.5 knock 载荷带 task/tip（…里找不到 [task=P9 tip=77a8fb954c7e]）
      ✗ P139 3.5 通知的 knock 载荷逐字投递（…里找不到 [task=P9 tip=77a8fb954c7e]）
```

绿（本树，`--select 47,55,56,12b-pi,13` 的原始行）：

```text
  ✓ P160 F2 same HEAD under core.abbrev 7 and 12 yields a byte-identical tip
  ✓ P160 F2 the tip width is fixed at 12 (does not follow core.abbrev)
  ✓ P160 F2 the tip is the first 12 characters of the full HEAD
  ✓ P82 1.2 worker 行的修订标识 = 分支 ID + 工作树 HEAD 前 12 位（P139）
  ✓ 12b-i 扩展的敲门载荷带 task/tip（R2，task/T1.1-smoke-task）
```

## 4. F3 · 只有证明得了的任务分支才盖 `task=`

**形状（P153 的 F3）**：`agent/dev` 这类普通席位分支（没有 `state/dev.env`、没有任务书、没有看板行）
也会盖 `task=dev tip=459596c`；P153 的 `notify-idle-inbox.txt` 是原始证据。

**修法**：`team_notify_task_proven`（CLI）与 `hasTaskEvidence`（扩展）用同一组判据 —— `task/<ID>-…` 的
`<ID>` 必须在 `state/<agent>.env`（`task=<ID>`）、看板行或任务书里存在；`agent/*`、保护分支、detached
工作树、工作树外的手工 notify 一律不盖。**fail-closed**：证明不出来就没有标识，绝不按分支名或席位名编造。

**红→绿（原始输出）**

红（基线树；取自 `logs/50-flip-firstrun.log` / `pkg/red.log`）：

```text
      ✗ P160 F3 an idle seat branch stamps no task= (nothing invented)（不该出现 [task=idle]）
      ✗ P160 F3 function level: the revision stamp of agent/idle is empty（期望 []，实际 [task=idle tip=e953d3b]）
      ✗ P160 F3 an idle seat branch stamps no task= into the knock payload（不该出现 [task=]）
```

绿（本树）：§55 的 inbox 行与函数级、§56 的 knock 载荷三条全绿：

```text
  ✓ P160 F3 an idle seat branch stamps no task= (nothing invented)
  ✓ P160 F3 function level: the revision stamp of agent/idle is empty
  ✓ P160 F3 an idle seat branch stamps no task= into the knock payload
```

**反向（真任务分支必须有标识）**：§47 的 P82 夹具是一个**合成**的任务分支（自己 `worktree add -b`，
没有 state/看板/任务书）—— F3 落地后它拿不到标识，第二次门禁因此红了这一条（`logs/56-secondrun-p82-fail-closed.txt`）。
这正是 fail-closed 要的形状：夹具随后补上 P82 的任务书（dispatch 必留的那个证据），反向随之成立。

## 5. 门禁（本次 revision 上的原始输出）

容器：`localhost/teamsmith-gate:local`（`--rm --pid=host --cgroups=enabled --userns=keep-id`，`HOME=/tmp`），
被测树是本地克隆 `/tmp/p160-gate/final`（**独立 checkout**，`git status --porcelain` 干净），原始日志在
`logs/`，一行未删。

| # | 命令 | 结果 | 原始日志 |
|---|---|---|---|
| 1 | `openspec validate --all --strict` | **rc=0** · `Totals: 20 passed, 0 failed (20 items)` | `logs/10-openspec.log` |
| 2 | `smoke.sh --select 47,55,56,12b-pi,13` | **rc=0** · `== 选段结果 ==  ✓ 666  ✗ 0`（没跑的 104 个键在日志尾行点名） | `logs/20-select.log` |
| 3 | `TEAM_SMOKE_FAST=1 smoke.sh` | **rc=0** · `== 结果 ==  ✓ 3445  ✗ 0` · 账本自查一致（SKIP 36 个真进程段，日志尾行逐个点名） | `logs/30-fast.log` |
| 4 | `smoke.sh`（全量） | **rc=0** · `== 结果 ==  ✓ 4175  ✗ 0` · `账本自查：119 段收口 · 增量 ✓4175 ✗0 SKIP3 ｜ 结果行 ✓4175 ✗0 —— 一致` | `logs/40-full.log` |
| 5 | `tests/flip-p160.sh`（红→绿） | **rc=0** · 红面 `✓ 148 ✗ 9`、绿面 `✓ 157 ✗ 0`（9 条 ✗ 的归属：F1 2 条、F2 4 条、F3 3 条；脚本自己的标签计数 F1=3 F2=5 F3=10 含通过行） | `logs/50-flip.log`，`pkg/{red,green,summary}.txt` |

被验 revision：`978a453db6864d090b4d672078d16e9473c2b125`（`logs/00-tree.txt` 的第一行；同时记了容器里的
`date`/`loadavg`/`node`/`openspec` 路径）。机器当时不空（`loadavg: 12.64 12.85 11.53`，与别的 agent
的夹具/门禁同机），全量仍 0 ✗ —— 面板计时行按门禁规则打印实测值或可见地跳过，没有出现借负载的假红。

**合并兼容性（只读预演，供复验者参考）**：本分支的基点是 `aa787487`，此后 main 已前进很多（P169 等已并入）。
`git merge-tree --write-tree --name-only main task/P160-rework` → rc=0，只打印合并后的 tree
`ec03cfc0baa304fbec5666ee7fc606ac5821eba1`、**没有冲突文件清单**（三方合并干净）。段落账本
（`sections.tsv` / 开跑行 / 收口行）是运行时由 `section_guard_*` 生成的，不是静态表，所以「两边各加了段」
不会留下过期的段清单。

```text
--- 10-openspec.log
  Totals: 20 passed, 0 failed (20 items)
  openspec rc=0
--- 20-select.log
  == 选段结果 ==  ✓ 666  ✗ 0
  选段运行不是全套门禁（交付 / 复验 / 归档仍跑整套）；引用它的报告必须点名没跑的段
--- 30-fast.log
  == 结果 ==  ✓ 3445  ✗ 0
  FAST 模式：跳过 36 个真进程段落（…逐个点名…）
  smoke 全绿
--- 40-full.log
  == 结果 ==  ✓ 4175  ✗ 0
  smoke 全绿
--- 50-flip.log
  红面 P160 断言命中：F1=3 F2=5 F3=10（行数，含通过的那些）
    == 结果 ==  ✓ 148  ✗ 9
    == 结果 ==  ✓ 157  ✗ 0
  flip-p160：三条的红→绿都对上了
```

## 6. 夹具与规格上顺带改了什么（都是修法的必然结果）

| 位置 | 改动 | 为什么 |
|---|---|---|
| §55（P139 纯逻辑） | 给 CLI 那一半补一份 P9 任务书；`tip` 期望值改成「全量 HEAD 前 12 位」；新增「同一 HEAD 在 `core.abbrev` 7/12 下逐字节相同」「空闲分支 inbox 无 `task=`」「函数级标识为空」；stale 夹具改成互为前缀（12 位 / 9 位 / 非前缀三种记录） | F2/F3 的可证伪断言（旧夹具的 `assert_has` 是子串匹配，7 位也能过） |
| §56（真 tmux） | 入队时断言账本未动；排水后断言恰好一行 `[meeting:m-tmux#1]`；空闲分支 knock 载荷无 `task=` | F1 的绿侧守卫 + F3 的载荷面 |
| §12b-i / §13 | 期望的 `tip` 改成 12 位；§13 的扩展夹具加 `core.abbrev` 7/12 同一性、空闲分支不盖、非任务分支不盖 | 扩展侧与 CLI 同契约 |
| §47（P82 身份） | 期望值改 12 位；夹具补 P82 任务书 | F2/F3 的必然结果（见 §4 反向） |
| `openspec` deltas + `protocol.md`/`meeting.md` | 规格写清 12 位 wire 形状、证据要求、接收方的互为前缀判据、投递时记账 | 让实现与文字同源（P153 要求「规格里要写明」） |

## 7. 已知边界与取舍

1. **F4 不在范围**：P153 记的 F4 是「与本变更无关的全量红」。本轮的全量门禁在本树上是全绿的（表 §5），
   没有出现 F4 形状的红；它的处置属于 PM（任务书只点了 F1/F2/F3）。
2. **`--now` 强制路径也记回执**：它与既有的 `delivered: forced` 同语义（盲打 + `forced.log` 审计）。
   要更严的话，应在投递层先验框再记账；那属于 delivery-guard 的下一轮，不在本次裁断里。
3. **证据是仓库本地的**：`team_notify_task_proven` 读的是**发送方仓库**的 state/看板/任务书。一个真的任务
   分支若在这三处都没有记录（例如手工建的合成分支），标识会**消失**而不是变错 —— 这是 fail-closed 的
   有意代价，§47 的第二次红就是它的见证。
4. **接收方判据的两个方向**：记录比 tip 短（9 位）或长（40 位）都算同一 revision；只有「互为前缀」不成立
   才算没判过。这个语义写进了 delta 与 `protocol.md` §4，避免读者按「同宽比较」实现。
5. **本报告的定位**：这是 apply 侧的返工报告，**不是**独立复验。复验必须换人（D31），且要在独立 checkout
   上重跑 §5 的全部命令与 `flip-p160.sh`。

## 8. 与 P153 的关系：哪些我自己跑、哪些引用

- **我自己跑**：§5 的五条命令（openspec / select / FAST / 全量 / flip）全部在本容器与本树上真跑，
  原始日志在 `logs/`；三条缺陷的红侧由 `flip-p160.sh` 在**基线树**（`aa787487` 的 `skills/teamsmith`
  档案副本）上现场复现，不是引用 P153 的输出。
- **引用 P153 的**：三条缺陷的**形状描述**来自 `docs/team/reports/P153-verify.md`；我在基线上逐处复核过
  旧形状：`git show aa787487:skills/teamsmith/scripts/lib/cmd-agents.sh`（1542 行 `--short HEAD`，
  1537 行 `task/*|agent/*`）、`…/extension/team-notify.ts`（299 行 `--short`）、
  `…/cmd-meeting.sh`（571–573 行只在立即投递分支写 `knocks.log`），并让 `flip-p160.sh` 的红面现场复现
  了三条（不引用 P153 的输出当证据）。
- **没有跑**：真实的跨项目会议（需要另一个项目的 PM 在场）与真归档；前者用 §56 的真 tmux 夹具替代，
  后者按 D 系列纪律只能由 PM 在用户确认后做。
