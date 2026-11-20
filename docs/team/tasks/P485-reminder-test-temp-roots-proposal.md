---
id: P485
title: 制定提醒测试共用现有临时目录的最小方案
agent: dev
category: analysis
phase: opsx-propose
change: reminder-test-temp-root-ownership
specs: verification
deltas: verification
branch: task/P485-reminder-test-temp-roots-proposal
---

# P485 · 提案：收掉默认临时文件，不动主动保留的验证记录

沿用 `docs/team/reports/P484-dev.md` 与 PM 接受记录，不重做旧盘点。只为两份提醒测试做方案：由现有 `tests/lib/tmp-root.sh` 管本轮工作目录，默认按既定规则回收；调用者明确给的 `P442_EVIDENCE` 及 `P442_KEEP`/`P444_KEEP` 保留现有实际可用行为。说明 smoke 的三个显式证据目录为何仍只由原外层决定保留。原有场景、独立直接调用 JS 的 `--select=`/参数/退出结果、私有终端和本地替代模型均保持；不改提醒产品、真实项目、待命或正式测试目录的命名判据。不要把普通退出的修复变成新的进程管理器、安全机制、全仓检查或批量清理；对已有常规中断流程尽量复用，不新造 owner 文件。用当前调用证明哪些现有入口可以共用逻辑；不得假定显式 `run-*` 证据能挪而不影响现有报告，也不靠共享 socket 逃避路径长度。

在 `openspec/changes/reminder-test-temp-root-ownership/` 写元数据、proposal/design、verification delta、tasks。基准以 `A fixture's temp root resolves TMPDIR, carries an owned name, and is reclaimed` 为准；不要重写、再抄或放宽通用要求。仅增加这两份测试的工作与显式证据边界，适合独立检查，不能与默认回收冲突。写清拟改的精确测试文件及每一处的必要性。验收优先一次成功的短运行、一次可见失败/保留和一个代表性的隔离中断样本；说明如何用原行为或短等价样本覆盖另一份测试、四入口与直接调用，不能以零场景假通过，也不要求先把 P484 报告的所有矩阵执行一遍。当前只设计，不执行这些样本；不跑整套、真实性能、安装、提醒发送或真实模型。

只做本 change 严格结构校验、普通全仓规格结构校验、`git diff --check` 和原账本公开文件检查。用现有 1.16，不安装或升级工具，命令 stdout/stderr/rc 与未验范围写入 `docs/team/reports/P485-dev.md`。本地分步提交，送非作者审阅；不推送、不进入实施。若发现改动会改变现有显式证据或非短的测量要求，说明缺口并以最小替代方案交 PM，不擅自扩大。