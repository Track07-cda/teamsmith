---
id: P467
title: 模型参数检查去重：同时减少正常检查与五条故障检查的重复
agent: dev2
category: analysis
phase: opsx-propose
change: routing-parameter-check-dedup
specs: verification
deltas: verification
branch: task/P467-routing-parameter-check-proposal
---

# P467 · 复用已有探索，直接提出下一批最小方案

用户已授权持续精简完整测试，要求删除重复执行、不做过度防御。D245/D248要求持续处理正常一阶成本，不能只优化检查测试自身的脚本。本任务只规划，不实施；后续由非作者独立审阅后再派apply。

## 输入与唯一问题

先读自己的线程、OWNERSHIP、propose skill及OpenSpec现有工件指引。沿用 `docs/team/reports/P454-dev2.md` §1/3/4及P432：P457/A8已经删除两条resplit的整组调用与第二次原树CORE，不重做这三处、不重新调查全仓。

余下五条 `extra-shadow`、`template-shadow`、`template-unbound`、`template-roles`、`literal-shell-expansion` 都调用共用boundary。P454引用的同轮历史成本合计3323s；正常§61历史为575s。二者不是本轮测量、不得相加成节省承诺。先只读核对当前调用与P454后的差异，报告真实可退休的执行。

本案回答：**能否把参数合法性判定从数百次完整CLI/项目准备中分开，同时保留真正的调用、启动、恢复和失败撤销证据，让正常boundary及上述五条故障检查一起变短？** 优先复用已有产品函数和测试助手，不先规定新框架或新入口。

## 规划范围

- 只分析/规划 `skills/teamsmith/tests/task-model-routing.sh` 与 `tests/lib/model-routing-{boundary,expansion,roles}.sh` 及其直接依赖；路径中的tests前缀相对skills/teamsmith。读取现有产品调用点、P228实际故障与当前verification规格，区分参数规则、真实接线和启动事务。
- 给一张短表：当前执行点/重复次数、替换或删除的旧执行、保留的具体行为、是否影响正常§61/五条故障检查、尚需真实验收的未知。无现成读数就写未测，不为提案新跑基线。
- 不预设旧断言数量、每个字符串排列或每个跨入口组合都必须保留。可以删真正重复或无实际对象的检查；不能把独立事实当重复，不能仅用同一产品算法的输出和自身比较。P454所引实际误选模型/会话的故障及真实调用点必须有对应观察。
- 只改变测试执行方式，不改产品判据、模型配置或真实团队状态；不重启P398的29×4减排列方案，不把成本挪到夜间/另一个入口，不缩超时、观察窗口或增加SKIP。若共用层不足以同时改善正常检查，明确指出而不把仅元套件收益写成全量收益。
- 后续验收按D246：作者只实施和静态，非作者在冻结独立检出统一执行一次受影响行为。规划最小正常、原故障与恢复及父级失败传播证据；合并后同一性和必要短检即可，不要求作者/验证者重复全组，不重跑未改的整套矩阵或其它功能。

## 交付与写集

唯一写集为 `openspec/changes/routing-parameter-check-dedup/**` 和自己的 `docs/team/reports/P467-dev2.md`。按当前OpenSpec 1.16原生指引创建proposal/design/tasks及verification delta；具体要求只写在OpenSpec，不在团队文档另造一份规格。正式规格、测试/产品/CI、其它change及PM账本均只读。

报告先给是否值得做及最小边界，再给执行退休表、证据出处和未证实项。若源码仍留影响方案成立的关键未知，点名交PM，不通过伪造成功的守卫、增加机制或长跑来掩盖。不在本任务执行真实行为样本、构建、正常路由组、61b、完整矩阵、smoke/FAST/meta/夜间/真实模型或性能测试。

完成工件及报告暂存后，只做本案适用静态检查各一次，保存真实命令、工具版本、stdout/stderr/rc：

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
openspec --version
openspec validate routing-parameter-check-dedup --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
git diff --cached --check
```

不跑全仓strict（既有长需求仍未全部处理），不把未运行项称通过。不修改引用/选择登记，因此不额外跑其平台；若确实需要改变范围，报告交PM。Conventional Commits含P467、`Agent: dev2`，小步本地提交，最终报告随分支交付；不merge/push/归档/发布，不碰0.4.7包和标签。自己的临时目录只能按本次具体路径处理，不清理之前批次尚未收存的原件。

## V172 定点返修（2026-11-16）

非作者已审冻结824cfd82，报告6955816d已收主根`docs/team/reports/V172-verify.md`，结论REWORK（C1/C2/W1/W2）。方向与其余安排已接受，不重开研究，不进入apply。保持原任务、分支、模型/SID，读该报告后只修以下四项及直接关联文字/数字：

1. C1：将worker `extra-consumes-model` 与PM `extra-consumes-resume`的真实list接线见证，换为旧faults已有的`extra-unknown-before-model` / `extra-unknown-before-resume`（extra为` --unknown harmless`）。明确固定输入、现有目标诊断和standalone extra可通过、周围模板role才拒绝的源依据；197个直接负例输入不扩表，不为此另加检查或运行样本。
2. C2：选报告的real-up方案，不同时安排第二套直接start实验。在同一私有验证副本把PM real-up写前拒绝边界定义为`cmd-watch.sh`的real-up identity预检和`common.sh`的`team_pm_start`首道identity检查一起旁路；真实函数及最终renderer保持，用已有坏custom PM模板观察prompt/诊断变化。这里只改未来验证说明，不修改产品或现在执行旁路。
3. W1：删“21个tag各preview/launch一次”的总规则。采用每tag一次launch，另留已有PM fresh `provider`坏模板的一次preview见证，覆盖独立PM preview入口；当前盘点为22次而不是42次，不设永久次数/PASS配额。同步proposal/design/tasks/delta/报告中所有关联表与措辞；合法启动/恢复/metadata/撤销不动。
4. W2：完整MODIFIED块中原第132/227/241–242行相关旧场景，明确完整61b义务属于routing-argv前批，P457/V163已接受原件供该批证据；本批按新增场景获取受影响事实，未改部分引用旧记录。不删场景标题/旧义务，不再要求本候选提供新的完整61b，也不重新审计长原件。

唯一写集仍为本change工件及自己的报告，不改V172报告、正式spec、产品/tests/CI或其它工件。修完只跑已改delta的本change strict，以及报告暂存后的必要ledger/diff各一次；不重复版本/根/选择/引用平台、不运行行为或长套。小步提交并报告相对824cfd82的真实差异和四项收口，交回原V172只复看这四项及直接矛盾，保留第一次REWORK及未验边界，不扩成全案重审。
