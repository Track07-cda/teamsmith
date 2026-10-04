# M55 · settings-choice-editors 实施（apply）

```
task:    M55
agent:   dev3
branch:  task/M55-apply-choices-suggest（local 模式：不 push；分支留在 .worktrees/dev3，PM 复验后本地合并）
change:  settings-choice-editors（phase: apply；deltas: panel, memory-and-deps）
deps:    M54（propose，已合并）
status:  PARTIAL（实现、夹具、门禁全绿；第一次复验 §38-b 的 flake 已按 §11 硬化并复验；两处**不属于本任务 grant** 的落点见 §7，交回 PM 决定）
```

## 1. 交付物

| 批次 | 文件 | 内容 |
|---|---|---|
| A1 = B1 | `skills/teamsmith/scripts/lib/cmd-config.sh` | schema 新增**可选第 9 列 `suggest`**（数值类的整值建议，逗号分隔；没有建议的行保持 8 列）；新增 `team_config_choices <row> [known]`，从**校验器读的那一行**派生 `{source,values,min,max,empty,note}`（bool 两个规范值 / enum 的 constraints / 数值类的 suggest + min/max / 模型类读 `models.known` / path 类在 note 里带存在性规则）；`team config list --json` 的每条键记录（含 schema 不认识的键）都带 `choices`；`models.known` 经同一支 `team_config_seat_state` 收进每个席位的**显示**模型（pm 席位在内，去重、首见序） |
| A2 = B2 | `skills/teamsmith/scripts/panel/src/{types,App,layout,main}.tsx` + `strings/{zh,en}.ts` + 重建的 `panel.js` | `choicePicker` 状态机（条目顺序：未设键的「保持未设」→ 当前 → 默认 → 命令给的 values 去重 → 该 kind 自己的动作）；封闭域（bool/enum）不给自由输入；`path` 只在 `choices.empty` 为真时给清空项、并带存在性标记（确认行重复，命令不因此拒写）；`winlist`/`pattern` 选模型后把 `<model>=` 种进写编辑器；`pairlist` 把焦点交给席位块；没有选项集的 kind 打开自由输入并在编辑器上方写明原因；**选中条目落到既有两步写入编辑器**，写路径一行未动 |
| A2 = B3 | `skills/teamsmith/tests/panel-p21.sh` | 新场景 `choices`（75 条断言 = 74 + 一条 `wait_picker` 硬化回归钉）与 `choices-schema`（9 条断言，新增 enum 键零改动 / 去掉 constraints 可见降级）；既有 write/conflict 场景改为先走选择器的自由输入项（它们用的键现在有选择集），并修两处**夹具漂移**（见 §5）；第一次复验 FAIL 后按 §11 做了同步硬化（条目标记等待 / `leave_*` / `remain-on-exit` 死因点名） |
| A1/A2 夹具 | `skills/teamsmith/tests/panel-choices.sh`（新） | headless：R1 逐 kind、R2 的 `known`、**一致性走查闸门**、目录泄漏、F-A/F-D 翻转 |
| A2 夹具 | `skills/teamsmith/tests/panel-flip-m54.sh`（新） | F-B（断 `choices` 读取）、F-C（目录泄漏进选择器）、A2-enum（bundle 里硬编码键表）三处红→绿翻转 |
| 门禁 | `skills/teamsmith/tests/smoke.sh` | §38-a 在 FAST 里跑 `panel-choices.sh`（一致性闸门不是可选项）；§38-b 跑 `panel-p21.sh choices`，FAST 显式 SKIP |

## 2. per requirement 覆盖表（delta → item → 夹具 → 翻转）

