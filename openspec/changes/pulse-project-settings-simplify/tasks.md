# Tasks

所有方框均为后续实施/验收工作，本propose不勾选、不执行。PM正式接受提案后才派一个Apply批次；实施者不是本提案作者，验证者不是实施者。本变更只改UI及其原有检查，不新增schema、后台行为或检查段。

## 1. 实施者：产品、同组检查/文档及静态自检

- [x] 1.1 实现精选行集、用途顺序、两个具名入口/返回与隐藏键错误呈现；同步改原`settings/groups`和字符串断言，退休全键/unknown自动出现/schema组绑定/逐行class/磁盘键必显示检查，并同步项目设置说明。完成判据：diff显示只选8既有键和全部实际类别，类别不硬编码；展示投影与字符串的静态核对支持默认C+7、全配置编辑入口C+8、CLI schema/group读写未变。覆盖`panel`的“Project settings expose selected user operations…”（含退休磁盘块的保留事实）、“Settings groups follow user purposes…”及`memory-and-deps`的“The machine read reports each key's functional group…”；同步`verification#A gate that cannot judge says so`的本次点名展示例外，报告旧断言到替代/保留行为的映射，不补旧计数；CLI全量行为引用既有证据，不重跑config-cli/panel-choices。
- [x] 1.2 用适用模型/同时运行数量字段编辑同一`TEAM_MODEL_LIMITS`草稿，保留token/顺序/重复/匹配语义及异常整值修正；在原`choices/choices-schema`中替换隐藏enum/path和旧pattern语法样例，文案只用用户字段。完成判据：类型/展示投影静态核对及diff证明无新存储或匹配算法、普通表单无手写`pattern=N`步骤，未修改token的内容/顺序/重复保留，实际修改保存后空格连接完整值，取消/非法/冲突保持原字节；主名称为“模型同时运行任务数 / Concurrent tasks by model”，0为“此项不限制”，摘要按实际项数显示，例如“2项”；覆盖`panel`的“Selected settings editors preserve owning-command choices and writes”中Separate fields场景及保留的choice来源/响应性。
- [x] 1.3 保留选择直接写/自由输入确认/危险值额外确认及CLI/CAS/actor/后台重读流程，改用用户标签、必要PM/Pulse生效提示；同步原`write/conflict/choices`见证键为保留键，危险值用`TEAM_REVIEW_TIMEOUT=30`，不增加复刻CLI检查。完成判据：静态调用链及测试diff保留原argv/字节/冲突/失败/取消证据点，无重启/执行按钮或恢复默认伪操作；覆盖`panel`的“The console writes a project setting only through…”及choice危险/取消/冲突场景。
- [x] 1.4 把assignments/pm_launch移入“模型记录”，保留完整模型/任务/类别/SID/来源、missing与unreadable区别，PM只称上次启动；同步`categories/policy/readonly`场景入口及两语文案/说明，并仅调整原`scn_flip`受本显示改动影响的产品触点，保留其两个破坏及正常policy收尾，不新增变异。完成判据：静态投影保持源值、不会借新策略补记录、只读路径不调用writer，原不同策略/记录模型和同任务预览样例保留；覆盖`panel`的“Settings edit task categories and independent PM policy rather than worker seats”。
- [x] 1.5 调整默认/命令/记录/规则编辑器的当前行集窗口与焦点，就地更新`panel-p21.sh settings`既有filter-fill/高度与计数断言及`wheel`场景，长输入改用实际类别/记录，不新增静态布局入口或截图矩阵。完成判据：测试diff保留短/长列表、卡片填高、实际行数、焦点/鼠标/窄屏的观察位置，实际行为全部留给2.1同一非作者批次；作者不执行pty或整轮snapshot。覆盖`panel`的“The settings view fills the pane it is given…”及显示块焦点/导航场景。
- [x] 1.6 用现有钉住工具链更新bundle并完成静态交付，报告逐一指向上述工件/场景，冻结产品/测试SHA。完成判据：按`skills/teamsmith/scripts/panel/README.md`既有命令执行typecheck/build、`node skills/teamsmith/tests/panel-strings.mjs`及短结构/引用/diff检查，记录真实rc与bundle来源；不得运行pty、smoke、meta、平台/模型矩阵。这是1.1–1.5的集成静态证据，不是UI已验。

## 2. 非作者验证者：独立固定检出，一次受影响UI行为验收

- [x] 2.1 在PM准备的独立冻结检出/既有隔离环境一次执行`bash skills/teamsmith/tests/panel-p21.sh settings groups wheel choices choices-schema write conflict categories readonly flip`。完成判据：原场景给出实际键鼠画面、config前后字节、argv/actor/CAS、保存/取消/非法/危险/失败/冲突、2入口/返回、全部实际类别、规则完整值及只读来源的证据；中文主路径混合真实键盘/单击二击/滚轮，英文与窄屏在同批既有片段走到入口/返回和编辑/失败，不按语言尺寸重复整套。短/长/计数/填高复用settings/wheel；红侧使用原scn_flip的类别写路由与策略冒充记录产品破坏并检查其正常policy收尾，不额外独立执行policy，也不把schema输入改动说成产品变异；不新增长变异矩阵。覆盖三份delta的全部受影响场景，CLI未改场景只核既有证据和代码同一性。
- [x] 2.2 提交独立OpenSpec completeness/correctness/coherence评估及实现ID的正式执行记录，逐项说明引用证据与实际执行、退休断言、未测范围及问题。完成判据：三份delta的9个原对象的修改/退休及3个替代块都有落点（verification仅本次展示例外，原23场景身份和旧例外保留），原完整CLI证据带原SHA/范围而非伪称新tip跑过；PM可以从报告、原日志及冻结SHA接收或退回，不把作者静态或文案审阅称作UI通过。

## 3. 同一验证者：合并后同一性与必要短接入

- [ ] 3.1 PM合并后在独立检出固定merged SHA，对比冻结候选的产品/bundle/测试/已验工件同一性；相同则复用2.1的完整UI证据，只做打开设置、一个入口返回及必要结构/引用短检查。完成判据：报告明确candidate/merged SHA、比对范围/结果及实际短命令；若存在影响行为的差异，交PM按差异另派，不重复整组或冒称旧证据已经验证新行为。关联1.1–2.2全部修改块的合并完整性。

## Workflow follow-up

- PM接受同一验证者merged证据并取得用户确认，或记录符合既有条件的窄范围代理确认后，另派非实现者执行archive；未测范围/警告在确认前明示。
- Archive worker只按原生流程同步这三份delta并移动工件，核对其余正式spec/Purpose不变，运行必要结构/引用/diff检查；不为归档重跑UI/CLI套件。此项为独立阶段，不纳入Apply方框完成数。
