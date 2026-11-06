---
id: P423
title: 提醒到点叫醒：定时到期 → 投递 → 待命联动 → 重启恢复
agent: dev2
category: code
phase: apply
change: agent-self-reminder
specs: agent-self-reminder
anchor: openspec/changes/agent-self-reminder/specs/agent-self-reminder/spec.md
deltas: -
branch: task/P423-remind-delivery
---

# P423 · 叫醒这条线（最短可用路径）

地基已落地：权威层（P406）、提醒命令（P409）、待命迁移（P422，已合入并执行，统一状态里 `standby.on=true / generation=0`）。**本片只叫到叫醒为止，不做模型侧 `team_remind` 工具注入**（那是 3.3）。

## 必须成立（四件）

1. **到期检查**：巡检窗口在现有节拍之外加一个轻量到期检查（目标约 10 秒一次，不重扫全项目、不重叠）；到点的提醒形成**一批**，快照里记下批次与到期项。普通巡检节奏不变。
2. **投递**：一批合成一条完整消息送进 PM 会话（走现有 inbox-watch / 消息通道，**不碰输入框草稿**）。投递前在快照里留“已送出”的证据，回执后更新；失败有明确状态与重试上限，不重复送。
3. **待命联动**：待命期间到点的提醒**照样叫**；只有真正送达才退出待命，**一次只退一次**（代次校验），并在审计里记下原因与来源；到期但未送达不得清待命。
4. **重启恢复**：PM 或巡检进程重启后，到点还没送出的提醒会补发；已送达/已终结的不重发。

## 红侧（每条都要能红）

- 到期形成批次：不到点不入队、取消的项不入队；
- 重复投递：同一批次第二次送 → 必须拒绝/去重；
- 待命：未送达不得清；已送达只退一次，代次不符时不得清；
- 恢复：进程重启后未送达项被补发，已终结项不被重发；
- 投递失败：状态显式（unknown/失败），不冒充成功。

## 验收

- 新增/扩展的测试（权威层 + 提醒命令 + 你自己的投递/巡检夹具）
- `bash skills/teamsmith/tests/state-authority.sh`、`bash skills/teamsmith/tests/remind-cli.sh`
- `bash skills/teamsmith/tests/smoke.sh --select 11b,11b3,11b4,66,67`（若 11b3 因提示词缺模型而红，写明真因）
- `openspec validate --all`、`spec-refs.sh --check`、`section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- **真实验证**：用本仓库的 `team` 在隔离项目里起一个真实 PM，设一条短提醒，证明到点真的被叫醒（看消息进入 PM 会话、快照状态变更、待命按规则退出）；把日志路径写进报告。
- 报告 `docs/team/reports/P423-dev2.md`，提交推分支，通知 PM

## 边界

- 只改投递/巡检/权威层与提醒命令；不动待命读写（P422 已落地）；不做模型侧工具注入；不改发布流程。
- 不跑全量 smoke；不合并/归档/发布；不碰真实团队的提醒/待命状态（真实验证只在隔离项目里做）。
