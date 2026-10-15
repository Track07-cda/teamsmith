# orphan-visibility · design

本文件记录**为什么这么判**。合同文本在 `specs/seat-visibility/spec.md`、`specs/boundary/spec.md` 与
`specs/board-and-status/spec.md` 的 delta 里；这里只写推理、被否掉的备选与已知边界。

## 0. 事故与事实基础

2026-10-15 的一次 OOM 之后，本项目的席位进程全没了，同机其他项目留下一批**孤儿 Pi 进程**：tmux 窗口已死
（`tmux list-panes` 找不到），进程还活着、各自占 0.2–0.6 GB，七个数合计约 4 GB。它们对使用者不可见——窗口
没了，`team status`/`team resume` 也看不到，因为**存活判据是窗口侧的**（`team_agent_alive_in_pane` 要求
「窗口在 + pane 里证明跑着 agent」）。内存却真实被占着，直接加剧下一次 OOM。

本次提案期间的只读盘点（不写盘、不发信号）证实了三件事：

1. 席位进程的环境里带着身份：`TEAM_ROOT`（启动时所在的工作树）、`TEAM_MAIN_ROOT`（属于哪个项目）、
   `TEAM_PROJECT`、`TEAM_SESSION`，还有 tmux 写入的 `TMUX`（`<socket>,<server pid>,<session index>`）
   与 `TMUX_PANE`（如 `%49`）。本机实测 90 个进程带 `TEAM_ROOT`。
2. 「窗口没了」与「没有 pane」是两件事：本机同一时刻既有「`TMUX_PANE` 指向的 pane 不在任何 server 上」
   的进程，也有「根本没有 `TMUX_PANE`」的进程（其中含一个 623 MB 的 tmux server 自己——它当然不是席位）。
3. 「按 `TEAM_ROOT` 存在」不足以当判据：带身份的进程里还有面板（`node panel.js`）、开发服务器、tmux server。
   判据必须是**身份 + 形状**两条。

## 1. 判据：身份从进程自己身上读，形状复用既有解析

**决定**：席位进程 = 进程**自己的**环境带 `TEAM_MAIN_ROOT`/`TEAM_ROOT` **且**命令行命中本项目配置的
agent/PM 可执行文件（`team_agent_bin_path` / `team_pm_bin_path`，即 `TEAM_AGENT_BIN` ＞
`TEAM_AGENT_CMD` 首词 ＞ `TEAM_PI_BIN` ＞ `pi`）。

**为什么**：

- 身份**只能**从进程自己的 `environ` 读：调用者的 `TEAM_*` 是继承值，从哪个目录调用、谁是 PM 都不改变
  「这个进程属于哪个项目」。这与既有的 M40 口径一致（身份 = 运行时目录，不是继承值）。
- 形状复用 `team_agent_bin_path`，所以「普查说它是席位」与「存活判据说它在跑」用的是**同一个**定义；
  各写一份就是下一个假告警的温床（`common.sh` 里那条注释的理由）。
- 形状判据自动排除面板/开发服务器/tmux server：它们的 argv 不命中 agent 可执行文件。

**被否掉的备选**：

- 「凡带 `TEAM_ROOT` 的进程都是席位」——会把 tmux server（本机实测 623 MB，带 `TEAM_ROOT`）与面板进程
  算成席位孤儿。
- 「按 `state/<seat>.env` 记录的 pid」——派单记录里**没有** pid（只有 sid、started、nonce），而且这条
  路看不见别的项目的孤儿，而任务书要的正是本机总量。
- 「按 `ps` 的命令行子串找 `pi`」——裸名字匹配会命中 `panel.js`、门禁夹具、以及任何命令行里提到 `pi` 的
  进程；既有的 `team_proc_cmdline_is_bin` 已经踩过这类坑（P103 的假活）。

## 2. 孤儿 = 没有活着的 pane，**按进程自己的 tmux server 判**

**决定**：`TMUX_PANE` 为空，或它不在**进程自己那个 socket**（`TMUX` 的第一段）的 pane 集合里
（`tmux -S <socket> list-panes -a -F '#{pane_id}'`）。

**为什么不能拿默认 server 的 pane 表比对**：pane id（`%N`）是**每个 tmux server 各自分配**的。本项目
的夹具大量使用私有 socket（`tests/lib/tmux-iso.sh`、`flip-*.sh` 里的 `-L <sock>`），测试机上也常有多个
server；拿默认 server 的表去比对私有 socket 上的席位，会把**活着的**席位判成孤儿——而孤儿读数紧跟着
一个「可复制的清理命令」，假孤儿就是一次错误清理的邀请。

**为什么不能是「不是当前窗口的 pane」**：任务书红侧 ② 点名了这条。席位正常在跑时，它所在的窗口当然
不是普查运行的窗口（PM 窗口）；判据必须问「它的 pane 在不在**这台机器上活着**」，而不是「是不是我」。

