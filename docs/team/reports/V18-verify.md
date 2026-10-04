# V18 · verify：console-board-page（P18 三批 apply 的独立验证）

agent: verify   status: **PASS**（带 1 条需要 PM 裁定的 finding 与 4 条留痕）   time: 2026-09-18T11:40:00Z
branch: `task/V18-verify-console-board-page-p1`   PR/MR: -（本仓库 local 模式：不 push，分支留 `.worktrees/verify`，PM 复验后本地合并）
验证对象：**main @ 00a8e4b**（P18 三批全部合入：B1 有界帧、B2 看板页、B3 只读 markdown 详情）
提案四件套：`openspec/changes/console-board-page/`；证物：`docs/team/reports/V18-verify/`（`pkg/` 可复跑小节 + `logs/` 全部原始输出）

## 判定

**PASS** —— `panel` delta 的四条 ADDED + 一条 MODIFIED + 一条 REMOVED（被四条页面要求取代）的**每个 scenario 都实跑取过证**，
没有一条 scenario 失败。三条口径上的偏差都追到了**我的夹具**（不是产品）：见 §5「我自己的三个假红」，已修正并重跑。

需要 PM 知道的事（都不构成 scenario 失败）：

| # | 级别 | 一句话 |
|---|---|---|
| **F-V18-1** | 文档漂移（建议修） | `skills/teamsmith/scripts/panel/README.md` 还是拆前口径：**「Three pages, switched by Tab or `1`–`3`」**、鼠标键 `1`–`3`，没有第四页/看板页/详情视图，也没写 `--detail`、`--targets`。规格不要求它，但它是面板的维护者文档，现在会把人带偏 |
| **F-V18-2** | 工具链（M28 侧） | `tests/container-tmux.sh` 的镜像里**没有 procps**（只有 BusyBox `ps`，不支持 `-o args= -p`）→ `panel-b3.sh` 的 `detail`/`collapse` 两段在容器里**必然假红 6 条**；同一份夹具在宿主上 `✓108 ✗0`。见 §4 |
| **F-V18-3** | 性能观察（要裁定） | 翻页路径有**缓存式内存增长**：60 次翻页 +147 MB（≈2.4 MB/次）后在 ~260 MB 平台；详情视图 +192 MB 后在 ~300 MB 平台；**空转 60 轮只涨 404 KB**。不是无界泄漏（尾段都平），但底噪偏高——见 §3.2 |
| **F-V18-4** | 归档门输入 | brief 说「PM 对每批做过复验（`reviews/P18.md` ×3 PASS）」，但**树里和历史里都没有 `reviews/P18.md`**；`reports/P18-dev3.md` 自己写着 `status: PARTIAL`（只交 B1+B2，B3 未开工）。B3 的提交在主线上、却**没有 apply 报告也没有复验记录** |
| **F-V18-5** | 夹具口径（给 PM 留痕） | 160 列下每条车道只有 26 列，stub 的长中文标题**任何宽度都放不下**（卡片被截成 `▸ P14 dev ap…`）——规格的「卡片带标题」场景只能用短标题夹具验（我用短标题板子验过，四项齐全）；`tests/panel-b3-stub.sh` 的默认长标题在快照里就是这样截断的 |

## 1. requirement × scenario 对账（逐条实跑）

各节的机器可读结果行（全文在 `logs/NN-*.log`）：

| 小节 | 结果行 |
|---|---|
| §10 有界帧 | `== 10 bounded frame 结果 == ok=40 bad=0 finding=0 skip=0` |
| §20 四页 | `== 20 four pages 结果 == ok=29 bad=0 finding=0 skip=0`（本轮最终复跑：10–50 五节合计 `ok=188 bad=0`，`logs/SUMMARY.txt`）|
| §30 看板 | `== 30 kanban 结果 == ok=40 bad=0 finding=0 skip=0` |
| §40 详情 | `== 40 detail view 结果 == ok=48 bad=0 finding=0 skip=0` |
| §50 鼠标 | `== 50 mouse targets 结果 == ok=31 bad=0 finding=0 skip=0` |
| §60 性能 | `== 60 performance 结果 == ok=10 bad=0 finding=0 skip=0` |
| §70 内存 | `== 70 memory drift 结果 == ok=2 bad=0 finding=1 skip=0` |

