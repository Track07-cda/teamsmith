# P162 · 破坏性段开跑前必须证明隔离生效，否则硬停

agent: dev   status: done（待 PM 独立复验）   time: 2026-10-02
branch: `task/P162-apply`（local 模式：分支留在本地工作树，未 push）
change: -   phase: apply   anchor: none (infra) — 门禁自身的隔离前置；只改门禁与夹具
base: `main@10d7ea4e`（本分支已合入）

## 交付物

| 路径 | 内容 |
|---|---|
| `skills/teamsmith/tests/lib/tmux-iso.sh` | 隔离前置库：`tmux_iso_prove`（三条件判定，只读）/ `tmux_iso_require`（硬停）/ `tmux_iso_guard_soft`（收尾用的响亮拒绝）/ `tmux_iso_hard_stop`·`tmux_iso_audit`·`tmux_iso_skip` 三个组件。判定只读环境与文件系统，不认任何 `TEAM_*` 旋钮、不认 `--force` |
| `skills/teamsmith/tests/lib/tmux-iso-probe.sh` | 红侧探针（子进程）：跑「证明 → 才动手」的同一形态，动作用桩（或真命令），供 0h 造已知假隔离形状与影子变异 |
| `skills/teamsmith/tests/smoke.sh` | 本套的 `tmux()` 包装：`kill-server/kill-session/kill-window/kill-pane` 先过前置（不成立 → 硬停 exit 2，段记 SKIP）；非破坏性调用原样透传；`0c` 的 M23 自检升级为前置；`cleanup` 的收尾用软形态；`10c-②`(M25) 与 `31c`(真 m36 server) 各加显式证明；新增 **0h 段**（38 条断言）；`p98_nest_state` 的环境归因多认 P162 的两条环境成因 |
| `skills/teamsmith/tests/lib/tmux-cap.sh`·`pm-box-real.sh`·`flip-m17/m45/m4.3/m6.3/m37/m6.5/m7.2`·`flip-glue.sh`·`death-cause.sh`·`panel-b2/b3/cpu/p21`·`fixtures/p55/flip-p49.sh` | 这些夹具的 kill-server/kill-session/kill-window 动手前先证明私有 socket 生效（收尾路径用软形态，中流重启/重建用硬形态）。`container-tmux.sh` **故意不动**：它的破坏性调用跑在一次性容器里，隔离是构造性的 |
| `skills/teamsmith/tests/section-paths.tsv`·`section-budgets.tsv` | 0h 的选段行 + 预算行（容器实测 1s，band 1.00、budget 60s） |
| `skills/teamsmith/references/troubleshooting.md` | §18.1：前置的三条件、硬停形状、无绕过路径、0h 钉住的可证伪面 |
| `docs/team/reports/P162-dev.md` + `docs/team/reports/P162-dev/**` | 本报告与原始输出（清单见「证据文件」） |

提交（`git log --oneline main..HEAD | tac`）：

```
feat(teamsmith): P162 — the isolation precondition library: prove the private socket before any destructive tmux call
feat(teamsmith): P162 — the gate's destructive tmux calls prove isolation first, and section 0h pins the red sides
fix(teamsmith): P162 — fixtures' destructive tmux calls prove their private socket first
fix(teamsmith): P162 — the observer reports liveness through stdout, so the socket-file condition really fires
test(teamsmith): P162 — §36⑥'s environment attribution learns the P162 hard stop, and its expectations follow
docs(teamsmith): P162 — §18.1 documents the isolation precondition, its hard stop and its falsifiable sides
fix(teamsmith): P162 — the last two unguarded fixture kills (flip-m6.3 mid-flow, the p55 flip fixture)
fix(teamsmith): P162 — death-cause reuses the caller's private socket, so its proof must not demand its own root
test(teamsmith): P162 — delivery report and raw evidence
```

## 根因

2026-10-02 共享 tmux server 一天死四次，每次都和门禁运行重合；而 tmux 审计里**零 kill 类调用** —— 说明动手的是**没有走 shim**的调用。两个已知的「假隔离」机制正好造出这个形状（D83）：