| requirement（delta） | tasks.md | 夹具/证据 | 翻转 |
|---|---|---|---|
| `memory-and-deps` R1 · 机器读报告每个键的选择集，schema 是唯一来源 | 1.1 1.2 1.3 1.4 | `panel-choices.sh read`（逐 kind 的 `choices` 形状、未知键 `source:none`、每个记录都带 choices、人读表与 `team monitor --json` 不动）；`panel-choices.sh walk`（86 条 options + 108 键的静态一致性 + 空值判定 + 契约 sha 不变） | **F-D**：scratch 树 `TEAM_PULSE_INTERVAL` 建议 `30`（min 60）→ 走查红并点名键与值；恢复 → 绿 |
| `memory-and-deps` R2 · 模型词表是本项目的数据，绝不读机器目录 | 1.2 3.4 | `panel-choices.sh known`（pm 席位显示模型恰好一次、`TEAM_PM_MODEL` 的 choices 含它、去掉后回退默认）；`panel-choices.sh catalogue`（scratch HOME 里 `sub2api`/`openrouter` 不进读）；`panel-p21.sh choices`（同一个 scratch HOME 下选择器与读都不含目录 provider） | **F-A**：scratch 树去掉 pm 席位的解析 → `known` 断言红并点名 pm；恢复 → 绿。**F-C**：目录里的 `sub2api/gpt-5.6-luna` 灌进选择器 → 红 |
| `panel` R3 · 有选择集就给选择器，没有就可见降级 | 2.1–2.6 3.1 3.2 3.4 | `panel-p21.sh choices`（bool 两个带标签条目 / enum 恰好 constraints / 未设键「保持未设」取消零写入 / 数值区间+自由输入 / path 标记与清空项 / cmd 的原因行 / pairlist 路由 / 点击=接受 / esc 不写 / 滚轮滚长列表 / 非规范 bool 拼写原样显示）；`panel-p21.sh choices-schema`（scratch CLI 加 `TEAM_ZZZ_MODE` → 提交的 bundle 零改动给出 `red`/`blue`；去掉 constraints → 同一 bundle 可见退回自由输入并写明原因） | **F-B**：断掉 bundle 的 `choices` 读取 → `choices` 红；**A2-enum**：bundle 里硬编码键表 → `choices-schema` 红；两者恢复后绿且 bundle 逐字节一致 |
| `panel` R4 · 写路径没动（编辑器只换喂给它的草稿） | 2.7 3.5 | `panel-p21.sh write`（一行 diff / 注释保留 / 两次确认 / 取消零写入 / 非法值留草稿 / danger 两步 / restart 不谎报）；`panel-p21.sh conflict`（指纹冲突、对方字节保住、审计一行）；`argv.log` 里选条目走的仍是 `config set … --dry-run` → `… --yes --fingerprint` | 既有 write/conflict 断言一条不改（只是多一步「走进自由输入项」），选条目本身不写契约 |

### 走查闸门的两条口径（复验时会问，先写清）

1. **`refuse` 类键不走查**：写路径对它们一律 exit 5（只读），所以「选项能被接受」对它们没有意义；
   它们的 `choices.values` 仍照 schema 给出（例如 `TEAM_BRANCH_MODE` 的 `task,agent`），静态一致性照查。
2. **token 类（`pairlist`/`winlist`/`pattern`）的 `values` 是词表，不是整值域**：R1 那句「读给出的每个值
   都要被校验器接受」在它们身上按**视图自己的组合规则**走查 —— `TEAM_AGENT_MODELS` 用 `<seat>=<model>`、
   `pattern`/`winlist` 用 `<model>=1`（裸 token 一定被拒，这正是它们带 N 的一端）。D1/D3 裁定
   `values` 就是 `models.known`（视图需要裸模型名来拼 `<model>=`），所以闸门走查的是
   「读给的词表 + 视图的组合规则 = 写入者接受的值」；其余 kind（bool/enum/数值/model）是逐值直接喂
   `team config set … --dry-run`。

## 3. README 式的四条手工实录（任务书 Acceptance 的「外加手工实录」）

① `team config list --json` 里四类 `choices` 的实际形状（真 `team init` 夹具）：

