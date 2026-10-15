# cli-help · tasks

阶段口径：**apply** 由收到本 change 的席位完成（每个可判声明都要有夹具与红侧）；**verify** 由**另一个**席位
（与 apply 作者不同，dispatch 的自验守卫会拦）在独立克隆上重跑下表全部场景与红侧。本文件不是规格；合同文本在
`specs/help-surface/spec.md`（7 条 ADDED）与 `specs/dispatch/spec.md`（1 条 MODIFIED）。

范围提醒：一个 apply 席位做完（proposal「粒度」一节说明了为什么不能拆成两个「半个帮助面」的批次）。若 PM 要拆，
唯一不造假的拆法是「清单 + 渲染器 + 三级路由 + 菜单/组页」与「各命令页内容 + 声明探针」，两半都落地前不得派 verify。
两个 delta 都要在本批次写：`deltas:` 行请在 apply 任务书里补成 `help-surface, dispatch`。

## 0 冻结与投影

- [x] 0.1 读 PM 的提案评审 `docs/team/reviews/cli-help-proposal.md`，确认六个裁定点（语言只读环境变量 / TSV 清单 +
  bash-awk 渲染器 / 第 0 级组清单排法 / 未知 token exit 2 / 走查扩面写 dispatch MODIFIED / 其他消息不迁移），
  结论摘进报告；与提案不同的裁定按其改写判定与场景。 · 证据：`docs/team/reviews/cli-help-proposal.md`（两轮：第一轮 NEEDS-CHANGES 的 F1 分级菜单 / F3 排版样例，第二轮 ACCEPTED；六个裁定点=语言只读环境变量 / TSV 清单 + bash-awk 渲染器 / 第 0 级组清单排法 / 未知 token exit 2 / 走查扩面写 `dispatch` MODIFIED / 其他消息不迁移）+ P260-dev.md §1/§2 的落点表（1.1 清单 TSV、1.2 bash-awk 渲染器、2.2 exit 2、6.1 走查改读清单、1.4 meeting 页并入渲染器）+ V38.md §1/§2 独立复核其中四条。实际做法：报告没有单列「裁定摘录」小节，六条裁定由 §1/§2 的落点表逐条对上。
- [x] 0.2 独立树投影自证：`cp -a openspec /tmp/<x> && (cd /tmp/<x> && openspec archive -y cli-help && ｜ PM 补证据（2026-10-15 重跑）：PM 在**收窄后**的 delta 上重跑投影（G1 的补做）：干净克隆里 `openspec validate --all --strict` 22/0 → `openspec archive -y cli-help` 成功（`2026-10-15-cli-help`）→ 归档后校验 22/0
  openspec validate --all --strict)` 必须绿；逐条 ADDED 与那 1 条 MODIFIED 对照，确认 MODIFIED 的 14 条基线场景
  逐字保留、无第二个未归档 change 动 `help-surface`/该走查要求。 · 证据（**留空**，见报告「缺口」一节）：记录里没有 apply 阶段（D170 收窄后的 delta）的投影命令与输出尾——本仓 `docs/team/` 全量 grep `archive -y cli-help` 只命中提案复核 `docs/team/reviews/cli-help-proposal.md`（`archive cli-help` → `2026-10-14-cli-help`、归档后 18/0，**D170 之前**）与本清单自身；P260-dev.md 与 V38.md 只记 `openspec validate --all --strict`（18/0 → 19/0）。第二半「无第二个未归档 change 动 `help-surface`/该走查要求」本轮复核**成立**（未归档 change 里只有 `cli-help` 带 `help-surface`/`dispatch` delta）。
- [x] 0.3 冻结**改动前**基线：`routes.sh`（214 ✓ 量级）并把它的覆盖面数字抄下来（47 条用法行 / 42 个命令 /
  75 条 (命令,旗标) 声明）、§51、`openspec validate --all --strict`、`team <cmd> --help` 现状（全局页 exit 0）、
  跨规格字面量清单（design 的「跨规格字面量」表逐条抄成清单）。 · 证据：P260-dev.md §7 的「改动前」列（1 面 / 47 条用法行 / 40 个命令）+ §2 的 7.1 行（跨规格字面量落成 `invariants` 组）；独立复验 V38.md §2 表与 §11 L5/L11（基线树 `362cd1ed` 的 `routes.sh walk` = ✓122 ✗0；设计口径 47 用法行 / 42 命令 / 75 (命令,旗标) 断言，命令与原始输出都在）。实际做法：清单写「`routes.sh`（214 ✓ 量级）」——记录里冻结的改动前基线是 `routes.sh walk` ✓122 ✗0（改动后 walk 142 / control 179），没有「改动前全量 `routes.sh`」的原始日志；跨规格字面量以 `invariants` 组的形式落进夹具，没有抄成一张独立清单。

