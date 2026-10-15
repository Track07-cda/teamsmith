# panel-plain-language · 设计

## Context

动机与范围见 proposal。以下是本轮读到的、决定做法的基线事实（2026-10-14，本 worktree 逐处读过；行号是当天的）。

- **设置页每行的注释来自 schema 的注释列**。`scripts/panel/src/layout.ts` 的 `settingsKeyLine` 画三样东西：
  标签（`label_<KEY>`，两张表）、值/默认值、类徽章，然后把 `row.warning || row.route || row.comment` 作为行的注释画在同一行；
  其中 `route` 是 `scripts/lib/cmd-config.sh` 的 `team_config_schema()` 每行第 8 列自由文本，经 `team_config_list_json`
  原样进 JSON。用户截图里的两行正是它：`TEAM_REQUIRE_JS` → 「依赖策略：手改 .pi/team/config.sh」、
  `TEAM_DISK_STATS_FILE` → 「测试旋钮：磁盘读数夹具（TEAM_MEMINFO_FILE 同族）；只在夹具里用」。
  逐行数：45 行 schema 注释里 45 行载着这轮要清的说法（身份 / 账本布局 / 环境定位 / 分支语义 / 凭据位置 / 权限守卫 /
  依赖策略 / 机器路径 / 测试旋钮 / 内部接缝 / P159…）。
- **夹具开关是 4 个 schema 键**：`TEAM_DISK_STATS_FILE`、`TEAM_SMOKE_FAST`、`TEAM_INBOX_WATCH_FORCE_FAIL`、
  `TEAM_IW_REQUIRE_WATCH`（类 `refuse`，group `policy`，notes 以「测试旋钮」开头；后两个的标签还写着「（测试）」）。
  其余「测试味道」的键（`TEAM_MEMINFO_FILE`、`TEAM_SIGNAL_REAL`、`TEAM_SIGNAL_CALLS_LOG`、`TEAM_BG_STOP_GRACE`）
  在**真实路径**上被读（容器覆盖 / 信号闸门 / 停止宽限），不是只给夹具用，**留在视图里**、只把注释改成普通话。
- **审计尾画在视图里**：`settingsBlock` 的尾巴固定画 `settingsAuditHeading`（「审计（最近）」）+ 最近 3 行
  `state/config.log`（`SETTINGS_AUDIT_LINES = 3`）；面板规格的 `The console writes a project setting only through
  team config set…` 明文要求「settle 之后重读列表**与审计尾**」，并有场景 `The audit is readable from the view and from
  the CLI`。`state/config.log`、`team config log`、`team config list` 自己的审计尾部（5 行）都与本变更无关。
- **席位记录的诊断原文直接上屏**：`settingsAssignmentNone: '没有完整派单记录：{diagnostic}'`；`{diagnostic}` 来自
  `common.sh` 的 `TEAM_ASSIGN_DIAGNOSTIC`（`missing assignment` / `legacy/unknown assignment_version` / `malformed line` /
  `incomplete model` …），就是用户截图里那行。读侧**已有**一个现成事实函数 `team_assignment_record_present <seat>`
  （`common.sh`，判「`state/<seat>.env` 自称是一份 assignment 记录」），dispatch 用它，`cmd-config.sh` 也可以直接调。
- **发布者标签**：面板 `replyDeclared: '自称来自 {from} · {at}'`、`replyDeclaredShort`、`replyBodyHint: '只读 · 发布者自称，
  未经核验'`；`replies.mjs` 的 `show` 文本头是 `来自 X（自称）· 时间 · 字节 · sha256 …`（`list` 文本行本来就是
  `#no <时间> <标签> <标题>`，不带限定词）；`cmd-reply.sh` 的用法头写「`--from` 是自称的平坦标识符…不是身份认证」。
