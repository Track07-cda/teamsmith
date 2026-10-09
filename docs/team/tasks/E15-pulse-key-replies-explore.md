# E15 · Pulse 关键回复页：入口与复用机制探索

task: E15
agent: dev2
phase: explore
category: routine
change: -
specs: panel#The console composes four pages and remembers the position
anchor: specs
deltas: -
branch: task/E15-pulse-key-replies-explore
deps: D104

## 已确认的输入与阶段

真实使用反馈：PM 的实质答复和待用户确认的消息会被后续自动消息与响应埋没，用户反复翻阅很长历史才能找到。用户已经选择方向并于 2026-10-09 批准进入探索与提案：**在现有 Pulse 面板增加关键回复查看页面，Agent 在回复前通过工具或 team CLI 主动发布当前关键回复正文**。降噪先不做，不另造审批/待办系统；不用重新询问用户该功能是否有必要。

此任务是限范围的只读探索，不是提案或实现。先核对现成 CLI/面板/详情 viewer/持久化和工具薄封装入口，交一个可进入正式提案的推荐。只有 PM 接受此探索后，你才在新的 propose 任务创建 change（拟议名 `pulse-key-replies`）；explore/propose 可以同一 owner，不能合在一份 brief。未来实现者不是你。

这是已有入口和复用点的限定调查，显式用快模型及 fresh；当前 category 不表示新任务模型引擎已生效。后续涉及正式接口/架构的提案由 PM 按强模型名额排队，必要时新会话交接。

## 阅读顺序

1. `AGENTS.md`、自己线程最后条目、此 brief、`docs/team/OWNERSHIP.md`。
2. D104、`skills/teamsmith/references/openspec.md` 和 explore workflow；未生成 workflow 时读取现有 OpenSpec 1.8.0 模板及 store-selection 交叉文档，不执行 init/install。
3. `openspec/specs/panel/spec.md` 全文、相关 `notify-and-inbox`/`memory-and-deps`/`boundary` specs 与 CLI/面板 source。特别核对四页组成、markdown detail viewer、异步 bounded 数据帧、安全显示、所有页发信及只读边界。
4. 在 `openspec/changes/task-model-routing/` 只读 design 和 panel delta：模型路由 S1 已另派，S2 尚未开始；你的计划必须指出未来 panel/shared CLI 路径冲突和 canonical/delta 接手顺序，不能把本功能塞进它。

如果研究 Pi extension 的工具注册接口，遵守本机 Pi 文档要求：完整阅读相关 extensions/SDK .md 与必要交叉文档；只设计调用 team CLI 的薄封装，不接管 Pi 消息历史、发布钩子或推理内容。没有触达这部分则如实标记尚未研究，不凭记忆编接口。

## 调查与交付

按现成 source 和公开文档形成一份可独立阅读的报告 `docs/team/reports/E15-dev2.md`，事实、推荐和未测分别标注。报告回答：

- 现有列表/全文查看/滚动/键盘鼠标/zh-en strings 的复用点和证据位置，新增页将触及哪条现有规格；避免再建 TUI 或 duplicating detail renderer。
- 正文在回复前显式传入的最小 CLI 接口与工具封装选择。工具成功保存不等于 Pi 已发送，不能读取聊天历史或模拟送达回执。说明如何使 Agent 正常发送同样正文、如何提示保存失败而不阻断答复；不靠自动重要性分类。
- 作者/标题/编号/时间/原文的最小存储与只读数据路径。原文落盘默认不入公开仓，项目作用域、原子写/碰撞或并发、重启后的读取、完整正文与 bounded 面板帧怎样兼容；展示最新标题不能覆盖旧条目。
- 主页面入口与关键回复页的建议交互、空/失败/窄屏/长文状态，区分存储原文和安全显示。用小示意说明用户如何从 Pulse 找到答复，无需做页面或真实栈。
- 可以实测哪些复用点、下一阶段哪些反例能使未来实现失败。没有渲染/CLI 功能时不宣称已经可用，不拿源码分析证明体验。
- 建议 delta capability/file 集合、成本和有序任务切片。模型路由设置面与关键回复页同时会改 panel，只能单写者串行交接；明确没有降噪、确认状态机、提醒/搜索平台或其他项目操作。

这些是探索问题，不是第二套需求清单；正式可观察约束应在下一阶段 OpenSpec delta 中定义。不要抄写模型路由提案中的复杂流程，也不要扩成泛化消息中心。

## 权限与禁止事项

唯一 versioned 写权限是自己的 `docs/team/reports/E15-dev2.md`；自建 scratch/证据放仓外 `pm-skills-ledger/team/reports/E15-dev2/`。source/specs/规划工件都只读。不修改 code/tests/UI/bundle/README、现有或新 change、canonical specs、OpenSpec 配置、AGENTS、PM 的任务书/看板/决策/评审/ownership、真实 `.pi`/会话记录。

不读取任何真实 Pi 聊天或凭据，不模拟用户身份，不启动业务服务或临时共享栈、不发布真实关键回复、不安装依赖、不修改全局 skill/source、不推送/PR/MR/合并/归档。只读实测若需独立夹具先证明 fixture HOME/TEAM 根和独立 tmux socket；不能在现有 teamsmith:pulse 做原型或改偏好。

## 记录检查

控制工具固定指向 PM 主检出，不运行被测 worktree 的变化版 CLI 操作真实团队：

```bash
CONTROL_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd -P)"
CONTROL="$CONTROL_ROOT/skills/teamsmith/scripts/team"
EVIDENCE="$CONTROL_ROOT/../pm-skills-ledger/team/reports/E15-dev2"
mkdir -p "$EVIDENCE"
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" context --json
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$CONTROL_ROOT/.pi/team/forbidden-names.txt"
git diff --check
bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/E15-dev2.md
```

此阶段资料-only，不跑全量/产品 smoke，不用门禁绿替代产品证据。记录实跑命令、rc、scope audit、未跑項、输入/输出 tip 和证据位置；长任务用 background 并收割。

使用 Conventional Commits，含 E15、`Agent: dev2` trailer。报告提交后树干净、仍在自己任务分支，通知 **pm**：`bash "$CONTROL" notify pm "E15 (Pulse key replies exploration): <结果或 BLOCKED>"`。生成提示里把接收人写成自己是旧缺陷，不照做不修复。只完成本阶段，不自行发起 propose 或 apply。
