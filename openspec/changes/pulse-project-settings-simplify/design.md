# Design

## Context

动机见`proposal.md`。本设计复用已接受的探索，不重跑页面、业务或计时：`docs/team/reports/P469-dev2.md`的原输入是C=3（有效任务类别）、A=5（名册成员）、L=1（PM启动记录存在）、U=0（未知键），默认118键加模型合成行得到127可选行。120×30旧页首帧23键都不能编辑；这不是用户真实配置截图。

本轮补看的源码仅用于收敛方案：`layout.ts/settingsViewRows`当前按schema组排全表，类别/派单/PM记录在末尾；成员表的列是姓名、状态、任务、分支、会话占用，不提供设置读侧的完整模型/SID/来源对比。`App.tsx/buildChoiceEntries`当前把模型词插成`<model>=`再交自由输入；`cmd-config.sh`的pattern校验及`common.sh/team_model_limit`已经决定匹配含义。没有执行这些函数或读取真实项目值。

## Goals / Non-Goals

**Goals:** 只改变现有设置读侧的展示投影、编辑交互和文案；选模型不经过路径/内部运行参数；低频内容只有确切用户目的才保留入口。所有规范承诺在三份delta，下面给实现取舍和未实现草图。

**Non-Goals:** 不改schema/完整CLI/group、默认/choices/值域/writer/CAS/actor/危险确认；不改匹配、派单、换模、恢复、容量检查或真实配置；不新增偏好、通用高级页、模型目录、记录库、迁移/重启/执行命令按钮。P469的8+3不作为上限或既定界面。

## Decisions

### 1. 默认页C+5项编辑，两个低频入口

只推荐这一种方案。配置编辑对应8个既有键，另加全部实际类别操作，不维护第二份配置schema。

| 位置 / 中文标签 | 英文标签 | 既有来源 | 保留理由及生效信息 |
|---|---|---|---|
| 模型 / 类别原名 | Models / category name | `models.policy.categories`，逐类`set-task-model` | 任务类别是项目自己的词，按读侧顺序全部显示；选中和保存时标“新任务生效 / New tasks”，不改既有任务 |
| PM模型 | PM model | `TEAM_PM_MODEL` | 独立于类别；选中和保存时标“重新启动PM后生效”，换模型所需`team up --fresh-pm`只在此时显示 |
| 模型同时运行任务数 | Concurrent tasks by model | `TEAM_MODEL_LIMITS` | 对后续派任务的实际数量限制；进入模型/数量表单，不要求手写配置串，不停止现有任务 |
| 自动检查 / 检查间隔 | Automatic checks / Check interval | `TEAM_PULSE_INTERVAL` | 控制完整自动检查周期，不冒称消息速度/Reminder精度；选中及保存时提示Pulse重新启动后生效 |
| PM每小时自动恢复次数 | PM recoveries per hour | `TEAM_PULSE_MAX_RESTARTS` | 已有自动恢复配额；0仅在选中时说明“不自动恢复” |
| 启动时检查新版本 | Check for updates at startup | `TEAM_UPDATE_CHECK` | 指teamsmith启动路径的版本提示，不是自动安装或Pi更新检查 |
| 项目命令 | Project commands | 下述3键 | 入口，不是开关；Enter打开，不伪装成可编辑值 |
| 模型记录 | Model records | 现有assignments/pm_launch | 入口，只按需读现有记录；不是运行状态列表 |

默认只用“模型”“自动检查”两个内容组，末尾直接列两个具名入口，不再加“其它”标题。只有选中操作需要的生效信息占一行；普通值行没有默认标记、徽章、配置注释或每行CLI提示。完整值在编辑器/选中信息中可查看；长值沿既有窗口操作访问，不用删值或硬限制类别数制造短页面。

### 2. 逐一论证入口，否决第三个“资源下限”页

