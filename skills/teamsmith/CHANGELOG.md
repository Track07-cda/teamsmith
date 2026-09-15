# teamsmith 变更史（旧名 pi-team）

> 版本号单一来源：`scripts/lib/common.sh` 的 `TEAM_VERSION`（`SKILL.md` 的 `metadata.version` 必须一致，
> `team version --check` 会检查）。**更新怎么拿到**：`scripts/**` 每次调用现读盘（零操作）；
> `SKILL.md`/`references/**`/`templates/**`/`extension/**` 在 Pi 里输入 `/reload`（或 `/pi-team-reload`）即生效；
> 判断自己是不是旧的：`team mark-loaded`（开局记一次）→ `team version --check`。

**未发布（版号由 PM 定；刻意不用 `##` 标题——版本解析取第一个 `##` 行）**

**M3.2 · adapter 加固（V3.0 的 F1、F4–F8 + 两条 nit）**

- **F1（blocker）worker 的摘要不再可能是 shell 代码**：新增 notify 占位符 `{summary_file}`（teamsmith 指定路径并
  加引号），worker 先把摘要写进 `state/summary-<agent>-<ID>.md`，再**原样**跑渲染好的固定命令；
  `team notify <agent> --from-file <路径>` 从文件读摘要（不经过 shell）。提示词里不再出现任何 worker 文本。
  归一化：去掉 `\r`、换行→空格、去尾部空白，其余字节**逐字节保留**（引号/`$`/反引号/`{agent}` 原样进收件箱）；
  摘要文件缺失或为空 → 非 0 退出且不写收件箱（不会假报「已通知」）。
- `{summary}` 保留可用，但**永不作文本插值**：渲染成对同一文件的「带引号读取」（`"$(cat '…')"`；在 `'{summary}'`
  里用单引号安全形态），所以旧模板既能继续工作，也不会把摘要变成代码。文档与模板示例改用文件通道。
- **F4**：畸形占位符（`{ cwd }` / `{cwd }` / `{{cwd}}` / `{cwd'}'`）不再默默进命令行 —— 带空格、双花括号、引号的
  近似写法一律判错并列出支持集（JSON body、awk `{print $1}`、`${HOME}` 不受影响）。
- **F5/F6**：纯空白的 `TEAM_AGENT_CMD` 被拒（不再默默渲染 `cd … &&`）、含换行被拒（第二行会被窗口 shell 当命令执行）。
- **F7**：提示词里「不是 Pi、没有自动通知」的说法改按 `TEAM_AGENT_CMD` 判定 —— 内置 Pi 路径不再诳 worker。
- **F8**：notify 模板不可用时，提示词整段换成「写进报告」，不再给一条半截命令。
- nit：dispatch 的分支提示改成 `%q` 引用（可安全复制粘贴）；文档明确「首词必须是裸可执行名」；
  模板展开改为**单趟从左到右**，`{extra_args}` 里的 `{cwd}` 不再被二次展开。

## v1.29.0 · 2026-09-14

**待复验清单不再越过看板的决定（M9.4）**

- 真实假信号：P1（propose 阶段）已被审（`reviews/spec-delta-gate-proposal.md` ACCEPTED）并 `done`，却**每一拍**仍被列为"待复验"——
  检测器把"已复验"等同于 `reviews/<任务ID>.md` 存在，且**不看板状态**。危害是**麻木**：永远清不空的清单会训练 PM 忽略它。
- 现在：看板为 `done/closed` 的任务**永不列出**；阶段任务的证据已就绪时，提示改成"**等 PM 把看板移入 done**"（指向真正该做的动作，
  而不是要求再做一次 `team review`）；**跳过会被点名**（`已按看板跳过 N 份报告（任务已 done/closed）…`）——静默跳过就是假阴性。
- PM 复验：一次夹具里四个任务（done+propose+证据 / done+无阶段 / **未裁决+阶段** / **未裁决+无阶段**），[3] 恰好只列两个未裁决的，
  并点名阶段证据就绪、点名被跳过的两份——四条要求一次跑齐。

## v1.28.0 · 2026-09-14

**`done` 的证据按 pipeline 阶段判定（M9.2）**

- 起因：F1 守卫只认"代码任务"的证据，而 M9.1 的流水线里 explore/propose 阶段**本来就不产出代码**——E1 只能靠
  `TEAM_BOARD_DONE_FORCE` 加一句自由文本理由（那正是会侵蚀守卫的习惯）。
- 现在按阶段给证据：`explore` → `DECISIONS.md` 里**标题条目**点名任务（正文提一句不算——老条目会提到别的任务，那样等于放宽守卫）
  或复验记录；`propose` → `docs/team/reviews/<change>-proposal.md` 判定 **ACCEPTED**（NEEDS-CHANGES 拒绝，且拒绝信息点名文件并说明原因）；
  `verify` → 该任务的复验记录；`archive` → change 出现在 `openspec/changes/archive/` 下；**未声明 phase → 与原样完全一致**（这条控制我亲自验了）。
- PM 复验：独立 checkout 门禁 PASS；逐条探针（无证据拒绝 / 标题点名通过 / NEEDS-CHANGES 拒绝 / ACCEPTED 通过 / 未声明阶段不变）
  全绿；并再次确认"夹具本身要先验"——我自己的探针因**同一任务 ID 的重复 stub 任务书**读错文件两次。

## v1.27.0 · 2026-09-14

**OpenSpec 指引重写为"流程管理"（M9.1）**

- `references/openspec.md` 从"复述 OpenSpec 手册"改为"**谁在什么时候跑哪个阶段、门在哪里**"：五阶段
  （`opsx-explore → propose → apply → verify → archive`）各带 owner / 输入 / 产出 / 门；一个阶段 = 一个任务 = 一个 owner；
  与 teamsmith 的简报/看板/账本如何对应；PM 在每个门的清单；前置条件（必须为 agent 的 CLI 生成这些命令）；以及"不值得做就停"的升级路径。
