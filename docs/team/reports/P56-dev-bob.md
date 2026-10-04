# P56 · 门禁的每一段都必须可归属、可超时、有现场（propose）— proposal package + the measurements behind it

agent: dev-bob   status: DONE   time: 2026-09-22T12:59Z
branch: `task/P56-propose`   PR/MR: - （local 模式：不 push，分支留在本地）

Phase: **propose**（planning only — 本任务不改 `skills/**`，不改 `openspec/specs/**`）。
Change: `gate-section-accounting` · deltas: `verification`（MODIFIED ×1 + ADDED ×2）。
Base revision: `57ce976`（P56 任务书提交）。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/gate-section-accounting/proposal.md` | why · what changes · flip · boundaries · acceptance commands · the evidence the apply report must carry |
| `openspec/changes/gate-section-accounting/design.md` | the incident; what this block measured（FAST 分段表 / 轮询普查 / 机制探针）; D1–D8 的裁决与替代方案; the shapes the apply must implement; coverage; residual risks |
| `openspec/changes/gate-section-accounting/tasks.md` | 两个 apply 批次 + 一个独立 verify 批次; coverage map（R1→3.x, R2→1.x/2.x, R3→4.x）; per-requirement re-check 表（跑什么/看哪一行/期望值）; 路径授权; 夹具隔离说明; 预算测量项; D40 重写前置条件; trial archive |
| `openspec/changes/gate-section-accounting/specs/verification/spec.md` | **MODIFIED** `The correctness gate judges correctness only`（守时探针 vs 性能判定的边界，base 三条 scenario 原样保留 + 一条新增）. **ADDED** `Every gate section accounts for itself, and a stuck section is named`（自述行 / 实测预算表 / 超时点名并停跑 / 现场活过整轮 / 进度自述 / watch dog 纪律）. **ADDED** `Every wait in the gate is bounded and attributes at its cap`（轮数与上限 / 心跳 / 上限处归因 / 清单静态检查） |
| `docs/team/reports/P56/probe-section-guard.sh` + `.log` + `.v1.log` | 机制探针：五个形状全绿（41/41）；v1 保留三条决定性实测事实 |
| `docs/team/reports/P56/fast-section-times.tsv` + `full-section-times.tsv` + 两个 `*-run-tail.txt` | 本块两次本地计时跑的分段表与尾部（全量 91 段 / 1050.1s / **✓2879 ✗1** 的预先存在红；FAST 92 段 / 561.5s） |
| `docs/team/reports/P56-dev-bob.md` | 本报告 |

## The brief's six design questions, answered

1. **每段自述与硬上限。** 每段开始打印 `== #<N> <id> == <ISO-8601> · 预算 <B>s`（`#<N>` 从 1 起、本次运行内单调无空号），
   结束时打印 `#<N>` + 用时，并把 `no id start elapsed_s ticks` 写进 `sections.tsv`。**硬上限不是字面上的
   `timeout <预算>`**：本套件是 12 107 行的单脚本、92 段**内联**、段间共享 shell 状态（`$TMP`/`$REPO`/`$SESSION`
   与大量段间变量），把段体 fork 出去就丢掉这些状态并再造 M59 那类级联假红。裁决（design D1）：**心跳看门狗 +
   触发标记**——看门狗（M33 哨兵同款双 fork，不进作业表；裸 `wait` 不会等它）超过预算时先写现场、再写标记、
   然后只信号**该段的子孙与套件本身**（`TERM`→`KILL`，**绝不用进程组**：非交互运行时 `team review`/CI 步骤/派单
   席位与套件同组），套件在每个安全点（段落边界、每条断言、每次轮询）读标记并以 **exit 2** 停跑。v1 探针实测了
   为什么必须这样：① 只杀卡住的子进程，bash 报 `Terminated` 后**继续往下跑**；② `TERM` trap 会被推迟到前台子进程
   之后、甚至跑到下一条命令之后；③ `ps | tail` 在忙机器上会漏掉卡住的子进程——所以现场必须抓「子孙树」。
2. **超时即现场。** 现场先写后杀：摘要（段号/预算/用时/最后进度）、子孙进程树 + 有界进程表、该段写过的夹具日志尾巴、
   私有 tmux server 上每个 pane 的尾巴、部分计时记录、旋钮生效值与忽略行。位置：`${TMPDIR:-/tmp}` 下**点开头的
   目录**、在套件自己的临时根**之外**——套件失败路径会删临时根（D39 追记二），而 CI 的既有收集步骤
   （`docker cp teamsmith-gates-run:/tmp/. .ci-artifacts/`，`include-hidden-files: true`）已经会带出 `/tmp`
   的点文件。**不改 D39 通道，也不改 workflow**；命名与 M33 的点开头诊断同族，P53 的 `tmp-hygiene.sh --status`
   已经把它们列为「列举但永不 sweep」。
