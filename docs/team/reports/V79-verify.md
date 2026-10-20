# V79 · P339 的独立验收：登记的生命周期从它可见那一刻起算

agent: verify   status: PASS（实现成立；一条与本次改动无关的既有 flake 见 §5.2）   time: 2026-10-20T15:17Z
branch: `task/V79-run-record-verify`（local 模式，未 push）   PR/MR: -
受检：候选 `1eaeafd1`（实现 `11a81632`，`skills/teamsmith/tests/smoke.sh` +26/−8）；作者报告 `docs/team/reports/P339-dev3.md`。

## 结论（先看这里）

**PASS。** 三件事都成立。

**(1) 竞态是真的，且在候选上消失。** 我的受控探针（同一现场，只改发 TERM 的时刻）在修前的 `main` 上
5/5 留下登记（`left=1`、`alive=no`、`sechdr=0` = 死在前导里），在候选 `1eaeafd1` 与落地树上
5/5 一条不留（`left=0`）；反向对照（等 `cleanup` 装好再杀）两棵树都 5/5 消失 —— 同一探针能给出两个方向，
读数不是「不管怎样都是 0」。`main` 的一遍普通 `--select 34b` 还**自己**撞了一次（349s、⑫ 红，见 §5.1）。

**(2) 三个附带问题都查清了。** 自检出口的「故意留下」在 ⑫ 的现场里不可能出现（另一把锁、另一个目录；
⑫ 数的是自己那个 `.runs/` 里「一条不剩」），而且同一条判据对多出来的那条会判红 —— 它只可能让 ⑫ 假红，
不可能假绿（§2）。⑫ 的判据**没有放宽**：仍是「一条不剩」，只是把起点从「等 300s」换成 `wait` 返回这个
确定时点，留下的 25×0.2s 只覆盖 `rm`/`ls` 之间的抖动；方向是把等待收紧（§3）。红侧（`_smoke_lock_drop_run_record`
改成 `return 0`）**2/2 稳定红、只有 ⑫ 一条**，还原后绿（§4）。

**(3) 没有波及别的锁段**：`--select 34,34c,34d` = `✓ 191 ✗ 0`（34 ✓35、34c ✓26、34d ✓107），与作者读数一致（§6）。

**两条 PM 要知道的**：① 候选分支的基点比 `main` 少了 V78 的合并（§0）——落地请只取 `11a81632` 这一个提交
（它干净地合进 `main`，`tree-land` 就是这么造出来并验收的）；② §5.2 的那条红是另一个夹具（`34b⑨`）的固定 5s
预算在高负载下不够，与本次改动不在同一条代码路径上，值得单独立单（§5.2 给了三条证据）。

## 0. 受检树的形状（一条 PM 要知道的事实）

候选分支的基点是 `4a6fc89b`，比今天的 `main`（`21921521`）少了 `542c2d76`（V78/P338 的等待者耐心）那次合并。
所以「候选 vs main」的整树 diff 里混着 V78 的回退（`git diff --stat main 1eaeafd1`：21 个文件，含
`gate-lock.sh −76`、`smoke.sh ±221`），**真正要落地的那一步只有 `11a81632` 这一个提交（+26/−8，只动 smoke.sh）**。

我因此在三棵树上取证（都在 `/var/tmp/v79-verify/`，都是本仓的 `--shared` 克隆，不是主检出、不是别人的工作树）：

| 树 | 内容 | 用途 |
|---|---|---|
| `tree-main` | `main` = `21921521` | 红侧对照（修前） |
| `tree-cand` | 候选 `1eaeafd1`（交付的那棵树） | 任务书字面要求：候选 vs main |
| `tree-land` | `main` + `git merge --no-ff 11a81632`（干净自动合并，只动 smoke.sh +26/−8） | 真正会落地的树：五遍稳定性、②/⑫、回归段、红侧还原 |

`git apply --check` 也确认 `11a81632` 的 smoke.sh 补丁能干净地落到 main 的 smoke.sh 上；`tree-land` 的合并结果
与候选那份 smoke.sh 的差异只是 V78 的那 187 行（`git diff --stat 1eaeafd1 -- smoke.sh`：+172/−15），没有第三处改动。

