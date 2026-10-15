# help-robustness · 帮助面的收尾：locale 无关的宽度、封闭的内部命令清单、可达性断言、未声明占位符判红

## Why

`cli-help`（帮助面：三级菜单 / 默认英文 / 可切语言 / 数据驱动）已交付并通过独立复验（`docs/team/reviews/V38.md`，
判定 PASS）。复验留下的是**非阻塞观察**，其中四条是合同面或断言面的缺口；另有两条证据缺口在 P277 的交叉勾选里
被发现。它们不是 `cli-help` 原范围的一部分（挂在它上面会让一个已交付的变更永远关不掉），所以单开本变更。

四条观察（本 worktree 实测，数字为度量）：

- **O1 · 非 UTF-8 locale 下排版失真（最实质）**。`team_help_cells` 靠 bash 的 `${s:i:1}` 与 `case` 的
  `$'\uXXXX'` 括号区间量显示宽度，两者都随 locale 变。实测（`bash skills/teamsmith/scripts/lib/cmd-help.sh` 的
  真函数）：

  | 探针 | `LC_ALL=C` | `LC_ALL=C.UTF-8` |
  |---|---|---|
  | `team_help_cells "中文宽字符"` | 15 | 10 |
  | `team_help_cells "a—b·c"` | 8 | 5 |
  | `team_help_char_width '<'` / `'>'` / `'['` | 0 / 0 / 0 | 1 / 1 / 1 |
  | `$'\u0300'` 的字节 | `\u0300`（6 个字面字节） | `cc80` |

  根因是确定的：非 UTF-8 locale 下 bash **不把 `$'\uXXXX'` 编成码点**，区间端点退化成字面字符，于是
  `[\u0300-\u036f]` 里出现 `0`–`\` 这个 ASCII 区间（吞掉数字、大写字母、`<`、`>`、`[`），而 `${s:i:1}` 按**字节**
  切片。后果：`team help dispatch` 在 `LC_ALL=C` 下比 UTF-8 下**少两行、最长行 106 格**（`C.UTF-8` 下 100 格），
  `team help meeting` 最长 120 格；中文面 `TEAM_LANG=zh team help dispatch` 在 `LC_ALL=C` 下输出**不是合法 UTF-8**
  （在字节 555 处截断一个汉字），41 行 vs UTF-8 的 36 行。这不是措辞或版式口味，是「同一输入在不同 locale 下
  给出不同输出」的行为缺陷。

- **O2 · 合同文字不准**。`specs/help-surface/spec.md` 与 `cli-help/design.md` 把「不进帮助面」的唯一例外写成
  `__panel-data`，而 dispatcher 有**两个** `__` 前缀内部入口：`__inbox-write`（`scripts/team` 的注释「内部：
  notify 扩展的收件箱写入口」）与 `__panel-data`（「内部：panel.js 的数据源」）。V38 的旧夹具用**字面**排除
  `panel-data`，于是把 `inbox-write` 判成「dispatcher 接受但清单没记录」而红（V38 §6.3）；新夹具改成按 `__` 前缀
  排除后全绿，但**合同文字仍只写一个例外**。这条不只是措辞：封闭清单不在合同里，就没人管「第三个内部入口悄悄
  出现」这件事。

- **O6 · 可达性断言缺口**。「任何命令都能从菜单经组页在三级内到达」是本变更**唯一**被移走、没有替代品接管的
  断言（`coverage` 组 10 条断言里少的那一条）。V38 的两处变异是干净的反证：**A2**（清单里删掉 `group versions`
  行，命令仍声明它）实测 `✓21 ✗0 rc=0` 全绿；**B**（清单与组页都不动，只让菜单渲染器漏印一个分组）同样
  `✓21 ✗0 rc=0` 全绿。A1（删 `group seats`）偶然红的那一条来自 route 组里写死的 `help seats` 样本，不是可达性
  判据。今天树上没有实际缺陷（没有组行改名、没有命令声明不存在的组、菜单确实列了 8 个组），缺的是**断言**。

- **O7 · CLI 拒绝语里还剩黑话**（来自 V36 的同类观察）。`team config set` 在 `refuse` 类键上写
  `TEAM_PROJECT 是只读键，控制台不改它`（`scripts/lib/cmd-config.sh` 的 `team_config_write_checked_unlocked`），
  同一族的未知键提示还写「自定义键请**手改** …」。用户点名过的词里，「只读键」「手改」都在这条命令行错误里；
  它在 v0.2.0 与候选上逐字相同（不是回退），而 `tests/config-cli.sh` 的 `validate` 组今天**正是**用
  `*"只读"*` 这个 needle 断言它 —— 也就是说，改措辞必须先换掉这条把黑话当合同的断言。

两条证据缺口（P277 交叉勾选时发现）：

- **G4 · 缺断言**。`cli-help` 的 tasks 1.4 要求「未知占位符判红」，但渲染器只解析 `{project}`/`{meeting_ttl}`
  两个已声明占位符，**未声明的 `{…}` 会被原样打印**，报告与 V38 里也没有任何断言盯着它。
- **G3 · 缺 rc 记录**。`cli-help` 8.1 点名的 `tests/spec-refs.sh --check` 在作者报告与复验记录里都没有 rc。

## What Changes

### O1 · 宽度计算与 locale 解耦（行为合同 + 红侧）

渲染器量宽不再借 locale：显式解码 UTF-8 字节到码点，按**码点区间**判宽，`${var:i:1}` 不再承担字符语义
（现状是「单字节 → 宽度 1」，所以 CJK 按 3 格、`<`/`>` 按 0 格）。合同新增一条要求：**同一棵树、同一个
`TEAM_LANG`/`TEAM_HELP_WIDTH` 下，菜单、每个组页、每个命令页在 `LC_ALL=C` 与 `LC_ALL=C.UTF-8`（或
`en_US.UTF-8`）下逐字节相同**，且**每一行都不超过 `TEAM_HELP_WIDTH` 显示格**（计数由夹具自己的 locale 无关
实现给出，不调用渲染器的函数），输出在任何 locale 下都是合法 UTF-8。

红侧：把宽度计算改回 locale 依赖（即今天的实现）→ 新断言必红并点名页与行。

**与 D170 的关系**：这条是**行为**断言（同一输入在不同 locale 下输出相同），不是措辞/排版口味；被 D170 移出
门禁的 `layout` 组（缩进阶梯、页面深度、小节顺序、行宽以外的版式）**不恢复**，一条都不加。`TEAM_HELP_WIDTH`
本来就是一个有文档的机制旋钮（`references/workflows.md` 写明「display cells，CJK 按 2 格」），「每行不超过它」
是这个旋钮的定义，不是版式偏好。

### O2 · 内部命令的封闭清单（可证伪）

合同把「唯一例外 `__panel-data`」改成：**内部入口 = dispatcher 里以 `__` 开头的标签**，这个集合**封闭且在一处
声明**，且必须等于 dispatcher 的 `__` 标签集合 ——

- dispatcher 里出现一个声明表没点名的 `__` 标签 → 红并点名；
- 声明表里的名字不再是 dispatcher 标签 → 红并点名；
- 任何页面**不得打印**内部名，清单（`commands.tsv`）**不得**携带内部名。

红侧：scratch 树里给 dispatcher 加一个 `__probe-x)` 标签 → 红点名；把声明表删一项 → 红。

### O6 · 可达性断言（逻辑类）

在帮助面夹具里加一条从清单出发的可达性判据：**菜单点名的组集合 == 清单的组表（双向）**，且每个命令的组在菜单里
有点名、组页列出了它、它有页；finding **点名那个组和它变成不可达的命令**。

红侧（两条，都不依赖写死样本）：清单里删一条 `group` 行（命令仍声明它）→ 红点名那些命令；菜单渲染器跳过
一个已声明的组 → 红点名该组命令。还原 → 全绿。

### G4 · 未声明占位符判红（补断言 + 补行为）

渲染器把占位符集合在一处声明（`{project}`、`{meeting_ttl}`，以及由调用方替换的 `{token}`/`{sub}`/`{cmd}`/
`{effect}`/`{faces}`/`{undo_cmd}`），加载清单与两张语言表时扫 `{…}`：**集合外的 token 不打印，渲染非零退出并
点名 token 与它来自哪张表/哪个字段**；声明了而树里不再用的占位符同样红（双向）。

红侧：scratch 树里给某张表加 `{undeclared}` → 渲染非零并点名；把渲染器的检查去掉 → 夹具的守卫必红（破坏 →
红 → 还原 → 绿）。

### O7 · CLI 拒绝语去黑话（措辞 + 行为判据，不带 delta 文字）

`refuse` 类键的拒绝语改成普通话（例如「这个键只能改项目配置文件 `.pi/team/config.sh`，控制台不能改」），同批
扫同族提示（未知键提示里的「手改」）。判据是**行为**：拒绝仍发生、退出码不变（`refuse` 类 = 5）、**提示里含
配置文件路径**、什么都不写；措辞由评审把关（D170）。因此 `tests/config-cli.sh` 里那条 `*"只读"*` needle 必须
换成行为 needle（rc + 路径 + 未写入），**不是**换一个词继续把措辞当合同。

### G3 · 验收 rc

交付时把 `tests/spec-refs.sh --check` 与 `openspec validate --all --strict` 一起跑并**贴 rc**（本任务的验收行，
不补历史记录）。

## Capabilities

### Modified Capabilities

- `help-surface`：**MODIFIED** 两条已归档的要求 + **ADDED** 一条新要求。
  - `The help surface is a level-0 menu, a page per group and a page per command`（MODIFIED）：O2 的封闭内部清单、
    O6 的可达性判据（含两条新场景）；基线三段散文与 4 条场景逐字保留，只增不改。
  - `Every behaviour a help page states is declared and probed`（MODIFIED）：G4 的占位符封闭集合与「未声明即失败」
    （含 1 条新场景）；基线段落与 3 条场景逐字保留。
  - `The surface's layout is the same in every locale, and never exceeds its width`（ADDED）：O1 的行为合同与两条
    场景。
