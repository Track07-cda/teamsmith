# P281 · 门禁锁卫生：锁的记录、嵌套运行与三条红侧

agent: dev-bob   status: DELIVERED   time: 2026-10-15
branch: `task/P281-gate-lock-hygiene-apply`   PR/MR: -（本仓 local 模式，分支留在本地）

change: `gate-lock-hygiene`   phase: apply

> **证据包位置**：`docs/team/reports/P281-dev-bob/logs/`（**本地**，`.gitignore` 的 D94 规则：
> `docs/team/reports/**` 下的证据包不进仓，只有 `reports/*.md` 进）。**判定用的命令与输出已逐条抄进本报告**，
> 所以独立复验不依赖那个目录；目录里是同一批日志的完整原文（00 改动前基线 / 01 改动前 §34,34b /
> 02 交付门禁 `--paths` / 03 main 上的既有红对照 / 04 §34,34b 绿 / 05 验收命令）。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/gate-lock.sh` | 新增：门禁锁记录的**唯一**实现（格式常量、写/读、活体过滤、席位/工作树解析、上限算式、期望用时） |
| `skills/teamsmith/scripts/lib/cmd-review.sh` | `team review` 改用共享实现：持有者记录自述 kind/席位/工作树/expected/bound，排队上限按持有者公布的 expected 算并打印算式 |
| `skills/teamsmith/tests/smoke.sh` | 顶层/嵌套判定与记录（marker 证持有者、进程树证祖辈）、等待者打印记录与算式、新夹具 §34②/⑦ + §34b②/⑦/⑧/⑨/⑪ |
| `skills/teamsmith/tests/lib/section-guard.sh` | 嵌套运行的期限对齐祖辈武装段的剩余预算；每段收口后点名「生它的那一段已收口但仍活着」的已登记嵌套运行 |
| `skills/teamsmith/tests/section-budgets.tsv` | §34 / §34b 两行按本次实测补 band（52.00 / 40.00） |
| `skills/teamsmith/tests/section-paths.tsv` | §34 / §34b 两行登记新路径（`scripts/lib/gate-lock.sh` 等） |
| `skills/teamsmith/references/protocol.md` | §9b-2 补「嵌套运行不排队 / 必须证明祖辈 / 必须在生它的那一段里结束 / no_lock 残余窗口」与上限算式 |
| `docs/team/reports/P281-dev-bob/logs/` | 本次全部证据（**本地证据包**，不进仓，见上） |

## PM 的裁定（复核 `docs/team/reviews/gate-lock-hygiene-proposal.md`，判定 ACCEPTED）

| 裁定点 | PM 的结论 | 本实现怎么落的 |
|---|---|---|
| D1 嵌套运行不抢机器锁 | **是**（「让夹具去抢机器唯一的共享资源，还会和它自己的祖辈死锁」） | 进程树 + starttime 证明祖辈 → 不排队、只登记；证不出按顶层排队 |
| D2 记录形状：`<lock>.holder` + `<lock>.runs/<pid>.run` | 认可 | 两处同形，单写者规则（只有真持有者写/删 `.holder`） |
| D3 上限算式 `clamp(remaining+60, W, 4W)` | 认可（不新增配置键） | `gate_lock_cap`；无 `expected` 退回 `W` |
| D4 嵌套期限来自祖辈武装段的心跳 | 认可 | 记录带 `heartbeat=`，嵌套运行读 `armed_epoch + budget` 取 `min(自己的表预算, 祖辈剩余)` |
| D5 不新增配置键（`TEAM_SMOKE_LOCK*` 不进 schema） | 认可 | 未动 schema/模板/面板；半登记状态见下面 finding |
| D6 apply 一次做完（记录与嵌套放行同一处） | 认可 | 一次交付：`gate-lock.sh` + `smoke.sh` 锁块 + `cmd-review.sh` 同一次提交序列 |

准入条件逐条兑现：① 锁没去掉，放行必须可证明（`34b⑨ 锁被活着但不是祖辈的进程持有 → 证明不成立 → 照旧排队`）；
② 三条红侧逐条跑出来（下面「Flip evidence」）；③ 交付前 `git merge main`，并逐条看过相对 main 的删除行；
④ 说明行用稳定短语 + 行为红侧（没有把判定建在措辞上：每条措辞断言旁边都有一条行为断言，如「锁可再取」
「同名诱饵仍活着」「`预算 60s` 不出现」）；⑤ 独立复验由 V30 做。

## 需求对照（brief 的四条 → 实现与证据）

| brief 要求 | 实现位置 | 证据 |
|---|---|---|
| ① 持有者记录自述 kind/席位/工作树/开始/已跑/上限，等待者按 expected 算上限并打印算式 | `gate-lock.sh` 的 `gate_lock_record_write` / `gate_lock_describe` / `gate_lock_cap`；smoke.sh 的持有行与排队行；`cmd-review.sh` 的 `QUEUE_WRAP` | §34b②（记录自述 kind=top/expected/bound/worktree）；§34b⑦（等待者两行都点名 kind=nested+席位+工作树+已跑+expected+bound）；§34⑦（`remaining=39Xs` / `cap=4XXs` / 下限）；验收运行里真实的一行：`持有 …（kind=top pid=… agent=dev-bob worktree=…`、`expected=948 bound=5710` |
| ② 嵌套运行不排队、锁记录可归因、结束要释放 | smoke.sh 的 `SMOKE_LOCK_SELF_HOLDER` / `gate_lock_prove_ancestor` 分支；`gate_lock_register_run`；EXIT 只删自己那条 | §34b⑧（自述「嵌套运行（祖辈 pid=…）→ 不排队，登记 …」；结束后登记消失；私有锁可立刻再取） |
| ③ 嵌套运行不许活过生它的那一段（超时、点名、现场、停跑） | `section-guard.sh` 的 `SG_NESTED` / `SG_ANCESTOR_HEARTBEAT` / `_sg_ancestor_deadline`（期限对齐）与 `section_guard_check_orphans`（收口检查） | §34b⑧ 三轮（祖辈预算 5s / 自己表预算 3s / 去掉期限）；§34b⑪(a)(b) |
| ④ 三条红侧 + 单层回归；残余窗口诚实写明 | 见下面「Flip evidence」；protocol.md §9b-2 | 全部在验收运行的 §34/§34b 里跑过 |

**规格没动**：`openspec/changes/gate-lock-hygiene/specs/verification/spec.md` 的散文已经承载这四条
（`The gate lock's holder record names its kind, its owner, its elapsed time and its bound`、
`A nested run does not queue on the machine lock…`、`The hard timeout covers the gate run, not the queue`），
本次只把它们落成实现，因此没有 spec delta 需要改写。用投影自证过：
`cp -a openspec /tmp/… && openspec archive -y gate-lock-hygiene` → `Specs updated successfully.`，
`validate --all --strict` 21 → 20 项全过（归档后 change 目录消失，规格文件本身有效）。

