# V68 · 独立审阅「等待者的耐心跟随心跳」提案：机制成立，文本与验证计划要收

task: V68   status: delivered   time: 2026-10-20T07:05Z   phase: verify
branch: `task/V68-waiter-proposal-review`（本分支只放报告，不改提案/规格/产品/测试）
受检原件：`openspec/changes/gate-waiter-patience/{proposal,design,tasks}.md` + `specs/verification/spec.md`
与 `docs/team/reports/P332-dev3.md` @ `6be339045201`；实现现状读本分支
`skills/teamsmith/scripts/lib/gate-lock.sh`、`skills/teamsmith/tests/lib/section-guard.sh`、
`skills/teamsmith/scripts/lib/cmd-review.sh`。
方式：**纯静态审阅**，只做只读 grep 与 `section-select.sh --paths/--select/--list` 的纯表查询；
没有跑选段、全量、容器、探针或计时实验，因此本报告不报任何「测试通过」。

## 判定：PARTIAL —— 机制可实施，提案原件要收 7 处文本/计划

一句话：用「活登记的段心跳」替掉「没有生产者的 `expected` 投影」这个方向与落点都成立（心跳确实在顶层
与 `team review` 两种真实形状里被写，且不是「进程活着」的同义词），但提案文本现在有**三处自相矛盾**、
**一处论证不成立**、**一处动机数据在 P316 之后已经不成立**，验证计划又把产品语义写成了负载敏感的墙钟带、
并把五条手跑场景重复了三遍。七处全部落在 change 文件夹与 `tasks.md` 的措辞/步骤上：不要求新协议、新守卫、
新夹具，也不改任何产品行为。

没有 FAIL 级缺陷：没有一条会让 apply 把产品行为做错。

## 阻塞项与最小改法（apply 前逐条收）

| | 位置 | 现在写的 | 与什么冲突 | 最小改法 |
|---|---|---|---|---|
| B1 | delta 正文第 1 段 | `the queue wait MUST be bounded by TEAM_SMOKE_LOCK_WAIT (default 1800 s)` | 同一条 requirement 的新段落允许上限到 `4 ×` | 在那一句后面加一个从句：`… (default 1800 s), extended to 4 × that while the holder's heartbeat keeps moving (below)`。一句话，不改任何行为 |
| B2 | delta「An older record with no heartbeat…」场景 | `its output does not claim any heartbeat state` | 正文要求失败行 `say whether … or had never been published`，且排队行本身就要打印 `state` | 把那一句改成 `does not claim a moving or stalled heartbeat`（「没有可用心跳」是可观测事实，不是编造的状态） |
| B3 | delta 场景名 `The cap follows the holder's published remaining time` | 名字断言这件事仍在发生 | 正文检验的正是它**不再**发生（`fails at 2 s instead of waiting out the published remaining time`） | 工具拒绝丢/改场景名（作者实测报错在 P332 报告里），所以在正文末尾补一句 `the cap no longer follows the published remaining time`，把名字降级为「这个字段还在被打印的历史场景」。整条退役重加会让 `docs/team` 十来处引用变 `retired`，不是最小改法 |
| B4 | design §2.1 | 「用『已等 ≥ ceiling』换来的是不同时产出两条红」 | 见 §2 的三钟分析：等待者**已经在等**时（唯一会双红的场合），心跳停到 `W` 与持有者自己的挂住上限是**同一个事件、同一个阈值**，ceiling 回落到 `W` 的那一轮等待者必然已经 `≥ W` → 当轮就失败 | **删掉这段论证**，不改判据。判据留着的真实理由是「只有一个时钟」、§34b①/⑦ 的 `已跑/等满 Ns` 语义逐字不变；同时把真正的残余写一句：已经等过 `W` 的等待者会在心跳转 stale 的同一轮失败，与持有者的挂住红同秒 |
| B5 | proposal「Why」第 2 个 bullet | 把「§61b 路由变异 82 分钟」列为**等待者误杀**的合法长跑 | P316 之后每段上限平 1800 s，而 §61b 正文（`smoke.sh:22392-22401`）是单次子进程、中间没有 tick → 它今天会先被自己的看门狗 trip（`section-guard.sh:408-447`），不是「合法的长时运行」；本 change 也延长不了它的耐心（心跳不动） | 把动机实例换成**靠 tick 变长的运行**（总时长超 `W`、每段都在 1800 s 内、断言一直在 tick：全量 35 分钟量级就是这种形状），并把「无 tick 的长段今天仍按 `W` 失败，本 change 不改变它」写成一句边界（design §7 已有 §61b 那条，只是 proposal 的口径与它相反） |
| P1 | tasks §5.3 / §5.4 | `2 s 左右失败`、`用时落在 [7,10] s` | 负载敏感墙钟带（项目规则 2842 要删时间阈值；本任务书也禁止恢复它） | 见 §4：改成产品自己打印的 `等满 Ns` 的**语义下界**（`≥ W`、`≥ 4×W`），再用 `timeout` 卡在 `W` 与 `4×W` 之间来区分「平 W」与「4W」，不用测量值 |
| P2 | tasks §7.1 / §7.2 | 复验再手跑 1.5 四条 + 5.1–5.5 五条，再跑三条反向对照 | 5.1/5.2/5.3 与 §34⑦/§34b⑨ 将要加的断言是同一批行为；7.2 的三条反向对照与 §5 每条已经写好的「破口」重复两条 | 把**只有手跑、没有断言**的两条（硬顶、review 形状）升级成 §34b⑨/§34⑦ 的断言；复验改跑一次 `--select 34,34b,34d,36`；反向对照只留「心跳来源改回只读 `.holder` → review 形状那条红」 |
| P3 | tasks §0.1 / §6.2 | 前置 `grep -c 'expected=400' = 0`；`--paths` 之后手动 `--select 34,34b` | `expected=400` 在 `smoke.sh:16463` 是**注释**，P329 的任务书只删「只为自造数字服务的 cap/remaining 断言」、没说要删这条注释 → 前置可能永远不成立；而 `--paths` 实测返回 46 个键（=135 段），不是 34/34b | 前置改成 `grep -c 'CAP_WANT' skills/teamsmith/tests/smoke.sh` = 0（实测现在 9 行，P329 删的就是这 9 行）；§6.2 写成「跑 `--select 34,34b,34d,36`（四个断言排队行/记录的段），一句话说明 `--paths` 在这里缩不窄」 |