- **O7 不写 delta 文字**，理由写在 `design.md` 的决策 5：它的行为合同（拒绝 + 退出码 + 点名路线）已经活在
  `panel#The console shows the project contract with its effect class, and refuses what it must not change`
  （`refuse` 行的交互「surface the owning command's refusal, which names the right route」）与 `config-cli.sh` 的
  `validate` 组里；本变更只改**措辞**并把那条把黑话当合同的 needle 换成行为 needle。给措辞补一条规格要求，等于
  把 D170 明说交给评审的东西写成门禁合同。若 PM 要它成为规格，落点是 `panel`（那条路线合同的家），本变更的
  `deltas:` 行要相应加一项 —— 见「需要 PM 裁定的点 2」。
- **G3 不写 delta 文字**：它是验收/证据行，不是合同；为它立一条要求就是第二套规格系统。

## Impact

- 产品面：`skills/teamsmith/scripts/lib/cmd-help.sh`（宽度/折行/占位符校验）、
  `skills/teamsmith/scripts/lib/cmd-config.sh`（O7 的拒绝语与同族提示）。
- 夹具面：`skills/teamsmith/tests/help-surface.sh`（新 `locale` 组 + coverage 组两条断言 + 占位符守卫 + 新红侧）、
  `skills/teamsmith/tests/config-cli.sh`（O7 的行为 needle）、`skills/teamsmith/tests/smoke.sh` §51（新组进选集）、
  `skills/teamsmith/tests/section-paths.tsv`（路径登记，见裁定点 3）。