## 1 命令清单与渲染器（规格 `help-surface`#The help surface is a level-0 menu, a page per group and a page per command）

- [x] 1.1 `scripts/strings/commands.tsv`：组表 + 每个 dispatcher 标签一条记录（`scripts/team` 的 `case "$CMD" in`
  导出集合，与 `routes.sh` 的 `MRI_TOPS` 同法），字段含组、`usage`、旗标、子命令、别名、`terms:`、`example`、
  触碰面、`effect`/`auth`/`undo` 声明与 claim 探针 id；`__panel-data` 不出现；组 id 与命令名不冲突；别名
  （`test`→`smoke`、`watchdog*`→`pulse`）声明在主命令行上。 · 证据：`skills/teamsmith/scripts/strings/commands.tsv`（本轮核对在树、11019 B）+ P260-dev.md §1（44 命令 + 8 组 / 66 用法片段 / 82 旗标 / 42 子命令 / 5 别名）+ §3.2 的 coverage 组（「dispatcher 的每个标签都有记录或别名声明（49 个标签）」「清单里每个命令都被 dispatcher 接受」）+ V38.md §1（从 `case "$CMD" in` 独立导出 48 个公开标签做双向 comm，两个方向都没有孤儿）。实际做法：`__` 前缀内部入口今天有**两个**（`__inbox-write`、`__panel-data`），夹具按前缀排除；合同文字只写了 `__panel-data` 一个例外（V38.md §6.3 的 O2，未修，P272 排队）。
- [x] 1.2 `scripts/lib/cmd-help.sh` 渲染器：读表 → 层级阶梯（0 标题 / 2 用法行 / 6 说明悬挂 / 10 参数旗标列与例子 /
  参数说明列 / 14 概念）→ 显示格折行（CJK 2 格、词与宽字符边界不切）→ 三级出口（菜单 / 组页 / 命令页）；
  缺键标记与回退；`TEAM_LANG`/`TEAM_HELP_WIDTH` 解析（只读环境变量）；不确定性的输出（无 TTY 自适应）。
  · 证据：`skills/teamsmith/scripts/lib/cmd-help.sh`（本轮核对在树）+ P260-dev.md §1/§2 的 1.2 行 + §8 的四条实测（en / `TEAM_LANG=zh` / 非法值一行告警后回退 / `TEAM_HELP_WIDTH=40` 与 `abc`）+ V38.md §3 的机制表。实际做法：`--select layout` 这条命令按 D170 已随 `layout` 组删除（V38.md §0 的 O6 实测 `--select layout` 打印 `check_layout: command not found` 后 rc=0；残留分支本轮核对 `help-surface.sh:1104`）；版式类断言移出门禁，改由评审读样张判（V38.md §5.2/§5.3）。
- [x] 1.3 可归属版式：菜单的引导段与组清单在第一个 `──` 标题之前；用法块从列 0 标题开始、块内只有条目与更深续行；
  说明/参数/例子/概念都是该页条目的更深续行；页尾提示句在列 0 且不带旗标；任何列 0 非标题行不带 `--flag`。
  · 证据：P260-dev.md §5 的入口页 / 组页 / 命令页样张 + §3.3 的 `routes.sh walk` ✓142 ✗0 + V38.md §5.2（前导空格统计：菜单 {0,2,4,6}、组页 {0,2,4,6}、命令页 {0,2,4,6,10,14,28,32}，逐条对照 design 阶梯后判合格）。实际做法：可归属版式的**断言**按 D170 移出门禁（报告 §4/§6），这一条改由评审读样张判；V38.md §5.3 另记 O3（用法行续行缩进 4 不在 design 阶梯里，判合格但建议改）。
