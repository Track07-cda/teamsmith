# P471 · 精选项目设置实现交付

## 最新结论 · D261集中返修

**返修候选已冻结，静态交付满足D261的限定范围；完整typecheck仍FAIL/rc2。** C1/C2测试修订与W1/W2界面修订已分步提交，尚未补验；原生仅1.1–1.6完成，为6/9，2.1/2.2/3.1未勾。最新候选为 `391ef8ee53feeedf3b19de8731ce9d1a9466b9d6`（第8节仅改测试等待一行；产品仍为第7节冻结内容），本轮作者没有运行UI或任何业务检查；V177旧批次177/16及四份现场仍是失败原件，不改判通过。完整静态命令、原错误及本次变更见第7节。

## 初次交付结论 · 原文保留

**STATIC-PARTIAL。** 设置实现、现有场景替换、对应文档及生成 bundle 已提交；1.1–1.5 已勾，1.6 仍未满足全部判据。原生进度为 **5/9**，不是交互验收通过。类型检查 rc=2：候选与真实起点导出均有同样四个 `OutboxListBlock` 字段错误；其它本轮静态命令 rc=0。PM 的 main 提交 `90d1381c` 明确允许先冻结此候选并交非作者验收，不授权补 optional/as/ignore 或修改队列；该决定不把失败转成通过。

- change：`pulse-project-settings-simplify`；phase：`opsx-apply`；agent：dev。
- 分支：`task/P471-project-settings-simplify-apply`；起点：`66ab596d68d74166bb350c6eb62b8dd62bfc948c`。
- 冻结产品/测试候选：`081bcdd50a6961936f2493fc14261435ccb94254`。正文之后只有本报告与交付扫描记录；不修改产品/测试。
- 源实现：`ee8d9e91`；原场景/文案及精修：`af82d719`；生成 bundle/既有变异触点：`5763c397`；双语字段与实施进度：`081bcdd5`。提交均有 P471 与 `Agent: dev`。
- 本轮 **没有运行** pty、实际键鼠、保存/取消、snapshot、config-cli/panel-choices 全量、smoke/FAST/meta/61b、真实 Pi 或性能测量。未启动/重启真实 Pulse，未修改真实配置、提醒或待命状态，未 push/merge/tag/archive/npm。

原件根：`E=/var/tmp/P471-dev-static.FEHqfA`，保留到 PM 收存。`run-static.sh`、各命令 `.log/.rc`、`baseline/`、`baseline-panel-p21.sh`、`typecheck-comparison.json`、`frozen-scope.log` 和最新主任务书副本均在此根。没有清理任何他人的临时目录。

## 1. 实现与任务落点

| 项 | 文件与静态依据 | 尚需行为证据 |
|---|---|---|
| 1.1 | `src/project-settings.ts` 只引用 8 个既有键；`layout.ts/settingsViewRows` 按源遍历全部类别，默认模型/自动检查两组，两个具名入口。排除键不进入投影或搜索；源 warning/迁移诊断另列并可打开全文。README/config/SKILL 已同步 | 实际默认计数、入口/返回、隐藏键/错误、搜索与机器出口 |
| 1.2 | `App.tsx` 的规则草稿只编辑同一个 `TEAM_MODEL_LIMITS` 完整值；`limitsTokens/limitFields/withLimitsTokens/limitsValue` 保持未改 token、先后和重复，实际修改才以空格连接。两个字段、增删、0 标签、旧/新完整确认；坏原值交原整值编辑器 | 完整写回、取消/非法/冲突的字节、选项与字段交互 |
| 1.3 | 普通选择与自由输入继续走原 `api.setSetting/setCategoryModel`，dry-run、原 fingerprint、actor、危险允许及后台 settle；类别、PM、间隔分别给真实生效条件；未增加执行/重启动作 | 实际 argv、审计、一次/两次确认、危险值30、失败留草稿 |
| 1.4 | `settingsRecordDetails` 与 records 投影只取 assignments/pm_launch 原事实；missing/unreadable 分开；完整模型/任务/类别/SID/来源及源时间可打开滚动阅读，PM 只称上次启动。没有用未来策略补记录 | 不同策略/原记录模型、来源和 SID、缺失/损坏、只读返回；原 policy 两处破坏 |
| 1.5 | 焦点、窗口与行数均使用当前视图；局部返回保存焦点/过滤/offset，不落导航文件。原 settings/filter-fill、高度45/33/30/25、wheel 更新成实际类别长列表，英文窄屏片段在同批原场景内 | 填高、可见+隐藏计数、短/长、焦点、单/二击、滚轮不穿透及窄屏 |
| 1.6 | Bun 1.3.14 按原 build.sh 生成 bundle；字符串/结构/引用/语法/diff 通过。**类型检查非0，故未勾** | 非作者核原有类型错误归属后由 PM 裁定静态边界 |