- 规格面：`openspec/changes/help-robustness/specs/help-surface/spec.md`（2 MODIFIED + 1 ADDED）。
- 不改：命令名/旗标名/退出码、`--print`/`--json` 字节、语言机制、`references/**` 与 README、面板。
- 不削弱：Walk A 的强度与解析器规则、承诺探针、控制臂、既有 10 条翻转一条不动；`layout` 组不恢复。

## 需要 PM 裁定的点

1. **`cli-help` 的归档提交还没落到 main 上**。本分支（起点 = main 的 tip）里
   `openspec/specs/help-surface/spec.md` **不存在**，`openspec/changes/cli-help/` 仍是活动变更；PM 的工作树里有
   43 条未提交的归档改动（四份 `archive/2026-10-15-*/`、`openspec/specs/help-surface/spec.md` 与三条
   `openspec/specs/*` 的修改、四个活动 change 目录的删除）。任务书的 `deps:` 写「cli-help 已归档」，事实是
   **磁盘上已归档、git 里未提交**。本提案的 delta 按**归档投影后的文本**写（我在 scratch 副本里
   `openspec archive -y cli-help` 核对过：投影出 `# help-surface Specification` + 四条要求，标题与基线逐字一致），
   所以内容是对的；但 **apply 之前 PM 必须先把归档提交到 main**，否则 apply 分支上 MODIFIED 的基线不在树里，
   `team dispatch` 的锚点解析与归档时的替换都会落空。
