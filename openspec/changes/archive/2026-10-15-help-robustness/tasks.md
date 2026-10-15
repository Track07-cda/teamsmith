# help-robustness · tasks

阶段口径：**apply** 由收到本 change 的席位完成（每条可判声明都要有夹具与红侧）；**verify** 由**另一个**席位
（与 apply 作者不同，dispatch 的自验守卫会拦）在独立克隆上重跑下表全部场景与红侧。本文件不是规格；合同文本在
`specs/help-surface/spec.md`（2 MODIFIED + 1 ADDED）。

范围提醒：O1 与 G4 都改 `scripts/lib/cmd-help.sh`；O2/O6/G4 的红侧都在 `tests/help-surface.sh` 的 `--flip` 里；
O7（若 PM 授权）改 `scripts/lib/cmd-config.sh` 与 `tests/config-cli.sh`。若 PM 把 O7 拆出，删除第 5 节即可，
其余不变。

## 0 冻结与投影

- [x] 0.1 读 PM 的提案复核 `docs/team/reviews/help-robustness-proposal.md`，把五个裁定点（归档提交 / O7 边界与
  delta 归属 / §51 路径登记 / O6 卫生是否收 / O1 行宽上界是否保留）的结论摘进报告；与提案不同的裁定按其改写判定
  与场景。 · 证据（已勾）：五个裁定结论逐条对到落点 —— 裁定 1（归档已提交到 main）由 P278 报告 §3.6 的试归档投影
  直接跑在含 `2026-10-15-cli-help` 归档的树上 + 合并提交 `1a1640e0` 证实；裁定 2（O7 收进本变更）§1 行 5.x 与
  §3.3；裁定 3（§51 路径登记）§3.4/§6.6；裁定 4（O6 卫生收）§1 行 7.1 与 §4 选段器红侧；裁定 5（宽度上界保留）
  §3.2/§6.2。注：报告没有单列「五裁定摘录」小节（同 P277 对 `cli-help` 0.1 的处理）
- [x] 0.2 独立树投影自证（**前置：归档已提交到 main**）：`cp -a openspec /tmp/<x>/openspec && ( cd /tmp/<x>/openspec
  && openspec validate --all --strict && openspec archive -y help-robustness && openspec validate --all --strict )`
  必须绿；逐条核对两条 MODIFIED 的基线要求标题与正文（除本变更增删的句子与场景外逐字保留）与一条 ADDED。 ·
  证据（已勾）：P278 报告 §3.6 的投影自证 —— `cp -a openspec` → `validate` rc=0（20 passed）→
  `archive -y help-robustness` rc=0（`help-surface: +1 ~2`，归档为 `2026-10-15-help-robustness`）→ `validate` rc=0
  （19 passed）。标题/正文的逐条核对不在 apply 报告里：P272 报告 §4 的投影自证列出五条要求标题、无重复，
  提案复核记「基线场景对照零丢失」（`level-0 menu` 4→6、`declared and probed` 3→4）
- [x] 0.3 冻结改动前基线：`LC_ALL=C` 与 `LC_ALL=C.UTF-8` 下 `team help`/`team help dispatch`/`team help meeting`
  的行数与最长行宽、中文面在 `LC_ALL=C` 下的 UTF-8 合法性（O1 红侧基线）；`help-surface.sh --select
  coverage,lang,invariants,route` 与 `--all` 的 ✓/✗ 计数；`config-cli.sh list validate roster` 的现状；
  `spec-refs.sh --check` 的 rc。 · 证据（已勾）：P278 报告 §3.1 —— 12 行 locale×语言表（`LC_ALL=C` 下 en 106 格 /
  zh 非法 UTF-8）、53 页探针（C 下 en 248 行越界 / zh 43 处非法 UTF-8）、选段器基线（`--select layout` /
  `nosuchsection` rc=0、✓0 ✗0）、G4 基线；P272 报告 §2.2/§4 —— `--select coverage,lang,invariants,route`
  ✓28 ✗0 rc=0、`spec-refs.sh --check` rc=0（111 引用）、`config-cli.sh:365-367` 的 `*"只读"*` needle 现状。
  注：改动前的 `--all` 与 config-cli 的 ✓/✗ 计数没有记录（P272 §4 明说 `--all` 本阶段没跑）

## 1 O1 · 宽度计算与 locale 解耦（规格 #The surface's layout is the same in every locale…）

