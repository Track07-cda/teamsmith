---
id: V133
title: reply-observer-skip-focus 提案独立审阅
agent: dev3
category: verify
phase: verify
change: reply-observer-skip-focus
specs: key-replies verification
anchor: openspec/specs/key-replies/spec.md#Reply readers remain bounded as history grows
deltas: -
branch: task/V133-reply-observer-proposal-review
---

# V133 · 非作者提案审阅

冻结候选 `44de7c2f`，作者 dev2。阅读 change 全部规划、P432 §3.1/§4A、P433 报告，以及真实 `tests/key-replies.sh` 和 `tests/lib/proc-io.sh`。你没有参与研究或提案。

PM 已跑：OpenSpec 23/23、change strict 通过、spec refs 125、section-select ok13、账本禁令 hits0、diff check。结构绿不是实质接受。

## 必查

1. 短样本是否调用正常 bounded/full_scan 的实际缺席处理和结果消费者，还是只生成/匹配一份日志；缺失大存储前提时会不会假绿。
2. 正常 bounded 在真实缺观测器场地是否仍执行坏最新、不可枚举、不可读正文等独立检查；能力检查前移是否意外跳过它们。
3. 完整 `bounded,flip` 与失败 trace 是否真删除，正常九臂、真实 full_scan 内核证据、存储/Pi/UI 是否保留；有没有转成夜间或备用路径。
4. 三条具体诊断、两项未验证、产品通过/失败分类和父级退出是否可证伪；三类至少七个变体是否比例适当，是否形成递归自检或新框架。
5. 7→6 局部断言和子样本计数是否与实际设计一致，是否掩盖其它覆盖损失。
6. verification 与 route-page-check-determinism 的完整 MODIFIED 块是否保留前者全部义务；后续归档顺序和试归档必须怎样验证。
7. 实施任务是否能在同一测试文件内完成，验收命令是否真实、足够且不跑无关全量。

## 交付

`docs/team/reports/V133-dev3.md`，先给 **ACCEPT / NEEDS-CHANGES**，每项附源码反例和最小修法。只审提案，不实施、不改规划、不跑完整 §62/全量/61b/真实模型/CI。通知 PM。
