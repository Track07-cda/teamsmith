---
id: V157
title: 三份小规格长需求试点独立复验
agent: dev3
category: verify
phase: opsx-verify
change: spec-clarity-burn-down
specs: writing-discipline extension-slash help-surface
anchor: openspec/changes/spec-clarity-burn-down/proposal.md
deltas: -
branch: task/V157-spec-clarity-pilot-verify
---

# V157 · 非作者复验 P408

冻结候选 `dab3145c`，作者 dev。你未参与改写。阅读 change、P408 报告与实际 diff；作者数字不是结论。

## 独立验证

1. 逐条对照 15 个 MODIFIED requirement：原标题未变、判定主旨与行为不变，43 个原场景逐字保留，新增场景只承接细节且可证伪；无引用断裂。
2. 在 `/var/tmp` 私有副本执行原生试归档，三份 `--strict` 必须 rc=0、0 warning；全局长需求从 239 降到 224，不把范围外失败说成通过。
3. 核对 `769fdb1b` 只替换两段 canonical Purpose，requirement/scenario 未改；change strict、spec-refs、section-select、账本禁令、diff check 通过。
4. 至少一处反向改坏：恢复一条长需求或删去承接边界后，对应检查必须红，恢复后绿。不得只看行数减少。
5. 给 PASS / NEEDS-CHANGES、行为漂移风险与是否可在后续单独授权后归档。不要真实归档、不改实现、不跑全量/夜间/61b。

报告 `docs/team/reports/V157-dev3.md`，附自己的命令、日志和未跑范围。只提交报告，通知 PM。
