# P29 · settings-view-groups 提案：设置视图按功能域分组 + 行级类徽章/色 + 视图滚轮

agent: dev-bob   status: DONE   time: 2026-09-22T03:02:36Z
branch: `task/P29-propose`（HEAD `b2e33bf`；local 模式：不 push，分支留在 `.worktrees/dev-bob`，PM 复验后本地合并）

```
task:   P29
change: settings-view-groups   phase: propose（只出提案包；不写实现）
base:   112a3f4（brief 97e293a）   commits: 06fdfa3 1bb0c4d 2e9236b 4aa730f acf1316 b2e33bf
```

## 1 · 交付清单

| Path | 内容 |
|---|---|
| `openspec/changes/settings-view-groups/proposal.md` | Why / What Changes（3 条）/ Capabilities / Impact / Acceptance（逐字三条命令）/ What flips（5 条红面）/ Boundaries / 报告证据清单；控制在 81 行、与仓库现有提案同量级 |
| `openspec/changes/settings-view-groups/design.md` | 侦察（§1 带 file:line 与实测数字）、用户三条反馈对着代码的成因（§2）、Goals/Non-Goals（§3）、八条裁决 D0–D8（§4：分组来源与两份被拒方案、12 个 token 表、视图结构、行级类、滚轮、不许动的清单、夹具与翻转、跨 change 核对 + F1/F2） |
| `openspec/changes/settings-view-groups/tasks.md` | apply 一个 brief 的分批条目 1.1–1.7 / 2.1–2.8 / 3.1–3.3 + 独立复验 4.1，每条带可失败命令与红侧；文件头写清路径授权（`cmd-config.sh`/`panel/**`/`references/**` 是 PM 的需明授，`tests/**` 归 `agent:dev`） |
| `openspec/changes/settings-view-groups/specs/memory-and-deps/spec.md` | **ADDED** 1 requirement / 3 scenario：`group` 是 schema 行的第 10 列（封闭 ASCII token），读原样上报；缺失/畸形 token 由走查点名变红；同文件既有字段与 machine exits 逐字节不动 |
| `openspec/changes/settings-view-groups/specs/panel/spec.md` | **ADDED** 1 requirement / 5 scenario（按读上报的 group 分组、标签两向查、无 group 行落可见兜底组、行级徽章+色、席位块自己的标题）+ **MODIFIED** 鼠标要求（wheel 作用域加设置视图，正文原样保留 7 条既有 scenario，新增 3 条：窗口滚动/页面不动/焦点键推窗） |
| `docs/team/reports/P29-dev-bob.md` | 本报告 |

规模：3 requirement、新增 11 scenario（brief 要求 2–4 / 8–15）；两个 delta 文件与 brief 的 `deltas: panel, memory-and-deps` 一致。

## 2 · 三条用户反馈 → 提案答案

| # | 反馈 | 提案裁决 |
|---|---|---|
| 1 | 设置页面没法用滚轮 | **R3/D5**：设置视图拿到自己的窗口 offset（与 board 页 lane 同一套：显式 offset 优先、帧把 drawn window 交回 App、焦点键只推够把聚焦行露出来）；鼠标分支在视图内**消费** wheel（每格一行、焦点不动、两端隐藏行计数跟着窗口），picker 打开时改为走 picker 自己的条目（选择器照旧 `moveChoicePicker`；席位选择器今天其实也是漏到页面，这次一并收进视图 → `moveSeatPicker`，属本 change 唯一的小新增，理由同「隐藏页面不许动」）；page/lane/detail 的滚轮路径不动并复钉。红侧（现状）：`App.tsx:1650` 的 `updateScroll` 落在视图**背后**的页面上，视图本身因 offset 由 focus 推导（`layout.ts:1331`）纹丝不动 |
| 2 | 不要按「是否需要重启」分组 | **R1/R2/D1–D3**：分组 token 落在 schema 行第 10 列（沿用 `suggest` 的先例），`team config list --json` 逐键上报；视图按读序分节（一个 token 一节、组内 schema 序）、组标题不可聚焦；标签走 zh/en 表 `group_<token>` 且两向查；无 token 的行落可见兜底组。现状是 bundle 自带的类桶表（`layout.ts:1205`） |
| 3 | 用颜色代表是否需要重启（行级） | **R2/D4**：类留在行级——文字徽章（`立即生效`/`需重启`/`只读`/未知键）**加**色，色单独存在不算数（面板既有「状态不得只靠颜色」红线）；`restart`→`warn`、`refuse`→`dim`、`apply`→正文色（48 行 apply 全绿是噪音，用户问的是「要不要重启」）；value 不再跟着染色 |

