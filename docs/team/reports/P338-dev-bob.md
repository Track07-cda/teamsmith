# P338 · apply：等待者的耐心跟随持有者心跳（`expected` 投影退场）

agent: dev-bob   status: delivered   time: 2026-10-20T12:40Z
branch: `task/P338-waiter-patience-apply`   phase: apply   change: `gate-waiter-patience`
判据锚：`verification#A waiter's patience follows the holder's heartbeat, not a budget nobody publishes`
写集：`skills/teamsmith/scripts/lib/gate-lock.sh`、`skills/teamsmith/scripts/lib/cmd-review.sh`、
`skills/teamsmith/tests/smoke.sh`、`skills/teamsmith/tests/perf.sh`、`skills/teamsmith/references/protocol.md`、
`skills/teamsmith/tests/loop-inventory.tsv`（一行，见 §4 末）
+ 本报告。`openspec/changes/gate-waiter-patience/` 只按 V78 的第四件补了一句（见 §0 与 §5），
别的 change 目录一个没动。
提交：`4f11ede7`（产品 + 断言）、`ab622e4b` / `c9869dc8`（本报告与补充）、`1f4d8360`（循环清单一行）、
`b24cb317`（V78 返修 1：死 `local`）、`ad9e7046`（V78 返修 2/3/5：两处注释、两条新断言、四条冗余腿）、
`06afde50`（V78 返修 4：delta 补回失败行要点名的字段）、`55417d2f`（返修记录）、`9fcaa9d2`（第三轮 F1+F2：
⑧ 的注释改成实测、④ 补回窗口内部采样点）

## 结论先写

- **新规则的四条喂值断言全部成立**，且都是等号断言（钉住时刻 + 绝对 mtime，不测秒）：心跳新鲜 → `live`/`4W`；
  心跳刚过期（含 `silent == W` 这一侧）→ `stalled`/`W`；记录无心跳字段 → `none`/`W`；每轮重算 → 同一份等待
  状态在心跳更新后给出更晚的截止、心跳停跳后落回 `W`（G3）。
- **旧记录的行为与今天逐字相同**：`heartbeat=` 没有该字段、写着 `-`、或公布的文件不在 → `ceiling` **就是**
  传进来的 `W`，与改前 `gate_lock_cap` 在同一现场的读数一模一样（§4 的前后读数对照）。
- **`expected` 的投影分支退场**：`gate_lock_cap`（17 行）与 `gate_lock_cap_pair`（6 行）删除，换成
  `gate_lock_path_mtime` / `gate_lock_heartbeat_newest` / `gate_lock_patience` / `gate_lock_patience_note`；
  `expected`/`bound`/`sections` 仍写、仍打印（§34b② 仍绿），只是不再决定耐心。
- **选段验收 `--select 34,34b` 全绿**：`rc=0`、`✓160 ✗0`（§34 `✓35`、§34b `✓102`，改前 §34b 是 75 条断言点，
  本次 +27：分支表 15 条 + 真实路径 12 条）。
- 两次反向对照各只让**该被钉住的那几条**变红（§6）；一次既有 flake（§34b⑫）在四次运行里红过一次，
  与本改动无关（§8 记录）。

## 0 · 返修轮次（V78 五件）：逐件处置

V78 判 PASS，点了五处。这里是每一处的处置与证据；下面 §1–§8 是第一轮交付的原文，数字仍是**返修后**的口径
（§34b 断言点仍是 102 条：删 4 条、加 4 条）。

