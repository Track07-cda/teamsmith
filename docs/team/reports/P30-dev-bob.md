# P30 · settings-view-groups apply（第 10 列 group + 功能域分组 + 行级 class + 滚轮）

```
task:    P30
agent:   dev-bob
branch:  task/P30-apply-10-group-class（local 模式：不 push；分支留在 .worktrees/dev-bob，PM 复验后本地合并）
change:  settings-view-groups（phase: apply；proposal 已验收 docs/team/reviews/settings-view-groups-proposal.md ACCEPTED）
specs:   panel#The settings view groups the contract by the functional group the command reports, and
         carries the effect class on the row /
         panel#Every key affordance is also a mouse target（MODIFIED：滚轮范围加上设置视图）/
         memory-and-deps#The machine read reports each key's functional group, and the schema is its only source
deltas:  panel（ADDED ×1 + MODIFIED ×1）· memory-and-deps（ADDED ×1）
设计真源: openspec/changes/settings-view-groups/design.md（D0–D8）+ tasks.md
commits: 1eba34f（schema 第 10 列 + read 的 group + config-cli groups 走查/翻转）·
         edc74fa（视图分组 + 徽章 tone + 滚轮 + 窗口按行数装 + 夹具/钉子 + bundle 重建）·
         <本报告与 tasks.md 勾选>
status:  APPLY 完成（FAST smoke ✓2301 ✗0；全量 smoke ✓2810 ✗0；p21 全套 ✓263 ✗1，唯一红是**改动前就存在**的
         choices-schema 断言，§9 有翻转证明；b3 全套 ✓155 ✗0）
```

## 0. Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-config.sh` | 111 行 schema 各加第 10 列 group（12 个封闭 token）；表头注释与 `team_config_field 1..10`；`team_config_list_json` 每条记录带 `"group"`（schema 键逐字、未知键 `""`） |
| `skills/teamsmith/references/config.md` | §5 新增「The schema's tenth column (`group`)」：列语义、token 形状、12 个域、词表封闭的判据（英文文档不变量保持） |
| `skills/teamsmith/scripts/panel/src/{types,layout,App}.ts(x)` | `SettingsKey.group`；`settingsViewRows` 按记录分组 + 「未分组」降级 + 席位块尾置；徽章独占 tone；设置视图自己的窗口 offset（滚轮消费、焦点推窗）；窗口按**画出的行数**装（见 §8 偏差 1） |
| `skills/teamsmith/scripts/panel/src/strings/{zh,en}.ts` | 12 个 `group_<token>` + `settingsGroupUngrouped` + `settingsGroupSeats` 改名「席位」；删掉三个类分组标签 |
| `skills/teamsmith/scripts/panel/panel.js` | 重建（两次构建逐字节一致） |
| `skills/teamsmith/tests/config-cli.sh` | 新 `groups` 走查段（独立 python 解析器）+ `groups-flip`（F-G1/F-G2 红侧） |
| `skills/teamsmith/tests/panel-strings.mjs` | 规则 5：`group_<token>` 双向相等（有 token 无标签 / 有标签无 token 都红）+ token 形状 |
| `skills/teamsmith/tests/panel-p21.sh` | `settings` 段更新；新 `groups`、`wheel` 两个真进程场景；`wheel_at`/`cap_line_exact`/`assert_badge_tone`/`assert_no_class_heading` 等夹具 |
| `skills/teamsmith/tests/smoke.sh` | 新 38-e：组标签双向相等的两条红侧 + 两条结构钉（分组只读记录 / 滚轮先于页面消费）各带红侧 |
| `openspec/changes/settings-view-groups/tasks.md` | 1.1–3.3 勾选（4.1 留给复验者） |

## 1. 规格 → 条目 → 夹具

| delta → requirement | 条目 | 夹具（行为面） |
|---|---|---|
| `memory-and-deps` ADDED：read 报告每键的 group，schema 是唯一来源 | 1.1 1.2 1.3 1.4 1.5 | `tests/config-cli.sh groups`（走查 + 样本键 + human 表/monitor 不动）、`groups-flip`（F-G1/F-G2） |
| `panel` ADDED：视图按报告的 group 分组，class 落在行上 | 1.6 1.7 2.1 2.2 2.3 2.6 2.7 | `panel-p21.sh groups`（标题/顺序/降级/无硬编码/徽章词+tone）、`panel-p21.sh settings`（徽章词）、`panel-strings.mjs` 规则 5、smoke 38-e 两条结构钉 |
| `panel` MODIFIED：滚轮范围加上设置视图（消费、一格一行、计数行、焦点推窗） | 2.4 2.5 2.6 2.7 | `panel-p21.sh wheel`（3 格位移/焦点不动/计数行/不穿透/焦点推窗/两个 picker）、smoke 38-e 的消费顺序钉 |

