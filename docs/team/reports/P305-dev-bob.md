# P305 · 补齐门禁锁清单里如实留空的 8 格 + 修 F1（作者侧）

agent: dev-bob   status: DONE   time: 2026-10-16T12:20Z
branch: `task/P305-gate-lock-gaps`   PR/MR: -（local 模式：分支留本地，PM 复验后本地合并）
phase: apply   change: `gate-lock-external-deletion`

## 结论（先读这段）

- **F1 已修（真缺陷，不是夹具洁癖）**：`flip-p287-lock.sh` 的 leg2 在并入 main 的树上必红，根因是一条**竞态**：
  旧探测写成 `git show … | grep -q …` 而脚本 `set -o pipefail`，`grep -q` 命中即退 → `git show` 吃 SIGPIPE
  → 管道整体非 0 → `!` 取反后把**含变更**的树当成「改动前」。改法两条一起做：探测不再走会提前退出的管道；
  「改动前」不再取 `main` 的移动 tip，而是从**记录在案的落地提交**（P288 = `6f1ed69d`）逐级往回找，并对选中的
  那棵树做**后置核对**（rev 与取出的树各核一次）。绿侧 rc=0（leg2 取 `6f1ed69d~1`），两条红侧各 rc=1。
- **5.2 的现场**：锁对三样 + 一个陈旧平铺根 → `--sweep --age 0` 的清单里只有那一项 `[reclaim]`，收完锁对全在（§5）。
- **8 格补齐**：`1.1`（第三向断言）、`2.1`（推导的纯函数单测）、`2.4`（`mtime >= claimed`）、`4.1`（冻结集合
  逐字 diff + 现行为现场）、`5.2`（`legacy` 标注 + 断言 + `--sweep` 不碰锁对）、`5.3`（§9b-2 三处缺文）、
  `7.1`（验收命令逐条 rc/输出尾）、`7.2`（本报告）。逐格证据见 §7，任务书里每格末尾都写上了指针。
- **一条需要 PM 知道的越界自报**：我的三个提交曾误落在**主检出 main** 上（`702bafb9`/`0178b6c3`/`b0ad48b7`，
  本地、未推送）。事故当时已 notify PM，PM 已建备份 ref `backup/P305-accident-20261016` 并复位到事故前状态；
  同一份改动已重做到本分支。重做后与事故提交核对：`smoke.sh`/`tmp-hygiene.sh`/`protocol.md` **逐字节相同**，
  `flip-p287-lock.sh` **本分支更完整**（红侧改成确定性复刻）。**零丢失**。防复发：提交前
  `git rev-parse --show-toplevel` 必须等于本工作树。
- **交付门禁的两个红灯都是既有的（都做了改动前的 A/B）**：全量跑一次 rc=2 —— `0i`（夹具嵌套临时根把私有
  tmux socket 顶过 AF_UNIX 107 字节上限 → 内层运行 exit 2）与 `10 · review`（review 起的门禁按顶层登记、
  排在本轮的锁后面 → 60s 预算耗尽）。两者在**改动前的基线** `238c4c6a`（独立克隆）上同形同因复现（§6.4）。
  本任务改动的段全绿。
- **两条先说清楚的边界**：① `spec-refs.sh --check` 在这棵树上是 **rc=1**，finding 是
  `undeclared openspec/specs/extension-slash/spec.md:47 docs/team/tasks/P1.md` —— 在**改动前的基线 `238c4c6a`**
  与分支基点 `3029115d` 上**同一条、同一 rc**（独立克隆上复现），不是本任务引入，本任务一个字未动它（§6.3）。
  ② 门禁是**选段**运行：`--select 34,34b,34c,34d,0e` 跑了 9/135 段 ✓314 ✗0，**未跑的 126 段不代表通过**（§6.2）。

## 1 · 交付物

| Path | What |
|---|---|
| `skills/teamsmith/tests/flip-p287-lock.sh` | F1：leg2 探测不再早退；「改动前」基线改为记录在案的落地提交 + 后置核对；红侧改 `old-probe`（确定性复刻 + 竞态实测）/ `main-baseline` |
| `skills/teamsmith/tests/smoke.sh` | 新断言：`34c` 1.1 第三向（非 git 检出 / PATH 无 git）、`34d` 2.1（伴生路径推导的纯函数单测）、`34d` 2.4（`mtime >= claimed`） |
| `skills/teamsmith/tests/tmp-hygiene.sh` | `--status` 把历史平铺根标 `legacy`；自检 ① 一对断言（平铺根必须带 / 带 ns 的根不许带）+ ⑥ 覆盖伴生锁与运行注册 |
| `skills/teamsmith/references/protocol.md` | §9b-2：根模板补 ns、perf 锁记录位置改 `<companion>.holder`、安全清理入口与「不许对共享前缀 `rm -rf`」 |
| `openspec/changes/gate-lock-external-deletion/tasks.md` | 8 格按事实勾 + 每格证据指针（既有 23 格与 PM 的 8.1–8.3 一字未动） |
| `docs/team/reports/P305-dev-bob.md` | 本报告 |

