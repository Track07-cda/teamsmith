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

- [ ] 1.1 新 `skills/teamsmith/scripts/lib/cmd-interrupt.sh` 落 `team interrupt <seat> --reason <一句话>
  [--force] [--yes]`：无 `--yes` 是计划态（打印席位/pid/读到的证据/将发的信号，**零信号零写盘**，退 0；目标不可
  打断则退非 0 并点名拒绝与出路），有 `--yes` 才执行；`scripts/team` 加一个分发标签。退出码：计划 0、拒绝 2、
  执行未收干净非 0。 · 证据：夹具 `plan` 组（`kill -0 <pid>` 前后 + `state/interrupt.log` 未增长 + thread/inbox
  逐字节不变 + 输出的三个字段）+ `team help interrupt` 渲染。
- [ ] 1.2 对象证明链按 design §3：名册 → 派单记录的 `window=` → 该 pane 的 agent 进程（`team_pane_agent_pid` 的
  既有形状，含 `bash <agent>` 的 P217 情形）→ 普查的同一套身份判据（进程自己的 `TEAM_MAIN_ROOT`/`TEAM_ROOT` +
  命令行命中本项目 agent 可执行文件）；**不新增第二套判据**。 · 证据：夹具 `target` 组（真 stub agent 进程 +
  私有 socket；断言计划打印的 pid 就是那个 stub 的 pid，且它自己的 environ 属于本项目）+ 反例臂：把身份判据换成
  「命令行里提到 agent 路径」→ 夹具必红。
- [ ] 1.3 发信号**前**复验：仍是该席位的活 agent 进程、窗口仍在、**进程启动时刻与计划时一致**；不一致 → 拒发、
  点名 pid 与理由、退非 0。 · 证据：夹具两条 TOCTOU 现场（先计划、再让 pane 死掉 / 再伪造启动时刻变化）+
  `--flip` 臂（拆掉复验 → 必红；还原 → 绿）。
- [ ] 1.4 信号序列：`SIGTERM` → 有界等待（默认 5 秒，环境变量可调）→ 仍活着再 `SIGKILL`；打印 pid 与信号；
  目标存活 → 退非 0。 · 证据：夹具 `execute` 组（真进程：正常退出 / 忽略 SIGTERM 后被 SIGKILL）+ 静态走查
  `perl skills/teamsmith/tests/signal-lint.pl --legacy /dev/null` 干净。
- [ ] 1.5 审计：每次**授权的**打断恰好一行 `state/interrupt.log`，字段逐个断言（时间戳、actor、seat、pid、
  `session_last`、`uncommitted`、`guard`、`reason`、`signal`、`outcome`）；**发信号前**读的 `session_last` 与
  `uncommitted`；拒绝的打断**不写**；actor 解析不出来 → 拒绝且什么都不写。 · 证据：夹具 `audit` 组逐字段断言 +
  「拒绝不增长」断言 + actor 不可解析臂（调用目录不在本项目工作树里）。
- [ ] 1.6 拒绝集合各自给路：进程不在 → 点名 `team resume`；窗口没了而进程还在（孤儿）→ 点名
  `team reap --orphans`；名字不在名册 → 点名名册；另一项目的席位/无身份进程/调用者自己及其祖先 → 拒发；
  **跨项目零点名**（另一个项目的项目名/席位名/工作树/pid 都不出现在输出里）。 · 证据：夹具 `refuse` 组五条臂 +
  零点名断言 + `ledger-ban.sh` rc=0。
- [ ] 1.7 读命令永不打断：`team ps`/`team status`/`team roster`/`team digest` 跑过之后进程仍活着、
  `state/interrupt.log` 未增长。 · 证据：夹具断言 + smoke 的 `51`/`51b` 既有段回归。

## 2 理由、新鲜窗口与副作用（规格：`boundary#An interrupt carries its reason to the seat, and a seat that is writing is not interrupted by accident`）

- [ ] 2.1 `--reason` 必填：缺 / 空 → 在**任何写入与信号之前**拒绝（审计、thread、inbox 逐字节不变）。理由写进
  该席位的 **thread**（谁/何时/为何/它该先做什么）与 **inbox**（一行持久通知），**先写理由后发信号**；thread 写不
  进去 → 拒绝、不发信号。 · 证据：夹具 `reason` 组（缺/空两条 + thread 不可写臂 + 写序：thread 的 mtime 早于进程
  退出时刻）。
- [ ] 2.2 新鲜窗口：证据 = 该席位那次会话的会话文件 mtime ∪ 工作树里 git 报为改动的文件 mtime（**同一次**
  `git status --porcelain -z` 既给计数又给路径）；比窗口（默认 3600 秒，`TEAM_INTERRUPT_FRESH_SEC`）更新 →
  拒绝、点名读到的文件与岁数与窗口、零写盘零信号。 · 证据：夹具 `guard` 组两个形状（会话文件新鲜 / 只有未提交
  文件新鲜）+ 非数字窗口值退回默认的断言 + 拒绝时 thread/inbox/审计逐字节不变。
