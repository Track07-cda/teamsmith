# P31 · settings-view-groups 独立验证（verify 阶段）

```
task:    P31
agent:   dev2
status:  VERIFY 完成（报告 + 复验包 + 日志已提交；1 finding F1 待 PM 裁定）
branch:  task/P31-tone（local 模式：不 push；PM 复验后本地合并）
change:  settings-view-groups
         propose=P29（dev-bob）· apply=P30（dev-bob）· verify=dev2（换人，D31）
specs:   panel#The settings view groups the contract by the functional group the command reports,
         and carries the effect class on the row /
         panel#Every key affordance is also a mouse target（MODIFIED）/
         memory-and-deps#The machine read reports each key's functional group,
         and the schema is its only source
phase:   verify
tip:     7c119fd（P30 apply）
verdict: PASS（六条行为面全部独立复现）· 1 条 finding（F1 门禁接线，归档前需 PM 裁定）· 2 条既有缺陷确认（P30 §8 已报）
```

## 0. 结论（一句话）

六条要对抗性验证的承诺**逐条独立复现**：group 逐字来自 schema 第 10 列（111 行/12 token，自有解析器比对）、
视图按功能域分组且顺序 = 读的顺序、class 是「词 + tone」两条通道、设置视图自己的滚轮消费事件且不穿透页面、
已归档 choice-editor 基线四条行为在真进程里逐条重跑全绿、i18n 双向与门禁结构钉成立。
**一条 finding**：design D7 与 `smoke.sh` 38-e 的注释都宣称慢 pty 场景（`panel-p21.sh settings/groups/wheel`）
在**完整门禁**里跑，实际 `smoke.sh` 里没有任何调用点 —— 全量门禁不覆盖它们（PM 需要决定补接线还是改文案）。
两条 apply 报告自报的既有缺陷（`choices-schema` 一条既有红、`TEAM_CONFIG_KEEP` 死开关）我都独立确认了（用 P30 之前的整棵树对照，不是旧测试配新 bundle）。

## 1. 方法：独立性与隔离

- **自写复验包** `docs/team/reports/P31-dev2/pkg/`（`lib.sh` + `run.sh` + 7 个分节 + `mut/`）：
  不引用 P30 的 `panel-p21.sh` 夹具/断言（只在其外的官方套件重跑里调用官方套件）；schema 走查是我自己
  从 `team_config_schema()` 函数体里拆的解析器（python），不是把被测实现的输出再读一遍。
- **每个分节独立夹具 + 私有 tmux**：`TMUX_TMPDIR=<本包私有目录>` + `-L <本包私有名>` +
  `env -u TMUX -u TMUX_PANE`；`lib.sh` 在会话建立后自检 `#{socket_path}` 必须落在私有目录，否则立即退出。
  默认 server 一次都没有被碰（每节的 `cleanup` 也只 kill 自己的私有 server）。
- **变体只在临时副本**：`variant_build` 把 `scripts/panel` 拷进 `$TMP`、软链 `node_modules`、在副本里改源码
  并重建 `panel.js`；主树一个字节都没动（结束时对比 `panel.js` sha256 = `c88acfd9c569…`）。
- **可重跑**：
  ```sh
  bash docs/team/reports/P31-dev2/pkg/run.sh            # 全部 7 节（约 12–15 分钟，含官方慢批、b3 与 3 次变体重建）
  bash docs/team/reports/P31-dev2/pkg/run.sh 10 20      # 只跑指定前缀的分节
  ```
  每节日志落在 `docs/team/reports/P31-dev2/logs/<分节>.log`；节末统一 `== <名> 结果 ==  ✓ n  ✗ m  findings f  skip s`。

## 2. 六条对抗性验证

### 2.1 单一真源：`group` 逐字 = schema 第 10 列（`memory-and-deps` ADDED）

命令：`bash docs/team/reports/P31-dev2/pkg/10-read-group.sh`（自有解析器 + 真 `team init` 夹具）

原始输出（节选）：