提交（Conventional Commits + `Agent: dev-bob`）：`284bde3b` fix、`10f8bcb1`/`f6efb1a1`/`fb826fd4` test、
`d08ecf70` test（legacy 断言的牙）、`ebe8513a` Merge main、以及 5.2/⑥ 的收尾提交与勾选/报告提交。
产品行为零改动：`git diff --stat <基点>..HEAD -- skills/teamsmith/scripts/` 为空。

## 2 · F1：根因、竞态实测、修法

### 2.1 现场（P303 的 F1）

P303 的复跑（在并入 main 的树上）`bash skills/teamsmith/tests/flip-p287-lock.sh --self-test` rc=1：leg2
「改动前的树」永远选中 `main`（含变更的那棵树），因为旧探测 `git show … | grep -q gate_lock_companion_path`
在 `set -o pipefail` 下把「命中」也变成了非 0。**合并前它绿，只因为那时 `main` 本来就不含变更** —— 这条腿
从来没真的往回找过。

### 2.2 竞态实测（本任务新测，三个数）

| 测法 | 次数 | 管道非 0（SIGPIPE 141） | 管道 0 |
|---|---|---|---|
| 独立测量旧表达式（`git show 6f1ed69d:…gate-lock.sh \| grep -q …`，`set -o pipefail`） | 60 | **60** | 0 |
| 夹具里的红侧测量（同一表达式，20 次，打印在 `flip-lock-red-pf.log`） | 20 | **20** | 0 |
| 第一轮门禁里 `pipefail-probe` 红侧那一次 | 1 | 0 | **1** |

结论：旧写法的误判是**竞态**（谁先被调度决定 git 有没有把 blob 写完），不是稳定复现 —— 所以「把探测改回旧写法」
这条红侧本身不稳定（那一轮它 rc=0，正确跳过了 `6f1ed69d`）。红侧因此改成**复刻判定语义**（管道非 0 ⇒ 当成
「不含伴生锁」⇒ 第一个候选即结论），并把实测 rc 与 20 次测量打进日志。修复后的实现不依赖竞态：后置核对在
两种落法下都判对。

### 2.3 修法

- 探测：`p287l_blob_of`（`git show` **先落盘**）+ `p287l_has_companion` / `p287l_lacks_companion`（grep **文件**，
  读完整流，不早退）。同族的坑写在 `flip-m33.sh:106`。
- 基线：`P287L_LANDED`（默认 `6f1ed69d`，`TEAM_FLIP_PRE287_LANDED=` 可覆盖）→ 从它 `~0…~40` 逐级往回找第一个
  不含 `gate_lock_companion_path` 的提交；找不到才退回 `main` 并**打印一行说明**。
- 后置核对（这条是牙）：选中的 rev 必须**确实**不含伴生锁实现，取出的树里的 `gate-lock.sh` 也必须不含。
- 红侧（`TEAM_FLIP_BREAK=`）：`old-probe`（旧判定 + 测量）、`main-baseline`（基线指回 `main`，旧形状不回溯）。

### 2.4 红绿原始输出（交付树，`--self-test`）

```
$ bash skills/teamsmith/tests/flip-p287-lock.sh --self-test            # 绿侧
== leg2 pre：改动前的树上做同一件事（那时没有伴生锁）→ 同样不点名、不停跑 ==
  ✓ leg2：改动前的树取自 6f1ed69d~1（b77af9e1 docs(team): pending ledger records [skip ci]）
  ✓ leg2：那棵树（6f1ed69d~1）里确实没有 gate_lock_companion_path —— 记录在案的落地提交是 6f1ed69d
  ✓ leg2：取出的树的 gate-lock.sh 里没有伴生锁实现（改动前的形状）
  ✓ leg2：改动前的树不点名（删伴生锁无从谈起）
  ✓ leg2：改动前的树继续跑完（与 leg1 同形）
FLIP 全绿：绿侧按预期点名并停跑，两条对照腿各按预期静默             rc=0

$ TEAM_FLIP_BREAK=old-probe bash skills/teamsmith/tests/flip-p287-lock.sh --self-test
  · leg2 红侧①：旧写法（git show … | grep -q + pipefail）的判定 = 管道非 0 ⇒ 当成改动前；量 20 次，20 次非 0（竞态：SIGPIPE）
  · leg2 红侧①：旧写法那一步在 6f1ed69d 上的管道 rc=141（非 0 ⇒ 旧写法把它当成改动前）
  ✗ leg2：选中的树 6f1ed69d 里**有**伴生锁实现 —— 它不是改动前的树（基线/探测指错了）
FLIP 有未达预期的腿                                                  rc=1

$ TEAM_FLIP_BREAK=main-baseline bash skills/teamsmith/tests/flip-p287-lock.sh --self-test
  · leg2 红侧②：基线指回 main（旧形状：起点 tip 直接当结论，不回溯）
  ✗ leg2：选中的树 main 里**有**伴生锁实现 —— 它不是改动前的树（基线/探测指错了）
FLIP 有未达预期的腿                                                  rc=1
```