| 形状 | 真 tmux 的实际行为 | 后果 |
|---|---|---|
| `TMUX_TMPDIR=<不存在的目录>` | 静默回退 `/tmp/tmux-<uid>/default` | `tmux kill-server` 打的是**共享** server（#1250，第 6 次死亡） |
| socket 路径 > 107 字节（AF_UNIX `sun_path` 上限） | 私有 server 绑不上 socket | 段里的私有 server 从未存在；后续按同一环境动手就落到默认 socket（P115/P120） |

而门禁自己的 M23 自检（`smoke.sh:837`）只是**断言**：它报一条红，然后段继续跑下去 —— 「先跑再看」正是任务书要消灭的形状。夹具侧也一样：`flip-*`/`panel-*`/`pm-box-real.sh`/`lib/tmux-cap.sh` 都各自 `env -u TMUX … TMUX_TMPDIR=$TMP/tmux tmux kill-server`，谁都没有在动手前证明那条 socket 真的是自己的。

## 修法

### 三条件（`tmux_iso_prove`，只读，不落任何副作用）

1. **目标路径存在且属于本轮**：`TMUX_TMPDIR` 给了就必须是**已存在**的目录（`-e`/`-d`）；期望路径 `$TMUX_TMPDIR/tmux-<uid>/<name>`（`-L` 名非 default 时目录可以是 `/tmp`）长度 ≤ **107** 字节；给了 `--own-root` 时必须在它之下；server 活着时 socket 文件必须 `-S` 在。
2. **实际 server 就是它**：用 tmux **自己**的解析结果比对 —— server 活着读 `display-message -p '#{socket_path}'`；server 不在则读真 tmux 报错文案里它要连的路径（`error connecting to <path> (<errno>)` / `no server running on <path>`）。判的是「kill 会打到哪条路径」，不是 server 活没活 —— 收尾常常发生在最后一个 session 已经没了之后。
3. **与共享默认 socket 不同**：`/tmp/tmux-<uid>/default`（写死 `/tmp`，不被环境改写）；另可给 `--caller-tmpdir`，调用者那份默认 socket 也一起挡。

三条有一条不成立 → **硬停**：一行醒目结论 + 一行审计（段号 / 哪一条不成立 / 实际 socket 路径 / `TMUX_TMPDIR`）+ `SKIP（前置不成立：<哪一条>）` + `exit 2`；破坏性调用**绝不执行**，并保留本轮临时根（审计行在里面）。

### 不许有例外路径

判定只读环境与文件系统：不认 `TEAM_*`（`TEAM_TMUX_ISO_LOG` 只决定审计行落点，不改判定）、不认 `--force`（未知参数按 `bad-option` 硬停）、不认 CI 模式。0h 里两个探针正面钉住。

### 接线

| 位置 | 形态 |
|---|---|
| `smoke.sh` 的 `tmux()` 包装 | 四个破坏性子命令先 `tmux_iso_require`（标签 = 当前段号），再按 M23 形态执行（`env -u TMUX -u TMUX_PANE TMUX_TMPDIR=<本轮私有>`）—— 这也是 lint（M28）认的隔离证据形态。非破坏性调用 `command tmux` 透传，PATH 解析与改动前一致 |
| `0c` M23 自检 | 断言 → **前置**（不成立即硬停，后面的破坏性段一个都不许跑） |
| `cleanup`（EXIT 陷阱） | 软形态：响亮拒绝 + 审计，**不 exit**（收尾里 exit 会吞掉真结论）；`kill-session` 之后 server 可能已经消失，第二道证明仍按「路径」判 |
| `10c-②`(M25 私有 server 收尾)、`31c`(真 m36 server 收尾 ×3) | 各自显式证明（`--tmpdir` 指自己的目录） |
| 夹具（`flip-*`/`panel-*`/`pm-box-real.sh`/`tmux-cap.sh`/`death-cause.sh`/`fixtures/p55/flip-p49.sh`） | 收尾软形态、中流重启/重建硬形态；通过时**静默**，夹具输出不变 |
| `container-tmux.sh` | 不动（容器内隔离是构造性的） |

全量清扫：`tests/**` 里 smoke.sh 之外的破坏性调用**零处未加守卫**；smoke.sh 内所有进程内 kill 都被包装拦下，唯一直呼 `"$REAL_TMUX"` 的是两处已守卫的收尾；M36 的 shim 判定探针（`m36_bound/probe/flog/mut_probe`）走 `TEAM_TMUX_REAL=<桩>`，根本不碰 server。

