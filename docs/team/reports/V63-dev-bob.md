# V63 · 性能精简返修（P316 删掉「需要安静机器才能过」的测试）的第二轮独立定点复检

agent: dev-bob · category: verify · phase: verify · 时间：2026-10-19
branch: `task/V63-performance-reference-recheck`（local 模式，不推送）
受检：`b025fbdf`（源码提交 `03e0c5ba`，tip 只多一份报告）；只看 `d73ca771..b025fbdf` 的返修差异
运行环境：私有 clone，三棵独立树 —— `cand`（交付树）、`mut`（唯一反例）、`base`（返修前 `d73ca771` 对照），
全部放在磁盘 `/var/tmp/v63-dev-bob-retest/` 下，`TMPDIR` 也指到这里（未落到 tmpfs `/tmp`）。
没有在交付树、他人 clone 或主工作树里写任何字节。

## 结论

**PARTIAL。**

五问里第 1、2、3、5 问成立，第 4 问（宽限旋钮覆盖）**不成立**：按 PM 指出的混淆做的唯一反例 —— 在私有 clone 把
实现里的宽限固定成 2（`grace="${TEAM_BG_STOP_GRACE:-5}"` → `grace=2`）—— 复用现有 `promises` 入口后
**两条宽限断言仍然全绿**，`routes.sh promises` 的结果与干净树同名同数（`✓ 18 ✗ 1`，那 1 条是与本返修无关的
`TEAM_PULSE_WINDOW` 旧红）。也就是说：这两腿覆盖的是账本里 `signal=TERM` 与 `signal=TERM,KILL` 两种效果，**不是**
旋钮对它们的影响 —— 同一个反例已经说明，连「配置里写 0 就不等待」这一步也不能由这两腿证明。任务书要求准确
区分的正是这两件事，因此这一问按字面判为未成立；其它取值我没有测，不在这里推断。

另外两处缺口（都不阻塞第 1、3 问的成立结论；去向见第四节，本报告不实现）：
- `key-replies` 的限时取锁断言把子进程的文件描述符字面量 `3` 也钉进了契约（`-w 2 3`），这与产品承诺无关；
- `section-guard` 的进度基线（`last_ticks`/`last_moved`）没有按「段」归属，跨段时可能继承上一段的基线。

作者报告里的自检总数 `✓65` 与实现不符：我这棵树上的断言位点合计 64，两次实跑都是 `✓ 64 ✗ 0`。

## 一 · 五问逐条

### 1. 持续进度不会被总耗时停跑，原有的无进度/失控/退出与现场行为仍在（成立）

判据改成「cap 秒内 ticks 没变」而不是「武装后过了多久」，并且进度证据复用了心跳里本来就有的 ticks：

```
$ sed -n '408,440p' skills/teamsmith/tests/lib/section-guard.sh      # 私有 clone b025fbdf
    [ -z "$last_ticks" ] && { last_ticks="$ticks"; last_moved=$now; }   # 第一次看到这段：从现在起算
    if [ "$ticks" != "$last_ticks" ]; then last_ticks="$ticks"; last_moved=$now; fi
    # ……（中间是进度自述与 SG_PROGRESS_INTERVAL 归一化，逐字见该文件 408–440 行）
    if [ "$(( now - last_moved ))" -ge "$cap" ]; then
      _sg_trip "$no" "$id" "$armed" "$cap" "$ticks" "$(( now - last_moved ))" "$now"
```

没有新增看门狗、没有新增进度协议、没有新增长期夹具：还是同一个 `section_guard_watchdog` 循环与同一份心跳，
`progressing` 形状走的是 `section_guard_check`（`ok()`/等待轮每次都会调的真实路径）。

实跑（`bash skills/teamsmith/tests/lib/section-guard.sh --self-test`，跑了两遍，两遍一致）：

```
== 结果 ==  ✓ 64  ✗ 0
section-guard 自检全绿
```

其中与本问直接相关的形状：

