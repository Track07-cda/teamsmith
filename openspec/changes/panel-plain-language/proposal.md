# panel-plain-language · 面板只说普通话：设置页去掉黑话与内部记录，关键回复页信任发布者标签

## Why

用户 2026-10-14 的要求（本变更的唯一需求来源，原话）：

> 这些都是什么语言？派单记录？为什么设置菜单里面要有记录？审计根本没有用，也看不懂，去掉！不要用你自己的一套简写的语言，什么「手改」
> 这里测试旋钮又是什么玩意儿？还有什么内部接缝？
> 不要在界面中包含任何黑话
> 自称去掉，默认信任

（两张截图是 Pulse 面板的设置页：一张逐席位显示「没有完整派单记录: legacy/unknown assignment_version」加一整块原始审计行；
另一张显示「依赖策略: 手改 .pi/team/config.sh」「测试旋钮: 磁盘读数夹具（TEAM_MEMINFO_FILE 同族）；只在夹具里用」。）

基线实测（2026-10-14，本 worktree 逐处读过，数字是度量）：

- **设置页每行的注释不是面板自己的字**：`scripts/panel/src/layout.ts` 的 `settingsKeyLine` 把
  `row.warning || row.route || row.comment` 画成行的注释，而 `route` 就是 `scripts/lib/cmd-config.sh` 里 schema 行的
  **第 8 列自由文本**。用户截图里的「依赖策略: 手改 …」「测试旋钮: …」正是这几列。逐行数一遍：schema 的 45 行里，
  **45 行**的注释载着这轮要清的说法（`身份`/`账本布局`/`环境定位`/`分支语义`/`凭据位置`/`权限守卫`/`依赖策略`/
  `机器路径`/`测试旋钮`/`内部接缝`/`P159…`）；其中 4 行是夹具开关（`TEAM_DISK_STATS_FILE`、`TEAM_SMOKE_FAST`、
  `TEAM_INBOX_WATCH_FORCE_FAIL`、`TEAM_IW_REQUIRE_WATCH`），4 行是 `内部接缝（frozen）` 的适配器键。
- **审计整块确实画在视图里**：`settingsBlock` 的尾巴固定画「审计（最近）」（`settingsAuditHeading`）+ 最近 3 行
  `state/config.log`（`SETTINGS_AUDIT_LINES = 3`）；写路径的「settle 之后重读列表**与审计尾**」写进了
  `panel#The console writes a project setting only through team config set…`。
- **席位「没有记录」把命令的诊断原文画上屏**：`settingsAssignmentNone: '没有完整派单记录：{diagnostic}'`，
  `{diagnostic}` 是 `common.sh` 的 `TEAM_ASSIGN_DIAGNOSTIC`（`missing assignment` / `legacy/unknown assignment_version` /
  `malformed line` / `incomplete model` …）——用户截图里那行就是它。
- **发布者标签到处带限定词**：面板两张表 `replyDeclared: '自称来自 {from} · {at}'`、`replyDeclaredShort: '自称来自 {from}'`、
  `replyBodyHint: '只读 · 发布者自称，未经核验'`；命令行 `scripts/replies.mjs` 的 `show` 头是
  `来自 X（自称）· 时间 · 字节 · sha256 …`，`scripts/lib/cmd-reply.sh` 的用法头写「`--from` 是自称的平坦标识符…不是身份认证」。
- **这些字被夹具钉住了**（改文案必须同时改夹具，这是本变更夹具面真实存在的原因）：
  `tests/panel-p21.sh` 12 处（refuse 路线 6 处含 wheel/scratch 场景、`实际派单记录（只读）`、`没有完整派单记录`、
  `磁盘读数夹具` 行、行数公式 `rows + ↑ + ↓ = 命令报的键+类别+派单记录`）；`tests/key-replies-pty.sh` 5 处
  （`自称发布者`、`只读 · 发布者自称，未经核验`、`只读 · 发布者自称`、`自称来自 dev2`）；`tests/key-replies-ui.sh` 的
  快照组；`tests/panel-strings.mjs`（键集/占位符/表外无 CJK/契约键标签双向相等）。