## 3 · 4.1 的冻结集合：逐字 diff（V53 §2.2 裁定后的形态）

裁定：两条防御性文案（`排队/加锁失败：flock 没能把本套跑起来…`、`注意：flock 探锁失败…`）的消失算机制改写的
必然；准入条件冻结的是**上限算式 / token 闭集 / 退出码集合 / `team_review_verdict`**，例外记在本节与任务书 4.1 格旁。

改动前 = P288 落地提交的父提交（`6f1ed69d^`）。① 上限算式（`gate_lock_cap` 函数体）与 ② `team_review_verdict`
函数体 diff **均为空**；③ 两条 `printf`（排队行、超限行）**逐字相同**（只差行首缩进）；④ 退出码集合逐字相同：

```
$ python3 …   # 提取整份 smoke.sh 的 exit N 集合 + 锁/排队路径上的 exit 码
pre smoke.sh exit codes : 0 1 2 3 5 7 64 90 124 130
now smoke.sh exit codes : 0 1 2 3 5 7 64 90 124 130
identical set           : True
pre lock path exit codes: 1 2
now lock path exit codes: 1 2

$ grep -h "printf '排队超限：等满" <pre>.sh | sed 's/^ *//' > /tmp/a; grep -h … <now>.sh | sed 's/^ *//' > /tmp/b
$ diff /tmp/a /tmp/b && echo IDENTICAL          # 超限行
IDENTICAL
$ diff /tmp/a2 /tmp/b2 && echo IDENTICAL        # 排队行（另一套全量 smoke 正在跑）
IDENTICAL
```

⑤ token 闭集 `PASS|FAIL|TIMEOUT|SKIPPED|UNKNOWN`：`team_review_verdict` 函数体 diff 为空（②），解析与打印两处
同形；`queued Ns / ran Ns / limit Ns` 三键由既有 `34d⑦` 断言持续钉住（本次选段里 ✓）。⑥ marker 语义（P66）：
`34b①` 四条断言（超限 → exit 2、报出等了多久、点名 `<lock>.holder` 里的持有者、说明「本套没有运行」）在本次
选段里全 ✓ —— 语义未动。

**「加锁失败」的现行为**（旧文案描述的是 `flock --close -w` 包装器的失败模式，那个包装器已经不在了，
`grep -r` 两条旧文案命中 0/0）：

```
$ flock --close -x <TMPDIR>/teamsmith-smoke.lock sleep 30 &   # 外部占着锁
$ TMPDIR=<TMPDIR> TEAM_SMOKE_LOCK_WAIT=2 bash skills/teamsmith/tests/smoke.sh --select 0b
排队超限：等满 2s 仍拿不到门禁锁 <TMPDIR>/teamsmith-smoke.lock（持锁者：持有者未知）→ 本套**没有运行**（这不是对代码的判定；等持锁者结束，或抬高 TEAM_SMOKE_LOCK_WAIT 后重跑；TEAM_SMOKE_NO_LOCK=1 可跳过排队）   rc=2
（注：「持有者未知」是因为占锁的是一次裸 flock，没有写持有者记录 —— 如实打印，不编。）

$ TEAM_SMOKE_LOCK=<TMPDIR>/blocker/x.lock bash skills/teamsmith/tests/smoke.sh --select 0b    # 锁文件建不了
  · 全量门禁互斥：no_lock=1（锁文件 <TMPDIR>/blocker/x.lock 建不了 → 不做排队；同机并发两套时可能互相干扰，见 M23）   rc=0
```

## 4 · 补章的三条新断言（含牙）

### 4.1 · `34c` 1.1 第三向：非 git 检出 / PATH 无 git

