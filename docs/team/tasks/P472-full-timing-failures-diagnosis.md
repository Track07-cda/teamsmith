---
id: P472
title: 只读归因完整计时暴露的两项失败
agent: verify
category: analysis
phase: opsx-explore
change: -
specs: verification#A gate that cannot judge says so
deltas: -
branch: task/P472-full-timing-failures-diagnosis
---

# P472 · 用已有材料区分真实缺陷、检查错误和证据不足

V174的一次完整运行已结束，固定`532c8b474f9aa3ec9d9094b28ae88463cd9d88e5`，140段/5139通过/2失败/19跳过，检查6704秒。测量交付可关闭，FAIL不改，不重开五批精简或把它设成新功能前置。你是原测量者，只做现有两失败的只读最小归因，不修实现。

## 输入与具体问题

先读本线程/本brief/OWNERSHIP及`docs/team/reports/V174-verify.md`、`reviews/V174-acceptance.md`。原始材料在`/var/tmp/v174-verify.aScB4e`，另有main根私有副本`.pi/team/state/evidence/V174/raw/`，13文件逐份SHA匹配。PM固定源仍在`/var/tmp/v174-review-532c8b47.RgzJCh`；自己的稳定任务分支可能在后续main，读代码用固定源或git对象，不让后续设置实现替代测量版本。原smoke/snapshot子现场已默认清理，不能声称仍有帧或Pi journal。

1. **F1**：完整log4769–4775，38-f汇总失败，内层apply/restart/refuse三种徽章tone检查都报label=0/badge=0。沿既有p21的产生输入/取得帧/定位标签与badge/断言调用，核实际布局输出约定，判断现有材料能否说明是查错结构/文本/状态或产品没有画出。P470已批准方向将取消逐行badge，尚未实现；不要为过时表现另开并行修补，也不能仅以将来删除为由宣布当前通过。说明是否还有不应丢失的行为需要带进UI验收。
2. **F2**：完整log5856–5873，`remind-tool-real.mjs:557`在busy-follow-up/manual-G2场景未看到custom_start/team-reminder。沿案例等待/采事件/消息入队/消息实际开始及待命代次判断，核固定源的原产品接口及已用SDK事件形状，区分哪个前提或观察缺失。不能把断言失败说成负载/网络/超时太短而不给证据；也不能用源码推断代替丢失的实际事件记录。

每项先答已证实什么、仍不能证实什么、下一步最小范围是什么；有源码调用位置或原始日志支撑的结论才写。若现场缺失使根因不能确定，就明确缺哪项及一条足以区别假设的最小后续观察，交PM裁定，不猜根因/主动复跑。读安装包公开类型/文档可以，不启动Pi、不读auth/models/凭据文件。

## 写集与执行

只写自己稳定工作树任务分支`docs/team/reports/P472-verify.md`。不改产品/tests/正式spec/规划/版本、真实配置、队列/提醒/待命或任何其它项目；不安装/重启/新起tmux或模型，不执行业务样本/正常或变异用例/完整测试/构建/native change校验，不搭新的复现框架。现有原件只读，不再清理；不是让你给V174补一次通过记录。

可用read/rg/git show/diff对已有源及材料核对；计时表无需再算或重做报告。报告提交前仅本人报告的ledger/diff短检查，不调用team review默认门禁。短检查真实回执、可定位证据、已观测与推断边界随报告交付，Conventional Commits含P472及`Agent: verify`；小步本地提交、不push/merge/archive/tag/npm。完成即通知PM；不需要中途确认，不因不能确定根因自行扩大运行。
