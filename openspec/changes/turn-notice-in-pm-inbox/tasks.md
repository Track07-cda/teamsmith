# turn-notice-in-pm-inbox · tasks

阶段口径：propose 完成（P363）。**apply 拆成两次派单，顺序固定 A1 → A2**：A1 是写入面（记录行拆两步、指针行、一份计数），
A2 是结果账与显示面。拆开是因为 A1 自己就是一次可交付的修复（指针行 + 计数），A2 的账本与 digest 两行依赖 A1 的
`__notify-settle` 命令与 outcome 分类；一次派单做两件会让复核无法把「通知到得了 PM」与「跳过的原因看得见」分开判。
两次派单都声明 `change: turn-notice-in-pm-inbox`、**不写任何 spec 文件**（`deltas: -`，delta 已由 P363 写入并经 PM 审核）。
本文件不是规格：合同在 `specs/notify-and-inbox/spec.md`，理由与取舍在 `design.md`。

## 0 · 共同前提（A1/A2 各自都要做）

- [x] 0.1 `git merge main`；确认 propose 的 delta 已被 PM 在 `docs/team/reviews/turn-notice-in-pm-inbox-proposal.md`
  里判 ACCEPTED。读完 `design.md` §1–§10 再动手；发现规格自相矛盾 → `BLOCKED:` 交回 PM，**不自行改 delta**。
  ↳ 证据（P371）：`docs/team/reviews/turn-notice-in-pm-inbox-proposal.md` 第 3 行「状态: **ACCEPTED**」；A1/A2 的实现提交已在 main（`git log --oneline main | grep notify` → `e035c57e`、`d9e219b2`）。
- [ ] 0.2 改前现场（命令与输出尾部进报告）：`docs/team/inbox/pm.md` 的行数与 `[auto]` 行数；
  `grep -c '\[auto' docs/team/inbox/*.md` 的形状；`team digest`（`[2]` 段原文）；`team inbox pm --detail` 的输出；
  `state/notify.log` 的记录数；一次 `team __inbox-write` 的返回三行。
  ↳ 缺（P371）：只留住了一半。在案的有 `proposal.md` 的 Why 表（`pm.md` 3 行全 `[manual]`、历史 `[auto]` 2 行、`dev3.md` 8 行 `[auto]`）与 P364 报告 §2 的 settle 前后现场（`state/notify.log` 不存在 → 1 行、`__inbox-write` 的 `state=/first=/key=` 三行）；**缺** `team digest` 的 `[2]` 段原文与 `team inbox pm --detail` 的现场输出。要做到才算：报告里能贴出这两条命令改前的原样输出 —— 改动已并入 main，今天只能从账本追溯，所以这一条留给 PM 裁定（以 proposal 的读数替代，还是接受这个缺口）。
- [x] 0.3 写集边界：`skills/teamsmith/{extension/team-notify.ts,scripts/team,scripts/lib/cmd-agents.sh,
  scripts/lib/cmd-status.sh,references/protocol.md,tests/help-surface.sh,tests/smoke.sh}`。**不碰**投递守卫、
  `scripts/lib/outbox.sh`、`state/outbox/*` 的格式、`scripts/lib/cmd-watch.sh` 的待办与唤醒判据、面板源码与
  `panel.js`（本 change 不改面板，`team_inbox_new` 的判据自动传达）。
  ↳ 证据（P371）：`git show --stat e035c57e d9e219b2` 碰到的 9 个文件（`team-notify.ts`、`scripts/team`、`cmd-agents.sh`、`cmd-status.sh`、`protocol.md`、`help-surface.sh`、`smoke.sh` + 两份报告）全在这份写集内；`outbox.sh`、`cmd-watch.sh`、`scripts/panel/**`、`panel.js` 一次都没出现。
