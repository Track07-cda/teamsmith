# cli-help · tasks

阶段口径：**apply** 由收到本 change 的席位完成（每个可判声明都要有夹具与红侧）；**verify** 由**另一个**席位
（与 apply 作者不同，dispatch 的自验守卫会拦）在独立克隆上重跑下表全部场景与红侧。本文件不是规格；合同文本在
`specs/help-surface/spec.md`（7 条 ADDED）与 `specs/dispatch/spec.md`（1 条 MODIFIED）。

范围提醒：一个 apply 席位做完（proposal「粒度」一节说明了为什么不能拆成两个「半个帮助面」的批次）。若 PM 要拆，
唯一不造假的拆法是「清单 + 渲染器 + 三级路由 + 菜单/组页」与「各命令页内容 + 声明探针」，两半都落地前不得派 verify。
两个 delta 都要在本批次写：`deltas:` 行请在 apply 任务书里补成 `help-surface, dispatch`。

## 0 冻结与投影

- [ ] 0.1 读 PM 的提案评审 `docs/team/reviews/cli-help-proposal.md`，确认六个裁定点（语言只读环境变量 / TSV 清单 +
  bash-awk 渲染器 / 第 0 级组清单排法 / 未知 token exit 2 / 走查扩面写 dispatch MODIFIED / 其他消息不迁移），
  结论摘进报告；与提案不同的裁定按其改写判定与场景。 · 证据：评审记录 + 报告摘录
- [ ] 0.2 独立树投影自证：`cp -a openspec /tmp/<x> && (cd /tmp/<x> && openspec archive -y cli-help &&
  openspec validate --all --strict)` 必须绿；逐条 ADDED 与那 1 条 MODIFIED 对照，确认 MODIFIED 的 14 条基线场景
  逐字保留、无第二个未归档 change 动 `help-surface`/该走查要求。 · 证据：投影命令与输出尾
- [ ] 0.3 冻结**改动前**基线：`routes.sh`（214 ✓ 量级）并把它的覆盖面数字抄下来（47 条用法行 / 42 个命令 /
  75 条 (命令,旗标) 声明）、§51、`openspec validate --all --strict`、`team <cmd> --help` 现状（全局页 exit 0）、
  跨规格字面量清单（design 的「跨规格字面量」表逐条抄成清单）。 · 证据：基线日志 + 清单

## 1 命令清单与渲染器（规格 `help-surface`#The help surface is a level-0 menu, a page per group and a page per command）

- [ ] 1.1 `scripts/strings/commands.tsv`：组表 + 每个 dispatcher 标签一条记录（`scripts/team` 的 `case "$CMD" in`
  导出集合，与 `routes.sh` 的 `MRI_TOPS` 同法），字段含组、`usage`、旗标、子命令、别名、`terms:`、`example`、
  触碰面、`effect`/`auth`/`undo` 声明与 claim 探针 id；`__panel-data` 不出现；组 id 与命令名不冲突；别名
  （`test`→`smoke`、`watchdog*`→`pulse`）声明在主命令行上。 · 证据：覆盖组的清单 ↔ 源码集合断言
- [ ] 1.2 `scripts/lib/cmd-help.sh` 渲染器：读表 → 层级阶梯（0 标题 / 2 用法行 / 6 说明悬挂 / 10 参数旗标列与例子 /
  参数说明列 / 14 概念）→ 显示格折行（CJK 2 格、词与宽字符边界不切）→ 三级出口（菜单 / 组页 / 命令页）；
  缺键标记与回退；`TEAM_LANG`/`TEAM_HELP_WIDTH` 解析（只读环境变量）；不确定性的输出（无 TTY 自适应）。
  · 证据：`bash tests/help-surface.sh --select layout`
- [ ] 1.3 可归属版式：菜单的引导段与组清单在第一个 `──` 标题之前；用法块从列 0 标题开始、块内只有条目与更深续行；
  说明/参数/例子/概念都是该页条目的更深续行；页尾提示句在列 0 且不带旗标；任何列 0 非标题行不带 `--flag`。
  · 证据：layout 组的可归属断言 + `bash tests/routes.sh walk`（下一节扩面后）
