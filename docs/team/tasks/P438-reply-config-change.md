---
id: P438
title: 模型配置变化不得停用关键回复捕获
agent: verify
category: code
phase: apply
change: -
specs: key-replies
anchor: openspec/specs/key-replies/spec.md
deltas: -
branch: task/P438-reply-config-change
---

# P438 · 配置身份判据收窄

## 真实现场

data_ontology 在 06:54 仅修改 `TEAM_TASK_MODELS`。下一条回复时，`team-reply.ts` 的 `verify()` 对整个 identity 做深比较，因 configHash/configIno 变化写入 `degraded: identity/config changed`。该消息没有 intent/source，Pulse 无内容可显示。

这不是模型没写标记或 Pulse 显示问题。仅修改任务模型不应停用捕获。

## 要做的

1. 运行中重新证明身份时，只比较真正决定捕获归属的字段：项目 root/state、会话身份与文件、进程和 tmux 证据。**模型映射及其它普通配置内容变化不得使捕获 degraded。**
2. `inspectRuntime()` 保持同一口径：配置路径仍须一致，但配置内容哈希/inode 变化不应单独判 stale；root/state/session/process/pane 改变仍必须拒绝。
3. 不读取或采用新模型配置来改写捕获归属；新任务模型路由由既有配置系统负责。
4. 不放宽符号链接、属主、主检出、会话文件或写入面判据，不新增开关。

## 验收

- 用本仓库真实 PM 探针：捕获 ready 后，通过产品 CLI 修改隔离项目的任务模型，再发一条带标记回复；必须仍被捕获并保存，runtime/doctor 不变成 degraded/stale。
- 反向改坏：恢复“整个 configHash/configIno 改变即拒绝”必须红。
- 至少一条身份边界仍红的对照：root/state/session/process/pane 中一项真实变化仍拒绝。
- reply-capture 套件、关键回复 workflow、doctor 相关选段、结构检查、账本禁令和 diff check；不跑全量/夜间/61b。

## 交付与顺序

报告 `docs/team/reports/P438-verify.md`，本地提交并通知 PM，之后由非作者复验；不合并、不发布。

**与 P437 同改 `team-reply.ts`，在 P437 合入后再基于新 main 开工，避免覆盖。** 当前只登记任务，不提前改文件。
