# P14 · Apply: `pulse-console` B3 —— 控制台表面（三页 / 设置浮层 / 鼠标 / i18n / 响应式 / `q` 收起）

agent: dev   status: DONE   time: 2026-09-17T05:30:00Z
branch: `task/P14-apply-pulse-console-b3`   PR/MR: -（本仓库 local 模式，分支留本地，PM 复验后本地合并）

范围 = `openspec/changes/pulse-console/tasks.md` 的 **B3 全段（4.1–7.4，13 项）**，已在本分支勾选。
B1/B2 的产物语义没动（`--print`/`--json` 的契约：0 转义字节、退出 0、不写 state、不 tick；JSON 键只增）；
`[v1.1]` 列表一项没碰（里程碑条/树、队列丢弃动作、上次门禁记录点、任务钻详情页、`draft send --json`）；
`openspec/specs/**` 与账本（BOARD/ROADMAP/DECISIONS/OWNERSHIP/reviews）没碰。

## Rework 2 · V15 F1–F8 + 追加 2/3/4

V15 整包复验 8 条 finding 已在本 worktree 逐条处理；随后任务书末尾追加 2/3/4（美观卡片、会话列永不截、agents 表头/数据单一列计划）一并落地。

### V15 findings

| ID | 处理 | 翻转证据 |
|---|---|---|
| **F1** | 写信时 hint 在输入行**上方**，输入行是 composing 期间最后一行（IME 锚在光标） | B2 2.1：`cursor_x` 随 `中文ab` / 退格整字走动；托盘后期望值 +2（`│ ` 墙）仍绿 |
| **F2** | 标题带时钟在 React **之外**每秒就地改写 8 列（save/restore cursor + chalk.hex），编辑器交接期间停表 | 合并树 idle ~0.72% 且时钟冻结 → 错误方案（每秒全帧 commit）1.37% 红 → 就地写 0.583%；本 tip 含卡片后 **0.499%** / 60s |
| **F3** | `sendingRef`：第二条 Enter 在 bridge 返回前直接 return | **OLD** bundle：两次独立 `tmux send-keys Enter` → outbox dupes=2；**NEW**：bridge 调用恰好 1 次、dupes=1。V15 20-g 的 `n=2` 期望按 busy→queued 算术是误校准（2 条粘贴 + 1 条探针 = 3）；见下方决定项 |
| **F4** | `placedWithHits` 按**渲染后**坐标裁 hit；终检再裁一次（含双列合并行） | 截断行上的 `…` 不再是可点目标 |
| **F5** | **裁定**：钉住现行行为（每页一个 scroll offset，滚轮/↑↓ 一格一行，无焦点块）。spec 文本交 PM | 回归网已钉（b3 滚轮、V15 20-i 列表滚动）。建议把 requirement「the wheel SHALL scroll the **focused block**」改成：「v1 keeps a single scroll offset per page — a notch moves the view one row wherever the pointer is; there is no per-block focus」 |
| **F6** | **BLOCKED**（PM 独占 `templates/`） | 见下方精确 diff |
| **F7** | **裁定**：`--print` 总览内容进入纯文本帧是 delta spec 授权的偏离（「plain-text frame 保持 overview 内容」）；JSON 只增 `refresh_s` | 请 PM/用户确认接受。本 tip 因 追加 3/4 再多了「任务」列和完整 `41k/272k`（缺陷修复，不是装饰） |
| **F8** | `panel-cpu.sh` 测量交互首帧（窗口 spawn → 标题带可见），预算 2000ms | 实测 837–1061ms；本 tip **840ms**。超预算与 CPU 红线一起 RED |

### 追加 2 · 美观（舒适密度 TUI）

- 有标题的区块 → 圆角卡片 `╭─ 标题 ──╮ / │ … │ / ╰──╯`（dim 边、heading 标题）。
- 高度不够逐级降级：卡片框 → 顶边分隔线（标签嵌线）→ 标题行。
- **紧凑密度默认无框**（今日的标题行+内容；页签保持 `▸name◂`；页脚保持 `·` 分隔）。`--print`/`--json` 无框。
- 页脚四个动作做成芯片 `( m 写信 )`，点击目标 = 视觉边界（含括号）1:1；导航键仍是纯文本。
- 当前页签 `[总览]` 框出。
- 写信输入行：开口底托盘（顶边+左墙，无底边），输入行仍是最后一行，IME 光标跟草稿走。

