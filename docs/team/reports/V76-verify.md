# V76 · P329 三处减法的独立验收（verify）

time: 2026-10-20T12:04Z（收尾时刻；各次运行的原始读数与耗时见下表和 `/var/tmp/v76-gate*/`）
受检：候选 `6a995d2a`（`ba3b17a8` 合并推导 → `33d83df0` 三处减法 → `2a47156d` §34b 路径声明 → `6a995d2a`
作者报告），分支 `task/P329-subtractions`，作者报告 `docs/team/reports/P329-dev-bob.md`。
形态：只读代码；所有破坏只发生在 `/var/tmp/v76-cand`（独立 `git clone` + `checkout --detach 6a995d2a`）与
`/var/tmp/v76-*` 现场目录里。worktree 只用来取 main 侧的改前读数。未改实现、未合并、未 push。

**任务书那句「该分支落后 main」成立，而且只剩这一点**：候选的 merge-base 是 `956a549e`，相对它只改了
5 个文件（两个库 + 一个 tsv + `smoke.sh` + 作者报告）；main 在其后多了 6 个 `[skip ci]` 账本提交，
所以 `git diff main 6a995d2a` 里 `docs/team/**` 的删除全部是「落后」造成的，与本次改动无关。我判的是
产品/测试面那四个文件。

## 结论

**PASS。** 三处减法减掉的东西各自找得到接管者或是有意的退场；合并后的单点是承重的；失败语义没有被合并。
两处残余不在本变更写集里，交 PM 裁定（F1/F2）。

1. **A（§58 删翻转①③）**：③ 的输入**逐字**在 `--selftest` 夹具表里（`kill_term_pid	clean	kill -TERM "$pid"`），
   判定路径也相同（`perl signal-lint.pl --root <dir> --quiet` → rc）；①（`#!/usr/bin/env bash` + `true`）
   没有逐字夹具，由 13 条 clean 夹具 + `self_clean` 按**同类**覆盖。`--selftest` 实跑 29 个夹具 + 豁免机制
   4 例全绿、rc=0；两条被删输入的**行为**我也直接跑过，都仍是 rc=0——删的是断言，不是行为。
2. **B（五条算式断言）**：剩下的那条真行为仍由 §34b⑨ 第一条钉着（本轮 ✓，把它改坏后**只有它变红**，见红侧 ②）。
   被删的五条守的是 `openspec/specs/verification/spec.md:137-140` 那段 `clamp(remaining + 60 s, W, 4W)` 的
   SHALL，而那段 SHALL **今天没有任何断言**：它的生产者在 P316（`d92f0a17`）退役，替代者是
   `gate-waiter-patience`，apply 还没派。删它们没有让任何**已修好的**事故回退（修本来就是死的），但确实删掉了
   那条约定的唯一执行证据——这是有意的、PM 已排在 P329 之后，复验时应知道这个窗口（F1）。
3. **C（合并两份推导）**：同一组命令在两棵树上跑，5 个席位解析点与两个失败语义**逐字相同**（`diff` 的
   唯一差异是我故意加的「只 source gate-lock.sh」探针，见 F4）。锁记录在席位解析不出时照旧**写成功**
   （`agent=?`、16 字段、rc=0），`team notify` 照旧**拒绝**（rc=1、收件箱零写入、文案逐字相同）。
4. **红侧（承重）**：把合并后的 `team_seat_from_paths` 改成返回 `seat-broken` → `--select 34b`
   `✓97 ✗1`，唯一红行是 `34b⑨ 反向对照：窗口名报 verify，记录里仍是 cwd 的席位（期望 [dev]，实际 [seat-broken]）`；
   复位后 `git status --porcelain` 为空、HEAD 仍是 `6a995d2a`。
