# gate-waiter-patience · tasks

阶段口径：**apply** 由收到本 change 的席位完成，先合并 main（P329 必须先落地），再按下面的顺序做；**verify** 由
没写过 apply 的席位在独立克隆上重跑改变的部分（一次定点执行，见 §7）。本文件不是规格：合同在
`specs/verification/spec.md`，理由与取舍在 `design.md`。

## 0 · 前置（先做，不成立就停）

- [ ] 0.1 `git merge main`，确认 **P329 已落地**：看它的**落地记录**（提交在位 + 看板 `done`）。再核对**它负责的
  那一片**：§34⑦/§34b⑨ 里不再有「从记录里的 `expected` 重算上限」的算式（`smoke.sh:16486-16491`、
  `:16696-16705` 那两条现场）。未落地 → 写 `BLOCKED:` 交回 PM，**不许**自己改同一批断言（两个写者会互相覆盖，
  `design.md` §5）。**前置不靠整文件里的字符串计数**：`expected=400` 在 `smoke.sh:16463` 是注释、`CAP_WANT`
  是夹具变量名，它们在整个文件里出现几次与「那批断言退了没有」不是同一件事（整文件计数只作报告里的一行附注）。
- [ ] 0.2 记下改动前的现场（报告要用）：`gate_lock_expected skills/teamsmith/tests/smoke.sh /dev/null` 的三个字段、
  一次 `gate_lock_cap <lock> <W>` 的返回、§34⑦/§34b⑨ 的现场行号。

## 1 · product：把「上限」换成「心跳耐心」（`scripts/lib/gate-lock.sh`）

- [ ] 1.1 删 `gate_lock_cap`（`:463-477`）与它的注释口径：`expected` 投影、`remaining`、`clamp`、四个返回形状，
  连同 `gate_lock_cap_pair`（`:392-397`）。
- [ ] 1.2 加 `gate_lock_path_mtime <path>` → epoch 秒（`stat -c %Y`，BSD 兜底 `stat -f %m`，与既有
  `gate_lock_path_identity` 同一个两平台写法）；读不到 → 非 0。
- [ ] 1.3 加 `gate_lock_heartbeat_newest <lock>` → `path<TAB>mtime`：遍历 `<lock>.holder` 与 `<lock>.runs/*.run`，
  只取 `gate_lock_record_live` 为真的条目，读它公布的 `heartbeat=`（空/`-` 跳过），取 mtime 最新的一个；没有 → 空。
  **不新增字段、不新增协议**：这就是等待者点名持有者时已经在 glob 的那两个位置。**不校验**登记与当前持有者的
  祖先关系 —— 这条放宽与其上界（遗留活登记最坏把上限顶到 `4W`）写在 `design.md` §3，不要在实现里补认证。
- [ ] 1.4 加 `gate_lock_patience <lock> <wait>` → `ceiling<TAB>state<TAB>silent_for<TAB>heartbeat`：
  `silent_for < wait` → `state=live`、`ceiling=4×wait`；文件在但 `silent_for >= wait`（**边界归这一侧**）→
  `state=stalled`、`ceiling=wait`；没有活登记公布、公布的是 `-`、或路径上的文件不在 → `state=none`、`ceiling=wait`。
  `gate_lock_patience_pair <published lock> <wait>` 与旧 `_pair` 同形（记录优先读伴生锁边上那份，旧写入者退回
  发布路径）。
- [ ] 1.5 **现在的时刻一律取自既有的 `gate_lock_now`**（`gate-lock.sh:33`；`gate_lock_cap` 本来就是这么写的），
  新增代码里不出现裸 `date +%s`。这样判据在测试里可以被钉住，不需要新时钟、不需要产品钩子。
- [ ] 1.6 可控输入定点证据（不起进程、不依赖真实秒差）：测试子 shell 里**局部覆写** `gate_lock_now() { printf '%s\n' "$PIN"; }`，
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
  命令与输出进报告。

## 2 · 四个排队点与两处文案

- [ ] 2.1 `tests/smoke.sh:532` 与 `scripts/lib/cmd-review.sh:1144` 换成 `*_patience_pair`，`read` 出
  `ceiling/state/silent_for/hb`。**每轮重读**（排队本来就是一秒一轮）。
- [ ] 2.2 排队行（`smoke.sh:536`、`cmd-review.sh:1151`）去掉 `remaining=`/`cap=` 算式，换成一句说明上限来自哪里：
  `live`（`silent_for=Ns`）→ 上限 `4×W`；`stalled` → 「心跳已停 Ns」；`none` → 「没有可用心跳」。
  必须保留的子串（既有断言依赖）：`另一套全量 smoke 正在跑`、`TEAM_SMOKE_LOCK_WAIT=<W>s`、`4×`。
