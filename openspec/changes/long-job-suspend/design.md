# long-job-suspend · 设计

## Context

动机与范围见 proposal 与 D125。以下是本轮读取的基线事实（均为当前磁盘状态，不是待实现能力）：

- `scripts/lib/cmd-agents.sh`（约 136 行）的后台车道段：「**Long jobs (a gate, a build)**: start them with
  `team_bg_run` … **Harvest every job before your turn ends** -- an unharvested job wakes you once when it
  finishes, and that costs a turn.」——职责式措辞，且把叫醒写成损失。该段只在内置 Pi 或自定义模板带
  `{bg_ext}` 时注入（M27 的适配器感知）。
- 同一提示词的「Never stop mid-task」段只承认两种结束状态（交付 / 硬阻塞）；续跑行
  （约 185 行）只说 `git status` / `git log`，不提后台作业。
- `extension/team-bg.ts`：`team_bg_run` 的 description 与 promptGuidelines（约 259–265 行）同样是
  「harvest before you end your turn」口径；起作业回执文本（约 313 行）以「Harvest it with
  `team_bg_wait <id>`」收尾。完成叫醒机制本身已经是「作业结束、agent 空闲、合并成一条 followUp、
  triggerTurn」（`finishJob` → `scheduleFlush`/`flushPending`），已收割的作业静默 ——
  「作业结束会自动叫醒」是既有事实，本设计不改它。
- 账本现状：`state/bg.log` 只有 `wake count=…`、`settled-with-unharvested=…`、`spawn-error …`
  与 CLI 侧的 `stop …` 四类行；**起**与**收**都不记。PM 2026-10-10 想从会话日志估算
  「起了就等」的规模，arg 记录不可靠，得不出可信数字（任务书现场证据）。
- `templates/pm-prompt.md.tmpl`（78–79 行）已是正确口径：「门禁不能卡在回合里：`team_bg_run` 起、
  让回合结束、叫醒时 `team_bg_wait` 收割」。`SKILL.md` 的快照行（约 20 行）同样是
  「`team_bg_run` → 回合结束 → 被叫醒一次 → `team_bg_wait`」。正确措辞存在，只是没进工人那段。
- turn-end 通知（`extension/team-notify.ts`）：`completed`（stopReason ∈ {stop, length}）→ `[auto]`，
  否则 `[auto·interrupted]`；工作树脏加 `⚠ 未提交 N 个文件 · ` 前缀。没有「挂起」概念 ——
  故意的挂起与真中断共用同一副面孔。
- 作业身份记录（P159）：`state/bg/<id>.job`（id/pid/pgid/start 指纹/cwd/log/cmd），由扩展在返回
  id 之前写；`team bg list` 用 `(pid, start-time)` 活体验证判 holds/gone。它的落盘规则（M30 修正后，
  team-bg.ts 的 `findRoot` + `stateDir`）是：显式 `TEAM_STATE_DIR` 压过一切；否则「cwd 的 worktree
  带 `.pi/team/config.sh` → 它自己；`TEAM_ROOT`（带 config）；最近的带 config 的祖先；git 主工作树（最后兜底）」。
  **本仓的实际落点要自己看**：`.pi/` 被 gitignore，linked worktree 里没有 `config.sh`，所以前三支
  都不命中 —— worker 会话的作业记录/log/账本今天全部落在**主工作树**的 `.pi/team/state/bg/`
  （现场：`p228-r6-*.job` 的 `cwd=…/.worktrees/dev`；主 state 下 263 份 `.job` 记录中多份的 cwd 是
  `.worktrees/<席位>`）。而 smoke 的 S11 夹具把 `config.sh` 提交进夹具仓库，worktree 带 config，
  那一支落 worktree 侧 —— 两种形状都存在。team-notify 的 `findRoot` 走 `--git-common-dir`，落点本来
  就是主工作树；**在本仓今天的形状里两侧巧合一致，在 worktree 带 config 的形状里会分叉**。
  因此挂起判定必须按**车道自己的规则**解析记录目录，不能拿 notify 自己的 root 顶替。