5. **断言账**：报告的三组数（25→21 / 39→37 / 86→82）是**语句级**计数（含只在红路径执行的 `bad` 分支）。
   我按同一口径复算得 25→21 / 40→38 / 86→82，三组**减量**逐条对上；§34 两端各差 1，差在
   `smoke.sh:16384` 那一行（同一个检查的 `ok` 与 `bad` 写在同一行）。门禁**运行级**读数是
   §58 **13→11**、§34 **36→35**、§34b **79→75**（main 侧这一轮撞上既有不稳定断言 §34b⑫，实测
   `✓78 ✗1`、绿侧等价 79，见 F3）。

## 测试状态（全部实跑，无容器、无整套、无机器锁争用）

开跑前 `ps -eo pid,etime,args | grep smoke.sh` 无输出，`/tmp/teamsmith-smoke.lock.holder` 不存在；
五次运行**顺序**执行（不并发），每次都在结束时放锁（收尾后 `/tmp/teamsmith-smoke.lock` 在、`.holder` 不在）。开跑时 `load1` 15.24 / 32 核（前提下限 0.75×32=24）。

| # | 命令 | 树 | rc | 读数 |
|---|---|---|---|---|
| 1 | `smoke.sh --select 34,34b,58` | 候选 clone | **0** | `✓144 ✗0`；§34 `✓35`、§34b `✓75`、§58 `✓11`（另 `0/0b/0c/0d` 共 23 条，选择器带的前置段）；7/135 段；113 s |
| 2 | 同上 | **main**（worktree） | 1 | `✓150 ✗1`；§34 `✓36`、§34b `✓78 ✗1`、§58 `✓13`；427 s；唯一红 = 既有不稳定断言 §34b⑫（F3） |
| 3 | `smoke.sh --select 0e` | **main** | 1 | `✓42 ✗3`；三条红都是循环清单不同步（改前就有，PM 立的账 (a)） |
| 4 | `--select 34b`，`team_seat_from_paths` 改坏 | 候选 clone | 1 | `✓97 ✗1`；唯一红 = §34b⑨ 反向对照；复位后 `git status` 空 |
| 5 | `--select 34b`，`gate_lock_cap` 的退回分支 +1 | 候选 clone | 1 | `✓97 ✗1`；唯一红 = §34b⑨「旧持有者（没有 expected）→ 上限仍是 TEAM_SMOKE_LOCK_WAIT（期望 [1800]，实际 [1801]）」；复位后 `git status` 空 |

运行 #1（验收选集）的段尾（长标题按 `…` 截断，数值逐字；`rc` 取自批量脚本的记录）：

```console
#5 34 · 门禁锁：排队/运行分开记账（P26/G1：…） · 参考 用时 66s · ✓35 ✗0 SKIP0 · ticks 35
#6 34b · 门禁锁排队守卫：超上限要大声失败并点名持有者（P66） · 参考 用时 27s · ✓75 ✗0 SKIP0 · ticks 75
#7 58 · 信号纪律：闸门 / 作业 pid / lint（P159） · 参考 用时 14s · ✓11 ✗0 SKIP0 · ticks 11
账本自查： 7 段收口 · 增量 ✓144 ✗0 SKIP0 ｜ 结果行 ✓144 ✗0 —— 一致
== 选段结果 ==  ✓ 144  ✗ 0
# /var/tmp/v76-gate/rc.txt → cand_select rc=0 secs=113
```

## A · §58 删掉的两条内联翻转：selftest 覆盖到什么程度

删掉的是「① 干净文件不报红」与「③ `kill -TERM "$pid"` 不误报」，各是一个 `if … then ok … else bad …`。
`--selftest` 的实跑（候选树）：

```console
$ perl skills/teamsmith/tests/signal-lint.pl --selftest 2>&1 | tail -9
  ok  selftest bash_c_clean          期望净 实际净
  ok  selftest pgrep_readonly        期望净 实际净
  ok  selftest killall_readonly      期望净 实际净
  ok  selftest self_clean            期望净 实际净
  ok  selftest exempt_hash_pinned    期望净 实际净
  ok  selftest exempt_bad_count      期望红 实际红
  ok  selftest exempt_stale_hash     期望红 实际红
  ok  selftest exempt_tests_refused  期望红 实际红

✓ signal-lint --selftest：29 个夹具 + 豁免机制全部符合预期（该红的红、该净的净）
rc=0
```

