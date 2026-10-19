# V64 · 性能精简最后一轮差异的复检（增量：`61ddc199..1edfda12`）

agent: dev-bob · category: verify · phase: verify · 时间：2026-10-19
branch: `task/V64-performance-final-recheck`（local 模式，不推送；本报告是这条分支上唯一的文件）
受检：最终候选 `1edfda12`（`task/P316-delete-load-sensitive-tests`），**本轮只审 `61ddc199..1edfda12`**；
上一轮对 `b025fbdf..61ddc199` 的结论原样复用 —— 凡标 **[复用]** 的条目本轮**没有重跑**，来源写明。
运行环境：私有磁盘目录 `/var/tmp/v64-dev-bob/` 下的 `cand2`（= `1edfda12` 的 clone）与 `mut2`（= `cand2` + 那一行反例），
`TMPDIR` 也指到同一块磁盘；交付树、主工作树、他人 clone 里没有写入任何字节。

## 结论

**PASS（增量）。** 两轮合起来，唯一问题（「配置被忽略、实现固定成 grace=2」是否真被检出）的答案是**是**。

本轮四项收口全部落地，逐条按源码与实跑核过：

| 收口项 | 本轮核到的状态 |
|---|---|
| 逻辑等待从 `(0,2]` 收成精确 `== 2` | `routes.sh:885` 是 `exit !(w + 0 == 2)`；干净树读数 `2.00`，ok 行写「等满 2.00s」 |
| KILL 替身变已死、返回值作为第三字段**先**断言 | `routes.sh:802` 在 KILL 时置 `G_TERMED=2`，存活判定对 2 直接返回假；`if team_bg_stop … then rc=0; else rc=$?; fi`；`for want in …`（856 行）在读数被使用之前逐个要求 0 |
| 删掉未读的 config 重写与残留注释 | `mr_grace_logic` 里三行 `config.sh` 重写连同 `grep … || true` 已经删除；「宽限腿②的作业：响应 TERM…」两行已删 |
| 报告命令/数字对应原始日志 | F2/F3 改成真实的 `--select 0e,0f,35` **✓68 ✗0**，并指向 `p316-flip2b.log` / `/tmp/p316-r2.log`（PM 已读原日志确认 68/0） |

本轮新跑的两组结果：`cand2` **✓18 ✗1**（唯一红是既有的 `TEAM_PULSE_WINDOW`），三条读数分别是
`0.00 TERM,KILL 0`、`0.00 TERM 0`、`2.00 TERM,KILL 0`；`mut2`（`grace=2`，只改一行）**✓17 ✗2**，
多出来的那条红正是目标断言
`✗ promise（TEAM_BG_STOP_GRACE）：配置 0 却没升级成 KILL（信号顺序 [TERM]）`。
正常路径现在**确实是 rc=0**（上一轮同一条腿是 rc=6，且被 `printf` 吞掉），意外返回会以第三个字段进断言并点名。

上一稿的两处过度外推已删除，这里只保留实测到的东西：本轮**只**实测了配置 0 与配置 2 两个取值，没有对其它取值
做任何推断；固定值小于 0.3 时的结局我也没有实测，上一稿那句「作业先在窗口内自己退出、于是只剩 TERM」的因果是
**反的**（循环到点后作业仍活着才会升级），不再保留。

上一轮四条缺口的现状：精确 `== 2` **已修**；替身扛 SIGKILL 与 rc 被 `printf` 吞 **已修**；惰性 config 重写
**已删**；报告里 `0e,0f` 的数字 **已修**。残留问题只在注释面（第五节第 1 条），不影响任何断言。

## 一 · 本轮实跑（增量，全部是本轮新跑的）

| # | 树 | 命令 | 结果 |
|---|---|---|---|
| 1 | `cand2` `1edfda12`，树干净（`git status -uall` 0 条） | `TMPDIR=… TEAM_ROUTES_FAST=1 bash skills/teamsmith/tests/routes.sh promises` | `✓18 ✗1`，rc=1（9.3s）；唯一 ✗ 是既有的 `TEAM_PULSE_WINDOW` |
| 2 | `mut2` = `cand2` + 一行 | 同上 | `✓17 ✗2`，rc=1（11.3s）；新增 ✗ 是目标断言 |
| 3 | `mut2` 的改动核对 | `git diff --numstat` / `sha256sum` | `1  1  skills/teamsmith/scripts/lib/cmd-bg.sh`；`git status` 只有这一个文件；sha `ca5d68e7…` → `64290c8a…` |
| 4 | `cand2` 的三条逻辑读数 | 见下（逐字截出的内层脚本，直接跑三次） | `0.00 TERM,KILL 0`、`0.00 TERM 0`、`2.00 TERM,KILL 0` |