| requirement / scenario | 判定 | 独立证据（命令 → 结果） |
|---|---|---|
| **有界帧 / 页脚钉底（flip）** | ✓ | `panel.js --print --width 120 --height 40` → **恰好 40 行**，末行是键带；99x50 → 50 行；59x12 → 12 行；160x60/80x24 同理；四个页面×120x40 各自恰好 40 行、键带收尾；最后一个非空行 == 最后一行（内容下方无空行） |
| **有界帧 / 更高的帧显示更多内容** | ✓ | 工作页（看板折叠历史，120 版历史）：40 行 → **33 条看板行**，60 行 → **53 条**；看板页：40 行 → **34 张卡**，60 行 → **54 张**（`↑87` → `↑67`，隐藏数同步变小）；详情：40 行 → **34 行文档**，60 行 → **54 行**；四帧都以键带收尾 |
| **有界帧 / 极小窗格不越界** | ✓ | 真 tmux 60x8 窗格（`display -p` 证明几何是 `60x8`）：非空行 **8**、可见区最长行 **60 显示列**、最后一个非空行是键带（截断形态） |
| **有界帧 / 无上限 --print 一个字节都不多** | ✓ | 与 **B1 的父提交**的 bundle 对照：归一化时间戳后**逐字节相同**（17 行）；与 HEAD 对照：差异只有翻页键带 `Tab/1-3` → `Tab/1-4`（B2 加了第四页），行数不变 17 → 17 |
| **四页 / 翻页与记忆** | ✓ | 真窗格里按 `4` → 六条车道全在、`state/panel-page` = 4；**重启后直接打开看板页**（未发任何键）；按 `1` 回总览、`2` 到工作页、`3` 到消息页，`panel-page` 逐页跟随 |
| **四页 / 越界页值回落** | ✓ | `state/panel-page` 写 `9` → 渲染默认页（总览）、pane 没死、进程仍是渲染器 |
| **四页 / 空块折叠** | ✓ | changes 块报 `available:true, changes:[]` → 捕获里**没有**「活动变更」，同帧的看板/规格块照常渲染完整。（`available:false` 是**降级**形态：渲染一张 `—` 卡，smoke F2 钉着「不是静默空块」，所以折叠场景要用前者） |
| **四页 / 消息页列队列** | ✓ | 消息页列出两条 `[排队]`（`…001-pm.msg · 42s`、`…002-pm.msg · 7s`）与一条滞留（含扣住原因），年龄随条目 |
| **看板 / 六条车道** | ✓ | 160 列一帧：车道顺序 = `BOARD.md` 图例（待办→进行→待复验→完成→阻塞→已放弃），六条都有表头计数，`待复验 0` 渲染空标记 `·` 且无卡 |
| **看板 / 卡片四要素** | ✓ | 短标题板子：`▸ M9 dev apply the…`（id + agent + phase token + 标题，车道宽内截断）；真实数据路径 `team __panel-data --block board` 给出 `"phase": "apply"`（来自 brief 的 `phase:` 头）与无 brief 行的 `"phase": "-"` |
| **看板 / 窄终端降级** | ✓ | 99 与 59 列：六条车道**各占一行**、自顶向下仍是图例顺序、最长行 ≤ 该宽度；59 列卡片一行（id + 标题，**无 agent 列**） |
| **看板 / 焦点按 id 跟踪** | ✓ | 真窗格 + 可重写的 board：初始焦点 V14 → 把 V14 挪到别的位置并 `r` 重建 → 焦点**仍在 V14**；把 V14 从盘面移除 → 焦点落到同车道的另一张卡 |
| **看板 / 长车道滚动与隐藏计数** | ✓ | 120 张完成卡：首帧可见的是**列表尾部（最新）**的 33 张，边沿标 `↑87`，且 **87 == 120 − 33**；`↓` 越过后窗口滚动（可见 id 从 D88… 变成 D01…），焦点仍在看板 |
| **看板 / 滚轮按车道** | ✓ | page-4 目标图里有 **6 条** `lane-scroll`（各带自己的 `lane` 名），不是整页一个滚动区域 |
| **详情 / 三族发现与 id 边界** | ✓ | `__panel-data --block detail --id P1` → `count: 4`，四个文件（brief/report:dev/review/review:done）齐全，**P17 诱饵不在**，同名**目录**不算；无关联文件的 id → `count: 0` |
| **详情 / 拒绝发现集之外的路径** | ✓ | `--file ../../BOARD.md`、`--file docs/team/tasks/P17-b.md`、`--file /etc/passwd` 三种都**退 1**、给出原因、且不打印任何文件内容 |
| **详情 / 大文件有界且快** | ✓ | 240 KiB 报告：退 0、`truncated: true`、正文 **131072 字节**（128 KiB 界）、读取 **0.17 s**；从 Enter 到详情可见 **112 ms**（预算 1 s） |
| **详情 / markdown 结构** | ✓ | 标题去掉 `##`；围栏逐字（含 `EOF-not-a-fence`）；列表/块引用在；链接显示文本 + URL；**表格三行的列边界在显示宽度上完全对齐** |
| **详情 / 恶意字节** | ✓ | 围栏里嵌 `ESC [2J`：reader 的 JSON 无裸 `0x1b`，详情帧里 `[2J` 没有透传，可见文本（before/after）仍在 |
| **详情 / Esc 与 q 返回且不收控制台** | ✓ | 真窗格：`q` 与 `Esc` 之后都回到看板页，且**面板进程仍是 `panel.js` 渲染器**（不是 `--headless` tick） |
| **详情 / 只读** | ✓ | 一轮完整导航（开→翻 tab→滚动→返回 ×2）：`state/`+`docs/` 逐文件 md5 对照，**只有控制台自己的三个文件**可能变，其余哈希完全一致 |
| **鼠标 / 每个可点花式** | ✓ | 第 1 页目标图动作集：`page page-cycle compose flush standby settings quit scroll`（`m f s , Tab 1-4 ↑↓ q` 全覆盖）；**没有任何 refresh/rebuild 目标**（`r` 键盘专用，符合规格） |
| **鼠标 / 卡片先聚焦再打开** | ✓ | page-4 目标图：卡片级 `open-focused` **恰好 1 个**且属于被聚焦的 `todo` 车道（其余卡是 `focus`）；键带上另有 1 个 `open-focused`（就是 Enter chip，页脚可点） |
| **鼠标 / 浮层不 modal 化页脚** | ✓ | `--overlay`：帧里页脚 chip 仍在；目标图里 `compose`/`page`/`quit` 都在（页脚与页签仍可点），而**被替换的块没有任何 `card-*` 目标** |
| **鼠标 / 关掉就静默** | ✓ | mouse off 的帧里没有 `?1000h`/`?1006h`；真 pty 侧的「关 → 0 个鼠标序列」由发货夹具覆盖（宿主跑绿） |