| # | V78 点名 | 处置 | 证据 |
|---|---|---|---|
| 1 | `cmd-review.sh:1101` 三个再也不写的 `local`，新增的 `lock_hb` 从没被读过 | `local lock_wait cap_remaining cap_expected cap_started` → `local lock_wait lock_pat lock_silent`；`read -r … lock_hb` → `… _`，`lock_hb` 这个名字从文件里消失 | `b24cb317`；`grep -n 'cap_remaining\|cap_expected\|cap_started\|lock_hb' skills/teamsmith/scripts/lib/cmd-review.sh` 无输出 |
| 2 | `smoke.sh:572`/`:650` 两处注释还写着已经不存在的 cap 算式 | 两处都改成：`# 诊断字段：P316 之后仍是 0，等待者的耐心不看它（只看心跳，见 gate_lock_patience）` | `ad9e7046`；`grep -rn 'cap 退回 W' skills/teamsmith/` 无输出 |
| 3① | delta 写了「`heartbeat=-` 的记录 → 上限 `W`」，⑨b 只有「没有该字段」「文件不在」两个现场 | 加一条纯函数腿：记录 `heartbeat=-`（`team review` 的持有者记录就是这个形状）→ `100\tnone\t-\t-` | `ad9e7046`；flip C 里它随「没有心跳也按 4W」一起变红 |
| 3② | `none` 那一支的说明文字全树没有断言 | ⑭ 加第三个现场：`heartbeat=-` 的持有者、`W=2` → `rc=2`、失败行说「没有可用心跳」、且**不**出现「心跳已停」 | `ad9e7046`；flip C 里两条都红 |
| 4 | delta 把「失败行点名 kind/席位/工作树/已跑时长/`expected`」整段删了，而 §34b⑦ 仍在断言它 | delta 补回那一句（只加这一条，别的没动） | `06afde50`；`openspec validate --all --strict` 21/21 |
| 5 | 分支表 15 条里 4 条没有独立判别力 | 删 4 条（下表），保留 12 条 | `ad9e7046`；§34b 仍 ✓102 |

### 删掉的四条：原文 → 处置 → 谁接管

| 原文（断言标题） | 处置 | 谁接管它原来的判别力 |
|---|---|---|
| `⑨b 心跳 mtime=W-1 秒前 → state=live、上限 4×W、silent_for=W-1` | 删（**第三轮已按实测推翻，见 §0b**） | 当时的理由是「mtime=现在 → live/4W」（新鲜侧）+「mtime 恰好 W 秒前 → stalled/W」（边界的另一侧）。验收实测这个理由不成立：它俩一外一内都贴着窗口的两端，**边界往里挪 10 秒时 12 条全绿**。现在这条采样点回来了（④ 的心跳 mtime 改成 `W-1`） |
| `⑨b 心跳停了 10 秒（W=5）→ state=stalled、上限 W、silent_for=10` | 删 | 上面那条边界腿（状态与上限是同一个判断，只是换了数字）；`silent_for` 的精确值由 G3 第 1 轮（120）与第 3 轮（100）承担 |
| `⑨b 新鲜心跳 + W=10 → 上限正好 40（硬顶 4×W）` | 删 | 「新鲜心跳 + W=1000 → 上限正好 4000」——同一条硬顶、换一个数字而已 |
| `⑨b 每轮重算 · 第 1 轮就该结束（已等 150 s >= 上限 100 s）` | 删 | 「第 3 轮就该结束」——同一判断，而第 3 轮是**必须从 4W 落回 W** 的那一轮，判别力更强 |

保留的 12 条：`none` 的三个现场（旧形状 / 文件不在 / `heartbeat=-`）、`live`、边界 `silent == W` → `stalled`、
硬顶 `4W` 的准确值，以及 G3 的三轮（判死 → 心跳更新后转活 → 再落回判死，含「第 2 轮继续等」与「截止更晚」）。

### flip C：两条新断言各自能红（改坏 → 变红 → 还原）

同一棵树，一次改两处：`none` 分支的 `ceiling` 由 `$wait` 改成 `$(( wait * 4 ))`（把「没有心跳」当成还活着，
这正是 delta 禁止的那条），`gate_lock_patience_note` 的 `*` 分支改成「心跳已停（未公布过）」（把两种卡死原因
混成一句）。`--select 34b` → **rc=1、✓116 ✗9**：

