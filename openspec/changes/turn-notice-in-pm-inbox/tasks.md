# turn-notice-in-pm-inbox · tasks

阶段口径：propose 完成（P363）。**apply 拆成两次派单，顺序固定 A1 → A2**：A1 是写入面（记录行拆两步、指针行、一份计数），
A2 是结果账与显示面。拆开是因为 A1 自己就是一次可交付的修复（指针行 + 计数），A2 的账本与 digest 两行依赖 A1 的
`__notify-settle` 命令与 outcome 分类；一次派单做两件会让复核无法把「通知到得了 PM」与「跳过的原因看得见」分开判。
两次派单都声明 `change: turn-notice-in-pm-inbox`、**不写任何 spec 文件**（`deltas: -`，delta 已由 P363 写入并经 PM 审核）。
本文件不是规格：合同在 `specs/notify-and-inbox/spec.md`，理由与取舍在 `design.md`。

## 0 · 共同前提（A1/A2 各自都要做）

- [ ] 0.1 `git merge main`；确认 propose 的 delta 已被 PM 在 `docs/team/reviews/turn-notice-in-pm-inbox-proposal.md`
  里判 ACCEPTED。读完 `design.md` §1–§10 再动手；发现规格自相矛盾 → `BLOCKED:` 交回 PM，**不自行改 delta**。
- [ ] 0.2 改前现场（命令与输出尾部进报告）：`docs/team/inbox/pm.md` 的行数与 `[auto]` 行数；
  `grep -c '\[auto' docs/team/inbox/*.md` 的形状；`team digest`（`[2]` 段原文）；`team inbox pm --detail` 的输出；
  `state/notify.log` 的记录数；一次 `team __inbox-write` 的返回三行。
- [ ] 0.3 写集边界：`skills/teamsmith/{extension/team-notify.ts,scripts/team,scripts/lib/cmd-agents.sh,
  scripts/lib/cmd-status.sh,references/protocol.md,tests/help-surface.sh,tests/smoke.sh}`。**不碰**投递守卫、
  `scripts/lib/outbox.sh`、`state/outbox/*` 的格式、`scripts/lib/cmd-watch.sh` 的待办与唤醒判据、面板源码与
  `panel.js`（本 change 不改面板，`team_inbox_new` 的判据自动传达）。
- [ ] 0.4 一次只跑改动点到的段（`--select 7,12f,13,13b,25,26,27,47,51` 的子集），**不要**每改一处跑整套；
  整套留给合并/交付前一次（在后台启动、下一次唤醒收）。

## 1 · A1 · 写入面：记录行拆两步 + 指针行 + 一份计数

### 1.1 把写入侧拆成「明细」与「合并/追加」两步（行为不变）

- [ ] 1.1.1 `team_inbox_write_locked` 拆出 `team_inbox_merge_or_append <recipient> <content> <file> <detail|->`：
  `detail=-` 表示不写明细；返回与今天同形的 `state=`/`first=`/`key=`。记录行那条腿的调用参数完全不变。
- [ ] 1.1.2 红侧：`--select 13` 的 F17 断言（同 run 三事件 → 一行 `×3` + `state/notify.log` 三条）不改一字仍绿；
  把 `detail=-` 误接到记录行 → `×3` 与明细数分家 → 该断言红。

### 1.2 指针行派生 `team_notify_pointer_line <记录行> <outcome>`

- [ ] 1.2.1 三条变换（`design.md` §2）：删 `⚠ … · ` 前缀；字段区尾部插 ` · knock=<outcome> · see=docs/team/inbox/<seat>.md`；
  删 ` :: <末消息>` 尾巴。`detail=unavailable` 标记照原样保留。字段顺序写死，并在夹具里钉住整行形状。
- [ ] 1.2.2 `team_notify_line_key` 对派生行的结果**必须等于**它对该记录行的结果 —— 这条做成夹具里的等号断言
  （不是「看起来合理」）。
- [ ] 1.2.3 红侧 R2：让派生顺手改记录行（例如把 `see=` 也塞进记录行）→ 记录行字节对照红。

### 1.3 合并器的 run 级字段规则（`knock=`）

- [ ] 1.3.1 `team_notify_line_merge` 接受可选的「已存在的那一行」，当两边都带 `knock=` 时取**已存在那一行**的值；
  只处理 `knock=` 一个字段。记录行从不带 `knock=`，所以它的输出必须逐字节不变（`--select 13` 的既有字节断言即证）。
- [ ] 1.3.2 红侧 R4：改成取新事件的值 → `enqueued` 的 run 被扩展后指针行显示 `skipped:merged` → 夹具红。

### 1.4 内部命令 `__notify-settle`