场景 → 夹具对照（新增/改动的 scenario）：
`The group is the row's tenth column, per section` → config-cli `groups` 样本键断言；
`A missing or malformed token is a gate failure` → config-cli `groups-flip` F-G1/F-G2；
`The field is additive and nothing else moves` → config-cli `groups` 的 human 表/monitor 两出口断言；
`The headings are functional domains, not effect classes` → p21 `groups`（标题 + `assert_no_class_heading`）；
`A key added to the schema lands in its group…` → p21 `groups` scratch CLI（TEAM_ZZZ_TEST → workflow / TEAM_GATES → meeting）；
`A row without a group renders under the fallback heading` → p21 `groups`（TEAM_HAND_ADDED + 畸形 TEAM_GATES + 尾部顺序）；
`The class is a word on the row and its tone is redundant` → p21 `groups` 三段 tone 断言（`capture-pane -e` + `--palette`）；
`The seats block keeps its own heading…` → p21 `groups` 尾部（席位标题与 `seat-model` 组标题不同名）+ `seats` 场景不回归；
`The wheel scrolls the settings view's window` → p21 `wheel`（↑3 / ↑1 / 上滚回顶）；
`The wheel over the view does not move the page behind it` → p21 `wheel`（页面 P-01/P-04 前后一致 + 两个 picker 的滚轮）；
`The focus keys keep the focused row inside the window` → p21 `wheel`（↓ 推窗 + enter 打开命令行点名的那一行）。

## 2. 实测普查（1.2）

```
$ awk -F'|' '/^# ----/{next} /^TEAM_[A-Z0-9_]+\|/{n++; t[$10]++} END{printf "rows=%d tokens=%d\n", n, length(t); for(k in t) printf "%s %d\n", k, t[k]}' skills/teamsmith/scripts/lib/cmd-config.sh | sort
rows=111 tokens=12
branch 11 · delivery 13 · identity 12 · meeting 4 · panel 7 · patrol 4 · pm-lifecycle 6 · policy 16 ·
roster 11 · seat-model 3 · session 10 · workflow 14
$ awk -F'|' '/^TEAM_[A-Z0-9_]+\|/{if (NF != 10) print "BAD " NF ": " $0}' …   # 空输出 = 无畸形行
```

## 3. 验收命令（原始输出尾部）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 16 passed, 0 failed (16 items)

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
  ✓ 33 config-cli.sh 全绿（133 条断言）
  ✓ 38-e 组标签：schema 行的 group token 与 zh/en 的 group_<token> 双向相等（12 schema group tokens）
  ✓ 38-e 翻转①：两张表都删掉 group_workflow → 断言非 0 且点名该 token
  ✓ 38-e 翻转②：加一个没有 schema 行使用的 group_zzz → 断言非 0 且点名陈旧标签
  ✓ 38-e 视图分组：layout.ts 无类分组表、无键→域表（标题按 group_<token> 查，分组只读记录）
  ✓ 38-e 翻转：layout.ts 里出现 settingsGroupApply → pin 红
  ✓ 38-e 滚轮消费：设置视图的分支在页面滚动之前（scrollSettings 先于 updateScroll，不穿透）
  ✓ 38-e 翻转：删掉 scrollSettings(delta) → pin 红（滚轮会落回页面滚动）
== 结果 ==  ✓ 2301  ✗ 0
smoke 全绿

$ node skills/teamsmith/tests/panel-strings.mjs
ok: contract-key labels — 111 schema keys covered in zh and en
ok: contract-group labels — 12 schema group tokens covered in zh and en
panel-strings: ok