| P469候选 | 本提案决定 | 用户用途 / 现有入口能否代替 / 代价 |
|---|---|---|
| 资源下限（4项） | 不建立，4键退出UI | 属于机器容量调优；原容量显示、`team ps`及拒绝原因已经告诉用户为什么不能启动，完整CLI仍可调整。没有探索证据证明普通用户需要日常编辑四条互有联系的阈值，单独加页只把内部参数换个位置。不是改名为“运行条件”后再保留 |
| 项目命令（3项） | 保留一个返回式视图 | 项目接入时用户确需设置安装/验收命令，并可按项目规模调整验收最长时间；偏好菜单无这三项，CLI虽然能改但不能替代本页已有的编辑能力。合成一个项目目的，3项都沿原自由输入/选择保存，不增加“运行”按钮 |
| 已派任务模型及PM记录 | 保留为“模型记录”返回式视图 | 用来回答“我已经改了任务模型，为什么这次任务仍是原模型”；成员表没有完整模型/SID/来源，现有CLI能读但没有相等的界面入口。保留源已有事实，不新建历史库；A+L行从默认页移出，返回成本一次Esc |

记录视图保持在设置里是为了紧邻“未来任务用什么模型”的疑问，不为只读内容另建顶层页，也不扩大到所有任务历史。PM行叫“PM上次启动”，派单行叫“成员 / 任务 / 模型”，选中后给类别、完整模型、会话编号、模型选择来源、本次启动方式及源实际携带的时间；没有时间不编造。记录可来自已结束任务，绝不写“正在使用/当前进程”。

### 3. 全表删、合、移的数量

以下全部是页面去向，不删除配置/值/命令。未选中的apply/restart键仍走原`team config set`，refuse键仍按原命令/文件路线维护；没有把整表转移到“高级”。

| 原域 / 默认可见键 | 本提案保留键 | 退出键行 | 去向 |
|---|---|---:|---|
| identity / 13 | 无 | 13 | 身份/路径/名册通过原接入、成员命令或文件维护；不是普通偏好 |
| branch / 11 | 无 | 11 | 仓库/分支/凭据路径/合并策略保留CLI/文件入口 |
| policy / 16 | 无 | 16 | 权限/依赖/信号等运行约定；退役参数也不再占设置行 |
| roster / 11 | `TEAM_MODEL_LIMITS` | 10 | 其余模型窗口/程序参数/适配器等留原CLI/文件 |
| task-model / 3 | `TEAM_PM_MODEL` | 2 | `TEAM_TASK_MODELS`重复整表行合并为C条类别操作；配置版本号退出 |
| workflow / 15 | update-check、install、gates、review-timeout | 11 | 其余等待/验证放行等低层策略留CLI；没有“一键放行” |
| delivery / 18 | 无 | 18 | 包括P469候选4阈值在内全部退出UI；容量告警/错误显示与实际检查保留 |
| panel / 7 | `TEAM_PULSE_INTERVAL` | 6 | 原五项面板偏好仍在偏好菜单；其余运行键留CLI，不偷偷变成偏好 |
| patrol / 4 | `TEAM_PULSE_MAX_RESTARTS` | 3 | 提醒间隔/todo-wip/恢复tmux策略留CLI |
| pm-lifecycle / 6 | 无 | 6 | 会话/启动模板/等待参数留CLI，不增PM第二套模型入口 |
| session / 10 | 无 | 10 | 轮询/心跳/重放/去重等运行参数留CLI |
| meeting / 4 | 无 | 4 | 协作策略留CLI，不新增会议设置 |
| **118** | **8键，另有C类别** | **110** | **1重复整表行合并，109个其它键退出UI** |

五个fixture-only键从前就不显示，不计入110。未知键U不再自动显示，但CLI仍逐条报告；未知键warning、迁移诊断及读失败是错误信息，不是可删的配置行。

| 同输入计数 | 旧页（P469已观察） | 候选（设计计数，未运行） |
|---|---:|---:|
| 默认可选行 | `118+C+A+L+U` = 127 | `C+7` = 10，含C+5编辑和2入口 |
| 默认内容标题段 | 15 | 2，不给两个末尾入口另造标题 |
| 默认不可编辑值行 | `40+A+L` = 46 | 0；另有2条导航，不冒充设置值 |
| 整个设置的配置编辑入口 | `77+C` = 80 | `C+8` = 11 |
| 按需记录 | `A+L` = 6，原埋在全表末尾 | 6，在模型记录；不是额外复制 |
| 跨三个列表的配置编辑/记录/导航行合计 | 127 | `C+10+A+L` = 19（11编辑+6记录+2导航） |
| 完整CLI schema | 123，另有未知键 | 不变 |

