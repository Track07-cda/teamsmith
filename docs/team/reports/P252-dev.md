# P252 · 分级菜单 + 每个命令的帮助页：默认英文、可切语言、给不懂这个项目的人看的（propose，含 2026-10-14 追加要求）

agent: dev   status: DONE   time: 2026-10-14T06:58:00Z
branch: `task/P252-cli-help-propose`   PR/MR: -（local 模式：分支留本地，PM 复验后本地合并）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/cli-help/proposal.md` | 用户三条原话（含两条追加：**分级**、**缩进层级**）、现状复核（98 行 / 47 行超 100 列 / 5 行 8 个 `→` / 无按命令页 / 无语言层 / 走查只读一处）、三级菜单与层级阶梯的变更说明、能力归属（**两个 delta**）、**六个 PM 裁定点**、承诺→兑现→红侧清单、走查覆盖面数字对比、验收命令、范围外 |
| `openspec/changes/cli-help/design.md` | 决策 1–10（三级路由与未知 token、第 0 级的四个组成与 30 行上限、数据驱动（清单 + 两语言表 + bash/awk 渲染器，不引框架）、**层级阶梯 0/2/6/10/14 + 可归属版式规则 + 同命令「今天 vs 改后」逐字节样例**、走查扩面（清单工作集 + 逐级解析 + 数字账）、页面 12 部分与概念复述、封闭词表 + 探针 + 机械边界、语言层、真源关系、被否决方案）、跨规格字面量表、风险、迁移、未决/后续 |
| `openspec/changes/cli-help/tasks.md` | apply 任务表（0 冻结投影 / 1 清单与渲染器 / 2 三级路由与第 0 级规模 / 3 语言层 / 4 页面内容与概念 / 5 声明与探针 / 6 **走查扩面** / 7 不变量与登记 / 8 收尾）+ 独立 verify（9）+ 验收命令（10），每条带证据与红侧方向 |
| `openspec/changes/cli-help/specs/help-surface/spec.md` | 新能力 delta：**7 条 ADDED、25 条场景** —— 三级菜单与路由 / 第 0 级规模上限 / 页面深度与必定义概念 / 默认英文 + `TEAM_LANG` / 固定层级版式与可解析性 / 命令清单 + 声明 + 探针 / 不改命令·旗标·退出码·机器出口 |
| `openspec/changes/cli-help/specs/dispatch/spec.md` | **MODIFIED** `The printed route is a route that works`：走查主语从「`team help` 的用法行」扩到**帮助面每一级**、工作集来自命令清单（覆盖度 = 每个命令 × 每条用法行）；**14 条基线场景逐字保留 + 3 条新场景**（第 2 级页面的坏用法行、清单漏命令、逐级都判到） |

本阶段只写提案（proposal/design/tasks/两个 delta）：**不改产品代码、不改任务书、不改其他目录**；apply 与 verify
另行换人。**给 PM 的两点**（也可看 proposal 的裁定点）：① 本变更写**两个** delta 文件，任务书的 `deltas: help-surface`
行只点了第一个 —— 派 apply 时请补成 `help-surface, dispatch`；② 第 0 级的组清单排法是裁定点 3（30 行上限与
「组标题顶格」的取舍）。

## Verification evidence (must have actually been run)

```bash
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict | tail -4
✓ change/turn-notice-merge
✓ spec/verification
✓ spec/watchdog
Totals: 18 passed, 0 failed (18 items)
$ echo ${PIPESTATUS[0]}
0

# 独立树投影：两个 delta 都真的能归档（+7 ADDED、~1 MODIFIED），归档后 validate 仍全绿
$ mkdir -p /tmp/p252-trial3 && cp -a openspec /tmp/p252-trial3/openspec
$ (cd /tmp/p252-trial3 && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y cli-help | tail -6 \
    && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict | tail -1)
Applying changes to openspec/specs/help-surface/spec.md:
  + 7 added