brief 的其余设计与验收要求：未知/畸形 token → schema 走查 + 标签两向查双红（`tasks.md` 1.4/1.7）；把某键换 token → 已提交 bundle 跟着换标题（2.6，证明不硬编码）；wheel 后窗口移动且两端计数正确（2.6）；每行徽章+tone 都在（2.6）；规模不膨胀（3 requirement / 11 scenario）。

## 3 · 验收命令与输出尾部

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ spec/verification
✓ spec/watchdog
Totals: 16 passed, 0 failed (16 items)      （rc=0；含 change/settings-view-groups）
```

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
  ✓ 33 config-cli.sh 全绿（122 条断言）
  ✓ 38-a panel-choices.sh 全绿（ ✓ 41 ✗ 0；含一致性走查与 F-A/F-D 翻转）
== 结果 ==  ✓ 2294  ✗ 0
FAST 模式：跳过 27 个真进程段落（…|38-b·panel-p21-choices）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿      （rc=0）
```

```
$ git status --porcelain
?? docs/team/reports/P29-dev-bob.md      # 提交本报告前：只有本报告 untracked；提交后为空（见 §6 的收尾复跑）
```

- Verdict: **pass**（两条门禁真跑；本轮是 propose 任务，没有实现可翻，故无执行过的 flip）
- Notes: 明确**没跑**的东西——任何 `skills/**` 实现或夹具改动（本任务边界禁止）、慢段 pty 场景（`38-b`，FAST 显式跳过）、`docs/team/reviews/**`（PM 的文件）。本条不含「未验证的实现声明」：本任务交付物全部是 spec/proposal/design/tasks 文本，验收就是它们能过 `openspec validate --strict` 且不破坏 smoke

## 4 · 侦察证据（design §1 的数字，均可复跑）

```
$ awk -F'|' '/^# ----/{next} /^TEAM_[A-Z0-9_]+\|/{n++; t[$10]++} END{printf "rows=%d tokens=%d\n", n, length(t); for(k in t) printf "[%s] %d\n", k, t[k]}' skills/teamsmith/scripts/lib/cmd-config.sh
rows=111 tokens=1
[] 111                     ← 第 10 列今天不存在；apply 后这里必须变成 12 个 token / 12·11·16·11·3·14·13·7·4·6·10·4
```

| 分节（= 提案的 group） | 键数 | apply | restart | refuse |
|---|---|---|---|---|
| 身份与账本布局 `identity` | 12 | 0 | 0 | 12 |
| 分支与 forge `branch` | 11 | 1 | 0 | 10 |
| 权限与依赖策略 `policy` | 16 | 0 | 0 | 16 |
| 名册、模型解析与适配器 `roster` | 11 | 11 | 0 | 0 |
| 按席位模型 `seat-model` | 3 | 0 | 3 | 0 |
| 工作流与门禁 `workflow` | 14 | 14 | 0 | 0 |
| 容量与投递通知 `delivery` | 13 | 13 | 0 | 0 |
| 巡检与面板 `panel` | 7 | 0 | 7 | 0 |
| 巡检策略 `patrol` | 4 | 4 | 0 | 0 |
| PM 生命周期 `pm-lifecycle` | 6 | 1 | 5 | 0 |
| 活着的会话 `session` | 10 | 0 | 10 | 0 |
| 跨项目会议 `meeting` | 4 | 4 | 0 | 0 |

（合计 111 = 48 apply + 25 restart + 38 refuse；两个分节混类，正是「类不能由组推导、组也不能由类推导」的实测依据。）

