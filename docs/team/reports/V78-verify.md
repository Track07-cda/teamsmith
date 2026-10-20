# V78 · P338 的独立验收：等待者的耐心跟随心跳，且没读墙钟

agent: verify   status: PASS（第二轮：五件返修全部落地且各自可判红；两条要改的话见第二轮 F1/F2）
               time: 2026-10-20T14:30Z（第一轮 12:52Z，那轮的唯一红是既有 flake §34b⑫）
branch: `task/V78-waiter-patience-verify`（local 模式，未 push）   PR/MR: -
受检：第二轮候选 `55417d2f`（增量 `c9869dc8..55417d2f`）；第一轮受检 `c9869dc8`（实现 `4f11ede7`）。
作者报告 `docs/team/reports/P338-dev-bob.md`（第二轮看它的 §0 返修表）。

## 结论（先看这里）

**A（规则对不对、能不能喂值验证）：成立。** `gate_lock_patience <lock> <W>` 是纯函数：唯一的时钟来源是既有的
`gate_lock_now`，心跳的「时间」是文件的绝对 mtime（读进来只做减法），进程存活判据走 `/proc` 的 pid+starttime，
全函数没有第二处 `date`。我自写的 11 条喂值断言（自己的夹具、手写的记录、钉住时刻、`touch -d @<epoch>` 写绝对
mtime）在候选上全绿：新鲜 → `live`/`4W`；`silent > W` 与 `silent == W` 两侧都 → `stalled`/`W`；记录没有心跳
字段 → `none`/`W`；同一份等待在心跳更新后给出**更晚**的截止、心跳停跳后又落回 `W`。另加一条纯度探针：
钉住 `now` 的同一输入、真实过 1.1 s，读数逐字不变 —— 读墙钟的实现会差 1 s。

**B（旧记录行为逐字未变）：三个现场逐个相同。** 同一份现场（无 `heartbeat=` 字段 / `heartbeat=-` / 公布的
文件不在）在 `main`（今天的 `gate_lock_cap`）与候选（`gate_lock_patience`）上读数完全一致，`W=1800` 与 `W=100`
两种取值都是：`1800/1800/1800` 与 `100/100/100`。唯一一处差异出现在**故意跨规则**的第四条现场（记录带
`expected=400`、`started` 在 120 s 前、`W=100`）：今天 `340`（`clamp` 投影），候选 `100` —— 这正是本 change
要换掉的那条规则，不是回归；默认 `W=1800` 时这一条两边也都是 `1800`。

**C（README 级的诚实性）：delta 与断言基本逐条对得上，但有两条要找的行不存在，另有一处规格比测试薄。**
找不到对应断言的两条是：① delta 明写「`heartbeat=-` 的记录 → 上限 `W`」，而 `⑨b` 的腿里没有 `heartbeat=-`
单独成立的现场（只有「没有该字段」与「文件不在」）；② delta 明写失败行要说「心跳是停了还是从未公布过」，
而 `none` 的那句话（`没有可用心跳`）没有任何断言 —— `gate_lock_patience_note` 的三个分支里 `none` 是全树
唯一没有断言覆盖的分支。**作者说「delta 一字未改、每条都能在断言里找到对应行」这句要打一个折扣**：上面两条
就是找不到的。第三处是反方向的：delta 把「失败行点名 `kind`/席位/工作树/已跑时长/`expected`」整段删掉了，
而 `§34b⑦` 仍在断言那批字段（`smoke.sh:16713-16714`）—— 测试比规格严，`kind` 这类字段从此只由测试守着。

**D（写集扩大是否都由改动蕴含）：四个文件都在且都被蕴含，没有顺手改动；但留了三处残渣。**
`cmd-review.sh` 与 `perf.sh` 都是被删函数 `gate_lock_cap_pair` 的调用方，改它们是被迫的；`protocol.md`
是排队上限的规范描述，删掉旧算式就必须改；`loop-inventory.tsv` 的两处（改了第 503 行那条的说法 + 新增心跳
写入器一行）都是 `--loop-check` 强制的，并且**新循环确实有界**：`p338_release` 在每次等待后 `kill`+`wait` 它，
循环自身的 `printf … || exit 0` 也会在临时根消失时自退（`--loop-check` 在合并现场 86/86/86，见 §6）。残渣：
`cmd-review.sh:1101` 还声明着三个死 `local`
（`cap_remaining cap_expected cap_started`），同一次改动引入的三个新变量 `lock_pat/lock_silent/lock_hb`
**没有声明 `local`**（其中 `lock_hb` 根本没被读过）；`smoke.sh:572` 与 `:650` 两处注释仍写「expected=0，
cap 退回 W」—— 那句描述的上限算式已经不存在了。

