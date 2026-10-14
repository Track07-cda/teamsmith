# cli-help · `team help` 与每个命令的帮助页：分级菜单、默认英文、可切语言、给不懂这个项目的人看的

## Why

用户 2026-10-14 的要求（本变更的唯一需求来源，原话）：

> 我看 `team --help` 里描述的语言风格太难懂了，而且需要默认是英文，且支持多语言。`--help` 菜单出来的也很乱，不好看。
>
> 你要确保的是对这个项目的实际内容和原理不懂的用户能够通过 `--help` 了解各种功能的作用和含义，避免过于简化的描述。
>
> （追加一）帮助要**分级**，不许一次把所有命令吐出来。
>
> （追加二）缩进也很糟糕，全都是同一级。

现状复核（2026-10-14，本 worktree 实测，数字为度量）：

- `team help` 是 `scripts/lib/cmd-project.sh` 的 `team_cmd_help` 里一段 **98 行中文 heredoc**：8 个 `── 组 ──`
  标题、47 条条目，**47 行超过 100 列**（最长 169 列），条目说明换行顶到第 19 列、**没有悬挂缩进**；组标题、
  命令、说明、参数、散文全挤在同一个 2 空格层级上（用户第二条追加要求说的就是这个）；5 行用 `→` 把动作串成
  8 个环节的链（例如 bootstrap：「写配置 + 文档骨架 + AGENTS 段落 + 把 skill 装进项目 .pi/skills/ → 建 agent
  worktree → 起巡检窗口 → 打印下一步清单」）。
- **一次把所有命令吐出来**：`team help` 一条命令就铺开 47 条用法行 / 42 个命令 / 75 个旗标声明，读者没有入口。
- **没有按命令的页**：全局参数在一个循环里把任意位置的 `--help` 折成 `help`，所以 `team status --help`、
  `team config --help`、`team meeting --help` 全都退回那 98 行的全局页（exit 0），`team help <cmd>` 一样被忽略
  ——V27 复验记过这条 nit。
- **没有语言层**：CLI 全中文硬编码（`scripts/lib` 里 5477 行含中文、20 个文件）；README 与 `references/**` 是
  英文（§18 的英文正文不变量只覆盖 `references/**` 与 `SCOPE.md`，脚本树不在口径内）。面板有先例：
  `scripts/panel/src/strings/{en,zh}.ts`（键集相等由门禁断言、缺键可见），但面板默认 `zh`，CLI 要求默认 `en`。
- **概念不解释**：PM/席位/worktree/brief/change/门禁/账本/pulse/knock/`--yes` 全都不定义。
- **已有的诚实性守卫与它今天的覆盖面**：`tests/routes.sh`（门禁 §51）的 Walk A 只读 `team help` **一处**输出，
  今天解析出 47 条用法行 / 42 个命令 / 75 个 (命令,旗标) 声明并逐条喂真解析器；Walk B 校验 schema 注释点名的
  命令有探针；另有 10 条翻转证明它坏得掉。基线：routes.sh **214 ✓ / 0 ✗**、`openspec validate --all --strict`
  17/17（本 change 加进来后 18/18）、`spec-refs.sh --check` 0 未声明。
- **产品无框架**：帮助本体就是一个 heredoc，`package.json` 的 `dependencies` 是空的（唯一带框架的是面板的
  ink+react）；所以本变更走**数据驱动**（一份命令清单 + 渲染器 + 平级语言表），不引 CLI 框架、不加依赖。

用户要的东西是三层：**看起来有层次**（分级 + 缩进）、**读得懂**（概念与深度）、**不许说谎**（每条声明有兑现）。
第三层是这个仓库已有的口味（P99 的用法诚实性），所以本变更不是「再写一段更好的文案」，而是把帮助面变成
**结构性声明 + 可跑检查**的产品面；分级之后 Walk A 的覆盖面从「一处 47 行」扩到「每一级的所有页 × 清单里每个
命令」，是拧紧而不是放松。

## What Changes

### 分级（第一条追加要求）