- **③ 是同一输入、同一判定路径。** 夹具表里那一行逐字是
  `kill_term_pid	clean	kill -TERM "$pid"`；selftest 把它写成 `<tmp>/kill_term_pid/case.sh`，再跑
  `perl signal-lint.pl --root <该目录> --quiet` 并看 rc（`tests/signal-lint.pl:343-352`）——与删掉的那条
  （写 `$P159_SB/x.sh` 再 `--root "$P159_SB" --quiet`）是同一个入口、同一个判据，只是文件名和有无
  shebang 不同。同族的 `kill_zero_pid`、`kill_pgid`、`kill_two_pids`、`kill_cat_pidfile`、`bash_c_clean`
  一起守住「pid 精确形态不误报」这一类。
- **① 只有同类覆盖，没有逐字夹具。** 表里没有 `#!/usr/bin/env bash` + `true` 这一例；覆盖它的是 13 条
  `clean` 夹具（`comment`、`quoted_data`、`grep_argument`、`pgrep_readonly` …）加上 `self_clean`（把 lint
  自己的整份源码写成 `signal-lint-self.pl` 再扫，必须 rc=0）。我把被删的两条输入原样重放，两条仍然 rc=0：

  ```console
  $ printf '#!/usr/bin/env bash\ntrue\n' > $D/a/x.sh; perl skills/teamsmith/tests/signal-lint.pl --root $D/a --quiet; echo rc=$?
  rc=0
  $ printf '#!/usr/bin/env bash\nkill -TERM "$pid"\n' > $D/c/x.sh; perl skills/teamsmith/tests/signal-lint.pl --root $D/c --quiet; echo rc=$?
  rc=0
  ```

- **留下的那条分工是真的**：§58 仍断言 `pkill -f` 被判红且**按 `file:line` 点名**
  （`p159-lint-flip/x.sh:2`），而 selftest 只判红/净、不判位置——`signal-lint.pl` 在整棵树里只有 §58 一个
  消费者（`grep -rn 'signal-lint\.pl' … --include='*.sh'` 只命中 `smoke.sh:22183`），所以这条位置判据没有第二处。

**判定：A 成立。** ③ 是等价替换；① 降到「同类覆盖」，代价可接受——lint 的净/红两个方向由 29 条夹具钉住，
而「任意干净文件」这一格今天没有逐字证据（F5）。

## B · 五条算式断言：逐条说明它守什么、今天谁守

规范里那段 SHALL 仍在生效（`openspec/specs/verification/spec.md:137-142`）：

> When the holder record publishes the run's expected upper bound, the queue cap SHALL be judged against the
> holder's expected remaining time … `clamp(remaining + 60 s, TEAM_SMOKE_LOCK_WAIT, 4 × TEAM_SMOKE_LOCK_WAIT)`,
> where `remaining = expected − (now − started)`, and it SHALL print that arithmetic together with the three
> numbers. When the record publishes no bound (an older writer, or an unreadable record) the cap SHALL remain
> `TEAM_SMOKE_LOCK_WAIT` exactly as before.