**断言密度（任务书的另外两件之一）：15 条分支表里 4 条没有独立判别力。** `W=10 → 40` 与 `W=1000 → 4000`
是同一个判断的第二个样本；三条「就该结束 / 继续等」把产品的 `elapsed >= cap` 判断**在测试里重写了一遍**
（`$([ "$P338_E" -ge "$P338_C1" ] && …)`），只会在它们的双胞胎（值断言）已经红的时候才红 —— 正是「夹具守
代码分支而不是守行为」的形状。更要紧的一点：**挂着 G3 名字的那条「后一次给出的截止比前一次晚」不会判红
「排队时缓存」**。作者的构造里第 2 轮的截止用了 `now-E+C2`，即等待起点跟着 `now` 一起前移；缓存实现给出
`C2=100` 时 `P338_D2 = PIN+150-150+100 = PIN+100` 仍大于 `P338_D1 = PIN-50`，于是照样打印「更晚」。我把
起点固定成同一个 `S`（同一份等待、已等从 150 s 长到 300 s）之后它才会红（见 §5）。「4 条没有独立判别力」
和「G3 那条不判红」不是推断，是把作者自己的 15 条断言抽出来跑出来的（§5 末）：在只缓存上限的变异下红的
正好是 ⑤（边界）、⑪（第 2 轮的值）、⑫（第 2 轮的决策），**⑬（G3 那条）不在其中**。

**不许用墙钟（另外两件之二）：新增断言里没有。** 新增的断言没有一条是「睡 N 秒再比较时间区间」，也没有
`elapsed >= 某个秒数`；唯一的真实时间只决定**持有者何时释放**（`p338_hold 6` / `sleep 20`），判据是「它拿到
了锁 / 它 exit 2」这个单向界。§34b⑭ 里 W=2、持有者 6 s 后释放，正是这个单向界，不是时间断言。

**实证（必须做的）：`--select 34,34b` 在候选上跑了，`✓159 ✗1`、rc=1 —— 唯一的红是任务书预先点名的既有 flake
`§34b⑫`，本 change 的 27 条新断言全绿；红侧在私有副本里把「每轮重算」改成「排队时缓存一次」之后，我 A 组的
「截止更晚」那条按要求变红，还原（字节相同）即绿。** 见 §4、§5。

**PM 要知道的一条合并事实：候选的基点比今天的 `main` 少了 `c4664509`（P337 的循环清单修复）及其后的账本
提交。** 候选树跑 `section-guard.sh --loop-check` 有 1 条红（`loop-inventory.tsv` 第 30 行的 `R_WAIT` 锚点还是
旧的单行写法），`main` 上**已经绿了**。作者报告把这处写成「改前就有的漂移、留给 PM」，那是他基点上的实况；
合并后它自己会消失 —— 但**谁也别照着候选的清单去“修”那一行**。我在私有副本里造了合并现场验证：
main 的树 + 候选的改动 → `--loop-check` 绿（86/86/86）。

## 第二轮（2026-10-20T14:30Z）· 候选 `55417d2f` 的五件返修

增量 `c9869dc8..55417d2f` 只动四个文件（`cmd-review.sh` / `smoke.sh` / delta / 作者报告），**产品库
`gate-lock.sh` 一个字节未变** —— 所以第一轮的 A 组、B 组读数在新候选上逐字相同（我又跑了一遍）。

**结论：五件全部落地，而且每一件都有我自己制造的「该红」实证（下表）。两条要改的话见 F1/F2，都不涉及
产品行为。**

