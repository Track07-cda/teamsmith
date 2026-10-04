# P32 · settings-view-groups 修订：分组标题可辨识 + 视图用满窗口高度（apply + delta 修订）

```
task:    P32
agent:   dev-bob
branch:  task/P32-p32（local 模式：不 push；分支留在 .worktrees/dev-bob，PM 复验后本地合并）
change:  settings-view-groups（phase: apply + 本 change 的 delta 修订；P31 的 verify 验的是**修订前**的
         tip，本修订按任务书要求另行复验）
specs:   panel#The settings view groups the contract by the functional group the command reports, and
         carries the effect class on the row（补 1 个 scenario：标题是分节线、标题自己承担组间分隔）/
         panel#The settings view fills the pane it is given and its row window grows with it（**新增** requirement）
deltas:  panel（既有 ADDED requirement 补 scenario ×1 + 新增 ADDED requirement ×1；base scenario 一个没删）
设计真源: openspec/changes/settings-view-groups/design.md（本次修订写进 §9，含 D9/D10 与「16 行去哪了」的算式）
commits: 4b47a1a（layout：分节线标题 + 计价表修正 + 尾部实测预算 + 卡片填满；bundle 重建）
         c03dacb（panel-p21：标题/分隔断言 + 45/33/30/25 四档高度断言 + 行数记账断言）
         2330a7e（panel delta 修订 + design §9 + proposal 修订段）
         f5f2e2d（settings 块注释 + docs/team/reports/P32/ 证据包：measure.ts / metrics.txt / 前后原始渲染）
         91e08cd（picker 条目窗口回到 M55 标定值（全量 smoke 38-b 的回归）+ 可复跑翻转包 flip.sh）
         6ed7b43（本报告）· <F1：smoke §38-f + design D7 + 报告 §8>
status:  完成（主交付：openspec 16/16 · panel-p21 groups/settings/wheel ✓102 ✗0 · FAST ✓2301 ✗0 ·
         全量 ✓2810 ✗0（38-f 之前）· choices 回归段 ✓182 ✗0 · tsc rc=0 · bundle 两次构建逐字节一致 ·
         git status 干净；F1 已收口：§38-f 接入全量门禁（FAST 可见 SKIP，28 段），改前 811s / 改后 960s
         （✓2811 ✗0），增量 ≈2.5 分钟 <3 分钟，见 §8）
```

## 0. Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/panel/src/layout.ts` | ① 分组标题改成**分节线**（`ruleTitle(label, width, tone)`），标题行不再与键行同形；② 窗口计价表改成「一行一条 + 标题在自己行」，删掉 D5 的 `rowLines()` 两行计费；③ 尾部改成**实测**（`1 hint + 1 空 + 1 审计标题 + ≤3 审计行`），两条 `↑/↓` 计数只是**上限**，没用掉的那行还回窗口（只向下长，不动滚轮 offset）；④ 卡片把没用掉的高度补在**卡片内部**（行列表 + 两个 picker 都补），键栏仍是最后一帧行；⑤ 装配处交给视图的是**内部整块**预算（不再预扣尾部）；⑥ 两个 picker 的**条目窗口**保持 M55 标定的 `SETTINGS_TAIL_ROWS`（长词表仍是分页的，见 §7 备注 2） |
| `skills/teamsmith/scripts/panel/panel.js` | 重建（两次构建逐字节一致，sha256 `c18ded751accc6d973aafcaba99e261ebcfb1cc80d46786c9140d7d4df45b799`） |
| `skills/teamsmith/tests/panel-p21.sh` | `groups`：标题是分节线 / 键行不带分节线 / `assert_heading_rule`（标题夹在上组最后一条与本组第一条之间）/ 降级组与席位标题同形；标题行匹配改用新的 `cap_line_heading`（`cap_line_exact` 对标题不再成立，已删）；`settings`：`resize_panel` + `wait_settings_frame` + `settings_window_stats`，在 120×45/33/30/25 四档断言「卡片下边框到键栏 ≤1 行空白」「rows + ↑N + ↓N = 命令报的键+席位」「45 行比 30 行多画 ≥8 行」，并断言「过滤到一条时卡片仍填满」 |
| `skills/teamsmith/tests/smoke.sh` | **§38-f（F1 返工项，PM 裁定）**：全量门禁里新增 `panel-p21.sh groups settings wheel` 的调用点（照 38-b 的写法：FAST 下 `fast_skip` **可见 SKIP** 带原因，慢段只在全量跑；失败时打 ✗ 清单）；38-e 的注释补上「38-f 就是那个调用点」；design D7 的宣称随之成真 |
| `openspec/changes/settings-view-groups/specs/panel/spec.md` | 既有 ADDED requirement 补 scenario「A heading is a section rule and it separates its own group」；新增 ADDED requirement「The settings view fills the pane it is given and its row window grows with it」（2 个 scenario）；base scenario 未删 |
| `openspec/changes/settings-view-groups/design.md` | §9 修订段：测量、逐项算式、D9/D10、B1 的关系、前后对照表、夹具与红侧 |
| `openspec/changes/settings-view-groups/proposal.md` | 修订段（日期 + 原因 + 用户反馈原文引用 + 影响面） |
| `docs/team/reports/P32/` | `measure.ts`（可从 layout 源码直接渲染并算行数账，`P32_SRC` 指向旧树得到「前」列）、`metrics.txt`（前后两列原始输出）、`before-*.txt` / `after-*.txt`（45/33/25 原始渲染）、`flip.sh`（可复跑的翻转包，见 §3） |