“编辑入口”不是编辑器内所有字段/按钮数量。并发规则表单随现有规则数R显示模型和数量字段及增删/保存控件，模型picker随项目词汇滚动；不把这些藏在11这个数里，也不把R或C限制成样例值。

### 4. 模型同时运行任务数：最小表单，不建立新规则系统

普通路径：Enter打开当前`TEAM_MODEL_LIMITS`草稿→选择一条规则→两个字段“适用模型 / 同时运行数量”→修改→校验/确认→一次完整键写入。适用模型提供读侧已知模型列表及“其它适用模型”，后者可保留原有`example/*`等表达式；不加“精确/通配/组”的新类型，也不展开成每个模型一条存储。0的字段显示“此项不限制”，保存仍是0。

增删只修改内存草稿。保留每个未修改token的内容、先后与重复，不排序、去重或展开；用户实际修改并保存时，将完整token列表用空格连接交原writer，不承诺保留token之间原有空格/制表符字节，也不建立无损解析器。取消、非法值或指纹冲突仍不改原配置任何字节，其它键/注释及writer不变。源为空时显示“未填写”，可添加限制；**清空值不是删键，也不宣称关闭所有默认限制**。`common.sh:1062`的空值启动默认处理不在本轮改动内。

匹配算法仍由`team_model_limit`/`team_model_limit_pattern_for`负责：既有精确匹配优先、通配取最小正上限、重复和顺序意义均不由UI重算。给实现者的范围事实是：被选中表达式覆盖的worker合计占用数量，PM及被替换worker不计入；某项为0仅表示此项不施加限制，其它精确/通配项仍可能限制该模型，不是全项目或所有进程的总量。UI不计算或预览最终有效上限，不增加匹配表，也不在默认页追加说明。已有warning或坏原值保持可见并交既有整值输入修正，不丢坏token或部分保存，不新造错误分类或无损解析系统。

规则表单复用自由输入的校验→确认→保存时序和打开时的fingerprint。字段Enter完成草稿字段，只有“保存”进入整值dry-run；确认显示按规则分行的旧/新完整值（适用模型、数量），不是原始key作标题。Esc从字段回草稿，从草稿取消整次编辑；选择适用模型是草稿选择，不误当成一次独立配置写入。普通bool/model/seconds选择器保留“一次接受即dry-run并保存”；不为统一外观把所有设置改成多次确认。

### 5. 同输入旧页与候选草图

以下候选全部**未实现**，使用P469相同C3/A5/L1/U0与虚构`example/model`。旧页是已接受原帧的节录，不是本轮重跑；斜线是节录合写，不代表原页有合并控件。数值是公开schema示例，不是本项目实际配置。

#### 旧页：120×30首帧

```text
项目设置
── 身份与账本布局 ──
› 项目名                 未设 · 默认 — · 不可改
  会话名                 未设 · 默认 — · 不可改
  PM窗口                 未设 · 默认 pm · 不可改
  名册                   未设 · 默认 — · 不可改
  账本目录 / 工作树目录 / 状态目录 / 会议目录 / 规格目录
  项目根 / 主检出根 / 临时根目录 / 契约文件
── 分支与 forge ──
  分支模式 / 分支前缀 / 保护分支 / 远端 / 托管平台 / 凭据位置
  ↓104
```

原首帧逐行显示23键、均不可编辑，模型行在全表之后。

#### 候选默认及选中

```text
项目设置
── 模型 ────────────────────────────────────
› routine                    example/model
  analysis                   example/model
  verify                     example/model
  PM模型                     example/model
  模型同时运行任务数         2项
── 自动检查 ────────────────────────────────
  检查间隔                   900秒
  PM每小时自动恢复次数       5
  启动时检查新版本           开
  项目命令                   ›
  模型记录                   ›

新任务生效
↑/↓ 选择 · Enter 编辑 · / 搜索 · Esc 返回
```

选中入口时footer的“Enter编辑”改“Enter打开”，不再加解释句；没必要的选中说明不占行。选中PM才显示重新启动条件/命令；选中检查间隔才显示Pulse重新启动条件/命令。新类别全部沿源显示并滚动，不硬编码前三行。

#### 项目命令/返回及自由输入

