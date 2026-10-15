# orphan-visibility · 孤儿席位进程看得见：报告、点名本项目的、清理要显式

## Why

**事故（2026-10-15，PM 实测）**：机器 OOM 之后，本项目的席位进程全没了，但同机**其他项目**留下了一批
**孤儿 Pi 进程**——它们的 tmux 窗口已死（`tmux list-panes` 里找不到），进程本身还活着并各自占 0.2–0.6 GB，
实测七个数合计约 4 GB。它们对使用者是**不可见**的：窗口没了、`team status`/`team resume` 也看不到
（存活判据按窗口算），但内存被占着，直接加剧下一次 OOM——而 OOM 会连带杀掉**所有**项目的团队。

事实基础（本机只读盘点，2026-10-15，本次提案期间实测）：

- 席位进程的环境里确实带着身份：`TEAM_ROOT`（它启动时所在的工作树）、`TEAM_MAIN_ROOT`（它属于哪个项目）、
  `TEAM_PROJECT`、`TEAM_SESSION`，另外 tmux 自己写入 `TMUX`（socket 路径 + server pid）与 `TMUX_PANE`。
  本机 `/proc/*/environ` 实测：90 个进程带 `TEAM_ROOT`，其中既有活着的席位，也有窗口已死的残留。
- 「没有窗口」不等于「不是任何 pane」：实测本机同一时刻既有一批「`TMUX_PANE` 指向的 pane 已不在任何
  server 上」的进程（含开发服务器、面板、以及一个 623 MB 的 tmux server 自身），也有一批「根本没有
  `TMUX_PANE`」的进程。判据必须落在「它的 pane 还在不在」上，且**按它自己那个 tmux server 判**
  （pane id 是**每 server 唯一**的：拿本机默认 server 的 pane 表去比对别的 socket 上的席位，会把活着的
  席位判成孤儿——本项目的夹具恰恰大量使用私有 socket）。
- 现有存活判据（`team_agent_alive_in_pane`）是**按窗口**的：没有窗口 = 看不到 = 不计数。这正是孤儿
  不可见的根因，本提案不推翻它，只补一条**从主机侧**看的读数。

本提案的立场（正面回应任务书五条）：**看得见、只报告、清理显式**。默认一个信号都不发；跨项目只报
**本机总量**（账本会随公开树发布，仓内记录不许出现别的项目名）；本项目的孤儿给一个显式的、带
`--yes` 与审计的清理入口。判据复用既有的身份解析（`team_agent_bin_path` / `team_pm_bin_path`），
不新造第二套「谁是席位」的定义。

## What Changes

1. **一个主机侧普查（新能力 `seat-visibility`）**：`team ps`、`team status`、`team up` 增加一项
   **孤儿席位进程**读数。普查不经过 tmux 枚举，而是读 `/proc`：进程**自己的**环境带 teamsmith 身份
   （`TEAM_MAIN_ROOT`/`TEAM_ROOT`）**且**命令行命中本项目配置的 agent/PM 可执行文件，就是席位进程；
   席位名由 `TEAM_ROOT` 相对该项目工作树目录推出；任务取该项目为这个席位**已提交的**派单记录
   （`state/<seat>.env`），并**标明它来自记录**（记录可能比进程新）；启动时间取进程自己的 start tick，
   内存取 `VmRSS`。
2. **孤儿的判据 = 没有活着的 pane，且按进程自己的 server 判**：`TMUX_PANE` 为空，或它**不在进程自己
   那个 tmux socket 的 pane 集合里**（`TMUX` 里就有 socket 路径与 server pid）。**不许**用「不是当前
   窗口的 pane」或「不是本项目的窗口」当判据；**不许**拿另一个 server 的 pane 表比对。那个 server
   查询不到（socket 没了、tmux 不可用）→ 该进程**判不了**，读数里单列「未判定 N 个」，**绝不**当成
   孤儿（假孤儿会诱导一次错误的清理）。
3. **点名本项目、其余只计数**：本项目的孤儿逐条打印 pid、内存、席位、记录里的任务、启动时间，并各给
   一条**可复制**的清理命令；**别的项目**的孤儿与**身份读不出来**的同形状进程只进「计数 + 合计内存」，
   一个 pid、一个项目名、一个席位名、一条工作树路径都不打——而且合计标成**下限**（`≥`），因为形状判据
   认得的是本项目配置的 Pi/agent 形状，认不出别的项目用的自定义 adapter。