**未改**（无授权 / 无必要）：`strings/{zh,en}.ts`（标题词一个没动）、`App.tsx`（焦点/滚轮语义不变）、
`cmd-config.sh`、`references/config.md`、`tests/smoke.sh`（FAST 结构钉仍绿）、`CHANGELOG.md`（见 §7 备注 1）。

## 1. 先给数字：「16 行去哪了」

用户实测（120×45，真实项目）：「内容到第 27 行就结束，28–43 共 16 行空白」。用仓库自己的契约读数
（`team config list --json`：111 个 schema 键 + 6 个席位 = **117** 条可聚焦行）在宽 120 复现，得同一现象。
**修订前**，45 行的账逐项如下（`layout.ts:1166` 是修订前的 `SETTINGS_FOOTER_ROWS`）：

| # | 项 | 预留/花了 | 说明 |
|---|---|---|---|
| 1 | 页面预算 | 42 行 | `45 − 2`（标题带 + 页签）`− 1`（键栏） |
| 2 | 卡片边框 | 2 行 | 装配处 `framed ? 2 : 0` 先扣掉，块只剩 **40 行** |
| 3 | `SETTINGS_FOOTER_ROWS` | 8 行 | `SETTINGS_COUNT_ROWS(2) + CLI 提示(1) + 空行(1) + 审计标题(1) + SETTINGS_AUDIT_LINES(3)`，所以窗口只拿到 `40 − 8 = 32` **模型行** |
| 4 | 窗口计价（D5 的 `rowLines()`） | 32 行 | 每一条 `warning ∥ route ∥ comment` 非空的键行按 **2 行**计费 |
| 5 | 窗口实际画出 | 17 行 | `1 标题 + 12 identity 行 + 1 标题 + 3 branch 行`——注释段是 push 到**同一行**的 `Line` 上，一行就是一行，所以 32 行买到的其实是 17 行：**15 行是虚账** |
| 6 | 尾部实际画出 | 7 行 | `↓102(1) + 提示(1) + 空行(1) + 审计标题(1) + 审计 3 行(3)`；窗口在顶部，`↑` 那行（预留 1）根本没画：**1 行白留** |

`15 + 1 = 16` —— 与用户数到的 16 行**逐行对上**（卡片下边框第 28 行，键栏第 45 行）。

其它高度的同一分解（都是修订前）：33 行 = 虚账 9 + 装不下的模型行 1 + 白留 1 = 11；25 行 = 5 + 1 + 1 = 7。
即：**D5 注释里「带注释的行画两行」这句前提本身是错的**（它加进来的「标题各占一行」那一半是对的，保留）。

## 2. 前后对照（同一 fixture、同一宽度、只改高度）

