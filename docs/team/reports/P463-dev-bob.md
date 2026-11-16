# P463 · 设置检查：先合并剪贴板用例的四次重复启动

agent: dev-bob · status: DELIVERED（只读探索；不含实现授权）
phase: opsx-explore · change: -（infra）
branch: `task/P463-settings-cost-explore` · PR/MR: -（本地交付）
分析基线：`8fc51cf115215cedc1ebd28823473bca355e9fb2`；资料核对：2026-11-16。

## 结论

**若只改一处，建议合并 `panel-b2.sh:scenario_clipboard` 中仅为切换假剪贴板输出而进行的四次面板重启。该场景的真实 bundle 启动可从 8 次降到 4 次；五种剪贴板条件仍逐个按真实 C-v、读真实临时文件和草稿，不删交互、不换成静态样张。** 调用链是 `smoke §38-h → panel-b2.sh --all → scenario_clipboard`；具体退休点为当前 `panel-b2.sh:712/733/746/759`。

这是已找到的最小、可核账的重复执行，不是“994 秒里已经量出最大可节省项”。现有日志只给出 §38 整段 **994 s**，没有这四次启动的逐项耗时；净省秒数未知。建议下一步只为此做独立 propose/review，不以本报告进入 apply。下文不再凑第二、第三个改造批次。

## 1 · 旧日志能证明什么，当前源码变了什么

现成原件 `/var/tmp/rel47-first-order.log:1` 绑定快照 `572856a3ae57503396019020f58e8e6abcc08db4`；`:4745–4784` 记录 §38 从 2026-11-13T02:11:09Z 跑到下一段 02:27:43Z，收口 **994 s、✓16 ✗0**。整轮 `:5899–5907` 是 **✓5139 ✗2、rc=1**，不是全绿。这里只借它定位正常全量的成本，不更改原判定。

先做 `572856a3..8fc51cf1` 的源码核对，再分析调用：

| 核对对象 | 实际差异及对结论的影响 |
|---|---|
| `smoke.sh` 的 §38 正文（从 `section "38 ·` 至 §38m 注释前） | **232 行逐字节相同**；sha256 `d56f72c69306647d99a26dff6537a2057391bdee0cd0c1ac3fafe708e1e84221`。旧轮调用形状可用于本轮静态分析 |
| `panel-choices.sh`、`panel-p21.sh`、`panel-b2.sh`、`panel-b3.sh`、`panel-clipboard-model.ts`、`lib/pty-wait.sh`、`panel-b3-pty-mouse.py`、`fake-tui.py` | `git show` 原字节与工作树字节相同；没有把旧脚本的重复误算到已被删掉的代码 |
| `scripts/panel/panel.js`、`scripts/lib/cmd-config.sh` | 原字节与当前相同；不是旧 bundle 上才存在的准备模式 |
| `section-paths.tsv` 的 `28/38/38m/63` 行；`section-select.sh`、`lib/tmp-root.sh`、`lib/tmux-iso.sh` | 对比无差异；本报告的直接命中/依赖带入区分仍成立 |
| 当前公共 CLI 与 smoke 其它区域 | `cmd-project.sh:434–443` 改了 init 生成 AGENTS 的命令路径，`common.sh:6` 版本升到 0.4.7，`cmd-review.sh` 有评审显示改动，`cmd-watch.sh` 改了一处注释；smoke 的配置准备/执行位置等也已变。不能把整份旧日志当当前树的新测量，更不能把旧秒数当改后收益 |

原日志提到的 `/var/tmp/teamsmith-smoke-pm_skills-deb708fe.K7ygTa` 和快照 `/var/tmp/teamsmith-snapshot.7CWnjh/tree` 本轮检查均 **ABSENT**。因此没有从现场取得 `p327-panel-b2.log` 或逐场景原件；没有重造现场、补跑计时。外层每 60 秒的进度行也不是逐子脚本起止记录，不能据此拆出“每次启动花多少秒”。

