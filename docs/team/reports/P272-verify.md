# P272 · help-robustness propose — delivery report

- **Task**: `docs/team/tasks/P272-help-robustness.md` · change `help-robustness` · phase `propose` · category `code`
- **Branch**: `task/P272-help-robustness-propose`（local 模式：无远端，分支留在本地给 PM）
- **Agent**: verify
- **Status**: **delivered**（方案三件 + delta 已提交；`openspec validate --all --strict` 23/0 rc=0；投影自证绿；
  `ledger-ban` hits=0；工作树干净）。**两条交回 PM 的动作**（归档提交、O7 边界）见 §5，它们是 apply 的前置条件，
  不是本交付的缺口。

## 0. 本阶段交付了什么

任务书末尾的「本阶段只写方案」：`openspec/changes/help-robustness/{proposal.md,design.md,tasks.md}` +
对 `help-surface` 的 delta。没有实现改动、没有碰产品代码或夹具（本阶段不需要）。三条提交：

| 提交 | 内容 |
|---|---|
| `bab8815c` | `openspec/changes/help-robustness/specs/help-surface/spec.md`（2 MODIFIED + 1 ADDED） |
| `47c3fba5` | `proposal.md` + `design.md` |
| `29118dff` | `tasks.md` |

## 1. 方案里各条的落点与判据

| # | 观察 | 合同落点 | 判据（逻辑类） | 红侧 |
|---|---|---|---|---|
| O1 | 非 UTF-8 locale 下排版失真 | **ADDED** `The surface's layout is the same in every locale, and never exceeds its width` | 同一输入在 `LC_ALL=C` 与 `LC_ALL=C.UTF-8` 下逐字节相同 + 每行 ≤ `TEAM_HELP_WIDTH` 显示格 + 合法 UTF-8 | 宽度计算换回 locale 依赖 → 红 |
| O2 | 合同只点名一个内部例外 | **MODIFIED** `The help surface is a level-0 menu…` | 内部入口 = `__` 前缀的**封闭集合**，与 dispatcher 的 `^__` 标签双向对账；任何页面不打印；清单不携带 | 加一个 `__probe-x)` → 红点名；声明表删一项 → 红点名 |
| O6 | 可达性断言被移走、没有替代品 | **MODIFIED** 同上 | 菜单点名的组集合 == 清单 `group` 表（双向）；每个命令的组已声明、在菜单里、组页列出它、它有页；finding 点名组与不可达命令 | 删一条 `group` 行 / 菜单漏印一组 → 红点名该组命令 |
| G4 | 「未知占位符判红」没有断言（且渲染器原样打印） | **MODIFIED** `Every behaviour a help page states is declared and probed` | 占位符集合封闭、一处声明；集合外 token → 渲染非零并点名 token 与来源；声明了而不用 → 同样红 | 去掉检查 → 夹具守卫必红（破坏 → 红 → 还原 → 绿） |
| O7 | `refuse` 类拒绝语仍是黑话 | **不写 delta 文字**（见 §3.5） | 行为 needle：拒绝仍发生、退出码 5 不变、提示含 `.pi/team/config.sh`、什么都没写 | `refuse` 分支放行 → `config-cli.sh validate` 红 |
| G3 | `spec-refs.sh --check` 无 rc | **不写 delta 文字**（验收行） | 交付时跑并贴 rc | — |

## 2. 实测基线（改动前，本 worktree）

### 2.1 O1 的机制与端到端后果

直接 source `scripts/lib/cmd-help.sh` 跑**真函数**：

```
locale=C  cjk=15  dash=8  ascii=8
  per-char of cjk: [<byte>]=1 ×15
locale=C.utf8  cjk=10  dash=5  ascii=8
  per-char of cjk: [中]=2 [文]=2 [宽]=2 [字]=2 [符]=2
```

```
locale=C       U+0300 bytes=5c7530333030
  [<] w=0  [a] w=1  [>] w=0  [-] w=1  [[] w=0  [—] w=1  [·] w=1  [中] w=1
locale=C.utf8  U+0300 bytes=cc80
  [<] w=1  [a] w=1  [>] w=1  [-] w=1  [[] w=1  [—] w=1  [·] w=1  [中] w=2
```