`docs/team/reports/P32/metrics.txt` 的原始输出（前 = `P32_SRC` 指向 3226ac0 的源码树，后 = 本分支；
fixture = 上面那条 117 行的契约读数，宽 120；`bash skills/teamsmith/scripts/team config list --json > /tmp/settings.json`
即可复跑）：

```
=== BEFORE (P32_SRC = commit 3226ac0, the revision's parent tree) ===
height | rows | count | cardTop cardBottom interior | lastContent footer gap
    45 |   15 |   117 | 3 28 24 | 28 45 16
    40 |   12 |   117 | 3 24 20 | 24 40 15
    33 |    9 |   117 | 3 21 17 | 21 33 11
    30 |    8 |   117 | 3 20 16 | 20 30 9
    25 |    5 |   117 | 3 17 13 | 17 25 7

=== AFTER (worktree) ===
height | rows | count | cardTop cardBottom interior | lastContent footer gap
    45 |   30 |   117 | 3 44 40 | 44 45 0
    40 |   25 |   117 | 3 39 35 | 39 40 0
    33 |   19 |   117 | 3 32 28 | 32 33 0
    30 |   16 |   117 | 3 29 25 | 29 30 0
    25 |   12 |   117 | 3 24 20 | 24 25 0
```

| 面板高度 | 画出的行数 | 内容→键栏空白 | 窗口随高度的增长 |
|---|---|---|---|
| 45 | 15 → **30** | 16 → **0** | — |
| 33 | 9 → **19** | 11 → **0** | — |
| 30 | 8 → **16** | 9 → **0** | 45 比 30 多 **14 行**（修订前只有 7 行，达不到任务书要求的 ≥8） |
| 25 | 5 → **12** | 7 → **0** | — |
| 40（夹具默认） | 12 → **25** | 15 → **0** | — |

真进程夹具（120 列、另一条 115 行契约、审计日志为空 → 尾部 1 行）复测得同一组性质（§5 门禁输出）：
45 行画 32 行、33 行 21、30 行 18、25 行 13，四档空白都是 0，`rows + ↑ + ↓` 恰好 = 115。

## 3. Flip evidence（故意破坏实现 → 守卫断言必须红 → 还原后绿）

**独立翻转包**：`docs/team/reports/P32/flip.sh`（不复用实现者的任何断言脚本；每个翻转都在**一次性
`git worktree`** 里改源码 + 重建 bundle + 跑真 pty 夹具，绝不写本检出；用完 `worktree remove` 清掉）：

```
$ bash skills/teamsmith/scripts/team config list --json > /tmp/settings.json
$ bash docs/team/reports/P32/flip.sh /tmp/settings.json 1a 1b 1c 2 3b      # 全部五个（约十分钟）
```

**翻转 1a（卡片不再填满交给它的高度：删掉行列表的卡片填充）** → 短列表立刻露出空白：

```
--- red (rc=1)
  ✗ 过滤到一条时卡片没有填满窗口（1 0 0 29）
== 结果 ==  ✓ 48  ✗ 1
--- green after restoring the same section (rc=0)
== 结果 ==  ✓ 49  ✗ 0
```

**翻转 1b（D5 的计价表装回来：带注释的键行按两行计费）** → 虚账的直接后果是窗口远小于可用高度：

```
--- red (rc=1)
  ✗ 窗口没有随行高长：45 行 16 → 30 行 9
== 结果 ==  ✓ 48  ✗ 1
--- green after restoring the same section (rc=0)
== 结果 ==  ✓ 49  ✗ 0
```

**翻转 1c（整套旧算术：计价表 + 装配处预扣 8 行 + 不补卡片）** → 用户看到的形态（四档空白全红）：

```
--- red (rc=1)
  ✗ 过滤到一条时卡片没有填满窗口（1 0 0 29）
  ✗ 45 行：内容结尾到键栏还有 22 行空白
  ✗ 33 行：内容结尾到键栏还有 15 行空白
  ✗ 30 行：内容结尾到键栏还有 14 行空白
  ✗ 窗口没有随行高长：45 行 12 → 30 行 5
  ✗ 25 行：内容结尾到键栏还有 11 行空白
== 结果 ==  ✓ 43  ✗ 6
--- green after restoring the same section (rc=0)
== 结果 ==  ✓ 49  ✗ 0
```