上述计数是源码投影/设计公式，不是新界面已实测：无错误的默认操作数 `C+7`，所有配置编辑入口 `C+8`。C3 的10行和旧127行仍是已接受的代表输入比较；本轮没有实际画面，不报“实测127→10”。规则字段/按钮和记录行不混算成配置编辑入口。

两个导航入口、规则草稿和详情均为当前设置视图局部状态；没有增加 schema、匹配算法、配置存储、目录扫描或只读数据协议。8 个键的值/default/choices/class 仍来自同一 settings read，而不是第二张值表。`git diff 66ab596d HEAD -- cmd-config.sh common.sh config-cli.sh panel-choices.sh`（实际用完整路径）为空、rc=0，回执在 `frozen-scope.log`。

## 2. 退休展示断言与必要行为承接

以下为 `baseline-panel-p21.sh` 的源归属到当前场景的映射，**不是新旧执行计数，也没有给退休断言补通过数**。没有新增脚本、检查段、快照矩阵、文案黑名单或长变异矩阵。

| 原展示/原位置 | 本次处理与承接 |
|---|---|
| settings 全表开头、unknown 回退行、全schema行数、fixture 去标记恢复行、磁盘/资源阈值必显示 | 退休。原 settings 检查精选类别/两组/C3计数、两入口/原位置返回、标签/值/标识过滤、退出键无操作命中及真实未知键 warning；长类别承接原 filter-fill/四高度和实际当前行计数。原 groups 的 scratch 新键/取消 fixture 标记不再创造 UI 行 |
| groups 的schema token顺序/新group自动标题、逐行class/default、三类徽章与颜色定位 | 退休。原 groups 检查用途分节线、自定义类别原序、非交互标题、保留键权限/route；无空组不造标题；必要生效/错误用文字。旧 label=0/badge=0 的归因采用 PM/P472 已接受说明，不加颜色检查、不重跑旧失败 |
| choices/choices-schema 的隐藏enum/path编辑、原pattern拼串、整表jump、无choice教学和raw-key主导等待 | 退休。bool见证换 `TEAM_UPDATE_CHECK`；数值/建议/默认/非法保留 `TEAM_PULSE_INTERVAL`；命令原值输入 `TEAM_GATES`；危险两路径 `TEAM_REVIEW_TIMEOUT=30`；schema输入变更只证明保留键新增7200选项、不证明产品变异。规则字段/完整确认/重复顺序、增删取消、非法、CAS、坏原值整值修正放原 choices/choices-schema |
| write/conflict 的raw-key回执、隐藏危险值/启动参数见证、重复CLI教学 | 仅换用户标签及保留键。保留一行diff/注释、dry-run/yes actor+指纹、取消无临时文件/无审计、非法不写/保留草稿、危险额外确认、冲突保住对方字节/审计/读回及运行argv不变。write 增量观察真实文件写故障及草稿，不运行项目命令 |
| categories/policy 的全映射重复入口、记录在默认全表尾部及运行模型叫法 | 退休显示。原不同策略/已提交记录样例保留，改从 records 查看；原missing/unreadable及record_present实际读、SID、整类别删除后原记录保留、PM与类别CLI写入、无dispatch/resume/restart及窗口集合不变保留。PM记录仅展示原启动时间/模式，未伪装存活 |
| settings/wheel 的全表计数及旧标签针 | 换成当前类别/入口等真实行集；保留四高度/短过滤填高、焦点推窗、单/二击、上下隐藏计数、picker滚轮及底层页面位置不变。英文入口/返回与窄屏字段非法/取消在原 settings/choices，不重跑整批语言矩阵 |
| readonly/原 scn_flip | readonly 保留契约/审计/docs/outbox及未绑定键观察，增加两个入口只读返回。flip 原两处产品破坏仍是 `set-task-model`→退休席位写入、未来策略模型冒充记录模型；只更新生成bundle的精确显示触点。原两个失败名字/rc和正常policy收尾保留，不另跑policy。**本轮未执行这些破坏** |
| panel-strings 全schema/key与12group双向绑定、fixture标签必须齐全 | 退休。改查8个精选键及实际使用的74个设置/来源字段引用；两语言字段一致与placeholder/非空检查保留。完整CLI/schema/group/fixture事实留原CLI检查，不要求退出参数有UI标签 |