- **规格里被钉住的字**：`memory-and-deps` 2 处 —— 身份键的 route 必须写「hand-editing `.pi/team/config.sh`」
  （`The project contract has exactly one writer…`）、适配器键的 route 必须写「`内部接缝（frozen）`」且「console shows it
  under the row」（`The worker-launch keys are an internal frozen seam…`）；`panel` 6 条要求（设置视图的行集与 route 行、
  审计尾的重读与场景、分组标题、高度场景里的 audit footer、磁盘缝「是视图里的 refuse 行」、类别与席位块的文案）；
  `key-replies` 1 条（`Publisher labels SHALL be displayed as declared, not verified` + 场景里 `visibly self-declared`）。
- **用户裁定 D170（门禁只管逻辑）**：措辞、术语、排版不进永久门禁，由设计与评审把关；本变更的红侧因此**只留渲染行为**
  （界面里有没有那块东西、标签按哪个字渲染、安全消毒照旧），不写「出现某个词就红」的断言。

## What Changes

### 一、设置页（`panel` 的 MODIFIED，6 条）

1. **审计整块从界面移除**。`state/config.log` 与 `team config log` 一字不动，只是视图不再画「审计（最近）」与那 3 行尾巴；
   design 写明理由：它是排障材料，不是设置，设置页的读者改不了它也不需要它。视图尾部因此只剩聚焦行的命令行，行窗口相应变宽。
2. **只供测试的开关在界面上完全不出现**。机制是**数据**而不是名单：那四个键的 schema 注释以声明标记 `fixture-only: ` 开头
   （`memory-and-deps` 拥有标记），视图**不渲染**带标记的行（也不为它们开分组标题、`/` 也不命中）。
   读取与命令行行为一字不变：`team config list --json` 照旧报告、`team config list` 照旧列出、`team config set` 照旧 exit 5。
   夹具的红侧是**数据驱动**的证明：把标记去掉 → 那一行回到界面（红），把标记加回 → 消失（绿）。
3. **界面可见文字里不许出现内部词汇**：清掉清单里的说法（手改、只读键、派单记录、测试旋钮、内部接缝、旋钮、接缝、依赖策略、
   机器路径；英文 hand-edit、knob、seam、assignment record、policy；`M<数字>` 编号）。做法是**同一条文案只住一个地方**：
   设置页那行注释的正文住在 schema 的注释列，所以在**源处**改写成普通话（`memory-and-deps` 的 MODIFIED），面板照旧原样渲染；
   面板自己的字（分组标题、徽章、提示、回执）在同一批里改写；`TEAM_*` 与命令行只留在与命令行对齐的地方——编辑器标题、
   确认行、聚焦行的命令行、以及命令自己打印的迁移诊断（那是用户要照着跑的命令行）。
4. **保留「策略与实际」这层区分，但改成普通话**。两个块的标题分别说「**下一次派任务会用的模型**」与
   「**正在运行的任务实际使用的模型**」，并加一句说明它们为什么会不同（任务派出去之后就固定用当时的模型）。
   席位没有记录时写普通话原因，且**不把命令的 diagnostic 原文画上屏**；两种原因由读侧的**事实**分开：
   没有记录文件 → 「这个席位还没有派过任务」；有记录但读不出来 → 明说读不出来（面板不编造模型、也不假称这个席位没用过）。
   为了让这个事实可查，读侧补一个布尔 `record_present`（`memory-and-deps`，用现成的 `team_assignment_record_present`）。
5. **只能改配置文件的值**：聚焦行的提示写成「这个值要改项目配置文件 `.pi/team/config.sh`，界面不能改」（路径是事实，保留），
   不再出现「手改」「只读键」；roster 这类由命令写回的值，提示给命令自己的路线（`team add-agent` / `team teardown`）。

### 二、关键回复页（`key-replies` 的 MODIFIED，1 条）

6. **发布者标签默认信任**：面板与命令行的**人面**都只显示标签本身（例如「来自 pm · 时间」「来自 dev2」），
   不再出现「自称」「未经核验」「declared」「not verified」。机器出口（`--json` 的 `from`、`--raw`、槽位记录）一字不变。
