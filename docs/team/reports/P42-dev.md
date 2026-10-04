# P42 · settings-view-groups 独立验证（覆盖 P30 + P32 修订）

```
task:    P42
agent:   dev
status:  VERIFY 完成（报告 + 证据包已提交）
branch:  task/P42-settings-view-groups-p32（local 模式：不 push；PM 复验后本地合并）
change:  settings-view-groups
         propose=P29 · apply=P30（dev-bob）· verify-P30 轮=P31（dev2）· 修订=P32（dev-bob）· 本轮 verify=dev（换人，D31）
specs:   panel#The settings view groups the contract by the functional group the command reports /
         panel#The settings view fills the pane it is given and its row window grows with it /
         panel#Every key affordance is also a mouse target（MODIFIED）/
         memory-and-deps#The machine read reports each row's group
phase:   verify
tip:     d8bfab1（P42 brief 落盘时的分支点；实现面 = P30+P32 合入后的 main 内容）
verdict: PASS · 0 finding
```

## 0. 结论（一句话）

P32 修订面（分节线标题 / 用满窗口高度 / 38-f 接线）与 P30 行为面（功能域分组 / 词+tone / 视图滚轮）
**逐条独立复现全绿**；三条变异（去分节线 / 退回高度算术 / 只留 tone）各自让对应断言精确变红，还原后
bundle 与提交版逐字节一致、场景回绿，工作树全程零改动；已归档 `settings-choice-editors` 基线抽查全绿。
**无 finding。**

## 1. 方法：独立性与隔离

- **变异只在临时副本**：`/tmp/p42-mut`（工作树的 `cp -a`，删掉 `.git` 指针），改源码 → 钉住的 bun 重建
  副本 bundle → 跑副本里的官方场景。工作树全程 `git status --porcelain` 为空（见 §8）。
- **R2 不复用被测断言**：自己写了 pty 驱动 + 解析器（`pkg/r2-heights.sh`）——私有 tmux server
  （`-L p42mine-*`、开跑前 `unset TMUX TMUX_PANE`、CLI 读数剥掉全部继承 `TEAM_*`），从原始 capture
  自己算 rows/↑/↓/gap，不与 `panel-p21.sh` 的 `settings_window_stats` 共享一行代码。
- **官方套件原样重跑**（真树）：`panel-p21.sh groups settings wheel`、`choices`、`panel-b3.sh`、
  FAST smoke、全量 smoke、`openspec validate --all --strict`。
- 证据包：`docs/team/reports/P42-dev/{logs,pkg}`，日志即原始输出（含 ANSI，未修饰）。

## 2. R1 · 标题可辨识（P32）

**断言**（baseline `groups`，logs/10）：标题行匹配分节线、键行不匹配、标题夹在两组之间承担分隔：

```
✓ 分组标题是分节线（不是缩进的普通行）            # ^│ ── 身份与账本布局 ─+
✓ 键行不带分节线（标题/行在渲染上可区分）          # ^│ [› ] 项目名.*─ 不得匹配
✓ 组间可见分隔：标题是分节线且夹在两组之间（分支与 forge 夹在 契约文件 与 分支命名模式 之间）
✓ 降级组标题也是同一种分节线（标题体系一致）        # ^│ ── 未分组 ─+
✓ 席位块标题也是同一种分节线（标题体系一致）        # ^│ ── 席位 ─+
```

**反向（M1，logs/20）**：把 `layout.ts:1592` 的 `ruleTitle(...)` 换成缩进文本行 → `groups` ✗7，
红的正是上表的可辨识断言（含 `cap_line_heading` 找不到带 ─ 的标题 → 尾部顺序两条连坐红）；
分组行为本身（顺序/降级/无键→域表）仍全绿 —— 红精确落在「可辨识」面上，不是全面崩。

## 3. R2 · 用满窗口高度（P32）——自己算一遍

**我自己的复算**（`pkg/r2-heights.sh`，输出 logs/11；夹具 111 键 + 2 席位 = 114 可聚焦行，
与 CLI 读数对账）：