## 2 · §38 实际支付的调用，而不是段名

沿用 P432 报告 §2/3/5 的范围边界，以下只展开当前 §38 及直接子脚本。路径前缀统一为 `skills/teamsmith/tests/`。

| 调用点 | 正常完整执行一次 §38 时实际执行 | 准备/等待与保留的事实 |
|---|---|---|
| `smoke.sh:20775`，38-a | `panel-choices.sh read known read-equality catalogue` 一次 | 四个组各 `new_proj`，即四次 git/真实 `team init`；读 schema/模型词表、独立解析器逐字节比对、机器目录不混入项目选项。不是 86 次 dry-run 走查 |
| `:20813`，38-b | `panel-p21.sh choices` 一次 | `server_up choices` 一次、真实 bundle 一次；同一面板完成 bool/enum/模型/数值/path/自由输入、点击、滚轮、危险值确认与真实写入。按键至成帧期间的 `config list/__panel-data` argv 计数、配置字节和 audit 增长都在这里；`P21_REFRESH=3600` 是隔离后台读取归因，不是应删的“等待” |
| `:20824–20925`，38-d/e | 源码检查；复制 panel 源与 schema；标签正常/删标签/多余标签三次检查；分组与滚轮源码判据及其变异 | 不启动真实面板。它们有重复读文件和复制，但没有本轮逐项耗时，不能把 994 s 归给它们 |
| `:20937`，38-f | `panel-p21.sh groups settings wheel` 一次 | 三个场景各 `server_up`，不是三个整套 p21；`groups` 启动 bundle 三次（正常/改组 token 与新键/缺组 token），`settings` 六次（正常/scratch schema/标记删掉/还原/英文/中文高度），`wheel` 一次。四档高度 45/33/30/25 是**同一个面板 resize**，不是四次冷启动 |
| `:20969`，38-h | `panel-b2.sh --all` 一次 | runner `:1229–1250` 列出 11 场景，每场景自己的项目与私有 tmux；草稿、编辑键、剪贴板、编辑器、回执、结算、刷新、粘贴、动作均执行。`clipboard` 内八次 bundle 启动是本次选定的减量位置 |
| `:20993`，38-i | `panel-b3.sh --all` 一次 | runner `:1570–1581` 列出 12 场景：页面、偏好、坏配置、队列、看板、折叠、详情、工作详情、鼠标、滚轮、resize、收起。真 pty 直驱与 tmux 点击全链路并非同一接口；`:810–837` 的鼠标开/关/即时关闭也不是三个相同输入 |
| 下一段 §38m（`:21008` 起） | 普通完整运行只打印具名跳过，不执行其内容 | `panel-choices.sh walk flip-drop-pm flip-suggest` 与等待库自检在这里。不能把它们的夜间成本算进本轮 994 s |

按上述正常成功路径，38-b/f 合计四个 p21 场景、四次项目初始化、**11 次 bundle 启动**；不是 p21 无参数默认的全部场景。该路径未调用其 `write/conflict/categories/policy/choices-schema/flip/readonly`，故不能把这些场景的成本或证据算到普通 §38。

### 直接点到 38 与只由 floor/needs 带入

判据在 `smoke.sh:388–407` 收集 `SELECT_DIRECT_KEYS`，`:20959` 的 `p38_direct` 读取它；`:20965/20989` 分别控制 b2/b3。

| 本轮入口条件 | 38-a/b/d/e/f | 38-h/i |
|---|---|---|
| 不带选段参数的完整运行；选择器 `decision=FULL` 兜底 | 跑 | 跑 |
| `--select 38`；路径理由实际点到 38，包括 `--floor --paths` 命中 | 跑 | 跑 |
| `decision=RUN` 且仅 floor、`needs:*` 或 coupled 带入 38 | 跑 | **具名跳过**，不是暗中执行 |
| FAST | 纯逻辑部分跑；b/f 具名跳过 | 具名跳过 |