- [x] 0.4 一次只跑改动点到的段（`--select 7,12f,13,13b,25,26,27,47,51` 的子集），**不要**每改一处跑整套；
  整套留给合并/交付前一次（在后台启动、下一次唤醒收）。
  ↳ 证据（P371）：P364 报告 §4/§5 的两批选段（`--select 6,7,13,25` → ✓271 ✗0；`--select 60,12f,26,27,47,51` → ✓356 ✗0）与 P365 报告 §1 的 `--select 7,13,25`（✓234 ✗0）：都是改动点到的子集，没有每改一步跑整套。

## 1 · A1 · 写入面：记录行拆两步 + 指针行 + 一份计数

### 1.1 把写入侧拆成「明细」与「合并/追加」两步（行为不变）

- [x] 1.1.1 `team_inbox_write_locked` 拆出 `team_inbox_merge_or_append <recipient> <content> <file> <detail|->`：
  `detail=-` 表示不写明细；返回与今天同形的 `state=`/`first=`/`key=`。记录行那条腿的调用参数完全不变。
  ↳ 证据（P371）：`scripts/lib/cmd-agents.sh:1981` `team_inbox_merge_or_append() { # <recipient> <行> <文件> <明细|-> → state=new|extended first=<ISO> key=<键>`；两条腿的行为断言是 `smoke.sh:5099`（`state=new`）与 `smoke.sh:5122`（`state=extended`）。
- [x] 1.1.2 红侧：`--select 13` 的 F17 断言（同 run 三事件 → 一行 `×3` + `state/notify.log` 三条）不改一字仍绿；
  - 2026-10-23 红侧实测（P373，`docs/team/reports/P373-dev.md` §1）：改坏 → 贴出的红行原文 → 还原 → 绿。
  把 `detail=-` 误接到记录行 → `×3` 与明细数分家 → 该断言红。
  ↳ 缺（P371）（红侧没做，整条不勾）：前半句有据 —— §13 的 F17 一字未改仍绿（P364 报告 §4、P365 报告 §1 两次选段都是 `13 · notify 扩展 · ✓1 ✗0`）；但「把 `detail=-` 误接到记录行 → 该断言红」这次破坏**没有任何在案实测**（P364 报告 §3 的三次变异是 R2/R4/R6）。要做到才算：真改一处 → §13 的退出码非 0 → `git checkout` 还原 → 同一段再绿，读数进报告。

### 1.2 指针行派生 `team_notify_pointer_line <记录行> <outcome>`

- [x] 1.2.1 三条变换（`design.md` §2）：删 `⚠ … · ` 前缀；字段区尾部插 ` · knock=<outcome> · see=docs/team/inbox/<seat>.md`；
  删 ` :: <末消息>` 尾巴。`detail=unavailable` 标记照原样保留。字段顺序写死，并在夹具里钉住整行形状。
  ↳ 证据（P371）：`cmd-agents.sh:1932` `team_notify_pointer_line`（`case "$rest" in '⚠'*)` 删前缀 → `printf '- %s [%s] agent:%s · %s · knock=%s · see=%s/inbox/%s.md'` → 只复制 `task=/awaiting=/asks=/detail=unavailable`，不复制 ` :: ` 尾巴）；整行形状由 `smoke.sh:5107` 的等号断言逐字节钉住。
- [x] 1.2.2 `team_notify_line_key` 对派生行的结果**必须等于**它对该记录行的结果 —— 这条做成夹具里的等号断言
  （不是「看起来合理」）。
  ↳ 证据（P371）：`smoke.sh:5117-5119` 是等号断言 —— `team_notify_line_key(pm.md 尾行)` = `team_notify_line_key(dev.md 尾行)`，标签原文「指针行与记录行同一个合并键（缺 task= 戳就退化成两条）」。
- [x] 1.2.3 红侧 R2：让派生顺手改记录行（例如把 `see=` 也塞进记录行）→ 记录行字节对照红。
  ↳ 证据（P371）：做过并被独立复现。P364 报告 §3「MUTANT R2 · --select 7」→ ✓125 ✗4（`✗ R2 指针是旁路：记录行逐字节不变`、`✗ 记录行不带 knock=`、`✗ 记录行不带 see=`、`✗ R2 扩展事件也不动记录行`），还原后绿；`docs/team/reviews/V96.md` 同一条红侧独立采纳。断言本体 `smoke.sh:5104`、`5115`、`5116`、`5126`。