- [ ] 2.3 失败行（`smoke.sh:548`、`cmd-review.sh` 的 `gates_out`）保留今天的形状：`排队超限：等满 Ns …（持锁者：…）`
  → `本套**没有运行**` / `**门禁没有运行**`、退出码仍是 2 / 判定仍是 `FAIL`（不是 `TIMEOUT`），后面多一句原因
  （`心跳仍在动，但到了硬顶 4×W` / `心跳已停 Ns` / `没有可用心跳`）。
- [ ] 2.4 `tests/perf.sh:180` 换同一个读数（`state=none` → `W`，行为不变）。
- [ ] 2.5 定点证据：`grep -n 'remaining=' skills/teamsmith/tests/smoke.sh skills/teamsmith/scripts/lib/cmd-review.sh`
  必须无输出。

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

- [ ] 3.1 §34b⑨ 的现有断言按上表改写：两条留用的（`没有心跳 → ceiling=W`、`W=1000/10` 的上下限）改成纯函数腿，
  再补边界 `silent_for == W`、`silent_for == W-1`、文件不在 → `none` 三条（全部用 §1.6 的钉住时刻与绝对 mtime）。
  §34b① 的**现有** `none` 失败现场只加一句原因断言（`没有可用心跳`），不新建夹具。
- [ ] 3.2 **正向（`team review` 形状）**：持有者是走 review 路径的夹具 —— 记录写在**伴生锁**边上
  （`$(gate_lock_companion_path "$LOCK")`，`heartbeat=-`），跑的门禁子套件经祖辈证明后以 **`kind=nested` +
  `ancestor=<holder pid>`** 登记自己，登记里公布一个心跳文件（后台按默认节奏重写它；**重写频率不作可靠性条件**）。
  `TEAM_SMOKE_LOCK_WAIT=1000`：整秒差与调度抖动远小于这个界，所以 `state` 不会被时钟噪声翻成 `stalled`；`timeout`
  只作防死等兜底。**它只证三件事**：① 子登记公布的那条心跳被真的发现（排队行里 `state=live`）；② 排队行在同一处
  打印了 `state` 与两个上限；③ 持有者看到这条排队行后**释放锁**（事件同步，不是睡固定秒数），等待者随后拿到锁、
  `rc=0`。它**不证明「等待者已经越过 `W`」**——那件事由 §1.6 的钉住时刻输入腿承担。
- [ ] 3.3 **反例（同一条断言）**：把 `gate_lock_heartbeat_newest` 改成只读 `.holder`（于是 review 形状永远是
  `heartbeat=-` → `none`）→ 3.2 的那条断言必须红；还原后回绿。这是本 change 唯一保留的反向对照。
- [ ] 3.4 **不重演等待循环的消耗与既有超限行为**：`排队超限` 的失败形状（`rc=2`、点名、`没有运行`、`FAIL` 不是
  `TIMEOUT`）由 §34b①/⑦ 的既成断言守；本 change 不复制它们，也不新增「等满第几秒」的场次。
- [ ] 3.5 **停滞（`stalled` 的失败行）**：与 §34b① **同形**的夹具（私有锁、`W=2`、记录公布一个
  **mtime 用绝对值写在 60 s 前**的心跳文件、`timeout` 只作兜底）。断言：`rc=2`、失败行含 `排队超限`、`心跳已停`，
  点名 `cmd=`。**不测「在哪一个秒区间完成」**：`silence` 只会随时间变大，不可能回到 `W` 以下，所以不存在边界抖动。
  **持有者按事件收尾**：等等待者返回（失败行已出现）后它才释放锁，不用固定 `sleep 20` 让它在前面提前放锁 ——
  否则就换成另一种调度竞态。
- [ ] 3.6 §34⑦ 保留 `TEAM_SMOKE_LOCK_WAIT=200s` 那条断言（下限仍被打印）；不加换场次。
- [ ] 3.7 断言账按 `diff` 的实际删改写进报告：删掉哪几条、改写哪几条、新增哪几条、每条的接管者是谁
  （P329 先删的记在它名下）。**不按场景数或翻转配额凑数。**
