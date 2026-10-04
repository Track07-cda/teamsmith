# P182 · `meeting-liveness` 换人复验（P153 FAIL → P160 返工之后）

```
task:    P182
agent:   dev
change:  meeting-liveness
phase:   verify
tip:     a34b81d7a5c64ac33ee27b8861e065f8713d5c8e（复验时的被测树 = 派单时的 main tip；此后 main 又进了 6 个提交，全是 docs/team 与其它能力的规格/归档，不碰 `skills/**` 与 `meeting-liveness` 的 delta —— 见 §8 末尾）
branch:  task/P182-verify（local 模式：分支留在本地 worktree，未 push）
verdict: **PASS** —— 三条缺陷真修好（各自有独立夹具 + 影子），既有承诺未破，门禁全绿；无阻塞性 finding
```

## 0. 判定摘要

| 任务书条目 | 判定 | 我的证据（不是引用 P160） |
|---|---|---|
| **1 F1 账本补记**（入队不写 / 投递补记同一轮次 / 只排队不写） | ✅ | §2 · 自建 alpha/beta + 假 TUI 夹具；4 轮敲门、3 种投递形状 |
| **2 F2 标识宽度**（7/12 同一 HEAD 逐字节相同 + 影子必红） | ✅ | §3 · CLI 与扩展两个发送方各跑一次；`--short` 前提当场证明；2 个影子 |
| **3 F3 不编造 task**（空闲分支无 `task=` + 真任务分支必须有） | ✅ | §4 · inbox 行与 knock 载荷两面；三种证据来源反向 |
| **4 既有承诺**（草稿保护 / 至多一次 / standby 不叫 / 无待办沉默） | ✅ | §5 · 草稿 md5 逐字节、提交计数、`watch --once` 三态 |
| **5 发现性与收尾**（未读 / `--peek` / `close --stale`） | ✅（抽查） | §6 |
| **6 门禁** | ✅ | §8 · validate 22/0 · 容器 `--select 55,56` ✓178 ✗0 · 容器 FAST ✓3792 ✗0（账本自查一致） |
| **影子/翻转证据** | ✅ | §7 · 6 个变异体各自点名变红 |

## 1. 我怎么验的（对抗验证包）

包在 `docs/team/reports/P182-dev/pkg/`：`lib.sh` + `run.sh` + 7 个编号段（`10-status` … `70-shadows`）+ `ext-probe.mjs` + `mutants/f1a.py…f3b.py`。**夹具全部由我自己建**（`team init` 起最小仓库、自己 `worktree add`、自己手写 transcript / 看板行 / 任务书），不复用 smoke 的 P139 夹具；唯一复用件是 `tests/fake-tui.py`（pane 模拟器，不是被测件，见 §9 第 1 条）。

跑法（P162 纪律：门禁与 tmux 夹具一律在容器里；tmux 用本轮私有 `TMUX_TMPDIR`，session 名带 `p182-<runid>-` 前缀，只清自己这一族）：

```bash
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id \
  -e HOME=/tmp -e P182_IN_CONTAINER=1 -v "$PWD":/work -w /work localhost/teamsmith-gate:local \
  bash -c 'P182_TREE_TIP=a34b81d7a5c64ac33ee27b8861e065f8713d5c8e \
           bash /work/docs/team/reports/P182-dev/pkg/run.sh'
```

一次完整跑（`logs/00-run.log`，含 `70-shadows` 的 6 个子跑）：

```text
== 10 结果 ==  ✓21 ✗0 skip0 finding0
== 20 结果 ==  ✓28 ✗0 skip0 finding0
== 30 结果 ==  ✓23 ✗0 skip0 finding0
== 40 结果 ==  ✓18 ✗0 skip0 finding0
== 50 结果 ==  ✓17 ✗0 skip0 finding0
== 60 结果 ==  ✓16 ✗0 skip0 finding0
== 70 结果 ==  ✓12 ✗0 skip0 finding0
P182 验证包：全绿
```

共 **135 条断言**，0 红。每段的逐条输出在 `logs/<段>.log`，单段输出在 `logs/00-run.log` 里也有。

## 2. F1 · 排队敲门的账本（自建夹具，四轮敲门三种形状）

夹具：`alpha`（发起方）与 `beta`（被敲方，自己的 tmux session + `pi` 窗口跑假 TUI，框里有草稿）；会议 `m-f1` 由 alpha 开、登记 `beta=<session> --window pi`。断言与结果（`logs/20-f1-ledger.log`）：

```text
✓ F1① 脏框敲门报 queued（不是 knocked）
✓ F1① 对方草稿逐字节未动（真草稿仍受保护）
✓ F1① 入队时账本零写入（共享区承诺）
✓ F1① 排队载荷带轮次 [meeting:m-f1#1]
✓ F1② 排水后投递恰好一次（提交 +1）
✓ F1② 投递载荷的轮次与队列里的一致
✓ F1② 账本补记同一轮次（对象 beta、意图 info、轮次 #1）
✓ F1② 该轮在账本里恰好一行
✓ F1④ 再排水不重投（提交数不变）／账本仍是恰好一行
✓ F1③ 只排队（未投递）时账本没有该轮
✓ F1③ 清框后 #2 投递一次 ／ #2 在账本里恰好一行
✓ F1③c 目标不可投（shell）时账本没有该轮
✓ F1⑤ --now 强制投递也补账本（#3 恰好一行）
```

覆盖了任务书的三条：**入队那一刻共享区零写入**（入队后立刻查 `knocks.log`）、**清空后 `outbox flush` 真投递时补记同一轮次**（账本行按 `knocked beta by … intent=info [meeting:m-f1#1]` 正则匹配，行数与载荷轮次都对上）、**只入队、从未投递 → 账本里没有该轮**（先验证 BUSY 排水不写，再把目标窗换成裸 shell 验证不可投也不写）。顺带把「再排水不重投/不重记」与 `--now` 路径也钉住（`forced.log` 旁证）。

## 3. F2 · 标识宽度（CLI 与扩展两个发送方，先证明前提再断言）

前提当场证明（不是引用 P153）：夹具里 `core.abbrev=7` → `git rev-parse --short HEAD` 是 7 位，`=12` → 12 位，两者逐字节不同；也就是说「旧形状确实随配置漂」在这个夹具上成立。

```text
✓ F2 前提：core.abbrev=7 时 --short 是 7 位（配置真的生效）
✓ F2 前提：core.abbrev=12 时 --short 是 12 位
✓ F2 前提：两种配置下 --short 逐字节不同（旧形状确实是缺陷）
✓ F2 CLI：同一 HEAD 在 core.abbrev 7/12 下 tip 逐字节相同
✓ F2 CLI：tip 宽度固定 12（不跟 core.abbrev）／tip = 全量 HEAD 前 12 位
✓ F2 扩展：core.abbrev 7/12 的 tip 逐字节相同
✓ F2 扩展：tip 宽度固定 12 ／ tip = 全量 HEAD 前 12 位
✓ F2 两个发送方同一契约：CLI tip == 扩展 tip
✓ F2 CLI：两条通知都在（摘要没被标识吃掉）／F2 扩展：摘要逐字节保留
```

CLI 侧走真命令 `team notify`（`--from dev`，工作树在 `task/P9-parser`）；扩展侧用 `ext-probe.mjs` 把 `extension/team-notify.ts` 当 pi 扩展加载（与 smoke §13 同一加载方式，夹具与断言是我自己的）。**接收方「互为前缀」判据**是规格里的判断规则、产品里没有对应代码路径，所以我验的是文字与 wire 形状：delta 里 `one is a prefix of the other` / `MUST NOT be a Git abbreviation` / `SHALL stamp`，`references/protocol.md` 的同一句（`logs/10-status.log`）。

顺带一份**真仓库现场**（不是夹具）：本报告交付时的回合通知就落在这条规则上 —— `docs/team/inbox/pm.md` 里这行是 CLI 自己写的，`task=P182`（任务书在册）与 `tip=e4660bde976c`（当时 HEAD `e4660bde…` 的前 12 位）都出自本次要验的两条修法。

## 4. F3 · 只有证明得了的任务分支才盖 `task=`（inbox 行与 knock 载荷两面）

```text
✓ F3 前提：工作树在普通席位分支 agent/idle ／没有 state/idle.env
✓ F3A agent/idle 的 inbox 行不盖 task=（不编造）
✓ F3A 函数级：team_notify_rev_stamp idle 为空
✓ F3B agent/dev 有证据也不盖（分支形状是硬前提）
✓ F3C task/ghost-run（无证据）不盖 task=
✓ F3D 非任务分支（有 state 证据）不盖 task=
✓ F3E 反向：state 证据 → task=P10 tip=<12>
✓ F3F 反向：看板证据 → task=P11 tip=<12>
✓ F3G 反向：任务书证据 → task=P9 tip=<12>
✓ F3H 空闲席位的 knock 载荷不盖 task=（脏 PM 框 → 入队后读条目载荷）
✓ F3H 反向：真任务分支的 knock 载荷带 task=P10 tip=<12>
✓ F3 扩展：agent/idle 不盖 task= ／ 非任务分支（有 state 证据）也不盖 task=
```

比任务书多打了四格：`agent/<seat>` **有**任务书/看板行也不盖（分支形状是硬前提）、`task/<ID>` 但 ID 无证据不盖（fail-closed）、非任务分支有 state 证据不盖、knock 载荷面与 inbox 行面同判。反向三种证据来源（state / 看板 / 任务书）都真的盖出了 `task=<ID> tip=<12>`。

## 5. 既有承诺（P109 两条 + 草稿保护 + 至多一次）

`logs/50-promises.log`：巡检仓库 + 脏 PM 框 + 活 `state/pm.pid`，跑三态：

```text
✓ F4 无待办：巡检沉默（P109 承诺）／没有叫醒记录／没有叫醒语进队列
✓ F4 standby：巡检不叫（P109 承诺）／没有叫醒记录／叫醒语没有进队列／PM 草稿逐字节未动
✓ F4 standby off：叫醒记录恰好一行／巡检叫醒
✓ F4 脏框：叫醒语进队列而不是粘字／队列载荷是叫醒语／PM 草稿逐字节未动
✓ F4 至多一次：叫醒记录仍是一行／队列仍是一条
```

草稿保护与「至多一次」在 F1 夹具里另有独立见证（§2 的 md5 与提交计数）。

## 6. 发现性与收尾（抽查）

`logs/60-discovery.log`：未读 peer turn 进 `meeting inbox`；`--peek` 打印该轮且 `read/<project>.seq` 逐字节不动，`read` 推进到 1 后 inbox 不再列它；过期会议在 `list` 里是 `expired`、`say` 被拒并点名 TTL；`close --stale` 只关过期那一场（另一场 `state.env` 逐字节未动），没有过期会议时非 0 且点名「没有已过期未关闭的会议」。

## 7. 影子（红侧：破坏实现 → 我的断言必须点名变红）

6 个变异体各自在被测树的一份拷贝上做，跑对应的段，要求**非 0 且命中点名的断言**（`logs/70-shadows.log`）：

| 变异 | 破坏的承重件 | 必须红的断言 | 结果 |
|---|---|---|---|
| f1a | 摘掉投递回执（`team_outbox_record_delivery_receipt` 直接 return） | F1② 账本补记同一轮次 | ✓ 命中 |
| f1b | 入队分支立刻写账本 | F1① 入队时账本必须零写入 | ✓ 命中 |
| f2a | CLI 改回 `git rev-parse --short HEAD` | F2 CLI：7/12 tip 逐字节相同 | ✓ 命中 |
| f2b | 扩展去掉 `slice(0, TIP_WIDTH)`、改回 `--short` | F2 扩展：7/12 tip 逐字节相同 | ✓ 命中 |
| f3a | CLI 恢复 `task/*|agent/*` + 去掉证据检查 | F3A agent/idle 不盖 task= | ✓ 命中 |
| f3b | 扩展恢复 `task|agent` + 去掉 `hasTaskEvidence` | F3 扩展：agent/idle 不盖 task= | ✓ 命中 |

```text
✓ F1 影子a（摘掉投递回执）：变异后按预期变红（F1② 账本补记同一轮次）
✓ F1 影子b（入队即写账本）：变异后按预期变红（F1① 入队时账本必须零写入）
✓ F2 影子a（CLI 改回 --short）：变异后按预期变红（F2 CLI：同一 HEAD 在 core.abbrev 7/12 下 tip 逐字节相同）
✓ F2 影子b（扩展改回 --short）：变异后按预期变红（F2 扩展：core.abbrev 7/12 的 tip 逐字节相同）
✓ F3 影子a（CLI 恢复旧形状）：变异后按预期变红（F3A agent/idle 的 inbox 行不盖 task=）
✓ F3 影子b（扩展恢复旧形状）：变异后按预期变红（F3 扩展：agent/idle 不盖 task=）
== 70 结果 ==  ✓12 ✗0 skip0 finding0
```

变异只发生在拷贝里；被测树没有被改动（交付时 `git status --porcelain` 只剩本报告与日志，`skills/**` 零改动）。

## 8. 门禁（容器里跑，原始输出）

被测树：独立 clone（`git status --porcelain` 空）在 `/tmp/p182-dev/tree`，tip `a34b81d7`。

| # | 命令（容器 `localhost/teamsmith-gate:local`） | 结果 | 日志 |
|---|---|---|---|
| 1 | `openspec validate --all --strict` | rc=0 · `Totals: 22 passed, 0 failed (22 items)` | `logs/10-openspec.log` |
| 2 | `smoke.sh --select 55,56` | rc=0 · `== 选段结果 ==  ✓ 178  ✗ 0`（55：✓88 ✗0 11s；56：✓69 ✗0 14s；6/123 段） | `logs/20-select.log` |
| 3 | `TEAM_SMOKE_FAST=1 smoke.sh` | rc=0 · `== 结果 ==  ✓ 3792  ✗ 0` · 账本自查 `123 段收口 · 增量 ✓3792 ✗0 SKIP36 ｜ 结果行 ✓3792 ✗0 —— 一致` | `logs/30-fast.log` |

```text
--- 10-openspec.log
Totals: 22 passed, 0 failed (22 items)
openspec rc=0

--- 20-select.log
#5 55 · meeting-liveness：未读 / 过期 / 队列 / 标识（P139，纯逻辑） · 用时 11s · ✓88 ✗0 SKIP0 · ticks 88
#6 56 · meeting-liveness 真 tmux：敲门 / 排水 / 每方窗口（P139） · 用时 14s · ✓69 ✗0 SKIP0 · ticks 69
== 选段结果 ==  ✓ 178  ✗ 0

--- 30-fast.log
账本自查： 123 段收口 · 增量 ✓3792 ✗0 SKIP36 ｜ 结果行 ✓3792 ✗0 —— 一致
== 结果 ==  ✓ 3792  ✗ 0
FAST 模式：跳过 36 个真进程段落（… 26-m·真 pane|…|55·会议真 tmux）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿
```

三条门禁都在**独立 clone**（`/tmp/p182-dev/tree`，`git status --porcelain` 空）与容器里跑；机器是共享的（跑门禁期间另有 3 个别人的 `teamsmith-gate:local` 容器在场，宿主 `loadavg` 5–8）。FAST 模式按设计**跳过真进程段落，其中包括会议真 tmux 那一段**（日志尾行逐个点名），所以会议面由门禁 2（`--select 55,56`，容器内真 tmux、私有 socket）承担——两者合起来才覆盖任务书要求的面。

**被测 revision 与 main 的关系**：门禁跑在 `a34b81d7`（派单时的 main tip）。复验结束时 main 已到 `d6ddbaeb`，新增的 6 个提交全部是 `docs/team/**`（任务书/看板/决策）与 `dispatch`/`panel`/`verification`/`watchdog` 四个**其它**能力的规格/归档；`git diff --name-only a34b81d7 main | grep -E '^skills/|meeting'` 只有两份**任务书**（P182/P193），没有产品代码、没有 `meeting-liveness` 的 delta。也就是说：本报告对产品代码与 meeting deltas 的结论对当前 main 同样成立；PM 归档前按惯例在合并后的树上重跑门禁即可（`openspec validate` 的条目数会因归档而变，22 只是 `a34b81d7` 上的读数）。

## 9. 没有测到什么（边界与残余）

1. **真实跨项目会议**：没有第二个项目/PM 在场，敲门面全部在容器夹具里（假 TUI）。真 Pi 输入框的几何判定（`team_delivery_verdict` 的 EMPTY/BUSY/UNTRUSTED 分支）没有用真 Pi 跑过。
2. **接收方「互为前缀」判据没有产品代码路径**：它是规格给 PM 的判断规则，我验的是 delta/protocol.md 的文字与两个发送方的 wire 形状，不是某段代码。
3. **F1 的 held 路径**：我用「目标窗换成裸 shell → 不可投」代表「只排队未投递」，没有等 TTL 到期把条目送进 `held/`（那需要真等 `TEAM_DEFER_TTL`）；`held` 不写账本是从代码路径与不可投用例推出来的，没有直接的 held 现场。
4. **`--now` 是在裸 shell 上验的**（盲打，审计行在 `forced.log`）：没有在真 TUI 上验强制投递的渲染。
5. **没有跑全量门禁**：任务书只要求 validate + `--select 55,56` + FAST；全量留给 PM 复验/归档。
6. **P153 的「敲门挂 900 秒」**：P153 记录为未复现、成因未定位；本次没有再去追它（任务书没要求），它仍是已知残余。
7. **P153 的 F4（与本变更无关的全量红）**：本次只跑 FAST，没有制造全量现场来复核它。

## 10. 观察（非本次范围，供 PM 决策）

**工作树里的 `config.sh` 副本会盖掉主工作树的改动。** 复验中我踩到并定位了它：夹具里 `team init` 把 `.pi/team/config.sh` 提交进 `main` 之后，`git worktree add` 出来的席位工作树带着**自己那份旧副本**；从工作树里跑 `team paths` / `team notify` 时，CLI 读到的是旧副本的值（我的夹具里 `TEAM_PM_WINDOW` 主配置改成 `pi`，工作树仍读到 `pm`，于是 notify 判成「PM 不在运行」）。扩展侧走 `git rev-parse --git-common-dir` 落到主工作树，和 CLI 不是同一份配置。

- 证据（可重跑）：`logs/obs-config-copy.log`，脚本 `pkg/obs-config-copy.sh`（不进 `run.sh`，它不是判定）——夹具 `team init` → 提交脚手架 → `worktree add` → 把主配置的 `TEAM_PM_WINDOW` 改成 `pulse-renamed`：

```text
· 主工作树 `team paths` → pm_window=pulse-renamed
· 席位工作树 `team paths` → pm_window=pm
· 工作树副本里的那一行：TEAM_PM_WINDOW="pm"        # window running the PM; notifications are typed into it
· 主配置里的最后一行：TEAM_PM_WINDOW="pulse-renamed"
✓ 复现：主配置改了、工作树仍读旧副本（两处读的不是同一份配置）
```

  本仓库自身也满足前提——`.pi/team/config.sh` 是**被跟踪**的（`git ls-files .pi/team/config.sh` 有输出），每个席位工作树都有一份创建时刻的副本。
- 影响面：只有当配置在「工作树创建之后」被改过才有差别；本项目的关键键（session / PM 窗口 / docs 目录）目前两边一致，所以**没有观察到实际故障**。
- 与 P160 无关（M40 时代的既有行为），也不是本 change 的 delta 范围。若 PM 认为值得处理，建议另开 infra 任务（候选形状：CLI 与扩展统一到主工作树的配置，或在 `team paths`/doctor 里对「工作树副本与主配置不一致」点名）。

## 11. 命令与日志索引

```text
docs/team/reports/P182-dev/pkg/            验证包（lib/run/7 段/扩展探针/6 个变异脚本）
docs/team/reports/P182-dev/logs/00-run.log 验证包完整一次跑（含影子）
docs/team/reports/P182-dev/logs/10-status.log … 70-shadows.log   分段原始输出
docs/team/reports/P182-dev/logs/00-tree.txt       被测 tip / 分支 / 宿主现场
docs/team/reports/P182-dev/logs/10-openspec.log   门禁 1
docs/team/reports/P182-dev/logs/20-select.log     门禁 2（--select 55,56）
docs/team/reports/P182-dev/logs/30-fast.log       门禁 3（FAST）
docs/team/reports/P182-dev/logs/obs-config-copy.log  观察复现（§10，非判定）
docs/team/reports/P182-dev/pkg/obs-config-copy.sh     观察复现脚本
```

自跑的命令（全部在容器里）：验证包 `run.sh` 一次；`smoke.sh --select 55,56` 一次；`TEAM_SMOKE_FAST=1 smoke.sh` 一次；`openspec validate --all --strict` 一次。引用的只有：P153 的三条缺陷形状与 PM 的裁断（来自任务书/评审，作对照，不作证据）。

---

Agent: dev