两条 promises 的尾部（颜色已去掉）：

```
# cand2（干净）
  ✗ promise（TEAM_PULSE_WINDOW）：pulse up 没有按新窗口名建窗（记录：6 条 tmux 调用）
  ✓ promise（TEAM_BG_STOP_GRACE）：宽限 0 → 忽略 TERM 的作业被立刻 KILL（账本 signal=TERM,KILL）
  ✓ promise（TEAM_BG_STOP_GRACE）：同一作业状态下配置 0/2 给出不同等待（0 → 立即 KILL；2 → 等满 2.00s；会响应的作业不升级）
== 结果 ==  ✓ 18  ✗ 1  SKIP 0

# mut2（grace 固定成 2）
  ✗ promise（TEAM_PULSE_WINDOW）：pulse up 没有按新窗口名建窗（记录：6 条 tmux 调用）
  ✓ promise（TEAM_BG_STOP_GRACE）：宽限 0 → 忽略 TERM 的作业被立刻 KILL（账本 signal=TERM,KILL）
  ✗ promise（TEAM_BG_STOP_GRACE）：配置 0 却没升级成 KILL（信号顺序 [TERM]）
== 结果 ==  ✓ 17  ✗ 2  SKIP 0
```

三条读数的取得方式：把 `routes.sh` 里那段 `bash -c` 主体**逐字截出来**（与源码 `diff` 为空，没有加任何一行），
直接把 skill 目录当参数跑三次 —— 主体自己就把 rc 作为第三个字段打印出来，所以不需要插桩：

```
  grace=0 alive_after_term=0.3 →  0.00 TERM,KILL 0     # 配置 0：零等待，直接升级，函数正常返回
  grace=2 alive_after_term=0.3 →  0.00 TERM      0     # 配置 2：作业在窗口内自己死，不升级
  grace=2 alive_after_term=99  →  2.00 TERM,KILL 0     # 配置 2：等满 2.00 逻辑秒才升级
```

三行末尾的 `0` 就是上一轮那个 rc=6 的位置：替身在 KILL 之后已死，函数走正常出口，`printf` 不再盖掉任何东西。

## 二 · 翻证（break the implementation → 目标断言必须红）

| # | 树 | 改动 | 结果 |
|---|---|---|---|
| 1 | `cand2` `1edfda12` | — | `✓18 ✗1`（只有既有 `TEAM_PULSE_WINDOW`） |
| 2 | `mut2` | `grace="${TEAM_BG_STOP_GRACE:-5}"` → `grace=2`（产品树只此一行） | `✓17 ✗2`，新增的红是 `配置 0 却没升级成 KILL（信号顺序 [TERM]）` |

两棵树上 `TEAM_PULSE_WINDOW` 那条红同名、同条数、同说明（都是「6 条 tmux 调用」），所以它不是这次改动引起的；
`mut2` 新增的那条红**就是目标断言**，不是无关旧红。旧的「真实进程腿」（腿①）在反例上仍然绿 —— 这是 V63 判
PARTIAL 的原因，也是这一轮把证据全部放进逻辑腿的原因；[复用] 上一轮同一反例在 `61ddc199` 上的红与这里完全同名。

反例树上的三条读数（同一份逐字脚本）：

```
  grace=0 alive_after_term=0.3 →  0.00 TERM 0     # ← 与配置 2 一模一样：旋钮被无视
  grace=2 alive_after_term=0.3 →  0.00 TERM 0
  grace=2 alive_after_term=99  →  2.00 TERM,KILL 0
```

即：`grace=2` 时配置 0 那条腿看到的是「等了 2 秒、作业自己死、只剩 TERM」，而断言要求「零等待 + 必须升级」。

## 三 · 四项收口逐条核实（本轮，按源码）

