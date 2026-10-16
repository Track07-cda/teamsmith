# seat-interrupt-entry · tasks

阶段口径：**propose 已由 dev-bob 完成**（本文件 §0）。**apply 是一个任务**（`deltas: boundary`）——本变更只落一个
能力的一份 delta，两个 apply 任务会撞上同一份 `specs/boundary/spec.md`（单写者守卫）。**verify 由没有写过本
change 的席位**在独立检出上逐场景 + 逐红侧重跑（写的人不验自己的活）。本文件不是规格；合同文本在
`specs/boundary/spec.md` 的两条 ADDED 里。

规格 ↔ 任务对照（闭合两向）：

| 规格 | 任务 |
|---|---|
| `boundary#A running seat's turn is ended only by an audited interrupt aimed at that seat's own process` | 1.1–1.7 |
| `boundary#An interrupt carries its reason to the seat, and a seat that is writing is not interrupted by accident` | 2.1–2.6 |
| （既有能力，非本 change 的 delta）`help-surface#The help surface is a level-0 menu, a page per group and a page per command` | 3.1 |
| （既有能力，非本 change 的 delta）`boundary#Scripts select processes by recorded pid, and the lint keeps it that way` | 3.4 |

## 0 提案（propose 阶段，本任务已完成）

- [x] 0.1 两份 delta 写全（`boundary` 两条 ADDED，逐条带全场景：入口/计划态/对象证明/复验/审计/拒绝集合/读命令 +
  理由必填/投递/新鲜窗口/`--force`/工作树幸存），`proposal.md` + `design.md` + `tasks.md` 与规格逐条对齐（无孤儿
  任务、无无主要求）。 · 证据：`docs/team/reports/P291-dev-bob.md` 的「Deliverables」段。
- [x] 0.2 事实基础是实测而不是转述：入口盘点（`scripts/team` 的 `reap`/`teardown`/`resume` 三条 + `commands.tsv`
  45 条命令）、长回合的读数（`dev` 窗口 `Elapsed 53m 5s`/`Working` 而它那次会话文件 2112882 字节、mtime 距今
  3188 秒、再采 20 秒不变）、同一会话 id 跨进程死亡继续追加（`state/dev.env` 的 `started=`/`mode=continued`/
  `sid=` 与那份会话文件的创建时间）、既有机器（`cmd-reap.sh` 的信号/复验/审计形状、`team_orphan_*` 的身份判据、
  `team_pane_agent_pid`、`team_inbox_append`、thread 写入器、`team_guard_resume_session`）、`config-cli.sh` 的
  completeness 走查方向（文档键 → schema）。 · 证据：报告「现状复核」段（命令 + 输出尾）。
- [x] 0.3 跨能力影响写清：`long-job-suspend` 的关系（design §1）、help 面/`commands.tsv`/探针、文档面
  （troubleshooting/protocol）、不新增契约键的理由（design §4）、死因词表与后台车道的明说边界（design §8）、
  apply 的写集串行（`tests/smoke.sh` 与 `tests/section-*.tsv` 与在飞的 `gate-lock-hygiene` 同批）。 · 证据：
  `proposal.md` 的 Capabilities / Impact 两节 + `design.md` §1/§4/§7/§8。
- [x] 0.4 propose 阶段验收跑过并贴出：`openspec validate --all --strict`、`spec-refs.sh --check`、
  `ledger-ban.sh`、`git diff --check && git status --short`。 · 证据：报告「验收（propose）」段。

## 1 入口、对象证明与信号（规格：`boundary#A running seat's turn is ended only by an audited interrupt aimed at that seat's own process`）