7. **安全一条不减**：存储路径与记录名仍按不可信数据处理（拒绝软链、非普通文件、路径穿越、外来根）、读取接口不接受任意路径、
   正文里的 Markdown 链接与图片、嵌入命令、终端控制序列仍然是惰性文本、显示前仍然消毒 —— delta 里这些句子**逐字保留**。
8. **数据层不变**：存储里记录的仍是发布者写下的标签原文；design 写清「显示信任」与「记录原样」两层的关系与不矛盾之处
   （标签是谁写的这个事实没有被抹掉，只是脏话式的限定词不再贴在每一次显示上），并在 Non-Goals 里留一句如实说明
   （标签是调用方自己声明的，工具不认证）。

## Capabilities

### Modified Capabilities

- **`panel`（6 条 MODIFIED，均改在要求自己的家里，不新造平行陈述）**：
  - `The console shows the project contract with its effect class, and refuses what it must not change` —— 行集（fixture 标记的行不渲染）、
    可见文字规则、refuse 行的路线提示（普通话句子 / 命令路线）、raw key 出现的三个对齐位置；
  - `The console writes a project setting only through team config set, after validation and a confirmation` —— settle 后只重读列表
    （审计尾不再重读、不再渲染），审计场景改成「审计留在文件与命令行里」的**存在性**断言；
  - `The settings view groups the contract by the functional group the command reports…` —— 组标题的措辞规则 + 「全部行都被标记隐藏的 token 不开标题」；
  - `The settings view fills the pane it is given and its row window grows with it` —— 行数公式把隐藏行排除，场景不再提 audit footer；
  - `The disk floor's keys are contract rows the console carries` —— 两条阈值仍进视图，夹具缝 `TEAM_DISK_STATS_FILE` 只进读侧、不进视图；
  - `Settings edit task categories and independent PM policy rather than worker seats` —— 两个块的普通话标题与「为什么不同」那句话、
    没有记录的两种普通话原因（由 `record_present` 分开）、SID/来源的人话标签；既有编辑器/确认/CAS/审计/取消/冲突行为逐条保留。
- **`key-replies`（1 条 MODIFIED）**：`Reply storage paths and declared identity are untrusted data` —— 显示规则从
  「displayed as declared, not verified」改成「按记录原样显示、不加限定词」，并明确人面（面板 + `list`/`show`）与机器面的分工；
  该要求的存储/拒绝/惰性/消毒句子逐字保留，另加一句「显示信任不构成认证」。
- **`memory-and-deps`（3 条 MODIFIED，本变更的第三个 delta）**：
  - `The project contract has exactly one writer, and it preserves what it does not change` —— schema 的注释列是**给用户看的正文**
    （写法要求 + D170 分工）、`fixture-only: ` 标记是数据、身份键 note 的「hand-editing」改成「directly editing」的普通话；
  - `The worker-launch keys are an internal frozen seam, not a supported extension point` —— 四个适配器键的 schema note 用普通话
    说清同一件事（保留给将来可能的非 Pi 适配、不是受支持的扩展点、不承诺兼容、新项目初始化不问），场景里钉死的
    `内部接缝（frozen）` 字符串随之改成普通话说法的描述；`references/config.md` 与 human table 不动；
  - `Machine reads separate future policy from committed assignments` —— 每个席位记录多一个 `record_present` 布尔。
  - **为什么必须动这条能力**：设置页那行注释的正文与「有没有记录」这个事实本来就住在这里；面板只能原样渲染读侧给的字，
    要清干净黑话就必须在源处改。**schema 的列格式、group 词表、`references/**` 一个字不动**（新列/新 token 都要改
    `references/config.md`，那是本任务书的不许碰面；把文案抄进面板又会让 bundle 长出第二份 schema，正是 panel 规格禁止的东西）。

### New Capabilities

无。本变更是既有两条能力（`panel`、`key-replies`）的显示契约修订，加上它们的两个**数据来源**（`memory-and-deps`）的同一批
文字与一个布尔；不新造能力，也不新造第二套规格系统。

## Impact

