# orphan-visibility · tasks

阶段口径：**propose 已由 dev3 完成**（本文件第 0 节）。**apply 按 delta 切成两个任务顺序执行**
（apply-1 声明 `deltas: seat-visibility,board-and-status`；apply-2 声明 `deltas: boundary`——两组不相交，
满足 delta 单写者守卫；两者都碰 `common.sh`/`cmd-status.sh`，**不同时派**，且 apply-2 的复验要用 apply-1 的
普查判据，所以顺序固定）。**verify 由没有写过本 change 的席位**在独立克隆上逐场景 + 逐红侧重跑（写的人不
验自己的活）。本文件不是规格；合同文本在三份 delta 里，逐条 MODIFIED 必须带全基线场景。

规格 ↔ 任务对照（闭合两向，PM 的 checklist 第 3 条）：

| 规格 | 任务 |
|---|---|
| `seat-visibility#A seat process is identified from its own environment and executable` | 1.1–1.4 |
| `seat-visibility#An orphan is a seat process with no live pane, judged on the process's own tmux server` | 2.1–2.4 |
| `seat-visibility#The reading names this project's orphans and only counts the rest` | 3.1–3.3 |
| `seat-visibility#The reading is additive, bounded and read-only` | 4.1–4.4 |
| `seat-visibility#The digest warns on its capacity line above a threshold, without changing its exit code` | 5.1–5.2 |
| `boundary#Orphan seat processes of this project are reaped by pid, with an audit and no pattern` | 6.1–6.6 |
| `board-and-status#The ledger read path stays inside a git-call budget and its cache is an equivalence-checked view` | 7.1–7.2 |

## 0 提案（propose 阶段，本任务已完成）

- [x] 0.1 三份 delta 写全（`seat-visibility` 5 ADDED、`boundary` 1 ADDED、`board-and-status` 1 MODIFIED 带全
  三条基线场景），`proposal.md` + `design.md` + `tasks.md` 与规格逐条对齐（无孤儿任务、无无主要求）。
- [x] 0.2 事实基础是实测而不是转述：本机 `/proc/*/environ` 只读盘点（身份变量、`TMUX`/`TMUX_PANE` 的存在、
  「有 pane 已死」与「无 `TMUX_PANE`」两种残留并存）、现有判据代码路径（`team_agent_alive_in_pane`、
  `team_agent_bin_path`、`team_pm_bin_path`、`team_proc_cmdline_is_bin`）、`team ps`/`team status` 的现
  输出、M50 的缓存等价性归一化（`grep -v 'RAM 可用'`）、帮助清单与 `signal-lint.pl` 的既有纪律。
  · 证据：`docs/team/reports/P269-dev3.md` 的「事实基础」段（命令 + 输出尾）。
- [x] 0.3 跨能力影响写清：`board-and-status` 的实时字段表（唯一被改的既有 requirement）、`boundary` 的破坏性
  纪律家、`cli-help`/`help-surface` 的命令清单、三个新契约键的四面登记与面板重建。
  · 证据：`proposal.md` 的 Capabilities / Impact 两节。
- [x] 0.4 propose 阶段验收跑过并贴出：`openspec validate --all --strict`、`spec-refs.sh --check`、
  `ledger-ban.sh`、`git diff --check && git status --short`。
  · 证据：`docs/team/reports/P269-dev3.md` 的「验收（propose）」段。

## 1 普查与身份判据（规格：`seat-visibility#A seat process is identified from its own environment and executable`）

- [ ] 1.1 `team_orphan_census`（名字以 apply 冻结为准）在 `common.sh` 里：枚举 `TEAM_ORPHAN_PROC_ROOT`
  下的 pid，读每个进程的 `environ` 取 `TEAM_MAIN_ROOT`/`TEAM_ROOT`/`TMUX`/`TMUX_PANE`，形状判据复用
  `team_proc_cmdline_is_bin` + `team_agent_bin_path`/`team_pm_bin_path`（**不新造第二套**）；输出每行
  一条记录（pid / rss / seat / 来源记录 / start）。**先一次 `ps -eo pid=,args=` 筛候选再读 `/proc`**
  （同 `team_pm_other_sessions_in_dir` 的既有做法），避免每个 pid 都 fork。 · 证据：夹具 `census` 组
  逐字段断言 + 真进程现场 + 一次普查的 fork/耗时读数