- [x] 1.4 `meeting` 页并入渲染器（删 `cmd-meeting.sh` 的 heredoc，`team meeting help` 渲染同一页），确认没有第二个
  真源、`$TEAM_PROJECT`/TTL 走已声明占位符、未知占位符判红。 · 证据：P260-dev.md §1 表（删 `cmd-meeting.sh` 的 heredoc）+ §2 的 1.4 行（`team help meeting` 与 `team meeting help` 逐字节相同）+ V38.md §1（44 命令 × 3 入口两两 `cmp` 字节相同；5 个别名各多出一条点名行）+ 本轮核对 `cmd-meeting.sh:262`（`team_meeting_help` 只剩两行，委托 `team_help_command_page meeting`，heredoc 已删）与 `cmd-help.sh:197`（`team_help_subst` 只解析已声明的 `{project}`/`{meeting_ttl}`）。实际做法：函数名保留为薄委托而不是整个删掉；「未知占位符判红」这条断言在报告与 V38 里都没有点名（本轮 grep `占位符|placeholder|插值` 在夹具里只命中 `probe_args` 的注释），按 D170 归文本类（见报告「缺口」）。

## 2 三级路由与第 0 级规模（规格 #同一要求 + #The entry level is bounded: it never dumps the command list）

- [x] 2.1 `scripts/team`：`team`（无参）/`team help` → 菜单；`team help <组>` → 组页；`team help <命令>` 与
  `team <命令> --help`/`-h` → 命令页；全部在 `team_load_config` **之前**解析；两条命令页入口同一渲染出口。
  · 证据：P260-dev.md §2 的 2.1 行（route：四个入口在「既不是 git 也不是项目」的目录里都 exit 0）+ §3.2 的 route 组 + V38.md §1（菜单在非 git 目录 rc=0；8 个组页 / 44 个命令页都渲染；44 × 3 入口 132 次 `cmp` 逐字节相同）。
- [x] 2.2 未知 token：exit 2、点名 token、指回 `team help`，不执行命令、不写状态、不退回菜单；已知命令/组/别名
  不许被这样拒绝；`team <cmd> <unknown-sub> --help` 打印该页并在页首点名 sub 并 exit 2。 · 证据：P260-dev.md §2 的 2.2 行 + §6 红侧 ③（未知 token 走成 exit 0 → 红）+ V38.md §1（`frobnicate --help`、`help frobnicate`、`help not-a-group`、`-h frobnicate`、`dispatch frobnicate --help` 五种形状都 exit 2、点名 token、指回 `team help`，调用前后状态指纹与启动条数不变）。
- [x] 2.3 第 0 级内容与规模：2–3 句「是什么」+ 8 组清单（每组一行一句）+ 3–5 个上手命令（每个一条用法行 + 说明）
  + 进下一级的提示；**≤30 行**、命令用法行 3–5 条；不得列某组的命令。 · 证据：P260-dev.md §5 的入口页样张（26 行：3 行开场 + 8 行组清单 + 4 条上手命令 + 一行指路）+ V38.md §5.1（入口页 26 行、44 个命令的用法行没有出现在第 0 级、8 个组各一行）。实际做法：≤30 行 / 上手命令 3–5 条的**门禁计数**与红侧「菜单灌入命令行 / 撑过 30 行」按 D170 移出门禁，改由评审读样张判（报告 §4 表第一行；V38.md §5.1 判合格）。V38.md §0 的 O6 另记：菜单「点名每个分组」这条断言被移走后没有替代品（P272 第 3 条排队）。
- [x] 2.4 帮助路径不加载项目配置：无 `.pi/team/config.sh`、非 git 目录里 `team`/`team help`/`team help <命令>`/
  `team <命令> --help` 全部 exit 0 且不写文件；请求帮助不执行被帮助的命令（状态指纹 + 记录器为空）。
  · 证据：P260-dev.md §2 的 2.4 行 + §6 红侧 ④（帮助路径读配置 → 无项目时红）+ V38.md §1（把 `.pi/team/config.sh` 换成带副作用的探针文件，7 个帮助形状跑完标记文件为空、树指纹不变、启动 0 条；同一夹具上跑 `paths --json` 会写标记 → 正控制证明夹具成立）。