## 2. 翻转（brief 第 2 项：改 layout 回内容高度 → 断言必须红）

`pkg/flip-frame.sh`，实录 `logs/flip-frame.out`。**产物优先**：`panel.js` 是提交进仓库、真正在跑的那份
（源码不在运行路径上，重建需要 registry），所以变异打在 **bundle 的同一段代码**上 —— 用 V16 那个自校验补丁器
（命中数必须等于期望、写回必须变化），并把 `layout.ts` 的对应行一起改，还原时一起回滚：

```
注入：if(height>0&&rows.length+footer.lines.length<height){…补白…}  →  if(false){…}
      flip-patch: bounded-frame padding: 1 hit(s) … bytes 866908..866938 → 866908..866913 changed
门禁（TEAM_SMOKE_FAST=1 smoke.sh）：== 结果 ==  ✓ 1620  ✗ 4
      ✗ 26-a bundle：重建后与提交的 bundle 不一致（源与产物漂了）
      ✗ 28-c 快照：快照套件失败
      ✗ 28-g 有界帧 120x40：恰好 40 行（帧不再低于给定高度）（期望 [40]，实际 [30]）
      ✗ 28-g 有界帧 99x50：恰好 50 行（期望 [50]，实际 [39]）
还原：git checkout -- skills/ → skills/ 逐字节干净（脚本自检）
```

**「实际 30 行」正是规格里点名的那条旧形态**（"≈29 rows rendered regardless of pane height"）✓ 翻转成立：
去掉填充 → 门禁红并点到行数断言 → 还原后树干净。

## 3. 性能与内存（brief 第 5、6 项）

### 3.1 CPU 与首帧（`panel-cpu.sh` 三档实测，宿主）

| 档位 | 窗格进程（红线 <1%） | reader tree | 交互首帧（预算 2000ms） | 夹具判定 |
|---|---|---|---|---|
| 总览（page 1） | **0.599%** | 21.7% | 1469 ms | `panel-cpu: OK` |
| 看板页（page 4） | **0.516%** | 21.2% | 1466 ms | `panel-cpu: OK` |
| 详情页打开 | **0.449%** | 23.9% | 1467 ms | `panel-cpu: OK` |

