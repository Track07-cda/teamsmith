# help-robustness · tasks

阶段口径：**apply** 由收到本 change 的席位完成（每条可判声明都要有夹具与红侧）；**verify** 由**另一个**席位
（与 apply 作者不同，dispatch 的自验守卫会拦）在独立克隆上重跑下表全部场景与红侧。本文件不是规格；合同文本在
`specs/help-surface/spec.md`（2 MODIFIED + 1 ADDED）。

范围提醒：O1 与 G4 都改 `scripts/lib/cmd-help.sh`；O2/O6/G4 的红侧都在 `tests/help-surface.sh` 的 `--flip` 里；
O7（若 PM 授权）改 `scripts/lib/cmd-config.sh` 与 `tests/config-cli.sh`。若 PM 把 O7 拆出，删除第 5 节即可，
其余不变。

## 0 冻结与投影

- [ ] 0.1 读 PM 的提案复核 `docs/team/reviews/help-robustness-proposal.md`，把五个裁定点（归档提交 / O7 边界与
  delta 归属 / §51 路径登记 / O6 卫生是否收 / O1 行宽上界是否保留）的结论摘进报告；与提案不同的裁定按其改写判定
  与场景。 · 证据：（待填）
- [ ] 0.2 独立树投影自证（**前置：归档已提交到 main**）：`cp -a openspec /tmp/<x>/openspec && ( cd /tmp/<x>/openspec
  && openspec validate --all --strict && openspec archive -y help-robustness && openspec validate --all --strict )`
  必须绿；逐条核对两条 MODIFIED 的基线要求标题与正文（除本变更增删的句子与场景外逐字保留）与一条 ADDED。 ·
  证据：（待填）
- [ ] 0.3 冻结改动前基线：`LC_ALL=C` 与 `LC_ALL=C.UTF-8` 下 `team help`/`team help dispatch`/`team help meeting`
  的行数与最长行宽、中文面在 `LC_ALL=C` 下的 UTF-8 合法性（O1 红侧基线）；`help-surface.sh --select
  coverage,lang,invariants,route` 与 `--all` 的 ✓/✗ 计数；`config-cli.sh list validate roster` 的现状；
  `spec-refs.sh --check` 的 rc。 · 证据：（待填）

## 1 O1 · 宽度计算与 locale 解耦（规格 #The surface's layout is the same in every locale…）

- [ ] 1.1 `scripts/lib/cmd-help.sh`：`team_help_char_width`/`team_help_cells` 与 `team_help_wrap` 的断词改成
  locale 无关实现 —— 用一次 locale 钉死的字节读取（`LC_ALL=C printf '%s' "$s" | od -An -tu1`）拿整串字节，在
  bash 算术里解码 UTF-8 到码点、按**码点数值区间**判 0/1/2 格、按码点边界折行；不再用 `${s:i:1}` 承担字符语义。
  行为不变：`TEAM_HELP_WIDTH` 默认 100、非法值一行告警回退、只读环境变量。 · 证据：（待填：改动前后同一输入的
  行数与最长行宽）
- [ ] 1.2 `tests/help-surface.sh` 新增 `locale` 组（`--all` 与 `--select locale` 都能选）：用**夹具自己的** locale
  无关计数（推荐 python3 `unicodedata.east_asian_width`，不调用渲染器函数）断言：菜单 + 8 个组页 + 44 个命令页
  在 `LC_ALL=C` 与 `LC_ALL=C.UTF-8` 下逐字节相同（`cmp`）、每行 ≤ `TEAM_HELP_WIDTH` 显示格（默认与非默认各一轮）、
  每个输出都是合法 UTF-8；`TEAM_LANG=en` 与 `zh` 各一轮。 · 证据：（待填：✓/✗ 计数 + 两 locale 的 `cmp` 结果）
- [ ] 1.3 `tests/smoke.sh` §51 的 FAST 选集加入 `locale`；`tests/section-paths.tsv` 的 §51 行登记新组涉及的路径
  （`scripts/lib/cmd-help.sh`、`scripts/strings/*`、`tests/help-surface.sh` 已在表里，按需补）。
  · 证据：（待填：`smoke.sh --select 51` 的输出尾）
- [ ] 1.4 红侧：`flip_case "locale-dependent-width" …` —— 在 scratch 树里把 1.1 的实现换回 locale 依赖
  （今天的 `$'\uXXXX'` 区间 + `${s:i:1}`）→ `locale` 组必红并点名页与行。 · 证据：（待填：红侧日志的 finding 行）

## 2 O2 · 内部入口的封闭清单（规格 #The help surface is a level-0 menu…）

- [ ] 2.1 `tests/help-surface.sh` 的 `coverage` 组声明封闭清单（`INTERNAL_ENTRIES="__inbox-write __panel-data"`）
  并加三条断言：① dispatcher 的 `^__` 标签集合 == 清单（双向，多一个/少一个都红点名）；② 任何页面（菜单/组页/
  命令页）不出现清单里的名字；③ `commands.tsv` 的命令名不以 `__` 开头。 · 证据：（待填：✓/✗ 计数）