- [ ] 1.4 `meeting` 页并入渲染器（删 `cmd-meeting.sh` 的 heredoc，`team meeting help` 渲染同一页），确认没有第二个
  真源、`$TEAM_PROJECT`/TTL 走已声明占位符、未知占位符判红。 · 证据：`team meeting --help` 与 `team help meeting`
  逐字节相同 + 占位符断言

## 2 三级路由与第 0 级规模（规格 #同一要求 + #The entry level is bounded: it never dumps the command list）

- [ ] 2.1 `scripts/team`：`team`（无参）/`team help` → 菜单；`team help <组>` → 组页；`team help <命令>` 与
  `team <命令> --help`/`-h` → 命令页；全部在 `team_load_config` **之前**解析；两条命令页入口同一渲染出口。
  · 证据：`bash tests/help-surface.sh --select coverage,route`
- [ ] 2.2 未知 token：exit 2、点名 token、指回 `team help`，不执行命令、不写状态、不退回菜单；已知命令/组/别名
  不许被这样拒绝；`team <cmd> <unknown-sub> --help` 打印该页并在页首点名 sub 并 exit 2。 · 证据：route 组
- [ ] 2.3 第 0 级内容与规模：2–3 句「是什么」+ 8 组清单（每组一行一句）+ 3–5 个上手命令（每个一条用法行 + 说明）
  + 进下一级的提示；**≤30 行**、命令用法行 3–5 条；不得列某组的命令。 · 证据：规模断言（含红侧 ⑥）
- [ ] 2.4 帮助路径不加载项目配置：无 `.pi/team/config.sh`、非 git 目录里 `team`/`team help`/`team help <命令>`/
  `team <命令> --help` 全部 exit 0 且不写文件；请求帮助不执行被帮助的命令（状态指纹 + 记录器为空）。
  · 证据：route 组
- [ ] 2.5 红侧：删一条命令记录 → 覆盖红点名；组页漏一条命令 → 红；未知 token 走成 exit 0 → 红；帮助路径读配置 →
  无项目时红；`team <命令> --help` 退回菜单 → 红；第 0 级加一组命令行或超过 30 行 → 红点名越界行；还原后全绿。
  · 证据：报告里的 red→green 原始输出

## 3 语言层（规格 #The help surface is English by default and switches language through `TEAM_LANG`）

- [ ] 3.1 `scripts/strings/help.en.tsv`（源）与 `help.zh.tsv`（译）：键方案 `group.<id>.title|purpose`、
  `cmd.<name>.what|when|arg.<flag>|example|read|write|effect|auth|undo|see`、`term.<id>.def`、`part.<id>.title`、
  `menu.lead`；字段禁制表符/换行；运行时插值只走已声明占位符。 · 证据：`bash tests/help-surface.sh --select lang`
- [ ] 3.2 `TEAM_LANG`（缺省/空/`en` → 英文；`zh` → 中文；其他值一行告警点名后给英文面，状态不变）与
  `TEAM_HELP_WIDTH`（正整数，非法值告警回退 100）都只从环境读。 · 证据：lang 组
- [ ] 3.3 缺键可见：打印行带含键 id 的标记并在另一语言有此键时回退；键集比对点名每个缺键并非零退出；值非空。
  · 证据：lang 组（删一条 zh 键的 scratch 副本）
- [ ] 3.4 语言不影响机器出口：`paths --json`、`config list --json`、`monitor --print`（夹具能渲染时）在 en/zh/
  变异表三份运行下字节相同。 · 证据：lang 组的机器出口断言
- [ ] 3.5 红侧：缺省不是英文 / 非法值静默 / 删一个 zh 键不点名 / 变异帮助表后机器出口变了 —— 各自红，还原全绿。
  · 证据：red→green 原始输出

## 4 页面内容与概念（规格 #A command's page explains the command to a reader who does not know teamsmith）

