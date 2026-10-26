# V105 · 34d 伴生锁夹具修复的独立复验

**当前结论（第二轮 · 候选 `5ff4b1de`）：PASS** —— 首轮 PARTIAL 原文保留在下方作为历史记录，F1 的复验与最终判定见文末「Second round」。

agent: verify · 分支 `task/V105-34d-lock-shape-review` · change: `-`（test-only fixture repair）
受检候选: `f62c14fc`（`task/P374-34d-lock-shape`，只改 `skills/teamsmith/tests/smoke.sh`，+18/−2）
对照实现: `main` `e1111a27`（它的 `smoke.sh` blob `791ac33c` 与候选父提交 `56d7dcb9` 的同一 blob 相同）
运行环境: 宿主直跑，32 核，loadavg 7.6–36.6；独立磁盘 clone `$HOME/.cache/v105-review/{cand,old,mut}`，
三个 clone 跑前跑后 `git status --porcelain --untracked-files=all` 均为空（`mut` 只在变异窗口内为脏，
它是 `cp -a cand mut` 建的一次性副本，跑完已删；重建命令在证据包 `README.md` 里）
证据包: `docs/team/reports/V105-verify/`（`README.md` + `run.sh` + `mutate.sh` + `logs/`）
time: 2026-10-26T02:13Z – 02:34Z（各轮起止见 `logs/*.meta` 的 `date_start` / `date_end`）

**判定：PARTIAL —— 报告的假红确已修好，且红/绿两侧都能被改动打红；但候选新增的「默认名字面量断言」
（`smoke.sh:18210`）在普通运行里不可达，普通跑法下默认名这条 pin 实际没有断言（F1，几行可修）。**

## 0 · 先回答任务书的问题

候选做的正是它说的事：`§34d 2.1` 的期望值不再写死 `.teamsmith-smoke.lock.machine`，而是从
`gate_lock_companion_path "$P287D_DEF"` 的**同一输入**按规则反推（同目录 + 点 + basename + `.machine`）。
私有锁 `7-1.lock` 下旧断言红、候选绿（§1.2），把 `gate_lock_companion_path` 改成「没有前导点」
或「搬到临时根」都会让新断言红并点名（§1.3）。缺的一处是候选自己承诺保留的那条字面量断言
（它的提交信息写 “keep the default-name literal only when TEAM_SMOKE_LOCK is unset”）：普通运行里
`TEAM_SMOKE_LOCK` 一定非空，所以这条断言从不执行（§1.4）。这不是产品缺陷，改一行即可。

## 1 · 任务书五项必做检查

### 1.1 候选两轮（`--select 34d`，各自私有磁盘 `TMPDIR`）

```
$ TMPDIR=$HOME/.cache/v105-review/tmp/cand-noenv \
  bash skills/teamsmith/tests/smoke.sh --select 34d          # 未设 TEAM_SMOKE_LOCK
== 选段结果 ==  ✓ 132  ✗ 0        exit=0  用时 235s   （logs/cand-noenv.{log,meta}）

$ TMPDIR=$HOME/.cache/v105-review/tmp/cand-priv \
  TEAM_SMOKE_LOCK=$HOME/.cache/v105-review/tmp/cand-locks/7-1.lock \
  bash skills/teamsmith/tests/smoke.sh --select 34d          # 私有发布路径，V103 那个名字
== 选段结果 ==  ✓ 132  ✗ 0        exit=0  用时 197s   （logs/cand-priv.{log,meta}）
```

两轮 `§34d` 本身都是 `✓108 ✗0`，账本自查 `增量 ✓132 ✗0 ｜ 结果行 ✓132 ✗0 —— 一致`。
私有锁那轮的 2.1 六条断言全绿，其中一条的输入就是 `.../cand-locks/7-1.lock`：