- [ ] 1.2 项目归属按进程自己的 `TEAM_MAIN_ROOT`（物理路径规范化）判定，席位名由 `TEAM_ROOT` 相对该项目
  工作树目录推出；调用者的身份**不参与**判定。 · 证据：夹具里「从项目 B 调用、进程属于项目 A」的用例
- [ ] 1.3 任务取 `state/<seat>.env` 的 `task` 并**标明来源**；启动时间取 `/proc/<pid>/stat` 第 22 字段 +
  `btime`，内存取 `VmRSS`；读不到就不写（绝不填 0/占位）。 · 证据：夹具里「记录比进程新」的用例 + 缺字段用例
- [ ] 1.4 红侧：把形状判据换成「命令行里提到 agent 路径」（P103 的旧形状）→ 夹具必须点名假阳性（`-e` 参数、
  `dispatch-*.spawn` 启动壳）；还原 → 绿。 · 证据：`--flip` 的对应臂 red→green 原始输出

## 2 孤儿判据（规格：`seat-visibility#An orphan is a seat process with no live pane, judged on the process's own tmux server`）

- [ ] 2.1 判据 = `TMUX_PANE` 为空 或 不在**进程自己 socket**（`TMUX` 第一段）的 pane 集合里
  （`tmux -S <socket> list-panes -a -F '#{pane_id}'`）；server 查询不到 → 该进程进「未判定」计数，
  **不进**孤儿。 · 证据：夹具 `judge` 组的四个方向（活窗 / 别的 session / pane 在别的 server / 窗口已杀）
- [ ] 2.2 红侧 A：把判据改成「不是当前窗口的 pane」→ 正常在跑的席位被误判为孤儿，夹具必红；还原 → 绿。
- [ ] 2.3 红侧 B：把判据改成拿**默认 server** 的 pane 表比对 → 私有 socket 上的活席位被误判为孤儿，夹具必红；
  还原 → 绿。（这是任务书红侧 ② 的核心，也是本设计 §2 的理由。）
- [ ] 2.4 红侧 C：server 查询不到时改成「算孤儿」→ 夹具的「未判定」用例必红；还原 → 绿。
  · 证据：2.2–2.4 各给 red→green 原始输出（`--flip` 表里逐臂一行）

## 3 点名与只计数（规格：`seat-visibility#The reading names this project's orphans and only counts the rest`）

- [ ] 3.1 本项目的孤儿逐条打印 pid/内存/席位/记录任务/启动时间 + 一条可复制的清理命令（`team reap <pid>`）。
- [ ] 3.2 别的项目与身份为空的同形状进程只进「计数 + 合计内存」，标 `≥`；输出里**不得**出现它们的 pid、
  项目名、席位名、工作树路径。 · 证据：夹具对输出做逐字断言（不点名）+ `ledger-ban.sh` rc=0
- [ ] 3.3 没有孤儿时恰好一行、零命令。 · 证据：夹具用例
- [ ] 3.4 红侧：让只计数的那一桶改成点名（打印 pid）→ 夹具必红；还原 → 绿。 · 证据：`--flip` 臂

## 4 读数只增、有界、只读、可关、不进面板（规格：`seat-visibility#The reading is additive, bounded and read-only`）

- [ ] 4.1 `team ps` 与 `team status` 追加同一块读数（同一个函数，两处逐字一致）；`team up` 在启动决策之后打
  一行（有孤儿：计数 + 合计 + 命令；没有：一行「无孤儿席位进程」）；三处都不发任何信号。
  · 证据：夹具对比 `ps`/`status` 的读数块逐字节相同 + 真进程现场
- [ ] 4.2 只增不改：`TEAM_ORPHAN_SCAN=0` 与开启两次 `team ps` 的**既有每一行**逐字节相同（容量行/存活块/
  模型表/会话块/窗口列表）。 · 证据：夹具的 diff 断言（`--flip` 臂：让读数插进容量行 → 必红）