```
✗ 34b⑨ 旧持有者（没有心跳字段，也没有 expected）→ 上限仍是 TEAM_SMOKE_LOCK_WAIT（期望 [1800]，实际 [7200]）
✗ 34b⑨b 旧形状记录（没有 heartbeat 字段）→ state=none、上限仍是 W（期望 [100 none - -]，实际 [400 none - -]）
✗ 34b⑨b heartbeat= 指向不存在的文件 → state=none、上限 W（期望 [100 none - -]，实际 [400 none - -]）
✗ 34b⑨b heartbeat=- （记录明说不公布心跳）→ state=none、上限 W（期望 [100 none - -]，实际 [400 none - -]）
✗ 34b⑨ 锁被活着但不是祖辈的进程持有 → 证明不成立 → 照旧排队（exit 2）（期望 [2]，实际 [0]）
✗ 34b⑨ 它照旧排队并撞上限（… 中找不到 [排队超限]）
✗ 34b⑭ 失败行说「没有可用心跳」（不是「心跳已停」）（… 中找不到 [没有可用心跳]）
✗ 34b⑭ 两种卡死原因不混为一谈（不该出现 [心跳已停]）
```

§34b⑨ 那两条是同一处改动的连带（它们的现场也是「没有心跳」，上限被撑到 8 s 于是不再撞限）。还原用
`git checkout -- skills/teamsmith/scripts/lib/gate-lock.sh`，`git status` 干净、两个原始分支的行逐字回位。
另一面：把 `gate_lock_heartbeat_newest` 的遍历范围砍到只读持有者记录，红的是 ⑭ 的四条（§6 的 flip A），
⑨b 全绿 —— 纯函数与真实路径这两层各有各的判据，不互相顶替。

### 0b · 第三轮返修（V78 第二轮 PASS 后只剩两条）

**F1 · 注释里有一句实测不符的假话，已按实测改写。** 我在 ⑧ 段写的是「缓存的实现在第 3 轮仍会说 4W（因而继续
放行），第 3 轮那两条断言就会红」。V78 第二轮把缓存变异打在这 12 条上量到的是另一回事：红的是**边界那条**与
**第 2 轮那两条**（`state`/`ceiling` 错，因为缓存还看得见第 1 轮那 120 s 的静默），**第 3 轮那条红在
`silent_for`**（缓存值 120，实测该是 100），它的状态与上限碰巧仍对。注释与本文 §2 的那句都按这个写法改了；
判据是三个字段，不是一句文案。

**F2 · 窗口内部补回采样点，并自己做定向变异证明它会红。** 删掉 `W-1` 那条之后，窗口里只剩 `silent=0`（最外）
与 `silent=W`（边界另一侧），V78 实测「把边界内移 10 秒，12 条全绿」—— 也就是说密度清理把一条真实覆盖切掉了。
采用它给的第一个选项：**④ 的心跳 mtime 从「现在」改成 `W-1`**（仍是 `live`/`4W`，但落在窗口内部）。选它而不是
「补回一条」，是因为它一条同时承担「新鲜」与「窗口内部」两件事，不再多一条只换数字的断言；最外那一点
（`silent=0`）本来就由 ⑭ 的真实路径（排队行 `0s 前更新`）与第 2 轮（`silent=10`）覆盖。

定向变异 = 把边界从 `silent >= W` 内移 10 秒（`-ge "$(( wait - 10 ))"`），`--select 34b` → **rc=1、✓96 ✗6**：

```
✗ 34b⑨b 心跳 mtime=W-1 秒前（窗口内部）→ state=live、上限 4×W、silent_for=W-1
      （期望 [400  live     99  …/p338-hb]，实际 [100  stalled  99  …/p338-hb]）
✗ 34b⑭ 心跳在动 → 等待者越过 W 也没被误杀（持有者比 W 晚释放，它仍拿到了锁：rc=0）（期望 [0]，实际 [2]）
✗ 34b⑭ 排队行说出上限来自活心跳（来自子登记，不是持有者记录）
✗ 34b⑭ 心跳在动时不报排队超限（不该出现 [排队超限]）
✗ 34b⑭ 它拿到锁后走到了子进程出口（真的取到锁）
✗ 34b⑫ 收尾：登记随它退出消失（只删自己那条）（期望 [1]，实际 [0]）   ← P339 那条既有 flake，不是本次
```

