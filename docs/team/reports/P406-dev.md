# P406 · 自我提醒 MVP 第一片：共享权威（状态根定位 + 版本化快照 + flock 事务）

agent: dev   status: delivered（V128 三处已修）   time: 2026-11-04 04:05 +0000
branch: `task/P406-self-reminder-authority`   PR/MR: -

结果先说：1.1 与 1.2 都落地了，1.3 一个字没动（**V128 的三处修在此文末尾「V128 修复」一节，最终树以上面那一节的数字为准**）。CLI、Pulse、Pi 从今往后只有一份状态权威实现
（`scripts/state-authority.mjs`），Bash 走它的 `--cli` 面、Node 直接 `import { request }`；两边的项目身份
都由**运行时目录**解析，继承错的主根在写任何东西之前就被拒绝。快照带版本号、项目 UUID 与持久序号，
每次变更是一把 `flock -x -w 5` 包住的事务（临时文件 → fsync → rename → fsync 目录），缺 `flock`、等锁超时、
快照读不懂都是具名失败，没有不持锁的落回路径。夹具 68 条断言全绿，其中四条红侧与一次按命名白名单判定的事故形状隔离
证明；选段门禁（`2,18b,40,66`）✓124 ✗0。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/state-authority.mjs` | 唯一的权威实现：项目定位器（`<main>/.pi/team/reminder-locator.json`，路径 + 项目 UUID）、版本化快照（`<state>/reminders/state.json`）、`flock` 事务、原子写（文件 + 目录 fsync）、持久 reminder/batch/queue 序号；`request()` / `resolve()` 供 Node，`--cli resolve\|init\|read\|allocate` 供 Bash |
| `skills/teamsmith/scripts/lib/common.sh` | Bash 入口 `team_authority_state_root / _init / _read / _allocate`，以及「继承的 `TEAM_MAIN_ROOT` 与目录不一致就拒绝」的守卫（新增 37 行，其余未动） |
| `skills/teamsmith/tests/state-authority.sh` | 隔离夹具：每个仓先 `git init`、显式主根/状态根、独立 `HOME`/`TMPDIR`、A 的真 link worktree；58 条断言 + 三条红侧 + 事故形状证明 |
| `skills/teamsmith/tests/state-authority-node.mjs` | 夹具的 Node 侧驱动：并发写入者与「继承来的主根」用例（可被红侧指向变异副本） |
| `skills/teamsmith/tests/smoke.sh` | 新段 `66`：跑夹具、校验它自己的结果行、并在段内再钉一次隔离证明 |
| `skills/teamsmith/tests/section-paths.tsv` | 段 66 的归属行（产品实现、两个夹具、本段） |

## Verification evidence (must have actually been run)

选段（按改到的路径选：产品 `scripts/state-authority.mjs`、`lib/common.sh`、`tests/state-authority*`、
`smoke.sh`；最终树上跑的那一次）：

```
$ bash skills/teamsmith/tests/smoke.sh --select 2,18b,40,66
== 选段 == decision=RUN · 运行 8/136 段 · 未跑 128 段
#5 2 · init · 参考 用时 2s · ✓39 ✗0 SKIP0 · ticks 39
#6 18b · 拆分不变量（P16）… · 参考 用时 1s · ✓16 ✗0 SKIP0 · ticks 16
#7 40 · 临时根纪律（P53…） · 参考 用时 59s · ✓42 ✗0 SKIP0 · ticks 42
== #8 66 · 项目状态权威：状态根 / 版本化快照 / flock 事务（P406 · agent-self-reminder 1.1/1.2） ==
  ✓ P406 权威层夹具全绿（✓68 ✗0 SKIP0：状态根 / 快照 / flock / 原子写 / 四条翻转臂）
  ✓ P406 隔离证明：主项目的非白名单路径零变化
  ✓ P406 隔离证明：state/ 下的杂散文件会被点名（事故形状）
