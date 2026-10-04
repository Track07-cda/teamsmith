# M11 · bootstrap 不该把 PM 窗口名写成当前窗口碰巧的名字

agent: dev   状态: 完成（待 PM 独立复验）   时间: 2026-09-16 14:20–15:05
branch: `task/M11-bootstrap-pm-pm-doctor`（= `abedc30` + 4 个提交）
PR/MR: -（TEAM_VCS=local：分支留在本地 worktree，PM 复验后本地合并）

## 交付物

| 路径 | 内容 |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-bootstrap.sh` | `pmwin` 不再取 `det_win`（约定 > 现场）；当前窗口名不同时按守卫条件顺手改名，改不动就打印确切命令；新增局部 helper `team_bootstrap_rename_pm_window`（空目标拒绝） |
| `skills/teamsmith/scripts/lib/cmd-project.sh` | doctor 新增「PM 窗口名漂移」检查 + `team_pm_window_drift` / `team_is_agentish_window`；「PM 存活」的 `missing` 分支在漂移时不再劝人直接 `up` |
| `skills/teamsmith/templates/config.sh.tmpl` | 注释两行：PM 窗口名是约定，bootstrap 不继承当前窗口的名字 |
| `skills/teamsmith/tests/smoke.sh` | 新段 `1c · bootstrap 的 PM 窗口名：约定不是现场（M11）`：①–⑤ 假 tmux 夹具（FAST 照跑）＋ ⑥ 真沙盒窗口夹具（真 tmux，FAST 跳过并登记）；`14c` 的跳过登记表加一条 |
| `docs/team/reports/M11-dev.md` | 本报告 |

未改动：`init`（它本来就不探测窗口，`pmwin="${pmwin:-pm}"`，写配置这一侧原本是对的）、巡检/pulse 逻辑、
`common.sh`、任何既有断言、版本号与 CHANGELOG（发版归 PM）。只碰了任务书「边界」列出的 4 个文件。

## 任务书要求逐条对照

| # | 要求 | 落地 | 证伪器 |
|---|---|---|---|
| 1 | 写配置固定用 `pm`，不继承当前窗口名 | `pmwin="${pmwin:-${TEAM_PM_WINDOW:-pm}}"`（`--pm-window` 是显式约定，仍照给） | smoke 1c①②③④ |
| 1 | 当前窗口名不同时顺手改名（或给命令） | 满足「cwd 在本项目 + session 一致 + 目标名空着 + 目标就是 `pm`」时代改；其它情形打印 `改名：tmux rename-window …` | smoke 1c②（假 tmux 证明命令）＋ 1c⑥（真 tmux 证明落地）＋ 1c④（不代改时给命令） |
| 2 | doctor 报「配置名与现场不符」（对改名漂移说人话） | 新检查 `PM 窗口名`：配置窗口缺失 + 现场有窗口在跑配置的 PM CLI（argv 命中 + cwd 在本项目，排除名册/巡检/草稿窗口）→ 报警，点名现场窗口、两条对齐办法、以及「直接 up 会开出第二个 PM」 | smoke 1c⑤（含负对照） |
| 3 | 窗口名是 `pi` 的沙盒 session 里跑 bootstrap → 配置必须是 `pm` | §1c⑥：真 tmux session `…:pi` 里跑 bootstrap，断言配置 `TEAM_PM_WINDOW="pm"` 且 `list-windows` 真的变成 `pm` | smoke 1c⑥ |

## 验证证据（全部真实执行过；命令逐字可复制）

### ① 现场复现（事故形状）：红 → 绿

**红（修复前，`abedc30`）** —— 真 tmux 沙盒 session，窗口碰巧叫 `pi`，在窗口里跑 `team bootstrap`：

```sh
$ tmux new-session -d -s m11-repro-$$ -n pi -c /tmp/m11-repro/repo
$ tmux respawn-pane -k -t m11-repro-$$:pi "cd /tmp/m11-repro/repo && bash $SKILL/scripts/team bootstrap --agents dev --session m11-repro-$$ --no-pulse; …"
--- 窗口名现在的现场: [pi ]
--- config PM_WINDOW: 9:TEAM_PM_WINDOW="pi"        # window running the PM; notifications are typed into it
```

**绿（修复后，交付 tip）** —— 同一条命令、同一个形状：

```sh
$ bash /tmp/m11-repro/repro.sh
bootstrap rc: 0
窗口名现在的现场: [pm ]
配置写下的: 11:TEAM_PM_WINDOW="pm"        # window running the PM; notifications are typed into it
--- bootstrap 输出里的窗口行 ---
3:  tmux        m11-repro-4151752:pm（探测自当前窗口）
4-      当前窗口 pi → pm（PM 窗口名是约定，不跟着现场走）
```

同一个事故形状下 doctor 的漂移报警（配置保留旧 bug 写下的 `pi`、PM 真的活着）：

```sh
$ bash /tmp/m11-repro/drift.sh
现场窗口: [pm ]  配置: TEAM_PM_WINDOW="pi"
--- team doctor 的相关行 ---
20:  PM 窗口名             ! 配置写的是 'pi'，但 m11-drift-4163026 里在跑 PM 的窗口叫 'pm'（改名漂移）：先对齐名字再动手 —— team up 只认配置，会另开一个 'pi' 窗口（两个 PM）。二选一：tmux rename-window -t m11-drift-4163026:pm pi ／ 把配置改成 TEAM_PM_WINDOW="pm"
21:  PM 存活                ! PM 窗口 m11-drift-4163026:pi 不存在，但 'pm' 里跑着 PM（见上一条「PM 窗口名」）→ 先对齐名字，别直接 up
```

（`/tmp/m11-repro/{repro.sh,drift.sh,bootstrap.log}` 是本报告用的复现脚本；两个沙盒 session 跑完即 kill，
下面「夹具副作用」有检查。）

### ② 门禁（任务书的验收命令，在交付 tip 的干净树上逐字跑）

```sh
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
- Validating...
✓ spec/agent-adapters … ✓ spec/watchdog
Totals: 12 passed, 0 failed (12 items)
== 结果 ==  ✓ 1734  ✗ 0
smoke 全绿
== 结果 ==  ✓ 1334  ✗ 0
smoke 全绿
$ echo $?
0
```

- 基线（同一命令、修复前、干净树）：全量 `✓ 1711 ✗ 0`（4m43）、FAST `✓ 1313 ✗ 0`（1m47）；
  改造后 全量 `✓ 1734/1735 ✗ 0`（4m46）、FAST `✓ 1334 ✗ 0`。新增 24 条断言，既有断言一条未删。
- 两次全量之间差 1 条是**既有**的条件断言：`11b3` 的「反向守卫：真实账本 inbox+state 一个字节没变」在真实账本
  （`<home>/…/pm-skills`）本段期间有别的写入时改打 `ℹ 反向守卫：真实账本在本段里有别的写入（… ；上面已证明其中没有夹具签名）`
  —— 团队在跑时属正常，不是失败，与 M11 无关。
- 环境说明：本机 `openspec` 装在 `~/.bun/bin`，不在我的 shell PATH 里（M8.1 那类 PATH 现象），
  所以验收命令前面加了 `PATH="$HOME/.bun/bin:$PATH"`。`.pi/team/config.sh` 里的 `TEAM_GATES`
  是两件套（M10 起 spec-lint 已删），与任务书一致。

### ③ 翻转证据（「破坏实现 → 守门测试必须失败 → 还原」；两次、分别定位）

**破坏 A：把 `pmwin` 换回旧写法**（`pmwin="${pmwin:-${det_win:-${TEAM_PM_WINDOW:-pm}}}"`）

```sh
$ sed -i 's|^  pmwin="${pmwin:-${TEAM_PM_WINDOW:-pm}}"$|  pmwin="${pmwin:-${det_win:-${TEAM_PM_WINDOW:-pm}}}"|' skills/teamsmith/scripts/lib/cmd-bootstrap.sh
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh        # EXIT=1
  ✗ M11 ①：计划里的 PM 窗口名是约定 pm（… 中找不到 [--pm-window pm]）
  ✗ M11 ①：--print 给出确切的改名命令
  ✗ M11 ②：配置写的是约定 pm，不是当前窗口 pi（… 中找不到 [TEAM_PM_WINDOW="pm"]）
  ✗ M11 ②：下了确切的改名命令
  ✗ M11 ②：输出里说明改了名
