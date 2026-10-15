# cli-help · 设计

## Context

动机与范围见 proposal。以下是本轮读到的、决定做法的基线事实（2026-10-14，本 worktree 实测）。

- **帮助面今天是两处 heredoc**：全局页在 `scripts/lib/cmd-project.sh` 的 `team_cmd_help`（98 行中文，8 个组头、
  47 条条目、47 行超 100 列、最长 169 列、5 行共 8 个 `→`）；`meeting` 另有 `cmd-meeting.sh` 的
  `team_meeting_help`（独立中文 heredoc，带 `$TEAM_PROJECT`/`team_meeting_ttl_default` 的运行时插值）。
  两处都是自由散文，没有「谁声明了这条行为」的概念，也没有层级：组头、命令、说明、参数、散文全在 2 空格这一级，
  长段落的换行顶到第 19 列、没有悬挂缩进。
- **帮助路由等于「没有路由」**：`scripts/team` 的全局参数循环把 `--root/--config/--yes` 之外的参数收进 `ARGS`，
  遇到 `-h|--help` 就把 `ARGS=(help)` 覆盖掉 —— `team <任意 token> --help` 都打印全局页并 exit 0；`CMD=help`
  时 `team_help` 忽略后续参数，所以 `team help <cmd>` 一样。帮助路径**先于** `team_load_config` 返回（本变更保住
  这条）。dispatcher 的 `case "$CMD" in` 有 **49 个标签**，去掉内部数据面 `__panel-data` 是 **48 个名字**。
- **走查今天只读一处**（`tests/routes.sh`，门禁 §51 跑它）：Walk A 用 awk 解析 `team help` 的输出 —— 块从
  `^[ \t]*──` 行开始（组头把 `lastindent` 重置为 -1），条目必须以真实命令名（TOP）开头、缩进 >0，**续行必须比
  它上面那条条目更深**（否则跳过），列 0 行一旦带 `--flag` 就是 finding，命令组用 `a|b` 展开并与
  `case "$sub" in` 导出的 SUB 表对照；每条用法行打印的旗标都要被真解析器接受，打印了旗标的命令还必须拒绝
  `--frobnicate-probe`（非空洞控制臂）；Entry ≥5 / Claim ≥10 的下限防「help 形状变了没人发现」；还有一条
  `grep -q '用法：'` 的用法头部识别。**实测覆盖面：1 个面 / 47 条用法行 / 42 个命令 / 75 条 (命令,旗标) 声明**
  （基线日志）；页面上的任何一条坏用法行它都看不到。Walk B 从 `cmd-config.sh` 的 `team_config_schema` 第 8 列注释
  导出「哪些键名点了 `team <cmd>`」，没有声明探针的键判红 —— 这是「声明出来的承诺必须有兑现」的现成口径，本变更
  的声明探针照它做，来源换成命令清单。
- **基线**：routes.sh **214 ✓ / 0 ✗**；`openspec validate --all --strict` 本 change 之前 17/17、现在 18/18；
  `spec-refs.sh --check` 0 未声明；`ledger-ban` hits=0。
- **门禁与段表**：§51 是「用法诚实性」，在 `smoke.sh` 里跑 `routes.sh`；`tests/section-paths.tsv` 决定改哪些
  路径要选哪些段（账本路径走表头 `# ledger-scan: 60 docs/team/*`）。
- **语言现状**：`scripts/lib` 5477 行含中文（20 个文件）；`references/**` 与 `SCOPE.md` 的正文由 §18 强制英文
  （CJK 只在代码 span/围栏里），**脚本树不在 §18 口径内**。面板已有 `scripts/panel/src/strings/{en,zh}.ts`
  （键集相等由 `tests/panel-strings.mjs` 断言、`stringsFor` 对未知值回退 `zh`），但面板默认 `zh`，本变更的 CLI
  面默认 `en`（用户要求），两者是各自的面。
- **产品无框架**：`package.json` 的 `dependencies` 是空的；唯一带框架的是面板（ink+react）。所以本变更走
  **数据驱动**：一份命令清单 + 一个渲染器 + 平级语言表，bash + awk 读，不新增依赖、不加构建步骤。