```
✓ progressing：套件 exit 0                      # 40 轮 × 0.1s ≈ 4.2s，总时长是 cap（2s）的两倍，仍在 tick
✓ progressing：干净路径没有现场
✓ progressing：裸 wait 没被看门狗卡住
✓ progressing：看门狗随套件退场（pidfile 已收）
✓ stuck：套件 exit 2（trip 路径）               # 四个卡死形状照旧停跑、点名、留现场
✓ deadspin：套件 exit 137（非零，KILL 路径）     # 忽略 TERM 的自旋走 KILL
✓ stuck：现场活过了 run 临时根被删（清理带不走）
✓ P313①：父进程被 KILL 后心跳自己退了（≤3s）     # 心跳/孤儿/F1 夹具与红侧都在
```

计数核对：日志里逐块是 clean 4 + progressing 4 + stuck/stubborn/spin/deadspin 各 8 + P313①—④ 9 +
现场尾巴 2 + 进程组 1 + F1 夹具 4 + F1 红侧 2 + P313 f3/f4/f5 红侧 6 = **64**，与实现里的固定断言位点一致；
`docs/team/reviews/P316.md` 记录的返修前自检是 60，本次只多出 `progressing` 这一个形状的 4 条 —— 64 是可复算的。作者报告的 65 在这个
树上找不到对应断言（没有哪一块少一条），我没有把它当成行为差异，但它作为「已成立」的数字依据不成立。

一处边界（读码可得，未造夹具验证）：进度基线没有按段重置。`no`/`id` 从心跳里读出来了，却没有和上一段比较；
`last_ticks` 只在 tick 值**不同**时刷新 `last_moved`。若一段收口时 `ticks=0`（或在两次轮询之间换段），而下一段
在第一次被轮询时也恰好是同一个值，基线就沿用上一段最后一次 tick 的时刻，cap 窗口会从上一段开始算起 ——
后果是**提前**停跑（真实停顿还没满 cap），不会漏停。要触发需要跨段 tick 值恰好相等且中间没有一次轮询落在变化上，
概率很低；最小改法是在 `no`/`id` 变化时重置 `last_ticks`/`last_moved`。

### 2. 三处首帧等待统一了调用视界与含义，性能读数仍不作正确性失败（成立）

V61 点名的三处（120x29 / CI=1 / tick）之外，60x8 那处也写着同一个 300s 却仍传 20；返修把**四处**都换了：
（现树 12067 / 12081 / 12156 / 12180）现在都传同一个视界，失败文案也不再把它说成「慢」：

```
$ grep -n 'P10_POLL_SECS=' skills/teamsmith/tests/smoke.sh
12022:  P10_POLL_SECS="${TEAM_SMOKE_PANEL_POLL_SECS:-300}"
12023:  case "$P10_POLL_SECS" in ''|*[!0-9]*) P10_POLL_SECS=300 ;; esac
$ grep -n 'p10_wait_pane ' skills/teamsmith/tests/smoke.sh
12067:  if P10_CAP="$(p10_wait_pane "$P10_SCOPE:$P10_W1" '巡检' "$P10_POLL_SECS")"
12081:  if P10_CI_CAP="$(p10_wait_pane "$P10_CI_SESS:panel" 'teamsmith pulse' "$P10_POLL_SECS")"
12119:  if p10_wait_pane "$P10_SCOPE:$P10_W1" 'M20-NEVER-APPEARS' 1    # 负例控制：证明轮询不是永远绿
12130:  if p10_wait_pane "$P10_SCOPE:$P10_W1" 'Enter 进入待命'          # 省略第三参数 = 同一个默认视界
12156:  if P10_TINY="$(p10_wait_pane "$P10_W2:panel" 'teamsmith' "$P10_POLL_SECS")"
12180:  if P10_TICK_LIVE="$(p10_wait_pane "$P10_W3:panel" '巡检' "$P10_POLL_SECS")"
$ sed -n '12043p;12070p;12084p' skills/teamsmith/tests/smoke.sh
  p10_wait_title() { # <pane> <needle> [秒] …      # 默认同样是 $P10_POLL_SECS
    bad "26-m 真 pane：没等到标题带渲染（上限 ${P10_POLL_SECS}s；这是状态没出现，不是帧慢）"
    bad "26-m CI=1：没等到面板标题渲染（上限 ${P10_POLL_SECS}s；这是状态没出现，不是帧慢）"
```