```
✓ 自有解析：schema 函数体拆出 111 行（key + 第 10 列）
✓ 自有解析的形状自查：rows=111 tokens=12，全部 token 匹配 ^[a-z][a-z0-9-]*$
✓ 全量比对：known=111 unknown=0 条记录的 group 与 schema 第 10 列逐条相等（键序也一致）
✓ samples ok: TEAM_PROJECT=identity, TEAM_PULSE_INTERVAL=panel, TEAM_DEFAULT_MODEL=seat-model, TEAM_GATES=workflow
✓ token 条数（自有解析 == read）：branch=11 delivery=13 identity=12 meeting=4 panel=7 patrol=4 pm-lifecycle=6 policy=16 roster=11 seat-model=3 session=10 workflow=14
✓ ok: TEAM_ZZZ_UNKNOWN group="" known=false（记录还在）
✓ human 表头仍是 KEY CLASS KIND VALUE
✓ human 表没有 group 列（TEAM_PROJECT 行不带 identity）
✓ team monitor --print / --json 都不带 group
✓ ok: TEAM_GATES 行仍在，group=""（缺列逐字为空）
✓ 走查判红并点名 TEAM_GATES（rc=1）
✓ ok: 畸形 token 逐字输出 group="NoPe!"（判红交给走查，read 不静默改值）
✓ 走查判红并点名键与畸形 token（rc=1）
✓ 真树 config-cli groups 绿（ ✓ 5 ✗ 0 SKIP 0）
✓ 写者段（writer cas validate audit）绿（ ✓ 54 ✗ 0 SKIP 0）
== 10-read-group.sh 结果 ==  ✓ 15  ✗ 0  findings 0  skip 0
```

边界说明（与 brief 措辞的差异，按 spec 判）：brief 写「未知键/缺 token/畸形 token → `""`」；delta spec 对
**畸形 token** 的要求是「逐字报告 + 走查判红」，不是 read 静默清空。实测 read 对 `NoPe!` **逐字**输出
（`group:"NoPe!"`），缺第 10 列输出 `""`，schema 不认识的键输出 `""` —— 与 spec 一致；畸形 token 的
可见降级在视图侧是「原始 token 作标题」（见 2.2），不是「未分组」。

### 2.2 不按生效类分组：12 个功能域标题、读取顺序、组内 schema 序（`panel` ADDED）

命令：`bash docs/team/reports/P31-dev2/pkg/20-view-grouping.sh`（真 bundle + 私有 tmux，焦点走完全部 114 行）

原始输出（节选）：

```
✓ i18n 静态面：12 个 group token zh/en 双侧齐全、无陈旧标签、类分组标签已删
✓ 读的期望焦点序：114 行（已知键 + 席位）
✓ 标题不是点击目标：点标题行坐标后焦点仍在第一行（身份与账本布局 行 4）
✓ 焦点行走：focus_seq=115 expected=114；焦点序逐位等于读的顺序（标题不是焦点目标）
✓ 标题首现顺序 = schema token 顺序：['身份与账本布局', '分支与 forge', '权限与依赖策略', '名册、模型解析与适配器', '按席位模型', '工作流与门禁', '容量与投递通知', '巡检与面板', '巡检策略', 'PM 生命周期', '活着的会话', '跨项目会议']
✓ 全程没有「只有类词」的行（视图没有按类分组）
✓ 席位块标题「席位」≠ seat-model 组标题「按席位模型」
✓ 新 schema 键（TEAM_ZZZ_TEST → workflow）落进 workflow 标题（已提交 bundle 不改一个字）
✓ TEAM_GATES 的 token 改成 meeting 后跟到跨项目会议标题（bundle 里没有键→域表）
✓ 三次渲染之间 panel.js 逐字节不变（sha=c88acfd9c569…）
✓ 缺第 10 列的 schema 行落在可见「未分组」组，行仍完整
✓ 未知键（schema 不认识）行仍在「未分组」，带未知键徽章与原始键名
✓ 畸形 token（NoPe!）以原始 token 作标题可见降级，行不消失
== 20-view-grouping.sh 结果 ==  ✓ 13  ✗ 0  findings 0  skip 0
```

「不硬编码」用的是**已提交的 bundle** + scratch CLI：schema 里把 `TEAM_GATES` 的 token 改到 `meeting`、
新加 `TEAM_ZZZ_TEST`（`workflow`），bundle 一个字不改，行跟着 token 走 —— 证明 bundle 里没有键→域表。
焦点行走逐位等于 `team config list --json` 的顺序（111 键 + 3 席位），标题不是焦点目标、不是点击目标
（点标题行坐标后焦点不动）—— 组内顺序与「walk 只停在键/席位行」都是行为面证据，不是读代码。