- [x] 1.1 新 `skills/teamsmith/scripts/lib/cmd-interrupt.sh` 落 `team interrupt <seat> --reason <一句话>
  [--force] [--yes]`：无 `--yes` 是计划态（打印席位/pid/读到的证据/将发的信号，**零信号零写盘**，退 0；目标不可
  打断则退非 0 并点名拒绝与出路），有 `--yes` 才执行；`scripts/team` 加一个分发标签。退出码：计划 0、拒绝 2、
  执行未收干净非 0。 · 证据：夹具 `plan` 组（`kill -0 <pid>` 前后 + `state/interrupt.log` 未增长 + thread/inbox
  逐字节不变 + 输出的三个字段）+ `team help interrupt` 渲染。 · **P295 按证据勾**：入口在
  `skills/teamsmith/scripts/lib/cmd-interrupt.sh`（461 行，提交 21add518）、`scripts/team` 一行路由（`interrupt)`）。
  退出码：计划 0、拒绝 2（缺理由/actor/名册/派单记录/窗口/pane 里没有本项目 agent/自身或祖先/身份各点 `return 2`）、
  SIGTERM 发不出去或 SIGKILL 后仍活着 1。夹具 plan 组 12 条断言（P292 §逐条 scenario 对照 plan 行）；复验方在真进程
  替身上 15 条（V49 §3：进程 alive、审计不增、线程与收件箱 sha256 不变、输出点名席位/pid/信号/未授权/回来的路/sid/mode）；
  `team help interrupt` 我在本树实跑 rc=0，help-surface `--select coverage` 46 条命令 × 页面/用法/旗标 15 断言全绿
  （本树实跑 rc=0，见报告 §验收）。
- [x] 1.2 对象证明链按 design §3：名册 → 派单记录的 `window=` → 该 pane 的 agent 进程（`team_pane_agent_pid` 的
  既有形状，含 `bash <agent>` 的 P217 情形）→ 普查的同一套身份判据（进程自己的 `TEAM_MAIN_ROOT`/`TEAM_ROOT` +
  命令行命中本项目 agent 可执行文件）；**不新增第二套判据**。 · 证据：夹具 `target` 组（真 stub agent 进程 +
  私有 socket；断言计划打印的 pid 就是那个 stub 的 pid，且它自己的 environ 属于本项目）+ 反例臂：把身份判据换成
  「命令行里提到 agent 路径」→ 夹具必红。 · **P295 按证据勾**：实现 `team_interrupt_identity` 复用普查判据
  （`team_orphan_shape_match` + 进程自己 environ 的 `TEAM_MAIN_ROOT`/`TEAM_ROOT` + 命令行命中配置的 agent 可执行文件），
  pid 只来自派单记录里那个窗口的 pane（`team_pane_agent_pid`）——P292 §实现自述的对象证明链；target 组 26 条断言含
  /proc 直读 environ、TEAM_ROOT 与记录工作树不一致 → 拒、窗口在但 pane 里没有本项目 agent → 拒、两条 TOCTOU、
  复验四条分支的库层硬目标（seat-interrupt.sh target 组）；红侧 `p292-flip-foreign` 把身份判据整体短路 → 跨项目那条
  必红、还原绿（P292 §逐条红侧第 8 格）；复验方独立复核 other-tree / 本项目正控制 / pane 已死（V49 §5b/c）。
  **差异**：条目点名的「命令行里提到 agent 路径」窄变异没有——落地的反例臂是整条身份判据被短路，另加 target 组里
  TEAM_ROOT 不一致的正面断言；实现里的 `anon`（有进程但读不到 teamsmith 身份）分支无夹具臂。
- [x] 1.3 发信号**前**复验：仍是该席位的活 agent 进程、窗口仍在、**进程启动时刻与计划时一致**；不一致 → 拒发、
  点名 pid 与理由、退非 0。 · 证据：夹具两条 TOCTOU 现场（先计划、再让 pane 死掉 / 再伪造启动时刻变化）+
  `--flip` 臂（拆掉复验 → 必红；还原 → 绿）。 · **P295 按证据勾**：target 组两条 TOCTOU 现场（执行前 pane 死掉 →
  拒 + 点名「回合已经结束了」；桩 tmux `list-panes` 预算造「第一次读到、复验时变了」→ 拒 + 点名「已经不是计划时那个
  pid」，两条都断言审计不增、thread/inbox 逐字节不变）+ 复验四条分支的库层直调（启动时刻不一致 → 拒并点名 pid 可能
  被回收；一致 → rc=0；pane 里已不是那个 pid；窗口不在）。红侧 `p292-flip-reverify`（拆掉复验）→ 指定用例必红、还原绿
  （P292 §逐条红侧第 3 格）；复验方用真 tmux `respawn-pane` 换 pid 端到端重做，并伪造启动时刻补上内核回收那一格
  （V49 §5a/b）。