3. **预算的来源。** 一份提交进仓库的表 `tests/section-budgets.tsv`：每段一行（id、实测带 `max_host_s`/`max_container_s`/`ci_s`、
   每次测量时的 load、`budget_s`、来源 revision/镜像 tag），表头写明推导规则 `budget_s = max(ceil(band × 4), 60)`；
   表里没有的段拿到**有界默认值**（start 行注明来自默认），`--budget-check` 是可证伪的依据检查（缺行 / 预算低于
   实测带×factor 都红）。为什么 factor 4 且带要取**加载状态**的实测：本块的 FAST 跑在 loadavg 10.59 / 32 核下花了
   **561.5s**，而套件头注释的 FAST 目标写着「< 60s」——用空载数当带就会再造假红。**没有整轮预算这条红线**：实测
   全量在加载态 1050.1s，而任何低于 review 的 1800s 的整轮上限只有 ~1.7× 余量（单段 `38` 实测 291.5s，按 4× 就是
   ~1166s）——那会变成 D33 禁止的性能红线。取而代之的是**进度自述**：段在跑时每 `SMOKE_PROGRESS_INTERVAL`（默认 60s）
   打一只有界的行（`#<N>`、id、已跑时长、目前最慢的几段），段超实测带关闭时打一行警告；两者都不是判定，不拦跑也不判红。
   于是：卡住的段由自己的预算抓住并点名+现场；而"整轮变慢"（原本会被整轮预算判红的形状）由外层时钟杀掉时，
   日志里最后那条进度行已经说出了段号/时长/慢段——12:03 那次事故要的就是这个。
4. **空转可辨识。** 普查（design §1.2）：门禁源 51 个文件、**43 个 `while`+`sleep` 循环**，其中只有 **3 个没有可见上限**，
   且三者都是结构性有界（`smoke.sh:360` M33 哨兵=停止位/属主死亡；`panel-cpu.sh:286`=`sub_end` 截止时刻；
   `flip-m7.2.sh:187`=调用方写的停止位）——它们进清单并**写明**边界，不需要重写。新等待统一走一个 helper：轮数计数、
   每轮刷新段落进度、到上限打印一行归因（名字、`n/cap`、在等什么、最后的读数）再返回非绿；`pty-wait.sh` 的
   settled-frame/前提语义**不动**，是这套纪律的范本。清单本身是一处静态检查（新出现的无上限 `while`+`sleep` 直接红）。
5. **可证伪。** 门禁内新增夹具：嵌套 FAST 跑 + 夹具开关 + 把「永不返回」注入一个早段 + 很小的预算 → 断言 exit 2、
   一行点名（`#<N>`/id/预算/用时）、没有结果行、没有后续段落、没有 `SKIP` 归因、现场在该段证据齐全且活过整轮；
   反向：干净跑每段都有自述与用时、exit 0、无超时行、无现场目录。破坏面：把安全点的标记检查去掉 → 卡住的跑会
   跑完该段并 exit 0 → 夹具红；装回 → 绿。机制本身已由探针实测（见下）。
6. **不做。** 不改任何段的判定语义；不改 D33（性能不进正确性门禁，且给 `gate-guard.sh` 加「只有守时模块能把时长
   和阈值比较」的方向）；不动 D39 的产物通道与 `.github/workflows/gates.yml`；不动面板夹具的前提规则；外层的
   `TEAM_REVIEW_TIMEOUT` 与 CI 作业超时都留在最外层当后备。

## Verification evidence (actually run)

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/gate-section-accounting
✓ change/ledger-and-gate-noise
…
✓ spec/verification
✓ spec/watchdog
Totals: 23 passed, 0 failed (23 items)
```

```
$ mkdir -p /tmp/trial-p56 && cp -r openspec /tmp/trial-p56/ && cd /tmp/trial-p56
$ openspec archive -y gate-section-accounting
Applying changes to openspec/specs/verification/spec.md:
  + 2 added
  ~ 1 modified
Totals: + 2, ~ 1, - 0, → 0
Specs updated successfully.
Change 'gate-section-accounting' archived as '2026-09-22-gate-section-accounting'.
$ openspec validate --all --strict
Totals: 21 passed, 1 failed (22 items)
Details: openspec validate pty-fixture-load-premise --type change
```

```
$ bash skills/teamsmith/tests/gate-guard.sh
ok: smoke.sh 里没有性能判定标记、时长/份额比较，也没有测量夹具的点名
ok: panel-knobs.sh 存在且走 panel-cpu.sh 的 premise-only 模式
ok: panel-knobs.sh 不驱赶测量夹具
ok: perf.sh 带着帧预算 / CPU 份额 / 前提系数的命名单源标记

