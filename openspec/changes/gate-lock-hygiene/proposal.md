# gate-lock-hygiene · 门禁锁的持有者自述与嵌套运行纪律

## Why

全量门禁是整机唯一的共享资源（M23：两套全量同时跑会在同一批 tmux/node/登录 shell 上互相拖死）。锁本身要留，
它今天的问题不是「存在」，而是**持有者不自述、嵌套运行没有预算、排队上限与运行时长脱钩**三件事：

1. **持有者记录只有三个字段**（`<lock>.holder` = `<ISO> pid=<pid> cmd=smoke.sh`）。它不说是哪个席位、哪个工作树、
   哪一类运行（外层 / 嵌套）、已经跑了多久、预计上限多少。等待者因此无法判断「再等一会儿」还是「这是异常」。
2. **任何带 `SMOKE_LOCK_WRAPPED=1` 的运行都会覆写并删除持有者记录**，即使它并没有拿到锁（本 worktree 实测，
   见 design §1 的 EXP1）。也就是说：嵌套运行会把真正的持有者从记录里挤掉，或者让等待者读到「持有者未知」。
3. **嵌套运行可以拿到机器锁**（丢掉标记时，见 EXP2），并且**没有任何预算**约束它：2026-10-15 实测锁被一个
   席位自己的运行持有 **1 小时 16 分**（`/tmp/teamsmith-smoke.lock`），期间别的席位的门禁全部排队——一次
   `--select 13c` 等了 19.5 分钟（PM 主动停掉），另一次完整验收等了 1 小时 20 分。而**排队上限默认 1800s**，
   于是排队超过 30 分钟就变成一次响亮的 FAIL，报的是「持有者：smoke.sh」——看不出那是嵌套运行、也看不出它还要多久。

代价在预算表里是可算的：129 段的 `budget_s` 合计 **41362s**、`band_s` 合计 **9330s**，单段最大的 `61b`
（路由翻转变异自检）是 band **5000s** / budget **20000s**。一次完整门禁合法地跑 80 分钟以上，而等待者的上限
是 30 分钟——两个数字从来不是按同一个口径定的。

同源的账（`docs/team/reports/P255-dev-bob.md` §2.2、§4.1，作者本人记录）：同一台机器上同一天，
**§36 超时**（预算 1400s，最后进度 297s，loadavg 20+）、**两次 `/tmp` 满（ENOSPC）造成的假红**
（§36⑦/§36⑧ 的嵌套运行、§40 的两条、P122/P70 的段账计数，共 ✗10），以及 **r6「本套没有运行」**——
默认 `TMPDIR` 重跑任务书原命令时，在机器门禁锁上等满 1800s，持锁者是一条挂了 1h20m 的运行。那三次都不是
产品缺陷（机器欠的账），但它们与本条**同源**：门禁是唯一的共享资源，而排队的人看不到「谁、什么、多久、
还有多久」。本变更修的是这条**可见性与纪律**，不是去改 §36 或 §40 的判定。

现状复核（2026-10-15，本 worktree 只读实测 + 私有锁夹具，机器锁一个字节没碰）：

| 事实 | 证据 |
|---|---|
| 持有者记录 = `<ISO> pid=<pid> cmd=smoke.sh`（无席位/工作树/类型/已跑/上限） | `smoke.sh:400`；design §1 EXP3 的等待者原文 |
| 带 `SMOKE_LOCK_WRAPPED=1` 的嵌套运行**覆写**持有者记录，并在退出时**删除**它 | design §1 EXP1：真持有者写 `cmd=REAL-HOLDER` → 嵌套运行后记录 `<MISSING>`，而真持有者仍在跑 |
| 丢掉标记的嵌套全量运行会**拿到机器锁** | design §1 EXP2（私有锁复现；`cmd=smoke.sh` 即它自己） |
| 等待者上限固定 1800s，与持有者的 `band`/`budget` 无关 | `smoke.sh:327`、`cmd-review.sh:1068` |
| 全量合计 band 9330s / budget 41362s；单段最大 61b = 5000s / 20000s | `awk` 读 `tests/section-budgets.tsv`（design §1 记了命令） |
| 锁的路径与上限键**不在** config schema 里（同族的 `TEAM_SMOKE_FAST` 是 `refuse` 类） | `grep TEAM_SMOKE scripts/lib/cmd-config.sh` |