成功文案也统一成「有界轮询 ≤${P10_POLL_SECS}s，实际 Nms」，没有再写死 20。`12119` 传的 `1` 是负例控制
（一个永远不会出现的 needle 必须在 1s 内超时），不是首帧判据；`12130` 省略第三参数，走同一默认值。
视界仍然是 300s 的有界等待、到点仍是红 —— 这正是 PM 保留的「必要的有界状态观察」，被去掉的是「把没等到
说成帧慢」这个归因，`gate-guard.sh` ① 的措辞也相应收窄成它真正检查的一种写法（见第 5 条）。

26-m 需要真 tmux 与面板渲染，我没有跑（任务书只允许三个入口），这一条是读码结论；没有跑过的部分是
「这三处等待在真实 pane 上的行为」，不是「代码里还有别的视界」——后者已用上面的全量 grep 覆盖。

遗留的呈现小瑕疵（改一行即可，不涉及行为）：`smoke.sh:12019-12021` 的注释仍写「预算 10s 的来历……10s ≈
最坏观测的 2.4 倍」，而代码默认是 300。main 的默认是 10，P316 第一轮把它抬到 300 时没有改这段注释，返修轮
紧接着改了这几行也没顺手修掉。

### 3. 限时取锁：用真实锁竞争 + 外部 flock 限时协议守住（成立；一处应收窄）

实跑 `bash skills/teamsmith/tests/key-replies.sh --select receipts`：`✓19 ✗0 SKIP0`，rc=0。与本问相关的断言：

```
✓ receipts：锁竞争 → rc5（=5）                       # 真锁：另一个活 publisher 持锁
✓ receipts：竞争失败没有发布（=1）
✓ receipts：锁被占时 show 照常（=0） / list 照常（=0）
✓ receipts：限时 flock 报到界了（忙） → rc5（=5）      # flock 桩：记 argv 后以 1 退出
✓ receipts：传给 flock 的是产品自己的界（-w 2 3）
✓ receipts：忙时的诊断报出同一个界（2000ms）
✓ receipts：限时 flock 放弃时同样没有发布（=1）
✓ 隔离守卫：真实仓库 … 的 inbox/state 前后逐字节不变
```

spec 的承诺是「writer-lock contention SHALL return 5 after at most 2000 ms of lock waiting」
（`openspec/specs/key-replies/spec.md:37`），产品用 `scripts/replies.mjs:53` 的 `LOCK_WAIT_SEC = 2` 实现。
返修没有恢复墙钟区间（那正是被裁掉的机器速度判据），而是把承诺的两半分开守：**行为**那半（返回 5、没有发布、
list/show 不受影响）用真实竞争守；**上界**那半用「交给限时 flock 的参数 + 诊断里的 2000ms」守。在不允许墙钟
断言的前提下，这是能守的部分，我认为**按性质足够**。

但断言写的是完整的 argv `-w 2 3`，其中的 `3` 是子进程重映射后的 fd 号（`spawnSync(..., stdio:[…, lockFd])`
的第四项），不是任何产品承诺。任何保持行为、换机制的改动（换 fd、换成 JS 的锁实现、`flock` 用别的 fd 号、
改成进程内等待）都会让这条断言变红 —— 这是把实现细节变成契约，没有必要。最小改法：只断言界（`-w 2`，或
`-w 2[[:space:]]+[0-9]+`），诊断那条不动；改 `LOCK_WAIT_SEC` 时照样会红。另需知道：桩只能观察 argv，所以
「产品用外部 `flock` 取限时锁」这个机制本身也被这条夹具默认了；要摆脱它只能回到墙钟断言，而那已被裁定排除。

### 4. 宽限旋钮覆盖没有真的恢复（不成立）

返修前两腿断言的是同一个可观察量（死代码，旋钮怎么改都不红）；返修把 `mr_promise_bg_stop_grace` 加进
`mr_walk_b` 的显式调用，这是对的方向，但两腿**同时**改变了旋钮与作业：① 旋钮 0 + 忽略 TERM 的作业，② 旋钮 2 +
响应 TERM 的作业。于是「宽限 0 会立刻升级」与「宽限 2 会等」都由作业差异解释，产物自己反而没有机会表态。

唯一反例（私有 clone `mut`，只改一行）：