该翻转同时打印了布局级账（`45 | 12 | 117 | 3 24 20 | 24 45 20`：只画 12 行、空白 20 行）。

**翻转 2（标题退回缩进的普通行：去掉区分标记）** → 标题形状与「未分组/席位」的识别一起红（预期连带：
标题不可辨认时，靠标题定位的断言本就无从判起）：

```
--- red (rc=1)
  ✗ 分组标题是分节线（不是缩进的普通行）（… 没有匹配 [^│ ── 身份与账本布局 ─+]）
  ✗ 组间可见分隔：标题是分节线且夹在两组之间：'分支与 forge' 不是分节线标题（没有带 ─ 的标题行）
  ✗ 未知键没有落在「未分组」标题下
  ✗ 降级组标题也是同一种分节线（标题体系一致）（… 没有匹配 [^│ ── 未分组 ─+]）
  ✗ 尾部顺序不对（未分组=0 席位=0）
  ✗ 席位块标题也是同一种分节线（标题体系一致）（… 没有匹配 [^│ ── 席位 ─+]）
  ✗ scratch 尾部顺序不对（未分组=0 席位=0）
== 结果 ==  ✓ 23  ✗ 7
--- green after restoring the same section (rc=0)
== 结果 ==  ✓ 30  ✗ 0
```

**翻转 3b（分节线保留、但标题晚一行画：去掉的是「分隔」而不是「形状」）** → 只有分隔断言红：

```
--- red (rc=1)
  ✗ 组间可见分隔：标题是分节线且夹在两组之间：标题上一行不是上一组的最后一条（'契约文件' 不在 '分支命名模式 …'）
== 结果 ==  ✓ 29  ✗ 1
--- green after restoring the same section (rc=0)
== 结果 ==  ✓ 30  ✗ 0
```

**还原之后**（本检出一个字节没被翻转影响）：

```
$ git status --porcelain
（空）
$ PATH="$HOME/.bun/bin:$PATH" bash skills/teamsmith/scripts/panel/build.sh   # 两次
$ git status --porcelain
（空）   # 两次构建逐字节一致：sha256 c18ded751accc6d973aafcaba99e261ebcfb1cc80d46786c9140d7d4df45b799
```

## 4. delta 修订（不删 base scenario）

`openspec/changes/settings-view-groups/specs/panel/spec.md`：

- 既有 ADDED requirement（功能域分组 + 行级 class）**新增** scenario
  `A heading is a section rule and it separates its own group`：标题（功能域/降级组/席位块一视同仁）画成
  **分节线**（标签夹在两段 `─` 之间），键行与席位行**不带**分节线；标题正好夹在上一组最后一条与本组第一条
  之间 —— 标题自身承担分隔，不另花一行。
- **新增** ADDED requirement `The settings view fills the pane it is given and its row window grows with it`：
  最后一行的下方最多 1 行空白；窗口随面板高度增长；一条行的价格 = 它真正画出的行数（一行一条 + 标题在自己行）；
  两条 `↑n`/`↓n` 计数是上限、只在那一侧真的藏了行时才花，没用掉的还回窗口；`画出的行 + ↑n + ↓n = 可聚焦行数`；
  没用掉的高度留在卡片**内部**（沿用 detail 视图的 fill 规则）；行列表、选择器、席位 picker 三种状态都成立
  （并显式声明它**加强**而不是削弱 B1 的「bounded frame fills the pane」：B1 说的是空高度落在内容区，
  这条说的是本视图那份配额就是行）。两个 scenario：`The card fills the pane and the window grows with it`
  （45/33/30/25 四档 + 45 比 30 多 ≥8 行）、`A short list keeps its blank space inside the card`（过滤到一条仍填满）。
- base scenario 一个没删；`panel` 的 MODIFIED 鼠标 requirement 与 `memory-and-deps` 的 delta 未改。

requirement/scenario → 夹具对照（本修订新增部分）：

