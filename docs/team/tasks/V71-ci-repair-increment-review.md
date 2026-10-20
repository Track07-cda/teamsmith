# V71 · CI减重复返修的独立行为复核

task: V71
agent: dev2
phase: verify
category: verify
change: behavior-focused-ci
specs: verification
deltas: -
branch: task/V71-ci-repair-increment-review

## 问题与固定对象

P326不能用截断的C4宣布通过。本任务只回答：V70后的定点返修是否成立、能否交给PM准备最终组合验收？整体验收仍未完成，不以本轮增量PASS冒充整个change已验收。

先读自己的线程、P326任务书、提案评审`docs/team/reviews/behavior-focused-ci-proposal.md`、本change提案/delta及verification规格。读P326报告§7与V70报告。候选固定`f14be42b`，报告`4760f7a1`（再往后`71a3be19`只新增32行取证缺口说明，PM已diff确认`skills/ openspec/ .github/ ci/`逐字节未变，不重跑）；后续纯报告变化只审diff，不重启测试。自己建一个磁盘上的真实独立clone（不是worktree挂进容器），固定HEAD且干净；不改源码，不写作者目录。不push。

已知原始日志`/var/tmp/p326-11c{3,4}/run.log`：前者PM状态为running，后者342/0、其中11c为16/0。作者未按要求保留第四次的夹具根，只有stdout可回读，不能虚称看过原up-agents.log。你本轮唯一11c运行用`--keep`，保留自己的原始现场到复核收口；无需为补作者现场另跑一次。

## 只做这些验证

1. 独立clone中**一次**非FAST的`bash skills/teamsmith/tests/smoke.sh --select 11c --keep`，私有磁盘TMPDIR和私有锁。它应带必要前置11b，全部行为成立；读取现场中的up-agents.log，确认仍是真的续跑agent、PM尝试启动失败，而非删断言或接受任意PM消息。审新增make_pm_idle是否只操作私有夹具，是否引入额外隐含依赖。原15条产品断言保留；不以用时为通过判据。
2. **一次**`bash skills/teamsmith/tests/workflow-entry.sh --tree <固定clone>`：有效基点的特殊字符原样传递；无效基点确实调用完整入口而非“没有floor就算过”；下层失败非零。它是执行实际workflow块并替换docker的检查，不是真GitHub运行、不证明容器内整套通过。静态核对已有回退换成true的反例确会被新断言检出；不再造三类变异矩阵。
3. 原`perl skills/teamsmith/tests/signal-lint.pl`与`section-select.sh --check`轻量检查；静态核对仅删除无对象M35历史豁免，lint规则未放宽，空清单不能导致产品扫描被跳过（读58段与原函数，不跑整段58）。现有报告把它归因P330没有证据，结论按你看到的树与历史写。
4. 静态审V70后probe差异：每次合并nest一次整体退出码、各段仍读自己结果。核对workflow归36的真实承接、11c的needs，以及保留main的P318/P331/P330成果。既有C1/C2纯逻辑和不受影响的反例证据复用，不枚举重做。

**不跑容器、floor、36整段、checkout-shape-probe、路由变异或新的计时实验；不新建夹具/守卫/框架，不扩大选择器豁免，不缩地板，不提高任何时限。** 本任务不重做C4。两个入口与轻量检查可合为一批后台作业；先完成静态审阅，再按长作业车道启动并结束回合，醒来后收割，固定树运行中不写源码或提交。

若发现必修项先汇总一次交PM，不自行改实现，也不要把每个文案问题变一轮验收。耗时只报告参考值；失败具名，不能凭“上轮绿过”放行。报告先给增量PASS/PARTIAL/FAIL，再给命令、返回码、原始尾部与未覆盖的整体范围。

## 交付

只写`docs/team/reports/V71-dev2.md`与自己的线程。提交前在自己的工作树运行ledger-ban固定验收行与`git diff --check`。local模式不push、不归档。最终C4和发布由PM另行统一安排；本任务不得触发远程CI。