- [ ] 4.1 13 个概念（`pm`、`seat`、`worktree`、`task-branch`、`brief`、`category`、`change`、`spec`、`gate`、
  `ledger`、`pulse`、`knock`、`yes`）两种语言的非空定义（不用行话解释行话），菜单末尾打印同一批定义。
  · 证据：content 组
- [ ] 4.2 每个命令页的 12 个部分（`Usage`/`What it does`/`When to use it`/`Arguments`/`Example`/`Reads`·
  `Writes`/`Side effects`/`Authorization`/`Undo`/`Concepts`/`See also`）在两种语言里齐全、有序、非空；
  `Arguments` 每个旗标一句；页内 `Concepts` 复述该页声明的概念（与菜单逐字节相同）。
  · 证据：content 组
- [ ] 4.3 读者测试（人判，写进报告）：随机抽 5 页（含 `dispatch`、`bootstrap`、`review`、`bg`、`meeting`），
  用 rubric 自答六个问题（干什么/何时用/读什么写什么/副作用/要不要 `--yes`/能不能撤）；中文面同样抽 2 页读一遍。
  · 证据：报告里的逐页自答
- [ ] 4.4 红侧：删掉一页的一部分内容 → content 红点名页与部分；删一个概念键 → 红点名概念；页内声明与复述不一致
  → 红。 · 证据：red→green 原始输出

## 5 声明与探针（规格 #Every behaviour a help page states is declared and probed）

- [ ] 5.1 词表与字段：`effect`（`read-only`/`writes-<面>`/`starts-process`）、`auth`（`none`/`needs-yes`/
  `needs-yes:<条件>`）、`undo`（`idempotent`/`undo-by-<cmd>`/`not-reversible:<reason>`）三类字段 48 个名字齐备、
  取值入词表。 · 证据：claims 组（越界判红点名命令与取值）
- [ ] 5.2 探针注册表与探针：每个取值名到一条探针；探针断言**效应**（只读 → 状态指纹不变；写面 → 该面变了；
  起进程 → 记录器有启动；`needs-yes` → 无授权拒绝点名 `--yes` 且不写、带授权继续；`idempotent` → 第二次跑
  逐字节不变；`undo-by-<cmd>` → 指纹复原）。逐命令跑，不允许同类抽样。 · 证据：claims 组
- [ ] 5.3 散文纪律：散文里的数字必须名到该命令已声明的 claim；散文里的 `--flag` 必须在该命令用法行打印；
  禁止 `→`；违反逐条判红点名页与行。 · 证据：layout 组（形态）/ claims 组（数字归属）
- [ ] 5.4 红侧：声明一个没有探针的取值 / 把写了盘的命令声明成 `read-only` / 把无需授权的命令声明成 `needs-yes` /
  散文里加一个没有声明的数字 —— 各自红，还原全绿。 · 证据：red→green 原始输出

## 6 走查扩面（规格 `dispatch`#The printed route is a route that works · MODIFIED）

- [ ] 6.1 Walk A 的**清单工作集**：读 `commands.tsv`，for 每个命令断言页存在、用法行与清单行一致、每个旗标被探针
  判过；dispatcher 接受而清单漏掉的名字 → 红点名（覆盖度反向）；同时保留从源码导出的 TOP/SUB 归属规则。
  · 证据：`bash tests/routes.sh walk` + 清单漏命令的红侧
- [ ] 6.2 Walk A 的**逐级解析**：菜单、每个组页、每个命令页的输出各喂同一个解析器（块规则不变），逐旗标探测；
  条目/断言下限按汇总不低于今天的口径（47 条用法行 / 75 条声明），逐级另有「这一级至少被判到一次」的非空洞断言；
  用法头部识别认 `Usage:`/`用法：`，并补「删掉用法头部仍必须红」的控制臂。 · 证据：`bash tests/routes.sh` 的输出尾
  （含各级的 ok 行与汇总计数）
- [ ] 6.3 **既有红侧一条不动**：解析器规则、`ENTRY ≥5`/`CLAIM ≥10`、未知旗标控制臂、10 条翻转、包含关系与沙箱
  约束原样保留；Walk B 不动。新增红侧：某一页的坏用法行（旧走查看不到）、清单漏命令、级别没被判到。
  · 证据：`bash tests/routes.sh flips` + 三条新红侧的原始输出