- **被钉住的断言/规格**（改文案必须同步改）：
  - 夹具：`tests/panel-p21.sh` 12 处 + 行数公式 `rows + ↑ + ↓ = 命令报的键+类别+派单记录`（隐藏 4 行后公式要变）；
    `tests/key-replies-pty.sh` 5 处（`自称发布者`、`只读 · 发布者自称，未经核验`、`只读 · 发布者自称`、`自称来自 dev2`）；
    `tests/key-replies-ui.sh` 的快照组；`tests/panel-strings.mjs`（键集相等 / 表外无 CJK / 契约键标签双向相等）。
  - 规格：`memory-and-deps` 两处（身份键 route 必须写 hand-editing；适配器键 route 必须写「内部接缝（frozen）」且
    「console shows it under the row」）；`panel` 6 条（行集与 route 行、审计尾、分组标题、高度场景的 audit footer、
    磁盘缝「是视图里的 refuse 行」、类别与席位块）；`key-replies` 1 条（displayed as declared, not verified +
    visibly self-declared）。
- **面板的纪律**：`panel#The console shows the project contract…` 明文禁止 bundle 自带第二份 schema（不许有按键的类/默认值/行序表），
  并要求键集与分组标签与 schema 双向相等（`panel-strings.mjs`）；`panel#All visible text comes from external zh/en string
  tables` 与 `tests/panel-strings.mjs` 还禁止 `src/**`（strings/ 除外）里出现中文正文 —— 面板自己的字只能住两张语言表。
- **用户裁定 D170**：门禁只管逻辑（行为/状态），措辞/术语/排版由设计与评审把关。故本变更没有「出现某个词就红」的断言。

## Goals / Non-Goals

**Goals**：设置页不再出现审计块与夹具开关；设置页与关键回复页的**每一句可见文字**都是普通话（含命令原样打印的
CLI 路线这一类「事实性命令行」）；「下一次派任务会用的模型」与「正在运行的任务实际使用的模型」这层区分保留且用普通话讲清；
发布者标签按记录原样显示、不贴限定词。所有承诺都落在两条能力（`panel`、`key-replies`）的 delta 与它们数据来源
（`memory-and-deps`）的 delta 上，机器出口逐字节不变。

**Non-Goals**：不翻译 CLI 的其余中文消息；不改审计的存储/写路径/`team config log`；不改 schema 的**列格式**与 group 词表；
不改 `references/**`；不改帮助面（P260）与 `cmd-watch.sh`/`common.sh` 的报错文案（P261）；不改关键回复的存储格式、
拒绝规则（软链/非普通文件/穿越/外来根）与 `--json`/`--raw`；不设文案门禁（D170）；**如实说明**：标签是调用方自己声明的，
工具不认证 —— 显示信任不等于认证，这句话写在 Non-Goals、delta 与文档里，不贴在标签上。

## Decisions

### 1. 黑话清在**源处**：schema 的注释列就是设置页那一行的正文

设置页那行注释的正文住在 schema 的第 8 列（`memory-and-deps` 的能力面）。要「界面里没有黑话」，只有两个方向：

- **推荐（本提案）**：把那一列改写成普通话（`memory-and-deps` 的 MODIFIED delta），面板**照旧原样渲染**读侧给的字。
  好处：一条文案只有一个家（不会漂移）；roster 的 `team add-agent` 路线、值的解释、适配器键的「预留、不承诺兼容」
  这些**有用**的信息一句不丢，只是换了说法；`team config set` 的拒绝诊断顺带也说人话。
- 被否决：**面板不再渲染 schema 注释**。要么丢掉上面那些信息（等于削弱既有承诺：规格里还钉着 roster 的路线与
  「raw key 与命令行对齐」），要么让面板长出一张按键的注释表 —— 那正是 panel 规格禁止的第二份 schema，且 schema 里新增的键
  会没有注释。

### 2. 夹具开关：schema 注释以声明标记 `fixture-only: ` 开头，视图不渲染带标记的行

用户要的是「界面上完全不出现」，机制必须是**数据**而不是面板里的名单：

- 那 4 个键的 schema 注释改成以声明标记 `fixture-only: ` 开头（例如
  `fixture-only: 磁盘读数夹具；只在测试套件里用`），`memory-and-deps` 拥有这个标记的语义；
- 面板的行集在渲染前过滤掉带标记的行：不给行、不给分组标题、`/` 也不命中（`panel` 的行集要求拥有这条规则）；
- 读取与命令行**一字不变**：`team config list --json` 照旧报告这些键的全部字段（含以标记开头的 `route`）、
  human table 照旧列出、`team config set` 照旧 exit 5（delta 里有场景），所以「读取与命令行行为不变」；
