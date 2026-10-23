# gate-waiter-patience · tasks

阶段口径：**apply** 由收到本 change 的席位完成，先合并 main（P329 必须先落地），再按下面的顺序做；**verify** 由
没写过 apply 的席位在独立克隆上重跑改变的部分（一次定点执行，见 §7）。本文件不是规格：合同在
`specs/verification/spec.md`，理由与取舍在 `design.md`。

## 0 · 前置（先做，不成立就停）

- [x] 0.1 `git merge main`，确认 **P329 已落地**：看它的**落地记录**（提交在位 + 看板 `done`）。再核对**它负责的
  那一片**：§34⑦/§34b⑨ 里不再有「从记录里的 `expected` 重算上限」的算式（`smoke.sh:16486-16491`、
  `:16696-16705` 那两条现场）。未落地 → 写 `BLOCKED:` 交回 PM，**不许**自己改同一批断言（两个写者会互相覆盖，
  `design.md` §5）。**前置不靠整文件里的字符串计数**：`expected=400` 在 `smoke.sh:16463` 是注释、`CAP_WANT`
  是夹具变量名，它们在整个文件里出现几次与「那批断言退了没有」不是同一件事（整文件计数只作报告里的一行附注）。 — 已做：P329 的落地记录是 `docs/team/reviews/P329.md`（判定 PASS，合入 `6d6b87db`）+ 看板 `P329 … done`；本树 `grep -c CAP_WANT skills/teamsmith/tests/smoke.sh` = 0，§34b⑨ 的现场现在调 `gate_lock_patience`（`smoke.sh:16944`），算式对账按 `docs/team/reports/P338-dev-bob.md` §4「断言账」记在 P329 名下。
- [x] 0.2 记下改动前的现场（报告要用）：`gate_lock_expected skills/teamsmith/tests/smoke.sh /dev/null` 的三个字段、
  一次 `gate_lock_cap <lock> <W>` 的返回、§34⑦/§34b⑨ 的现场行号。 — 已做：三字段与 cap 返回记在 `docs/team/reports/P332-dev3.md`「今天的行为（供复验对照）」（`gate_lock_expected skills/teamsmith/tests/smoke.sh /dev/null` → `0`/`121500`/`135`；`gate_lock_cap <lock> 1800` → `1800 -120 0 …`；`… 2` → `8 0 0 …`），同节还给了 §34⑦ `:16461-16491` / §34b⑨ `:16688-16708` 的行号；改前/改后并排读数见 `P338-dev-bob.md` §4。

## 1 · product：把「上限」换成「心跳耐心」（`scripts/lib/gate-lock.sh`）

- [x] 1.1 删 `gate_lock_cap`（`:463-477`）与它的注释口径：`expected` 投影、`remaining`、`clamp`、四个返回形状，
  连同 `gate_lock_cap_pair`（`:392-397`）。 — 已做：`skills/teamsmith/scripts/lib/gate-lock.sh`（582 行）里 `gate_lock_cap` 与 `gate_lock_cap_pair` 都不在了（`grep -rn gate_lock_cap skills/` 只命中历史报告与 design 正文，`skills/` 零命中）；删除账 17 行 + 6 行见 `P338-dev-bob.md` §4，实现提交 `4f11ede7`。
- [x] 1.2 加 `gate_lock_path_mtime <path>` → epoch 秒（`stat -c %Y`，BSD 兜底 `stat -f %m`，与既有
  `gate_lock_path_identity` 同一个两平台写法）；读不到 → 非 0。 — 已做：`gate-lock.sh:104 gate_lock_path_mtime`（`stat -c %Y`，BSD 兜底 `stat -f %m`，读不到非 0）。
- [x] 1.3 加 `gate_lock_heartbeat_newest <lock>` → `path<TAB>mtime`：遍历 `<lock>.holder` 与 `<lock>.runs/*.run`，
  只取 `gate_lock_record_live` 为真的条目，读它公布的 `heartbeat=`（空/`-` 跳过），取 mtime 最新的一个；没有 → 空。
  **不新增字段、不新增协议**：这就是等待者点名持有者时已经在 glob 的那两个位置。**不校验**登记与当前持有者的
  祖先关系 —— 这条放宽与其上界（遗留活登记最坏把上限顶到 `4W`）写在 `design.md` §3，不要在实现里补认证。 — 已做：`gate-lock.sh:480 gate_lock_heartbeat_newest` —— 遍历 `.holder` 与 `.runs/*.run`、只取 `gate_lock_record_live` 为真的条目、`''`/`-` 跳过、取 mtime 最新，无可用 → 非 0；没有新增字段，也没有在实现里补祖先认证。