环境读数（每次运行都记了，报告里只写结论）：跑第一轮时 loadavg 一度 26.9 / 32 核（另一个席位的一批负载夹具在跑，
`ps` 的前 8 名里是 8 个 busy loop），
已经**超过门禁自己给计时断言的 0.75 × 核 = 24 的前提**；之后的运行 loadavg 落到 3.7。这一条直接决定了
下面的 §5 里那一条红怎么归类。

## 1. 受控探针（承重）：同一现场，只改「什么时候发 TERM」

探针脚本 `/var/tmp/v79-verify/probe.sh`（树外）。每次运行：自有 `TMPDIR` + 私有锁（`TEAM_SMOKE_LOCK=$R/lock`），
`bash <tree>/skills/teamsmith/tests/smoke.sh --select 34c </dev/null`；**每 5 ms 轮询一次** `<companion>.runs/*.run`，
一出现就读记录里的 `pid=`、立刻 `kill -TERM` 那个 pid（就是登记的主人 = 选段副本起的那个顶层运行），
`wait` 之后数 `<companion>.runs/*.run` 剩几条，并看那个 pid 还活不活。`early` 是受检窗口（登记已写出、
`cleanup` 还没装：`sechdr=0` = 内层一段都没打到）；`late` 是探针自身的反向对照（等内层打出第一段再杀，
那时 `trap cleanup EXIT` 已装好）。

`main`（修前）· `early` · 5 遍：

```
k=1 MODE=early detect=1933ms killrc=0 waitrc=143 left=1 left_after5s=1 alive=no rec=479066.run sechdr=0 pid=479066
k=2 MODE=early detect=1966ms killrc=0 waitrc=143 left=1 left_after5s=1 alive=no rec=490899.run sechdr=0 pid=490899
k=3 MODE=early detect=1924ms killrc=0 waitrc=143 left=1 left_after5s=1 alive=no rec=504057.run sechdr=0 pid=504057
k=4 MODE=early detect=1926ms killrc=0 waitrc=143 left=1 left_after5s=1 alive=no rec=513360.run sechdr=0 pid=513360
k=5 MODE=early detect=1953ms killrc=0 waitrc=143 left=1 left_after5s=1 alive=no rec=526957.run sechdr=0 pid=526957
```

候选 `1eaeafd1` · `early` · 5 遍：

```
k=1 MODE=early detect=1935ms killrc=0 waitrc=143 left=0 left_after5s=0 alive=no rec=539900.run sechdr=0 pid=539900
k=2 MODE=early detect=1920ms killrc=0 waitrc=143 left=0 left_after5s=0 alive=no rec=543617.run sechdr=0 pid=543617
k=3 MODE=early detect=1948ms killrc=0 waitrc=143 left=0 left_after5s=0 alive=no rec=548578.run sechdr=0 pid=548578
k=4 MODE=early detect=1916ms killrc=0 waitrc=143 left=0 left_after5s=0 alive=no rec=551592.run sechdr=0 pid=551592
k=5 MODE=early detect=1917ms killrc=0 waitrc=143 left=0 left_after5s=0 alive=no rec=556039.run sechdr=0 pid=556039
```

`tree-land`（main + 修复）· `early` · 5 遍：

```
k=1 MODE=early detect=1935ms killrc=0 waitrc=143 left=0 left_after5s=0 alive=no rec=560486.run sechdr=0 pid=560486
k=2 MODE=early detect=1943ms killrc=0 waitrc=143 left=0 left_after5s=0 alive=no rec=566177.run sechdr=0 pid=566177
k=3 MODE=early detect=1968ms killrc=0 waitrc=143 left=0 left_after5s=0 alive=no rec=574054.run sechdr=0 pid=574054
k=4 MODE=early detect=1959ms killrc=0 waitrc=143 left=0 left_after5s=0 alive=no rec=577442.run sechdr=0 pid=577442
k=5 MODE=early detect=1937ms killrc=0 waitrc=143 left=0 left_after5s=0 alive=no rec=581714.run sechdr=0 pid=581714
```

反向对照（同一探针，等 `cleanup` 装好再杀）：`main` 2/2、候选 2/2 全部 `left=0 sechdr=1`：