### 追加 3 · 会话列永不截

- 列宽 = max(表头 dispWidth, 各 `session_text` dispWidth)。值永不 `…`。
- 截断/丢列顺序：分支 → 任务 →（本表无时间列，跳过）→ 会话最后。59 列最小档仍保留完整 `41k/272k`。
- 四档快照正则断言 `41k/272k` 全文。

### 追加 4 · agents 表单一列计划

- `agentColumnPlan()` 是表头和每一行数据的**唯一**列宽来源，按显示宽度算；`cell()` 保证省略号不跨列。
- 表头补上「任务」列（原先数据有、表头无，对不齐）。
- 英文表头进 `en.ts`（`agent/state/task/branch/session`）；中文 `zh.ts` 用 `代理/状态/任务/分支/会话`（不再把英文 `AGENT` 放在中文表里）。
- 四档快照：表头/数据列起点相等 + 任务单元格不跨进下一列。

### F6 精确 diff（PM 独占，未落笔）

`skills/teamsmith/templates/config.sh.tmpl:86`：

```
- TEAM_MONITOR_REFRESH=5                # monitor refresh interval (seconds)
+ TEAM_MONITOR_REFRESH=3                # monitor refresh interval (seconds); console default (was 5)
```

`references/config.md` 已写默认 3。`SKILL.md` / `references/migration.md` 本树未再发现钉死的 `=5`。

### 决定项请 PM/用户确认

1. **F5 spec 措辞**（上表）。
2. **F7 `--print` 总览内容** + 本次表头/会话列修复进入纯文本帧。
3. **V15 20-g `n=2` 校准**：busy 夹具下两条粘贴入队后双 Enter 正确结果是 n=3 dupes=1（本树 bridge 调用 1 次）。包里 `n=2` 是 off-by-one。
4. **V15 包在追加 2/3/4 之后不再 0 bad**（见下）——探针仍在找 `AGENT`、59 列「砍掉会话列」、无卡片时的键位行号。F1–F8 的 0-bad 记录在卡片落地前的 bundle `15923f10`。请 verify 按新表面改探针，或 PM 接受「这 7 条 bad 是授权视觉变更，不是 F1–F8 回退」。

### 本 tip 门禁

```
openspec validate --all --strict          13 passed, 0 failed
bash skills/teamsmith/tests/smoke.sh      ✓ 1775  ✗ 0
TEAM_SMOKE_FAST=1 …/smoke.sh              ✓ 1373  ✗ 0
bash skills/teamsmith/tests/panel-b2.sh   ✓ 70  ✗ 0
bash skills/teamsmith/tests/panel-b3.sh   ✓ 60  ✗ 0
bash skills/teamsmith/tests/panel-snapshots.sh  ✓ 17  ✗ 0   (8 钉住快照 + 8 列对齐/会话全文 + tiny)
node …/panel-strings.mjs                  138 keys, ok
node …/panel-contrast.mjs                 ok ≥ 4.5:1
bash …/panel-cpu.sh . 60                  first frame 840ms (budget 2000) · pane 0.499% of one core
```

V15 包 × 本 tip（卡片后）：`ok=172 bad=7 finding=5`。7 条 bad 全是新表面：
- 10-d / 20-e：探针找 `AGENT`（现 `代理`）
- 20-e：59 列仍渲染会话列（追加 3 的合同）
- 20-c：64 列键位行 28 vs 期望 19（卡片多占行）
- 10-j：b2 夹具 cursor 期望已改为托盘 +2，对 B3 前树也红（翻转基线被测试书改写，不是 F1 回退）
- 40-d：20 次 resize RSS +77MB（卡片节点更多；卡片前 0 bad）

finding 5 条与卡片前相同：F5 滚轮无焦点块、20-g n=3、30-a/c `--print` diff、F6 模板仍是 5。