`section-paths.tsv:163/193` 仍为 `38 needs 28`、`63 needs 28,38`；纯依赖带入 38 **不会**再带入 b2/b3。这次建议改变的是普通全量与直接命中 38 的执行内容，floor/needs-only 的 b2 启动原来就是零次，不能给它记四次节省。全量中的 §38 也只执行一次，不能用 994 s 乘上 needs 的数量。

## 3 · 只改一处：剪贴板条件改变，不再重起整个面板

### 3.1 八次启动的逐项账

`panel-b2.sh:622–840` 已经只创建一次项目（`:624 server_up clipboard`）、一个私有 server、一次 PM 窗格（`:689`）。以下是它内部八次**面板**启动，不是八次 `team init`。

| 当前行号/启动 | 输入与实际证据 | 下一步建议 |
|---|---|---|
| `:690 start_panel image/image` | Wayland 图像优先、X11 不被调用；一个 PNG 文件内容 `PNGDATA8`；路径插在 `a…d` 的插入点 | 保留，作为该组真实冷启动 |
| `:712 start_panel fail/image` | Wayland 失败后读 X11；文件 `XCLIPDATA`，路径入草稿，调用日志先 wl 后 xclip | **退休重启**，保留这次 C-v、文件/草稿/顺序检查 |
| `:733 start_panel text/image` | 无图时文本回退；不读 X11、不写图片文件 | **退休重启**，保留这次 C-v 及原断言 |
| `:746 start_panel fail/fail` | 工具不给数据：草稿不变、无文件、仍能继续打字 | **退休重启**，保留这次 C-v、Z 和原断言 |
| `:759 start_panel hang/fail` | 工具挂起时草稿不变、无文件、仍能打 Z、Esc 正常 | **退休重启**，保留真实挂起工具、原 5s 观察及交互 |
| `:776 start_panel image/image` | 理由行粘入完整路径，消息草稿不变 | 保留这次独立输入模式的准备，本批不并入 |
| `:813 new-window`，不经过 `start_panel` | 换成记录动作的 `teamwrap.sh`；C-v 不触发 team 动作 | 保留不同 CLI 接口的启动，不误漏这一次 |
| `:830 start_panel image/image` | 未按 C-v 时，关闭/打开写信两段各 5s 均不调用工具 | 保留这次冷启动及两个观察窗口，不把“未变化”改成即时采样 |

**结构净减：8→4 次真实 bundle 启动；项目初始化 1→1、私有 server 1→1、PM 窗格启动 1→1、八个子用例 8→8。** 会退休的是四组 `kill-window/new-window → team monitor → 首帧等待`，而非任何剪贴板行为、状态写入或恢复事实。这个数不包含整个 b2 的其它场景，也不包含 p21/b3。

### 3.2 为什么这四次是准备重复，不是冷启动功能验证

`clip_env`（`:678–681`）给每次面板改变的只有 `P20_WL_MODE/P20_X_MODE`；PATH、TMPDIR、调用日志与可执行工具不变。模式由**测试提供的** `wl-paste/xclip`（`:648–676`）读取，只决定本次工具返回的内容。四处重启前后没有“重启后带回原草稿/设置”的断言；原草稿先写成 `ad` 或 `half a thought`，再靠重启加载，是设置下一个输入的手段。

最小候选做法是让现有两个假工具每次调用读取本次私有目录里的两个模式值，而不是从面板的固定环境读取；仍执行这些假工具的真实子进程。只在这个函数内维护两个普通输入文件，不建缓存、服务、runner 平台或新测试开关。第一至第五子用例共享首个活面板。

**必须同时替换旧的草稿准备方式。** 仅删 `start_panel`、继续 `printf ... > draft.md` 会让内存里仍是上次的草稿，不能工作。候选改为通过真实写信托盘清空并输入下一条种子，等屏幕与 `state/draft.md` 都是目标文本，沿用现有 Esc、m、C-e→C-u（单行种子）、键入和 `wait_draft/wait_frame`；随后照旧 Left、C-v。模式切换在前一次探测完成且输入托盘收起后进行，每个子用例照旧清自己的图片文件与调用日志。不得用未等到的上一例结果继续顶替下一例。