**新增/改动的那条自己红了**，而且红在 `state` 与 `ceiling` 两个字段上（`100 stalled` vs `400 live`）——正是
「边界内移」应该被抓住的地方；⑭ 那四条是同一处改动的连带（`W=2` 时阈值变成 -8，什么都被算成卡死）。
`git checkout --` 还原后树逐字节回到提交态，随后 `--select 34b` 绿（**rc=0、✓102 ✗0**，见 §7）。

## 1 · 新规则的四条喂值断言（任务书 §3）

函数是纯的：`gate_lock_patience <lock> <W>` → `ceiling<TAB>state<TAB>silent_for<TAB>heartbeat`；时刻一律取自
既有的 `gate_lock_now`，测试子 shell 里局部覆写它把 `now` 钉住，心跳 mtime 用 `touch -d @<epoch>` 写绝对值。

返修后的分支表（12 条；四条没独立判别力的已按 §0 删掉，每条都写明了接管者）：

```
✓ 34b⑨b 旧形状记录（没有 heartbeat 字段）→ state=none、上限仍是 W
✓ 34b⑨b heartbeat= 指向不存在的文件 → state=none、上限 W
✓ 34b⑨b heartbeat=- （记录明说不公布心跳）→ state=none、上限 W
✓ 34b⑨b 心跳 mtime=W-1 秒前（窗口内部）→ state=live、上限 4×W、silent_for=W-1
✓ 34b⑨b 心跳 mtime 恰好 W 秒前（边界）→ state=stalled、上限 W、silent_for=W
✓ 34b⑨b 新鲜心跳 + W=1000 → 上限正好 4000（硬顶 4×W）
```

（后 6 条是 G3 的五个现场，见 §2。）硬顶不用「等待者第几秒退出」证，就是同一个纯函数在 `W=1000` 上的
准确值 `4000`；`4 ×` 是乘法，不是第二个数字，所以不拿 `W=10` 再证一遍。

## 2 · 「每轮重算」而不是排队时缓存（V68 的 G3）

任务书要求的是**喂值**证明，不是 elapsed 时间带。同一份等待状态（已等 `E=150 s`）喂三个不同的 `now`：

```
✓ 34b⑨b 每轮重算 · 第 1 轮（心跳停了 120 s、已等 150 s）→ 判卡死、上限 W
✓ 34b⑨b 每轮重算 · 第 2 轮（同一份等待状态、更晚的时刻、心跳刚动过）→ live + 4W
✓ 34b⑨b 每轮重算 · 第 2 轮继续等（已等 150 s < 硬顶 400 s）
✓ 34b⑨b 每轮重算 · 后一次给出的截止比前一次晚（1790000400 > 1789999950）
✓ 34b⑨b 每轮重算 · 第 3 轮（心跳不再更新、从它最后一动起又过了 W）→ 判卡死、上限落回 W（缓存的 4W 会在这里继续放行）
✓ 34b⑨b 每轮重算 · 第 3 轮就该结束（已等 150 s >= 上限 100 s）
```

第 1 轮 `silent=120` → `stalled`、上限 100，`E=150` 已超；中间把心跳 mtime 更新到「刚动过」，第 2 轮同一个 `E`
变成 `live`、上限 400，截止从 `PIN-50` 推到 `PIN+400`（**更晚**）；第 3 轮心跳不再更新、`silent=100` → 落回 `W`
并判死。「stalled 时这一轮就该结束」只在第 3 轮断言一次：第 1 轮与它同一判断、只是换了数字，按 §0 的裁定删掉。

**判据落在哪几个字段上（第三轮按实测改写过，见 §0b）**：把「排队时缓存」的变异打在这 12 条上，红的是
**边界那条**与**第 2 轮那两条**（缓存看得见第 1 轮那 120 s 的静默 → `state`/`ceiling` 错），**第 3 轮那条红在
`silent_for`**（缓存值 120，实测该是 100）—— 它并不会「仍说 4W」，`state`/`ceiling` 碰巧还对。

