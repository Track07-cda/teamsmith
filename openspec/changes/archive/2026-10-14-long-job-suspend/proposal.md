# long-job-suspend · 长作业车道：起完就结束回合、叫醒带结果

## Why

工人提示词（`scripts/lib/cmd-agents.sh` 的后台车道段）与 `extension/team-bg.ts` 两个工具的
description/promptGuidelines 今天只给职责不给目的：「Harvest every job before your turn ends」，并把
「未收割被叫醒」写成一种损失。于是 agent 把长作业起完立刻原地 `team_bg_wait` —— 后台车道名存实亡，
等作业的几十分钟里 agent 答不了话也不能并行推进别的事（D125：时间成本比 token 成本更宝贵）。
PM 提示词模板（`templates/pm-prompt.md.tmpl`）早就写着正确口径（起、结束回合、叫醒时收割），
说明正确措辞存在，只是没进工人那段。同源的还有两个缺口：协议只承认两种回合结束状态（交付 /
`BLOCKED:`），故意的「挂起等作业」没有合法身份，落到 PM 收件箱里长成 `⚠ 未提交 N 个文件 ·
[auto·interrupted]` 的中断形状；车道的账本（`state/bg.log`）只记叫醒与回合收尾，不记作业的起与收，
「起了就等」今天无法从事后证据里数出来。

## What Changes

- 车道用法从「职责」改回「目的」：工人提示词的后台车道段、两个工具的 description / promptGuidelines /
  起作业回执文本一律改写为「起完默认结束回合，完成叫醒把结果带回来再收割」；原地等是有界例外
  （预期在文本点名的内联等待预算内完成 + 结果卡住下一步 + 没有别的可推进），不再有
  「回合结束前必须收割」的措辞，叫醒不得再被写成惩罚。
- 协议补第三种合法回合结束状态：**挂起等后台作业**（不是放弃、不是中断）。工人简报的
  「Never stop mid-task」段、`templates/AGENTS.section.md.tmpl` 的纪律条、`references/protocol.md`
  各落同一份三态合同；挂起要求回合最后一行点名在等的 job id。
- 挂起对 PM 可见且不误报：turn-end 通知在「回合已完成 + 本会话还有在跑的作业」时改打
  `[auto·suspended]` 标签并带 `awaiting=<id>[,…]` 字段，挂起行省略 ⚠ 未提交告警前缀
  （`uncommitted=<n>` 字段保留）；真中断（`[auto·interrupted]`）在仍有作业在跑时同样带
  `awaiting=` 字段。在跑集合从**车道自己写记录的那个目录**（`state/bg/*.job`）读，按车道自己的规则解析（显式
  `TEAM_STATE_DIR` 优先，否则车道自己的工作树/项目根规则），逐条做 `(pid, start-time)` 活体验证
  （与 `team bg list` 同一条身份规则）；通知侧不得拿自己的项目根顶替车道的目录 —— 本仓 `.pi/` 被
  gitignore、worktree 不带 config，两者今天恰好同落主工作树，而夹具形状（worktree 自带 config）下会分叉。
- 车道账本可计数：`state/bg.log` 新增 `start id=… pid=…`（返回 id 前）与
  `wait id=… outcome=<harvested|running|interrupted> waited_s=…`（每次 `team_bg_wait` 返回）两类行；
  既有 `wake` / `settled-with-unharvested` / `stop` 行形状不变。「起了就等」与「挂起后被叫醒再收」
  从此可以只凭账本区分并审计。
- 叫醒不可达的兜底写进合同：会话进程没了（作业是 detached 的，不受影响）由既有
  「任务未完成 + 窗口不在」巡检待办与席位死亡敲门兜底，续跑后的提示词引导先查
  `state/bg.log` / `team bg list` 再继续；被叫醒时先收割核对再推进。不改叫醒的传输机制。

不在范围：叫醒的传输机制、工具名、Pi 自身行为、非 Pi 适配器的另一套车道；不顺手改派单/身份相关代码。

## Capabilities

### New Capabilities

- `background-jobs`: 会话侧后台车道 —— team-bg 扩展的工具面合同（措辞）、完成叫醒纪律与车道自己账本的
  可计数事件、重启后「作业留证但不回收入表」。（CLI 的 `team bg list/stop` 一侧已由 `boundary` 覆盖，
  本能力不重复。）

### Modified Capabilities

- `dispatch`: 新增工人提示词合同 —— 后台车道按目的教学、三种合法回合结束状态、续跑先查盘上证据，
  以及同一份合同在 AGENTS 模板与 references 的一致落地。
- `notify-and-inbox`: 修改「A turn-end notification appends one inbox line and knocks once」——
  挂起与中断在标签与字段上区分，在跑集合的判定规则（车道目录里的记录 + 活体验证）。

任务书头字段写的预期落点是 `agent-adapters, dispatch`；实际落点的偏离与理由见 design 的
「落点与任务书头字段」一节（`agent-adapters` 不动：内置启动命令逐字节不变；工具面合同落在新能力
`background-jobs`；挂起可见性落在 `notify-and-inbox`）。

## Impact

- 代码：`skills/teamsmith/extension/team-bg.ts`（措辞 + 两类账本行）、
  `skills/teamsmith/extension/team-notify.ts`（挂起判定与标签/字段）、
  `skills/teamsmith/scripts/lib/cmd-agents.sh`（工人提示词的后台车道段、三态段、续跑行）。
- 文档/模板：`templates/AGENTS.section.md.tmpl`、`references/protocol.md`、
  `references/workflows.md` §E2；`templates/pm-prompt.md.tmpl` 与 `SKILL.md` 核对后预计不动
  （现状已是正确口径）。
- 测试：A 刀先在新的独立入口（`tests/bg-ledger.sh`）里落断言 —— 不碰 S1 拥有的 `smoke.sh`；B 刀把用例
  折回 smoke §13（notify）/ §13c（后台车道）并登记 section-select 映射。今天没有任何门禁钉提示词文本，
  本 change 首次钉上。
- 兼容性：**BREAKING（行为口径）** —— 工人不再被要求在回合结束前收割；PM 收件箱新增
  `[auto·suspended]` 标签与 `awaiting=` 字段（旧标签不变，新增不覆盖）。账本新行是追加形状，
  旧读者不受影响。内置 Pi 启动命令（`-e` 集合与顺序）逐字节不变。
- 排期：`task-model-routing` 的 S1 正在改写 `cmd-agents.sh`、S3 拥有 `templates/**` 与
  `references/**`；本 change 的 apply 与它们的交接/串行约束见 design 与 tasks。

本轮仅提案：不派 apply、不勾实现任务、不改产品代码；apply、独立 verify、归档各需各自授权。
