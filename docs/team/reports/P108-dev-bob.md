# P108 · `gate-section-accounting` 独立验证 · **verify** · dev-bob

agent: dev-bob
status: **PARTIAL —— 机制四要件独立复现（全绿）；2 个 finding 待 PM 裁决**（F2 = 字面需求未达成；F1 = 归因措辞与证据矛盾）
time: 2026-09-28T14:55Z
branch: `task/P108-p108`（本地模式：不 push）
change: `gate-section-accounting`（已在 main：apply = P70 dev2，propose = P56 verify；我不是其中任何一位）
specs: `verification#Every gate section accounts for itself, and a stuck section is named`、`verification#Every wait in the gate is bounded and attributes at its cap`、`verification#The correctness gate judges correctness only`（MODIFIED）
deltas: `-`（验证任务只写报告与证据）
anchor: change
base: `841cda5d`（P108 任务书）；验证对象 = 树上的实现 `b30027aa`（P70 apply）+ `a3d4c615`（P70 done）
证据包: `docs/team/reports/P108-dev-bob/pkg/`（`lib.sh` + `run.sh` + 编号分节 `10/20/30/40/50/60/80` + `README.md` + `logs/`）

> 复现：`bash docs/team/reports/P108-dev-bob/pkg/run.sh`（全部分节）。
> 单节：`bash .../pkg/50-slow-in-budget.sh`；全量重放：`P108_FULL_RECHECK=.../logs/80-full-pristine.log bash run.sh 80`。
> 所有 fixture 在 `${TMPDIR:-/tmp}/p108-pkg.$$` 下，退出回收（`P108_KEEP=1` 保留）；
> 嵌套 smoke 显式 `env -u TMUX -u TMUX_PANE -u TEAM_*` + 私有 `TMPDIR`。

## 0. 结论（先给判定）

| 任务书条目 | 我的独立证据 | 判定 |
|---|---|---|
| 1. 静态三面（**我做了 12 种**，含 9 种 PM 没做的） | `pkg/10-*`：删行 / 压低预算 / **边界 need vs need-1** / band 与实测列不符 / 重复 id / provenance 空 / band 全 `-` / 表头丢推导 / 预算非数字 / 表丢失；每种都是**非零 rc + 点名**；外加我自己的算术/行数对账 | **PASS** |
| 2. 运行时真卡住 → 点名 + 停掉 + 现场；反向「只是慢」绿 | `pkg/40-*`（scratch **整棵工作树**副本的真实段体：0b 真睡 4s、0c 真挂住、scratch 表把 0c 压到 3s，夹具开关**关**）→ exit 2、`#3 0c` 点名、无结果行/无后续段、现场完整、慢段 #2 段内 0 红；`pkg/50-*`（同段体：预算 60s 绿 / 2s 红）；`pkg/60-*`（拖慢 4s 的完整 FAST → `✓2930 ✗0`、`smoke 全绿`） | **PASS** |
| 3. 等待归属 + 进度自述 | `pkg/30-*`：到顶 → 归因行（name、`3/3`、状态、最后读数）+ ticks=3；成功等待 → 绿、无归因；`cap=0` 拒绝；真实 60s 间隔下段内出现进度行、短段没有 | **PASS** |
| 4. 循环清单完整性 | `pkg/20-*`：69 行**逐行独立解析**（锚点按序、cap 字面量在循环体、5 个 bound 行的结构逐条对回代码）+ 4 种变异红 | **PASS** |
| 5. 零回归门禁 | `pkg/80-*`：`openspec validate --all --strict` 17/0；`gate-guard.sh` 四向；pristine FAST `✓2930 ✗0`；全量 `✓3584 ✗0`（§7） | **PASS** |
| 规范内的自述承诺 | **F2**：小数 band（表的 110/112 行）**从不**打印「超实测带」警告 —— “a section that closes above its recorded band SHALL print one warning line” 实际不可达 | **FINDING** |
| 现场证据的归因诚实 | **F1**：`--desc-grace 2` 下普通 `sleep 3` 的 trip 里，日志已有 `Terminated sleep 3`，escalation 行仍称「子孙忽略 TERM」 | **FINDING（低）** |