### 2.3 颜色不做唯一通道：词 + tone（`panel` ADDED，D4）

命令：`bash docs/team/reports/P31-dev2/pkg/30-word-tone.sh`（三类各一行：plain 捕获查词，`capture-pane -e` 查 tone）

原始输出（节选）：

```
✓ 三个类的样本行标签来自 zh 表：模型并发上限 / 巡检周期 / 项目名
WORD text: ok（模型并发上限 行带着徽章词 立即生效）
STRIPPED text: ok（剥掉 SGR 后徽章词仍在）
TONE text: ok（badge=#dfe3ea，值=#dfe3ea=text，palette=dark）
WORD warn: ok（巡检周期 行带着徽章词 需重启）
STRIPPED warn: ok（剥掉 SGR 后徽章词仍在）
TONE warn: ok（badge=#f2c66d，值=#dfe3ea=text，palette=dark）
WORD dim: ok（项目名 行带着徽章词 只读）
STRIPPED dim: ok（剥掉 SGR 后徽章词仍在）
TONE dim: ok（badge=#98a2b3，值=#dfe3ea=text，palette=dark）
✓ 已提交 bundle：三类都是「词 + 该类的 tone」，值保持 text tone（0 失败）
...
== 30-word-tone.sh 结果 ==  ✓ 5  ✗ 0  findings 0  skip 0
```

tone 断言不写死颜色：期望色从 `panel.js --palette` 读，活动调色板由「值的颜色 = 哪个调色板的 text tone」
现场判定（dark 命中）。**只用 tone 的变体**红侧见 §3。

### 2.4 滚轮（用户痛点）：视图自己的 offset、事件消费、焦点推窗、两个 picker（`panel` MODIFIED）

命令：`bash docs/team/reports/P31-dev2/pkg/40-wheel.sh`（page 3 先写 12 条巡检标记做「背后页面」对照）

原始输出（节选）：

```
PAGE ok: 页面滚得动（ZZ-01 出屏、ZZ-04 进屏）
TOP ok: 视图开屏焦点在第一行（项目名 / TEAM_PROJECT）
DOWN3 ok: 窗口移 3 行（↑3），第一行出窗，焦点不动（命令行仍 TEAM_PROJECT）
UP3 ok: 回到顶部、计数行消失
PUSH ok: ↓ 把窗口推到聚焦行（↑1，会话名 / TEAM_SESSION）
ENTER ok: enter 打开的是命令行点名的那行（TEAM_SESSION 的只读回执）
PICKER ok: 选择器滚轮走条目（选中行 6 → 8）
PICKERCLOSE ok: 一次 esc 关掉选择器（仍在设置视图）
SEAT ok: 席位 picker 滚轮走条目（5 → 7）
NOPASS ok: 视图里的滚轮没有穿透页面（页面还是进视图前的那一屏）
✓ 已提交 bundle：滚轮探针全项通过（0 失败）
...
== 40-wheel.sh 结果 ==  ✓ 3  ✗ 0  findings 0  skip 0
```

三处既有滚轮（页面/泳道/详情）不回归：`bash docs/team/reports/P31-dev2/pkg/60-official-regress.sh`（见 §4 原始输出）。

### 2.5 已归档基线：`settings-choice-editors` 四条行为逐条重跑

命令：`bash docs/team/reports/P31-dev2/pkg/50-baseline.sh`（自有夹具：未设 bool、危险值 `TEAM_MIN_FREE_SWAP_MB=0`、
未设数值键；`--refresh 3600` 保证「按键→帧」窗口里的子进程都是这次交互产生的）

原始输出（节选）：