- [x] 1.1 `scripts/lib/cmd-help.sh`：`team_help_char_width`/`team_help_cells` 与 `team_help_wrap` 的断词改成
  locale 无关实现 —— 用一次 locale 钉死的字节读取（`LC_ALL=C printf '%s' "$s" | od -An -tu1`）拿整串字节，在
  bash 算术里解码 UTF-8 到码点、按**码点数值区间**判 0/1/2 格、按码点边界折行；不再用 `${s:i:1}` 承担字符语义。
  行为不变：`TEAM_HELP_WIDTH` 默认 100、非法值一行告警回退、只读环境变量。 · 证据（已勾）：P278 报告 §6.3（`LC_ALL=C printf|od -An -tu1` 取整串字节 + 手写 UTF-8 解码
  + 码点判 0/1/2 格，`${s:off:len}` 只在 `LC_ALL=C` 下切片）+ §6.2（三处页首行也纳入折行，宽度 100 时逐字节
  不变）+ §3.2（默认宽度、UTF-8 locale 下 53 页与 HEAD 逐字节相同）；V41 §2.1/§2.4（独立 oracle：基线 en 248 行
  越界 / zh 43 页非法 UTF-8 / 两语言各 53 页随 locale 变 → 候选 0/0/0；`TEAM_HELP_WIDTH=abc`/`0`/`200` 与基线
  逐字节相同、非法值一行告警回退）
- [x] 1.2 `tests/help-surface.sh` 新增 `locale` 组（`--all` 与 `--select locale` 都能选）：用**夹具自己的** locale
  无关计数（推荐 python3 `unicodedata.east_asian_width`，不调用渲染器函数）断言：菜单 + 8 个组页 + 44 个命令页
  在 `LC_ALL=C` 与 `LC_ALL=C.UTF-8` 下逐字节相同（`cmp`）、每行 ≤ `TEAM_HELP_WIDTH` 显示格（默认与非默认各一轮）、
  每个输出都是合法 UTF-8；`TEAM_LANG=en` 与 `zh` 各一轮。 · 证据（已勾）：P278 报告 §3.2 的 `locale` 组 8 条 ✓（en/zh × 双 locale
  逐字节相同 + C/100、C.UTF-8/100、C.UTF-8/64 的行宽与 UTF-8 合法性）、`LC_ALL=C … --all` ✓105 ✗0、
  `--select locale` ✓8 ✗0；夹具自己的计数在 `help-surface.sh:495-554`（python3 `unicodedata.east_asian_width`
  + `cmp -s`，不调渲染器）；V41 §2.1 自建 `probe.py` 复核 53 页 × 两语言 × 宽度 {100,72,64,48} 全 0 违规
- [x] 1.3 `tests/smoke.sh` §51 的 FAST 选集加入 `locale`；`tests/section-paths.tsv` 的 §51 行登记新组涉及的路径
  （`scripts/lib/cmd-help.sh`、`scripts/strings/*`、`tests/help-surface.sh` 已在表里，按需补）。
  · 证据（已勾）：树内 `smoke.sh:19176` 的 FAST 选集为 `--select coverage,locale,lang,invariants,route`（含
  `locale`）；`section-paths.tsv` §51 行的数据列含 `cmd-help.sh`、`strings/*`、`help-surface.sh`（并按裁定 3 补
  `cmd-config.sh`）。P278 报告 §6.6 逐条说明这两处登记 + §3.5 的 `TEAM_SMOKE_FAST=1 smoke.sh --select 51` 输出尾
  （✓3 ✗0，270s）；V41 §7/§8 独立复核
- [x] 1.4 红侧：`flip_case "locale-dependent-width" …` —— 在 scratch 树里把 1.1 的实现换回 locale 依赖
  （今天的 `$'\uXXXX'` 区间 + `${s:i:1}`）→ `locale` 组必红并点名页与行。 · 证据（已勾）：P278 报告 §4 翻转⑨（破坏：宽度判定改回看 `LC_ALL`/`LANG`）→
  `✗ locale(zh): 1 个页面随 locale 变：command--dispatch[line 3 differs]`，还原后 `--flip` 全绿；V41 §2.3 自造三条
  变异（按字符索引 / `wc -L` / 改动前的宽度引擎）各自红并点名页与行，并用独立 oracle 复核

## 2 O2 · 内部入口的封闭清单（规格 #The help surface is a level-0 menu…）