## What Changes

### 1 · 持有者记录自述（新增要求 #The gate lock's holder record names its kind, its owner, its elapsed time and its bound）

`<lock>.holder` 与同目录的每运行一条 `<lock>.runs/<pid>.run` 记录，字段固定为：
`kind=top|nested`、`agent=<席位>`、`worktree=<路径>`、`started=<epoch>`、`expected=<Σband_s>`、
`bound=<Σbudget_s>`、`sections=<段数>`、`no_lock=<0|1>`，嵌套运行另带 `ancestor=<pid>`。
席位与工作树取自**运行时目录**（`team notify` 发送者同一条规则），**不取窗口名**（`tmux-identity-scope` 的教训）。
记录只由**真的持有 flock 的那个进程**写，退出时只删自己那一条——嵌套运行不得覆写、也不得删除持有者记录。

等待者（`smoke.sh` 的排队行、`cmd-review.sh` 的排队行与记录）在**开始排队时**与**撞上限时**都要打印这份记录，
并按 `started` 算出「已跑 Ns」。

### 2 · 嵌套运行不排队，但必须有祖辈证明、必须登记、必须待在生它的那一段里（新增要求 #A nested run does not queue on the machine lock, and its work stays inside the section that spawned it）

- **判定（见 design D1）**：嵌套运行**不抢**机器锁。机器锁的契约是「串行化**顶层**运行」；嵌套运行按定义就在
  一个顶层运行内部，再去排同一把锁等于把整队唯一的共享资源交给一个夹具——这正是实测里堵住整队 1h16m 的形状；
  而且它会与自己的祖辈自锁（祖辈不释放，它永远拿不到）。
- 「两个席位的嵌套运行同时跑重活」这一侧的交代：嵌套运行**只有在能证明祖辈持有锁时才放行**——证明方式是
  **进程树**（沿 ppid 走到记录里的持有者 pid，且 pid + starttime 仍是那个进程），不依赖 `SMOKE_LOCK_WRAPPED`
  这个会被夹具 `env -u` 掉的标记。锁一次只放一个顶层运行，所以跨席位的嵌套重叠只可能来自**显式退出串行**
  （`TEAM_SMOKE_NO_LOCK=1`、没有 `flock`、或 FAST 档——FAST 按契约不跑真进程段）。这个残余窗口写进记录
  （`no_lock=1`）与文档，让它**可观测**，而不是被一句「不会发生」打发。
- 嵌套运行的**预算显式**：它登记自己的 `expected`/`bound`，并把自己的段落看门狗期限对齐到**生它的那一段的剩余
  预算**（持有者记录里带 `heartbeat=<路径>`，嵌套运行读它得到祖辈当前武装段的 `armed_epoch + budget`）。期限
  到点由它**自己的**看门狗按既有形状点名（`#<no> <id> … 超时：预算 Ns，实际 Ns`）+ 停跑 + 留现场，登记随之
  消失——**不许无声占着**。夹具若把嵌套运行丢到后台，门禁要在该段收口后发现它仍活着并**点名**（可见，不静默）。

### 3 · 排队上限按可预期的剩余时间判（修改要求 #The hard timeout covers the gate run, not the queue）