这些替换对应 panel 的3个 ADDED 块与4个 REMOVED 块、写入/填高/类别3个 MODIFIED 块，memory-and-deps 的group来源1个 MODIFIED，以及 verification 原覆盖保留块的本次窄例外。三份delta、正式spec、proposal/design没有改正文。其它页面/写入者/匹配及完整CLI测试未改。

### 未变 CLI 既有证据，非本轮重跑

- `docs/team/reports/P370-dev2.md` 原 `tests/config-cli.sh` **331/0**；正式接受记录 `docs/team/reviews/P370.md` 绑定原候选 **`b53c2d23`**。范围是原完整配置读/校验/写入等CLI夹具，不是本候选执行结果；本轮不抄整张CLI矩阵。
- `docs/team/reports/P367-dev3.md`、`docs/team/reviews/P367.md` 与 `docs/team/reviews/V97.md` 原候选 **`43cdbc96`**，panel-choices 直跑 **48/0**，含一致性与 F-A/F-D 原控制。范围是原choices/读侧与夹具派生行为，不是新设置的键鼠证据。
- 本任务起点到冻结候选的 `cmd-config.sh/common.sh/config-cli.sh/panel-choices.sh` 完全相同；这只证明 P471 未修改这些能力，不能把旧SHA的通过说成新tip全量通过。新设置行为的证据仍全部待2.1。

## 3. 本人实际静态命令和输出

运行环境：Bun **1.3.14**、Node **v24.22.1**、OpenSpec **1.16.0**；`PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0`。没有升级依赖/改锁。唯一后台静态批次 `P471-static`，12.6s、整体 **rc=1**，已收取；不报全绿。

| 命令 | 实际结果 | 原件 |
|---|---|---|
| `(cd skills/teamsmith/scripts/panel && bun install --frozen-lockfile)` | rc0；Checked 45 installs across 46 packages (no changes) | `deps.log/.rc` |
| `(cd skills/teamsmith/scripts/panel && bunx tsc --noEmit)` | **rc2，四条TS2339** | `typecheck.log/.rc` |
| `bash skills/teamsmith/scripts/panel/build.sh` | rc0；562 modules；972977 bytes | `build.log/.rc` |
| `node skills/teamsmith/tests/panel-strings.mjs` | rc0；8 key labels / 74 displayed references；panel-strings: ok | `strings.log/.rc`；最终双语字段恢复后的同命令为 `strings-final.log/.rc`，rc0 |
| `openspec validate pulse-project-settings-simplify --type change --strict --no-interactive` | rc0；Change is valid | `validate.log/.rc` |
| `bash skills/teamsmith/tests/spec-refs.sh` | rc0；122 reference(s), 49 distinct, 14237 effective lines；retired 0 / undeclared 0 | `refs.log/.rc` |
| `bash -n skills/teamsmith/tests/panel-p21.sh` | rc0；包括最后更新的原flip触点、旧trace保留和PM记录输入 | `shell-syntax.log/.rc`、`shell-final.log/.rc`；末次提交前实际再次语法检查rc0 |
| `node --check skills/teamsmith/tests/panel-strings.mjs` | rc0 | `string-syntax.log/.rc` |
| `git diff --check`、提交前 `git diff --cached --check` | rc0 | 静态批次 `diff.log/.rc` 及各实际提交前命令 |