- [x] 1.4 信号序列：`SIGTERM` → 有界等待（默认 5 秒，环境变量可调）→ 仍活着再 `SIGKILL`；打印 pid 与信号；
  目标存活 → 退非 0。 · 证据：夹具 `execute` 组（真进程：正常退出 / 忽略 SIGTERM 后被 SIGKILL）+ 静态走查
  `perl skills/teamsmith/tests/signal-lint.pl --legacy /dev/null` 干净。 · **P295 按证据勾**：execute 组两臂——正常退出、
  忽略 SIGTERM 的 stub 被 SIGKILL（审计 `signal=SIGTERM→SIGKILL`、输出点名 SIGKILL、恰好一行）；
  `perl …/signal-lint.pl --legacy /dev/null` 我在本树实跑 **rc=0**（「干净（扫描 119 个脚本；pid 精确形态全部干净）」）。
  **差异**：条目「目标存活 → 退非 0」没有夹具现场（SIGKILL 之后仍活着的进程造不出来）——该分支在 `team_interrupt_signal`
  里是 `still-alive` → 1，只有代码证据；另注意不带 `--legacy /dev/null` 的 `--quiet` 调用会因**树上既有的豁免清单过期**
  报 rc=1（V49 §11 与 v0.2.0 对照条数相同），与本变更无关。
- [x] 1.5 审计：每次**授权的**打断恰好一行 `state/interrupt.log`，字段逐个断言（时间戳、actor、seat、pid、
  `session_last`、`uncommitted`、`guard`、`reason`、`signal`、`outcome`）；**发信号前**读的 `session_last` 与
  `uncommitted`；拒绝的打断**不写**；actor 解析不出来 → 拒绝且什么都不写。 · 证据：夹具 `audit` 组逐字段断言 +
  「拒绝不增长」断言 + actor 不可解析臂（调用目录不在本项目工作树里）。 · **P295 按证据勾**：audit 组 20 条逐字段
  断言——时间戳、actor=pm（运行时目录解析）、seat、pid、`session_last`=**打断前**读数（stub 在 TERM 里把会话文件摸新，
  这一格因此有判别力）、`uncommitted=3`、`guard=clear`、`reason`（多行折叠成一行、行内无控制字符）、`signal`、`outcome`；
  缺理由被拒后审计不增长；actor 解析不出来（在项目之外的 worktree 里调用）→ 拒绝且审计/线程不变、进程不被碰
  （seat-interrupt.sh audit 组；P292 §逐条 scenario 对照 audit 行）。
- [x] 1.6 拒绝集合各自给路：进程不在 → 点名 `team resume`；窗口没了而进程还在（孤儿）→ 点名
  `team reap --orphans`；名字不在名册 → 点名名册；另一项目的席位/无身份进程/调用者自己及其祖先 → 拒发；
  **跨项目零点名**（另一个项目的项目名/席位名/工作树/pid 都不出现在输出里）。 · 证据：夹具 `refuse` 组五条臂 +
  零点名断言 + `ledger-ban.sh` rc=0。 · **P295 按证据勾**：refuse 组五条臂逐字断言——进程不在 → 点名
  `team resume --agent dev2`；孤儿 → 点名 `team reap --orphans`（进程没被碰、审计不增）；不在名册 → 点名名册；
  别的项目身份 → 拒 + 输出里搜不到 `other-proj` 与它的 pid + 进程没被碰；调用者自己/它的祖先 → 拒。`ledger-ban.sh`
  rc=0、hits=0（P292 §账本面）；复验方在真项目替身上重做同一组并逐字贴上五条拒绝消息（V49 §8）。**差异**：条目里的
  「无身份进程」没有独立臂（最近的落地断言是 target 组「窗口在、pane 里没有本项目的 agent 进程 → 拒 + 点名 resume」，
  不是「有进程但读不到身份」的 `anon` 分支）。