4. **只报告，不擅自杀；清理是另一条显式、复验过、有审计的命令**：`team reap --orphans`（无 `--yes`）
   只打印计划、一个信号都不发、退 0；`team reap --orphans --yes` / `team reap <pid> --yes` 在每个目标
   **发信号前重新验一遍**（仍是本项目席位、仍没有活 pane、进程启动时刻与计划时一致——pid 被内核回收
   就杀不到别人），先 `SIGTERM`、有界等待、仍活着再 `SIGKILL`，每个信号写一行 `state/reap.log`
   （时间戳 / pid / 席位 / 信号 / 结果）。**`--yes` 是唯一授权**，没有配置键能让它默认开；别的项目、
   身份为空、调用者自己或其祖先，一律拒发并点名原因。这条要求落在既有能力 `boundary`（那里已经是
   「信号只发给记录过的 pid」与「`team bg` 按记录 pid 停、并打印它停了什么」的家）。
5. **digest 的容量行加一条阈值提示**：本机孤儿合计 ≥ `TEAM_ORPHAN_WARN_MB`（默认 1024）时，`team digest`
   的容量行**行尾**追加一条提示（总量、本项目份额、可复制的清理命令）；低于阈值一个字都不加。不是红、
   是同一行的后缀（因此 digest 的缓存等价性检查照旧把那一行当实时字段）、**不改退出码**。
6. **读数只增不改、有界、只读**：`team ps` 的既有每一行（容量行、存活块、模型表、会话块、窗口列表）
   逐字节不变，读数只增行；普查不写任何文件、不发任何信号、有界；`/proc` 条目读不到/中途消失 → 跳过，
   绝不让调用命令失败；`TEAM_ORPHAN_SCAN=0` 完全不扫并打一行**点名**的跳过。普查**不进面板数据面**
   （`team __panel-data` 与面板输出不变：面板按帧预算刷新，一次全主机普查会把预算打穿）。
7. **三个契约键**（四面登记：schema / `templates/config.sh.tmpl` / `references/config.md` / 面板
   `zh.ts`+`en.ts` 的 `label_<KEY>`）：`TEAM_ORPHAN_WARN_MB`（mb，默认 1024，组 `delivery`）、
   `TEAM_ORPHAN_SCAN`（bool，默认 1，组 `delivery`）、`TEAM_ORPHAN_PROC_ROOT`（path/dir，默认 `/proc`，
   `fixture-only:` 的夹具接缝，组 `delivery`）。加面板文案必须用钉住的工具链重建 `panel.js`。
8. **红侧（apply/verify 阶段执行）**：① 起一个带本项目身份、不在 tmux 里的 Pi 替身 → 被点名、`--yes`
   清理后消失；② 正常在跑的席位**不得**被判成孤儿（判据是「无 pane」而不是「不是当前 pane」；含
   「同一 pane id 存在于另一个 server」这条反例）；③ 身份为空/属于别的项目 → 只进总量、不点名、不清理。

## Capabilities

### New Capabilities

- `seat-visibility` —— 席位进程的主机侧普查：身份与形状的判据、孤儿的判据（按进程自己的 tmux server）、
  点名与只计数的边界、读数只增/有界/只读/可关、digest 容量行的阈值提示。五条 requirement 全部是
  **ADDED**（本能力今天不存在：现有 `dispatch` 的容量读数、`board-and-status` 的窗口存活都不覆盖
  「窗口没了但进程还活着」这一格）。

### Modified Capabilities

- `board-and-status`
  - **MODIFIED** `The ledger read path stays inside a git-call budget and its cache is an equivalence-checked
    view`：只改**实时字段的枚举**——`(timestamps and capacity)` → `(timestamps, capacity, and the orphan
    seat-process census)`，并补一句「闸门按这张表过滤」。理由：`team status` 现在会打印普查读数（任务书
    第 1 条），而它是主机实时状态；不把它写进实时字段表，这条 requirement 就变成假的（缓存开/关两次
    运行之间 RSS 会变）。三条基线场景逐字保留，另加一条「普查被当实时字段过滤、且两次都直读不缓存」。
    这是本变更唯一一条被改动的既有 requirement。
- `boundary`
  - **ADDED** `Orphan seat processes of this project are reaped by pid, with an audit and no pattern`：`team reap`
    的计划/`--yes` 两态、发信号前的复验（含启动时刻一致，防 pid 回收）、拒绝集合（别的项目 / 身份为空 /
    调用者自己与祖先）、`SIGTERM`→有界等待→`SIGKILL`、`state/reap.log` 一行一信号、`--yes` 是唯一授权、
    不许按名字或模式选进程、按 pid 选。它复用该能力已有的纪律（`Signals go to a recorded pid, never to a
    name or a pattern`、``team bg` stops a job by the pid it recorded`），所以**不另立 capability**。

**为什么落点是这三处**：普查与读数是新面（`seat-visibility`）；`team status` 的实时字段表住在
`board-and-status` 的那条缓存等价性 requirement 里，改它才不是平行规格；`team reap` 是**破坏性动作**，
既有能力 `boundary` 正是这条纪律的家（信号只发给记录过的 pid、拒绝要留证据、`team bg` 按记录 pid 停）。
写进别的能力会制造两份互相矛盾的规格，PM 的「无冲突」检查会直接判红。

