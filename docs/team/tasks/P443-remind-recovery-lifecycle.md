---
id: P443
title: 自我提醒：PM 停止恢复、剩余生命周期与操作文档
agent: dev
category: code
phase: opsx-apply
change: agent-self-reminder
specs: agent-self-reminder pm-lifecycle watchdog
anchor: openspec/changes/agent-self-reminder/proposal.md
deltas: agent-self-reminder, pm-lifecycle, watchdog
branch: task/P443-remind-recovery-lifecycle
---

# P443 · 完成提醒运行生命周期（不含最终 AC 验收）

## 范围

基于已合入的 P442。执行 change tasks 4.1.2、4.2、4.3、4.4，以及 2.3.2 和 V150 的两条生命周期建议。**不做 5.x 最终验收，不做真实模型自主创建。**

## 必做

1. **Reminder-only 恢复**：复用现有 PM 身份、continuity、starting、capacity、quota 和窗口证据。PM 停止且条件满足时，以通常 resume 参数和 PM 扩展启动，但不得带 `@pm-prompt` 或替代初始提示； watcher 启动后走现有提醒直投。不得产生普通 backlog 的启动工作。
2. **恢复边界**：running/busy/stopped/already-starting、quota/capacity/identity/missing extension/unsupported adapter/failed/lost send 都有明确结果；不重复进程、不破坏草稿、不用普通 nudge 冒充提醒、不把未知结果自动退出 Standby。观察成功且代次允许后才恢复普通工作。
3. **两种 Pulse 形状**：完成 4.1.2，证明到期发生在长巡检期间也能入队，至多一个全巡检和一个 Reminder recovery，结束后一次 Reminder-only 复查，正确回收子进程；不以模型延迟冒充 30 秒入队保证。
4. **剩余生命周期证据**：2.3.2 的并发创建、cancel-vs-intent、key 重用、旧 active 保留、pruned 后迟到事件；不得合成新提醒或重复发。
5. **V150 建议**：stdin 正文校验失败时 `--json` 输出结构化拒绝；hide/switch/fork 时撤下能力证据，doctor 不再等 20 秒仍报 ready。保持无额度与 PM-only。
6. **文档**：更新 `references/reminders.md` 等实际操作文档，写清无额度、周期同 key、due≠wake、Standby 歧义、unknown/resolve、停止恢复、flock、升级与回滚。面板源若变才按钉住工具链重建 bundle；不新增可视化或配置。

只勾选上述证据真正覆盖的 tasks；5.x 和未覆盖子项保持未勾。

## 验收

- 私有真实 Pi/tmux + controlled model：PM 停止后无通用启动提示，能由提醒恢复并观察；普通 backlog 未先执行；running/busy/starting 不重复启动；拒绝分支不假装成功。
- 两种 Pulse 形状、进程/锁/状态故障、cancel-vs-intent、pruned late event、JSON 拒绝、hide 后 doctor 立即失效均有红/绿/恢复。
- 现有 remind CLI/delivery/tool、state-authority、Standby 与相关选段保持绿；新夹具登记 section-paths。
- `openspec validate --all`、spec-refs、section-select、账本禁令、diff check；不跑全量/夜间/61b，不操作真实团队 PM/Pulse/Standby。

## 交付

小步提交，`docs/team/reports/P443-dev.md` 先给结论，附真实启动参数、会话/状态证据、两种 Pulse、红/绿/恢复和未做范围。通知 PM 后由非作者复验；不合并、不归档、不发布。