Totals: + 7, ~ 1, - 0, → 0
Specs updated successfully.
Change 'cli-help' archived as '2026-10-14-cli-help'.
Totals: 18 passed, 0 failed (18 items)

# MODIFIED 的保真核对：归档后的走查要求 = 14 条基线场景（原序）+ 3 条新场景；dispatch 仍是 21 条要求
$ diff <(sed -n '806,943p' openspec/specs/dispatch/spec.md | grep '^#### Scenario:') \
       <(sed -n '806,974p' /tmp/p252-trial3/openspec/specs/dispatch/spec.md | grep '^#### Scenario:')
14a15,17
> #### Scenario: A level-2 page's bad usage line is caught
> #### Scenario: A command the manifest omits fails the coverage arm
> #### Scenario: Every level is judged, not just the menu
$ grep -c '^### Requirement:' openspec/specs/dispatch/spec.md            # 21（与基线一致）

$ bash skills/teamsmith/tests/routes.sh      # 改动前的基线（任务书要求的那一遍）；最终 tip 上又跑一次
$ tail -1 /tmp/p252-routes-baseline.log
== 结果 ==  ✓ 214  ✗ 0  SKIP 0
$ tail -1 /tmp/p252-routes-final.log
== 结果 ==  ✓ 214  ✗ 0  SKIP 0
$ echo $?    # 两次都 0（第二次后台作业 p252-routes-final，exit 0，314.9 s）

# 走查今天的覆盖面（本变更的对照数字，基线日志实测）
$ grep -ac '用法行 L' /tmp/p252-routes-baseline.log        # 47 条用法行
$ grep -ac '断言 L'   /tmp/p252-routes-baseline.log        # 75 条 (命令,旗标) 声明
$ grep -a '用法行 L' /tmp/p252-routes-baseline.log | sed 's/.*：//' | awk '{print $1}' | sort -u | wc -l
42                                                          # 42 个命令（只来自 team help 一处）

$ bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ') | tail -3
0c	prologue
0d	prologue
18c	openspec/changes/cli-help/design.md, openspec/changes/cli-help/proposal.md, openspec/changes/cli-help/specs/dispatch/spec.md, openspec/changes/cli-help/specs/help-surface/spec.md, openspec/changes/cli-help/tasks.md
60	docs/team/reports/P252-dev.md
$ echo $?
0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 111 reference(s) (49 distinct) in 11042 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
$ echo $?
0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（…/.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=…/.worktrees/dev scope=published files=1460 hits=0 names=ok user=resolved
$ echo $?
0

