# route-page-check-determinism · 提案审阅

当前判定：**REVIEW — 返修候选复审中，未批准 Apply**

返修候选：`68f82553`；定点复审：V131（V130 原审阅者 dev3）。PM 对返修差异重跑 OpenSpec 22/22、change strict、spec refs 121、section-select ok13、账本禁令 hits0、diff check，均通过。以下为 V130 对上一候选 `9ac9a709` 的裁定与返修要求。

上一轮候选：`9ac9a709`（P429，作者 dev2）。独立审阅 V130（dev3）报告：`docs/team/reports/V130-dev3.md`。

## 已关闭的结构检查

OpenSpec 全部 22/22、change strict 通过、spec refs 121 条、section-select ok13、账本禁令 hits0、diff check。结构绿不代表实质接受。

## 采纳的五项返修

1. **共享完整判定与记账。** 不能只抽解析原语；逐页判定、`ok`/`finding` 与失败状态必须同构接回真实走查。走查调用点的失败传播边界写入风险，不声称有廉价测试覆盖。
2. **门禁路径与验收路径合一。** 采用 V130 的更简方案：`bash skills/teamsmith/tests/routes.sh pages`，复用同一脚本已有环境；`mr_flips` 无条件调用它并检查至少三条具名用例。删除独立 `tests/routes-pages.sh` 与复制脚手架的设计，不新增门禁段。
3. **诊断必须来自正确规则。** ④断言列 0 归属诊断；⑪断言集合差“页与清单不一致/多出”及完整用法，不能由 `ghost-probe` 特例字面量冒充；⑬菜单/命令页必须各自通过，缺 group 是唯一失败。正常/还原输入不得发 finding，并打印替代④/⑪/⑬。
4. **计数对象可观测。** delta 明确使用 routes.sh 的 `✓/✗` 与逐用例清单，不用 smoke 段计数；写明 FAST 不产生这份证据，改后由同一路径产生。
5. **撤掉 baseline-only 副本。** 改前只手工复现⑪一次，不改测试源码；④/⑬按现有父级断言源码行计数并标明不重跑。结构算术不冒充秒数。不得引入一次性选择器或要求审阅一份改过的基线测试。

同时落入 design/tasks：渲染必须 rc=0 且非空；正常页来自未变异树；菜单/组/命令比较都进同一逐页判定；空文件不算已读；顺手修正 routes.sh 头部旧描述，不扩大改 smoke/section-paths 的既有旧计数措辞。

## 下一步

P429 只修提案、设计与任务，重跑结构校验后交 V130 定点复审。复审只核这五项及直接联动，不重开已接受的样本范围，不跑全量、完整 51m 或 61b。通过前不得 Apply。