代码结构上，轮询循环体里每轮现算（`smoke.sh:540`、`cmd-review.sh:1146` 都在 `while` 内、调用点无跨轮变量）。

## 3 · 端到端只跑一条真实排队路径（不改夹具）

沿用 §34b 既有的 `flock --close` 持有者 + 私有锁 + 私有 `TMPDIR` 形状，只把持有者记录换成新格式：

```
✓ 34b⑭ 心跳在动 → 等待者越过 W 也没被误杀（持有者比 W 晚释放，它仍拿到了锁：rc=0）
✓ 34b⑭ 它确实排过队（不是没排队就直接拿到）
✓ 34b⑭ 排队行说出上限来自活心跳（来自子登记，不是持有者记录）
✓ 34b⑭ 排队行同时打印两条上限（W=2 与 4×=8）
✓ 34b⑭ 心跳在动时不报排队超限
✓ 34b⑭ 它拿到锁后走到了子进程出口（真的取到锁）
✓ 34b⑭ 心跳停跳 → exit 2（约定的那个：不是 1、不静默）
✓ 34b⑭ 一行说明是排队超限，并报出等了多久
✓ 34b⑭ 那一行点名持有者
✓ 34b⑭ 那一行说出**为什么**耐心只剩 W（心跳已停 Ns）
✓ 34b⑭ 说明本套没有运行（不是对代码的判定）
✓ 34b⑭ 它一次都没拿到锁
✓ 34b⑭ 没有可用心跳（heartbeat=-）→ exit 2
✓ 34b⑭ 失败行说「没有可用心跳」（不是「心跳已停」）
✓ 34b⑭ 两种卡死原因不混为一谈
```

正向现场是「持有者记录 `heartbeat=-`、真正在动的是它子运行那条登记」——这正是顶层 `smoke.sh` 的真实形状
（包装器公布的心跳路径没人写；子套件在 `.runs/<pid>.run` 里公布真正会动的那个）。`W=2`、持有者 6 s 后释放：
比 `W` 晚、比硬顶 `8 s` 早，所以 `rc=0` 只能来自「耐心跟着心跳延长了」；忽略子登记的实现会按 `W=2` 判死
（§6 的反向对照就是把这一点变红的）。时间只决定**持有者何时释放**（单向界），进不了判据。
停滞现场同样沿用：心跳 mtime 写在 60 s 前、`W=2`，失败行 `排队超限 …（持锁者：kind=top pid=… cmd=p338-holder …；心跳已停 60s）`。

排队行的实际样子（同一现场的手工复现，非门禁输出）：

```
另一套全量 smoke 正在跑（kind=top pid=… cmd=p338-holder …已跑 120s expected=400 bound=2400；kind=nested pid=…
cmd=p338-nested …已跑 60s expected=400 bound=2400）；本套排队，最多等 8s（心跳仍在动（0s 前更新）；
下限 TEAM_SMOKE_LOCK_WAIT=2s，上限 4×=8s；TEAM_SMOKE_NO_LOCK=1 可跳过排队）
```

## 4 · 净零账与「旧记录逐字不变」的前后读数

删 / 换 / 加（`scripts/lib/gate-lock.sh` 542 → 582 行）：