根因是确定的：非 UTF-8 locale 下 bash 不把 `$'\u0300'` 编成码点（实测是 6 个字面字节 `\u0300`），
`case` 的括号区间端点因此退化成字面字符，`[\u0300-\u036f]` 里出现 `0`–`\` 这个 ASCII 区间（吞掉数字、大写字母、
`<`、`>`、`[`）；而 `${s:i:1}` 按字节切片。端到端（`TEAM_LANG=en`，同一棵树，行宽用 locale 无关的
`unicodedata.east_asian_width` 量）：

| 页面 | `LC_ALL=C` | `LC_ALL=C.UTF-8` | `cmp` |
|---|---|---|---|
| `team help` | 25 行 / 最长 106 格 / 3 行越 100 | 26 行 / 100 格 / 0 | DIFFERS |
| `team help dispatch` | 41 行 / 106 格 / 11 行越界 | 43 行 / 100 格 / 0 | DIFFERS |
| `team help meeting` | 46 行 / 120 格 / 6 行越界 | 47 行 / 100 格 / 0 | DIFFERS |
| `TEAM_LANG=zh team help dispatch` | 41 行 / 106 格 / **不是合法 UTF-8**（字节 555 截断汉字） | 36 行 / 100 格 / 合法 | DIFFERS |

越界的原因也量到了：`team_help_wrap` 把 `<a>`/`<ID>` 量成 1/0 格，于是 `dispatch <a> <ID> …` 这条 104 格的用法行
被判成「不超过 98」而不折（`wrap(98,96)` 在 C 下出 1 行，在 `C.UTF-8` 下出 2 行）。

### 2.2 O2 / O6 / O7 / G3 / 归档状态

```
$ grep -n '__[a-z-]*' skills/teamsmith/scripts/team
99:  __inbox-write) team_cmd_inbox_write "$@" ;;   # 内部：notify 扩展的收件箱写入口（合并 + 明细；不进 help）
120:  __panel-data) team_cmd_panel_data "$@" ;;     # 内部：panel.js 的数据源（不出现在 help 里）
```

```
$ bash skills/teamsmith/tests/help-surface.sh --select layout
skills/teamsmith/tests/help-surface.sh: line 1104: check_layout: command not found
== 结果 ==  ✓ 0  ✗ 0  SKIP 0          rc=0
$ bash skills/teamsmith/tests/help-surface.sh --select nosuchsection
== 结果 ==  ✓ 0  ✗ 0  SKIP 0          rc=0
```

```
$ sed -n '365,367p' skills/teamsmith/tests/config-cli.sh
  err="$(run_in "$p" config set TEAM_PROJECT x --yes)"
  case "$err" in *"只读"*) ok "refuse 的报错点名只读" ;; *) bad "refuse 的报错没说清（$err）" ;; esac
