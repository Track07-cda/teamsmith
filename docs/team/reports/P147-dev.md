# P147 · `delivery-truth` apply：真帧几何 + 队列阻碍如实 + notify 三处同名

agent: dev · status: DELIVERED（本地分支，不 push；PM 复验后本地合并） · time: 2026-10-01
branch: `task/P147-delivery-truth-apply-notify` · base: `603a4e8e`（= 当时的 main） · change: `delivery-truth`（phase: apply）
授权实现路径：`skills/teamsmith/scripts/lib/**`、`skills/teamsmith/extension/**`、`skills/teamsmith/tests/**`、`panel/src/**`、`openspec/changes/delivery-truth/**`、本报告目录。

## 结论

`tasks.md` 的 1.1–4.2、5.1–5.2 全部做完并在**真实 Pi 0.99.2 的容器场景**里转绿；5.3 的接入与全量门禁见
「门禁」，5.4 留给独立复验。核心三条：

1. **真帧几何**：真 Pi 的编辑器矩形从闭集形状（页脚 cwd + context 状态行、紧贴页脚的底线、光标上方唯一
   的等宽顶线、内部行在测量宽高界内、内部无第二条整宽规则行）里定位。P138/P147 真帧的对话区规则行
   （第 21 行）不再被当编辑器顶线：几何 `[21 30] BUSY`（假 BUSY，`say` 退出 0 并承诺「清空后自动投递」
   而永不兑现）→ `[28 30] EMPTY`，第二次追问真的一次投出去（`second_received=1`，`PASS second say delivered`）。
2. **队列阻碍如实且有界**：不可信几何 → 立即 `held/geometry-untrusted` + 非零退出 + durable 副本 +
   恢复命令，且**不许**给人扣「你有草稿」的帽子或承诺自动投递；连续三次**可信空框、无进展**的合格评估
   → `held/queue-stalled`（每条评估记进 `state/outbox/diagnostics/<entry>.json`）。真草稿/工作中/离线/锁竞争
   都不计入，观察者（list/status/digest/panel）不推进任何计数、不发键、不改队列。
3. **notify 三处同名**：durable 收件人文件（`docs/team/inbox/<recipient>.md`）、outbox 条目声明
   （`inbox: <recipient>` + `inbox-written: 1`）、wake 的 durable 字段现在指同一个存在的文件；PM 仍是 knock
   目标（行为不变）；durable 写失败 → 非零退出、不写声明、不敲门。

## 提交（分支留给 PM 本地合并）

| commit | 内容 |
|---|---|
| `79e5410d` | 真帧闭集准入（`_team_box_layout_decision`）+ 两份新真帧 + `delivery-truth.sh --section frames --mutations` |
| `78960658` | 队列阻碍（sidecar/三次计数/恢复）、`say`/`flush`/notify 的 held 传播、notify 三指针、panel impeded、drafts/queue/receipts/notify/panel 段 |
| `b4b160de` | 文档（troubleshooting §3 + config/protocol/SKILL.md）、smoke 段 + 预算/路径表、`draft send` held、巡检 tick 记录阻碍 |
| `0e6d2dbc` | 阻碍扫描收进单一实现（list/status/digest/panel 同一份事实） |
| `1934cd33` | 阻碍回执点名 durable 全文路径（held 命令/巡检行） |
| `431d4513` | 观察者不建 `outbox/`（refactor 引入的回归；smoke §26-j 抓到 → 修 → 该段绿） |
| `afbf165f` | 报告（翻转证据、门禁日志、环境缺口说明） |
| `cccfac1b` | 段键 54 → 57（main 已占 54：P140 派单摩擦） |

### 与当前 main 的合并预检（PM 决定怎么并）

我的分支基点 `603a4e8e`；main 现为 `bc0b0ce0`（`603a4e8e` 是 main 的祖先）。`git merge-tree --write-tree main HEAD`
报三处内容冲突：`skills/teamsmith/scripts/lib/cmd-agents.sh`、`skills/teamsmith/tests/smoke.sh`、
`skills/teamsmith/tests/section-budgets.tsv`。都是预期内的**语义**冲突，不是「谁写错了」：