- 红侧是**数据驱动**的证明：把某一行的标记删掉 → 那一行回到视图（红）；把真实 4 行的标记删掉 → 4 行一起回来；
  改回 → 全绿。夹具因此不依赖任何写死的名单。
- 被否决：新增第 11 列或新增 group token `fixture`（两者都要改 `references/config.md` 的列/词表文档，是本任务书的
  不许碰面）、面板自带隐藏名单（把读侧的数据复制进 bundle，将来 schema 新增夹具键会重新漏到界面）。

### 3. 审计离开视图，留在文件与命令行

- 视图不再画 `settingsAuditHeading` 与那 3 行（也不画任何「去别处看审计」的指路行 —— 用户要的是这块东西从界面消失，
  指路行仍属「出现在界面」）；写路径的 settle 后重读只重读列表；视图的尾部只剩聚焦行的命令行。
- 审计本身：`state/config.log` 一字不动，`team config log` 与 `team config list` 自己的审计尾部照旧（delta 里用
  「仍能从文件与命令行读到同一行最新记录」的存在性场景守住，并显式写明设置视图不是它的读者）。
- **两个基线场景名的保留**：`openspec validate --strict` 拒绝 MODIFIED 块丢掉基线场景名
  （`MODIFIED … omits scenario(s) the current spec still has`），所以
  `panel#…after validation and a confirmation` 里的场景名 `The audit is readable from the view and from the CLI`
  与 `panel#The disk floor's keys…` 里的 `The three keys reach the view and the machine read` **原名保留**，
  正文改成新规则（前者的「the view」现在指契约自己的人面 `team config list`；后者正文写明三条键都进机器读、
  只有两条阈值进视图）。工具不让我们在 MODIFIED 里改名，这两处**名字**因此是历史名；**正文**是新合同，没有歧义。
  （备选是 REMOVED + ADDED 整条要求换名，那会丢掉要求的历史与 `spec-refs` 的稳定性，收益只是两个名字，不做。）

### 4. 「策略与实际」的普通话，与「没有记录」的两种原因

- 两个块的标题：`settingsGroupCategories` → 「下一次派任务会用的模型」；`settingsGroupAssignments` →
  「正在运行的任务实际使用的模型」；类别行的徽章仍是「新任务」；
- 一句「为什么不同」：`settingsAssignmentHint` → 「任务派出去以后就固定用它当时的模型，不跟着上面的设置变」，
  放在聚焦行的命令行上（既有的 M49 位置），类别 picker 的说明里同义再说一次；
- 席位没有完整记录时**不渲染命令的 `diagnostic`**，按读侧事实选句子：
  `record_present=false` → 「这个席位还没有派过任务」；`record_present=true`（有记录但读不出来：版本、字节、
  外来内容）→ 「这个席位派过任务，但它的记录读不出来，面板不显示它在用的模型」。两个句子都在两张表里；
- 为此读侧补一个布尔：`team config list --json` 的每个 assignment 记录多一个 `record_present`
  （`cmd-config.sh` 调现成的 `team_assignment_record_present`，不加新函数、不改 `common.sh`）；delta 落在
  `memory-and-deps#Machine reads separate future policy from committed assignments`。
- `SID` 这类字段名在行里改成「会话」；来源 token（`selected_via`/`launch_via`）继续用表里的普通话标签
  （现在叫「显式 / 类别策略 / 已派记录」，改成「派单时指定 / 按类别设置 / 沿用原记录」）。
- 迁移诊断：面板**不用**在这里做 1 与 2 之外的重排。正文由 `common.sh` 的 `team_model_policy_issue` 生成（P261 的面），
  它是用户要照着跑的 CLI 路线 → 原文保留（proposal 裁定点 4），只把面板的标题改成「旧设置需要升级」。

### 5. 发布者标签：显示信任 + 记录原样

两层，互不矛盾：