- **propose 与 apply 之间加了记录式 PM 产物审查**：判定写在 `docs/team/reviews/<change>-proposal.md`
  （ACCEPTED / NEEDS-CHANGES + 逐条 findings + PM 实际跑过的命令），**未 ACCEPTED 不得派 apply**；附八条审查清单。
- 两条硬规则写进 agent 最先读的模板（AGENTS.section / PROTOCOL）：**验证必须独立**（不许自验），**归档需用户确认**
  （PM 只有在明确声明并记录理由时才能以用户角度代为确认）。
- 本仓库跑 `openspec update --tools pi`，生成 `.pi/prompts/opsx-*.md` 与 `.pi/skills/openspec-*`；smoke 新增 §19
  逐条断言五阶段契约（翻转时点名被破坏的那条规则）。

## v1.26.0 · 2026-09-14

**worker 侧的两个"静默失败"修掉（M8.2）**

- **裸可执行名会被解析**：窗口 harness 走 `bash -lc`，本机登录 shell 的 PATH 不含 `~/.bun/bin`，于是 `TEAM_AGENT_CMD`
  首词写裸名字（文档示例写法）时 CLI **从未运行**，而 dispatch 仍打印 `✓ dispatched … proof=spawn`。现在首词替换为解析出的
  绝对路径（复用 M8.1 的通用 helper）；PM 实测：只在 caller PATH 里可见的 CLI 真的跑起来了（它自己的日志记下了收到的 argv）。
- **"harness 起来了"与"agent 真起来了"分开**：CLI 立刻退出时如实报
  `✗ 派单失败：harness 起来了，但 agent 立刻退出了（exit=N）—— agent 没跑起来`，退出码非 0，
  并把诊断（窗口尾屏 + 渲染命令 + 解析到的可执行文件）落盘 `state/dispatch-<agent>-launch-failed.log`。
- 发布流程按 D13 走链式顺序（门禁 → bump → 提交 → tag/release），本次是第一次在顺序上真的做到。

## v1.25.0 · 2026-09-14

**PM 侧也成了一个 adapter：`TEAM_PM_CMD` / `TEAM_PM_BIN` / `TEAM_PM_RESUME_ARGS`（M8.1）**

- 三键默认全空 = Pi 行为**逐字节不变**（PM 用 old/new 两条 CLI 在同一夹具里 diff 了渲染出的窗口命令，除夹具路径外完全相同）。
- 非 Pi PM 可真跑：用 `codex` 当 PM，`team up` 启动后 codex 真的收到简报并开始当 PM 干活；`TEAM_PM_RESUME_ARGS` 为空时
  工具**如实说明"这次不延续历史"**并给出接手路径（`docs/team/**` + `team inbox`）。
- **退回返工修掉的真缺陷**：窗口 harness 用 `bash -lc`，而本机登录 shell 的 PATH 不含 `~/.bun/bin`，于是文档示例里的
  **裸可执行名**（`codex exec {prompt}`）必然启动失败、且失败清理会把窗口连诊断一起杀掉。现在：模板首词替换为解析出的
  绝对路径；启动失败保留诊断（窗口末尾 + 渲染命令 + 解析到的可执行文件）到 `state/pm-launch-failed.log`，错误行给出退出码。
- **worker 侧同洞已被测量**（裸名字时 CLI 从未运行却打印 `✓ dispatched … proof=spawn`）→ 触发下一任务 M8.2。

## v1.24.0 · 2026-09-14

**派单退出通知改为"事件证据"（M7.5）+ 修掉 v1.23.0 遗留的 main 红**

- **根因（检测侧，非夹具）**：旧实现是"睡 `TEAM_DISPATCH_ALIVE_SEC` 后**采样一次** `team_pane_busy`"。本容器里
  "agent 退出 → 窗口回到 shell"是**非确定性过程**（`bash -lc` → 交互 bash 读 rc → `exec zsh -l` 的登录期 churn），
  采样点落进去就会把"已退出"误判为"还在跑"，于是**退出通知与续跑提示整条消失**——同一提交时而 `904/2` 时而 `906/0`。
- **修法**：agent 的**父 shell**在进程返回后把 `<nonce> <退出码>` 写进 `state/dispatch-<agent>.exit`（事件，不是采样），
  派单路径**有界轮询**该证据；同区域的固定 sleep 一并改成有界轮询；守卫连跑 5 次并要求事件证据。
- **翻数据**：作者给出 red-before `965/12`、break-the-fix `966/11`、修复后全绿；PM 亲自复跑其 30 次复现器（0 次漏报）。
- **修复 main 红**：M7.2 的 troubleshooting 段落引用了中文 CLI 输出但没放进 code span → M7.3 的英文不变量在 main 上失败。
  修好后 PM 在**合并树**上亲自复跑门禁：`✓ 977 ✗ 0`。发布流程加了检查清单（DECISIONS D13）。

## v1.23.0 · 2026-09-14

**迁移指南 + 看门狗"启动中"状态 + 英文不变量机制（M7 批）**

- **迁移/升级指南**（`references/migration.md`）：哪些契约永不需要迁移（`team`/`.pi/team`/`TEAM_*`/`docs/team`）；
  `pi-team → teamsmith` 的自动/手工项；v1.11 删除的命令与替代；v1.19 新增的两个必需依赖与逃生口；
  会咬人的行为变更（分支比对、`done` 需证据、空 tmux 目标、`TEAM_SESSION` 必须匹配真实 session）；升级配方与回滚。
  `team doctor` 只在真需要时（陈旧会话，或项目里还只有 `<!-- pi-team:begin -->` 旧标记）打印一行指向它。
- **看门狗抖动根因**（M7.2）：不是"存活闪一下"，而是**"启动中"这个状态根本不存在**——respawn 后 agent 尚未可辨识时
  被当成"PM 没在跑"，下一拍于是又拉起一个（配额算两次、刚起来的可能被杀）。现在有 `starting/running/busy/idle/foreign/unknown`
  六态、以及"用哪条证据判定"的如实输出；单拍内不会再自相矛盾。