## Verification evidence（全部真跑过）

### 1. brief 的验收命令

```
$ bash skills/teamsmith/tests/section-select.sh --check
ok: 段正文点名的真实路径 token 都被各自的行覆盖（488 个 token 检查过；0 个豁免类 token 不参与）
== 选段自检 ==  ok 8  bad 0  SKIP 1
rc=0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 111 reference(s) (49 distinct) in 11892 effective line(s); retired 0; undeclared 0
rc=0

$ openspec validate --all --strict
Totals: 21 passed, 0 failed (21 items)
rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<home>/…/.worktrees/dev-bob scope=published files=1572 hits=0 names=ok user=resolved
rc=0

$ git diff --check && git status --short
（无输出）

$ bash skills/teamsmith/tests/lib/section-guard.sh --self-test
== 结果 ==  ✓ 55  ✗ 0
```

`gate-lock.sh` 那一条按 tasks.md 定的入口跑（本变更的夹具就在 §34/§34b 里，没有另建同名脚本）：

```
$ TEAM_SMOKE_LOCK=<私有>/lock TMPDIR=<私有> bash skills/teamsmith/tests/smoke.sh --select 34,34b
#6 34b · 门禁锁排队守卫 · 用时 41s · ✓77 ✗0 SKIP0 · ticks 77
#5 34 · 门禁锁：排队/运行分开记账 · 用时 51s · ✓36 ✗0 SKIP0 · ticks 36
账本自查：6 段收口 · 增量 ✓134 ✗0 SKIP0 ｜ 结果行 ✓134 ✗0 —— 一致
== 选段结果 ==  ✓ 134  ✗ 0

$ TEAM_SMOKE_LOCK=<私有>/lock TMPDIR=<私有> bash skills/teamsmith/tests/smoke.sh --select 0e
#5 0e · 段落自述：看门狗 / 预算表 / 循环清单（P70） · 用时 45s · ✓23 ✗0 SKIP0 · ticks 23
== 选段结果 ==  ✓ 63  ✗ 0
```

### 2. 交付门禁（`--paths`，交付树的最终一轮）