| # | 作者处置 | 我的复核（命令与读数） |
|---|---|---|
| 1 · 三个死 `local` + 没声明的新变量 | `b24cb317`：`local lock_wait lock_pat lock_silent`，读到的第四个字段改 `_` | `grep -n 'cap_remaining\|cap_expected\|cap_started\|lock_hb' cmd-review.sh` → **无输出**（rc=1）。另核 `lock_cap` 仍是函数级 `local`（`:1036` 的 `local … lock_cap=""`），没有因为删掉那三个名字而泄漏成全局。**注**：死 `local` 没有行为，这条只能是静态判据，造不出真红。 |
| 2 · 两处注释还写着已不存在的 cap 算式 | `ad9e7046`：两行都改成「诊断字段……只看心跳」 | 新树上 `grep -n 'cap 退回 W\|P316 之后没有生产者'` → **无输出**（rc=1）。同上，静态判据。 |
| 3① · delta 写了 `heartbeat=-` → W，但没有腿 | `ad9e7046`：`p338_scene "-"` → `100\tnone\t-\t-` | **定向变异**：让 `-` 被读成「刚刚还在动」（`gate_lock_heartbeat_newest` 里给 `-` 特判成 now）→ **恰好那一条红**（期望 `100 none - -`，实际 `400 live 0 -`），其余 11 条全绿。这条腿有唯一判别力。 |
| 3② · 「从未公布过」那句没断言 | `ad9e7046`：⑭ 加第三个现场（`heartbeat=-`、W=2） | **自写 e2e**（私有锁 + 伴生锁上的真持有者 + `heartbeat=-` 记录 + 真 `smoke.sh` 入口）：未变异 → rc=2、失败行含「没有可用心跳」、不含「心跳已停」；把 note 的 `none` 分支改成「心跳已停（从未公布过）」→ 后两条红，真实失败行：`排队超限：等满 2s（… 已跑 122s expected=400 bound=2400；心跳已停（从未公布过））`。 |
| 4 · delta 把失败行要点名的字段整段删了 | `06afde50`：补回那一句 | delta 里那句回来了且与 §34b⑦ 的断言一致（kind / 席位 / 工作树 / 已跑时长 / `expected`+`bound`）；「`4 × W` 硬顶」那句没有被挤掉；`$HOME/.bun/bin/openspec validate --all --strict` → **21/21**。 |
| 5 · 分支表 15 → 12 条 | `ad9e7046`：删 4 条（W−1 / silent=10(W=5) / W=10→40 / 第 1 轮就该结束） | 实测 12 条全绿。三条删除确认无损：`W=10→40` 与 `W=1000→4000` 同一个判断；`silent=10` 的精确值由边界（100）与 G3 的 120/100 承担；「第 1 轮就该结束」与第 3 轮同一判断。**第四条有实测缺口 → F2**。 |

### F1 · 这一轮新写的一句注释是错的（关于「什么会被缓存抓红」）

`smoke.sh` ⑧ 段新注释说：「缓存的实现在第 3 轮仍会说 4W（因而继续放行），**第 3 轮那两条断言就会红**」。
把两种「排队时缓存」变异打在**新的 12 条**上实测：

```
# 变体 A（整行缓存：上限 + state + silent）→ 4 条红
✗ ⑨b 心跳 mtime 恰好 W 秒前（边界）→ stalled、上限 W        （实际 400 live 0）
✗ ⑨b 每轮重算 · 第 2 轮（…心跳刚动过）→ live + 4W            （实际 100/stalled/120）
✗ ⑨b 每轮重算 · 第 2 轮继续等（已等 150 s < 硬顶 400 s）     （实际 超限）
✗ ⑨b 每轮重算 · 第 3 轮（…上限落回 W）                       （实际 100/stalled/120 —— 红在 silent_for，不是 4W）
# 变体 B（只缓存上限，state/silent 每轮重读 —— V68 点名的那一版）→ 3 条红
✗ ⑨b 心跳 mtime 恰好 W 秒前（边界）→ stalled、上限 W        （实际 400 stalled 100）
✗ ⑨b 每轮重算 · 第 2 轮（…心跳刚动过）→ live + 4W            （实际 100/live/10）
✗ ⑨b 每轮重算 · 第 2 轮继续等（已等 150 s < 硬顶 400 s）     （实际 超限）
# 两版里都绿的：⑨b 每轮重算 · 后一次给出的截止比前一次晚（⑬）
```

变体 B 下第 3 轮两条**都绿**（缓存的上限 100 = 现场本来该给的 100），所以「第 3 轮那两条断言就会红」
只对变体 A 的 `silent_for` 成立，对「缓存上限」这一侧不成立。真正抓红的是**边界腿 ⑤ 与第 2 轮那两条**。
建议把那句改成「被 ⑤ 与第 2 轮那两条抓住」；想让 G3 那条自己会红，得把我第一轮的构造拿回来
（把等待起点固定在同一个 `S`，别让起点跟着 `now` 一起前移）。

### F2 · 删掉的那条 W−1 腿是唯一落在「可用窗口内部」的样本

保留的两条是 `silent=0`（窗口最外）与 `silent=W`（边界那一侧），**窗口内部没有任何采样点**。实测：把边界
内移 10 s（`silent >= wait - 10`）后，12 条**全绿**（我自己的 A 组也全绿）。这是删腿带来的唯一一处实测
覆盖缺口。建议二选一：把 ④ 的 mtime 从「现在」改成 `W-1`（仍是 `live`/`4W`，但落在窗口内部），或在 ④ 旁边
补回一条 `W-1`。