```
main k=1 MODE=late detect=2344ms waitrc=143 left=0 alive=no rec=590833.run sechdr=1
main k=2 MODE=late detect=2308ms waitrc=143 left=0 alive=no rec=597100.run sechdr=1
cand k=1 MODE=late detect=2550ms waitrc=143 left=0 alive=no rec=605145.run sechdr=1
cand k=2 MODE=late detect=2425ms waitrc=143 left=0 alive=no rec=618847.run sechdr=1
```

读法：三次 `early` 系列的 `detect` 都在 1.9s 左右、`sechdr=0`、`waitrc=143`（确实是被 TERM 打死并被回收），
所以差别只有一处 —— **树**。修前 5/5 留下登记，修后（候选与落地树）5/5 一条不留；`late` 那 4 遍证明同一探针
不是「无论何时杀都能得到 left=0」：修前的树在 `cleanup` 装好之后被杀，登记同样消失。

## 2. 「自检出口故意留下登记」会不会把 ⑫ 弄成假绿

代码事实（`tree-land` 行号）：`smoke.sh:643` 的 `_smoke_lock_drop_run_record` 只删 `$SMOKE_LOCK_RECORD_TARGET.runs/$$.run`
（自己 pid 那条）；`:698` 的 `trap '_smoke_lock_drop_run_record' EXIT` 装在 `gate_lock_register_run` **之前**；
`:706` 的自检出口在 `TEAM_SMOKE_FIXTURE=1` 下把 `SMOKE_LOCK_RECORD=0` 写死再 `exit`，于是那条登记**故意**留了下来；
`:1401` 的 `cleanup` 调同一个函数（幂等）。

⑫ 的现场是**另一把锁**：`$TMP/p281-nolock/lock`（`rm -rf "$P281NL"; mkdir -p "$P281NL"` 起步），而 ② 的自检出口留的是
`$TMP/p66/.lock.machine.runs/<pid>.run`。⑫ 的判据数的是 `$(gate_lock_companion_path "$P281_NLLOCK").runs/*.run`
——**它自己那把锁的目录**，且要求「一条不剩」。

实测（`/var/tmp/v79-verify/selftest-leak.sh`，`tree-land`）：

```
① selftest-exit rc=0 left=1
   留下：2026-10-20T15:15:58+00:00	pid=969882	start=64964044	cmd=smoke.sh	kind=top	agent=pm	worktree=…	started=1792509358	expected=0	bound=121500	sections=135	no_lock=0	ancestor=-	heartbeat=…
   自检出口：本进程作为队列子进程到此为止（SMOKE_LOCK_SELFTEST_CHILD=0）
   自检出口：保留持有者记录 …/.lock1.machine.holder（队列守卫自检要读它的格式）；真实路径收尾必删
② ⑫ 现场（干净锁）：
   two: rec=974715.run pid=974715 waitrc=143 left_after_wait=0
   ① 的那条还在它自己的锁里：1 条
③ ⑫ 现场 + 一条别人的登记（同一判据）：
   three: rec=979276.run pid=979276 waitrc=143 left_after_wait=1 (含注入的 999999.run)
      …/.lock-three.machine.runs/999999.run
   → ③ 的读数 1 条 ≠ 0，按 ⑫ 的判据（要求「一条不剩」）就是红：判据不会忽略多出来的那条。
```

读法：① 证明确实是「故意」（一条完整登记留下来了，内容照抄）；② 证明确实是「另一把锁」（⑫ 的现场干净到 0 条）；
③ 是这条判据的反向：现场里**多一条**别人的登记，同一判据就数出 1（= 判 0，红）。所以「故意留下」这条路径
**只可能让 ⑫ 变假红，不可能让它假绿**；而且 ② 的现场与 ⑫ 的现场在文件系统上不相交，连假红都不会发生。

### 2.1 一次 `--select 34b` 的 ② 与 ⑫ 读数（`tree-land`，五遍里的第 2 遍）