- **smoke.sh**：main 已加 55/56 两段（P139）；我的段原本占 54（与 main 的 `54 · 派单摩擦（P140）`撞键），
  已改成 **57**。合并时要保住两边的段与 `section-budgets.tsv` / `section-paths.tsv` 的行。
- **cmd-agents.sh**：main 的 notify（P82/P155 之后）仍然写死 `--inbox-written pm`，即本 change 的
  deliverable（三处同名）在 main 上还没落地；合并时要把我这边的 `--inbox-written "$agent"` 应用到
  main 的新版 notify 上，不能退回旧函数体。
- 其余我碰过的文件（outbox.sh / cmd-outbox.sh / cmd-watch.sh / cmd-draft.sh / panel/src / tests/frames /
  tests/delivery-truth.sh / 文档）在 main 上没有并行改动（`git diff --stat main...HEAD` 里只有我这边的改动）。

## What flips（每条的原始输出都在下面点名）

| # | 红（修前，自己的现场） | 绿（修后，同一命令） |
|---|---|---|
| 1 | 真帧：几何 `[21 30]`、空编辑器判 `BUSY`、`say` 退出 0 +「清空后自动投递」；judge `second_received=0 … FAIL second say stranded despite idle empty editor` | 几何 `[28 30]`、`EMPTY`、第二次追问 `second_received=1 … PASS second say delivered` |
| 2 | 不可信几何（识别出 Pi 但矩形冲突）：没有这条判决（旧域要么打字、要么把对话区当草稿） | `held/geometry-untrusted` + 退出 1 + 零按键 + 恢复命令；`--mutations` 把准入影子成 `none` → 同一份真帧逐字退回 `[21 30] BUSY` |
| 3 | 可信空框 + 粘贴失败：旧实现每次排水都重试、无计数、无结论（TTL 到才 held） | 第 3 次合格评估 `held/queue-stalled` + 退出 1 + `consecutive_empty: 3`；影子掉观察转移 → 三次评估后仍在活动队列（守卫咬在那个决策点上） |
| 4 | notify dev：写 `dev.md`，条目/wake 声明 `pm`，`pm.md` 不存在（wake 指向空气） | 条目 `inbox: dev`、wake durable 字段 `dev`、`dev.md` 存在含全文（真容器里同样验证） |
| 5 | panel 没有 impeded/impediments 键；诊断不可读与零阻碍不可区分 | `"impeded": 2` + 两条 `impediments`（entry/target/reason/last_observed/durable_text_path/diagnostic）；sidecar 删掉后计数仍为 2、标记 `unavailable` |

## 1. 真帧几何（[容器 · 真 Pi 0.99.2，5.1/5.2）

配方 = P138 的 `run-case.sh` + `scenario.sh`（一次性容器、私有 tmux socket、loopback mock 模型、真实
Pi 0.99.2 宿主包只读挂载），只把证据目录换成 `docs/team/reports/P147-dev/`（`pkg/` 与 P143 逐字节相同，
只有 `run-case.sh` 的 `E=` 一行改成 P147）。**红侧是修前在自己的 worktree 上跑的**，不是引用 P138。

红（修前，`603a4e8e`，证据 `logs/tmux-delivery-truth-before-dirty/`）：

```
$ P138_SECOND=1 bash docs/team/reports/P147-dev/pkg/run-case.sh tmux-delivery-truth-before-dirty 603a4e8e 0 host
$ python3 docs/team/reports/P147-dev/pkg/judge-second.py tmux-delivery-truth-before-dirty
tmux-delivery-truth-before-dirty: second_received=0 backend=0 backend_requests=0 settled=2 settle_editors_empty=1
FAIL second say stranded despite idle empty editor
```

同一次运行里 `say` 的原始输出（`logs/tmux-delivery-truth-before-dirty/second-say.txt`）：

```
✓ queued for p138:dev: P138-SECOND-tmux-delivery-truth-before-dirty（目标输入框里有草稿：没有写任何键；条目已入 state/outbox/，清空后自动投递）
```

真帧本身（`second-before.frame`，120×32，光标 29）：第 21 行是对话区的整宽规则行，编辑器顶线 28、底线 30，
页脚 `31=/tmp/p138..../proj/.worktrees/dev (task/P138)`、`32=1.2%/128k (auto) … p138`。存进
`skills/teamsmith/tests/frames/pi-0.99.2-empty-editor.txt`（sha256 `61153ab2…`），草稿帧
`pi-0.99.2-human-draft.txt`（`a0198a0f…`，文本 `P143-HUMAN-DRAFT`）。