**判定**：机制本体（每段自述/预算表/看门狗/trip/现场/有界等待/进度自述）在对抗形状下全部独立复现且不见假红；
但 **F2 是一条字面需求未达成**（影响 110/112 段），**F1** 是现场证据的归因矛盾（不改变机制行为，会误导读者）。
按团队纪律（有 finding 的复验记录仍需返工/裁决），本记录不构成归档授权。

## 1. 我做了什么（以及没做什么）

- **只写** `docs/team/reports/P108-dev-bob/**`；**没有动**实现（verify 席位纪律）、没有动任务书、
  没有动别的 agent 目录；没有 push/force-push/merge/rebase。
- **不拿作者的夹具当主证据**：作者的 `0e/0f/0g/14d` 会在我跑 pristine FAST/全量时顺带执行（那是引用），
  我自己的每条结论都由 `pkg/` 下的**自造脚本 + raw log**支撑。
- **没有重测**预算表里的实测值（host/container 列）：我核对的是**结构**（列数、band=max(三列)、
  `budget ≥ max(ceil(band×4),60)`、provenance 非空、表头写下推导）——外加我自己的独立对账。
- CI 被账号层挡着（任务书原话）：**本地全量就是决定性证据**（§7）。

## 2. 静态检查：12 种变异，全部非零 rc + 点名（`pkg/10-budget-mutations.sh`）

基线（同一 fresh scratch）：`--budget-check` rc=0（`预算表覆盖 112/112`），`--loop-check` rc=0
（`扫描 69 行清单 …配平 69 个`）。**我自己的对账**（不经检查工具的实现）：`section 数 = 表行数 = 112`；
`budget < max(ceil(band×4),60)` 0 行；`band ≠ max(host/container/ci)` 0 行；provenance 空 0 行。

| # | 变异 | rc | 点名/说明（原输出） |
|---|---|---|---|
| 1 | 删预算行 `0c`（PM 做过；独立重做） | 1 | `bad: 预算表没有段落「0c · 静态检查（函数结尾的 set -e 陷阱）」的行…` |
| 2 | 预算压到 1（`0e`，band 44） | 1 | `bad: 段落「0e …」budget_s=1 低于 max(ceil(band×4), 60)=176（不许收到实测带以下）` |
| 3a | **边界**：`1 · doctor` 预算 = `need`(60) | 0 | 绿（边界上界） |
| 3b | **边界**：同一行预算 = `need-1`(59) | 1 | `bad: 段落「1 · doctor…」budget_s=59 低于 max(ceil(band×4), 60)=60` |
| 4 | `band_s` 改成 9（该行 max 列是 10） | 1 | `bad: … band_s=9 ≠ max(host/container/ci)=10.00（导出值与实测列不符）` |
| 5 | 重复 id（追加同 id 行） | 1 | `bad: 预算表有重复 id：…` |
| 6 | provenance 列清空 | 1 | `bad: 段落「0c …」没有 provenance（修订/镜像/日期）` |
| 7 | 三个 band 列全 `-` | 1 | `bad: 段落「0c …」三个 band 列全是「-」：没有实测基础` |
| 8 | 表头丢 `factor=4` | 1 | `bad: 预算表头没有 factor=4（推导必须写进文件）` |
| 9 | 表头丢 `floor=60` | 1 | `bad: 预算表头没有 floor=60（推导必须写进文件）` |
| 10 | 预算列写 `x` | 1 | `bad: 段落「0c …」的 budget_s=[x] 不是正整数` |
| 11 | 表整个删掉 | 1 | `bad: 缺预算表 …` |
| 12 | 未登记段的默认预算 + 旋钮忽略（模块探针） | — | `unlisted=[900] src=[default]`、开跑行 `预算 900s（默认：预算表没有这段）`；夹具关时 `TEAM_SMOKE_SECTION_BUDGET=3` 打印忽略行且 `override=[]`；夹具开时被点名段 `listed=[3] src=[fixture]`、别的段仍 `src=table` |