- **英文正文不变量变成机制**（M7.3）：`references/**` + `SCOPE.md` 的**散文**不得含 CJK（反引号/围栏里的 CLI 原文豁免），
  缺 `perl` 报红而非静默跳过，双向翻转自测在套件内；`install.sh` 不再把兼容软链装成第二个 skill。
- **测试隔离硬规则（DECISIONS D12）**：夹具/翻转包/smoke 新段凡调用写盘命令，必须沙箱化 + 先断言 `team paths`
  指向临时仓库 + 反向守卫真实账本未被改动（起因：M7.2 的翻转脚本往真实收件箱写了 9 条幻影通知，把 PM 叫醒 9 次）。

## v1.22.0 · 2026-09-14

**V4.0 收口：信号诚实（M4.3 A–E）+ 规格可证伪不变量（M5.3）** —— 至此 V4.0 的 29 条 finding 全部落地。

- **A 长会话 × 小窗口**：派单前检查"会话规模 vs 模型窗口"，必要时拒绝/告警并指向 `--fresh`；`ps`/`roster`
  在模型旁显示 `已用/窗口`（此前会把 361k 会话塞进 272k 窗口 → Context full 循环、`roster` 仍说"pi 在跑"）。
- **B 卡死 pane 的假成功**：派单改为 respawn + 启动校验（`含启动校验：proof=spawn pid=…`），失败则重试一次、
  清掉残留窗口并留下已知终态；不再把命令打进卡死进程的输入缓冲还报成功。
- **C 草稿 vs 交付**：还没提交到任务分支的报告草稿标注"report 未提交：先等 agent 交付"，不再指向一个跑不了的 review。
- **D squash 噪音**：内容已在保护分支里的分支显示 `已合并（squash，内容一致）· 无需 push`（tree 相等启发式；
  若 squash 提交里还夹带了别的改动则落回诚实的"领先 N"）。
- **E 假"回合结束"**：扩展不再把回合内部的压缩/重载/续跑（生命周期事件）播报成交付；未完成且无生命周期事件时
  仍会通知，但**绝不**用未完成回合的文本编造摘要。
- **M5.3 规格 lint**：`openspec validate --strict` 看不见"场景缺 THEN"这类问题，新增 `tests/spec-lint.sh`
  （每条需求至少一个场景、每个场景必须有 WHEN+THEN、空规格拒绝）并置于门禁中。

## v1.21.0 · 2026-09-14

**V4.0 修复批收口：派单/通知/边界（M6.3）+ digest/版本/会议（M6.4）**

- 派单：工作树分支必须与该任务的分支一致（错分支直接拒绝并给出 `git switch` 命令）；项目外的任务书被拒；
  未知收件人 **rc=1** 并列出名册（`--any` 越权需显式且留痕）。
- 通知：**PM 自己的收件箱成为一等待办来源**（digest §[2]、`team inbox`、watchdog 都会看 `inbox/pm.md`）——
  此前 `team notify pm --from-file`（文档推荐的通道）在 PM 没跑时等于失踪；去重键能区分前缀相同的不同简报。
- 边界：空/空白 tmux 目标在**所有**包装里集中拒绝（此前 `send_text('')` 会把文字打进当前 pane —— 两次打死 PM 的那类事故）；
  wrapper 脚本型 agent 的启动改用 `proof=spawn`（实测 pid 活着 + cwd 在本项目内），不再误报"启动失败"。
- digest：`未 push` 改按 `@{upstream}` 判定（此前拿分支与保护分支比，squash 合并后永久误报）；含 `-` 的任务 ID
  （如 `API-2`）的报告不再被当成"忽略的非任务报告"。
- 版本：`version --check` 在"本会话是旧版本"时**退出码 0**（此前经 `| head` 在 pipefail 下 141/SIGPIPE，`&&` 链会当成崩溃）。
- 会议：`--ttl` 必须是正整数小时（`0`/负数/`abc` 以前会让会议永不超时），`read` 显示的有效 TTL 与实际一致。
- OpenSpec 指引进入协议模板（`AGENTS.section` / `PROTOCOL`），bootstrap 出来的项目第一眼就能看到"规格在 openspec/，门禁跑 validate"。

## v1.20.0 · 2026-09-14

**诚实三连：状态不丢、证据不假、存活不猜（V4.0 对抗验证的修复批）**

- **状态诚实（M6.1）**：只读命令不再破坏 durable 任务记录（`team ps` 曾把崩溃 agent 的 task/branch 抹掉，导致 digest
  报"无待办"、`resume` 说"没有需要续跑的 agent"）；`board set` 未知 ID 不再伪报成功；标 `done` 需要证据（分支已并入保护分支
  或存在复验记录），或显式 `TEAM_BOARD_DONE_FORCE=1` + 理由（写进看板行）；`close` 不再声称不存在的复验记录；
  `TEAM_TASK_BRANCH_RESET` 从死配置变成真行为。
- **复验证据（M6.2）**：`--branch` 解析不到时**默认拒绝**（fail-closed，另有显式 `--allow-unresolved-branch` 并留痕）；
  dirty 覆盖、ignored 构建产物、超时判定、`--no-gates`、`--strong` 全部改为"如实记录 + 结构化判定"；
  复验记录绑定 revision（分支再动一格，digest 会重新列为待复验）。
- **存活证明（M6.5）**：PM 存活改为**正向证据**（`state/pm.pid` 活着且 cwd 在本项目内；手工启动场景要求前台进程就是本项目
  解析出的 agent 可执行文件）。此前"窗口前台不是 shell"就会被判 `running:*` —— 新 tmux 环境里空窗口的前台进程是 `tmux`，
  于是 `team up` 跳过启动 PM 却报"PM 在运行"，连带项目自己的 7 条门禁断言失败。TIMEOUT 判定也改为"包装器真的到点杀进程"
  才算（不再被门禁自身退出码 124 误导）。

## v1.19.0 · 2026-09-14

**必需依赖 + OpenSpec 规格层（"不重复造轮子"）**

