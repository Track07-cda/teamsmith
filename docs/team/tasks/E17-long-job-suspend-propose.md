# E17 · 长作业车道：起完就结束回合、叫醒带结果（正式提案）

task: E17
agent: dev2
phase: propose
category: analysis
change: long-job-suspend
specs: agent-adapters, dispatch
deltas: agent-adapters, dispatch
branch: task/E17-long-job-suspend-propose
deps: -

## 决定与范围

用户 2026-10-10 指出：agent 常把长作业 `team_bg_run` 起完立刻 `team_bg_wait`，那何必起后台；并进一步确认「作业结束时本来就会自动叫醒，不必主动收割」，要求按「**时间成本比 token 成本更宝贵**」的取向立项（D125）。目标不是删掉后台车道，而是把它的用法从「职责」改回「目的」：

1. 工人那段注入提示词（`cmd-agents.sh:136`）与两个工具的 description（`extension/team-bg.ts:259-265`）现在写的是「**Harvest every job before your turn ends**」——只给职责不给目的，并且把「未收割被叫醒」写成惩罚。改为：起完作业**默认结束回合**，让完成叫醒把结果带回来；只在作业很短、或结果卡住下一步且确实没有别的可做时才原地等。
2. 协议现在只允许工人回合以两种状态结束（交付 / `BLOCKED:`，见 `cmd-agents.sh:165-169`）。补第三种合法状态：**挂起等后台作业**（不是放弃、不是中断），并在回合末尾用一行说明在等哪个 job id。
3. 挂起必须对 PM 可见且不误报：现在工人回合结束时若工作树有未提交文件，会自动发一条 `⚠ 未提交 N 个文件 · [auto·interrupted]` 给 PM（今天多次出现，PM 把它读成中断）。故意的挂起不该长成这个形状。
4. 可选但希望论证：让 harness 把作业的**起/醒/收**事件连时间记进日志，使「起了就等」成为可数的事实（PM 今天试过从会话日志估算，arg 记录不可靠，得不出可信数字）；若提案认为不值，请给出反证与替代的可核对信号。

不在范围：叫醒的传输机制、工具名、Pi 自身行为、给非 Pi 适配器另造一套车道；也不要顺手改派单/身份相关代码。

## 现场证据（提案必须引用并核对）

- `skills/teamsmith/scripts/lib/cmd-agents.sh:136`（工人提示词）：`**Long jobs (a gate, a build)**: start them with team_bg_run … then harvest with team_bg_wait <id> … **Harvest every job before your turn ends** -- an unharvested job wakes you once when it finishes, and that costs a turn.`
- `skills/teamsmith/extension/team-bg.ts:259-265`（工具面）：`Harvest it with team_bg_wait before you end your turn; otherwise the team wakes you once when it finishes.` 与 `promptGuidelines` 里的同义句。
- `skills/teamsmith/templates/pm-prompt.md.tmpl:78-79`（PM 侧）：**已经写对了**——「不能让一个几十分钟的门禁卡在回合里：用 `team_bg_run` 起、让回合结束、叫醒时再收割」。说明正确措辞存在，只是没进工人那段；提案要让两者收敛到同一口径。
- 运行实例（今天）：dev 席位在 08:28–08:56 起过 7 个 `p228-r6-*` 后台作业，其中两个各跑约 7 分 30 秒，随后立刻收割；同一天 PM 自己也多数是「起完就等」（跨回合等结果的只有少数）。这类等待期间 agent 答不了话、也不能并行推进别的事。
- 误报实例：今天多条 `⚠ 未提交 N 个文件 · [auto·interrupted]`（例如 `tip=147e233`、`tip=985328b` 两次）——都是回合结束+未提交触发的自动告警，与真实中断混在同一形状里。

## 阶段与写边界

只写 `openspec/changes/long-job-suspend/` 的 proposal / design / tasks / delta specs，不写产品代码、不改 `extension/`、`cmd-agents.sh`、`templates/`、`references/`、`AGENTS.md`。后面由**另一个**席位 apply、再由第三个席位 verify，PM 审提案并归档。

写法按已接受的既有契约：`deltas:` 头里那两个名字是 PM 的预期落点（工具面/提示词合同法在 `agent-adapters`，派单简报在 `dispatch`），**实际落点由你判断**；若与头字段不同，在报告里点名并说明，PM 会改任务书头字段，不由你改。每条 MODIFIED requirement 必须与基线逐场景对照（不许丢场景），新增 requirement 要有反例/红侧思路。设计里要写清：

- 新规则的准确措辞与它落在哪几处（工具 description、promptGuidelines、工人简报、PM 模板、protocol 参考、SKILL 若有）；
- 「原地等」的例外判据（按绝对时长、按作业性质、还是按「下一步是否被卡住」），以及如何避免它被重新解释成「随手等」；
- 第三种回合结束状态的表达（在工人简报的「Never stop mid-task」段、`references/protocol.md`、以及自动通知的判据里各落哪里），以及**挂起与中断在 PM 侧如何区分**（通知文案/字段/是否带 job id）；
- 叫醒不可达时的兜底（会话进程没了会怎样：收件箱告警 + 巡检续跑；被叫醒时先核对 job 状态再继续）；
- 可数性：日志事件若做，写清字段与落在哪个文件；若不做，写清为什么不值。
- 同批序列约束：`task-model-routing` 的 S1 私有实现**正在改写 `cmd-agents.sh`**（其 design 的 S1 所有权列了该文件）。本 change 的 apply 与该 change 的 S1 不能并行写同一文件——把这条写进 design/tasks 的排期说明，别在 apply 时才发现。

## 验收（本阶段）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/E17-dev2.md
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
```

`validate` 必须 `--strict` 通过；每条 MODIFIED 与基线对照不丢场景，新增场景要能证伪（写出红侧思路）。证据包按 D94 放仓外 `pm-skills-ledger/team/reports/E17-dev2/`，报告提交在 `docs/team/reports/E17-dev2.md`。不改产品源码、不合并、不推送、不勾 `tasks.md` 的 apply 项。做完按协议通知 PM。

## 交付

- `openspec/changes/long-job-suspend/{proposal,design,tasks}.md` 与相应 delta specs。
- `docs/team/reports/E17-dev2.md`：改动清单、逐条基线与新增场景、验收命令与 rc、未解问题、以及如果落点与头字段不同时的说明。
