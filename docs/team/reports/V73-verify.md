# V73 · P334（门禁的私有 tmux 锚点必须随本轮消失）的独立验收 — 复验报告（dev2）

time: 2026-10-20T09:48Z（实际收尾时间；各段原始时刻见证据）
受检：分支 `task/P334-anchor-lifetime` 的候选 `ca9f4929`（实现 `185b81fc`），作者报告 `docs/team/reports/P334-dev3.md`
形态：只读代码 + 自己造现场；没改实现、没合并、没 push

## 结论（先看这里）

**PASS。** 要回答的两件事都成立，下面每条都点名了它改变的那个判断：

1. **不可捕获的终止之后，锚点真的自己走掉**：外部 `kill -9` 之后 **2.0s**（两轮独立复现，上限 30s）`ps` 里
   不再有 `teamsmith-smoke-anchor-<套件 pid>`，锚点的 tmux server 也一起没了。同一实验在**旧树**
   （`1c7615a7`，`sleep 100000`）上 **30.1s 仍在、server 还活着** —— 这条修复是**承重的**：消失是新的
   pane 命令带来的，不是这台机器上别的什么让 server 自己散掉。
2. **这个判据不误伤别人的东西**：调用者默认 server 的 server pid 前后同一个，session 清单与 pane 清单
   **逐行相同**（before/after sha256 相同）；我在默认 server 和**另一个私有 socket** 上各放了一个同形
   诱饵锚点 `teamsmith-smoke-anchor-424242/424243`，两轮 kill 实验 + 两轮正常退出（其中一轮会真的执行
   cleanup 的 `kill-server`）之后都原样活着。
3. **形状判据只收自己那一个**：真实形状 `.t-<uid>.<6 位>` 命中（KEEP=1 打出保留行、KEEP=0 目录被删），
   8 个不该收的形状一个都不命中、目录都还在；**旧树对照**里恰恰相反（`.t-` 真实形状**不**命中、
   `.tm-*` **命中**）—— 红绿两侧都点名，所以这不是「怎么都绿」。
4. **正常路径没被改坏**：不带 `--keep` 的正常退出 rc=0、`✓ 23 ✗ 0`，`ps` 里没有锚点，socket 目录被收掉
   （`ls` → No such file）；`--select 2`（FAST）rc=0 `✓ 61 ✗ 0`，其中
   `✓ 探测守卫：不认别的项目的 tmux session`（这条只在 `$TMUX` 有值时运行）= 锚点身份在这一轮里有效。

**一处措辞更正（任务书的假设不准确）**：任务书要求确认 `kill -9` 之后留下的是「**空**目录」。实测留下的是
**目录 + 里面那个死 socket 文件** `tmux-1000/default`（`srw-rw----`、0 字节）——没有活的 server
（`tmux -S … list-sessions` → `no server running`，rc=1；`ps` 里没有对应 server）。作者报告写的「里面只剩死
socket 文件」才是准确的。判据的实质（**不是还有一个活 server**）成立，结论不受影响；如果照任务书的字面
「空目录」验收，这一条会被误判成不满足。

## 测试状态

所有命令都在 `/var/tmp/v73-dev2-…` 的**独立 worktree** 里跑；运行现场全部在自己的目录
（`TMPDIR=/var/tmp/v73-dev2-…/<轮>/tmp`、私有锁 `…/<轮>/lock/teamsmith-smoke.lock`），不抢机器级门禁锁。

| 命令 | rc | 结果 / 证据 |
|---|---|---|
| `bash -n skills/teamsmith/tests/smoke.sh`（受检树） | 0 | 无输出 |
| `bash skills/teamsmith/tests/section-select.sh --check` | 0 | `== 选段自检 ==  ok 9  bad 0  SKIP 1` |
| `"$HOME/.bun/bin/openspec" validate --all --strict` | 0 | `Totals: 21 passed, 0 failed (21 items)` |
| ledger-ban 固定验收行（见下） | 0 | `scope=published files=1890 hits=0 names=ok user=resolved` |
| `git diff --check`（受检树） | 0 | 无输出 |
| `git show --check 185b81fc` | 0 | 无空白错误 |
| `smoke.sh --select 0c`（FAST，不带 `--keep`） | 0 | `✓ 23 ✗ 0`；`ps` 无锚点；socket 目录已被收掉 |
| `smoke.sh --select 0c --keep` + 外部 `kill -9`（轮 1） | 启动器 137 | 锚点 **2.0s** 消失（上限 30s） |
| 同上（轮 2，独立重跑） | 启动器 137 | 锚点 **2.0s** 消失 |
| 同上（**旧树** `1c7615a7`，红腿） | 启动器 137 | 30.1s 后锚点**仍在**（`ppid=1`，`sleep 100000`） |
| `smoke.sh --select 0c`（FAST，带两个诱饵锚点） | 0 | `✓ 23 ✗ 0`；两个诱饵都活着；调用者 pane sha256 不变 |
| `smoke.sh --select 2`（FAST） | 0 | `✓ 61 ✗ 0`；`✓ 探测守卫：不认别的项目的 tmux session` |