持有者记录给出 `expected` 之后，等待者的上限不再是「一律 1800s」：
`cap = clamp(remaining + margin, TEAM_SMOKE_LOCK_WAIT, 4 × TEAM_SMOKE_LOCK_WAIT)`，其中
`remaining = expected − (now − started)`；等待者必须打印这个算式与三个数。记录里没有 `expected`（旧写入者、
或读不到）时退回今天的 `TEAM_SMOKE_LOCK_WAIT`。**FAIL 的文案必须一行说清**：持有者是哪一类（外层 / 嵌套）、
属于哪个席位与工作树、已跑多久、上限多少、还剩多久——让 PM 一眼看出「这是嵌套运行堵住了，不是谁坏了」。
判定 token 仍是闭集（`PASS|FAIL|TIMEOUT|SKIPPED|UNKNOWN`），排队超限仍走 `FAIL`，不新增 token、不改
`team_review_verdict` 的解析。

不新增配置键（`TEAM_SMOKE_LOCK_WAIT` 是既有的门禁旋钮，同族的 `TEAM_SMOKE_LOCK`/`NO_LOCK` 也只在环境里读，
不在 config schema；见 design 裁定点 D5）。

## Capabilities

### Modified Capabilities

- `verification`：
  - **ADDED** `The gate lock's holder record names its kind, its owner, its elapsed time and its bound`
  - **ADDED** `A nested run does not queue on the machine lock, and its work stays inside the section that spawned it`
  - **MODIFIED** `The hard timeout covers the gate run, not the queue`：既有正文与五条 scenario 逐字保留，
    新增一条 scenario（上限按持有者公布的剩余时间判）与一句「FAIL 文案必须点名类别与席位」；闭集 token 与
    「排队不消耗运行预算」的语义一个字不改。

不新增 capability：锁的机制面本来就在 `verification`（`gate-hygiene` 起），本变更只加它的**自述面**与
**嵌套纪律**；`team review` 的判定词表、锁路径与既有旋钮语义都不改。

## Impact

- 产品面：`skills/teamsmith/scripts/lib/gate-lock.sh`（**新**：记录格式的唯一读写实现，`smoke.sh` 与
  `cmd-review.sh` 共用）、`skills/teamsmith/scripts/lib/cmd-review.sh`（排队行、记录、上限算式）、
  `skills/teamsmith/tests/smoke.sh`（锁块、持有者记录、嵌套放行与登记、上限算式）、
  `skills/teamsmith/tests/lib/section-guard.sh`（公布 `heartbeat` 路径、嵌套期限对齐、登记/注销）。
- 文档面：`skills/teamsmith/references/protocol.md` §9b（把「嵌套运行不排队、必须有祖辈证明、必须在生它的那一段里
  结束」写进纪律；把 `no_lock` 残余窗口写明）。
- 夹具面：`skills/teamsmith/tests/smoke.sh` §34 / §34b 扩面（三条红侧 + 既有断言零回退）、
  `skills/teamsmith/tests/section-budgets.tsv` 的 §34/§34b 行按实测补 band（§0e 守表）。
- 规格面：`openspec/specs/verification/spec.md` 的 2 条 ADDED + 1 条 MODIFIED，delta 在
  `openspec/changes/gate-lock-hygiene/specs/verification/spec.md`。
- 选段面：`tests/section-paths.tsv` 的 §34/§34b 行登记新涉及的路径（`scripts/lib/gate-lock.sh` 等），
  跑一次 `section-select.sh --check`。
- 兼容性：**没有**运行时行为变化，除了「锁被占时等待者的等待时长与打印」；顶层单层运行的排队与
  「排到了再跑」语义逐字节不变（§34 ①–⑥ / §34b ①–⑤ 一条都不许改判定）。
- 分工：apply 需要明授 `skills/teamsmith/scripts/lib/**`（默认 PM）与 `skills/teamsmith/tests/**`；
  不碰 `references/migration.md`（P255）、`references/config.md`（P261）、`scripts/lib/cmd-project.sh` 的帮助段（P260）。
- 排期：一个 apply 席位做完（记录 + 嵌套纪律 + 三条红侧）；verify 由**另一席位**在独立克隆上重跑全部场景与红侧。

## 需要 PM 裁定的点（提案按推荐版本落笔）