- [x] 1.7 读命令永不打断：`team ps`/`team status`/`team roster`/`team digest` 跑过之后进程仍活着、
  `state/interrupt.log` 未增长。 · 证据：夹具断言 + smoke 的 `51`/`51b` 既有段回归。 · **P295 按证据勾**：read 组 6 条
  ——`ps`/`status`/`roster`/`digest` 各跑一次后进程仍活着、`state/interrupt.log` 未增长、线程未增长；复验方四条读命令
  重做（V49 §9）。**差异**：条目点名的 smoke `51`/`51b` 段回归**不在 apply/verify 的已提交证据里**（P292 跑
  `--select 0c,0e,31,51c,58`，V49 跑 `31,51c,58`）——留待 PM 复验时补（见报告 §缺口 4 的连带）。

## 2 理由、新鲜窗口与副作用（规格：`boundary#An interrupt carries its reason to the seat, and a seat that is writing is not interrupted by accident`）

- [x] 2.1 `--reason` 必填：缺 / 空 → 在**任何写入与信号之前**拒绝（审计、thread、inbox 逐字节不变）。理由写进
  该席位的 **thread**（谁/何时/为何/它该先做什么）与 **inbox**（一行持久通知），**先写理由后发信号**；thread 写不
  进去 → 拒绝、不发信号。 · 证据：夹具 `reason` 组（缺/空两条 + thread 不可写臂 + 写序：thread 的 mtime 早于进程
  退出时刻）。 · **P295 按证据勾**：reason 组 20 条——缺/空 `--reason` 两条都在任何写入与信号之前被拒（线程/收件箱/
  审计逐字节不变、进程 alive）；授权打断时 stub 在 TERM 现场检查线程里已有这句话（`ordered`）、线程恰好 +1（条目点名
  from: pm、理由、先做什么）、收件箱恰好 +1 行 `[interrupt]`；线程文件换成目录（写不进去）→ 拒发、点名「写不进该席位的
  线程」、进程仍活、审计与收件箱一个字节不动——这一格是夹具逮到的**真缺陷**（`if !` 复合命令重定向失败的可见性），
  修法见 P292 §真缺陷与翻转证据；红侧 `p292-flip-reason-order` 把投递延迟到信号之后 → 必红、还原绿。**差异**：条目的
  「thread 的 mtime 早于进程退出时刻」落成 stub 在 TERM 现场读线程的 `ordered` 断言（更直接），不是 mtime 比较。
- [x] 2.2 新鲜窗口：证据 = 该席位那次会话的会话文件 mtime ∪ 工作树里 git 报为改动的文件 mtime（**同一次**
  `git status --porcelain -z` 既给计数又给路径）；比窗口（默认 3600 秒，`TEAM_INTERRUPT_FRESH_SEC`）更新 →
  拒绝、点名读到的文件与岁数与窗口、零写盘零信号。 · 证据：夹具 `guard` 组两个形状（会话文件新鲜 / 只有未提交
  文件新鲜）+ 非数字窗口值退回默认的断言 + 拒绝时 thread/inbox/审计逐字节不变。 · **P295 按证据勾**：guard 组 22 条
  ——会话文件新鲜 → 拒且点名文件、岁数、窗口 3600s，进程仍活、审计不增、线程不变；只有工作树未提交文件新鲜 → 也拒并
  点名那个文件；`TEAM_INTERRUPT_FRESH_SEC=not-a-number` → 仍按 3600 判并点名；缺证据（会话文件不在 + 工作树干净）→
  计划态放行且如实写「缺证据不编造」；实现按条目写的一次 `git status --porcelain -z --untracked-files=all` 同时给计数与
  路径、R/C 第二段跳过（cmd-interrupt.sh 的 `team_interrupt_evidence`）。**差异**：条目要的「拒绝时 thread/**inbox**/
  审计逐字节不变」在 guard 组只断言了审计与线程，inbox 未断言（缺理由/TOCTOU 的拒绝臂有 inbox 断言）。
