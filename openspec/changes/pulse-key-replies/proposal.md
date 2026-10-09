## Why

Agent 的关键答复目前留在不断增长的聊天记录里，用户回头找完整结论需要翻历史。Pulse 已经是团队的固定观察入口；增加一个明确的「关键回复」页，可以让用户直接找到 Agent 主动保留的正文，而不把普通聊天都搬进面板。

## What Changes

- Agent 使用 `team reply post` 显式保存要保留的正文，随后照常向用户发送同一份答复。保存失败不阻止正常答复，保存回执不代表消息送达或屏幕刷新。
- Pulse 增加固定第 5 页「关键回复 / Key replies」：最新在前，打开条目查看完整正文；通过显式翻页继续找旧答复。总览提供最新标题和跳转入口。
- 复用既有异步分块、列表焦点、只读 markdown、键鼠和中英字符串，分开读取最新摘要、当前列表页和按需正文。
- 新增项目内的持久正文与有界索引读取，支持并发编号、原子可见性、可判定的中断和坏源诊断。不给 outbox、待办、巡逻唤醒或审批流程增加状态。
- **BREAKING（页导航边界）**：顶层页面从四页扩为五页，数字键 `1`–`4` 仍指向原页面，`Tab` 在第 4 页之后进入第 5 页再回总览；设置仍是覆盖层入口，不改成顶层页。

## Capabilities

### New Capabilities

- `key-replies`: 显式发布与只读查询、原文保存、有界可继续列表、稳定编号、故障与安全边界。

### Modified Capabilities

- `panel`: 五页导航、最新回复入口、关键回复列表与全文、异步读源、只读机器出口及键鼠/语言集成。

## Impact

预计影响 `scripts/team`、新增 reply CLI/存储 helper、`common.sh` 的观察命令判别、`cmd-watch.sh` 的面板读块、panel 的 types/data/layout/App/settings/main/strings/markdown 复用、对应测试/快照/发布 bundle，以及 SKILL/协议的主动发布指引。复用现有 JS runtime，不引入数据库或新项目配置键；存储在项目解析所得的 state 内，不读取 Pi 会话。

与 `task-model-routing` 独立规划，但其 panel 设置 requirement 和实际 CLI/UI/文档路径与本项相交。该项的 S1 目前只是冻结候选；本提案不宣称 main 已实现模型路由。采用顺序是模型路由的完整私有交付先冻结、接收，再在独立非部署输入上接入本项；同一 requirement 的最终投影与共享文件交接见 design。`proposal` 文本不承担自动调度依赖。

本轮仅提案；后续 apply、独立 verify、main/共享技能采纳及真实 Pulse 更新均需各自授权。不做降噪、通知、审批/确认/已读状态、聊天解析、Pi 薄工具、隐藏推理或 provider 兼容工程。