== 结果 ==  ✓ 1329  ✗ 5
$ git checkout -- skills/teamsmith/scripts/lib/cmd-bootstrap.sh
restored: H0=f1ce0c67… H1=f1ce0c67… same=yes          # sha1 逐字节还原
```

只红 bootstrap 那 5 条（①②），doctor 的 ⑤ 全绿 —— 破坏与断言一一对应。

**破坏 B：让 doctor 的漂移检查永不开口**（`pmwin_drift="$(team_pm_window_drift)"` → `pmwin_drift=""`）

```sh
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh        # EXIT=1
  ✗ M11 ⑤：doctor 有「PM 窗口名」这一条
  ✗ M11 ⑤：点明是改名漂移（不是笼统的「窗口缺失」）
  ✗ M11 ⑤：点名现场窗口
  ✗ M11 ⑤：给出对齐名字的确切命令
  ✗ M11 ⑤：点明直接 up 的后果（会开出第二个 PM）
== 结果 ==  ✓ 1329  ✗ 5
$ git checkout -- skills/teamsmith/scripts/lib/cmd-project.sh
restored: H0=20863bcb… H1=20863bcb… same=yes          # sha1 逐字节还原
```

只红 doctor 那 5 条（⑤），①–④ 全绿；连负对照（配置与现场一致时不刷漂移行）都仍然绿。

**红证据（先写证伪器、再改实现）**：夹具是在改实现之前提交的（`7f33e49`），当时 FAST 跑出
`== 结果 == ✓ 1323 ✗ 11`，红的正是 1c 的 11 条（配置写成 `pi`、一条 `rename-window` 都没下、
doctor 里搜不到「PM 窗口名/改名漂移」）。日志 `/tmp/m11-red-fast.log`。

### ④ 夹具副作用（P6 纪律）

```sh
$ bash /tmp/m11-fixture-cleanup.sh          # 把 1c⑤ 单独拿出来：起真进程 → 断言报警 → 收尾
夹具进程 pid=2334001 活着：yes
doctor 报警：1 行
收尾后 pid 还在：no                         # kill 生效
m11-drift-repo 里残留进程数：0