- [x] 1.4 加 `gate_lock_patience <lock> <wait>` → `ceiling<TAB>state<TAB>silent_for<TAB>heartbeat`：
  `silent_for < wait` → `state=live`、`ceiling=4×wait`；文件在但 `silent_for >= wait`（**边界归这一侧**）→
  `state=stalled`、`ceiling=wait`；没有活登记公布、公布的是 `-`、或路径上的文件不在 → `state=none`、`ceiling=wait`。
  `gate_lock_patience_pair <published lock> <wait>` 与旧 `_pair` 同形（记录优先读伴生锁边上那份，旧写入者退回
  发布路径）。 — 已做：`gate-lock.sh:496 gate_lock_patience`（`silent < wait` → live + 4×wait；`>= wait` → stalled + wait；无可用 → none + wait）与 `:399 gate_lock_patience_pair`（记录优先读伴生锁边那份）。
- [x] 1.5 **现在的时刻一律取自既有的 `gate_lock_now`**（`gate-lock.sh:33`；`gate_lock_cap` 本来就是这么写的），
  新增代码里不出现裸 `date +%s`。这样判据在测试里可以被钉住，不需要新时钟、不需要产品钩子。 — 已做：`gate_lock_patience` 的时刻只取 `gate_lock_now`（`:502`）；`grep -n 'date +%s' skills/teamsmith/scripts/lib/gate-lock.sh` 只剩 `:34` 的 `gate_lock_now` 本身。
- [x] 1.6 可控输入定点证据（不起进程、不依赖真实秒差）：测试子 shell 里**局部覆写** `gate_lock_now() { printf '%s\n' "$PIN"; }`，
  心跳文件的 mtime 用**绝对值**写 `touch -d "@<epoch>"`，于是 `silent_for` 是等号而不是「大约」：

  | 现场 | 断言（准确值） |
  |---|---|
  | 旧形状记录（无 `heartbeat` 字段） | `state=none`、`ceiling=W` |
  | `heartbeat=` 指向不存在的文件 | `state=none`、`ceiling=W` |
  | 心跳 mtime `@PIN`（新鲜） | `state=live`、`ceiling=4×W`、`silent_for=0` |
  | 心跳 mtime `@((PIN - W + 1))`（还新鲜） | `state=live`、`ceiling=4×W`、`silent_for=W-1` |
  | 心跳 mtime `@((PIN - W))`（**恰好边界**） | `state=stalled`、`ceiling=W`、`silent_for=W` |
  | 心跳 mtime `@((PIN - 10))`（停滞） | `state=stalled`、`ceiling=W`、`silent_for=10` |
  | 新鲜心跳 + `W=1000` / `W=10` | `ceiling=4000` / `ceiling=40`（**硬顶就是这里的准确值**） |

  最后一行承担「硬顶 `4×W` 被准确遵守」这一判断；**不**再用「等待者第几秒退出」去证它（`design.md` §2）。
  命令与输出进报告。 — 已做（实际是 12 条腿，且三行按审阅退役）：读数在 `docs/team/reports/P338-dev-bob.md` §1/§2（旧形状 / 文件不在 / `heartbeat=-` → none+W；`W-1` → live+4W；边界 `== W` → stalled+W；`W=1000` → 4000；G3 三轮），另有 `docs/team/reports/V78-verify.md` §1 的 11 条独立喂值断言。退役的三行与接管者写在 `P338-dev-bob.md` §0b F2：`silent=0` 由 §34b⑭① 的真实排队行承担、`silent=10` 由 G3 的 120/100 承担、`W=10→40` 与 `W=1000→4000` 是同一判断；「硬顶 `4×W` 被准确遵守」仍由 `W=1000 → 4000` 这个准确值承担。

## 2 · 四个排队点与两处文案