- [ ] 2.3 `--force` 只越过新鲜窗口，且越权进审计（`guard=forced`）；它**不**越过身份/存活/名册/跨项目/自身。
  · 证据：夹具两臂（新鲜证据 + `--force` → 进程消失且审计带 `forced`；`--force` + 孤儿/别名目标 → 仍拒绝）+
  `--flip` 臂（让 `--force` 也跳过身份判据 → 必红；还原 → 绿）。
- [ ] 2.4 磁盘状态逐字节幸存：打断后未提交文件逐字节相同、会话文件仍在且字节数不变（或只增）、派单记录
  `state/<seat>.env` 逐字节不变；除该席位的 thread、它的 inbox 与 `state/interrupt.log` 之外，树指纹前后一致。
  夹具同时记录**只对那一个 pid 发过信号**（一个信号对象）：回合里被 agent 起的工具子进程是否随它退出由那个 CLI
  自己决定，本入口不做组/父子/名字的选择。 · 证据：夹具 `survive` 组（造未提交文件 + 已知字节 + 树指纹 +
  信号对象记录）。
- [ ] 2.5 路线回得去：命令打印 `team resume --agent <seat>`；`team resume --agent <seat> --dry-run` 之后列出该席位
  可续跑；`dispatch --print` 的同一任务计划里 `sid=` 是记录里那个、`mode=continued`；渲染出的提示词里有
  `threads/<seat>.md` 这一步（阅读顺序的第二步）。 · 证据：夹具断言（四条逐个）。
- [ ] 2.6 夹具与门禁接线：`tests/interrupt.sh` 的组与 `--flip` 臂进 `tests/section-paths.tsv`
  (必要时 `section-budgets.tsv`)，`smoke.sh` 新段（**id 定 `51c`**；落地时若与在飞改动撞号，以落地的 id 为准并在
  报告里写明）在 FAST 档跑静态组（计划/拒绝/缺理由/审计字段）并**可见 SKIP** 真进程与变异臂，全量档跑全部；
  `section-select.sh --check` 绿。 · 证据：命令 + rc + 段输出。

## 3 命令页与文档面

- [ ] 3.1 `scripts/strings/commands.tsv` 加一行（`cmd interrupt seats …`：usage/flags/faces=`state docs`/
  effect=`writes-state`/auth=`needs-yes`/undo=`not-reversible:…`/probe id），`help.en.tsv` 与 `help.zh.tsv` 加该
  命令的文案键（`title/what/when/example/read/write/see` + 每个 flag 的 `arg.*` + `auth`/`undo`）；
  `bash skills/teamsmith/tests/help-surface.sh --select coverage` 绿，既有命令页逐字节不变。
- [ ] 3.2 `tests/help-surface.sh` 加该命令的**探针**（浅 fixture：私有 socket 上起 stub agent 席位 →
  `interrupt … --yes` → 声明效果真的发生：审计多一行、进程消失），并让 45 → 46 条命令的双向走查仍绿。
  · 证据：命令 + rc + 走查判过的命令数。
- [ ] 3.3 文档：`references/troubleshooting.md` 加一节「席位卡在一个长回合里」（先读什么证据、命令怎么用、
  拒绝是什么意思、之后怎么回同一会话、以及它**不**改什么）；`references/protocol.md` 加一段「两条信号入口各管
  什么」（`reap` = 孤儿进程、`interrupt` = 活席位的回合；`resume` 只管回来的路）。 · 证据：diff 全文 + 两处
  指回的既有小节没被改写。
- [ ] 3.4 静态纪律与回归：`perl skills/teamsmith/tests/signal-lint.pl --legacy /dev/null` 干净（`kill -TERM "$pid"`
  的 pid 精确形态）；`bash skills/teamsmith/tests/config-cli.sh` 的 completeness 仍绿（**本变更不新增契约键**，
  所以 `references/config.md` 里不得出现 `TEAM_INTERRUPT_FRESH_SEC`）；smoke 既有段（`51`/`51b`/`33`/`37`）回归。
  · 证据：命令 + rc + 尾部。

## 4 独立验证（另一席位，不是 apply 作者）

- [ ] 4.1 在独立冻结克隆里重跑第 1–3 节的**全部**场景，逐条给 command/assertion/rc 与 skip；至少两条用**自建**
  夹具（不复用作者夹具）：建议一条「真进程在私有 socket 上被 `SIGKILL` 收干净」、一条「跨项目零点名」。
- [ ] 4.2 逐条重做红侧（1.2 / 1.3 / 2.3 / 2.6），破坏必红、还原必绿；并自设计至少一条相邻反例（建议：席位在
  **另一个 tmux server** 上的同名窗口；进程身份属于本项目但 `TEAM_ROOT` 与派单记录的工作树不一致的进程；
  `--reason` 里带换行与超长文本时的审计行形状）。
- [ ] 4.3 判 `verification` 的正确性门：只有证据通过；不因为作者报告说绿就判过。 · 证据：
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
