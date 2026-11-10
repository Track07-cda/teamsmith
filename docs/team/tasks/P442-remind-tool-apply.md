---
id: P442
title: 自我提醒：实施无额度的 PM 专用 team_remind 工具
agent: dev2
category: code
phase: opsx-apply
change: agent-self-reminder
specs: agent-self-reminder pm-lifecycle watchdog
anchor: openspec/changes/agent-self-reminder/proposal.md
deltas: agent-self-reminder, pm-lifecycle, watchdog
branch: task/P442-remind-tool-apply
---

# P442 · 实施无额度的 PM 工具并删除旧批次限制

## 唯一依据与分工

最终提案修订 `0e9b6f87` 已合并并经 V149 ACCEPT。阅读 change 全部规划与 `docs/team/reviews/P441.md`。你未参与修订，执行 tasks 2.1.2、2.2.2、3.3；不做 4.2/4.3 停止恢复，不做 5.x 全量验收，不做真实模型自主创建。

## 必做

1. 新增独立 `team-remind.ts`，只通过现有 `team_pm_pi_args` 注入已验证 PM；不注入 worker、不加入 `/team`。提供 `team_remind` add/list/show/cancel，复用 CLI/权威，无项目/owner/state path/recipient 参数。
2. 每次调用重新验证项目、会话、进程、tmux/PM 启动证据；worker、ordinary、forged、失效或 reload 后在任何 Reminder 状态读写之前隐藏或拒绝。保留 `/team` 无工具面与 worker 启动。
3. 实现 freshness-bounded 能力证据与 doctor：not-running、unknown、explicit load failure、registered/active。没有证据只报 unknown，不声称跨进程查到工具列表、模型可见性或真实使用。
4. 删除当前代码的 `BATCH_LIMIT`、`BATCH_SPACING_MS` 及快照成员数量限制；不新增配置键、创建频率、active 数量、正文字节、最小延迟或批次间隔。保留 30 秒逾期判定（它是状态说明，不是创建/发送限制）和既有终态保留规则。
5. 有效未来时间、非空合法 UTF-8 无 NUL、全文不截断、活动 key 重试原 ID/原 due、观察后同 key 新单调 ID、未知不盲重发、单批未定不阻止新创建。
6. 只勾选本片证据覆盖的 tasks；未做的恢复和 AC 保持未勾。

## 验收

- 现有 remind CLI/delivery/state-authority 保持绿；删除旧限制的发送与快照断言，替换为正向行为：九条同批、无等待下批、64 KiB+末尾换行、超过旧 active 数量仍不拒绝、正间隔/短延迟可创建。
- 私有真实 Pi/tmux + controlled model：PM 工具可调用并落同一状态；worker/ordinary/forged/reload 后隐藏或拒绝且零状态变化；doctor unknown/error/ready 诚实。
- 周期同 key、无 key 相同正文两个 ID、身份失效零读写、全文无截断均有反向改坏和恢复。
- 新夹具登记 `section-paths.tsv`；运行受影响选段、`openspec validate --all`、`spec-refs`、`section-select --check`、账本禁令、`git diff --check`。不跑全量/夜间/61b，不启用真实团队的新扩展。

## 交付

小步提交，`docs/team/reports/P442-dev2.md` 先给结论，附真实命令、私有 Pi 证据、旧限制删除点、红/绿/恢复和未做范围。通知 PM 后由非作者复验；不合并、不归档、不发布。