## 一 · 必答点 1：规则一致性

**(a) `W` 与 `4W`。** delta 第 1 段仍写 `the queue wait MUST be bounded by TEAM_SMOKE_LOCK_WAIT`，
第 3 段写「心跳在动 → cap SHALL be `4 × TEAM_SMOKE_LOCK_WAIT`」。按字面读，一条 requirement 里的两个上限
互相否定（一个是常量、一个是四倍常量）。这是**同一份 delta 内部**的冲突，与实现无关 → B1。

**(b) 「不声称心跳状态」与「说出没发布过」。** 场景
`An older record with no heartbeat keeps today's patience` 的 THEN 有两个断言：`prints ? for the fields the
record does not carry`（与 §34b① 的既有形状一致，`gate_lock_describe_one` 就是这么打的）和
`its output does not claim any heartbeat state`。而正文要求失败行 `say whether the heartbeat was still moving
at the ceiling, had been silent, or had never been published`，且**排队行**在每一版设计里都要打印
`state`（tasks 2.2 明写）。所以「不声称任何心跳状态」既与失败行冲突，也与排队行冲突。可观测且不编造的
最小口径是「不声称心跳**在动或已停**」→ B2。

**(c) 不再发生的行为顶着旧名字。** 场景名 `The cap follows the holder's published remaining time` 断言的是
被本 change 退场的行为，正文（`fails at 2 s instead of waiting out the published remaining time`）检验的
是它退场。工具拒绝丢场景（作者记录的报错原文：`MODIFIED "…" omits scenario(s) the current spec still has`），
所以最小纠正只能落在正文：一句话点明「上限不再跟随它」→ B3。整条退役重加不是最小改法（`docs/team` 里
十来处 `verification#The hard timeout covers the gate run, not the queue` 会变 `retired`，读者跟不过去）。

**(d) 边界值的两句话说反。** 正文用 `moved within TEAM_SMOKE_LOCK_WAIT` 判 live、`has not moved for
TEAM_SMOKE_LOCK_WAIT` 判 stalled；两句在 `silent_for == W` 处重叠，而 design §2 的表写的是
`silent_for < wait` → live、`>= wait` → stalled。夹具用的就是 `W=1..30` 的整数秒，这条边界一定会被撞到。
最小改法：正文统一成一句 `a heartbeat whose last movement is at least TEAM_SMOKE_LOCK_WAIT ago counts as no
usable heartbeat`，别一处写 `within`、一处写 `not moved for`。

## 二 · 必答点 2：心跳可见性，以及 design §2.1 的双红论证

### 2.1 心跳确实可见，且不是「进程活着」