```
$ git diff --numstat
1	1	skills/teamsmith/scripts/lib/cmd-bg.sh
$ git diff -U1 -- skills/teamsmith/scripts/lib/cmd-bg.sh | tail -4
-  grace="${TEAM_BG_STOP_GRACE:-5}"
+  grace=2   # V63 counterexample: knob ignored, implementation fixed at 2
$ sha256sum skills/teamsmith/scripts/lib/cmd-bg.sh
e17217d2…（干净树同一文件是 ca5d68e7…，也是作者报告里记录的那个还原值）
$ TEAM_ROUTES_FAST=1 bash skills/teamsmith/tests/routes.sh promises
✓ promise（TEAM_BG_STOP_GRACE）：宽限 0 → 忽略 TERM 的作业被立刻 KILL（账本 signal=TERM,KILL）
✓ promise（TEAM_BG_STOP_GRACE）：宽限 2 → 响应 TERM 的作业在窗口内自己退出（账本 signal=TERM，没有升级）
== 结果 ==  ✓ 18  ✗ 1  SKIP 0
$ grep -c 'grace=2' skills/teamsmith/scripts/lib/cmd-bg.sh
1
```

结果与干净树（同一条命令，同一棵树只差这一行）**同名同数**：`✓ 18 ✗ 1`，那 1 条是 `TEAM_PULSE_WINDOW`
（见下）。所以：

- 实测事实只有一条：**配置 0 + 忽略 TERM 的作业，在实现固定成 2 时仍然得到 `signal=TERM,KILL`，腿①照样绿**。
  所以腿①区分不了「实现读到了配置里的 0」与「实现固定成了 2」，这个可观察量与配置值无关（就这两组取值而言）；
- 作者记录的 F-B（实现固定成 0 → 腿②红）说明腿②能看见「实现完全不等待」；那是对实现的证据，不是配置被读取的
  证据，我未重跑它；
- 这两腿真正钉住的是两种账本效果：`signal=TERM`（作业响应 TERM 后自己退）与 `signal=TERM,KILL`（升级）。
  其它取值（例如默认 5）没有测，我不据这一个反例外推。

PM 问的机器速度前提，一并核过：

- 新增作业的自然寿命是 4s（`while [ "$i" -lt 40 ] … sleep 0.1`），夹具先 `sleep 0.3`，再起 `bg stop`。所以
  「TERM 到达时作业还活着」要求一次 `team` CLI 启动 < 3.7s。本机实测 `team bg list`（清掉继承身份、无 config
  的下限口径）是 `0.08s / 0.08s / 0.08s`，另一次走身份拒绝路径的启动是 `0.15–0.16s`，余量约 20 倍 ——
  当下不会误伤，但这确实是一条隐含的机器速度前提：若某台机器一次 CLI 启动超过 3.7s，腿②会以
  「账本没有记下 TERM 之后它自己退了」的形式假红，而不是露出「机器太慢」。
- 腿②要求响应 TERM 的作业在 2s 内死掉（产品的宽限窗口本身），这是产品语义，不是基准性能；实测 0.1s 粒度
  的作业在这台机器上远早于此。这一条我按裁定当契约看，不提出改动。
- 小瑕疵：新作业的记录里写 `cmd=sleep 300`，真实命令是 bash 循环。身份判定不读 `cmd`，所以不影响结论，
  但夹具记录里留了一个不真的字段。

### 5. 参考汇总表、自指检查、产品源码（成立）

汇总表的两处修复我按真实格式样本验证（任务书允许不重跑性能，我没有跑 `perf.sh`）：

