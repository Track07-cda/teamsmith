# V70 · CI减重复：独立审代码与现有失败证据

task: V70
agent: dev2
phase: verify
category: verify
change: behavior-focused-ci
specs: verification
Deltas-note: 本任务只写报告，不改delta。
deltas: -
branch: task/V70-ci-reduction-static-review

## 读取与固定范围

读自己的线程、P326任务书、`docs/team/reviews/behavior-focused-ci-proposal.md`（如名称不同先查reviews），以及候选 `762cd654` 的 `openspec/changes/behavior-focused-ci/`、相关capability规格。产品与测试受检ref固定762cd654；后续作者报告/任务勾选与当前main分开看，不能把它们当成该ref已执行过。任务只读、不改实现、不push，只写 `docs/team/reports/V70-dev2.md`。

P326作者正在整理冻结报告；可先审已冻结代码和已有日志，不等报告去重跑。现有证据：`.pi/team/state/bg/p326-{gate-runs,probe-compare,c4-floor}.log`，容器原始日志 `$HOME/.cache/p326-c4/c4.log`，现场 `$HOME/.cache/p326-c4/tmp/`。C4在2699秒被作者按原预算停止，rc143，没有最终suite结果。PM的 `p326-enforce-deadline` 检查发现容器已经自动移除，未发送信号。

## 要回答的问题

方案是否真的减少重复嵌套而没有漏掉必要产品行为？当前改动可否进入合并，若不能，现有证据支持的最小修正是什么？必须区分独立代码审阅与尚未完成的容器行为验收，不能给一个无边界的PASS。

- 对照提案与代码审floor并集、显式自检入口、路由基线/变异的保留入口、未执行段披露及选段依赖；只追实际调用链，不枚举44个场景做配额。
- 从现有日志定位最重的11c（1018秒），静态查昂贵调用与重复执行。必要产品行为不可仅因慢而删除，时长只作参考，不增预算。
- 已确定一个现场形状错误：容器仅将作者worktree挂到/work，它的.git指针却引用宿主Git公共目录，后者未挂入；冲突标记检查报找不到Git仓库。核明哪些红有同一原始原因、哪些尚不能归因，不能凭相似措辞统归环境。覆盖0i、34c、34d已有红；不能从这些无效现场断言产品已绿。
- 对照当前main的P318/其它已验收改动，指出候选合入会不会抹去它们；只读差异，不帮作者merge。

## 执行预算与交付

**不跑任何smoke、probe、变异、容器或计时实验，不重跑45分钟，不造新夹具，不改CI时限。** 本任务是独立静态阶段；只用git/read/rg等以及必要的轻量格式检查。证据不足就明确尚未验证，不补实验。

报告结论先行，逐项给文件/行或现有日志证据；列最小修正和必要验证的唯一后续入口，不能重新设计一套测试系统。若仅日志和现有代码不足区分某条失败，列一个最小可区分问题，交PM裁，不运行。提交前在自己的工作树检查ledger-ban与diff；local模式，不push。完整独立验收待修复批次最终固定环境运行后再收口，本任务不冒充它。
