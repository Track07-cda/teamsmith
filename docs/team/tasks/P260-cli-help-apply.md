# P260 · 帮助面三级菜单与语言层：apply

task: P260
agent: dev
phase: apply
category: code
change: cli-help
specs: help-surface, dispatch
deltas: -
branch: task/P260-cli-help-apply
deps: P252（提案已 ACCEPTED，见 `docs/team/reviews/cli-help-proposal.md`；change 目录已在 main）

## 范围

实现已接受的 `openspec/changes/cli-help/` 全部内容：proposal、design 十条决策、`tasks.md` 第 1–6 节、以及两个 delta——新能力 `specs/help-surface/spec.md`（7 条要求）与 `specs/dispatch/spec.md` 的 MODIFIED（**基线 14 条场景逐字保留 + 3 条新场景**，一个都不许丢）。**不重述**合同：以 change 目录与 `dispatch` 的基线要求为准。

三条来自 PM 复核的硬性条件（记在这里以便你自查）：

1. **第 0 级的规模由门禁计数**：渲染行数 ≤30、上手命令 3–5 条，两条都要有可跑的检查与红侧（灌入命令清单必须红、填充撑过 30 行必须红）。不许改成人工检查。
2. **走查扩面不许降级**：`tests/routes.sh` 的 Walk A 主语扩到每一级（菜单 / 每个组页 / 每个命令页），读同一份命令清单作为工作集；非空洞控制臂、承诺探针、既有翻转一条不动；报告里给出改动前后的覆盖数字（design 里写的是今天 1 面/47 用法行/42 命令 → 改后 1 菜单 + 8 组页 + 48 命令页）。
3. **第 0 级的组清单是清单、不是小节标题序列**（列 0 的 `Groups` 标题 + 每组一行、缩进 2）；`── Start here ──` 那块与组页/命令页照旧按四级缩进渲染。

## 边界

- 落点按 design 的「落点」一节：`scripts/strings/commands.tsv`、`scripts/strings/help.{en,zh}.tsv`、`scripts/lib/cmd-help.sh`（新）、`scripts/team`（全局参数循环里解析 `--help`/`-h`，先于配置加载）、`scripts/lib/cmd-project.sh`（删那 98 行 heredoc）、`scripts/lib/cmd-meeting.sh`（其 help 并入 `meeting` 页）、`tests/help-surface.sh`（新）、`tests/routes.sh`、`tests/smoke.sh` 的登记、`tests/section-paths.tsv`（必要时 `section-budgets.tsv`）。
- **不许碰**：面板字符串与设置页（那是 P258 的面）、`cmd-watch.sh`/`common.sh` 的报错文案（那是 P254 的面）、`references/migration.md`（P255）、`references/config.md`（P251）。命令名、旗标名、既有退出码、`--print`/`--json` 字节一个不改（未知 token 的 `--help` 由 exit 0 改 exit 2 是本变更唯一允许改的退出行为，delta 有专门场景）。
- **写集重叠**：`tests/smoke.sh` 与 `tests/section-paths.tsv` 正被 P251（通知合并）改动——交付前先 `git merge main`，冲突按**双方保留**解决（两处都是各自追加段/行），并在合并后的树上重跑你那批选段；出现**语义**冲突（不是两处各自追加）就停下来 `BLOCKED:` 给 PM。
- 不许删/skip 断言换绿；新增跳过要有名与理由。
- 不合并、不推送；做完 `team notify pm`。

## 验收（报告里贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/help-surface.sh --all            # 新入口（组名按你实现）
bash skills/teamsmith/tests/routes.sh                        # §51 的走查（扩面后）
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

**红侧**（每条给「破坏→红（点名）→还原→绿」）：菜单灌入某组命令行；菜单被填充撑过 30 行；某条用法行只出现在命令页而不在组页（走查必须红）；删一条命令记录（覆盖红）；未知 token 走成 exit 0；帮助路径读配置（无项目目录时必须仍可用）；非法 `TEAM_LANG` 静默；删一条 zh 键不点名；页内声明与复述不一致；变异帮助表后机器出口变了。

## 交付

`docs/team/reports/P260-dev.md`（逐条 `tasks.md` 1–6 对照、命令与 rc、十一条红侧的前后证据、走查覆盖数字、`TEAM_LANG`/`TEAM_HELP_WIDTH` 的实测、未做项）；证据包按 D94 放仓外；之后由**未写过本任务**的席位独立复验。