静态批次受测源 **`af82d71985979a59ec726278e95c1892a302d203`**。它到冻结候选的 `panel/src/**` 差异为空、rc0；生成物和最终测试身份见下节。上述输出不是独立行为验收。

### 真实基线对照与未通过项

从起点 `66ab596d` 用 `git archive` 导出 panel 源、package.json、tsconfig.json 到 `E/baseline/`，只链接同一 node_modules，在那里实际执行 `bunx tsc --noEmit`。rc=2；**没有改基线，也没有抑制报错**。

```text
candidate:
src/layout.ts(2219,32): error TS2339: Property 'impediments' does not exist on type 'OutboxListBlock'.
src/layout.ts(2220,9): error TS2339: Property 'impeded' does not exist on type 'OutboxListBlock'.
src/layout.ts(2220,22): error TS2339: Property 'impeded' does not exist on type 'OutboxListBlock'.
src/layout.ts(2222,78): error TS2339: Property 'impeded' does not exist on type 'OutboxListBlock'.
baseline:
src/layout.ts(2388,32): error TS2339: Property 'impediments' does not exist on type 'OutboxListBlock'.
src/layout.ts(2389,9): error TS2339: Property 'impeded' does not exist on type 'OutboxListBlock'.
src/layout.ts(2389,22): error TS2339: Property 'impeded' does not exist on type 'OutboxListBlock'.
src/layout.ts(2391,78): error TS2339: Property 'impeded' does not exist on type 'OutboxListBlock'.
```

`baseline-typecheck.log/.rc` 是实际对照，`typecheck-comparison.json` 记录只忽略行列后的四条诊断相同。PM又逐字节核对了基线19份编译源码/配置与原SHA，并核出 `outbox_list` 生产者没有这两字段，因此明确不允许只补类型隐藏错误（main任务书末节、`90d1381c`）。**改变结论的是保留STATIC-PARTIAL/1.6未勾，不是修掉队列或宣布typecheck通过。**

## 4. bundle 与冻结身份

来源：原 `skills/teamsmith/scripts/panel/build.sh`，Bun 1.3.14，原 package.json/bun.lock；头部保留 ink7.1.1/react19.3.0 和构建命令。没有手改bundle；没有为了比较再做第二次构建。

```text
candidate 081bcdd50a6961936f2493fc14261435ccb94254
panel.js           c5473cd3978e85814d387634dcfbefa75f448110591b8e5430bb2efb7e2aed83
panel-p21.sh       6c2e694bab1a879538aa699a1061e71e5cef2b261969fdf49a6df5e7befed863
panel-strings.mjs  ac149d72539337ca490c97cd357a67b4afa29a11fc58d7015d50a770755519f9
```

原件 `frozen-scope.log` 绑定完整路径及SHA；该时 `git status --short` 为空。后续报告提交不变更这三份文件或产品源。最新brief副本只保存到 E，没有用主检出新账本覆盖自己分支，也不合并无关工作。

## 5. 交付检查与下一步

报告已暂存后实际执行：

```sh
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
git diff --cached --check
```

