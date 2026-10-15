# help-robustness · 设计

## Context

`cli-help` 已交付并复验通过（`docs/team/reviews/V38.md`）。本变更只做它留下的收尾：一条行为缺陷（O1）、两处
合同/断言缺口（O2、O6）、一条同类文案缺口（O7）、两条证据缺口（G4、G3）。以下是本轮读到的、决定做法的基线
事实（2026-10-15，本 worktree 实测）。

- **O1 的机制是确定的，不是猜测**。渲染器量显示宽度只有一条路：`team_help_char_width` 用 bash `case` 的
  `$'\uXXXX'` 括号区间把字符分成 0/1/2 格，`team_help_cells` 用 `${s:i:1}` 逐「字符」累加，`team_help_wrap` 用
  同一对函数折行。两者都随 locale 变。实测（直接 source `scripts/lib/cmd-help.sh` 跑真函数）：

  | 探针 | `LC_ALL=C` | `LC_ALL=C.UTF-8` |
  |---|---|---|
  | `team_help_cells "中文宽字符"` | 15 | 10 |
  | `team_help_cells "a—b·c"` | 8 | 5 |
  | `team_help_char_width '<'` / `'>'` / `'['` | 0 / 0 / 0 | 1 / 1 / 1 |
  | `team_help_char_width '中'` | 1 | 2 |
  | `printf '%s' $'\u0300' \| od -An -tx1` | `5c7530333030`（字面 `\u0300`） | `cc80` |

  非 UTF-8 locale 下 bash 不把 `$'\uXXXX'` 编成码点，端点退化成字面字符：`[\u0300-\u036f]` 的括号集合里因此
  出现 `0`–`\` 这个 ASCII 区间（吞掉数字、大写字母、`<`、`>`、`[`），而 `${s:i:1}` 按字节切片。端到端后果
  （`TEAM_LANG=en`，同一棵树）：

  | 页面 | `LC_ALL=C` | `LC_ALL=C.UTF-8` |
  |---|---|---|
  | `team help` | 25 行 / 最长 106 格 / 3 行越 100 | 26 行 / 100 格 / 0 行越界 |
  | `team help dispatch` | 41 行 / 106 格 / 11 行越界 | 43 行 / 100 格 / 0 |
  | `team help meeting` | 46 行 / 120 格 / 6 行越界 | 47 行 / 100 格 / 0 |
  | `TEAM_LANG=zh team help dispatch` | 41 行 / **不是合法 UTF-8**（字节 555 处截断汉字） | 36 行 / 100 格 / 合法 |

  越界的原因也量到了：`team_help_wrap` 折行时把 `<a>`、`<ID>` 量成 1、0 格（`<`/`>` 宽度为 0），于是
  `dispatch <a> <ID> …` 这条 104 格的用法行被判成「不超过 98」而不折。**这是行为缺陷**（同一输入两种输出、
  中文面输出不是合法 UTF-8），不是版式口味。

- **O2 的事实**：`scripts/team` 的 `case "$CMD" in` 里有**两个** `__` 前缀标签 —— `__inbox-write`（注释
  「内部：notify 扩展的收件箱写入口（合并 + 明细；不进 help）」）与 `__panel-data`（「内部：panel.js 的数据源
  （不出现在 help 里）」）。合同文字（`specs/help-surface/spec.md` 与 `cli-help/design.md`）只写 `__panel-data`
  一个例外；V38 的旧夹具用字面排除 `panel-data`，于是把 `inbox-write` 判成「dispatcher 接受但清单没记录」而红
  （V38 §6.3）。新夹具按 `__` 前缀排除后 49 个标签双向对账全绿，但**封闭清单没有进合同**。

- **O6 的事实**：`help-surface.sh` 的 `coverage` 组今天有 9 条断言（V38 §6.1：从 10 条收窄到 9 条），少的那条
  是「每个命令都能从菜单经组页在三级内到达」。V38 的变异是干净的反证：清单删 `group versions`（命令仍声明它）
  → `✓21 ✗0 rc=0`；只让菜单渲染器漏印一个分组 → `✓21 ✗0 rc=0`。今天树上没有实际缺陷，缺的是断言。

- **O6 的「卫生」半条**（**未纳入本变更**，见裁定点 4）：`--select layout` 今天打印
  `help-surface.sh: line 1104: check_layout: command not found` 后 **rc=0（✓0 ✗0）**；`--select nosuchsection`
  同样 rc=0 —— 选段名拼错或过期就静默全绿。

- **O7 的事实**：`scripts/lib/cmd-config.sh` 的 `team_config_write_checked_unlocked` 对 `refuse` 类键写
  `team_err "$key 是只读键，控制台不改它"`，下一行 `team_dim` 打 schema 第 8 列（`项目身份：只能改项目配置文件
  .pi/team/config.sh 里的这一行；…` —— **路线其实已经点名了**）；未知键的提示写
  `自定义键请手改 $path`。`tests/config-cli.sh` 的 `validate` 组（§51 跑它）今天**把黑话当合同**：
  `case "$err" in *"只读"*) ok "refuse 的报错点名只读"`。同族的拒绝语共六条（退休键 / 未知键 / refuse 类 /
  值不合法 / 危险值 / 指纹冲突），本轮逐条读过，含用户点名词的是「只读键」「控制台」「手改」。

- **G4 的事实**：`team_help_subst` 只替换 `{project}` 与 `{meeting_ttl}`；`{token}`/`{sub}`/`{cmd}`/`{effect}`/
  `{faces}`/`{undo_cmd}` 由调用方替换。未声明的 `{…}` **原样打印**，没有任何检查。`cli-help` 的 tasks 1.4 却写着
  「未知占位符判红」——行为的一半（只解析已声明的）在，判红的一半不在，红侧也不在。

- **G3 的事实**：`tests/spec-refs.sh --check` 在本轮实测 `judged 111 reference(s) (49 distinct) … undeclared 0`，
  rc=0；`cli-help` 的报告与 V38 里都没有它的 rc。

- **门禁与段表**：§51 是「用法诚实性」，跑 `routes.sh` + `help-surface.sh` + `config-cli.sh list validate roster`；
  §51 的路径表是 `tests/routes.sh tests/config-cli.sh scripts/lib/cmd-help.sh scripts/strings/*
  tests/help-surface.sh` —— **不含 `scripts/lib/cmd-config.sh`**。实测
  `section-select.sh --paths scripts/lib/cmd-config.sh` 选出 `7b,11h,14b,15c,18b,26,27,28,38,55,56`，不含 §51。

- **本轮基线（未改动的树，实测）**：`openspec validate --all --strict` = 22/0 rc=0；`spec-refs.sh --check` = rc=0；
  `help-surface.sh --select coverage,lang,invariants,route` = ✓28 ✗0 rc=0。

- **归档状态（重要）**：任务书的 `deps:` 写「`cli-help` 已归档」，事实是**磁盘上已归档、git 里未提交**：本分支
  （起点 = main 的 tip）里 `openspec/specs/help-surface/spec.md` **不存在**，`openspec/changes/cli-help/` 仍是活动
  变更；PM 的工作树里有 43 条未提交改动（四份 `archive/2026-10-15-*/`、`openspec/specs/help-surface/spec.md` 与
  三条 `openspec/specs/*` 的修改、四个活动 change 目录的删除）。本 delta 的 MODIFIED 标题与基线文本按**归档投影
  后的那份**写；核对方法见决策 8。

## Goals / Non-Goals

**Goals**：把四条缺口变成可跑的合同 —— 宽度计算与 locale 无关（行为）、内部入口的集合封闭且双向对账（结构）、
可达性由清单判而不是由「渲染出来碰巧有」判（结构）、未声明的占位符判红（声明纪律）；O7 的措辞改成普通话，判据
换成行为。全部是逻辑类断言。

**Non-Goals**：不恢复 D170 移出门禁的 `layout`/`scale`/`content` 三组（缩进阶梯、页面深度、第 0 级行数、小节
顺序、措辞、语言表键集比对）；不改命令/旗标/退出码/机器出口字节；不翻译 `scripts/lib` 其余中文消息；不改
`references/**`、README、SKILL.md、面板与语言表内容；不引新依赖；不给 O7 补规格文字（见决策 5）。

## Decisions

### 1. O1：宽度计算从 locale 里拿出来，合同只判「同一输入同一输出 + 行宽上界」

**做法**：渲染器不再借 locale 做任何字符语义 —— 显式解码 UTF-8 字节到码点，按**码点数值区间**判 0/1/2 格，
折行也按码点边界切。取字节的路径必须**本身与 locale 无关**：`${#s}`/`${s:i:1}` 在 UTF-8 locale 下按字符、在
C 下按字节，正是要消灭的东西；用一次 `LC_ALL=C printf '%s' "$s" | od -An -tu1` 把整串的字节拿到（这条管道的
输出只取决于输入字节），再在 bash 算术里解码与判宽。`od` 每次字符串调用一次（今天反而是每字符一次命令替换），
所以这个改动同时把渲染器的常数项降下来。

**被否决的方案**：

- **脚本内 `export LC_ALL=C.UTF-8`**：把行为押在一个可能不存在的 locale 上（最小容器、musl、某些 CI 只有
  `C`/`POSIX`），而且仍然是「交给 locale 决定」；`C.UTF-8` 缺失时输出又变回去，违反任务书的「不依赖 locale 行为」。
- **`wcwidth(3)` / `wc -L` / `awk` 的 `length()`**：同一类问题，且可用性不保证。
- **保留 `${s:i:1}`，只把区间表换成算术比较**：不够 —— 切片本身就是字节/字符歧义，宽字符会被切成半个。

**合同文本**（`specs/help-surface/spec.md` 的 ADDED 要求）：同一棵树、同一 `TEAM_LANG`/`TEAM_HELP_WIDTH` 下，
菜单/组页/命令页在 `LC_ALL=C` 与 `LC_ALL=C.UTF-8`（或 `en_US.UTF-8`）下**逐字节相同**；每行不超过
`TEAM_HELP_WIDTH` 显示格；输出在任何 locale 下都是合法 UTF-8。计数由**夹具自己的** locale 无关实现给出
（推荐 python3 的 `unicodedata.east_asian_width`，与渲染器无共享代码；夹具已经在用 python3），**不许调用渲染器的
函数**——否则是自证。

**与 D170 的界线**：这条是行为（同一输入在不同 locale 下输出相同），不是措辞/版式口味；`TEAM_HELP_WIDTH` 是有
文档的机制旋钮（`references/workflows.md`：「the width the surface wraps to, in display cells (a CJK-wide
character counts two)」），「每行不超过它」是这个旋钮的定义。**不新增**缩进阶梯、页面深度、行数、小节顺序、
措辞这类断言。

**红侧**：把宽度计算换回 locale 依赖（即今天的 `team_help_char_width`/`team_help_cells`）→ 新断言必红并点名页与行。

### 2. O2：内部入口是「`__` 前缀」这个封闭集合，不是点名一个例外

**做法**：夹具声明封闭清单（`INTERNAL_ENTRIES="__inbox-write __panel-data"`，一处），三条断言：

1. **双向对账**：dispatcher（`scripts/team` 的 `case "$CMD" in` 标签）里 `^__` 的标签集合 == 声明清单。
   多一个（`__probe-x` 悄悄出现）→ 红点名它；少一个（清单里留了已删的名字）→ 红点名它。
2. **不上帮助面**：菜单、每个组页、每个命令页的输出里**不得出现**清单里的任何名字。
3. **不进清单**：`commands.tsv` 的命令名不得以 `__` 开头。

**为什么用前缀而不是点名两个**：源码的约定本来就是「`__` 前缀 = 内部」（两条注释都这么写），V38 §6.3 的结论也
是「按约定前缀，对未加 `__` 的新标签照旧判红」。用前缀，第三个内部入口一出现就会被抓；点名两个则只抓这两个。

**红侧**：`flip_case` 在 scratch 树的 `scripts/team` 里加一个 `__probe-x)` 标签 → 红点名 `__probe-x`；
`flip_case` 在 scratch 树的 `tests/help-surface.sh` 里从声明清单删一项 → 红点名那一项。

### 3. O6：可达性从清单判，finding 点名组与它变成不可达的命令

**做法**：`coverage` 组新增一条判据，从清单出发而不是从渲染结果出发：

- 菜单的**引导段**（第一个 `──` 标题之前的列 2 行）里，每行的第一个 token 就是它点名的组 id；
  该集合 SHALL **等于**清单的 `group` 行集合（双向：菜单多一组、少一组都红）。
- 对清单里每个命令：它的组必须是已声明的组、必须出现在菜单的组集合里、`team help <组>` 必须渲染出一个列出它
  的组页、它必须有页。任一不成立 → finding **点名那个组和它变成不可达的命令**。

这样「入口 → 组页 → 命令页」三级路径的每一环都有断言：菜单点名（新）、组页列出（既有「组页用法行逐条等于
清单」）、命令有页（既有）。既有 9 条一条不动。

**红侧**（两条，都不依赖写死的样本）：`flip_case` 删清单里一条 `group` 行（命令仍声明它）→ 红点名那些命令；
`flip_case` 让菜单渲染器的组循环跳过一个已声明的组 → 红点名该组命令。还原 → 全绿。

**未纳入的「卫生」半条**：`--select <未知或已删的名字>` 今天静默 rc=0。它不是帮助面的合同，所以本变更不写进
delta；见裁定点 4。

### 4. G4：占位符集合封闭，未声明的 token 不打印而是判红

**做法**：渲染器把占位符集合在一处声明（`{project}`、`{meeting_ttl}`，以及调用方替换的 `{token}`、`{sub}`、
`{cmd}`、`{effect}`、`{faces}`、`{undo_cmd}`），`team_help_load` 读清单与两张语言表时扫 `{…}` 形状的 token：

- 集合外的 token → 渲染**非零退出**，消息点名 token 与它来自哪张表/哪个字段，**不打印**那一页；
- 声明了而树里不再用的占位符 → 同样红（两个方向都判，避免声明表变成死条目）。

**红侧**：`flip_case` 给 `help.en.tsv` 某个值加 `{undeclared}` → 渲染非零并点名；`flip_case` 把渲染器里的检查
删掉 → 夹具的 G4 守卫（它自己在 scratch 副本里放一个未声明 token，断言渲染失败）必红。这就是任务书要的
「破坏 → 红 → 还原 → 绿」。

### 5. O7：改措辞、换判据，但不给它写规格文字

**做法**：`refuse` 类键的拒绝语改成普通话（例如「这个键只能改项目配置文件 `.pi/team/config.sh`，控制台不能改」），
同批扫同族提示（未知键提示的「手改」）。`tests/config-cli.sh` 的 needle 从 `*"只读"*` 换成行为 needle：退出码
仍是 5、提示里含 `.pi/team/config.sh`、契约文件 sha 未变（后两条一条新增、一条已有）。

**为什么不写 delta 文字**：它要保的行为已经活在规格里 ——
`panel#The console shows the project contract with its effect class, and refuses what it must not change` 要求
`refuse` 行的交互「surface the owning command's refusal, which names the right route (hand-editing the file,
`team add-agent`, …)」；控制台只能照 CLI 的原文显示，所以「CLI 的拒绝点名路线」这条合同已经存在。剩下的就是
**措辞**，而 D170 明说措辞由设计与评审把关。给措辞补一条门禁要求，正好是把 D170 要拿出门禁的东西再请回来。
若 PM 要它成为规格文字，正确的落点是 `panel`（那条路线合同的家），本变更的 `deltas:` 行再加一项 —— 见裁定点 2。

**边界**：这两条路径（`scripts/lib/cmd-config.sh`、`tests/config-cli.sh`）不在任务书的边界里，见裁定点 2；
`cmd-config.sh` 的改动还有一个门禁覆盖问题，见裁定点 3。

**红侧**：`config-cli.sh` 的 `TEAM_CONFIG_TREE` flip 形态（该文件已有 `flip-shape`/`groups-flip` 两个同形段）：
scratch 树里把 `refuse` 分支改成放行 → `validate` 段红并点名；还原 → 绿。

### 6. 本变更的不变量（D170 与「不许削弱」）

**只加逻辑类断言**，共五条：locale 逐字节相同、行宽上界、内部集合双向对账、可达性（菜单 ↔ 清单 ↔ 组页 ↔ 命令页）、
未声明占位符判红。**不加**：缩进阶梯/悬挂缩进/页面深度/第 0 级行数/小节顺序/措辞/语言表键集相等/中文标点——
这些按 D170 留在设计与评审。

**一条不动**：`routes.sh` Walk A 的解析器规则、工作集来源（清单）与 `ENTRY`/`CLAIM` 下限；承诺探针（`effect`/
`auth`/`undo` 的逐值探针）与控制臂；`help-surface.sh` 既有 9+ 条 coverage 断言、`lang` 机制、`claims`、
`invariants`、`route` 与全部既有翻转。新增红侧与既有翻转一起在 `--flip` 里跑，`--flip` 必须全绿。

### 7. 任务切分

一个 apply 席位按 tasks 顺序做：O1（渲染器 + locale 组）→ O2/O6（coverage 组两条）→ G4（渲染器 + 守卫）→
O7（若 PM 授权）→ 登记与验收。这四条互相独立（各自文件、各自红侧），**可以**拆给不同席位；但 O1 与 G4 都改
`cmd-help.sh`，同一席位列上串行做，或按文件分给两个席位时错开提交顺序（delta 单写者规则只管 delta 文件）。

### 8. 归档基线：本 delta 按「归档投影后的文本」写，PM 需先把归档提交到 main

本分支里 `openspec/specs/help-surface/spec.md` 不存在（`cli-help` 的归档在 PM 的工作树里**未提交**）。本 delta 的
两条 MODIFIED 用**投影后**的标题与基线文本（`### Requirement: The help surface is a level-0 menu, a page per group
and a page per command`、`### Requirement: Every behaviour a help page states is declared and probed`），核对方法：

```bash
cp -a openspec /tmp/<x>/openspec
( cd /tmp/<x>/openspec && openspec validate --all --strict && openspec archive -y cli-help && openspec validate --all --strict )
grep -n '^### Requirement:' /tmp/<x>/openspec/specs/help-surface/spec.md   # 四条标题与 delta 逐字一致
```

`openspec validate --all --strict` 今天在本分支上是绿的（22/0），因为它只做 delta 自身的结构校验，**不核对
MODIFIED 的基线是否存在**（本轮实测：一个指向不存在能力的 MODIFIED 也 rc=0）。所以「validate 绿」不能替代
「归档已提交」；apply 之前 PM 必须把归档落到 main，否则归档本变更时替换不到基线要求。

## Risks / Trade-offs

- **`od` 的可用性**：coreutils 的 `od` 在门禁容器与目标机器上都在（今天的夹具与脚本已大量用 `od`/`awk`）。
  若 PM 不接受新增的外部命令调用，等价替代是「一次 `LC_ALL=C` 的 awk 解码器」——合同不变，只是实现选择。
- **行宽上界的门禁含义**：它会让「故意加长一行」变红。这是宽度旋钮的定义，不是版式口味；若 PM 判它属 D170，
  最小形态是只留「两 locale 逐字节相同 + 合法 UTF-8」（见裁定点 5）。
- **占位符检查的误报**：扫描形状要窄（`{` + 小写标识符 + `}`），别把散文里合法的花括号当占位符；新增的表
  字段若真需要新占位符，必须显式加进声明集合（这正是这条纪律要的）。
- **O6 的菜单解析**：判据依赖「组清单在第一个 `──` 标题之前、列 2」这个版式事实（`cli-help` design 决策 2）。
  版式本身是设计决定（D170 不设门禁），但**这条判据只依赖它读得到组 id**；若将来版式改到别处，判据要跟着改
  （这比「没有判据」好，也比「判措辞」稳）。
- **O7 的边界**：若 PM 不授权 `cmd-config.sh`/`config-cli.sh`，O7 只能拆出，本变更范围缩到 O1/O2/O6/G4/G3。

## Migration Plan

- 无数据迁移。`TEAM_HELP_WIDTH`/`TEAM_LANG` 的语义与默认值不变；唯一的行为变化是非 UTF-8 locale 下的输出
  会**变得和 UTF-8 locale 一样**（今天那些越界/半个汉字的输出是缺陷，不是兼容面）。
- O7 的措辞变化会改 CLI 错误文本；`config-cli.sh` 的 needle 同批换掉，避免门禁把旧措辞当合同。

## Open Questions / 未决（交给 PM，见 proposal 的「需要 PM 裁定的点」）

1. `cli-help` 归档提交的落点（apply 的前置条件）。
2. O7 的两条路径是否加进边界（推荐加），以及 O7 是否要补规格文字（推荐不补）。
3. §51 的路径表是否补 `scripts/lib/cmd-config.sh`（推荐补，附 `section-select.sh --paths` 的复核命令）。
4. O6 的「选段名静默通过」卫生半条是否顺手收（推荐收，但不在本变更的 delta 里）。
5. O1 的「每行 ≤ `TEAM_HELP_WIDTH`」是否保留为门禁断言（推荐保留）。