- **BREAKING**：`TEAM_REQUIRE_MAGIC_CONTEXT` 默认从 `0` 变 `1`；新增 `TEAM_REQUIRE_OPENSPEC=1`、
  `TEAM_OPENSPEC_BIN=openspec`、`TEAM_SPEC_DIR=openspec`。缺任一项 `team doctor` **失败**并给出安装/初始化命令
  （`openspec init --tools none`）；`team paths` 暴露解析结果；`dispatch` 缺依赖时明确警告（不阻断）。
- **OpenSpec 接管规格与变更流程**：本仓库 `openspec/` 落地，`config.yaml` 的 context/rules/operations 写入
  我们的工作规则（验收命令必须可复制可跑、需求必须有可证伪场景、缺陷修复必须写翻转证据、边界必写）；
  8 个 capability 规格（dispatch / verification / board-and-status / watchdog / notify-and-inbox / meeting /
  memory-and-deps / boundary）共 45 条需求 / 77 个场景；`openspec validate --all --strict` 已加入 `TEAM_GATES`
  （在 smoke 之前）。
- 新文档 `references/openspec.md`（分工：规格=必须成立什么，简报=一个工作切片，报告/复验=证据，archive=关闭变更）
  + `workflows.md` runbook 的规格步骤 + 简报/PM 提示词接上变更 id 与场景。
- 顺手修掉一个真实 flake：11b 的"超过配额拒绝拉起"断言依赖"此刻有待办"，会偶发假红；现在先造一条未读通知。

## v1.18.0 · 2026-09-14

**新增 `references/memory.md`：长期 PM 的记忆手册**

- 说清三层记忆的分工：**会话记忆**（magic-context，PM 的快捷方式）/ **落盘证据**（reports、reviews、BOARD、
  threads、DECISIONS —— 唯一被他人和别的工具信任的东西）/ **技能版本状态**（`mark-loaded`、`version --check`、`/reload`）。
- 明确规则：结论必须落盘，"我记得"永远不是证据；**记忆与磁盘冲突时磁盘赢，然后修记忆**。
- 讲清什么该进项目记忆（项目事实、信条里的工作规则、本项目特有的坑）与什么不该（当天的任务状态、秘密、长日志、
  本来就在磁盘上的证据），并指向 `templates/memory-seed.md.tmpl`。
- 讲清生命周期：`/compact`、重启（`pi -c`）、`/reload`、移动 worktree 各会怎样；以及没有 magic-context 时的替代流程。
- SKILL.md 阅读表与 memory-seed 模板头部都加了指向。

## v1.17.0 · 2026-09-14

**文档面全英文收口**（`references/**` + `SCOPE.md`）

- 翻译：`protocol.md`（规则的理由，最长一篇）、`workflows.md`（端到端 runbook）、`troubleshooting.md`、
  `config.md`、`meeting.md`（跨项目会议）、`bootstrap.md`、`SCOPE.md`，以及 `agent-adapters.md` 里残留的中文。
- 结构保真：每篇的标题 / 代码块 / 表格行数与原文一致，行数只随英文变长而增加；规则**理由**逐条保留
  （PM 抽查了 zram 分账、worktree 长期制、forge 403 三处）。
- 同步了 2 条检查中文内容的断言（`不执行`→`does not perform`、`直接用`→`real tools`），语义不变。
- 可机器校验的不变量：`grep -rP '[\x{4e00}-\x{9fff}]' skills/teamsmith/references SCOPE.md` 必须为空。
- 边界（DECISIONS D8）：CLI 输出、`team help`、smoke 断言**标签**仍为中文，属有意保留（要做就是独立的 M4.2）。

## v1.16.0 · 2026-09-14

**安全加固：worker 摘要不再是 shell 代码（V3.0 对抗性复核的 F1–F8）+ monitor 内存/显示安全（F2/F3）**

- **BREAKING（行为）**：通知通道改为**数据通道**——`{summary_file}` 占位符（teamsmith 生成、`%q` 引用）
  与 `team notify <agent> --from-file <path>`；渲染出的提示词里**不再有 worker 可替换的摘要槽位**
  （旧写法让 worker 把摘要写进双引号里，摘要里的 `$(...)`/反引号/引号破出会**真的执行**）。
  旧配置的 `{summary}` 仍可用，但文档与示例默认给出安全写法。
- 模板校验变严：畸形占位符（`{ cwd }` / `{cwd }` / `{{cwd}}` / 未闭合）、纯空白模板、多行模板
  一律**让派单失败**（多行模板此前会把第二行当命令执行）。
- 提示词不再说谎：只有配了 `TEAM_AGENT_CMD` 才提"非 Pi 无自动通知"；notify 模板不可用时不再给 worker 一条空命令。
- monitor（F2/F3）：日志只读**尾窗**（默认 64KiB、硬上限 1MiB，`TEAM_AGENT_LOG_TAIL_BYTES`），
  只认普通文件（FIFO/设备不再可能挂死看门狗），读不到就 `available:false` + 原因；
  渲染前剥掉 OSC/CSI/C0·C1/双向控制字符（此前会把窗口标题、清屏、剪贴板序列喷进 PM 终端）。
- 实测数字：256MB 日志 **584MB → 59.7MB RSS**；64MB 堆上限下 **exit 134 → exit 0**；敌意日志 ESC 字节 **6 → 0**。
- 门禁：smoke 425 断言全绿；新增 M3.2/M3.3 两个 PM 可复跑的独立验证包（`docs/team/reports/M3.{2,3}-*/pkg/run.sh`）。

## v1.15.0 · 2026-09-14

**agent adapter：worker 可以是任意 TUI agent（Pi 仍是默认）**

- 新增四个配置键，**全留空时行为与之前逐字节一致**（Pi 命令、报错文案、断言都不变）：
  `TEAM_AGENT_CMD`（启动模板）、`TEAM_AGENT_NOTIFY_CMD`（回合结束通知）、
  `TEAM_AGENT_LOG_GLOB`（`monitor --activity` 的日志来源）、`TEAM_AGENT_BIN`（就绪/存在性检查）。
- 提示词里的「回合结束通知 PM」示例走 English-first（v1.14.0 之后提示词是英文），示例摘要也给成
  具体的 `T1.1 done: <one-line summary>`（不是字面 `{summary}`：弱模型会把占位符原样执行）。