写入方一处实现：`section_guard_write_heartbeat`（`section-guard.sh:202-214`）把
`<TMPDIR>/.teamsmith-smoke-heartbeat.<pid>` 原子重写，触发点只有三个——开段（`:294-307`）、每次断言
（`section_guard_check` `:234-240` → `section_guard_progress_tick` `:215-221`，`ok()/bad()/skip` 全走它）、
收段（写 `disarm`）。持有者自己的看门狗（`:408-447`）判挂住用的就是同一个文件的 `ticks` 字段。
所以 mtime 的三种含义可以分开：

- **mtime 变了**：至少发生了一次断言、或一次开段/收段 —— 是真进展证据，粒度是「一条断言」；
- **ticks 变了**：同一件事的子集（开段/收段会刷新 mtime 但不加 tick），所以用 mtime 只会比用 ticks 更宽松，
  不会更严；
- **只看「进程活着」**：`gate_lock_record_live`（`gate-lock.sh:356-362`）只核对 pid 与 starttime，它只能
  当「读哪条记录」的过滤，不能当进展证据 —— 提案的正确之处正是拿它过滤、再读 `heartbeat=` 指向文件的
  mtime，而不是把「记录活着」当心跳。

### 2.2 两种真实形状，心跳都只写在子登记里

- **顶层**：取锁的**包装器**写 `.holder`，公布的是 `section_guard_heartbeat_path "$$"`（`smoke.sh:559-562`），
  但包装器自己不武装段守卫（它随后 `bash smoke.sh "$@"` 起子套件，`:617-621`）→ 那条路径**从头到尾没人写**。
  真正在动的是子套件：它在 `smoke.sh:871` 自己 `section_guard_init`，并以
  `gate_lock_register_run … "$(section_guard_heartbeat_path "$$")"`（`:668-673`）登记 `.runs/<pid>.run`。
  作者在 design §1.2 的探针现场（`.holder` 公布 2815796、唯一在动的是 `.runs/2817178.run`）与这条调用链
  完全一致。
- **`team review`**：持有者记录写死 `GATE_HB=-`（`cmd-review.sh:1169`、`:1200`）；它起的门禁套件用
  `gate_lock_prove_ancestor_pair`（`smoke.sh:471-476`）把 review 的 pid 证明成祖辈 → `kind=nested` →
  同样 `gate_lock_register_run`（`:668-673`）登记自己的心跳。
  **这一条是静态推断，不是现场**：作者的探针只覆盖了顶层形状。所以 tasks 5.5 不是可有可无的重复，它是
  这个形状的第一次实证 —— 应当在门禁里落成断言（§4），而不是每轮手跑。

### 2.3 §2.1 的双红论证不成立（B4 的依据）

design §2.1 说：若等待者「一观察到 stalled 就失败」，会把一个刚被段守卫判挂住、正在写现场 + TERM→KILL 的
持有者先判死，产出两条红；用「已等 ≥ ceiling」则「最坏只让等待者多等 `W`，换掉的是一次双红」。

设持有者最后一次 tick 的时刻是 `L`（= 心跳 mtime），段守卫挂住上限 `cap_h`，等待者起点 `T0`、上限 `W`：

- 看门狗在 `t = L + cap_h` 判挂住（判据是 `now - last_moved >= cap`，`last_moved` 就是 `L`）；
- 等待者在同一时刻算 `silent_for = t - L`，`>= W` → `state=stalled` → ceiling 落回 `W`；
- 等待者的失败判据是 `t - T0 >= ceiling`。在 `t = L + W` 这一轮：若 `T0 <= L`，则 `t - T0 >= W` →
  **当轮失败**；若 `T0 > L`（等待者是心跳停之后才来的），则当轮还不失败，但持有者已经在 `L + cap_h`
  被 trip、几秒后放锁（作者自己算的是约 2 s + 6 s），等待者拿到锁、根本走不到自己的截止时刻。

结论：**双红恰好发生在「等待者已经在等」这一种场合，而它正是 §2.1 想救的那一种**；默认 `cap_h = W = 1800`
时，两个阈值由同一个事件同时到达，所以「已等 ≥ ceiling」换不来任何延迟。若两个旋钮不相等（等待者
`W=600`、持有者 `cap_h=1800`），ceiling 回落到 600 还会让等待者比持有者自己的 trip 早 20 分钟判死。
另一个方向（等待者在心跳停了之后才来）本来就不会红，且与判据无关（取锁检查在超限检查之前）。
所以：**删掉这段论证，判据不动**。判据留着的真实理由只有一条 —— 「等待者只用自己那一个时钟」，这保住了
§34b①/⑦ 的 `已跑/等满 Ns` 语义；想保住「双红」的说法就得给推迟规则（例如转 stalled 的那一轮宽限一次），
那是第二条耐心规则，违反本 change 的净零。