#8 66 · … · 参考 用时 22s · ✓3 ✗0 SKIP0 · ticks 3
账本自查： 8 段收口 · 增量 ✓124 ✗0 SKIP0 ｜ 结果行 ✓124 ✗0 —— 一致
== 选段结果 ==  ✓ 124  ✗ 0
$ echo $?
0
```

**这次没跑的段（128 个键，照日志原样）**：`0e 0f 0g 0h 0i 1 1b 1c 3 4 4b 4c 5 3b 6 6b 6c 6d 6e 6f 6g 6h 6i 6j 6k 7 7b 8 9 10 10b 10c 11 11b 11b2 11b3 11b4 11c 11d 11e 11e2 11f 11g 11h 11i 11j 14b 15b 15c 12 13 13b 13c 12b 12b-h0 12b-h0b 12b-h0d 12b-h0c 12b-pi 12b-pi2 12b-pi3 14 14c 54 14d 17 18 18c 19 20 21 22 23 24 25 26 27 28 29 30 31 31c 32 33 12e 12f 12g 12h 12i 12j 12k 34 34b 34c 34d 35 36 37 38 39 41 42 43 44 45 46 47 48 49 50 51 51b 51c 52 53 57 58 15 55 56 59 60 61 61b 62 63 64 65`。选段不是全套门禁：交付/复验/归档仍跑全套，本片没有跑全量。

夹具单独跑（最终树，`rc=0`；下面的 ✓ 列表是全部断言里的代表项，总数以结果行为准）：

```
$ bash skills/teamsmith/tests/state-authority.sh
  ✓ 未初始化的权威：read 显式失败并点名 not initialized（不当作空快照）
  ✓ 主检出解析出项目自己的状态根
  ✓ link worktree 解析出同一个状态根
  ✓ 主检出与 worktree 共用一个持久序号（1）
  ✓ 冲突的 TEAM_STATE_DIR：显式拒绝（canonical state-root mismatch）
  ✓ 别的项目的 .pi/team 作为状态根：显式拒绝（inside another project's .pi/team）
  ✓ 定位器指向别的项目：显式拒绝（belongs to another project）
  ✓ 外来快照（项目身份不符）：显式拒绝（project identity mismatch）
  ✓ 未锁定入口（继承的 TEAM_MAIN_ROOT 与目录不一致）：显式拒绝，不挑一个权威
  ✓ 锁定入口按目录解析出本项目
  ✓ 锁定入口对会改共享状态的命令返回拒绝
  ✓ Node 入口（Pulse/Pi 形状）：cwd 属于 A、继承的主根指向别的项目 → 显式拒绝
  ✓ 快照损坏（unsupported version / half snapshot / no project identity）：
       read 与 init 都显式失败，文件一字未改（6 条）
  ✓ 孤儿 .tmp 不会被当成快照（read 正常，残留文件不被误删）
  ✓ 锁被占：显式超时失败（点名 5s），不静默重试
  ✓ 锁等待有界（实测 5087ms ≈ 5s 上限）
  ✓ 持锁者被杀后锁立刻释放（104ms 内下一个事务成功）
  ✓ 6 个 Bash + 6 个 Node 写入者（TMPDIR 各不相同）拿到 1..12
  ✓ 并发结束后持久 high-water = 13（没有丢更新）
  ✓ 锁是状态根下唯一的一份（与 TMPDIR 无关）／TMPDIR 里没有落下任何锁文件
  ✓ 12 个被杀写入者之后快照仍可读（无半个文件）
  ✓ 本片（1.1/1.2）不读不动旧的 standby 标记
  ✓ 新快照的 Standby 槽位是 generation 0（迁移留给 1.3）
  ✓ 助手自己死掉：报 transaction helper exited with status 137（不冒充等锁超时）
  ✓ 助手死掉时没有多余的「超时」措辞（两种失败不再混为一谈）
  ✓ 助手死掉时立即返回（62ms，没有白等 5s）
  ✓ 助手死掉时状态一个字节没动
flip 臂：unlocked,version,foreign,manifest
== state-authority 结果 == ✓68 ✗0 SKIP0
$ echo $?
0
```

**隔离证明（brief 要求贴一次）**——夹具跑完，真实项目的 `.pi/team` 前后清单一致，且事故形状的四个路径
不存在：

```
  ✓ 主项目 .pi/team：非白名单路径零变化（钉住 2 个文件；同期白名单内 4 个运行时文件在动，按名字放行）
  ✓ 白名单没有覆盖权威写面（加名字遮不住事故形状）
  ✓ 只动白名单形状的运行时文件：不算违规（判据不是「一切都不许变」）
  ✓ state/ 下的杂散文件必须被点名（事故形状）
  ✓ state/ 之外的新文件同样被点名
  ✓ 事故形状：主项目里没有出现 .pi/team/reminder-locator.json
  ✓ 事故形状：主项目里没有出现 .pi/team/state/reminders
  ✓ 事故形状：主项目里没有出现 .pi/team/state/standby
  ✓ 事故形状：主项目里没有出现 reminder-locator.json
    证明对象：<本项目主检出>/.pi/team（活团队 state/ 下 4738 个运行时文件不参与；权威写面单独比对）