- **记录层**（不变）：`team reply post --from <label>` 的标签是调用方填的平坦标识符，存进槽位的就是这段原文；
  `--json` 的 `from`、`--raw` 的字节、槽位记录的哈希规则都不动。
- **显示层**（本变更）：人面只显示这段原文（面板「来自 pm · 时间」，CLI `show` 头「来自 pm · 时间 · 字节 · sha256」，
  `list` 行本来就只有标签）；不再出现「自称」「未经核验」以及英文的 declared / not verified。
- **不矛盾在哪**：限定词原本贴在每一次显示上，而它想说的是一件**关于工具**的事实（工具不认证标签），不是关于这条回复的事实；
  那件事写在文档、Non-Goals 与 `key-replies` delta 的一句「显示信任不构成认证」里，仍然是明说的。
- 安全一条都不弱化：存储路径与记录名仍按不可信数据处理、读接口不接受任意路径、正文惰性、显示前消毒 —— delta 里这些句子逐字保留。

### 6. 可见文字规则与「与命令行对齐的位置」

- 面板自己的字只能来自两张语言表（既有纪律）；schema 的注释列是读侧给的**事实性正文**，在源处写成普通话；
- 原始 `TEAM_*` 键名与内部编号只允许出现在**与命令行对齐**的位置：`/` 焦点行的命令行（`team config set <KEY> <value>`）、
  编辑器标题与确认行、命令自己打印的迁移诊断；其余任何用户可见文字里不出现 `TEAM_*`、`M<数字>`、`P<数字>`；
- 迁移诊断、`team add-agent` / `team teardown` 这类**路线**是命令行本身（用户要照着跑），保留原样；
- 措辞是否干净由合并前的人读把关（D170），夹具只判行为。

### 7. 不改的东西（边界）

`references/**`、schema 的列格式与 group 词表、`cmd-watch.sh`/`common.sh` 的报错文案、帮助面与新帮助表、
key-replies 的存储/拒绝/消毒、审计的存储与 CLI、命令名/旗标/退出码/`team config list --json` 的既有字段与
`team monitor --print/--json` 的字节。若 `cli-help`(P260) 先落地把回复命令的帮助页搬进帮助面，`team reply` 的
用法文案随页面走，由 PM 在派单时点名文件。

## 最终文案（两种语言的样张）

### 设置页 · 渲染样张（zh，示意帧，列宽 100）

```
 项目设置
 ── 身份与账本布局 ────────────────────────────────────────────────────────────
 › 项目名                       acme  · 不可改
   项目身份：只能改项目配置文件 .pi/team/config.sh 里的这一行；team init 不会改它，team init --force 会重写整份文件
   会话名                       acme-dev  · 不可改
   账本目录                     docs/team  · 不可改
 ── 权限与依赖 ────────────────────────────────────────────────────────────────
   必需 OpenSpec                开（1）  · 不可改
   内存信息文件                 （未设 · 默认 —）  · 不可改
 ── 工作流与门禁 ──────────────────────────────────────────────────────────────
   复验超时                     1800  · 立即生效
   复验放行脏工作树             0  · 立即生效
 ── 名册、模型解析与适配器 ────────────────────────────────────────────────────
   席位启动命令                 （未设）  · 立即生效
   预留：为以后可能更换的 agent 适配器保留，不是受支持的扩展方式，也不承诺兼容；新项目初始化时不问
   名册                         dev verify  · 不可改
   席位名单：用 team add-agent <名> --register 添加，team teardown --agent <名> --register 移除
 ── 下一次派任务会用的模型 ────────────────────────────────────────────────────
   类别 routine                 kimi-coding/k3-256k  · 新任务
 ── 正在运行的任务实际使用的模型 ──────────────────────────────────────────────
   dev                          xai/grok-4.6  · 不可改
   任务 T232-x · 类别 routine · 会话 sid-dev-232 · 来源 派单时指定/派单时指定
   verify                       —  · 不可改
   这个席位还没有派过任务
   命令性路线（聚焦行）：team config set TEAM_PULSE_INTERVAL <value>
   只读行的提示：这个值要改项目配置文件 .pi/team/config.sh，界面不能改
```