- 启动模板占位符：`{cwd}` `{session_id}` `{model}` `{provider}` `{prompt_file}` `{prompt}` `{skill_dir}`
  `{notify_ext}` `{extra_args}`；未知占位符 → 派单**直接失败**并列出支持集（不静默）。
  提示词落盘到 `state/prompt-<agent>-<ID>.md`（`{prompt_file}` 指向它，也方便排查“派了什么”）。
- `team doctor` / `team paths` 新增 adapter 行（`built-in (Pi)` 或 `custom: …`）；只有「配了但解析不到
  可执行文件」才 fail，默认路径仍由 `pi` 检查负责。`roster`/`say` 的存活文案也跟着换 CLI 名。
- `team monitor --activity` 配了 `TEAM_AGENT_LOG_GLOB` 就显示最新匹配文件的尾部（无依赖的 `*` `?` `**`、
  `~`、`{agent}`）；没匹配到/没 Pi 会话/没配 glob 都只降级成「无会话」并说明原因，面板不受影响；
  `--json` 多一个 `source: pi|log|none` 字段。
- 新文档 `references/agent-adapters.md`：契约、占位符表、**codex 与 opencode 实测例子**、新 adapter 验证清单、
  以及明确不支持的事（不模拟各家内部回合事件、不从共享日志里分流转、PM 自己仍然是 Pi）。

## v1.14.0 · 2026-09-14

**English-first prompt surface** (README, skill description, every prompt, every template)

- README rewritten in English (capability table + compatibility notes) — this is the public face of the repo.
- `SKILL.md` fully English, including the frontmatter `description` (the trigger text).
- All templates English: PM prompt (with the 5-line creed), bootstrap prompt, task brief, report, AGENTS section,
  PROTOCOL, ROADMAP, OWNERSHIP, memory seed, config.
- The dispatch prompt generated by `scripts/lib/cmd-agents.sh` is now English (identity, reading order, scope
  discipline, red lines, cross-project boundary, delivery process, flip evidence).
- `references/philosophy.md` (the creed) in English; this repo's own `AGENTS.md` section and `docs/team/PROTOCOL.md`
  re-rendered in English.
- Still Chinese (follow-up batch): the remaining `references/*.md` (protocol/workflows/config/meeting/troubleshooting/bootstrap),
  CLI output strings and `team help`, script comments, and the smoke assertion labels.

## v1.13.0 · 2026-09-14

**改名：pi-team → teamsmith**（仓库名同；命令与路径契约不变）

- 为什么：这个 skill 定义的其实是**一个真正负责项目的 agent**（排期/派活/独立复验/合并/留账），
  而不是"更会聊天的 agent 群"；`teamsmith` = 造队伍的人，且不绑任何 agent/TUI 生态。
- **零迁移成本**：命令仍是 `team`；`.pi/team/config.sh`、`TEAM_*`、`docs/team/**` 全部不变；
  `skills/pi-team` 保留为兼容软链 → `skills/teamsmith`；Pi 里 `/pi-team-reload` 仍注册（新名 `/teamsmith-reload`）。
- 旧项目 `AGENTS.md` 的 `<!-- pi-team:begin -->` 标记会在下次 `team init/bootstrap` **就地迁移**（幂等，不重复注入）。
- smoke 新增**名字一致性不变量**：文档/脚本里出现旧名就报红（历史 CHANGELOG 与显式兼容说明除外），
  并带翻转自测（注入旧名必须被抓到）。

## v1.12.0 · 2026-09-14

**依赖收窄（BREAKING）+ PM 信条落盘 + 可选记忆依赖（magic-context）**

### BREAKING
- **看门狗只剩一个后端**：同 session 的 `watchdog` 窗口（`team watchdog up`）。
  容器形态（podman/镜像/socket/`--container`/`TEAM_WATCH_*` 容器键）**整体删除**，`container/` 目录也删了。
  `team watchdog up --container` 会明确拒绝并说明原因（不是静默忽略）。
  理由（信条第 3 条"少管等于可靠"）：容器换来的那点"脱离 tmux 也能活"的存活能力，
  要靠多一层运行时/权限/socket 去换；而 tmux server 没了 PM 也没了，`team up` 一起重建即可。
- **skill 与 forge 完全解耦**：`team doctor` 不再探测 `gh`/`glab`/PAT/host（以前 `TEAM_VCS=github` 缺 `gh` 会 **fail**）；
  派单提示词不再教已删的 `team pr`（**这就是一处真 drift**：v1.11 删了命令，提示词还在教）；
  `TEAM_VCS` 降级为**纯措辞标签**；token 文件键保留但标注"仅供 PM 手动调用工具，skill 不读"。

### 新增
- **`references/philosophy.md`：PM 的信条（8 条）**——交付物必须能被独立验证 / 状态即承诺 / 少管等于可靠 /
  失败是信息（假绿比没做更危险）/ 重复的问题必须变成机制 / 一切可交接 / 长期主义与预算意识 /
  权威来自证据与授权。每条都带"推论"与"反面"。SKILL.md 与 protocol.md 都指向它（冲突时以信条为准），
  `templates/pm-prompt.md.tmpl` 顶部加了 5 行 credo（PM 每次启动都会读到）。
- **magic-context 作为"可选但推荐"依赖**（PM 长期会话的跨会话记忆）：`team doctor` 新增「PM 记忆（可选）」
  三态检查（装了报版本 / 没装只警告 / `TEAM_REQUIRE_MAGIC_CONTEXT=1` 时失败）；
  新键 `TEAM_PI_SETTINGS_FILE`（探测位置，测试用）；`templates/memory-seed.md.tmpl`（项目记忆种子：把跨任务规则写进项目记忆）；
  PM 提示词加"开局先检索既有决策、收尾把跨任务规则记进项目记忆"两条；文档写清边界：**记忆是 PM 的快捷方式，证据仍以落盘文件为准**。