原输出：`pkg/logs/10-*.log`。**每种变异都是「先红后绿」可复现的翻转**：同一 scratch 做一次编辑 → 红；
fresh 副本 → 绿（上面的基线）。

## 3. 循环清单：69 行逐条独立核对 + 4 种变异（`pkg/20-loop-inventory.sh`）

**不引用** `lib/loop-scan.awk` 的实现：`pkg/loop-verify.py` 按**清单文件序**把锚点解析到源码行
（锚点是源码行的子串；同名循环取下一个未用过的），再从 while 行按开/合关键字配平取循环体：

- **全部 69 行**：锚点在源码存在且按序解析；`cap=` 行（64）的上限字面量在循环体里找得到；
  `bound=` 行（5）结构单独对代码 → `rows=69 cap=64 bound=5 bad=0`。
- 10 行 spotlight（含全部 5 个 `bound=`）逐条把结构对回代码：`flip-m7.2.sh` 的 `$stop`
  （调用方 `touch "$stop"`）、`panel-cpu.sh` 的 `sub_end`/`remain_ms -le 0`、`smoke.sh` 的
  `SMOKE_TMP_STOP` + `kill -0 "$SMOKE_OWNER_PID"`、`lib/section-guard.sh` 的 `[ -e "$SG_STOP" ] && break` /
  `_sg_pid_alive "$SG_OWNER_PID"`、`_sg_stop_children` 的 `grace -ge "$SG_DESC_GRACE"`。
  登记行号有漂移（清单头部声明不按行号配对）：如 `S6_WAIT` 记录 1546、实际 1549。
- 变异（全部红 + 点名 file:line）：新增未登记循环 → `bad: lib/tmp-root.sh:517 是未登记的 while+sleep 循环`；
  锚点条件改动 → `bad: … 的 while 行与清单第 N 行的锚点不符`；删一条清单行 →
  `bad: flip-m37.sh 的 while+sleep 循环数 1 ≠ 清单行数 0`；**丢上限**（先加「新循环+同步清单行」证明绿，
  再把循环改 `while :;` 并同步锚点、清单仍写 `cap=`）→ `bad: … 的循环丢了上限（清单要求循环体里出现 ["$i" -lt 5]）`。

说明（非 finding）：今天每一行的 `cap=` 字面量都包含在自己的锚点里，所以「丢上限」分支与锚点检查在现状下
等价；上面第 4 种变异是**构造**出「锚点同步但上限真丢」的形状来单独验证该分支。

## 4. 等待归属 + 进度自述（`pkg/30-wait-attribution.sh`，真实时间、真看门狗）

自造 driver（`sleep`/`reader` 都是真的，不是伪造 `SG_ARMED_EPOCH`）：

| 形状 | 结果 | 证据 |
|---|---|---|
| cap=3 且谓词永假 | `WAIT_RC=1`；心跳 `ticks 0→3`；归因行**第一行**：`等待到顶 p108-never：3/3 轮；在等「永不出现的状态」；最后一次读数：reader-3`；干净退出 | `logs/30-wait-cap.log` |
| 第 2 轮成功 | `WAIT_RC=0`；`ticks 0→2`；`wait.log` 为空（成功不喊到顶） | `logs/30-wait-ok.log` |
| `cap=0` | 返回 2 + `section_guard_wait: cap 必须是正整数（收到 [0]）` | 同上 |
| 进度自述（真实路径固定 60s 间隔，段真实歇 62s） | 出现 ≥1 条 `段落 #1（p108-prog）已运行 …s（预算 …s）`；段正常收尾、无停跑 | `pkg/30-*.sh` 输出 |
| 短段（0.2s < 60s） | 0 条进度行 | 同上 |