gate-guard: 三向都过（门禁无判定、旋钮助手在岗、性能套件带标记）
（rc=0）
```

```
$ bash docs/team/reports/P56/probe-section-guard.sh | tail -4
probe result: ✓ 41  ✗ 0
root kept for inspection: /tmp/.p56-probe.77344
```
五形状：卡住的 `sleep infinity` / 忽略 `TERM` 的子进程 / 干净段 / 纯内建自旋 / 自旋且 `trap '' TERM`（被 KILL，退出码 137）。
每个形状都断言：调用方（探针）的进程组完好、套件里裸 `wait` 没有等看门狗、看门狗随套件退出而回收、现场只在该出现时出现。

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null     # 验收命令（计时跑，seed 表）
… 92 段 · 561.5s 墙钟 · loadavg_1m 10.59 · nproc 32 · ✓2350 ✗0 · exit 0
最慢：38=56.9s · 34=47.4s · 12b-pi=40.6s · 26=37.9s · 39=33.7s · 33=33.3s
```

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null     # 验收命令，重跑（工件落盘之后）
fast_rc=0（672.3s）
== 结果 ==  ✓ 2350  ✗ 0
smoke 全绿
```

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null     # 验收命令，终稿 tip f5c2f8c
fast_rc=0（531.8s）· tip=f5c2f8cc37987417e62ffd93edbd2e97ca6c4ea3
== 结果 ==  ✓ 2350  ✗ 0
smoke 全绿
```
（终稿 tip 之后的一个提交只改了 `docs/team/reports/P56-dev-bob.md` 与 delta 里一句带（CI 列）的措辞，
套件不读它们。）

```
$ bash skills/teamsmith/tests/smoke.sh </dev/null                       # 额外证据：一次本地全量（排队拿到锁）
smoke_rc=1（1050.6s）
== 结果 ==  ✓ 2879  ✗ 1
smoke 有失败项（--keep 保留现场）
唯一红行：✗ M28 容器里跑真 pi 体检失败（rc=1）＋它下游的 M45 一行
```

原始分段表：`docs/team/reports/P56/fast-section-times.tsv`（92 段）与 `full-section-times.tsv`（91 段），
尾部 `fast-run-tail.txt` / `full-run-tail.txt`。全量最慢：`38`=291.5s · `26`=67.5s · `12b-h0b`=62.4s · `34`=47.4s。

**那条红是预先存在的环境红，不是本任务引入的（已做反向证明）**：直跑失败腿
`bash tests/container-tmux.sh --with-pi --cmd "bash tests/pm-box-real.sh --idle-secs 3"` 得 rc=1、
`verdict=UNKNOWN / M45 idle-read=NOT-EMPTY BAD`（宿主的 pi 在容器里弹出了 `Do not trust (this session only)` 对话）；
把 **base commit `57ce976` 原样导出**到 `~/.cache/p56-base`（`git archive`，没改仓库）再跑同一条腿，**逐字相同的红**。
本任务的 diff 只有新增的 `docs/**` 与 `openspec/changes/gate-section-accounting/**`（`git diff --stat 57ce976..HEAD`：9 个新文件、0 修改），
与容器/pi 夹具无接触；pinned image 里这条腿因容器内无 runtime 走 SKIP。**这条红交给 PM 处理（不在本任务范围，也不算 BLOCKED）。**

**未做（如实声明）**：本块没有产出**容器列**与 **CI 列**的实测——预算表的三列与 provenance 是 **apply #1 的交付项**
（tasks 2.1），本块提供**宿主 FAST + 全量两列**的种子表与推导规则。**也没有在 CI 上跑过**——CI 是 PM/CI 的事，
且本任务只 propose。

## Flip evidence（propose 包承诺的反转，机制侧已实测）

```
$ bash docs/team/reports/P56/probe-section-guard.sh   # v1（历史输出，保留在 .v1.log）
  ✓ A-stuck: watchdog named the section on stderr
  ✗ A-stuck: suite exit 0 (expected 2)          ← 只杀子进程：套件报 Terminated 后继续跑完并 exit 0
  ✗ A-stuck: the suite finished its section after a trip
（同一次隔离实验里：TERM 到「shell + 前台子进程」时，trap 在 t+30s 才跑，且在 AFTER 之后）

$ bash docs/team/reports/P56/probe-section-guard.sh   # v2（当前）
  ✓ A-stuck: suite exit 2 ·  ✓ scene written ·  ✓ watchdog named the section
  ✓ A-stuck: the suite did not finish its section · ✓ caller's process group intact
probe result: ✓ 41  ✗ 0
```
apply 阶段要补的三条破坏面（已写进 tasks）：标记检查去掉 → 卡住跑变成绿；预算表某行调低 → `--budget-check` 红；
新增无上限 `while`+`sleep` → `--loop-check` 红。