| 删掉的断言 | 它守的是什么 | 事故/来源 | 今天谁守 |
|---|---|---|---|
| §34⑦ `cap = clamp(remaining+60, W, 4W)，同一 remaining 算出来的` | 真实排队现场里的上限公式（`expected` 投影） | P281 的 Why：一次合法长跑持锁 **1 h 16 min**，别的席位排队 19.5 min（PM 停掉）与 1 h 20 min，而等待者上限固定 1800 s | **无断言**。规范原文在；接管者 `gate-waiter-patience`（proposal「删掉 `expected` 在 cap 里的分支」）未派 apply |
| §34b⑨ `cap = clamp(…)（remaining=… → 期望 …）` | 同上，纯函数腿（`gate_lock_cap`） | 同上 | 同上 |
| §34b⑨ `remaining 由记录里的 started 算出（落点 ∈ [lo,hi]）` | `remaining` 的输入是**记录里的 `started`**，不是进程启动时刻、不是 now | 这条自己是 P281 返修 F3 的产物：旧写法建在「1 秒宽窗口」上，候选树 3 跑 2 红（`reviews/P281.md`） | **无断言**；`gate_lock_cap` 仍这么算（产品代码未动）。`gate-waiter-patience` 1.1 会整段删掉它 |
| §34b⑨ `W 抬到 1000 → cap 落回下限（1000）` | `clamp` 的**下限**（`expected` 小的时候不把上限压到 W 以下） | P281 的公式设计本身 | **无断言**；且 `gate-waiter-patience/tasks.md:82` 仍把它写成「留用的两条」之一（F2） |
| §34b⑨ `W 只有 10 → cap 落回上限 4×W（40）` | `clamp` 的**上限**（耐心有界，不会无限等） | 同上（4W 硬顶） | **无断言**；同上 |
| §34⑦ 的 `bad "队列行没打印算式里的 remaining/cap"` | 排队行必须把**算式与三个数**打印出来（规范原话 "print that arithmetic together with the three numbers"） | 同第一行 | **部分**：§34⑦ 仍断言排队行打印 `TEAM_SMOKE_LOCK_WAIT=200s`（下限），`remaining=`/`cap=` 不再判 |

**「读不到 expected → 退回 W」仍由 §34b⑨ 第一条钉着**（候选树 `smoke.sh:16739`）：

```console
assert_eq "34b⑨ 旧持有者（没有 expected）→ 上限仍是 TEAM_SMOKE_LOCK_WAIT" \
  "$(gate_lock_cap "$P281_LOCK" 1800 | cut -f1)" "1800"
```

它在 #1 那次运行里是 ✓；我把它改坏（读不到 `expected` 时 `wait + 1`）后 `--select 34b` 只有这一条变红，
期望与实测都打了出来（红侧 ②）。所以「退回 W」这一格**是承重的**，而不是「算式删了也没人管」。

**历史里的三条记录（P288 / P310 / P316）没有一条守的是这五条**：P288 是锁被外部删除的症状、
P310 是门禁回归的两处修复、P316 是把预算表整表退役（`expected` 从此没有生产者、
`gate_lock_expected smoke.sh /dev/null` → `0 121500 135`）。也就是说：这五条守的那条约定在 P316 之后
就已经**不再跑起来**，P329 删的是「一个不存在的数」的执行证据，不是一条活着的事故的护栏。

## C · 席位＝运行时目录：失败语义有没有被合并

现场脚本 `/var/tmp/v76-scene.sh <树根> <现场目录> <会话名>`：init 一个真项目 → 建 `.worktrees/dev2` 与一棵
**项目外**的工作树 → 逐点问席位 → 写锁记录 → 从项目外那棵工作树跑真 `team notify`。两棵树各跑一次，
输出 `diff`（`/var/tmp/v76-before.out` vs `/var/tmp/v76-after.out`；`<S>` 是现场目录占位）：

```console
seat_worktree=dev2      seat_worktree_sub=dev2      seat_main=pm
seat_outside=?          seat_nongit=?
c1_write_rc=0           c1_record_exists=yes        c1_record_agent=?
c1_record_kind=top      c1_record_fields=16
c2_notify_rc=1          c2_inbox_unchanged=yes      c2_inbox_lines=0   c2_outbox=0
✗ notify：发送者无法解析 —— 运行时目录（<S>/outside）不在本项目的工作树里（主工作树，或 <S>/repo/.worktrees/<名字>）
  发送者按运行时目录解析，绝不用收件人冒充；这里没有任何东西被写入。
  从别处调用请显式声明发送者：team notify <收件人> --from <你的名字> --from-file <摘要文件>
```

