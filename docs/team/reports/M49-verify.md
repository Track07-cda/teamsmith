# M49 · 项目设置的 key 要 i18n：列表显示人话标签，不显示裸 `TEAM_*`

agent: verify   status: DONE   time: 2026-09-20T07:10Z
branch: `task/M49-key-i18n`   PR/MR: -（local 模式：不 push；分支留在 `.worktrees/verify`，PM 复验后本地合并）
change: `console-project-settings`（phase: apply —— 已验收 change 上的一次有记录收口返工；delta 已同步，等 PM 归档）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/panel/src/strings/{zh,en}.ts` | schema 的 **108 个键各一条人话标签**（`label_TEAM_*`，zh/en 键集一致非空）+ 三条 CLI 对齐文案：`settingsCliHint`（命令行）、`settingsRefusedHint`（只读手改路线）、`settingsUnknownHint`（未知键） |
| `skills/teamsmith/scripts/panel/src/strings/index.ts` | `keyLabel(s, name)`：按**命令报来的键名**查表；查不到（schema 不认识的键）回退**原始键名**。静态查表，渲染路径不读文件 |
| `skills/teamsmith/scripts/panel/src/layout.ts` | 行的主文本改成标签（`cell(keyLabel(...), SETTINGS_LABEL_W=22)`，座位行同列）；视图底部多一行「当前焦点行怎么在命令行里写」的提示（`team config set <KEY> <value>` / 只读手改 `<KEY>` / 未知键点名）；过滤匹配**标签 + 原始键 + 值**；`SETTINGS_FOOTER_ROWS` 把多出来的一行算进行预算 |
| `skills/teamsmith/scripts/panel/panel.js` | bun 1.3.14 重建（941164 字节，sha256 `a830ca2f93343f95a8d4213f2188c5627840ae7ff22f08d911782f1a901cb790`），与门禁沙盒重建逐字节一致 |
| `skills/teamsmith/tests/panel-strings.mjs` | 新第 4 条断言：schema 每个键在 zh/en 都要有非空标签（**两个方向**：缺标签、schema 删行后留下的陈旧标签），标签不能是键名的变体，且不超标签列宽 |
| `skills/teamsmith/tests/smoke.sh` | 28-a2：上面的断言进**门禁**，并带两条翻转（两张表各删一条标签 → 红；schema 删一行 → 陈旧标签被抓） |
| `skills/teamsmith/tests/panel-p21.sh` | settings 场景改到标签世界（23→36 条断言）：标签/徽章/未设/注释、**原始键搜索仍能找到**、**未知键回退**、聚焦行的 CLI 提示、点击按标签认行（原始键从提示行读）、en 语言一趟；conflict 场景两条行断言跟随 |
| `openspec/changes/console-project-settings/specs/panel/spec.md` | 那条 requirement 改写成「行=字符串表的人话标签；原始键只在与 CLI 对齐处出现；未知键回退原始键」，新增 4 个 scenario，2 个既有 scenario 的措辞同步（**只动这份 delta**） |
| `docs/team/reports/M49/pkg/**` | 可重跑的证据包（`10` 断言+翻转、`20` 真帧实录、`30` 门禁）、帧、门禁日志 |

## Verification evidence (must have actually been run)

### 1) 验收命令（brief 的 Acceptance 两件套）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
- Validating...
✓ spec/agent-adapters … ✓ spec/watchdog
Totals: 15 passed, 0 failed (15 items)                    # 完整输出：pkg/logs/openspec.log

$ bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2365  ✗ 0
smoke 全绿                                                 # 完整输出：pkg/logs/smoke-full.log

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1876  ✗ 0
smoke 全绿                                                 # 完整输出：pkg/logs/smoke-fast.log
```

新断言在门禁里的位置（`smoke-fast.log`，28-a2 是本次新增、两条翻转是常驻的）：

```
  ✓ 28-a2 契约键标签：schema 的每个键在 zh/en 两张表里都有标签（108 schema keys）
  ✓ 28-a2 翻转①：两张表都删掉 label_TEAM_PULSE_INTERVAL 后断言非 0 且点名该键
  ✓ 28-a2 翻转②：schema 删掉一行后，留下的标签被抓住（点名 TEAM_MEETING_KNOCK）
```

第一次跑快门禁抓到的两条红（都已修，**这就是门禁的价值**）：`26-a bundle：重建后与提交的 bundle
不一致`（我在缩短三条 en 标签后忘了重建 `panel.js`）与 `M28 真树有未隔离的 tmux 变更命令`
（证据包的 tmux shim 用了绝对路径 `/usr/bin/tmux`，撞上 M41 那条红线）。修完：26-a 逐字节一致、
`tmux-lint.pl` 红 0 条。

### 2) 交付物 4 的完整性断言与两条翻转（可重跑：`pkg/10-strings-flip.sh`）

```
$ node skills/teamsmith/tests/panel-strings.mjs .
ok: zh/en key sets compared (308 keys)
ok: values are non-empty strings with matching placeholders
ok: no CJK literals outside src/strings/**
ok: contract-key labels — 108 schema keys covered in zh and en
panel-strings: ok

# 翻转 A：从**两张表**各删 label_TEAM_PULSE_INTERVAL（键集合仍一致 → 只有这条断言能抓住）
✗ panel-strings failed:
  zh: no label for schema key(s) [ TEAM_PULSE_INTERVAL ]
  en: no label for schema key(s) [ TEAM_PULSE_INTERVAL ]      → rc=1

# 翻转 B：schema 里删掉 TEAM_MEETING_KNOCK 一行（表不动 → 反向断言必须抓住）
✗ panel-strings failed:
  zh.label_TEAM_MEETING_KNOCK names no schema key (stale label)
  en.label_TEAM_MEETING_KNOCK names no schema key (stale label) → rc=1

# 还原后：同一条命令再跑仍然绿（panel-strings: ok）
```

翻转 A 的键集合仍是 307/307（zh 与 en 一起删），所以它**不可能**被既有的「键集一致」那条抓住——
红的必须、且确实来自新的第 4 条断言。

### 3) 交付物 2 的手工实录：真实 pty 上的帧（zh 与 en，`pkg/frames/`）

夹具：私有 tmux socket + 真 `team init` + 真 CLI + 真 `panel.js`，160×40 真 pane（`pkg/20-frames.sh`）。

zh（`frames/zh-restart.txt`，`/` + `TEAM_PULSE_INTERVAL` 过滤）：

```
│ › 巡检周期               900 · 需重启  # patrol nudge (fixture)
│  命令行：team config set TEAM_PULSE_INTERVAL <新值>
```

zh 只读键（`frames/zh-refuse.txt`）：

```
│ › 项目名                 root · 只读  身份：手改 .pi/team/config.sh（或重新 team init）
│  只读：手改 .pi/team/config.sh 里的 TEAM_PROJECT
```

zh 未知键回退（`frames/zh-unknown.txt`，文件里手加的 `TEAM_HAND_ADDED`）：

```
│ › TEAM_HAND_ADDED        hand · 未知键  不是已知的项目设置（见 references/config.md）；手改 .pi/team/config.sh
│  未知键：TEAM_HAND_ADDED 在文件里，命令的 schema 不认识
```

en（`frames/en-restart.txt`，同一台夹具里把语言偏好切成 `en` 后重开视图）：

```
│ › Patrol interval        900 · restart  # patrol nudge (fixture)
│  CLI: team config set TEAM_PULSE_INTERVAL <value>
```

即：**行的主文本是标签**（zh/en 各一段），**要执行哪条命令的文案里点名原始键**；`panel.conf` 里
`lang=en` 是切过来的真偏好（不是帧里的巧合）；整段只读（`state/config.log` 一行没长）。

### 4) 视图夹具（`panel-p21.sh`，brief 未要求但 P22 的桩）

```
$ bash skills/teamsmith/tests/panel-p21.sh settings
== 结果 ==  ✓ 36  ✗ 0        （M49 之前是 23 条断言；新增 13 条：标签/提示/原始键搜索/未知键/en）
$ bash skills/teamsmith/tests/panel-p21.sh
== 结果 ==  ✓ 92  ✗ 0        （完整日志 pkg/logs/p21-all.log；settings 36 / write 23 / conflict 6 / seats 22 / readonly 5）
```

`seats` 场景在本任务期间**间歇**红过一次同一条断言（“拒绝用例没能把焦点移到 dev 席位行”）：
M49 的 bundle 红过一次、换回 M49 之前的 bundle（`119af6f9…`）也能复现，随后全套重跑又绿 → 见 Finding F1
（既有间歇 red，与标签改动无关）。

### 5) 性能边界（brief：契约不变，标签是静态查表）

`panel-cpu.sh`（真 pane，60s 采样）在**本机当前负载**（loadavg ≈ 11–12，另有两个项目在跑）下贴线：

| 运行 | bundle | 面板进程 | 首帧 | 判定 |
|---|---|---|---|---|
| 空转 | M49 | 1.064% | 2041ms | RED（CPU 贴线 + 首帧超 41ms） |
| 设置视图开着 | M49 | 0.982% | 2440ms | RED（首帧；CPU 仍在 1% 以内） |
| 空转（对照） | M49 之前 `119af6f9…` | 1.082% | 在预算内 | RED（CPU） |
| 设置视图开着（对照） | M49 之前 | 0.799% | 在预算内 | OK |

即：两种 bundle 都会在 0.8–1.08% 这条线两侧跳——**空转路径（根本不渲染 settings 块）也会红**，
所以红来自机器负载，不是标签查表；门禁自己的性能断言（`27-d` 装配中位 < 2s）在完整 smoke 里全绿。
日志：`pkg/logs/panel-cpu{,-view,-old-idle,-old-view}.log`（对照跑完自动还原 bundle，sha `a830ca2f93343f95…`）。

### 6) 交付物 5：delta 只改了一份
`openspec/changes/console-project-settings/specs/panel/spec.md`：

- requirement 正文：行的人话标签来自 zh/en 表（每键非空，门禁两个方向都断言）；**裸键不得作为行的主文本**；
  原始键只出现在「与命令行对齐处」（编辑器标题、确认行、视图底部那行命令/手改路线/席位命令）；
  未知键没有标签也**不许编**，回退原始键；bundle **不得带第二张 schema**（键的类/默认/顺序仍来自命令）；
  过滤匹配标签、原始键或值。
- 新增 scenario：`The raw key is exactly where the CLI is named`、`A search by the raw key still finds the
  row`、`A key the schema does not know falls back to the raw name`、`The string tables cover the command's
  schema, both directions`；既有 `The rows carry the three classes…`（补「主文本是标签」）、
  `The row set and the classes come from the command…`（补「无标签→原始键」）、`The filter narrows and clears`
  （`label, raw key or value`）同步改措辞。
- `openspec validate --all --strict`：15 项全过（`pkg/logs/openspec.log`）。

### 7) 实现翻转（break → 断言红 → restore 绿，可重跑：`pkg/15-render-flip.sh`）

| 翻转 | 把实现破坏成 | `panel-p21.sh settings` | 还原后 |
|---|---|---|---|
| A 行身份 | `seg(cell(keyLabel(s, row.name), …))` → `seg(cell(row.name, …))`（行主文本回到裸键） | `✓ 23 ✗ 14`（标签/徽章/未设/注释/按标签搜索/点击/en 全覆盖） | `✓ 36 ✗ 0` |
| B CLI 提示 | 删掉底部 `settingsCliHint` 那一行（视图不再点名原始键） | `✓ 27 ✗ 10`（命令提示/只读手改路线/未知键提示/en 提示） | `✓ 36 ✗ 0` |

红侧共 24 条断言，逐条点名被破坏的行为，例如 `✗ restart 行的标签 + 需重启 徽章（…没有匹配 [巡检周期 +900 · 需重启]）`、
`✗ 行里不再出现裸键 TEAM_MODEL_LIMITS`、`✗ CLI 提示行点名原始键（…找不到 [命令行：team config set TEAM_PULSE_INTERVAL <新值>]）`。
还原核验：`layout.ts` 与 `panel.js` 与 HEAD 逐字节一致（sha `a830ca2f93343f95…`）。
日志：`pkg/logs/flip-{A-bare-key,B-no-cli-hint}{,-restored}.log`。

## 覆盖表（brief 交付物 → 实现 → 能红的夹具 → 翻转）

| brief | 实现 | 能失败的证据 | 翻转 |
|---|---|---|---|
| 1 标签进字符串表（每键 zh+en，人话） | `strings/{zh,en}.ts` 108×2（`label_TEAM_*`） | `panel-strings.mjs` 第 4 条；`pkg/10`；smoke 28-a2 | 删一条标签 → 红并点名（A）；schema 删一行 → 陈旧标签红（B） |
| 2 列表渲染改成人话标识 | `layout.ts` `settingsKeyLine` + `keyLabel()` | `panel-p21.sh settings`：`› 巡检周期` / `› 项目名`；帧实录 | 翻转 A（`keyLabel()` 换回 `row.name` + 重建）→ `✓ 23 ✗ 14`，逐条点名 |
| 2 CLI 对齐（编辑提示/命令文案点名原始键） | 编辑器标题（既有）+ `settingsCliHint/RefusedHint/UnknownHint` + 确认行（既有） | p21：`命令行：team config set TEAM_PULSE_INTERVAL <新值>`、`只读：… TEAM_PROJECT`、点击第二条断言（原始键从提示行读） | 翻转 B（删掉提示行 + 重建）→ `✓ 27 ✗ 10` |
| 3 搜索匹配标签/原始键/值 | `settingsViewRows` 的 `match(keyLabel(...), k.name, k.value, …)` | p21：`按标签搜到该行`、`按原始键 pulse 仍能找到` | 翻转 A 里同时红（`按标签搜到该行` / `按原始键 pulse 仍能找到`） |
| 4 完整性断言（可证伪） | `panel-strings.mjs` 第 4 条 + smoke 28-a2 | `pkg/10`、smoke 输出 | A/B 两条（见上） |
| 5 delta 同步（含两条新 scenario） | `specs/panel/spec.md` | `openspec validate --all --strict`；p21 与包 20 的场景与 scenario 一一对应 | —（文档；可观察面由 p21 断言覆盖） |
| 边界：性能契约不变、渲染路径不读文件 | `keyLabel()` 静态查表（对象查键） | 无新增 IO；`panel-cpu.sh` 在 p21 之外（P22 已钉，M49 未改渲染结构） | — |
| 边界：`panel.js` 改了要重建 | 重建 sha `a830ca2f…` | smoke 26-a 沙盒重建逐字节比对 | 不重建（我第一版就是）→ 26-a 红，门禁自己抓住 |

## 刻意决定（写清并说明）

1. **未知键回退显示原始键**（brief 要求）：`keyLabel()` 查不到就返回键名本身——行不会没有名字，
   而且那个名字正是文件与命令里的名字。帧实录里 `TEAM_HAND_ADDED` 一行同时给了「未知键」徽章和
   「未知键：… 命令的 schema 不认识」的提示行。
2. **标签表不是「第二张 schema」**：表里只有键→标签的映射，没有类、默认值、顺序；行集/类/默认仍来自
   `team config list --json`。schema 新增键时仍然「不重建 panel.js 就出现」（scratch 夹具里
   `TEAM_ZZZ_TEST` 一行是原始键文本 + 它自己的默认值/徽章）。这也是把 delta 里「MUST NOT carry a
   second key table」改写成「MUST NOT carry a second **schema**」的原因：原措辞在 M49 后自相矛盾。
3. **标签列 22 格**：zh 标签最长 19 格（`openspec 可执行文件`）、en 最长 21 格；超过就被 `cell()` 截断，
   所以 `panel-strings.mjs` 里连同标签宽度一起断言（超宽的标签直接红）。
4. **行内注释照旧不翻译**：它是契约文件那一行的原文（脚手架模板里是英文注释）。brief 明说「该行自己的
   行尾注释，这几样照旧」，M49 不动文件字节 → 见 Finding F2（记录，不修）。

## Findings（交回 PM）

**F1（既有间歇 red，不属于 M49，未修）** `panel-p21.sh seats` 的「拒绝用例没能把焦点移到 dev 席位行」：

- 三次运行：① M49 bundle 全套 → 该条红（`✓ 22 ✗ 1`）；② 换回 M49 之前的 bundle（`git show 227eb99:…/panel.js`，
  sha `119af6f9…`）单跑 seats → **同一条红**；③ M49 bundle 全套重跑 → 绿（`✓ 92 ✗ 0`）。
- 机制（初判，两次红的帧形状一致）：视图的焦点是**筛选后列表的下标**；`filter_to dev` 把
  `TEAM_AGENT_MODELS` 一行匹配进来是因为它的**值**含 `dev`，移除覆盖后值变空 → 该行退出列表 → 同一个下标
  落到下一行（`dev2`）；夹具的 `focus_row` 只会向下走，于是找不到在上面的 `dev` 行（帧：`removed.txt`
  还有该行，`shapeless.txt` 里它消失且光标在 `dev2`）。
- 归属：P22 的视图状态机（`settingsFocus` 是下标而不是行的身份），不是 M49 的标签改动；M49 只改了行文本、
  提示行与列宽。**M49 的验收门禁（openspec + smoke）不含 panel-p21.sh**，所以它不阻塞本次交付；
  但它是间歇回归信号，建议 PM 另派（或归档前决定接受）。

**F2（记录，非缺陷）** 行的行尾注释仍是契约文件里的原文（模板里是英文），落在中文界面里显得混语言。
brief 明确「照旧」，M49 未动；若要 i18n 注释，需要改的是模板/契约文件（PM 所有），不是面板。

## 未做的事 / 边界

- 没改 schema 的键名/语义、没改写入门面（`team config set` 仍收原始键）、没碰 `--print`/`--json`：
  机读出口字节不变的证据在门禁里——`26-a bundle：沙盒里重建逐字节一致（941164 字节）`、
  `26-c 纯文本：--print 退出 0 且 0 个 ESC 字节`、`26-d JSON：一个对象，含 panel 与 activity`、
  `28-c 快照：4 档宽度 × 2 主题 + 60x8 极小 pane 全部逐字节一致`（完整日志 `pkg/logs/smoke-full.log`）。
- 没碰 M47/M48 动的文件区域；`openspec` 只改了本次 change 的 delta（`openspec/specs/**` 未动）。
- 没修 F1（越界：P22 的视图状态机），按协议写进报告交回 PM。
- **改动落点与 OWNERSHIP**：`skills/teamsmith/tests/**` 在 OWNERSHIP 里记在 `agent:dev` 名下，本次任务
  书（交付物 4 的断言 + 交付物 5 的 delta）要求它，且没有另派 dev；本次由本 agent 一次性落地，
  请 PM 在复验时确认或另行归口。除这一处外未碰到 PM 独占目录（`scripts/panel/src/**` 是交付物 1–3
  的落点，同样是任务书明授的实现面）。