保留冷启动/恢复的事实：本组 `:690/:776/:813/:830` 四个启动；`scenario_draft:843–875` 的跨重启草稿恢复；`scenario_settle:1146–1160` 的发送后清空与重启无旧稿；p21 的设置写入/audit 和 b3 的页面/偏好重启。这里没有把“真界面要留”理解成“四次只换工具输出的重起也要留”。

### 3.3 一个最小具名反例，只计划、不运行

选 **`B4-CV-NOOP`**：在独立测试副本，把 `scripts/panel/src/App.tsx:2085–2086` 的 C-v 分支改成只 return、不调用 `pasteClipboard()`，其余按键与 `readClipboard` 不动。构建该副本 bundle 后，用已有 `TEAM_B2_PANEL` 指向它，只跑现有 `panel-b2.sh clipboard`，不新建变异平台。

预期第一例原具名断言 **`B4 TMPDIR 里恰好一个 teamsmith-paste-*.png`** 报 `0 != 1`，紧随的文件字节/插入点草稿也不能通过；恢复后同入口应通过。headless 的 `panel-clipboard-model.ts` 仍会通过，因为它直接调用 `readClipboard`，不经过真实 C-v。这个反例正好区分“保留了真实按键→产品→工具→文件/草稿”与“只剩纯函数/样张”。未来实际执行须让失败原样向 §38-h 的 `p38_verdict` 传播，不能只贴模型测试结果。

此外，正常例②的 `XCLIPDATA` 与例③的 `afrom the clipboardd` 已能揭穿模式未切换或串用上一例输出，不需再加一层“模式文件存在”的检查。本轮没有运行反例、没有构建 bundle，也没有改上述代码。

## 4 · 等待：不从已有事故验证里挤时间

这轮没有逐项测量，以下源码事实直接约束下一步范围：

- `panel-b2.sh:201–222` 的 `B2_KEY_GAP_US=200000` 用来把控制键分到不同 stdin 读；文件记录 V75 的同批按键会被 Ink 当粘贴。它不是“慢了就加的保险”，不缩短、不合并键来省数。
- `:761–772` 是挂起工具下仍可输入的观察，`:826–840` 是两段未按 C-v 时不调用工具的观察。单个“不变”瞬间不能证明整个窗口不发生动作；本批保留原 5s，不以更短超时提速。
- `panel-p21.sh:203–211/850–910` 要等写后的那一行/当前值实际到帧，避免用旧 settings 开选择器；`:1098–1123/1161–1169` 还有中间帧、已关闭选择器与不存在条目的旧故障检查。它们虽含测试自检，源码点名过 M59/M55 真实故障；本轮不把“已经有 §38m”当成逐条等价证明，也不把标题命中替代稳定帧。
- `panel-b3.sh:810–850/854–871` 分别走 pty 直驱与 tmux 点击，开/关/即时关闭检查终端原始序列和偏好落盘。接口不同，不能按名字都叫 mouse 就删一条。

因此不改等待上限、稳定帧条件或失败归因，不移动真实按键/鼠标/粘贴/resize 到夜间；只退休 §3.1 指定的四次准备。

## 5 · Deliverables / assessment

唯一交付：本报告 `docs/team/reports/P463-dev-bob.md`。产品、测试、配置、规格、他人报告、任务书与真实团队状态均只读；未启动真实模型、容器、Pi/tmux 或任何设置测试。

OpenSpec assessment：**N/A — 本任务是 `change: -` 的只读 infra 探索，没有新建/修改 requirement、设计或实施任务。** 本报告的候选不是第二份规格；PM 如接受，再独立派 propose 并交非作者评审。