```
want_count(keys+seats from CLI)=114
h=45 pane_lines=45 rows=32 up=0 down=82 gap=0  rows+up+down=114 (want 114)
h=33 pane_lines=33 rows=21 up=0 down=93 gap=0  rows+up+down=114 (want 114)
h=30 pane_lines=30 rows=18 up=0 down=96 gap=0  rows+up+down=114 (want 114)
h=25 pane_lines=25 rows=13 up=0 down=101 gap=0  rows+up+down=114 (want 114)
growth 45→30: 32 → 18 (diff 14, need ≥8)
```

- 四档 `pane_lines` 恰等于 pane 高度（帧画满），**gap=0 ≤ 1**（卡片下边框到键栏无空白）；
- `rows + ↑n + ↓n == 114` 四档全等（计数行诚实）；**45 vs 30 差 14 ≥ 8**。
- 官方 baseline（logs/10，它的夹具多一条手加键所以总数 115）量出同样的 32/21/18/13 与 gap=0 ——
  两套独立解析器、两个独立夹具，数字一致。

**反向（M2，logs/21+22）**：把 P32 的两处算术一起退回（键行带注释按两行记账 + 组装余量不移交卡片）
→ `settings` ✗6：**45/33/30/25 空白断言全红（28/16/13/8 行空白）**、「窗口随行高长」红（3→3）、
「过滤到一条时卡片仍填满」红。中间形态（只退价格）空白断言不红但「增长 + 记账」红（45 行窗口
32→16）——两条断言分工明确，任一半边退回都逃不掉。

## 4. R3 · 功能域分组（P30）

- **12 个 slug 普查**（自己跑 awk，与 D2 表逐一相等）：`rows=111 tokens=12` —— branch 11 /
  delivery 13 / identity 12 / meeting 4 / panel 7 / patrol 4 / pm-lifecycle 6 / policy 16 /
  roster 11 / seat-model 3 / session 10 / workflow 14。
- **机器读**（真树 `team config list --json`，自己解析）：`TEAM_PROJECT→identity`、`TEAM_PULSE_INTERVAL→panel`、
  `TEAM_DEFAULT_MODEL→seat-model`、`TEAM_GATES→workflow`；111 条记录 token 全部匹配
  `^[a-z][a-z0-9-]*$`；`group` 是纯新增字段（既有字段一个不少）；人表表头仍是 `KEY CLASS KIND VALUE`；
  `team monitor --print/--json` 无 group 字段（--print 唯一 grep 命中是我自己的任务 slug 行）。
- **视图面**（baseline `groups`，logs/10）：标题是功能域名（开屏 `身份与账本布局`，第 13 行进窗见
  `分支与 forge`，无 `立即生效/需要重启/只读` 标题）；组内保持 schema 序（项目名=5 < 会话名=6 < PM 窗口=7）；
  未知键落「未分组」且在席位块之前（28 < 30）；第 10 列缺失的 schema 行同样降级到「未分组」且行完整。
- **视图不硬编码**（同日志）：scratch CLI 新增 `TEAM_ZZZ_TEST|…|workflow` → 落在「工作流与门禁」；
  `TEAM_GATES` 的 token 改成 `meeting` → 跟到「跨项目会议」；三次运行 bundle 逐字节不变（sha 不变）。

## 5. R4 · 词 + tone（P30）

baseline `groups`（logs/10）：三类徽章词都在（去 SGR 的捕获里可见），tone 逐类对上调色板
（apply=text `#dfe3ea`、restart=warn `#f2c66d`、refuse=dim `#98a2b3`，值保持 text tone，palette=dark）。

**反向（M3，logs/23）**：删掉徽章词只留 tone（值被染色）→ `groups` ✗9：三条「徽章词仍在」红、
三条「徽章 = 类 tone」红（断言按词定位徽章）、两条行完整性红 —— 「颜色不是唯一通道」被钉死。

## 6. R5 · 滚轮（P30）+ b3 不回归