**1. 精确 `== 2`。** `routes.sh:885`：`awk -v w="$r2b" 'BEGIN { exit !(w + 0 == 2) }'`。读数 `2.00` 是
`sleep` 桩按参数累加出来的逻辑秒（20 × 0.1），与机器快慢无关，所以这条精确断言不会因为负载抖动。它取代了
上一轮的 `(0,2]`：后者只证明「非零且不超窗口」，现在证明的是「等满配置的宽限」。作者另有单点
`grace*5 → 1.00s` 的红（报告里记为「不是配置的完整宽限 2s」）—— **引用，未重跑**。

**2. KILL 替身已死 + rc 先断言。** 替身状态改成三值：`0` 未收 TERM（活着）、`1` 收到 TERM 后按逻辑秒自己死、
`2` 已被 SIGKILL（`kill` 桩里置 `G_TERMED=2`，存活判定对 2 直接返回假，不再复活）。受测函数的返回走
`if team_bg_stop gl >/dev/null 2>&1; then rc=0; else rc=$?; fi`，作为 stdout 第三个字段回到调用侧；调用侧
`for want in "0:${rc0:-缺}" "2a:${rc2a:-缺}" "2b:${rc2b:-缺}"; do case "$want" in *:0) ;; *) finding …`
在读数被使用之前逐个要求 0，失败时点名腿号与原始 stderr 首行。三条实测都是 0（第一节）。

异常路径也核了两条，不再是静默绿：

- 内层脚本加载产品失败时，它打印 `0 none source-failed`（本轮实跑，把 skill 目录指到一个不存在的路径得到这一行），
  第三个字段不是 0 → 上面的 rc 断言点名 `source-failed` 判红（`0` 只骗过第一个字段，第二个字段是 `none`）。
- 作者的单点：把替身改回「扛 SIGKILL」（`2) return 0`）→ `✗ … 逻辑腿 0 的 team_bg_stop 返回了 6（期望 0）`，
  rc 原样传播、`printf` 没有盖掉 —— **引用，未重跑**。

**3. 未读的 config 重写与残留注释。** `git diff 61ddc199..1edfda12` 删掉了 `mr_grace_logic` 里的三行
`config.sh` 重写与那条 `grep … || true`；现在值只经 `env` 给（`TEAM_BG_STOP_GRACE="$grace"`），`bash -c` 里
不再有任何 `config.sh` 写入。上一轮那两行「宽限腿②的作业：响应 TERM…」也已删除。

**4. 报告数字。** F2/F3 两格的还原命令改成 `--select 0e,0f,35` **✓68 ✗0**，并指向 `p316-flip2b.log`
（翻转日志）与 `/tmp/p316-r2.log`（还原后的选段运行）；F-C 的引文注明那是当时的断言文本、V63 后已收窄。
PM 已读原始日志确认 68/0，我本轮按任务书没有重跑 smoke，只核了「报告里的命令与它自己记录的输出对应」：
两段的断言位点最多 42 条（49 个位点减 7 条互斥臂），68 只可能属于三段的那次运行，现在写的正是三段。

## 四 · [复用] 上一轮已独立验证、本轮未重跑的部分

- **[复用] `key-replies.sh --select receipts` = `✓19 ✗0 SKIP0`、rc=0**（本轮前一次实跑，在 `61ddc199` 上）。
  本轮 `git diff --stat 61ddc199..1edfda12 -- key-replies.sh lib/section-guard.sh smoke.sh loop-inventory.tsv`
  为空，四个文件逐字节相同，所以没有重跑。限时取锁那条断言仍只守 `-w 2`（`has` 是纯子串匹配；`-w 2 3` 命中，
  `-w 30 3` 不命中），fd 字号不再是契约。
- **[复用] 跨段状态按 `no`/`armed` 复位**（源码核实，本增量没有碰 `section-guard.sh`）。**上一稿的单位写错了**：
  `_sg_now() { date +%s; }`，`armed` 字段是 `SG_ARMED_EPOCH`，单位是**秒**，不是毫秒。复位用的是
  `"$no|$armed" != "$seen_sec|$seen_arm"`；真正保证「换段必复位」的是 `no`（每次 `section_guard_begin` 自增，
  秒级 `armed` 在同一秒内的两次武装可能相同，但 `no` 一定不同）。只重置 `last_ticks`/`last_moved` 两个既有变量，
  没有新增心跳字段、没有新增守卫、没有新增断言；一个挂住的段不会重新武装，所以复位不会掩盖真停跑。
  残留的跨段变量只有 `last_progress`（它只控制进度自述那一行的节奏，不参与停跑判定）。
  作者的 2.0s / 1.0s 单点按任务书只作历史证据，未重跑，也没有为它加墙钟判据。