`openspec` 的裸名字在这台机器的 shell 里**不在 PATH**（`command -v openspec` 空）；用的是 bun 全局那份
（`$HOME/.bun/bin/openspec 1.8.0`），与作者报告同一口径。

**不是整套门禁**：选段只跑了前导 + 0c（另一轮 2），选段自己打印的点名行是「未跑 131 个键」。凡是这次没跑到
的段，本报告都不替它下结论。

## 受检与实验形态（不是照抄作者的实验）

- 受检树：`ca9f4929`，在 `/var/tmp/v73-dev2-…/cand` 的独立 git worktree（detached，`git status` 0 行）。
  对照树：`1c7615a7`（`185b81fc` 的父提交，即改动前），同样独立 worktree。两个 worktree 在实验收尾后已
  `git worktree remove`（不给共享 `.git` 留注册项）；实验脚本只吃「树路径」这一个参数，任何 `ca9f4929` /
  `1c7615a7` 的检出都能用同一批脚本原样复跑，每轮的 `summary.txt` / `run.log` 留在下面那个目录里。
- 每轮开跑前先 `ps` 确认**没有别人的门禁在跑**（每轮输出 `<empty>`），再建现场。
- 与作者实验的差别（刻意）：① 用 `setsid --fork` 把运行**交出去**，于是杀它的进程（实验脚本）既不是它的
  父进程也不是任何祖先 —— `kill -9` 是**外部**终止，收尸靠 init 而不是靠杀它的进程 `wait`；
  ② 诱饵锚点用了**两个**（调用者默认 server + 我自己另开的私有 socket），不是同形目录；
  ③ 调用者默认 server 的 pane 清单 before/after 逐行 sha256；
  ④ 补了一条作者没做的**红腿**（旧树）与双向形状判据。
- 运行从**调用者的 tmux 会话内部**发起（`TMUX=/tmp/tmux-1000/default,2767298,0`，即本席位所在的
  `teamsmith` 会话），与生产形态一致；门禁自己仍走私有 `TMUX_TMPDIR`。
- 实验脚本与原始日志留在 `/var/tmp/v73-dev2-1020094437-3011167/`（`exp-kill.sh` / `exp-normal.sh` /
  `exp-normal2.sh` / `exp-shape.sh` + 每轮 `summary.txt`、`run.log`），复验期间保留，可整目录删除。

## 证据

### 1. 反向（核心）：外部 `kill -9` → 锚点 ≤30s 消失

**轮 1**（受检树 `ca9f4929`，`--select 0c --keep`，FAST，`TMPDIR=/var/tmp/v73-dev2-…/r1/tmp`）：

```
== 别人的门禁进程（应为空）：<empty>
== 调用者默认 server pid=2767298（TMUX=/tmp/tmux-1000/default,2767298,0）
== 套件进程 pid=3109579（父进程 pid=3106053；杀它的进程是本实验脚本 pid=3105775，两者无亲缘）
== 锚点 teamsmith-smoke-anchor-3109579 的 tmux server pid=3110376
== ps before kill（2026-10-20T09:45:49Z）：
   3106053       1 Tue Oct 20 09:45:47 2026 bash skills/teamsmith/tests/smoke.sh --select 0c --keep
   3109579 3106053 Tue Oct 20 09:45:49 2026 bash /var/tmp/v73-dev2-…/r1/tmp/teamsmith-select.<ns>.3106053.sh
   3110376       1 Tue Oct 20 09:45:49 2026 tmux new-session -d -s teamsmith-smoke-anchor-3109579 -n anchor while kill -0 3109579 2>/dev/null; do sleep 2; done
== 发 kill -9 3109579（2026-10-20T09:45:49Z）
== 杀后 2.0s：锚点在 ps 里 已消失
== ps after kill（2026-10-20T09:45:51Z）：（空）
== 锚点 server pid=3110376 还活着吗：不在
== 直接问那条 socket：no server running on /var/tmp/v73-dev2-…/r1/tmp/.t-1000.UklcWm/tmux-1000/default
   list-sessions rc=1（非 0 = 没有活的 server）
== 启动器（pid=3106053）还活着吗：已退出
```