- [x] 2.1 `tests/help-surface.sh` 的 `coverage` 组声明封闭清单（`INTERNAL_ENTRIES="__inbox-write __panel-data"`）
  并加三条断言：① dispatcher 的 `^__` 标签集合 == 清单（双向，多一个/少一个都红点名）；② 任何页面（菜单/组页/
  命令页）不出现清单里的名字；③ `commands.tsv` 的命令名不以 `__` 开头。 · 证据（已勾）：P278 报告 §3.2 的四条 ✓（`内部入口清单与 dispatcher
  的 __ 标签双向相等（2 个）`、`没有任何页面打印内部入口的名字`、`清单里没有以 __ 开头的命令名` 等）；一处声明在
  `help-surface.sh:698`（`local internal="__inbox-write __panel-data"` —— **条目写的变量名 `INTERNAL_ENTRIES` 与实现
  不同**）；V41 §3.1 自建走查（51 个标签 / 2 个 `__`、problems=0）
- [x] 2.2 红侧：`flip_case` 在 scratch 树的 `scripts/team` 加 `__probe-x)` 标签 → 红点名 `__probe-x`；
  `flip_case` 从 scratch 树的声明清单删一项 → 红点名那一项。 · 证据（已勾）：P278 报告 §4 翻转⑩（加 `__probe-x)` 标签 → `✗ 内部入口清单：dispatcher 的
  __ 标签 __probe-x 不在声明清单里`）与⑪（声明清单删一项 → 红点名 `__inbox-write`）；V41 §3.2 B2 独立复核

## 3 O6 · 可达性断言（规格 #The help surface is a level-0 menu…）

- [x] 3.1 `tests/help-surface.sh` 的 `coverage` 组加一条从清单出发的判据：菜单引导段（第一个 `──` 之前的列 2 行）
  点名的组集合 == 清单的 `group` 行集合（双向）；每个命令的组已声明、在菜单里点名、组页列出它、它有页；
  finding 点名那个组与它变成不可达的命令。既有 9 条一条不动。 · 证据（已勾）：P278 报告 §3.2 两条 ✓（`菜单的分组入口与清单的分组表双向相等（8 个组）`、
  `每个命令都能从菜单经组页在三级内到达（44 个命令）`）；§1 行 3.2 的 finding 文案带分组名与它下面的命令清单；
  V41 §3.1 自建可达性走查 problems=0
- [x] 3.2 红侧：`flip_case` 删清单里一条 `group` 行（命令仍声明它）→ 红点名那些命令；`flip_case` 让菜单渲染器
  跳过一组 → 红点名该组命令；还原 → 全绿。 · 证据（已勾）：P278 报告 §4 翻转⑫（清单删一条 `group` 行 → 点名 `mark-loaded` 不可达、分组
  `versions` 没有声明）与⑬（菜单渲染器跳过分组 → 点名分组 `versions` 与 `mark-loaded version changelog`），每条
  还原后全绿；V41 §3.2 B1/B3 独立复核
- [x] 3.3（**仅当 PM 裁定 4 收**，否则不写）选段器拒绝未知/已删的组名（今天 `--select layout` 打印
  `check_layout: command not found` 后 rc=0、`--select nosuchsection` 同样 rc=0），并删掉 `check_layout` 这类悬空
  分支；红侧：`--select nosuchsection` 非零并点名。 · 证据（已勾）：裁定 4 采纳（提案复核「O6 的『卫生』半条：**收**」）；
  P278 报告 §4 选段器红侧（`--select layout` / `nosuchsection` → `rc=2` 并列出可用组名）与 §1 行 3.3/7.1
  （悬空分支删除、不复活 `layout` 组）；树内复核 `grep check_layout\|check_scale` 无输出、两个未知名 rc=2；
  V41 §5 四个未知名 rc=2

## 4 G4 · 未声明占位符判红（规格 #Every behaviour a help page states is declared and probed）

- [x] 4.1 `scripts/lib/cmd-help.sh`：在一处声明占位符集合（`{project}`、`{meeting_ttl}`、`{token}`、`{sub}`、
  `{cmd}`、`{effect}`、`{faces}`、`{undo_cmd}`）；`team_help_load` 读清单与两张语言表时扫 `{…}` 形状的 token，
  集合外的 → 渲染非零退出并点名 token 与来源表/字段（不打印那一页）；声明了而树里不再用的 → 同样红。
  · 证据（已勾，带差异）：P278 报告 §6.1 —— 闭集声明在 `cmd-help.sh:42`：
  `TEAM_HELP_PLACEHOLDERS="{project} {meeting_ttl} {token} {sub} {cmd} {undo_cmd}"`，**是 6 个，不是条目列的
  8 个**：`{effect}`/`{faces}` 无替换点，声明它们会让「声明了而树里不再用 → 红」的反向判据失效（条目正文自相矛盾，
  apply 按证据裁掉）；未声明 token 非零退出并点名来源表的原文与反向（`{nowhere}`/`{undo_cmd}`）原文都在 §6.1；
  V41 §4 P3a–P3f 自建探针（含清单字段与反向）。另：V41 §10.4 指 `cmd-help.sh:351` 的旧注释仍与闭集矛盾
  （一行注释，未修，待顺手改）