### 第二轮的选段验收（`--select 34,34b`）

同一套场地（新候选的私有 clone，`HEAD=55417d2f`，`git status` 干净；跑前 `ps` 确认无别人的 `smoke.sh`）：

```
$ bash skills/teamsmith/tests/smoke.sh --select 34,34b        (14:18:02Z → 14:25:18Z)
… ✗ 34b⑫ 收尾：登记随它退出消失（只删自己那条）（期望 [1]，实际 [0]）
✓ 34b⑭ 没有可用心跳（heartbeat=-）→ exit 2
✓ 34b⑭ 失败行说「没有可用心跳」（不是「心跳已停」）
✓ 34b⑭ 两种卡死原因不混为一谈
#5 34  · 门禁锁：排队/运行分开记账 · 参考 用时 66s  · ✓35  ✗0 SKIP0
#6 34b · 门禁锁排队守卫：超上限要大声失败 · 参考 用时 348s · ✓101 ✗1 SKIP0 · ticks 102
== 选段结果 ==  ✓ 159  ✗ 1      (rc=1)
```

- 三个新断言在**真门禁里**也是绿的（不只是我的 e2e）。
- 唯一红仍是 `§34b⑫`（348 s 里 300 s 是它自己的等待；P339 在修、尚未并入）—— 与第一轮同一个形状，
  不算本次增量的缺陷，也没有为了凑绿重跑。
- `ticks 102` 与作者报告「§34b 仍是 102 条（删 4 加 4）」一致；静态 `assert_` 调用点在 12 条腿的新表上
  仍是 97 处（与 `c9869dc8` 相同）。

### 第二轮的轻量收口