**轮 2**（同一实验重跑一遍，独立 pid）：

```
== 套件进程 pid=3128895（父进程 pid=3127246；杀它的进程是本实验脚本 pid=3127057，两者无亲缘）
== 锚点 teamsmith-smoke-anchor-3128895 的 tmux server pid=3129687
   3127246       1 Tue Oct 20 09:45:59 2026 bash skills/teamsmith/tests/smoke.sh --select 0c --keep
   3128895 3127246 Tue Oct 20 09:46:01 2026 bash /var/tmp/v73-dev2-…/r2/tmp/teamsmith-select.<ns>.3127246.sh
   3129687       1 Tue Oct 20 09:46:01 2026 tmux new-session -d -s teamsmith-smoke-anchor-3128895 -n anchor while kill -0 3128895 2>/dev/null; do sleep 2; done
== 发 kill -9 3128895（2026-10-20T09:46:01Z）
== 杀后 2.0s：锚点在 ps 里 已消失
== 锚点 server pid=3129687 还活着吗：不在
== 直接问那条 socket：no server running on /var/tmp/v73-dev2-…/r2/tmp/.t-1000.dM8S3k/tmux-1000/default
   list-sessions rc=1
```

2.0s = pane 里 `sleep 2` 的轮询粒度（作者测到 1s，是同一条 2s 轮询的采样相位差，不是两套行为）。

**红腿（旧树 `1c7615a7`，同一个实验、同一种杀法）**：证明这条修复承重。

```
== 发 kill -9 3199429（2026-10-20T09:46:50Z）
== 杀后 30.1s：锚点在 ps 里 仍然活着（>30s）
   3200675       1 Tue Oct 20 09:46:50 2026 tmux new-session -d -s teamsmith-smoke-anchor-3199429 -n anchor sleep 100000
== 锚点 server pid=3200675 还活着吗：活着
== 直接问那条 socket：teamsmith-smoke-anchor-3199429: 1 windows (created Tue Oct 20 09:46:50 2026)
   list-sessions rc=0（= 还有活的 server）
```

红腿现场按显式 socket 路径收掉（`tmux -S <该轮 socket> kill-server` → rc=0 → `ps` 空、`list-sessions`
变 `no server running`），没有碰任何别人的东西。

### 2. 不误伤（同一轮实验里取，不是另做一次）

```
== 调用者默认 server pid（after）=2767298（before=2767298 → 同一个）
== 调用者 pane 清单 sha256（before）：4259db06187a41b00b1456c5f3f65f5938b7d87f713a4cadebc0de4497406d98
== 调用者 pane 清单 sha256（after） ：4259db06187a41b00b1456c5f3f65f5938b7d87f713a4cadebc0de4497406d98
== session 清单 diff（before→after）：无差异
== pane 清单 diff（before→after）：无差异
== 诱饵锚点 teamsmith-smoke-anchor-424242：server_pid=2767298 现在 活着；pane_pid=3067840 现在 活着
```

（调用者默认 server 上另外三个项目的 session 名按账本禁令隐去；pane 清单的 sha256 就是「一个 pane 都没变」的证据。）

**cleanup 的 `kill-server` 也没打偏**（这一条只有正常退出才会真执行）：一轮**不带 `--keep`** 的正常运行，
事先在**另一个私有 socket**（`/var/tmp/v73-dev2-…/norm2/decoy-sock`）和调用者默认 server 上各放一个同形诱饵：

```
== smoke rc=0（不带 --keep）
== 结果行：== 选段结果 ==  ✓ 23 ✗ 0
== 本轮 socket 目录还在吗：已收掉（正常）
== 判词 ①：本轮锚点不许留下（ps 里应只剩两个诱饵）
   3279528       1 /usr/bin/tmux new-session -d -s teamsmith-smoke-anchor-424242 -n anchor sleep 100000
== 判词 ②：调用者默认 server 的 session 清单 无差异；pane 清单 无差异
== 判词 ③：诱饵 A（别的私有 socket）
   server pid=3279528 活着；pane pid=3279539 活着
   teamsmith-smoke-anchor-424242 pid=3279528
== 判词 ④：诱饵 B（调用者默认 server）
   server pid=2767298 活着；pane pid=3279745 活着
```

