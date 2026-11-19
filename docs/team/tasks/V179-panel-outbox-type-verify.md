---
id: V179
title: 独立验证消息页受阻提示及完整类型检查
agent: verify
category: verify
phase: opsx-verify
change: -
specs: panel#The deferred-delivery queue is read, counted and never touched
deltas: -
branch: task/V179-panel-outbox-type-verify
---

# V179 · 只验消息页读法，不跑面板全套

实现者 dev；PM 固定候选 `22a1c4aff372fdad1c71093100d876539ef78e2b`，独立检出 `/var/tmp/p474-review-22a1c4af.jwDL7B`；改前 `2ac59d49`。读 AGENTS、本人线程、OWNERSHIP、P474 brief 和交付报告，确认候选与写集；候选检出的依赖安装或重建使用自己的私有副本，固定检出保持干净。

- 在私有副本实际执行锁定依赖安装、panel 完整 `bunx tsc --noEmit`（候选 rc0），用原 build 重建并核对已提交 bundle 的内容。作者的旧编译 4 处 TS2339 有实跑记录，不重复编译改前副本。
- 复用现有 `skills/teamsmith/tests/delivery-truth.sh` 的 panel 样本（两个受阻记录）。用实际 bundle 通过隔离项目读取诊断并单独保存消息页帧：检查**队列区**内受阻数、两条原因和各自时间，不能靠共用页首警示或列表行理由通过。相同断言对改前真实 bundle 应因消息列表缺这一行而失败，而不是启动错误。至少再核一次只有普通待发项不会冒出受阻提示，以及已知受阻项缺诊断文件时仍显示不可用而非零。观察前后队列内容及发送/尝试记录不变；不实际发送，不碰正在运行的 Pulse、真实队列或待命。保存帧/输出、返回值和核对依据。只做这些短检查，不跑完整 panel、delivery-truth 全部、全量、真实模型。
- 正式候选执行可用 `TEAM_GATES='bash /var/tmp/<你的证据根>/<定点检查脚本>' bash skills/teamsmith/scripts/team review P474 --dir /var/tmp/p474-review-22a1c4af.jwDL7B --branch 22a1c4aff372fdad1c71093100d876539ef78e2b`，中央只允许工具写 `reviews/P474.md` / `P474-verify.log`。报告 `docs/team/reports/V179-verify.md` 用实际证据、范围限制，`git diff --check` 后本地提交（V179 / Agent: verify）。若需要长作业按后台规则；证据保留至 PM 接收。
- 合并后由同一验证者在 PM 新固定检出只核对可执行字节同一和一帧消息页受阻提示，不重复编译和完整候选验证。未获通知不自行动作；不推送、合并或发布。