绿（修后，同一 HEAD 的 `git archive`，证据 `logs/tmux-delivery-truth-dirty/`）：

```
$ P138_SECOND=1 bash docs/team/reports/P147-dev/pkg/run-case.sh tmux-delivery-truth-dirty HEAD 0 host
run rc=0
$ python3 docs/team/reports/P147-dev/pkg/judge-second.py tmux-delivery-truth-dirty
tmux-delivery-truth-dirty: second_received=1 backend=1 backend_requests=1 settled=3 settle_editors_empty=1
PASS second say delivered
```

配套原始观察：`second-say.txt` = `✓ said to p138:dev: …（已确认送达）`；`box-after-say.txt` =
`verdict=EMPTY / box_text=[|]`；`second-outbox.txt` 与 `outbox-final.txt` 都是「队列为空」→ 没有残留的假
`draft-raced`、没有重复。草稿负例（`P143_DRAFT=1 … tmux-delivery-truth-draft-dirty`）：`draft-say.txt` =
`✓ queued for p138:dev: …（目标输入框里有草稿：没有写任何键…）`，`draft-before.frame` 与
`draft-after.frame` **逐字节相同**（零按键）；watcher 正控（`watch-delivery-truth-dirty`）同样
`second_received=1 … PASS second say delivered`。Pi 版本 `0.99.2`（`logs/*/pi-version.txt`）。

帧级判据（生产实现，不开 tmux）：

```
$ bash skills/teamsmith/tests/delivery-truth.sh --section frames --mutations
✓ 真帧：admission 选出闭集矩形 (closed 28 30) / ✓ 几何 =[28 30] / ✓ 判定 idle-read=EMPTY
✓ 真草稿帧：文本 =P143-HUMAN-DRAFT / ✓ 判定 BUSY
✓ 全部 18 份既有帧（含 2 份新真帧）判定保持、定位的框都含光标
✓ 红侧（admission 影子成 none）：同一份真帧退回 [21 30]
✓ 红侧：空编辑器被判成 NOT-EMPTY（假 BUSY 形状复现）
✓ 红侧（最近优先）：p78-draft-rule-below-cursor.txt → [1 3]；p86-f1-* → [5 7] EMPTY（两条既有安全回归都还咬得住）
```

## 2. 队列阻碍（section queue/receipts）

同一份真帧 + 假 tmux/假 TUI 夹具（真进程读同一串字节，生产 `team say`/`outbox flush`）：

```
$ bash skills/teamsmith/tests/delivery-truth.sh --section queue --mutations
✓ 三次评估：前两次退出 0，第三次非零（第 3 次才终态化）
✓ 第三次输出报 held / queue-stalled
✓ 条目进 held/（同名，FIFO 不变）
✓ 诊断 sidecar：consecutive_empty=3 + reason=queue-stalled；记下原始 entry id
✓ outbox list / team status 暴露阻碍计数与原因
✓ 观察计数 == 尝试打字次数（每次评估恰好计一次）
✓ 红侧：影子掉观察转移 → 三次评估后仍在活动队列（守卫确实钉住那一个决策点；影子前它会 held）
✓ 真草稿：三次排水一个键都没发 / 没有 queue-stalled / BUSY 读把连续空读清零
✓ 工作形状（spinner 顶线）：没有 queue-stalled
✓ offline 目标：不计 stalled、没有空读观察记录；锁竞争（claim 被占）：一次观察都不发生
✓ 观察者（list/status/digest）：payload/sidecar/按键数一个字节都没变
✓ 并发排水：恰好一次粘贴 + 一次提交；投递后无 held 残留
✓ 恢复 flush：两个 never-typed hold 各提交一次；终态 draft-raced 仍在 held/
✓ terminal draft-raced 在 flush --now 下也一个键都不收；forced.log 里没有它
```

`--section receipts`：不可信几何 `退出 1 + held/geometry-untrusted + 恢复命令 + 零按键 + durable 收件箱副本`、
真帧 + 页脚 cwd 不符同样走 untrusted（不退回旧域的「承诺」形状）、真草稿 `queued/exit 0/零按键/无「已确认
送达」`、干净空框仍 `已确认送达` 且队列为空、`flush` 的阻碍非零退出而 `outbox list` 仍 0。