- **跨规格字面量**（其他规格对帮助行的期望，改帮助文本不能碰坏）：

  | 规格 | 对帮助面的字面期望 |
  |---|---|
  | `dispatch#The printed route is a route that works` | 用法行的每个旗标都被真解析器接受；打印旗标的命令拒绝未知旗标；schema 注释点名的命令有探针 |
  | `dispatch`（席位列） | `add-agent` 行打印 `--register`/`--create`/`--no-install`/`--print`、不打印 `--model`；`teardown` 行打印 `--register` |
  | `dispatch`（分支声明场景） | `dispatch` 行打印 `--branch <name>` |
  | `init-skill`（安装引导场景） | `team help` 的 `init` 行点名 `.pi/skills`、`--copy`、`--no-skills` |
  | `init-skill`（npm bin 透明性） | `team help` 经 `bin/team.mjs` 与直接跑 bash CLI **逐字节相同**（语言/宽度只能从 argv/env 解析，不能引入 cwd 依赖） |

## Goals / Non-Goals

**Goals**：把「分级、看得懂、不说谎」三件事同时变成可跑的合同：三级菜单各有覆盖面与规模上限；每页有层级与深度；
语言可切、缺键可见；每条行为声明都能追到清单的字段或一条用法行，而用法行由扩面后的走查逐条喂真解析器。
可观察边界只在本 change 的两个 delta 里定义。

**Non-Goals**：不翻译帮助面之外的 5477 行消息；不引 CLI 框架或新依赖；不改命令名/旗标名/既有退出码/
`--print`·`--json` 字节；不改 Walk A 的解析器规则与强度、不删既有红侧；不改面板语言机制；不改
`references/**`、README、SKILL.md 的语言；不新造第二个规格系统。

## Decisions

> **范围修订（2026-10-14，用户裁定 D170）**：门禁只管**逻辑**，文本类（措辞、排版、语言内容、概念定义）由设计
> 与评审把关。下面的决策里，**版式层级、第 0 级规模、页面 schema 与概念定义仍是设计决定**（渲染器照此实现、
> 评审照此读样张），但**不再有门禁断言**；`TEAM_LANG` 的门禁面只剩机制（读哪个值、怎么回退、缺键可见、机器出口
> 不受影响），两表键集是否齐全由评审核对。合同文本见 `specs/help-surface/spec.md`（三条文本类要求已删、两条已收窄）。

### 1. 三级路由：菜单 / 组页 / 命令页，未知 token exit 2

- `team`（无参）与 `team help` → 第 0 级菜单；`team help <group>` → 组页；`team help <command>` 与
  `team <command> --help`（`-h` 同）→ 命令页，两条入口走同一个渲染出口（逐字节相同、exit 0）。
- 解析位置：`scripts/team` 的全局参数循环里识别 `-h|--help` 与裸 `team`/`team help`，**在 `team_load_config`
  之前**决定渲染哪一级（帮助路径今天就不需要项目，这条要保住；npm wrapper 的透明性断言也要求帮助输出不依赖 cwd）。
- 覆盖集合 = dispatcher 的 `case "$CMD" in` 标签（走查与夹具都从源码导出，和 `routes.sh` 的 `MRI_TOPS` 同法），
  例外只有内部数据面 `__panel-data`（不出现在帮助面）。**别名**（`test`→`smoke`；`watchdog`、`watchdog-status`、
  `install-watchdog`、`uninstall-watchdog`→`pulse`）在主命令的页上以别名行说明；请求别名给主命令的页 + 别名行
  （`team test --help` 不是未知 token）。**退役名**（`merge`/`pr`/`gh`/`gl`）是 dispatcher 真的接受的名字
  （拒绝并给真实工具路线），给最小页（无旗标），不留「接受却没有页」的缝。
- 未知组/未知命令：exit 2（与非帮助路径的未知子命令同码）、点名 token、指回 `team help`，不执行任何命令、
  不写状态、不退回菜单或全局页。这是本变更唯一改掉的退出行为（今天它们打印全局页并 exit 0，见裁定点 4）。
- 两层「未知」要分开：`team help <token>` 里 token 既不是清单里的组也不是命令 → 拒绝；`team <cmd> <sub> --help`
  里的 sub 不认识 → 打印该命令的页并在页首加一行点名 sub 的拒绝行、exit 2（页有用，但错字不许被藏起来）。

### 2. 第 0 级：四个组成部分，规模是设计决定（评审把关，不设门禁断言）