```

写清楚这条证明的口径：它是**命名的易变白名单**，不是「整段跳过 `state/`」（V128-F3）。白名单按形状写死
（巡检 append 日志、`state/bg`、`state/inbox-watch`、锁、spawn 记录、每会话草稿、release 笔记……，见夹具
`state_volatile()`），其余任何路径出现、消失或内容变化都算违规——包括 `state/` 下一个杂散文件。真实项目
此刻**还没有** `state/reminders`（迁移是 1.3），所以「事故路径不存在」这四条仍是隔离证明的一部分。

其它验收命令（最终树）：

```
$ ~/.cache/openspec-1.8.0/node_modules/.bin/openspec validate --all --strict
Totals: 20 passed, 0 failed (20 items)          # rc=0
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 120 reference(s) (48 distinct) in 13657 effective line(s); retired 0; undeclared 0   # rc=0
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 12  bad 0  SKIP 1          # rc=0（136 段/136 行；551 个 token 全被覆盖）
$ git diff --check
                                                # rc=0（无输出）
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file .pi/team/forbidden-names.txt
ledger-ban: SKIP names —— 禁令名单未配置（.pi/team/forbidden-names.txt 不存在；这一项不是通过）
ledger-ban: root=<本工作树> scope=published files=2346 hits=0 names=missing user=resolved
$ echo $?
3
```

- Verdict: **pass**（选段绿、夹具绿、四条静态门禁绿；ledger-ban 的 `names` 形状是**可见跳过**，不是通过）
- Notes:
  - **V128 之后的重跑**：上面两种跑法（夹具单独跑、选段）的数字是最终树上的；V128 之前那一轮是
    ✓123/✓58，历史数字不再代表当前树。
  - `forbidden-names.txt` 在本检出里不存在（主检出也没有），所以「他项目名」这一形状没被检查，`rc=3`
    就是这个意思；`hits=0` 是另外三种形状的结果。
  - 没有跑全量门禁：按团队的每轮规则只跑与改动相关的选段，上文的 128 个键点名了没跑的段。
  - 没有 `team remind` 子命令、没有两个配置键、没有 `team paths`/`team doctor` 的 flock 诊断——它们分别属于
    2.1、2.2 与 1.3；本片只交付能被它们复用的权威层。
  - 真实项目尚未初始化权威（`init` 是显式动作），所以它今天没有 `reminder-locator.json`；这是刻意的：
    1.3 的迁移要先在静默窗口里建立并导入旧标记。

## Flip evidence (required for defect-fix tasks)

红侧分两层。第一层是夹具自带的三个变异副本（每次跑都执行，判据与原实现完全相同）：不持锁的直写、删掉快照
版本检查、删掉外来项目分支。

```
  ✓ 原实现（flock -x）：6×10 并发分配恰好拿到 1..60
  ✓ 原实现（flock -x）：持久 high-water = 61（没有丢更新）
  ✓ flip（不持锁的直写）：并发断言变红 —— 60 次分配得到 60 个不同序号、high-water=87（逐条无丢更新应为 121）
  ✓ flip（删掉版本检查）：同一份版本 2 快照被接受 —— 上一条具名断言会红
  ✓ flip（删掉外来项目检查）：别的项目的 .pi/team 被接受 —— 上一条具名断言会红
```

第二层是「直接把产品代码改坏 → 同一条判据变红 → `git checkout` 复原」，三次各一条：

```
### break 1: snapshot version check removed
  ✗ 原实现没有拒绝版本 2（rc=0，输出：{"version": 2, "created": false, …}）
== state-authority 结果 == ✓52 ✗2 SKIP0