（同一份样张的 en 面用 `en.ts` 的对应条目：`Permissions & dependencies`、`The model the next task will use`、
`The model running tasks actually use`、`this seat has not been given a task yet`、
`change this value in the project config file .pi/team/config.sh; the panel cannot change it`、
`Reserved: kept for a possible different agent adapter; not a supported extension and no compatibility promise;
a new project is not asked about it`。）

**本变更里设置页要动的字（zh → en）**：

| 位置 | 现在 | 改成（zh） | 改成（en） |
|---|---|---|---|
| 组标题 `group_policy` | 权限与依赖策略 / Permissions & dependencies | 权限与依赖 | Permissions & dependencies（不动） |
| 组标题 `group_patrol` | 巡检策略 / Patrol policy | 巡检 | Patrol |
| 类别块标题 `settingsGroupCategories` | 任务类别（未来策略） | 下一次派任务会用的模型 | The model the next task will use |
| 席位块标题 `settingsGroupAssignments` | 实际派单记录（只读） | 正在运行的任务实际使用的模型 | The model running tasks actually use |
| 类徽章 `settingsBadgeRefuse`、`settingsReadOnlyBadge` | 只读 | 不可改 | change in file |
| 未知键徽章 `settingsUnknownBadge` | 未知键 | 不认识 | not recognized |
| `settingsAssignmentHint` | 只读：实际模型来自已提交的派单记录（由 dispatch/resume 决定），不是上面的未来策略 | 任务派出去以后就固定用它当时的模型，不跟着上面的设置变 | Once a task is dispatched it keeps the model it was given; this setting does not change it |
| `settingsAssignmentNote` | 任务 {task} · 类别 {category} · SID {sid} · 来源 {selected}/{launch} | 任务 {task} · 类别 {category} · 会话 {sid} · 来源 {selected}/{launch} | task {task} · category {category} · session {sid} · origin {selected}/{launch} |
| `settingsAssignmentNone` | 没有完整派单记录：{diagnostic} | 这个席位还没有派过任务 | this seat has not been given a task yet |
| `settingsAssignmentUnreadable`（新增） | — | 这个席位派过任务，但它的记录读不出来，面板不显示它在用的模型 | this seat was given a task, but its record could not be read, so the panel does not show its model |
| `settingsPmLaunchLabel` / `Hint` | PM 启动记录 / 只读：PM 的实际启动记录（state/pm-launch.env） | PM 上次启动 / PM 上一次启动时用的模型，这里不能改 | last PM start / the model the PM used the last time it started; it cannot be changed here |
| `settingsDiagnosisHeading` | 策略迁移诊断 | 旧设置需要升级 | these settings need an upgrade |
| `settingsRefusedRoute`、`settingsRefusedHint` | 只读键：手改 .pi/team/config.sh（里的 {key}） | 这个值要改项目配置文件 .pi/team/config.sh，界面不能改 | change this value in the project config file .pi/team/config.sh; the panel cannot change it |
| `settingsUnknownHint` | 未知键：{key} 在文件里，命令的 schema 不认识 | {key}：这个设置在文件里，工具不认识它，面板不能改 | {key}: the file carries this setting but the tool does not know it; the panel cannot change it |
| `settingsCategoryHint`、`settingsCategoryPickerHint`、`settingCategoryConfirm`、`settingCategoryWritten` | …已派任务保留原模型/SID… | …只影响以后派的新任务；已经派出去的任务继续用它当时的模型… | …new tasks only; a task already dispatched keeps the model it was given… |
| `settingPmWritten` | 换模型须 fresh-pm，由启动守卫判定 | 换模型要用 team up --fresh-pm 重开一场对话 | changing the model needs team up --fresh-pm, which starts a new conversation |
| `settingRefused` | ✗ 只读键：{line} | ✗ 这个值要在项目配置文件里改：{line} | ✗ this value is changed in the project config file: {line} |
| `settingsChoiceKeepUnset` | 保持未设（取消 = 不写、不留审计） | 保持未设（取消，什么都不写） | keep unset (cancel, nothing written) |
| 来源标签 `seatSource*` | 显式 / 类别策略 / 已派记录 | 派单时指定 / 按类别设置 / 沿用原记录 | chosen at dispatch / set by category / kept from the record |