$ bash skills/teamsmith/tests/config-cli.sh        # 全段（脚本自己的计数 125 条断言）
== 结果 ==  ✓ 125  ✗ 0  SKIP 0
```

（smoke §33 那行「133 条断言」是它按日志里 ✓ 行数的粗计，包含 `groups-flip` 里两条红侧的
「已判红」证据行；脚本自己的断言计数是 **125**。）

`git status --porcelain`：提交后为空（验收要的干净树）。

## 4. 翻转（红 → 绿，原始输出）

**F-G1 / F-G2（config-cli `groups-flip`，已进门禁）**

```
$ bash skills/teamsmith/tests/config-cli.sh groups groups-flip
  ✓ 还原两行 → groups 段重新绿（rc=0）
    --- F-G1 红侧尾部 ---
      ✗ groups 走查：记录与 schema 第 10 列不一致
          PROBLEM	TEAM_GATES：schema 行的第 10 列（group）缺失
      ✗ 样本键的 group 不对
          PROBLEM	TEAM_GATES: group '' != 'workflow'
    == 结果 ==  ✓ 3  ✗ 2
    --- F-G2 红侧尾部 ---
      ✗ groups 走查：记录与 schema 第 10 列不一致
          PROBLEM	TEAM_PULSE_INTERVAL：token 'NoPe!' 形状不对（要 ^[a-z][a-z0-9-]*$）
      ✗ 样本键的 group 不对
          PROBLEM	TEAM_PULSE_INTERVAL: group 'NoPe!' != 'panel'
    == 结果 ==  ✓ 3  ✗ 2
== 结果 ==  ✓ 9  ✗ 0  SKIP 0      # 含 scratch 原状绿 → 两个红 → 还原绿
```

**标签双向相等（panel-strings 规则 5；smoke 38-e 也各带一条）**

```
$ node skills/teamsmith/tests/panel-strings.mjs                 # 绿
ok: contract-group labels — 12 schema group tokens covered in zh and en
$ # 翻转①：从 zh/en 两张表各删 group_workflow
✗ panel-strings failed:
  zh: no group_workflow label for the group the schema rows carry
  en: no group_workflow label for the group the schema rows carry
$ # 翻转②：两张表各加一个没有 schema 行使用的 group_zzz
✗ panel-strings failed:
  zh.group_zzz names no group any schema row uses (stale label)
  en.group_zzz names no group any schema row uses (stale label)
```

**视图不硬编码（变体 bundle：把键→域表塞回 bundle）** — scratch 构建 + 同一份 `panel-p21.sh groups`：

```
$ TEAM_P21_PANEL=/tmp/p30-variant-hardcoded/panel/panel.js bash skills/teamsmith/tests/panel-p21.sh groups
  ✗ TEAM_GATES 的 token 改成 meeting 后跟到新标题下（bundle 里没有键→域表）（… 里找不到 [跨项目会议]）
  ✗ 第 10 列缺失的 schema 行落在可见的降级组里（不消失）（… 里找不到 [未分组]）
  ✗ 降级组里畸形行同屏（schema 行可见）（… 里找不到 [门禁命令]）
== 结果 ==  ✓ 22  ✗ 3      # 现 bundle：✓ 25  ✗ 0
```

**缺 token 的行必须可见降级（变体 bundle：跳过空 group 的行）**

```
$ TEAM_P21_PANEL=/tmp/p30-variant-dropempty/panel/panel.js bash skills/teamsmith/tests/panel-p21.sh groups
  ✗ 未知键的行仍在（没有消失）（… 里没有匹配 [TEAM_HAND_ADDED +hand · 未知键]）
  ✗ 未知键没有落在「未分组」标题下
  ✗ 降级组里的行仍完整（标签/值/徽章）…
  ✗ 降级组里未知键与畸形行同屏（未知键可见）…
== 结果 ==  ✓ 17  ✗ 8      # 现 bundle：✓ 25  ✗ 0
```

**滚轮消费（变体 bundle：删掉设置视图的滚轮分支 = 改回穿透）**

```
$ TEAM_P21_PANEL=/tmp/p30-variant-noconsume/panel/panel.js bash skills/teamsmith/tests/panel-p21.sh wheel
  ✗ 下滚 3 格：顶部计数行读出 ↑3（窗口正好移 3 行）（… 里没有匹配 [↑3]）
  ✗ 下滚 3 格：原本第一行（项目名）已出窗（不该出现 [项目名]）
  ✗ ↓ 之后窗口被推到聚焦行上（顶部计数行 = ↑1）（… 里没有匹配 [↑1]）
  ✗ 页面窗口还是进视图前的那一屏（P-04 仍可见）（… 里找不到 [P-04]）   ← 用户报的「滚轮偷偷滚页面」