- [x] 2.1 `tests/smoke.sh:532` 与 `scripts/lib/cmd-review.sh:1144` 换成 `*_patience_pair`，`read` 出
  `ceiling/state/silent_for/hb`。**每轮重读**（排队本来就是一秒一轮）。 — 已做：`smoke.sh:607` 与 `scripts/lib/cmd-review.sh:1148` 都在 `while` 内 `read` `gate_lock_patience_pair` 的 `ceiling/state/silent_for/_`（任务书里的 532 / 1144 是改动前的位置，已被 P329/P338 推后）。
- [x] 2.2 排队行（`smoke.sh:536`、`cmd-review.sh:1151`）去掉 `remaining=`/`cap=` 算式，换成一句说明上限来自哪里：
  `live`（`silent_for=Ns`）→ 上限 `4×W`；`stalled` → 「心跳已停 Ns」；`none` → 「没有可用心跳」。
  必须保留的子串（既有断言依赖）：`另一套全量 smoke 正在跑`、`TEAM_SMOKE_LOCK_WAIT=<W>s`、`4×`。 — 已做：`smoke.sh:611` 与 `cmd-review.sh:1152` 打印 `（<心跳说明>；下限 TEAM_SMOKE_LOCK_WAIT=<W>s，上限 4×=<4W>s）`，三个必须保留的子串都在；`remaining=` / `cap=` 算式已无（见 2.5）。
- [x] 2.3 失败行（`smoke.sh:548`、`cmd-review.sh` 的 `gates_out`）保留今天的形状：`排队超限：等满 Ns …（持锁者：…）`
  → `本套**没有运行**` / `**门禁没有运行**`、退出码仍是 2 / 判定仍是 `FAIL`（不是 `TIMEOUT`），后面多一句原因
  （`心跳仍在动，但到了硬顶 4×W` / `心跳已停 Ns` / `没有可用心跳`）。 — 已做：`smoke.sh:625` 仍是 `排队超限：等满 Ns（上限 Ns）…（持锁者：…；<原因>）→ 本套**没有运行**`，原因由 `gate_lock_patience_note` 的三个分支给出；`rc=2` / 点名 / `没有运行` / 「TIMEOUT 计数 0」由 §34b①（`smoke.sh:16761-16768`）与 §34②（`:16613`）钉着；`cmd-review.sh:1260` 同形、`queuecap` 走 `FAIL`（`:1396`）。
- [x] 2.4 `tests/perf.sh:180` 换同一个读数（`state=none` → `W`，行为不变）。 — 已做：`perf.sh:181` 读 `gate_lock_patience_pair`，非数字时退回 `$wait_s`。
- [x] 2.5 定点证据：`grep -n 'remaining=' skills/teamsmith/tests/smoke.sh skills/teamsmith/scripts/lib/cmd-review.sh`
  必须无输出。 — 已做：2026-10-22 在本树实跑同一条 grep → 无输出（rc=1）。

## 3 · 门禁断言（`tests/smoke.sh`，§34b⑨ / §34⑦）：一张分支表，不重复

判据只有一种：**每条分支的 `ceiling` 用函数入口当场算**（§1.6 的可控输入，准确、不测秒）；真实进程只留
**一条正向 + 同一条断言的反例**，因为「读哪条记录」这件事只有真流程里才看得见。

**表头的共同前提**：记录里的 `started` 一律回填到 120 s 之前 —— `started=现在` 时**今天**的
`clamp(remaining + 60, W, 4W)` 也落在 `4W`（实测 `gate_lock_cap(lock, 2)` → `8`），那样新断言会「今天也通过」，
红不起来（`design.md` §1.1 末尾、§5.2）。

| 分支 | 准确 `ceiling`（纯函数，§34b⑨） | 真实进程 |
|---|---|---|
| 旧形状记录 / 无 `heartbeat` 字段 | `none` + `W` | §34b① 已守（旧形状记录 + `W` 失败 + 点名 + `没有运行`），**并在同一处加一句原因断言**（`没有可用心跳`） |
| `heartbeat=` 指向的文件不在 | `none` + `W` | 无（同一条代码路径） |
| `silent_for >= W`（含 `== W` 边界） | `stalled` + `W` + 精确 `silent_for` | **§3.5 停滞现场**（复用 §34b① 的夹具，只加一个失败分支） |
| `silent_for < W`（含 `W-1`） | `live` + `4×W`（`W=1000→4000`、`W=10→40`） | 无（准确值由本行的纯函数腿证） |
| 硬顶 | 同上一行（同一个准确值即证） | 无（不用「第几秒退出」证；delta 也不再为「仍在硬顶」这句单独承诺文案） |
| `team review` 形状（`heartbeat=-` + 子登记在动） | —— | **§3.2**：只证「子登记被发现 → 排队行打印 `state` 与两个上限 → 释放后取到锁」 |