- [x] 4.2 `tests/help-surface.sh`：一条守卫 —— 在 scratch 副本里给某张表加 `{undeclared}`，断言渲染非零且点名
  token 与来源；未改动的树照旧全绿。 · 证据（已勾）：P278 报告 §3.2（`✓ G4：未声明的 {undeclared} 让渲染非零
  退出（rc=1）、点名 token 与来源表、且不打印那一页`）与 §4「G4 的守卫」原文；V41 §4 P3a–P3d 自建探针
  （含清单字段与已声明 token 的正常替换）
- [x] 4.3 红侧（破坏 → 红 → 还原 → 绿）：`flip_case` 把 4.1 的检查删掉 → 4.2 的守卫必红；还原 → 绿。
  · 证据（已勾）：P278 报告 §4 翻转⑭（去掉检查 → `✗ G4：表里出现未声明的 {undeclared} 时渲染仍 exit 0`），
  还原后 `--flip` 全绿；V41 §1b.3（把声明过的 `{undo_cmd}` 从三张表删掉 → rc=1 并点名）

## 5 O7 · CLI 拒绝语去黑话（**仅当 PM 授权边界**，见裁定点 2）

- [x] 5.1 `scripts/lib/cmd-config.sh` 的 `team_config_write_checked_unlocked`：`refuse` 类键的拒绝语改成普通话
  （去掉「只读键」「控制台」），同批扫同族提示（未知键提示的「手改」等）；退出码、审计行、写入行为一个不改。
  · 证据（已勾）：P278 报告 §3.3 的 before/after 原文（`✗ TEAM_PROJECT 是只读键，控制台不改它` →
  `✗ TEAM_PROJECT 不能由命令改`；未知键的「请手改」→「写在」）与 Deliverables（六处改写）；V41 §6
  （scratch 项目里 rc 仍 5、提示含 `.pi/team/config.sh`、契约 sha 前后一致）
- [x] 5.2 `tests/config-cli.sh` 的 `validate` 组：把 `*"只读"*` needle 换成行为 needle —— 退出码 5、提示里含
  `.pi/team/config.sh`、契约文件 sha 未变。 · 证据（已勾，带差异）：P278 报告 §3.3 的四条行为断言（`refuse：
  TEAM_PROJECT 的退出码是 5` / `点名项目配置文件 .pi/team/config.sh` / `契约逐字节未变` / `不含「只读/控制台」
  行话`），树内 `config-cli.sh:366-373`；V41 §6 复核。差异：`:371` 是一条**否定式措辞断言**（不是行为 needle），
  V41 §10.3 记它与「措辞不设门禁断言」的口径有出入、留 PM 裁定
- [x] 5.3 红侧：`TEAM_CONFIG_TREE` flip —— scratch 树里把 `refuse` 分支改成放行 → `validate` 段红并点名；
  还原 → 绿。 · 证据（已勾）：P278 报告 §4 O7 红侧原文（scratch 树原状 validate 绿 → 删掉 `refuse` 分支 →
  rc=1 并点名 `TEAM_PROJECT`：`✗ TEAM_PROJECT=x → 5（refuse）（期望 [5]，实际 [4]）` → 还原 → `rc=0`）；
  树内 `config-cli.sh:392-435`
- [x] 5.4 若 PM 在裁定点 3 同意：`tests/section-paths.tsv` 的 §51 行补 `scripts/lib/cmd-config.sh`，并用
  `section-select.sh --paths scripts/lib/cmd-config.sh` 复核 §51 在选集里（今天不在：实测选出
  `7b,11h,14b,15c,18b,26,27,28,38,55,56`）。 · 证据（已勾）：裁定 3 采纳（提案复核「§51 路径登记缺
  `cmd-config.sh`：**收**」）；P278 报告 §3.4（`section-select.sh --paths …/cmd-config.sh` → `decision=RUN`、
  `51 ← skills/teamsmith/scripts/lib/cmd-config.sh`）与 §6.6（补的是**数据列**第 3 列）；树内复核同一命令 rc=0
  且列出 §51；V41 §5。注：报告写 `keys=19`、V41 实测 `keys=20`，口径差见 V41 §10.2

## 6 G3 · 验收 rc