1. **D1 · 嵌套运行不抢机器锁**。推荐：**是**（理由与两侧代价见 design D1；「不许直接放行」由「祖辈证明 +
   登记 + 段内期限」三条兑现）。若 PM 裁「仍抢」，则 requirement #2 改成「嵌套运行可以排队，但它的记录必须
   自述、且它的持有不得超过生它的那一段的剩余预算」，红侧 ① 与 ② 的形状不变。
2. **D2 · 记录形状**：`<lock>.holder` 单文件 + `<lock>.runs/<pid>.run` 每运行一条。推荐：**是**——单文件会被
   多个运行同时写（EXP1 就是这个病），每运行一条文件天然无竞争，等待者 glob 后按 pid+starttime 过滤。
3. **D3 · 上限算式**：`clamp(remaining + margin, TEAM_SMOKE_LOCK_WAIT, 4 × TEAM_SMOKE_LOCK_WAIT)`，
   `margin` 固定 60s。推荐：**是**（不新增配置键；抬高 `TEAM_SMOKE_LOCK_WAIT` 同时抬高天花板）。
   备选：保持固定 1800s，只把 FAIL 文案做诚实（brief 的「或者」那一支）——代价是 80 分钟的合法运行仍会被
   30 分钟的上限误判成 FAIL。
4. **D4 · 嵌套期限的来源**：持有者记录带 `heartbeat=<section-guard 心跳路径>`，嵌套运行读祖辈当前武装段的
   `armed_epoch + budget` 作为自己的期限。推荐：**是**。备选：嵌套运行只用预算表里自己的合计（代价：它仍可
   超出「生它的那一段」的预算）。
5. **D5 · 不新增配置键**。推荐：**是**——`TEAM_SMOKE_LOCK`/`TEAM_SMOKE_LOCK_WAIT`/`TEAM_SMOKE_NO_LOCK`
   今天都不在 config schema（只有 `TEAM_SMOKE_FAST` 是 `refuse` 类），本变更不打破这个半登记状态，只把它
   记为 finding（P141 的 R1 曾要求把文档化过的阈值键注册进 schema；这里没有新增键，所以不触发那条）。
   若 PM 要顺手把这一族注册进 schema（带 zh/en 标签），它是独立的一小步，见 tasks 4.3。
6. **D6 · apply 一次做完还是拆两轮**。推荐：**一次**——记录写入者与嵌套放行在同一处（`smoke.sh` 的锁块 +
   `gate-lock.sh`），拆开会让同一个记录文件有两个写者（delta 单写者规则的同一种病）。

## Acceptance（apply / verify 阶段执行；本阶段只写提案，不跑）

```bash
bash skills/teamsmith/tests/smoke.sh --select 34,34b          # 既有断言零回退 + 三条新红侧
bash skills/teamsmith/tests/smoke.sh --select 0e              # 预算表自述（新 band 必须登记）
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
rm -rf /tmp/glh-trial && mkdir -p /tmp/glh-trial && cp -a openspec /tmp/glh-trial/openspec \
  && (cd /tmp/glh-trial && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y gate-lock-hygiene \
      && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict)
```

夹具与命令的最终形态以 apply 冻结的接口为准；**三条红侧的方向、`kind=top|nested` 字段名与「顶层单层行为不变」
不得改**（改了就是换合同，要重新走提案）。

## Out of scope

- 不把锁去掉，也不给等待者优先级 / 插队权（锁的价值是别让机器被压垮，D50 的机器纪律不变）。
- 不改 `TEAM_SMOKE_LOCK_WAIT` / `TEAM_SMOKE_NO_LOCK` 的语义与默认值，不改 `TEAM_SMOKE_FAST` 的分层。
- 不修 §36 / §40 / §61b 本身的判定或预算（P255 记的那三次是机器欠的账，不是本变更的活）。
- 不改 `team review` 的判定词表、退出码与记录 token 闭集，不改 `team_review_verdict` 的解析。
- 不引入「按席位优先级」或「抢占别人的锁」（`kill` 别人的进程永远是 PM 的现场决定，不是门禁的自动行为）。