需要写进 design 的残余一句：**已经等过 `W` 的等待者，会在心跳转 stale 的同一轮失败**，与持有者的挂住红
同秒；契约（delta 正文 + 场景 `A heartbeat that stops moving ends the wait at the flat cap`，后者把现场限定为
「a waiter that starts after the heartbeat went silent」）本身是对的，错的只是 §2.1 给的理由。

## 三 · 必答点 3：扫描范围是否限定为「当前锁的实际持有运行」

- **按锁路径限定，够用**。`gate_lock_patience_pair` 先用既有的 `gate_lock_record_source`
  （`gate-lock.sh:234-252`）在伴生锁与发布路径之间选**记录所在的那一侧**，再扫那侧的 `.holder` 与
  `.runs/*.run` —— 与等待者点名持有者时 `gate_lock_describe`（`:400-419`）、以及给嵌套运行定期限时
  `gate_lock_heartbeat_of_pid`（`:341-354`）扫的是**同一对位置**。所以「本锁的登记」这层关联已经存在，
  「取最新」只是把后者的 pid 过滤去掉，不需要第二套认证或监测（提案也确实没加：无新字段、无新文件、
  无新循环）。
- **它不是「持有者那条运行」**，这是有意的：两种真实形状里持有者记录那条都是空/`-`（§2.2）。把
  `kind=nested`、`no_lock=1` 的登记也算进来，等于「这棵运行树还有人在推进」，与 requirement 正文的
  `any live record of that lock` 一致。
- **已知的放宽（要在 design 写一句）**：`gate_lock_record_live` 不比对记录里的 `lock_identity`/`lock_dev_ino`
  与当前锁的身份，所以一条**遗留但进程还活着**的登记（例如泄漏的孤儿段守卫）仍在 tick 时，会把上限顶在
  `4W`，而持有者可能已经卡死 —— 默认值下最坏是 2 小时而不是 30 分钟。这是有界的，且与「嵌套运行也是这棵树
  的进展」这个口径一致，建议**接受并写明**；若 PM 要更紧，现成的字段就是每条记录已经在写的 `ancestor=` 与
  `lock_dev_ino`（P287），用它们收紧即可，仍然不需要新认证、不需要新监测。
- **公开 holder 没心跳 + 子登记有心跳**（review 与顶层两种形状）复用的就是同一次读取：`.holder` 里
  `heartbeat=-`/空 → 跳过；`runs/*.run` 里那条 → 读它公布路径的 mtime。没有第二条读法。

## 四 · 必答点 4：验证计划的减法

先给两条实测的规模事实（纯表查询，没有跑段）：

```
$ bash skills/teamsmith/tests/section-select.sh --paths <gate-lock.sh cmd-review.sh perf.sh protocol.md>
decision=RUN   sections=135   keys=46
$ bash skills/teamsmith/tests/section-select.sh --select 34,34b,34d,36
decision=RUN   sections=135   keys=8      # 0 0b 0c 0d 前导 + 34 34b 34d 36
```

四个段覆盖了产品面里**所有**断言排队行/记录的地方：34（`smoke.sh:16461-16491`）、34b（`:16688-16708`）、
34d（`:17383-17527`）、36（`:17655-18071`）。所以最小必要入口是 `--select 34,34b,34d,36`，而 `--paths`
在这里缩不窄（它把 `smoke.sh` 这个测试文件本身算成 17 个键，四份产品/文档文件合计 46 个键）。tasks §6.2
现在的写法（先 `--paths`、再手动 `--select 34,34b`）两头都不对：既没照选择器的输出跑，也漏了 34d/36。

**时间带要删，语义要留。** 三条被删的墙钟带与替代它们的判据：

| 现在 | 改成 | 丢掉了什么 |
|---|---|---|
| 5.3「约 2 s 失败」 | `W=2`、旧形状记录：`rc=2` + `排队超限` + 点名 + `没有运行`，并把整个等待放进 `timeout 4`（低于 `4W=8`）→ 「按 `4W` 等」的实现在 4 s 被杀（`rc=124`） | 只丢「机器负载下第几秒退出」；`W` 与 `4W` 仍被区分开，这是产品语义 |
| 5.4「用时落在 `[7,10] s`」 | `W=1`（`4W=4`）、持有者 `sleep 20`、`timeout 12`：`rc=2`、失败行含 `硬顶`、打印的 `等满 Ns ≥ 4`；无上限实现会被 `timeout` 杀掉 | 只丢测量值；「不到硬顶不判死」与「到硬顶必死」两条都被断言 |
| 5.1「等了 3 s 以上」 | 保留（它是下界，不是测量带）：`W=2`、持有者 `sleep 6`（低于 `4W=8`）→ `rc=0`、日志里没有 `排队超限` | 无 |