菜单只给四件东西：teamsmith 是什么（2–3 句）、8 组清单（每组一行一句用途）、新手上手 3–5 个命令（每个一条用法行
+ 说明）、怎么进下一级（`team help <组>` / `team help <命令>`）。**目标是 ≤30 行、上手命令 3–5 条** —— 这是设计
决定，由评审读样张判断（D170：不数行数、不设门禁断言）。

**组清单的排法**（裁定点 3）：推荐「列 0 的 `Groups` 标题 + 每组一行（`组 id — 一句用途`，缩进 2）」，而不是
「每组一个 `──` 标题 + 标题下一行散文」。理由有两个硬约束：
① 设计上的 30 行目标：8 组 × (标题 + 一行 + 组间空行) ≈ 23 行，再加引导 3 行、`── Start here ──` + 3–5 个命令
（每个至少 2 行）与收尾行就超过 30 行；
② 走查的可归属规则（决策 4）：`──` 标题一开块，块内第一行必须能归到某个真实命令；「组 id + 一句用途」这种
散文行在块内无法归属，会（正确地）判红。把组清单放在**第一个 `──` 标题之前**（走查忽略标题之前的内容）既保住
30 行目标，又让组清单成为普通清单而不是伪命令。
命令的「组标题列 0 / 命令缩进 2」层级因此落在组页与 `── Start here ──` 块上。若 PM 认为「组标题必须顶格」重于
30 行目标，另一个可解析的排法是每组一个 `── <组> ──` 标题 + 一条 `help <组>` 条目承载用途（条目首 token 是真实
命令 `help`），代价是第 0 级 ~35–40 行。

### 3. 数据驱动：命令清单 + 两语言表 + 渲染器，bash + awk，不新增依赖

```
scripts/strings/commands.tsv     # 语言无关：组表 + 每个 dispatcher 标签一行（命令/组/用法片段/旗标/子命令/别名/
                                 #   例子/触碰面/effect/auth/undo 声明/概念引用/claim 探针 id）
scripts/strings/help.en.tsv      # 键 → 散文（英文，唯一真源）
scripts/strings/help.zh.tsv      # 键 → 散文（中文翻译；键集必须与 en 相等）
scripts/lib/cmd-help.sh          # 渲染器：读表 → 层级与折行 → 三级出口；语言/宽度解析；缺键标记
```

- 键名自带归属，便于点红与夹具删键：`group.<id>.title|purpose`、`cmd.<name>.what|when|arg.<flag>|example|read|
  write|effect|auth|undo|see`、`term.<id>.def`、`part.<id>.title`、`menu.lead`。
- TSV 一行一条；字段里禁止制表符与换行（折行由渲染器做，作者不手折）；散文里的引号/`$`/反引号不需要转义 ——
  这正是它相对 heredoc 的好处。运行时插值只走已声明的少量占位符（`{project}`、`{meeting_ttl}`），未知占位符判红。
- 被否决：JSON（要 node/jq，而 `team help` 必须在没有 node 的机器上可用）；散文留在 heredoc（缺键检测、键集比对、
  逐条红侧都做不了）；复用面板的 `.ts` 表（bash 没有 TS 加载器）；引 CLI 框架（给一个纯 bash 的 CLI 拉进 Node
  运行时或构建步骤，PM 的设计说明明确排除）。
- `meeting` 的 `team_meeting_help` 并入 `meeting` 页（同一渲染器），`team meeting help` 子命令保留并渲染同一页；
  删除第二个 heredoc，不留两个真源。

### 4. 版式：固定层级阶梯，且**能被走查认出来**

- **阶梯**（渲染器强制；D170 后由评审读样张核对，不设门禁断言）：`0` = `── <标题> ──…` 组/小节标题（组与组之间空一行），以及每个输出片段第一个
  标题之前的引导行；`2` = 命令用法行（条目）；`6` = 命令说明（悬挂块，后续行与首行同列；**用法行不与说明同行**）；
  `10` = 参数旗标列与例子块；`≥10` 的**唯一**例外是「该命令参数说明列」（同一命令的所有参数共用一个比旗标列更深的
  说明列，折行对齐到它）；`14` = 概念定义。除此之外的缩进判红。
- **宽度**：默认 100 显示格（CJK 宽字符按 2 格），`TEAM_HELP_WIDTH` 正整数覆盖，非法值一行告警后回退 100；
  **不做 TTY 自适应**（帮助输出要逐字节稳定：夹具、npm wrapper 的透明性断言、用户 diff 都受益）。宽度函数在 awk 里
  按面板 `width.ts` 的 WIDE 区间表实现（Hangul Jamo、CJK 扩展 A/统一区/兼容表意、全角形式、emoji 主区……），
  不引外部命令。折行只在词/宽字符边界切，续行**严格更深**于它续的行（不许「后半句顶回左边」）。
