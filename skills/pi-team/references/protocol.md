# 协议：为什么这样组织一支 Pi Agent 团队

这份文档是 `AGENTS.md` 团队协议段落的「理由版」。规则本身很短，理由是让未来的你和 agent
不再把规则当成官僚流程而绕过。

---

## 1. 角色：PM 不是「更聪明的 agent」，而是唯一有权合并的角色

| | PM（orchestrator） | worker agent |
|---|---|---|
| 上下文 | 长驻、跨任务，持有路线图与决策历史 | 每任务一段，聚焦实现 |
| 输出 | 任务书、决策日志、复验记录、合并 | 代码、测试、报告、PR/MR |
| 权限 | 保护分支、forge 写操作、仓库设置 | 自己的任务分支 |

把「写代码」和「判定代码合格」拆给不同会话，是为了制造**独立复验**：agent 的报告是**主张**，
PM 在独立 worktree 上跑出来的门禁结果是**证据**。

> CEP 的真实教训：某次报告声称 28/28 测试通过，PM 复跑时 4 个 spec 全挂（原因是
> `verbatimModuleSyntax` 下用值导入导入了纯类型）。结论：报告 ≠ 证据，复验必须制度化。

## 2. 证据模型（三层，逐层可信度上升）

1. **主张**：agent 在报告里写的结论（最低可信）。
2. **可复核产物**：commit、测试文件、日志文件、diff。
3. **独立复验**：PM 在**另一个 checkout** 上跑同一命令得到的结果（最高可信）。

任何「通过/完成」都必须落到第 2、3 层。任务书里的验收命令 + PM 的 `team review` 就是这条链路的实现。

## 3. 隔离：worktree + 分支 + 长期 cwd

- **一 agent 一 worktree**（长期），每个任务在其内新建分支。
- 为什么长期：Pi 的 session 是按 **cwd** 归属的。worktree 路径一变，旧会话就找不回来（CEP 踩过）。
- 为什么不用「一任务一 worktree」：会话会碎，追问与断点续跑都更难；长期 worktree 让 agent 保持记忆。
- 主工作树（main）只属于 PM：合并、复验、写文档都在这里，避免与 agent 抢工作区。

## 4. 唤醒回路：异步工作的 agent 必须能主动叫醒 PM

PM 不能靠轮询（浪费上下文、延迟高），也不该等用户转达。机制（`extension/team-notify.ts`）：

```
agent 回合结束（Pi 的 agent_settled：不会再自动继续的那个点）
   ├─ 追加 <root>/<docs>/inbox/<agent>.md      ← 持久，PM 随时可读
   └─ tmux send-keys -t <session>:<pm-window>  ← 作为用户消息提交给 PM 会话，把它唤醒
```

守卫与限制：
- 只在 cwd 位于 `<worktrees>/` 之下时触发；窗口名等于 PM 窗口名时跳过（防自触发循环）。
- **linked worktree 里 Pi 不会自动发现项目本地 `.pi/extensions/`**，所以 `team dispatch` 必须用
  `-e <skill>/extension/team-notify.ts` 显式加载（CEP 已实测）。
- 通知文本会进入 PM 的输入行；如果用户此刻正在打字，可能与用户输入拼接（已知副作用）。
- 收件箱是临时状态（gitignore），持久记录仍是报告 + 复验 + 决策日志。
- 同一简报在 `TEAM_NOTIFY_DEDUP_SEC` 秒内只发一次：Pi 可能在一次工作里连续 settle 多次。
- 主动通知（阻塞、发现别人的 bug）用 `team notify <agent> "<一句话>"`，比自动通知更早到达。

## 5. 任务书：写给「没有上下文的弱模型」

默认开发模型是便宜快速的模型（如 `deepseek/deepseek-flash`）。它**不会主动纠正模糊需求**，
所以任务书必须自包含：

- 背景：为什么做、相关文档在哪（不要贴大段代码）。
- 交付物：逐项写清文件路径 + 关键签名/行为。
- 边界：明确「不要做」什么（比「要做什么」更能防止跑偏）。
- 验收：**可复制的命令**，以及报告要求。
- 报告格式固定（交付物/证据/偏离/下一步），便于 PM 机器式阅读。

## 6. 模型策略：便宜模型干活，不同族模型做对抗验证

| 用途 | 选择原则 |
|---|---|
| 实现/测试/文档 | 便宜、无并发限制的模型；任务书写好就够用 |
| 独立验证/对抗分析 | 换一个模型族（避免同源盲区），如 grok 系 |
| 高强度评审/难点 | 订阅额度紧张 → 用 `TEAM_MODEL_LIMITS` 限并发，一次只跑一个 |
| 长上下文难题 | 慢且并发受限，PM 点名才用 |