```
  ✓ 34b② 无竞争 → 子进程的退出码原样透传（0）
  ✓ 34b② 子进程真的作为队列子进程跑起来了
  ✓ 34b② 它把 holder 写成了自己（真的拿到了锁；记录在伴生锁边上）
  ✓ 34b② 发布路径边上没有被我们创建记录（兼容声明只读、只建文件本身）
  ✓ 34b② 持有者记录自述 kind=top（顶层运行）
  ✓ 34b② 持有者记录带 expected（Σband_s）
  ✓ 34b② 持有者记录带 bound（Σbudget_s）
  ✓ 34b② 持有者记录带工作树字段（解析不出就写 ?，不猜）
  ✓ 34b② 持有者记录带 lock_identity（fd 或 path，如实写）
  ✓ 34b② 持有者记录带 lock_dev_ino（dev:ino）
  ✓ 34b② 顶层运行也在 <companion>.runs/ 登记自己那条（kind=top）
  ✓ 34b② 顶层运行的 ancestor 是 -
  ✓ 34b② 无竞争时没有排队失败的噪音
  ✓ 34b② 空闲锁不进排队路径
  ✓ 34b⑫ opt-out 运行也登记了 <companion>.runs/<pid>.run（972130.run）
  ✓ 34b⑫ 那条记录带 no_lock=1（残余窗口可观测）
  ✓ 34b⑫ opt-out 的运行不声称嵌套（没做过祖辈证明）
  ✓ 34b⑫ 记录带 started（等待者能算已跑时长）
  ✓ 34b⑫ 运行时自述 no_lock=1（既有行为）
  ✓ 34b⑫ 等待者读到的描述行里也标了 no_lock=1（残余窗口可见）
  ✓ 34b⑫ 收尾：登记随它退出消失（只删自己那条）
```

## 3. 判据有没有放宽：没有，方向相反

⑫ 的新判据（`tree-land:16972`）逐字是：

```
wait "$P281NL_JOB" 2>/dev/null || true
for _i in $(seq 1 25); do
  [ -z "$(ls -A "$(gate_lock_companion_path "$P281_NLLOCK").runs"/*.run 2>/dev/null || true)" ] && { P281NL_GONE=1; break; }
  sleep 0.2
done
assert_eq "34b⑫ 收尾：登记随它退出消失（只删自己那条）" "$P281NL_GONE" "1"
```

- 等的条件没变：仍是「`.runs/` 里一条不剩」（`ls -A` + 空判，不是「我那一条不见了」）。
- 变的是**起点**：从「杀掉之后等 300 秒」改成「等那个装登记的进程被回收（`wait` 返回）之后立刻查」；
  剩下的 25 × 0.2s = 5s 只是 `rm` 与 `ls` 之间文件系统抖动的容差。
- 方向：`wait` 返回是一个**确定时点**（登记的 EXIT trap 在进程死之前就跑完了），300s → 5s 是把等待**收紧**；
  旧判据下「250 秒后才消失」会算过，新判据下不会。没有「最终会消失就行」这类写法。

一条旁证（顺带说明它不是靠「等」）：修前的树里同一件事要等满 300s 才红；修复后红侧（§4）一遍 46–51s
（段落 ＋ 5s 容差）。

## 4. 红侧：把「退出时删登记」拆掉 → ⑫ 必须稳定红；还原 → 绿

做法：`tree-broken` = `tree-land` 的克隆，在 `_smoke_lock_drop_run_record` 的第一行插一句
`return 0  # V79 红侧：退出时不删登记（只验 ⑫ 会不会红）`（`git diff` 恰好 +1 行，`smoke.sh` md5 从
`2319d1cd…` 变成 `50af01af…`）。

还原：`git checkout -- skills/teamsmith/tests/smoke.sh` → `git status --porcelain` 空、md5 回到 `2319d1cd…`
（与 `tree-land` 逐字节相同），同一命令再跑一遍 `rc=0 ✓125 ✗0`（15:05:13→15:05:58）。两次红侧各花 46s / 51s
—— 没有一遍等满 300s，⑫ 的 5s 容差判的是「没删」，不是「删得慢」。