## Decisions and deviations

1. **与任务书字面的偏差（已裁决）：不是 `timeout <预算>`，而是心跳看门狗 + 触发标记。** 理由与实测见 design D1
   （内联段共享 shell 状态；v1 的三条事实；进程组会打到调用方）。语义完全满足任务书：每段有硬上限、超时**点名该段**、
   非零退出（套件走安全点/trap 时 exit 2，看门狗不得不 KILL 时是 137/143，都非零）、现场先写后杀。
2. **超时必须红，不改写成 skip。** 这对「机器人比预算还慢」的情形意味着按约定红——design §6 第 3 条把它当成
   残余风险明说：带取加载态实测、factor 4、现场带前提读数，修法是**可评审的实测表改动**，不是环境旋钮
   （旋钮只在夹具开关下生效，其余打印忽略）；而「整轮均匀变慢」没有整轮红线（D3），由进度行 + 外层时钟归因。
3. **D33 边界**：本改动引入唯一一个能停段的时钟，所以 MODIFIED 的 requirement 明写它是**活性探针**（不算性能判定、
   不得低于实测带、段内慢也绿、触发即红且点名），并让 `gate-guard.sh` 多一个方向守住「计时记录不是判定」；
   进度自述是报告不是判定。`perf.sh`/`panel-cpu.sh` 及其阈值一行不动（tasks 3.3 用 diff 证明）。
3. **D40 归档顺序（已实测）**：`pty-fixture-load-premise`（P44/P48，未归档）MODIFY 了**同一条** requirement。本 delta 是按
   **当前 base** 写的、三条 base scenario 原样携带（用脚本核对：三条 scenario 逐字相同、base 段落是 delta 段落的前缀），
   所以本 change 自身现在能归档。但我在 scratch 副本上做了 trial archive：本 change 归档成功后（`+ 2 added, ~ 1 modified`）
   整棵树变成 **21 passed / 1 failed** —— `pty-fixture-load-premise` 的 delta 不再覆盖被加重的 requirement（D40 的形状，
   方向相反）。所以两者必须**串行归档**、后归档者按新 base 重写；apply/归档前置条件已写进 tasks 5.3。
4. **整轮预算（D3，在实测后改的裁决）**：初稿曾提「总预算」红线；拿到全量实测（1050.1s、单段 `38`=291.5s）后
   改了——低于 review 的 1800s 的整轮上限只有 ~1.7× 余量，那会是 D33 禁止的性能红线。现在改成**进度自述**
   （每 60s 一行：段号/已跑时长/最慢几段）+ 段超带警告行，两者都不拦跑也不判红；卡住的段仍由自己的预算点名+现场。
   差异已写回 design D3、delta 的 requirement 与该条场景、tasks 1.6。
5. **额外发现（不属于本任务，交 PM）**：本机全量门禁的 `31b2` 腿（容器里真 pi 体检）是**预先存在**的红——
   宿主的 pi 在新会话里弹出 `Do not trust (this session only)` 对话，夹具判 `verdict=UNKNOWN`/`M45 NOT-EMPTY`；
   用 base commit 导出树重跑得到逐字相同的红（证据见上）。pinned image/CI 里这条腿走 SKIP，所以它与本 change 无关，
   但本机上的全量门禁会一直是 `✓2879 ✗1` 直到有人处理宿主 pi 的信任提示。

## Suggested next steps

1. PM 走 propose 复审（`docs/team/reviews/gate-section-accounting-proposal.md`）——checklist 第 9 条要把本 change 的
   两个 apply brief 写成恰好一个 `change: gate-section-accounting`。
2. 复审 ACCEPTED 后派 **apply #1**（tasks 1.x/2.x：自述 + 看门狗 + 现场 + 实测预算表 + 夹具），再派 **apply #2**
   （tasks 3.x/4.x：D33 方向 + 等待清单），verify 由**没写过这两个 apply 的**席位做（`team change status` 会看）。
3. **没有 BLOCKED**：所有需要的路径都在 agent 自有的 `skills/teamsmith/tests/**` 内；`openspec/specs/**`、`docs/team/tasks/**`
   未被本任务触碰；PM 拥有的文档不在本 change 的范围内（不需要授权）。
4. 预算表的 CI 列在换一次 CI 跑之后回填（列里记 run id + load），此后「CI 分段耗时」从 CI 日志即可读——这正是本
   change 想让下一次 12:03 那样的事故自己说出名字的方式。