## 翻转证据（red → green）

### ① 两个已知假隔离形状 → 硬停 + 点名 + 审计 + 没动手（0h 红侧①②）

```
✗ 隔离前置不成立：TMUX_TMPDIR=/…/p162-nope/sock 指向不存在的目录（真 tmux 会静默回退默认 socket）
   段 P162 探针 · 用途 破坏性动作（探针） · 实际 socket /tmp/tmux-1000/default（期望 /…/p162-nope/sock/tmux-1000/default）· 审计 …/tmux-iso-guard.log
   硬停（exit 2）：这条破坏性 tmux 调用绝不执行
SKIP（前置不成立：TMUX_TMPDIR=… 指向不存在的目录（真 tmux 会静默回退默认 socket）） P162 探针
```
审计行（逐字）：`… · 段=P162 探针 · 用途=破坏性动作（探针） · 不成立=tmpdir-missing · 期望 socket=… · 实际 socket=/tmp/tmux-1000/default · TMUX_TMPDIR=…`。第二条（超深路径）点名「路径超 AF_UNIX 上限」、审计记 `不成立=sock-path-too-long`。两条的桩文件都不存在 → **破坏性动作没执行**。

### ② 破坏实现 → 守卫必须失败（守卫有牙）

| 变异 | 0h 结果 |
|---|---|
| **A**：`tmux_iso_prove` 判据恒真（影子变异，进真实现） | `--select 0h` **rc=2**、**21 条红**（红侧①②、审计、包装探针、无绕过、端到端全红） |
| **B**：拿掉 `tmux()` 包装里的前置调用 | `--select 0h` **rc=1**、**5 条红**（包装硬停 4 条 + 静态钉子「包装体里看得见 tmux_iso_require」） |
| 恢复（`cp` 还原两个文件后复核） | `--select 0h` **rc=0**、0 条红 |

样本（A 的前 4 条）：
```
✗ P162 红侧①：TMUX_TMPDIR 指向不存在的目录 → 硬停（exit 2）（期望 [2]，实际 [0]）
✗ P162 红侧①：一行醒目结论（…/p162-out 中找不到 [隔离前置不成立]）
✗ P162 审计格式：带段号（…/p162-guard.log 中找不到 [段=P162 探针]）
✗ P162 红侧①：破坏性动作没执行（…/p162-stub 不该存在）
```
样本（B 的前 3 条）：
```
✗ P162 本套入口：TMUX_TMPDIR 坏了 → tmux() 包装硬停（exit 2）（期望 [2]，实际 [1]）
✗ P162 本套入口：一行醒目结论（… 中找不到 [隔离前置不成立]）
✗ P162 静态钉子：tmux() 包装体里看得见 tmux_iso_require
```

第三个变异（**C**：拿掉 `0c` 里那条显式前置）**没有**让 0h 变红 —— 因为同一段里包装的前置先响（同一个成因、同一段号、同一条消息），深 TMPDIR 下 0c 的那条前置是第一道闸门但不是唯一一道。这条不作为翻转证据，如实记录。

### ③ 端到端：深 TMPDIR 的嵌套 smoke 在 0c 段硬停（exit 2、该段记 SKIP）

```
$ TMPDIR=/tmp/p162dbg3/aaaa…/gggggggg TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 0b   # 深根 76 字节
✗ 隔离前置不成立：socket 路径 122 字节 > AF_UNIX 上限 107（私有 server 绑不上）
   段 0c · 静态检查（函数结尾的 set -e 陷阱） · 用途 M23 隔离自检：本轮私有 socket 必须已生效 · 实际 socket …/teamsmith-smoke.6dr9xt/tmux/tmux-1000/default（期望 同左）· 审计 …/tmux-iso-guard.log
SKIP（前置不成立：socket 路径 122 字节 > AF_UNIX 上限 107（私有 server 绑不上）） 0c · 静态检查（函数结尾的 set -e 陷阱）
✗ 隔离前置不成立（拒绝执行）：…（段 cleanup；…）   ×2（kill-session / kill-server 各一次）
#3 0c · 静态检查（函数结尾的 set -e 陷阱） · 用时 0s · ✓5 ✗0 SKIP1 · ticks 6
rc=2
```
注意 `SKIP1`：该段在账本里记成 SKIP（不是假绿），而且 `0b` 之后一段都没跑。