```
$ bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
HEAD=2faa0604
docs/team/reports/P281-dev-bob.md openspec/changes/gate-lock-hygiene/tasks.md
skills/teamsmith/references/protocol.md skills/teamsmith/scripts/lib/cmd-review.sh
skills/teamsmith/scripts/lib/gate-lock.sh skills/teamsmith/tests/lib/section-guard.sh
skills/teamsmith/tests/section-budgets.tsv skills/teamsmith/tests/section-paths.tsv skills/teamsmith/tests/smoke.sh
== 选段 == decision=RUN · 运行 55/129 段 · 未跑 74 段
  · 全量门禁互斥：持有 /tmp/teamsmith-smoke.lock（kind=top pid=… agent=dev-bob worktree=<home>/…/.worktrees/dev-bob；…）
#5  0e  · 段落自述：看门狗 / 预算表 / 循环清单（P70） · 用时 45s · ✓23 ✗0
#41 34  · 门禁锁：排队/运行分开记账 · 用时 52s · ✓36 ✗0
#42 34b · 门禁锁排队守卫 · 用时 40s · ✓77 ✗0
#43 36  · 选段与分段账本自检（P98 · gate-runtime-budget） · 用时 893s · ✓119 ✗1 SKIP3
账本自查：54 段收口 · 增量 ✓2153 ✗2 SKIP3 ｜ 结果行 ✓2153 ✗2 —— 一致
== 选段结果 ==  ✓ 2153  ✗ 2
smoke rc=1        real 24m44s（未排队：拿到锁时它正是空闲的）
```

**这 2 条红都不是本变更的**：两条都是同一处既有缺陷 —— §6f 的
`坏模板下不给半截 notify 命令（F8）`，§36⑧ 的 `产品面检出探针有失败（8 条）` 是它的级联
（探针里嵌套跑 `--select 58`，而 §58 的 needs 闭包含 §6f → 探针如实报失败）。
对照证据：把 **main（54aaf1e8）** 浅克隆到 /tmp 后跑同一段

```
$ git clone --depth 1 --branch main file://<repo> /tmp/p281-main
$ bash skills/teamsmith/tests/smoke.sh --select 6f
✗ 坏模板下不给半截 notify 命令（F8）（不该出现 [scripts/team notify pm]）
== 选段结果 ==  ✓ 266  ✗ 1
```

同一句话、同一条断言。本变更没有碰 adapter / notify 模板 / dispatch 渲染面。
（本地证据包里的 `02-accept-paths.log` 与 `03-preexisting-f8-on-main.log` 是这两次的完整日志；
本轮在 `06-accept-paths-final.log`。）

**没跑的部分要说清**：这是 `--paths` 选段运行（55/129 段），**不是全套**。没跑的 74 个键在
`06-accept-paths-final.log` 的「这次不跑的键」里逐个列出（`1 1b 1c 3 4c 6b 6c 6g … 61 61b 62 63`）。
按 protocol.md §9b-2，交付/复验/归档仍跑整套；本任务按 brief 的验收命令只跑了选段。
（早一轮 `--paths` 打在 `ff482869` 上（✓2106 ✗2，同样那2 条红），因为之后夹具与预算表又改了一次，
所以**不以它为准**：上面这轮 `2faa0604` 才是交付树。）

## Flip evidence

三条红侧都在夹具里、都在验收运行的 §34b 里跑过（下面是验收日志里的原话）。

**红侧① 锁记录可归因：删掉那条嵌套登记 → 等待者那一行就丢字段**

```
✓ 34b⑦ 排队行点名 kind=nested + 席位 + 工作树 + expected + bound
✓ 34b⑦ 撞上限行也点名同一批字段
✓ 34b⑦ 真持有者活着 → 绝不打印「持有者未知」
✓ 34b⑦ 红侧：删掉嵌套登记 → 那一行丢字段（缺：kind=nested expected=300 bound=1200）→ 绿侧那条断言会红
✓ 34b⑦ 还原登记 → 字段齐了（绿）
```

**红侧② 嵌套运行不许活过生它的那一段：去掉期限 → 无声占着（三条断言同时红）**

```
✓ 34b⑧ 嵌套运行超预算 → exit 2（安全点路径）
✓ 34b⑧ 一行点名段号 + id + 预算
✓ 34b⑧ 现场存在（p281-nested/.teamsmith-smoke-scene.…）
✓ 34b⑧ 嵌套结束后私有锁可被立刻取到（「释放」的可观测判据）
✓ 34b⑧ 红侧：去掉期限 → 8s 内一行点名都没有（无声占着）
✓ 34b⑧ 红侧：登记还在（没有人收尾）
✓ 34b⑧ 红侧：锁仍被占着（「释放」判据分得出两者）
```

