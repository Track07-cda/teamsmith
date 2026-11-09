---
id: V130
title: route-page-check-determinism 提案独立审阅
agent: dev3
category: verify
phase: verify
change: route-page-check-determinism
specs: dispatch verification
anchor: openspec/specs/dispatch/spec.md#The printed route is a route that works
deltas: -
branch: task/V130-route-page-proposal-review
---

# V130 · 非作者提案审阅

## 冻结输入

候选提交 `9ac9a709`，作者 dev2；你没有参与探索或提案。阅读：

- `openspec/changes/route-page-check-determinism/` 全部文件；
- `docs/team/reports/P429-dev2.md`；
- 已接受探索 `docs/team/reports/P428-dev2.md` 与 PM 审阅 `docs/team/reviews/P428.md`；
- 正式 `openspec/specs/dispatch/spec.md`、`openspec/specs/verification/spec.md` 对应要求；
- 提案涉及的 `skills/teamsmith/tests/routes.sh` 真实代码。

PM 已独立运行：OpenSpec 全部 22/22、该 change strict 通过、spec refs 121 条、section-select ok13、账本禁令 hits0、diff check。结构绿不是实质接受。

## 先回答

给出 **ACCEPT** 或 **NEEDS-CHANGES**，然后逐条证据。只审这份提案，不重开 DSH 全案、不实施、不改规划文件。

## 必查问题

1. ④、⑪、⑬是否确实删除三次完整 `walk`，还是通过新入口、夜间或基线机制继续保留；删除后真实 renderer、页面枚举与真实 CLI 行为是否仍有足够证据。
2. 共享判定是否真的只有一份，是否可能让文件样本与真实走查各自演化；⑬只做文件判定是否丢失关键接线覆盖。
3. 两个 damaged renderer 与两个 normal control 是否足以防止“手写文本自证”；缺失/空文件、renderer 失败与内容失败是否区分。
4. `verification` 的例外是否严格限于这三项，实际断言计数是否可能掩盖丢失覆盖。
5. **比例性**：设计要求用一次性 baseline-only 副本分别跑三条旧控制并保留 diff，是否形成变相的新选择器或不必要的重型验证；若有更简单且同样可证伪的交接证据，给出具体替代。不要为了简化而省掉正常对照或真实单页渲染。
6. `tests/routes-pages.sh` 既作短入口又被 `mr_flips` 复用，是否会重复执行、变成新框架或与旧臂叠加。
7. 任务清单能否交给另一位实施者直接执行，验收命令是否真实存在或明确标为未来产物，是否误要求全量/61b。

## 交付与边界

- 写 `docs/team/reports/V130-dev3.md`，先结论后证据；每个必改项给具体反例和最小修法。
- 可做静态检查和小算术；不跑全量、完整 51m、61b、真实模型或公开 CI。
- 只提交自己的报告，不改提案；不合并、不归档、不发布。通知 PM。