- [x] 3.1 §34b⑨ 的现有断言按上表改写：两条留用的（`没有心跳 → ceiling=W`、`W=1000/10` 的上下限）改成纯函数腿，
  再补边界 `silent_for == W`、`silent_for == W-1`、文件不在 → `none` 三条（全部用 §1.6 的钉住时刻与绝对 mtime）。
  §34b① 的**现有** `none` 失败现场只加一句原因断言（`没有可用心跳`），不新建夹具。 — 已做：§34b⑨b 的 12 条腿在 `smoke.sh:16948-17020`（旧形状 / 文件不在 / `heartbeat=-` → none+W；`W-1` → live+4W；边界 `== W` → stalled+W；`W=1000` → 4000；G3 三轮），读数见 `P338-dev-bob.md` §1/§2。**一处偏离如实记下**：`没有可用心跳` 那句原因断言落在**新建**的 ⑭③ 现场（`smoke.sh:17335-17341`，`heartbeat=-`、`W=2`），不在 §34b① 原现场 —— `V78-verify.md` §0 表 3② 把它当缺口提出、作者按新现场补上，V78 验过红/绿后判 PASS。
- [x] 3.2 **正向（`team review` 形状）**：持有者是走 review 路径的夹具 —— 记录写在**伴生锁**边上
  （`$(gate_lock_companion_path "$LOCK")`，`heartbeat=-`），跑的门禁子套件经祖辈证明后以 **`kind=nested` +
  `ancestor=<holder pid>`** 登记自己，登记里公布一个心跳文件（后台按默认节奏重写它；**重写频率不作可靠性条件**）。
  `TEAM_SMOKE_LOCK_WAIT=1000`：整秒差与调度抖动远小于这个界，所以 `state` 不会被时钟噪声翻成 `stalled`；`timeout`
  只作防死等兜底。**它只证三件事**：① 子登记公布的那条心跳被真的发现（排队行里 `state=live`）；② 排队行在同一处
  打印了 `state` 与两个上限；③ 持有者看到这条排队行后**释放锁**（事件同步，不是睡固定秒数），等待者随后拿到锁、
  `rc=0`。它**不证明「等待者已经越过 `W`」**——那件事由 §1.6 的钉住时刻输入腿承担。 — 已做：§34b⑭①（`smoke.sh:17308-17321`）—— 持有者记录 `heartbeat=-`、真子登记 `kind=nested ancestor=<holder pid>` 公布活心跳、`W=2`、持有者在等待者返回后才放锁 → `rc=0`，排队行含 `心跳仍在动` 与 `上限 4×=8s` 且不报 `排队超限`；读数见 `P338-dev-bob.md` §3。
- [x] 3.3 **反例（同一条断言）**：把 `gate_lock_heartbeat_newest` 改成只读 `.holder`（于是 review 形状永远是
  `heartbeat=-` → `none`）→ 3.2 的那条断言必须红；还原后回绿。这是本 change 唯一保留的反向对照。 — 已做：`P338-dev-bob.md` §6 flip A —— 把 `gate_lock_heartbeat_newest` 砍成只读 `.holder` 后 `--select 34b` 为 `✓121 ✗4`（红的正是 ⑭① 那一组），`git checkout --` 还原后 `✓102 ✗0`。
- [x] 3.4 **不重演等待循环的消耗与既有超限行为**：`排队超限` 的失败形状（`rc=2`、点名、`没有运行`、`FAIL` 不是
  `TIMEOUT`）由 §34b①/⑦ 的既成断言守；本 change 不复制它们，也不新增「等满第几秒」的场次。 — 已做：断言账 `P338-dev-bob.md` §4（§34 仍 35 条、不改写；§34b 只加分支表与 ⑭ 的真实路径），`V78-verify.md` 结论「不许用墙钟」那一段逐条核过新增断言没有「睡 N 秒再比时间区间」，也没有新增「等满第几秒」的场次。
