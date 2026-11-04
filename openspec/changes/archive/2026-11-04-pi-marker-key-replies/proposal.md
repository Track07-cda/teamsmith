## Why

PM 目前必须先调用 `team reply post`、再在会话重复同一正文，才能把给用户的完整回答留在回复页。改为普通回答末尾的显式标记，由 PM 专用 Pi 扩展保存到原回复库，取消日常双写步骤，同时保留用户已接受的流式短暂可见边界。

## What Changes

- 默认流程变为“PM 正常回答并在末尾标记；扩展保存完整净化正文”。未标记不发布；`team reply post` 保留为人工补录/恢复。**BREAKING**：移除先 post 再重复回答的默认职责，三处指令与可运行捕获路径同批交付。
- 只识别代码区外的独立控制行 `[[team-reply]]` / `[[team-reply:标题]]`。所有 assistant 终态均清理完整控制行；只有本次活动最后一条、成功且完成 settled 资格绑定的消息才可发布。普通示例、未完成前缀和正文其余字节保持不变。
- 一个 PM 定向扩展、一份窄 parser/原 offset 映射、一份 source 操作 journal，复用既有 writer 和编号库。每个稳定来源最多一次自动尝试；不确定结果不自动重发，不承诺 exactly-once 或最终必达。
- 内置 PM 启动注入一次，核验真实项目/配置/state、tmux、进程及会话证据；补齐模块指纹与 doctor 的“磁盘存在”和“当前 PM 已加载”区分。首次注入需要经授权重启，已有入口才可 reload。
- 以真实产品 parser、真实 writer、私有 Pi/受控模型和实际 marker 的原始 pty 证据替换旧默认 CLI guide 验收。明确模型遵从率、任意闪现时限和实时团队采用均未获证明。

## Capabilities

### New Capabilities

无；不新建第二套回复能力。

### Modified Capabilities

- `key-replies`：实际修改三个既有 requirement，替换默认 CLI 双写职责并保留人工 stdin/重复提交行为；增加控制行保真、来源资格/一次尝试/恢复合同。
- `pm-lifecycle`：定向 PM 注入及真实身份；保留 reload 请求仅记账，区分首次注入重启与已加载扩展刷新。
- `memory-and-deps`：更新指纹覆盖捕获入口及依赖；诊断须区分磁盘、启动参数与可核实的运行时装载证据，不扩展冻结 adapter seam。
- `verification`：捕获行为所需证据层、故障与变异反例，复用既有 reply 门禁入口，不新增独立健康/流程守卫。

## Impact

计划涉及 `skills/teamsmith/extension/team-reply.ts`、窄 `scripts/reply-capture.mjs`、现有 `scripts/replies.mjs` 的纯输入验证复用、`scripts/lib/{common,cmd-update,cmd-project}.sh`，以及 `templates/pm-prompt.md.tmpl`、`references/protocol.md` §4b、`SKILL.md` 和既有 reply/PM/extension 测试。Pulse/CLI 编号、分页、原文、原子可见、receipt 与只读合同不变；不读 session/journal 来刷新页面。

无新配置键、provider 改写、daemon、scheduler、worker 捕获、slash 命令或 adapter placeholder。不将入口安装到普通 Pi 的 `.pi/extensions/`，不改变 `/team` 的单命令合同。未标记路径只做内存判断，不因该消息访问 journal/store、启动进程或调用模型；运行时注册及已有生命周期的 eligible 恢复是独立动作。

P393 的既有 say 改动独立且先串行完成其 `SKILL.md` 编辑。P391 的关键回复指令继续等待本提案评审和可运行捕获路径，不另立平行提案。实现、独立验证、正式 PM 提案评审、真实团队采用和归档是分别授权的步骤；本次仅交规划产物，不创建 Apply 任务书。

既有 `key-replies` Purpose 的绝对排斥 Pi reader 表述也须在获准归档时作窄化。OpenSpec 不会合并既有能力 delta 的 Purpose，因此具体 canonical Purpose 替换列在 `design.md` 的迁移计划中，只在一次性副本演练，本次不改 canonical specs。