- **第 0 级**：`team`（无参）与 `team help` → 「teamsmith 是什么」（2–3 句人话）+ **8 组清单**（每组一行一句用途）
  + **新手上手 3–5 个命令**（每个一条用法行 + 说明）+ 「怎么进下一级」。**渲染不超过 30 行**，且第 0 级打印的
  命令用法行必须是 3–5 条 —— 两条都由夹具断言规模，超了红并点名越界的那几行（红侧 ⑥）。
- **第 1 级**：`team help <组>` → 该组每个命令**一行**（用法片段 + 一句用途）+ 「看完整一页用
  `team help <命令>`」。
- **第 2 级**：`team help <命令>` 与 `team <命令> --help`（含 `-h`）→ 该命令自己的页；
  **两条入口逐字节相同**（delta 有专项场景），**不得**再退回全局那 98 行。
- **未知组/未知命令**：exit 2、点名 token、指回 `team help`，不执行任何命令、不写状态；dispatcher 真的接受的
  名字（含别名）不许被这样拒绝 —— 别名打印主命令的页 + 一行别名说明。
- **结构单一真源**：一份机器可读的**命令清单**（`scripts/strings/commands.tsv`：命令 / 组 / 用法片段 / 旗标 /
  子命令 / 别名 / 例子 / 触碰面 / 效应 / 授权 / 可撤销性 / 概念引用），菜单、组页、命令页全部由它渲染；
  **`tests/routes.sh` 的 Walk A 读同一份清单**（覆盖度 = 清单里每个命令 × 每条用法行）。
- 帮助路径**不加载项目配置**、在任何目录可用、请求帮助永远不执行被帮助的命令、不启动进程。

### 排版层级（第二条追加要求）

渲染器强制的固定层级（每条都可由夹具查，见 design 的「目标排版样例」与决策 4）：

| 层级 | 内容 | 缩进 |
|---|---|---|
| 0 | `── <标题> ──…` 组/小节标题（组与组之间空一行）；每个输出片段第一个标题之前的引导行 | 列 0 |
| 1 | 命令的用法行（条目；首个 token 是 dispatcher 接受的命令名） | 2 |
| 2 | 命令的说明（悬挂块：后续行对齐到说明首列；**用法行不与说明同处一行**） | 6 |
| 3 | 参数/旗标（一行一个/一块）与例子块 | 10 |
| 4 | 概念定义（比说明再进一级） | 14 |

宽度默认 **100 显示格**（CJK 宽字符按 2 格），`TEAM_HELP_WIDTH` 正整数覆盖（非法值一行告警后回退）；
折行只由渲染器做，**续行必须比它续的那一行更深**（不许出现「后半句顶回左边」）。禁止形态逐条可查：`→`、
散文里的数字而该命令没有声明它、散文里出现该命令用法行没打印的 `--flag`、小节乱序、空小节、空组、
用法块里非标题的列 0 行、层级之外的缩进；`Arguments` 与 `Usage` 的旗标集合**双向相等**；`Example` 的命令路径
必须真实存在。**版式必须能被走查认出来**：用法块从列 0 的 `──` 标题开始，块内只有条目（缩进 2、首 token 是真实
命令）与更深续行；其余行要么在片段第一个标题之前，要么是无旗标的列 0 行（结束当前块）。

### 读者与深度、语言、诚实性

- 每页固定 12 个带标签的部分（用途一句话 / `Usage` / `What it does` / `When to use it` / `Arguments` /
  `Example` / `Reads`·`Writes` / `Side effects` / `Authorization` / `Undo` / `Concepts` / `See also`），每部分非空；
  页内 `Concepts` 复述该页用到的概念定义（与菜单里的定义逐字节相同），单读一页也读得懂。必定义概念：
  PM 与 worker 席位、worktree 与任务分支、brief 与它的 `category:`、change 与 spec、门禁与「为什么绿是证据」、
  账本与「谁写的」、pulse 与 knock、`--yes` 与授权边界。