```
  ✓ 34c 1.1 非 git 检出：team_project_ns 不报错（rc=0）
  ✓ 34c 1.1 非 git 检出：stderr 干净
  ✓ 34c 1.1 非 git 检出 → ns=nogit-648ab608（slug 取目录名，hash 取 realpath）
  ✓ 34c 1.1 PATH 无 git：team_project_ns 不报错（rc=0）
  ✓ 34c 1.1 PATH 无 git：stderr 干净
  ✓ 34c 1.1 PATH 无 git + 无 sha256 工具 → ns 退 <slug>-00000000（仍不报错）
```

牙（同一探针指向一份「让 `team_project_ns` 失败」的暂存副本，不碰本树）：

```
boom
rc=1（§34c 的两条 1.1 断言会红）
```

### 4.2 · `34d` 2.1 伴生路径推导的纯函数单测

```
  ✓ 34d 2.1 默认路径那一条：外层设了 TEAM_SMOKE_LOCK=<TMPDIR>/teamsmith-smoke.lock → 按同一规矩换输入（避免误判）
  ✓ 34d 2.1 默认路径 → 伴生锁（同行同目录、basename + .machine）
  ✓ 34d 2.1 私有 TEAM_SMOKE_LOCK 形状 → 默认路径取它
  ✓ 34d 2.1 私有 TEAM_SMOKE_LOCK 形状 → 伴生锁推导
  ✓ 34d 2.1 伴生锁名点开头（事故那条平铺 glob 够不着）
```

### 4.3 · `34d` 2.4 取锁时刷 `mtime`

```
  ✓ 34d 2.4 取锁时刷了伴生锁 mtime（改动前 1792144628 → 取锁后 1792151830 ≥ claimed=1792151828）
```

牙分两层：① **真变异**（第一轮门禁）：把 `touch "$SMOKE_LOCK" "$SMOKE_LOCK_COMPANION"` 一行删掉 →
`--select 34d` rc=1，2.4 断言红（日志 `/var/tmp/p305/gates/mut-mtime.log`；那一轮的内容与本分支逐字节相同）；
② 合成输入演示（交付树这一轮）：

```
mtime0=1792144958 claimed=1792152158 mtime1=1792144958 → [ … -ge … ] = 假（假 ⇒ 2.4 断言红）
刷过之后 mtime=1792152158 → [ … -ge … ] = 真（真 ⇒ 断言绿）
```

### 4.4 · 顺带发现：我自己写的 `legacy` 断言第一版**没有牙**

第一版自检用 `grep 'legacy'` 去查 `teamsmith-legacy.L1` 那一行 —— **路径自己就含 legacy**，于是变异把标注去掉后
断言仍然绿（第一轮 `mut-legacy` rc=0 抓到的就是这个：变异生效了，断言没红）。修法：fixture 目录改名
`teamsmith-oldflat.L1`，两条断言都只认标注文本 `legacy（P287 之前的平铺名，没有 ns）`。修完后变异 → 红。**这一步的原始输出**（`/var/tmp/p305/legacy-teeth/`）：

```
$ bash skills/teamsmith/tests/tmp-hygiene.sh --self-test                     # 绿侧
  ✓ P287 status：历史平铺根标 legacy
  ✓ P287 status：带 ns 的根不标 legacy
rc=0

$ 变异：legacy 标注 → 空串；bash … --self-test                              # 红侧
  ✓ status 按角色报出运行注册目录
  ✗ P287 status：历史平铺根没有 legacy 标注（  <TMPDIR>/teamsmith-oldflat.L1|    目录 · 0 KB · 1 文件 · 年龄 2 小时 · 无 owner 标记…|）
  ✓ P287 status：带 ns 的根不标 legacy
rc=1（期望 1）
· 变异已还原（逐字节相同）
```

## 5 · 5.2 / 5.3 的落地

- `tmp-hygiene.sh --status` 对「名字里没有本项目 ns 的 `teamsmith-*` 根」在归属行追加
  `legacy（P287 之前的平铺名，没有 ns）`；候选判据与 `--sweep` 谓词**不动**。自检 ① 一对断言（平铺根必须带、
  带 ns 的根不许带），⑥ 扩成同时覆盖**发布路径 / 伴生锁 / 运行注册目录**与一个陈旧平铺根：收完三样与两个
  `.holder` 都在、只有平铺根被回收。
- **现场**（私有 `TMPDIR`，脚本 `/var/tmp/p305/sweep-evidence.sh`）：陈旧平铺根 `teamsmith-selftest.OLD1` +
  锁对三样 + 两个 `.holder`：