```
✓ 交互路径零读取：打开选择器（按键→帧）之间 0 个子进程
✓ bool 选项一次 accept 完成直写（回执出现）
✓ argv 序列 = --dry-run → --yes（各带 64 位指纹）
✓ 直写没有确认帧、没有编辑器
✓ 契约里落了 0
✓ 一次 accept 审计恰好 +1
✓ 危险值第一次 accept 只给警告（出现「危险：」）
✓ 第一次 accept 后契约与审计都没动
✓ 警告之后选择器还开着（第二次 accept 在同一处）
✓ 第二次 accept 写入
✓ 写入 argv 带着 --allow-danger（命令的 danger 例外）
✓ 危险值第二次 accept 审计 +1
✓ 自由输入段仍零读取：进编辑器（按键→帧）之间 0 个子进程
✓ 「其他」路径打开的是写编辑器（数值键 → 自由输入）
✓ 编辑器第一次 Enter 只给确认行（→ 120），此时未写
✓ 确认阶段契约未变
✓ 编辑器第二次 Enter 写入并给出回执
✓ 自由输入的写也是 --dry-run → --yes
== 50-baseline.sh 结果 ==  ✓ 18  ✗ 0  findings 0  skip 0
```

官方 `panel-p21.sh choices` 整套重跑见 §4。写者路径不变的一句声明由官方 fixture 覆盖：
`config-cli.sh writer cas validate audit` ✓ 54 ✗ 0（§2.1 末两行）。

### 2.6 i18n 与门禁接线

命令：`bash docs/team/reports/P31-dev2/pkg/70-gates.sh`

原始输出：

```
✓ panel-strings.mjs 绿：ok: contract-group labels — 12 schema group tokens covered in zh and en
✓ scratch 原状：panel-strings 绿（红侧不是因为缺文件）
✓ 翻转①：两张表删掉 group_workflow → 断言非 0 并点名该 token（rc=1）
✓ 翻转②：加一个没有 schema 行使用的 group_zzz → 断言非 0 并点名陈旧标签（rc=1）
✓ 还原（主树）后 panel-strings 重新绿
✓ bundle 可复现：临时重建两次 = 已提交 panel.js（c88acfd9c569…）
✓ 38-e 结构钉存在（分组只读记录 / 滚轮先于页面消费，各带红侧）
✓ 38-e 没有 fast_skip：FAST 模式确实执行这些结构钉
● finding: 慢 pty 场景 panel-p21.sh settings/groups/wheel 在 smoke.sh 里**没有**任何调用点 ……
✓ openspec validate --all --strict：Totals: 16 passed, 0 failed (16 items)
== 70-gates.sh 结果 ==  ✓ 9  ✗ 0  findings 1  skip 0
```

## 3. Flip evidence（变异：红 → 绿）

### M-1 wheel 消费（brief 指定）——`mut/no-consume.sh`

把 App.tsx 鼠标分支里 `if (settingsViewRef.current) { … scrollSettings(delta); return }` 整块删掉，
临时副本重建 bundle，再跑同一支滚轮探针：

```
Red before（变体：删掉消费分支）:
DOWN3 BAD: 视图自己的窗口没有正好移 3 行（没有 ↑3 / 第一行还在 / 焦点动了）
NOPASS BAD: 页面被视图里的滚轮推动了（穿透）

Green after（还原成已提交 bundle）:
✓ 变体（删掉消费分支）：视图窗口不再动（DOWN3 红）且页面被穿透（NOPASS 红）——用户报的形状
✓ 还原（已提交 bundle，sha=c88acfd9c569…）后最小探针重新全绿：0 失败
```

### M-2 tone 通道（brief 第 3 条要求）——`mut/tone-only.sh`

`settingsClassTone` 恒返回 `text`（词留着、tone 的区分拿掉）：

```
Red before（变体：三类 tone 全塌成 text）:
TONE warn: BAD badge 颜色 #dfe3ea != warn tone #f2c66d（调色板 dark）
TONE dim: BAD badge 颜色 #dfe3ea != dim tone #98a2b3（调色板 dark）

Green after（还原成已提交 bundle）:
✓ 变体（三类 tone 全塌成 text）让 tone 断言红：2 处失败
✓ 同一变体上词通道仍全绿（3/3 行带徽章词；词与 tone 两条通道互相独立）
✓ 还原（已提交 bundle，sha=c88acfd9c569…）后探针重新全绿：0 失败
```

### M-3 schema token（brief 指定）——scratch CLI 树（`TEAM_CONFIG_TREE`）

