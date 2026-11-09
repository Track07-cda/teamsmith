---
id: V134
title: reply-observer-skip-focus 六项返修定点复核
agent: dev3
category: verify
phase: verify
change: reply-observer-skip-focus
specs: key-replies verification
anchor: openspec/specs/key-replies/spec.md#Reply readers remain bounded as history grows
deltas: -
branch: task/V134-reply-observer-rework-review
---

# V134 · V133 原审阅者定点复核

冻结返修候选 `5a6cb0cc`；上一候选 `44de7c2f`。只核你的 V133 六项及直接联动，不重开已接受范围，不实施。

PM 已重跑：OpenSpec 23/23、change strict、spec refs 125、section-select ok13、账本禁令 hits0、diff check。

## 六项

1. 独立 bounded 检查是否由正常 bounded 证明；缺席样本是否只证明观测入口在其后且在大准备前，不再引用已删除 replay。
2. 是否明确断言无观测专属索引/第二份大存储；一槽准备反例是否足以让顺序错误变红。
3. 父级证据是否使用具名诊断，且有“吞掉样本失败仍 rc=1 但具名诊断消失”的反侧；rc 不再单独算证据。
4. 反例是否用 subshell 函数覆盖、不递归、不新增入口；子样本结果前缀是否不会被 smoke 汇总误认。
5. 是否写清 PM 在临时副本的正序两处例外=1、逆序=0 的命令，真实归档仍需用户确认。PM 会自己执行，不要求你代跑真实归档。
6. verification 是否明确允许三项 route-page 替代加一项 reply-observer 退休，不再自相矛盾。

同时检查新引入的外部一次性 scratch 取证没有变成常规入口或永久新层，任务计数和验收命令仍一致。

## 交付

`docs/team/reports/V134-dev3.md`，先给 **ACCEPT / NEEDS-CHANGES**；若仍拒绝，必须给返修后仍成立的具体反例与最小修法。只做静态检查/小算术，不跑完整 §62、全量、61b、真实模型或 CI，不改提案、不合并、不归档。通知 PM。