说明：非夹具路径的 `--progress/--poll` 会被 `_sg_parse_knobs` 固定回 60/1（D8 的加固），所以进度自述只能
用真实 60s 间隔验证（62s 的段）——夹具开关下缩短间隔是它给门禁自己用的路子。pristine FAST 里的 §0g
（引用）同形状绿灯。

## 5. 运行时：真挂住的段被点名、停掉、留现场；慢段保持绿（`pkg/40-runtime-stall.sh`）

**形状**（不是作者的夹具注入）：scratch 副本里改真实段体 —— `0b` 后加 `sleep 4`（会返回），`0c` 段体
第一行是 `bash -c 'trap "" TERM; while :; do sleep 0.2; done'`（真挂住且忽略 TERM），scratch 预算表把
`0c` 的 `budget_s` 压到 3。同时环境里放 `TEAM_SMOKE_STUCK_SECTION=0c`、`TEAM_SMOKE_SECTION_BUDGET=999`、
`TEAM_SMOKE_PROGRESS_INTERVAL=1`，但**夹具开关关着**。

原始输出（`logs/40-runtime-stall.log`）：

```
  · 注意：TEAM_SMOKE_STUCK_SECTION=0c 只给夹具路径用；非夹具路径忽略它
  · 注意：TEAM_SMOKE_SECTION_BUDGET=999 只给夹具路径用；非夹具路径忽略它
  · 注意：TEAM_SMOKE_PROGRESS_INTERVAL=1 只给夹具路径用；非夹具路径忽略它
== #1 0 · 临时仓库 == … · 预算 60s
  #1 用时 0s · ticks 3
== #2 0b · skill 可被 pi 解析器加载 == … · 预算 60s
  #2 用时 4s · ticks 2
== #3 0c · 静态检查（函数结尾的 set -e 陷阱） == … · 预算 3s
  ✗ 段落 #3（0c · 静态检查（函数结尾的 set -e 陷阱））超时：预算 3s，实际 3s，最后进度 0s → 停跑（exit 2），现场 …
  ✗ 看门狗：段落 #3 的子孙忽略 TERM → 已发 KILL（现场 …）
```

- 退出码 **2**（不是 0、不是 999s、不是 outer timeout 的 124）；恰**一条**点名行；无 `== 结果 ==`、
  无 `== #4`、无 SKIP；**环境旋钮全部被忽略**（预算仍是 scratch 表的 3s，ignore 行在）。
- **慢段 #2 保持绿**：真实 `用时 4s`、段内 **0 条红**（`skill-load teamsmith` 与 `teamsmith-init` 两条都 ✓）、无任何超时（D33 在完整门禁形状里的反向证据）；完整 FAST 版本见 §7 的 `60`。
- 现场（`logs/40-scene-summary.txt`、`logs/40-scene-sections.tsv.partial`）：点开头目录、在私有 TMPDIR 下、
  在 run 自己的临时根**之外**；`id: 0c …`、`budget: 3s`、`last progress: 0s`、子孙树里有挂住的命令、
  `escalation`、`mode: FAST=1 fixture=0`；run 临时根回收后现场仍在；看门狗 pidfile 已收。

## 6. D33 反向的可证伪对 + 两个 finding（`pkg/50-slow-in-budget.sh`）

同一个 driver：段体只做真实的 `sleep 3`，**唯一差别**是预算表的 `budget` 列。

- **A（预算 60s）**：rc=0；结束行 `#1 用时 3s`；`⚠ #1 用时 3s，超过实测带 0s（这是记录，不是判定）`；
  无超时、无现场、看门狗退场。→ **慢、但没卡 = 绿**。
- **B（预算 2s）**：rc=2；恰好一条 `✗ 段落 #1（p108-slow）超时：预算 2s…`；没有 `DRIVER_DONE`（停跑）；
  现场存在并 `id: p108-slow`。→ 收紧到存活上界以下才红。