```
$ sed -n '301p' skills/teamsmith/tests/panel-cpu.sh
printf '· 参考 首帧：%s（3 次独立 spawn 的中位）｜ 窗格 CPU：%s%%（三等分中位）｜ 树 CPU：%s%%（%s）\n' …   # 参数略
$ sample='  · 参考 首帧：5246ms（3 次独立 spawn 的中位）｜ 窗格 CPU：0.50%（三等分中位）｜ 树 CPU：0.33%（6s）'
$ sed -n 's/^.*· 参考 首帧：\([0-9][0-9.]*\)ms（3 次独立 spawn.*$/\1/p' <<<"$sample"     # → 5246
$ sed -n 's/^.*窗格 CPU：\([0-9][0-9.]*\)%（三等分中位）.*$/\1/p' <<<"$sample"           # → 0.50
$ printf '  ① 交互首帧               | %-12s | %s\n' "${J_FIRST_MEDIAN:+${J_FIRST_MEDIAN}ms}" "3 次独立 spawn 的中位（上面逐次读数）"
$ printf '  ③ 稳态窗格 CPU           | %-12s | %s\n' "${J_CPU_MEDIAN:+${J_CPU_MEDIAN}%}" "三等分中位（上面三等分读数）"
  ① 交互首帧               | 5246ms       | 3 次独立 spawn 的中位（上面逐次读数）
  ③ 稳态窗格 CPU           | 0.50%        | 三等分中位（上面三等分读数）
```

旧实现是单引号里又双写了反斜杠（`\\(` / `\\1`），模式永远匹配不到；现在是单反斜杠，捕获组只取数字，单位由
表格那一列补一次 —— `4065msms` 那一类不会再有。`set -uo pipefail` 的重复行也删了。
一个剩余的小口子：`never` 时（`首帧：never（3 次…`）数字模式匹配不到，表格中位格留空、说明列仍写
「3 次独立 spawn 的中位」；上面 panel-cpu 的原始行还在，所以不算误导，但汇总表分不清「没出现」与「没测到」。

自指/措辞检查确实删掉或收窄了（`gate-guard.sh` 现存三向，纯逻辑、不起进程）：

```
$ sed -n '7,20p' skills/teamsmith/tests/gate-guard.sh
#   ① 门禁面（smoke.sh + tests/lib/*.sh）里没有**这一种**墙钟判据……
#      —— 参数形态（例如等待函数第 N 个参数是秒数）它看不见，那要靠调用点的单点实验。
#   ② 门禁不点名测量夹具……
#   ③ 两个参考打印器没有**判定型退出码**（exit 2 / exit 4）……
# 已删除（P316 返修 · V61 裁定）：原来的 ④「门禁真的调用本守卫」是自指检查……以及 ③ 里「必须带 `· 参考` 标记」那一半
```

`smoke.sh` §0e④ 的翻转②也随之从「丢掉 `· 参考` 标记」改成行为面（给参考打印器追加一个 `exit 2`，守卫必须红，
且点名「判定型退出码」）；§35 的 ok 措辞同步收窄。`bash skills/teamsmith/tests/section-guard.sh --loop-check`
（返修重排过 `loop-inventory.tsv` 的行号，这条必须仍然配平）：

```
ok: 扫描 89 行清单 / 89 个 while+sleep 循环，配平 89 个

section-guard --loop-check: 全过
rc=0
```

产品源码未改：分支自己的差异里，测试面之外只有作者报告这一个路径。

```
$ git diff --name-only $(git merge-base main b025fbdf)..b025fbdf | grep -v '^skills/teamsmith/tests/'
docs/team/reports/P316-dev.md
$ git diff --stat 03e0c5ba..b025fbdf          # tip 只加报告
 docs/team/reports/P316-dev.md | 55 +++++++++++++++++++++++++++++++++++++++++++++++++++++++
 1 file changed, 55 insertions(+)
$ git diff --name-only d73ca771..b025fbdf     # 返修轮触及的 8 个测试文件 + 报告
docs/team/reports/P316-dev.md
skills/teamsmith/tests/gate-guard.sh
skills/teamsmith/tests/key-replies.sh
skills/teamsmith/tests/lib/section-guard.sh
skills/teamsmith/tests/loop-inventory.tsv
skills/teamsmith/tests/panel-cpu.sh
skills/teamsmith/tests/perf.sh
skills/teamsmith/tests/routes.sh
skills/teamsmith/tests/smoke.sh
```

`skills/teamsmith/scripts/**`、`references/**`、`SKILL.md`、`openspec/**`、`.github/**` 都不在差异里；P320/V62
的修复与标签没有进入这棵树，也没有合并、推送或移动标签。

## 二 · 实跑记录（三个入口 + 对照 + 反例）