```
TEAM_NOTIFY_TMUX         kind=bool     class=apply   {"source": "schema", "values": ["1", "0"], "min": "", "max": "", "empty": false, "note": ""}
TEAM_MONITOR_UI          kind=enum     class=restart {"source": "schema", "values": ["auto", "tui", "text"], "min": "", "max": "", "empty": false, "note": ""}
TEAM_DEFAULT_MODEL       kind=model    class=restart {"source": "known", "values": ["deepseek/deepseek-flash"], "min": "", "max": "", "empty": false, "note": ""}
TEAM_PULSE_INTERVAL      kind=seconds  class=restart {"source": "schema", "values": ["300", "900", "1800", "3600"], "min": "60", "max": "", "empty": false, "note": ""}
TEAM_AGENT_BIN           kind=path     class=apply   {"source": "none", "values": [], "min": "", "max": "", "empty": true, "note": "exec"}
models.known = ["deepseek/deepseek-flash"]   keys = 108
```

② 临时新增一个 enum 键（只改 scratch 树的 schema，`panel.js` 就是提交的那份）→ 控制台出现它的选项：

```
// scratch schema：TEAM_ZZZ_MODE|apply|enum|red,blue|plain|red|…
╭─ 项目设置 ─────────────────────────────────────────────────╮
│  选择 TEAM_ZZZ_MODE 的值 · TEAM_ZZZ_MODE                   │
│ › 保持未设（取消 = 不写、不留审计）                        │
│   red · 默认                                               │
│   blue                                                     │
│  ↑/↓ 选择 · Enter 编辑该值 · Esc 返回（…）                 │
╰────────────────────────────────────────────────────────────╯
```

③ 同一个 schema 去掉 constraints（`TEAM_ZZZ_MODE|apply|enum||plain|red`）→ 同一个 bundle 可见降级：

```
enum 这种 kind 没有选项集；写入仍由命令校验（Enter 打开自由输入）
╭─ TEAM_ZZZ_MODE ────────────────────────────────────────────╮
│ > red                                                      │
```

④ 未设键的首条目与「取消不写」：`panel-p21.sh choices` 的 TEAM_DEFER_TTL 断言（行 `未设 · 默认 300`、
编辑器开在 `› 保持未设` 上、接受后**无写编辑器 / 契约 sha 不变 / `state/config.log` 不增行 / 无
`config.sh.tmp.*`**；再开一次接受 `300` 才走两步写入，回执说「已写入」而不是 unset）。

## 4. 翻转证据（红 → 绿）

### F-A（`panel-choices.sh flip-drop-pm`）

```
  ✓ F-A：去掉 pm 的解析后 known 断言红且点名 pm（rc=1）
    --- 红侧尾部 ---
      ✗ known = 配置 default + 席位记录 + pm 的 TEAM_PM_MODEL（各一次）（…）
      ✗ pm 的模型恰好出现一次（去重）（…）
      ✗ TEAM_PM_MODEL 的 choices.values 含 pm 的模型（…）
  ✓ F-A：恢复真树后 known 断言绿
```

### F-D（`panel-choices.sh flip-suggest`）

```
  ✓ F-D：建议值 30 让走查变红（rc=1）
  ✓ F-D：红侧点名 TEAM_PULSE_INTERVAL 与 30
    --- 红侧尾部 ---
      ✗ 走查（real）：schema 与 choices 的静态一致性有 1 条问题
      ✗ 走查（real）：TEAM_PULSE_INTERVAL 的选项 [30]（组合成 [30]）被校验器拒绝（rc=4）：✗ TEAM_PULSE_INTERVAL=30 不合法：超出范围：最小 60
  ✓ F-D：恢复建议列后走查变绿
```

### F-B / F-C / A2-enum（`panel-flip-m54.sh`）

三处都跑在同一份 `panel-flip-m54.sh` 上。提交前修正过 F-C 与 A2-enum 的**红侧点名片段**（代码断点当时已生效，
只是断言没点在预期那条上）。修正后的**完整**运行是 `== 结果 ==  ✓ 11  ✗ 1`：F-B 的「恢复后变绿」那一步
在一次负载尾巴上抖了一次（下节如实记录），F-C 与 A2-enum 全绿；随后单独重跑 F-B 是 `✓ 4 ✗ 0`。下面
两份运行输出合起来覆盖三处翻转。