== 结果 ==  ✓ 19  ✗ 4      # 现 bundle：✓ 23  ✗ 0
```

**词 + tone 两通道（变体 bundle：去掉词 / 只留一个 tone）**

```
$ TEAM_P21_PANEL=/tmp/p30-variant-noword/panel/panel.js bash skills/teamsmith/tests/panel-p21.sh groups
  ✗ apply 行的徽章词仍在（颜色不是唯一通道）… ✗ restart 行的徽章词仍在 … ✗ refuse 行的徽章词仍在
== 结果 ==  ✓ 17  ✗ 8
$ TEAM_P21_PANEL=/tmp/p30-variant-onetone/panel/panel.js bash skills/teamsmith/tests/panel-p21.sh groups
  ✗ restart 徽章 = warn tone：badge 颜色 #dfe3ea ≠ warn tone #f2c66d（调色板 dark）
  ✗ refuse 徽章 = dim tone：badge 颜色 #dfe3ea ≠ dim tone #98a2b3（调色板 dark）
== 结果 ==  ✓ 23  ✗ 2      # 只有 tone 断言红，词断言仍绿（两条通道互相独立）
```

**bundle 可复现**

```
$ bash skills/teamsmith/scripts/panel/build.sh   # 第一次
panel.js written (953252 bytes, sha256 c88acfd9c5690dfca7bd0d95b01db24b87fe328d86eb687d83c95792df14b9d7)
$ bash skills/teamsmith/scripts/panel/build.sh   # 第二次
panel.js written (953252 bytes, sha256 c88acfd9c5690dfca7bd0d95b01db24b87fe328d86eb687d83c95792df14b9d7)
# 两次 sha256 相同；全量 smoke 的 26-a 沙盒重建也逐字节比对（§5）
```

## 5. 真进程门禁（pty / 全量 smoke）

`bash skills/teamsmith/tests/panel-p21.sh`（私有 tmux server + 真 bundle + argv 记录 wrapper）：

| 场景 | 结果 | 备注 |
|---|---|---|
| `settings`（改过） | ✓39 ✗0 | 开屏即功能域标题；「模型」过滤 → 点击打开编辑器；窗口计数行 |
| `groups`（新） | ✓25 ✗0 | 标题/读取顺序/组内 schema 序/未分组降级/scratch 无硬编码/徽章词+tone/尾部顺序 |
| `wheel`（新） | ✓23 ✗0 | 页面滚轮不回归；视图一格一行 + 焦点不动 + 计数行；焦点推窗；两个 picker 的滚轮；页面不穿透 |
| `choices` | ✓110 ✗0 | 选择器/直写/危险值路径不回归 |
| `choices-schema` | ✓8 ✗1 | **唯一红是改动前就存在的断言**（§9 finding 1） |
| `write` / `conflict` / `seats` / `readonly` | ✓24 / ✓7 / ✓22 / ✓5，✗0 | 写路径与席位块不回归 |
| 合计 | ✓263 ✗1 | |

全量 smoke（不设 `TEAM_SMOKE_FAST`，含全部真进程段落；已跑完）：

```
$ bash skills/teamsmith/tests/smoke.sh </dev/null
  ✓ 26-a bundle：沙盒里重建逐字节一致（953252 字节）
  ✓ 38-b panel-p21.sh choices 全绿（ ✓ 110 ✗ 0）
== 结果 ==  ✓ 2810  ✗ 0
smoke 全绿
```

既有 b3 回归钉（设计 D7 的「三处既有 wheel 不回归」；本任务未改该文件）：

```
$ bash skills/teamsmith/tests/panel-b3.sh          # 全套 11 个场景，含 mouse/wheel/board/detail
== 结果 ==  ✓ 155  ✗ 0
  ✓ 滚轮下滚 3 格：可见窗口后移（10:00:00Z 移出、10:45:00Z 进入）      # 页面滚轮
  ✓ 车道内滚轮上滚：done 窗口移到更旧的卡片（原先隐藏的 D01–D05 进入视图）  # 泳道滚轮
  ✓ 滚轮把详情文档窗口后移（更靠后的报告行上屏）                          # 详情滚轮