- 环境要求收紧为四项硬依赖（bash ≥4 / git / tmux / pi），可选只剩 `timeout`、`lsof`（+ 推荐的 magic-context）。

### 测试
- smoke：336 断言全绿。新增：容器后端被明确拒绝、`up --print` 指明窗口与周期、
  文档不得再把容器/forge CLI 当依赖、派单提示词不得出现 `team pr`、信条与记忆种子存在、
  doctor 的 PM 记忆三态（用假 settings.json，不依赖真装）。

## v1.11.8 · 2026-09-14

**强复验的假阴性（SIGPIPE）+ 门禁测试场地**

- **修一个静默假阴性**：`team review --strong` 判定「有没有翻转证据」用的是
  `printf '%s' "$报告正文" | grep -q …`。在 `set -o pipefail` 下，grep 命中后提前退出会让 printf 收到 SIGPIPE（141），
  于是**报告越长、证据写得越靠后，越被判成"缺"**（实测：V1.1 报告 7 处「翻转」被判 flip=0）。
  现在改成写入临时文件再 grep。独立包的关键词也放宽到任务书的说法（独立验证包/对抗性包/不复用被测夹具）。
  新增回归断言：300+ 行报告、关键词在结尾 → 必须判「有」。
- smoke 的 tmux 场地显式 `-c "$REPO"`：新加的「进程 cwd 归属」校验本来会把测试自己的 PM 判成 foreign。
- 看门狗断言容忍单拍抖动（最多重跑 3 拍）——消掉一个偶发 flake。

## v1.11.7 · 2026-09-14

**smoke 快慢分层：门禁有 60 秒内的快模式（`TEAM_SMOKE_FAST=1`）**

- 起因：全量门禁要建真实 tmux 场地、拉起假 pi 进程、跑看门狗/容器 dry-run，跑一次几十秒；
  派单/复验时嫌慢就想跳过门禁。
- 新增快模式：`TEAM_SMOKE_FAST=1 bash skills/pi-team/tests/smoke.sh`（或 `TEAM_SMOKE_FAST=1 team smoke`）
  只跑不依赖真进程的段落。需要真进程的 7 段 —— 派单真拉起、close 后窗口、巡检/watchdog、agent 续跑、
  跨 session 打字守卫、say 离线投递、敲门 session 探测 —— 每段都打印 `SKIP（FAST 模式）` + 原因，不静默少跑。
  **身份隔离自检（第 2 节）与文档一致性自检（14b）是纯逻辑，快模式照跑不跳**（安全断言不能被快模式绕过）。
- 新增「快模式自检」（14c 节，只在快模式跑）：①一次真进程段都没执行（假 pi 参数文件 / PM 参数文件 /
  容量日志都不该存在）；②预期跳过的 7 段都在 SKIP 名单里。把分层改坏（FAST 仍跑全量、或把跳过改成静默）时，
  这一节必红 —— 它按“用户要没要快模式”（`FAST_REQ`）判定，所以把内部开关 `FAST` 改成 0 也关不掉它。
- 默认行为不变：不设 `TEAM_SMOKE_FAST` 时断言数量、顺序、退出码与改造前一致（断言标签集合逐条相同）。
  `TEAM_SMOKE_FAST` 只认 1/0（或 yes/no/true/false/on/off），别的值直接退出码 2，不静默掉回全量。

## v1.11.6 · 2026-09-14

**PM 身份归属校验 + 复验的干净度校验（实测踩到才发现的）**

- `team_pm_state` 以前只看「PM 窗口在 + 前台不是 shell」→ **任何** pi 都算本项目的 PM。
  实测现场：smoke 残留的一个 dummy PM（cwd 是已删除的 `/tmp/pi-team-smoke.*/repo`）挂在我
  session 的 `pi` 窗口里，团队工具一直拿它当 PM（叫醒、digest、看门狗判活全打到它身上）。
  现在：读该窗口进程的 cwd（Linux `/proc/<pid>/cwd`，macOS 退 `lsof`），不在本项目（含其 worktree）
  就判 `foreign:<cmd>`；`team_pm_alive` 为假。
- `team up` / `team_pm_start`：PM 窗口被外来进程占用时**不覆盖、也不新开第二个 `pi` 窗口**
  （这正是双窗口/双 PM 的来源），要显式 `TEAM_REPLACE_FOREIGN_PM=1` 才覆盖。
- `team review <ID> --dir`：checkout **脏**（有未提交改动）时拒绝盖章 —— 复验证据必须能复现；
  要跑脏树得显式 `TEAM_REVIEW_ALLOW_DIRTY=1`（这条来自那个 dummy PM 的独立观察）。
- smoke 新增 4 条断言：foreign 判定、`cwd` 归属判定、`team up` 拒绝 + 不新开窗口、显式覆盖生效；
  另加「脏 checkout 被拒」。全量 ✓ 320 / ✗ 0。

## v1.11.5 · 2026-09-14

**按 V1.1 对抗性复验（agent:verify）的 finding 修**

- **复验判定可信度**（最严重的一条）：`team review <ID> --dir <checkout>` 以前只校验"是个 git worktree"，
  拿 **main 的 checkout / 别的任务分支 / checkout 的子目录** 都能拿到 `判定: PASS`，而记录抬头照样写着任务分支。
  现在：必须传 checkout **根目录**；`--dir` 的 HEAD 必须等于任务分支的 HEAD，否则拒绝并给重新准备 checkout 的命令
  （确要复验历史提交：`TEAM_REVIEW_ANY_DIR=1` + `--branch <sha>`）。
- **文档一致性不变量重写**：改用**词边界**（`team[[:space:]]+(merge|pr|gh|gl)`）而不是尾随空格，
  扫描范围补上 `README.md` 与 `scripts/**`；豁免只对"删除词 + 反引号包裹"的说明句生效（不再整行豁免）。
  并新增**翻转自测**：往 skill 沙箱副本里注入 5 类变体（双空格/制表符/反引号紧贴/行尾裸命令/
  同行既有删除词又有真用法），断言检查器必须报红 —— 防止"无残留 ✓"其实是检查器太弱（真树假绿）。
  这条新口径当场又抓出 3 处真残留：`references/protocol.md`、`references/troubleshooting.md`、
  `templates/PROTOCOL.md.tmpl`（都在教已删的 `team gh/gl/pr`）。