$ for p in /proc/[0-9]*/cwd; do c=$(readlink "$p" 2>/dev/null || true); case "$c" in *m11-drift-repo*|*m11-live-repo*|*m11-repro*|*m11-print-repo*|*m11-conv-repo*|*m11-same-repo*|*m11-explicit-repo*) echo "LEAK $c";; esac; done
（空 —— 没有残留进程）
$ tmux ls | grep -c m11          # 0：两个复现 session + 1c⑥ 的真沙盒 session 全部已收
$ for d in N207LV 0Dj2hd T653Nt c4EYyq QPAEuS 546v86 8skeH3 jfUf94; do [ -d "/tmp/teamsmith-smoke.$d" ] && echo "still-there: $d"; done
（空 —— 我这轮 7 次 smoke 的临时目录全部由 smoke 既有的 EXIT trap 删掉）
$ tmux ls | grep -E 'teamsmith-smoke'
teamsmith-smoke-2193632: 4 windows (created Wed Sep 16 09:45:03 2026)   # 别人的遗留，早于我这一轮（14:2x 起）
teamsmith-smoke-2702769: 4 windows (created Wed Sep 16 08:12:58 2026)
teamsmith-smoke-43280:   4 windows (created Wed Sep 16 08:53:38 2026)
```

1c⑥ 的 pane 收尾是 `tmux kill-session`（`exec sleep 300` 随 pane 一起消失）；1c 起的 6 个 git 临时仓库（A–E + 真沙盒那个）都在 `$TMP` 里，
由 smoke 既有的 EXIT trap 删除。

## 决定与偏离（含偏保守的取舍）

1. **代改名的范围比任务书要求的更窄（刻意）**：只在「目标名就是约定 `pm`」时 bootstrap 才真的动窗口；
   `--pm-window tool` 或配置里写着别的名字时只打印 `改名：tmux rename-window …` 命令。
   理由：`--pm-window` 的人为语义是「这次按这个名字写配置」，不是「顺手把我正坐着的窗口改名」——
   从 worker 窗口误跑 bootstrap 时不该搬别人的窗口。任务书两种做法都允许（「或在输出里给出一条改名命令」）。
   另外三条守卫（cwd 属于本项目 / session 与要写的一致 / 目标名没被别的窗口占）都在动窗口之前判。
2. **doctor 不一定开口**：只有「配置窗口不在 + 有窗口在跑配置的 PM CLI 且 cwd 在本项目」才报警，
   与 `team_pm_state` 的「人工启动的 PM」同一证据标准；认不出来就沉默（不猜一个窗口名字出来）。
   名册 / pulse / watchdog / draft 窗口被排除，因为 worker 跑的是同一个 agent 可执行文件 —— 不排除会把
   worker 窗口报成漂移的 PM 现场。检查是纯只读（tmux 读 + `/proc`），符合 M6.1 F28。
3. **`init` 未改**：`team_cmd_init` 的 `pmwin="${pmwin:-pm}"` 本来就不探测窗口，写配置这一侧没问题；
   问题只在 bootstrap 把 `det_win` 传了进去。任务书要求 1 的前半句因此无需改动（少一个改动面）。
4. **「PM 存活」的 `missing` 分支在漂移时改了措辞**：原来无条件说「→ team up」，而在漂移现场照做会开出
   第二个 PM —— 这是任务书说的「现在的提示不说人话」的另一半，所以一并改；两条警告各司其职（一条说漂移、
   一条说存活），不是同一句重复。
5. **模板注释写在值上面两行**（`templates/config.sh.tmpl`）：任务书说「注释一句话」，一行装不下
   「是约定 + 会改当前窗口」两层，所以用了两行；没有动任何键或默认值。
6. **没有动 CHANGELOG / 版本号**：本仓库的 release（`chore(teamsmith): release vX`）由 PM 做，
   smoke 的「版本号三处一致」断言也要求三处一起改，超出任务书边界。
7. **【观察，不属本任务，未改】** `skills/teamsmith/tests/smoke.sh` §6h 的楔死夹具里那个
   `sleep 300 >/dev/null 2>&1 &`（tmux shim 的 `new-window` 分支）会留下孤儿进程（cwd = 本次运行的主仓库，
   5 分钟后自己退出）。我在 FAST 运行里看到两个（`QPAEuS/repo`、`546v86/repo`），**不是** M11 夹具：
   我的 `sleep` 在 `m11-drift-repo` 里且被 kill（上面 ④ 已证）。`tests/**` 归我，但它不在 M11 范围，
   只报告不改 —— 要收的话建议给 shim 记 pid 并在 cleanup 里回收（同一族：夹具不许留副作用）。
8. **【观察，未动】** tmux server 里有 3 个别人早先留下的 `teamsmith-smoke-*` session（创建于 08:12 / 08:53 / 09:45，
   都早于我这一轮）。不是我的现场，我没有替别人收 —— PM 决定。

## 未验证 / 风险

- **未验证：`TEAM_PM_WINDOW` 已经是旧 bug 写下的值、且窗口名恰好与配置一致的项目**（例如配置 `pi`、窗口也叫 `pi`）：
  bootstrap 保持配置不变、doctor 也不报警（两边自洽）。这是任务书范围之外（要求只说「写配置固定 `pm`」+「不符时报警」），
  真要迁移只能 PM 显式决定（改配置或改窗口）。**这是本次修复不留自动迁移的已知边界。**
- **未验证：多候选漂移**（session 里同时有两个窗口跑配置的 PM CLI）。代码会全部列出来，但建议命令只用第一个
  （`${pmwin_drift%% *}`）。现实里这本身是异常现场，日志里看得见两个名字。
- **未验证：非 Linux（`/proc` 不存在）**：漂移判据复用 `team_proc_cwd`（已有 macOS `lsof` 兜底），
  我这台机器上只能验 Linux 路径。
- 夹具计时：真实沙盒 ⑥ 用 0.25s × 80 的有界轮询等 `.rc` 文件，正常 1–3s 内结束；tmux 完全不响应时
  最多等 20s，属可接受的确定性等待（不是 sleep 赌时序）。

## 下一步建议

- PM 复验建议：`team review M11 --strong`（本任务带翻转证据段），并抽查「基础分支 + 四个提交」的 diff；
  骨架分支 = `abedc30`。
- 合并干净性（只读检查，没碰 main）：main 现在在 `5668f85`（`docs/team/BOARD.md` 一行，M11 派单提交），
  我的基点 = `abedc30`，`git merge-tree --write-tree --name-only main HEAD` → `rc=0`、只输出 tree oid、
  没有冲突文件名（BOARD.md 与我的 5 个文件不重叠）→ 可以直接 merge/squash。
- 合并顺序建议：`git merge --squash task/M11-bootstrap-pm-pm-doctor`（4 个提交：test → fix → feat → docs），
  合并后 CHANGELOG/release 由 PM 照常走。
- 若想让「旧 bug 项目」（配置 `pi`、窗口也叫 `pi`）也回到 `pm` 约定：建议下单独立任务（要显式决定迁移方向，
  不该由 bootstrap 猜）；`references/**` 要不要写一句也由 PM 定。
- `BLOCKED:` 无。跨项目依赖：无。