- **详情首帧**（我自己量的：Enter → 捕获里出现详情标题）：**112 ms** ✓（预算 1 s）。
- **静默成本**：看板页停着时 stub 的 spawn 日志里**没有 `detail`**；打开详情后 `detail` 才出现 ✓。
- reader tree 21–24% 是**块读取子进程**的合计（夹具自己的口径，不是红线）；窗格进程本身三档都远低于 1% ✓。

### 3.2 内存曲线（60 轮采样，三种形状）

| 形状 | 首 → 末 | 增量 | 结论 |
|---|---|---|---|
| 空转（不发键，同一段墙钟） | 111.7 → 112.1 MB | **+404 KB** | 刷新/tick 路径**不涨** ✓ |
| 每轮一次翻页（60 次） | 112.1 → 259.7 MB | **+147 MB（≈2.4 MB/次）** | 尾三样本平（平台），但底噪高 → **F-V18-3** |
| 开/关详情（60 次） | 109.6 → 302.1 MB | **+192 MB 预热后平台** | 没有逐次泄漏 ✓ |

判别口径：先看**空转是否涨**（不涨 ⇒ 不是 tick 泄漏），再看**尾段是否平**（平 ⇒ 有界缓存而非无界泄漏）。
两种会动键盘的形状都在 ~260–300 MB 处进入平台，所以不是线性泄漏；但「按一次翻页 ≈ 2.4 MB」的量级值得 PM 裁一次
（控制台是长驻进程：一小时翻页 100 次 ≈ +240 MB 且停在平台）。

## 4. 与发货夹具/容器的关系（F-V18-2 的证据）

- 宿主（`env -u TMUX -u TMUX_PANE`，私有 `-L` socket）：`bash skills/teamsmith/tests/panel-b3.sh` → **`== 结果 == ✓ 108 ✗ 0`，`panel-b3 全绿`**（`logs/suite-panel-b3-host.log`）。
- 容器（`tests/container-tmux.sh -- bash …/panel-b3.sh`）：**`✓ 102 ✗ 6`**，红的 6 条全部依赖 `ps -o args= -p <pid>`（`detail` 的「q 之后窗口进程不是渲染器」、`collapse` 的 5 条）。
- 根因：镜像里是 **BusyBox v1.37.0 的 `ps`**，`ps: unrecognized option: p`（`container-tmux.sh -- sh -c 'ps -o args= -p 1'` 实测）。
- 同一份夹具**只**跑 `detail collapse` 两段：宿主 **`✓ 35 ✗ 0` 全绿** ⇒ 6 条红是容器工具链，不是回归。
- 结论给 M28/P18：容器镜像装 `procps`（或让 harness 打印「容器内 `ps` 不支持 -o」的 SKIP），否则任何用 `ps` 判进程身份的夹具在容器里都会假红。
- 同一原因也意味着 `panel-cpu.sh` 不能在容器里跑（它用 `ps -o args= -p` 打印被测进程）——本包因此把它跑在宿主。

## 5. 我自己的三个假红（都追到夹具，修好才出的结论）

1. **「空块折叠」**：第一版夹具让 changes 报 `available:false` → 渲染的是**降级**卡（`—`），不是折叠。读实现后发现折叠条件是 `!c.changes.length`（`layout.ts:1043`）✓ 改成 `available:true, changes:[]` 后通过。
2. **「更高度显示更多内容」**：第一版夹具（20 张历史）在 40 行里**已经全部装下**，所以 60 行只能多出空白——那是规格允许的第三顺位（最后一张卡片的空白）。换成 120 张历史后，40→60 行的看板行 33→53 ✓。
3. **「卡片带标题」**：160 列下单条车道 26 列，stub 的长中文标题**必然**被截断（`…`），所以用短标题板子（M9）验四项齐全 ✓（F-V18-5 记了这件事）。

装配过程的另外几次自伤（记在日志里，不隐瞒）：`local a=$1 b=$a` 的 bash 求值顺序 + `set -u` 让两处辅助函数直接中止（已拆行）；
`wc -L` 之前用 `awk length($0)` 量的是**字节**（盒子线/CJK 每字 3 字节）导致「一行 180 列」的假象；
60x8 夹具第一版没钉 `window-size manual`/`resize-window`，捕获里混进了启动瞬间的大尺寸历史帧。

## 6. Findings（与开头表一致，带复跑命令）