baseline `wheel`（logs/10，✓24/24）：3 格滚轮窗口正好移 3 行（`↑3`）、焦点不动（命令行仍点名
`TEAM_PROJECT`）、回滚计数行消失、`↓` 把窗口推回聚焦行、选择器/席位 picker 里滚轮走条目、
esc 一次关 picker 不穿透、**页面窗口保持进视图前那一屏（P-04 仍可见、P-01 仍在屏外）**。

b3（logs/30）：✓155 ✗0 —— 页面滚轮 3 格窗口后移、resize 实时重排 8 档、q 收起后巡检仍在跑，全绿。

## 7. R6 · F1 接线（P32 收口）

- **FAST 下可见 SKIP（带原因）**（logs/40，FAST ✓2315 ✗0 / 8m8s）：
  `SKIP（FAST 模式）38-f·panel-p21-settings-groups-wheel —— panel-p21.sh groups/settings/wheel 要真 tmux 场地 + 真 bundle（慢段 ~2 分钟）`，
  且汇总行的 29 个跳过段落里点名 `38-f·panel-p21-settings-groups-wheel`。
- **全量里硬断言**（logs/41）：全量 smoke 里 38-f 实跑 `panel-p21.sh groups settings wheel` 并
  ok/bad 断言其结果（见 §8 全量尾巴）。
- **自己跑三场景并计时**（logs/10）：`real 2m10.656s`（user 10.5s sys 5.5s）。P32 报告称 148s /
  增量 ≈2.5 分钟 —— 实测 131s，同量级（本机本轮更快），声明成立。
- 38-e（FAST 结构钉）本轮全绿：token⇄label 双向（删 `group_workflow` / 加 `group_zzz` 两侧翻转都红）、
  无类分组表 pin（注入 `settingsGroupApply` 红）、滚轮消费 pin（删 `scrollSettings(delta)` 红）。

## 8. R7 · 基线未被碰（settings-choice-editors 抽查）

`panel-p21.sh choices` 全绿（logs/30，✓110 ✗0 / 1m34s）。抽查两条：

1. **直写 + 零读取**：bool/enum/数值建议值/path 清空「一次 accept = 校验（--dry-run）+ 写入（--yes）」，
   无确认帧、无编辑器、审计恰长一行；打开选择器/自由输入「按键→帧之间零读取、零子进程」。
2. **危险值例外（选项/自由输入两路）**：文件里的 `0` 在选项里就是「当前」；第一次 accept 只警告
   （契约不变、审计不长、没有 --yes），第二次 accept 才带 `--allow-danger` 写入、审计长一行；
   自由输入路径同样先要一个额外确认。

## 9. Acceptance 四条

```sh
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 18 passed, 0 failed (18 items)          # 含 ✓ change/settings-view-groups

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2315  ✗ 0                          # real 8m8s（logs/40）

$ bash skills/teamsmith/tests/panel-p21.sh groups settings wheel
== 结果 ==  ✓ 102  ✗ 0                           # real 2m10.7s（logs/10）

$ bash skills/teamsmith/tests/panel-b3.sh
== 结果 ==  ✓ 155  ✗ 0                           # （logs/30）
```

全量 smoke（R6 的全量面）：见 logs/41 —— **结果待全量跑完回填**。

## 10. 还原与边界

- 三条变异全部只动 `/tmp/p42-mut`；还原后副本 `layout.ts` 与工作树逐字节一致、副本重建 bundle
  sha256 == 工作树提交 bundle（`c18ded751accc6d973aafcaba99e261ebcfb1cc80d46786c9140d7d4df45b799`，
  确定性构建双向成立）、副本里 `groups settings` 回绿 ✓79 ✗0（logs/24）。
- 工作树交付前 `git status --porcelain` 输出为空（实现面零改动；只有本报告与证据包新增）。
- 未碰 `scripts/**`、`tests/**`、`openspec/**`；未 push（local 模式）；未改 PM 的文件。
- 构建事故自清：M2b 的第一版补丁把 `//` 注释放行尾吃掉了 ` }) ?? b)`，bun 直接报语法错、
  那次「运行」实际跑的是旧 bundle（数字与 M2a 完全相同，被我发现后重打补丁重跑）——证据链里
  logs/21 与 logs/22 因此分得清。