## 范围修订（2026-10-14，用户裁定 D170：门禁只管逻辑，文本类由设计与评审把关）

**这一条比任务书其余部分优先，与它有冲突时以本条为准。** 用户原话：「文本类（措辞、排版、语言、概念定义）不适合靠代码程序来测试限制，不要依靠门禁；门禁只对逻辑类有效。」据此把本变更的**门禁面**收窄，**行为面不变**。

### 留在门禁里（逻辑类）

1. **路由与退出码**：三级各自的入口（`team help` / `team help <组>` / `team help <命令>` 与 `team <命令> --help`）、命令页与组页逐字节一致、未知组与未知命令 exit 2 且点名、`--help` 不加载配置、不执行被帮助的命令、不启动进程。
2. **用法行走查（Walk A）扩面**：读命令清单作为工作集，**逐级的**每条用法行喂真解析器；非空洞控制臂、承诺探针、既有翻转一条不动。这是逻辑（帮助承诺的旗标必须真实存在）。
3. **不变量**：命令名、旗标名、既有退出码、`--print`/`--json` 字节一个不改。
4. **语言的机制**（不是内容）：`TEAM_LANG` 读环境变量、缺省英文、`zh` 切中文、非法值一行可见告警后回退英文、缺键渲染出可见标记（不是空白也不是崩）、`--json`/`--print` 不受语言影响。
5. **声明与探针的逻辑部分**：命令清单里 `effect`/`auth`/`undo` 这些**行为声明**每个取值有真探针（只读 → 状态指纹不变；`needs-yes` → 无授权拒绝；起进程 → 有启动记录；幂等 → 第二次逐字节不变；可撤销 → 指纹复原）；没有探针的取值判红；清单的一行只渲染出它自己的那条用法行。

### 从门禁里拿掉（文本类，由设计与评审把关）

- **排版层级**（缩进、行宽、悬挂缩进、禁 `→` 链这些**断言**）——渲染器**仍按层级排版**（那是它的性质），但**不设门禁断言**；合并前 PM/复验**读一遍渲染出的样张**（design 里的「今天对比改后」逐字节样例）。
- **入口页的规模上限**（≤30 行、上手命令 3–5 条）——菜单**仍做成三级、入口页仍保持短小**（这是设计决定），但**不用门禁数行数**；「任何命令从菜单三步内可达」改由清单单一真源 + Walk A 保证（每个命令都有页）。
- **页面内容 schema**（12 个小节、13 个概念在页内复述）——页面**仍写这些内容**（那是设计要求），但**不设门禁断言**；由评审读页面判断深度是否够。
- **语言表键集相等的那条单独检查**——删（保留上面第 4 条里「缺键渲染可见标记」这个**行为**）；两表的键是否齐全由评审核对。

### 对 delta 的相应改动（由你，作为本变更的写者）

在 `openspec/changes/cli-help/specs/help-surface/spec.md` 里：删掉三条要求（`The entry level is bounded…`、`A command's page explains… to a reader who does not know teamsmith`、`The help surface's layout is fixed and mechanically checkable`）；把 `The help surface is English by default…` 收窄到上面的第 4 点（删掉键集比对那条 gate 检查）；`Every behaviour a help page states is declared and probed` 收窄到上面的第 5 点（删掉散文纪律里「数字必须名到 claim」「散文里的 `--flag` 必须在用法行打印」这类文本一致性检查；**保留**探针注册表与效应探针）。其余（路由、不变量）不动。design 里的排版层级、页面 schema、概念定义**保留为设计决定**（不是合同）；它的「目标排版样例」保留（合并前评审要照着它读样张）。

### 交付补充

- 报告里单列一节：「**哪些内容从门禁移到评审**」，逐项列出（删掉的门禁断言 / 改由评审把关的设计决定），并在合并前把**入口页、一个组页、两个命令页**的渲染样张贴进报告（供 PM 与复验直接读，不用靠门禁断言）。
- 验收命令同前（`help-surface.sh --all`、`routes.sh`、按路径算闭包的选段、账本禁令），但 `help-surface.sh` 里**不再出现**上表「从门禁里拿掉」的那些检查。
