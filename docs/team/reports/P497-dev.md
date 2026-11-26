# P497 · 任务标签、看板筛选与优先级

agent: dev   status: INTEGRATED — STATIC PASS, AWAITING INDEPENDENT RETEST   time: 2026-11-26
branch: `task/P497-task-labels-apply`   PR/MR: -

标签接入 `d8968556` 的现行看板，实施候选 `2494ac7b` 的语法、类型、词条、构建及差异检查通过；未运行接入后的行为验收。默认保持最近更新，显式优先级按同栏权重和排序，两种顺序都可筛选。两轮 V196 原结果保留；OpenSpec 实现项 5/5 已勾选，独立验收 3.1 未勾选。只在本地任务分支提交，未合并到主线或推送；没有修改真实团队的标签、配置、窗口或看板。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/task-labels.mjs`、`scripts/lib/{cmd-docs,common}.sh`、`scripts/strings/{commands,help.zh,help.en}.tsv` | `8cf3b1c5`、`f7b15af7`、`5d26558d`：标签目录和关联保存在解析出的看板同目录；名称逐字匹配，分数按去重后的整数权重求和。原 `board`、无参数 `board ls` 和原有状态修改不读取标签。|
| `skills/teamsmith/scripts/lib/cmd-watch.sh`、`scripts/panel/src/`、`scripts/panel/panel.js`、`scripts/panel/README.md` | `9f1611f9`：只有 Pulse 界面及其画面快照带 `--with-labels` 请求原看板块。六列、原始行顺序与卡片文字不变；标签筛选和排序共用同一组行给显示和操作，选择不写进偏好。两个页面的详情均保留原文件查找，同时按打开时的表内身份和刷新后的行身份显示标签。构建产物 `979784` 字节。|
| `skills/teamsmith/tests/{smoke.sh,panel-b3.sh,panel-b3-stub.sh}` | `038e4520`：替换 §6d 的旧子串断言和 §28-h 的裸标题断言；保留旧重复 ID、无标签历史与滚轮场景。标签刷新、详情和新排序使用 `server_up board` 的同一真实隔离项目；未增独立测试入口。|
| `openspec/changes/task-labels/tasks.md` | 仅改 1.1–2.2 的勾选；未改方案、规格正文以及 3.1。|

## OpenSpec assessment

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 实施 5/5；独立验收 0/1 | `openspec instructions apply --change task-labels --json` 报告 `total=6 complete=5 remaining=1`，未勾选 `3.1`。|
| Correctness | 静态通过；行为待验 | Bash、JavaScript、TypeScript、构建、双语词条和 Git 空白检查的实际结果见下。CLI 分数、键鼠、颜色变化和错误回退未实跑。|
| Coherence | 路径已落实；集成待验 | `scores()` 同时供 CLI 和 Pulse；任务表身份在产生行时判断，详情还记住打开时的来源身份。机械输出不请求可选标签；巡检、派单和设置没有新增标签读写路径。|

## CRITICAL

- 未发现阻止移交候选的静态错误。没有基于静态检查给出行为验收或发布结论。

## WARNING

- §6d 的兼容对照需要检出包含 `v0.4.8` tag；测试从该 tag 取出真 CLI，与候选读取同一块测试看板，分别比较 stdout、stderr 和退出值。独立检出需保留该 tag。

## SUGGESTION

- 运行已指定的两条行为命令前设 `TEAM_SMOKE_KEEP=1` 和 `TEAM_B3_KEEP=1` 保留本次临时根；验收无需重跑来收集原件。

## Final assessment

- Counts: CRITICAL 0 · WARNING 1 · SUGGESTION 1。
- Readiness: 可交非作者验收；未达到行为验收、合并、发布或归档条件。
- Unverified applicable checks: 未运行 smoke、PTY、快照套件、真实 Pulse 或模型；未运行算分反例，未重跑既有 OpenSpec validate。范围由实施任务书的“作者实际执行：只做静态检查”限定。

## Verification evidence

`P497-static-final` 后台作业实际退出 `0`；终端日志首轮由 `P497-static` 保留，修正后由 `P497-static-final` 保留。环境为 Bun `1.3.14`、Node `v24.22.1`。实际回执：

```text
$ bash -n skills/teamsmith/scripts/lib/common.sh
rc=0
$ bash -n skills/teamsmith/scripts/lib/cmd-docs.sh
rc=0
$ bash -n skills/teamsmith/scripts/lib/cmd-watch.sh
rc=0
$ bash -n skills/teamsmith/tests/smoke.sh
rc=0
$ bash -n skills/teamsmith/tests/panel-b3.sh
rc=0
$ bash -n skills/teamsmith/tests/panel-b3-stub.sh
rc=0
$ node --check skills/teamsmith/scripts/text-sanitize.mjs
rc=0
$ node --check skills/teamsmith/scripts/task-labels.mjs
rc=0
$ (cd skills/teamsmith/scripts/panel && bunx tsc --noEmit)
rc=0
$ bash skills/teamsmith/scripts/panel/build.sh
Bundled 563 modules in 40ms
panel.js written (979784 bytes, sha256 cae80ab589032b4cf44347d2963f143a62524a670391220a5eb17c6734d1aee1)
rc=0
$ node skills/teamsmith/tests/panel-strings.mjs
ok: values are non-empty strings with matching placeholders
ok: selected settings references — 8 key labels; 76 displayed references
panel-strings: ok
rc=0
$ git diff --check
rc=0
$ git diff --cached --check
rc=0
$ openspec instructions apply --change task-labels --json  # 提取进度字段
schema: spec-driven progress: {'total': 6, 'complete': 5, 'remaining': 1} unchecked: ['3.1']
```

- Verdict: 作者静态 PASS；行为未运行。首轮 `tsc` 报错来自新增标签联合类型的缩小，已修正；其后首轮静态作业中的 `node --check text-sanitize.mjs` 和构建因 `.mjs:10` 残留 `: string` 返回 1。`f7b15af7` 删除 JS 源的类型标注，精确类型仍在 `.d.mts`；终轮上述所有命令返回 0。
- Ledger ban: 未运行 `ledger-ban.sh`。任务书将作者执行限定为列明的静态命令；没有 `hits=` 或退出值可报告。

## Flip evidence

本单为功能实施，按 3.1 仍须做算分反例。§6d 将原六条真实任务的 `board-six.md`、`catalog-six.tsv` 及 `priority-original.tsv` 放在保留的临时根 `task-labels/`，位置在新增重复行和改权重之前。独立验收先保留真输出，再用这一对文件在自己的临时副本仅把 `scores()` 内的加法改为取最大值，运行一次同样的 `team board ls --sort priority`。要比的是 `T2` 的实际第三列 `8 → 5`，不是两个算法都相同的 ID 序列。没有执行反例或声称它已失败。

## Scenes for independent verification

- §6d：对照发布前版本同输入的普通 `ls/row`；七列含空 Issue、写状态和指派的字段对比；标签创建、原子写失败、并发、名称精确性和整批拒绝；保留向量原件与真实重复行/表外同 ID 的区别；缓存开关比较整块 JSON。
- §28-h：相同的 59 列画面有无标签的非空卡片行逐字对比，带标签画面验证两个点击目标；机器入口比较实际子命令参数和输出。
- `panel-b3.sh board`：`board/live-labels/` 保留真实看板与详情回执；`board/` 中保留焦点、款式前后、窄屏和中英文截图文本。表外详情刷新让同一个实际报告正文变化，以免旧画面通过“没有标签”检查；插入后的 `insert-board-reply.json` 另断言第三个 `M39` 已是表内的新任务。空文件详情使用独立保存的真实 `first-detail-reply.json`，不是固定详情样本。

## Decisions and deviations

- 无范围偏离。标签读取失败保留原看板，只有标签状态不可用；写入发布后如果目录同步失败，`publish()` 报非零、点出可能已更新的路径并要求先重读，不尝试回滚覆盖。不为此制造产品故障开关。

## Suggested next steps

- 从新候选补验下列三处，并执行首轮未启动的实时看板操作与一次算分反例。不重跑已过的项目。验收前不要启动或替换真实 Pulse，不要勾选 3.1。

## V196 首轮返修

首轮独立记录 `docs/team/reports/V196-verify.md`（`aadffdf2`）对 `6ce75ccf` 判定 FAIL：636 通过、3 失败、3 跳过。原记录和原始文件未修改，包括取不到行生成的空文件。该轮是首次行为证据；上文构建来自实施首轮，不是隔离重建通过的证据。

| V196 发现 | `f9ba8bbb` 的处理 |
|---|---|
| §6d：公开入口吃掉首个 `--`，`-Follow-up` 被当作选项 | `skills/teamsmith/scripts/team` 仅在已识别到 `board label` 时保留 `--`，随后停止扫描全局选项。原来的单个分隔符和 §6d 断言不变；其他命令仍走原路径。 |
| §28-h：两份原帧的 `V14` 后均有四个排版空格，旧取法找不到该行 | `skills/teamsmith/tests/smoke.sh` 接受 ID 后一个或多个空格，两帧各要求恰一行；只去 ANSI，保留所有空格和文字交给 `cmp`。未改画面和尺寸。 |
| §26-a：依赖实际装好了，构建没找到 `../../text-sanitize.mjs`，却报成安装失败 | 同一测试脚本把共享文件放到隔离副本的 `panel/` 同级，并删除复制来的旧产物。锁定依赖装不上时保留原条件跳过；安装后构建退出非零直接失败并附日志；构建成功仍对新文件逐字节比较。 |

本轮实际回执（未改 JavaScript、面板源或提交的构建产物）：

```text
bash -n skills/teamsmith/scripts/team: rc=0
bash -n skills/teamsmith/tests/smoke.sh: rc=0
git diff --check: rc=0
git diff --cached --check: rc=0
```

该次返修作者未执行 CLI 行为、取行测试、隔离重建、整组选段、实时界面、分数反例或 OpenSpec 结构复查。V196 首轮保存的原分数 `T2=8` 仍可复用；随后验证结果见下。

## 接入现行看板 · 2026-11-26

本地合并 `2494ac7ba0eee12f6fdb7ba287d8ed70053850b1` 的两个父提交分别是原候选 `4cbc5bc78eeeca78cef535c727dd22379d9360c0`、固定主线 `d8968556689623e90231896340543d6ef45aa888`。V205 `b2b2785a` 接受的是方案 `f36d1e51`，不是产品验收。原候选、V196 两轮 FAIL 和停做记录保留，这次未重跑。

| 合并冲突或接合点 | 最终处理 |
|---|---|
| `scripts/lib/cmd-watch.sh`、面板 `types.ts` | 保留现行时间的读取、合法性条件、行序和字段；只有请求标签时，原行带上任务表归属及标签数据。`common.sh` 对基准只增加原标签读写辅助函数，原看板写入规则与时间处理不改。 |
| `panel/src/layout.ts`、`App.tsx` | 同一组栏内行供渲染、方向键、点击和 Enter 使用；原始行身份在筛选前计算。保留 P509 的同步焦点更新、当帧点击行和窄屏跟随。默认按有效时间最近优先，保留无时间与历史栏规则；显式优先级同分用原表序。刷新先解析符合当前筛选的原行，再找同号匹配行，再从原栏或其他栏找符合筛选的任务；无匹配时 Enter 不打开详情。工作页、机器模式和原文件读取不变。 |
| `tests/panel-b3.sh`、自动合并的 `tests/smoke.sh` | 在现有 `server_up board` 中保留基准已有的时间、连续按键、窄窗、滚轮及工作页断言，去掉只适用于旧无时间版的重复断言；标签部分补同批 `Down Down Enter`、逆时间同分、筛选跨顺序与同号表外刷新。§6d 以固定 pre-label 源读同一份看板，精确对照七个业务字段与合法最右时间；旧标签向量不改。§28-h 的非空整行断言不变，控件文字与默认顺序一致。 |
| `panel/panel.js`、`panel/README.md` | 不手合产物；原 `build.sh` 生成 `981443` 字节，SHA-256 `0dbbc61704aa1f9c960c8c9fad00964cf4ca1c57ea13af307098b0412a09108e`。README 已同步。 |
| `openspec/changes/task-labels/tasks.md` | 保留现行受审正文，只保留 1.1–2.2 的原实施勾选。3.1 未勾选；未改正式规格、项目设置、巡检或待命路径。 |

**已有证据可用范围：** `git diff --exit-code 4cbc5bc7 --` 对 `scripts/{team,task-labels.mjs,lib/cmd-docs.sh}` 和 `tests/panel-b3-stub.sh` 为 0；V196 的公开分隔符字面名称、原 `T2=8` 与只改算分后的 `T2=5` 不需重做。首轮的七字段对照来自旧候选，不能证明本次含时间的对照；59 列旧原帧取行和旧产物隔离重建只证明当时的输入和产物，不替代新数据、新画面及新包检查。V196 已看见的空详情、同界面改色和三行身份可作为对照，不充作新界面结果；第二轮连键只移一步，后续操作未到达。P509 `c0d2cfd9` 的真实连键与 V202 结果仅证明原无标签看板；这次保留它的下一键读取新焦点做法，仍待对接合后有标签的路径补验。

**作者实跑：** 后台作业 `P497-recent-static` 退出 0。`bash -n` 对 `scripts/team`、`scripts/lib/{cmd-docs,cmd-watch,common}.sh`、`tests/{smoke,panel-b3,panel-b3-stub}.sh` 均为 0；`node --check` 对 `task-labels.mjs`、`text-sanitize.mjs` 和新产物均为 0。Bun `1.3.14`、Node `v24.22.1`，已有冻结依赖，未另装；`bunx --no-install tsc --noEmit` 退出 0；原 build 打包 563 modules 并给出上述哈希。`node skills/teamsmith/tests/panel-strings.mjs`回执 `panel-strings: ok`，8 个设置键和 76 个引用仍能识别。最终追加真实 board 回执断言后，`bash -n skills/teamsmith/tests/panel-b3.sh` 仍退出 0；对基准的工作区与暂存区 `git diff --check` 都为 0。

**该次作者未执行：** 新候选的 CLI 兼容与缓存对照、隔离重建、画面、实时键鼠和刷新均未实跑；没有重新执行已获得证据的分数反例、V196 两轮、P503/P509 行为批次、整套 smoke、OpenSpec 结构校验、模型或发布检查。随后独立验收见下。

## 第三轮后：只修同一个终端测试

V196 的第三轮（`d6079783`，候选 `4a8bf012`）正式 FAIL，74 秒；终端 26 通过、1 失败。原现场同时显示 `Board body M39 proof` 和标签，因此不是产品漏读文件。`live-labels/` 没有 `board.json` 或 `detail.json`：面板实际使用 `board-cli`，而保存逻辑原先在不接收这两类请求的 stub。第三轮原记录、文件和其他通过证据不变。

- `cc97da35`：标签段通过原私有根和账本校验后，只把本场景前段生成的 `tasks/M39-board.md` 移到 `live-labels/pre-label-M39-board.md`，不再放在项目资料目录。保留前段真实正文断言、后段无文件画面与原 JSON 断言。
- `cc97da35`：标签段继续使用同一个 `board-cli`，保留项目、账本及状态目录核对。每次 `board` 或 `detail` 请求只调用一次真实 CLI：原字节送给面板，同一输出先保存再重命名为现有的 `board.json`/`detail.json`；命令失败不发布新回执。删除 stub 里的第二份真实读取逻辑；其余固定块不变。现有等待、插入、损坏与恢复、末尾筛选刷新断言都未改。

作者仅执行两份测试 Bash 文件和其中 `board-cli` 脚本片段的 `bash -n`，均退出 0；暂存前后的 `git diff --check` 均退出 0。相对 `4a8bf012` 排除这两份测试后的 `git diff --exit-code` 退出 0（本段报告提交另计），产品源和 `panel.js` 未改。未运行终端测试、构建、选段、CLI、缓存、59 列或机器模式。§3.1 保持未勾，该次由 V196 只补真实看板路径。

## 第四轮后：只修英文 59 列的卡片匹配

V196 `4597518c` 对 `2309f8c5` 的正式结论仍是 FAIL（107 秒，终端 43 通过、1 失败）。该次关闭了前轮的空详情和回执问题，并实测连键、立即 Enter、改色及权重、两种排序、筛选、表外详情刷新、损坏恢复。`en-default.txt` 实际有 `   · M39    Outside`，失败来自测试用单个空格找这行，并非界面没画出来。原始画面和回执仍保留。

`4a0952a6` 只改 `skills/teamsmith/tests/panel-b3.sh`。英文窄屏沿用已有稳定帧读取，只给真实卡片行生成独立匹配文字：允许 ID 后的空格，同时精确比较完整标题；未把全屏或用于鼠标定位的画面改写。逐项核对从 `en-default` 到 `fallback-detail` 的显示、排除和焦点条件，后段仍要求唯一焦点、原 JSON 中保留的表外同号、Enter 打开 M48 真实正文。菜单、两个完整标签名、控件、鼠标坐标、等待时间和 JSON 断言不变。

从候选提取实际 `awk` 规则，只读第四轮原帧 `en-default.txt`。旧条件对 `M39 Outside`、`M48 Neighbor`、`M51 Other` 各 0 行，新规则各恰 1 行；`M39 First`、`Second`、`Inserted` 分别恰 1 行。错配 ID/标题、标题前缀和无卡片符号的文字均不匹配，原帧逐字保留，焦点只认 `M39 Inserted`，不认 `Outside`。`bash -n` 和暂存前后的 `git diff --check` 均退出 0；排除该测试与本报告后，对固定候选 `2309f8c5` 无差异。未重跑终端或其他行为；V196 只补英文鼠标、草稿编辑器、不写入浏览选择和隐藏同号后的实际刷新与打开，§3.1 仍未勾。