三项均 **rc=0**；名单扫描 `scope=published files=2856 hits=0 names=ok user=resolved`，原件 `E/ledger-ban.log/.rc`。后台作业 `P471-ledger` 已收取，16.3s、rc0。两种diff检查在报告暂存及最终提交前均已实际运行；没有重复已完成的构建/类型/业务检查。所有本会话后台作业均已收取。

按PM当前裁定交 **STATIC-PARTIAL** 冻结候选；1.6、2.1、2.2、3.1 均未勾。非作者可在独立固定检出按原命令一次执行：

```sh
bash skills/teamsmith/tests/panel-p21.sh settings groups wheel choices choices-schema write conflict categories readonly flip
```

本报告没有红绿行为证据：原flip两处控制只完成源码触点更新，不以schema输入变化/语法检查冒充检出。真实键鼠画面、完整config字节/argv、两入口返回、规则字段与只读记录、英文窄屏、危险/失败/冲突均待该批验证；同一验证者在PM合并后核同一性并只做必要短接入。类型错误静态边界由PM据非作者结论裁定；不增加新矩阵或为归档再跑UI/CLI。

## 6. V177 前置窄返修 · 2026-11-17

**最新候选为 `22f9ad47bd23b26dc75981299598812db6c9fbb1`，仍是 STATIC-PARTIAL。** 本节更新前文初次冻结的测试身份；产品源与bundle保持初次候选不变。原四条类型错误、1.6未完成和原生5/9均保留，不把本次参数修正写成UI通过。

依据：V177报告 `7f156d08`（`docs/team/reports/V177-dev3.md`）在前置检查发现，入口保存KEEP后清理全部TEAM变量，只重导出TEAM_TMP_KEEP，原flip的三次policy子运行因此收不到同一保留决定。V177尚未执行任何UI（外层0/10、子policy0/3）。PM已在主任务书新增末节窄授权，仅恢复原保留参数，不改产品或破坏。

本次只改 `skills/teamsmith/tests/panel-p21.sh:72` 一行：

```diff
-[ "$keep" = "1" ] && export TEAM_TMP_KEEP=1
+[ "$keep" = "1" ] && export TEAM_TMP_KEEP=1 TEAM_P21_KEEP=1
```

源码结果：显式keep=1同时向原三个子运行传递既有决定；默认keep=0的分支、身份清理、两个原破坏/失败名/rc与正常policy收尾均未修改。子运行是否实际保留现场仍待非作者运行，本次没有用源码推断计作行为实测。

实际只执行 `bash -n skills/teamsmith/tests/panel-p21.sh`、`git diff --check`、`git diff --cached --check`，均rc0；语法原件为 `E/keep-fix-syntax.log/.rc`。修改提交 `22f9ad47` 只有此一行；提交后工作树干净。没有重跑旧静态、名单扫描、UI/CLI/flip，没有重建bundle，也没有改任务勾选。后续V177只核此行并启动尚未运行的原定一批，不追加policy批次。

```text
latest candidate 22f9ad47bd23b26dc75981299598812db6c9fbb1
panel-p21.sh 88b3358e1e2d642db97a4ed29193380c24cc1c448d21a2634b9bbc8dc9cc5e2c
panel.js     c5473cd3978e85814d387634dcfbefa75f448110591b8e5430bb2efb7e2aed83
```

本次报告提交只追加此节；本地分支与模型/SID均保持，不push、不合并。原件根继续保留给PM收存。

## 7. D261集中返修 · 2026-11-17

依据：main任务书“集中返修（当前有效，D261）”、本人线程，以及V177最终报告 `16bc42e763d0cb9f54f56860fb6079b57c3b7d2f`。D261已明确替代此前“1.6待PM裁定”的安排：仅当新源没有新增类型错误、其余必要静态成功时接受这四个已由非作者确认的旧错误；**完整类型检查不是通过**。本轮满足该条件，故勾1.6为6/9；验证/merged三项未勾，不改任何规划、delta或正式spec。

### 修改与未闭合行为