（ps 里只出现诱饵 A 是正常的：诱饵 B 的 session 跑在**已经存在**的默认 server 里，那个 server 的 argv 是它第一
个 session 的命令；诱饵 B 是否活着由 `tmux list-sessions` 与 pane pid 两条证据给，不靠 ps 里的名字。）

### 3. 形状判据：只收自己那一个（红绿两侧）

做法：把受检树 `cleanup()` 里那段 `case` **逐字节取出**（`sed -n '1364,1371p'`，md5
`fa1fcef1cbb82c655c06eb2816313e5d`）在本地跑，不重写、不改通配。判据用 `KEEP=1` 的打印行当放大器：只有
`case` 命中才会打「保留」行 —— 于是「目录活着」不会被误读成「匹配了」。

**受检树（`ca9f4929`）**：

```
   |     case "$(basename "$SMOKE_TMUX_TMPDIR")" in
   |       .t-"$(id -u)".[A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9])
   |         if [ "${KEEP:-0}" = "1" ] || [ "${TEAM_TMP_KEEP:-0}" = "1" ]; then
   |           printf '  \033[2m·\033[0m 私有 socket 目录（保留）：%s\n' "$SMOKE_TMUX_TMPDIR"
   |         else
   |           rm -rf -- "$SMOKE_TMUX_TMPDIR" 2>/dev/null || true
   |         fi ;;
   |     esac
✓ real-keep · basename=.t-1000.abcdef · KEEP=1 · case 判定=match（期望 match）· 目录在  → 打出保留行
✓ real-del  · basename=.t-1000.abcdef · KEEP=0 · case 判定=match（期望 match）· 目录没了
✓ tmux            · basename=tmux              · KEEP=1 · nomatch · 目录在
✓ short           · basename=.t-1000.short      · KEEP=1 · nomatch · 目录在
✓ long            · basename=.t-1000.abcdefg    · KEEP=1 · nomatch · 目录在
✓ other-uid       · basename=.t-1001.abcdef     · KEEP=1 · nomatch · 目录在
✓ old-prefix      · basename=.tm-1000.abcdef    · KEEP=1 · nomatch · 目录在
✓ underscore      · basename=.t-1000.abcde_     · KEEP=1 · nomatch · 目录在
✓ dots            · basename=.t-1000.abcd.f     · KEEP=1 · nomatch · 目录在
✓ empty-tail      · basename=.t-1000.           · KEEP=1 · nomatch · 目录在
✓ upper-keep      · basename=.t-1000.ABCDEF     · KEEP=1 · match   · 目录在  → 打出保留行
✓ upper-del       · basename=.t-1000.ABCDEF     · KEEP=0 · match   · 目录没了
== 结论：PASS
```

**旧树（`1c7615a7`，`.tm-*` 前缀）同一组形状**：

```
✗ real-keep  · basename=.t-1000.abcdef  · KEEP=1 · case 判定=nomatch（期望 match）· 目录在
✗ real-del   · basename=.t-1000.abcdef  · KEEP=0 · case 判定=nomatch（期望 match）· 目录在
✗ old-prefix · basename=.tm-1000.abcdef · KEEP=1 · case 判定=match（期望 nomatch）· 目录在  → 打出保留行
✗ upper-keep / upper-del · .t-1000.ABCDEF · nomatch
== 结论：FAIL
```

两侧合起来说的是同一件事：旧判据既**漏掉**真实形状（每跑一轮漏一个目录），又**认**`.tm-*` 这个已经不存在
的形状；新判据收窄到 uid + 恰好 6 位，且不认 `tmux`/`.tm-*`/长度不对/uuid 不对的目录。**收窄没有变成通配**。

### 4. 正常路径（不带 `--keep`）：锚点与 socket 目录都不留