- [ ] 4.3 有界与竞态安全：读不到 / 中途消失 / 缺字段一律跳过；`ps`/`status`/`up` 的退出码不因普查改变；
  普查不写任何文件（前后 `state/` 快照相同）。 · 证据：夹具的四种边界（`TEAM_ORPHAN_PROC_ROOT`）+ 快照断言
- [ ] 4.4 面板数据面不变：`team __panel-data --no-activity` 前后逐字节相同（除既有实时字段），开/关普查
  也一样。 · 证据：夹具断言 + smoke §37 回归
- [ ] 4.5 红侧：把普查挂进 `__panel-data` → 面板数据面夹具必红；还原 → 绿。

## 5 digest 容量行提示（规格：`seat-visibility#The digest warns on its capacity line above a threshold, without changing its exit code`）

- [ ] 5.1 `team digest` 的容量行**行尾**追加提示（总量 / 本项目份额 / 可复制命令），仅当合计 ≥
  `TEAM_ORPHAN_WARN_MB`；不是红、不改退出码、不新开行。 · 证据：夹具在阈值上下各一次（`TEAM_ORPHAN_WARN_MB`
  夹具旋钮）+ 退出码断言
- [ ] 5.2 红侧：让提示变成独立一行 → M50 的 digest 归一化必红（`m50_dg_norm` 只滤 `RAM 可用`）；还原 → 绿。
  · 证据：red→green 原始输出（smoke §37 的 M50 组）

## 6 `team reap`（规格：`boundary#Orphan seat processes of this project are reaped by pid, with an audit and no pattern`）

- [ ] 6.1 `team reap --orphans`（计划）打印目标与将发的信号、**一个信号都不发**、退 0；`team reap <pid>`
  同样。 · 证据：夹具 `kill -0` 前后 + `state/reap.log` 未增长 + rc
- [ ] 6.2 `--yes` 执行：每个目标发信号前复验（仍是本项目席位 / 仍无活 pane / 启动时刻一致），
  `SIGTERM` → 有界等待 → 仍活着再 `SIGKILL`；每个信号一行 `state/reap.log`（时间戳/pid/席位/信号/结果）；
  打印它发了什么；有目标存活 → 退非 0。 · 证据：真进程现场（红侧 ①）+ 审计行逐字
- [ ] 6.3 拒绝集合：别的项目的席位 / 身份为空 / 调用者自己及其祖先 → 不发、点名原因、退非 0。
  · 证据：夹具三例 + 真进程现场
- [ ] 6.4 复验（TOCTOU）：计划时是孤儿、执行前 pane 回来了（或 pid 被回收 → 启动时刻变了）→ 拒绝该 pid、
  退非 0。 · 证据：夹具用「先计划、再把进程放进一个 pane、再 --yes」的现场
- [ ] 6.5 `--yes` 是唯一授权：`TEAM_CONFIRM_WRITES=0/1`、继承的环境变量都不能让它默认开；不带 `--yes`
  永不发信号。 · 证据：夹具的授权矩阵
- [ ] 6.6 红侧：把复验拆掉（直接按计划 pid 发信号）→ 6.4 的用例必红；还原 → 绿。 · 证据：`--flip` 臂
- [ ] 6.7 静态纪律：`perl skills/teamsmith/tests/signal-lint.pl --legacy /dev/null` 必须干净（`team reap` 的
  `kill` 是 pid 精确形态；不许 `pkill`/`killall`/`pgrep` 选进程）。裸调用（不带 `--legacy`）今天因为一条过期
  的豁免清单（一个已不在树里的历史证据包）而红，闸门 §58 的既有做法就是改用空清单跑；两者对 `team reap`
  的判定相同。 · 证据：命令 + rc + 尾部

## 7 帮助面、契约键与闸门归一化

- [ ] 7.1 `team reap` 进命令清单 `scripts/strings/commands.tsv`（一行：usage/flags/四字段）并有命令页；
  `bash skills/teamsmith/tests/help-surface.sh --select coverage` 绿；既有命令的页面逐字节不变。
  · 证据：命令 + rc + 走查判过的命令数与 usage 行数