## Impact

- 产品面：`scripts/lib/common.sh`（普查本体 + 身份/形状判据复用 + 未判定计数）、
  `scripts/lib/cmd-status.sh`（`team_cmd_ps`/`team_cmd_status` 的读数、`team_cmd_digest` 容量行的后缀提示）、
  `scripts/lib/cmd-watch.sh`（`team_cmd_up` 的一行读数）、新命令 `team reap`（`scripts/team` 分派表 +
  实现文件）、`scripts/lib/cmd-config.sh` + `templates/config.sh.tmpl` + `references/config.md`（三个键）。
- 帮助面：`team reap` 必须进命令清单 `scripts/strings/commands.tsv`（一行，带 flags 与
  effect/authorization/touched-face/reversibility 四字段）并有自己的命令页——`help-surface` 能力要求
  「dispatcher 接受的每个命令都在清单里、每个命令都有页」，`tests/help-surface.sh` 的 coverage 组会扫。
- 面板面：`scripts/panel/src/strings/zh.ts` + `en.ts` 加 `label_TEAM_ORPHAN_*`（三个键 + 若用到新 group 则
  `group_*`；本提案复用既有 `delivery` 组，不新增 group）；改完必须用钉住的工具链重建
  `scripts/panel/panel.js`（提交的构建产物），否则 §26-a 的逐字节比对红。
- 夹具面：新 `tests/orphan-census.sh`（`--select` 分组 + `--flip` 红侧，接口以 apply 冻结为准）；
  `tests/smoke.sh` 的 M50 归一化补一条过滤（`team status` 的普查块）；`tests/section-paths.tsv`
  （必要时 `tests/section-budgets.tsv`）登记归属；`tests/config-cli.sh` 覆盖三个新键；
  `tests/signal-lint.pl` 必须对 `team reap` 的新 `kill` 调用保持绿（pid 精确形态）。
- 规格面：`openspec/changes/orphan-visibility/specs/seat-visibility/spec.md`（5 ADDED）、
  `specs/boundary/spec.md`（1 ADDED）、`specs/board-and-status/spec.md`（1 MODIFIED）。
- 兼容性：既有判据（`team_agent_alive_in_pane`、`team_pm_state`、`team ps` 的容量行、面板、`team bg`）语义
  一律不变；普查默认开但只读、`TEAM_ORPHAN_SCAN=0` 可整体关掉；`team reap` 是**新**命令，没有任何既有
  命令因此开始发信号。
- 排期：见 tasks.md。按 delta 切成 **两个 apply 任务顺序执行**（都碰 `common.sh`/`cmd-status.sh`，不同时
  派）：apply-1 写 `seat-visibility` + `board-and-status`（普查、读数、digest 提示、三个键、闸门归一化），
  apply-2 写 `boundary`（`team reap` + 审计 + 帮助清单/页面 + 红侧 ①）。verify 由**没写过本 change 的
  席位**在独立克隆上逐场景 + 逐红侧重跑。

## 需要 PM 裁定的点（提案按推荐版本落笔）

1. **任务书头部的 `deltas:` 要改**：现在是 `deltas: -`，但本提案必须改 `board-and-status` 的一条既有
   requirement（实时字段表），并把 `team reap` 的破坏性纪律落在 `boundary`。**推荐**：改成
   `deltas: seat-visibility,boundary,board-and-status`，并按上面的排期切两个 apply 任务（apply-1 声明
   `seat-visibility,board-and-status`，apply-2 声明 `boundary`，两组不相交，天然满足 delta 单写者守卫）。
2. **digest 是「容量行后缀」还是「完整块」**：任务书第 1 条点名 `team up`/`team status`/`team ps`，
   第 4 条只说 digest 的容量行加提示。**推荐按字面**：`ps`/`status`/`up` 打完整读数，digest 只在容量行
   行尾加提示（这样 M50 的 digest 归一化一个字都不用改——那一行本来就是实时字段）。若裁定 digest 也要
   完整块，apply 加一次同函数调用，同时 M50 的 digest 归一化也要加滤除，且 digest 输出会变长。
3. **三个新契约键**：**推荐全要**——`TEAM_ORPHAN_WARN_MB` 是任务书里那个「例如 1 GB」的阈值（契约里
   的阈值一律是 schema 行，不是硬编码）；`TEAM_ORPHAN_SCAN` 是关掉普查的接缝（夹具与慢机器要用）；
   `TEAM_ORPHAN_PROC_ROOT` 是 `fixture-only:` 的夹具接缝，用来确定性地造「读不到 / 中途消失 / 空环境」
   三种边界（否则那三条只能靠真进程竞态，做成可见 SKIP）。三个都进 `delivery` 组，不新增 group。