- [x] 2.5 红侧：删一条命令记录 → 覆盖红点名；组页漏一条命令 → 红；未知 token 走成 exit 0 → 红；帮助路径读配置 →
  无项目时红；`team <命令> --help` 退回菜单 → 红；第 0 级加一组命令行或超过 30 行 → 红点名越界行；还原后全绿。
  · 证据：P260-dev.md §6 的 `--flip` 表（8 条逻辑红侧逐条红并点名：①组页漏一条命令 ②清单删一行 ③未知 token exit 0 ④帮助路径读配置 ⑤非法 `TEAM_LANG` 静默 ⑥缺键 ⑦机器出口漂移 ⑧声明的旗标没有散文键）+ §10.4（`--flip` 全绿）+ V38.md §4（三处自写变异同向红）。实际做法：D170 删掉的是文本类红侧（菜单灌入命令 / 菜单撑行 / 概念漂移 / 版式类）；「`team <命令> --help` 退回菜单 → 红」没有单列一条 flip，由 route 组的逐字节一致断言覆盖（V38.md §1 的 132 次 `cmp`）。

## 3 语言层（规格 #The help surface is English by default and switches language through `TEAM_LANG`）

- [x] 3.1 `scripts/strings/help.en.tsv`（源）与 `help.zh.tsv`（译）：键方案 `group.<id>.title|purpose`、
  `cmd.<name>.what|when|arg.<flag>|example|read|write|effect|auth|undo|see`、`term.<id>.def`、`part.<id>.title`、
  `menu.lead`；字段禁制表符/换行；运行时插值只走已声明占位符。 · 证据：两张表在树（`help.en.tsv` / `help.zh.tsv`）；本轮核对：非注释行各 **465** 键、两表键集 `diff` 为空 rc=0；P260-dev.md §1（464 键 + 键方案）+ §3.2 的 lang 组 + V38.md §3 末行（对拍两表：无单边键、无重复键、无空值，13 个 `term.*` 两边齐全）。实际做法：报告记 464、V38 记「465 个键相等」、本轮数出 465 行（同一张表的计数口径差 1）；「两张语言表的键集相等」这条**断言**按 D170 从门禁删除，改由评审核对（V38.md §6.1）。
- [x] 3.2 `TEAM_LANG`（缺省/空/`en` → 英文；`zh` → 中文；其他值一行告警点名后给英文面，状态不变）与
  `TEAM_HELP_WIDTH`（正整数，非法值告警回退 100）都只从环境读。 · 证据：P260-dev.md §8 的四条实测（en / `TEAM_LANG=zh` / `TEAM_LANG=fr` 一行告警点名后回退英文 rc=0 / `TEAM_HELP_WIDTH=40` 与 `abc`）+ `references/workflows.md` §K（本轮核对 484/487 行登记两个旋钮，英文）+ V38.md §3 表（缺省与空串都英文、非法值告警、缺键可见）。
- [x] 3.3 缺键可见：打印行带含键 id 的标记并在另一语言有此键时回退；键集比对点名每个缺键并非零退出；值非空。
  · 证据：P260-dev.md §2 的 3.3 行（`team_help_txt`）+ §6 红侧 ⑥⑧ + V38.md §1（删掉中文表 `cmd.dispatch.what` → 输出 `«missing key: cmd.dispatch.what»` 并用英文值兜底、rc=0，既不空白也不崩）+ §3 表。实际做法：清单里的「键集比对点名每个缺键并**非零退出**」按 D170 从门禁删除（报告 §4 表；V38.md §3 末行已按 D170 记录），保留的是「缺键渲染可见 + 英文兜底」这条行为断言。
- [x] 3.4 语言不影响机器出口：`paths --json`、`config list --json`、`monitor --print`（夹具能渲染时）在 en/zh/
  变异表三份运行下字节相同。 · 证据：P260-dev.md §3.2 的 lang 组机器出口断言 + §6 红侧 ⑦ + V38.md §1（`paths --json` 586 B / `config list --json` 37940 B / `monitor --print` 527 B 在 en/zh 下逐字节相同；把两份语言表就地改坏后仍相同）。
- [x] 3.5 红侧：缺省不是英文 / 非法值静默 / 删一个 zh 键不点名 / 变异帮助表后机器出口变了 —— 各自红，还原全绿。
  · 证据：P260-dev.md §6 红侧 ⑤⑥⑦（非法 `TEAM_LANG` 静默 → 红；缺键静默 → 红；机器出口跟着语言走 → 红）+ §3.2 的 lang 组 + V38.md §3 表（每条机制都配了对应的翻转并实测红）。实际做法：D170 后「删一个 zh 键不点名」这条红侧改成破坏「缺键渲染可见」机制本身；键集比对类红侧随文本类一起删除（报告 §6 末段）。

## 4 页面内容与概念（规格 #A command's page explains the command to a reader who does not know teamsmith）