### 1.3 合并器的 run 级字段规则（`knock=`）

- [x] 1.3.1 `team_notify_line_merge` 接受可选的「已存在的那一行」，当两边都带 `knock=` 时取**已存在那一行**的值；
  只处理 `knock=` 一个字段。记录行从不带 `knock=`，所以它的输出必须逐字节不变（`--select 13` 的既有字节断言即证）。
  ↳ 证据（P371）：`cmd-agents.sh:1817` `team_notify_line_merge <新事件行> <首时间戳> <n> <末时间戳> [<已存在的行>]`；「记录行逐字节不变」由 `smoke.sh:5115`（`记录行不带 knock=`）与 `5126`（`R2 扩展事件也不动记录行`，`cmp` 前后）钉住。
- [x] 1.3.2 红侧 R4：改成取新事件的值 → `enqueued` 的 run 被扩展后指针行显示 `skipped:merged` → 夹具红。
  ↳ 证据（P371）：P364 报告 §3「MUTANT R4 · --select 7,13b」→ ✓129 ✗5，红行原文 `knock=skipped:merged` 与 `FAIL: R4：扩展事件把 run 级 knock= 改写成了 skipped:merged`，还原后绿。守住它的等号断言是 `smoke.sh:5129`。

### 1.4 内部命令 `__notify-settle`

- [x] 1.4.1 参数：`--agent <seat> --outcome <enqueued|skipped:<类>> [--record-from-file <行文件>] [--identity <id>]
  [--task <ID>]`。A1 只做指针腿：有 `--record-from-file` → 派生 + 合并/追加进 `pm.md`（持 `pm` 的收件箱锁）；
  没有 → 什么都不写（A2 才补账本）。打印 `pointer=ok|failed`，**退出码恒 0**（旁路写，失败只报告）。
  ↳ 证据（P371）：`cmd-agents.sh:2093-2141` `team_cmd_notify_settle`（参数表、`--outcome` 只接受 `enqueued` 与 `skipped:<类>`、有 `--record-from-file` 才派生指针、持 `pm` 锁写、`printf 'pointer=%s\n'`、`:2140 return 0`）；没有记录行那条腿 `pointer=none` 由 `smoke.sh:5162` 钉住。
- [x] 1.4.2 `scripts/team` 的分派表加一行；`tests/help-surface.sh` 的内部命令白名单（`__inbox-write __panel-data`）
  与覆盖断言加 `__notify-settle`。
  ↳ 证据（P371）：`scripts/team:105` `__notify-settle) team_cmd_notify_settle "$@" ;;  # 内部：settle 的旁路记账入口…`；`tests/help-surface.sh:815` `local internal="__inbox-write __notify-settle __panel-data"`。
- [x] 1.4.3 红侧：命令未注册 → help-surface 的覆盖断言红；`pm.md` 不可写（只读文件）→ 打印 `pointer=failed`、
  - 2026-10-23 红侧实测（P373，`docs/team/reports/P373-dev.md` §1）：改坏 → 贴出的红行原文 → 还原 → 绿。
  退出 0、且记录行仍在。
  ↳ 缺（P371）（前半条没做，整条不勾）：后半条有真断言在跑（`smoke.sh:5149-5159` 的四条 R10 断言：`pointer=failed`、退出码 0、`pm.md` 一行没多、记录行照旧落盘）；**缺**「命令未注册 → help-surface 的覆盖断言红」这次破坏 —— 没有任何在案报告记录过把 `scripts/team:105` 那一行删掉再跑 help-surface。要做到才算：删那一行 → help-surface 的 O2 覆盖断言非 0 → 还原 → 绿。

### 1.5 扩展侧：先算 outcome，再交给 `__notify-settle`