**红侧③ 席位/工作树不取窗口名：窗口名报成别的席位，记录里仍是运行时目录的席位**

```
✓ 34b⑨ 席位按运行时目录解析（.worktrees/<名字> → 那个名字）
✓ 34b⑨ 主检出 → pm
✓ 34b⑨ 不是 git 树 → ?（不猜）
✓ 34b⑨ 反向对照：窗口名报 verify，记录里仍是 cwd 的席位
```

**改动前的现场（EXP1/EXP3，改动前跑在 `ff482869` 的父提交上，私有锁 + 私有 TMPDIR）**

```
=== EXP1: 嵌套运行覆写并删除真正的持有者记录 ===
before nested run: 2026-10-15T11:56:20+00:00 pid=3147290 cmd=REAL-HOLDER
nested rc=0
after nested run: <MISSING>                     ← 真持有者的记录被嵌套运行覆写、退出时又被删掉
=== EXP3: 等待者看到的一行（旧文案） ===
另一套全量 smoke 正在跑（2026-10-15T11:56:23+00:00 pid=3162587 cmd=smoke.sh）；本套排队，最多等 1s
排队超限：等满 1s 仍拿不到门禁锁 …（持锁者：2026-10-15T11:56:23+00:00 pid=3162587 cmd=smoke.sh）
                                             ← 没有 kind / 席位 / 工作树 / 已跑 / expected / 上限算式
```

改动后同一条路（验收运行里的真话）：

```
另一套全量 smoke 正在跑（kind=? pid=1075054 cmd=smoke.sh agent=? worktree=? 已跑 ?s expected=? bound=?）；
本套排队，最多等 1800s（算式：remaining=-s + 60s → cap=1800s，下限 TEAM_SMOKE_LOCK_WAIT=1800s，上限 4×=7200s）
  · 全量门禁互斥：持有 …（kind=top pid=… agent=dev-bob worktree=<home>/…/.worktrees/dev-bob；…）
```

（`?` 是**旧形状**的持有者记录——那时还没有这些字段；旧记录照旧可读、缺的字段不编数字，
上限退回 `TEAM_SMOKE_LOCK_WAIT`，这就是 §34② 那条 `没有 expected 的旧持有者仍按 TEAM_SMOKE_LOCK_WAIT 判`。）

## 单层运行回归

既有判定一条没改（§34 ①–⑥ / §34b ①–⑤ 全绿，逐条对照 diff 的结论在下面），新增的是对照与扩面：

- §34② 新增：旧持有者（没有 expected）→ 上限仍是 `TEAM_SMOKE_LOCK_WAIT`（W=2s，实测排队 2s）；旧记录缺的字段写 `?`。
- §34⑦ 新增：持有者公布 expected=400、已跑 10s、W=200 → cap=clamp(450,200,800)=45X，并打印 remaining/下限。
- §34b⑨ 新增：上限算式单元级钉住（W=10 → 40 = 4×W；W=1000 → 1000 = 下限）。
- 判定出口没动：`queued Ns / ran Ns / limit Ns`、队列超限是 `FAIL` 而不是 `TIMEOUT`、`PASS|FAIL|TIMEOUT|SKIPPED|UNKNOWN`
  闭集都原样（§34①–⑥ 的断言逐条通过，`team_review_verdict` 仍解析出 PASS/FAIL）。

**相对 main 的删除行逐条看过**（26 行删除，全部是同一处的替换，没有误删）：旧 holder 文本写入、
旧 `QUEUE_WRAP`、`SMOKE_LOCK_WRAPPER` 的环境标记分支、旧的心跳路径拼接、§34/§34b 两行旧 band 值
（旧值 48.00 / 5.00 留在 container 列，provenance 里写明）、§34b 的旧 patterns 列。
没有删除任何既有断言。

### 4.5 / D5：不新增配置键（按 N/A 勾）

PM 的复核认可「不新增配置键」这个推荐，`TEAM_SMOKE_LOCK` / `TEAM_SMOKE_LOCK_WAIT` / `TEAM_SMOKE_NO_LOCK`
**不进 config schema**，所以 schema / `templates/config.sh.tmpl` / `references/config.md` / 面板 `label_<KEY>`
四面都没动。**finding（半登记状态照旧存在）**：这三个键今天只在 `references/protocol.md` §9b-2 与
`smoke.sh`/`cmd-review.sh` 的用法里被文档化，`team config` 看不见它们；P141 的 R1 只对**新增**的
文档化阈值键生效，本变更没有新增键，所以没有触发那条 —— 但这个族仍是「文档里有、schema 里没有」的状态。