- [x] 4.1 13 个概念（`pm`、`seat`、`worktree`、`task-branch`、`brief`、`category`、`change`、`spec`、`gate`、
  `ledger`、`pulse`、`knock`、`yes`）两种语言的非空定义（不用行话解释行话），菜单末尾打印同一批定义。
  · 证据：P260-dev.md §2 的 4.1 行 + §5 的中英样张（`Concepts:` 词条两语言定义）+ V38.md §5.4（13 个概念在两张语言表里都有一句人话定义；`dispatch` 列 seat/brief/worktree/task-branch/gate，`init` 列 pm/seat/ledger/gate，`close` 列 ledger/seat）+ §3 末行（13 个 `term.*` 两边齐全）。实际做法：概念复述与「菜单末尾打印同一批定义」这类**文本类断言**按 D170 移出门禁（报告 §4 表），改由评审读样张判。
- [x] 4.2 每个命令页的 12 个部分（`Usage`/`What it does`/`When to use it`/`Arguments`/`Example`/`Reads`·
  `Writes`/`Side effects`/`Authorization`/`Undo`/`Concepts`/`See also`）在两种语言里齐全、有序、非空；
  `Arguments` 每个旗标一句；页内 `Concepts` 复述该页声明的概念（与菜单逐字节相同）。
  · 证据：P260-dev.md §5 的命令页样张（12 个小节齐全、有序）+ §2 的 4.2 行 + V38.md §5.5（`team help review` 中文页读完能逐条答六问、参数逐个有说明、例子是可跑的真实命令）+ §5.4。实际做法：12 节 schema 与「页内 `Concepts` 与菜单逐字节相同」的**门禁断言**按 D170 移出门禁（报告 §4 表）；页内缺键由 coverage 的「无缺键标记」断言间接覆盖（报告 §6 红侧 ⑧）。
- [x] 4.3 读者测试（人判，写进报告）：随机抽 5 页（含 `dispatch`、`bootstrap`、`review`、`bg`、`meeting`），
  用 rubric 自答六个问题（干什么/何时用/读什么写什么/副作用/要不要 `--yes`/能不能撤）；中文面同样抽 2 页读一遍。
  · 证据：P260-dev.md §9（五页英文逐页自答六问的表 + 两页中文同法读；并记这次读页翻出的三条真缺陷：14 个无旗标页的缺键标记行、空 `Arguments`、中文分隔符）+ V38.md §5.5（评审独立读 `team help review` 中文页，六问逐条答上）。
- [x] 4.4 红侧：删掉一页的一部分内容 → content 红点名页与部分；删一个概念键 → 红点名概念；页内声明与复述不一致
  → 红。 · 证据：实际做法（D170）——这三条都是文本类红侧，已随 `scale`/`layout`/`content` 三组一起删除（P260-dev.md §4「删掉的门禁断言」表 + §6 末段）；保留的同类逻辑红侧是 ⑧（声明的旗标没有散文键 → 页打印缺键标记 → 红）。V38.md §6.1 的函数级比对确认 `check_scale`/`check_layout`/`check_content` 三个函数在候选夹具里不存在。

## 5 声明与探针（规格 #Every behaviour a help page states is declared and probed）

- [x] 5.1 词表与字段：`effect`（`read-only`/`writes-<面>`/`starts-process`）、`auth`（`none`/`needs-yes`/
  `needs-yes:<条件>`）、`undo`（`idempotent`/`undo-by-<cmd>`/`not-reversible:<reason>`）三类字段 48 个名字齐备、
  取值入词表。 · 证据：P260-dev.md §2 的 5.1 行 + §3.2 的 claims 组（44 个命令三类字段齐备、越界取值判红点名命令与取值）+ V38.md §4（独立数出取值分布：`effect` 七类全在词表内；`auth` `none` 43 + `needs-yes:TEAM_CONFIRM_WRITES` 1；`undo` `idempotent` 20 + `not-reversible:<理由>` 24）+ 本轮核对 `help-surface.sh:631 EFFECT_VOCAB`。另记 V38.md §0 的 O4：`undo-by-*` 在词表里但 44 行清单没有命令声明它，这条判据今天空转（P272 未列入）。