`TEAM_GATES` 丢第 10 列 / `TEAM_PULSE_INTERVAL` 变成 `NoPe!`：官方 `config-cli.sh groups` 走查判红并点名，
还原（真树）绿（§2.1 第 11–14 行）。视图侧跟着看到可见降级（§2.2 后三行）。

**还原后工作树干净**：三组变体都只建在 `$TMP`（`variant_build`/`scratch_tree`），主树 `panel.js` 的 sha 在
每次探针末尾都验回 `c88acfd9c5690dfca7bd0d95b01db24b87fe328d86eb687d83c95792df14b9d7`；
`git status --porcelain` 见 §6。

## 4. 验收命令（原始输出）

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/smoke.sh </dev/null
node skills/teamsmith/tests/panel-strings.mjs
```

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 16 passed, 0 failed (16 items)

$ bash skills/teamsmith/tests/smoke.sh </dev/null          # 全量（05:02:47 → 05:16:15，约 13.5 分钟）
== 结果 ==  ✓ 2810  ✗ 0
smoke 全绿

$ node skills/teamsmith/tests/panel-strings.mjs
ok: contract-key labels — 111 schema keys covered in zh and en
ok: contract-group labels — 12 schema group tokens covered in zh and en
panel-strings: ok
```

全量 smoke 与官方 pty 套件是并发跑完的（loadavg 峰值 18）——仍然 ✓2810 ✗0，与 P30 报告的数字一致。

官方真进程套件（apply 报告点名的慢批；本包 60 节会整套重跑并留下完整日志）：

```
$ bash skills/teamsmith/tests/panel-p21.sh settings groups wheel
== 结果 ==  ✓ 87  ✗ 0        # settings ✓39 + groups ✓25 + wheel ✓23

$ bash skills/teamsmith/tests/panel-p21.sh choices
== 结果 ==  ✓ 110  ✗ 0       # 已归档基线的整套行为面

$ bash skills/teamsmith/tests/panel-b3.sh collapse     # 隔离重跑
== 结果 ==  ✓ 8  ✗ 0         # 首次与全量 smoke 并发（loadavg 18）时 collapse 两条假红；隔离后绿
```

安静机器上跑完整复验包（`bash docs/team/reports/P31-dev2/pkg/run.sh`）的总表：

```
10-read-group          ✓ 15  ✗ 0  findings 0  skip 0
20-view-grouping       ✓ 13  ✗ 0  findings 0  skip 0
30-word-tone           ✓ 5  ✗ 0  findings 0  skip 0
40-wheel               ✓ 3  ✗ 0  findings 0  skip 0
50-baseline            ✓ 18  ✗ 0  findings 0  skip 0
60-official-regress    ✓ 9  ✗ 0  findings 0  skip 0    # 含官方 b3 整套 ✓ 155 ✗ 0
70-gates               ✓ 9  ✗ 0  findings 1  skip 0
复验包：没有 ✗（finding 是记录，不是失败）
```

## 5. Findings

### F1（归档前需 PM 裁定）：慢 pty 场景没有接进全量门禁