- **[复用] 自检 `✓64 ✗0` 与 `--loop-check` 89/89**：V63 在 `b025fbdf` 上两次实测 64，`61ddc199` 那一轮
  `section-guard.sh` 的新增行里断言数为 0，本增量又没有碰这个文件 —— 所以 64 仍然成立，本轮不重跑（任务书禁止）。
- **[复用] 逻辑腿不是自证模拟器、不是墙钟**：本轮重看了当前源码并重跑了读数 —— 它 `source` 产品自己的
  `cmd-bg.sh` 后直接调 `team_bg_stop`，只换依赖（`sleep` 累加参数、`kill` 记顺序、存活判定读替身状态，
  另加记录/目录/账本/输出的替身），等待循环与升级判断都是产品代码；新增行里没有 `date`/`SECONDS`/`%N`/
  `timeout`。0 与 2a 两次调用之间作业替身完全相同，唯一变量是配置值；`2b` 换的是作业响应性、配置不变 ——
  两个维度分别被三组读数分开，所以 0 与 2 的差别不能被「不同作业」解释。
- **[复用] 产品面**：`git diff --name-only 61ddc199..1edfda12 -- skills/teamsmith/scripts skills/teamsmith/references
  openspec .github` 为空；本增量只动 `routes.sh` 与作者报告两个文件。

## 五 · 剩余缺口与未验证项

**1（新发现，文档面，不影响断言）**：`mr_promise_bg_stop_grace` 的声明行被粘贴了两次 ——
`routes.sh:828` 是 `mr_promise_bg_stop_grace() { # <KEY>mr_promise_bg_stop_grace() { # <KEY>`。语法上无害
（`#` 之后到行尾都是注释，函数照常运行，本轮 ✓18 就是证据），但显然是编辑事故。同一函数的注释块还留着三行
与本轮实现相反的旧话：`routes.sh:778-779` 写「同一份 `.job` 记录…跑两次，只有 `config.sh` 里的
`TEAM_BG_STOP_GRACE` 不同」，而 782–783 行写的正是「与真实 `.job` 记录无关」「值由 env 给出」「不重写
`config.sh`」，并且实际跑的是三遍；另外 `752` 行说「只替换 sleep / kill / 存活判定三个依赖」，实际还替换了
目录/记录/账本/输出四个替身。最小改法：删掉 778–779，`752` 的「三个依赖」后面补一句「外加记录/账本/输出替身
（不测文件载入）」，并删掉 828 行重复的半句。这些都不改行为，也不该为它们加断言。

**未验证（按任务书不跑，或本轮无必要）：**

- `key-replies.sh`、`section-guard.sh --self-test`、`--loop-check`、`smoke.sh`（含 0e/0f/26-m）、`perf.sh`、
  FAST 全量、routes flips、模型路由变异：本轮全部没有跑（文件逐字节相同或任务书排除）。上面 68/64/89 这些
  数字都不是本轮实测，来源已逐条标注。
- 作者的两项单点（`grace*5 → 1.00s` 红、替身扛 KILL → rc=6 红）：引用，未重跑。
- 机器负载未记录（任务书要求不造负载、不等安静机器）；本报告不使用任何耗时读数作判据。
- 配置 0 与 2 之外的取值、以及「作业在窗口内自己死」的时间边界（恰好 2.0s 才死）都没有实测，不在这里推断。

## 六 · 裁定与去向

- 增量判 **PASS**：四项收口都落地，目标断言在 `grace=2` 反例上仍然红、在干净树上绿；正常路径 rc=0，
  异常返回会进断言；精确 `== 2` 把「配置被读取并遵守」钉在逻辑时钟上，不再需要墙钟。
- 唯一残留是第五节第 1 条的注释/声明行（三处互相矛盾的旧话 + 一个重复的半句），零行为影响；是否顺手修由
  PM 定，本报告不实现。
- 候选 `1edfda12` 仍冻结在 P316 分支，不进 0.3.0；本报告不推动合并、不改任何实现文件。