## Decisions and deviations

- **没有 `tests/gate-lock.sh`**：brief 的验收命令里写「若无此名，用你在 tasks.md 里定的入口」，
  tasks.md 把夹具定在 §34/§34b 里，所以入口是 `smoke.sh --select 34,34b`（跑法见上）。
- **基线与夹具运行用私有外层锁**：改动期间机器锁被 dev3 的全量 `--paths` 占着（约 1 小时），
  为了让基线/迭代能落地，用了 `TEAM_SMOKE_LOCK=/tmp/p281-*.lock` 的私有锁（文件内容与默认路径逐字节相同，
  只把路径换掉，不碰机器锁）。**验收运行用的是默认机器锁**（brief 的命令原样），并如实排队了约 6.5 分钟。
- **`--paths` 选段**：按 brief 的命令原样跑（53 段），没跑全套；没跑的段在上面点名。
- **section-budgets 两行按实测补 band**（52.00 / 40.00）：这是 brief「新增段/改动段要按实测补预算表」的直接要求，
  旧值保留在 container 列，provenance 写明「P281 apply 实测」。跑门禁时机器负载 loadavg1 ≈ 12–17（32 核）。
- **§34b⑪(b) 故意留一个真实的嵌套运行给下一段收口**：验收日志里会出现一行
  `嵌套运行在生它的那一段收口后仍活着：pid=… kind=nested …`（它**不是**断言失败，账本行里是 ✗0），
  那是 §35 开段时的收口检查在点名 §34b 留下的那条登记 —— 这就是「收口检查在真运行里被执行」的端到端证据。
  收口只对登记过的 pid 发信号（同名诱饵进程活着），由 §34b⑪(a) 三个断言钉住。
- **门禁不能证明的两件事写进了 protocol.md**：一个活着的席位读到那一行之后会怎么做、以及
  `no_lock` 窗口里两套嵌套运行会不会重叠。前者不在门禁能观测的范围内，后者只能在「不排队」的
  明确出口上被看见（`no_lock=1` 行），不能被断言掉。

## 已知问题 / 交给 PM

- **既有红（不是本变更引入）**：`§6f 坏模板下不给半截 notify 命令（F8）` 在 main（54aaf1e8）上就红，
  并让 §36⑧ 的探针级联红 8 条。任何在本仓跑 `--paths`/全套的席位都会看到这 2 条红。
  建议派一个独立任务（adapter/notify 渲染面，不是门禁锁面）。
- **V30 复验时怎么造「改动前」现场**：改动前的两次实验脚本在本地证据包的 `logs/00-baseline.txt` 里，
  复验可以在 main 树上照跑（私有锁 + 私有 TMPDIR，不碰机器锁）。
- main 已推进到 `54aaf1e8`（相对本分支的基点只多一个 docs 提交），已并入本分支。

## 诚实边界（门禁证明不了的）

- **一个活着的席位读到等待行之后会不会照做**：门禁能证明记录里写了 kind/席位/工作树/已跑/上限、
  能证明等待者把那行打出来了，**不能**证明有人读了它。这是人的纪律，不是判据。
- **`no_lock` 窗口里两套嵌套运行会不会重叠**：`TEAM_SMOKE_NO_LOCK=1` / 没有 `flock` / FAST 三条路上
  没有串行化。门禁能做的是把那三条路**打成可见的 `no_lock=1` 行**（带原因），不能把它们断言掉。
- **没有 `/proc` 的主机**：`gate_lock_proc_tree_available` 是 `[ -r /proc/self/stat ]`，这条 fail-closed
  分支在 Linux 上跑不到（没有夹具能造出「没有 /proc」而不动挂载命名空间）。它的**行为半边**被覆盖了：
  「证明不成立 → 照旧排队」由 `34b⑨` 那条活着的非祖辈持有者夹具钉住；缺的是「没有 /proc 时多打一行说明」
  这一句本身。
- **§34b⑪(b) 故意留一条真实的嵌套运行给下一段收口**：验收日志里会出现
  `嵌套运行在生它的那一段收口后仍活着：pid=… kind=nested …`（**不是**断言失败，账本行是 ✗0）——
  那是 §35 开段时的收口检查在真运行里被执行的端到端证据。
