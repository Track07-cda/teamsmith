# gate-lock-hygiene · 设计

## 0 范围与写法

本文件回答 brief 的三问（判定 / 修法 / 三条红侧的设计），并给出 apply 需要的接口冻结。合同文本在
`specs/verification/spec.md`（2 条 ADDED + 1 条 MODIFIED）；本文件不是规格。

事实分两类，分别标注：
- **[实测]** —— 本 worktree 2026-10-15 亲手跑的，命令与输出原文在本节；
- **[引用]** —— 别人已经记在磁盘上的（`docs/team/reports/P255-dev-bob.md`、`tests/section-budgets.tsv`）。

所有实测都用**私有锁**与**私有 `TMPDIR`**：机器锁 `/tmp/teamsmith-smoke.lock` 一个字节没碰，也没有起任何
共享 tmux 调用。本任务只写提案，不跑门禁。

## 1 事实（决定做法的那几条）

### 1.1 锁块与记录写入者的形状 [实测 · 读码]

`skills/teamsmith/tests/smoke.sh` 的锁块（`:324`–`:400`）三段：

- `:324` 顶层判定：`FAST=0 && TEAM_SMOKE_NO_LOCK != 1 && SMOKE_LOCK_WRAPPED != 1` → 进排队/加锁路径；
- `:355`–`:375` 用 `flock --close -w "$SMOKE_LOCK_WAIT"` 把**整份脚本**（或选段过滤副本）重跑一遍，
  `:357` `export SMOKE_LOCK_WRAPPED=1`；marker 文件是「真的拿到了锁」的唯一证据（P66）；
- `:396`–`:400` **任何**带 `SMOKE_LOCK_WRAPPED=1` 的进程都认为「本套持有锁」，并把
  `<ISO> pid=$$ cmd=smoke.sh` 写进 `<lock>.holder`；`:881` 的 EXIT 收尾在 `SMOKE_LOCK_HELD=1` 时
  `rm -f <lock>.holder`。

关键：`:396` 的判定读的是**环境标记**，不是「本进程是不是 flock 的持有者」。标记会被继承，所以**嵌套运行**
会走到同一行。

### 1.2 EXP1 —— 嵌套运行覆写并删除真正的持有者记录 [实测]

```bash
D=/tmp/p280-exp; rm -rf $D; mkdir -p $D/t1; L=$D/lock; : >> $L
flock --close -x $L sleep 25 & HP=$!; sleep 0.3
printf '%s pid=%s cmd=REAL-HOLDER\n' "$(date -Is)" "$HP" > "$L.holder"
# 一个「带 wrapped 标记的嵌套全量 run」（真实入口、私有锁、私有 TMPDIR、只选两段）
env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_DOCS_DIR -u TEAM_SKILL_DIR \
    TMPDIR=$D/t1 TEAM_SMOKE_LOCK=$L SMOKE_LOCK_WRAPPED=1 \
    bash skills/teamsmith/tests/smoke.sh --select 0b </dev/null > $D/nested.log 2>&1
```

原文输出：

```
before nested run: 2026-10-15T11:40:54+00:00 pid=3458474 cmd=REAL-HOLDER
nested rc=0
after nested run: [<MISSING>]
--- nested log: 持有行 ---
  · 全量门禁互斥：持有 /tmp/p280-exp/lock（同机第二套会排队；TEAM_SMOKE_NO_LOCK=1 可跳过）
```

即：**真持有者还在跑**（`flock ... sleep 25` 未结束），而嵌套运行打印了「持有」、把记录改成自己、
并在退出时把它**删掉**。所以等待者读到的持有者可能是错的，也可能是「持有者未知」——而真正持有锁的那个进程
的席位、工作树、已跑时长从来没有被记录过。

### 1.3 EXP2 —— 丢掉标记的嵌套全量运行会拿到机器锁 [实测]

```bash
env -u TEAM_ROOT … TMPDIR=$D/t2 TEAM_SMOKE_LOCK=$L2 TEAM_SMOKE_LOCK_WAIT=20 \
    bash skills/teamsmith/tests/smoke.sh --select 0b </dev/null > $D/nested2.log 2>&1
```

```
nested rc=0
--- 日志里的互斥行 ---
  · 全量门禁互斥：持有 /tmp/p280-exp/lock2（同机第二套会排队；TEAM_SMOKE_NO_LOCK=1 可跳过）
```