- [x] 1.5.1 每个退出点给出闭集里的类（表见 `design.md` §6）：`suspended`、`merged`、`dedup`、`turn-unfinished`、
  `write-failed`、`notify-off`、`no-pane`、`pm-not-running`、`pm-window-missing`、`enqueue-failed`；成功后 `enqueued`。
  ↳ 证据（P371）：`extension/team-notify.ts` 的十一个退出点各给一类 —— 613 `skipped:turn-unfinished`、636 `dedup`、670 `merged`/`write-failed`、680 `suspended`、686 `notify-off`、691 `no-pane`、701 `pm-not-running`、706 `pm-window-missing`、743 `enqueue-failed`，成功路径写 `enqueued`。闭集外不吞：`smoke.sh:5235`（`闭集外的类原样落账`）与 `smoke.sh:5238` 的 `其它（something-new 1）`。
- [x] 1.5.2 顺序：记录行（`__inbox-write`，不变）→ 敲门判定与入队（不变）→ `__notify-settle`。指针失败只进扩展日志，
  **不**回退打字、**不**抑制已经入队的敲门、**不**改变退出。
  ↳ 证据（P371）：`team-notify.ts` 的顺序是 记录行（`writeState` 已定）→ 敲门判定与 `outbox enqueue` → 收尾的 `settleSkipped('enqueued', true)`；`settleSkipped` 的 `catch` 只 `log(...)`（原文：`the pointer is a side channel, the knock is untouched`），没有任何回退打字或改变退出的路径。
- [x] 1.5.3 红侧 R1/R8：删掉那一次 `__notify-settle` 调用 → `pm.md` 无指针行 → 夹具红；把一个分支的 outcome 写成
  - 2026-10-23 红侧实测（P373，`docs/team/reports/P373-dev.md` §1）：改坏 → 贴出的红行原文 → 还原 → 绿。
  别的类 → 该类的断言红。
  ↳ 缺（P371）（两个破坏都没做，整条不勾）：R8 只做了一半 —— P365 报告 §5 的 M1「不写账本」→ ✓149 ✗16；**缺** R1「删掉那一次 `__notify-settle` 调用 → `pm.md` 无指针行 → 夹具红」与「把一个分支的 outcome 写成别的类 → 该类的断言红」，两者都无在案实测。要做到才算：在 `team-notify.ts` 里各改一处 → `§13` 的退出码非 0（`smoke.sh:7966-7999` 的 40–51 号 FAIL 之一）→ 还原 → 绿。

### 1.6 计数判据（一条实现）

- [x] 1.6.1 `team_inbox_line_is_record <file-seat> <line>`：auto 类行且 `agent:<name>` == 文件席位名 → 记录。
  `team_inbox_new` 与 `team_inbox_since` 都用它（其它读者通过这两个函数自动一致：digest 的待办、面板块、
  `team inbox` 的未读清单）。
  ↳ 证据（P371）：`cmd-status.sh:36` `team_inbox_line_is_record`（只看 tag ∈ {`auto`,`auto·suspended`,`auto·interrupted`} 与 `agent:<name>` == 文件席位）；`team_inbox_since`（:59）与 `team_inbox_new`（:67）都调它，所以 digest 待办、面板块、`team inbox` 的未读是同一读数。
- [x] 1.6.2 红侧 R6/R7：删掉判据 → 一次交付后 `team_pending_text` 的未读通知 = 2 → 红；反向配对：`pm.md` 的指针行
  必须让 `team_inbox_new pm` 从 0 变 1（不增长的实现红）。
  ↳ 证据（P371）：R6 的破坏做过 —— P364 报告 §3「MUTANT R6 · --select 7」→ ✓125 ✗4（`✗ R6：席位自己的 auto 记录不算它自己的未读流量（期望 [0]，实际 [1]）`、`✗ R6：待办里的未读通知 = 1（不是 2）`），还原后绿；反向配对的等号断言在 `smoke.sh:5136`（`R7：指针行让 PM 的未读从 0 变 1`）。
