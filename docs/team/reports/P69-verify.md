# P69 · change-centric-discipline 独立验证（verify 阶段）

agent: verify   status: DONE（分支留在本地，等 PM 复验/合并）   time: 2026-09-22T18:50Z
change: `change-centric-discipline`（propose=P23 dev-bob · apply=P24 dev-bob + P45 dev2）   phase: verify
branch: `task/P69-change-centric`   PR/MR: -（本仓库 local 模式：不 push，PM 复验后本地合并）
tip: `2b3efed4`（验证包）+ 本报告提交（同分支）

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P69-verify.md` | 本报告 |
| `docs/team/reports/P69-verify/pkg/lib.sh` | 独立验证包：夹具、断言、私有 tmux 隔离 |
| `docs/team/reports/P69-verify/pkg/10-dispatch-guards.sh` | 规则 1 + 规则 B 的红/绿两侧 + `--force` 真实审计 |
| `docs/team/reports/P69-verify/pkg/20-delta-writer.sh` | 规则 2（delta 单写者）红/绿/跨 change/续跑/坏行 + `--force` 审计 |
| `docs/team/reports/P69-verify/pkg/30-verifier-independence.sh` | 规则 3（verifier ≠ apply 作者）红/绿/dropped/缺信号 + `--force` 审计 |
| `docs/team/reports/P69-verify/pkg/40-change-view.sh` | `team change status` 退出码/JSON/只读、digest `[6]` 对账与界、`[1]`–`[5]` 差分、面板（块/token/窄宽度丢弃） |
| `docs/team/reports/P69-verify/pkg/50-archive.sh` | 归档前提：阻塞/同一谓词/FORCED/`change: -` 回归 |
| `docs/team/reports/P69-verify/pkg/60-mutations.sh` | 三条变异（红→绿）+ 还原干净 |
| `docs/team/reports/P69-verify/pkg/run.sh` | 一次跑完六段；`bash run.sh` 退出 0 = 全绿 |
| `docs/team/reports/P69-verify/pkg/raw-demo.sh` | 报告里引用的原始输出（八个现场） |
| `docs/team/reports/P69-verify/pkg/logs/*.log` | 各段原始日志、openspec/FAST/全量门禁日志、raw-demo |

## 方法与独立性

- **自己的夹具**：每个场景组一个 scratch 项目（`team init` + 自己的 brief/BOARD/openspec 目录），
  不复用 P24/P45 的 smoke 夹具；断言只看**可外部观察的**输出、退出码、shim 调用日志、看板行与文件字节。
- **红侧不开窗**：拒绝类用例一律用「只记账的 tmux shim」，断言 `new-window/new-session/respawn-pane`
  请求为 0、且看板行逐字不变。
- **真实路径私有化**：`--force` 落审计那一类必须真派单成功，走 PATH shim 把 socket 名烘死成
  `exec /usr/bin/tmux -L p69verify-<pid>-<rand> "$@"`，并清空 `TMUX`/`TMUX_PANE`；实现树一个字节不动。
- **基线与差分**：`[1]`–`[5]` 段头对 pre-B2 树（`8073acd3^`）逐字节差分；`change: -` 归档路线对
  pre-P24 树（`0d5a95a6^`）逐字节差分；`[6]` 号冲突用真实死 pane 复现。

## 逐条验收

整包一次跑完（`bash docs/team/reports/P69-verify/pkg/run.sh`，原始输出 `pkg/logs/run-all.log`；
每段的全量 stdout 在 `pkg/logs/<段名>.log`）：

```
10-dispatch-guards             rc=0  == 1 结果 ==  ✓ 49  ✗ 0  finding 0  skip 0
20-delta-writer                rc=0  == 2 结果 ==  ✓ 34  ✗ 0  finding 0  skip 0
30-verifier-independence       rc=0  == 3 结果 ==  ✓ 19  ✗ 0  finding 0  skip 0
40-change-view                 rc=0  == 4 结果 ==  ✓ 58  ✗ 0  finding 1  skip 0
50-archive                     rc=0  == 5 结果 ==  ✓ 19  ✗ 0  finding 0  skip 0
60-mutations                   rc=0  == 6 结果 ==  ✓ 9  ✗ 0  finding 0  skip 0
RUNALL_RC=0
```

### 1 · dispatch 的四条纪律（每条红/绿两侧）—— 102 条断言（段 10+20+30）全绿

原始输出见 `pkg/logs/raw-demo.log` ①–④ 与 `pkg/logs/10-dispatch-guards.log`、`20-delta-writer.log`、`30-verifier-independence.log`。

**规则 1（一个任务一个 change id）**

| 用例 | 期望 | 实测 |
|---|---|---|
| `change: alpha, beta` | 拒 + 点名该行 + 两种接受形式 | ✓ rc=1，开窗请求 0，看板不变 |
| `change: alpha beta`（空格） | 拒 | ✓ |
| 两行 `change: alpha` + `change: beta` | 拒 + 点名两行（不是静默用第一行） | ✓「change: 有 2 行（alpha、beta）」 |
| `change: alpha -` / `change: alpha,` | 拒 | ✓ |
| `--print` 同 brief | 拒且不打印提示词 | ✓ |
| `--force` 同 brief | 仍拒（规则 1 没有逃生门） | ✓ |
| `change: alpha` / `al.pha-b_1`（合法 token） | `--print` 放行 | ✓ rc=0 + 提示词 + 任务书路径 |

**规则 B（change-less 必须声明锚）**

| 用例 | 期望 | 实测 |
|---|---|---|
| `specs: -` + 无 `anchor:` | 拒 + 两种形式 | ✓ |
| `anchor: none (infra)` | 拒（缺分隔符） | ✓ |
| `anchor: none (infra) —`（理由空） | 拒（理由必填） | ✓ |
| `specs: no-such-capability#x` | 拒 + 点名 `openspec/specs/...` | ✓ |
| `specs: panel#A requirement that does not exist` | 拒 + 点名 `### Requirement:` | ✓ |
| 没有 `change:` 行（≡ `-`）且无锚 | 拒 | ✓ |
| `specs: panel#<存在的 requirement>` / `specs: panel` / `anchor: none (infra) — 理由` | `--print` 放行 | ✓ ×3，且 infra 那份无锚警告 |
| `--force` + 真实派单 | 警告 + **恰一行** `state/watchdog.log` 审计 | ✓ rc=0，`覆盖锚缺失（N1 无 change …）` 1 行 |

**规则 2（delta 单写者）**

红：兄弟 `M1`（wip，`deltas: panel`）→ 新 `M2`（`deltas: panel`）被拒，输出点名
`M1`、阶段、看板 `wip`、共享文件 `openspec/changes/alpha/specs/panel/spec.md`、双方声明；开窗 0、看板不变；
`--print` 同样拒。另：
- 兄弟**无 `deltas:` 行** vs 新任务（有/无声明）都拒，文案说明「读作整个 change 的 delta 集」；
- 新任务 `deltas: panel,` / `deltas: panel extra` → 拒（坏行不静默当空集）；
- 兄弟的 `deltas:` 行坏掉 → **吵但放行**（`它的目标集判不出来，不冒充干净`，rc=0，且不是单写者拒绝）。

绿（各自独立夹具，避免别的未结束兄弟干扰）：`deltas: -` 放行且打印「无重叠」；不相交 capability
（dispatch vs panel）放行；跨 change（beta 同声明）不比；兄弟 `done` 放行；派任务自己（resume）不与自己冲突。

`--force` 真实派单：rc=0，警告点名 `M1（看板 wip）与 M2 都会写 …panel/spec.md`，
`state/watchdog.log` **恰一行** `覆盖 delta 单写者`，`team monitor` 事件列可见该行。

**规则 3（verifier ≠ apply 作者）**

红：change `alpha` 的 apply `M1` 由 `dev` 写，verify `V1` 也是 `dev` → 拒，输出点名
`change：alpha ｜ agent：dev ｜ 它写过的任务：M1`、换人出路、开窗 0、看板不变；`--print` 同样拒。
绿：换 `verify` 席位放行；`M1` dropped → 放行且点名「已排除（看板 dropped）：M1」；
`dev` 的 apply 任务属于 change `beta` → 对 `alpha` 的 verify 放行（作者集合按 change 取）；
apply 任务头里没有 `agent:` → 大声放行（`作者信号缺失：M4 … 不当作干净`）。
`--force` 真实派单：rc=0，恰一行 `覆盖自验（change alpha 的 apply 作者 M1 来 verify V1）`。

### 2 · `team change status` 与 digest 的 token 对账（段 40 的 58 条断言全绿，含 F1）

原始输出：`pkg/logs/raw-demo.log` ⑤⑥⑧ 与 `pkg/logs/40-change-view.log`。

- 全结束 fixture（两个任务 board `done` + 各自的 `reviews/<ID>.md: PASS`）→ `change alpha · ready`，
  **exit 0**；blockers 显示「（无：全部任务已结束）」。
- 加一个 `wip` 兄弟 → `change alpha · not ready`，**exit 1**，blocker 点名 `M2 · apply · wip ·` 与缺的
  证据（复验记录）；`--json` 解析成功、`ready:false`、`tasks` 三行、blocker 就是 `M2`。
- **只读**：命令前后 fixture 的 `git status --porcelain` 与 `BOARD.md` 字节都不变。
- 未知 id → 非 0，且同时说清「没有任务指向它」与「没有 `openspec/changes/<id>/` 目录」。
- `self-verify: dev（作者任务 M1）` 出现在 verify 任务的同一行；没写过 apply 的 agent 无标记。
- **同一 fixture 对账**：digest `[6]` 的 `change alpha · not ready → M1 done · M2 wip · V1 todo`
  与 `team change status alpha --json` 的 `id board` 串**逐字一致**（断言直接比较两串）。
- `[6]` 的另外两个标记也实测：目录在没任务 → `（没有任务指向它）`；任务指向不存在的目录 →
  `not ready（change 目录不存在）→ N9 todo`；只有目录没有任务时 `change status` 非 0 并点名。
- `declared by` 与 `touched by` 分列：M1 显式 `deltas: panel` + M2 缺失行 → `declared by M1、M2`；
  真的在 `task/M1-fixture` 分支上改了 delta 文件 → `touched by M1`。

### 3 · B2 的界与机器出口（同段 40；上面 §2 与本节共用那次运行的全部断言）

- **token ≤8 + `+N`**：10 个任务 → `[6]` 行恰 8 个 token + `+2`，第 9 个不打印；
  面板 `__panel-data --block changes` 的 `tasks` 数组 = 8、`tasks_more` = 2，token 带
  `id/phase/board/verdict`。
- **change 列表有界**：10 个 change（各一个任务）→ 8 行 + `… +2（另有 2 个未归档 change）`。
- **`[1]`–`[5]` 逐字节不变**：当前 digest 与 pre-B2 树（`git archive 8073acd3^ skills`）在**同一 fixture**
  上的前五段头（含历史重复的 `[5] 任务板`/`[5] 建议`）逐字节一致；当前多出的正是 `[6] change 归组`。
- **机器出口**：`monitor --print` / `--json` 在 change 数据面变化（新增一个映射任务）前后
  逐字节一致（滤时间戳）——console-only；`--print` 不含 token、`--json` 不含 `"tasks":`。
- **窄宽度丢弃而不重排**：160 列帧里放得下的 `M1 done · M2 wip` 照常渲染，放不下的 8 个长 token 行
  **整行消失**，且「有 token」帧与「本来没有 token」帧**逐字节一致**（无重排）；270 列时 token 行渲染出来。
- **finding F1**：digest 的段号不唯一。B2 的 `[6] change 归组` 与 P55 的条件段
  `[6] 死 pane 席位` 在同一轮 digest 里**同时出现两个 `[6]`**（真实私有 tmux 造死 pane 复现）：

```
$ team digest | grep -E '^\[6\]'
[6] change 归组
[6] 死 pane 席位（窗口是遗体：现场可读；死 pane 不是投递目标，消息已换道收件箱）
```

  时序：P24（09-20）→ P55（09-22 15:36，引入死 pane `[6]`）→ P45/B2（09-22 16:53，选择 `[6]`）。
  既有的 `[5]`×2 说明编号本来就不唯一，但两个 `[6]` 确实让「用段号定位」失效；建议 PM 决定
  （重排 change 段号或让死 pane 段另起编号），不阻塞本 change 的其它判定。

### 4 · archive 前置 —— 19/19 ✓

- 归档任务 `A1`（`phase: archive`，归档目录已存在）+ 未结束兄弟 `M1`（wip）：
  `team board set A1 done` 非 0，文案 `change alpha 还没就绪（归档前提：……）` 点名 `M1 · apply · wip ·`，
  看板行不动。
- **一个谓词两个消费者**：`team change status alpha` 的 blocker 行与闸门拒绝里的那一行**逐字一致**
  （断言直接取视图里的行去闸门输出里找）。
- 兄弟 `M1` 拿到 PASS + `done` 后：`team board set A1 done` 成功，证据行点名归档目录，
  `reviews/A1-done.md` 落盘。
- `TEAM_BOARD_DONE_FORCE=1` + 理由 → 成功、记录含 `FORCED` 与理由。
- `change: -` 的归档任务：退出码与文案对 **pre-P24 树逐字节一致**（旧路线保留）。

### 5 · 零回归（门禁）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 26 passed, 0 failed (26 items)                       # ✓（OPENSPEC_RC=0，pkg/logs/gate-openspec.log）

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2393  ✗ 2                                      # 2 条红均为环境/既有，见下
FAST 模式：跳过 31 个真进程段落 …
smoke 有失败项（--keep 保留现场）                              # FAST_RC=1
```

两条红的归属（都**不是**本 change 的回归）：

1. `12b-j 隔离：调用方项目的 inbox/state 里没有夹具痕迹（实际 …/pm-skills/.pi/team/state/tmux-calls.log）`
   —— 命中的是 **17:10:34 dev3 的 P67 夹具**经 M36 闸门写进共享账本的那两行
   （`argv=new-window … FAKE_TUI_DRAFT='半句草稿 half a sentence'`，`cwd=.worktrees/dev3`），
   扫描模式里正好有 `半句草稿 half a sentence`。并发 worker 的活动把共享 `.pi/team/state/tmux-calls.log`
   写成了「调用方项目的夹具痕迹」。P24/P45 都没碰闸门与日志路径。
2. `40 lint 有 finding（rc=1）` —— 8 条，全部落在两个**本 change 没碰过**的文件：
   `container-tmux.sh:159/215`（P64 在修的那个 fpcheck 临时根，任务书已点名的既有红）与
   `fixtures/p55/flip-p49.sh:29/37/173/195/203/211`（P55 的夹具）。
   `git show --stat 0d5a95a6`（P24）与 `git show --stat 8073acd3`（P45）都**不含**这两个文件。

全量 smoke：见下节（排队/并发情况一并记录）。

**门禁资源现状（环境，非本 change）**：全量 smoke 的机器锁当时被一个**自死锁**的外层 flock 占着
（`flock --close -w 3600 /tmp/teamsmith-smoke.lock bash -c bash smoke.sh`，smoke 内部又
`exec flock -w 1800` 抢同一把锁 → 持锁 29 分钟）。我第一轮排队在 1800s 上限**静默超时**
（日志只有排队行，`FULL_RC=1`）—— 这正是 P66 任务书描述的「排队超时路径不打印大声失败」；
第二轮改用 `TEAM_SMOKE_LOCK_WAIT=5400` 继续排队，结果见下。

### 全量 smoke

```
$ TEAM_SMOKE_LOCK_WAIT=5400 bash skills/teamsmith/tests/smoke.sh </dev/null
  · 全量门禁互斥：持有 /tmp/teamsmith-smoke.lock（同机第二套会排队；TEAM_SMOKE_NO_LOCK=1 可跳过）
  ✓ 12b-j 隔离：调用方项目的 inbox/state 里没有夹具痕迹
  · 12b-j 提示：真项目 state 在夹具期间有自己的活动（真团队在跑）——指纹变了，但夹具痕迹扫描为零
  ✗ 40 lint 有 finding（rc=1）：container-tmux.sh:159 … / container-tmux.sh:215 … / fixtures/p55/flip-p49.sh:29 …
…
== 结果 ==  ✓ 3018  ✗ 1
smoke 有失败项（--keep 保留现场）                          # FULL2_RC=1
```

- **唯一红就是上面那 8 条既有 lint**（同一组文件、同一组行），与本 change 无交集；
  `12b-j` 在全量这轮**是绿的**（并显式打印「真项目 state 有自己的活动，但夹具痕迹扫描为零」）——
  FAST 那轮的红是**瞬时**的：`.pi/team/state/tmux-calls.log` 后来被活着的 M36 闸门轮转/清掉
  （`grep -c 半句草稿` 现在是 0），属于并发 worker 活动的环境噪声。
- 排队过程：第一轮 1800s 静默超时（见上文）；第二轮 `TEAM_SMOKE_LOCK_WAIT=5400` 排队约 41 分钟后拿到锁
  跑完（整套 3125s 含排队；日志 `pkg/logs/gate-smoke-full2.log`，212KB）。
- 结论：**零回归**——本 change 没有新增任何门禁红。

## Flip evidence（三条变异，红 → 绿；脚本 `pkg/60-mutations.sh`，原始日志 `pkg/logs/60-mutations.log`）

变异只打在 `/tmp` 的 **skills 副本**上，实现树一个字节不动（见下第 4 条）。

| # | 变异 | 红侧（断言必须失败） | 绿侧（还原后） |
|---|---|---|---|
| 1 | 关掉规则 2 的单写者块（`if [ "$change" != "-" ]` → `if false`） | `变异体: rc=1 · 没有单写者拒绝 · shim 开窗请求 1`（越过守卫走到建窗口） | `原树: rc=1 · 输出点名单写者规则 · shim 开窗请求 0` |
| 2 | `team change status` 未全 done 也 ready（`ready=1`） | `变异体: rc=0 · 首行=change alpha · ready` | `原树: rc=1 · 首行=change alpha · not ready` |
| 3 | 面板 `changeTasksLine` 不再按宽度整行丢弃（`return { line }` 无条件） | `窄帧与「无 token」帧逐字节一致=no · 帧里含 G01 token=yes`（行留在块里） | `窄帧与「无 token」帧逐字节一致=yes · 帧里含 G01 token=no` |

变异 3 的红侧 diff（原始）：

```
7,16c7,15
< │   · V21       verify  阻塞    阻塞夹具                          │   │   G01 todo · G02 todo · G03 todo · G04 todo · G05 todo · G06 todo… │
< │   · P13       dev     完成    消息入口与三个动作                │   ╰────────────────────────────────────────────────────╯
```

还原证明：

```
$ git status --porcelain -- skills openspec AGENTS.md      # 空 → ok 实现树干净
$ git status --porcelain | grep -v P69-verify/             # 空 → ok 只有本报告包是新文件
```

## Findings

| # | severity | finding | 证据 | 建议 |
|---|---|---|---|---|
| F1 | low（展示） | digest 里 `[6] change 归组` 与死 pane 段的 `[6]` 同时出现两个 `[6]` | `grep -E '^\[6\]' <digest>` 两行（真实死 pane 复现，见 §3） | PM 决定：重排 change 段号，或给死 pane 段另一个编号；规格只要求「不重排 `[1]`–`[5]`」，没要求全局唯一，故不影响本 change 的验收 |
| F2 | low（展示） | `team change status` 的复验记录证据行打印 `docs/team/<ID>.md: PASS`，真实文件是 `docs/team/reviews/<ID>.md`（缺 `reviews/` 段） | raw-demo ⑧：`M1 apply dev done docs/team/M1.md: PASS`；`reviews/M1.md` 实际存在 | 一行格式化（`team_task_evidence_line`）的小修；判定内容（PASS）正确，不阻塞 |

环境类（**不是**本 change 的 finding，已在上文点名归属）：FAST 的 `12b-j` 共享账本被并发夹具污染、
`40 lint` 8 条落在他人的文件上、门禁锁自死锁 + 排队静默超时（P66）。

## Decisions and deviations

- **不 push**：本仓库 local 模式（任务书明示）；分支留在 `.worktrees/verify` 的 `task/P69-change-centric`。
- **红侧不开真窗口**：拒绝类断言用记录式 shim（0 次开窗请求比「真 tmux 里没有窗」更强且更快）；
  只有 `--force` 必须真派单成功才写审计，那部分走私有 `-L` server（socket 名烘死在 PATH shim 里）。
- **夹具分组**：规则 2 的「不相交」绿侧必须放在**没有 unknown 声明兄弟**的项目里——否则会因另一个
  未结束兄弟（缺失 `deltas:` = 全量）而拒，那是夹具串台不是守卫缺陷。
- **`[6]` 号冲突**：按要求只作为 finding 陈述，不当 FAIL（规格的两条要求——不重排 `[1]`–`[5]`、
  段内 token 有界——都实测成立）。
- **变异 1 的红侧要越过守卫才看得见**：夹具给新任务建好工作树（否则变异体会停在「worktree 不存在」，
  而不是「真的去建窗口」）；红侧因此看到 shim 开窗请求 1 次。
- **全量门禁**：第一轮在 1800s 队列上限**静默超时**（环境），第二轮 `TEAM_SMOKE_LOCK_WAIT=5400`
  重排；不进 `TEAM_SMOKE_NO_LOCK=1`（不破坏「一套门禁」纪律）。
- **计数口径**：包内 188 条断言 = 段 10(49) + 20(34) + 30(19) + 40(58) + 50(19) + 60(9)；
  报告 §2/§3 共用段 40 那一次运行，不重复计数。

## Suggested next steps

- PM 复验：`team review P69 --strong`（独立 checkout 重跑本包 `bash docs/team/reports/P69-verify/pkg/run.sh`）。
- F1/F2 的处置由 PM 决定（两处都是一行改动 + 一个断言）；F1 若改段号，注意 smoke 12f 与
  P55 的段落断言（`[1]`–`[5]` 的字节稳定性断言不受影响）。
- 全量 smoke 的唯一红是既有 lint（P64/P55），与本 change 无交集——合并判定可以直接引用本节。
