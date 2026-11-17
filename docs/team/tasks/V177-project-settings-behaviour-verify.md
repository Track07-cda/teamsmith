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

P471实现者dev，最新交付`9c1adb1c0f52ef8fa1aad3593ced2cdc2d874ef8`；测试修订`22f9ad47bd23b26dc75981299598812db6c9fbb1`，产品源/bundle保持首次`081bcdd50a6961936f2493fc14261435ccb94254`不变。相对首轮`0b33fe1f`只有原KEEP导出一行及报告追加。PM新独立干净源`/var/tmp/p471-review-9c1adb1c.3bl6PT`，只读；旧独立源及你的首轮BLOCKED报告保留。你做过V175规划审阅，未参与实现，具备非作者资格。规划接受记录`reviews/pulse-project-settings-simplify-proposal.md`已ACCEPTED；本单是实际操作和实现对照，不重开规划审阅。

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
TEAM_GATES='TEAM_P21_KEEP=1 bash skills/teamsmith/tests/panel-p21.sh settings groups wheel choices choices-schema write conflict categories readonly flip' \
  bash skills/teamsmith/scripts/team review P471 \
  --dir /var/tmp/p471-review-9c1adb1c.3bl6PT \
  --branch 9c1adb1c0f52ef8fa1aad3593ced2cdc2d874ef8
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

## 前置返修后同任务续跑（2026-11-17）

首轮7f156d08真实前置BLOCKED已收存main，原批次0/10、子policy0/3，不抹历史。作者22f9ad47只把原keep=1行改为同时export TEAM_TMP_KEEP=1 TEAM_P21_KEEP=1；原参数/默认/身份清理/两破坏未变，仅bash语法及diff rc0，没有新增行为执行或重建bundle。

保持V177原模型/SID/分支，仅核0b33fe1f..9c1adb1c的这一行及报告后，直接在上面新源启动尚未跑过的原批次。规划、UI源/bundle/除该行外原测试均未变，不重新核原生context/version/作者静态/既有类型归属或全份方案。报告追加而不抹前置结论；完整映射和真实画面仍须完成。外层KEEP请明确放在TEAM_GATES命令内，子现场实际保留路径随输出记录；不用为先验证继承另跑一批policy。四个原有类型错误与1.6保持原边界。

## 本批FAIL后的分析收尾（2026-11-17）

唯一批次已执行：十场景全覆盖，外层177/16、ran1477秒，原件四份均保住；正式P471 FAIL原样保留。接着只完成当前原件/源码/实际画面的根因分类和最终报告，不再起任何UI/正常policy/变异/静态。八条相同排除键断言先给出具体命中行：`^│ [› ] .+`可能把空白填高行也当操作行，不只看末尾全局提示。相同原因合并发现，不为了保八个重复检查造新解析器或控制。正常policy也红，两个红侧尚不能视为恢复闭环，分别指出真正目标断言和正常失败的最早原因。

PM读真实settings/view.txt与commands.txt另见两个原定用户文案评估范围内的问题：900/1800时间值没有单位；设置底栏仍写“f 冲刷”。请结合现有帧/输入处理核当前视图中单位和可用操作的最低限度呈现，给原工件依据及最小修正建议；不另扫其它页面，不把PM观察冒充本人运行，也不先改实现。

报告对每类说明产品缺陷/测试错误/缺证、真正改变结论的帧/字节/命令、最小返修及需不需要真实重测。纯匹配问题优先用现存真实帧核修正，必要时可建议删合重复断言；不得以此减少仍应有的保存/取消/身份/故障观察。未改且已过的case不再整批重跑。四旧类型错误和未来merged另列，别混成新UI缺陷。提交当前最终归因即可，不等待PM再次确认，不提前跑返修后的验收。

## 最终报告接收后（等待新候选，不启动运行）

16bc42e7最终报告已接收，原9c1adb1c正式FAIL/原日志已逐字节存入私有`.pi/team/state/evidence/P471/round1/`。PM已交原作者同P471集中修C1/C2/W1/W2，作者只静态；本V177目前等待新候选与局部补验brief，不重开UI批次、不先生成runner或重跑正常policy。

D261已裁定C3的窄边界：基线四错不在本change修，返修后真实tsc如仍仅同四旧错且其它静态成功，可据该边界完成1.6的静态交付；完整tsc始终rc2/FAIL，报告保留该边界而非称全绿。不增加第二个解析/写入源或可选类型来掩盖旧问题；你后续只核真实新回执和差异，不重复编译或作者静态。

最终候选后，纯空白匹配先用本批保存帧；真实交互缺口与原两破坏/正常恢复按新差异作最小定点补验。原10场景不再全跑，未改且通过的保存/CAS等证据复用。具体命令在新候选后由PM决定，当前无新gate授权；C4 merged输入仍未给，不提前声称已完成。