- 唤醒不可达的形态：作业是 detached 的，会话进程死了作业照跑，日志与记录留盘；但作业表是
  每会话的（`session_start` 清空），新会话的 `team_bg_wait` 对旧 id 报 unknown。巡检既有待办已含
  「记录在案的任务未完成但窗口不在的 agent」，席位死亡也有敲门（notify-and-inbox 的 seat-death
  requirement）——兜底链路存在，缺的是续跑后「先查盘上证据」的引导。
- 同批在途：`task-model-routing` 的 S1 所有权列表含 `scripts/lib/cmd-agents.sh`（其 design 的切片表），
  S3 拥有 `templates/**` 与 `references/**`。本 change 的 apply 与它们写同一批文件，必须串行
  （见「排期与交接」）。

## Goals / Non-Goals

**Goals:** 让「起完就结束回合」成为合同而非建议；挂起成为第三种合法结束状态且对 PM 不误报；
「起了就等」成为可数的账本事实；叫醒不可达时有既有机制兜底且续跑者知道先查盘。可观察边界只在
三份 delta（dispatch / background-jobs / notify-and-inbox）中定义。

**Non-Goals:** 不改叫醒的传输机制（sendMessage/followUp/triggerTurn 原样）；不改工具名与既有工具行为
语义（`team_bg_wait` 的默认超时、返回形状不变）；不给非 Pi 适配器另造车道；不改派单/身份/模型路由
相关代码；不给 `team close` 增加「席位还有在跑作业」的拦截（作业本就 detached，记录留盘，停作业是
`team bg stop` 的既有职责 —— 见 Risks）。

## Decisions

### 1. 一处口径，逐面落地 —— 每个面的准确措辞

新口径（单一合同，各面逐字收敛到它）：

> 长作业用 `team_bg_run` 起，起完**默认结束回合**；作业完成时你被叫醒一次（多条合并成一条），
> 那时再用 `team_bg_wait <id>` 收割（退出码 + 日志尾段内联返回）。**原地等是例外**，只在三条同时
> 成立时用：作业预期在**内联等待预算（约 2 分钟）**内完成、其结果卡住你的下一步、且这段时间里
> 没有别的任务工作可以推进。任何面都不得再出现「回合结束前必须收割」的措辞，也不得把
> 「未收割被叫醒」写成惩罚或损失。

落点逐面（现状 → 新口径）：

| 面 | 现状 | 改动 |
|---|---|---|
| `cmd-agents.sh` bg 段 | 「Harvest every job before your turn ends … costs a turn」 | 整段重写为上面的口径（默认结束回合 + 例外三条 + 例外预算数字） |
| `cmd-agents.sh` 「Never stop mid-task」段 | 两种结束状态 | 三种：交付 / 硬阻塞 / **挂起等后台作业**（要点名在等的 job id；不是交付也不是阻塞，不写最终结论、不报 BLOCKED） |
| `cmd-agents.sh` 续跑行 | 只提 git | 加：上一会话的叫醒随进程死了，先用 `state/bg.log` 与 `team bg list` 核对在跑/已完成未收割的作业再继续 |
| `team-bg.ts` `team_bg_run` description + promptGuidelines + 起作业回执 | 「Harvest it with team_bg_wait before you end your turn」 | 「End your turn after starting; the completion wake-up is the normal harvest point」+ 例外三条 |
| `team-bg.ts` `team_bg_wait` description | 只说收割语义 | 加：回合内等待是有界例外（预算 + 卡住下一步 + 无别的可推进）；正常收割点是完成叫醒 |
| `templates/AGENTS.section.md.tmpl` 纪律条 | 「either deliver … or be hard-blocked」 | 同一份三态合同的一句话版 |
| `references/protocol.md` 通知段 | 无挂起概念 | 加 `[auto·suspended]` 与三态的交叉引用 |
| `references/workflows.md` §E2 规则 1 | 「Harvest before the turn ends」 | 改为结束回合默认；规则 2 的账本清单补 `start`/`wait` 行 |
| `templates/pm-prompt.md.tmpl`、§E2 流程段、`SKILL.md` | 已是正确口径 | **不动**（PM 模板是参照措辞；一致性场景会盯住它不被弱化） |