- 产品面：`scripts/panel/src/strings/{zh,en}.ts`（几十条字）、`scripts/panel/src/layout.ts`（设置块的行集过滤、尾巴、宁缺勿编的
  两种「没有记录」行）、`scripts/lib/cmd-config.sh`（schema 注释列 + `record_present`）、`scripts/replies.mjs`（show 头）、
  `scripts/lib/cmd-reply.sh`（用法文本）。
- 夹具面：`tests/panel-p21.sh`（12 处断言 + 行数公式 + 新增「缝行不在视图里」场景）、`tests/key-replies-pty.sh`（5 处）、
  `tests/key-replies-ui.sh`（快照/元数据组）、`tests/panel-strings.mjs`（键集照旧；标记与隐藏的交叉检查）、
  `tests/config-cli.sh`（seats/json 段若断言 `record_present` 或 note 文字）、`tests/section-paths.tsv` 与 `smoke.sh` 的段登记。
- 规格面：`openspec/changes/panel-plain-language/specs/panel/spec.md`（6 条 MODIFIED）、
  `.../specs/key-replies/spec.md`（1 条 MODIFIED）、`.../specs/memory-and-deps/spec.md`（3 条 MODIFIED）。
- 兼容性：**机器出口一字不改**（`team config list --json` 的既有字段类型、`team monitor --print/--json` 的字节稳定性、
  key-replies 的 `--json`/`--raw`）；命令名、退出码、写路径（CAS/审计/danger/类）不动；`references/**`、帮助面（P260）、
  `cmd-watch.sh`/`common.sh` 的报错文案（P261）不在本变更内。
- 用户可见的变化就是本变更的目的：设置页不再有审计块、测试开关、黑话与内部编号；关键回复页不再给标签加限定词。

## 落点（apply 阶段才写；本阶段只写提案）

- 改：`skills/teamsmith/scripts/panel/src/strings/zh.ts`、`.../strings/en.ts`、`.../panel/src/layout.ts`、
  `skills/teamsmith/scripts/lib/cmd-config.sh`（schema 注释列 + `record_present`）、
  `skills/teamsmith/scripts/replies.mjs`、`skills/teamsmith/scripts/lib/cmd-reply.sh`。
- 改（夹具）：`skills/teamsmith/tests/panel-p21.sh`、`tests/key-replies-pty.sh`、`tests/key-replies-ui.sh`、
  `tests/panel-strings.mjs`，以及按需 `tests/config-cli.sh`、`tests/section-paths.tsv`、`tests/smoke.sh`（段名/登记）。
- 不动：`references/**`、`skills/teamsmith/scripts/lib/cmd-watch.sh`、`common.sh` 的报错文案、帮助面与新帮助表、
  key-replies 的存储 helper 的安全边界（`replies.mjs` 只改 show 头那一行人话）。
- 若 `cli-help`(P260) 先落地把回复命令的帮助页搬进帮助面：那条用法文案随页面走，由 PM 在派单时点名文件（帮助面本身仍不动）。

## 需要 PM 裁定的点（提案按推荐版本落笔）

1. **第三个 delta（`memory-and-deps`）**：推荐**要**。理由见 Capabilities 末段；被否决的替代是「面板不再渲染 schema 注释」——
   那要么丢掉 roster 的路线与值的解释（等于削弱既有承诺），要么让面板长出一张按键的注释表（panel 规格明文禁止 bundle 带第二份 schema）。
   任务书 `deltas:` 行写的是 `panel, key-replies`，按 cli-help 的先例，**apply 任务书请把 `deltas:` 行补成三个 capability**
   （`panel, key-replies, memory-and-deps`），否则 memory-and-deps 的 delta 会被判成「没有单写者声明」。
2. **测试开关的标记机制**：推荐 schema 注释前缀 `fixture-only: `（读侧原样报告、面板据此隐藏、夹具按数据驱动验红绿）。
   被否决：新增列或新增 group token（两者都要改 `references/config.md` 的列/词表文档，是本任务书的不许碰面）、
   面板自带隐藏名单（把读侧的数据复制进 bundle，且 schema 以后新增的夹具键会重新漏出到界面）。