它没有「另一套正在跑」的排队行——因为那一刻锁是空的，它**自己**拿到了锁。同一形状打在机器锁上，就是
2026-10-15 那次实测：一个席位自己的运行持有机器锁 1 小时 16 分。夹具侧今天靠「每个嵌套调用自己记得带
`TEAM_SMOKE_NO_LOCK=1`」避免这件事（`tests/` 里 12 处），也就是说这条纪律**靠记性**，没有机制兜底——
而 `SMOKE_LOCK_WRAPPED` 恰好是夹具为了测排队路径**故意 `env -u` 掉**的那个变量。

### 1.4 EXP3 —— 等待者看到的一行 [实测]

```bash
: > $L2; flock --close -x $L2 sleep 8 & HP=$!; sleep 0.3
printf '%s pid=%s cmd=smoke.sh\n' "$(date -Is)" "$HP" > "$L2.holder"
env -u … TMPDIR=$D/t3 TEAM_SMOKE_LOCK=$L2 TEAM_SMOKE_LOCK_WAIT=1 \
    bash skills/teamsmith/tests/smoke.sh --select 0b </dev/null
```

```
另一套全量 smoke 正在跑（2026-10-15T11:41:28+00:00 pid=3603975 cmd=smoke.sh）；本套排队，最多等 1s（TEAM_SMOKE_NO_LOCK=1 可跳过排队）
排队超限：等满 1s 仍拿不到门禁锁 /tmp/p280-exp/lock3（持锁者：2026-10-15T11:41:28+00:00 pid=3603975 cmd=smoke.sh）→ 本套**没有运行**（这不是对代码的判定；等持锁者结束，或抬高 TEAM_SMOKE_LOCK_WAIT 后重跑；TEAM_SMOKE_NO_LOCK=1 可跳过排队）
```

`cmd=smoke.sh` 对**外层**运行和**嵌套**运行完全同形；没有席位、没有工作树、没有已跑时长、没有上限。
`cmd-review.sh` 的排队路径写的是 `cmd=team review <id>`（`:1101` 的 `QUEUE_WRAP`），同样是这四样都缺。

### 1.5 上限与运行时长从来不是一个口径 [实测 · 读表]

```
$ awk -F'\t' '!/^#/ && NF>=3 && $2 ~ /^[0-9.]+$/ {n++; s+=$3; b+=$2} END{printf "rows=%d sum_band=%.2f sum_budget=%d\n", n, b, s}' \
    skills/teamsmith/tests/section-budgets.tsv
rows=129 sum_band=9330.28 sum_budget=41362
```

单段最大是 `61b · 任务类别模型路由：翻转变异自检`：band **5000** / budget **20000**（表里写着 P238 实测
独立跑 4883s、V28 复验 4946s）。§61b 在**完整门禁**里真跑（`:20482` 只在 FAST 档可见跳过）。
而等待者的上限是 `TEAM_SMOKE_LOCK_WAIT` 默认 **1800s**（`smoke.sh:327`、`cmd-review.sh:1068`）。
一次完整门禁合法地跑 80 分钟以上，等待者 30 分钟就 FAIL——两个数字没有共同口径，且 FAIL 的文案里
没有任何东西能让读的人看出「这是合法的长运行」还是「谁坏了」。

### 1.6 同源的账 [引用]

`docs/team/reports/P255-dev-bob.md` §2.2 / §4.1 记着同一天同一台机器的三次「机器欠的账」：
**§36 超时**（预算 1400s、最后进度 297s、loadavg 20+）、**两次 ENOSPC 造成的假红**（§36⑦/§36⑧ 的嵌套运行、
§40 的两条、P122/P70 的段账计数，共 ✗10）、以及 **r6「本套没有运行」**（默认 `TMPDIR` 重跑任务书原命令时在
机器锁上等满 1800s，持锁者是一条挂了 1h20m 的运行）。作者同时自报了 r4/r5 把 `TMPDIR` 覆盖掉、等于把锁也搬进
私有目录，于是与别的席位**并发**跑了——那是「一次只跑一套」这条机器纪律被绕过的现场，正好说明锁不是多余的。

loadavg 20+ 出现在**排队正常**的 r3 里，也就是说：**一套全量门禁自己就能把 32 核机器压到 20+**。
这条事实支持两件事：① 锁要留（两套并发会更糟）；② 嵌套运行**不能没有预算**——一台机器已经被一套运行压满时，
再让一个没有期限的夹具叠上去，就是 §36 那次超时的形状。