**结论**：design D7 写着 “The slow pty scenarios run in the full gate (the brief's acceptance runs FAST)”，
`smoke.sh` 的 38-e 注释也写着 “pty 行为面（settings / groups / wheel 三个场景）在完整门禁里跑”；
但 `smoke.sh` 里根本没有这三支场景的调用点 —— 全量门禁只跑 `panel-p21.sh choices`。

```
$ grep -n 'panel-p21.sh' skills/teamsmith/tests/smoke.sh
11533:# 38-b pty 夹具：panel-p21.sh choices（…）——FAST 显式跳过。
11536:    fast_skip "38-b·panel-p21-choices" …
11539:    if bash "$SKILL_DIR/tests/panel-p21.sh" choices >…
11584:  assert_has "$SKILL_DIR/tests/panel-p21.sh" "按键→帧之间零读取" …
11585:  assert_has "$SKILL_DIR/tests/panel-p21.sh" "argv_reads" …
（没有任何 settings / groups / wheel 的调用）
```

- 影响：settings/groups/wheel 的行为面只靠 FAST 的两条结构钉（分组只读记录、滚轮先于页面消费）
  与手工运行兜底；例如「下滚 3 格 = ↑3」「不穿透页面」「未分组降级」这些行为回归，全量门禁不会红。
- 代价参考：官方三支场景一次约 1–2 分钟（05:01:57 START → 约 05:04 前出 `✓87 ✗0`）。
- 出路（PM 选）：(a) 在 smoke 里加一段跑 `panel-p21.sh settings groups wheel`（FAST 显式 skip）；
  或 (b) 接受「慢 pty 手工跑」的现状，但把 design D7 与 38-e 注释改掉（消除死宣称）。

### F2（确认，既有，与 P30 §8.1 一致）：`choices-schema` 一条既有红

```
$ bash skills/teamsmith/tests/panel-p21.sh choices-schema
✗ enum 是封闭域：没有自由输入项（不该出现 [自由输入]）
== 结果 ==  ✓ 8  ✗ 1

$ git archive 7c119fd^ | tar -x -C /tmp/p31-pre30 \
  && bash /tmp/p31-pre30/skills/teamsmith/tests/panel-p21.sh choices-schema
✗ enum 是封闭域：没有自由输入项（不该出现 [自由输入]）
== 结果 ==  ✓ 8  ✗ 1          # 与 P30 之前的树逐字相同 → 既有红
```

该断言在 7c119fd^ 里就存在（旧文件第 935 行），P30 的 diff 没有碰它；它撞的是选择器**提示行**里的
「自由输入」字样（不是自由输入条目）。场景不在任何门禁里（全量只跑 `choices`），所以一直潜伏。
P30 报告用「旧测试 + 新 bundle」做对照是不成立的（旧测试的 `open_view` 等 `立即生效` 标题，而 P30
把类标题删了 → 超时级联）；本报告用**P30 之前的整棵树**（bundle + 测试）对照，结论一致。

### F3（确认，既有，与 P30 §8.2 一致）：`TEAM_CONFIG_KEEP` 是死开关

```
$ grep -n 'keep=' skills/teamsmith/tests/config-cli.sh
33:keep="${TEAM_CONFIG_KEEP:-0}"     # 在它之前（第 18–22 行）的 TEAM_* 清理已经把旋钮删了
$ TEAM_CONFIG_KEEP=1 bash skills/teamsmith/tests/config-cli.sh list | grep 保留
（无输出）
```

两步都不在本 change 的实现面里：F2/F3 都在 `tests/**`（agent:dev），是否派单由 PM 定。

### 说明：b3 并发假红（不是 finding）

首次官方 b3 与全量 smoke 并发（loadavg 18）时 `collapse` 场景 2 条断言读不到控制台文案；
隔离重跑（`panel-b3.sh collapse`）`✓8 ✗0`，复验包 60 节在安静机器上跑整套 b3 是 `✓155 ✗0`（日志
`logs/60-official-b3.log`）。这两条红与本 change 无关（collapse 场景不碰设置视图）。

## 6. 记录

- 被验 tip：`7c119fd`（P30 apply，已在保护分支）；本复验没有改实现。三组变体/探针结束后：
  ```
  $ git status --porcelain | grep -v '^??'
  （无输出 —— 没有任何已跟踪文件被改动；panel.js 的 git diff 为空）
  $ git status --porcelain
  ?? docs/team/reports/P31-dev2.md
  ?? docs/team/reports/P31-dev2/
  ```
  两个未跟踪项就是本任务的交付物（报告 + 复验包/日志），交付提交后 `git status --porcelain` 为空。
- `panel.js`：`c88acfd9c5690dfca7bd0d95b01db24b87fe328d86eb687d83c95792df14b9d7`（在所有变体/探针
  结束时都验回原值；临时副本重建两次逐字节相同）。
- 复验包：`docs/team/reports/P31-dev2/pkg/{lib.sh,run.sh,10-…,20-…,30-…,40-…,50-…,60-…,70-…,mut/}`；
  日志：`docs/team/reports/P31-dev2/logs/`（含官方三套完整日志与全量 smoke/官方的背景日志）。
- 复验断言总计：**✓ 72 ✗ 0，1 finding**（六条全部独立复现；finding 只有 F1）。
- 变异：M-1 滚轮消费（40 节）、M-2 tone 通道（30 节）、M-3 schema token（10/20 节，官方走查红侧）——
  全部只在 `$TMP` 副本里发生，还原后主树逐字节未动。