- CRITICAL：0（限定为本报告的分析交付，不评判产品已验收）。
- WARNING：1，§1 的逐场景日志/原现场缺失，§3 的净省秒数与复用面板行为尚未实跑；这使下一步只能先提案，不能报已提速。
- SUGGESTION：1，§3 所述单点改造；未追加其它批次。
- 未验：完整设置/面板/§38、smoke 全量/FAST、meta/61b/夜间、真实模型、计时对照、反例；任务书明确禁止本轮运行。未运行无关 OpenSpec 全仓检查、选择器或产品检查。
- Flip evidence：**N/A（探索，不是缺陷修复）；§3.3 只提供下一阶段的具名反例计划。**

## 6 · 本轮实际证据

### 源码与历史原件

实际执行了 `git status --short`、`git branch --show-current`、`git log --oneline -5`，确认工作树初始干净、分支为任务分支。读取 P432 §2/3/5、旧日志的绑定/§38/尾部、当前子脚本；`git diff 572856a3..HEAD -- <相关路径>` 核对变化。

一次 Python 只读统计用 `subprocess.check_output(['git','show','572856a3:<path>'])` 对比 `Path(path).read_bytes()`；从两版 smoke 各取 `section "38 ·` 到 §38m 注释前；只统计 `scenario_clipboard` 范围的 `start_panel` 与直接 `new-window`。没有 source 或执行测试。实际输出尾部：

```text
skills/teamsmith/tests/panel-choices.sh: IDENTICAL
skills/teamsmith/tests/panel-p21.sh: IDENTICAL
skills/teamsmith/tests/panel-b2.sh: IDENTICAL
skills/teamsmith/tests/panel-b3.sh: IDENTICAL
skills/teamsmith/tests/panel-clipboard-model.ts: IDENTICAL
skills/teamsmith/tests/lib/pty-wait.sh: IDENTICAL
skills/teamsmith/tests/panel-b3-pty-mouse.py: IDENTICAL
skills/teamsmith/tests/fake-tui.py: IDENTICAL
skills/teamsmith/scripts/panel/panel.js: IDENTICAL
skills/teamsmith/scripts/lib/cmd-config.sh: IDENTICAL
smoke section 38: IDENTICAL sha256=d56f72c69306647d99a26dff6537a2057391bdee0cd0c1ac3fafe708e1e84221 lines=232
clipboard starts via helper: 690,712,733,746,759,776,830
clipboard direct panel new-window: 813
clipboard total bundle launches: 8
proposed removal lines: 712,733,746,759; 8 -> 4 bundle launches; no timing claim
```

该命令 rc=0；数字是静态正常路径次数，不是新的耗时测量或行为通过记录。

### 报告检查

报告先以 `9963e8c9` 提交静态结论，再补交检查回执；以下命令均在自己的任务工作树执行，报告已 `git add` 后才扫描。真实输出：

```sh
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev-bob scope=published files=2770 hits=0 names=ok user=resolved
$ echo $?
0

$ git diff --check
# rc=0，无输出
$ git diff --cached --check
# rc=0，无输出
$ git diff 8fc51cf1 --name-only
 docs/team/reports/P463-dev-bob.md
```

名单只通过主 git 公共目录的参数路径使用，未打印内容；扫描包含本任务分支的报告。报告补上这些回执后再次暂存并复跑同三项检查，结果仍为 `files=2770 hits=0 names=ok user=resolved` / rc=0，普通与暂存 diff-check 均 rc=0。最终仅提交自己的报告，本地分支收妥，不推送。

## 7 · Decisions / next step

- 范围偏离：无。没有代码/配置/规格改动，没有清理任何旧现场或其它任务目录，没有 push、PR/MR 或 merge。
- PM 下一步：只评审“剪贴板八次启动收敛到四次、真实子用例不减”的候选；如接受，另派 propose 与独立方案评审。没有现成秒数可承诺，不以增加框架、缩超时或牺牲真实接口作为代价。