- **两条语义各自保留**：席位解析不出时，锁记录**写成功**且 `agent=?`（16 个字段、`kind=top`）；同一条
  `team notify` 拒绝、rc=1、收件箱逐字节不变、outbox 零条目。两棵树这 12 行逐字相同。
- **失败语义没有被合并**：锁记录那一侧 `?`（诊断证据必须写成功），notify 那一侧空 + 调用方拒绝
  （`team_sender_resolve`）。代码里也是两个收尾点（`gate-lock.sh` 的 `[ -n "$n" ] || printf '?…'`、
  `common.sh` 的 `team_sender_resolve` 直接返回 1）。
- **唯一的行为差异在解析成功的一侧**（F4）：`.worktrees` 是**软链**时，改前 gate-lock 给 `?`、notify 给席位名
  （两份实现在这里本来就不一致），合并后两边都给席位名：

  ```console
  # 现场：repo/wts/dev 是一棵工作树，repo/.worktrees -> wts（软链）；同一条调用各跑一次
  $ ( cd "$R/wts/dev" && bash -c '. <树>/skills/teamsmith/scripts/lib/common.sh; . <树>/skills/teamsmith/scripts/lib/gate-lock.sh; gate_lock_seat_of_dir "$PWD" "dev dev2"' )
  main 树    -> ?
  候选树     -> dev
  ```

  方向与头注写的「与 team notify 同一条规则」一致，但它确实是**去重之外**的一处行为改动，两棵树里都没有
  断言覆盖它。

## 红侧（承重证明）

**① 合并后的单点（本次要求的那条）**：在私有 clone 里把 `team_seat_from_paths` 的兜底改成返回
`seat-broken`，`--select 34b`：

```console
$ git -C /var/tmp/v76-cand status --porcelain   # 改前：空
$ bash skills/teamsmith/tests/smoke.sh --select 34b > /var/tmp/v76-gate/cand_red_seat.log 2>&1; echo rc=$?
rc=1
$ grep '✗ 34b' /var/tmp/v76-gate/cand_red_seat.log
  ✗ 34b⑨ 反向对照：窗口名报 verify，记录里仍是 cwd 的席位（期望 [dev]，实际 [seat-broken]）
$ grep '选段结果' /var/tmp/v76-gate/cand_red_seat.log
== 选段结果 ==  ✓ 97  ✗ 1
$ git -C /var/tmp/v76-cand checkout -- skills/teamsmith/scripts/lib/common.sh
$ git -C /var/tmp/v76-cand status --porcelain; git -C /var/tmp/v76-cand rev-parse --short HEAD
（空）6a995d2a
```

这一处破坏只让**一条**断言变红，因为同一个函数里名册匹配那条分支提前返回、我改的是兜底分支：
`34b⑨ 同一推导…（dev）` 传了名册 `verify dev`，走的是没被改坏的那条。要点仍然成立——被删掉的两份推导里，
`gate_lock_seat_of_dir` 这一侧的**值**现在由共享函数决定，改坏它，§34b⑨ 立刻点名。

**② B 的接管者（「读不到 expected → 退回 W」）**：把 `gate_lock_cap` 的退回分支从 `$wait` 改成
`$(( wait + 1 ))`，`--select 34b`：

```console
$ grep '✗ 34b' /var/tmp/v76-gate2/red_w.log
  ✗ 34b⑨ 旧持有者（没有 expected）→ 上限仍是 TEAM_SMOKE_LOCK_WAIT（期望 [1800]，实际 [1801]）
== 选段结果 ==  ✓ 97  ✗ 1
$ git -C /var/tmp/v76-cand status --porcelain   # 复位后：空
```

## 断言账

**语句级**（`§` 段体内 `assert_*` + `ok`/`bad` 的词数；含只在红路径执行的 `bad`，用同一口径复算）：