| requirement / scenario | 夹具 |
|---|---|
| `…groups the contract…` / `A heading is a section rule and it separates its own group` | `panel-p21.sh groups`：`^│ ── 身份与账本布局 ─+`、`^│ [› ] 项目名.*─`（反面）、`assert_heading_rule 分支与 forge 契约文件 分支命名模式`、`未分组`/`席位` 同形断言 |
| `The settings view fills…` / `The card fills the pane and the window grows with it` | `panel-p21.sh settings`：`resize_panel` 到 120×45/33/30/25 + `settings_window_stats`（空白 ≤1、`rows+↑+↓=命令报的键+席位`、45↔30 差 ≥8） |
| 同上 / `A short list keeps its blank space inside the card` | `panel-p21.sh settings`：过滤到 `TEAM_PROJECT` 一条时的填满断言（翻转 1a/1c 的红侧就是它） |
| 布局级前后对照（证据，非门禁） | `docs/team/reports/P32/measure.ts` + `metrics.txt` + 前后原始渲染；翻转包 `docs/team/reports/P32/flip.sh` |

## 5. 门禁（原始输出尾部）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ spec/agent-adapters … ✓ change/settings-view-groups … ✓ spec/watchdog
Totals: 16 passed, 0 failed (16 items)

$ bash skills/teamsmith/tests/panel-p21.sh groups settings wheel
  ✓ 45 行：内容结尾到键栏只剩 0 行空白（≤1）
  ✓ 45 行：rows(32) + ↑(0) + ↓(83) = 命令报的键+席位（115）
  ✓ 33 行：内容结尾到键栏只剩 0 行空白（≤1）
  ✓ 33 行：rows(21) + ↑(0) + ↓(94) = 命令报的键+席位（115）
  ✓ 30 行：内容结尾到键栏只剩 0 行空白（≤1）
  ✓ 30 行：rows(18) + ↑(0) + ↓(97) = 命令报的键+席位（115）
  ✓ 窗口随行高长：45 行 32 → 30 行 18（差 14 ≥ 8）
  ✓ 25 行：内容结尾到键栏只剩 0 行空白（≤1）
  ✓ 25 行：rows(13) + ↑(0) + ↓(102) = 命令报的键+席位（115）
…
== 结果 ==  ✓ 102  ✗ 0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
  SKIP（FAST 模式） 38-b·panel-p21-choices —— panel-p21.sh choices 要真 tmux 场地 + 真 bundle（慢段 ~2.5 分钟）
  SKIP（FAST 模式） 38-f·panel-p21-settings-groups-wheel —— panel-p21.sh groups/settings/wheel 要真 tmux 场地 + 真 bundle（慢段 ~2 分钟）
== 结果 ==  ✓ 2301  ✗ 0
FAST 模式：跳过 28 个真进程段落（…|38-b·panel-p21-choices|38-f·panel-p21-settings-groups-wheel）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿

$ bash skills/teamsmith/tests/smoke.sh </dev/null        # 全量（含 F1 的 §38-f）
  ✓ 38-f panel-p21.sh groups/settings/wheel 全绿（ ✓ 102 ✗ 0）
== 结果 ==  ✓ 2811  ✗ 0
smoke 全绿
rc=0

$ bash skills/teamsmith/tests/panel-p21.sh choices settings wheel     # 回归（picker 条目窗口）
== 结果 ==  ✓ 182  ✗ 0

$ (cd skills/teamsmith/scripts/panel && PATH="$HOME/.bun/bin:$PATH" bunx tsc --noEmit)     # rc=0
$ bash skills/teamsmith/scripts/panel/build.sh            # 两次，逐字节一致
$ git status --porcelain   # 空
```

`groups` 段本修订新增/改动的断言（绿侧）：

```
  ✓ 分组标题是分节线（不是缩进的普通行）
  ✓ 键行不带分节线（标题/行在渲染上可区分）
  ✓ 组间可见分隔：标题是分节线且夹在两组之间（分支与 forge 是分节线标题，夹在 契约文件 与 分支命名模式 之间）
  ✓ 降级组标题也是同一种分节线（标题体系一致）
  ✓ 席位块标题也是同一种分节线（标题体系一致）