（其余设置页的字，例如「项目设置」「未设 · 默认 {value}」「↑/↓ 行 · Enter 编辑 · / 筛选 · Esc 返回」「保持未设」之外的选择器条目、
间隔说明、bool 的开/关、路径的存在/不存在，本轮不动：它们已是普通话。）

**schema 注释列（`memory-and-deps`）改写的类别规则**（apply 逐行落；这里给规则与每类一条样张）：

| 类别（键） | 现在 | 改成（zh；en 表同义） |
|---|---|---|
| 身份 `TEAM_PROJECT/SESSION/PM_WINDOW` | 身份：手改 .pi/team/config.sh（team init 不改它）；team init --force 会重渲染整份契约 | 项目身份：只能改项目配置文件 .pi/team/config.sh 里的这一行；team init 不会改它，team init --force 会重写整份文件 |
| 账本位置 `TEAM_DOCS_DIR/WORKTREES_DIR/STATE_DIR/MEETINGS_DIR/SPEC_DIR` | 账本布局：手改 .pi/team/config.sh | 账本位置：只能改项目配置文件 .pi/team/config.sh |
| 环境定位 `TEAM_ROOT/MAIN_ROOT/CONFIG_FILE` | 环境定位：用 --root 或手改 .pi/team/config.sh | 位置：启动时用 --root/--config 指定，或改项目配置文件 .pi/team/config.sh |
| 分支与凭据 `TEAM_BRANCH_MODE`、各前缀/远端/VCS/token | 分支语义：手改 … / 凭据位置：手改 … | 分支与落地判定：只能改项目配置文件 .pi/team/config.sh / 凭据文件位置：只能改项目配置文件 .pi/team/config.sh |
| 权限 `TEAM_CONFIRM_WRITES` … | 权限守卫：手改 .pi/team/config.sh | 权限：只能改项目配置文件 .pi/team/config.sh（面板不给自己扩权） |
| 依赖 `TEAM_REQUIRE_*` | 依赖策略：手改 .pi/team/config.sh | 依赖要求：只能改项目配置文件 .pi/team/config.sh |
| 机器路径 `TEAM_PI_AGENT_DIR`、`TEAM_PI_SETTINGS_FILE`、`TEAM_MEMINFO_FILE` | 机器路径：手改 … | 这台机器上的路径：只能改项目配置文件 .pi/team/config.sh |
| 夹具开关（4 行） | 测试旋钮：…（M53） | fixture-only: 只在测试套件里用（磁盘读数夹具 / 冒烟快模式 / 强制 watcher 注册失败 / 记录严格模式） |
| 适配器键（4 行） | 内部接缝（frozen）：为将来非 Pi 适配预留，不承诺兼容；不在 init 问卷里问 | 预留：为以后可能更换的 agent 适配器保留，不是受支持的扩展方式，也不承诺兼容；新项目初始化时不问 |
| 信号/后台（3 行） | P159 信号闸门：…；手改 … | 信号调用记录：每次调用写一行，只能改项目配置文件 .pi/team/config.sh / 信号程序的位置（测试钉桩用），只能改项目配置文件 … / 停止后台作业前的等待秒数，只能改项目配置文件 … |
| 名册 `TEAM_AGENTS` | 名册：team add-agent <a> --register / team teardown --agent <a> --register（都走审计写入器） | 席位名单：用 team add-agent <名> --register 添加，team teardown --agent <名> --register 移除 |
| 类别/PM 模型 | 新任务类别：…；恢复保留已派身份 / 独立 PM 模型：team up 启动受 fresh-pm 守卫 | 新任务用哪个模型：用 team config set-task-model <类别> <模型> 改 / PM 用哪个模型：下次 team up 启动时生效，换模型要用 --fresh-pm |
| 已退役键 `TEAM_ALLOW_DESTRUCTIVE_TMUX` | 权限守卫（M67 退役）：不再授权任何操作… | 已退役：不再授权任何操作，只保留为不可写的记录行，只能改项目配置文件 .pi/team/config.sh |