```
=== broken-red run 1 (15:03:35 -> 15:04:26 UTC) rc=1 ===
  ✗ 34b⑫ 收尾：登记随它退出消失（只删自己那条）（期望 [1]，实际 [0]）
== 选段结果 ==  ✓ 124  ✗ 1
=== broken-red run 2 (15:04:26 -> 15:05:12 UTC) rc=1 ===
  ✗ 34b⑫ 收尾：登记随它退出消失（只删自己那条）（期望 [1]，实际 [0]）
== 选段结果 ==  ✓ 124  ✗ 1
=== broken-restored run 1 (15:05:13 -> 15:05:58 UTC) rc=0 ===
  ✓ 34b⑫ 收尾：登记随它退出消失（只删自己那条）
== 选段结果 ==  ✓ 125  ✗ 0
```

## 5. 五遍稳定性（`--select 34b`，顺序、自有 TMPDIR、私有锁）

### 5.1 红侧的自然复现（不是探针，是一遍普通运行）

`main` 的一遍 `--select 34b`（`tree-main`，14:53:08 起）**自己**撞上了这个竞态：

```
  ✗ 34b⑫ 收尾：登记随它退出消失（只删自己那条）（期望 [1]，实际 [0]）
#5 34b · 门禁锁排队守卫：超上限要大声失败并点名持有者（P66） · 参考 用时 349s · ✓101 ✗1 SKIP0 · ticks 102
== 选段结果 ==  ✓ 124  ✗ 1
```

349s = 约 45s 的段落 + ⑫ 里那段 1500×0.2s 的等待。这就是任务书里「时红时绿」的原始形状（作者的五遍里也有一遍
341s / `✓74 ✗1`）；同一棵修前的树在别的遍里 30s 就绿。**修后的树（`tree-land`）在 §5.2/§5.3 的十遍里没有一次
走那条等待**。

这一批我只跑了第 1 遍就停了：修前的树每一遍都可能撞上那条 300s 的等待（五遍可能要 25 分钟），而这一问
只需要一次自然复现；它不是「五遍稳定性」的证据（那个在 §5.2/§5.3，全在修后的树上）。

### 5.2 第一批（跑在高负载窗口里，loadavg 一度 26.9 / 32 核）

| 遍 | rc | 起止（UTC） | 段尾读数 |
|---|---|---|---|
| 1 | **1** | 14:47:44→14:48:53 | `✓ 123 ✗ 2`（两条都在 34b⑨，见下） |
| 2 | 0 | 14:48:53→14:49:56 | `✓ 125 ✗ 0` |
| 3 | 0 | 14:49:56→14:50:44 | `✓ 125 ✗ 0` |
| 4 | 0 | 14:50:44→14:51:27 | `✓ 125 ✗ 0` |
| 5 | 0 | 14:51:27→14:52:07 | `✓ 125 ✗ 0` |

**⑫ 在这五遍里全绿**（每遍都有 `✓ 34b⑫ 收尾：登记随它退出消失（只删自己那条）`）。第 1 遍的两条红是另一个
夹具，原文：

```
  ✗ 34b⑨ 锁被活着但不是祖辈的进程持有 → 证明不成立 → 照旧排队（exit 2）（期望 [2]，实际 [0]）
  ✗ 34b⑨ 它照旧排队并撞上限（…/p281/w-notanc.log 中找不到 [排队超限]）
```

这两条红落在「waiter **拿到了**锁」那一侧（rc=0，且它的日志里没有排队行），也就是那个夹具里
`flock --close -x $P281_LOCK sleep 5` 的真实持有在 waiter 到达取锁之前已经结束。归因（三条，不是推断）：

1. **本改动的任何一行都不在取锁这条路上。** 它只改：登记进程的 EXIT trap（登记之后才装）、
   `SMOKE_LOCK_RECORD=1` 的位置、自检出口的 `SMOKE_LOCK_RECORD=0`、`cleanup` 改调同一个函数、⑫ 的容差。
   红的那一步发生在 waiter **注册之前**（它拿到了锁，压根没排队），所以 P339 的代码一行都还没跑。
2. **照抄那个夹具的现场跑，两棵树都稳。** `/var/tmp/v79-verify/neg-holder.sh` 原样照抄 ⑨ 的现场
   （`sleep 30` 诱饵 + `flock --close -x LOCK sleep 5` + `sleep 0.4` + 写「持有者=诱饵」的记录 +
   `--select 0b` / `WAIT=1` 的真入口 waiter）：`tree-land` 5/5、`tree-main` 5/5 都是 `rc=2 queued=1 limit=1`，
   0.4s 宽限结束时锁都在持有者手里（`grace_free=no`），waiter 从启动到退出 2.95–2.98s。