- **默认英文**；`TEAM_LANG=en|zh`（**只读环境变量**，理由见裁定点 1）；非法值一行告警点名后给英文面；
  语言只换散文（命令路径/旗标/用法片段/部分顺序逐字节相同）；**缺键可见**（打印行带含键 id 的标记并回退到另一
  语言的值），另有键集比对检查，删一个键必红点名；`TEAM_LANG` 不影响任何 `--json`/`--print` 字节。
- **声明与兑现**：命令清单的 `effect`/`auth`/`undo` 三类字段取值来自封闭词表，**每个取值名到一条探针**（只读 →
  状态指纹不变；写面 → 该面变了；起进程 → 记录器有启动；`needs-yes` → 无授权拒绝点名 `--yes` 且一个字不写、
  有授权继续；`idempotent` → 第二次跑逐字节不变；`undo-by-<cmd>` → 指纹复原）；没有探针的取值判红点名；
  散文里的数字必须名到已声明的 claim。用法行那一半在 `dispatch#The printed route is a route that works`。

### 走查扩面（第一条追加要求的诚实性一半）

`dispatch#The printed route is a route that works` 的**主语从 `team help` 扩到帮助面的每一级**（本变更写
`dispatch` 的 MODIFIED delta）：Walk A 读命令清单作为工作集（覆盖度 = 清单里每个命令 × 每条用法行），逐级解析
**菜单 / 每个组页 / 每个命令页**的输出并逐条喂真解析器，同时保留它今天全部的红侧与非空洞控制臂。数字对比
（写进 design 与报告）：**今天** 1 个面 / 47 条用法行 / 42 个命令 / 75 条 (命令,旗标) 声明；**改后** 1 个菜单 +
8 个组页 + 48 个命令页，dispatcher 接受的每个名字的用法行都被解析、打印出的每个旗标都被探针判过。这是**加强**，
不是放松：旧走查看不到页面上任何一条坏用法行。

### 不变量

命令名、旗标名、每个既有命令的退出码一个不改；`--print`/`--json` 字节一个不改（帮助表读不到那条路径）；
其他规格对帮助行的字面期望继续成立（`init` 行有 `.pi/skills`/`--copy`/`--no-skills`；`add-agent` 行有
`--register`/`--create`/`--no-install`/`--print` 且没有 `--model`；`teardown` 行有 `--register`；`dispatch` 行有
`--branch <name>`）。未知 token 的 `--help` 从今天的 exit 0 改成 exit 2（见裁定点 4），是本变更唯一改掉的退出行为。

### 落点（实现面，apply 阶段才写）

- 新增：`scripts/strings/commands.tsv`（命令清单，语言无关）、`scripts/strings/help.en.tsv`、
  `scripts/strings/help.zh.tsv`（键 → 散文）、`scripts/lib/cmd-help.sh`（渲染器：层级、折行、缺键标记、语言与
  宽度解析、三级路由的渲染出口）。
- 改：`scripts/team`（`--help`/`-h` 与 `team`/`team help` 在**加载配置之前**解析到三级路由）、
  `scripts/lib/cmd-project.sh`（删 98 行 heredoc）、`scripts/lib/cmd-meeting.sh`（`team_meeting_help` 并入
  `meeting` 页，不留第二个真源）。
- 夹具：`tests/help-surface.sh`（新：分级覆盖 / 第 0 级规模 / 键集 / 布局层级 / 声明探针 / 机器出口 / 内容不变量，
  逐组红侧；**版式阶梯只在这里测一次**）、`tests/routes.sh`（Walk A 读清单 + 逐级解析并探测、保留全部既有红侧与控制臂；Walk B 不动）、
  `tests/smoke.sh` §51 增跑、`tests/section-paths.tsv` 归属登记、必要时 `section-budgets.tsv`。
- 文档：`references/config.md`（或 `workflows.md`）登记 `TEAM_LANG`、`TEAM_HELP_WIDTH` 两个环境旋钮（英文）。

## Capabilities

### New Capabilities