守卫没有放松：`p78-*`/`p86-f1-*`/0.85.1/0.87.0 的判定全部保持（§1 的红侧同时证明两条影子仍能翻转），
`--now`、终端 hold、FIFO、TTL、去重、resume 语义都没动；`TEAM_DEFER_TTL` 仍是兜底而不是第一信号。

## 3. notify 三处同名（section notify + 真容器）

```
$ bash skills/teamsmith/tests/delivery-truth.sh --section notify
✓ durable：dev.md 恰好一行且署名 agent:dev2
✓ 没有伪造 pm.md 来掩盖指针不一致
✓ wake 的 durable 字段 =dev（不再写死 pm）
✓ wake 指向的文件真实存在且含全文
✓ PM 草稿：敲门入队、退出 0、PM 草稿零按键
✓ 排队条目的 inbox 声明 =dev（不是 pm）
✓ 队列恢复后：dev.md 仍一行、全文仍在（没有第二次 durable 写）
✓ 敲门文本带着发送者 dev2 进了 PM 框
✓ durable 写不进去：notify 非零退出 / 没有重建收件箱 / 错误消息点名失败路径
✓ inbox-only：收件人 dev.md 一行、署名 dev3、退出 0、不入队不敲门
```

真容器同一场景（`logs/tmux-delivery-truth-dirty/`）：`notify.txt` = `✓ outbox：已投递（pi 监视通道）… → pm.md（输入框零按键）`；
`state-final/inbox-watch/p138_pm-*.wake` 的第 4 字段 = `dev`；`inbox-final/dev.md` 两行（`agent:dev` 的
turn-end 简报 + `[manual] agent:pm` 的这条通知），**没有 `pm.md`**。PM 仍是 knock 目标（wake 落进 PM 会话）。

## 4. panel 只读（section panel）

```
✓ JSON：panel.outbox.impeded=2 / impediments 带两种原因 / 带两个 entry id / 带 last_observed
✓ 纯文本：同一份阻碍事实（原因可见）
✓ TUI：阻碍（原因或计数）在帧里可见
✓ panel/print/TUI 观察后：payload 与 sidecar 哈希不变、没有排水副作用
✓ sidecar 缺失：阻碍计数仍为 2（不许静默当零）/ renders unavailable
```

`node tests/panel-strings.mjs` = `ok`（zh/en 表非空、占位符一致、无 CJK 字面量泄漏），
`tests/panel-snapshots.sh` = `✓ 52 ✗ 0`，提交进仓库的 bundle 已重建。

## 5. 文档（4.2）

`references/troubleshooting.md` §3 新增四段（支持布局的边界与 `geometry-untrusted`、`queue-stalled` 的计数
规则、notify 的收件人 vs PM knock、panel 只读阻碍）；`config.md`（`TEAM_DEFER_TTL` + deferred-delivery 段）、
`protocol.md`（notify）、`SKILL.md`（Draft/deferred delivery 行）同步。**没有**擦掉旧的残余洞（whitespace-only
草稿、状态行克隆、P86 混宽度边界都还在原文里），也没有声称 <peer-c> 原始事故已修 —— 原文的 <peer-c> 归因段落未改动。

## 6. 保留场景（六块 MODIFIED，`check-deltas.py` 输出）

| Capability / modified requirement | Before | After | Preserved verbatim |
|---|---:|---:|---|
| delivery-guard / An automated send never types into a non-empty input box | 13 | 17 | YES |
| delivery-guard / Delivery is confirmed by the pane, and a queued message is reported as queued | 7 | 8 | YES |
| delivery-guard / The bottom border is the lowest qualifying rule row below the cursor | 11 | 11 | YES |
| notify-and-inbox / A manual notification is attributed to its sender, not its recipient | 7 | 11 | YES |
| panel / The deferred-delivery queue is read, counted and never touched | 5 | 6 | YES |
| panel / A human can write to the PM from any page | 6 | 7 | YES |

`PASS all baseline scenarios retained verbatim`

## 6b. 新场景 → 证据（复验逐条对照用）

