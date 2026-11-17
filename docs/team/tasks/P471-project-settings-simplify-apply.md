---
id: P471
title: 实施Pulse项目设置精简与用户文案
agent: dev
category: code
phase: opsx-apply
change: pulse-project-settings-simplify
specs: panel, memory-and-deps, verification
deltas: -
branch: task/P471-project-settings-simplify-apply
---

# P471 · 按已接受方案实现；作者只静态，非作者一次行为验收

PM接受记录`docs/team/reviews/pulse-project-settings-simplify-proposal.md`已ACCEPTED（ecde1365/D260）。作者dev2的最终规划f987cc05、非作者dev3最终审阅2eb1e8e2已合并7a2e2918；仅delta末尾空行规范化，正文未变。你未参与规划/审阅。用户要减少日常设置数量和内部语言，不是把完整清单搬进高级页；没有真实配置写入或新版本发布授权。

先读AGENTS/本人线程/OWNERSHIP、本brief及openspec-apply-change skill；用现有OpenSpec1.16在本工作树读list root、status及instructions apply，完整读取其contextFiles。原生proposal/design/三份delta/tasks是唯一范围，不在brief再复制要求。只完成tasks **1.1–1.6**，每项实际完成并静态有据才勾；2.1/2.2/3.1留给非作者及merged阶段，不提前勾验收/归档。遇真正设计冲突交PM，不自行改规划/增加能力。

## Boundaries · 本任务明授写集

- `skills/teamsmith/scripts/panel/src/**`：仅设置展示、局部导航/规则草稿、类型及中英文；复用原数据块/CLI路径，不改变数据协议、匹配算法或后台行为。
- `skills/teamsmith/scripts/panel/panel.js`：仅现有钉住工具链生成，禁止手改。原`panel/README.md`、`skills/teamsmith/references/config.md`及`skills/teamsmith/SKILL.md`只更新对应设置说明，不改版本/无关协议。
- `skills/teamsmith/tests/panel-p21.sh`、`skills/teamsmith/tests/panel-strings.mjs`：在原场景替换本change点名退休的展示断言，保留必要观察；不新增脚本、检查段、词表或快照/平台矩阵。原flip两个产品破坏及正常policy收尾保留；失败必须来自实际被改坏的目标行为，不能拿注入失败或语法错误冒充检出。
- `openspec/changes/pulse-project-settings-simplify/tasks.md`仅勾本人完成项；本人`docs/team/reports/P471-dev.md`。其余规划/正式spec只读；schema/配置writer/common运行语义、真实配置/提醒队列/待命均不改。

源与bundle/相关原测试分小步提交，及时给出可读进度，不把整批留未提交。不要先建通用设置系统或无损解析器；规则编辑只处理原完整值的字段草稿，原token/顺序/重复及取消/错误/冲突按已接受工件承接。同步展示/交互/用户文案，不仅删行。

