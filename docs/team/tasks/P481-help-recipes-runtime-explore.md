---
id: P481
title: 查清用法与实际入口测试中的两处长等待
agent: dev2
category: analysis
phase: opsx-explore
change: -
specs: verification#A gate that cannot judge says so
deltas: -
branch: task/P481-help-recipes-runtime-explore
---

# P481 · 缩短完整测试的下一处，只做定点归因

用户授权按顺序推进未完工作。本会话 Pulse 已现场核对。本单只查完整测试的下一个候选，不重复 P477：`docs/team/reports/P477-dev3.md` 的 §51 用法与实际入口曾耗 705 秒，`routes.sh` 较早结束；`skills/teamsmith/tests/help-surface.sh` 中 `claims` 下的 `smoke --select 0` 与 `perf --host` 各有 300 秒外部超时，记录只是前后状态比对且不留命令退出证据。旧总时长不能证明两条都用满了等待；P480 三次只读终端、P479 保留的 FIFO 判定、P465 帮助重复渲染均不再查。

对上述两条分别说明：该测试原本要证明什么、命令实际会等待谁或启动什么、现有判断还能否区分“成功执行”与“根本未进到实质调用”。用现有日志与源码给出证据，对照是否已经有其他测试直接证明该行为；只有证据不足且能用隔离单条短命令直接证明时，才允许运行该短样本，不触发完整 smoke、性能测试、整段帮助检查、真实团队、真实模型或远端。不要通过缩短正式超时把等待伪装成已验证。只建议一个最小减重动作，写明保留的实际行为、明确可删的重复项和用于独立验收的最小范围；无法归因或无法安全简化就写清缺口并建议保留。不改源码、规格、测试或运行配置；不得以长时间等待补证据。

只提交 `docs/team/reports/P481-dev2.md`，记录命令、原始输出位置、未运行范围及结论。短 `git diff --check` 后本地提交 `P481` / `Agent: dev2`，不推送。不要顺带处理提醒临时目录、消息页清理或长需求。
