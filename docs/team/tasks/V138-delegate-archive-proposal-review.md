---
id: V138
title: delegate-openspec-archive 提案独立审阅
agent: dev
category: verify
phase: verify
change: delegate-openspec-archive
specs: verification
anchor: openspec/specs/verification/spec.md
deltas: -
branch: task/V138-delegate-archive-proposal-review
---

# V138 · 非作者审阅 teamsmith 默认归档委派

冻结候选 `e180fdbf`，作者 dev2；你未参与该提案。阅读 change 全部规划、当前 teamsmith 模板与 references，以及用户要求：verify/archive 都不由 PM 亲自做，且是 teamsmith 默认规则。

PM 已跑结构检查：OpenSpec 24/24、change strict、spec refs 125、section-select ok13、账本禁令 hits0、diff check。P435 报告正在补齐，不以缺失报告冒充完整交付。

## 必查

1. 是否准确保留 PM 的审阅、差异核对和合并权，同时把 verify/archive 及其门禁执行交给非实现者；没有形成“名义委派、PM 后台照跑”的漏洞。
2. verifier 可兼 archive 是否符合用户要求且仍独立于实现者；是否无意要求第三个永久席位。
3. 归档前 OpenSpec verification、CRITICAL 清零、WARNING/未验证项披露和用户确认是否完整；移除 PM-proxy 是否有现有规则冲突或超出用户裁定。
4. archive 在自己 worktree/branch 写 specs 与归档目录，PM 后续合并，是否与 OWNERSHIP 和团队权限兼容；两个依赖 change 串行的要求是否可执行。
5. 八份文档与 §19/§12j 的修改是否覆盖所有相反口径；是否借规则修正建立新流程系统、额外门禁层或不必要的状态。
6. 现有 `team change status` 自身 archive 任务未完成的语义是否描述准确；不能为让命令变绿而绕其它 blocker。
7. 当前两个变更已经由用户授权委派 verify/archive，本提案是否明确不追溯阻塞它们。

## 交付

`docs/team/reports/V138-dev.md`，先给 **ACCEPT / NEEDS-CHANGES**，每项附具体反例和最小修法。只审提案，不改规划、不实施、不跑全量或真实归档、不合并。通知 PM。