- [x] 2.3 `--force` 只越过新鲜窗口，且越权进审计（`guard=forced`）；它**不**越过身份/存活/名册/跨项目/自身。
  · 证据：夹具两臂（新鲜证据 + `--force` → 进程消失且审计带 `forced`；`--force` + 孤儿/别名目标 → 仍拒绝）+
  `--flip` 臂（让 `--force` 也跳过身份判据 → 必红；还原 → 绿）。 · **P295 按证据勾**：guard 组——`--force` + 新鲜
  会话文件 → 执行成功、目标退出、审计 `guard=forced`（仍是打断前读数、恰好一行、理由也投递）；`--force` + 别的项目身份
  → 仍拒绝、那个进程没被碰、审计不增；红侧 `p292-flip-fresh`（新鲜判据恒放行）→ 必红、还原绿；复验方独立重做同样两臂，
  另证 `--force` 越不过不在名册（V49 §6）。**差异**：条目点名的「让 `--force` 也跳过身份判据」窄变异没有——落地红侧是
  `p292-flip-foreign`（身份判据被整体短路）＋ guard 组 `--force` 越不过身份的正面断言。
- [x] 2.4 磁盘状态逐字节幸存：打断后未提交文件逐字节相同、会话文件仍在且字节数不变（或只增）、派单记录
  `state/<seat>.env` 逐字节不变；除该席位的 thread、它的 inbox 与 `state/interrupt.log` 之外，树指纹前后一致。
  夹具同时记录**只对那一个 pid 发过信号**（一个信号对象）：回合里被 agent 起的工具子进程是否随它退出由那个 CLI
  自己决定，本入口不做组/父子/名字的选择。 · 证据：夹具 `survive` 组（造未提交文件 + 已知字节 + 树指纹 +
  信号对象记录）。 · **P295 按证据勾**：survive 组 10 条——未提交文件逐字节不变（内容仍是那一行）、会话文件仍在且
  sha256 不变、派单记录 `state/dev2.env` 逐字节不变、工作树树指纹前后一致、thread/收件箱/审计各 +1、同身份的另一条进程
  仍在（只有一个信号对象）；复验方在真项目替身上重做：打断前后全树哈希一致、三个未提交文件仍在且内容一致、旁观席位
  零 TERM 且全程活着（V49 §4）。
- [x] 2.5 路线回得去：命令打印 `team resume --agent <seat>`；`team resume --agent <seat> --dry-run` 之后列出该席位
  可续跑；`dispatch --print` 的同一任务计划里 `sid=` 是记录里那个、`mode=continued`；渲染出的提示词里有
  `threads/<seat>.md` 这一步（阅读顺序的第二步）。 · 证据：夹具断言（四条逐个）。 · **P295 按证据勾**：route 组 8 条
  ——输出打印 `team resume --agent dev2` 并点名记录里的 `sid=$SID`、`mode=continued`；执行过打断之后
  `resume --agent dev2 --dry-run` 把该席位「可续跑」、点名同一个 sid 与 continued、渲染出的提示词里点名
  `threads/dev2.md`；复验方在真项目替身上复核同一路（V49 §7：dry-run rc=0、sid、continued、threads/dev1.md）。
  **差异**：条目字面写 `dispatch --print`；落地走 `resume --agent <seat> --dry-run`（同一任务计划，`cmd-watch.sh` 的
  可续跑行），输出里 sid/continued/线程逐条都在。