- **用法级不变量**：文档里出现 `team review <ID>` 就必须带 `--dir`（`references/workflows.md`
  与仓库 `README.md` 之前还在教旧签名 + 已删的 `team merge`）。
- 复验记录里 PASS 清单不再教已删命令（改为「squash 到保护分支并 push 之后再 `board set done`」）。
- `pi` 不在 PATH 时 smoke 不再级联 14 条红：改用统一的假 pi（对 `--version/--help` 给出像样回答），
  无 pi 环境实测 ✓ 311 / ✗ 0（原来 ✓ 280 / ✗ 14）。

## v1.11.4 · 2026-09-14

**修一个会把 PM 自己打死的 bug：测试隔离 + 破坏性 tmux 守卫**

- 事故：V1.1 复验的门禁（全量 smoke）从 PM 的 Pi 会话里跑，继承了 `TEAM_ROOT` →
  `team` 读到**真实项目**的配置（session=`pm-skills`、pm_window=`pi`）→ smoke 里的
  tmux/watchdog 段落作用到真实 session 上：空目标的 `tmux respawn-pane -k -t ""`
  （tmux 里等于"当前 pane"）杀掉了 PM 自己的 pi 进程，真实 session 的 dev/verify/watchdog 窗口一并消失。
- 修复：`team_assert_own_session`（cwd 仓库 == TEAM_ROOT 仓库 + session 显式/等于项目名）、
  四个安全 tmux 包装（拒绝空目标）、`init/bootstrap` 的 session 探测守卫（pane 目录必须在项目内）、
  `tests/smoke.sh` 身份隔离自检 + 危险助手防空目标。
- 新增 4 条断言（继承 TEAM_ROOT 不改根解析 / 别的项目里的 up 被拒 / 空目标被拒 / 探测守卫生效）。

## v1.11.3 · 2026-09-14

**文档与代码对齐（把 v1.10/v1.11 的残留清干净）**
- 起因：一份会话里加载的 SKILL.md（v1.10 era）仍写着 `team merge` / `team pr` / `team gh` / `team gl` /
  `review <ID> [--branch]` / "token 只由 wrapper 注入" / bootstrap "建每个 agent 的 worktree"。
  核查后发现**磁盘上也有同类残留**（SKILL.md 7 处、references 4 处、templates 3 处），已全部改为
  "PM 直接用 git/gh"的说法。
- 新增 smoke 不变量：**文档/模板里不得再出现已删除的命令**（`team merge`/`team pr `/`team gh `/`team gl `/`forge.sh`），
  否则用例失败 —— 防止"代码删了、文档还在"这类漂移再次发生。
- `team watch`：每次 tick 都打印一行结论（`watchdog: 无待办（PM 在跑：不打扰）` / `有待办 … 已提醒` / `已拉起`），
  日志仍保持去重（不刷屏）；便于人看与脚本断言。
- smoke 的 `make_pm_idle` 改为**轮询** pane 落回 shell（不再靠固定 sleep），消除偶发 flake；连跑 3 次全绿。

## v1.11.2 · 2026-09-12

**`/reload` 的语义说清 + 自动重读**
- 事实（读 Pi 实现确认）：`/reload` 会重新发现 skills、重建 system prompt（清单与描述）并清扩展缓存，
  **但不会改写对话历史里已经 `read` 过的 `SKILL.md` 正文** —— 那段旧文本仍在 context 里。
- 因此：reload 后需要**重新读一遍** `SKILL.md`。扩展现在会在 `session_start(reason="reload")` 时
  自动发一条 follow-up（`triggerTurn`）提示 agent 重读，并顺手清掉 `state/reload-requested` 标记
  → 不需要人提醒、也不需要 agent 自己记得。
- `team version --check` 仍是发现"我是旧的"的入口；`mark-loaded` 记录新版本。

## v1.11.1 · 2026-09-12

- **自解释的破坏性变更**：已删除的命令在最需要的地方给出替代做法 ——
  `team merge` / `team pr` 提示用 git/gh 的完整步骤（含 forge-first 顺序与 `board set done` 前提），
  `team gh` / `team gl` 提示直接用真实工具并给出带 token 注入的示例；
  未知子命令提示 `team help` 与 `team version --check`
- 若本会话加载的版本早于磁盘，上面这些提示会附带一句「输入 /reload 刷新 skill 描述」
  → **别的项目不需要人额外通知，也不需要专门迁移说明**：`/reload` 一次即可，漏了也会在报错处得到指引

## v1.11.0 · 2026-09-11

**收窄到"不包装已有工具"（用户原则）**
- **删除** `team merge` / `team pr`（连"打印食谱"也算包装）：合并与开 PR 由 PM 直接用 git/gh/glab/tea/网页；
  步骤写进 `SKILL.md`、`references/workflows.md`、`references/protocol.md §8h`
- **删除** `team gh` / `team gl` 透传与 `scripts/lib/forge.sh`（token 只作为项目配置；PM 自己注入）
- `team review <ID>` 现在**要求 `--dir <PM 准备的独立 checkout>`**：skill 只跑门禁 + 写证据，不碰 git
- `team add-agent` / `bootstrap` 默认**只打印** `git worktree add` 命令（git 归 PM）；
  想让它代建加 `--create` / `--create-worktrees`；`dispatch` 不再代建 worktree
- `team close <ID>` 也彻底不碰 git（不再 `--delete-branch`；只在输出里提示 PM 自己跑 switch/删分支）
- 保留（这些不是已有工具的包装）：任务书/看板/线程/报告/收件箱/digest、派单与提示词、
  看门狗与巡检、容量守卫、监视器、跨项目会议、版本与更新

## v1.10.0 · 2026-09-11

