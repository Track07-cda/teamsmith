---
id: P460
title: 正常完整测试的配置重复执行精简提案
agent: dev2
category: analysis
phase: opsx-propose
change: config-check-execution-dedup
specs: verification
deltas: verification
branch: task/P460-config-check-dedup-proposal
---

# P460 · 沿用已有调研，只规划配置检查这一批

依据已接受的 `docs/team/reports/P432-dev2.md` §3.3/3.4/4C、D238及用户之后的测试减重裁定。不是重新调研全仓，也不是实现任务。前一批模型路由已交付归档；本批面向正常完整测试，不混算夜间路由节省。

当前main已确认：`smoke.sh` §33无参数调用config-cli（含list/validate/roster），§51又调用同样三组；P24_ROOT/p24_*定义位于§33后，七个使用者以needs:33取得准备定义。具体行号随当前源码查，不沿用旧报告行号作证据。

## 交付

在自己的工作树建立唯一change `config-check-execution-dedup` 的原生proposal/design/spec delta/tasks及 `docs/team/reports/P460-dev2.md`，规划后交非作者独立审阅，不实施、不合并、不归档、不发布。只写该change和自己的报告，不改正式spec、产品、tests或主检出。

规划范围只含两项已有重复：
1. 正常完整运行中list/validate/roster只在一个既有位置执行，具体保留哪处由最小改动和现有消费者决定；独立config-cli无参数入口仍完整。不能删去真实CLI/写盘/拒绝证据，也不把另一套不同语义的routes roster承诺检查误删。
2. 只有函数定义依赖的p24准备从执行§33解开，让七个既有选段按实际准备独立运行；若发现真实数据依赖则保留并指出。不引入通用夹具平台、跨用例可写缓存或另一套框架。

按当前源码给出具体删除的调用/依赖边、保留的具名检查、改后选段如何选中它们、最小实施和独立验证命令。先看是否同参数/同环境/同状态，不能按同名就删。新的检查必须替代旧重复，不追加守卫；不预设每条旧自检必须保留，只为正常使用和已证实际故障留证据。

沿用P432现有成本，必要时只读 `/var/tmp/rel47-first-order.log` 的已有段记录；不能把整个§33的耗时当作三组重复的节省，更不能把删除needs的局部收益算入完整运行。静态执行次数与尚未实测的耗时明确分开。不得为提案重跑全量、61b/meta/夜间、完整help/routes/config或长变异矩阵；如无需短样本则不要运行测试来补形式。

## 规划验收

使用已安装OpenSpec1.16（先报实际版本/根，通常PATH前置 `$HOME/.bun/bin`），对本change做结构校验；spec-refs、section-select、报告暂存后的ledger-ban/diff-check。全项目普通validate的既有警告不记为strict通过。命令较长后台启动即结束回合，不在会话内等待。

报告先给推荐的最小范围和实际删除账，再列真实回执与未验证项；不用全仓新统计、虚构秒数或完整套件绿单。若两项不适合绑在同一批可收窄并说明，不能扩大到帮助页/模型路由或新功能。

## 2026-11-16 · V166定点返修

PM接受 `docs/team/reports/V166-verify.md`（main已收存，原提交3d6e8fdd）的R1/R2/R3，裁定见 `docs/team/reviews/config-check-execution-dedup-proposal.md`。只修design/tasks的重复验收安排、delta正文的完整/单选歧义、缺准备负例和自己的报告；原规划b00853dc/5ab4f040保留对照。按报告R1最小表收窄未来验收，不执行那些未来命令；按R3替换负例，不增加防护代码或新框架。

本次只对改动的规划做OpenSpec1.16本change严格结构、报告暂存后的ledger-ban/diff-check；未变的现状11份选择计划、全项目validate/spec-refs等已有回执不重跑。不更新已无关的proposal或扩大产品/测试写集。不合并main到本分支；用 `git show main:docs/team/reports/V166-verify.md` 读证据。原任务/分支/模型/SID续跑，完成后由原独立审阅者只复看R1–R3。