bundle：`panel.js` 881962 字节，sha256 `22e67b782b989db76d34a6f64178a1e7d187ea6db99d087119bb0c93d2e54189`。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/panel/src/layout.ts` | 重写：三页 + 设置浮层 + 四档宽度（160/100/99/59）+ 区块空则收起 + 高度是硬上限；几何纯函数；点击目标（hit map）与色调分段（相邻同色合并）；标题带的时钟是一个**独立可标记**的分段；`renderPlain`/`renderAnsi`/`buildJson` |
| `skills/teamsmith/scripts/panel/src/strings/{zh,en,types,index}.ts` | 136 键的 zh/en 字符串表（纯 ESM + JSDoc，门禁脚本可用任意 JS 运行时直接 import）+ `fill()` 占位符替换；上屏文本只从表里取 |
| `skills/teamsmith/scripts/panel/src/settings.ts` | `state/panel.conf`（lang/page/activity/mouse/density + 非浮层的 `theme`）与 `state/panel-page`；坏/缺文件回默认、坏值忽略、二进制内容拒绝 |
| `skills/teamsmith/scripts/panel/src/theme.ts` | 深浅两套调色板 + WCAG 对比度计算 + SGR 映射 + `auto` 主题（`COLORFGBG`） |
| `skills/teamsmith/scripts/panel/src/App.tsx` | 页签/Tab/1-3、设置浮层交互、SGR 鼠标（点击目标 + 滚轮）、语言即时切换、密度；`q` 收起；`<Clock>` 活时钟；行级 memo + 帧签名（内容没变就不重绘——红线的主要来源） |
| `skills/teamsmith/scripts/panel/src/main.tsx` | `--headless`、`--snapshot`（`--targets` 输出点击目标）、`--palette`；`panel.conf`/`panel-page` 读写；`q` → `team pulse collapse`；SIGTERM/SIGHUP 关鼠标上报；`adopt()` 用帧签名挡住无变化的重绘 |
| `skills/teamsmith/scripts/panel/src/data.ts` | 新增 8 个块（board/changes/specs/decisions/outbox_list/inbox/patrol/health）+ 每块 TTL；机读出口只装配原有 8 块 + 总览要的 4 块 |
| `skills/teamsmith/scripts/panel/src/width.ts` | `charWidth()` + O(n) 截断（原来每字符 `dispWidth(out+ch)` 是 O(n²)，每帧每行都跑） |
| `skills/teamsmith/scripts/lib/cmd-watch.sh` | 8 个只读读者的 bash 实现（BOARD 行/交付、变更+阶段、规格计数、决策、队列逐条（净化全文）、收件箱/线程、巡检尾、健康）；BOARD 解析改单趟 awk（1.5s → 0.08s CPU）；`monitor --headless`；`pulse collapse`；`pulse status` 报形态（控制台/无界面） |
| `skills/teamsmith/scripts/lib/common.sh` | `TEAM_MONITOR_REFRESH` 默认 5 → 3 |
| `skills/teamsmith/scripts/panel/README.md` | 控制台表面的完整说明（页面/按键/鼠标/设置/状态文件/布局四档/性能取舍/两个测试出口） |
| `skills/teamsmith/scripts/panel/panel.js` | 重建的 bundle（878217 字节，sha256 `904f39fe…`；`bun install --frozen-lockfile && bash build.sh` 可逐字节复现，26-a 每次门禁都比一次） |
| `skills/teamsmith/tests/panel-b3.sh` + `panel-b3-stub.sh` + `panel-b3-pty-mouse.py` + `panel-b3-pty-tmux-mouse.py` | 8 个场景 60 条断言的夹具（私有 tmux server、确定性数据 stub、零残留）：三页/页记忆、设置、坏 conf、队列全文只读、鼠标（直驱 + tmux 全链路）、滚轮、四档 resize、`q` 收起 |
| `skills/teamsmith/tests/panel-snapshots.sh` + `snapshots/*` | 四档宽度 × 深浅两套主题的快照套件（`--snapshot` 逐字节比对）+ 60x8 不越界（按显示宽度算） |
| `skills/teamsmith/tests/panel-strings.mjs` / `panel-contrast.mjs` | 门禁脚本：键集合/占位符/表外无 CJK；调色板对比度 ≥ 4.5:1 |
| `skills/teamsmith/tests/panel-cpu.sh` | 收尾改成 SIGTERM（`q` 现在是把窗口重建成无界面循环，`/usr/bin/time` 拿不到总结）；表头打印被测进程 |
| `skills/teamsmith/tests/smoke.sh` | §28 新增（i18n 键集合+翻转 / 调色板+翻转 / 快照 / `refresh_s` / `panel.conf` 边界 / 点击目标）；§26-e 按 REMOVED 需求改成四档几何断言；§26-m 增加「数据跟着节拍走」断言；§27-a 覆盖 16 个块名 |
| `docs/team/reports/P14-dev/evidence/**` | 原始证据：门禁、夹具、快照、i18n/对比度翻转、滚轮翻转的前后字节、CPU、计时 |

## Verification evidence

### 门禁（最终 tip；原始日志在 `evidence/`）

```
$ openspec validate --all --strict
Totals: 13 passed, 0 failed (13 items)

$ bash skills/teamsmith/tests/smoke.sh                        # evidence/01-smoke-full.txt
== 结果 ==  ✓ 1776  ✗ 0        smoke 全绿        （rc=0）

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh       # evidence/02-smoke-fast.txt
== 结果 ==  ✓ 1373  ✗ 0        smoke 全绿        （rc=0）
```

### B3 段（任务书列的验收）

```
$ bash skills/teamsmith/tests/panel-b3.sh                      # evidence/04-panel-b3.txt
== 结果 ==  ✓ 60  ✗ 0         panel-b3 全绿
  场景：pages(11) · settings(8) · conf(3) · queue(10) · mouse(9) · wheel(2) · resize(7) · collapse(8)
  其中 [real] 的：直驱 pty 的 SGR enable/点页签切页/滚轮后窗口后移、tmux 全链路点 m 提示开输入行、
  99→160 重排与 160/100/99/60/59 五档边界、q 收起后 capacity.log 继续增长、pulse up 原地恢复控制台

$ bash skills/teamsmith/tests/panel-snapshots.sh               # evidence/05-snapshots.txt
== 结果 ==  ✓ 9  ✗ 0         4 档宽度 × 2 主题 + 60x8 极小 pane 逐字节一致

$ node skills/teamsmith/tests/panel-strings.mjs .              # evidence/06-strings.txt
ok: zh/en key sets compared (136 keys) · ok: values are non-empty strings with matching placeholders
ok: no CJK literals outside src/strings/** · panel-strings: ok

$ node skills/teamsmith/tests/panel-contrast.mjs panel.js      # evidence/08-contrast.txt
ok: dark palette checked (9 pairs) · ok: light palette checked (9 pairs) · panel-contrast: ok

$ bash skills/teamsmith/tests/panel-cpu.sh . 60                # evidence/10-panel-cpu.txt
== measured process: /usr/bin/node …/panel.js ==
== summary over 60s: console pane process 0.300% of one core · reader tree 15.176% of one core ==
panel-cpu: OK — the pane process is under 1% of one core

$ time bash skills/teamsmith/scripts/team monitor --print       # evidence/11-timing.txt
run1: 0.78 s wall, 1.70 user 0.57 sys   （B1 的改前实测 7.0–7.2s；红线 ≤2s）
```

### 翻转证据（红 → 绿）

**① CPU 红线：Ink 每个节拍无条件重绘整棵树（真实缺陷，夹具先红后绿）**

```
$ bash tests/panel-cpu.sh . 60        # 修复前（帧内容没变也 rerender）
== summary over 60s: console pane process 1.198% of one core ==
panel-cpu: RED — the pane process is 1.198% of one core (red line: <1%)
$ bash tests/panel-cpu.sh . 60        # 修复后
== summary over 60s: console pane process 0.300% of one core ==
panel-cpu: OK — the pane process is under 1% of one core
```

**② 滚轮：滚动状态被下一个刷新节拍抹掉（`evidence/wheel-red.bin` / `wheel-green.bin`）**

```
# 修复前 bundle（f5ff1ec 的 panel.js）：
$ python3 tests/panel-b3-pty-mouse.py --panel <prefix> --no-click --wheel down --wheel-clicks 3 …
prefix: after-wheel bytes=0      ← 滚轮没有任何可见效果
# 修复后：
fix:    after-wheel bytes=7784   ← 可见窗口后移（10:00:00Z 移出、10:45:00Z 进入）
```

**③ i18n 键集合：删掉 `en` 的一个键 → 断言非 0 且点名（`evidence/07-strings-flip.txt`）**

```
$ cp -r src $TMP && sed -i '/^  keyCompose:/d' $TMP/.../strings/en.ts
$ node tests/panel-strings.mjs $TMP
✗ panel-strings failed:
  only in zh: [ "keyCompose" ]        （rc=1；恢复后 rc=0）
```

**④ 调色板对比度：把 `dark.text` 压到背景色 → 非 0 且点名（`evidence/09-contrast-flip.txt`）**

```
$ node tests/panel-contrast.mjs --palette-file /tmp/p14pal-bad.json
✗ dark.text: #10141a on #10141a = 1.00:1 (below 4.5:1)
✗ panel-contrast: 1 pair(s) below 4.5:1      （rc=1）
```

**⑤ 活体宽度：TUI 的布局宽度必须来自当前终端（真实缺陷，边界断言先红后绿）**

```
$ bash tests/panel-b3.sh resize      # 修前（把修好的那行退回 data.width）
✗ 99 列：不该是双列      ✗ 59 列：最小档没有生效      （✓5 ✗2）
$ bash tests/panel-b3.sh resize      # 修后（同一夹具、同一条断言）
✓ 99 列：单列 · ✓ 60 列：单列 · ✓ 59 列：最小档      （✓7 ✗0，panel-b3 全绿）
（完整前后日志：evidence/12-live-width-flip.txt；这次翻转还暴露了夹具自己的一个 `$59` 拼写 bug，
 已一并修掉——断言失败时它原本会因 unbound variable 崩掉而不是报红。）
```

## 返工（V14 复审 F1）：26-m 红 —— 动作的回响不能等 TTL

复审在独立 checkout 上跑出 `26-m 红`：我加的那条断言是**从面板外**写 standby（`team standby on`），
靠块 TTL 到期才上屏；`frame` 块的 TTL 当时是 1s，而面板节拍也是 1s，于是写入刚好落在两次重建之间时
要等 ~2s——1.5s 的窗口会偶发红。**修法不是放宽断言**（复审说得对）：

1. **面板自己的动作一律事件驱动**：`m`/Enter（发送）、`f`（冲刷）、`s`（待命）、设置浮层的活动列开关
   在动作完成后都走 `refreshNow()`（`cache.refresh({force:true})` + 立即重绘，绕过所有 TTL）；这次把
   **`r`（手动刷新）** 也改成强制失效（原来只重建过期块，等人按了刷新却没有刷新的效果）。
2. **面板外的改动交给节拍**：`frame` 块（横幅 + 面板时钟，最便宜的块）TTL 1000ms → **500ms**，短于最短
   节拍（1s），所以外部改动最迟一拍就上屏——「每个节拍重建一次缓存」这条也因此是可断言的。
3. **断言改成测真实路径**：26-m 现在先**在面板里按 `s` → 输入理由 → Enter**，要求 1.5s 内标题带出现
   `待命 on（原因：action-proof）`；再在面板外 `standby off`，要求 1.5s 内标题带回 `待命 off`
   （前者证动作即时回响，后者证节拍仍在重建）。两条都读**标题带那一行**，不再全文 grep（旧写法会被
   输入行里刚敲进去的同一个字符串误判通过——这也是复审那次红的一个诱因）。
4. 实测（同一夹具，`TEAM_MONITOR_REFRESH=1`）：按 Enter 到标题带出现原因是 **423ms**，
   面板外 `standby off` 到标题带回到 off 是 **525ms**。

## 修复过程中被夹具抓到的两个真缺陷（都在本分支修掉）

1. **TUI 的布局宽度被冻结在启动那一刻**：`layout()` 用的是 `frameOf()` 在进程启动时算好的 `width`，
   窗口建立时面板看到的是会话默认尺寸，之后 `resize`/`--width` 都不会改它（`main.tsx` 的 `stdoutColumns`
   是模块级常量）。夹具的 160/100/99/60/59 边界断言抓住（旧断言只看「99 列有 AGENT、160 列是双列」，
   冻结在 120 也能过——旧断言太松）。修法：App 把 `size.columns`（`process.stdout.columns` 的实时值）
   喂给 `layout()`。
2. **Ink 每个节拍无条件重绘整棵树**：`main.tsx` 的 `adopt()` 每次都 `app.rerender()`，即使这一拍任何块都没
   过期、帧内容一字未变——一次全树调和 + Yoga 布局 ≈ 13–20ms，是 <1% 红线的主要开销。修法：帧内容签名
   不变就不重绘（`frameSignature` 同时被 App 的 `setData` 路径使用）。

## 性能取舍（红线的账，全在 `evidence/10-panel-cpu.txt` / `11-timing.txt` 里有原始数字）

- measured pane process = **0.300%**（60s）；红线 <1%。读者树（pane + 它 fork 的所有读者）15.2%，
  含首帧装配（16 块，含 `doctor`）与 B1 读者的固有成本（`pending` 0.45s、`agents` 0.24s per rebuild）。
- `--print` 一帧从 1.75s 降到 **0.72s**：BOARD 行读者原先每行起 6 个子 shell 做 JSON 转义
  （73 行 = 400+ fork，实测 1.5s CPU/次）→ 单趟 awk，**0.08s**。
- `truncateW/truncateWStart` 是 O(n²)（每字符都 `dispWidth(out+ch)`）→ O(n)。
- 各块 TTL：活动列保持 3s（设计要求唯一「活」的块），`frame`（横幅：项目/节拍/待命/时钟）0.5s，其余 9–15s，
  重的（规格/变更/`doctor`）3–10 分钟；三个动作完成后 `refreshNow()` 强制重建，人做完动作立刻见效。
- 标题带的时钟改成客户端 `<Clock>` 组件（每秒自走，只重绘一行），并把它从 `frameSignature` 里排除：
  这是「每个节拍重建缓存」（spec 要求）与「<1% 红线」能同时成立的关键。机读出口（`--print`/`--json`/快照）
  仍然渲染**装配时刻**的时间戳（原契约不变）。smoke §26-m 因此补了一条「数据也跟着节拍走」的断言
  （1s 节拍下，standby 原因 1.5s 内出现在标题带），避免只测到活时钟。

## Decisions and deviations

- **机读出口的文本内容随总览一起长**（P11 审查条件 3 的「逐字节兼容」）：`--print` 仍然是「一帧纯文本、
  0 转义字节、退出 0、不写 state、不 tick」，但总览现在多了项目进度/最近交付两个区块、键位行也换成控制台
  的按键（`q 收起` 等）。这是 delta 里 MODIFIED 那条「plain-text frame = 总览内容」的直接结果；夹具
  §26-c/§26-e 在本分支重钉（task 书允许 tests/**，提案审查条件也要求每批重钉）。`--json` 只多了
  `refresh_s`；页签/页标记/控制台专用块**没有**进机读出口（§28-e 断言）。
- **控制台专用块不进机读出口**：`outbox_list`/`inbox`/`patrol`/`health` 只有 TUI 装配，`--json` 的成本与键
  都不变，`doctor` 也不在机读出口的路径上。
- **`q` 语义变了**：从「退出」变成「收起成无界面巡检」（`Ctrl-C` 才是退出）。`pulse status` 报形态，
  `team pulse up` 原地恢复控制台；`team pulse collapse` 也可单独调用。
- **快照的字节**在本分支重钉了一次（时钟分段从「与右半段同色合并」变成独立分段），**文本零差异**；
  这是 `--snapshot` 出口的语义（钉渲染字节，不是钉文本）。

## PM 待办（越界项，我没有改，按 OWNERSHIP 交回）

以下三个文件不在 B3 的路径授权里（授权的是 `skills/teamsmith/scripts/**`、`references/config.md`、
`tests/**`），但它们与新默认/新行为不一致，需要 PM 决定后自行落笔（我原本改了，已按边界纪律回滚）：

1. `skills/teamsmith/templates/config.sh.tmpl`：脚手架模板里写着 `TEAM_MONITOR_REFRESH=5`
   → 新项目会被钉死在 5，覆盖「默认 3」的契约变更。建议改成 `3`（一行）。
2. `skills/teamsmith/references/migration.md` §5：加一行「监视器刷新节拍默认 3s（原 5s）；项目 config 里
   显式写着 5 的升级后继续用 5，想用新默认就删掉那一行」+ 一行「`q` 现在是收起不是退出」。
3. `skills/teamsmith/SKILL.md`：Monitor 行还是「`team monitor [--once] [--activity]`」的旧描述，
   建议点明三页/设置浮层/鼠标/`q` 收起/`--headless`，并把 pulse 那段的「一个后端」补上两种形态。

（smoke §28-d 因此显式删掉夹具 config 里的那一行再断言默认 3——规格场景的前提是「键未设」；
`templates/` 仍是 5 时这段依然正确。）

## Suggested next steps

- PM 复验：独立 checkout 跑三段门禁 + `tests/panel-b3.sh` + `tests/panel-snapshots.sh` + `tests/panel-cpu.sh`。
- 上面三条 PM 待办（模板默认值优先，否则新项目看不到这次契约变更）。
- 独立验证（verify agent）值得对抗的点：`q` 收起后真的只有一个窗口/一个进程（我用 `pulse status` 与
  `capacity.log` 增长钉了，「没有孤儿进程」值得再查一次 `ps`）；`--print` 文本变化是否被接受；
  以及 `--print` 的「≤2s」红线在别的 checkout 上（这里是 0.72s）。