```

试归档（scratch 副本，不动本树）：

```
$ cp -r openspec /tmp/p30-trial2/openspec && (cd /tmp/p30-trial2 && openspec archive -y settings-view-groups)
Applying changes to openspec/specs/memory-and-deps/spec.md:  + 1 added
Applying changes to openspec/specs/panel/spec.md:            + 1 added, ~ 1 modified
Change 'settings-view-groups' archived as '2026-09-22-settings-view-groups'.
# 合并后的 spec/panel：mouse 需求下 10 条 scenario（base 7 条一条未丢，顺序不变）+ 新需求 5 条；
# memory-and-deps 的 group 需求 1 条。与另两个未归档 change 无冲突。
```

## 6. 写者未动（一句话声明）

`team config set` 的校验、指纹 CAS、审计、危险值清单与直写路径一行未改：`bash tests/config-cli.sh writer cas validate audit` → `✓ 54 ✗ 0`（inject/seats/models/completeness/docs/callers/flip 各段也全绿，全段 `✓ 133 ✗ 0`）。

## 7. 决策与偏差

1. **窗口按画出的行数装（超出任务书 2.4 的字面，但不做就是缺陷）**：分组改成「route 密集的 identity 打头」后，行注释（第二行）与组标题让原来的「行数 = 可见行数」记账爆掉 —— `pickChrome` 会把整块降级成一行 rule/summary，滚轮无从可滚。实测证据（真实载荷 + 160×40）：
   ```
   focus=  0 old=card  new=card      focus= 40 old=card new=rule
   focus= 80 old=card  new=SUMMARY   focus=113 old=card new=SUMMARY
   ```
   修法：`settingsBlock` 先算每个可聚焦行真正的行数（+注释、+组标题），从窗口首行向后装到预算为止；焦点跟随模式下若焦点被挤出窗口，再从焦点向前取最大窗口。修后 115 个焦点位 × 115 个显式 offset 全部 `card`、焦点必在窗内（脚本实测 0 bad / 115）。
2. **`capture-pane -e` + `--palette` 做 tone 断言**：tmux 的 `-e` 捕获保留每个 run 的 truecolor SGR，期望色从 bundle 自己的 `--palette` 读（不写死颜色，深浅主题由「值的颜色 = 哪个调色板的 text」现场判定）。报告里的 tone 证据即由此而来。
3. **`smoke.sh` 的位置**：任务书 1.7 说「接在 §28-a2 的键标签翻转旁边」，但本任务书 `grant:` 只给 `tests/smoke.sh（§33/§38 附近 append-only）`；两条组标签红侧因此落在 **38-e**（与 2.7 的结构钉同段），实际覆盖率不变。
4. **`walk_to_tail` 的稳健性**：设置块有 15s TTL 重读，重读失败时整块会短暂换成摘要行（既有现象）；夹具等到「席位标题 + 光标行」同帧才收据，空列表上的 Down 是无害 no-op（最多走 6 轮）。
5. **`panel-p21.sh` 的 fixtures 补了 group token**：`settings` 与 `choices-schema` 的 scratch 新键原本不带第 10 列（会默默走「未分组」）；现显式声明（`workflow`），让夹具覆盖真实形状。

## 8. Findings（本轮不修，越界/既有）

1. **`choices-schema` 有一条既有红（与本改动无关）**：断言 `assert_not … "自由输入"` 撞上选择器**提示行**里的「自由输入」字样（`settingsChoiceHint` 一直含这三个字），不是「自由输入项」。翻转证明（HEAD 的测试脚本 + 现有 bundle）：
   ```
   $ git show HEAD:skills/teamsmith/tests/panel-p21.sh > tests/.tmp-p21-old.sh
   $ bash tests/.tmp-p21-old.sh choices-schema
     ✗ enum 是封闭域：没有自由输入项（不该出现 [自由输入]）
   ```
   该场景不在任何门禁里（全量 smoke 只跑 `panel-p21.sh choices`），所以一直没暴露。建议（由 PM 决定）：把断言改成查条目 `…（自由输入）`。
2. **`tests/config-cli.sh` 的 `TEAM_CONFIG_KEEP=1` 是死开关**：脚本在读取 `keep` 之前就把继承的 `TEAM_*` 全清掉了，所以文件头注释承诺的「保留现场」实际不生效（我在排查 p21 时踩到）。修复属于该文件的既有约定，未在本任务范围内动手。

## 9. Suggested next steps

- **独立复验（4.1，换人）**：`panel-p21.sh settings groups wheel` 三个场景 + 全量 smoke + `openspec validate`；§4 的变体 bundle 翻转可按报告里的命令复现（变体只建在 `/tmp`，不提交）。
- 归档时 `openspec archive -y settings-view-groups`（已在本树 scratch 副本试归档通过）。
- 后续项 **F2**（settings 视图的 snapshot 钉子）仍按 design 的 F2 排期，不在本 change。
- 上面 §8 的两条 finding 建议单独派单（都碰 `tests/**`，与 settings-view-groups 无重叠）。