### ④ 反向：隔离正常时照常跑（结论与今天一致）

0h 的第三腿起真私有 server 再真 `kill-server`（在 `$TMP` 的私有目录里），证明通过 → 动作执行、server 真的被收掉；`tmux-cap.sh` 的能力探测与 `10c-②`/`31c` 的私有 server 收尾照旧；全量门禁里这些断言全绿。

### ⑤ 无绕过

```
TEAM_ALLOW_DESTRUCTIVE_TMUX=1 TEAM_SMOKE_NO_PRIVATE_TMUX=1 TEAM_SMOKE_CI=1 TEAM_TMP_KEEP=1 … --tmpdir <不存在的目录> → exit 2，点名同一条判据
--tmpdir <正常目录> --force → exit 2，审计记 不成立=bad-option
```

### ⑥ 全量门禁自己抓到的一处真红（这一轮的价值证明）

第一次全量（容器，非 FAST）跑出 **✓4179 ✗1**，唯一那条红是 §52：

```
✗ 52 真遗体那一半有失败（rc=2）
      ✗ 隔离前置不成立：目标 socket 不在本轮自有目录 /tmp/teamsmith-death-cause.C4lLMQ 之下（/tmp/teamsmith-smoke.kcIw7K/tmux/tmux-1000/default）
```
`death-cause.sh` 的 `td_live()` 会**复用已存在的 `TMUX_TMPDIR`**（smoke 传进来的私有目录），而我给它加的守卫要求 socket 在自己的临时根之下 → 守卫正确地**拒绝**了那条 kill（没伤到任何东西），但那一段判红。修法：那条守卫只证「tmux 解析出的就是这条私有路径、且不是共享默认 socket」（两处 `--own-root` 去掉）。修后 `--select 52`（**不带 FAST**，跑到真遗体那一半）：`✓3 ✗0`（修前 `✓2 ✗1`）。

## 门禁结果

### 全量（容器，最终树 `23feab97`，非 FAST）

```
$ distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp \
    -v "$PWD":/work -v "<主仓库>/.git":"<主仓库>/.git":ro -w /work localhost/teamsmith-gate:local \
    bash -c '… openspec validate --all --strict; bash skills/teamsmith/tests/smoke.sh'
=== tree: 23feab97 ===
openspec rc=0
账本自查： 119 段收口 · 增量 ✓4180 ✗0 SKIP3 ｜ 结果行 ✓4180 ✗0 —— 一致
== 结果 ==  ✓ 4180  ✗ 0
smoke 全绿
full rc=0
```

关键段（全量那半）：`0c ✓7 ✗0` · `0d ✓9 ✗0` · **`0h ✓38 ✗0（1s）`** · `10c ✓11 ✗0` · **`31c ✓269 ✗0`**（真私有 server 生死 + 加的三处前置）· `36 ✓109 ✗0` · **`52 ✓3 ✗0`**（修前 ✓2 ✗1）。

### FAST 全量（容器，最终树）

```
=== FAST 全量 ===
== 结果 ==  ✓ 3463  ✗ 0
smoke 全绿
fast rc=0
```
（FAST 跳过 36 个真进程段落，其中包含 `10c-②`/`31c·真私有 server 生死`/`52·p113-live` —— 这三段由上面的非 FAST 全量覆盖 ✓）

### 相关段（自己跑的）

| 命令 | 结果 |
|---|---|
| `smoke.sh --select 0h`（FAST） | ✓59 ✗0（前导 0/0b/0c/0d + 0h 38 条） |
| `smoke.sh --select 36`（FAST，最终树） | ✓130 ✗0（原始输出：`36-select-and-flips.log`） |
| `smoke.sh --select 52`（**非** FAST，真遗体那一半） | ✓24 ✗0 |
| `smoke.sh --select 0b`（深 TMPDIR） | rc=2、0c 记 `SKIP1`（前置硬停） |
| `section-select.sh --check` | `== 选段自检 ==  ok 7  bad 0` |
| `section-guard.sh --budget-check` | `ok: 预算表覆盖 120/120 个 section` |
| `perl tmux-lint.pl --quiet` | rc=0（改动了 15 个夹具后仍干净） |
| 12 形状探针（`lib/tmux-iso-probe.sh`，见证据文件） | 11/12 判定符合预期（含「正常隔离 → 真 kill 私有 server」「`-L` 私有名」「`--force` → bad-option」）；第 10 例（`PATH` 里没有 tmux）是驱动起不来的产物，见「没跑的」 |
| 影子/破坏变异（A/B/C + 恢复，最终树复跑） | A：21 红；B：5 红；C：0 红（如实记录）；恢复后 rc=0、0 红 |