**为什么查询不到 server 时判「未判定」而不是「孤儿」**：socket 没了说明整个 server 死了，此时「没有
pane」对**所有**席位都成立——但它们的进程可能马上要退出（SIGHUP 的正常路径），也可能像这次事故一样
活着。判不了就不猜（哲学：假绿比没有更糟）：读数单列「未判定 N 个」，既不点名也不清理。真正的孤儿
是**同一个 server 上别的 pane 还在、只有它这个 pane 没了**这一格。

**已知边界（明说，不当保证）**：如果 tmux 默认 socket 之外的 server 在 OOM 中被杀、而进程活下来，
普查报的是「未判定」。这是刻意的保守方向。

## 3. 任务归属：记录里的任务，并标明来源

**决定**：条目的任务字段取该项目 `state/<seat>.env`（已提交的派单记录）的 `task`，并在读数里**标明**
「记录里的任务」。启动时间取进程自己的 start tick（`/proc/<pid>/stat` 第 22 字段 + `/proc/stat` 的
`btime`），内存取 `/proc/<pid>/status` 的 `VmRSS`。

**为什么标明来源**：记录是**最后一次提交的派单**，进程可能是更早一轮启动的（席位被重派过）。把记录里的
任务当成「它现在在干什么」就是编造。读数里写「记录里的任务」既不隐瞒也不撒谎。

**被否掉的备选**：把 pid 写进派单记录，用记录反查 pid。那会改派单写入面（`assignment_version` 的形状、
CAS 指纹、既有夹具），收益只是省一次 `/proc` 读；而且对**别的项目**的孤儿毫无帮助（我们读不到它们的
记录）。所以不做。

## 4. 只报告；清理是另一条命令，且发信号前复验

**决定**：读命令（`ps`/`status`/`up`）一个信号都不发。清理只有 `team reap`：

- 计划态：`team reap --orphans`（无 `--yes`）→ 打印目标与将发的信号，**不发**，退 0。
- 执行态：`--yes` → 每个目标**发信号前**重新验一遍：仍是本项目席位、仍没有活 pane、**启动时刻与计划时
  一致**（pid 被内核回收 → 启动时刻变了 → 拒绝），然后 `SIGTERM`、有界等待（默认 5s）、仍活着再
  `SIGKILL`。每个信号一行 `state/reap.log`。
- 拒绝集合：别的项目的席位、身份为空的进程、调用者自己及其祖先（`/proc/<pid>/stat` 的 ppid 链）。
- `--yes` 是唯一授权：没有配置键、没有环境变量、没有继承值能把它变成默认开。

**为什么复验**：从普查到发信号之间有 TOCTOU 窗口。一个刚被回收的 pid 可能是别人的进程；一个刚被重派的
席位可能已经有活 pane。既有纪律（`boundary#Signals go to a recorded pid, never to a name or a pattern`）
要的正是「对象是证明过的那个」，所以复验是**判据的一部分**，不是防御性装饰。

**为什么不是 `team resume --adopt-orphans`**：进程的 TUI 已经不在任何 pane 里，没有「收编回窗口」的可
行路径（`respawn-pane` 会杀掉它，等于清理）。一个叫 adopt 的旗标却只能 kill，是误导；命令名就说它做的
事：`reap`。

**为什么不进信号闸门**：`scripts/shim/signal-gate` 有意**不拦** `kill <pid>`（它拦的是按名字/模式选进程的
`pkill`/`killall`），理由写在闸门自己的注释里：`kill $(pgrep -f x)` 与 `kill $(cat job.pid)` 在 argv 上
同形。`team reap` 走的就是「记录过的 pid」这条安全路线，因此静态那一半（`tests/signal-lint.pl`：pid 精确
形态为净）必须保持绿，这是 apply 的验收项之一。

## 5. digest 的提示挂在容量行行尾

**决定**：`team digest` 在 `[1] 容量与存活` 的容量行**行尾**追加提示（总量、本项目份额、可复制命令），
只有合计 ≥ `TEAM_ORPHAN_WARN_MB` 时才有。

**为什么是同一行而不是新行**：`board-and-status#The ledger read path stays inside a git-call budget and its
cache is an equivalence-checked view` 要求缓存开/关两次运行的输出「除实时字段（时间戳、容量）外逐字节
一致」，而闸门（`smoke.sh` 的 M50 组）用 `grep -v 'RAM 可用'` 过滤那一行。把提示挂在那一行行尾，它自动
落在既有的实时字段里，闸门的 digest 归一化一个字都不用改。新开一行则必须在闸门里加滤除，且那行会随
主机状态抖动。

**但 `team status` 的读数不能这么躲**：任务书第 1 条要求 `team status` 打**读数**（pid/RSS/席位/任务/启动
时间），这些无法塞进一行容量行，也塞不进任何既有实时字段。所以本变更**必须**改那条 requirement 的实时
字段枚举（加上「孤儿席位进程普查」），并让闸门按新表过滤。这是本变更唯一一条被改的既有 requirement，
改动只有一处枚举，三条基线场景逐字保留。