### FINDING F2（中）：小数 band 的「超实测带」警告永不打印 —— 字面需求未达成

`_sg_close_current` 的守卫是 `case "${SG_BAND:-}" in ''|*[!0-9]*) ;;`：任何含 `.` 的 band 都落到空分支
（即使数值上是整数，如 `44.00`）。而表的 band 列 **110/112 行带小数点**（`0.02`、`0.19`…`44.00`；
只有 §50/§51 是 `2`/`127`）。规范原文是“a section that closes above its recorded band SHALL print one
warning line”——对 110 行不可达。

复现（包内 case C，`logs/50-band-decimal.log`）：band=0.19、段真实 3s、预算 60s →
```
== #1 p108-slow == … · 预算 60s
  #1 用时 3s · ticks 1
DRIVER_DONE
```
**没有** `超过实测带` 行；而 band=0（整数，A case）同样 3s 就有警告行。真实门禁里同样可见：§5 的
`#2 0b`（band 0.19、用时 4s）没有警告行。作者自检没抓到，是因为 `_sg_selftest_case clean` 用
`SG_BAND=0`（整数）——真实表里几乎不存在整数 band。

影响：这是门禁里唯一一行「这段跑得比实测带久」的自述；机器变慢时 `team review` 的日志看不到它。
建议（不在我权限内）：比较改成数值比较（如 `awk -v a="$elapsed" -v b="$SG_BAND" 'BEGIN{exit !(a+0 > b+0)}'`），
并让自检用一个小数 band 的形状钉住它。

### FINDING F1（低）：escalation 行把 grace 用尽归因成「忽略 TERM」

B 的段体是普通 `sleep 3`（响应 TERM）。`--desc-grace 2`（**模块自检自己用的配置**，`_sg_selftest_case`
的 `--desc-grace 2`）下，同一日志里有 `Terminated sleep 3`，看门狗之后仍打
`✗ 看门狗：段落 #1 的子孙忽略 TERM → 已发 KILL`，接着 `Killed sleep 0.02`。
带时间戳的复现（`logs/50-f1-escalation-timeline.log`）：

```
+2.02 ✗ 段落 #1（p108-slow）超时：预算 2s …          ← trip
+2.22 Terminated sleep 3                              ← 挂住子进程确实响应了 TERM
+2.42 Terminated sleep 0.02                           ← 套件退出路径里自己 spawn 的等待轮
+2.63 ✗ 看门狗：… 子孙忽略 TERM → 已发 KILL           ← grace(2) 用尽，KILL 落在这类短命子进程上
```

对照：`--desc-grace 6`（默认值）下同一形状**没有**这条 escalation 行（同一时间线文件的后半段）。
即：该行的因果句是「grace 用尽即认定子孙忽略 TERM」，并未验证任何一个 pid 真的扛过 TERM；在套件退出
路径持续产出子进程（或 desc-grace 较小时）会给出错误归因。机制行为（停跑、现场、KILL 有界）不受影响；
作者 §0f 的现场断言用的是真顽固子进程，所以在那里这句话成立。
建议（不在我权限内）：措辞改成「grace 用尽（仍有子孙）→ 已发 KILL」，或只对**扛过一轮 TERM 的具体 pid**
打「忽略 TERM」。

## 7. 零回归门禁（`pkg/80-gates.sh` + `pkg/60-runtime-slow-green.sh`）

命令（私有 TMPDIR、`env -u TMUX/TEAM_*`）：`bash pkg/run.sh 80`（内含 openspec + gate-guard + pristine FAST）；
`P108_FULL=1`/`P108_FULL_RECHECK=<log>` 追加全量；`bash pkg/run.sh 60` 跑「拖慢的完整 FAST」。
`60` 的 scratch 是**整棵工作树的 tar 副本 + `git init`/一次提交**（含兄弟 skill 与仓库根文件、
真实 git 工作树），变异只加一句 `sleep 4` 并保留 `smoke.sh` 的 `+x`。