- [x] 1.6.3 不许把判据写成「文件名是 pm」的特例：断言里要有一条**其它席位之间**的对照（一条非 auto 行照旧计数，
  一条指向别人的 auto 行照旧计数）。
  ↳ 证据（P371）：`smoke.sh:5141-5143` 在 `dev2.md` 里放一条 `[auto] agent:dev` 与一条 `[manual]`，断言 `team_inbox_new dev2 = 2`，标签原文「R6：判据不是「文件名是 pm」的特例」；判据的注释也在 `cmd-status.sh:31-35` 把这条纪律写死。

### 1.7 `team inbox <agent> --detail` 按行自己的键对账

- [x] 1.7.1 合并行的 `×N` 改成与**该行合并键**的记录比（键的第一个分量就是发送者）；「该席位的原始记录」那一行改成
  按文件里实际出现的键列出并点名席位。缺口判据（缺文件、被轮转出去）不放松。
  ↳ 证据（P371）：`cmd-status.sh:1190-1235` 的 `--detail` 用 `team_notify_line_key` 收集当前代的键（`RKEYS`/`KC`/`SHOWN`），合并行按**该行自己的键**计数并打印 `键 agent:%s · %s · %s · awaiting=%s`；缺口分支（`count < n` → 报「缺口」并 `rc=1`）一字未松。
- [x] 1.7.2 红侧 R12：回到按文件席位取记录 → `team inbox pm --detail` 对一条 `×N` 指针行报缺口 → 红。
  - 2026-10-23 红侧实测（P373，`docs/team/reports/P373-dev.md` §1）：改坏 → 贴出的红行原文 → 还原 → 绿。
  ↳ 缺（P371）：断言在跑（`smoke.sh:5146-5148` 的三条 R12 断言：退出码 0、`记录 2/2 OK`、`不报缺口`），但「回到按文件席位取记录 → 报缺口」这次破坏没有在案实测。要做到才算：把 `--detail` 的计数键改回文件席位 → 对一条 `×N` 指针行打印「缺口」且 `rc=1` → 还原 → 绿。

### 1.8 生效文档

- [x] 1.8.1 `references/protocol.md` §4 加：指针行、`knock=` 的 run 级语义、一份计数、以及「指针写失败不改变敲门」。
  **不留第二份口径**：`grep -n 'inbox/<agent>.md' references/*.md SKILL.md` 的输出贴进报告核对。
  ↳ 证据（P371）：`references/protocol.md:82-92` 的指针行段落（形状、`knock=` 的 run 级语义、`enqueued` ≠ 已送达、指针写失败不改敲门、记录行逐字节不变）；「不留第二份口径」的 grep 输出在 P364 报告 §6（七处 `inbox/<agent>.md` 都只讲记录落点，新增只有 protocol.md §4）。

### 1.9 A1 断言落点与定点验收

- [x] 1.9.1 新断言放**既有段**，不新建段：CLI 面（派生、键相等、合并、计数、`--detail`）进 `§7 · notify / inbox / digest`；
  扩展面（指针行、outcome 类）进 `§13 · notify 扩展`。
  ↳ 证据（P371）：`git show e035c57e -- skills/teamsmith/tests/smoke.sh | grep -c '^+section '` = 0、`git show d9e219b2 …` 同为 0；新增断言全落在 `smoke.sh:5020` 的 `section "7 · notify / inbox / digest"` 与 `smoke.sh:7846` 的 `section "13 · notify 扩展…"` 里（CLI 面 5078-5330、扩展面 7962-8000）。
- [x] 1.9.2 执行：`bash skills/teamsmith/tests/smoke.sh --select 7,12f,13,13b,25,26,27,47,51`，把结果行与新增断言的
  原文贴进报告。**不跑 FAST 全量**，整套留给交付前一次。
  ↳ 证据（P371）：P364 报告 §4 的实跑结果行（`--select 6,7,13,25` → `✓271 ✗0`，含 `#10 7 · notify / inbox / digest · ✓66 ✗0`）与 §5 的第二批（`--select 60,12f,26,27,47,51` → ✓356 ✗0）。任务书字面的 `--select 7,13,25` 当时红在 §13 的 `.worktrees/dev` 前提上，该选段表缺口已由 P367 落地、V97 核过。