## 本轮真实命令 · 仅静态

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
# 依赖未就绪时才按panel/README使用bun install --frozen-lockfile；不升级依赖。
(cd skills/teamsmith/scripts/panel && bunx tsc --noEmit)
bash skills/teamsmith/scripts/panel/build.sh
node skills/teamsmith/tests/panel-strings.mjs
openspec validate pulse-project-settings-simplify --type change --strict --no-interactive
bash skills/teamsmith/tests/spec-refs.sh
# 报告暂存后，仅本任务交付检查
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
git diff --cached --check
```

不运行pty、snapshot、config-cli/panel-choices全量、smoke/FAST/meta/61b、真实Pi、性能或完整计时；不启动/重启真实Pulse。本次V174已完成且FAIL保留，两旧失败由P472只读归因，不等待它全绿、不顺手修提醒。没有“静态通过所以用户操作通过”的说法。

交付冻结候选后，由PM另派非作者在独立检出**一次**执行原定`panel-p21.sh settings groups wheel choices choices-schema write conflict categories readonly flip`；已接受的中英文/窄屏/键鼠/短长列表及真实保存、错误、只读来源放同批，不把每种尺寸/语言跑一整遍，不单独再跑policy。合并后同一人核同一性与必要短接入。你本轮不得提前执行这些场景。

## 交付

报告先给STATIC-READY/阻塞结论及实现范围；写真实命令/版本/rc/输出和bundle来源、退休断言到替代/保留行为的映射、候选产品/测试SHA与尚未执行的行为验收。UI10行仍是C3设计数，未有真实画面前不能写实测127→10。Conventional Commits含P471及`Agent: dev`，本地分步提交，不push/merge/archive/tag/npm；慢命令用team_bg_run后结束回合，完成唤醒再收，不轮询等待。自己的具体临时根用/var/tmp，原件留到PM收存；不碰别人的根或主检出。

## 已见的原有typecheck问题（只记录，不扩大当前范围）

首次静态检查报告OutboxListBlock的4处impediments/impeded错误。PM只读核对：既有types只声明entries/queued/held，queue布局却读另外两字段，而`team_panel_outbox_list_json`也没有输出它们；不能直接补两个可选类型或强转来掩盖问题。当前不授权改队列页面/读接口；继续本brief其余实现与静态，保留完整原错误及版本/源SHA，最终明确typecheck仍非0、1.6未全满足，不报全静态通过、不重跑业务。代码与声明相同只是源码归属证据，不等于已实际运行基线编译。待候选交付后，非作者确认归属并由PM裁定最小修复，不另起无关页面实现。

实跑对照已到：`/var/tmp/P471-dev-static.FEHqfA/{typecheck,baseline-typecheck}.log`均4个同字段TS2339、rc2，行号随设置布局改动平移；PM已逐份读取。基线19份实际编译源码/配置与66ab596d逐字节相同，共享同一依赖树；没有复制的bun.lock不属于tsc输入，任务也未修改锁或包配置。这支持原有问题的归属，不等于全类型检查通过。不授权补optional类型或改队列；无需等进一步授权才交候选：收齐其它真实回执，提交bundle/报告并冻结，明确STATIC-PARTIAL及1.6待解决，随后可做设置的非作者独立验收。其余构建/字符串/本change严格结构/引用rc0，不追加已完成运行；最终是否接受该静态边界由PM据非作者结论裁定。

## V177前置窄返修：传递原有保留参数（2026-11-17）

非作者报告7f156d08已确认：原十场景尚未运行，UI执行0/10、policy子运行0/3。现有P21入口保存TEAM_P21_KEEP后清掉TEAM_*，只恢复TEAM_TMP_KEEP；flip三次policy子运行重新进入入口时收不到原KEEP，因此会清掉子运行现场。不是新产品缺陷，不重做设置实现或规划。

只在原脚本已有`keep=1`的export处同时恢复`TEAM_P21_KEEP=1`，让原三次policy调用收到同一既有决定即可；这是推荐的一行修正，不新增开关/清理规则/场景。等效的局部参数传递亦可，但不扩改其它代码。原正常默认不保留、两种破坏/失败名/rc、恢复policy与身份清理均不变。

同一P471模型/SID/分支继续，仅做这一行及报告最新冻结SHA/事实追加；不改产品源/bundle/任务勾选，不重跑构建/类型/字符串/strict/引用或任何UI/CLI/flip。只对修改脚本跑一次bash -n、本人diff检查，小步本地提交并冻结；已有ledger回执不用因这一行再跑。报告保留STATIC-PARTIAL和原四错/1.6未完成。交付后原V177只核这一行，再在新独立源启动尚未运行的原定一批。

## V177完整归因后的集中返修（当前有效，D261）

最终报告`16bc42e763d0cb9f54f56860fb6079b57c3b7d2f`已收存main；先读其“最终三维评估与交付”。原批次已执行177/16、1477秒，四份真实现场保留；不是16个已证实的产品缺陷。原UI通过尚未取得，不恢复旧全表/徽章来迎合旧断言。

保持同P471模型/SID/分支，一次集中修C1/C2/W1/W2：

- C1仅修原测试的观察、准备与操作路径。空白填高不算操作行，可合并/删同因重复断言，不新建解析器或全键矩阵；wheel用已有过滤/聚焦把真实类别放入可见窗口再Enter，不加扫描器；异常规则用定点替换原配置行并核实际读值，不追加第二个同名赋值、不改配置解析器；categories/readonly/policy在回父页后清其恢复的筛选，并确认起始层后继续，不用盲按Esc、sleep或延长等待掩盖路径错误；迁移诊断只去原实际行，不恢复旧长说明。两原破坏和正常policy收尾保留，路由破坏须真正到目标写入，不能以共同导航失败冒充检出。
- C2就地用已有断言/比较恢复原`assert_neq`意图，不吞command-not-found、不删除比较、不加全局错误扫描或新断言库。
- W1在两个现有时间设置的行、原选择器范围/选项及编辑提示中明确秒/s；仅显示改变，实际数值/存储/范围/选择回调不变。不添加解释段，不改其它设置。
- W2设置/其子编辑器打开时，只显示当前可用按键和返回操作；移除此处的四个全局动作及点击目标，解决冲刷用词、键鼠不一致和窄屏返回不可见。不重命名全产品、不更改其它页面动作或发送逻辑，不用另一段解释替代无效按钮。

### 静态交付当前边界

D261明确接受已由非作者确认的四个旧TS2339作为本change已知失败，覆盖此前“1.6未勾/待PM裁定”的暂定安排；不是修好了旧错误，也不是typecheck成功。此次确改UI源，只运行一次当前源的`bunx tsc --noEmit`、原build.sh、panel-strings及修改脚本bash -n；保留完整命令/rc和新bundle来源。只有仍为同一四错且无新增、其余上述检查成功，才能按该窄边界勾1.6；否则正常报告阻塞。不得过滤错误或修改退出码，不补optional/as/ignore、不改队列页逻辑。

规划/delta/正式spec/CLI未变，不重复strict/spec-refs、安装依赖或原已完成的静态矩阵。报告新增内容仅必要ledger/diff一次；原5个实现勾选保留，2.1/2.2/3.1不得由作者提前勾。静态整体如非0照实记录，不以PM范围接受伪造全绿。

分步本地提交测试修订、UI单位/按键带、原工具生成bundle及真实报告；冻结新产品/测试SHA，原失败原文不抹。**本轮作者不执行UI/任何policy/flip/CLI业务或全套。** 后续由原V177按实际差异做局部补验：纯匹配用现存真帧、未到达交互只补相关路径，既有未改且通过的保存/CAS证据复用；不重跑原十场景，也不先自行另跑七组。具体补验命令由PM在新候选后裁定，不新建产品开关/测试框架。真实团队、0.4.7及所有现存原件仍不动。