### break 2: authority lock removed (direct transaction)
  ✗ 锁被占时没有显式超时（rc=0）
  ✗ 锁等待不是有界的 5s（实测 79ms）
  ✗ 6 个 Bash + 6 个 Node 写入者（TMPDIR 各不相同）拿到 1..12（期望 [1 2 … 12]，实际 [1 1 2 2 3 4 4 5 6 7 8 9]）
  ✗ 并发结束后持久 high-water = 13（没有丢更新）（期望 [13]，实际 [10]）
  ✗ 原实现（flock -x）：6×10 并发分配恰好拿到 1..60（序号不连续）
  ✗ 原实现（flock -x）：持久 high-water = 61（期望 [61]，实际 [20]）
== state-authority 结果 == ✓48 ✗6 SKIP0

### break 3: foreign-project refusal removed
  ✗ 别的项目的状态根没有被拒绝（rc=0）
  ✗ 拒绝外来状态根时 B/.pi 被建了出来
== state-authority 结果 == ✓51 ✗3 SKIP0

$ git status --short      # 三次复原之后：空
```

## Decisions and deviations

- **身份 = 运行时目录，两侧同一规则。** Node 侧（Pulse/Pi 的形状）不再相信调用方给的主根：它先用
  `git rev-parse --show-toplevel --git-common-dir` 解析 cwd 属于哪个项目，再与传进来的主根比对；不一致就在
  建任何东西之前拒绝。Bash 侧保留 `team_identity_resolve` 的既有判定，并在 `team_authority_main_root` 里
  拒绝与目录不一致的继承 `TEAM_MAIN_ROOT`。身份判定仍只有一份（Bash），Node 侧用的是同一条 git 规则。
- **定位器在热路径上不加锁读。** 定位器用 rename 原子替换，读到的永远是一份完整的；锁只在**首次建立**
  时取。这样每次事务不再多 fork 一个 `flock` 子进程（实测从 ~30ms 降到 ~1ms），也让「authority.lock 是
  唯一串行点」这件事真的成立——否则红侧的缺锁变异会被定位器锁顺手串行掉，看起来是绿的。两边都要用的
  场合仍是「先定位器、后权威」，顺序没变。
- **快照里带 Standby 槽位，但本片绝不碰旧标记。** `standby: {on:false, generation:0, reason:null, since:null}`
  是给 1.3 迁移进同一份快照用的；本片的 `init` 只写新快照，不读、不写、不删 `state/standby`。夹具里有一条
  专门的断言钉住这一点（旧标记前后哈希一致）。
- **并发判据需要一个起跑线。** 六个写入者先等一个 `go` 文件，再同时开始；否则 Node 冷启动的抖动足以把竞态
  窗口错开，缺锁的变异体会偶尔看起来是绿的（实测有 2/3 次）。起跑线在夹具侧，产品代码没有为测试留钩子。
- **没有做的事**：不改 `openspec/changes/agent-self-reminder/` 的任何文本；不注册 CLI 命令、不加配置键、
  不动 Pulse 节奏、不写活的 `standby`、不碰 Pi 投递；不合并/归档/发布；没有为了让夹具好写而在产品里加测试
  专用分支（红侧全部在 scratch 副本上操作）。
- **性能口径**：一次变更 = 一把 `flock` + 一个 helper 子进程，实测 CLI 读 64ms、进程内连续 10 次分配
  366ms（~37ms/次）。这是 design 里写明的形状（Bash 和 Node 用同一个锁与同一个事务助手），Pulse 每 10 秒
  的一次读也照此计费；如果 1.3/4.x 觉得贵，正确的改法是减少读的频率或换一个更轻的读路径，不是去掉锁。

## V128 修复（NEEDS-CHANGES 的三处，最终树）

三处都很小，产品只动了 `flock()` 的失败分类一处；其余是夹具。`docs/team/threads/dev.md` 2026-11-04 那条
要求的红侧都在下面，没有扩大范围。

### F1 · `--flip` 只有文档、没有解析

修改前：四条不同调用（含 `--nonsense-flag`）都跑满全部臂、都 rc=0 —— 一条臂被当成四条在用。
修改后：`--flip=unlocked|version|foreign|manifest` 四个值都实现；认不出来的值、认不出来的参数、互相冲突的
两条臂一律 rc=2 并具名说出原因；带一条臂时只有那条跑，结果前面单起一行 `flip 臂：…` 点名实际跑了什么，
被跳过的臂各打一条 `跳过红侧臂 …（本次 --flip=…）`（跳过不计入、也不当通过）。

```
$ bash skills/teamsmith/tests/state-authority.sh --flip=nonsense;      # rc=2
state-authority: 不认识的 --flip 值 [nonsense]；只接受 unlocked|version|foreign|manifest
$ bash skills/teamsmith/tests/state-authority.sh --nonsense-flag;      # rc=2
state-authority: 不认识的参数 [--nonsense-flag]（只接受 --flip=<unlocked|version|foreign|manifest>）
$ bash skills/teamsmith/tests/state-authority.sh --flip=unlocked --flip=version;   # rc=2
state-authority: 互相冲突的 --flip（unlocked / version）：一次只跑一条臂
$ for a in "" --flip=unlocked --flip=version --flip=foreign --flip=manifest; do
    bash skills/teamsmith/tests/state-authority.sh $a | grep -E 'flip 臂|结果 =='; done