- [x] 6.1 交付时把 `tests/spec-refs.sh --check` 与 `openspec validate --all --strict` 一起跑，把 rc 与输出尾贴进
  报告（不补历史记录）。 · 证据（已勾）：P278 报告 §3.6 —— `spec-refs.sh --check` → `judged 111 reference(s)
  (49 distinct) … retired 0; undeclared 0` rc=0；`openspec validate --all --strict` → `Totals: 20 passed, 0 failed
  (20 items)` rc=0（验收表第 1 行同步）；V41 §8 独立重跑同一对命令

## 7 交付前

- [x] 7.1 `git merge main`（冲突按双方保留；语义冲突停下报 PM）。 · 证据（已勾）：分支合并提交 `1a1640e0 Merge branch 'main' into
  task/P278-help-robustness-apply`；冲突处理记录在合并记录 `docs/team/reviews/P278.md`（`section-paths.tsv` 第 51 行
  按并集解，解完 `section-select.sh --check` `ok 8 bad 0 SKIP 1`）。注：apply 报告没有贴 merge 输出原文
- [x] 7.2 逐条看「本次相对 main 的删除行」（P261 的教训）：确认没有误删既有断言/红侧/语言表行。
  · 证据（已勾）：P278 报告 §2 末（既有 9 条 `coverage` 断言、`lang`/`claims`/`invariants`/`route` 各条、既有
  8 条红侧「一条没删」，都在 `--all ✓105` 里）+ §4 既有 ①–⑧ 翻转保留；合并记录 `docs/team/reviews/P278.md`
  「合并时按纪律核过：删除行都是本任务的改写」；V41 §7 独立断言集合对照（`help-surface.sh` 106→132 丢失 0；
  `config-cli.sh` 365→378，只换掉那条措辞断言）。注：apply 报告没有贴 `git diff main...HEAD --stat`/删除行清单本身
- [x] 7.3 跑「验收」一节全部命令 + 写报告 + `team notify pm`。 · 证据（已勾）：P278 报告 §3 表（validate/`--all`/
  `LC_ALL=C --all`/`--flip`/`routes.sh`/`config-cli`/`spec-refs`/`ledger-ban`/`git diff` 逐条 rc）+ §3.2–§3.6 输出尾
  + §4 红侧；报告本体 `docs/team/reports/P278-verify.md`（提交 `9104550f`，随 `919aef0f` 并入 main）；送达由合并记录
  `docs/team/reviews/P278.md` 与 BOARD 的 P278 行证实（`team notify` 的收件箱在本仓 gitignore 里）

## 验收（贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/help-surface.sh --all
bash skills/teamsmith/tests/help-surface.sh --flip
bash skills/teamsmith/tests/routes.sh
LC_ALL=C bash skills/teamsmith/tests/help-surface.sh --select locale
bash skills/teamsmith/tests/config-cli.sh list validate roster
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/cmd-config.sh
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

## 红侧汇总（逐条：破坏 → 指定用例红 → 还原 → 绿）

| # | 破坏（scratch 树里的变异） | 指定用例 | 期望红点名 |
|---|---|---|---|
| O1 | `cmd-help.sh` 换回 locale 依赖的宽度计算 | `--select locale` | 页 + 越界/不一致的行 |
| O2a | `team` 加一个 `__probe-x)` 标签 | `--select coverage` | `__probe-x` |
| O2b | 声明清单里删一个内部名 | `--select coverage` | 那个内部名 |
| O6a | `commands.tsv` 删一条 `group` 行（命令仍声明它） | `--select coverage` | 该组 + 不可达的命令 |
| O6b | 菜单渲染器跳过一个已声明的组 | `--select coverage` | 该组命令 |
| G4 | `cmd-help.sh` 去掉占位符检查 | 夹具的 G4 守卫（内部 scratch 副本） | 未声明 token + 来源 |
| O7 | `cmd-config.sh` 的 `refuse` 分支放行 | `config-cli.sh validate` | 退出码/路径 needle |

## 不变量（apply 与 verify 都要核）

- `routes.sh` Walk A 的解析器规则、工作集来源、`ENTRY`/`CLAIM` 下限、非空洞控制臂与既有翻转一条不动；
  `help-surface.sh` 既有 9+ 条 coverage 断言、`lang` 机制、`claims`、`invariants`、`route` 与既有翻转一条不删。
- 不新加文本类断言（D170）：不加缩进阶梯、页面深度、第 0 级行数、小节顺序、措辞、语言表键集相等；`layout`/
  `scale`/`content` 三组不恢复。
- 命令名、旗标名、既有退出码、`--print`/`--json` 字节一个不改；`--flip` 全绿。