`team dispatch` 会在派单前检查 `TEAM_MODEL_LIMITS` 与容量：规则（来自 CEP 的两次 OOM 事故，其中一次是 RAM + zram 同时见底）：

| 线 | 默认 | 语义 |
|---|---|---|
| `TEAM_MIN_AVAIL_MB` | 1024 | **硬线**：`MemAvailable` 低于它就拒绝派单（CEP 那台机器设 4096） |
| `TEAM_MIN_FREE_SWAP_MB` | 1024 | **硬线**：**磁盘 swap** 空闲低于它拒绝派单（**不计 zram**） |
| `TEAM_MIN_TOTAL_MB` | 512 | 硬线：`MemAvailable + 磁盘 swap 空闲` |
| `TEAM_WARN_AVAIL_MB` | 4096 | 只警告：RAM 偏紧，允许卡顿 |
| `TEAM_ZRAM_WARN_PCT` | 85 | 只警告：zram 占用过高（zram 的页存在 RAM 里，是卡顿来源不是安全网） |

为什么把 zram 单独看：`/dev/zram0` 的“可用空间”其实是 RAM 里被压缩的页，一满就基本常满；
把它算进并发额度会系统性高估余量，OOM 时 RAM 与 zram 会一起见底。

## 7. 安全红线（不可协商）

- token 只在 wrapper 内部注入（`team gh` / `team gl` / `team pr`），永不回显、永不落进项目文件或日志。
- agent 禁止：push 保护分支、force push、merge、rebase/删除他人分支、改仓库设置。
- agent 禁止阅读凭据/账户文件（如 `~/.pi/agent/auth.json`）。
- 任何改变共享/远端状态的操作都要 `--yes`（用户显式授权）。skill 不替用户做主。

## 8. 定时巡检：不许“监视一切”，只负责叫醒

watchdog 不是保活心跳，而是一个**节拍器**：定时问一句“现在有没有活儿要 PM 处理”。

- 默认每 15 分钟（`TEAM_WATCH_INTERVAL=900`，建议 300~3600）算一次待办：未读通知 / 待复验报告 /
  看板 todo·wip / blocked / 有任务但停了的 agent。
- **有待办** → 叫醒 PM（在跑就发一句提醒；不在跑就用 `pi -c` 拉起，开场提示词 `@state/pm-prompt.md`）；
  **没待办** → 不叫醒、不启动 —— 不要求 PM 一直运行，静默也是一种正确状态。
- PM 可主动停工：`team standby on --reason "…"`（无事可做/需人工介入），之后不再被叫醒，
  待办积压仍记日志；人处理完 `team standby off`。
- 同一批待办按 `TEAM_WATCH_NUDGE_GAP` 限制重复提醒频率；PM 正在忙时可直接忽略提醒。
- 与即时通知的分工：agent 回合结束的通知是**即时**的（notify 扩展：写 inbox + 敲 PM 窗口）；
  watchdog 的提醒是**定时兜底**：只要那批待办还是未读/未处理，下一轮（或待办变化时）会再提一次。
- 边界：不管 tmux 布局（`TEAM_WATCH_REBUILD_TMUX=0`，丢了只告警）、不管 agent（PM 的活）、
  不管模型额度、不自动合并。防失控：自动拉起配额 1 小时 5 次 + watchdog 自身 pid 锁。

为什么把边界画这么窄：一个“什么都管”的守护进程会同时操纵 tmux 布局、agent 生命周期、模型额度，
出事时无法判断是谁改坏了状态；而且“保活”越多，就越容易把本应人工介入的事默默掩盖。

## 8b. 分支模型：一任务一分支（默认）

- `TEAM_BRANCH_MODE=task`（默认）：`dispatch` 在 agent 的长期 worktree 里从保护分支切出
  `task/<ID>-<slug>`；`review/merge/close` 的单位都是这个任务分支 → **复验范围 = 一个任务的 diff**、
  回滚粒度 = 一个任务、PR 描述 = 任务书引用。任务 `close` 后 worktree 退回 `detached@保护分支`，下一个任务干净开始。
- `TEAM_BRANCH_MODE=agent`：一 agent 一长期分支 `agent/<name>`（适合长线重构、或一个 agent 只做一件事的团队）。
- worktree 脏时拒绝切分支（否则会把上一个任务的改动混进新任务）；这条是硬规则，不是提醒。

## 8c. 看门狗的服务范围：只服务当前 tmux session

- 看门狗（`watchdog` 窗口里的 `team monitor`）只回答本 session 的问题：谁在跑、在做什么任务、有什么待办、容量如何；
  **不去翻别的 agent 的会话内容**（那是 PM 用 `inbox`/报告/`digest` 该看的）。