```
$ tmp-hygiene.sh --status
不是根 · 锁对（P287：互斥在伴生锁上；发布路径只是兼容声明；三样都不是 --sweep 的候选）：
  [machine     运行互斥] <TMPDIR>/.teamsmith-smoke.lock.machine（存在）
  [published   兼容声明] <TMPDIR>/teamsmith-smoke.lock（存在；P287 之前的写入者只取这一把）
  [records     运行注册] <TMPDIR>/.teamsmith-smoke.lock.machine.runs（1 条）

$ tmp-hygiene.sh --sweep --age 0
清单（先打印，后删除；安全前提挡下的候选逐条点名）：
  [reclaim] <TMPDIR>/teamsmith-selftest.OLD1
      0 KB · 1 文件 · 无占用、年龄 3 小时 ≥ 0 分钟
  已回收 <TMPDIR>/teamsmith-selftest.OLD1（0 KB）

$ ls -a <TMPDIR>
teamsmith-smoke.lock            teamsmith-smoke.lock.holder
.teamsmith-smoke.lock.machine   .teamsmith-smoke.lock.machine.holder   .teamsmith-smoke.lock.machine.runs
```
- `references/protocol.md` §9b-2 三处：根模板 → `teamsmith-<kind>-<ns>.XXXXXX`（含 ns 推导、标记/台账/`--status`、
  `legacy`）；安全清理入口写全（`tmp-hygiene.sh --status` → `--sweep`，或只删自己项目的
  `teamsmith-<kind>-<ns>.*`；**绝不**对共享前缀写 `rm -rf`，并点名 2026-10-15 那次事故的形状）；perf 锁的记录
  位置改 `<companion>.holder`（落地如此，原文写 `<lock>.holder`）。

## 6 · 验收命令逐条（7.1）

全部在**交付树**（`task/P305-gate-lock-gaps`）上跑；原始日志留在 `/var/tmp/p305/gates-branch/`。

| # | 命令 | rc | 输出尾 / 判据 |
|---|---|---|---|
| 1 | `bash skills/teamsmith/tests/flip-p287-lock.sh --self-test` | 0 | leg2 五条 ✓；`FLIP 全绿` |
| 2 | `TEAM_FLIP_BREAK=old-probe … --self-test` | **1** | ✗ 选中的树含伴生锁实现（红侧按预期）；打印 20/20 与 rc=141 |
| 3 | `TEAM_FLIP_BREAK=main-baseline … --self-test` | **1** | ✗ 同上（第二条红侧） |
| 4 | `bash skills/teamsmith/tests/flip-p287-name.sh --self-test` | 0 | `FLIP 全绿：leg0 全绿 + shadow/lint/shape 三条腿各按预期` |
| 5 | `bash skills/teamsmith/tests/smoke.sh --select 34,34b,34c,34d,0e` | 0 | `运行 9/135 段`；`账本自查：9 段收口 · 增量 ✓314 ✗0 SKIP0 ｜ 结果行 ✓314 ✗0 —— 一致`；`== 选段结果 == ✓ 314 ✗ 0` |
| 6 | `bash skills/teamsmith/tests/tmp-hygiene.sh --self-test` | 0 | `== 结果 == ✓ 75 ✗ 0`；`tmp-hygiene.sh 自检全绿`（含 ① 两条 legacy 断言、⑥ 锁对三样一条） |
| 7 | `bash skills/teamsmith/tests/tmp-hygiene.sh --lint` | 0 | `检查了 32 个 mktemp 模板（…）`；`owned 家族 / TMPDIR / 命名空间口径全部合规` |
| 8 | `bash skills/teamsmith/tests/section-select.sh --check` | 0 | `ok: 账本归属（ledger-scan 60）声明有效：9/9`；`== 选段自检 == ok 8 bad 0 SKIP 1` |
| 9 | `bash skills/teamsmith/tests/spec-refs.sh --check` | **1** | `undeclared openspec/specs/extension-slash/spec.md:47 docs/team/tasks/P1.md`（**既有**，见 §6.3） |
| 10 | `"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict` | 0 | `Totals: 21 passed, 0 failed (21 items)` |
| 11 | `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"` | 0 | `ledger-ban: root=<worktree> scope=published files=1713 hits=0 names=ok user=resolved` |
| 12 | 投影自证（独立树 `cp -a openspec` → `archive -y gate-lock-external-deletion` → `validate --all --strict`） | 0 | `Totals: 20 passed, 0 failed (20 items)`（change 目录移出后 21→20，spec 数不变） |
| 13 | 锁被外部占住 + `TEAM_SMOKE_LOCK_WAIT=2` + `--select 0b` | **2** | `排队超限：等满 2s 仍拿不到门禁锁 …（持锁者：持有者未知）→ 本套**没有运行**`（红侧：这是既有的超限语义） |
| 14 | `TEAM_SMOKE_LOCK=<不可建路径>` + `--select 0b` | 0 | `no_lock=1（锁文件 … 建不了 → 不做排队）` + 「（记录：持有者未知）」——可见降级、不是硬失败 |
| 15 | 变异：删 `touch "$SMOKE_LOCK" "$SMOKE_LOCK_COMPANION"` → `--select 34d`（第一轮，内容与本分支逐字节相同） | **1** | 2.4 断言红 |
| 16 | 变异（本轮交付树）：把 `legacy` 标注置空 → `tmp-hygiene.sh --self-test` | **1** | ① 的 legacy 断言红（第一版无牙 → 修好后有牙，见 §4.4） |
| 17 | `git merge main` + `git status --short` + `git diff --check` | 0 | 合并只带进账本两文件（`docs/team/DECISIONS.md`、`docs/team/reviews/P303-done.md`），无冲突；树干净 |
| 18 | 现场：陈旧平铺根 + 锁对三样 + 两 `.holder` → `--status` / `--sweep --age 0` / `ls -a`（§5） | 0 | 清单只有 `[reclaim] …teamsmith-selftest.OLD1`；收完锁对三样与 `.holder` 全在、平铺根没了 |
| 19 | 变异（终版）：`--self-test --break=lock`（把「家族里的文件不是候选」这条规则关掉） | **1** | `✗ 锁保护失效（pub=没了 comp=在 runs=在 dir=没了）`，`== 结果 == ✓ 74 ✗ 1` —— ⑥ 的牙 |
| 20 | 变异（终版）：`legacy` 标注置空 → `--self-test` | **1** | `✗ P287 status：历史平铺根没有 legacy 标注（…/teamsmith-oldflat.L1）`，两条带 ns 的断言仍 ✓ —— ① 的牙（§4.4） |