2. **O7 的两条路径不在任务书边界里**。任务书写「只碰帮助面（`scripts/strings/*`、`lib/cmd-help.sh`、
   `tests/help-surface.sh`、`routes.sh` 里属于帮助走查的部分）」，而 O7 必须改
   `skills/teamsmith/scripts/lib/cmd-config.sh` 与 `skills/teamsmith/tests/config-cli.sh`。**推荐**：把这两条路径加进
   边界（措辞改动本身仍由评审把关，不带 delta 文字）；替代方案是把 O7 拆成独立任务/变更。若选拆出，本变更
   范围只剩 O1/O2/O6/G4/G3，`deltas:` 不变。
3. **§51 的路径登记缺 `cmd-config.sh`**（门禁覆盖缺口，实测）。`bash tests/section-select.sh --paths
   skills/teamsmith/scripts/lib/cmd-config.sh` 选出 `7b,11h,14b,15c,18b,26,27,28,38,55,56`，**不含 §51**；而 §51
   正是跑 `config-cli.sh list validate roster` 的段（`config-cli.sh` 在 §51 的路径表里，`cmd-config.sh` 不在）。
   于是改 `cmd-config.sh` 不会让那条断言重跑。**推荐**：把 `skills/teamsmith/scripts/lib/cmd-config.sh` 加进 §51 的
   路径表（改完用 `section-select.sh --paths` 复核 §51 在选集里，并跑 `tests/section-needs-audit.sh` 看它认不认）。
   这是夹具/登记改动，属 `tests/**`（dev 面），需要 PM 在 apply 任务书里明授。
4. **O6 的「卫生」半条是否收**（本提案**未**纳入合同，因为任务书 O6 只要求可达性断言）：`--select layout` 今天
   打印 `check_layout: command not found` 后 **rc=0（✓0 ✗0）**，`--select nosuchsection` 同样 rc=0 —— 「选段名拼错
   或过期 → 静默全绿」。**推荐**：顺手收（选段器拒绝未知名字 + 删悬空分支），它是一条假绿口子，与本变更动同一个
   夹具；但它不是帮助面的合同，所以要么写进 apply 任务书当夹具卫生项，要么留给后续任务。
5. **O1 的宽度上界要不要进门禁**。本提案按任务书原文把「每行 ≤ `TEAM_HELP_WIDTH` 显示格」写成合同的一条场景。
   如果 PM 认为它仍属 D170 的排版类，正确的最小形态是只留「不同 locale 逐字节相同 + 合法 UTF-8」，把行宽上界
   降为评审项。**推荐保留上界**：它由渲染器自己的折行保证，是宽度旋钮的定义（不是阶梯/深度/措辞），且它是
   O1 最便宜的红侧之一。

## Acceptance（apply / verify 执行；本阶段只读地跑基线与两条 rc）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/help-surface.sh --all
bash skills/teamsmith/tests/help-surface.sh --flip            # 含本变更新增的红侧
bash skills/teamsmith/tests/routes.sh
LC_ALL=C bash skills/teamsmith/tests/help-surface.sh --select locale   # 与 UTF-8 下逐字节对照
bash skills/teamsmith/tests/config-cli.sh list validate roster         # O7 的行为 needle
bash skills/teamsmith/tests/spec-refs.sh --check                       # G3：贴 rc
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/cmd-config.sh
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

## Out of scope

- 不恢复被 D170 移出门禁的 `layout`/`scale`/`content` 三组（缩进阶梯、页面深度、第 0 级行数、小节顺序、措辞）。
- 不翻译 `scripts/lib` 其余中文消息；不改 `references/**`、README、SKILL.md、面板与语言表内容。
- 不改命令名/旗标名/退出码/机器出口字节；不删既有红侧；不引新依赖（仍 bash + awk，夹具的独立计数用已有 python3）。
- 不为 O7 补规格要求（见 Capabilities 与裁定点 2）。