flip 臂：unlocked,version,foreign,manifest   == state-authority 结果 == ✓67 ✗0 SKIP0
flip 臂：unlocked                            == state-authority 结果 == ✓60 ✗0 SKIP0
flip 臂：version                             == state-authority 结果 == ✓60 ✗0 SKIP0
flip 臂：foreign                             == state-authority 结果 == ✓59 ✗0 SKIP0
flip 臂：manifest                            == state-authority 结果 == ✓59 ✗0 SKIP0
```

### F2 · 助手被 SIGKILL 却被报成「等锁 5 秒超时」

先量清楚两种失败长什么样（宿主机实测）：助手被 `SIGKILL` 时 `flock` 立即以 **137** 退出（~1ms）；真的等满锁
是 **75**（`-E 75`）且耗时整整 5s；助手自己失败则原样转发它自己的状态码（如 3）。修改前 `flock()` 把「没有
stderr 的非零退出」一律当成超时，于是 137 被说成「等了 5 秒」——报告的那句话是假的。

修改后：`flock` 带 `-E 75`，超时措辞只在「冲突码 75 且真的用满了等待窗口」时出现；其余非零退出报
`transaction helper exited with status N (signal) … no state was written`。

新判据（去产物夹具里让助手以 137 退出——对调用方与 SIGKILL 同形）：

```
  ✓ 助手自己死掉：报 transaction helper exited with status 137（不冒充等锁超时）
  ✓ 助手死掉时没有多余的「超时」措辞（两种失败不再混为一谈）
  ✓ 助手死掉时立即返回（62ms，没有白等 5s）
  ✓ 助手死掉时状态一个字节没动
```

红侧（把 `flock()` 的失败分类改回旧形状，判据同一份；复原后产品 sha 与改前逐字节相同）：

```
  ✗ 助手死掉时的报错不对（rc=1，输出：state-authority: lock wait timed out after 5s at …/authority.lock; no state was written）
  ✗ 助手死掉时仍在说等锁超时（输出：state-authority: lock wait timed out after 5s at …）
== state-authority 结果 == ✓65 ✗2 SKIP0
```

真超时的既有断言仍然绿（`锁等待有界（实测 5090ms ≈ 5s 上限）`），所以这次没有把超时判据弄松。

### F3 · 隔离清单整段跳过 `state/`

修改前：清单只比 `state/` 之外的东西，另单独比 `state/reminders`、`state/standby`；往 `state/<杂散文件>`
写一个仍然全绿——正是 2026-10-31 事故的形状。

修改后：`manifest_snapshot` 把 `.pi/team` 下**每个**文件按 `路径<TAB>哈希` 记下来，`manifest_violations`
逐个比路径与内容，只有**命名的易变白名单**（`state_volatile()`：巡检 append 日志、`state/bg`、
`state/inbox-watch`、锁、spawn/exit 记录、每会话草稿与收件箱、`release-*`、`product-field-trial` 等）允许
新增或变化；其余任何出现、消失、内容变化都是违规。判据自己在 scratch 树上被证伪（不写真实项目）：

```
  ✓ 主项目 .pi/team：非白名单路径零变化（钉住 2 个文件；同期白名单内 4 个运行时文件在动，按名字放行）
  ✓ 白名单没有覆盖权威写面（加名字遮不住事故形状）
  ✓ 只动白名单形状的运行时文件：不算违规（判据不是「一切都不许变」）
  ✓ state/ 下的杂散文件必须被点名（事故形状）
  ✓ state/ 之外的新文件同样被点名
  ✓ flip（跳过 state/ 的旧形状）：state/ 下的杂散文件不再被报 —— 上一条具名断言会红
  ✓ flip（跳过 state/ 的旧形状）：state/ 之外的杂散文件仍然被报（没收窄判据）