## 2 判定 D1：嵌套运行该不该抢机器级的那把锁

**结论：不该。** 机器锁的契约是「串行化**顶层**运行」，嵌套运行按定义在一个顶层运行内部——它的祖辈已经
持有那把锁，它再去排同一把锁**不是更多的串行化**，而是：

- **把整队唯一的共享资源交给一个夹具**：实测的 1h16m 就是这条（EXP2 的形状打在机器锁上）。等待者排队等的是
  「别人的门禁」，实际等的是一个夹具内部的全量套件。
- **与自己祖辈自锁**：祖辈不释放锁，嵌套运行永远拿不到；今天没炸只是因为大多数嵌套调用恰好带了
  `SMOKE_LOCK_WRAPPED` 或 `TEAM_SMOKE_NO_LOCK`（靠记性，见 1.3）。
- **让 FAIL 的归因失真**：排队超限时点名的持有者是 `smoke.sh`（EXP3），读的人分不出「嵌套堵住了」还是
  「谁坏了」。

**另一侧的代价（brief 点名的那条）**：不抢 → 两个席位的嵌套运行可能同时在机器上跑重活，loadavg 会上去。
这一侧的交代有三条，都要写进合同与记录，不许用一句「不会发生」打发：

1. **放行是有条件的**：嵌套运行只有在**能证明祖辈持有锁**时才不排队。证明走**进程树**——沿 ppid 走到
   `<lock>.holder` / `<lock>.runs/*.run` 记的持有者 pid，且该 pid 的 starttime 仍是那一次（pid 复用安全）。
   证明不成立 → 它就是**顶层**运行，照旧排队。所以「不排队」不是自由通行证。
2. **一次只放一个顶层运行**：锁仍然只串行化顶层运行，而嵌套运行必须有活着的顶层祖辈。跨席位的嵌套重叠因此
   只可能来自**显式退出串行**——`TEAM_SMOKE_NO_LOCK=1`（契约原文写着「自担并发风险」）、没有 `flock`、
   或 FAST 档（按契约不跑真进程段，§14c 守着）。这个残余窗口记进记录（`no_lock=1`）与
   `references/protocol.md` §9b，让它**可观测**，而不是被断言掩盖。P255 的 r4/r5 就是这条窗口的现场。
3. **嵌套运行必须有预算**：它登记 `expected`/`bound`，期限对齐到**生它的那一段的剩余预算**；到点由它自己的
   看门狗点名 + 停跑 + 留现场（既有机制）。所以即使残余窗口成立，叠上去的也是有期限的活，不是一个没有上限的
   夹具。

**被否掉的备选**（写在这里，免得 review 时再问一遍）：

- *「嵌套运行也排队，但给一个小上限」*：上限不能把嵌套运行的**工作量**变小，只能改「谁被 FAIL」。堵住整队的
  原因是「嵌套运行持有机器锁」，不是「它等太久」。
- *「给嵌套运行另一把锁（`<lock>.nested`）」*：多一把锁就多一份「谁持有、多久、上限多少」的自述与
  清理责任，而它要挡的只是同一台机器上的重活叠加——那件事已经有既有的**负载前提**
  （`loadavg_1m ≤ factor × 核数`，D33/P56）在管性能与面板段落。本变更不新增第二把锁；残余窗口按第 2 条
  记成 `no_lock=1` 可见。

## 3 记录形状（D2）与接口冻结

### 3.1 两个位置，一个写者规则

- `<lock>.holder`：**只有真的持有 flock 的那个进程**写它、也只有它删它（收尾时）。字段见 3.2。
- `<lock>.runs/<pid>.run`：**每个**顶层/嵌套运行登记自己的一条，退出时删自己那条。等待者 glob 之后按
  pid+starttime 过滤，把「已死但没清掉」的条目打印成 `stale` 并**忽略**（不静默信任，也不去删别人的文件——
  删只删自己写的那条）。

为什么不是单文件追加：EXP1 就是多写者（覆写 + 删除）的病；每运行一条文件天然无竞争，且等待者能一次读全。

### 3.2 字段（两个位置同形）

```
<ISO-8601>\tpid=<pid>\tkind=<top|nested>\tagent=<席位>\tworktree=<绝对路径>
\tstarted=<epoch>\texpected=<Σband_s>\tbound=<Σbudget_s>\tsections=<段数>
\tno_lock=<0|1>\tancestor=<pid|->\theartbeat=<section-guard 心跳路径|->
```

