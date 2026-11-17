# pulse-project-settings-simplify · PM proposal review

verdict: **NEEDS-CHANGES** · reviewer: pm · 2026-11-17

P470冻结交付`26f5e08eb44e3648c4bd35546983bdb959ef8222`，工作树干净，pre-merge检查无未提交账本。PM已读六份原生规划文件、本人报告及对应设置布局/模型并发代码；尚未接受方案或授权Apply，不把作者strict通过当独立审阅。

## 方案及待裁定内容

按同一C3/A5/L1/U0示例，设计为默认127→10可选行（8编辑+项目命令/模型记录两入口）；整个设置配置编辑入口C+8，不包含规则表单内字段或按钮。相较P469候选，4资源阈值全部退出UI，不另建资源页；只保留有项目接入/模型差异查询用途的两个低频入口。并发字段表单编辑原完整值，底层schema/CLI/writer/默认及运行语义不改。上述都是未实现设计，不是新界面测量。

V175交非作者dev3审阅，固定独立源`/var/tmp/p470-review-26f5e08e.eA48zu`。重点核删减与入口是否足够简单、用词和数字是否诚实、规则表单对0/空/重叠及共享计数的呈现是否准确、无损字节/异常回退是否过重、4退休+3新增是否保住不应删的既有行为，以及未来一次UI验收是否真实可执行且无重复长测。

## 已有证据与当前边界

- 作者原生status4/4规划齐、6文件与9未勾实施/验收项、strict/spec-refs/ledger/diff回执：`docs/team/reports/P470-dev2.md`（候选分支，尚未并入main）。首轮strict失败及之后显式退休的修订原样保留，PM未代跑检查。
- 独立证据：V175报告1b0e8c80已由PM逐项读源码接受并原文收存至main 10a76598，结果REWORK；真实change strict=0、ledger hits=0、两diff=0。结构通过不代表方案无冲突，未来UI行为/键鼠/窄屏/英文/真实保存均未发生。
- 只规划，未改产品/tests/正式spec/用户配置/版本/真实状态。V174固定532c8b47的一次后台计时与本案独立，不等待或重跑。

## Required changes · 首轮V175

1. C1：verification正式覆盖保留条款与退休设置全表断言冲突。授权P470只在该change加verification delta，给`A gate that cannot judge says so`及相应场景加本次展示替换的窄例外，保留其它覆盖/旧例外，不改正式spec或新增检查。
2. W1：既有snapshot只涉及偏好菜单而非项目设置，作者不跑其整轮；布局落在同一次非作者p21 settings/wheel，红侧用原scn_flip实际入口，并复用它的正常policy收尾，不额外重复policy。
3. W2：标签用“模型同时运行任务数 / Concurrent tasks by model”，0用“此项不限制”；原模型范围内worker合计不冒称整个项目总数或解除其它规则。
4. S1采纳：移除空白分隔字节必须不变的额外承诺。保留token/顺序/重复，实际改变并保存才拼接完整值；取消/非法/冲突仍不改原配置，不造无损解析框架。

P470/任务头/delta授权已更新为三cap，默认计数及两个入口不重开。原作者同任务/模型/SID/分支已交规划93b3bc2b及最终报告96750d49，写集只有六个规划/报告差异文件；作者本轮strict/spec-refs/ledger/diff回执rc0，PM已看实际diff及verification完整原块对照，不代跑验证。

原V175继续，仅复看C1/W1/W2/S1；新固定独立源`/var/tmp/p470-review-96750d49.2Mtu5O` @ `96750d494ff412e138b82156395ec3ab2fc1eb3a`，旧源和首次REWORK不动。本轮只补新源一次必要strict，不重跑首轮ledger/root/版本或UI、业务、归档、完整套件。本记录仍未ACCEPTED，不派Apply。

## 最后一句 · C1-R1

V175第二轮64037777（main f5cdf248）已关闭W1/W2/S1，C1原23场景同序、21正文未改及旧四类例外成立。唯一遗漏是保留TEAM_GATES编辑器的schema-kind/没有选项集文字及其等待断言，p21:1046/1053确实强制显示，而已认可panel delta要求删除此教学。PM核原文后授权原作者只把该短语补入现有显式退休清单；其余规划不动，不再跑检查或重开设计。新提交到齐后原V175仅从固定Git对象确认这一句及其余字节不变，沿用96750d49的结构回执并保留原SHA，未ACCEPTED前仍不派Apply。

C1-R1最终作者交付`f987cc05b924bb38e8f757236e7e220e8c39ca2c`：仅verification段内两行及本人报告；PM已看真实diff，加入保留编辑器内部说明/等待条件的退休及正常编辑器观察，不引用已撤回的“54字”。原V175现从固定Git对象仅核此处，不创建第三份检出或重跑检查。独立最终结论未到，仍NEEDS-CHANGES。