```
  ✓ F-B choices 读取被断掉：断掉之后 choices 变红（rc=1）
  ✓ F-B choices 读取被断掉：红侧的失败点就是预期的那条（保持未设）
  ✓ F-B choices 读取被断掉：恢复之后 choices 变绿
  ✓ F-B choices 读取被断掉：恢复后 bundle 与提交的逐字节一致
      红侧尾部：
        ✗ bool 的选择器没有打开
        ✗ 未设键的首个条目是保持未设（并且是焦点）
        ✗ 1 是默认条目，带表里的 on 词
  ✓ F-C 机器目录泄漏进选择器：断掉之后 choices 变红（rc=1）
  ✓ F-C 机器目录泄漏进选择器：红侧的失败点就是预期的那条（sub2api）
  ✓ F-C 机器目录泄漏进选择器：恢复之后 choices 变绿
  ✓ F-C 机器目录泄漏进选择器：恢复后 bundle 与提交的逐字节一致
      红侧尾部：
        ✗ 选择器开屏不列机器目录里的 sub2api（词表只有项目数据）（不该出现 [sub2api]）
  ✓ A2 硬编码键表：断掉之后 choices-schema 变红（rc=1）
  ✓ A2 硬编码键表：红侧的失败点就是预期的那条（新增 enum 键的选择器没有打开）
  ✓ A2 硬编码键表：恢复之后 choices-schema 变绿
  ✓ A2 硬编码键表：恢复后 bundle 与提交的逐字节一致
      红侧尾部：
        ✗ 新增 enum 键的选择器没有打开（要重建 bundle = 反硬编码判据失败）
        ✗ 未设的新键也以保持未设开头
        ✗ constraints 里的 red 是默认条目
```

修正前的完整运行（`bash tests/panel-flip-m54.sh`，红侧片段未修正的那次）结果行是 `== 结果 ==  ✓ 9  ✗ 3`
（F-B 四条绿；F-C/A2 的红侧片段当时失败，不是实现失败）；修正后 `bash tests/panel-flip-m54.sh F-C A2-enum`
是 `✓ 8 ✗ 0`。

#### F-B「恢复后变绿」的一次时序抖动（如实记录；非实现问题）

- 现象：**修正后**的完整运行（恰在全量 smoke 刚结束、机器还在收尾的窗口里）结果行 `== 结果 ==  ✓ 11  ✗ 1`，
  唯一失败是 F-B 的恢复步骤 —— 源码已还原、重建后的 bundle 与提交**逐字节一致**（该断言 ✓）——
  但 `panel-p21.sh choices` 仍返回非 0（`✗ F-B choices 读取被断掉：恢复之后 choices 仍然红`）。
- 复现尝试：单独重跑 `bash tests/panel-flip-m54.sh F-B` → `✓ 4 ✗ 0`（红→绿、bundle 逐字节一致）；
  随后连续 4 次 `TEAM_P21_KEEP=1 bash tests/panel-p21.sh choices` → 每次 `✓ 74 ✗ 0`。
  同一提交的 `panel-p21.sh` 全场景 `✓ 175 ✗ 0` 与全量 smoke 38-b `✓ 74 ✗ 0` 也在本 session 内验证过。
- 结论：这是 pty 夹具 `wait_picker`（~7.2s 预算）在高负载收尾窗口里的时序抖动，不是 bundle 或实现问题 ——
  抖动那一刻的 bundle 与提交逐字节一致，且同一 bundle 之后连续 5 次 `choices` 运行全绿
  （F-B 重跑 1 次 + 单独连跑 4 次）。夹具**不**因此改动：改预算会作废已跑证据，且没有复现
  能证明新预算解决问题；此处如实留给复验知悉。