| 段 | main | 候选 | 差 | 报告写的是 | 对上？ |
|---|---|---|---|---|---|
| §58 | 25 | 21 | −4（两对 `ok`/`bad`） | 25→21 | ✓ |
| §34 | 40 | 38 | −2（`assert_eq` + 它的 `else bad`） | 39→37 | 减量 ✓；两端各 −1（计数口径：`smoke.sh:16384` 的 `&& ok … \|\| { bad …; }` 算 1 条检查） |
| §34b | 86 | 82 | −4（四条算式 `assert_eq`；三条旧席位断言换成四条新的，净 0） | 86→82 | ✓ |

**运行级**（门禁自己打印的段落增量，绿跑）：§58 **13→11**、§34 **36→35**、§34b **79→75**。main 侧合计是
`3+2+9+9+36+79+13 = 151`，候选是 `144`，差 7 = §34 −1、§34b −4、§58 −2；main 的**原始**读数是 `✓150 ✗1`
（那 1 条 ✗ 是既有不稳定断言，见 F3）。两个口径的差来自 3 条只写在红路径上的 `bad` 分支。
报告里「`--select 34,34b,58` ✓144，§34 ✓35、§34b ✓75、§58 ✓11」自洽：选择器同时跑前置段
`0/0b/0c/0d`（3+2+9+9=23），23+121=144。

## PM 立的两处账

- **(a) §0e 的 3 条红是改前就有的 —— 确认成立。** 在**未改动的 main**（worktree，`b005f69c`，`git status` 空）
  上跑 `--select 0e`：`✓42 ✗3`、rc=1，三条红全在循环清单上：

  ```console
    ✗ P70 循环清单：干净树绿（85 行清单 / 85 个 while+sleep 循环，配平 85 个）（期望 [0]，实际 [1]）
    ✗ P70 翻转（循环）还原：绿（期望 [0]，实际 [1]）
    ✗ P313 翻转（盲区）还原：绿（期望 [0]，实际 [1]）
  ```

  与作者报告「§0e 改前就有 3 条红」逐条对得上；候选树上那 3 条也不会因为这次删了 `smoke.sh` 的行而变。
- **(b) `openspec` 不在 PATH —— 确认成立。** 当前 shell 与登录 shell 都查不到；真实入口是包内软链：

  ```console
  $ command -v openspec ; echo rc=$?
  （空）rc=1
  $ bash -lc 'command -v openspec'; echo rc=$?
  （空）rc=1
  $ ls -l "$HOME/.bun/bin/openspec"
  lrwxrwxrwx … $HOME/.bun/bin/openspec -> ../install/global/node_modules/@fission-ai/openspec/bin/openspec.js
  $ "$HOME/.bun/bin/openspec" --version
  1.8.0
  $ "$HOME/.bun/bin/openspec" validate --all --strict | tail -1
  Totals: 21 passed, 0 failed (21 items)     # rc=0
  ```

  即：验收命令第 2 条按全路径跑，21/0；按裸名字跑得到的是 `command not found`，不是判定的红。

## 静态收口（实跑）

```console
$ for f in skills/teamsmith/scripts/lib/common.sh skills/teamsmith/scripts/lib/gate-lock.sh skills/teamsmith/tests/smoke.sh; do bash -n "$f" && echo "ok  $f"; done
ok  skills/teamsmith/scripts/lib/common.sh
ok  skills/teamsmith/scripts/lib/gate-lock.sh
ok  skills/teamsmith/tests/smoke.sh
$ bash skills/teamsmith/tests/section-select.sh --check | tail -1
== 选段自检 ==  ok 9  bad 0  SKIP 1        # rc=0；SKIP 是 `.pi/skills` 这条机器生成面不在检出里
$ git diff --check main 6a995d2a
（无输出）rc=0
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt" | tail -1
ledger-ban: names：名单已配置（…/.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=<home>/…/.worktrees/verify scope=published files=1908 hits=0 names=ok user=resolved   # rc=0（本报告写完后的最后一次扫描）
```

## 发现（每条说明它改变了什么）