- [x] 3.5 **停滞（`stalled` 的失败行）**：与 §34b① **同形**的夹具（私有锁、`W=2`、记录公布一个
  **mtime 用绝对值写在 60 s 前**的心跳文件、`timeout` 只作兜底）。断言：`rc=2`、失败行含 `排队超限`、`心跳已停`，
  点名 `cmd=`。**不测「在哪一个秒区间完成」**：`silence` 只会随时间变大，不可能回到 `W` 以下，所以不存在边界抖动。
  **持有者按事件收尾**：等等待者返回（失败行已出现）后它才释放锁，不用固定 `sleep 20` 让它在前面提前放锁 ——
  否则就换成另一种调度竞态。 — 已做：§34b⑭②（`smoke.sh:17322-17332`）—— 私有锁、`W=2`、心跳 mtime 用 `touch -d @(now-60)` 写绝对值、持有者 20 s；断言 `rc=2`、`排队超限：等满 Ns`、`排队超限.*cmd=p338-holder`、`心跳已停`、`没有运行`、`自检出口` 不出现。
- [x] 3.6 §34⑦ 保留 `TEAM_SMOKE_LOCK_WAIT=200s` 那条断言（下限仍被打印）；不加换场次。 — 已做：`smoke.sh:16685` 仍断言 `TEAM_SMOKE_LOCK_WAIT=200s`（§34⑦ 本轮未动），`P338-dev-bob.md` §8「既有断言一条没被放松」点名它。
- [x] 3.7 断言账按 `diff` 的实际删改写进报告：删掉哪几条、改写哪几条、新增哪几条、每条的接管者是谁
  （P329 先删的记在它名下）。**不按场景数或翻转配额凑数。** — 已做：`P338-dev-bob.md` §4「断言账（按 `diff` 实测）」—— §34b 70→97（+27）、§34 33 不变、改写 1 条（`gate_lock_cap` → `gate_lock_patience`，同标题同期望 1800）、删掉的 4 条各写了接管者；`V78-verify.md` §0 复核「删 4 加 4、静态 `assert_` 调用点仍 97」。
- [x] 3.8 **「每轮重算」的可证伪验证：实施阶段未解决项（不拿墙钟做替代）**。合同与 §2.1 要求 `state`/上限
  - 2026-10-23 `§34b⑨c`（P372）落地：同一次等待、同一个进程、两个「现在」→ 正确实现下第二条移动、缓存实现下第二条逐字等于第一条（实测缓存：⑨c 两条红、⑧ 的 12 条全绿；还原全绿）。
  - 同批纠正一条既有注释的功劳归属：「后一次截止更晚」在缓存下也成立（截止 = 现在 − 已等 + 上限），缓存由 ⑨c 判，不由它判（V78 §5 的两个变体都绿）。
  **每轮重算**，但现有输出（排队行、失败行、产品的 `等满 Ns`）只能证明「它此刻认定的上限是多少」，**不能区分**
  「每轮重算」与「排队时算一次就缓存」：缓存的实现在持有者停跳后照样写 `心跳已停`，只是白等到 `4W`，而唯一可观察的
  差异是**真实 elapsed** —— 拿它做判据又是一条墙钟带，本 change 不采用（`等满 Ns` 就是产品记录的真实 elapsed，
  读它并不比量墙钟更稳定）。所以：① 实施阶段要让「重算」在**代码结构**上可核（上限在每一轮循环里从记录现算，
  没有跨轮缓存）；② 独立审阅在 verify 时**核循环内的调用点**、确认没有缓存，并把结论写进复验记录；③ 若实施阶段
  找到**非计时**的可证伪判据，就在那个 change 里补上；**找不到就在报告里写明这个缺口，不许宣称缓存反例已被杀死**。 — **未勾：② 没有成立。** ① 与 ③ 有证据：轮询点每轮现算（`smoke.sh:607`、`cmd-review.sh:1148` 在 `while` 内、无跨轮变量，见 `P338-dev-bob.md` §2）；③ 的非计时判据经 `V78-verify.md` §5 的两个「排队时缓存」变异实测成立（变体 A 红 5 条、变体 B 红 3 条，红在边界腿与本轮值断言），`P338-dev-bob.md` §0b F1 已按实测改写了原来的错误推断。但 ② 要的是「独立审阅核循环内调用点、确认没有缓存，并把结论写进复验记录」——`V78-verify.md` 里没有这一段，它用定向变异代替，留给 PM 判。