其它锚点（design §1/§2 引用的都实测过）：`layout.ts:1205` 是 bundle 自带的三个类桶；`App.tsx:1623` 是 wheel 分支、`:1650` 是落到 `updateScroll` 的兜底；`layout.ts:1331` 是视图 offset 由 focus 推导；`laneWindow`（`layout.ts:849`）+ `laneOffset`/`lanesRef`（`App.tsx:258/300/1507`）是要照抄的 board 先例；`panel-strings.mjs` 规则 4 已经用 `label_<KEY>` 两向查 schema（22 格限宽只对行标签列，组标题是整行）；`tests/snapshots/` 20 个快照只有 p4 与 detail，**没有**设置视图快照（所以行内容变化不churn 快照，改的是 pty 夹具）；`tests/panel-b3.sh` 已覆盖页/车道/详情滚轮（`scn_wheel` + `detail-wheel`），设置视图是唯一缺口。

## 5 · 设计取舍（被拒方案与理由，全文在 design §4）

- **分组来源**：拒绝「解析 `# ---- 分节注释`」（注释变载荷：一次普通注释编辑就会挪动视图分组；banner 里带括号说明，不是标识符语法；且读路径今天把注释当 prose 跳过）与「命令里再放一份 group 声明表/函数」（第二张表，正是 `choices` 的 `source:schema` 纪律禁止的形状）。封闭集由**标签两向查**证明：没有 label 的 token、没有 token 的 label 都红。
- **token 用 ASCII slug 而不是中文分节名**（`identity`…`meeting`，见 §4 表；zh 标题逐字用分节名）：CJK 会把语言焊进数据（en 标题本来就要第二处），也让形状校验（`^[a-z][a-z0-9-]*$`）没法证伪。brief 的「沿用现有分节名」按**分组维度与成员**逐条对上（12 个分节 ↔ 12 个 token，成员一字不差）。
- **组顺序 = 读序（schema 序）**：控制台不再拥有任何排序表，视图行序与 `team config list` 一致。代价已显式记录（D2 末尾）：开视图前三节是只读骨架（39 个 refuse 键），「可编辑优先」被拒（那会让一节的位置随内部行的类变化）；若用户要改序，F1 给的形状是显式 order 列而不是控制台规则。
- **席位块不并入 `seat-model` 组**（合并需要一个硬编码的 token 锚点——正是本 change 要消灭的东西），改为把席位块自己的标题改成 `席位`/`Seats`，与 schema 组标题不再重名。
- **apply 不绿**（`apply`→正文色）与**整行底色**被拒：前者 48 行噪音、后者与聚焦游标/身份列打架。
- 徽章词保留 `需重启`（brief 括号写的是「重启生效」）：用户要的是**颜色**通道，改词只会无谓 churn 全部夹具；文字通道本身是「颜色不是唯一通道」的载体。

## 6 · 与基线的边界

- 本任务只动 `openspec/changes/settings-view-groups/**`（5 个文件）与 `docs/team/reports/P29-dev-bob.md`；`scripts/**`、`tests/**`、`references/**`、`panel.js`、`openspec/specs/**`（基线规格）一行未改：

```
$ git diff --stat 112a3f4..HEAD
 openspec/changes/settings-view-groups/design.md    | 253 +++++++++++++++++++++
 openspec/changes/settings-view-groups/proposal.md  |  81 +++++++
 .../specs/memory-and-deps/spec.md                  |  44 ++++
 .../settings-view-groups/specs/panel/spec.md       | 166 ++++++++++++++
 openspec/changes/settings-view-groups/tasks.md     | 117 ++++++++++
 5 files changed, 661 insertions(+)
```
- 提案在 Boundaries 与 design D6 里把「不许动」写死：写入路径（`team config set` 的校验/CAS/审计/危险清单/直写）、`settings-choice-editors` 已归档的交互（直写、零读取、危险值例外、「其他」路径）、读的既有字段、人读表格、machine exits、`panel.conf`、其它页的滚轮。
- 任务书 `deltas: panel, memory-and-deps` 逐字满足；`team dispatch` 的「一个 delta 一个写者」不受影响（apply 只有一个 brief，两个 delta 都在它名下，且没有别的未完成任务写它们）。

