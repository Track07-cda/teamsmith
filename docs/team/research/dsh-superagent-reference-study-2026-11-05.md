# DSH Superagent 与 Teamsmith 对照研究：供 PM 讨论与立项取舍

日期：2026-11-05。读者：Teamsmith 项目 PM、后续探索者与独立评审者。

文档状态：研究意见，尚未采纳为产品需求。用户授权的是研究及整理本文，并未据此授权运行席位调整、开发派单、外部接入、发布或状态迁移。

本文集中保存研究结论与出处，不承担规格、任务书、开发设计或验收契约的职责。后续被采纳的行为进入既有 OpenSpec 流程；本文不随实现维护第二份需求清单。候选的优先级是研究者建议，最终采纳与流程权限以项目既有约定为准。

## 1. 先给 PM 的结论

建议借鉴 DSH 的三种组织方式：围绕下一步行动呈现状态、集中表达状态转换、让规则能够脱离真实运行环境被验证。它们有机会减少 PM 的机械核对与维护成本。

当前证据不支持“重写 Teamsmith”“迁移到 DSH”“统一换成数据库”或“引入完整事件平台”。本项目已有可靠投递、完整派单身份、后台作业车道、提醒状态权威和测试分层。优先在这些能力上收敛，而不是叠加同名系统。

建议首先讨论两个小探索：

1. 从现有 pending/digest/面板中，找一个能够通过重组信息减少 PM 查找步骤的场景。
2. 从现有重型测试中，找一组可以改成确定性行为测试、并退休原重型执行路径的场景。

状态持久化重构、执行历史扩充与外部事件接入先保留为条件候选。它们需要实际反例或操作成本证据，当前阅读没有证明这些领域存在新缺陷。

本文引用的是截至本次阅读的源码与本地文件，不是两项目的运行对比。没有安装 DSH、运行其测试、测量延迟、统计事故率或开展用户实验。因此，“可能减少成本”是待验证推论，“实现里有某机制”才是已经观察到的事实。

## 2. 阅读范围与证据用法

### 2.1 外部项目固定版本

