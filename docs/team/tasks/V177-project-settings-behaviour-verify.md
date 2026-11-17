---
id: V177
title: 独立验证Pulse项目设置精简的实际操作
agent: dev3
category: verify
phase: opsx-verify
change: pulse-project-settings-simplify
specs: panel, memory-and-deps, verification
deltas: -
branch: task/V177-project-settings-behaviour-verify
---

# V177 · 一次受影响UI批次，逐页看真实画面

P471实现者dev，最终交付`0b33fe1ff28c83d5cb47973564400ee8e3579eee`；产品/测试冻结`081bcdd50a6961936f2493fc14261435ccb94254`，之后只加报告。PM已准备独立干净源`/var/tmp/p471-review-0b33fe1f.MdTZSf`，只读。你做过V175规划审阅，未参与本change实现，具备非作者资格。规划接受记录`reviews/pulse-project-settings-simplify-proposal.md`已ACCEPTED；本单是实际操作和实现对照，不重开规划审阅。

先读AGENTS、本人线程、OWNERSHIP及本brief；读openspec-verify-change skill，在固定源用现有OpenSpec1.16的status/instructions apply定位并读完整contextFiles和P471报告。原生任务当前5/9，1.6及未来验证/合并项未勾是实际状态，不能先声称归档就绪。命令读取是上下文，不是让你实施或同步正式spec。

## 先核实现，再只跑一次原定UI批次

核对原生ADDED/MODIFIED行为、REMOVED对应旧正式块及必要行为承接，真实代码与原检查是否测到了目标。重点是删的是旧全表/徽章/内部说明，不是保存、来源完整性、响应和必要错误；规则编辑仍走原完整值/CLI/CAS，不建立第二套匹配规则。报告须指向实际调用与证据，不只写作者报告说通过。

本轮唯一行为命令为原定：

```sh
bash skills/teamsmith/tests/panel-p21.sh settings groups wheel choices choices-schema write conflict categories readonly flip
```

从自己的稳定任务工作树，使用原有review锁及正式工具执行，避免默认全套：

```sh
TMPDIR=/var/tmp \
TEAM_GATES='bash skills/teamsmith/tests/panel-p21.sh settings groups wheel choices choices-schema write conflict categories readonly flip' \
  bash skills/teamsmith/scripts/team review P471 \
  --dir /var/tmp/p471-review-0b33fe1f.MdTZSf \
  --branch 0b33fe1ff28c83d5cb47973564400ee8e3579eee
```

先只读P21现有运行前提及保留证据参数，按既有方式指定本人唯一/var/tmp证据根、保留现场；不能为准备环境先跑正常policy/完整配置检查/全组。若原脚本保留条件不足以保住真实帧和config/argv/事件，先交具体缺口，不自行扩写框架或改固定源。一次批次内保留原flip两处真实产品破坏及正常policy收尾；不额外单跑正常policy、不增加第三项变异。两个红侧必须由原目标行为报错，不能把替换失败、启动失败或语法错误算检出。

真实pty/键鼠/CLI写入均只在本次隔离项目，无外部模型或其它项目，不启动/重启真实团队Pulse，不写真实配置/提醒/待命。固定源不得留node_modules、snapshot、日志、bundle改写或ignored产物。

## 检查组织与取证，不另建要求清单

以原生tasks 1.1–1.5、2.1的对应工件及作者“退休展示断言与必要行为承接”表建立证据索引，核对源、原场景及实际操作是否闭合；要求正文仍只以三份delta为准。给实际类别数/默认行数/编辑入口数和数据前提，不把C3的10行例子说成所有项目都只有10行；记录/表单字段不混入设置数。保存、冲突、错误、记录来源与原flip结果用实际config/argv/事件证明，不另跑或复刻CLI全量。

**逐页看**本批实际捕获的默认页、项目命令、模型记录、规则列表/字段、确认和错误画面，不只看断言总数。按已有UI文案规则从普通用户角度核对标签、说明和生效提示；如果计数下降但仍有原问题，指出具体控件/画面和最小修正。保留供PM查看的实际帧路径及对应交互；隔离样例不冒充用户实际设置，设计草图不冒充新界面。中文/英文、宽/窄、短/长只看原场景中的片段，不为组合另跑一遍。

## 既有静态失败必须单列

P471的完整类型检查仍rc2、4个OutboxListBlock TS2339，1.6未勾。实际基线对照及其它静态回执在`/var/tmp/P471-dev-static.FEHqfA`；作者起点66ab596d真实导出相同4错。PM已核19份编译源码/config与原SHA、同依赖树；起点到候选未改相应消息列表读取/声明语义。构建、字符串、change strict、spec refs及语法等有原回执，源与冻结bundle身份见作者报告。

你的任务是独立看这些原件及实际差异是否支持归属，不重跑两次tsc或作者已完成的构建/字符串/strict/引用。报告将“设置实际操作结果”“完整类型检查仍失败”“1.6完成判据还缺什么”分别写清。不要预设旧错误一定是本change阻断或一定可忽略，给出原文/源码/回执依据及最小建议；未经PM裁定不勾1.6，不补optional/as/ignore或顺手修其它页面。UI批次通过也不能写所有检查通过/可归档。

## 写集和交付

只写本人任务分支`docs/team/reports/V177-dev3.md`；主检出唯一例外为正式工具生成`docs/team/reviews/P471.md`与`P471-verify.log`。本轮不写产品/tests/规划/正式spec/tasks，不改任务勾选；报告逐项说明真实完成项和未验项，后续由PM依真实证据推进状态。

真实长命令用team_bg_run一次启动后结束回合，完成唤醒再team_bg_wait，不轮询、不回合内等；既有超时不延长。不要并行其它gate。禁止smoke/FAST/meta/61b/完整计时/安装验证/真实Pi模型/新增截图矩阵。报告暂存后仅本人ledger/diff短检查，小步本地提交，Conventional Commits含V177及`Agent: dev3`；不push/merge/archive/tag/npm，不清别人或本次原件。

报告先给本批UI PASS/REWORK及总体未完成边界，三维Completeness/Correctness/Coherence、CRITICAL/WARNING/SUGGESTION均按事实列；保留原flip失败名/rc、恢复、真实画面、配置/argv及原件路径，不以静态或源码推断冒充操作。只统计真正执行的场景，实际时间仅作参考。

## 合并后（当前不执行）

同一你接PM新固定merged源，核本change实际UI源/bundle/相关测试/依赖读路径同一性；相同只做必要短接入，不重跑本批。main已合入P473的提醒测试一行，与你的UI路径无关，不把该已知差异当作重新跑UI的理由。任务/报告进度差异也不是产品字节变化；若相关行为真有差异先交PM裁范围。不提前声称最终merged或归档已通过。
