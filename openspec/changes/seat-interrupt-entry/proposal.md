# seat-interrupt-entry · 给工具加一条「打断席位长回合」的正式入口

## Why

2026-10-15 两次实测（账本 D188）：两个席位各自卡在**一个极长的单回合**里——**18 小时**与 **16 小时**没有提交、也没
有改动工作树里的文件，窗口一直是 `Working`；PM 用 `team say` 发的两条消息（其中一条是已复现的根因）**一条都没
被读到**。机制缺口是死的：投递给席位的消息要**等回合结束**才进它的上下文，而工具里只有 `resume`（给停了的
席位）与 `teardown`——**没有「打断一个正在跑的长回合」**。当天 PM 的处置是手动结束进程再 `team resume`，那是
**绕过 CLI 的动作**，所以记进了账本；账本同时点名了退役条件：哪天有了正式入口（登记的候选名就是
`team interrupt <seat>`），这条手工动作就退役。

## 现状复核（本 worktree 只读实测，数字是读数不是回忆）

1. **入口盘点**：`scripts/team` 的分发里与席位进程有关的只有三条——`reap`（**孤儿**席位的 pid，`boundary`
   已固化的信号纪律）、`teardown`（清窗口/状态/worktree）、`resume`（给**停了**的席位续跑）。命令清单
   `scripts/strings/commands.tsv` 共 **45** 条命令，没有任何一条能结束一个**正在跑**的回合。
2. **「长回合」今天只能从窗口看出来，不能从记录里读出来**：2026-10-15T23:32:39Z 实测 `dev` 的窗口
   （`tmux capture-pane -p -t teamsmith:dev`）显示 `Elapsed 53m 5s` 与 `⠙ Working`，而它**自己那份会话记录**
   （它的派单记录 `sid=` 指向的 `~/.pi/agent/sessions/--…-worktrees-dev--/2026-10-15T03-36-04-356Z_teamsmith-dev-…jsonl`）
   `stat` 出来是 **2112882 字节、mtime 22:39:31Z**——距今 **3188 秒**，再采 20 秒仍是同一字节数。也就是说：
   **回合在跑 ≠ 它在落盘**，而「多久没落盘」是今天就能读出来的一个数。
3. **会话跨进程死亡继续追加，这件事今天已经发生过**：上一条那份会话文件的**创建**时间是 03:36，而 `dev` 的
   派单记录 `state/dev.env` 写的是 `started=2026-10-15T22:38:58Z`、`mode=continued`、同一个 `sid=`——22:38 那次
   派单是在**同一个会话 id 上继续**，文件从启动那一刻的 `sid_bytes=2103032` 长到 2112882。这就是「杀掉进程 →
   `resume` 回到同一会话」这条路线今天已经在跑的机制，不是设想。
4. **要用的机器已经都在**：`team reap` 已经有「按 pid 选对象、发信号前复验（仍属于本项目 + 启动时刻一致）、
   `SIGTERM` → 有界 5 秒 → `SIGKILL`、每个信号一行 `state/reap.log`」；席位身份判据已经在 `common.sh` 的
   `team_orphan_*`（从进程**自己**的 `environ` 读 `TEAM_MAIN_ROOT`/`TEAM_ROOT` + 命令行命中本项目 agent 可执行
   文件）与 `team_pane_agent_pid`（从 pane 读 agent 进程）；投递面有 `team_inbox_append` 与 thread 写入器；
   续跑的会话身份守卫是 `team_guard_resume_session`。本变更**不新造第二套判据**，只把它们接到一个新入口上。
5. **为什么不是「自动判断卡住了」**：`Working` + 长时间无落盘**不等于**卡住——一个正在跑长门禁的席位可以几十分
   钟不写工作树。谁该被打断是 PM 的判断；工具只做两件事：把判据读出来（会话最后落盘时间 + 未提交文件数）、
   把动作做成一条有审计的路。

## What Changes

- **一条新入口**：`team interrupt <seat> --reason <一句话> [--force] [--yes]`——**结束该席位当前的回合**（进程级），
  **保留**磁盘状态（未提交改动、会话文件、派单记录），随后由 `team resume --agent <seat>`（语义不变）**重新进入
  同一会话**。没有 `--yes` 是**计划态**：打印席位、pid、它读到的证据与将发的信号，一个信号都不发、一个字都不写
  （与 `reap` 同一形状：**信号永远不是默认路径**）。
- **对象是证明出来的，不是搜出来的**：pid 只能来自**该席位派单记录里那个窗口**的 pane（前台进程，或那个本项目
  agent 可执行文件的直接子进程），并要满足普查用的**同一套身份判据**（进程自己的 `TEAM_MAIN_ROOT` 属于本项目、
  `TEAM_ROOT` 等于派单记录的工作树、命令行命中本项目 agent 可执行文件）。发信号**前**再用一次（仍是该席位的活
  agent 进程 + 启动时刻与计划时一致）——被内核回收的 pid、又活了回来的 pane 都打不中。另一个项目的席位、
  没有 teamsmith 身份的进程、调用者自己及其祖先：不发，且**不点名**别的项目的项目名/席位名/工作树/pid。
- **拒绝集合各自给出路**：进程不在的席位 → `team resume`；窗口没了而进程还在（孤儿）→ `team reap --orphans`；
  不在名册的名字 → 名册；**缺理由** → 直接拒绝（不写任何东西、不发任何信号）。