研究对象：[deepseek-ai/dsh-superagent-prototype](https://github.com/deepseek-ai/dsh-superagent-prototype)。本次固定阅读提交为 [`8c32a9dc5d72c033816c6a8110b37f40cf94fba4`](https://github.com/deepseek-ai/dsh-superagent-prototype/tree/8c32a9dc5d72c033816c6a8110b37f40cf94fba4)。下文外部链接均指向该版本，避免后续主分支变化改变论据。

主要阅读了 README、000–005 号文档、007 架构文档的相关部分，以及 core、运行时、持久队列、背景工作和部分测试；没有逐行审计整个仓库。

DSH 的 [README](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/README.md) 明确将其定位为研究原型，并说明公开版本与内部版本及文章描述存在差异。因此，本文不把文章中的未来方向算作已实现能力，也不将源码结构推断为生产可靠性结论。

### 2.2 本地项目基线

本地以 2026-11-05 阅读时的工作区文件为准；没有为本文冻结独立 checkout 或绑定本地提交，接手者需复核后续变化。关键入口：

| 主题 | 本地证据入口 | 本次能够支持的判断 |
|---|---|---|
| 产品定位 | [README](../../../README.md)、[PM 哲学](../../../skills/teamsmith/references/philosophy.md) | PM 拥有项目判断、独立复验与协调职责，Pi 是当前承诺的运行时 |
| 方向采纳 | [候选提案收件箱](../PRODUCT-PROPOSALS.md) | 候选与正式采纳分离，方向采纳有既有入口 |
| 项目纪律 | [AGENTS](../../../AGENTS.md)、[OWNERSHIP](../OWNERSHIP.md) | 复杂度、目录归属、模型切换与交付边界已有约定 |
| 待办计算 | [common.sh](../../../skills/teamsmith/scripts/lib/common.sh) 的 `team_pending_counts`、`team_pending_text`、`team_pending_nudge_key` | 已有统一待办计数与叫醒键，不能假设需要从零实现 |
| 面板数据 | [data.ts](../../../skills/teamsmith/scripts/panel/src/data.ts)、[App.tsx](../../../skills/teamsmith/scripts/panel/src/App.tsx) | 已有异步分块、缓存和不同视图，讨论应考虑现有性能边界 |
| 派单身份 | [cmd-agents.sh](../../../skills/teamsmith/scripts/lib/cmd-agents.sh)、[common.sh](../../../skills/teamsmith/scripts/lib/common.sh) 的 assignment 解析 | 已有任务、模型、SID、分支、席位、启动 nonce 等身份事实 |
| 投递 | [outbox.sh](../../../skills/teamsmith/scripts/lib/outbox.sh)、[team-inbox-watch.ts](../../../skills/teamsmith/extension/team-inbox-watch.ts) | 已有持久收件箱、队列、日志、重放与不确定结果处理 |
| 后台工作 | [team-bg.ts](../../../skills/teamsmith/extension/team-bg.ts)、[background-jobs spec](../../../openspec/specs/background-jobs/spec.md) | 已有起作业、挂起、完成合并通知与收割；重启不恢复内存作业表 |
| 提醒状态 | [state-authority.mjs](../../../skills/teamsmith/scripts/state-authority.mjs)、[remind-store.mjs](../../../skills/teamsmith/scripts/remind-store.mjs)、[提醒手册](../../../skills/teamsmith/references/reminders.md) | 提醒域已采用统一入口、锁、原子快照和派生视图 |
| 回复保存 | [team-reply.ts](../../../skills/teamsmith/extension/team-reply.ts)、[key-replies spec](../../../openspec/specs/key-replies/spec.md) | 已有显式回复标记捕获，不应另建回复同步系统 |
| 测试分层 | [meta-suite.sh](../../../skills/teamsmith/tests/meta-suite.sh)、[测试说明](../../../skills/teamsmith/tests/README.md)、[CI](../../../.github/workflows/gates.yml) | 已有一阶/二阶分频与低频记录，本研究不重复立项 |

上表是入口索引，不代表每个文件的所有行为都已被本研究验证。

### 2.3 阅读中的三种证据

- **源码事实**：代码或文档可直接定位的机制。例如 DSH 将报告问题保存为结构化字段。
- **研究推论**：从机制推导的潜在收益。例如结构化问题可能减少 PM 翻报告的时间。
- **探索问题**：本项目是否需要改变。例如当前用户决定是否真的被报告正文淹没。

后续评审可用这三个标签区分证据强度。只有推论而没有现场，不宜当作缺陷修复派单。

## 3. 两个项目哪些地方可比

DSH 面向一个 GitHub 仓库，以 GitHub、可选飞书等来源接收消息，把获准工作交给执行会话，并将结果回复原会话。Teamsmith 面向项目所有权：PM 组织工作，worker 在长期 worktree 中完成任务，另一路证据用于复验。[DSH 领域模型](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/docs/001-domain.md)、[本项目 README](../../../README.md)

| 维度 | DSH 本次阅读到的做法 | Teamsmith 当前事实 | 可借鉴程度 |
|---|---|---|---|
| 主会话职责 | 以准入、路由、转交为中心，技术工作交执行器 | PM 还承担方案判断、复验和合并责任 | 借鉴机械分工，保留 PM 判断 |
| 工作与执行 | Ticket 表达工作，Assignment 表达一次执行绑定 | brief/board 表达任务，已有 committed assignment 身份 | 核查关联完整性，避免重复建模 |
| 人工介入 | Attention/问题字段与状态分类支持直接行动 | 已有 blocked、review、报告与回复页 | 值得探索信息重组 |
| 状态写入 | Engine 统一领域修改，Store 提供事务，Effects 执行动作 | 多个既有文件机制；提醒域已有统一状态权威 | 按具体操作收敛，不做全仓迁移 |
| 运行时 | DSH 提供会话、事件、作业和子代理能力 | Pi 扩展、CLI、tmux 与磁盘账本协作 | 比较能力边界，不能只比较代码量 |
| 验证路径 | 内存仓库、模拟宿主和运行时测试分层 | 真实 tmux/Pi、行为测试与元测试并存 | 借鉴确定性边界，保留真实接口验证 |
| 外部接入 | 已有 Source、Thread、订阅、授权和回复路径 | 先前记录仍将外部仓库融合列为讨论项 | 远期参考，当前不启动接入 |

这里不做“谁更先进”的评分：两者的职责和宿主能力不同，源码行数或概念数量不足以证明优劣。

## 4. 候选 A：让首页直接回答“下一步由谁做什么”

### 已观察到什么

DSH 的 [`ticketStage`](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/src/core/stage.ts) 按固定优先顺序派生阶段，区分投递故障、等待回答、等待评审、阻塞、排队、执行与空闲；[面板文档](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/docs/005-panel.md) 将需要操作的工作放在概览前部。

本项目已有 pending 计算、报告扫描、收件箱与面板数据块。因而问题不是“缺少看板”，而是这些已有事实是否能让 PM 少走几次查询。

### 值得先验证的假设

如果 PM 要先读 digest、再找任务书、再翻报告才能确定一个动作，那么重排已有信息可能有收益。本次没有测量这些步骤的频率，不能据此声称现有面板不好用。

建议用最近完成的一项复验、一项阻塞工作和一条 held 投递做人工走查，记录从打开入口到找到证据及下一步所需的操作。若现有入口已经足够直接，就不为这三个场景开发新功能。

### 可讨论的最小切片

先只选一个痛点，把现有事实显示为“对象、需要谁、下一步、证据入口”。例如复验项可以同时链接任务、报告和已有复验入口；投递项可以直接显示当前原因和既有恢复动作。这里的字段只是评审表达，不是新增 API schema。

使用者与 PM 的待办不宜混为一个队列：PM 能自行完成的复验，不应变成要求用户回答的问题。没有观察到结构化问题时，也不宜从报告自由文本里猜测一条“等用户”的记录。

本项目的视图还可能来自不同缓存时刻。状态组合矛盾时，保留各项事实及来源比强行归成“正常”更诚实；是否需要增加新鲜度说明，由走查结果决定。

### 可以退休什么，以及何时不做

如果采用这一方向，优先替换重复摘要和同一事实的重复展开，保留原始证据链接。不要另建一个人工维护的待办文件，也不要在面板里复制第二套 pending 规则。

若收益依赖解析所有历史报告、增加持续扫描、修改叫醒策略或引入新的问题状态机，就已超出最小展示切片，适合退回单独讨论。首页改排并不自动授权改变 Pulse 叫醒语义。

相关规格入口：[panel](../../../openspec/specs/panel/spec.md)、[board-and-status](../../../openspec/specs/board-and-status/spec.md)、[watchdog](../../../openspec/specs/watchdog/spec.md)。

## 5. 候选 B：沿用已有状态权威，减少跨文件补偿

### 已观察到什么

DSH 的 [Engine](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/src/core/engine.ts) 是领域修改入口；[Effects](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/src/app/effects.ts) 把后续动作持久化，集中表达并发限制、退避和失败状态；[Outbox](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/src/app/outbox.ts) 在一个事务内记录回执并排入发送动作。

本项目已存在两类相关实践：派单 committed assignment 的事务约束，以及提醒域的 `state-authority.mjs`。提醒域使用锁和原子 JSON 快照，不是 SQLite；现有快照也不包含整个团队账本。其手册明确说明本构建还没有提醒投递和 PM 唤醒，因此不能将它当作已完成的通用调度系统。

### 真正值得问的问题

下一次遇到“一个命令写入几个位置，随后靠扫描核对一致性”的实际问题时，先画出该命令的写入顺序及失败返回点，定位哪个事实有多个写入者、哪个恢复判断在多个地方重复。

现在不预设“所有文件都应该进同一个数据库”。独立、职责清楚的文件并不是问题；需要反复补偿同一操作的中间态，才可能成为收敛理由。

### 可讨论的最小切片

选一个操作及其一组状态，复用现有权威入口或收敛该域的现有写入口，使读侧消费同一事实。立项依据应包含一个当前确实存在的失败窗口，以及迁移后能够删除的补偿逻辑。

不建议把提醒域的 authority 直接扩成所有模块的中心。它的定位、锁、快照和兼容范围已经构成契约；扩大职责需要重新评估，而不是给它不断加字段。

### 关键边界：本地原子不等于外部恰好一次

事务可以保证“本地状态与发送意图一起存在”，但不能单独保证外部消息只出现一次。远端已经执行、进程却在回执落盘前退出，仍会留下不确定窗口。DSH 的持久队列也不能仅凭结构消除这个问题。

本项目已有“不确定不盲目重发”的约束，提醒手册也区分 `intent`、`observed` 与 `unknown`。这些事实不能被“统一队列会自动重试”的口号覆盖。后续若讨论复用队列，应分别分析目标是否可去重、是否可查询结果、是否具有不可重复副作用。

特别是回复保存和通知唤醒，不宜仅因都有“发送”这个词就合并：它们的业务成功含义、观察点和恢复约束并不相同。

### 可以退休什么，以及何时不做

可退休对象是同一操作的重复写入口、补偿扫描或状态副本，不是审计证据。若无法点名被替代的旧逻辑，或没有实际失败反例，建议保持现状。

相关规格入口：[dispatch](../../../openspec/specs/dispatch/spec.md)、[notify-and-inbox](../../../openspec/specs/notify-and-inbox/spec.md)、[delivery-guard](../../../openspec/specs/delivery-guard/spec.md)、[key-replies](../../../openspec/specs/key-replies/spec.md)；提醒开发范围另读 [agent-self-reminder](../../../openspec/changes/agent-self-reminder/proposal.md)。

## 6. 候选 C：检查执行关联是否完整，而不是再建 Assignment

### 已观察到什么

DSH 的 [领域模型](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/docs/001-domain.md) 将工作与执行绑定分开，允许一个 Ticket 历经多个 Assignment；[执行文档](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/docs/003-execution.md) 描述重试、重启和恢复。

Teamsmith 也已经有 assignment。`cmd-agents.sh` 写入 `assignment_version`、task、taskfile、category、branch、worktree、window、seat、model、selected_via、launch_via、sid、launch_nonce、started 等；`common.sh` 有统一解析与运行证明。`dispatch` 规格明确规定完整身份、同任务恢复和派单事务。

所以，上轮研究中“任务与执行分离”的建议，应理解为核查现有机制是否覆盖实际恢复路径，不能解释成“本项目缺失 Assignment，应该新增”。

### 有价值的探索场景

可选择一个已有恢复实例，追踪任务、分支、SID、作业与报告的关联；也可在后续确实发生项目规则允许的额度换模时，观察旧证据与新 SID 是否容易区分。

这里有两个不同问题：当前执行身份是否可信，以及旧执行的历史是否方便追溯。前者已有契约；后者是否值得产品化，要看当前证据路径是否足够。缺少方便的聚合展示不等于身份机制失效。

“旧执行的完成通知会覆盖新执行”目前只是值得检查的反例类型，本研究没有复现它，不能作为已确认缺陷写入任务书。

### 取舍

优先沿用 nonce、SID 和已有证据路径；能靠已有字段说明的，不增加另一套 run ID、attempt ID 或执行账本。若实际发现旧记录被覆盖导致关键证据无法恢复，再由 PM 决定补历史引用还是调整记录方式。

模型更换继续受 [AGENTS 项目规则](../../../AGENTS.md) 约束：普通连接错误不代表额度耗尽；本文不提供自动换模授权。也不建议照搬 DSH 的所有重启行为，例如它会在 Assignment 结束时清理所属背景工作，而 Teamsmith 的 detached 作业有自己的存续约定。

相关规格入口：[dispatch](../../../openspec/specs/dispatch/spec.md)、[watchdog](../../../openspec/specs/watchdog/spec.md)、[background-jobs](../../../openspec/specs/background-jobs/spec.md)、[verification](../../../openspec/specs/verification/spec.md)。

## 7. 候选 D：用确定性测试替代一部分重型运行

### 已观察到什么

DSH 的 [核心测试](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/tests/core-engine.spec.ts) 使用内存仓库与假的执行器、评估器；[队列测试](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/tests/effects.spec.ts) 注入时间，推进时钟验证退避和事务结果。其 [ports](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/src/core/ports.ts) 让业务逻辑依赖较窄接口。

本项目已有纯函数、独立状态模块、FAST/选段测试及一阶/二阶分频。本方向不是“再增加测试分层”，而是继续减少不必依赖真实 pane 的行为检查。

### 如何选择第一个样本

建议 PM 从近期门禁日志选择一个耗时或环境敏感的测试组，再确认它验证的是规则还是接口。如果红绿只取决于状态、输入与时间，例如派生分类、退避计算或去重规则，就有可能迁为确定性测试。

真实 Pi 注入、输入框行为、进程身份、tmux 生命周期和背景作业完成唤醒仍涉及真实接口，不能仅用 mock 的绿色替代。切片边界应由它在验证什么决定，不能由“运行慢”单独决定。

### 探索后的证据应回答什么

评审者需要看到：迁移前后检查的是同一项产品行为；破坏该行为仍能得到红侧；被删除的是哪条重型执行路径；真实接口覆盖留在哪里。若只是新增一套快测试、旧套件照跑，维护成本可能反而增加。

时间和资源读数只作为参考，附带环境和执行范围，不设负载敏感的性能门禁。也不建议为了测试给产品增加自检命令或测试专用分支。

### 不宜照搬的部分

DSH 同时存在文档、类注释、提示词和结构一致性测试。本文没有证明它的测试总成本低于 Teamsmith，也不建议移植其全部测试目录。值得借鉴的是独立验证业务逻辑的能力，而不是更多检查种类。

相关依据：[测试说明](../../../skills/teamsmith/tests/README.md)、[meta-suite](../../../skills/teamsmith/tests/meta-suite.sh)、[代码与复杂度纪律](../../../AGENTS.md)、[verification spec](../../../openspec/specs/verification/spec.md)。

## 8. 候选 E：检查真实上下文装配，继续减少重复指令

### 已观察到什么

DSH 的 [提示词文档](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/docs/004-prompts.md) 描述角色、共享规则、团队段落与动态策略的装配顺序，并保存覆盖所依据的默认版本。把动态策略放在末尾，旨在减少前部变化；本研究没有测量缓存命中或 token 成本。

本项目近期已完成指令上下文瘦身，见 [已归档提案](../../../openspec/changes/archive/2026-11-04-instruction-context-slimming/proposal.md)。本地回复保存也已采用显式标记捕获，不能恢复旧的“先手动保存再重复回答”路径。

### 下一步值得做的检查

如果 PM 仍观察到重复指令、职责冲突或上下文浪费，可以选择一个真实 PM 启动和一个 worker 派单，记录当次实际装配的材料及随后按需读取的材料。模板文件变小，只能说明文件变小，不能直接代表每个回合输入变小。

建议分别统计原始字节、实际加载范围和重复段落；没有可信 tokenizer 时，不将字节估算包装成精确 token 计数。不记录凭据、环境中的敏感值或无关历史内容。

若问题仅来自重复表述，优先删除重复并保留一个准确入口。只有当多个项目确实遇到默认升级与自定义覆盖冲突，才值得讨论类似 DSH 的覆盖基线与升级差异界面。

### 取舍

Teamsmith 的 PM 可以减少机械工作，但仍需要技术判断、独立复验与合并决策。DSH 的“主会话只路由”不适合直接转成 PM 职责收缩。

不建议为这次探索建立提示词注册中心、热更新服务或新配置框架；也不自动刷新本项目受管 AGENTS、共享技能安装和运行会话。这些是不同的采用操作，研究文档不替代它们的权限与审阅。

相关入口：[init-skill spec](../../../openspec/specs/init-skill/spec.md)、[migration](../../../skills/teamsmith/references/migration.md)、[key-replies spec](../../../openspec/specs/key-replies/spec.md)。

## 9. 候选 F：将外部反馈作为上下文，谨慎讨论新工作入口

### 已观察到什么

DSH 将 Source、Trigger、Thread、Subscription 与 Mandate 分开。订阅消息可以补充上下文，但不授予新权限；主动候选支持先观察、后自动接单的模式。[领域模型](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/docs/001-domain.md)、[授权文档](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/docs/002-authorization.md)

本项目 [ROADMAP](../ROADMAP.md) 已记载外部仓库平面融合的讨论，并明确当时未立项。本次用户要求研究与写文档，也没有将该议题转成接入开发。

### 未来若重启讨论，哪些问题最有用

- 想减少的究竟是 PM 手工搬运反馈，还是让外部消息启动新任务？这两者的成本与权限范围不同。
- GitHub 评论、CI 与机器人评审哪些只供当前任务参考，哪些可以成为待分诊候选？
- 同一事件从通知和轮询重复到达时，怎样对应同一个外部事实？
- 多人参与同一线程时，谁能扩展原任务范围，谁只能提供上下文？
- 工作已经结束后，新评论应该恢复原任务还是产生新候选？当前项目是否真的需要自动恢复？

最小研究可以先人工记录少量已有 Issue/PR 的来源、关联任务和处理结果，了解搬运成本；不要求新增监听器、账号、bot 或对外回复。若以后采用自动候选，观察模式值得作为评估手段，而不是直接开启自动派单。

### 不宜照搬的部分

DSH 某些跟进消息可以绕过新工作 Eval，以既有 Mandate 继续，并将范围判断交执行器。Teamsmith 的任务书、所有权与变更审批更严格，不能把整个外部线程解释成持续开发授权。

也不建议立即引入完整 Source/Thread/Subscription/Policy 系统或跨平台身份映射。外部来源可以先是已有候选入口的一项引用，是否需要新领域对象由实际工作量决定。

## 10. 不建议直接采纳的机制

| 机制 | 当前不直接采用的依据 | 以后什么证据可能改变判断 |
|---|---|---|
| 将 PM 降为纯路由器 | 当前产品定位包含独立判断和复验；DSH 的职责不同 | 项目明确调整产品定位，且独立职责有新的承担者 |
| 全仓 Shell/文件状态迁移到 TypeScript/SQLite | 本地已有可复用状态边界；没有测量证明存储技术是主要瓶颈 | 一个具体事务问题无法通过现有边界合理解决，且迁移收益可证明 |
| 新建通用事件总线和插件平台 | 当前外部来源尚未立项，存在先建平台后找场景的风险 | 多个已采用来源确实共享一组稳定行为 |
| 自动恢复所有停止 worker | 与 Pulse 只报告、不自行管理席位的既有边界冲突 | 用户明确调整该职责且另行完成规格讨论 |
| 所有外部副作用无限重试 | 不能消除执行成功后丢回执的不确定窗口 | 具体目标具备可证明的去重或结果查询能力 |
| 按行数阈值直接自动合并 | DSH 的交付策略不等同于本项目独立验证与合并职责 | 用户另行改变合并政策，而非由本文推导 |
| 新增一个“管理所有管理状态”的守卫 | 与当前净零守卫及复杂度纪律相冲突 | 有具体不能由产品行为表达的问题及旧守卫退休安排 |

## 11. 建议的讨论次序与停损点

这张表用于取舍，不是任务板、排期或已分配的工作；候选字母不是任务 ID。

| 次序 | 候选 | 首次探索的范围 | 相对成本依据 | 继续的理由 | 停下的理由 |
|---|---|---|---|---|---|
| 优先讨论 | A：下一步行动视图 | 一个现有待办的查找路径 | 低至中：展示可小改，涉及派生逻辑则扩面 | 确实减少查询与证据查找步骤 | 现有入口已直接，或必须引入新状态系统 |
| 优先讨论 | D：确定性测试替代 | 一个测试组及其产品行为 | 中：需要确认逻辑边界与退休旧执行路径 | 同一行为更易复现，原重型路径可删除 | mock 掩盖真实接口，或快慢套件只能重复维护 |
| 有现场再讨论 | B：状态写入收敛 | 一次操作的具体失败窗口 | 中至高：可能涉及兼容、恢复与旧状态 | 能退休补偿逻辑并解释迁移边界 | 没有反例，只是希望技术栈更整齐 |
| 有现场再讨论 | C：执行关联 | 一次恢复或额度切换的证据链 | 低至中：先查已有身份，再判断是否缺历史 | 找到真实的归属或追溯缺口 | 现有 nonce/SID 与证据已足够 |
| 低成本复查 | E：上下文装配 | 一个 PM 与 worker 样本 | 低：先审阅实际输入，不建平台 | 找到重复加载或矛盾指令 | 只有模板体积变化，没有使用问题 |
| 保留讨论 | F：外部反馈 | 少量现有反馈的人工关联 | 接入成本高，人工观察成本较低 | 用户再次采纳方向且搬运成本明确 | 仅因对方有此能力就想增加外部服务 |

建议第一轮最多选择 A、D 两项进行证据探索，不先打包成一个“大型架构优化”变更。B/C/F 可以不立项；若没有新证据，研究结论就是暂不改变。

在进入开发前，PM 可以要求提案者用一个具体场景说明：当前多做了什么、改变后省掉什么、删除哪个旧展示或执行路径、哪些行为继续由既有规格约束。回答不了“删什么”的方向，先缩小范围。

## 12. 如何接入本项目既有开发流程

这部分只给出处和操作顺序，不代写新任务书或新规格。

1. PM 先复核候选与已有候选/在飞 change 是否重合，入口为 [PRODUCT-PROPOSALS](../PRODUCT-PROPOSALS.md)、[BOARD](../BOARD.md) 与 `openspec/changes/`。不要仅凭旧 ROADMAP 快照判断当前排期。
2. 产品方向的采纳按候选入口既有权限进行。研究优先级不构成用户已采纳；可复现工程缺陷按既有缺陷权限处理。
3. 获准探索后，按 [OpenSpec 相位说明](../../../skills/teamsmith/references/openspec.md) 组织工作。本文提供证据入口，正式 brief 负责实际 scope、category、锚点、owner 与命令。
4. 行为变化及最终方案进入对应 OpenSpec change；新任务书引用该 change，而不是复制本文形成第二套契约。
5. 提案审查通过后才安排 apply，独立 verify 仍由不同作者完成。共享文件依 [OWNERSHIP](../OWNERSHIP.md) 明授，避免多个切片并发改 `common.sh`、面板数据层或同一测试清单。
6. PM 在独立 checkout 核验最终证据。归档、采用共享源、刷新项目指令和发布仍遵循各自既有条件，不因“研究已完成”而合并为一次操作。

### 门禁口径需要特别注意

当前读取到的受管 AGENTS 仍列 `openspec validate --all --strict`；但 [CONTRIBUTING](../../../CONTRIBUTING.md)、[CI](../../../.github/workflows/gates.yml)、[容器入口](../../../ci/Containerfile) 与 [DECISIONS](../DECISIONS.md) 的 P407 裁定记载本仓因 OpenSpec 1.16 长需求 warning 暂用非 strict，目标是完成拆分后恢复 strict。

因此，本文不替 PM 重新选择门禁或修改配置。后续 brief 应核对当时生效的项目裁定和配置，明确实际命令、覆盖范围与例外依据；不能把产品对新项目的默认口径误写成本仓本次实跑结果。

一阶/二阶分频已存在。确定性测试迁移也不意味着自动提高二阶套件频率或新增全量运行次数。具体检查由变更影响决定，性能读数继续只是参考。

## 13. PM 首轮讨论可用的问题

以下是决策议题，不是待实现需求。

| 议题 | 研究者建议 | 需要 PM 带回的依据 |
|---|---|---|
| 首要目标是什么 | 先减少 PM 查找步骤和测试维护成本 | 最近一轮真实工作中哪项最耗注意力 |
| A 是改首页还是改底层待办 | 从一个已有条目的展示开始 | 当前 pending/digest 是否已有所需事实 |
| “等用户”是否有结构化来源 | 先盘点，避免读自由文本猜测 | 现有问题提出、解决和记录路径 |
| 首个测试迁移选哪组 | 选只依赖状态/输入/时间的行为 | 对应测试、真实接口边界及可退休路径 |
| 是否要扩大 authority | 暂不做全局扩展 | 一个具体失败窗口与现有方案不足 |
| 是否缺执行历史 | 先用 nonce/SID 追一次现场 | 当前证据链中实际断掉的位置 |
| 是否立项外部来源 | 本轮先保留讨论 | 用户方向采纳与人工搬运成本 |
| 是否再做提示词平台 | 先审一个实际装配样本 | 重复输入或升级冲突的具体记录 |

讨论后，记录采纳、驳回或搁置及理由即可；无需为每个研究候选都创建任务。已进入正式 change 的内容在本文保留链接即可，不回填一套持续更新的实现状态。

## 14. 研究依据索引

### 外部：定位与机制

| 入口 | 主要支持的论点 |
|---|---|
| [000 Philosophy](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/docs/000-philosophy.md) | 人的注意力是成本，概念、设置和消息需要有价值 |
| [001 Domain](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/docs/001-domain.md) | 工作、执行绑定、上下文与授权分离 |
| [002 Authorization](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/docs/002-authorization.md) | 准入、观察模式、跟进与恢复边界 |
| [003 Execution](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/docs/003-execution.md) | 背景工作、执行槽位、失败、重试和恢复 |
| [004 Prompts](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/docs/004-prompts.md) | 角色装配、团队覆盖、动态内容与结构化问题 |
| [005 Panel](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/docs/005-panel.md) | 先展示行动，再展示健康与历史 |
| [007 Architecture](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/docs/007-architecture.md) | 单写入者、窄接口、持久动作与测试分布 |
| [Background 实现](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/src/executor/background.ts) | 背景工作归属及宿主生命周期能力 |
| [Worker handoff 提示](https://github.com/deepseek-ai/dsh-superagent-prototype/blob/8c32a9dc5d72c033816c6a8110b37f40cf94fba4/prompts/handoff-worker.md) | 将需要人回答的问题单独表达，并明确清除已解决问题 |

代码与测试的具体链接在各候选正文中，建议按候选阅读，不必先通读外部仓库。

### 本地：接手阅读顺序

建议依次读本文件第 1、11、13 节，再定位所选候选正文，随后阅读该候选指向的规格及实现。项目规则以 [AGENTS](../../../AGENTS.md) 与正式规格为准；研发流程以 [OpenSpec 说明](../../../skills/teamsmith/references/openspec.md) 为入口。

本文件没有产生正式任务 ID、OpenSpec change、迁移、运行席位调整或对外消息，也没有给出任何运行测试已通过的结论。交付对象是可供 PM 独立讨论和取舍的研究材料。

## 15. 本次文档检查记录

2026-11-05 使用 Python `pathlib` 与正则提取 Markdown 链接，逐个检查相对本文件的本地目标是否存在，并检查冲突标记及外部源码引用是否固定版本。结果：55 个本地链接、38 个不同目标，缺失 0；26 个外部链接、19 个不同地址，源码及目录引用均固定在上述提交；未发现冲突标记。

这是文档完整性检查，外部链接的内容依据本次源码阅读；没有对所有外部链接另做 HTTP 可达性测试。没有运行 OpenSpec、smoke 或 DSH 测试，因为本次只新增研究文档，未改变产品、规格、配置或测试。