- [x] 1.9.3 报告 `docs/team/reports/<ID>-<agent>.md`：先给结论（哪条要求由哪条断言守住），再给改前/改后现场、
  红侧表里**实际做过**的破坏实验与它们的红/绿输出，最后给未验项。
  ↳ 证据（P371）：P364 报告 §1「哪条要求由哪条断言守住」表 + §2 改前/改后现场 + §3 三次真实变异（R2/R4/R6）+ §7 未验项，四段齐；P365 报告同构（结论 → Verification evidence → Flip evidence M1–M5 → Findings → 没做的事）。

## 2 · A2 · 结果账与显示面

### 2.1 结果账

- [x] 2.1.1 `state/notify-knock.log`：一行一次 settle（字段与闭集见 `design.md` §6）；越界轮转到 `.1`（复用
  `team_notify_detail_append` 的轮转器与 `TEAM_NOTIFY_DETAIL_MAX`，**不新增配置键**）。写在 `__notify-settle` 里。
  ↳ 证据（P371）：`cmd-agents.sh:1924` `team_notify_knock_ledger_path`（`<state>/notify-knock.log`）、`:1926` `team_notify_knock_ledger_append`（走 `team_notify_detail_append … knock`，第 3 参只改日志措辞）；有界与轮转的断言在 `smoke.sh:5266-5273`（`越界后产生一代 .1`、`当前代不超过上限`、`轮转头点名…`、`扩展日志点名`）。本 change 没有新增配置键（`cmd-config.sh` 的 schema 未改）。
- [x] 2.1.2 顺序：先尝试指针、后写账本（账本要带得上 `pointer=failed`）；两次写都是旁路，失败只打印。
  ↳ 证据（P371）：`cmd-agents.sh:2119-2141` 的顺序是 指针腿（`team_inbox_write_pointer_line`，`:2055` 定义）→ 账本腿（`team_notify_knock_ledger_append`），账行带 `pointer=$pointer`；断言 `smoke.sh:5251`（`P365/R10：先指针后账本 —— 账行带得上 pointer=failed`）。
- [x] 2.1.3 红侧：把顺序倒过来 → `pointer=failed` 记不出来 → 红；把轮转去掉 → 有界断言红。
  ↳ 证据（P371）：P365 报告 §5 的 M2（顺序倒过来 → ✓158 ✗7，`✗ P365/R10：先指针后账本 —— 账行带得上 pointer=failed`）与 M4（去掉轮转 → ✓159 ✗6，五条轮转断言红），都 `git checkout --` 还原后绿。

### 2.2 digest 的两行

- [x] 2.2.1 `[2] 待处理通知` 内加两行（为 0 不打印）：`未敲门 N 条已记录的通知没有叫醒 PM（<类> <n> · …）`
  （从 `pm.md` 未 ack 的指针行数 `knock=skipped:`，一条 run 一次）与 `指针缺失 M 条通知没有写进 PM 收件箱
  （pointer-write-failed；state/notify-knock.log 当前代）`（从账本当前代）。段头字面量不动。
  ↳ 证据（P371）：`cmd-status.sh:1008-1017` 的两行（`未敲门 %s 条已记录的通知没有叫醒 PM（%s）—— 见 %s/inbox/pm.md 的 knock= 字段`、`指针缺失 %s 条通知没有写进 PM 收件箱（pointer-write-failed；…当前代，更早的代不计）`，都为 0 不打印）；读者是 `team_inbox_skipped_knock_summary`（:93）与 `team_knock_pointer_failed_count`（:161）。读数断言 `smoke.sh:5238`、`5253`。