- [ ] 1.4.1 参数：`--agent <seat> --outcome <enqueued|skipped:<类>> [--record-from-file <行文件>] [--identity <id>]
  [--task <ID>]`。A1 只做指针腿：有 `--record-from-file` → 派生 + 合并/追加进 `pm.md`（持 `pm` 的收件箱锁）；
  没有 → 什么都不写（A2 才补账本）。打印 `pointer=ok|failed`，**退出码恒 0**（旁路写，失败只报告）。
- [ ] 1.4.2 `scripts/team` 的分派表加一行；`tests/help-surface.sh` 的内部命令白名单（`__inbox-write __panel-data`）
  与覆盖断言加 `__notify-settle`。
- [ ] 1.4.3 红侧：命令未注册 → help-surface 的覆盖断言红；`pm.md` 不可写（只读文件）→ 打印 `pointer=failed`、
  退出 0、且记录行仍在。

### 1.5 扩展侧：先算 outcome，再交给 `__notify-settle`

- [ ] 1.5.1 每个退出点给出闭集里的类（表见 `design.md` §6）：`suspended`、`merged`、`dedup`、`turn-unfinished`、
  `write-failed`、`notify-off`、`no-pane`、`pm-not-running`、`pm-window-missing`、`enqueue-failed`；成功后 `enqueued`。
- [ ] 1.5.2 顺序：记录行（`__inbox-write`，不变）→ 敲门判定与入队（不变）→ `__notify-settle`。指针失败只进扩展日志，
  **不**回退打字、**不**抑制已经入队的敲门、**不**改变退出。
- [ ] 1.5.3 红侧 R1/R8：删掉那一次 `__notify-settle` 调用 → `pm.md` 无指针行 → 夹具红；把一个分支的 outcome 写成
  别的类 → 该类的断言红。

### 1.6 计数判据（一条实现）

- [ ] 1.6.1 `team_inbox_line_is_record <file-seat> <line>`：auto 类行且 `agent:<name>` == 文件席位名 → 记录。
  `team_inbox_new` 与 `team_inbox_since` 都用它（其它读者通过这两个函数自动一致：digest 的待办、面板块、
  `team inbox` 的未读清单）。
- [ ] 1.6.2 红侧 R6/R7：删掉判据 → 一次交付后 `team_pending_text` 的未读通知 = 2 → 红；反向配对：`pm.md` 的指针行
  必须让 `team_inbox_new pm` 从 0 变 1（不增长的实现红）。
- [ ] 1.6.3 不许把判据写成「文件名是 pm」的特例：断言里要有一条**其它席位之间**的对照（一条非 auto 行照旧计数，
  一条指向别人的 auto 行照旧计数）。

### 1.7 `team inbox <agent> --detail` 按行自己的键对账

- [ ] 1.7.1 合并行的 `×N` 改成与**该行合并键**的记录比（键的第一个分量就是发送者）；「该席位的原始记录」那一行改成
  按文件里实际出现的键列出并点名席位。缺口判据（缺文件、被轮转出去）不放松。
- [ ] 1.7.2 红侧 R12：回到按文件席位取记录 → `team inbox pm --detail` 对一条 `×N` 指针行报缺口 → 红。

### 1.8 生效文档

- [ ] 1.8.1 `references/protocol.md` §4 加：指针行、`knock=` 的 run 级语义、一份计数、以及「指针写失败不改变敲门」。
  **不留第二份口径**：`grep -n 'inbox/<agent>.md' references/*.md SKILL.md` 的输出贴进报告核对。

### 1.9 A1 断言落点与定点验收

- [ ] 1.9.1 新断言放**既有段**，不新建段：CLI 面（派生、键相等、合并、计数、`--detail`）进 `§7 · notify / inbox / digest`；
  扩展面（指针行、outcome 类）进 `§13 · notify 扩展`。
- [ ] 1.9.2 执行：`bash skills/teamsmith/tests/smoke.sh --select 7,12f,13,13b,25,26,27,47,51`，把结果行与新增断言的
  原文贴进报告。**不跑 FAST 全量**，整套留给交付前一次。
- [ ] 1.9.3 报告 `docs/team/reports/<ID>-<agent>.md`：先给结论（哪条要求由哪条断言守住），再给改前/改后现场、
  红侧表里**实际做过**的破坏实验与它们的红/绿输出，最后给未验项。

## 2 · A2 · 结果账与显示面

### 2.1 结果账

- [ ] 2.1.1 `state/notify-knock.log`：一行一次 settle（字段与闭集见 `design.md` §6）；越界轮转到 `.1`（复用
  `team_notify_detail_append` 的轮转器与 `TEAM_NOTIFY_DETAIL_MAX`，**不新增配置键**）。写在 `__notify-settle` 里。
