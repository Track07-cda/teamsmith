# Agent ↔ PM 消息线程

每个 agent 一个文件：`<agent>.md`（**append-only**：只追加，不改历史条目）。

## 规则

- 条目格式：`### <ISO8601> · from: <pm|agent:名> · re: <任务ID>` + 正文。
- **agent 每次开工前先读自己的 thread**（PM 可能在你开工前补了指令或答复）。
- PM 的回复是同文件里 `from: pm` 的条目。
- 只在需要 PM 决策/协调时写线程；**消息不能替代报告**（报告在 `../reports/`）。
- 写线程的便捷方式：`team thread <agent> "内容" --from pm --re ["任务ID"]`。

## 本项目的 agent

dev verify

（用 `team thread <agent>` 不带内容时可以直接打印整个线程。）