### 2. 例外判据为什么长这样（防「随手等」回潮）

任务书把例外写成「作业很短、**或**其结果卡住下一步且确实没有别的可做」；本设计把那个「或」收成
**三条同时成立**。理由：「作业很短」在没有绝对数字时是不可核对的弹性词，而「结果卡住我」单独存在时
正好就是「这步很重要所以等」的通行证 —— 用户立项正是冲着这种等待。三条同时成立缺一不可：
**预算**（可数的绝对时长，约 2 分钟）、**阻塞**（结果卡住下一步）、
**独占**（没有别的可推进）。只有「阻塞 + 独占」没有预算，会被解释成「我这步很重要所以等」；
只有预算没有另两条，会鼓励短作业也走内联等（短作业的等待同样是回合被占）。预算给绝对数字而不是
「短作业」这种弹性词，是为了让账本可审计：apply 后每条 `wait … waited_s=<n>` 都能对预算核，
超预算的内联等待在 `state/bg.log` 里一眼可数（PM 抽查或 grep 即可）。工具行为不设硬顶
（见 Risks 的否决项）。

### 3. 第三种结束状态在协议层的表达

- 工人简报「Never stop mid-task」段：列举三种合法结束状态，挂起的定义 = 「仍有本会话起的作业在跑，
  且不依赖其结果的工作都已完成」；挂起时回合最后一行必须点名 job id（形如
  `waiting on: <id>[, <id>…]`）；挂起不写报告终稿、不推分支、不敲 BLOCKED。
- `templates/AGENTS.section.md.tmpl` 的纪律条同步成同一句话版本。
- `references/protocol.md` 的通知小节登记 `[auto·suspended]` 标签与 `awaiting=` 字段。
- 这些面的一致性由 dispatch delta 的「一份合同跨面」场景钉住（可证伪：任一面缺第三态即红）。

### 4. PM 侧如何区分挂起与中断（notify-and-inbox MODIFIED）

turn-end 通知在 settle 时计算**在跑作业集合**，规则与 `team bg list` 同源：从**车道写记录的那个目录**
读 `state/bg/*.job`，按车道的解析规则定位（显式 `TEAM_STATE_DIR` 优先；否则「cwd 的 worktree 带
`.pi/team/config.sh` → 它自己；`TEAM_ROOT`；最近的带 config 的祖先；git 主工作树」），逐条做
`(pid, start-time)` 活体验证，只有验证通过的才算在跑。**不许拿 notify 自己的 root 顶替车道目录**：
notify 的 `findRoot` 走 `--git-common-dir`，落点本来就是主工作树；本仓 worktree 不带 config
（`.pi/` 被 gitignore），车道今天也落主工作树，于是一致 —— 而在 S11 那种 worktree 自带 config 的形状里
车道落 worktree 侧，notify 的 root 就会读错。然后：

- 回合完成 + 在跑集合非空 → 标签 `[auto·suspended]`，带 `awaiting=<id>[,<id>…]`；**省略** ⚠ 未提交
  告警前缀（挂起不是交付主张，告警框只会误导；`uncommitted=<n>` 字段保留，事实不藏）。
- 回合未完成 + 在跑集合非空 → 保持 `[auto·interrupted]`（诚实），同样带 `awaiting=` ——
  真中断与它的在跑作业都可见，PM 能据此决定 `team bg stop`。
- 其他情形逐字节不变（`[auto]` + 脏树告警照旧）。