这些只用到既有的夹具旋钮（`TEAM_SMOKE_LOCK_WAIT` 就是函数输入）与产品**自己打印**的 `等满 Ns`，
不引入通用时钟框架；`touch -d '-10 seconds'` 那一类可控时间是 tasks 1.5 的四条纯函数腿，也不含睡眠。

**重复的减法。** 5.1/5.2/5.3 要证的三件事，正是 tasks 3.1/3.2 要落成 §34b⑨/§34⑦ 断言的三条
（心跳在动不提前失败 / 心跳停了按 `W` 失败 / 没有心跳退回 `W`）；再手跑一遍没有增加覆盖，只是把同一批
行为在每个席位重演一次。真正缺断言的是 5.4（硬顶）与 5.5（review 形状）—— 把它们**落成**
§34b⑨/§34⑦ 的两条断言，然后 apply 与 verify 各跑一次 `--select 34,34b,34d,36`（verify 在自己的克隆上），
手跑的五条删掉。断言账：−3（P329/本 change 删掉的投影腿）+ 3 条改写 + 2 条新增 = **净 −1**，不需要
「新增守卫净零配额」的豁免。

**三条反向对照只留一条。** 7.2 的②（心跳来源改回只读 `.holder`）是唯一证明 requirement
`any live record of that lock` 这句的控制，留；①（判据放宽到 `2W`）与③（`none` 判成 `4W`）与
5.2/5.3 已经写下的「破口」是同一件事，删。

**整套只跑一次。** 6.2 的「定点之后再 FAST 全量」让计划里出现三次整套运行（apply FAST + verify FAST +
合并全量）。按项目规则（2026-10-19 的裁定，full 留给合并/收尾），保留**合并/发布的那一次**，删掉 apply
侧的 FAST 全量；支持这个裁剪的证据是静态的：`gate_lock_cap` 全仓只有 4 个调用点
（`smoke.sh:532`、`cmd-review.sh:1144`、`perf.sh:180`、`gate-lock.sh:397`），全部落在 34/34b 或它们
所在的 review/perf 路径上。裁剪**可能漏掉**的是 `--paths` 映射到 `gate-lock.sh`/`cmd-review.sh` 但不碰
排队行的那些键（7b、10、11、11h、14b、15c、18b、23、26、45、55、56、59）与 review 记录的键 —— 它们由
合并侧的全量覆盖；这是保留那一次全量的理由，删掉它就没人跑。

## 五 · 没有证据的担心不列（本报告的边界）

- 本报告没有跑任何段/整套/容器/探针/计时实验，所有「今天如何」都来自源码调用关系与作者已记录的现场
  （design §1.1/§1.2 的两次实测探针、P332 报告的验收输出），不冒充复验。
- 一条**未实测的推断**已标明：§61b 今天会被自己的段守卫 trip（B5 的依据），来自 `section-guard.sh:408-447`
  的判据 + `smoke.sh:22392-22401` 的单次子进程正文；作者自己在 design §7 写下了同一条推断（未实测）。
- `team review` 形状的心跳（§2.2 第 2 条）是静态推断，作者没有该形状的探针 —— 所以它在 §4 里被要求
  落成断言，而不是被当成已经证明。
- P329 尚未落地（`git log --oneline --grep=P329` 只有一条「排队」账本提交、
  `grep -c 'CAP_WANT' smoke.sh` = 9 ≠ 0），tasks 0.1 的硬前置当前按设计不成立；这不是缺陷，只是 apply
  开工时会被它拦下。前置本身的判据见 P3。

## 六 · 落地记录

只读查询（本报告引用的全部实测）：

```
$ git log --oneline -1 6be339045201                       # 6be33904 docs(team): P332 proposal report [skip ci]
$ grep -c 'CAP_WANT' skills/teamsmith/tests/smoke.sh      # 9（P329 落地后应为 0）
$ grep -c 'expected=400' skills/teamsmith/tests/smoke.sh  # 1，且是注释（smoke.sh:16463）→ tasks 0.1 的判据不可靠
$ bash skills/teamsmith/tests/section-select.sh --paths … # keys=46 / sections=135
$ bash skills/teamsmith/tests/section-select.sh --select 34,34b,34d,36  # keys=8
```

账本禁令（P212）在提交前于本分支跑固定验收行，rc=0 后再提交；local 模式不 push。