- **可归属规则**（本决策的证明义务，走查要在每一级读到用法块）：块从列 0 的 `──` 标题开始；块内只有条目
  （缩进 2、首 token 是 dispatcher 接受的命令名）与更深续行；其余行要么在片段的第一个标题之前，要么是无旗标的
  列 0 行（结束当前块）。所以：菜单的引导段与组清单放在第一个标题之前；页面的说明/参数/例子/概念块是**该页条目
  的更深续行**（走查跳过它们；它们里出现的旗标由评审读样张核对，D170 后不再由门禁断言）；页尾的「看完整一页用
  `team help <命令>`」这类句子放在列 0（无旗标）。
- **目标排版样例（同一命令，今天 vs 改后；逐字节）**：

  今天（`team help`，两行，实测；第二行从第 19 列起、没有悬挂缩进）：
  ```
    dispatch <a> <ID> <task-file> [--model m] [--branch <name>] [--fresh] [--allow-overflow] [--print]
                    首次按类别/override 分配新 SID，完整同任务恢复保留 model/SID；换模型必须 --fresh；--branch 声明任务分支
  ```

  改后（第 0 级菜单里的同一条，`·` 表示列号）：
  ```
  ── Start here ────────────────────────────────────────────────────────   ← 列 0
    dispatch <a> <ID> <task-file> [--model m] [--branch <name>] [--fresh] [--allow-overflow] [--print]
                                                                           ← 列 2 用法行
        Hand one brief to one seat and start (or resume) its session there. ← 列 6 说明，悬挂
  ```
  改后（第 2 级 `team help dispatch` 的页）：
  ```
  teamsmith · dispatch — hand one brief to one seat                              ← 列 0 引导（标题之前）
                                                                                 
  ── Usage ─────────────────────────────────────────────────────────────         ← 列 0 标题
    dispatch <a> <ID> <task-file> [--model m] [--branch <name>] [--fresh] [--allow-overflow] [--print]
                                                                                 ← 列 2 条目
        What it does: creates the seat's task branch, writes the assignment and starts or resumes
        that seat's session in its own worktree.                                 ← 列 6 说明块（悬挂）
        When to use it: once the brief exists and the seat is chosen; run it again with the same ID
        to continue an unfinished task.
        Arguments:
            --model m          Use this model instead of what the brief's `category:` policy picks.   ← 列 10 旗标 + 说明列
            --branch <name>    Declare the task branch this dispatch expects.
            --fresh            Start a new session instead of reopening the recorded one.
            --allow-overflow   Run even when the model's concurrency limit is reached.
            --print            Print the launch command without starting anything.
        Example:
            team dispatch dev P252 docs/team/tasks/P252-cli-help-propose.md --branch task/P252-cli-help-propose
        Reads: the brief, the contract, the board.  Writes: the board row, the seat record, the worktree.
        Side effects: starts a tmux window and a pi session.
        Authorization: no --yes (nothing shared or remote changes).
        Undo: `team teardown --agent dev` closes the window; the worktree and branch stay.
        Concepts:
            seat          One worker agent: its own tmux window and its own git worktree.             ← 列 14
            worktree      A separate checkout so two seats never write in the same files.
        See also: team resume · team review · the brief-writing guide in references/.
  ```
  差异要点：层级从「全都在 2 格」变成 0/2/6/10/14 的阶梯；用法行与说明分行；说明与参数各自悬挂；例子单独成块；
  `→` 链拆成短句（「写完 X，再写 Y」或分行列举）；没有顶到第 19 列的长尾巴。
- 目标形态（**设计决定，评审逐条读样张**；D170 后这些都不再是门禁断言）：不超宽；续行更深；不写 `→` 链；散文
  里的数字有该命令的声明；散文里的 `--flag` 在该命令用法行里；小节有序；小节非空；组非空；用法块内非标题的列 0
  行不存在；缩进落在阶梯上；`Arguments` 与 `Usage` 旗标集合相等；`Example` 里的旗标在用法行里。