```
✓ 34d 2.1 默认路径那一条：外层设了 TEAM_SMOKE_LOCK=.../cand-locks/7-1.lock → 按同一规矩换输入（避免误判）
✓ 34d 2.1 默认路径 → 伴生锁名 = 点 + basename(发布路径) + .machine
```

### 1.2 旧实现 + 同一把私有锁（翻转证据的红侧）

```
$ TMPDIR=.../tmp/old-priv TEAM_SMOKE_LOCK=.../tmp/old-locks/7-1.lock \
  bash skills/teamsmith/tests/smoke.sh --select 34d          # main e1111a27
✗ 34d 2.1 默认路径 → 伴生锁（同行同目录、basename + .machine）
  （期望 [.../old-locks/.teamsmith-smoke.lock.machine]，实际 [.../old-locks/.7-1.lock.machine]）
== 选段结果 ==  ✓ 130  ✗ 1        exit=1  用时 170s   （logs/old-priv.{log,meta}）
```

同一份旧实现在默认输入下是绿的（`✓ 131 ✗ 0`，exit=0，`logs/old-noenv.*`）—— 红只跟私有输入有关，
不是夹具坏了。旧实现在两种输入下都是 131 条断言（私有那轮是 130 ✓ + 1 ✗），候选是 132 条，
差额是新增的那条推导断言。

### 1.3 私有副本里改坏 `gate_lock_companion_path`（`mut` = `cand` 的 `cp -a`）

去掉前导点（`printf '%s/%s.machine' "$dir" "$base"`，diff 见 `logs/mutA.diff`）：

```
✗ 34d 2.1 伴生锁名不是「点开头 + .machine 结尾」：.../tmp/mutA/teamsmith-smoke.lock.machine
✗ 34d 2.1 私有 TEAM_SMOKE_LOCK 形状 → 伴生锁推导（期望 [.../p287-id/.priv.lock.machine]，实际 [.../p287-id/priv.lock.machine]）
✗ 34d 2.1 伴生锁名不是点开头：/x/y.lock.machine
```

把伴生锁搬到临时根（`printf '%s/.%s.machine' "${TMPDIR:-/tmp}" "$base"`，私有锁放在同级
`mutB-locks/` 目录，`logs/mutB.diff`）：

```
✗ 34d 2.1 默认路径 → 伴生锁同目录（同行同目录，不跟着临时根搬）（期望 [.../tmp/mutB-locks]，实际 [.../tmp/mutB]）
✗ 34d 2.1 私有 TEAM_SMOKE_LOCK 形状 → 伴生锁推导（期望 [.../p287-id/.priv.lock.machine]，实际 [.../tmp/mutB/.priv.lock.machine]）
== 选段结果 ==  ✓ 130  ✗ 2        exit=1  用时 163s   （logs/mutB.{log,meta,diff}）
```

还原后同一私有锁输入，2.1 六条全绿（`logs/mutR.log`；该轮按设计 60s 截断，完整一轮的绿是 §1.1 的
`cand-priv`）。还原前后的副本 `git status` 为空，即副本与候选逐字节相同。
`mutA` 的同一次运行也按设计在 60s 被截断（退出码 124 不是判定）：前导点去掉后，`§34d ①②` 的场景
夹具等的是写死的 `.teamsmith-smoke.lock.machine`，每个场景要等满 300s 才报一句会误导的 `exit 9`，
所以只取 2.1 块那三条点名红。

### 1.4 默认输入那条字面量断言 —— 这项没达成（F1）

私有输入那一半成立：期望名从私有路径派生，`7-1.lock → .7-1.lock.machine`、`priv.lock → .priv.lock.machine`，
单一前导点、无双点（`cand-priv` 的期望/实际都是 `.7-1.lock.machine`；纯函数探针的三种输入见 §3）。

默认输入那一半不成立：**两轮候选运行走的都是 else 分支**，新增的字面量断言没执行。

```
✓ 34d 2.1 默认路径那一条：外层设了 TEAM_SMOKE_LOCK=.../tmp/cand-noenv/teamsmith-smoke.lock → 按同一规矩换输入（避免误判）
```