- [x] 2.6 夹具与门禁接线：`tests/interrupt.sh` 的组与 `--flip` 臂进 `tests/section-paths.tsv`
  (必要时 `section-budgets.tsv`)，`smoke.sh` 新段（**id 定 `51c`**；落地时若与在飞改动撞号，以落地的 id 为准并在
  报告里写明）在 FAST 档跑静态组（计划/拒绝/缺理由/审计字段）并**可见 SKIP** 真进程与变异臂，全量档跑全部；
  `section-select.sh --check` 绿。 · 证据：命令 + rc + 段输出。 · **P295 按证据勾**：段 `51c` 落在 `smoke.sh`（FAST 档
  `--select plan,target,execute,audit,refuse,reason,guard,survive,read,route,hygiene` + 可见
  `skip "51c live 组（真 tmux server）与逐条红侧（FAST 档不跑）"`；全量档跑全组 + `--flip`）；两张表各一行
  （`section-paths.tsv` 依据逐条点名本 change；`section-budgets.tsv` band 40 → budget 160）；`section-select.sh --check`
  rc=0（源码 132 段 / 表 132 行；ok 8 bad 0 SKIP 1）——P292 §验收命令与真实输出。**差异**：①夹具落地名
  `tests/seat-interrupt.sh`（条目写 `tests/interrupt.sh`）；②FAST 档实际跑 11 组（含桩 tmux 下的真进程组），比条目
  「只跑静态组并 SKIP 真进程」更强，只 SKIP 真 server 组与变异臂；③段 id 就是 `51c`，没有撞号。

## 3 命令页与文档面

- [x] 3.1 `scripts/strings/commands.tsv` 加一行（`cmd interrupt seats …`：usage/flags/faces=`state docs`/ · 证据（PM 按事实勾）：P292 收尾轮：`commands.tsv` 的 `interrupt` 行改成实现真正触碰的面与授权语义（提交 `8d126f5d`）；V52 复检核过声明与实现逐项对齐（`docs/team/reviews/V52.md`）
  effect=`writes-state`/auth=`needs-yes`/undo=`not-reversible:…`/probe id），`help.en.tsv` 与 `help.zh.tsv` 加该
  命令的文案键（`title/what/when/example/read/write/see` + 每个 flag 的 `arg.*` + `auth`/`undo`）；
  `bash skills/teamsmith/tests/help-surface.sh --select coverage` 绿，既有命令页逐字节不变。
- [x] 3.2 `tests/help-surface.sh` 加该命令的**探针**（浅 fixture：私有 socket 上起 stub agent 席位 → · 证据（PM 按事实勾）：P292 收尾轮新增 `interrupt` 的 claims 探针配方 + **反向判据**（`changed ⊆ declared`）与工作树内容指纹（`8d126f5d`/`2201dd36`）；V52 第二轮用三个原反例证明它必须红并点名
  `interrupt … --yes` → 声明效果真的发生：审计多一行、进程消失），并让 45 → 46 条命令的双向走查仍绿。
  · 证据：命令 + rc + 走查判过的命令数。
- [x] 3.3 文档：`references/troubleshooting.md` 加一节「席位卡在一个长回合里」（先读什么证据、命令怎么用、 · 证据（PM 按事实勾）：P292 收尾轮：`references/troubleshooting.md` 新增「席位卡在长回合里」一节、`references/protocol.md` 对应小节（V52 第二轮把文档里每条命令逐条对拍真行为）
  拒绝是什么意思、之后怎么回同一会话、以及它**不**改什么）；`references/protocol.md` 加一段「两条信号入口各管
  什么」（`reap` = 孤儿进程、`interrupt` = 活席位的回合；`resume` 只管回来的路）。 · 证据：diff 全文 + 两处
  指回的既有小节没被改写。
