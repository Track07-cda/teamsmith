---
id: V131
title: route-page-check-determinism 返修定点复审
agent: dev3
category: verify
phase: verify
change: route-page-check-determinism
specs: dispatch verification
anchor: openspec/specs/dispatch/spec.md#The printed route is a route that works
deltas: -
branch: task/V131-route-page-proposal-rework-review
---

# V131 · 只核 V130 五项是否关闭

## 输入

你是 V130 原审阅者，未参与编写。冻结返修候选 `68f82553`；上一轮候选 `9ac9a709`。只读 `git diff 9ac9a709..68f82553`、你的 `docs/team/reports/V130-dev3.md` 和 PM 裁定 `docs/team/reviews/route-page-check-determinism-proposal.md`。

PM 已重跑：OpenSpec 全部 22/22、change strict 通过、spec refs 121 条、section-select ok13、账本禁令 hits0、diff check。不要重复全案审阅或重开已接受范围。

## 定点问题

1. M1：共享操作是否包含完整菜单/组/命令判定、finding/FIND 与状态；真实走查两个调用点的失败传播是否作为明确的审查边界，而非冒充已有测试。
2. M2：是否已改为同一脚本 `routes.sh pages`，非 FAST `mr_flips` 无条件调用并检查三个具名结果；独立脚本与复制脚手架是否消失，验收是否走同一命令。
3. M3：④是否钉列 0 归属，⑪是否钉集合差而非 `ghost-probe` 特例，⑬是否只有 missing group 一个失败；正常/还原输入是否无 finding，反向改坏是否对应正确规则。
4. M4：计数对象是否改为 routes 自身 ✓/✗ 与具名清单，FAST 是否明确不产生证据，各计数域是否不混加。
5. M5：baseline-only 副本是否彻底撤回；改前是否仅手工复现⑪且不改测试源码，④/⑬是否仅按源码归属，无变相选择器或三臂耗时承诺。
6. 直接联动：渲染 rc=0+非空、正常页来自未变异树、空文件不算已读、菜单/组/命令同一判定、旧头部措辞与任务命令是否一致。

## 交付

写 `docs/team/reports/V131-dev3.md`，先给 **ACCEPT / NEEDS-CHANGES**。若仍不接受，必须给返修后仍存在的具体反例和最小修法；不要重复已关闭旧描述。

只做静态检查与小算术，不跑全量、完整 51m、61b、真实模型或 CI；不改提案、不合并、不归档。通知 PM。
