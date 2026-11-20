---
id: V184
title: 独立审阅提醒测试临时目录方案
agent: verify
category: verify
phase: opsx-verify
change: reminder-test-temp-root-ownership
specs: verification
deltas: -
branch: task/V184-reminder-test-temp-roots-proposal-review
---

# V184 · 只审方案，优先删掉不必要的机制和重复验收

P485 作者 dev，固定候选 `227b04f6823196512170b64a136ffe0adfbea511`，PM 干净检出 `/var/tmp/p485-review-227b04f6.JIpQ4M`。读 P484/P485 交付、正式临时目录要求和候选，核实际代码路径，不重新做旧调查。

独立判定六个测试文件是否都非改不可，直接 JS 调用、已有 shell 包装和共用目录工具能否更简单地复用；不得让规划变成新进程管理器、扫描器或第二套命名。核实际证据：显式 `P442_EVIDENCE`/`run-*` 在已用回执及 smoke 的三处路径保持，默认工作可回收，保留参数、现有退出和指纹比对不变。核当前私有套接字的真实长度边界及工具接口、运行进程在普通中断时不被遗留、清理不误删证据；仅针对真实存在的路径或明确的现行要求，不加理论防护。检查方案安排的短样本能运行到目标行为，删掉等价或无改动路径的重复验收，不能以零场景或准备失败证明通过。如果新增要求仅重述通用规则，要求用最窄条款写明两份测试的独有证据边界。

只做固定检出差异、现行调用路径静态核对、本 change `openspec validate reminder-test-temp-root-ownership --strict`（1.16）及短差异检查；不执行样本、实验、提醒、真实 Pi、完整测试或清理工具，不改方案/实现。报告 `docs/team/reports/V184-verify.md` 说明接受或必须修项，每项有具体路径/反例及最小改法；本地提交，不推送。交付仅代表方案审阅；后续是否实施由 PM 接受后另派。