（`fixture-only: ` 是**声明标记**：面板据此隐藏整行；其余类别的正文里不再出现 `手改`、`只读键`、`测试旋钮`、
`内部接缝`、`旋钮`、`接缝`、`依赖策略`、`机器路径`，也不再出现 `P159`/`M53`/`M67` 这类内部编号。）

### 关键回复页 · 渲染样张（zh）

```
 关键回复
   #3  结论与取舍                    来自 dev2 · 2026-10-14T07:12Z
   #2  第二份回复                    来自 verify · 2026-10-14T07:10Z
   → 正文页头：
      #3 结论与取舍
      来自 dev2 · 2026-10-14T07:12Z · 1.2 KB
      只读 · 按发布的原文显示
```

命令行（人面）：
- `team reply list`：`#3<TAB>2026-10-14T07:12Z<TAB>dev2<TAB>结论与取舍`（本就不带限定词）；
- `team reply show 3`：头两行 `#3 结论与取舍` / `来自 dev2 · 2026-10-14T07:12Z · 1234 字节 · sha256 0123456789abcdef…`（删掉「（自称）」）；
- `team reply --help`：`--from` 的说明改成「调用方填的标签（1–48 个 `[A-Za-z0-9._-]`）；工具不核对它是谁」；`list` 一行的说明改成
  「`#no <时间> <发布者标签> <标题>`」。

## 红侧（逻辑类，进门禁）与「文本类不设门禁」

| 承诺 | 夹具（apply 写） | 红侧（破坏 → 必红 → 还原 → 绿） |
|---|---|---|
| 审计与夹具开关不进渲染 | `panel-p21.sh` 新增场景：真实读侧 payload + scratch schema 多一行带标记的键 | 去掉行集过滤 / 把审计尾画回 → 场景红 |
| 夹具开关仍在校验面 | `panel-p21.sh` / `config-cli.sh` 断言 `team config list --json` 仍报告、human table 仍列出、`set` 仍 exit 5 | 把键从 schema 删掉（让读都看不到）→ 红 |
| 标记是数据 | scratch 树：删掉某一行的标记 → 该行回到视图 | 标记解析写成写死名单 → 换一个键名就红 |
| 没有记录的两种原因 | `panel-p21.sh`：一个无记录席位（`record_present=false`）+ 一个有记录读不出来的席位（true） | 读侧把两者都报成 false / 面板把 `diagnostic` 画上屏 → 红 |
| 发布者标签按原文渲染 | `key-replies-pty.sh`（总览摘要、列表行、正文页头）、`key-replies-ui.sh`（快照）、`key-replies.sh`（`show` 文本头） | 给标签加回限定词 → 红；`--json` 的 `from` 字节变 → 红 |
| 安全面未削弱 | 既有 `key-replies.sh` 的 paths/original/readonly 组与 `key-replies-ui.sh` 的 hostile-strings 场景 | 原样保留；夹具被删/被放宽 → 红 |
| 机器出口稳定 | `panel-snapshots.sh` 四档快照、`monitor --print/--json` 字节断言（既有） | 文案改动漏进 `--print`/`--json` → 红 |

**文本类不设门禁**（D170）：不写「界面出现某个词就红」「缩进必须 N 格」这类断言；上面的表里每一条判的都是**行为**
（哪块画了、哪行画了、标签画成什么字、退出码/字节是否变化）。最终文案的干净程度由合并前 PM/复验读一遍样张与真实界面把关。

## 未决 / 后续

- 迁移诊断的正文（`common.sh` 的 `migration_required: …；修法：…`）保留原文：它是 P261 的面，本任务书不许碰。
  若用户希望那几行也是普通话，另派一条 P261 面上的任务。
- `team reply` 的用法/帮助文案：今天在 `cmd-reply.sh`；若 `cli-help`(P260) 先落地把帮助页搬进帮助面，同一句随页面走。
- 本变更不引入任何文案门禁；将来若要「术语表」，D170 的口径是设计与评审，不是夹具。

## Acceptance

本阶段（propose，只读地跑基线）：

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/P262-dev3.md
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

apply/verify 阶段见 tasks.md §5/§6（各段命令与红侧在那里逐条列出）。