4. **`team reap` 的默认态退出码**：**推荐**无 `--yes` 时是**计划态、退 0**（与 `--print`/`--dry-run` 的既有
   惯例一致），被拒绝的目标（复验不过）退非 0。若裁定无 `--yes` 要退非 0，请明说，那会与
   `up --print`/`dispatch --print` 的惯例分叉。
5. **`--yes` 与 `TEAM_CONFIRM_WRITES` 的关系**：**推荐** `--yes` 是唯一授权，不读 `TEAM_CONFIRM_WRITES`
   （那个键的既有语义是「远端/共享状态」，而这里是本机进程）。若裁定要受它约束，默认模板下这个命令
   将永不生效。
6. **`state/reap.log` 的保留策略**：**推荐**先照 `watchdog.log` 的形状（追加一行，不轮转），把轮转留给
   需要它的那次改动；若裁定现在就要有界，请给上限（本提案按「一行一信号、无轮转」落笔）。
7. **`team up` 的读数形态**：**推荐**一行（有孤儿时给计数 + 合计内存 + 可复制命令；没有时一行「无孤儿席位
   进程」），不打完整块——`up` 是启动路径，块留给 `ps`/`status`。`--print` 下同样打印（它只读、无副作用）。

## Acceptance（propose 阶段已跑；apply/verify 阶段另按 tasks.md 执行）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

apply / verify 阶段另跑（命令今天就存在；新夹具 `tests/orphan-census.sh` 由 apply-1 产出）。其中
`signal-lint.pl` 必须带 `--legacy /dev/null`：裸调用今天因为一条过期的豁免清单（一个已不在树里的历史证据包）
而红，闸门 §58 的既有做法就是用空清单跑；两者对 `team reap` 的判定相同：

```bash
bash skills/teamsmith/tests/orphan-census.sh --select census,judge,reading,naming,hint,seams   # 新夹具（键名以 apply 冻结为准）
bash skills/teamsmith/tests/orphan-census.sh --flip                                            # 逐条破坏 → 指定用例必红；还原 → 绿
bash skills/teamsmith/tests/smoke.sh --select 6b,6h,7,11b2,11b3,11c,33                         # ps/status/digest/up/配置读写面
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/common.sh \
  skills/teamsmith/scripts/lib/cmd-status.sh skills/teamsmith/scripts/lib/cmd-watch.sh
bash skills/teamsmith/tests/config-cli.sh                                                      # 三个新键的四面完整性
bash skills/teamsmith/tests/panel-strings.mjs                                                  # 面板标签双向走查
bash skills/teamsmith/tests/help-surface.sh --select coverage                                  # team reap 的清单行与命令页
perl skills/teamsmith/tests/signal-lint.pl --legacy /dev/null                             # team reap 的 kill 是 pid 精确形态（裸调用会因过期豁免清单红，闸门 §58 也是这么绕开的）
bash skills/teamsmith/tests/spec-refs.sh --check
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
```

外加一段**端到端现场**（报告里贴原文）：在夹具项目里造三个现场——① 带本项目身份、不在 tmux 里的 Pi 替身；
② 一个真在跑（有活 pane）的席位；③ 一个身份属于别的项目、一个身份为空的同形状进程——跑 `team ps`/`team status`
贴出点名/只计数/未判定的分列，跑 `team reap --orphans`（计划）与 `--yes`（清理）贴出前后 `kill -0` 与
`state/reap.log` 的一行。红侧按 tasks.md 的每条现场破坏再还原（先冻结改动前的输出，再破坏、再还原）。

## Out of scope

- **跨项目动手**：不杀别的项目的进程、不改它们的仓库、不在读数里点它们的名（账本会发布，仓内记录
  不许出现别的项目名）。本提案只做**可见性 + 本项目的显式清理入口**。
- **不接管既有判据**：`team_agent_alive_in_pane`/`team_pm_state`/`team ps` 的容量行/面板/`team bg` 的语义
  与输出一律不动（读数只增行）。
- **不做自动清理、不做定时清理、不做「孤儿自动收编」**：默认一个信号都不发；没有 pulse/watchdog 自动
  reap 的路径（那是「不可逆动作自动发生」，与既有纪律相反）。
- **不新增轮转/保留机制**给 `state/reap.log`（见裁定点 6），也不改 `state/watchdog.log` 的形状。
- **不碰**：`docs/team/**` 账本（本阶段只写 change 与报告）、`openspec/specs/**`（归档时才写入）、
  `team help` 的既有页面文本（只**增** `reap` 的清单行与命令页）、面板数据面（`__panel-data`）。
- 不改派单/合并/复验/看板的任何判据。