```

`--flip=manifest` 就是 F3 的红侧：`MANIFEST_BREAK=skip-state` 把旧形状放回来（与 `tmp-root.sh` 的
`TMP_ROOT_BREAK` 同一手法），杂散文件那条判据必须随之不再报；产品不读这个变量。

**F3 的第二轮（第一版白名单两头都错，重跑当场抓住）**：第一版写成 `./state/*.log` 这种单层 case 形状，
两处都错——(a) 太窄：活团队的投递器在运行期间写了 `state/notify-dedup`，被新判据当成杂散文件判红（它确实是
运行时文件，代码在 `extension/team-notify.ts` 里写它）；(b) 太宽：bash 的 `case` `*` 连 `/` 一起匹配，
`./state/*.lock` 把 `state/reminders/authority.lock` 也放行了——正好是「白名单吃掉事故形状」的漏洞。
现在白名单是两层：`state/` 根下的**一层**文件名按名字族放行，子目录只放行已知的运行时目录（`bg`、
`inbox-watch`、`outbox`、`spool`、`draft`、`key-replies`、`release-*`、`product-field-trial`）；权威写面由
**独立判据** `authority_surface()` 先挡，另加一条断言证明白名单没覆盖它：

```
  ✓ 白名单没有覆盖权威写面（加名字遮不住事故形状）
```

现场有运行时写入时连跑三次都绿（同一棵树上，白名单内分别有 4、7、4 个文件在动）：

```
  ✓ 主项目 .pi/team：非白名单路径零变化（钉住 2 个文件；同期白名单内 7 个运行时文件在动，按名字放行）
$ echo $?   # 0
```

代价写在这里，不藏着：这是**有意的 fail-closed**——活团队新加一个运行时写入者（新的文件名族）时，这条会
以具体路径判红，需要把名字族加进 `state_volatile()`（一行）。这是 V128-F3 要的方向（宁可报，不可静默放行），
所以没有退回到「整段跳过 state/」。

### 修完自撞的两处（记录在案）

第一次重跑选段时，§66 红了两条，都是我这次改夹具自己弄出来的：夹具结果行被我加了 `· flip=…` 尾巴，
`smoke_inner_summary` 的严格匹配读不到；段 66 还在断言我改掉的旧措辞。修法是结果行保持契约形状、臂信息
另起一行，段 66 改断言新措辞（非白名单零变化 + `state/` 杂散文件被点名）。顺带说明：这两个红是门禁真的
在判我改的文件，不是噪声。

### 最终树上的选段（V128 之后）

```
$ bash skills/teamsmith/tests/smoke.sh --select 2,18b,40,66
#8 66 · … · 参考 用时 23s · ✓3 ✗0 SKIP0 · ticks 3
账本自查： 8 段收口 · 增量 ✓124 ✗0 SKIP0 ｜ 结果行 ✓124 ✗0 —— 一致
== 选段结果 ==  ✓ 124  ✗ 0
$ echo $?
0
```

## Suggested next steps

- 1.3 可以直接消费：Bash 侧 `team_authority_state_root|init|read|allocate`，Node 侧
  `request({cwd|mainRoot, stateRoot}, op)`；迁移旧 `state/standby` 标记应在权威锁内一次完成（读旧标记 → 写
  `standby` 槽位 → 退役标记），并保留它现在的前后证据。
- 迁移夹具可以直接复用本片的隔离形状（每仓 `git init` + 显式主根 + 独立 `HOME`/`TMPDIR` + 事故路径断言）；
  「不重新初始化」要有断言：已有快照时 `init` 必须 `created=false` 且项目 UUID 不变（本片已有这条）。
- 复验建议：在独立工作树里 `bash skills/teamsmith/tests/state-authority.sh`（16 秒，自带红侧与隔离证明），
  再跑 `--select 66`。