原因是 `smoke.sh:684` 在起子套件前就 `export TEAM_SMOKE_LOCK="$SMOKE_LOCK"`（`SMOKE_LOCK` 在
`smoke.sh:446` 已解析成默认路径），所以段体里 `TEAM_SMOKE_LOCK` 永远非空 —— 不设该变量的**调用者**
进来后，段内看到的也是默认路径。前置的 `smoke.sh:18188` 那条判断同样一直落 else 分支（`18189` 那句
`assert_eq` 比较的是同一个函数调用两次，本来就是恒真）。字面量断言只在没人取锁的那条路上可达：

```
$ TMPDIR=.../tmp/cand-nolock TEAM_SMOKE_NO_LOCK=1 bash skills/teamsmith/tests/smoke.sh --select 34d
✓ 34d 2.1 默认路径（未设 TEAM_SMOKE_LOCK）
✓ 34d 2.1 未设 TEAM_SMOKE_LOCK → 默认名的伴生锁就是 .teamsmith-smoke.lock.machine
```

（`logs/cand-nolock.{log,meta}`，55s 截断，只取 2.1 块。）
后果是精确的：默认跑法下「默认锁名是 `teamsmith-smoke.lock`」这条常量不再有断言——同一条 2.1 的
派生断言期望 `.$(basename "$P287D_DEF").machine`，默认名被改掉时会跟着一起变，于是绿。

### 1.5 静态读数

```
$ bash -n skills/teamsmith/tests/smoke.sh                                   → rc=0
$ bash skills/teamsmith/tests/section-select.sh --check
ok: 分片是地板的精确划分（N=2 3 4 5 6 8 12：128 段，每片非空、无重复、无遗漏）
== 选段自检 ==  ok 12  bad 0  SKIP 1                                        → rc=0
$ bash skills/teamsmith/tests/section-guard.sh --loop-check
ok: 扫描 83 行清单 / 83 个 while+sleep 循环，配平 83 个
section-guard --loop-check: 全过                                            → rc=0
$ git diff --check                     （工作树干净）                       → rc=0
$ git diff --check f62c14fc^ f62c14fc  （候选这一个提交）                   → rc=0
```

选段自检那 1 条 `SKIP` 与本次候选无关（它是既有条目，读数与 `main` 相同）。未跑整套、未进容器。

## 2 · 必改项

**F1 · `smoke.sh:18210` 的字面量断言在普通运行里不可达。** 证据见 §1.4：两轮候选运行与
`TEAM_SMOKE_NO_LOCK=1` 那轮的对比，加上 `smoke.sh:684` 的导出。影响：默认跑法（门禁、CI、复验）里
默认锁名这条常量没有断言；§34d ① 仍能抓到改名，但要等 300s 并报一句与原因无关的 `exit 9`。

最小修法（二选一，我没有动代码）：

- 推荐：把常量断言改成不依赖调用者环境 —— 用子 shell 强制拿默认值再比对，例如
  `(unset TEAM_SMOKE_LOCK; gate_lock_default_path)` 的 `basename` 必须等于 `teamsmith-smoke.lock`，
  伴生锁那条随之变成无条件断言。这同时把 `18189` 那条恒真断言变成真断言。
- 或者：在 `smoke.sh` 取锁之前把**调用者的**输入记下来（如 `SMOKE_LOCK_FROM_CALLER="${TEAM_SMOKE_LOCK:-}"`），
  `18188` / `18209` 两处改用这个变量判断，不要用运行期已被改写的 `TEAM_SMOKE_LOCK`。

## 3 · 观察（不阻塞）

- 派生规则本身没有被写成双点：伴生锁名是「一个点 + basename + `.machine`」，候选三种输入实测
  `teamsmith-smoke.lock → .teamsmith-smoke.lock.machine`、`priv.lock → .priv.lock.machine`、
  `7-1.lock → .7-1.lock.machine`，与各自由 `dirname` 推出来的期望值逐字相同。输入本身以点开头时才会
  出现 `..x.lock.machine`，那是规则的直接结果，套件里没有这种输入。