| Delta 里的新场景 | 证据（断言原文在同一日志） |
|---|---|
| delivery-guard / An automated send… · A real settled editor excludes transcript separators | `frames`：`真帧：admission 选出闭集矩形 (closed 28 30)` + `idle-read=EMPTY`；`logs/tmux-delivery-truth-dirty/`（真 Pi 第二次追问 `second_received=1`） |
| … · A real draft in the same layout is still protected | `frames`：`真草稿帧：文本 =P143-HUMAN-DRAFT` / `判定 BUSY`；`logs/tmux-delivery-truth-draft-dirty/`（前后帧逐字节相同、零按键） |
| … · A rule-shaped draft cannot borrow the closed-layout exception | `drafts`：`DRAFT-RULE：held/geometry-untrusted、非零退出、零按键` + `DRAFT-RULE2` |
| … · An ambiguous Pi suffix is held, not guessed empty | `frames`：`页脚 cwd 与 target 不一致 → untrusted`；`receipts`：`真帧 + 页脚 cwd 不符：held/geometry-untrusted…不承诺自动投递` |
| delivery-guard / Delivery is confirmed… · The real second correction reaches the settled fallback once | 5.1/5.2 真容器（`logs/tmux-delivery-truth-dirty/{second-say.txt,outbox-final.txt,box-after-say.txt}`） |
| delivery-guard / Queue impediments…（4 条） | `queue` 段 1–7 + `receipts` 段（含影子红侧、并发、观察者零变更、终态绝不重贴） |
| notify-and-inbox … · A manual worker inbox and PM wake name the same full-text file | `notify`：`wake 的 durable 字段 =dev` + `wake 指向的文件真实存在且含全文` |
| … · The same pointer survives a queued PM knock | `notify`：PM 草稿下 `敲门入队` + `排队条目的 inbox 声明 =dev` + 清空后仍一行 |
| … · A failed durable write cannot authorize a wake | `notify`：`durable 写不进去：notify 非零退出` + `没有重建收件箱` |
| … · An inbox-only notification retains its named recipient | `notify`：`inbox-only：收件人 dev.md 一行、署名 dev3、退出 0` |
| panel / deferred-delivery… · An impediment is visible in every observer mode without mutation | `panel`：JSON `impeded=2` + 纯文本 + TUI 帧 + `payload 与 sidecar 哈希不变` + `观察者不创建 outbox/` |
| panel / A human can write… · Geometry and stalled outcomes retain their machine reason | `panel`：`impediments 带两种原因`（JSON/文本/TUI 三处）+ `sidecar 缺失：…renders unavailable` |

## 7. 门禁

| 门禁 | 结果 |
|---|---|
| `openspec validate --all --strict`（最终 HEAD） | `Totals: 17 passed, 0 failed (17 items)`（`logs/openspec-validate.txt`；容器全量门禁里同样的校验也通过） |
| `python3 docs/team/reports/P143-verify/pkg/check-deltas.py`（最终 HEAD） | `PASS all baseline scenarios retained verbatim`（`logs/check-deltas.txt`） |
| 相关段 · 本机（`delivery-truth.sh --section all --mutations`） | ✓ 96 ✗ 0（`logs/gate-delivery-truth.txt`） |
| 相关段 · 容器（git archive 独立仓库） | 六段全绿：25/10/25/12/15/9 ✓，0 ✗（`logs/container-delivery-truth.txt`） |
| smoke §12b-*（投递链）/§26-j（面板只读）/§46（P86 语料，含两份新帧）/§38-b/c（panel）/§57（新增，原 54 与 main 的 P140 段撞键） | 见下（§26-j 的一次红/绿翻转见「一次红」） |
| `TEAM_SMOKE_FAST=1 smoke`（host，最终 HEAD `cccfac1b`） | ✓ 3157 ✗0 ·「smoke 全绿」（`logs/host-fast-final.txt`；跳过 34 个真进程段，清单在日志尾） |
| 一次全量（独立仓库 · 全依赖容器，5.3 的命令，最终 HEAD `cccfac1b`） | ✓ 3806 ✗1（唯一红 = §40「陈旧 socket」环境缺口，见下；`logs/container-full.txt`） |
| 一次全量（同一命令，修 §26-j 之前的 HEAD） | ✓ 3805 ✗2（§26-j 面板建 outbox/ + §40；`logs/container-full-prefix.txt`） |
| brief 的六条容器命令（`-v $PWD:/src:ro`，逐段 `--mutations`） | 25/10/25/12/15/10 ✓，0 ✗（`logs/brief-container-sections.txt`） |
| 容器 · `--select 26`（§26-j 绿侧） | ✓ 203 ✗0（`logs/container-select-26.txt`） |
| §40 在本机（有 `ss`） | ✓（host FAST 里绿） |
| §40 在容器 · 本分支 | ✗ `陈旧 socket ?（没有 ss，无法判）` |
| §40 在容器 · **main**（`logs/container-main-s40.txt`） | ✗ 同一行、同一形状 → **环境缺口，不是本 change 的回归** |