3. **夹具的预算有多窄**：它给 waiter 4.6s（5s 减持有的 0.4s 宽限），而 waiter 空闲时从启动到拿到锁约 1.95s
   （启动到退出 2.95s，减去排那 1s）—— 一个约 2.4 倍（4.6 ÷ 1.95）的变慢就够越线。第 1 遍开跑时 loadavg 26.9，已经**高于门禁自己给计时断言
   的 0.75 × 核 = 24 的前提**；这一条我没有在事后造假负载重演（那会把「五遍」的机器条件再弄脏），而是用
   上面 2 的现场数字与 3 的预算差的算术说话。

**我没拿到的**：第 1 遍那次失败现场的 `w-notanc.log` 随临时根被回收了，所以那次 waiter 具体慢了多久没有读数
—— 归因靠的是上面第 1 条的代码可达性与第 2 条的同现场实测，不是那次运行的日志。

### 5.3 第二批（同一棵树、同一命令、loadavg 3.7→10；顺序、各有自己的 TMPDIR 与私有锁）

| 遍 | rc | 起止（UTC） | 段尾读数 |
|---|---|---|---|
| 1 | 0 | 15:00:00→15:00:43 | `✓ 125 ✗ 0` |
| 2 | 0 | 15:00:43→15:01:26 | `✓ 125 ✗ 0` |
| 3 | 0 | 15:01:26→15:02:08 | `✓ 125 ✗ 0` |
| 4 | 0 | 15:02:08→15:02:51 | `✓ 125 ✗ 0` |
| 5 | 0 | 15:02:51→15:03:32 | `✓ 125 ✗ 0` |

五遍全绿，每遍 ~43s（没有一遍走 ⑫ 的等待）。连同第一批的四遍全绿，修后的树上一共 9 遍绿、1 遍红（那条红见
§5.2 的归因）。两批的差别是机器条件（高负载 vs 平静），不是树。

## 6. 没有波及别的锁段：`--select 34,34c,34d`

`tree-land`、顺序一遍（15:06:01→15:10:39）：

```
#5 34 · 门禁锁：排队/运行分开记账 · 参考 用时 66s · ✓35 ✗0 SKIP0 · ticks 35
#6 34c · 命名面：运行条目点开头或带 ns · 参考 用时 45s · ✓26 ✗0 SKIP0 · ticks 26
#7 34d · 身份面：锁被删/被换 → 一行点名 + 证据 + 停跑；入场检查；等待者 · 参考 用时 164s · ✓107 ✗0 SKIP0 · ticks 107
```

与作者读数（✓191 ✗0）一致。**这条命令需要一次重跑，原因是我自己第一次的姿势**：第一次我给私有锁起的名字是
`<run>/lock`，`34d 2.1` 里那条断言的期望值把默认锁名硬编码成 `.teamsmith-smoke.lock.machine`，于是
（期望 `…/r1/.teamsmith-smoke.lock.machine`、实际 `…/r1/.lock.machine`）假红一条（✓190 ✗1）。

这是一个**既有夹具的脆弱点，不是本次改动引起的**（`tree-main` / `tree-cand` / `tree-land` 三棵树里那条断言逐字相同，
`gate_lock_default_path` 又确实听 `TEAM_SMOKE_LOCK`）：它的上一条断言已经承认了「外层设了 TEAM_SMOKE_LOCK」，
而下一条又把默认名字写死了。`team review` 自己的锁默认就叫 `teamsmith-smoke.lock`，所以 PM 的复验不会碰到；
碰到它的只会是像验证侧这样把 `TEAM_SMOKE_LOCK` 改成别的名字的调用方。重跑用
`TEAM_SMOKE_LOCK=<run>/teamsmith-smoke.lock`（默认形状）重跑一遍（15:11:07→15:15:46）：