- **F-V18-1（文档漂移）** `skills/teamsmith/scripts/panel/README.md`：`Three pages, switched by Tab or 1–3`、鼠标键 `1`–`3`，缺第四页/看板页/详情与 `--detail`/`--targets`。复跑：`grep -n 'Three pages\|1`–`3' skills/teamsmith/scripts/panel/README.md`。
- **F-V18-2（容器镜像缺 procps）** 见 §4。复跑：`TEAM_TMUX_RUNTIME="distrobox-host-exec podman" bash skills/teamsmith/tests/container-tmux.sh -- sh -c 'ps -o args= -p 1'`。
- **F-V18-3（翻页路径的内存平台）** 见 §3.2。复跑：`bash docs/team/reports/V18-verify/pkg/mem-probe.sh 60 tab`。
- **F-V18-4（归档门输入缺件）** `reviews/P18.md` 不存在；`reports/P18-dev3.md` 是 `PARTIAL`（B1+B2）；B3 无 apply 报告。复跑：`git log --all --pretty=format: --name-only -- docs/team/reviews/ | sort -u | grep -i p18`（只得到 `console-board-page-proposal.md`）。
- **F-V18-5（夹具口径）** stub 的长标题在 160 列车道里必然截断。复跑：`bash docs/team/reports/V18-verify/pkg/30-kanban.sh`（§30-b 的两块对照）。

## 验收（brief 的两条命令，全部实跑）

```
① $ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
   Totals: 14 passed, 0 failed (14 items)                     （openspec_rc=0）
② $ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
   == 结果 ==  ✓ 1624  ✗ 0                                    （fast_rc=0，10:45Z 跑在最终 tip 上；翻转实验另跑过一次同款门禁）
   （全文 logs/gates-fast.log）

另加两条强门禁（PM 复验用得上）：
③ $ bash skills/teamsmith/tests/smoke.sh
   == 结果 ==  ✓ 2057  ✗ 0                                    （full_rc=0；logs/gates-full.log）
④ $ env -u TMUX -u TMUX_PANE bash skills/teamsmith/tests/panel-b3.sh
   == 结果 ==  ✓ 108  ✗ 0   panel-b3 全绿                     （logs/suite-panel-b3-host.log）
```

本包一键复跑：`bash docs/team/reports/V18-verify/pkg/run.sh`（七节；`finding` 不失败，`bad` 才失败；
`SUMMARY.txt` 是权威汇总），翻转：`bash docs/team/reports/V18-verify/pkg/flip-frame.sh`。

## Decisions and deviations

- **验证对象是 main 合并后的树**（`00a8e4b`），不是某一批的分支；因此本报告同时是「三批合起来的不变量仍成立」的证据。
- **翻转打 bundle**（产物）而不是只改 `layout.ts`：源码不在运行路径上（面板 README 自述），重建需要 registry。
  补丁器是 V16 那个自校验的（MISS/AMBIGUOUS/NO-OP 都非 0 退出），并且**源码与产物同步改、同步还原**。
- **`panel.js --snapshot --targets` 只打印目标图**（没有帧），所以目标图与帧分开渲染 —— README 没写这条，我按实测用。
- **tmux 纪律**：本包每个 tmux 调用都走 `v18_tmux()`（`env -u TMUX -u TMUX_PANE` + 私有 `-L v18pkg-$$`，从不 `default`）；
  60x8 夹具在断言前先 `display -p` **证明几何**。发货夹具在宿主跑时也显式清了 `TMUX`/`TMUX_PANE`。
- **没有改任何 `skills/**`、`openspec/**` 或账本**：五条 finding 全部留痕交回，一个字没顺手改。
- **brief 的 `deps: P18` 与「PM 复验 ×3 PASS」**：P18 三批确实都在主线上，但复验记录不存在（F-V18-4）——我按「只验树」执行，没有去补记录。

## Suggested next steps

1. PM：把 **F-V18-1**（面板 README 的四页/看板/详情/`--targets`）补一句，成本十分钟；它是这个 change 唯一「改了行为没改文档」的地方。
2. PM：**F-V18-3** 需要一次裁定 —— 记成「已知内存平台」还是开一个小任务（比如给页面缓存加上限）。数在我这里：60 次翻页 +147 MB 后平台、详情 +192 MB 后平台、空转 +404 KB。
3. M28 侧：容器镜像加 `procps`（或 harness 在缺 `ps -o` 时打印 SKIP 而不是假红）—— 现在任何用 `ps` 判身份的夹具在容器里都会假红，容易被当成回归。
4. 归档前补齐 **F-V18-4** 的输入（`reviews/P18.md` 或把三批复验结论落成一份记录），并按流程让用户确认归档。
5. 后续动面板时把本包当回归用：`bash docs/team/reports/V18-verify/pkg/run.sh`（约 20 分钟）+ `flip-frame.sh`（约 3 分钟）。