- [ ] 2.2 红侧：`flip_case` 在 scratch 树的 `scripts/team` 加 `__probe-x)` 标签 → 红点名 `__probe-x`；
  `flip_case` 从 scratch 树的声明清单删一项 → 红点名那一项。 · 证据：（待填：两条红侧日志）

## 3 O6 · 可达性断言（规格 #The help surface is a level-0 menu…）

- [ ] 3.1 `tests/help-surface.sh` 的 `coverage` 组加一条从清单出发的判据：菜单引导段（第一个 `──` 之前的列 2 行）
  点名的组集合 == 清单的 `group` 行集合（双向）；每个命令的组已声明、在菜单里点名、组页列出它、它有页；
  finding 点名那个组与它变成不可达的命令。既有 9 条一条不动。 · 证据：（待填：✓/✗ 计数）
- [ ] 3.2 红侧：`flip_case` 删清单里一条 `group` 行（命令仍声明它）→ 红点名那些命令；`flip_case` 让菜单渲染器
  跳过一组 → 红点名该组命令；还原 → 全绿。 · 证据：（待填：两条红侧日志 + 还原后绿）
- [ ] 3.3（**仅当 PM 裁定 4 收**，否则不写）选段器拒绝未知/已删的组名（今天 `--select layout` 打印
  `check_layout: command not found` 后 rc=0、`--select nosuchsection` 同样 rc=0），并删掉 `check_layout` 这类悬空
  分支；红侧：`--select nosuchsection` 非零并点名。 · 证据：（待填）

## 4 G4 · 未声明占位符判红（规格 #Every behaviour a help page states is declared and probed）

- [ ] 4.1 `scripts/lib/cmd-help.sh`：在一处声明占位符集合（`{project}`、`{meeting_ttl}`、`{token}`、`{sub}`、
  `{cmd}`、`{effect}`、`{faces}`、`{undo_cmd}`）；`team_help_load` 读清单与两张语言表时扫 `{…}` 形状的 token，
  集合外的 → 渲染非零退出并点名 token 与来源表/字段（不打印那一页）；声明了而树里不再用的 → 同样红。
  · 证据：（待填：未声明 token 的报错原文）
- [ ] 4.2 `tests/help-surface.sh`：一条守卫 —— 在 scratch 副本里给某张表加 `{undeclared}`，断言渲染非零且点名
  token 与来源；未改动的树照旧全绿。 · 证据：（待填：✓/✗ 计数）
- [ ] 4.3 红侧（破坏 → 红 → 还原 → 绿）：`flip_case` 把 4.1 的检查删掉 → 4.2 的守卫必红；还原 → 绿。
  · 证据：（待填：红侧日志）

## 5 O7 · CLI 拒绝语去黑话（**仅当 PM 授权边界**，见裁定点 2）

- [ ] 5.1 `scripts/lib/cmd-config.sh` 的 `team_config_write_checked_unlocked`：`refuse` 类键的拒绝语改成普通话
  （去掉「只读键」「控制台」），同批扫同族提示（未知键提示的「手改」等）；退出码、审计行、写入行为一个不改。
  · 证据：（待填：改动前后的报错原文）
- [ ] 5.2 `tests/config-cli.sh` 的 `validate` 组：把 `*"只读"*` needle 换成行为 needle —— 退出码 5、提示里含
  `.pi/team/config.sh`、契约文件 sha 未变。 · 证据：（待填：✓/✗ 计数）
- [ ] 5.3 红侧：`TEAM_CONFIG_TREE` flip —— scratch 树里把 `refuse` 分支改成放行 → `validate` 段红并点名；
  还原 → 绿。 · 证据：（待填：红侧日志）
- [ ] 5.4 若 PM 在裁定点 3 同意：`tests/section-paths.tsv` 的 §51 行补 `scripts/lib/cmd-config.sh`，并用
  `section-select.sh --paths scripts/lib/cmd-config.sh` 复核 §51 在选集里（今天不在：实测选出
  `7b,11h,14b,15c,18b,26,27,28,38,55,56`）。 · 证据：（待填：复核输出）

## 6 G3 · 验收 rc

- [ ] 6.1 交付时把 `tests/spec-refs.sh --check` 与 `openspec validate --all --strict` 一起跑，把 rc 与输出尾贴进
  报告（不补历史记录）。 · 证据：（待填）

## 7 交付前

- [ ] 7.1 `git merge main`（冲突按双方保留；语义冲突停下报 PM）。 · 证据：（待填：merge 输出）
- [ ] 7.2 逐条看「本次相对 main 的删除行」（P261 的教训）：确认没有误删既有断言/红侧/语言表行。
  · 证据：（待填：`git diff main...HEAD --stat` 与删除行清单）
- [ ] 7.3 跑「验收」一节全部命令 + 写报告 + `team notify pm`。 · 证据：（待填：报告路径）

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