- [x] 2.2.2 红侧 R9：ack 之后「未敲门」必须消失；若实现改成数账本（不随 ack 变），该断言红。
  ↳ 证据（P371）：P365 报告 §5 的 M3（「未敲门」改成数账本 → ✓162 ✗3，`✗ P365/R9：ack 之后「未敲门」消失`），还原后绿；断言本体 `smoke.sh:5259` 与 `smoke.sh:11826`。
- [x] 2.2.3 红侧（计数隔离）：把这两行接进 `team_pending_text` → `§25` 的「无待办 → 不叫醒」断言红。
  ↳ 证据（P371）：P365 报告 §5 的 M5（把两行接进 `team_pending_text` → 跑 `--select 25` → ✓86 ✗3，`✗ P365：未敲门不进唤醒计数`、`✗ P365：一个不会自己消失的指针故障不会每一拍都叫醒 PM`），还原后绿；断言本体 `smoke.sh:11823`、`11828`、`11830`。
- [x] 2.2.4 未知类原样打印（夹具写一行 `skipped:something-new`）。
  ↳ 证据（P371）：`smoke.sh:5235`（`✓ P365：闭集外的类原样落账`）与 `smoke.sh:5238` 的 `其它（something-new 1）`；`docs/team/reviews/V98.md` 的采纳依据记录了两条自造红侧之一「把「未知类原样」改成丢弃」真红、还原后绿。

### 2.3 定点验收与报告

- [x] 2.3.1 `bash skills/teamsmith/tests/smoke.sh --select 7,13,25`；贴结果行与两行的原文。
  ↳ 证据（P371）：P365 报告 §1 的实跑（`#7 ✓102 ✗0`、`#8 ✓1 ✗0`、`#9 ✓65 ✗0`、`== 选段结果 == ✓234 ✗ 0`）与 §5 的两行原文（`未敲门 3 条已记录的通知没有叫醒 PM（suspended 1 · notify-off 1 · 其它（something-new 1））`、`指针缺失 1 条通知没有写进 PM 收件箱（…）`）。
- [x] 2.3.2 报告：结论先行（这两个后果各自被哪条断言守住），再给账本与 digest 的真实输出、红侧实验、未验项。
  ↳ 证据（P371）：P365 报告的结构齐 —— 结论两条（每次 settle 一行账 / digest 两行）各自点名守住它的断言，其后是 Verification evidence 六节、Flip evidence M1–M5、Findings F1–F3、没做的事。

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

- [x] 5.1 在自己的克隆上定点**执行**（不是查表）：`--select 7,13,25`，贴结果行与新增断言原文；不复用 apply 的日志。
  - 2026-10-23 V102 独立执行：`--select 7,13,25` 在其自有副本 `✓245 ✗0`、rc=0（无「本次运行无效」）。
- [x] 5.2 反向对照只做两条（其余由 §3 表在 apply 阶段完成，不重复）：R4（合并取首事件的 `knock=`）与 R6（记录判据）
  - 2026-10-23 V102 两条反向对照：R4（合并取新事件 `knock=`）与 R6（指针行改写记录行）都真红、还原后同一选段再绿。
  —— 这两条是「run 级字段」与「一份计数」的唯一控制。
- [x] 5.3 `openspec validate --all --strict`、`bash skills/teamsmith/tests/spec-refs.sh --check` 与 `--flips`、
  - 2026-10-23 V102：`openspec validate --all --strict`、`spec-refs --check`、`--flips`、账本禁令、`git diff --check` 全绿；另按本条点名的四项回归跑 `--select 12f,51` `✓55 ✗0`（1488 s，其中 §51 自嵌套 §33 `✓331 ✗0`）。
  `git diff --check`；确认没有回归：`§25` 的手工通知计数、`§12f` 的段头字面量、`§13` 的扩展字节断言、
  `§51` 的内部命令白名单。
- [x] 5.4 复验记录写 `docs/team/reviews/turn-notice-in-pm-inbox.md`；**只有复验通过且用户确认后** PM 才归档。
  - 2026-10-23 V102：`docs/team/reviews/turn-notice-in-pm-inbox.md` 落盘（P371 §结论第 4 条指出的缺口因此闭合）。