**分工变更：git 与 forge 写操作归 PM，skill 不再代做**
- `team merge <ID>` / `team pr <ID>` 由"执行合并/建 PR"改成**打印可复制粘贴的食谱**：
  - `merge`：在主工作树 squash 合并（含 lockfile 用 `--theirs` 的处理提示）→ push → `board set done`
    → 删分支（可选）；给了 `--pr N` 时按 **forge-first** 排序（先合 PR，再 `fetch + merge --ff-only`）
  - `pr`：push 分支 + 建 PR/MR 的命令
- `team dispatch` 不再自动建/切分支：只**检查**工作树（不在保护分支上、不脏），否则拒绝并给出该跑的 git 命令
- `team close` 只动 BOARD/窗口/状态，不再切/删分支（只提示）
- 删除 forge 写操作（`forge_open_pr` / `forge_merge_pr` / `forge_pr_record_and_close`）；
  `team gh` / `team gl` 变成**只读透传**，写命令直接拒绝并指路食谱
- **forge 无关**：`TEAM_VCS=local|github|gitlab|other`；非 GitHub/GitLab 可用 `TEAM_PR_CMD` /
  `TEAM_MERGE_PR_CMD` 写命令模板（占位符 `{branch} {base} {title} {pr} {body}`），skill 只负责渲染
- 任务书文件名：非 ASCII（中文）标题的 slug 退化为 `task`，不再出现 `T1.1-.md`

## v1.9.0 · 2026-09-11

**更新分发与版本自检（新）**
- `team mark-loaded`：把本会话加载的 skill 版本 + 指纹（SKILL.md+extension 哈希）记进 `.pi/team/state/pm-loaded.env`
- `team version [--check]`：磁盘代码版本 / SKILL.md 版本 / CHANGELOG 版本 / 本会话加载版本 + 结论与生效方式
- `team changelog [--since X]`、`team reload [--done]`
- 扩展新增命令 `/pi-team-reload` 与工具 `reload_skills`：PM/agent 可自助刷新 skill（等价 `/reload`）
- `digest` / `doctor` 增加"skill 版本 vs 本会话"提示行
- 依据（读 Pi 实现确认）：`/reload` 会重新发现 skills 并重建 system prompt（`available_skills`），
  同时清扩展模块缓存并重新解析 CLI 传入的 `--skill`/`-e` 路径 → 文档与扩展都能热更新；
  `scripts/**` 本来就每次现读盘

**合并顺序修正（CEP 实测，重要）**
- `team merge --pr N` 改为 **forge-first**：先让 forge 合 PR/MR（历史保留真合并提交与 PR 链接），
  成功后 `git fetch && merge --ff-only` 快进本地保护分支；失败才回落到本地 squash+push+留言+关 PR
- 失败提示不再甩锅权限：打印 forge 的真实错误，并按内容区分「不可合并（冲突/已被推进）」与「权限」

**`team say` 投递校验（CEP 实测）**
- 发送后比对 pane 内容指纹确认送达；没动静就补发 Enter、再整条重发一次；仍未确认 → 明确报"投递未确认"
  并写明消息已落收件箱 + 手工兜底命令（不再假报成功）
- agent 没在跑（窗口不在 / pi 已退出）时不再硬失败：消息落收件箱 + 提示 `team resume --agent`
- 新增 `--no-verify` 跳过校验

**跨项目会议**
- 新增 `meeting peer <slug> <项目>:<session>`（事后登记 session）与 `meeting knock <slug>`（重敲最后一条）
- 敲门失败输出五步排查清单（全局开关 / 对方 session / session 是否存在 / PM 窗口是否在跑 pi / 边界守卫）

## v1.8.0 · 2026-09-11

- **跨项目会议模式**（peer 交流，不是指令通道）：`meeting open/say/read/list/inbox/propose/agree/close`
  - 共享区 `~/.pi/team/meetings/<slug>/`（两个项目之外）；transcript 是唯一真相，先落盘再（可选）敲门
  - `intent` 白名单 `info|question|report|proposal|request` —— 机制里没有 command/order
  - `--as-user` 仅人类终端可用；共识需双方各自 `agree`；TTL 72h、每边 20 条上限；close 后冻结
  - 跨 session 打字默认一律拒绝，唯一例外＝已登记会议的敲门
- 修复：新建 tmux 窗口瞬间 `pane_pid` 可能是 tmux 自己（`[tmux: server]`）→ 窗口被误判"忙"、PM 拉不起来

## v1.7.3 · 2026-09-11

- `forge_gitlab_api` 按调用自动选 Content-Type（`--data-urlencode` → 表单头），修 GitLab 开不出 MR
- 派单解析 `pi` 绝对路径 + 校验存在性（修 `pi: command not found` 竞态）
- `team_render` 不再走 sed 并关掉 bash 5.2+ 的 `patsub_replacement`（修 `TEAM_GATES="a && b"` 被写成 `{{GATES}}{{GATES}}`）
- 非任务交付物不再被当待复验；`team resume` 支持位置参数

## v1.7.2 · 2026-09-11

- **BOARD 的 done 只在「merge + push 都成功」后写**；任何失败都还原状态并给恢复步骤
- `--pr` 自动带 `--push`；`--prefer-theirs <path>` 解决 lockfile 冲突；merge 前校验分支存在

## v1.7.1 · 2026-09-11

- merge 失败列出未合并文件（UU/AA/…）+ `--no-renames`
- BOARD 解析按表头名定位（容忍手工加列）；`board set` 只改状态列
- 「待复验」收紧为真任务报告；结项报告进「忽略的非任务报告」
- 翻转证据（修复前红→修复后绿 / 破坏实现→守门测试失败）写进任务书/报告模板与派单提示词

## v1.7.0 · 2026-09-11

- 容量口径：zram 不当额度（硬线＝MemAvailable + 磁盘 swap 空闲；zram 只警告）
- 分支模型：`TEAM_BRANCH_MODE=task`（默认，一任务一分支）
- 门禁硬超时 `TEAM_REVIEW_TIMEOUT`（超时判 `TIMEOUT`→FAIL）；`review --strong`
- 模型并发限额支持通配（默认 `kimi-coding/k3=2 openai-codex/*=1`）
