# gate-waiter-patience · design

本文件记的是**为什么这样做**与**怎么证明**；合同文本在 `specs/verification/spec.md`，执行单在 `tasks.md`。

## 1 · 现场（都是量出来的，不是读注释读出来的）

### 1.1 `expected` 没有生产者，`cap` 恒等于 `W`

```
$ . skills/teamsmith/scripts/lib/gate-lock.sh
$ gate_lock_expected skills/teamsmith/tests/smoke.sh /dev/null
0	121500	135
```

`expected`（Σband）= **0**，`bound` = 121 500 = 135 段 × 默认 900，`sections` = 135。`gate_lock_expected`
唯一的输入是 `section-budgets.tsv`（`gate-lock.sh:515`），它在 P316（`d92f0a17`）被删；三处调用点读的是
`/dev/null`（`smoke.sh:559`、`:637`）或一个不存在的路径（`cmd-review.sh:1171`、`:1202`）。

于是 `gate_lock_cap`（`gate-lock.sh:466`）的投影恒为负：

```
$ # 记录：started = 4560 秒前、expected=0、W=1800
$ gate_lock_cap <lock> 1800
1800	-4560	0	1792474111
```

`cap`=1800 = `W`。`clamp(remaining + 60, W, 4W)` 这条 P281 的意图**今天没有任何一条路径能生效**。

一个必须写下来的细节（它决定红侧现场怎么造）：`remaining + 60` 里那 60 秒是一个固定余量，所以当 `started`
离现在不到 60 s 时，投影落在 `4W` 上而不是 `W`。实测一个 `started=现在`、`W=2` 的记录：

```
$ gate_lock_cap <lock> 2
8	0	0	1792479097        # = clamp(60-0, 2, 8) 的上界
```

也就是说：`W ≥ 60`（生产默认 1800 就是）时 cap 恒为 `W`；只有夹具那种小 `W` 且记录刚写的时候才会落到 `4W`。
所以后面每一条红侧的现场都把记录里的 `started` 放到 120 s 前，否则新旧两版都算 `4W`，翻转看不出来。

### 1.2 持有者记录公布的心跳路径，不是被写的那个

顶层 `smoke.sh` 是「取锁的包装器 + 子套件」两个进程：包装器写 `.holder`，子套件登记
`.runs/<pid>.run` 并在自己的临时根里写心跳。用私有锁跑一次真实的选段（`--select 1,1b,2`，非 FAST 才排队），
在跑动中每 20 ms 列一次锁目录：

```
$ TMPDIR=$P TEAM_SMOKE_LOCK=$P/ts.lock bash skills/teamsmith/tests/smoke.sh --select 1,1b,2
# 观察期间出现过的全部文件（去重）：
/var/tmp/p332probe4.BB0a0v/.ts.lock.machine.runs/2817178.run
/var/tmp/p332probe4.BB0a0v/.teamsmith-smoke-heartbeat.2817178
# 持有者记录（包装器 pid=2815796）：
heartbeat=/var/tmp/p332probe4.BB0a0v/.teamsmith-smoke-heartbeat.2815796
```

包装器公布的是 `.teamsmith-smoke-heartbeat.2815796`，**这个文件从头到尾没有人写**；唯一在动的是子套件
（pid 2817178）的心跳，而它的路径写在 `.runs/2817178.run` 那条登记里。`team review` 的形状是**静态推断，未实测**：
它的持有者记录写死 `heartbeat=-`（`cmd-review.sh:1169`、`:1200` 的 `GATE_HB=-`），而它跑的门禁是子进程，按同一条
调用链（`smoke.sh:668-673` 的 `gate_lock_register_run`）它只会在自己的登记里公布心跳 —— 这一条由 `tasks.md` §3.2
的正例在门禁里落成断言，不是已证事实。

结论：**「读持有者记录里那一个 `heartbeat=` 字段」在今天的两种形状下都是空的（顶层实测，review 形状静态）**。
心跳本身不是新东西（`gate_lock_heartbeat_of_pid` 已经在用它给嵌套运行定期限，`gate-lock.sh:343`），缺的是
「等待者怎么读到它」。

## 2 · 规则

等待者的上限不再是「按 expected 预算出来的一个数」，而是每个轮询轮次按现场算出来的一个上界：

| 现场 | `state` | 上限 `ceiling` | 失败行多说的那一句 |
|---|---|---|---|
| 有活登记公布心跳路径，文件存在，`silent_for < W` | `live` | `4 × W` | 心跳仍在动，但到了硬顶 `4 × W` |
| 同上，但 `silent_for >= W`（**边界归这一侧**） | `stalled` | `W` | 持有者的心跳已停 `N` 秒 |
| 没有活登记公布心跳路径（旧写入者 / `heartbeat=-`），或路径上的文件不存在 | `none` | `W` | 没有可用心跳（记录公布的是 `<path>`，文件不在 / 记录没有这个字段） |