```text
项目命令
› 安装命令                 <原值>
  验收命令                 <原值>
  验收最长时间             1800秒
↑/↓ 选择 · Enter 编辑 · Esc 返回

验收命令
> <可编辑的原值及插入点>
Enter 继续 · Esc 取消

验收命令
原值  <完整原值>
新值  <完整新值>
Enter 保存 · Esc 取消
```

这里只编辑，既不运行命令，也无“测试命令”按钮。取消不写配置/审计、不创建文件；保存结果“已保存验收命令”，返回原行。验收最长时间仍用schema建议值和自由输入；小于60秒的危险值沿`TEAM_REVIEW_TIMEOUT`原规则额外确认，不新增阈值。

#### 模型选择/默认/取消

```text
routine
› example/model             当前
  example/other
  输入其它模型
↑/↓ 选择 · Enter 保存 · Esc 取消
```

接受普通选项：dry-run→CAS写入→“已保存routine模型 · 新任务生效”。“输入其它模型”才进自由输入并额外确认。未设置的数值行直接显示read.default；其编辑器可有“保持默认值”（默认空则“保持未设置”），选择它只是取消且不写入。已有显式值时没有“恢复默认”按钮；writer没有删键操作。可清空的原控件仍仅依choices.empty显示“清空”，不伪装成恢复默认。

#### 模型同时运行任务数/字段选择/保存

```text
模型同时运行任务数
  适用模型                   同时运行数量
› example/model              2
  example/*                  1
  添加限制
  保存
↑/↓ 选择 · Enter 编辑 · Esc 取消

编辑限制
› 适用模型                   example/model
  同时运行数量                 2
  删除限制
Enter 编辑 · Esc 返回
```

适用模型进入项目模型选择器或其它适用模型输入；数量进入整数输入并允许0。所有字段/增删/保存都是同一未提交草稿，不产生单行配置文件；删除最后一条仍是现有空值，不暗示取消启动默认值。确认按适用模型/数量显示整组旧/新规则；取消整组返回原设置焦点。

#### 只读记录/选中/返回

```text
模型记录
› dev       P-example       example/old-model
  verify    尚无派单记录
  dev2      P-example2      example/model
  dev3      P-example3      example/model
  dev-bob   记录读取失败
  PM上次启动                example/model

任务             P-example
类别             routine
模型             example/old-model
会话编号         example-session
模型选择来源     指定模型
本次启动方式     延续原任务
↑/↓ 选择 · / 搜索 · Esc 返回
```

此例仅说明字段布局和记录差异，错误行不编造model。PM选中时仅显示源已有的启动时间/模式等；派单源没有时间就不画。记录页不显示编辑/换模/续跑/重启按钮；Esc回“模型记录”入口。完整值/字段以原有可滚动区域到达，窄屏竖排，不用“当前运行”的错误标题。

#### 失败、迁移及生效提示

```text
检查间隔
> 30
数值无效：<原命令的范围错误>
Enter 继续 · Esc 取消

设置已被修改，未保存
<读回后的另一写入者值>

保存失败：<原错误>
<保留原草稿>

配置需要更新
<原命令的完整迁移诊断及可执行修复命令>
```

失败不改成“完成”；校验失败留草稿，冲突保持别人的字节并读回，写失败显示真实原因。移除键行不移除读侧warning；多条错误沿现有区域窗口访问，不因为只有10行设置就只留一个错误。记录的“尚无派单记录”和“记录读取失败”依据record_present/assigned事实，不能从错误字符串猜。

类别保存只说明新任务；PM保存“已保存PM模型 · 重新启动PM后生效”，选中/收据提供`team up --fresh-pm`；间隔保存“已保存检查间隔 · 重新启动Pulse后生效”，提供`team pulse restart`。不自动发命令、不把保存称作已经切换或重启。英文对应“Saved PM model · After PM restart”“Saved check interval · After Pulse restart”。

英文主标签为Models / Automatic checks / Concurrent tasks by model / PM recoveries per hour / Project commands / Model records；记录为Dispatch record / Last PM startup / Session ID / Model selection / Launch method。保存为Saved，冲突为Settings changed; not saved，取消为Cancel。说明只在动作所需处出现，不给内部词增加括注或长教学。

### 6. 最小实现面与既有规格冲突