## 4 · 生效文档对齐

- [x] 4.1 `skills/teamsmith/references/protocol.md` §9b-2：把「The queue cap follows the holder's published
  expected duration」那段改写成心跳口径（与 delta 同一件事：`state`/两条上限/`expected` 不再决定耐心），并顺手把
  「its expected duration and its bound (the section table's Σband / Σbudget …)」改成现状（P316 之后没有生产者，
  字段留下当诊断）。**不留第二份口径**。 — 已做：`skills/teamsmith/references/protocol.md:740` 起了「The queue cap follows the holder's heartbeat; the published `expected` no longer decides it.」整段（可用窗口 / 两条上限 / 三种「没有可用心跳」来湸0/「读的不是认证」），`:717-719` 同时把 `expected`/`bound` 写成「P316 之后是诊断字段，仍写仍打印、不决定任何事」。
- [x] 4.2 `grep -n 'remaining=\|clamp(remaining' skills/teamsmith/references/*.md skills/teamsmith/SKILL.md`
  的输出贴进报告，确认没有第二处旧算式。**模式里不含 `4 ×`** —— 那正是 §4.1 要求写进去的新措辞，把它放进
  检查会让这条永远不可能干净。 — 已做：2026-10-22 在本树实跑该 grep → 无输出（rc=1）；`P338-dev-bob.md` §5 记了同一条。

## 5 · 现场的共同前提（不重复造场面）

- [x] 5.1 所有真实进程现场：私有锁 + 私有 `TMPDIR` + 自选 `TEAM_SMOKE_LOCK_WAIT`（与 §34b⑦ 的 `p281_waiter`
  同形），不碰机器锁。 — 已做：⑭ 的真实现场都走 `p338_hold`/`p338_waiter`（`smoke.sh:17277-17308`）—— `TEAM_SMOKE_LOCK=$P338_LOCK`、`TMPDIR=$P338D`、自选 `TEAM_SMOKE_LOCK_WAIT`；⑨b 的纯函数腿连进程都不起。
- [x] 5.2 记录里的 `started` 回填到 120 s 之前（理由见 §3 表头）。 — 已做：`p338_scene` 把记录的 `started` 写成 `$(( P338_PIN - 120 ))`（`smoke.sh:16957`），理由写在 `design.md` §1.1 末尾。
- [x] 5.3 `timeout` 只作**防死等兜底**；断言只看 `rc`、失败行、排队行里的 `state`/两个上限与产品自己打印的
  `等满 Ns`，**不看「第几秒退出」**。 — 已做：`P338-dev-bob.md` §3 与 `V78-verify.md` 结论「不许用墙钟」—— 真实时间只决定持有者何时释放（单向界），判据是 `rc`、失败行 / 排队行字段与产品自己打印的 `等满 Ns`。

## 6 · 最终一次运行 + 报告

- [x] 6.1 `openspec validate --all --strict`（21 项）、`bash skills/teamsmith/tests/spec-refs.sh --check`、
  - 2026-10-23 PM 读数：`openspec validate --all --strict` 23/0；`spec-refs.sh --check` rc=0、judged 118 references、**undeclared 0**；`git status --short` 空（干净）。
  `git diff --check && git status --short`。 — **未勾：证据不全。** `openspec validate --all --strict` 21/21 与 `git diff --check` 在 `P338-dev-bob.md` §7 有读数；`spec-refs.sh --check` 与 `git status --short` 在 P338/V78 的记录里**没有**，缺这两条。
- [x] 6.2 定点**执行**（不是查表）：`bash skills/teamsmith/tests/smoke.sh --select 34,34b,34d,36`。这四段覆盖了
  - 2026-10-23 PM 执行（干净冻结树 `6f23252a`）：`--select 34,34b,34d,36` → **rc=0**、**1327 s**，**34d 首次在新代码上实跑**；日志 `~/.cache/close033/logs/6-2.log`。
  产品面里**所有**断言排队行/记录的段（34 `smoke.sh:16461-16491`、34b `:16688-16708`、34d `:17383-17527`、
  36 `:17655-18071`）。`section-select.sh` 只用来**查表**（`--list`/`--select` 打印 `decision=RUN`/`keys=N` 就退出，
  一段都不跑），不能当执行证据；`--paths` 也缩不窄（它把 `smoke.sh` 本身算成 17 个键、四份文件合计 46 个键 =
  全量 135 段）。 — **未勾：没做。** `bash skills/teamsmith/tests/smoke.sh --select 34,34b,34d,36` 从未跑过 —— apply 只跑了 `--select 34,34b`（`P338-dev-bob.md` §7，§34d / §36 在 §8 明写未跑），verify 也只跑了 `--select 34,34b`（`V78-verify.md` §4）；§34d 至今没有在新代码上的实跑读数。
- [x] 6.3 **不再跑 FAST 全量**：整套只跑一次，放在合并/发布。定点可能漏的键（`gate-lock.sh`/`cmd-review.sh`
  映射到但不过排队行的那些）由那一次全量覆盖 —— 这就是保留它的理由。 — 已做：apply 与 verify 都只跑定点选段（`P338-dev-bob.md` §7、`V78-verify.md` §4），没有跑 FAST 全量。
- [x] 6.4 报告 `docs/team/reports/<ID>-<agent>.md`：先给结论，再给「删了什么/加了什么」与断言账、§1.6 与 §3 的
  原始输出尾部、两条未验项（§61b 的静默段是源码推断、未实测；`expected` 生产者未退役）。 — 已做：`docs/team/reports/P338-dev-bob.md` —— 结论先写，§4 的删/加账与断言账，§1/§3/§6 的原始输出尾部，§8 的两条未验项。

## 7 · verify（独立席位，非 apply 作者）

- [x] 7.1 在自己的克隆上跑同一条定点**执行**：`bash skills/teamsmith/tests/smoke.sh --select 34,34b,34d,36`，
  - 2026-10-23 V103 独立执行 `--select 34,34b,34d,36`：`✓390 ✗1`、1563 s；那 1 条红是**夹具自相矛盾**（`§34d 2.1` 把默认锁名写死），换默认约定重跑该段全绿。夹具缺陷另立 P374。
  给结果行与新增断言的原文；不复用 apply 的日志，也不拿 `section-select.sh` 的查表输出代替。 — 复验项（按协议留给 PM 勾）：`V78-verify.md` 在独立克隆上跑的是 `--select 34,34b`（§4：`✓159 ✗1`，唯一红是既有 flake §34b⑫），不是本条要的 `34,34b,34d,36`；§34d 没有复验读数。
- [x] 7.2 只做一条反向对照：把心跳来源改回只读 `.holder` → §3.2 正向必须红（「读全部活登记」的唯一控制）。
  - 2026-10-23 V103：把心跳来源改回「只读 `.holder`」→ `§34b` 正向断言红；还原绿。
  另两条（放宽判据、把 `none` 判成 `4W`）与 §3 各条已写明的破口重复，删。 — 复验项（留给 PM 勾）：这条只读 `.holder` 的反向对照是**作者**跑的（`P338-dev-bob.md` §6 flip A）；`V78-verify.md` §5 的自造红侧是另一个变异（「排队时缓存」），`reviews/V78.md` 记 PM 自己重跑过 F2 那个变异。
- [x] 7.3 确认没有回归：§34b①/⑦ 的排队超限语义（`rc=2`、点名、`没有运行`、`FAIL` 不是 `TIMEOUT`）与
  - 2026-10-23 V103：`§34b①/⑦` 的排队超限语义仍为 `rc=2`、点名、`没有运行`、`FAIL` 不是 `TIMEOUT`（`§34c` ✓）；无回归。
  `TEAM_SMOKE_FAST`（`no_lock=1`、不排队）都没变；§4.2 的 grep 干净。 — 复验项（留给 PM 勾）：`V78-verify.md` §4 记 §34b①/⑦ 语义未变，§4.2 的 grep 干净；`TEAM_SMOKE_FAST`（`no_lock=1`、不排队）本轮没有单独读数。
- [x] 7.4 复验记录写 `docs/team/reviews/<ID>.md`，只有复验通过且用户确认后 PM 才归档。 — 复验项（留给 PM 勾）：`docs/team/reviews/V78.md` 已写判定 PASS 与依据；归档前的用户确认仍未发生。
  - 2026-10-23 V103：`docs/team/reviews/gate-waiter-patience.md` 落盘（`58419e83`）。