三条判据，都写成一件事：
1. **失败判据只有一个**：等待者自己的已等时长 `>= ceiling`。判据**只读等待者自己的那一个时钟**，所以
   §34b①/⑦ 的 `已跑/等满 Ns` 语义逐字不变，也没有第二条宽限规则 —— 这是它唯一的理由（旧的「避免双红」
   论证是错的，见 §2.1）。
2. `state` **每轮重算**（排队本来就是 1 s 一轮、每轮重读记录），所以心跳停了会让上限从 `4W` 落回 `W`。
3. `expected`/`bound`/`sections` 仍写进记录、仍被 `gate_lock_describe_one` 打印（§34b② 断言它们存在），
   **只是不再参与任何判定**。它们从「预算」降级为「诊断字段」。

为什么是 `4 W` 而不是更大：`4 × 1800 s = 2 小时`，仍然是一个**有界**的两小时；记录里出现过一小时以上的持锁
（那一次是否全程有进展未核实，不作为「合法运行」的先例），乘数再大只是把无界往后挪。要更长的耐心，改的是
`W`（运维旋钮），不是乘数。

### 2.1 为什么耐心用等待者自己的时钟（以及它不做到什么）

判据用「等待者已等 `>= ceiling`」而不用「心跳停了多久」，理由只有一个：**只有一个时钟**。等待者不引入第二
个时间语义（「停了多久」需要它自己记住上一轮的心跳 mtime），§34b①/⑦ 的时长文案因此一个字不改。

**它做不到的事（写清楚，不拿论证去救）**：等待者**已经在等**的时候，心跳转 stale 的那一轮，`silent_for` 到
`W` 与持有者自己看门狗的挂住上限（默认也是 `W`）是**同一个事件、同一个阈值** —— 那一轮等待者必然已经
`>= W`，当轮就失败。所以「已等 ≥ ceiling」不能避免双红（一条挂住 + 一条排队超限），它们同秒出现；两个旋钮
不等时（等待者 `W=600`、持有者 `cap_h=1800`），ceiling 回落还会让等待者比持有者自己的 trip 早判死。想避免
这件事就得给延期规则（转 stalled 的那一轮宽限一次），那是第二条耐心规则，违反净零。

## 3 · 心跳来源：本锁所有活登记里最新的那一个

`gate_lock_heartbeat_newest <published lock>`：遍历 `<companion>.holder` 与 `<companion>.runs/*.run`，
只取 `gate_lock_record_live` 为真的条目，从每条记录里读 `heartbeat=`，对存在的文件取 mtime，返回最新的一条
（`path<TAB>mtime`）；没有 → 空。

- **不是新机制**：等待者本来就要 glob 这两个位置来点名持有者（`gate_lock_describe`），这里只是顺带读同一个
  记录里的另一个字段；轮询仍然是那一个 `while` 循环。
- **为什么不是「只读 `.holder`」**：§1.2。顶层 `smoke.sh` 与 `team review` 两种形状都会退化成 `none`，改动
  等于没改 —— 「合法的长跑不该让等待者失败」这条目标一条都实现不了。
- **为什么取「最新」而不是「top 的那条」**：一次运行的进展可能出现在任何一条活登记上（顶层套件自己那条，
  或它跑的一个嵌套运行）；机器忙的证据是「还有心跳在动」，不是「哪一条记录在动」。
- **为什么看 mtime 而不是内容**：段守卫每次 tick 都原子重写这个文件（`section_guard_write_heartbeat`），
  `no|armed|cap|elapsed|ticks|id` 里 `elapsed` 一定变化，但读内容需要解析两行格式并自己保存上一次读数（多一处
  状态）；mtime 是一次 `stat`，与 `gate_lock_path_identity` 同一个两平台兜底写法。1 s 的文件时间分辨率对
  `W ≥ 1 s` 足够，而夹具本来就用 `W=1..30`。
- **已知的有界放宽（本 change 明写接受）**：读取**不校验**登记与当前持有者的祖先关系 —— 它不看既有的
  `ancestor=`，也不比对记录里的 `lock_identity`/`lock_dev_ino` 与当前锁的身份。于是一条**遗留但仍活着**的
  登记（例如泄漏的孤儿段守卫）如果在 tick，会把等待者的上限顶在 `4W`，而真正的持有者可能已经卡死；默认值下
  最坏是 2 小时而不是 30 分。它与「这棵运行树还有人在推进」的口径一致，且仍然有界，所以本 change 接受它，
  **不新增认证、不新增监测器**；要更紧的读法，现成字段（`ancestor=`、`lock_dev_ino`）就够，但那是另一次变更。