| | 内容 |
|---|---|
| 删 | `gate_lock_cap`（`expected` 投影、`remaining`、`clamp`、四字段返回，17 行）与 `gate_lock_cap_pair`（6 行）；两处排队行的 `remaining=`/`cap=` 算式 |
| 加 | `gate_lock_path_mtime`（3 行，与 `gate_lock_path_identity` 同一个 stat 两平台写法）、`gate_lock_heartbeat_newest`（19 行，遍历 `.holder` + `.runs/*.run` 取最新的活心跳）、`gate_lock_patience`（15 行）、`gate_lock_patience_note`（7 行，排队行与失败行共用同一份措辞） |
| 换 | 三个消费点读同一行：`smoke.sh` 排队循环、`cmd-review.sh` 排队循环、`perf.sh` 性能锁（`state=none` → `W`，行为不变） |
| 不动 | `gate_lock_expected`（`expected`/`bound` 的生产者：属另一条 requirement，设计 §6）；`TEAM_SMOKE_LOCK_WAIT` 与 `4×` 的默认值；`queued/ran/limit` 记账；判定词闭集；§34b⑨ 的席位推导与 §34⑥ |
| 附带 | `tests/loop-inventory.tsv` 一行：真实路径现场需要一个「一直在动」的心跳文件，那就是一个 `while`+`sleep` 循环，循环清单必须登记它（`bound=心跳写入器…由 p338_release kill 收尾`）；同一行顺手把排队循环那条 `bound=` 的说法从「持有者公布的 expected」改成心跳口径。不加这行的后果是清单少一行（§0e 会点名「未登记的 while+sleep 循环」），这不是本 change 想留下的第二种缺陷 |

净零：**一个耐心规则替掉一个耐心规则**，没有新增监测器、第二个等待循环、预算表或「兼容」开关。

同一现场的前后读数（`W=1800`；记录用今天产品真实写的 `expected=0`、`started` 120 s 前）：

```
# 改前（git show HEAD:…/gate-lock.sh）
old-cap(production record expected=0, fresh heartbeat, W=1800): 1800  -120  0  1792499308
old-cap(production record expected=0, fresh heartbeat, W=2)   : 2     -120  0  1792499308
# 改后（同一场景）
fresh   (silent<W)   : 7200  live     0        ← 唯一的变化：有活心跳时才延长
silent2000 (>=W)     : 1800  stalled  2000
legacy (no heartbeat): 1800  none     -
published path gone  : 1800  none     -
```

第三、四行就是**旧记录行为与今天逐字相同**的证据：`ceiling` 等于传进来的 `W`，`state=none`，失败行的形状与文案
（`排队超限：等满 Ns …（持锁者：…）→ 本套**没有运行**`）只多一句「没有可用心跳」。门禁里由
`34b⑨ 旧持有者（没有心跳字段，也没有 expected）→ 上限仍是 TEAM_SMOKE_LOCK_WAIT` 与 `34b⑨b` 前两条钉住。

断言账（按 `diff` 实测，不按场景数凑）：§34b 断言点 **70 → 97**（`+27`：分支表 12、真实路径 15，返修后仍是
这个数 —— 去掉 4 条冗余腿、补上 `heartbeat=-` 与「没有可用心跳」两处）；
§34 **33 不变**（算式对账已由 P329 删除，本 change 不重复计）；**改写** 1 条 —— §34b⑨ 的
`gate_lock_cap "$P281_LOCK" 1800 | cut -f1` → `gate_lock_patience … | cut -f1`（同一断言标题、同一期望值
`1800`，只换入口：被删的函数是它唯一的调用者，标题里补上了真正决定耐心的字段名）。接管关系：被删的
`expected` 投影腿由 §34b⑨b 的 6 条纯函数腿接管；旧记录 `→W` 腿由 §34b⑨ 与 ⑨b①②③ 接管；
「读哪条记录」这件事由 §34b⑭① 接管（纯函数看不到）。

## 5 · 规格 delta 与生效文档

- delta（`openspec/changes/gate-waiter-patience/specs/verification/spec.md`，P332 已过独立审阅）逐条对照实现，
  第一轮**一字未改**；V78 第四件指出它比测试薄（失败行要点名的字段那段被删掉了，而 §34b⑦ 仍在断言），返修里
  补回那一句（`06afde50`），其余要求没动：`any live record`（`gate_lock_heartbeat_newest` 的遍历范围）、
  `usable only while less than W ago` 与 `at least W counts as no usable`（`silent >= W` 落 `stalled`）、`4 ×` 上限、
  `re-evaluate on every round`、`print both bounds with the state`、`failure says silent or never published`、
  `expected`/`bound` 不再决定耐心 —— 每一条都能在上面的断言里找到对应行。