全部在私有 clone 里跑，`TMPDIR` 指向同一块磁盘目录；运行前后 `git status --porcelain -uall` 都是 0 条路径变化
（交付树没有被测试写脏）。跑这一组的起止负载是 `6.32 7.07 7.79` → `6.66 7.06 7.74`（32 核），只作参考。

| 入口 | 树 | 结果 |
|---|---|---|
| `bash skills/teamsmith/tests/lib/section-guard.sh --self-test` | cand `b025fbdf` | `✓ 64 ✗ 0`，rc=0（两次一致） |
| `bash skills/teamsmith/tests/section-guard.sh --loop-check` | cand | `89/89` 配平，rc=0 |
| `bash skills/teamsmith/tests/key-replies.sh --select receipts` | cand | `✓19 ✗0 SKIP0`，rc=0 |
| `TEAM_ROUTES_FAST=1 bash skills/teamsmith/tests/routes.sh promises` | cand | `✓18 ✗1`，rc=1 |
| 同上 | base `d73ca771` | `✓16 ✗1`，rc=1 |
| 同上 | mut `b025fbdf` + `grace=2` | `✓18 ✗1`，rc=1（两条宽限断言绿） |

两条 `routes.sh promises` 的红色是同一条、同名、同数：

```
✗ promise（TEAM_PULSE_WINDOW）：pulse up 没有按新窗口名建窗（记录：6 条 tmux 调用）
```

它在返修前的 `d73ca771` 上就已经红，而返修只改了宽限那一段（`git diff d73ca771..b025fbdf -- routes.sh` 只有
新增的 `mr_bg_stop_on_term_job` 与 `mr_promise_bg_stop_grace` 调用），所以不是这次返修引入的。两棵树的断言数
差 2（18 对 16），正是返修新加的两条宽限断言；返修前那两腿确实是死代码。按任务书「按命名结果判，不要求修复
范围外的旧红」，这条不构成返修项的失败。

## 三 · 未验证的边界

- `smoke.sh` §0e④ / §0f / §35 没有重跑（任务书只允许三个入口，且禁止 smoke 闭包）。我只做了读码核对：§0f 的
  断言已改成「没有进度」「ticks 0」、现场断言改成 `stalled for:` / `ticks:`；注入段在 `section_guard_begin`
  写心跳（`SG_TICKS=0`）之后才 `wait` 不返回，所以「无进度」这个前提在结构上成立。作者记录的
  `--select 0e,0f,35 ✓68 ✗0` 我没有独立复现。
- 26-m 的四处在真实 tmux/pane 上的行为没有跑（同上），这一条是读码结论。
- `perf.sh` 没有端到端重跑（任务书允许），汇总表的验证用的是 panel-cpu 真实打印格式的样本 + 逐条 sed/printf，
  不是一次真测。
- 反例只有一个（`grace=2`），按任务书没有建变异器、没有跑版本矩阵；作者记录的「固定成 0 → 腿②红」只作为
  对照引用，未重跑。
- 第 1 条里「跨段基线可能提前停跑」是读码得出的边界，没有造夹具去触发（任务书禁止新增夹具）。

## 四 · 裁定与去向

本报告不实现任何改动、没有再跑测试；下面按 PM 的裁定记，落地的活留给返修轮。

1. **宽限旋钮**：PM 已裁定不采纳把「响应 TERM 的作业 + 宽限 0」加成第三条腿 —— 它会引入 TERM/KILL 调度竞态。
   在现有机制下，配置的等待值是否被读取并遵守仍未被覆盖，P316 以 PARTIAL 继续；这一项不接受「覆盖已恢复」的说法。
2. **section-guard 的进度基线**：PM 已核实 watchdog 是**套件级一次 arm**，接受段间重置建议（在 `no`/`id` 变化时
   重置 `last_ticks`/`last_moved`），落地留给返修轮。
3. **key-replies 的 fd 字面量**（未决，供下一轮取舍）：`-w 2 3` 里的 `3` 是子进程 fd 号，只钉界（`-w 2` 或
   `-w 2[[:space:]]+[0-9]+`）即可保住这条断言的意图，诊断与行为断言不动。
4. **两处一行小修**（未决）：`smoke.sh:12019-12021` 的「预算 10s」注释与实际 300 对齐；作者报告里的自检总数
   65 改成 64（当前树两次实跑都是 64）。