- **只实现一次**（回应 PM 的实现说明，D170 后收敛）：层级与折行只有渲染器一份实现；版式阶梯与目标形态由评审
  读样张核对，门禁不再断言它们。`routes.sh` 不判版式 —— 它判的是**可归属与探针**（走查自己的合同：
  块规则、条目归属、逐旗标喂真解析器）。两者共用的「用法块从列 0 的 `──` 标题开始、块内只有条目与更深续行」
  是走查读得懂版式的**前提约定**，不是第二份版式规则。

### 5. 走查扩面：一处 47 行 → 每一级的每一页，工作集来自清单

- Walk A 的输入从「`team help` 的一段文本」变成「帮助面每一级的输出 + 命令清单」：
  ① **清单工作集**：读 `commands.tsv` 的每一行（命令、组、用法片段、旗标、例子），for 每个命令断言它的页存在、
  它的用法行与清单行一致、它的每个旗标被探针判过；**清单漏掉一个 dispatcher 接受的名字 → 红点名**（覆盖度的
  反向）；同时保留今天从源码导出的 TOP/SUB 归属规则，所以「打印了却不存在」与「存在却没打印」两个方向都判。
  ② **逐级解析**：菜单、每个组页、每个命令页的输出各自喂同一个 awk 解析器（块规则同上），每条用法行逐旗标探测；
  解析出的条目/断言下限按**汇总**保持今天的口径（不低于 47 条用法行 / 75 条声明），逐级另有「这一级至少被判到
  一次」的非空洞断言。
  ③ **既有红侧一条不动**：解析器、`ENTRY ≥5`/`CLAIM ≥10`、未知旗标控制臂、10 条翻转、包含关系与沙箱约束原样保留；
  只改两处：用法头部识别认 `Usage:`/`用法：`（默认语言变英文）并补「删掉用法头部仍必须红」的控制臂；新增红侧
  「某一页的坏用法行 / 清单漏命令 / 级别没被判到」。
- **数字对比**（本变更的覆盖面账）：今天 = 1 个面 / 47 条用法行 / 42 个命令 / 75 条 (命令,旗标) 声明；改后 =
  1 个菜单 + 8 个组页 + 48 个命令页，每个 dispatcher 名字的用法行都被解析、打印出的每个旗标都被探针判过
  （组合数只增不减：页面/组页/菜单打印同一份用法片段的三个渲染点都要与清单行一致）。这是**加强**：旧走查对
  页面上的坏用法行的检出能力是 0。
- **为什么写在 `dispatch` 的 MODIFIED delta 里**（裁定点 5）：走查合同只有一个家，主语从 `team help` 扩到三级
  帮助面必须改在它自己的要求里；写成 `help-surface` 的新要求就是同一条合同的第二份文本（PM 评审清单第 7 条）。
  基线 14 条场景逐字保留，新增 3 条（第 2 级页面的坏用法行、清单漏命令、逐级都判到）。
- **为什么页面版式必须可归属**：走查要读每一级，就必须能认出级别里的用法块；决策 4 的可归属规则就是为此而定，
  它同时是走查的一条检查（页面上任何无法归属的列 0 行都会在走查里变成 finding）——这条留在门禁里，因为它是
  走查读得懂输出的**前提**，不是审美判断。

### 6. 页面架构与概念：12 个部分、页内复述定义（设计决定，评审把关）

命令页 = 引导行（`teamsmith · <命令> — <用途一句话>`）+ 条目的更深续行里的 12 个带标签部分：`Usage`、
`What it does`、`When to use it`、`Arguments`、`Example`、`Reads`/`Writes`、`Side effects`、`Authorization`、
`Undo`、`Concepts`、`See also`。每部分非空；`Arguments` 每个旗标一块、一句话；`Example` 用真实命令路径。

概念定义放在 `term.<id>.def`（两种语言都非空）：`pm`、`seat`、`worktree`、`task-branch`、`brief`、`category`、
`change`、`spec`、`gate`、`ledger`、`pulse`、`knock`、`yes`。命令行声明它用到的 `terms:`，页面的 `Concepts`
部分**复述**这些定义（与菜单同一批键、逐字节相同），单读一页也读得懂。菜单末尾也打印同一批定义。

深度标准（**全部由评审与独立 verify 的读者测试判**；D170 后页面 schema 与概念复述没有门禁断言）：一个「知道要管一个项目、会用
git/tmux、但不懂 teamsmith」的读者读完一页应能回答：这命令干什么、什么时候用它、它读什么写什么、有什么副作用、
要不要 `--yes`、能不能撤。`what`/`when` 各 1–3 句，一句话一件事。