```
$ for f in scripts/lib/gate-lock.sh scripts/lib/cmd-review.sh tests/smoke.sh; do bash -n skills/teamsmith/$f; done   → 三个 ok
$ bash skills/teamsmith/tests/section-select.sh --check        → == 选段自检 ==  ok 9  bad 0  SKIP 1   (rc=0)
$ $HOME/.bun/bin/openspec validate --all --strict              → Totals: 21 passed, 0 failed   (rc=0)
$ git diff --check c9869dc8 55417d2f                           → 无输出 (rc=0)
```

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/V78-verify.md` | 本复验报告（唯一的写入） |

受检对象（只读）：`skills/teamsmith/scripts/lib/{gate-lock.sh,cmd-review.sh}`、
`skills/teamsmith/tests/{smoke.sh,perf.sh,loop-inventory.tsv}`、`skills/teamsmith/references/protocol.md` @ `c9869dc8`，
以及 `openspec/changes/gate-waiter-patience/**` 的 delta。

## Verification evidence （都是我真跑过的）

运行场地：`/var/tmp/v78-<pid>/`（候选 `git archive c9869dc8`、main `git archive main`、一份候选的
`git clone` 用于跑门禁 —— 都不在项目树里）。所有命令的工作目录都是那份副本。

### 1 · A：纯函数与喂值（自己的夹具，不抄作者）

夹具手写一条新格式记录（`pid=$$`、`start` 从 `/proc/$$/stat` 取，记录因此是「活着的」），时刻只从
`gate_lock_now` 来（子 shell 里局部覆写它），心跳 mtime 用 `touch -d @<epoch>` 写成绝对值。

```
$ bash /var/tmp/v78-a.sh <候选>/skills/teamsmith/scripts/lib/gate-lock.sh
PASS  A1 心跳 mtime=现在（silent=0，W=137）→ 4W=548 / live / heartbeat 路径
PASS  A2a 心跳停了 101 s（> W=100）→ 判卡死、上限 W、silent 是准确值
PASS  A2b 心跳恰好停了 W=100 s（边界）→ 归卡死侧、上限 W
PASS  A3 旧形状记录（根本没有 heartbeat 字段，W=100）→ 上限 W
PASS  A3b 同上，state/silent 如实说「没有」（不编一个状态）
PASS  A4a 第 1 轮（心跳停了 120 s、已等 150s）→ 卡死、上限 W
PASS  A4b 第 2 轮（同一份等待、更晚的时刻、心跳刚动过）→ live、上限 4W
PASS  A4c 心跳更新后截止更晚（S+100=1789999950 → S+400=1790000250）
PASS  A4c2 第 2 轮继续等（已等 300s < 硬顶 400s）
PASS  A4d 第 3 轮（心跳不再动、从它最后一动起又过了 W）→ 上限落回 W（缓存的 4W 会继续放行）
PASS  A5 钉住 now 的同一输入、真实过了 1.1 s → 读数逐字不变（时间只从 gate_lock_now 来）

A: 0 条不成立        (rc=0)
```

- `A1` 用 `W=137`（不是整数十），`4W=548` 是等号断言 —— 抓整数化的实现。
- `A2a/A2b` 是同一侧的两个点：`silent > W` 与**恰好** `silent == W`，边界只归「不可用」一侧。
- `A4` 与作者的构造**不同**：等待起点 `S` 固定（同一份等待），时刻往前走，所以「已等」从 150 s 长到 300 s；
  作者那版第 2 轮的起点跟着 `now` 前移，见上面结论里的密度那一段。

### 2 · B：旧记录在 `main` 与候选上的前后读数

```
$ bash /var/tmp/v78-b.sh <main>    cap       # 今天的 gate_lock_cap
$ bash /var/tmp/v78-b.sh <候选>    patience  # 候选的 gate_lock_patience
S1-no-heartbeat-field	1800	1800      S1-no-heartbeat-field	1800	1800
S2-heartbeat-dash	1800	1800      S2-heartbeat-dash	1800	1800
S3-heartbeat-file-gone	1800	1800      S3-heartbeat-file-gone	1800	1800
S4-expected-400-started-120s-ago	1800	1800   S4-expected-400-started-120s-ago	1800	1800
S1-no-heartbeat-field	100	100       S1-no-heartbeat-field	100	100
S2-heartbeat-dash	100	100           S2-heartbeat-dash	100	100
S3-heartbeat-file-gone	100	100       S3-heartbeat-file-gone	100	100
S4-expected-400-started-120s-ago	100	340   S4-expected-400-started-120s-ago	100	100
                                     ^ 唯一差异：S4 是**故意**跨规则的那条（见结论 B）
```

三个旧记录现场（`S1/S2/S3`）在两种 `W` 下逐个相同。同一现场的排队行文案，今天与候选：

```
main · 排队行：1800（算式：remaining=-s + 60s → cap=1800s，下限 TEAM_SMOKE_LOCK_WAIT=1800s，上限 4×=7200s…）
候选 · 排队行：1800（没有可用心跳；下限 TEAM_SMOKE_LOCK_WAIT=1800s，上限 4×=7200s…）
```

上限一字不差（`1800`）；括号里的解释按 delta 的要求从「算式」换成「心跳状态」。所以准确的说法是：**耐心上限
逐字未变，文案多一句/换一句**（作者报告自己写的是「行为与今天逐字相同 …… 只多一句『没有可用心跳』」，两个
半句都对；我把它拎出来写明，是因为任务书 §B 的判据是「三个读数逐个相同」，而读数确实相同）。

### 3 · C：delta 的要求 → 断言（逐条，含找不到的）

| delta 的要求 | 对应断言（候选 `tests/smoke.sh`） | 结论 |
|---|---|---|
| 上限跟着心跳，不再是 `expected` 的投影 | `§34b⑨b`（`:16768-16820`，夹具记录写 `expected=400`、`started` 在 120 s 前，`W=100` 仍给 `100`；旧算式给 `340`，见 B 的 S4） | 成立 |
| 从**任一**活登记读心跳（`.holder` 或 `.runs/*.run`） | `§34b⑭①`（`:17097-17102`，持有者记录 `heartbeat=-`，活心跳在子登记里） | 成立 |
| 可用 = 最后一动在 `W` 秒内；`>= W` 算不可用；边界归「不可用」 | `§34b⑨b ④⑤`（`:16780`、`:16784`，`W-1` 与**恰好** `W` 两侧） | 成立 |
| 可用 → 上限 `4×W`，且**不能**超过 | `§34b⑨b ③⑦⑧`（`:16776`、`:16792`、`:16794`） | 成立（是准确值；没有真等 4W 的现场，见下方备注） |
| 不可用 → 上限 `W`，四种来源：旧写入者 / `heartbeat=-` / 文件不在 / `silent >= W` | 旧写入者 `:16768`；文件不在 `:16772`；`silent >= W` `:16784`、`:16788`。**`heartbeat=-` 单独成立 → `W`：无对应行** | **找不到（C-1）** |
| 每轮重算；排队行同时打印两条上限与心跳状态 | 重算：`:16804-16820` 的三轮；打印两条上限 + 状态：`§34b⑭①`（`:17099-17100`） | 成立 |
| 撞上限的失败行点名持有者，并说出**心跳停了还是从未公布过** | 点名持有者 + `心跳已停`：`§34b⑭②`（`:17111-17112`）。「从未公布过」那句（`没有可用心跳`）**没有任何断言**；`gate_lock_patience_note` 的 `none` 分支是全树唯一没被断言覆盖的分支 | **找不到（C-2）** |
| `expected`/`bound` 仍在记录里、仍被打印，但**不**决定耐心 | 记录里：`§34b②`（`:16615-16616`）；打印：`§34b⑦`（`:16713-16714` 断言两行都点名 `expected`/`bound`）；不决定：`⑨b` 的 `expected=400` 现场 | 成立 |
| （delta 已删除）失败行点名 `kind`/席位/工作树/已跑时长/`expected` | **测试仍在断言**（`§34b⑦`，`:16713-16714`） | **反方向不一致（C-3）** |
| 一个真 review 的持有者记录 `heartbeat=-`、它生的运行在动 | `§34b⑭①` 用的就是这个布局 | 成立 |

备注（不是缺口，但要记）：delta 的两个场景「移动的心跳不能买无限等待」与「真的 review 形状」在门禁里只有
**上限准确值**（`4W`）与**真实排队路径**两层证据，没有一次「心跳连动超过 4W 然后按时判死」的真等现场 ——
那需要 4×W 秒的真实时间，按本仓既有纪律（不靠秒数判行为）不值得造。判死那一侧由 `E >= cap` 的决策与
`⑨b` 的准确上限值共同构成。

### 4 · `--select 34,34b` 在候选上

场地是候选的私有 clone（`git clone --single-branch --branch task/P338-waiter-patience-apply`，`HEAD=c9869dc8`，
`git status` 干净；跑之前 `ps` 确认没有别人的 `smoke.sh`）。

```
$ bash skills/teamsmith/tests/smoke.sh --select 34,34b        (12:40:31Z → 12:47:45Z)
… ✗ 34b⑫ 收尾：登记随它退出消失（只删自己那条）（期望 [1]，实际 [0]）
#5 34  · 门禁锁：排队/运行分开记账 · 参考 用时 66s  · ✓35  ✗0 SKIP0
#6 34b · 门禁锁排队守卫：超上限要大声失败并点名持有者 · 参考 用时 347s · ✓101 ✗1 SKIP0 · ticks 102
账本自查： 6 段收口 · 增量 ✓159 ✗1 ｜ 结果行 ✓159 ✗1 —— 一致
== 选段结果 ==  ✓ 159  ✗ 1      (rc=1)
```

- **唯一的红是 `§34b⑫ 收尾：登记随它退出消失（只删自己那条）`** —— 任务书预先点名的既有 flake（已有另一席
  在查）。66 秒的 §34 全绿；§34b 的 347 s 里 300 s 就是这条 flake 自己的等待上限（`for _i in $(seq 1 1500); … sleep 0.2`），
  与作者报告里那次 345 s 的红是同一个形状，**本 change 不碰那两个函数**（`gate_lock_register_run` /
  `gate_lock_remove_run` 逐字节未改）。
- 本 change 的 27 条新断言（`⑨b` 15 + `⑭` 12）**一条不红**，包括 `⑭` 的那条真实排队路径。
- 所以这条命令的结论是「与本次改动相关的全绿、rc 非 0 来自一条与本改动无关的既有 flake」，不是「全绿」。
  任务书要求「遇到它红时如实记录、不要算成本次改动的缺陷」，我按这个口径记，并且**没有**为了凑绿重跑。

### 5 · 红侧：把「每轮重算」改成「排队时缓存一次」

私有副本里给 `gate_lock_patience` 包了一层「第一次算出的那一行写进缓存，此后每轮复用」（`bash -n` 通过；
被改的只有这一处）：

```
$ V78_PAT_CACHE=… bash /var/tmp/v78-a.sh <变异副本>/…/gate-lock.sh
FAIL  A4b 第 2 轮（同一份等待、更晚的时刻、心跳刚动过）→ live、上限 4W :: 期望 [400] 实际 [100]
FAIL  A4c 心跳更新后截止更晚（S+100=1789999950 → S+100=1789999950） :: 期望 [更晚] 实际 [没有更晚]
FAIL  A4c2 第 2 轮继续等（已等 300s < 硬顶 100s） :: 期望 [继续等] 实际 [超限]
A: 3 条不成立        (rc=1)

$ # 还原：把候选的 gate-lock.sh 原样拷回
$ cmp -s <候选>/…/gate-lock.sh <变异副本>/…/gate-lock.sh && echo byte-identical
byte-identical
$ bash /var/tmp/v78-a.sh <还原后的副本>/…/gate-lock.sh
A: 0 条不成立        (rc=0)
```

A1/A2/A3/A5 在这个变异下不变红（它们都是单轮读数），**只有 G3 那一组红** —— 这正是这条变异该有的形状。

再把**作者自己的 15 条断言**（从候选 `smoke.sh:16748-16822` 原样抽出来，只补 `ok/bad/assert_eq` 与
`$P281D/$P281_LOCK`）打在同一个变异上。为了让变异是「同一个等待者」而不是「同一把锁」：缓存的键是
`(锁, W)`，并在写新的持有者记录时丢弃缓存（新的排队）。两个变体都跑：

```
# 变体 A：把整行（上限 + state + silent）缓存起来
FAIL  34b⑨b 心跳 mtime=W-1 秒前 → state=live、上限 4×W、silent_for=W-1        （silent=0，缓存的）
FAIL  34b⑨b 心跳 mtime 恰好 W 秒前（边界）→ state=stalled、上限 W、silent_for=W
FAIL  34b⑨b 每轮重算 · 第 2 轮（…心跳刚动过）→ live + 4W                    （实际 [100/stalled/120]）
FAIL  34b⑨b 每轮重算 · 第 2 轮继续等（已等 150 s < 硬顶 400 s）
FAIL  34b⑨b 每轮重算 · 第 3 轮（…上限落回 W）                                 （上限对、silent_for 还是 120）
5 条不成立            ← 对照组（未变异、同一套抽取）0 条不成立

# 变体 B：**只**缓存排队时算出的上限，state/silent 每轮重读（V68 点名的那一版）
FAIL  34b⑨b 心跳 mtime 恰好 W 秒前（边界）→ state=stalled、上限 W              （实际 [400 stalled 100]）
FAIL  34b⑨b 每轮重算 · 第 2 轮（…心跳刚动过）→ live + 4W                     （实际 [100/live/10]）
FAIL  34b⑨b 每轮重算 · 第 2 轮继续等（已等 150 s < 硬顶 400 s）
3 条不成立
```

两个变体里，**⑬「后一次给出的截止比前一次晚」都绿**，`⑭`/`⑮`（第 3 轮）在变体 B 下也绿 —— 也就是「缓存
的上限」那一侧真正被抓住的是**值断言**（⑤/⑪），挂着 G3 名字的那条抓不住。这不是要退回，是要知道门禁的
真实覆盖在哪。

### 6 · 轻量收口

```
$ for f in scripts/lib/gate-lock.sh scripts/lib/cmd-review.sh tests/smoke.sh tests/perf.sh; do bash -n skills/teamsmith/$f; done
ok   skills/teamsmith/scripts/lib/gate-lock.sh
ok   skills/teamsmith/scripts/lib/cmd-review.sh
ok   skills/teamsmith/tests/smoke.sh
ok   skills/teamsmith/tests/perf.sh

$ git diff --check 4f11ede7~1 c9869dc8
（无输出，rc=0）

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 9  bad 0  SKIP 1          (rc=0；SKIP 是行 19 的 `.pi/skills` 检出形状，既有)

$ bash -lc 'command -v openspec'
（空）→ openspec 不在登录 shell 的 PATH 上
$ $HOME/.bun/bin/openspec validate --all --strict
✓ spec/watchdog  ✓ spec/writing-discipline
Totals: 21 passed, 0 failed (21 items)       (rc=0；入口是绝对路径，version 1.8.0)

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file <项目 common dir 的 .pi/team/forbidden-names.txt>
ledger-ban: … files=1917 hits=0 names=ok user=resolved        (rc=0)
```

合并现场的 `--loop-check`（见结论里那条合并事实；main 的树 + 候选的 `skills/` 改动，私有副本里 `git apply`）：

```
$ bash skills/teamsmith/tests/section-guard.sh --loop-check      # 候选自己：1 条红
bad: smoke.sh:6397 的 while 行与清单第 30 行的锚点不符
     源码：  while [ "$R_WAIT" -lt "$R_MAX" ]; do
     清单：  while [ "$R_WAIT" -lt 1500 ] && ! $TEAM roster …
ok: 扫描 86 行清单 / 86 个 while+sleep 循环，配平 86 个

$ bash skills/teamsmith/tests/section-guard.sh --loop-check      # main：绿
ok: 扫描 85 行清单 / 85 个 while+sleep 循环，配平 85 个

$ bash skills/teamsmith/tests/section-guard.sh --loop-check      # main + 候选改动：绿
ok: 扫描 86 行清单 / 86 个 while+sleep 循环，配平 86 个
$ grep -n 'R_MAX\|心跳写入器' skills/teamsmith/tests/loop-inventory.tsv
47:smoke.sh<TAB>6392<TAB>cap="$R_WAIT" -lt "$R_MAX"<TAB>  while [ "$R_WAIT" -lt "$R_MAX" ]; do
59:smoke.sh<TAB>17067<TAB>bound=心跳写入器（§34b⑭ 的现场）…
```

（`ledger-ban` 先在候选的副本里跑（名单取本仓 common dir 里那份，`files=1917 hits=0`），写完本报告后在**本分支
的树上**又跑了一次固定验收行：`files=1925 hits=0 names=ok`，rc=0 —— 副本自己的 `.git` 边上没有 `.pi/team/`，
用副本的路径会 `names=missing` 并 rc=3，那不是「通过」。）

## Flip evidence（红 → 绿）

| 被破坏的 | 该红的 | 实跑 |
|---|---|---|
| 「每轮重算」→「排队时缓存一次」 | A 组里「心跳更新后截止更晚」那条 | 红：`A4c 期望[更晚] 实际[没有更晚]`（连带 `A4b`、`A4c2`）；还原后字节相同、0 条不成立 |
| 同上，打在**作者自己的** 15 条上（变体 A / B） | 上限值那一侧（⑤/⑪/⑫） | 红：变体 A 5 条、变体 B 3 条；两版里 G3 那条都绿（见 §5） |

## Decisions and deviations

- 任务书 §A 要「自己写四条喂值断言」：我写了 11 条（多了 `silent > W` 与 `silent == W` 的分侧、`4W` 的两个
  准确值、以及一条纯度探针）。`A4` 的**构造**与作者不同（起点固定、已等随时刻增长），原因见结论里的密度段。
- 任务书 §B 说「三个读数必须逐个相同」：我按「上限（耐心）」这一读数比，另把排队行文案并排贴出来 —— 文案
  **确实**变了（算式 → 心跳状态），这是 delta 要求的，不算回归；作者报告自己也写了「只多一句」，我把它
  记成「上限逐字未变、文案换了一句」而不是笼统的「一字不改」。
- 我不判断 §34b⑫ 的既有 flake（任务书明说不算本次缺陷）；本次 `--select 34,34b` 的实测见 §4。
- 第二轮只核了 PM 点的五件 + 一次 `--select 34,34b`，每件自己造了「该红」（F1/F2 那两条是它们的例外：
  1 与 2 是死代码/注释，造不出行为级 flip，只能静态判据）。第一轮的 A/B/C/D 结论在新候选上仍然成立（产品
  库逐字节未变）。
- 我没有改实现、没有合并、没有 push；写集只有本报告与自己的线程。

## Suggested next steps（都只报，不改）

第二轮已收掉下面的 1、2、4、5 前三条与 5 的删除本身；现在剩下的只有第二轮 F1（一句注释）与 F2（一条采样腿），
以及 6（真 review 形状的端到端）。下面的编号保留第一轮原文，方便对照作者报告里那五件的处置。

1. **C-1 / C-2 补两条腿（作者工作量很小，判据都是喂值）**：`heartbeat=-` 单独成立 → `(W, none, -, -)`；
   以及 `gate_lock_patience_note none` → `没有可用心跳`。前者防「`-` 被当成路径再去 stat」这类改动无感，
   后者是失败行文案里唯一没人守的一句。
2. **C-3**：delta 既然把「失败行点名 `kind`/席位/工作树/已跑/`expected`」删了，要么在 delta 里留一句
   （测试仍在守它），要么在后续 change 里连测试一起收；两处不一致时，档案里的规格会比门禁弱。
3. **密度**：`⑧`（`W=10 → 40`）可删（与 `W=1000 → 4000` 同一个判断）；三条「就该结束 / 继续等」是把
   产品的比较写在测试里，建议合并成一条对**产品输出**的断言，或直接留给 `§34b⑭` 的真实路径。
4. **残渣**（不构成退回，建议顺手）：`cmd-review.sh:1101` 三个死 `local` + 三个没声明 `local` 的新变量
   （`lock_hb` 从未被读）；`smoke.sh:572`/`:650` 两处注释里的「cap 退回 W」。
5. **合并时**：别拿候选的 `loop-inventory.tsv` 覆盖 main 的（候选基点没有 P337 的 `c4664509`）；合并后
   `section-guard.sh --loop-check` 应当是 86/86/86。
6. **真 review 形状**（作者 §8 自己列的缺口）：本 change 值得在后续补一次「`team review` 排队时读到子运行
   的活心跳」的端到端现场；今天 `cmd-review.sh` 的排队点与 `smoke.sh` 读的是同一个函数，风险低但无证据。