## 6. 点名与只计数：账本会发布，别的项目名不许进仓

**决定**：本项目的孤儿逐条点名；别的项目的孤儿与身份为空的同形状进程只进「计数 + 合计内存」，且合计标
`≥`（下限）。

**为什么**：`docs/team/**` 会随公开树发布，且本仓有一条账本禁令（`ledger-ban`）扫别的项目名。读数会被人
粘进报告与决策记录，所以它自己就不能点名别的项目。下限的理由同样是「不许编造」：形状判据认得的是本项目
配置的 Pi/agent 形状，认不出别的项目用的自定义 adapter，所以那个总数是**至少**这么多。

**身份为空那一桶**：任务书的实测里就有「一个身份为空的 0.23 GB」。判据是「没有 `TEAM_MAIN_ROOT`/
`TEAM_ROOT`，但命令行命中 agent 形状，且没有活 pane」。它可能不是任何项目的席位（比如人工起的 Pi），
所以只计数、不点名、不清理。

## 7. 只增不改、有界、只读、可关、不进面板

- **只增不改**：`team ps` 的既有每一行逐字节不变（任务书边界）。实现上读数是**追加**在既有输出之后的
  独立块，复用同一份普查函数，`ps`/`status` 共用（两处输出因此逐字一致）。
- **不进面板数据面**：`team __panel-data` 与面板输出不变。面板按帧预算刷新（2000 ms 帧、1% CPU 的
  计时行），一次全主机 `/proc` 普查（本机实测 159 个 pid、每个要读 environ）会把预算打穿；而且面板的
  数据面有「缓存是视图」的等价性契约，加一个实时主机读数只会让它更难说清。PM 在 `ps`/`status` 里看它。
- **有界与竞态安全**：`/proc` 枚举后条目可能消失、`environ`/`status`/`stat` 可能读不到（本机实测有多个
  `Permission denied` 的进程）→ 一律跳过，绝不让调用命令失败。普查不写任何文件。
- **代价有界**：先用**一次** `ps -eo pid=,args=` 把绝大多数进程筛掉（只对命令行里出现 agent 可执行文件
  basename 的 pid 读 `/proc`），形状与 `team_pm_other_sessions_in_dir` 的既有做法一致（它已经在注释里写明
  为什么：每个 pid 都 fork 一次读 `/proc` 会把一次判定变成几百次 fork）。本机实测 159 个 pid。
- **可关**：`TEAM_ORPHAN_SCAN=0` 不扫、打一行点名的跳过。夹具与慢机器需要它。
- **夹具接缝**：`TEAM_ORPHAN_PROC_ROOT`（默认 `/proc`，`fixture-only:`）让夹具确定性地造「读不到 /
  中途消失 / 空环境 / 缺字段」四种边界；真进程现场（红侧 ①②③）仍走真 `/proc`，两者互为对照。

## 8. 能力落点与任务切分

| 内容 | 落点 | 理由 |
|---|---|---|
| 普查、判据、点名边界、只增/有界/只读、digest 提示 | 新能力 `seat-visibility`（5 ADDED） | 今天没有任何能力覆盖「窗口没了但进程活着」这一格 |
| `team status` 的实时字段表 | `board-and-status`（1 MODIFIED） | 那条缓存等价性 requirement 就住在那里；写别处就是平行规格 |
| `team reap`（破坏性、按 pid、审计、复验） | `boundary`（1 ADDED） | 该能力已经是「信号只发给记录过的 pid」与「按记录 pid 停、并打印停了什么」的家 |

任务切分按 delta：apply-1 = `seat-visibility` + `board-and-status`（普查 → 读数 → digest 提示 → 三个键 →
闸门归一化），apply-2 = `boundary`（`team reap` → 审计 → 帮助清单/页面 → 红侧 ①）。两组 delta 不相交，
满足 dispatch 的 delta 单写者守卫；两者都碰 `common.sh`/`cmd-status.sh`，所以**顺序执行**（apply-2 的复验
要用 apply-1 的普查判据）。

## 9. Non-Goals

- 不自动清理、不定时清理、不「收编」孤儿（见 §4）。
- 不改既有判据的语义（存活/容量/面板/`team bg`）。
- 不为 `state/reap.log` 现在引入轮转（裁定点 6）。
- 不做「按名字/模式找孤儿」——那正是三次信号事故的形状。
- 不追「这个孤儿是哪个 agent 会话」这类**判不准**的归因：进程的 argv 里没有 sid（实测 `pi` 的 argv 就是
  `pi`），只有环境里的 `TEAM_ROOT`；所以席位名来自工作树目录，任务来自记录并标明来源（§3）。