- [x] 3.4 静态纪律与回归：`perl skills/teamsmith/tests/signal-lint.pl --legacy /dev/null` 干净（`kill -TERM "$pid"` · 证据（PM 按事实勾）：P292 收尾轮跑了 `perl skills/teamsmith/tests/signal-lint.pl --legacy /dev/null`（干净，报告 §验收）
  的 pid 精确形态）；`bash skills/teamsmith/tests/config-cli.sh` 的 completeness 仍绿（**本变更不新增契约键**，
  所以 `references/config.md` 里不得出现 `TEAM_INTERRUPT_FRESH_SEC`）；smoke 既有段（`51`/`51b`/`33`/`37`）回归。
  · 证据：命令 + rc + 尾部。

## 4 独立验证（另一席位，不是 apply 作者）

- [x] 4.1 在独立冻结克隆里重跑第 1–3 节的**全部**场景，逐条给 command/assertion/rc 与 skip；至少两条用**自建** · 证据（PM 事后按事实勾，注明执行者）：**由独立席位在冻结克隆上完成（比作者自证更强）**：V49 在 `reviews/V49/checkout`（受检 `d3b3e23`）重跑第 1–5 节全场景与保留回归，逐条给 command/rc（`docs/team/reviews/V49.md`）；V52 两轮在同一流程里重跑相关面
  夹具（不复用作者夹具）：建议一条「真进程在私有 socket 上被 `SIGKILL` 收干净」、一条「跨项目零点名」。
- [x] 4.2 逐条重做红侧（1.2 / 1.3 / 2.3 / 2.6），破坏必红、还原必绿；并自设计至少一条相邻反例（建议：席位在 · 证据（PM 事后按事实勾，注明执行者）：**同上，由独立席位完成**：V49 自造三条红侧（含一条相邻反例）；V52 两轮又补了探针反向判据与 `reap` 指向的反例（`docs/team/reviews/V52.md`）
  **另一个 tmux server** 上的同名窗口；进程身份属于本项目但 `TEAM_ROOT` 与派单记录的工作树不一致的进程；
  `--reason` 里带换行与超长文本时的审计行形状）。
- [x] 4.3 判 `verification` 的正确性门：只有证据通过；不因为作者报告说绿就判过。 · 证据： · 证据（PM 事后按事实勾，注明执行者）：PM 据 V49 与 V52 两轮的证据判过 `verification` 门（PASS）；**不以作者报告为依据**（本轮还因此翻出四类真问题：探针缺反向判据、`reap` 缺指向、以及收尾轮的活红）
  `docs/team/reviews/<ID>.md`。

## 5 apply / verify 的验收命令（propose 阶段不运行）

```bash
bash skills/teamsmith/tests/interrupt.sh --select plan,target,execute,audit,refuse,reason,guard,survive
bash skills/teamsmith/tests/interrupt.sh --flip
bash skills/teamsmith/tests/smoke.sh --select 51c,51,51b,33,37
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/cmd-interrupt.sh \
  skills/teamsmith/scripts/team skills/teamsmith/scripts/strings/commands.tsv
bash skills/teamsmith/tests/help-surface.sh --select coverage
bash skills/teamsmith/tests/config-cli.sh
perl skills/teamsmith/tests/signal-lint.pl --legacy /dev/null
bash skills/teamsmith/tests/spec-refs.sh --check
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

红侧按第 1.2 / 1.3 / 2.3 / 2.6 节逐条现场改坏再还原（scratch 变异，只写 `${TMPDIR:-/tmp}` 下的 owned 根）；夹具
与命令的最终形态以 apply 冻结的接口为准，但**场景名与红侧方向**不得改（改了就是换合同，要重新走提案）。新增门禁段
的 id 以 apply 落地的 `smoke.sh` 段为准（建议 `51c`），段名与 `section-paths.tsv` 的 basis 必须点名本 change。
`TEAM_SMOKE_FAST=1` 用于逐改动的快速回归；全量门禁留给 PM 复验与合并，按纪律后台跑。