- `help-surface`：三级帮助面本身的合同 —— 三级菜单与路由、第 0 级的规模上限、页面深度与必定义概念、默认英文 +
  `TEAM_LANG`、固定层级版式与可解析性、命令清单 + 封闭词表 + 探针、以及「不改命令/旗标/退出码/机器出口」的不变量
  （7 条 ADDED，26 条场景）。

### Modified Capabilities

- `dispatch`：**MODIFIED** `The printed route is a route that works` —— 走查的主语从「`team help` 的用法行」扩到
  「帮助面每一级的用法行」，工作集来自新的命令清单（覆盖度 = 每个命令 × 每条用法行），并新增 3 条场景（第 2 级页面
  的坏用法行、清单漏命令、逐级判断）。**不是**平行陈述：走查合同只有一个家，主语的扩大必须改在它自己的要求里；
  基线的每条句子与 14 条场景逐字保留（apply 的 0.2 项会做投影核对）。
- 为什么不把走查扩面写成 `help-surface` 的新要求：那会在两个能力里同时维护一条走查合同（同一份旗标判两次、
  两份文本会漂移），PM 的提案评审清单第 7 条明确禁止这种平行陈述。
- 任务书的 `deltas: help-surface` 行只点了第一个 delta；本变更实际写两个 delta 文件（`help-surface` 与
  `dispatch`），写 apply 任务书时请把 `deltas:` 行补成两个 capability（否则 dispatch 的 delta 会被判成「没有
  单写者声明」）。

## Impact

- 产品面：`scripts/team`、`scripts/lib/cmd-help.sh`（新）、`scripts/strings/{commands,help.en,help.zh}.tsv`（新）、
  `scripts/lib/cmd-project.sh`、`scripts/lib/cmd-meeting.sh`。
- 夹具面：`tests/help-surface.sh`（新）、`tests/routes.sh`（Walk A 扩面 + 语言化头部识别 + 新控制臂，10 条既有翻转
  与全部既有红侧保留）、`tests/smoke.sh`（§51 增跑）、`tests/section-paths.tsv`、必要时 `section-budgets.tsv`。
- 文档面：`references/config.md`/`workflows.md` 两个环境旋钮（英文，§18 不变量照旧）。
- 规格面：`openspec/changes/cli-help/specs/help-surface/spec.md`（7 条 ADDED）+
  `openspec/changes/cli-help/specs/dispatch/spec.md`（1 条 MODIFIED，14 条基线场景逐字保留 + 3 条新场景）。
- 兼容性：用户可见的帮助文本整体改写（语言、分级、版式），这是本变更的目的，也是升级说明要写的一条；
  机器出口、命令语义、退出码（未知 token 的 `--help` 除外）都不动。
- 排期：一个 apply 席位按 tasks 顺序做（清单与渲染器 → 三级路由 → 语言层 → 内容与概念 → 声明与探针 → 走查扩面 →
  不变量与登记），verify 由**另一席位**在独立克隆重跑全部场景与红侧。**粒度**（评审清单第 8 条）：一个 apply 能做完
  —— 「键集相等」「每个命令都有页」「第 0 级 ≤30 行」这几条不变量只在完整集合上成立，拆一半会留下必须临时放宽
  检查才能绿的中间态；若 PM 要拆，唯一不造假的拆法是「清单 + 渲染器 + 三级路由 + 菜单/组页」与「各命令页内容 +
  声明探针」，且两半都落地前不得派 verify。

## 需要 PM 裁定的点（提案按推荐版本落笔）

1. **语言从环境变量读，不落项目契约**：推荐 `TEAM_LANG`（`en`/`zh`，缺省 `en`）**只读环境变量**，
   `.pi/team/config.sh` 不加键。理由：帮助面是「什么都还没配好」时唯一能用的面（它今天就先于 `team_load_config`
   返回）；语言若只认配置，没初始化过的目录、刚装完包的机器、npm wrapper 的 `--help` 都切不了语言，一次文案偏好
   还会变成一次契约 CAS 写。代价是不持久。若 PM 要持久化，正确形态是**新增配置键 + 优先级 环境变量 > 配置 > en**
   （那是加法，不是本变更的前提）。