- 新断言是对规则的独立重述（`dirname`/`basename` + 字面 `.machine`），不是调用同一表达式自证；
  两个变异各自打红且点名，可作为这条判断的证据。
- 我会在报告外说明一件事：第一次跑变异时脚本用了相对路径、没先进副本，把应该落在副本里的
  `skills/teamsmith/scripts/lib/gate-lock.sh` 改到了**我这个工作树**的同一文件上（那是产品实现，不在
  `verify` 的写集里）。我从「diff 文件为空但 2.1 仍全绿」发现它、用 `team bg stop v105-mut` 停掉作业、
  `git checkout --` 还原，并核对 blob 与 HEAD 相同（`1221a48e`）；此后脚本的每条路径都是绝对路径并断言
  落在副本里。产品实现与候选都没有因此改变（还原后工作树 `git status` 为空，候选 clone 全程为空）。

## 4 · 边界

未跑整套、未进容器、未新建夹具或守卫、未修改候选与 `main`、未 push（local 模式）、未 archive；
只写了本报告与自己的线程，证据包在 `docs/team/reports/V105-verify/`（按仓库 `.gitignore` 不入库，
`docs/team/reports/**` 只放行顶层 `.md`）。

## Second round

**判定：PASS —— F1 已修好。**默认输入下那条常量断言现在真的执行（普通跑法与私有锁跑法都跑到并打印），
把默认锁名改掉时它会红并点名期望值与实际值；按输入派生的三条规则断言同时保持绿，首轮两条形状变异结论不受影响。
受检对象 `5ff4b1de`（`smoke.sh` blob `ed32b7e2`，与 `7ce7fec5` 逐字节相同；本轮不重复审 `7d2d561b` 的合并，
它对 `smoke.sh` 零改动）。

时间窗口 2026-10-26T02:59:52Z – 03:10:38Z，宿主直跑，32 核，loadavg 4.1–6.6。
运行场地是磁盘 clone `$HOME/.cache/v105-review/cand2`（= `5ff4b1de`）与它的私有副本 `mut2`
（`cp -a` 一次，只用于变异）。两个 clone 跑前跑后 `git status --porcelain --untracked-files=all` 都是空；
`mut2` 只在变异窗口内为脏，还原后与候选逐字节相同（R4 的 `cmp`）。

### R1 · 普通运行（未设 `TEAM_SMOKE_LOCK`）：两条默认名断言真的出现在输出里

```
$ TMPDIR=$HOME/.cache/v105-review/tmp/r2-cand-default \
  bash skills/teamsmith/tests/smoke.sh --select 34d
  ✓ 34d 2.1 未设 TEAM_SMOKE_LOCK → 默认发布路径的名字是 teamsmith-smoke.lock
  ✓ 34d 2.1 未设 TEAM_SMOKE_LOCK → 伴生锁就是同目录的 .teamsmith-smoke.lock.machine
  ✓ 34d 2.1 本次发布路径 = TEAM_SMOKE_LOCK（外面没给就是刚算出的默认值）
  ✓ 34d 2.1 发布路径 → 伴生锁同目录（同行同目录，不跟着临时根搬）
  ✓ 34d 2.1 发布路径 → 伴生锁名 = 点 + basename(发布路径) + .machine
  ✓ 34d 2.1 私有 TEAM_SMOKE_LOCK 形状 → 默认路径取它
  ✓ 34d 2.1 私有 TEAM_SMOKE_LOCK 形状 → 伴生锁推导
  ✓ 34d 2.1 伴生锁名点开头（事故那条平铺 glob 够不着）
账本自查： 5 段收口 · 增量 ✓134 ✗0 SKIP0 ｜ 结果行 ✓134 ✗0 —— 一致
== 选段结果 ==  ✓ 134  ✗ 0
```