$ grep -n '只读键' skills/teamsmith/scripts/lib/cmd-config.sh
929:    team_err "$key 是只读键，控制台不改它"
```

`spec-refs.sh --check`（G3）：`judged 111 reference(s) (49 distinct) in 11299 effective line(s); retired 0;
undeclared 0` → **rc=0**。

`cli-help` 的归档**在磁盘上、不在 git 里**（本分支起点 = main 的 tip `2e7b386a`）：

```
$ ls openspec/changes/archive/ | grep cli-help      # 空
$ ls openspec/specs/ | grep help-surface            # 空
$ git -C <main worktree> status --porcelain --untracked-files=all | wc -l
43
$ git -C <main worktree> status --porcelain --untracked-files=all | grep -c '^??.*archive/2026-10-15'
16   # 四份归档目录；另有 openspec/specs/help-surface/spec.md 与三条 specs 的 M、四个活动 change 目录的 D
```

## 3. 设计里对每条的关键决定

### 3.1 O1：把宽度从 locale 里拿出来，而不是挑一个 locale

取字节的路径本身必须与 locale 无关 —— `${#s}`/`${s:i:1}` 正是要消灭的歧义。方案：一次
`LC_ALL=C printf '%s' "$s" | od -An -tu1` 拿整串字节，在 bash 算术里解码 UTF-8 到码点、按**码点数值区间**判宽、
按码点边界折行（顺带把「每字符一次命令替换」降成「每串一次」）。被否决：脚本内 `export LC_ALL=C.UTF-8`
（押在可能不存在的 locale 上，仍是「交给 locale 决定」）、`wcwidth`/`wc -L`（同类问题 + 可用性）、只换区间表不换
切片（切片本身就把宽字符切成半个）。

### 3.2 O1 与 D170 的界线（任务书要求写清）

新增的只有**行为**断言：同一输入在不同 locale 下输出相同、每行不超过那个有文档的宽度旋钮
（`references/workflows.md`：「the width the surface wraps to, in display cells (a CJK-wide character counts
two)」）。**不新增**缩进阶梯、悬挂缩进、页面深度、第 0 级行数、小节顺序、措辞、语言表键集相等；被 D170 移走的
`layout`/`scale`/`content` 三组**不恢复**。夹具的量宽实现必须与渲染器**不共享代码**（推荐 python3 的
`unicodedata.east_asian_width`；夹具已在用 python3），否则是自证。

### 3.3 O2 为什么用 `__` 前缀而不是点名两个名字

源码的约定本来就是「`__` 前缀 = 内部」（两条注释都这么写），V38 §6.3 的结论也是「按约定前缀，对未加 `__` 的
新标签照旧判红」。用前缀，第三个内部入口一出现就被抓；点名两个只抓这两个。清单**双向**对账（多一个、少一个都
红），并额外断言「任何页面不打印内部名」「清单不携带内部名」。

### 3.4 O6 的判据从清单出发，finding 点名组与命令

菜单引导段（第一个 `──` 之前的列 2 行）点名的组集合 == 清单 `group` 表；对每个命令，组已声明 / 在菜单里 /
组页列出它 / 它有页。这样「入口 → 组页 → 命令页」三环都有断言：菜单点名（新）、组页列出（既有「组页用法行
逐条等于清单」）、命令有页（既有）。既有 9 条 coverage 断言一条不动。

### 3.5 O7 为什么不写 delta 文字（请 PM 复核这个判断）

它要保的行为**已经在规格里**：`panel#The console shows the project contract with its effect class, and refuses
what it must not change` 要求 `refuse` 行的交互「surface the owning command's refusal, which names the right
route (hand-editing the file, `team add-agent`, …)」，而控制台只能照 CLI 的原文显示 —— 所以「CLI 的拒绝点名路线」
这条合同已存在。剩下的只是**措辞**（「只读键」「控制台」「手改」），D170 明说交给评审。给措辞补一条门禁要求，
正好是把 D170 要拿出门禁的东西请回来。若 PM 判它必须成为规格文字，落点是 `panel`（那条路线合同的家），本变更的
`deltas:` 行要加一项。

### 3.6 不变量（「不许削弱」）

`routes.sh` Walk A 的解析器规则 / 工作集来源 / `ENTRY`·`CLAIM` 下限 / 非空洞控制臂 / 既有翻转一条不动；
`help-surface.sh` 既有 coverage 9+ 条、`lang` 机制、`claims`、`invariants`、`route` 与既有翻转一条不删；
命令名/旗标名/退出码/`--print`·`--json` 字节不改；`--flip` 必须全绿。新增红侧见 `tasks.md` 的红侧汇总表。

## 4. 本阶段实跑的验收（贴真实输出尾）

```bash
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
✓ spec/watchdog
Totals: 23 passed, 0 failed (23 items)          rc=0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 111 reference(s) (49 distinct) in 11299 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
spec-refs rc=0

$ bash skills/teamsmith/tests/help-surface.sh --select coverage,lang,invariants,route
== 结果 ==  ✓ 28  ✗ 0  SKIP 0                    rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: … scope=published files=1560 hits=0 names=ok user=resolved   rc=0

$ git diff --check && git status --short
（空）
```

**投影自证**（本 delta 的 MODIFIED 标题对得上归档投影后的基线）：

```bash
$ cp -a openspec /tmp/<x>/openspec && ( cd /tmp/<x>/openspec \
    && openspec archive -y cli-help && openspec archive -y help-robustness && openspec validate --all --strict )
Change 'cli-help' archived as '2026-10-15-cli-help'.
Applying changes to openspec/specs/help-surface/spec.md:   + 1 added   ~ 2 modified
Change 'help-robustness' archived as '2026-10-15-help-robustness'.
Totals: 22 passed, 0 failed (22 items)
$ grep -n '^### Requirement:' specs/help-surface/spec.md
6:### Requirement: The help surface is a level-0 menu, a page per group and a page per command
87:### Requirement: The help surface is English by default and switches language through `TEAM_LANG`
134:### Requirement: Every behaviour a help page states is declared and probed
189:### Requirement: The help rewrite changes no command, flag, exit code or machine output
222:### Requirement: The surface's layout is the same in every locale, and never exceeds its width
```

五条要求 = 基线的四条（两条被替换、两条原样保留）+ 一条新增；没有出现重复标题。

**本阶段没跑的**（属 apply/verify 的门禁，方案未实现，跑了也不判任何东西）：`help-surface.sh --all`（含逐命令
承诺探针）、`help-surface.sh --flip`、`routes.sh`、`config-cli.sh list validate roster`。`--select layout` 我跑了
（它是 O6 卫生半条的现场证据，见 §2.2），不是验收。

## 5. 交回 PM 的动作（apply 的前置条件）

1. **`BLOCKED:`（PM）`cli-help` 的归档必须提交到 main**。任务书 `deps:` 写「已归档」，观测到的是「磁盘已归档、
   git 未提交」（§2.2）。本 delta 的 MODIFIED 标题按投影后的文本写、投影自证已绿，所以内容是对的；但 apply 分支上
   `openspec/specs/help-surface/spec.md` 不存在 → `team dispatch` 的锚点解析与将来归档本变更时的基线替换都会落空。
   请把工作树里那 43 条归档改动（四份 `archive/2026-10-15-*/`、`openspec/specs/help-surface/spec.md`、三条 specs 的
   修改、四个活动 change 目录的删除）作为一次账本提交落到 main。顺带一提：`D180` 写的「据此本批已执行：归档四条」
   与观测到的树不一致（提交 `2d712559` 只改了 `DECISIONS.md`），请一并核对。
2. **`BLOCKED:`（PM 裁定）O7 的两条路径不在任务书边界里**：`skills/teamsmith/scripts/lib/cmd-config.sh` 与
   `skills/teamsmith/tests/config-cli.sh`。推荐把这两条加进边界（措辞仍由评审把关、不带 delta 文字）；替代是拆出
   O7。同时请裁 §51 的路径登记（裁定点 3）：实测
   `section-select.sh --paths skills/teamsmith/scripts/lib/cmd-config.sh` 选出 `7b,11h,14b,15c,18b,26,27,28,38,55,56`，
   **不含 §51**，而 §51 正是跑 `config-cli.sh` 那条 needle 的段 —— 改 `cmd-config.sh` 不会让那条断言重跑。
3. **（PM 裁定）O6 的「选段名静默通过」卫生半条**：本变更**未**纳入（任务书 O6 只要求可达性断言），但现场是
   `--select layout` 打印 `check_layout: command not found` 后 rc=0、`--select nosuchsection` 同样 rc=0。推荐顺手收
   （选段器拒绝未知名字 + 删悬空分支），它是一条假绿口子；要收就写进 apply 任务书当夹具卫生项。
4. **（PM 裁定）O1 的行宽上界是否保留为门禁断言**：本提案按任务书原文保留。若判它属 D170 的排版类，最小形态是
   只留「两 locale 逐字节相同 + 合法 UTF-8」，行宽上界降为评审项。

## 6. 残余与风险

- **行宽上界的门禁含义**：会让「故意加长一行」变红 —— 它是宽度旋钮的定义，不是版式口味（见 §3.2）；请按裁定点 4 定。
- **`od` 依赖**：coreutils 的 `od` 在门禁容器与目标机器都在（脚本/夹具已大量用 `od`/`awk`）；等价替代是一次
  `LC_ALL=C` 的 awk 解码器，合同不变。
- **占位符扫描的形状**：要窄（`{` + 小写标识符 + `}`），别把散文里合法的花括号当占位符。
- **O6 判据依赖菜单引导段的版式事实**（组清单在第一个 `──` 之前、列 2）；版式本身由设计/评审把关，但这条判据
  只依赖「读得到组 id」。若将来版式搬走，判据要跟着改（仍比没有判据稳）。