## 4 · 删了什么、加了什么（净零账）

| | 内容 | 谁接住被删掉的行为 |
|---|---|---|
| 删（product） | `gate_lock_cap` 的 `expected` 投影分支与 4 字段输出（`gate-lock.sh:463-477`），`remaining=` 在两条排队行里 | 同一处换成心跳读数；「上限」这件事仍然只有一个实现 |
| 删（product） | `gate-lock.sh:464` 的 `cap = clamp(remaining + 60, W, 4W)` 注释 | 新函数头注释写规则（状态表的三行） |
| 删（断言） | §34⑦ 的 remaining/cap 对账（`smoke.sh:16486-16491`）、§34b⑨ 的 clamp 与 remaining 两条（`:16696-16705`） | 换成 `tasks.md` §3 分支表里的断言。**P329 可能已先删**：它的任务书写明要删这三条，本 change 按实际状态记账，不重复算 |
| 改（断言） | §34b⑨ 留用的两条现有断言（无 `expected` → `W`、`W=1000/10` 的上下限）改成心跳口径的纯函数腿（`gate_lock_patience` 的直接输入/输出） | 同一个函数入口、同样的夹具现场，只是判据从投影换成心跳 |
| 加（断言） | 今天没有任何断言覆盖的分支：`silent_for == W` 与 `== W-1` 的边界、路径在但文件不在、`team review` 形状（件生锁 + `kind=nested` + `ancestor`）的正例与「只读 `.holder`」反例 | 每条对应 delta 的一条 scenario，逐条看 `tasks.md` §3 |
| 加（product） | `gate_lock_path_mtime`（3 行）、`gate_lock_heartbeat_newest`（约 12 行，与既有 `gate_lock_heartbeat_of_pid` 同一个遍历形状）、`gate_lock_patience[_pair]`（约 14 行，替掉 12 行的 `gate_lock_cap`） | —— |

**判据里的时间只有一个来源**：新增代码的 `now` 一律取自既有的 `gate_lock_now`（`gate-lock.sh:33`，`gate_lock_cap`
本来就是这么写的）。这不是新机制，而是让分类可以**用准确值证明**：测试子 shell 局部覆写这个函数把时刻钉住，
心跳文件的 mtime 用绝对值写入（`touch -d "@<epoch>"`），于是 `silent_for == W` 与 `== W-1` 是等号断言而不是
「大约 W 秒」；硬顶 `4×W` 也在同一个纯函数腿上取准确值，**不靠「等到第几秒退出」**（`tasks.md` §1.6）。

**规则数 1 → 1**：一个耐心规则替掉一个耐心规则，没有新增第二个等待机制、没有新增调度器/监测器/预算表；
product 净增约 17 行。**断言账按实际删改记，不按场景数或翻转配额凑数**：被删的投影腿由分支表的纯函数腿与两条
端到端正/反例替掉，P329 先删的记在它名下，实施时按 `diff` 的真实行数写报告。判据只有一个不变的目标：
**每一条被换掉的断言都得说得出接管者**（`tasks.md` §3 的矩阵就是那张表）。

## 5 · 与 P329 的写集冲突

P329（`docs/team/tasks/P329-subtractions.md`）先落地，逐行分工：

| 位置 | P329 做 | 本 change 做 |
|---|---|---|
| `smoke.sh:16462-16466`（§34⑦ 的注释与现场说明） | 删其中「预算表退役」的假注释 | 换成心跳口径的说明（一条变体现场） |
| `smoke.sh:16480`（`TEAM_SMOKE_LOCK_WAIT=200s` 断言） | 留 | 留（下限仍被打印） |
| `smoke.sh:16486-16491`（remaining/cap 对账） | 删 | 删（已删则记「P329 已删」，不重复计） |
| `smoke.sh:16688`（§34b⑨ 的注释） | 删「clamp(remaining+60, W, 4W)」口径 | 写心跳口径 |
| `smoke.sh:16696-16705`（expected=400 的两条） | 删 | 删（同上） |
| `smoke.sh:16691`、`:16706-16707`（旧→W、1000/10 两条） | 留 | 改写成纯函数腿 + 分支表（`tasks.md` §3.1） |
| `gate-lock.sh:463-477`（cap） | **不碰** | 换掉 |
| `gate-lock.sh:479-513`（席位推导） | 合并进 `team_sender_from_dir` | **不碰** |