exit=0，165s（`logs/r2-cand-default.{log,meta}`）。这一轮没有 `TEAM_SMOKE_NO_LOCK`、没有截断，
前两条就是首轮 F1 缺的那两条字面量断言，在普通跑法里直接执行并通过。运行自己取的锁也印证默认形状：
`持有 .../r2-cand-default/teamsmith-smoke.lock（互斥在伴生锁 .../r2-cand-default/.teamsmith-smoke.lock.machine）`。

### R2 · 私有锁 `7-1.lock`：绿，派生值就是 `.7-1.lock.machine`

```
$ TMPDIR=$HOME/.cache/v105-review/tmp/r2-cand-priv \
  TEAM_SMOKE_LOCK=$HOME/.cache/v105-review/tmp/r2-locks/7-1.lock \
  bash skills/teamsmith/tests/smoke.sh --select 34d
  （2.1 八条与 R1 同，全 ✓）
== 选段结果 ==  ✓ 134  ✗ 0
```

exit=0，163s（`logs/r2-cand-priv.{log,meta}`）。`.7-1.lock.machine` 不是靠断言自证，而是运行真正握的那把锁：
`持有 .../r2-locks/7-1.lock（互斥在伴生锁 .../r2-locks/.7-1.lock.machine）` —— 一个前导点，没有双点。
两条字面量断言在私有输入下仍然通过，因为它在子 shell 里 `unset TEAM_SMOKE_LOCK` 再问产品函数：
外部换输入不会再让常量那条失真，这正是首轮那张假红要修的东西。

### R3 · 私有副本里改默认锁名：两条字面量红、三条规则绿

`mut2` 里只改 `gate_lock_default_path` 的默认名（`teamsmith-smoke.lock` → `teamsmith-smoke-renamed.lock`，
`logs/r2-mut.diff` 只有这一行）：

```
$ TMPDIR=.../tmp/r2-mut-default bash skills/teamsmith/tests/smoke.sh --select 34d
  ✗ 34d 2.1 未设 TEAM_SMOKE_LOCK → 默认发布路径的名字是 teamsmith-smoke.lock（期望 [teamsmith-smoke.lock]，实际 [teamsmith-smoke-renamed.lock]）
  ✗ 34d 2.1 未设 TEAM_SMOKE_LOCK → 伴生锁就是同目录的 .teamsmith-smoke.lock.machine（期望 [.../tmp/r2-mut-default/.teamsmith-smoke.lock.machine]，实际 [.../tmp/r2-mut-default/.teamsmith-smoke-renamed.lock.machine]）
  ✓ 34d 2.1 本次发布路径 = TEAM_SMOKE_LOCK（外面没给就是刚算出的默认值）
  ✓ 34d 2.1 发布路径 → 伴生锁同目录（同行同目录，不跟着临时根搬）
  ✓ 34d 2.1 发布路径 → 伴生锁名 = 点 + basename(发布路径) + .machine
```

按设计 150s 截断，退出码 124 不是判定（`logs/r2-mut-default.{log,meta}`）：2.1 块在段落开头执行，
不需要等后面的场景夹具。首轮做不到这一点 —— 旧实现把常量那条锁在 `TEAM_SMOKE_LOCK` 为空的分支里，
普通跑法下改默认名没有任何断言直接红，只能等 `34d ①` 的场景夹具超时后报一句与原因无关的 `exit 9`。

### R4 · 还原后普通跑法回到绿

```
$ git -C mut2 checkout -- skills/teamsmith/scripts/lib/gate-lock.sh   # dirty=0
$ cmp mut2/…/gate-lock.sh cand2/…/gate-lock.sh   → identical
$ cmp mut2/…/smoke.sh     cand2/…/smoke.sh       → identical
$ TMPDIR=.../tmp/r2-mut-restore bash skills/teamsmith/tests/smoke.sh --select 34d
== 选段结果 ==  ✓ 134  ✗ 0
```