- `agent` / `worktree`：取自**运行时目录**（`team notify` 发送者同一条规则：包含 cwd 的工作树一级目录名，
  名册拼写优先），**不取窗口名**（`tmux-identity-scope` 的教训）。解析不出来就写 `agent=?` /
  `worktree=?`——**如实说不知道**，不猜。
- `expected` / `bound`：`Σband_s` / `Σbudget_s`，取 `tests/section-budgets.tsv`；全量运行 = 全表
  （9330 / 41362），`--select` / `--paths` = 选中键的闭包（含 `needs`）。表里没登记的段用
  `SG_DEFAULT_BUDGET`（900）计入，并在记录里标 `sections` 的段数，让「读表读到了几段」可核。
- `heartbeat`：持有者当前武装段的 section-guard 心跳文件路径（`section-guard.sh` 的 `SG_HEARTBEAT`）。
  嵌套运行读它（格式 `no|armed_epoch|budget|elapsed|ticks|id`）拿到祖辈的期限。顶层运行还没武装第一段时写 `-`。

### 3.3 席位/工作树的解析要可证伪

夹具用**私有 `TMPDIR` 与私有锁**，在 `.worktrees/<name>/` 形状与「名册拼写」两种情形下各断言一次，
并给一条反向对照：窗口名故意报成别的席位（cwd 仍是本工作树）→ 记录里仍是 cwd 的那个席位。
这条与 `notify` 的发送者同源，`tests/` 里已有同形的先例可抄（P82 的 3.1/3.2）。

## 4 嵌套运行的纪律（requirement #2 的可判定形状）

一个运行的四种状态，判定顺序固定：

| 状态 | 判定 | 行为 |
|---|---|---|
| `top` | 没有祖辈持有锁（含：锁空、或持有者不是自己的祖辈） | 照今天的排队/加锁路径，记录 `kind=top` |
| `nested` | 沿 ppid 走到持有者 pid（pid+starttime 匹配） | **不排队**；登记 `<lock>.runs/<pid>.run`（`kind=nested`、`ancestor=<pid>`）；期限对齐祖辈武装段 |
| `no_lock` | 环境是 `TEAM_SMOKE_NO_LOCK=1` / 没有 `flock` / FAST | 照今天：打印降级行，记录 `no_lock=1` |
| `stale` | 记录里的持有者 pid 已死或 starttime 不符 | 打印 `stale` 并忽略该条；不删别人的文件 |

**期限对齐**：嵌套运行把自己的 section guard 武装期限设为 `min(自己的表预算, 祖辈武装段的 armed_epoch + budget)`。
到点走既有 trip 路径：一行点名（`#<no> <id> … 超时：预算 Ns，实际 Ns`）+ 写现场 + 停跑；登记随之消失。
祖辈的 `heartbeat` 读不到（顶层还没开段）时，只用自己的表预算。

**「不许无声占着」的第二个口子**：夹具把嵌套运行丢到后台、自己先收段的情况。门禁在该段收口后检查
`<lock>.runs/*` 里 `ancestor=<自己的 pid>` 的条目是否仍活着；仍活着就**打印一行点名**（可见，不静默），
并按 D37 的纪律只对**自己登记过的 pid** 发信号收尾（不按名字、不按进程组）。

## 5 上限算式（D3）

```
remaining = expected − (now − started)              # 记录里没有 expected 时：不进入这个分支
cap       = clamp(remaining + 60, TEAM_SMOKE_LOCK_WAIT, 4 × TEAM_SMOKE_LOCK_WAIT)
```

- 等待者必须打印算式与三个数（`remaining`、`cap`、`TEAM_SMOKE_LOCK_WAIT`），并在超限时打印持有者的
  `kind`/`agent`/`worktree`/已跑/`expected`/`bound`。
- 没有 `expected`（旧写入者 / 记录读不到）→ 退回今天的 `TEAM_SMOKE_LOCK_WAIT`，文案仍带新字段
  （有多少打多少，缺的写 `?`，不编）。
- 不新增配置键。天花板由 `TEAM_SMOKE_LOCK_WAIT` 派生，操作者抬高它就同时抬高天花板。
- 判定 token 闭集不变：排队超限仍是 `FAIL`（不是 `TIMEOUT`），`team_review_verdict` 的解析不动。

## 6 三条红侧的设计（brief 第 3 条）

