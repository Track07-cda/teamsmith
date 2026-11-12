---
id: V158
title: 自我提醒 AC-02 / AC-09 真实模型自主性验证
agent: dev3
category: verify
phase: opsx-verify
change: agent-self-reminder
specs: reminders agent-remind-tool
anchor: openspec/changes/agent-self-reminder/tasks.md
deltas: -
branch: task/V158-reminder-real-autonomy
---

# V158 · 真实 PM 自主性最后两项验收

用户已明确授权。当前 main `3f941382`；PM 准备 `/var/tmp/v158-autonomy-3f941382`。你未实现提醒功能，沿用 V152 的最终验证上下文，不重做已经通过的受控实现与全量检查。

## 场景

1. **AC-02 创建自主性**：在 `/var/tmp` 新建隔离团队与私有状态，使用当前 main 的 `team up` 起真实 PM、真实模型。用自然语言请 PM 在短延迟后提醒一件明确的小事，不在提示词里写工具名、参数、JSON 或“必须调用某函数”。观察 PM 是否根据已加载指引自行使用 `team_remind` 创建有效提醒，并在到点后产生新的模型回合。
2. **AC-09 醒来后自行续排**：用自然语言提出短周期检查任务，让 PM 在第一次醒来后自行决定是否创建下一条；至少观察一次由模型自己发起的续排及第二次叫醒，然后明确让它停止，确认不再继续创建。不能由测试脚本代替模型循环创建。
3. 记录真实模型/provider、PM session JSONL 中的用户提示、`team_remind` 工具调用与结果、提醒状态、投递/叫醒记录和模型回复。区分“用户直接要求一次提醒”与“模型醒来后自行续排”。
4. 若模型没有调用，先检查工具是否实际注入、模型是否理解任务；不要用更强提示词把失败洗成通过。产品缺陷如实报 NEEDS-CHANGES，不直接改实现。

## 边界

- 只在隔离项目、私有 tmux socket/会话与私有 HOME 运行；不得操作 pm-skills 或其他真实团队的 PM/Pulse/待命状态。
- 不联系外部人员，不发短信/邮件，不执行外部回调；测试事项用本地无害事实。
- 不为了省钱改用假模型或模拟工具；不修改测试提示直到通过。记录全部尝试，失败尝试不得从证据中删掉。
- 不重跑全量/夜间/61b，不合并、不归档。

## 交付

`docs/team/reports/V158-dev3.md`：先给 PASS / NEEDS-CHANGES，逐项映射 AC-02、AC-09，附原始 session/工具/提醒/投递证据路径与时间线、停止与清理结果、OpenSpec CRITICAL/WARNING。若通过，说明 `agent-self-reminder` 是否具备最终归档条件；只提交报告，通知 PM。

## 08:50 续跑提示

上一轮已完成 P450 定点复核，不要重做。因 opencode-go 网络断连切到 kimi-coding/k3.1-pro:high 新会话；先检查 `/var/tmp/v158-lab-r2`、`v158r2-lab-4` 与最新后台日志并收割现有隔离 lab。真实 PM 使用 kimi-coding/k3.1-pro:max，`team init` 配置保持原样。只补 AC-02/AC-09、停止后不续建与最终报告，不碰真实团队。