exit=0，167s（`logs/r2-mut-restore.{log,meta}`），2.1 八条全 ✓。

### R5 · 增量核（`f62c14fc..5ff4b1de`）

```
$ git diff --stat f62c14fc 7ce7fec5     → skills/teamsmith/tests/smoke.sh | 32 +++--- (17+/15-)
$ git diff --name-only f62c14fc 7ce7fec5 → skills/teamsmith/tests/smoke.sh
$ git rev-parse f62c14fc:…/gate-lock.sh 5ff4b1de:…/gate-lock.sh 7d2d561b:…/gate-lock.sh
  → 三处都是 1221a48e（产品实现没被碰，首轮两条形状变异仍有效，本轮不重跑）
```

对照首轮的断言清单，**既有的伴生锁形状断言都还在**：`伴生锁同目录`、`点 + basename + .machine`、
`case *) bad 伴生锁名不是「点开头 + .machine 结尾」`、私有输入两条、`点开头` 探针；
只把标签里的「默认路径」改成「发布路径」（现在它对两种输入都成立）。删掉的是首轮那个
`if [ -z "$TEAM_SMOKE_LOCK" ]` 分支和「换输入（避免误判）」那句只打印不断言的 `ok`。
新增的只有三件，与任务书要求一致：

1. `P287D_DEF_DEFAULT="$(unset TEAM_SMOKE_LOCK; gate_lock_default_path)"`，再断言它的 basename 是
   `teamsmith-smoke.lock`（无条件，不再依赖调用者环境）；
2. 同一默认值的伴生锁等于 `dirname/.teamsmith-smoke.lock.machine`（无条件）；
3. `P287D_DEF = ${TEAM_SMOKE_LOCK:-$P287D_DEF_DEFAULT}` 的当前路径一致性检查 —— 它把首轮那条
   「同一个函数调用两次」的恒真断言换成了有内容的比较。

### R6 · 静态读数（候选 clone 内，与首轮同一组）

```
$ bash -n skills/teamsmith/tests/smoke.sh                                → rc=0
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 12  bad 0  SKIP 1                                     → rc=0
$ bash skills/teamsmith/tests/section-guard.sh --loop-check
section-guard --loop-check: 全过                                          → rc=0
$ git diff --check                                                       → rc=0
$ git diff --check f62c14fc 5ff4b1de -- skills/teamsmith/tests/smoke.sh   → rc=0
```

（`logs/r2-static.log`。读数与首轮 §1.5 相同；选段自检那 1 条 `SKIP` 是既有条目 `.pi/skills`，与候选无关。）

### R7 · 观察（不阻塞）

- 内容上并非零和：删掉的那句 `ok` 只回显调用者的输入，不含断言；它的信息现在由第 3 条一致性检查
  以可失败的比较承担（R3 里它就是绿的，因为 `mut2` 改的是默认值而不是发布路径）。
- `34d ①` 的场景夹具在锁名不对时仍会各自等满 300s 才报一句与原因无关的 `exit 9`；新增的两条断言
  把这类改名在段落开头就点名，不必等夹具超时。这是本轮修好 F1 的实际价值，也是它值得保留的理由。
- 首轮 §3 记录的「变异脚本第一次写错位置」不适用于本轮：`mut2` 是独立 clone，
  `git -C mut2 rev-parse --show-toplevel` 写前断言过，diff 只有那一行。

### R8 · 边界（第二轮）

只跑了 `--select 34d` 的四轮（R1–R4，R3 按设计 150s 截断）与 R6 的静态检查；未跑整套、未进容器、
未新建夹具或守卫、未修改候选与 `main`、未 push（local 模式）、未 archive。
证据包同首轮（`docs/team/reports/V105-verify/`），本轮新增驱动 `round2.sh` 与 `logs/r2-*`。