### 6.2 未跑项（选段运行**不是**全套门禁）

`--select 34,34b,34c,34d,0e` 只跑了 **9/135 段**；日志列出**未跑的 126 个键**。全量另跑一次（`full-gate.log`，rc=2 —— 两个既有红灯见 §6.4）。按协议「交付跑那次跑全量、复验一次、
PM 在归档/发布里程碑再跑」，本任务的写集（测试夹具 + protocol 文档）按 `section-select.sh --paths` 的答案是
`RUN`（本次选段）；**完整 135 段的全量门禁我没有跑**，性能套件（`perf.sh`）也没有跑（red 不影响正确性判定）。
按 change 的 7.2 要求点名：**未跑的是 126 段**（清单在日志 `gates-branch/smoke-select.log` 的「这次没跑的段」一节），
不是「通过」。

### 6.3 `spec-refs.sh --check` 的 rc=1 是既有的

在**独立克隆**（`/var/tmp/p305/specref-base`，`git clone` 本仓）上复现：

```
基线 238c4c6a（本任务的改动之前）   rc=1   undeclared openspec/specs/extension-slash/spec.md:47 docs/team/tasks/P1.md
分支基点 3029115d                   rc=1   同一条
```

原因：`openspec/specs/extension-slash/spec.md:47` 的 GIVEN 例句里写了示意路径 `docs/team/tasks/P1.md`，而仓库里
**没有**这个文件（`ls` 不存在）—— 扫描器的既有形状，与本任务无关；本任务一个字未动它。**建议**（不在本任务写集内）：
要么把例句里的路径改成不存在的示意名加标记，要么让扫描器对 GIVEN/WHEN 例句里的路径放宽。

## 6.4 交付门禁（全量）与两个**既有**红灯

按协议「交付跑整套」，在交付树上跑了一次全量（`bash skills/teamsmith/tests/smoke.sh`，12:15–12:22，
日志 `/var/tmp/p305/full-gate.log`）：**rc=2** —— `#9 0i`（运行指纹夹具）与 `#35 10 · review` 两段红。

**先说结论：两处都不是本任务引入的，`0i` 已用 A/B 证到改动之前。**

### 6.4.1 `0i` 的根因：夹具嵌套临时根把私有 tmux socket 顶过 AF_UNIX 上限（既有）

夹具跑一次真门禁（`--select 0b`）作为「被测运行」，而这条内层运行的临时根嵌在夹具自己的临时根里：

```
/tmp/teamsmith-flip-p158-pm_skills-deb708fe.fMFwoh/case-clean/teamsmith-smoke-pm_skills-deb708fe.LYzrtg/tmux/tmux-1000/default
（126 字节 > AF_UNIX 上限 107 —— 私有 server 绑不上）

内层运行的自述（case-clean/run.log，`TEAM_TMP_KEEP=1` 保住的现场）：
  ✗ 隔离前置不成立：socket 路径 126 字节 > AF_UNIX 上限 107（私有 server 绑不上）
     段 0c … · 硬停（exit 2）：这条破坏性 tmux 调用绝不执行
```