- [ ] 3.8 **「每轮重算」的可证伪验证：实施阶段未解决项（不拿墙钟做替代）**。合同与 §2.1 要求 `state`/上限
  **每轮重算**，但现有输出（排队行、失败行、产品的 `等满 Ns`）只能证明「它此刻认定的上限是多少」，**不能区分**
  「每轮重算」与「排队时算一次就缓存」：缓存的实现在持有者停跳后照样写 `心跳已停`，只是白等到 `4W`，而唯一可观察的
  差异是**真实 elapsed** —— 拿它做判据又是一条墙钟带，本 change 不采用（`等满 Ns` 就是产品记录的真实 elapsed，
  读它并不比量墙钟更稳定）。所以：① 实施阶段要让「重算」在**代码结构**上可核（上限在每一轮循环里从记录现算，
  没有跨轮缓存）；② 独立审阅在 verify 时**核循环内的调用点**、确认没有缓存，并把结论写进复验记录；③ 若实施阶段
  找到**非计时**的可证伪判据，就在那个 change 里补上；**找不到就在报告里写明这个缺口，不许宣称缓存反例已被杀死**。

## 4 · 生效文档对齐

- [ ] 4.1 `skills/teamsmith/references/protocol.md` §9b-2：把「The queue cap follows the holder's published
  expected duration」那段改写成心跳口径（与 delta 同一件事：`state`/两条上限/`expected` 不再决定耐心），并顺手把
  「its expected duration and its bound (the section table's Σband / Σbudget …)」改成现状（P316 之后没有生产者，
  字段留下当诊断）。**不留第二份口径**。
- [ ] 4.2 `grep -n 'remaining=\|clamp(remaining' skills/teamsmith/references/*.md skills/teamsmith/SKILL.md`
  的输出贴进报告，确认没有第二处旧算式。**模式里不含 `4 ×`** —— 那正是 §4.1 要求写进去的新措辞，把它放进
  检查会让这条永远不可能干净。

## 5 · 现场的共同前提（不重复造场面）

- [ ] 5.1 所有真实进程现场：私有锁 + 私有 `TMPDIR` + 自选 `TEAM_SMOKE_LOCK_WAIT`（与 §34b⑦ 的 `p281_waiter`
  同形），不碰机器锁。
- [ ] 5.2 记录里的 `started` 回填到 120 s 之前（理由见 §3 表头）。
- [ ] 5.3 `timeout` 只作**防死等兜底**；断言只看 `rc`、失败行、排队行里的 `state`/两个上限与产品自己打印的
  `等满 Ns`，**不看「第几秒退出」**。

## 6 · 最终一次运行 + 报告

- [ ] 6.1 `openspec validate --all --strict`（21 项）、`bash skills/teamsmith/tests/spec-refs.sh --check`、
  `git diff --check && git status --short`。
- [ ] 6.2 定点**执行**（不是查表）：`bash skills/teamsmith/tests/smoke.sh --select 34,34b,34d,36`。这四段覆盖了
  产品面里**所有**断言排队行/记录的段（34 `smoke.sh:16461-16491`、34b `:16688-16708`、34d `:17383-17527`、
  36 `:17655-18071`）。`section-select.sh` 只用来**查表**（`--list`/`--select` 打印 `decision=RUN`/`keys=N` 就退出，
  一段都不跑），不能当执行证据；`--paths` 也缩不窄（它把 `smoke.sh` 本身算成 17 个键、四份文件合计 46 个键 =
  全量 135 段）。
- [ ] 6.3 **不再跑 FAST 全量**：整套只跑一次，放在合并/发布。定点可能漏的键（`gate-lock.sh`/`cmd-review.sh`
  映射到但不过排队行的那些）由那一次全量覆盖 —— 这就是保留它的理由。
- [ ] 6.4 报告 `docs/team/reports/<ID>-<agent>.md`：先给结论，再给「删了什么/加了什么」与断言账、§1.6 与 §3 的
  原始输出尾部、两条未验项（§61b 的静默段是源码推断、未实测；`expected` 生产者未退役）。

## 7 · verify（独立席位，非 apply 作者）

- [ ] 7.1 在自己的克隆上跑同一条定点**执行**：`bash skills/teamsmith/tests/smoke.sh --select 34,34b,34d,36`，
  给结果行与新增断言的原文；不复用 apply 的日志，也不拿 `section-select.sh` 的查表输出代替。
- [ ] 7.2 只做一条反向对照：把心跳来源改回只读 `.holder` → §3.2 正向必须红（「读全部活登记」的唯一控制）。
  另两条（放宽判据、把 `none` 判成 `4W`）与 §3 各条已写明的破口重复，删。
- [ ] 7.3 确认没有回归：§34b①/⑦ 的排队超限语义（`rc=2`、点名、`没有运行`、`FAIL` 不是 `TIMEOUT`）与
  `TEAM_SMOKE_FAST`（`no_lock=1`、不排队）都没变；§4.2 的 grep 干净。
- [ ] 7.4 复验记录写 `docs/team/reviews/<ID>.md`，只有复验通过且用户确认后 PM 才归档。