| 原发现 | 本轮实际修改 | 证据边界/下一步 |
|---|---|---|
| C1八条空白填高误匹配 | 原三处循环/断言的操作行匹配要求存在非空格、非边框字符，不再把空白填高行当内容 | 不新建解析器/全键矩阵；非作者可复用原八份真帧判断，不以本次语法检查说匹配已实测 |
| C1类别picker未到达 | 原wheel片段先用已有filter_to routine让实际类别可见、再用原focus_row/Enter；退出前清除该过滤 | 保留原picker滚轮/页面不穿透观察，待补原未到达路径，不重复已绿布尔选择/滚轮 |
| C1异常规则样例未生效 | choices-schema定点替换唯一原TEAM_MODEL_LIMITS行，并核原CLI实际读值再打开；不追加第二个同名赋值 | 原整值异常修正/错误观察保留，待补该片段；不改配置读取器/正常规则保存/CAS |
| C1父页筛选/返回起始层错误 | 原reopen_view、categories和readonly在回主设置后清恢复的筛选；Escape前后用现有pty_key_when/pty_wait_frame确认当前主设置/浮层；未加sleep或等待预算 | 原类别保留/读失败/正常类别写入/路由破坏闭环均保留，仍待非作者真正到达操作；两原破坏、失败名/rc及正常policy收尾调用没有改变 |
| C1迁移诊断定位 | 聚焦实际upgrade-models行后打开；原退休键事实改在原legacy-key帧核对 | 不恢复旧长说明，不移除迁移可达性/退休writer检查；待对应原片段核对 |
| C2未定义assert_neq | 同一位置以既有ok/bad和原字符串比较执行“PM行确实变了” | 未删除比较或吞command-not-found，没有新增断言库/全局错误扫描；尚未实跑新比较 |
| W1无时间单位 | 仅TEAM_PULSE_INTERVAL/TEAM_REVIEW_TIMEOUT的行值、原picker数值选项/范围及输入提示加秒/s；原numeric默认值断言同步单位 | 原数据/范围/choice值与保存回调未改，待对应显示/原未到达交互补验，不扩到其它设置 |
| W2无效全局按键/窄屏返回 | 仅设置视图移除四个全局action标签及点击目标；返回改Esc且排首。设置/筛选输入器打开时不生成底层按键带/目标，沿用已有输入器Enter/Esc提示，避免展示不可用动作；其它页面保持原动作 | 源层命中目标已删；没有点击flush/发信/待命，也没有更改发送逻辑。真实宽窄工件和当前view操作仍待非作者核对 |

测试提交 `e9756f1a`；UI源提交 `34b57973`；原工具生成bundle及D261下1.6提交 `78fdb984`。未新增脚本/检查段/产品开关/框架/场景/第三种变异；未修改CLI/匹配/存储/身份/后台语义。没有运行UI、policy、flip、CLI业务、原十场景或另七组；未安装依赖/重复strict/spec-refs/旧静态矩阵。原177/16、路由未到达及正常policy失败不会被本次源码修订覆盖，后续补验命令由PM按新差异裁定。

### 唯一本轮静态回执

原件在 `E/repair-d261/`，其中 `E=/var/tmp/P471-dev-static.FEHqfA`。工具链沿用原Bun1.3.14、Node v24.22.1及未改package/lock；环境 `PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0`。

| 实际命令 | 原始结果 | 原件 |
|---|---|---|
| `(cd skills/teamsmith/scripts/panel && bunx tsc --noEmit)` | **rc2/FAIL；仍仅同一四条TS2339**，与首次候选诊断文件逐字节cmp为rc0，无新增错误 | `typecheck.log/.rc`、`typecheck-original-exact-cmp.rc` |
| `bash skills/teamsmith/scripts/panel/build.sh` | rc0；562 modules；973617 bytes；原build脚本生成，未手改bundle | `build.log/.rc` |
| `node skills/teamsmith/tests/panel-strings.mjs` | rc0；8 key labels / 76 displayed references；placeholder/双语字段检查成功 | `strings.log/.rc` |
| `bash -n skills/teamsmith/tests/panel-p21.sh` | rc0；本轮只一次 | `shell-syntax.log/.rc` |