- 会话活动流是 opt-in：`team monitor --activity`（且只列本 session 里活着的窗口）。
  默认关闭的原因很实际：6 个 agent ≈ 每次渲染读 ~9MB JSONL（实测 7MB→67MB RSS、3s 一刷），噪音还盖住真正要看的状态。
- 面板刷新默认 5s，巡检节拍仍是 `TEAM_WATCH_INTERVAL`（默认 900s）。
- **什么叫"有待办"**：未读通知 / 待复验报告 / `blocked` 行 / 停了的 agent（还有任务没交活）。
  看板的 `todo/wip` **默认不算**——backlog 常年存在，每 15 分钟敲一次纯属噪音；
  想连 backlog 一起提醒就设 `TEAM_WATCH_PENDING_BOARD=1`（面板与 digest 里始终能看到它们）。

## 8d. 看板与报告的解析要容忍人的手工改动

CEP 实测踩过的三处，现在都有明确的宽容规则：

- **BOARD 列数**：按**表头名字**定位 `ID/任务/Agent/分支/依赖/状态`，允许手工插列（例如加 `Issue` 列）；
  `board ls` 会提示"非标准列布局"但照常工作；`team board set` 只改状态列，不动你加的那列；
  新建行按现有列数对齐（未知列留空）。以前按固定列号解析，加列后会读出 `—` 当标题。
- **待复验的启发式**：`reports/*.md` 只有同时满足「文件名前缀是任务 ID」+「标题是 `# <ID> · …`」+
  「该 ID 在 BOARD 里（或有任务书）」才算待复验；PM 自己的里程碑/结项报告（`P2-closure.md` 等）
  会被 `digest` 归到"忽略的非任务报告"里——不静默丢，也不会一直催你复验。
- **merge 冲突**：失败时直接列出未合并文件（`UU/AA/DD/AU/UA/DU/UD`），并提示 `--no-renames`
  （add/add 常常是 git 的 rename 检测把 `reports/<ID>-x.md` 与 `reviews/<ID>.md` 配成了一对）。
  不再只丢一句"冲突/失败"让人手工重跑。

## 8e. BOARD 的状态只在「真的进了保护分支」之后才写 done

CEP 踩过：冲突失败路径上 BOARD 已经被标 `done`，而代码没进 `main`（PR 还开着）——状态与事实相反，
是比失败本身更危险的事。现在的顺序与收口：

1. 校验分支存在（`--branch` 拼错不会被误报成"冲突"）；
2. `merge --squash` → `commit` → **`push`（若 `--push`/`--pr`）** 全部成功；
3. 才 `board set <ID> done`。

任何一步失败（冲突 / commit 失败 / push 失败）：`merge --abort` 收尾 + **把 BOARD 还原成合并前的状态**
（通常 `review`，空则 `review`）+ 打印可复制粘贴的恢复步骤。给 `--pr N` 会自动带上 `--push`
（否则远端保护分支没更新，forge 侧永远合不动）。

lockfile 类冲突（`pnpm-lock.yaml` 等）有一条命令的重试路径：

```bash
team merge T1.2 --no-renames --prefer-theirs pnpm-lock.yaml   # 冲突时这些路径取分支侧，然后继续
```

（`--no-renames` 关掉 rename 误配对；`--prefer-theirs` 也可用配置默认给 `TEAM_MERGE_PREFER_THEIRS`。）

## 8f. 模板渲染与派单的坑（erp 实测）

- **渲染不能经过 sed**：替换串里的 `&` 是"命中文本"，`TEAM_GATES="pnpm test && pnpm lint"`
  会被写成 `pnpm test {{GATES}}{{GATES}} pnpm lint`。现在 `team_render` 用 bash 参数展开，
  并且显式关掉 bash 5.2+ 的 `patsub_replacement`（它同样把替换串里的 `&` 当命中文本）。
  `init` 还会把含 `$ \` \ "` 的门禁值转义后写入 config，保证 source 回来与入参一致（不会被执行）。
- **派单写绝对路径**：窗口 shell 的 PATH/rc 可能还没就绪，直接 exec `pi` 会 `command not found`
  （erp 复现 2 次）。现在派单前解析 `pi` 的绝对路径、写进窗口命令，并在派单前校验存在性
  （找不到就直接报错，不会等到窗口里才发现）。
- **GitLab API 的头/体必须匹配**：`--data-urlencode` 是表单体，就必须配
  `Content-Type: application/x-www-form-urlencoded`；配成 `application/json` 会被 GitLab 拒
  （`{"error":"Invalid JSON format"}`，PR/MR 开不出来）。JSON 体（`--data/--data-binary`）仍走 `application/json`。

## 8g. 跨项目：谈事可以，指挥不行

- 项目之间**正常交流是允许的**：接口怎么接、建议与依据、问题报告与复现、约联调窗口。
  **不允许**：指挥别的 PM/agent 做事、替对方决策、冒充人类下指令、改对方仓库或状态。