$ git diff --check && git status --short
（无输出）
$ echo $?
0
```

- Verdict: pass（本阶段：两个 delta 可归档且 MODIFIED 保真、走查与账本检查全绿、树干净）
- Notes（要显式说明的）：
  - 本阶段**没有**改任何产品代码或夹具，所以 §51 走的是**改动前的树**：214 ✓ / 0 ✗ 是基线，不是「改完还绿」。
    分级、版式、走查扩面都必须由 apply 实现并重跑（tasks 6/10 的验收命令），本报告不声称那一步已经发生；
    报告里的覆盖数字是**改动前**的实测与改动后的**目标**。
  - 全量 `smoke.sh` 本阶段**未跑**（propose 只写文档；按纪律全量留给 PM 在最终 tip 上后台跑）。
  - 提案里的 apply/verify 验收命令是**计划**（含新夹具 `help-surface.sh`），尚未存在；本报告不把它当已兑现的证据。
  - 六个裁定点在 proposal「需要 PM 裁定的点」一节，按推荐版本落笔；裁定若与推荐不同，相关场景要按裁定改写。
  - 观察（不属于本任务范围，供 PM 判断长作业的收割时点）：`p252-routes-baseline` 的进程在 06:08:48 就退出
    （`state/bg/p252-routes-baseline.log` 的 mtime 与末尾的 `rc=0` 都是那时写的），但完成通知约 47 分钟后才到
    （`team_bg_wait` 报 3121.0 s）。结果与报告里引用的完全一致（exit 0、214 ✓ / 0 ✗），只是**通知时点**晚；
    按 D120/#2027 的职责边界，这属于 Pi harness 的唤醒行为，Teamsmith 侧不做兼容实现 —— 记在这里供 PM 判断。
- Ledger ban:

  ```
  $ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  ledger-ban: root=…/.worktrees/dev scope=published files=1460 hits=0 names=ok user=resolved
  $ echo $?
  0
  ```

## Flip evidence (required for defect-fix tasks)

本任务不是 defect-fix（phase: propose，只写提案），没有要翻转的旧缺陷。**六条红侧**已经写成 apply 的验收要求：
① 缺一条命令页 ② 中文表缺一条键 ③ 帮助里解析器不接受的形式（**每一级**都判） ④ 没有夹具兑现的承诺
⑤ 布局违规（行宽/层级/悬挂/`→`/空组） ⑥ **第 0 级超规模（>30 行或一次列出超过 N 个命令）**；proposal 的
「承诺与兑现」表、design 决策 4/5/7 与 tasks 的 2.5/3.5/4.4/5.4/6.3 逐条给出「破坏 → 指定用例红 → 还原 → 全绿」
的方向与落点，并含夹具自证的「变异必须落地」判据。

## Decisions and deviations

- 与任务书一致：change id `cli-help`、capability `help-surface`、本阶段只写提案、不引 CLI 框架（采纳 PM 的
  数据驱动倾向：单一命令清单 + 渲染器 + 平级语言表，Walk A 读同一份清单）。
- 按 2026-10-14 追加要求做的修订（对应 PM 的唤醒消息与更新后的任务书第 1、4 条）：
  - **分级**成为第 1 条要求：三级菜单 + 第 0 级 ≤30 行/3–5 个命令的规模断言（红侧 ⑥）+ 未知组/命令 exit 2 +
    `team <命令> --help` 不许退回全局页。
  - **版式层级**成为显式阶梯（0/2/6/10/14 + 参数说明列），并给出「同一条 `dispatch` 今天 vs 改后」的逐字节样例；
    版式必须能被走查认出来（这是扩面的前提）。
  - **Walk A 扩面到每一级的所有页**：主语从 `team help` 扩到三级帮助面，工作集来自命令清单；因为这是走查合同的
    主语变化，本变更写了 `dispatch` 的 **MODIFIED** delta（14 条基线场景逐字保留 + 3 条新场景），而不是在
    `help-surface` 里写平行陈述。
- 三处按任务书授权做的判断（都写成裁定点）：① 语言只读环境变量（不落配置）；② 未知 token 的 `--help` 改为
  exit 2（唯一改掉的退出行为）；③ 第 0 级组清单用紧凑清单（`Groups` 标题 + 每组一行）而不是「每组一个 `──` 标题 +
  一行散文」—— 30 行上限与走查的可归属规则同时排除了后者（proposal 裁定点 3 给了另一个方向的代价）。
- 未做的事：没有为了「让走查更好过」删任何用法行或放宽解析器（proposal 的范围外一节明确禁掉）；没有动
  `references/**`、README、面板语言机制；没有翻译帮助面之外的 5477 行消息（设计写了分步迁移路线）。

## Suggested next steps

- PM 按 `skills/teamsmith/references/openspec.md` §4 写 `docs/team/reviews/cli-help-proposal.md`（ACCEPTED 或
  NEEDS-CHANGES），并裁定 proposal 的六个点（尤其裁定点 3 的 30 行上限与「组标题顶格」取舍、裁定点 5 的
  两个 delta）。
- ACCEPTED 之后把 apply 任务书的 `deltas:` 行补成 `help-surface, dispatch`，再按 tasks 派 apply（一个席位，
  0→8 顺序）与 verify（另一席位，第 9 节）；红侧方向不得改。
- 需要用户拍板的一件事（PM 转达即可）：未知 token 的 `--help` 从今天的 exit 0 变成 exit 2（裁定点 4）；
  若用户希望保持 exit 0，改一条场景与一条断言即可。