- [ ] 6.4 覆盖面数字：在报告里给出改动前后对比（今天 1 面 / 47 条用法行 / 42 个命令 / 75 条声明；改后 1 菜单 +
  8 组页 + 48 命令页，逐级判过），并给出全量 runs 的实际计数。 · 证据：报告数字 + 走查汇总行

## 7 内容不变量与门禁登记（规格 #The help rewrite changes no command, flag, exit code or machine output）

- [ ] 7.1 跨规格字面量：`init` 行 `.pi/skills`/`--copy`/`--no-skills`、`add-agent` 行四个旗标且无 `--model`、
  `teardown` 行 `--register`、`dispatch` 行 `--branch <name>` —— 逐条断言；每个命令的旗标集合是**旧集的超集/相等**
  （不许悄悄删旗标）。 · 证据：content 组的字面量断言 + `routes.sh walk`
- [ ] 7.2 退出码与机器出口：既有命令退出码不变；`team <cmd> --help`=0、未知 token + `--help`=2；`--print`/`--json`
  字节不被清单或语言表影响（变异表断言）。 · 证据：claims/lang 组的机器出口断言
- [ ] 7.3 登记：`smoke.sh` §51 增跑 `help-surface.sh`（失败即 §51 红）；`section-paths.tsv` 把
  `scripts/strings/*`、`scripts/lib/cmd-help.sh` 归到 §51 的 patterns；必要时 `section-budgets.tsv` 加预算；
  `references/config.md`（或 `workflows.md`）登记两个环境旋钮（英文）。 · 证据：
  `bash tests/section-select.sh --check` + `--paths skills/teamsmith/scripts/strings/commands.tsv` 的 RUN 决定 +
  §51 段输出尾
- [ ] 7.4 夹具自证：`help-surface.sh --flip` 的每条变异都证明**落地**（目标文本 1→0 / 新文本 0→1、副本与原件
  逐字节不同），没落地报「夹具缺陷」而不是「检查不灵」；红侧逐条破坏→指定用例红→还原→全绿。 · 证据：`--flip`
  输出尾 + 报告里的 red→green

## 8 收尾

- [ ] 8.1 相关段：`bash tests/smoke.sh --select 51,18,19` + `TEAM_SMOKE_FAST=1` 快跑 + `openspec validate
  --all --strict` + `spec-refs.sh --check` + `ledger-ban.sh`（自家 worktree、自家分支的树）；全量门禁留给 PM
  复验，按纪律后台跑。 · 证据：各命令 rc 与输出尾
- [ ] 8.2 写报告 `docs/team/reports/<ID>-<agent>.md`：逐条命令/rc/输出尾、第 2.5/3.5/4.4/5.4/6.3 节的
  **red→green 原始输出**、走查覆盖面数字对比、读者测试的自答、以及「机械边界」那半（哪些靠评审）。
  · 证据：报告本体 + 提交

## 9 独立验证（另一席位，不是 apply 作者）

- [ ] 9.1 在独立冻结克隆重跑全部场景与保留回归（help-surface 全组、`routes.sh` 的 walk/control/promises/refusals/
  flips、§51、§18、§19），逐条给 command/assertion/rc 与 skip。 · 证据：独立记录 + 原始日志
- [ ] 9.2 逐条重做红侧（破坏必红、还原必绿），并自设计反例：CJK 宽字符的折行边界（正好等于/超过宽度）、
  缺键回退在**中文**面上的标记、未知 token 在**别名**上的行为（`team test --help`、`team watchdog --help`）、
  无项目目录 + 非 TTY 的组合、变异帮助表后机器出口不变、`meeting` 页与 `team meeting help` 的字节一致、
  **第 0 级恰好 30 行/31 行的边界**、组页与命令页的用法片段逐字节一致。 · 证据：反例脚本与输出尾
- [ ] 9.3 读者测试（人判）：用同一 rubric 独立读 5 页（含中文面 2 页），对照 design 的深度标准，结论写进
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