3. **席位「没有记录」的两种普通话原因**：推荐读侧补 `record_present`（一行，复用现成的 `team_assignment_record_present`），
   面板按它选句子。被否决：只写一句「这个席位还没有派过任务」——对有记录但读不出来的席位是假话；把 `diagnostic` 做字符串映射——
   那串字不是封闭词表，映射会腐烂。
4. **迁移诊断的正文**：它由 `common.sh` 的 `team_model_policy_issue` 生成（P261 的面，本任务书不许碰），
   推荐**原文保留**（它是用户要照着跑的 CLI 路线），只把面板自己的标题改成普通话（「旧设置需要升级」）。
   要连正文一起改，是 P261 面上的另一条任务。
5. **关键回复的用法/帮助文本**：今天在 `cmd-reply.sh` 的 heredoc（任务书落点里的「用法与列表文本」）；
   若 cli-help 先搬走帮助页，按上一条落点处理。

## 红侧（逻辑类，进门禁）

- **测试开关与审计不在界面里（渲染行为）**：给设置页一份**含**审计与测试开关的输入（真实读侧 payload + scratch schema 多一行带标记的键）
  → 渲染结果里没有审计标题/审计行、没有那些行与标题、`/` 也搜不到；把过滤拿掉（或把标记去掉）→ 红；还原 → 绿。
- **发布者标签按原文渲染**：输入 `--from pm` → 面板（总览摘要、列表行、正文页头）与 `team reply show`/`list` 的人面只出现 `pm` 这个标签、
  不加限定词；把它改成带「自称/未经核验」字样 → 红（`key-replies-pty.sh` / `key-replies-ui.sh` / `key-replies.sh` 的相应断言）；
  机器出口仍逐字相等。
- **正文的安全消毒照旧**：恶意正文仍惰性渲染且不触发任何动作、软链与 FIFO 仍被拒（既有 `key-replies.sh` 的 paths/original 组与
  `key-replies-ui.sh` 的 hostile-strings 场景原样保留，是**未削弱**的证据）。
- **「策略与实际」仍是两行只读、且不编造模型**：P232 的既有场景（类别写不改已派记录、picker 不组合映射、argv 走
  `set-task-model`/`config set`）保留；新增：没有记录的席位两种原因按 `record_present` 分开——把读侧谎报成「都没记录」→ 红。
- **还原后全绿**。

## 文本类不设门禁

措辞、术语是否干净由合并前的评审把关（D170）：**不写**「出现禁用词/内部键名/内部编号就红」这类断言。design 给出设置页与关键回复页
的**最终文案样张**（两种语言），PM 与复验在合并前读一遍界面与命令行的最终文本，确认没有清单里的词与内部编号。

## Acceptance（本阶段只读地跑基线）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/P262-dev3.md
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

（apply/verify 阶段的验收命令与红侧见 tasks.md §5/§6；夹具与命令的最终形态以 apply 冻结的接口为准，但**场景名与红侧方向**不得改。）

## Out of scope

- 不改审计的存储、写路径与 `team config log`（审计仍然写在 `state/config.log`，只是不回界面）。
- 不改任何命令名、旗标、退出码、`team config list --json` 的既有字段与 human table 的列、`team monitor --print/--json` 的字节稳定性。
- 不新增 schema 列、不改 group 词表、不改 `references/**`；不改关键回复的存储格式、安全边界与 `--json`/`--raw`。
- 不改帮助面（P260 的面）、`cmd-watch.sh`/`common.sh` 的报错文案（P261 的面）。
- 不把 `panel-preview-and-compose`(P249) 的输入行动作面、`cli-help`(P260) 的帮助页、`startup-self-heal`(P261) 的启动面并进本变更。

## 粒度

一个 apply 席位做完：文案 + 渲染 + 数据来源是一个原子改动（只做一半时用户看到的界面仍然是黑话或仍缺事实），
夹具（`panel-p21.sh` 的设置场景 + `key-replies-*`）只能整套重跑。若 PM 要拆，唯一不造假的拆法是
「`memory-and-deps`（注释列改写 + 标记 + `record_present`）」与「`panel`/`key-replies`（渲染与两张表 + 夹具）」两批，
且两批都落地前不得派 verify —— 中间态的用户界面既不清也不完整，不能作为验收对象。