被否决：只在菜单定义概念、各页只列术语名（单读一页仍读不懂，违背用户原话）；每页独立定义键（13 个概念 × N 页
的副本必然漂移）。

### 7. 声明与探针：封闭词表 + 注册表 + 逐条红侧；机械边界写明

| 字段 | 取值 | 探针（断言效应，不看退出码） |
|---|---|---|
| `effect` | `read-only` / `writes-<面>` / `starts-process`（面表封闭） | 只读：跑完状态指纹不变；写面：该面变了；起进程：夹具记录器里有启动 |
| `auth` | `none` / `needs-yes` / `needs-yes:<条件>` | `needs-yes`：无 `--yes` 时拒绝、点名 `--yes`、一个字不写；带 `--yes` 时继续 |
| `undo` | `idempotent` / `undo-by-<cmd>` / `not-reversible:<reason>` | `idempotent`：第二次跑状态逐字节不变；`undo-by-<cmd>`：跑它之后指纹复原；负声明不探 |

`help-surface.sh` 的声明组（D170 后的门禁面）：① 每个命令记录三类字段齐备、取值入词表（越界判红点名命令与取值）；
② **每个取值名到一条探针**，没有探针的取值判红；③ 逐条跑探针并断言效应；④ 清单的一行只渲染出它自己的那条用法行。
散文里的数字/旗标这类文本一致性检查已随 D170 移出门禁（改由评审读样张）。

**机械边界**（不假装夹具能代替判断，D170 后这条边界就是门禁的边界）：门禁判**逻辑**——封闭词表、探针效应、
覆盖度、字节相等、退出码；一句自由散文的**真伪与可读性**，以及措辞、排版层级、页面深度、概念定义的质量、
两表键是否齐全，都由设计与评审把关（PM 的提案评审、apply 报告的读者测试与样张、verify 的独立复核）。
proposal 的承诺清单写明了这条分工。

被否决：给每条散文句配探针（48 个命令 × 每页 5–10 句 → 数百条空探针）；只靠人工评审（用户要求「不许出现文档说能、
实际没做的句子」，仓库的口味是「声明必须有兑现」）。

### 8. 语言层：只读环境变量，缺键可见，机器出口不受影响

- 值 `en`（或不设/空）→ 英文；`zh` → 中文；其他值 → 一行可见告警点名该值，然后英文面，退出状态不变。
- 语言只选散文；命令路径、旗标名、用法片段、部分顺序逐字节相同（结构表语言无关）。
- 缺键不许静默（**门禁只判这条行为**）：渲染器对每个取不到的键打印含该键 id 的可搜索标记，并在另一语言有该键
  时用它的值；两表键集是否齐全由评审核对（D170：键集比对检查已从门禁删除）。
- 与面板的关系：面板的 `panel.conf` 偏好是面板自己的面，本变更不动它的默认与语义；两者将来若统一，方向是
  「配置键 → 导出 `TEAM_LANG`」（后续加法）。
- 被否决：只认配置键（帮助面必须在没有项目时可用）；认 `LANG`/`LC_ALL`（它们控制别的程序的本地化与排序，本仓库
  多处用 `LC_ALL=C` 做字节级比较，借它当产品语言会让夹具与用户互相干扰）。

### 9. 真源与语言关系

- **合同**：`openspec/specs/help-surface/spec.md` + `openspec/specs/dispatch/spec.md` 的走查要求。
- **单体真源**：`commands.tsv` 是命令/用法/旗标/声明/例子的唯一真源；`help.en.tsv` 是散文的真源，`help.zh.tsv`
  是翻译（键集齐全由评审核对、缺键渲染可见由门禁判）；页面复述概念时用同一批键的原文，不存在第二份定义。
- **深文档**：`references/**`（英文）是更长的解释；帮助页是它的**派生摘要**（`See also` 指过去）。冲突时
  references 与 spec 赢，帮助文本是缺陷。
- **README / SKILL.md**：保持英文（文档面）；本变更不动。
- **面板**：保持自己的语言机制；本变更不读不写 `panel.conf`。

### 10. 被否决的方案（汇总）

