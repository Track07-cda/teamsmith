---
id: P455
title: 模型路由参数检查与重复全跑精简提案
agent: dev2
category: analysis
phase: opsx-propose
change: routing-argv-check-slimming
specs: verification
deltas: verification
branch: task/P455-routing-argv-slimming-proposal
---

# P455 · 三处执行精简的局部提案

输入为已接受的 P454 探索报告 `docs/team/reports/P454-dev2.md`（报告源提交588c8df0，PM接受 `docs/team/reviews/P454.md`）。用户要求缩短一次完整测试本身、不要过度防御；本阶段只规划，不改测试和产品，不插入0.4.7冻结发布对象。

## 定界

三处候选：worker-literal-resplit、pm-literal-resplit 两臂以真实 shell argv 短检查替代完整 boundary；删除结尾在未变异原树重复执行的第二次CORE。首个正常CORE与正常产品路径保留。明确本批只减61b、不宣称一阶61已变快；旧三次1419s是历史成本，不是净提速承诺。

先做一个PM短样本，回答唯一剩余未知：不stub真实 team_pm_identity_guard，extra和显式resume SID是否都能在合法私有前提下直接观测实际shell argv，并让原pm-literal-resplit变异红、原字节恢复绿？仅运行这一个窄样本，不重跑boundary/CORE/61b/full，不靠长等待造前提。若PM样本不成立，本提案只纳入CORE和worker两处，保留原PM臂，在报告明确缩小范围；不扩成身份/启动框架重构。

短检查使用独立固定预期和实际Bash参数，不把产品lexer输出与自身比较。必须接到现有--flip父级失败记账，保留正确失败名字和child rc传播；恢复验证对象是同一副本。可以舍弃两个旧整组里与参数拆分无关的附带观察，不声称那些观察全部等价保留。

## 交付与规格

在自己的分支用当前OpenSpec脚手架创建 routing-argv-check-slimming，先运行 context/list 确认本项目root，再new change，按status/instructions创建必要规划文件。不手工创建change根，不复制基准规格，不改主spec。

verification delta只为本批实际退休的执行提供窄例外，保留现有其他具名例外；不把当前一次性优化变成新的全局拒绝/流程检查。设计文件只在schema要求确有必要时创建，不为了三处删除写架构稿。

规划需说清旧执行如何实际删除、正常真实调用方覆盖留在哪里、实施者怎样用短样本与具名失败证明接线、哪一个完整运行才需要在交付时跑一次。性能读数只作参考。新检查必须替换旧检查，不添加独立验测试的再验层，不保留隐藏slow备用入口。

不要强制为每一个小提交、候选、报告补提交各重跑完整矩阵。实施后的独立验证范围应由真实差异决定；无产品变化的合并可核对文件同一性并补关键调用点，不再机械重复小时级全量。最终证据与未测范围必须可核对。

报告 `docs/team/reports/P455-dev2.md` 首先给最小范围、PM样本结果与尚需独立审阅的点。仅跑 change结构校验、spec refs、ledger-ban、diff check及上述PM窄样本；不运行产品完整门禁为规划取证。完成后提交并通知PM，由非作者独立审阅，未接受前不实施、不归档、不合并、不发布。