竞态自洽：settle 判定与作业完成之间差一毫秒的，挂起行之后立刻跟一条完成叫醒 —— 只会稍显过时，
绝不静默错（叫醒把真相带来）。去重键已含标签与摘要，新形状不与旧形状互吞。
否决的替代：① team-bg 写「挂起标记文件」给 notify 读 —— 多一个生命周期会腐烂的状态文件
（进程被杀即留 staleness），而活体验证是自愈证据；② 读 bg.log 最后一行 —— 两个扩展的 settle
回调顺序是加载顺序（notify 在 bg 前），读到的是上一回合的行，天然错一位；③ 直接用 notify 自己 root 下的
`state/bg/` —— 在本仓今天的形状里「碰巧对」（两边都落主工作树），在 worktree 自带 config 的形状里
读错目录；把「碰巧」写成规则正是要避免的。

### 5. 叫醒不可达的兜底（不新增巡检条款，写明理由）

- 会话活着：叫醒是进程内的，随作业完成必然到达；传输机制不在范围。
- 会话死了：作业 detached 照跑，记录/日志/账本留盘。**既有链路已经够**——巡检待办含
  「记录在案的任务未完成而窗口不在的 agent」（watchdog#Pending work is defined…），席位死亡另有
  敲门（notify-and-inbox#A seat-death knock…）；PM 被叫醒后 `team resume`，续跑提示词（决策 1 的
  续跑行）让 worker 先查 `state/bg.log` 与 `team bg list`：旧会话的叫醒随进程死了，结果在盘上。
  因此**不给 watchdog 加新待办类**：挂起席位的任务本来就未完成，现有条款已覆盖，再加一条
  「带在跑作业」的细分只会让 pending 定义多长一个分支而唤不醒更多东西。tasks 里配一条夹具证明
  「挂起后死亡的席位」确实命中现有待办条款。
- 被叫醒时：先收割核对（`team_bg_wait` / 读日志）再推进 —— 写进工人简报的三态段。

### 6. 可数性：账本新增两类行（不新增文件）

`state/bg.log`（车道自己的 state 目录 —— 与 `.job` 记录同一个目录，按决策 4 的同一规则定位；
ISO 时间戳由既有 appendLedger 统一打）：

- `start id=<id> pid=<pid>` —— `team_bg_run` 里、返回 job id 之前（与写 `.job` 记录同一点位）。
- `wait id=<id> outcome=<harvested|running|interrupted> waited_s=<秒>` —— 每次 `team_bg_wait`
  返回时；`waited_s` 只量这一次调用自己等的时间（已完成作业的收割 ≈ 0）。

既有 `wake count=…` / `settled-with-unharvested=…` / `spawn-error …` / `stop …` 行形状不变。
可回答的问题（只凭账本）：「起了就原地等」= `start` 后紧跟 `wait outcome=harvested` 且
`waited_s` ≈ 作业全程、中间无 `settled-with-unharvested`；「挂起」= `start` 与 `wait` 之间有
点名该 id 的 `settled-with-unharvested`；超预算内联等待 = `waited_s` 对照预算。
否决的替代：① 从 Pi 会话日志/工具调用参数反推 —— PM 已实测不可靠（任务书现场证据）；
② 另起指标文件 —— bg.log 就是车道自己的账本，一个账本一把 grep，不长第二张脸。

### 7. 落点与任务书头字段（偏离说明）

任务书 `deltas:` 头写 `agent-adapters, dispatch`（PM 的预期：工具面/提示词合同法在 agent-adapters）。
实际落点三处，偏离与理由：

- **agent-adapters 不动**：它的四条 requirement 管的是「启动模板合同 / 首词解析 / PM 适配器 /
  冻结缝」，从不涉及工具文本；内置 Pi 启动命令（`-e` 集合与顺序）本 change 逐字节不变。
  把车道语义塞进它会让这个 capability 失去单一目的。
- **新能力 `background-jobs`**：车道的会话侧（工具面合同、叫醒纪律、账本事件、重启留证）今天
  **没有**规格家 —— `boundary` 只覆盖 CLI 的 `team bg list/stop` 一侧。本 change 改的正是车道
  自己的合同，给它一个家比借住在适配器里干净。
- **notify-and-inbox MODIFIED**：挂起可见性的实现位在 team-notify.ts，就是
  「A turn-end notification…」这条既有 requirement 的行为。