| 方案 | 否决理由 |
|---|---|
| 只重写 heredoc 文案、不加检查 | 用户要的「分级、可读、不说谎」没有兑现机制；规模、缺键、层级、声明都判不了 |
| 走查不扩面（只读 `team help`） | 页面上的坏用法行检出能力为 0；PM 的第一条追加要求明确要扩到每一级（决策 5） |
| 扩面写成 `help-surface` 的新要求 | 同一条走查合同两份文本（平行陈述），PM 评审清单第 7 条会拦（决策 5） |
| 第 0 级每组一个 `──` 标题 + 一行散文 | 30 行上限放不下，且散文行在用法块里无法归属（决策 2） |
| 每页独立定义键 | 13 个概念 × N 页的副本必然漂移（决策 6） |
| 逐条散文配探针 | 数百条空探针，成本高、证明力低（决策 7） |
| JSON 表 / 面板 TS 表复用 / CLI 框架 | 引入依赖或构建步骤（决策 3） |
| TTY 宽度自适应 | 输出不再逐字节稳定（决策 4） |
| 每 settle 都重渲染的缓存层 | 帮助是冷路径，缓存只会多一处状态（不必要） |

## Risks / Trade-offs

- **第 0 级的 30 行上限与 8 组 + 3–5 个命令的张力** → 决策 2 的紧凑组清单；若 PM 要「组标题顶格」，代价是放宽
  上限到 ~40 行（裁定点 3）。
- **页面变长**（12 部分 + 概念复述）→ 折行与 `TEAM_HELP_WIDTH` 让窄终端可用；`Concepts` 只复述该页声明的概念
  （3–6 条）。若用户嫌长，第一刀是「概念块只在菜单打印」—— 那会牺牲单页可读性，改之前问用户。
- **翻译漂移**：键集相等只保证结构，不保证语义同步 → 英文是源；apply/verify 的读者测试要读**中文**面一次
  （verify 清单里写明）。
- **走查变慢**：逐级解析 + 逐旗标探测 ≈ 57 个片段（现在是 1 个）→ 探测结果按 (命令,旗标) 去重、页面渲染一次
  喂一次解析器；夹具的沙箱与超时不变。若成本过高，先在 `TEAM_SMOKE_FAST=1` 下只跑清单工作集与逐级解析、
  全量才逐旗标探测（可见的 SKIP，不许静默）。
- **散文真伪仍是人判**：proposal 的承诺清单写明了分工；机械边界见决策 7。
- **`TEAM_LANG` 与面板默认不同**（CLI 默认 en、面板默认 zh）→ 刻意；后续统一走配置键。
- **升级即换脸**：老用户升级后 `team help` 变英文、分级、版式重排 → 写进版本说明；`TEAM_LANG=zh` 是一行回退。

## Migration Plan

无数据迁移。发布顺序：`openspec validate --all --strict` → 投影归档自证 → 相关段（§51、§18、§19、§60）+
全量门禁 → 合入 → 版本说明写「帮助面默认英文、三级菜单、`TEAM_LANG=zh` 切换、版式重排」→ 发布（npm）。
回退：`TEAM_LANG=zh` 只是语言；整面回退是 revert 本变更的提交（帮助面不写任何持久状态，回退无残留）。

## Open Questions / 未决（可以在不改变本变更的合同与任务切分的前提下后答）

1. **帮助面之外的中文消息迁移路线**（本变更不做）：同一套键表 + 渲染器先覆盖最常被读到的少数拒绝/告警
   （`team_usage_die` 的用法行、`team_allow_write` 的授权拒绝、`dispatch` 的头部拒绝、`doctor` 的前提失败行），
   每条迁移配一条「两种语言都打印且语义等价」的夹具；机器可解析的 token（路径、键名、ID、退出码）永不翻译；
   英文默认与 `TEAM_LANG` 语义沿用本变更。分步走，不设期限。
2. **配置键持久化**（`TEAM_LANG` 落 `.pi/team/config.sh`，优先级 环境变量 > 配置 > en）：等真有用户要
   「这个项目默认中文」再加；加时要在 `cmd-config.sh` 的 schema 里给注释并给 Walk B 写一条承诺探针。
3. **TTY 宽度自适应**：现在是刻意的确定性输出；日后要的话写成 `TEAM_HELP_WIDTH=auto` 的显式值，而不是默认。
4. **子命令页**（`team <cmd> <sub> --help` 只讲该子命令）：本变更只做到「父页里逐条讲子命令」；是否需要子页取决于
   用户查询习惯，另开变更。
5. **与面板语言的统一**：见风险一节。