- 机制上做到了"想指挥也指挥不了"：`team meeting` 的 `intent` 白名单里**没有 command/order**；
  `--as-user` 只有人类终端（+`TEAM_MEETING_ALLOW_USER_ID=1`）能用，agent 进程写会被拒；
  共识必须**双方各自 agree**；会议只写共享区，对对方仓库零写权限。
- 分工：**worker 不参会**（跨项目沟通只走 PM）；worker 需要外部配合时在报告里写 `BLOCKED:`。
- 共享区在两个项目之外（`~/.pi/team/meetings/<slug>/`），transcript 是唯一真相；
  敲门（提醒对方 PM 窗口）默认关闭，只在 `--knock` + `TEAM_MEETING_KNOCK=1` + 对方登记了 session 时发生。
- 边界守卫：跨 session 打字默认**一律拒绝**，唯一例外是已登记会议的敲门 —— 这条挡住了"顺手插手别的项目"。

## 8h. git 与 forge 归 PM：skill 不执行、也不包装

- skill **不执行** git 写操作（建/切分支、squash、push）与 forge 写操作（开/合 PR、留言、关 PR）；
  **也不打印"食谱"**——那属于过度包装已有工具。PM 直接用 `git` / `gh` / `glab` / `tea` / 网页。
- skill 在 git 上只做三件事（都是只读或记录）：
  1. **检查**：`dispatch` 前确认工作树不脏、不在保护分支上（否则拒绝并说明原因）；
  2. **只读观察**：`roster` / `digest` 显示分支、脏文件数、领先提交、"待收尾"清单；
  3. **复验证据**：`review <ID> --dir <PM 准备的 checkout>` 跑门禁并写 `reviews/<ID>.md`（git 由 PM 准备）。
- 约定（写在 SKILL.md 与项目 PROTOCOL 里，PM 照做即可）：一 agent 一长期 worktree；
  任务分支从保护分支切出；复验用 detached 独立 checkout；合并 = squash 进保护分支（有 PR 时先合 PR 再 `fetch + merge --ff-only`）；
  **BOARD 只在代码真的进了保护分支之后才标 done**。
- forge 无关：不假设 GitHub/GitLab；token 从项目配置的 token 文件读，只在调用命令时注入，不回显。

## 9. 容量：底线是 RAM 与磁盘 swap 都不见底（zram 不算额度）

- 拒绝派单的条件只有一个：空闲 swap < `TEAM_MIN_FREE_SWAP_MB`（默认 1024MB）或 RAM+swap < `TEAM_MIN_TOTAL_MB`。
- RAM 紧张（< `TEAM_WARN_AVAIL_MB`）只警告：允许卡顿，因为慢不等于崩；OOM 才是真事故。
- `team ps` / `team doctor` 直接用同一数据源报数，并给出“还能再加几个 agent”的估算（`TEAM_AGENT_MEM_MB`）。

## 9b. 测试与门禁必须有超时（不可协商）

- 事实：一个被故意改坏的实现让 PG 集成测试永久等待连接（池无超时 + `--test-timeout` 缺失 +
  bash `timeout` 被设成 1800000s）→ 脚本挂 **85 分钟**、期间零输出。
- 因此：`team review` 跑门禁时**一律套硬超时**（`TEAM_REVIEW_TIMEOUT`，默认 1800s；超时判定 `TIMEOUT`，
  按 FAIL 处理并写进复验记录）。门禁命令自身也应带 `timeout`（如 `timeout 900 pnpm test:unit`）。
- 任务书里的验收命令要自带超时；破坏性实验脚本必须 `trap 'git checkout -- …' EXIT` 还原现场。

## 9c. 强复验（对抗性验证包 + finding 翻转，里程碑收口用）

`team review <ID> --strong` 会额外检查两件事，并把结论写进复验记录：

1. **对抗性验证包**：验证 agent 在**独立包**里写测试（不复用被测项目的夹具，避免“用被验证对象验证它自己”）；
2. **finding 翻转**：修复者把「记录缺陷的 finding 测试」翻转为守门测试，报告给出「修复前红 → 修复后绿」；
   更狠的做法是**故意破坏实现 → 守门测试必须失败**（证明测试不是表演）。

成本更高，适合里程碑/收口轮；日常任务跑普通门禁即可。

## 10. 决策日志与调研规则

- 技术栈/选型（语言、框架、库、存储、协议）**先派 research agent 取证**（① 本机实测 > ② 官方文档 >
  ③ 二手资料；无实测必须标注），PM 复验证据链后才写「决定」。
- 每个决策必须写**理由**与**影响**：只写结论的决策日志在半年后等于没有。
- agent 可以用自己的证据推翻 PM 的暂定判断——这是设计意图，不是越权。