## 7 · apply 阶段的翻转清单（已落成可失败命令，见 `tasks.md`）

1. **F-G1 / F-G2**（1.4，`config-cli.sh` 自己的 scratch-tree 翻转）：删某键第 10 列 → 走查红点名该键；`NoPe!` token → 红；恢复 → 绿。
2. **标签两向查**（1.7，贴着 smoke §28-a2 既有翻转）：删一个 `group_<token>` → 红点名该 token；加 `group_zzz` → 陈旧红。
3. **视图不硬编码**（2.6 pty，真 bundle + 私有 tmux）：scratch CLI 加 `TEAM_ZZZ_TEST` 带 `workflow`、把 `TEAM_GATES` 改到 `meeting` → 已提交 `panel.js` 跟着换标题与位置；删掉某键 token → 该行落兜底标题而不是消失。
4. **滚轮前后**（2.6 pty）：改动前——wheel 后视图帧不变、背后页面 offset 变了；改动后——窗口按格移动、两端计数正确、焦点不动（CLI 提示行仍点同一键）、`esc` 回页面时页面原地不动；焦点键把窗口推回聚焦行；picker 打开时 wheel 走 picker 条目、页面仍不动。
5. **徽章/tone**（2.3+2.6）：把三类的 tone 归一 → tone 断言红；剥掉 SGR 的单色捕获仍能读出三类文字（证明颜色不是唯一通道）。
6. **写入路径未动**：既有的 `config-cli.sh writer cas validate audit` 段保持全绿（3.1 尾部）。

## 8 · 偏差与备注

- **token 形状**：ASCII slug + zh 标题逐字用分节名（§5）——与 brief 字面「直接沿用分节名」有解释空间，已按实质（维度与成员）对齐并把理由写进 D2；若 PM 坚持 CJK token，改动只在 D2/token 表的 12 个字符串与形状校验。
- **组顺序**：读序（=文件序），前三节是只读骨架——已在 D2 显式记录并留给 PM 在提案复审裁决（F1 给了将来的诚实形状）。
- **席位块标题改名**（`settingsGroupSeats` → `席位`/`Seats`）：这是超出 brief 字面的一处可见文案改动，理由是与 schema 的 `seat-model` 组标题重名；三个类分组标签（`settingsGroupApply/Restart/Refuse`）删除，因为只有设置视图在用（`grep` 证实）。
- **picker 状态下的 wheel（超出 brief 字面的一处小新增）**：席位选择器的 wheel 今天会漏到背后的页面（`App.tsx` 的鼠标分支只认 choice picker）；既然要求「视图打开时 wheel 不得到达背后的页面」，席位选择器一并收进视图（走自己的条目，与 choice picker 同规则）。理由与红侧已写进 design D5 与 spec 的鼠标要求。
- 本任务是 propose：没有执行任何实现翻转；第 7 节是 apply 必须交的红/绿面，`tasks.md` 已把它们写成命令。
- 未收到需要 `BLOCKED:` 的边界冲突：`deltas`、路径授权、跨 change 核对（`change-centric-discipline`、`tmux-gate-grant-redesign` 都不碰控制台面）都在提案里交代完。

## 9 · 建议的下一步

- PM 复审提案包（建议记录 `docs/team/reviews/settings-view-groups-proposal.md`）。ACCEPTED 后按 `tasks.md` 派 **一个 apply brief**：路径授权需明授 `skills/teamsmith/scripts/lib/cmd-config.sh`、`skills/teamsmith/scripts/panel/**`、`skills/teamsmith/references/config.md`；`skills/teamsmith/tests/**` 归 `agent:dev`；`deltas: panel, memory-and-deps`。
- apply 落地后由**不同 agent**走 §4.1（复跑全部翻转 + pty 场景 + 全量门禁），再轮到 PM 的 archive 准备。