```
== smoke rc=0
== socket dir from log: /var/tmp/v73-dev2-…/norm/tmp/.t-1000.Pv2ri5
== ps after (anchors, must be empty):（空）
== ls of socket dir (must not exist):
ls: cannot access '/var/tmp/v73-dev2-…/norm/tmp/.t-1000.Pv2ri5': No such file or directory
== ls of tmp base (.t-* dirs):（无）
== 0c 私有 socket 目录在临时根之外（/var/tmp/v73-dev2-…/norm/tmp/.t-1000.Pv2ri5）——不随临时根变长
== 选段结果 ==  ✓ 23 ✗ 0
```

`--select 2`（FAST，含依赖 `$TMUX` 的那条断言）：`rc=0`，`== 选段结果 ==  ✓ 61 ✗ 0`，
`✓ 探测守卫：不认别的项目的 tmux session`，运行后 `ps` 里没有锚点、`.t-*` 目录一个都没有。
（这条断言在没有 `$TMUX` 时会打印跳过、不会打 ✓ —— 所以它是「锚点身份在这一轮里真生效」的证据，不是形式上的绿。）

### 5. `kill -0` 的僵尸形态：判断（不是实验，也不写成「已覆盖」）

`kill -0` 对一个**未被回收**的僵尸仍然返回真，所以「套件进程变成僵尸且父进程永不 `wait`」会让锚点一直轮询下去。
本仓的终止形态**不会**产生这个形状：

- **超时预算**：`team review` 的门禁一律是 `timeout --verbose --signal=TERM --kill-after=60 <预算>`
  （`scripts/lib/cmd-review.sh:1055`）。`timeout` 自己是等它的父进程：TERM 那一支跑得到套件的 EXIT trap（收尾
  走 `kill-server`，根本不用轮询）；KILL 那一支由 `timeout` 立刻 `wait` 收尸。
- **长作业车道**：`team_bg_run` 是 Pi 进程 `spawn('bash',['-c',…],{detached:true})` 并监听 `exit`
  （`extension/team-bg.ts:309/324`）—— Node 的 SIGCHLD 处理会回收它；就算 Pi 先退出，作业被 reparent 给 init，
  由 init 收尸。
- **套件自己的段挂住上限**：`section-guard` 杀的是**子进程**（`wait "$child"` 也在同一处），套件本体继续活到
  自己的收尾，不产生「父进程活着却永不 wait」。

也就是说：套件一死，它的父进程总在有限时间内 `wait`（或者父进程先走、由 init 收），僵尸窗口是毫秒级。
**这条边界我没有构造反例去证明它被覆盖**，只是判断在真实终止形态下不会发生。

（顺带一条同族的、同一条谓词上的边界，未验：`kill -0` 只看 pid、不看启动时间。`/proc/sys/kernel/pid_max =
4194304`，而轮询是 2s 一次，要在一次轮询间隔里把整个 pid 空间转一圈才会撞上复用的 pid —— 量级上可忽略，但
它是「`kill -0` 当活着的判据」这个机制的固有缺口，不是这次改动引入的。）

## 没做的 / 边界

- **没跑整套门禁**（任务书明确不要），也没跑容器门禁；选段只覆盖前导 + 0c / 2。结论只覆盖锚点寿命与 socket
  目录清理这两条代码路径。
- **僵尸形态只判断、没造实验**（见上），不声称已覆盖。
- **`kill -9` 之后 socket 目录仍留下**（目录 + 死 socket 文件），这是作者报告已写明的边界，我复核为真；
  不在本任务写集内（目录回收在 `cleanup()` 里，不可捕获的终止跑不到它）。
- **盘上历史的残留目录没清**（作者报的 1200 多个）：可能压着别人的在飞运行，不属于本任务的写集。
- 本报告没改代码；受检树与对照树都是 `/var/tmp` 下的独立 worktree（detached），收尾时已 `git worktree remove`，
  不碰主检出、不碰别人的分支。

## 交付物

- 本报告：`docs/team/reports/V73-verify.md`（分支 `task/V73-anchor-lifetime-verify`，local 模式不 push）
- 实验脚本与原始现场（保留供复验，可整目录删）：`/var/tmp/v73-dev2-1020094437-3011167/`
  - `exp-kill.sh`（反向腿：两轮 + 红腿，现场逐轮在 `r1/`、`r2/`、`r0/`）
  - `exp-normal.sh` / `exp-normal2.sh`（正常路径；后者带两个诱饵锚点）
  - `exp-shape.sh`（形状判据，红绿两侧都用它；取段行号与 md5 写在它的输出里）