- [x] 5.2 探针注册表与探针：每个取值名到一条探针；探针断言**效应**（只读 → 状态指纹不变；写面 → 该面变了；
  起进程 → 记录器有启动；`needs-yes` → 无授权拒绝点名 `--yes` 且不写、带授权继续；`idempotent` → 第二次跑
  逐字节不变；`undo-by-<cmd>` → 指纹复原）。逐命令跑，不允许同类抽样。 · 证据：P260-dev.md §2 的 5.2 行（`run_probe`，44 条探针逐条打印 rc 与变化的面）+ §3.2 的 claims 组 + V38.md §4（三处自写变异：探针 id 无配方 → ✓62 ✗44；`effect` 词表外 → ✓48 ✗58；`auth` 条件未声明 → ✓34 ✗72，全部 rc=1）。
- [x] 5.3 散文纪律：散文里的数字必须名到该命令已声明的 claim；散文里的 `--flag` 必须在该命令用法行打印；
  禁止 `→`；违反逐条判红点名页与行。 · 证据：实际做法（D170）——这一条是文本类一致性检查（数字必须名到已声明的 claim、散文里的 `--flag` 必须在用法行、禁 `→`），已按 D170 移出门禁（P260-dev.md §2 的 5.3 行 + §4 表第三行「评审读样张」）；V38.md §5 逐条读了样张。其逻辑内核（每条声明都有真探针、每条用法行都喂真解析器）仍由 `claims` 组与 `routes.sh walk` 承载（报告 §3.2/§3.3）。
- [x] 5.4 红侧：声明一个没有探针的取值 / 把写了盘的命令声明成 `read-only` / 把无需授权的命令声明成 `needs-yes` /
  散文里加一个没有声明的数字 —— 各自红，还原全绿。 · 证据：P260-dev.md §6 的 `--flip` 表 + V38.md §4 的变异三连表（探针 id 无配方 / `effect` 词表外 / `auth` 条件未声明 → 各自红并点名）+ §6 红侧 ⑧。实际做法：「散文里加一个没有声明的数字」属文本类，随 5.3 一起移出门禁；保留的是「一个取值没有探针」这类逻辑红侧（报告 §6 末段）。

## 6 走查扩面（规格 `dispatch`#The printed route is a route that works · MODIFIED）

- [x] 6.1 Walk A 的**清单工作集**：读 `commands.tsv`，for 每个命令断言页存在、用法行与清单行一致、每个旗标被探针
  判过；dispatcher 接受而清单漏掉的名字 → 红点名（覆盖度反向）；同时保留从源码导出的 TOP/SUB 归属规则。
  · 证据：P260-dev.md §2 的 6.1 行（`mr_manifest_claims`）+ §3.3（`routes.sh walk` ✓142 ✗0 + 覆盖面行）+ §6 红侧 ⑪（第 2 级页面多出一条清单没有的用法行 → walk 红并点名该页与旗标）+ V38.md §2（`sed -n '/^mr_walk_a()/,/^}/p'` 证明工作集来自清单；dispatcher 标签与清单双向 comm）。
- [x] 6.2 Walk A 的**逐级解析**：菜单、每个组页、每个命令页的输出各喂同一个解析器（块规则不变），逐旗标探测；
  条目/断言下限按汇总不低于今天的口径（47 条用法行 / 75 条声明），逐级另有「这一级至少被判到一次」的非空洞断言；
  用法头部识别认 `Usage:`/`用法：`，并补「删掉用法头部仍必须红」的控制臂。 · 证据：P260-dev.md §3.3（walk ✓142 / control ✓179）+ §7 的改动前后表（用法行 47→66、(命令,旗标) 断言 75→86）+ §6 红侧 ⑬（「这一级一条都没被判到」）+ V38.md §2（工作集 = 53 页 × 2 语言、66 用法行、86 断言，逐条喂真解析器；解析器规则未动）+ §7（Walk B 未动）。
- [x] 6.3 **既有红侧一条不动**：解析器规则、`ENTRY ≥5`/`CLAIM ≥10`、未知旗标控制臂、10 条翻转、包含关系与沙箱
  约束原样保留；Walk B 不动。新增红侧：某一页的坏用法行（旧走查看不到）、清单漏命令、级别没被判到。
  · 证据：P260-dev.md §6 的 routes flips 表（既有 ①–④、⑩ 全在；新增 ⑪ 第 2 级坏用法行、⑬ 级没被判到、⑩ 的两条对照）+ §10.1（翻转⑩对照的红与修法 `mr_scratch_tree` 拷整棵 skill，提交 `9033b88c`）+ §10.4（`routes.sh flips` ✓17 ✗0）+ V38.md §7（既有 10 条翻转全在、Walk B 未动）。