全部在 §34 / §34b 里，**只用私有锁与私有 `TMPDIR`**，绝不碰机器锁；身份清洗与既有夹具同形。

### ① 「嵌套运行持有锁」的现场 → 等待者点名它是嵌套、属于谁、已跑多久

- **造现场**：真 `flock --close -x <私有锁> sleep N` 持锁并写持有者记录（`kind=top`、`agent=dev`、
  `worktree=<夹具目录>`、`started=<T-120s>`、`expected=600`）；再在它的进程树里起一个嵌套运行登记
  （`kind=nested`、`ancestor=<持有者 pid>`、`started=<T-30s>`、`expected=300`）。
- **断言**：等待者的排队行与超限行都必须带 `kind=nested`、那个 `agent`、那个 `worktree`、`已跑 30s`
  （±容差）、`expected=300`；并且**不得**出现 `持有者未知`。
- **红侧**：去掉嵌套运行的登记 → 等待者的一行里 `kind=nested` 消失 → 该断言红并点名缺哪个字段；还原后绿。

### ② 嵌套运行超预算 → 可见处理（点名 + 释放），不许无声占着

- **造现场**：嵌套运行被武装一个 3s 期限（夹具旋钮，照 `TEAM_SMOKE_SECTION_BUDGET` 的先例），其段落永不返回；
  同时它登记在 `<lock>.runs/` 里。另一条形状：嵌套运行**持有私有锁**（EXP2 的形状，标记丢失）。
- **断言**：3s 后一行点名（段号 + id + `预算 3s` + 实际）、现场存在、进程退出码是约定的 2（安全点路径）、
  `<lock>.runs/` 里那条登记消失、**并且私有锁可被立刻取到**（`flock -n` 成功——「释放」的可观测判据）。
- **红侧**：把期限去掉（或设成无限）→ 现场无声占着 → 三条断言（点名行 / 登记消失 / 锁可再取）都红；
  还原后绿。

### ③ 正常单层运行的行为不许回退

- **既有断言一条不改**：§34 ①–⑥（排队不消耗运行预算、超限 FAIL 点名、真跑超限仍 TIMEOUT、祖先持锁不二次排队、
  没有 `flock` 的降级、排队阶段不碰 tmux）、§34b ①–⑤（超限 exit 2 并点名、排到了再跑、退出码原样透传、
  真红不被报成排队超限、旧形状 premise）。
- **新增对照**：锁空闲的顶层运行，记录 `kind=top`、排队行/`queued`/`ran` 三个数与今天逐字节同形；
  `TEAM_SMOKE_LOCK_WAIT` 不变时，一个没有 `expected` 的旧持有者仍按 1800s 判。
- **红侧**：把顶层路径也改成「不排队」→ §34 ①/② 与 §34b ①/③ 红；还原后绿。

## 7 风险与诚实边界

- **风险 1 · 进程树证明在 `--close` 与双重 fork 下要准**：`flock --close` 的持有者是 flock 进程本身，
  顶层运行是它的**子**进程。所以「祖辈持有锁」的判据要写成「持有者 pid 在我的 ppid 链上**或**是我的直接父
  （flock 形状）」，并且用 pid+starttime 防复用。夹具必须两向都钉：真祖辈 → `nested`；一个**不是**祖辈的
  活 pid → 仍然是 `top` 并排队。
- **风险 2 · `/proc` 不可用**：没有 `/proc` 时进程树走不了 → 一律按 `top` 处理（**fail closed**：宁可多排队，
  不可少串行）。这条要打印一行说明。
- **风险 3 · 记录文件的陈旧条目**：等待者按 pid+starttime 过滤并打印 `stale`；不做全局清扫
  （清扫别人的目录是 P122 的教训：一处拒绝/误判就可能删掉别人正在跑的东西）。
- **风险 4 · 段账**：新增断言会改 §34/§34b 的用时，`tests/section-budgets.tsv` 的 band 必须按实测补
  （§0e 守表：band 必须等于实测最差值、budget = `max(band×4, 60)`）。apply 必须报改前/改后各一次实测。
- **诚实边界（必须写进文档与门禁输出）**：门禁能证明的是「记录里有这几样、等待者打印了它们、嵌套运行的期限
  到点会被点名」。它**不能**证明「某个活着的席位读了那行并作出正确判断」，也**不能**证明「两个席位的嵌套运行
  一定不重叠」——残余窗口（`no_lock`）存在，本变更只让它**可观测**。任何输出不得声称已经证明了后者。