`layout.ts`只增加展示引用、用途顺序和对应列表，不复制默认/choices/class；`App.tsx`复用settings打开/返回、editor、CAS、actor及后台重读，增加两个局部导航状态和一个完整键的规则草稿；`types.ts`及两语表表达这些UI动作。导航不落新的state文件；既有settings数据块仍是唯一数据源，已有只读记录按需展示不是新增命令读路。`panel.js`按既有钉住工具链更新，相关README/config/skill的“全表”说明一并缩窄，CLI教学文档保持完整。

下表是对delta的定位，不再另立要求。原生OpenSpec1.16的首次validate实际拒绝MODIFIED丢弃或改名旧场景，因此不把已退休的全表场景混入新规则：4个展示块显式REMOVED并给出Reason/Migration，3个新的精选展示块承接必要行为；写入/窗口/模型3块保留完整场景身份作MODIFIED，memory-and-deps仍为1块最小MODIFIED；按V175的C1定点授权，另给verification的既有覆盖保留块及两处对应覆盖场景补窄例外，完整保留原23场景身份与此前例外。panel要求总数净减1，没有绕开检查器或修改正式spec。

| panel原块（以标题识别） | 本delta处理 |
|---|---|
| The console shows the project contract… | REMOVED；由Project settings expose selected user operations…承接精选操作/两入口/错误/导航/机器出口；全键自动显示等场景显式退休 |
| The console writes a project setting only through… | 保留完整写入流程，确认以标签作主语；替换被移走的用例键和重复CLI尾行，明确PM/Pulse时间；审计仍不在UI读取 |
| The console offers the schema's choice set… | REMOVED；由Selected settings editors preserve owning-command choices and writes承接choices/直接选择/自由输入/危险确认/无同步重读及字段表单；隐藏enum/path/整表跳转场景显式退休 |
| The settings view groups the contract… | REMOVED；由Settings groups follow user purposes and keep visible action state承接用途分组/分隔线/不可聚焦/双语及必要状态；schema绑定/逐行徽章退休 |
| The settings view fills the pane… | 仅改计数行集和见证输入，填高/窗口/短列表规则保留 |
| The disk floor's keys… | REMOVED；selected-operations的磁盘场景保留全部schema/CLI事实及容量错误；空间/inode键和fixture键标签退出UI，不增另一条重复要求 |
| Settings edit task categories… | 退休重复whole-map跳转；记录移到返回式视图、标题不再声称运行；逐类别/PM写入、身份/缺失区分/不中断进程保留 |
| memory-and-deps: The machine read reports each key's functional group… | 只把新增键自动进UI改为完整CLI报告；第十列来源、元数据/顺序/全量group校验和原3场景不变 |
| verification: A gate that cannot judge says so | 仅将本次panel点名退休的旧展示断言从旧计数比较中移出，映射到精选UI/编辑/记录检查；完整CLI、writer/CAS/身份/错误及其它覆盖不变，不新跑FAST/全量或补旧通过数 |

P469说“8个panel块”，其§5.2表实际列出7个不同panel标题，另1个memory-and-deps标题；初稿按这8个精确原对象修改或显式退休，并以3个展示替代块承接必要行为；本轮只按C1再修改1个verification覆盖保留对象，合计9个原对象，不扩至其它覆盖规则。全局双语同键集、鼠标、容量显示、模型语义、错误读侧和设置pty前提等未受本展示冲突影响的要求不重写。

### 7. 验收减重复与职责

规划作者本轮只运行brief列的结构/引用/账本/diff短检查。未来Apply由另一人实施并仅跑静态（类型、字符串及钉住bundle一致性），不自行跑pty或套件；非作者在PM独立固定检出一次完成受影响UI行为。不是拿静态通过冒充交互已验。