- [ ] 7.2 `board-and-status` 的闸门归一化：`smoke.sh` 的 M50 组给 `team status` 的输出加「滤掉普查块」的
  归一化（`m50_st_norm`），断言「滤后逐字节一致 + 两次都直读、不经缓存」。 · 证据：smoke §37 的 M50 组输出
- [ ] 7.3 三个契约键四面登记：`cmd-config.sh` schema 行（组 `delivery`）、`templates/config.sh.tmpl`、
  `references/config.md`、面板 `zh.ts`+`en.ts` 的 `label_TEAM_ORPHAN_WARN_MB`/`label_TEAM_ORPHAN_SCAN`/
  `label_TEAM_ORPHAN_PROC_ROOT`（`TEAM_ORPHAN_PROC_ROOT` 的 route 列以 `fixture-only: ` 开头）；
  用钉住的工具链重建 `scripts/panel/panel.js`。 · 证据：`config-cli.sh`（完整性走查）、
  `panel-strings.mjs`、`bash build.sh` 后 `panel.js` 的 sandbox 逐字节比对
- [ ] 7.4 夹具与路径归属：新 `tests/orphan-census.sh` 的 `--select` 分组与 `--flip` 臂进 `tests/section-paths.tsv`
  （必要时 `section-budgets.tsv`）；`section-select.sh --check` 绿。 · 证据：命令 + rc
- [ ] 7.5 文档：`references/config.md` 的键说明 + `references/troubleshooting.md` 一段「孤儿是什么、怎么清、
  为什么默认不清」（若既有章节已覆盖则不新增章节）；**不重写** `team help` 的既有页面。
  · 证据：diff 全文

## 8 独立验证（另一席位，不是 apply 作者）

- [ ] 8.1 在独立冻结克隆重跑第 1–7 节的**全部**场景与回归，逐条给 command/assertion/rc 与 skip；对每条
  requirement 至少一个场景用**自建**夹具（不复用作者夹具）。 · 证据：独立记录 + 原始日志
- [ ] 8.2 逐条重做红侧（1.4 / 2.2–2.4 / 3.4 / 4.5 / 5.2 / 6.6），破坏必红、还原必绿，不是只复跑绿侧；
  并自设计至少一条相邻反例（建议：两个私有 socket 上同名 pane id 的席位；一个「进程身份属于本项目但
  `TEAM_ROOT` 不在工作树目录里」的进程；`team reap` 的 pid 在 `--yes` 与信号之间被回收）。 · 证据：red→green 原始输出
- [ ] 8.3 判 `verification` 的正确性门：只有证据通过；不因为作者报告说绿就判过。 · 证据：`docs/team/reviews/<ID>.md`

## 9 apply / verify 的验收命令（propose 阶段不运行）

```bash
bash skills/teamsmith/tests/orphan-census.sh --select census,judge,reading,naming,hint,seams
bash skills/teamsmith/tests/orphan-census.sh --flip
bash skills/teamsmith/tests/smoke.sh --select 6b,6h,7,11b2,11b3,11c,37,33
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/common.sh \
  skills/teamsmith/scripts/lib/cmd-status.sh skills/teamsmith/scripts/lib/cmd-watch.sh
bash skills/teamsmith/tests/config-cli.sh
bash skills/teamsmith/tests/panel-strings.mjs
bash skills/teamsmith/tests/help-surface.sh --select coverage
perl skills/teamsmith/tests/signal-lint.pl --legacy /dev/null
bash skills/teamsmith/tests/spec-refs.sh --check
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
```

红侧按第 1.4/2.2–2.4/3.4/4.5/5.2/6.6 节逐条现场改坏再还原（scratch 变异，只写 `${TMPDIR:-/tmp}` 下的 owned
根）；夹具与命令的最终形态以 apply 冻结的接口为准，但**场景名与红侧方向**不得改（改了就是换合同，要重新
走提案）。`TEAM_SMOKE_FAST=1` 用于逐改动的快速回归；全量门禁留给 PM 复验与合并，按纪律后台跑。