后台作业 `P471-D261-static` 已收取，21.2s，整体原退出码 **2**。未过滤错误、改变退出码或补optional/as/ignore，未改队列页；不写全静态全绿。当前源与首次候选四条诊断完全相同：

```text
src/layout.ts(2219,32): error TS2339: Property 'impediments' does not exist on type 'OutboxListBlock'.
src/layout.ts(2220,9): error TS2339: Property 'impeded' does not exist on type 'OutboxListBlock'.
src/layout.ts(2220,22): error TS2339: Property 'impeded' does not exist on type 'OutboxListBlock'.
src/layout.ts(2222,78): error TS2339: Property 'impeded' does not exist on type 'OutboxListBlock'.
```

类型/构建/字符串实际受测源为 `34b57973482819b4f3bb1cf06cbb4c9e08ba44a5`；它到最新候选的 `panel/src/**` 差异为空。生成物来源与冻结身份见 `repair-d261/frozen-scope.log`；未为核hash重建第二次。原两处bundle精确变异触点仍各唯一，显示触点的上下文仍为原I参数；只读核字节，不执行变异。

```text
latest candidate   78fdb984c4a6860ae3ecf0d59168aca2f203b7ac
panel.js           220e896d0f326e3d22b8761cd75d400ba6f1ef1de8dbaa07f252fcb43667f76b
panel-p21.sh       191338a86ca0e5c37450b2b55899036a2c5023d29e567aaa8fab4f6933142f1e
```

本轮报告暂存后实际执行一次 `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"`，rc0，`scope=published files=2856 hits=0 names=ok user=resolved`；原件 `repair-d261/ledger-ban.log/.rc`。后台 `P471-D261-ledger` 已收取，17.7s、rc0。`git diff --check` 与 `git diff --cached --check` 在报告暂存及最终提交前均rc0；没有复跑其它检查，所有本会话作业均已收取。分支/model/SID保持，全部原件继续保留；不操作真实团队、0.4.7、配置/提醒/待命，不push/merge/archive/tag/npm。

## 8. 最后一行等待修订 · 2026-11-17

最新测试候选 **`391ef8ee53feeedf3b19de8731ce9d1a9466b9d6`**。依据主任务书“当前唯一返修：wheel等待只看实际首屏（V177 79f247c4）”及本人线程，仅把原wheel约1668行的 `pty_wait_frame` 第二个needle从屏外的“输入其它值”改为首屏“· 当前”。`╭─ routine`标题needle、超时/稳定确认和全部后续滚动/退出/不穿透断言不变；产品源、bundle、样例、1.6及其它任务勾选均未改，仍6/9，不由作者宣称验收通过。

本次实际只执行一次 `bash -n skills/teamsmith/tests/panel-p21.sh` 及 `git diff --check` / `git diff --cached --check`，均rc0；原件 `E/repair-d261/wheel-needle-syntax.log/.rc`。未运行UI/policy/flip/CLI业务，未重做编译/构建/strings/strict/ledger；按PM授权由原验证者用已保存的真实打开/关闭/其它picker帧核原matcher，不重启界面或重跑原case。V177第二轮55/2、正常policy29/0及路由目标红均属PM任务书所引独立证据，不是本人本次运行；正式FAIL不在本次改写。

当前 `panel-p21.sh` SHA-256为 `872d93c2525e2015c4a47d93d25571a5b0917cc57db34ce1d598e998046eb8f1`。原完整typecheck四错/rc2照留，D261静态限定范围不变；本报告之后只有追加记录，不改冻结代码。本地原分支/model/SID保持，原件继续保留，不push/merge/archive。