| 现有场景 / 文件 | 替换或沿用，不叠加 |
|---|---|
| `panel-p21.sh settings/groups/wheel` | 在原场景内替换全表开头、新键自动出现/unknown回退/schema组随动/三类徽章/全表数量；同一次非作者运行中用settings已有filter-fill、高度45/33/30/25的计数/填高及wheel断言观察短/长当前列表，类别/记录作长输入；退休重复whole-map导航 |
| `choices/choices-schema` | 把不再保留的bool见证换update-check；数值/默认/危险值用interval与review-timeout；移除隐藏enum/path专用UI场景，新增规则字段动作放原choices而非新脚本；后台CLI完整choices证据不重跑 |
| `write/conflict` | 留dry-run/确认/actor/指纹/取消/非法/失败/并发字节对照；用保留键，命令记录证明未增加执行/重启。原危险两路径合用review-timeout=30，不再测已退出的swap阈值UI |
| `categories/policy/readonly`及原`scn_flip` | 原不同策略与记录模型样例改从模型记录入口查看；留missing/unreadable、SID/来源及同任务预览；原flip两处产品破坏仍是类别写路由、策略模型冒充记录模型，仅调整新显示所需触点，复用其正常policy收尾，不单独再跑policy；删除“refuse键必须在列表”前提 |
| `panel-strings.mjs` | 保留双语字段一致/引用完整性，将全schema/全group双向相等缩为实际展示引用；删除无用标签/说明。无文案词表、无新保护规则 |
| `panel-snapshots.sh` | 不纳入本批执行：现有样例是偏好菜单及其它页面，不含项目设置短/长列表；不新增snapshot入口或矩阵，布局行为由同次p21 settings/wheel承担 |
| `config-cli.sh` / `panel-choices.sh` | 产品未改，不重新运行；保留既有完整CLI/校验/choices证据的原SHA及范围，不声称在新tip重新通过 |

非作者的唯一受影响pty批次使用已有选择形式：`bash skills/teamsmith/tests/panel-p21.sh settings groups wheel choices choices-schema write conflict categories readonly flip`（在既有隔离gate环境，非本轮执行）。中文主路径同时走键盘、单击/二击及滚轮；同一批中的英文/窄屏片段覆盖两个入口/返回、长类别与记录、规则字段/保存/取消及真实错误，不把全套每种语言和尺寸重复一遍。一次批次中保存完整config前后字节、argv、实际画面和必要红侧；红侧明确由原`scn_flip`执行类别写路由和策略冒充记录两处产品破坏，保留对应失败名/rc及未破坏bundle的正常policy收尾，不另跑正常policy；settings/choices-schema里的schema改动只是输入见证，不能当作产品变异。绝不为文案做长变异矩阵、增加脚本或等待预算。

同一verifier合并后确认产品/测试及已验工件与冻结候选同一性；若相同，引用那一批完整UI证据，只做必要的短接入（设置能打开、一个入口返回、结构引用检查），不重跑整批。若不是同一性，明确指出差异影响后由PM重派所需范围，不把旧证据称作新行为通过。非实现者收到确认与已接受证据后才归档。此表是后续任务安排，不是当前运行回执。

## Risks / Trade-offs

- [移出110键后，用户不能再从UI编辑其中原本可写的参数] → CLI和配置文件路线保留；这是明确接受的界面范围收窄，不把全表改名“高级”掩盖它。
- [资源阈值退出会让排障用户多走CLI] → 原容量显示/错误仍在，没有普通操作需要阈值页的证据；不把减少日常噪音变成隐藏真实故障。
- [新规则表单误改重叠/重复含义] → 只做token字段编辑，保留token内容/顺序/重复，实际修改保存后空格连接完整值交原writer；坏值保留并交既有整值输入，不推断有效上限。
- [记录被当成活进程] → 只叫记录/上次启动，不新增“正在使用”标题或生命周期按钮；数据仍来自原source，不用策略补全missing。
- [旧检查仍强制全表或重复跑大量CLI] → 原场景就地替换，明确退休清单，作者静态/非作者一次UI证据，合并后同一性复用。

## Migration Plan

无数据迁移、默认值变化或真实配置写入；既有用户直接看到精选列表，项目命令及记录在具名入口。先由非作者审本提案，再由独立实施者完成一个Apply批次；产品、bundle、文档及现有断言同时提交。冻结后按上节一次UI验收，PM接受、获授权合并后由同一verifier核同一性及短接入。

若原CLI值/匹配或写入字节变化、任一必要错误消失、记录误称运行、键鼠不能保存/取消/返回，则不接收候选；返修限定具体差异，不发布试错。撤销这次展示提交即可恢复旧UI，用户配置不需要回滚；不把回滚画成产品按钮。