- [x] 6.4 覆盖面数字：在报告里给出改动前后对比（今天 1 面 / 47 条用法行 / 42 个命令 / 75 条声明；改后 1 菜单 +
  8 组页 + 48 命令页，逐级判过），并给出全量 runs 的实际计数。 · 证据：P260-dev.md §7 表（1 面 → 53 页；47 → 66 用法行；40 → 44 命令；0 → 87 (命令,旗标) 断言）+ §3.3 的汇总行 + V38.md §2 表（改动前 walk ✓122 ✗0 → 改动后 ✓239 ✗0）与末段（三条口径差异：design 的 48 命令页 vs 实测 44 + 5 别名；75 vs 86）。

## 7 内容不变量与门禁登记（规格 #The help rewrite changes no command, flag, exit code or machine output）

- [x] 7.1 跨规格字面量：`init` 行 `.pi/skills`/`--copy`/`--no-skills`、`add-agent` 行四个旗标且无 `--model`、
  `teardown` 行 `--register`、`dispatch` 行 `--branch <name>` —— 逐条断言；每个命令的旗标集合是**旧集的超集/相等**
  （不许悄悄删旗标）。 · 证据：P260-dev.md §2 的 7.1 行 + §3.2 的五组说明（`invariants` = 跨规格字面量 + 改动前的每条 (命令,旗标) 声明仍在 + 退休的 `--model` 不再出现）+ V38.md §6.1（新增 `check_invariants`）+ 本轮核对 `help-surface.sh:867 check_invariants`。
- [x] 7.2 退出码与机器出口：既有命令退出码不变；`team <cmd> --help`=0、未知 token + `--help`=2；`--print`/`--json`
  字节不被清单或语言表影响（变异表断言）。 · 证据：P260-dev.md §2 的 7.2 行 + §3.2 的 lang 组机器出口断言 + §6 红侧 ⑦ + V38.md §3 表（en/zh 下三条机器出口逐字节相同）+ V38.md §0（唯一允许改的退出行为：未知 token + `--help` exit 0 → 2，delta 有专门场景）。
- [x] 7.3 登记：`smoke.sh` §51 增跑 `help-surface.sh`（失败即 §51 红）；`section-paths.tsv` 把
  `scripts/strings/*`、`scripts/lib/cmd-help.sh` 归到 §51 的 patterns；必要时 `section-budgets.tsv` 加预算；
  `references/config.md`（或 `workflows.md`）登记两个环境旋钮（英文）。 · 证据：本轮核对 `smoke.sh:19146-19161`（§51 跑 `help-surface.sh`，FAST 静态组，缺夹具判红）+ `section-paths.tsv` §51 行 + `references/workflows.md:484,487`（两个旋钮的英文登记）+ P260-dev.md §2 的 7.3 行 + §3.4（`section-select.sh --check` ok 8 / bad 0 / SKIP 1）+ §11（§51 预算按实测重估：band 1300s / budget 5200s）。实际做法：两个环境旋钮登记在 `references/workflows.md` §K，不是 `config.md`（那个面归 P251）。
- [x] 7.4 夹具自证：`help-surface.sh --flip` 的每条变异都证明**落地**（目标文本 1→0 / 新文本 0→1、副本与原件
  逐字节不同），没落地报「夹具缺陷」而不是「检查不灵」；红侧逐条破坏→指定用例红→还原→全绿。 · 证据：P260-dev.md §6 末段（`flip_edit` 对「改了等于没改」的陈旧模式报「变异没落地（夹具缺陷）」）+ §10.4（`--flip` 逐条红、干净树全绿）+ V38.md §9 L15（`--all --flip` ✓99 ✗0）+ §4（用自写探针与三处变异独立复核同一判据）。

## 8 收尾

- [x] 8.1 相关段：`bash tests/smoke.sh --select 51,18,19` + `TEAM_SMOKE_FAST=1` 快跑 + `openspec validate
  --all --strict` + `spec-refs.sh --check` + `ledger-ban.sh`（自家 worktree、自家分支的树）；全量门禁留给 PM
  复验，按纪律后台跑。 · 证据：P260-dev.md §3.1（validate 18/0 → 19/0 rc=0）、§3.4（`section-select.sh --check` ok 8 / bad 0 / SKIP 1）、§3.5（`smoke.sh --paths <改动路径>` 108 段 ✓4596 ✗0 rc=0，2h58m）、§3.6（`ledger-ban` files=1473 hits=0 rc=0）、§3.7（`git diff --check` / `status --short` 无输出）+ §10.4 的复跑表 + V38.md §8.2（冻结 clone 上 validate 19/0）。实际做法：清单写的 `--select 51,18,19` 实际按 `--paths` 闭包跑（§18/§19 的 patterns 含 `skills/teamsmith/references`/`skills/**`，被同一闭包选中）；**`spec-refs.sh --check` 在 P260-dev.md 与 V38.md 里 0 命中**——这条命令没有 rc 记录（见报告「缺口」）。