| 检查 | 结果 | 原始日志 |
|---|---|---|
| `openspec validate --all --strict` | **17 passed, 0 failed**（含 `✓ change/gate-section-accounting`） | `logs/80-openspec.log` |
| `gate-guard.sh` | 四向全过（含「时长比较只许在段落守卫里」） | `logs/80-gate-guard.log` |
| pristine FAST | rc 0；**112 段全闭合**（112 开跑 = 112 收尾）；`✓2930 ✗0`；trip=0；无现场；`14:03:04→14:16:41` | `logs/80-fast-pristine.log` |
| pristine 全量 | rc 0；**111 段全闭合**（111/111）；`✓3584 ✗0`；trip=0；无现场；`13:33:36→13:58:02` | `logs/80-full-pristine.log` + `logs/80-full-pristine.log.plain`（重放断言） |

> 全量由 13:33 那次真跑产生（跑完后包装脚本被我的一次热编辑打断在收尾打印处；门禁本体已完整跑完
> 并写出结果行）；随后用 `P108_FULL_RECHECK` 对同一份日志**重放同一组断言**（纯读，`logs/run-80.log`；
> 重放信号：17/0 openspec、四向 gate-guard、FAST `✓2930 ✗0`、全量 `✓3584 ✗0`、trip=0）。
| 拖慢 4s 的完整 FAST | rc 0；**112 段全闭合**；`✓2930 ✗0`；`#2 用时 4s` 且段内 0 红；trip=0；无现场；`14:30:38→14:44:39` | `logs/60-fast-slow-green.log` |

- FAST 112 段 vs 全量 111 段：快模式多跑一段 `14c · 快模式自检`（只有 `FAST_REQ=1` 才 `section`），与账目一致。
- trip 行按**精确形状** `段落 #<N>（<id>）超时：预算 <B>s` 计数 = 0（裸 `grep 超时` 会误报：段落名与
  断言标签里合法地含这个词；我的第一版 harness 就误报过一次，已在包内修掉并注明）。
- 全量跑的时候另一席（dev3）的门禁也在同机（loadavg ≈3–7 / 32 核）；D33 明确时长不是判定，本次全量从未出现 trip。

## 8. 证据归属（哪些是我的，哪些是引用）

- **我的**（全部实跑，原始输出在 `pkg/logs/`）：§2/§3/§4/§5/§6 的每一条；§7 的门禁命令与账目复核；
  `pkg/loop-verify.py`（不复用 `loop-scan.awk`）；`pkg/50-f1-escalation-timeline.log` 的时间戳复现。
- **引用**（只在 pristine 运行里顺带执行，我没有以其为结论依据）：作者实现的 `smoke.sh` §0e/0f/0g/14d 与
  `lib/section-guard.sh --self-test`；P70 的测量带与 provenance 数值。
- **边界**：预算表的实测值没有重测（结构核对见 §2）；D7（与 `pty-fixture-load-premise` 的 delta 撞车）的
  归档前提不是本任务范围。

## 9. 复现命令（最小集）

```bash
cd <home>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev-bob
bash docs/team/reports/P108-dev-bob/pkg/run.sh 10 20 30 40 50   # 静态+清单+等待+运行时+翻转（~2 分钟）
bash docs/team/reports/P108-dev-bob/pkg/run.sh 80               # openspec + gate-guard + FAST（~14 分钟）
P108_FULL_RECHECK=$PWD/docs/team/reports/P108-dev-bob/pkg/logs/80-full-pristine.log \
  bash docs/team/reports/P108-dev-bob/pkg/run.sh 80             # 对已跑全量日志重放断言（纯读）
bash docs/team/reports/P108-dev-bob/pkg/run.sh 60               # 拖慢的完整 FAST（~14 分钟）
```