## 没跑的（点名）

- **宿主上的全量门禁**：P162 期间门禁一律进容器（用户纪律）。`host_s` 预算列因此留 `-`。
- 容器里跑全量时**额外挂载了主仓库的 `.git`（只读）**，让 worktree 的 `.git` 文件（gitdir 指向挂载外）在容器里可解析 —— 否则 `0d`（冲突标记守卫）找不到工作树、§36 的嵌套跑连带假红。这是容器的挂载形状，不是产品改动；完整命令在证据文件里。
- `container-tmux.sh` 未改（容器内隔离是构造性的）。
- 12 形状探针的第 10 例（`PATH` 里没有 tmux）在容器里 rc=127 —— 那是**驱动**起不来（连 bash/`cat` 都不在 PATH 里），不是守卫的判定；守卫的 `no-tmux` 分支只由代码路径覆盖，没有单独夹具。

## 已知边界与取舍

- **判定「server 不在」时读的是 tmux 的报错文案**（`error connecting to …` / `no server running on …`）。tmux 换文案会让这一支落到 `resolution-unobservable` → 硬停（保守方向：宁可停，不猜）。
- 收尾软形态会多打一行红字（`✗ 隔离前置不成立（拒绝执行）`）。这是「响亮拒绝」的代价；`p98_nest_state` 的环境归因已经认这条形状（环境成因不判产品红，代码缺陷照旧红），并新增两条合成日志断言钉住这个口径。
- `death-cause.sh` 复用调用者的私有 `TMUX_TMPDIR` 是**有意**的（smoke 传进来的那一个），所以它的守卫不带 `--own-root` —— 判据是「私有、且不是共享默认 socket」。同理，`flip-m17/m45`、`panel-*` 用 `-L <私有名>` 形状，守卫只按名字算路径。
- `107` 字节是 Linux `sun_path` 的上限（P115 口径：107 OK / 108 ENAMETOOLONG），可用 `TMUX_ISO_AF_UNIX_MAX` 覆盖（判定参数，不是绕过开关）。
- 0h 段在容器里 1s，预算 60s（`×4` + floor）；它自己不依赖机器负载。

## 问题（写给 PM）

- §36⑥ 的环境归因口径被我扩了两条（P162 的环境成因），并把原来 `私有 socket 没生效` 的期望改成 `AF_UNIX 上限`（那条断言现在看到的是更早、更准的硬停消息）。请复验时重点看这一处。
- 容器里跑全量需要额外挂 `.git`（见上）；PM 复验时若不加这个挂载，`0d` 与 §36 的红是挂载形状造成的，不是本分支的回归。
- 0h 是**新段**，`section-paths.tsv` 里给了 `--select 0h` 的行；`section-needs-audit.sh`（全键逐键审计）我没有整跑（它不在默认门禁里），如果 PM 的复验流程要它，我这边可以补。

## 证据文件

`docs/team/reports/P162-dev/`：

| 文件 | 内容 |
|---|---|
| `probe-12-shapes.log` | 前置库的 12 形状探针（`tmux-iso-probe.sh`）原始输出 |
| `36-select-and-flips.log` | `--select 36` 绿 + 三个变异（A/B/C）+ 恢复复核的原始输出 |
| `deep-nested-0c-hardstop.log` | 深 TMPDIR 嵌套 smoke 的 0c 硬停原始输出 |
| `final-gates.log` | 最终树上的 `openspec validate` + FAST 全量 + 全量（原始输出） |
| `full-gate-run1-death-cause-red.log` | 第一次全量的唯一红（§52 death-cause）+ 修后复核 |