- [ ] 2.1.2 顺序：先尝试指针、后写账本（账本要带得上 `pointer=failed`）；两次写都是旁路，失败只打印。
- [ ] 2.1.3 红侧：把顺序倒过来 → `pointer=failed` 记不出来 → 红；把轮转去掉 → 有界断言红。

### 2.2 digest 的两行

- [ ] 2.2.1 `[2] 待处理通知` 内加两行（为 0 不打印）：`未敲门 N 条已记录的通知没有叫醒 PM（<类> <n> · …）`
  （从 `pm.md` 未 ack 的指针行数 `knock=skipped:`，一条 run 一次）与 `指针缺失 M 条通知没有写进 PM 收件箱
  （pointer-write-failed；state/notify-knock.log 当前代）`（从账本当前代）。段头字面量不动。
- [ ] 2.2.2 红侧 R9：ack 之后「未敲门」必须消失；若实现改成数账本（不随 ack 变），该断言红。
- [ ] 2.2.3 红侧（计数隔离）：把这两行接进 `team_pending_text` → `§25` 的「无待办 → 不叫醒」断言红。
- [ ] 2.2.4 未知类原样打印（夹具写一行 `skipped:something-new`）。

### 2.3 定点验收与报告

- [ ] 2.3.1 `bash skills/teamsmith/tests/smoke.sh --select 7,13,25`；贴结果行与两行的原文。
- [ ] 2.3.2 报告：结论先行（这两个后果各自被哪条断言守住），再给账本与 digest 的真实输出、红侧实验、未验项。

## 3 · 红侧总表（与 `design.md` §9 同一编号）

| # | 断言落点 | 破坏实现 → 必须红 |
|---|---|---|
| R1 | `§13` 扩展夹具 | 删 `__notify-settle` 调用 → `pm.md` 无指针行 |
| R2 | `§7` 字节对照 | 派生改写记录行 |
| R3 | `§7` 键相等 + `×N` | 指针行不带 `task=` 戳 → 同 run 变两行 |
| R4 | `§13` 扩展夹具 | 合并取新事件的 `knock=` |
| R5 | `§7` 明细计数 | 指针写入也进明细 → 记录数翻倍 |
| R6 | `§7` + `§25` | 删记录判据 → 待办 +2 |
| R7 | `§7` | 指针行不进 PM 的未读 |
| R8 | `§13` + `§7` | 某分支不给 outcome / 不写账本 |
| R9 | `§7` | `未敲门` 改成数账本 → ack 后不消失 |
| R10 | `§7` | `pm.md` 只读 → 无 `pointer=failed` / 无「指针缺失」行 |
| R11 | `§13` 既有断言 | 敲门语义（挂起不敲、扩展不敲、去重、`::` 摘要、`⚠` 前缀）原样绿 —— **不做新断言** |
| R12 | `§7` | `--detail` 按文件席位取记录 → 指针行假缺口 |

## 4 · 边界（写进报告，不靠默契）

- **不修敲门本身的可靠性**：本 change 不改变任何敲门分支的判据，只让每次 settle 的结果可读。用户报的「没有自动通知」
  之后仍然靠「`pm.md` 看得见 + digest 点名」被发现。
- **不回填历史指针行**，历史 `[auto]` 行升级后不再计入该席位的未读（delta 已写为 SHALL NOT）。
- **身份守卫之前被拒的 settle 不进账本**（不是通知）。
- **`enqueued` 不是「已送达」**：投递由 `state/outbox/delivered.log` 记账，指针行与 digest 都不许改写这句话。
- **不给结果账新增配置键**（沿用 `TEAM_NOTIFY_DETAIL_MAX`），因此本 change **没有**配置四面（schema/模板/config.md/
  面板标签）的改动；若实施中发现必须新增键，停下报 PM（那是一次四面登记，不在本 change 的写集里）。

## 5 · verify（独立席位，非 A1/A2 作者）

- [ ] 5.1 在自己的克隆上定点**执行**（不是查表）：`--select 7,13,25`，贴结果行与新增断言原文；不复用 apply 的日志。
- [ ] 5.2 反向对照只做两条（其余由 §3 表在 apply 阶段完成，不重复）：R4（合并取首事件的 `knock=`）与 R6（记录判据）
  —— 这两条是「run 级字段」与「一份计数」的唯一控制。
- [ ] 5.3 `openspec validate --all --strict`、`bash skills/teamsmith/tests/spec-refs.sh --check` 与 `--flips`、
  `git diff --check`；确认没有回归：`§25` 的手工通知计数、`§12f` 的段头字面量、`§13` 的扩展字节断言、
  `§51` 的内部命令白名单。
- [ ] 5.4 复验记录写 `docs/team/reviews/turn-notice-in-pm-inbox.md`；**只有复验通过且用户确认后** PM 才归档。