- delta 的要求与断言现在一一对上：`heartbeat=-` → `W`（⑨b 第三条 + ⑭③）、两种卡死原因可区分（⑭②③）、
  失败行点名 `kind`/席位/工作树/时长/`expected`（§34b⑦ 既有五条，本轮未动）。
- `skills/teamsmith/references/protocol.md` §9b-2 同轮对齐，不留第二份口径：排队上限段落改写为心跳口径；
  记录字段那句改成现状（P316 之后 `expected`/`bound` 是诊断字段，仍写仍打印、不决定任何事）。
  `grep -n 'remaining=\|clamp(remaining' skills/teamsmith/references/*.md skills/teamsmith/SKILL.md` 无输出。

## 6 · 反向对照（flip evidence）

两次都是「改坏实现 → 该变红的变红 → 还原 → 全绿」，改完即还原（`git diff` 与还原前逐字节相同）。

**A · 只读 `.holder`**（把 `gate_lock_heartbeat_newest` 的遍历范围砍成持有者记录一个文件）→ `--select 34b`：

```
✗ 34b⑭ 心跳在动 → 等待者越过 W 也没被误杀（持有者比 W 晚释放，它仍拿到了锁：rc=0）（期望 [0]，实际 [2]）
✗ 34b⑭ 排队行说出上限来自活心跳（来自子登记，不是持有者记录）（… 中找不到 [心跳仍在动]）
✗ 34b⑭ 心跳在动时不报排队超限（不该出现 [排队超限]）
✗ 34b⑭ 它拿到锁后走到了子进程出口（真的取到锁）（… 中找不到 [自检出口]）
== 选段结果 ==  ✓ 121  ✗ 4          ← 只有这四条红，其余（包括停滞那条）全绿
```

**B · 边界换成 `silent > W`**（让 `silent == W` 落到 `live`）：

```
✗ 34b⑨b 心跳 mtime 恰好 W 秒前（边界）→ state=stalled、上限 W、silent_for=W（期望 [100 stalled 100 …]，实际 [400 live 100 …]）
✗ 34b⑨b 每轮重算 · 第 3 轮（…）→ 判卡死、上限落回 W（期望 [100/stalled/100]，实际 [400/live/100]）
✗ 34b⑨b 每轮重算 · 第 3 轮就该结束（期望 [超限]，实际 [继续等]）
== 选段结果 ==  ✓ 121  ✗ 3
```

A 证的是「读全部活登记」是载荷所在（设计 §3 的核心决定）；B 证的是边界归属与「每轮重算」的准确值不是空话。

## 7 · 验收命令

```
$ git diff --check && echo ok
ok
$ bash skills/teamsmith/tests/section-select.sh --check
… == 选段自检 ==  ok 9  bad 0  SKIP 1        (rc=0；SKIP 是行 19 的 `.pi/skills` 检出形状，既有)
$ ~/.bun/bin/openspec validate --all --strict
✓ spec/verification …  Totals: 21 passed, 0 failed (21 items)      (rc=0)
   注：`openspec` 不在登录 shell 的 PATH 里（`bash -lc 'command -v openspec'` 为空），所以用绝对入口
   `~/.bun/bin/openspec`（指向全局安装的 @fission-ai/openspec）。
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: … files=1916 hits=0 names=ok user=resolved        (rc=0)
$ bash skills/teamsmith/tests/smoke.sh --select 34,34b
…
#5 34 · 门禁锁：排队/运行分开记账（P26/G1：…） · 参考 用时 67s · ✓35 ✗0 SKIP0 · ticks 35
#6 34b · 门禁锁排队守卫：超上限要大声失败并点名持有者（P66） · 参考 用时 40s · ✓102 ✗0 SKIP0 · ticks 102
账本自查： 6 段收口 · 增量 ✓160 ✗0 SKIP0 ｜ 结果行 ✓160 ✗0 —— 一致
== 选段结果 ==  ✓ 160  ✗ 0
    （返修第一轮之后的交付树上跑的；第三轮只动 §34b 的两处，任务书只批 `--select 34b`：）
$ bash skills/teamsmith/tests/smoke.sh --select 34b
✓ 34b⑨b 心跳 mtime=W-1 秒前（窗口内部）→ state=live、上限 4×W、silent_for=W-1
…
#5 34b · 门禁锁排队守卫：超上限要大声失败并点名持有者（P66） · 参考 用时 40s · ✓102 ✗0 SKIP0 · ticks 102
账本自查： 5 段收口 · 增量 ✓125 ✗0 SKIP0 ｜ 结果行 ✓125 ✗0 —— 一致
== 选段结果 ==  ✓ 125  ✗ 0
```