2. **命令清单的形态**：推荐 `commands.tsv`（结构 + 命令记录）+ `help.en.tsv`/`help.zh.tsv`（键 → 散文），由
   `lib/cmd-help.sh` 用 bash+awk 读，**不新增运行时依赖**。被否决：JSON（要 node/jq，而 `team help` 必须在没有
   node 的机器上可用）、把散文留在 heredoc（缺键检测、键集比对、逐条红侧都做不了）、复用面板的 `.ts` 表（bash
   没有 TS 加载器）。
3. **第 0 级的组清单怎么排**：推荐**紧凑清单** —— 列 0 的 `Groups` 标题 + 每组一行（`组 id + 一句用途`，缩进 2），
   命令的「组标题列 0 / 命令缩进 2」层级用在组页与 `── Start here ──` 块上。理由：30 行上限 + 走查的可归属规则
   一起排除了「每组一个 `──` 标题 + 标题下一行散文」的排法（8 组 × 2 行 + 空行 + 3–5 个命令就超过 30 行，且散文
   行在用法块里无法归属）。若 PM 认为「组标题必须顶格」重于 30 行上限，可选：把上限放到 ~40 行、每组一个 `──`
   标题并在标题下一行用 `help <组>` 条目承载体（可解析），代价是第 0 级变长 —— 这是另一个方向的取舍，请裁定。
4. **未知 token 的行为**：推荐 **exit 2 + 点名 token + 指回 `team help`**（`team help <unknown>` 与
   `team <unknown> --help` 一致），不退回第 0 级、不静默成功。理由：非帮助路径的未知子命令今天就 exit 2，
   帮助路径不该把同一个错误报成成功。代价：今天 `team frobnicate --help` 是 exit 0（全局页），本变更把它改成
   exit 2 —— 这是本变更唯一改掉的退出行为，delta 有专门场景。
5. **走查扩面写成 `dispatch` 的 MODIFIED delta**：推荐**是**（主语的扩大必须改在走查自己的要求里；基线 14 条场景
   逐字保留 + 3 条新场景）。替代方案是把「覆盖每一级」写成 `help-surface` 的新要求，放弃给 `dispatch` 写 MODIFIED
   —— 那是平行陈述，PM 的评审清单第 7 条会拦；且同一个走查会有两份合同文本。若 PM 选替代方案，本变更的
   `deltas:` 行只需 help-surface，但要在 delta 里明写「walk 的合同有意分两处陈述」。
6. **帮助面之外的中文消息**：本变更不翻译（见范围外）；迁移路线写在 design 的「未决/后续」一节。

## 新增/改写的承诺与它们的兑现（评审清单第 5、6 条的清单）