### 一次红（交付门禁抓到的自己的回归）

全量容器门禁在 `1934cd33`（我自己的 refactor 之后）红了一条 **§26-j「面板把 outbox/ 建出来了」**：
把阻碍扫描收进单一实现时，它改用了 `team_outbox_dir()`（会 `mkdir -p`），于是三个**只读**出口
（`__panel-data` / `monitor --print` / TUI 帧）会在没有队列目录的项目里把它建出来。修复：读路径改用
不建目录的 `team_outbox_dir_ro` / `team_outbox_diag_dir_ro`（`431d4513`），并在 `--section panel` 里
加了一条同口径断言（删掉整个 `outbox/` 后跑三个出口，state 里仍不许出现它）。证据：
`logs/container-full-prefix.txt`（红）→ `logs/container-select-26.txt`（绿）。

### 环境缺口（不是回归）

§40 的「陈旧 socket」在容器里数不出来：镜像里没有 `ss`，输出明说「没有 ss，无法判」。把它当红是环境
问题：同一条命令在 **main** 上以同一形状失败（`logs/container-main-s40.txt`），在本机（有 `ss`）通过。
本 change 不碰 §40 的判据面；留给环境那边补 `ss`。

（原始日志都在 `logs/` 下：`host-fast.txt`（改名前的 FAST）、`host-fast-final.txt`、`container-full.txt`（最终）、
`container-full-prefix.txt`（修 §26-j 前）、`container-full-gate1.txt`、`container-main-s40.txt`、
`container-select-26.txt`、`brief-container-sections.txt`、`gate-delivery-truth.txt`。）

## 8. 我自己跑的 vs 引用 P138/P143 的

- **自己跑**：上面所有容器真 Pi 场景（红/绿/草稿负例/watcher 正控）、全部 `delivery-truth.sh` 段、FAST、
  容器全量、`openspec validate`、`check-deltas.py`、panel 夹具。红侧的 `pkg/` 与 P143 逐字节相同（`diff` 只有
  `run-case.sh` 的证据目录一行），但**命令是我在这个 worktree 的 HEAD/修前提交上跑的**。
- **引用**：P138 的原始事故描述与 <peer-c> 归因（未复现、未改动文档）；P143 的规划探针（我只用了它的帧与
  配方，判据用的是生产提取和新的门禁）。没有把 P138/P143 的绿色当成自己的绿色。

## 9. 残余与 finding

1. **`pi-0.99.2-*` 两份帧在 smoke §46 里走旧域**（那段探针不传 expect cwd，只做 P86 的口径/单调性；
   闭集几何的判定由 `delivery-truth.sh --section frames` 钉住）。这是有意的：两段各自守一个判据，不重复。
2. **闭集准入只覆盖测到的 0.99.2 页脚形态**：0.85.1/0.87.0（三行页脚、无 cwd 行）不被识别 → 维持旧域，
   判定逐字不变。将来 Pi 改页脚 → 识别失败 → 旧域（保守），写进 troubleshooting §3。
3. **P86 混宽度边界与 whitespace-only 草稿、状态行克隆仍然开着**（原文保留，未擦）。
4. 队列阻碍的恢复目前只有一条命令 `team outbox flush`（重试）+ `outbox drop`（人显式丢弃）；没有做
   「自动重试第 N 次」。

## 10. 任务勾选

`tasks.md`：1.1、1.2、2.1、2.2、2.3、2.4、3.1、4.1、4.2、5.1、5.2 已勾；5.3 在容器全量跑完后勾；
5.4 归独立复验（不属于本任务）。