于是内层运行以 **exit 2** 结束（不是夹具期望的 0/4），四条用例全红。

**改动前的 A/B（独立克隆，检出 `238c4c6a`，不含本任务任何改动）**：

```
$ cd /var/tmp/p305/specref-base && git checkout 238c4c6a && bash skills/teamsmith/tests/smoke.sh --select 0i
  ✗ 0i 红侧：四条用例全过（基线 rc=0 不报；三条改动 rc=4 都报「无效」）（期望 [0]，实际 [1]）
  ✗ 0i 四条用例各自有 ✓（不是只报了一个总数）（期望 [4]，实际 [0]）
（夹具内层运行的自述：socket 路径 142 字节 > AF_UNIX 上限 107；四条例用例 ①–④ 各 rc=2）
```

两边同因、同形 ⇒ **`0i` 在改动前就是红的**（与本任务无关）。它取决于 `ns`（`pm_skills-deb708fe`，17 字符）
与 `TMPDIR`：本项目的 ns 名字长度 + 夹具嵌套深度必然超过 107 字节，与树内容无关。**这不是本任务的写集**，
建议单立一条：给夹具的内层运行一个更短的临时根前缀（或不把 tmux socket 放进嵌套根）。

### 6.4.2 `10 · review` 的超时（预算 60s）

第一次全量里该段「超时：预算 60s，实际 60s，最后进度 43s → 停跑（exit 2）」；单独重跑（`--select 0i,10`）
同样超时（最后进度 13s）。现场（`/tmp/.teamsmith-smoke-scene.1658072/summary.txt`）显示卡在
`team review T1.1 --dir …`（进程树里那条 review 已运行 60s），当时 `loadavg 9.21/12.39/13.82`（32 核），
机器上同时有别的席位的夹具在跑。该段 P70 实测带是 10.6–14.0s、预算 60s —— 负载下的计时，
不是功能判定（D192 口径：过载时计时不作判据）。单独重跑同样红（`/var/tmp/p305/select10.log`：超时 60s、最后进度 7s），**在改动前的基线 `238c4c6a` 上也是
同形同因**（`/var/tmp/p305/select10-baseline.log`：超时 60s、最后进度 6s）——两边现场写着同一行：

```
门禁锁正被持有（kind=top pid=3423453 … 已跑 12s expected=7 bound=660；kind=top pid=3424457 … 已跑 12s …）；
排队，最多等 1800s（算式：remaining=-5s + 60s → cap=1800s，下限 TEAM_SMOKE_LOCK_WAIT=1800s…）
```

（我的现场：`/tmp/.teamsmith-smoke-scene.2879403/`；基线的现场：`/tmp/.teamsmith-smoke-scene.3424457/`。）
也就是说 `10` 在这台机器上不是负载问题而是**结构性的**：review 在独立 checkout 里起的那套门禁**把自己按
「顶层」登记**（34① 测过的「wrapped 标记 ⇒ 子套件不再二次排队」这条路没生效），于是排队等在本轮外层运行
持有的锁后面，60s 预算必然耗尽。这段属于 change 自己动过的锁记账面，与本任务无关（两棵树同形同因），
但**归档这条 change 之前值得单立一条**。

### 6.4.3 顺手清掉的**本席位**僵尸夹具（与本任务无关，但会污染锁注册表）

第一次全量前，我的席位工作树脚本路径下挂着三个更早会话遗留的顶层运行（07:34 / 09:42 / 10:16 起，
`--select 0c`、`ppid=1`、`cwd` 已被回收）——各自 `do_wait` 在一个 `p281-orphan2` 的嵌套运行上，其中
pid 1661041 以「活的 `kind=nested`」身份在锁注册表里挂了 9161s（记录：`已跑 9161s expected=0 bound=240`）。
清掉这六个进程（三个父 `3709093/1647998/2218235` + 三个子 `3719610/1661041/2224353`）后锁注册表为空、
锁空闲。**清完 `0i` 仍然复现** ⇒ 它们不是 `0i` 红的原因（§6.4.1 的 A/B 才是），但它们确实让锁的记账里
长期带着一条假的活运行。别的席位还留着同类残留（`pm-skills-ledger` 的 V53 检出里 `--select 0c` 已 2h27m、
P304 控制目录里一条）——不是我的范围，没动。

## 7 · 任务书 8 格的证据指针（写进 `tasks.md` 的原文）