| 承诺（帮助面上的说法） | 兑现（夹具） | 红侧 |
|---|---|---|
| 三级可达、每条命令有页、组页列全 | `help-surface.sh` 分级覆盖组（dispatcher 标签 ↔ 清单 ↔ 三级渲染） | 删一条记录 → 红点名命令；组页漏一条命令 → 红 |
| 第 0 级不铺开命令列表 | 规模断言（≤30 行、用法行 3–5 条、每组一次） | 红侧 ⑥：第 0 级加一组命令行 / 超过 30 行 → 红点名 |
| `team help <命令>` ≡ `team <命令> --help` | 字节相等断言 | 两处渲染分叉 → 红 |
| `team <命令> --help` 不退回全局页 | 覆盖组 + 字节断言 | 退回菜单 → 红 |
| 未知组/命令 exit 2、点名、不写状态 | 路由组（状态指纹 + 记录器） | 走成 exit 0 → 红；执行了命令 → 指纹变 → 红 |
| 帮助路径不需要项目、不执行命令 | 路由组（无项目目录、非 git） | 读配置 → 无项目时红 |
| 每条用法行被真解析器接受（每一级） | `routes.sh` Walk A 扩面（清单工作集 + 逐级解析 + 逐旗标探针） | 页面上的坏用法行 → 红点名页与旗标（旧走查看不到） |
| 页/组页/菜单打印同一份用法片段 | 三处渲染与清单行一致 | 页面多一个清单没有的旗标 → 红 |
| 默认英文；`TEAM_LANG=zh` 切中文；非法值告警 | 语言组 | 缺省不是英文 → 红；非法值静默 → 红 |
| 缺键可见点名；两张表键集相等且值非空 | 语言组 + 键集检查 | 删一条 zh 键 → 红点名；打印空值 → 红 |
| 语言不影响 `--json`/`--print` | 机器出口组（两种语言 + 变异表三份输出字节相等） | 变异帮助表后输出变了 → 红 |
| 层级（列 0 标题 / 2 用法 / 6 说明 / 10 参数与例子 / 14 概念） | 布局组（缩进阶梯、悬挂、行宽、空组、列 0 规则） | 逐条植入 → 逐条红；把今天的平铺渲染代入 → 红 |
| 禁止 `→`、散文数字需声明、散文旗标须在用法行 | 布局组 + 声明组 | 逐条植入 → 逐条红 |
| 每个命令的效应/授权/可撤销性声明 | 声明组（封闭词表 + 逐取值探针） | 无探针取值 → 红点名；只读命令写盘 → 红；无需授权却要 `--yes` → 红 |
| 每页 12 个部分齐全有序非空；概念两种语言非空且页内复述一致 | 内容组 | 删一节 → 红点名；删一个概念键 → 红点名 |
| 四个既有规格字面量（init/add-agent/teardown/dispatch 行） | 内容不变量组 | 去掉 `--copy` 等 → 红 |

没有夹具兑现的句子不进帮助面。**机械边界**：封闭词表、数字/旗标/缩进/覆盖/键集/字节相等都能机械判；一句自由
散文的**真伪与可读性**判不了，由 PM 的提案评审与独立 verify 的读者测试承担（design 写明分工与 rubric）。

## Acceptance（apply / verify 阶段执行；本阶段只读地跑基线）

```bash
bash skills/teamsmith/tests/help-surface.sh                    # 分级覆盖/规模/键集/布局/声明/机器出口/内容
bash skills/teamsmith/tests/help-surface.sh --flip             # 逐条破坏 → 指定用例必红；还原 → 全绿
bash skills/teamsmith/tests/routes.sh                          # Walk A 扩面（每级 × 清单）+ 既有红侧与 10 条翻转
bash skills/teamsmith/tests/smoke.sh --select 51                # §51 段（含新夹具）
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/team \
  skills/teamsmith/scripts/lib/cmd-help.sh skills/teamsmith/scripts/lib/cmd-project.sh \
  skills/teamsmith/scripts/lib/cmd-meeting.sh skills/teamsmith/scripts/strings/commands.tsv \
  skills/teamsmith/scripts/strings/help.en.tsv skills/teamsmith/scripts/strings/help.zh.tsv \
  skills/teamsmith/tests/help-surface.sh skills/teamsmith/tests/routes.sh
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
```

夹具与命令的最终形态以 apply 冻结的接口为准，但**场景名与红侧方向**不得改（改了就是换合同，要重新走提案）。

## Out of scope

- 不翻译 `scripts/lib` 其余中文消息（5477 行、20 个文件）；本变更的范围是帮助面（三级菜单、每个命令的页、
  帮助里用到的概念词）。迁移路线写在 design 的「未决/后续」一节。
- 不改命令名、旗标名、既有命令的退出码、`--print`/`--json` 字节；**不引入 CLI 框架或任何新依赖**（bash + awk）。
- 不改面板的语言机制（`panel/src/strings/*` 与面板设置里的偏好是面板自己的面）。
- 不改 `references/**`、README、SKILL.md 的语言与内容（只在需要时于 `config.md` 登记两个环境旋钮）。
- 不改 Walk A 的解析器规则、条目/断言下限、非空洞控制臂与既有 10 条翻转；不用删用法行/放宽解析器的方式让
  走查变绿。