- **dispatch ADDED**：工人简报的内容合同（三态 + 车道教学 + 续跑查盘）今天完全没有规格钉着
  （门禁零断言），本 change 首次钉上。

### 8. 排期与交接（写进 tasks 的硬约束）

`task-model-routing` 的 S1（私有实现中）所有权列了 `scripts/lib/cmd-agents.sh`，S3 拥有
`templates/**` 与 `references/**`。本 change 的 apply 因此切成两刀：

- **A 刀（无碰撞）**：`extension/team-bg.ts`、`extension/team-notify.ts` 及它们的**独立新测试入口**
  （不动 smoke.sh 本体）—— 可随时开始。
- **B 刀（需释放）**：`cmd-agents.sh`、`templates/AGENTS.section.md.tmpl`、`references/protocol.md`、
  `references/workflows.md`、smoke.sh 的 §13/§13c 断言登记 —— 必须等 S1/S3 释放对应文件后由 PM
  串行派单，PM 在 apply 任务书里写明输入 tip 与释放记录。

两刀可以分两次 apply 任务，delta 文件归同一 change（dispatch 守卫按 delta 文件判碰撞，
本 change 三个 delta 各只有一份）。若 PM 判断 routing 先行归档，则本 change 的 MODIFIED 基线
需按归档后文本刷新（notify-and-inbox 不受 routing 影响；dispatch 的本 change 是 ADDED，与
routing 的七个 MODIFIED 无交集）。

## Risks / Trade-offs

- [模型对「例外三条」的自由裁量] → 预算给绝对数字 + 账本 `waited_s` 可审计；超预算等待是有痕的，
  PM 抽查即可。不靠提示词自律alone。
- [不设工具硬顶：把 `team_bg_wait` 默认超时砍到预算值会改变工具行为语义，可能困住「收割已完成作业
  之外的合法长等」] → 本 change 只改措辞与账本，不改行为；若审计显示措辞管不住，再立项评估硬顶。
- [`[auto·suspended]` 新标签的旧读者] → 标签是开放族（`[auto]`/`[manual]` 都是子串匹配，无机内
  解析器依赖标签闭集 —— 已核 smoke/panel/scripts）；收件箱行只增字段不删字段。
- [挂起判定读车道的记录目录引入一次 settle 时延] → 记录数有界（每作业一文件），活体检查是几次
  /proc 读，远低于 notify 已有的 git 调用簇；失败一律不当在跑（fail-closed 偏向不打挂起标签，
  退回现状形状，绝不假造挂起）。
- [两刀 apply 之间口径半新不旧] → A 刀落地后工具文本已是新口径、提示词还是旧口径，窗口期内
  工具教「结束回合」而简报教「收割后再结束」—— 方向相同（都教人用后台车道）、程度不同，
  可在 B 刀完成前接受；PM 在派单顺序上尽量缩短窗口。
- [`.job` 记录永续累积被 notify 逐条验活] → 每条记录一次 /proc 读；正常项目每席位作业数在十位级。
  清理策略（如归档已完成记录）不在本 change，留作后续候选。

## Migration Plan

1. 本提案由 PM 审 + 独立评审；通过前不派 apply。
2. apply 按决策 8 分刀：A 刀（扩展 + 独立夹具入口）可立即；B 刀（提示词/模板/文档/门禁登记）
   待 `task-model-routing` S1/S3 释放对应文件，PM 在任务书里写输入 tip。
3. 无数据迁移：账本新行是追加形状；`[auto·suspended]` 是新标签不是改名；无配置键新增。
   已挂起的作业无状态要迁（新口径只管措辞、标签与账本）。
4. 独立 verify 由未写过本 change apply 的席位在独立 clone 上跑：三个 delta 的全部场景 +
   红侧（措辞回退即红、删 `start` 行即红、身份不验即红、读错目录即红、缺第三态即红）。
5. PM 合并、用户确认后归档；共享技能软链接的影响授权不在本 change 内（沿用 D107 的既有程序）。