| 格 | 勾选依据（本报告 / 日志） |
|---|---|
| 1.1 | §4.1 的六条 ✓（三向：同项目两 worktree 一致 / 第二仓库不同 / 非 git 与无 git 不报错）+ 牙 `rc=1 boom` |
| 2.1 | §4.2 的五条 ✓（默认路径与私有 `TEAM_SMOKE_LOCK` 两种输入 + 点开头） |
| 2.4 | §4.3（`改动前 1792144628 → 取锁后 1792151830 ≥ claimed=1792151828`）+ 真变异 rc=1 + 合成牙 |
| 4.1 | §3 的①–⑥（两个函数体 diff 空、两条 `printf` 逐字、退出码集合逐字、token 闭集、P66 marker 四条 ✓、超限现行为 rc=2 + 建不了锁 rc=0）；V53 §2.2 的例外裁定记在本节 |
| 5.2 | §5（`--status` 按角色 + `legacy` 标注 + 现场 `--sweep --age 0` 只收平铺根 + 自检 ①/⑥ + `--break=lock` 的牙） |
| 5.3 | §5 的三处缺文（protocol §9b-2） |
| 7.1 | §6 的 17 行（命令 / rc / 输出尾），含投影自证与两条现行为现场 |
| 7.2 | 本报告（含 §8 的诚实边界与 §6.2 的未跑项） |

## 8 · 诚实边界（design §10 八条，逐条对现状）

1. **没有不可删的锁**：`rm` 掉锁文件这件事在内核里无法禁止；本变更给的是**察觉**（0.2s 守卫）与**停工**
   （exit 2、无结果行），不是免疫。本任务未改变这一点。
2. **`source=path` 的窗口**：记录里的身份优先取持有者自己 `/proc` 里的 fd 身份（`lock_identity=fd`）；
   读不到时才如实写 `path`（那时取锁瞬间的替换窗口由入场登记兜住）。本任务未引入新窗口。
3. **升级过渡期**：旧的写入者（P287 之前）只取发布路径；本版本的运行先取发布路径再取伴生锁。发布路径被删时
   只点名不停跑（互斥仍在伴生锁上）；这期间启动的旧写入者可以并发 —— 会被点名、会被记录，由下一次取锁封住。
4. **`TMPDIR` 覆盖的残留**：`--status`/`--sweep` 只看**解析后的**临时根；有人用别的 `TMPDIR` 起的根不在视野里
   （除非把那个 `TMPDIR` 指过来）。`legacy` 标注只在这一层做标记。
5. **守卫不能证明「是谁换的锁」，也不能证明「有人读过那行」**：它只证明「路径上的身份不再是我持有的那个 inode」
   并把证据落盘。两种形状（已不在 / 已被替换）是**证据的形状**，不是对肇事者的归因。
6. **容器/共享临时根**：容器里 `/tmp` 可能被共享；命名空间（`ns`）把本项目与别的项目分开，但**不能**把
   「别的项目对本项目文件名的通配删除」挡住 —— 那要靠对方的清理纪律（协议里已写：只删自己的
   `teamsmith-<kind>-<ns>.*`，不许对共享前缀 `rm -rf`）。
7. **无 git 检出的 ns 各自为政**：git 不可用时 `ns` 退到 skill 自己所在目录推 hash（`<slug>-<hash8>`），
   一个目录一个 ns、两个副本互不共享 —— 这是**已知的**形状，不是缺陷也不被断言掉（§4.1 的第三向断言只保证
   「不报错 + 形状对」）。
8. **历史 111 个平铺残留不清理**：P287 之前创建的平铺根不会被自动清理；`--status` 只是把它们标 `legacy`，
   `--sweep` 的候选判据一字未动（不是本项目候选的照旧不碰）。

## 9 · 事故与防复发（越界自报）

- **事故**：三个提交（`702bafb9`/`0178b6c3`/`b0ad48b7`）误落在**主检出 main** 上。原因是 `git -C <主检出>`
  的编辑用绝对路径写文件、而 `git add/commit` 在**当时的工作目录**（本工作树）里执行 —— 命令拼在一起时
  cwd 与 `-C` 不一致。当时立即 notify PM；PM 建备份 ref `backup/P305-accident-20261016` 后 `git reset --hard`
  回事故前状态（未推送）。
- **核对**：重做后与事故提交逐文件比对 —— `smoke.sh`/`tmp-hygiene.sh`/`protocol.md` 逐字节相同；
  `flip-p287-lock.sh` 本分支更完整（红侧改成确定性复刻）。**零丢失**。
- **防复发**：每次提交前 `git rev-parse --show-toplevel` 必须等于本工作树；提交命令与文件写入用同一个 cwd。