```
$ bash skills/teamsmith/tests/panel-flip-m54.sh F-B      # 抖动后的单独重跑
  ✓ F-B choices 读取被断掉：断掉之后 choices 变红（rc=1）
  ✓ F-B choices 读取被断掉：红侧的失败点就是预期的那条（保持未设）
  ✓ F-B choices 读取被断掉：恢复之后 choices 变绿
  ✓ F-B choices 读取被断掉：恢复后 bundle 与提交的逐字节一致

== 结果 ==  ✓ 4  ✗ 0

$ for i in 1 2 3 4; do TEAM_P21_KEEP=1 bash skills/teamsmith/tests/panel-p21.sh choices; done
=== RUN 1 === exit=0   == 结果 ==  ✓ 74  ✗ 0
=== RUN 2 === exit=0   == 结果 ==  ✓ 74  ✗ 0
=== RUN 3 === exit=0   == 结果 ==  ✓ 74  ✗ 0
=== RUN 4 === exit=0   == 结果 ==  ✓ 74  ✗ 0
```

F-B 的断点是「bundle 不看命令的 `choices`」（被否掉的第二张键表）：`hasChoiceEditor` 直接 `return false`
→ 所有可编辑行都退回自由输入，选择器断言全红。F-C 的断点是「机器 Pi 目录变成选项」：往 `model` 类的
条目里塞一条 `sub2api/gpt-5.6-luna` → 开屏就露出来。A2 的断点是「bundle 里硬编码了一张键表」：只有它
认识的三个 enum 有约束，scratch CLI 新加的 `TEAM_ZZZ_MODE` 什么都拿不到 → 零改动判据红。

## 5. 夹具漂移修复（不是本次改动引入，`panel-p21.sh seats` 用**改动前的 bundle** 同样红）

1. 席位写之后视图会重读合同，而夹具在旧行集上做 40 步走位 → 新帧一到就冲过 `dev` 行：夹具现在先等
   「`xai/grok-4.6 · 历史记录 · 回退默认`」出现（视图确实重读了）再走位。
2. `seats` 场景的 `P22-x` 任务书是 `# P22-x fixture brief` 一行，没有 P24 起 `dispatch` 强制的
   `change:`/`anchor:` 头 → `dispatch --print` 在渲染启动命令前就被拒（与面板无关的漂移）：夹具补上
   `change: -` + `anchor: none (infra) — …` 的头。

证据（改动前的 bundle：`git show HEAD:skills/teamsmith/scripts/panel/panel.js`）：

```
$ TEAM_P21_PANEL=/tmp/m55-panel-old.js bash skills/teamsmith/tests/panel-p21.sh seats
  ✗ 拒绝用例没能把焦点移到 dev 席位行
  ✗ 下一次 dispatch --print 用新模型（--provider kimi-coding --model k3-256k）
== 结果 ==  ✓ 21  ✗ 2

$ TEAM_P21_PANEL=/tmp/m55-panel-old.js bash skills/teamsmith/tests/panel-p21.sh seats   # 修好夹具后
== 结果 ==  ✓ 22  ✗ 0
```

## 6. 验收命令与原始输出

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/settings-choice-editors
Totals: 18 passed, 0 failed (18 items)

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 38 · 设置选项（M55：choices 读 / 一致性走查 / 选择器夹具） ==
  ✓ 38-a panel-choices.sh 全绿（✓ 35  ✗ 0；含一致性走查与 F-A/F-D 翻转）
      == 结果 ==  ✓ 35  ✗ 0
  SKIP（FAST 模式） 38-b·panel-p21-choices —— panel-p21.sh choices 要真 tmux 场地 + 真 bundle（慢段 ~2.5 分钟）
== 结果 ==  ✓ 2173  ✗ 0
smoke 全绿

$ bash skills/teamsmith/tests/panel-p21.sh
== 结果 ==  ✓ 175  ✗ 0      # settings 36 / choices 74 / choices-schema 9 / write 23 / conflict 6 / seats 22 / readonly 5