```

`choices` 段（picker 条目窗口回归）：

```
  ✓ 长列表在可视预算之外还有 8 个条目（计数行）
  ✓ 滚动前看不到列表末尾的自由输入项
  ✓ 滚轮把可见窗口往下推了（↓8 → ↓0）
```

## 6. 未动的既有行为（回归钉仍在）

P30/D1–D3 的功能域分组、读取顺序、`未分组` 降级、无键→域表（scratch CLI 两跳）、D4 的徽章词 + tone（三条
tone 断言）、D5 的滚轮（一格一行、焦点不动、`↑3`/`↑1` 计数、不穿透页面、两个 picker 各自走条目）、
`panel-b3` 的三处 wheel、已归档的直写/零读取基线、M55 的选择器与 `choices` 夹具前提：全部照旧 —— 本任务只动
layout 的**行高记账与标题形状**；`git diff --stat 3226ac0 HEAD` 里没有 `App.tsx`、`strings/*`、写入路径与机器出口。

## 7. 备注 / 偏差

1. **`CHANGELOG.md` 未改**：门禁要求 `CHANGELOG` 首行版本 == `TEAM_VERSION` == 两个 `SKILL.md` ==
   `package.json`（smoke 的五处一致性）。加一条 changelog 就得发版（五处版本号），这是 PM 的发布决策；且同一批的
   M49/M55/P29/P30 都没进 changelog（首条仍是 v1.42.0 · 2026-09-19）。任务书写的是「如需要」。
2. **第一次全量 smoke 抓到一个真回归并已修**：`38-b panel-p21.sh choices` 有 4 条红 —— 我把 picker 的条目窗口
   一起放大了，`choices` 夹具按 M55 的窗口标定了 28 条模型记录，于是「长列表被截断」这条**前提**不再成立。
   修正：行列表用 P32 的整块预算（用户报的那块），**picker 的条目窗口保持 M55 标定的 `SETTINGS_TAIL_ROWS`**
   （长词表仍然分页，卡片本身仍填满）——`choices`、`seats`、`wheel` 三段的窗口语义与已归档基线一字不变；
   改完重跑了 p21 全套、FAST 与全量（§5）。
3. **高度断言的数字随夹具的审计尾部长度变化**：pty 夹具的 `config.log` 为空，尾部 = 4 行，所以 45 行画出 32 行；
   本机真实项目有 3 条审计 → 尾部 6 行、30 行。断言本身不写死这些数字，只断言「空白 ≤1」
   「rows+↑+↓ = 命令报的键+席位」「45 比 30 多 ≥8」。
4. **「33/25 行同理按比例」的取法**：不是按比例留白，而是同一判据（空白 ≤1 行）在四档都成立；实测四档都是 0 行。
5. **滚轮 offset 与向下长窗口**：窗口只向下扩张，向上扩张会移动窗口首行、和 D5「offset 命名窗口首行」冲突
   （测试里 `↑3` 读的就是这个位置）。列表到底时不再往上补，剩余高度补在卡片内部。
6. **`cap_line_exact` 删除**：它原来靠「行内容恰好等于标题词」认标题，标题变成分节线后这条判据不再成立，
   换成 `cap_line_heading`（认「卡片行 + 标签 + `─`」）；它在改动前的四个用例全部迁完，没有留死代码。
7. **本修订不碰 P31 的 verify 结论**：P31 验的是修订前的 tip；本修订按任务书要求另行复验（PM 安排）。

## 8. F1（返工项，PM 裁定必须收口）：三个 pty 场景接进完整门禁 + 门禁时长增量

**问题（P31 的 finding）**：design D7 与 `smoke.sh` 38-e 的注释都宣称 `panel-p21.sh settings/groups/wheel`
三个场景**在完整门禁里跑**，实际没有任何调用点（38-b 只跑 `choices`）。

**接法**（照 38-b 的写法，`skills/teamsmith/tests/smoke.sh` 新增 §38-f，位置在 38-e 之后）：

```sh
if [ -f "$SKILL_DIR/tests/panel-p21.sh" ]; then
  if [ "$FAST" = "1" ]; then
    fast_skip "38-f·panel-p21-settings-groups-wheel" "panel-p21.sh groups/settings/wheel 要真 tmux 场地 + 真 bundle（慢段 ~2 分钟）"
  else
    live_mark
    if bash "$SKILL_DIR/tests/panel-p21.sh" groups settings wheel >"$TMP/panel-p21-view.log" 2>&1; then
      ok "38-f panel-p21.sh groups/settings/wheel 全绿（…）"
    else
      bad "38-f panel-p21.sh groups/settings/wheel 有失败"   # + ✗ 清单 + 末两行
    fi
  fi
else
  bad "38-f 缺 tests/panel-p21.sh"
fi
```

- **FAST 下是可见 SKIP**（`fast_skip` 的唯一出口会打印段名 + 原因，并进最后的跳过清单），**不是永远 SKIP、
  也没删任何断言**：全量下它是一条硬断言（失败即 ✗ + 断言清单）。
- 38-e 的注释补上「38-f 就是那个调用点」；design D7 的宣称随之成真（并把实测数字写进 D7）。

**门禁时长增量（同一台机器、本日、改前/改后各一次完整跑）**：

| 项 | 命令 | 结果 | 时长 |
|---|---|---|---|
| 改前（无 38-f） | `bash skills/teamsmith/tests/smoke.sh` | ✓ 2810 ✗ 0 | **811 s**（13.5 分钟；无排队，日志首行无「排队」提示） |
| 改后（有 38-f） | 同上 | ✓ 2811 ✗ 0 · `✓ 38-f …（✓ 102 ✗ 0）` | **960 s**（16 分钟；`pure_run_seconds=960`，另有 518 s 排队等别的 agent 的全量门禁） |
| 增量 | — | — | **+149 s ≈ 2.5 分钟** < 任务书的 3 分钟阈值 |
| 38-f 载荷自身 | `bash skills/teamsmith/tests/panel-p21.sh groups settings wheel` ×3 | 三次都 ✓ 102 ✗ 0 | **128 / 128 / 131 s**（中位 128 s ≈ 2.1 分钟） |

原始输出尾部：

```
$ (timed) bash skills/teamsmith/tests/smoke.sh </dev/null          # 改后
wall_seconds=1478 lock_acquired_epoch=1790064781 pure_run_seconds=960
rc=0
  ✓ 38-b panel-p21.sh choices 全绿（ ✓ 110 ✗ 0）
  ✓ 38-c pty-wait 自检全绿（ ✓ 12 ✗ 0；中间帧注入 + 清理守卫 + 失败现场）
  ✓ 38-f panel-p21.sh groups/settings/wheel 全绿（ ✓ 102 ✗ 0）
== 结果 ==  ✓ 2811  ✗ 0
smoke 全绿

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null   # FAST：38-f 可见 SKIP
  SKIP（FAST 模式） 38-b·panel-p21-choices —— panel-p21.sh choices 要真 tmux 场地 + 真 bundle（慢段 ~2.5 分钟）
  SKIP（FAST 模式） 38-f·panel-p21-settings-groups-wheel —— panel-p21.sh groups/settings/wheel 要真 tmux 场地 + 真 bundle（慢段 ~2 分钟）
== 结果 ==  ✓ 2301  ✗ 0
FAST 模式：跳过 28 个真进程段落（…|38-b·panel-p21-choices|38-f·panel-p21-settings-groups-wheel）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿

$ for i in 1 2 3; do time bash skills/teamsmith/tests/panel-p21.sh groups settings wheel; done
run 1: rc=0 seconds=128 == 结果 ==  ✓ 102  ✗ 0
run 2: rc=0 seconds=128 == 结果 ==  ✓ 102  ✗ 0
run 3: rc=0 seconds=131 == 结果 ==  ✓ 102  ✗ 0
```

**判定**：增量 **2.1–2.5 分钟 < 3 分钟**（载荷 128 s；整门禁 811 → 960 s），故按任务书直接接入、不需要替代方案；
不需要只接 `groups+wheel`，也不需要把 settings 并进 38-b 的 server（FAST 跳过的 28 个真进程段里，38-f 与 38-b 各起自己的
私有 tmux server，互不影响；合并省不下多少，反而让两段的失败现场混在一起）。