```
#5 34 · 门禁锁：排队/运行分开记账 · 参考 用时 66s · ✓35 ✗0 SKIP0 · ticks 35
#6 34c · 命名面：运行条目点开头或带 ns · 参考 用时 45s · ✓26 ✗0 SKIP0 · ticks 26
#7 34d · 身份面：锁被删/被换 → 一行点名 + 证据 + 停跑；入场检查；等待者 · 参考 用时 164s · ✓107 ✗0 SKIP0 · ticks 107
账本自查： 7 段收口 · 增量 ✓191 ✗0 SKIP0 ｜ 结果行 ✓191 ✗0 —— 一致
== 选段结果 ==  ✓ 191  ✗ 0
```

## 7. 轻量收口

| 检查 | 命令 | 读数 |
|---|---|---|
| 语法（落地树） | `bash -n <tree-land>/skills/teamsmith/tests/smoke.sh` | rc=0、无输出 |
| 语法（候选树） | `bash -n <tree-cand>/skills/teamsmith/tests/smoke.sh` | rc=0、无输出 |
| 选段表自检 | `bash skills/teamsmith/tests/section-select.sh --check`（落地树） | `== 选段自检 ==  ok 9  bad 0  SKIP 1`，rc=0；SKIP 那条是 `.pi/skills` 的字面模式（检出形状 internal，机器生成面，不属于本次改动） |
| 账本禁令（固定验收行） | 见下 | `hits=0 names=ok`，rc=0 |
| 空白/冲突 | `git diff --check`（本任务分支） | 无输出、rc=0 |

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（…/.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=<home>/…/.worktrees/verify scope=published files=1932 hits=0 names=ok user=resolved
$ echo $?
0
```

## 8. 没跑的、剩下的边界

- **没跑整套门禁、没跑容器**（任务书明确不要）。本报告的读数一律是**选段**读数：`34`/`34b`/`34c`/`34d`
  及其前导段（`0`、`0b`、`0c`、`0d`），其余 131 段没跑。引用时必须照这个口径。
- 候选分支比 `main` 少 V78 的合并（§0）：我在 `tree-land`（main + 本提交）上取的五遍/回归读数才是落地形状；
  `tree-cand` 上的读数只用来回答任务书字面那一问（候选 vs main）。
- 探针、跑手、红侧副本都在 `/var/tmp/v79-verify/`（树外，不进仓库）。

## 9. 测试状态（总表）

| 验收项 | 命令（都在本席位 worktree 外的 `/var/tmp/v79-verify/` 里跑） | 读数 |
|---|---|---|
| 受控探针（修前） | `probe.sh tree-main main 34c 5 early` | 5/5 `left=1`、`alive=no`、`sechdr=0` |
| 受控探针（候选） | `probe.sh tree-cand cand 34c 5 early` | 5/5 `left=0` |
| 受控探针（落地树） | `probe.sh tree-land land 34c 5 early` | 5/5 `left=0` |
| 探针反向对照 | `probe.sh … late`（main 2 / cand 2） | 4/4 `left=0 sechdr=1` |
| ②/⑫ 读数 | `--select 34b`（落地树） | ② 14 条、⑫ 7 条全绿（§2.1） |
| 自检出口那个坑 | `selftest-leak.sh tree-land` | ① 故意留 1 条；② ⑫ 现场 0 条；③ 多一条别人的 → 判据读数 1（红） |
| 红侧 | `tree-broken`（`_smoke_lock_drop_run_record` → `return 0`）`--select 34b` ×2 | 2/2 `✓124 ✗1`，只有 ⑫ |
| 红侧还原 | `git checkout --` + `--select 34b` | rc=0 `✓125 ✗0`；md5 与 `tree-land` 相同 |
| 五遍稳定性 | `--select 34b` ×5（两批，顺序、自有 TMPDIR/私有锁） | 第二批 5/5 `✓125 ✗0`；第一批 4/5（那条红见 §5.2） |
| `main` 天然复现 | `--select 34b`（`tree-main`） | `✓124 ✗1`、段 349s（⑫ 红） |
| 其它锁段 | `--select 34,34c,34d` | `✓191 ✗0` |
| 轻量收口 | `bash -n` / `section-select.sh --check` / 账本禁令 / `git diff --check` | 见 §7 |