- **审计**：每次**授权的**打断恰好一行 `state/interrupt.log`，带时间戳、**谁**（从运行时目录解析出的 actor）、
  哪个席位、pid、理由、**打断前**该会话的最后落盘时间与工作树里未提交文件数、信号与结果；被拒绝的打断**不写**
  审计行。事后可以只凭这一行判断这次打断是否必要。
- **理由一定落到席位会读到的地方**：发信号**之前**把理由写进该席位的**线程**（工厂里的第二条阅读步骤就是它自
  己的 thread）与**收件箱**（同一件事的持久通知行）；理由写不进去 → 拒绝，不发信号。线程条目写明谁、什么时候、
  为什么、以及它**该先做什么**。
- **不许误打断一个还在写盘的席位**：该席位**自己的最新磁盘证据**（它那次会话的会话文件，或工作树里 git 报为
  改动的文件）比**新鲜窗口**（默认 3600 秒）更新时，拒绝，并点名读到的是哪个文件、它多大岁数、窗口是多少；
  `--force` 才越过它，而这条越权会写进那一行审计。`--force` **不能**越过其它任何拒绝（身份/存活/名册/跨项目/
  自身）。
- **做不到的事说清楚**：不改 `resume`/`dispatch`/`reap`/`teardown` 的任何语义；`ps`/`status`/`digest`/面板的
  数据面一行不动；不加自动「卡住」启发式；不碰别的项目的席位。

## Capabilities

### Modified Capabilities

- `boundary`（2 ADDED）：该能力已经是「信号只发给记录过的 pid」「按记录 pid 停、并打印停了什么」「孤儿席位按 pid
  清理 + 审计」的家，这两条落在同一面：
  ① **A running seat's turn is ended only by an audited interrupt aimed at that seat's own process**——入口、计划
  态、对象证明、复验、`SIGTERM`→有界→`SIGKILL`、审计行字段、拒绝集合与各自的路、读命令永不打断；
  ② **An interrupt carries its reason to the seat, and a seat that is writing is not interrupted by accident**——
  理由必填与投递面、新鲜窗口与 `--force`、以及「打断不改工作树：未提交文件逐字节还在、会话文件与它原来的字节
  还在、只写 thread/inbox/`state/interrupt.log` 三个文件」。

**不新开能力**：这不是一个新的「可见性」话题（`seat-visibility` 是读数：普查、点名、只增只读），而是一条**破坏
性动作**；它的许可、对象证明、复验与审计与 `reap` 是同一族，放在同一个能力里才不会再长出第二套「谁能发信号」
的说法。与 `long-job-suspend` 的关系也在 design §1 里写清：**长作业**有账本、有叫醒（那个变更管的），**长回合**
两者都没有，本条是后者的入口，不重复前者的机制。

## Impact

- **代码**：新增 `skills/teamsmith/scripts/lib/cmd-interrupt.sh`（入口/计划态/对象证明/复验/审计/信号/拒绝）；
  `skills/teamsmith/scripts/team` 加一个分发标签；`scripts/strings/commands.tsv` 一行 + `help.en.tsv`/`help.zh.tsv`
  的命令页文案；`references/troubleshooting.md` 一节（席位卡在长回合里怎么办）+ `references/protocol.md` 一段
  （两条信号入口各管什么）。**不改** `cmd-agents.sh`/`cmd-watch.sh`/`cmd-reap.sh`/`common.sh` 的既有语义
  （只用它们的既成函数）。
- **测试**：新增夹具 `skills/teamsmith/tests/interrupt.sh`（按组 + `--flip` 变异臂）：计划态零信号、授权打断 +
  审计逐字段、TOCTOU 两形状、四条拒绝各自的路、缺理由、新鲜证据两形状、`--force` 及「越不过别的拒绝」、
  工作树逐字节幸存、thread/inbox 各一行、路线回到同一个 sid；登记 `tests/section-paths.tsv`
  （+ `section-budgets.tsv`）与 `smoke.sh` 的段；`tests/help-surface.sh` 的命令页探针。
- **兼容性**：`resume`/`dispatch`/`teardown`/`reap` 语义逐条不变；`state/interrupt.log` 是**新文件**（追加形状，
  今天没有读者）；新鲜窗口是**实现接缝** `TEAM_INTERRUPT_FRESH_SEC`（默认 3600 秒，与 `TEAM_REAP_GRACE_SEC`
  同族：**不进** `cmd-config.sh` 的 schema，也不进 `references/config.md`，只在命令页与实现里写明有界默认值），
  因此本变更**不新增契约键**、不动面板数据面与重建产物。
- **apply 的写面**（供 PM 写 `grant:`）：`skills/teamsmith/scripts/lib/cmd-interrupt.sh`（新）、`skills/teamsmith/scripts/team`、
  `skills/teamsmith/scripts/strings/{commands,help.en,help.zh}.tsv`、`skills/teamsmith/tests/interrupt.sh`（新）、
  `skills/teamsmith/tests/{smoke.sh,section-paths.tsv,section-budgets.tsv,help-surface.sh}`、
  `skills/teamsmith/references/{troubleshooting,protocol}.md`，以及本 change 自己的 `openspec/changes/seat-interrupt-entry/**`。
  产品面的既有语义文件（`cmd-agents.sh`/`cmd-watch.sh`/`cmd-reap.sh`/`common.sh`/`cmd-config.sh`/面板）**不在**写面里。
- **排期**：todo。本轮**只写提案**：不派 apply、不勾实现任务、不改产品代码（本分支只新增 `openspec/changes/seat-interrupt-entry/**`）；
  apply、独立 verify、归档各需各自授权。