1. **F1 · 规范 137-140 那段 SHALL 在今天没有执行证据。** 依据：规范原文仍在；`gate_lock_expected` 的
   生产者已由 P316 退役；候选删掉了唯一判它的五条断言；`openspec validate --all --strict` 21/0 不看覆盖，
   所以门禁不会替这件事发声。**改变**：P329 可以合，但它的落地记录应写明「这一条由 `gate-waiter-patience`
   接管，apply 未派」——否则下一个读规范的人会以为它被 §34b⑨ 覆盖着。接管者的名字、分支表与边界
   断言已经写在那个 change 的 `tasks.md` §3 里。
2. **F2 · `gate-waiter-patience/tasks.md:82` 的「两条留用的」现在是假的。** 它把
   `W=1000/10` 的上下限写成 P329 之后仍然存在的两条、准备「改成纯函数腿」；P329 把它们删了。同一份
   `tasks.md` 的分支表仍要求 `W=1000→4000`、`W=10→40` 两腿，所以**覆盖义务没丢，丢的是任务书的措辞**。
   **改变**：PM 在派 apply 之前改那一行（改成「新增两条纯函数腿」），否则实施者会去找两条不存在的断言。
3. **F3 · §34b⑫「登记随它退出消失」的既有不稳定断言，我在**未改动的 main** 上独立撞到了。**
   证据：同一台机器、相隔 5 分钟，候选 `--select 34,34b,58` 里 §34b `✓75 ✗0`（27 s），而 main 的同一段
   `✓78 ✗1`、耗时 342 s，红行是
   `✗ 34b⑫ 收尾：登记随它退出消失（只删自己那条）（期望 [1]，实际 [0]）`——它是那段 300 s 轮询跑满后的
   收尾断言。这与作者报告的发现 6 是同一件事，历史记录也一致：`reports/P288-dev-bob.md:411`、
   `reports/P313-dev3.md:240`、`reports/P316-dev.md:137`（「同一棵树、没改它」）、`reviews/V53.md:216`
   都记过同一行。
   **改变**：main 侧的 §34b 读数要按「绿侧等价 79」读（F3 不是 P329 的），而这条例外值得它自己的任务
   （作者的「请 PM 立单或并入 `gate-waiter-patience`」成立）。
4. **F4 · 合并顺带改了一处 gate-lock 的行为（软链 `.worktrees`）。** 改前 gate-lock 不规范化 worktrees 前缀
   （`?`），notify 规范化（席位名）；合并后两边都规范化。证据是上面 C 节的软链探针（main `?` / 候选 `dev`）。
   方向与头注一致，也不算坏——但它是**去重之外**的行为变化，两棵树的断言都没有覆盖它。**改变**：如果 PM
   希望「合并=等价」这句话严格成立，应把它写进合并记录；要守它则需要一条新断言（本次不新增，见 F5 的理由）。
5. **F5 · §58 的「干净文件不报红」从逐字证据降到同类证据。** 删掉的 ① 用的输入（`#!/usr/bin/env bash` +
   `true`）在夹具表里没有对应行，覆盖它的是 13 条 `clean` 夹具 + `self_clean`。**改变**：这是本条减法的
   真实代价，接受与否属于 PM 的判断；若要补，最小代价是在 `tests/fixtures/signal-lint-cases.txt` 加一行
   `script_true	clean	true`（数据文件，不是新守卫），但 P329 的写集里没有它，我没有替它加。
6. **F6 · 报告 §34 的基数差 1。** 39 对 40：`smoke.sh:16384` 把 `ok` 与 `bad` 写在同一个检查的同一行。
   **改变**：只影响绝对基数，三组减量都复算对得上，不值得再改报告。

## 边界

- 只读代码；破坏只在 `/var/tmp/v76-cand` 与 `/var/tmp/v76-*`；worktree 只用于 main 侧读数，未改实现，
  未合并，未 push。任务书与作者报告未改。
- 没跑整套门禁、没跑容器、没抢机器级门禁锁（五次运行顺序执行，开跑前后都确认没有别人的 `smoke.sh`）。
- `openspec` 一律用 `$HOME/.bun/bin/openspec` 全路径跑。