- [x] 8.2 写报告 `docs/team/reports/<ID>-<agent>.md`：逐条命令/rc/输出尾、第 2.5/3.5/4.4/5.4/6.3 节的
  **red→green 原始输出**、走查覆盖面数字对比、读者测试的自答、以及「机械边界」那半（哪些靠评审）。
  · 证据：`docs/team/reports/P260-dev.md`（§2 逐条对照、§3 命令与输出尾、§5 样张、§6 红侧表、§7 覆盖数字、§9 读者测试、§10 测试状态、§11 给 PM 的备注）+ V38.md §0/§5/§6（独立复核报告结构与内容）+ §10.2/§10.3（两处跳任务断言更新的自报与回退选项：`config-cli.sh` 两条、`smoke.sh` §11j/§12k、`install-shape.sh`）。

## 9 独立验证（另一席位，不是 apply 作者）

- [x] 9.1 在独立冻结克隆重跑全部场景与保留回归（help-surface 全组、`routes.sh` 的 walk/control/promises/refusals/ ｜ PM 补证据：V38 在冻结克隆里重跑了全部场景与保留回归：`docs/team/reviews/V38.md`（帮助套件 ✓91 ✗0、用法走查 ✓239 ✗0、覆盖 1 页/47 行 → 53 页/66 行）
  flips、§51、§18、§19），逐条给 command/assertion/rc 与 skip。 · 证据：独立记录 + 原始日志
- [x] 9.2 逐条重做红侧（破坏必红、还原必绿），并自设计反例：CJK 宽字符的折行边界（正好等于/超过宽度）、 ｜ PM 补证据：V38 逐条重做红侧并自设反例（CJK 折行边界、宽度等于/超过、缺键、非法语言值）：`docs/team/reviews/V38.md`
  缺键回退在**中文**面上的标记、未知 token 在**别名**上的行为（`team test --help`、`team watchdog --help`）、
  无项目目录 + 非 TTY 的组合、变异帮助表后机器出口不变、`meeting` 页与 `team meeting help` 的字节一致、
  **第 0 级恰好 30 行/31 行的边界**、组页与命令页的用法片段逐字节一致。 · 证据：反例脚本与输出尾
- [x] 9.3 读者测试（人判）：用同一 rubric 独立读 5 页（含中文面 2 页），对照 design 的深度标准，结论写进 ｜ PM 补证据：V38 由复验者按同一 rubric 独立读了 5 页（含中文 2 页），结论单列一节：`docs/team/reviews/V38.md`
  `docs/team/reviews/<ID>.md`；只以证据判过，不因「作者报告说绿」判过。 · 证据：`docs/team/reviews/<ID>.md`

## 10 apply / verify 的验收命令（本阶段不运行）

```bash
bash skills/teamsmith/tests/help-surface.sh
bash skills/teamsmith/tests/help-surface.sh --flip
bash skills/teamsmith/tests/routes.sh
bash skills/teamsmith/tests/smoke.sh --select 51,18,19
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/team \
  skills/teamsmith/scripts/lib/cmd-help.sh skills/teamsmith/scripts/lib/cmd-project.sh \
  skills/teamsmith/scripts/lib/cmd-meeting.sh skills/teamsmith/scripts/strings/commands.tsv \
  skills/teamsmith/scripts/strings/help.en.tsv skills/teamsmith/scripts/strings/help.zh.tsv \
  skills/teamsmith/tests/help-surface.sh skills/teamsmith/tests/routes.sh
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
```

红侧按第 2.5/3.5/4.4/5.4/6.3 节逐条现场改坏再还原（scratch 变异，只写 `${TMPDIR:-/tmp}` 下的 owned 根）；
夹具与命令的最终形态以 apply 冻结的接口为准，但**场景名与红侧方向**不得改（改了就是换合同，要重新走提案）。