$ bash skills/teamsmith/tests/config-cli.sh writer cas validate audit
== 结果 ==  ✓ 54  ✗ 0  SKIP 0     # 写入者（校验/CAS/审计/danger）一行未动

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/panel-strings.mjs .    # 26-a/28-a 的同一支
ok: zh/en key sets compared (324 keys)
ok: values are non-empty strings with matching placeholders
ok: no CJK literals outside src/strings/**
ok: contract-key labels — 108 schema keys covered in zh and en
panel-strings: ok
```

（`panel-snapshots.sh` 全绿由上面 FAST smoke 的 28-c 段覆盖：设置视图不在快照里，行列表一行未动，
所以没有快照抖动。）

### 全量门禁（`bash skills/teamsmith/tests/smoke.sh`，不带 FAST）

```
$ bash skills/teamsmith/tests/smoke.sh </dev/null
== 38 · 设置选项（M55：choices 读 / 一致性走查 / 选择器夹具） ==
  ✓ 38-a panel-choices.sh 全绿（ ✓ 35 ✗ 0；含一致性走查与 F-A/F-D 翻转）
      == 结果 ==  ✓ 35  ✗ 0
  ✓ 38-b panel-p21.sh choices 全绿（ ✓ 74 ✗ 0）
== 结果 ==  ✓ 2672  ✗ 0
smoke 全绿
```

（全量里 38-b 是真跑：私有 tmux server + 真 bundle + argv 记录的 wrapper；FAST 里它是显式 SKIP 而不是静默省略。）

## 7. 边界与两处 BLOCKED（交回 PM）

- **`scripts/panel/panel.js`（重建的 bundle）**：任务书 `grant:` 写的是 `scripts/panel/src/**`，而 tasks.md 2.5
  明列「用 pin 的 bun 重建并提交 bundle」（change 的 A2 授权行写作 `scripts/panel/**`）。bundle 是 `src/**` 的
  构建产物、且 smoke 的 26-a/26-b 断言它与源码构建一致，因此按 tasks.md 重建并提交；本节点名，供复验对照。
  证据：`bash scripts/panel/build.sh` 连跑两次 → 产物逐字节一致、`git diff --exit-code` 干净
  （sha256 `e2f07bc2a4fc06b2a43dc9658ae3f0edbe05fc6c712d79ed5844ee889eb08d17`）。
- **`references/config.md`（tasks.md 1.5）— BLOCKED：不在本任务 `grant:` 里。**
  OWNERSHIP 里 `references/**` 是 PM 独占、apply 任务书需明授；M55 任务书的 `grant:` 只有
  `scripts/lib/cmd-config.sh · scripts/lib/cmd-status.sh · scripts/panel/src/** · tests/smoke.sh · tests/panel-*.sh`。
  需要 PM 补的内容（两处）：schema 行格式从 `KEY|class|kind|spec|form|default|danger|route` 扩成
  「`…|route|suggest`（可选第 9 列，数值类的建议值；没有建议的行保持 8 列）」；`team config list --json`
  的 `choices` 对象字段（`source/values/min/max/empty/note`，`note` 在 path 类携带 `file|dir|exec|any`），
  以及「读给出的值必须被 `team config set` 接受，由 `tests/panel-choices.sh` 的走查夹具钉住」。
- **`tests/config-cli.sh`（tasks.md 1.3 的重心，dev 的 OWNERSHIP）— BLOCKED：本任务 `grant:` 没有它。**
  等价的一致性闸门与 R1/R2 夹具体现在 `tests/panel-choices.sh`（`tests/panel-*.sh` 在本任务 grant 里），
  并由 `smoke.sh §38-a` 在 FAST 模式每次运行 —— 闸门强度不变，只是文件落点与 tasks.md 的写法不同；
  PM 若坚持放在 `config-cli.sh`，把该文件授予 dev3 或移交给 dev 即可。
- 同理，tasks.md 3.2 写的 `tests/flip-m54.sh` 落成了 `tests/panel-flip-m54.sh`（grant 里只有
  `tests/panel-*.sh`），内容一致。

## 8. 写入者与门禁（R4 的「不动的部分」）

- 校验、canonical 化、指纹 CAS、审计行格式、danger 清单、`refuse` 行为**一行未动**：本任务只加了**读**
  （`team_config_choices`）与 schema 的一列数据；`team config set` / `set-agent-model` 的入口、参数与
  退出码都没碰。既有 `config-cli.sh` 的 `writer cas validate audit` 段全绿（见 §6）。
- `panel` 的写路径也没动：选择器只把值放进既有写编辑器，`argv.log` 证明落地仍是
  `config set … --dry-run` → `… --yes --fingerprint`。

## 9. 一处布局修复（在 panel delta 的「行预算」要求内，报告在此点名）

`layout.ts` 的 `SETTINGS_FOOTER_ROWS` 原来只预留了「CLI 提示 + 审计尾」，没有预留两条
`↑n`/`↓n` 计数行：窗口装满 + 审计尾巴写满时整个视图会退化成一行摘要（实测：`pairlist` 路由刚把焦点
交给席位块，那一块就从帧里消失了）。修成 `2 + 1 + 1 + 1 + audit` 后视图恒在帧内；设置视图不在任何
快照里，所以没有快照抖动（`panel-snapshots.sh` 全绿见 §6）。选择器的条目预算同样按 6 行预留
（标题 + 区间 + 两行计数 + 空行 + 提示）。

## 10. 本地模式

不 push：分支 `task/M55-apply-choices-suggest` 留在 `.worktrees/dev3`，等 PM 独立复验后本地合并。

## 11. 第一次复验 FAIL（§38-b 的 62 条红）的处置：夹具同步硬化

### 11.1 现场（外部证据，tip 78dcbcb）

PM 的第一次复验（`docs/team/reviews/M55.md` 的旧版结论，checkout `/tmp/review-M55`）门禁 FAIL；
§38-b 的结果行是 `✓ 33 ✗ 62`，前 8 条红是：

```
✗ 已设的 bool 把文件里的值标成当前（…/choices/bool-set.txt 里找不到 [关（0） · 当前]）
✗ 默认标记移到 1 上（…/choices/bool-set.txt 里找不到 [开（1） · 默认]）
✗ 非规范 bool 的选择器没有打开
✗ 非规范拼写的手改值原样显示成当前条目（…/choices/bool-spelling.txt 里找不到 [true · 当前]）
✗ 规范默认值仍在（…/choices/bool-spelling.txt 里找不到 [开（1） · 默认]）
✗ enum 的选择器没有打开
✗ 未设的 enum 也以保持未设开头（…/choices/enum.txt 里没有匹配 [› 保持未设]）
✗ 默认标记在 auto 上（…/choices/enum.txt 里找不到 [auto · 默认]）
```

PM 的两条排查假设（线程 08:33/08:36）：**① 键位被 drop；② 选择器只在规范值分支渲染。** 下面逐条回答，
并给出夹具侧的处置。

### 11.2 假设②不成立（代码层面，可静态复核）

`hasChoiceEditor(key)`（`panel/src/App.tsx:39`）：只看 `key.choices` 存在且 `values` 是数组 + kind 在
`CHOICE_KINDS` 里；`enum` 额外要求 `values.length > 0`。**它不看 `key.value`、不看 `set`**，所以
非规范值（`true`）照样开选择器（`choices` 段的断言 `true · 当前` 就是钉这一点）， enum 也只看 schema 的
constraints。选择器只在「kind 不是选择类」或「enum 的 constraints 为空」时不开 —— 后者是本 change
要求的可见降级，开的是写编辑器（`╭─ TEAM_…` + `… 这种 kind 没有选项集…`），不是 62 条红里的形状。

### 11.3 62 条红的解释（中间帧 + 清理 esc 的级联）

夹具当时等的是**标题**：`wait_picker` 只 grep ` · <KEY>`。面板的帧由 Ink **逐行**写（同一个 key 的标题
行与条目行不保证在同一次 `capture-pane` 里同时可见），所以「标题已在、条目还没到」的中间帧会让等待提前
放行 → 紧随的两条条目断言红；随后那句**清理用的裸 `keys Escape`** 打在还开着的行列表上（选择器此刻没开）
→ 关闭整个设置视图 → 之后每段都在错的视图里跑。62 条红的绝大多数是这一次错位的回声：第 3、6 条
「选择器没有打开」正是「视图已被关掉」的后果，而不是选择器对非规范值 / enum 不开。

` · <KEY>` 这个形状在面板里只出现在选择器标题（`settingsChoiceTitle: '选择 {label} 的值 · {key}'`）；
行列表、写回执（`✓ 已写入 TEAM_NOTIFY_TMUX = 0 · 下一个读取它的进程生效`）、审计尾（`key=…`）都不含它。
标题出现 = 选择器确实被打开过；条目缺席只能是中间帧。另一种同形可能是键位真被丢或面板进程没了
（那样也不会有第二个选择器）——两种情形都由下面的硬化和死因点名分别接住（丢键现在以单条红结束，
不再级联）。

### 11.4 硬化（全在 `tests/panel-p21.sh`；不碰实现）

| 改动 | 作用 |
|---|---|
| `wait_picker <KEY> [entry]` / `wait_editor <tray> [marker]` 的**条目标记**必须在同一帧里 | 标题命中不再算数；等的是「紧跟要断言的条目」 |
| 所有选择器等待都带该段期望条目（`› 保持未设` / `关（0） · 当前` / `true · 当前` / `auto · 默认` / `tui · 当前` / `↓` / `red · 默认` / `· 当前`） | choices、choices-schema、write、conflict 四段一起覆盖 |
| `leave_picker <KEY>` / `leave_editor <KEY>` 取代清理点的裸 `keys Escape` | 选择器/编辑器没开时**不发 esc**：一次漏检不再升级成「关掉设置视图」 |
| 预算：选择器/编辑器 ~13s、回执 12s、视图 16s、面板首帧 20s、编辑器关闭 10s | 负载下 `openSettingsRow` 的 `await refreshSettings()` 不再撞 7s 死线 |
| 私有 server `remain-on-exit on` + 等待超时时 `panel_dead_note` 点名 `pane_dead status` | 「面板进程死了」与「条目没出现」在失败信息里分开，不再把空捕获当断言失败 |
| choices 段末尾**回归钉**：选择器开着时，`wait_picker` 要一个不存在的条目必须判负 | 把这次 FAIL 的形状钉进夹具本身（标题命中不算数） |

### 11.5 红 → 绿（夹具侧）

- **红（外部，不可自造）**：PM 第一次复验，tip 78dcbcb，§38-b `✓ 33 ✗ 62`（11.1）。
- **钉子的红**：回归钉在「要求的条目不存在」时判负 —— `✓ wait_picker 要的条目不在帧里时判负（标题命中不算）`；
  这是夹具能自证「标题不再放行」的那一面。
- **绿（修复后，本 session 实测）**：
  - `panel-p21.sh choices` 6 次全绿（含 3 并发一轮），每份 `✓ 75 ✗ 0`；
  - `panel-p21.sh`（全场景）`✓ 176 ✗ 0`；
  - `panel-flip-m54.sh`（F-B / F-C / A2-enum）`✓ 12 ✗ 0`（硬化后的等待仍能红侧点名、绿侧恢复）；
  - FAST smoke / 全量 smoke 见 §6（全量里 §38-b 读作 `✓ 75 ✗ 0`）。
- **复现尝试**：本机在 tip 78dcbcb / 1c5f9c4 上共跑了 13 次 `choices`（含 3 并发 ×2 轮、4 连跑、F-B 恢复侧），
  全绿 —— 负载窗口里的那张中间帧无法自造；所以处置是把这个**类**的同步缺口堵死，而不是再跑一遍。
  硬化后的 3 并发一轮同样全绿（上文）。