`rc=0`。既有断言一条没被放松：§34⑦ 的 `TEAM_SMOKE_LOCK_WAIT=200s`、§34b① 的 `排队超限：等满 Ns` +
点名 + 「本套没有运行」、§34b⑦ 的嵌套点名、§34⑥ 的「排队不碰 tmux/看板」都还是绿的。

## 8 · 未验与缺口（写明的边界）

- **`team review` 形状的活心跳没有端到端证据**：`cmd-review.sh` 的排队点换成了同一个读数、文案同样打印
  `state` 与两条上限，但本次刻意没有让一个真 `team review` 的等待者读到活心跳 —— 任务书把端到端钉成「一条
  真实排队路径、不新建夹具」，而 §34b⑭ 用的记录布局（持有者 `heartbeat=-` + 子登记在动）就是 review 的形状
  （同一个 `gate_lock_heartbeat_newest`、同一对写函数）。`team review` 路径的排队行为今天由 §34①/② 守，但
  它们用的是旧形状记录（`none` → `W`）。这条留给 verify 判断是否要补一次真 review 现场。
- **§61b 的静默段**未实测：提案 §7 的静态推断（`W` 秒无 tick 的段今天不可能在顶层存活）本 change 未验证，
  也不改变它。
- **`expected` 的生产者未退役**（设计 §6 明写属另一条 requirement）：它仍被写成 0、仍被打印。
- **§34d / §36 本次没跑**（任务书只批 §34/§34b，不跑整套）：这两段的持有者记录一律公布 `heartbeat=-` 或根本
  没有该字段，走的是 `none` → `W` 的同一条读数，行为不变；由交付/复验的全量覆盖。
- **§0e 的循环清单有一条改前就有的漂移，我没碰**：`loop-inventory.tsv` 第 30 行（`smoke.sh` 的 `R_WAIT` 循环）锚点
  还是旧的单行写法，源码现在是多行的 `while [ "$R_WAIT" -lt "$R_MAX" ]; do`。改前树（我自己导出的 `HEAD~2` 的
  `tests/` 副本）跑同一条检查给出**同一条、且只有这一条**：

  ```
  bad: smoke.sh:6392 的 while 行与清单第 30 行的锚点不符
       源码：  while [ "$R_WAIT" -lt "$R_MAX" ]; do
       清单：  while [ "$R_WAIT" -lt 1500 ] && ! $TEAM roster …; do sleep 0.2; R_WAIT=$((R_WAIT + 1)); done
  ok: 扫描 85 行清单 / 85 个 while+sleep 循环，配平 85 个
  ```

  本任务的树是 `86 行清单 / 86 个循环` 配平、同一处仍是唯一一条。它是别人的循环被改了写法而清单没跟上，
  修它要判断那条循环现在真正守的是什么，按 P329 报告的先例留给 PM 立单（我没有把它连同本任务一起改，
  以免把一条既有红悄悄抹掉）。
- **一次既有 flake 的观测**：本轮第一次 `--select 34,34b` 里 `34b⑫ 收尾：登记随它退出消失（只删自己那条）`
  红了（§34b 用了 345 s，其中 300 s 是它自己的等待上限），随后三次运行（flip A、flip B、最终绿）都绿 ——
  与 P329 报告里登记的同一条既有不稳定断言同一个形状，本改动不碰那两个函数。请 PM 知悉：它不是本次引入的。