顺序是硬约束：同一批断言两个写者会互相覆盖。apply 的第一步是 `git merge main` 后核对 P329 已落地：**看它的
落地记录（提交/看板 `done`），再看它负责的那条判据已退役**（`grep -c 'CAP_WANT' skills/teamsmith/tests/smoke.sh`
= 0），不拿整文件里一句注释的 grep 计数当前置（`expected=400` 在 `smoke.sh:16463` 是注释，P329 不必删它）；
未落地 → `BLOCKED:` 交回 PM。

P326（`behavior-focused-ci`）也改 `smoke.sh`，但它改的是选段器、`--floor` 与 §58/§36，与本 change 的行不重叠。
它**还没有**落地：本任务的基点 `d2903a3b` 上 `grep -c -- --floor skills/teamsmith/tests/smoke.sh` = 0（P326 仍在看板
`wip`）。propose 阶段不冲突（本阶段不写产品文件），apply 阶段两个 change 都要先 `git merge main`。

## 6 · 规格 delta 的四块取舍

- **MODIFIED，不是 REMOVED+ADDED。** 工具拒绝丢场景：在 `/var/tmp` 的副本上试过一次改名，报错原文
  `MODIFIED "The hard timeout covers the gate run, not the queue" omits scenario(s) the current spec still has`。
  另一条路（整条退场再以新标题重加）会让 `docs/team` 里十来处 `verification#The hard timeout covers the gate
  run, not the queue` 的引用变成 `retired`（`spec-refs.sh` 会打印，不判失败，但读者跟不过去）。所以：**标题与
  六个原场景名全部保留**（工具只允许保留名字，不允许改名），只改其中那条描述被删行为的场景的正文（并让正文
  点明「上限不再跟随它」），并新增五条（心跳在动 / 心跳停了 / 硬顶 / 旧记录无心跳 / `team review` 形状）。
  被保留名字的那条场景现在钉的是**退场本身**：公布了 `expected=400` 也不再延长耐心。
- **ADDED / RENAMED / REMOVED 都是空的。** 没有新能力，没有改名，没有整条退役。
- 只改这一条 requirement：`expected`/`bound` 的**生产者**（`gate_lock_expected`）不动，因为「记录的字段」
  属另一条 requirement（`The gate lock's holder record names its kind, its owner, its elapsed time and its
  bound`）；退役它要第二次改规格，超出本 change 的范围，写进未知项。

## 7 · 不做 / 未知

- **§61b 的静默段。** `smoke.sh:22392` 的 §61b 正文是一次子进程（`task-model-routing.sh --flip`，记录 4946 s），
  中间没有任何 `ok()`/`bad()`/等待轮，也就是整段**没有 tick**。按段守卫自己的判据（`cap` 秒内 ticks 没动就停跑），
  顶层的 §61b 会在 1800 s 上先被自己的挂住上限判死 —— 所以「合法、活着、但 `W` 秒没有心跳」的段今天不可能
  在顶层运行里存在，`stalled` 只会指向真正卡死（或守卫已经不在）的持有者。**未实测**：我没有把一次运行跑到
  §61b（P326 已把它移出普通入口，全量里它仍在第 #128 段），这条结论是从 §61b 正文与 `section_guard_watchdog`
  的 ticks 判据推出来的（V68 独立得出了同一条静态推断，两边都未实测）；apply 阶段若要证，只能用 `--select 61b`
  + 夹具旋钮降 cap（几分钟量级）。
- **「每轮重算」没有非计时的可证伪判据（实施阶段未解决项）。** 合同与 §2 判据 2 要求 `state`/上限每轮重算，但现有
  输出只能证明「此刻认定的上限」：只缓存的实现在持有者停跳后照样写 `心跳已停`，差别只在真实 elapsed —— 拿它做
  判据就是墙钟带（本 change 不采用）。所以这条行为在 apply 阶段靠**代码结构**（上限每轮从记录现算）与**独立审阅
  核对循环内的调用点**保证，不是靠断言；若到时候仍无非计时判据，报告里写明这个缺口，不声称已杀死缓存反例。
- **心跳是 mtime。** 第三方把运行临时根删了（`tmp-hygiene.sh` 的清理）→ 文件不在 → `state=none` → 退回 `W`：
  保守，不假装有进展。
- **`expected` 仍会被写成 0。** 那是诊断字段的现状（P316 之后没有生产者），本 change 不再让它决定任何事；
  彻底退役它要另改一条 requirement。
- **没碰**：`TEAM_SMOKE_LOCK_WAIT`（1800）与 `4×` 的默认值、CI 的 60 分钟、`TEAM_REVIEW_TIMEOUT` 的
  `queued/ran/limit` 记账、判定词闭集、`TEAM_SMOKE_FAST`（它按契约不排队，`no_lock=1`，本 change 与它无关）。
