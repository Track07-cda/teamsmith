# P352 · `panel-b3.sh` 那 8 条：判行为，不判列宽

agent: dev　status: delivered　time: 2026-10-21T05:01Z（`date -u`，见 §5 各次运行的起止）
branch: `task/P352-panel-b3-assertions`　phase: apply　change: -　anchor: none (infra) — 夹具断言
specs: `verification#The gate judges behaviour only, and never reports a skip as a pass`

## 结论（先看这一段）

**8 条红全部改成判产品行为，断言总数不变（231 → 231）；红侧、绿侧的读数都在，翻回的说明见 §4 末。**

- **7 条**：判据从「帧上有没有 `已放弃`」改成「**帧上是看板页**（未折叠车道的头 `▾ 待办` 在场）**且目标表
  按图例顺序给出六条车道**」。两个条件都来自产品自己：前者只在看板页画，后者是产品的点击目标表（`--snapshot
  --targets`）对「这条车道在这里」的承诺。
- **1 条**：点击的列/行**从帧里取**（行 = 画着 P14 的那一行，列 = `P14` 这个 id 所在的显示列），实测
  `row=4 col=30`；写死的 25 正是 P125 之后卡片内边距那一列（改前那条就红在这里）。
- **顺带**：同一批里两条**恒真**断言（`assert_not … 已放弃`，P351 点名它们已变成永真）改成「帧上没有看板页
  的车道头」。不改就等于把红换成橡皮章。
- **绿侧**：`bash skills/teamsmith/tests/panel-b3.sh --all` → **✓231 ✗0**（WALL 211.43 s）；三个受影响场景
  `board detail workdetail` 改前 **✓129 ✗8**、改后 **✓137 ✗0**（同一台机器、同一份夹具，断言一条没少）。
- **红侧**（私有副本，产品只改一处）：
  - 让车道表少一条（`dropped`）→ **恰好那 7 条红**（✓130 ✗7），其余全绿，失败消息点名「车道目标
    `[todo,wip,review,done,blocked]` ≠ 期望 `[…,dropped]`」；
  - 把卡片命中区左边界从内容首列右移 7 列（画面上的 id 那几列不再属于这张卡）→ **第 8 条红**（✓134 ✗3；
    另两条同批的坐标断言跟着红，全是「点在卡片左侧那几列上」的同族）。
- **单次全场景耗时**（接线决策要的数）：`--all` **211.4 s**；三个受影响场景 107.4 s（改前）→ 109.3 s（改后）。
  宿主 `loadavg` 7.9–12.2（32 核）。

## 1 · 为什么「`已放弃` 在帧上」不能当判据

规格 `openspec/specs/panel/spec.md:2410-2424` 写死了并排档的形态：折叠车道是**三列小框**（四角圆角 + 两侧
竖边 + 中列省略号），框里放不下 `已放弃` 这样的标签，标签只在**聚焦**时到卡片那对位置显示。夹具的 pane 是
120x32 → 并排档 → 默认折叠的空车道（`review`/`dropped`）没有标签。P125（`a78473ae`）改的就是这个形态，它只
更新了自己的 `fold` 场景，于是这三处场景的 7 条代理判据红着留到今天（P351 的归因，我在保留的帧上复核过）。

同一件事的另一面：那两条 `assert_not … 已放弃`（`panel-page=9` 回落、详情替换看板块）在该档里**恒真**——
字符串已不可能出现，它们什么都没守。

## 2 · 改了什么（写集：只有 `skills/teamsmith/tests/panel-b3.sh`）

新增 5 个 helper（`panel-b3.sh:333-423`），9 处断言的判据 + 1 处坐标：

| 位置（改后行） | 断言 | 改法 |
|---|---|---|
| `panel-b3.sh:345` | `board_lane_list` | 跑产品自己的 `--snapshot --targets`（同一夹具状态、`--page 4`），把 `lane-fold` 目标按出现顺序去重 → 车道名序列；dump 读不出来就打印 `<unreadable: …>`，断言随之红（不当成「六条都在」） |
| `panel-b3.sh:365` | `board_anchor_hits` | 帧上未折叠车道头（`▾ 待办`）的处数；读不到文件按 0 算 → 断言红 |
| `panel-b3.sh:371` | `assert_board_page` | 一条断言：车道头 ≥1 处 **且** 车道序列 = `todo,wip,review,done,blocked,dropped`；失败消息把两半都报出来 |
| `panel-b3.sh:382` | `assert_not_board_page` | 一条断言：帧上没有车道头（反向） |
| `panel-b3.sh:395` | `card_point` | 按**显示列**（宽字符占两列）找出 id 所在的行与列，输出 `col row`；取不到就打印空，由下面的断言红（不回落常数） |

| 场景 · 断言 | 改前 | 改后 |
|---|---|---|
| `B5 切到看板页`（:603） | `assert_has … 已放弃` | `assert_board_page` |
| `B5 esc 回到看板页`（:610） | 同上 | 同上 |
| `按 4 切到看板页（六车道在场）`（:986） | 同上 | 同上 |
| `重启后仍在看板页（panel-page 记忆）`（:990） | 同上 | 同上 |
| `panel-page=9 时没有渲染看板页`（:997） | `assert_not … 已放弃`（恒真） | `assert_not_board_page` |
| `夹具：控制台停在看板页（六车道在场）`（:1184） | `assert_has … 已放弃` | `assert_board_page` |
| `详情视图替换了看板块（替换块不留内容）`（:1210） | `assert_not … 已放弃`（恒真） | `assert_not_board_page` |
| `q 返回看板页`（:1232） | `assert_has … 已放弃` | `assert_board_page` |
| `Esc 返回看板页`（:1247） | `assert_has … 已放弃` | `assert_board_page` |
| `点击 wip 车道第一张卡后焦点光标落在 P14 上`（:1140-1145） | `--click-col 25 --click-row 4` | `card_point "$(bfile lane-first)" P14` → `row=4 col=30`（并打印一行 `· 夹具` 把取到的点记进日志） |

断言条数一条没变：7 条 `assert_has` 变 7 条 `assert_board_page`，2 条 `assert_not` 变 2 条
`assert_not_board_page`，点击那条本来就是一条。

## 3 · 新判据为什么是真的（不是换个字符串）

- **反向**：保留的夹具里，page 4 的帧 `▾ 待办` 1 处、`▾` 共 4 处（四条未折叠车道）；page 1、page 2 的帧
  **两样都是 0**。所以「车道头在场」真的在区分「这一帧是不是看板页」，不是恒真。
- **六条车道的顺序**：同一帧的目标表 189 个目标，其中 `lane-fold` 63 个；按出现顺序去重正好
  `todo,wip,review,done,blocked,dropped`——第 2 行（车道头那一行）就给出六条车道的头，折叠车道的每一行
  也是目标，页脚那个 `c` 键的目标是同一车道的重复项（被去重吃掉）。
- **点击点**：`lane-first` 帧第 4 行里，wip 车道边框在第 24 显示列，卡片内容首列在第 26、`▸` 在第 28、
  `P14` 在第 30；写死的 25 落在内容与边框之间的空白列上。`card_point` 取到的 30 是画出来的 id，点它就聚焦。

## 4 · 红侧读数（私有副本，产品只改一处）

私有副本：`git archive HEAD`（本分支）展开到 `/var/tmp/p352/base`，再把改后的 `panel-b3.sh` 覆盖进去；
两个副本 `a`/`b` 各改 `panel.js` 的一行（同一个 bundle，其余字节不动）。**产品树本身没改**（`git status` 干净）。

### A · 车道表少一条（`dropped` 从 `BOARD_LANES` 里去掉）

```
$ cd /var/tmp/p352/a && bash skills/teamsmith/tests/panel-b3.sh board detail workdetail
  ✗ 按 4 切到看板页（六车道在场）（帧上车道头 1 处、期望 ≥1；车道目标 [todo,wip,review,done,blocked]、期望 [todo,wip,review,done,blocked,dropped]）
  ✗ 重启后仍在看板页（panel-page 记忆）（帧上车道头 1 处、期望 ≥1；车道目标 [todo,wip,review,done,blocked]、期望 […,dropped]）
  ✗ 夹具：控制台停在看板页（六车道在场）（同上）
  ✗ q 返回看板页（同上）
  ✗ Esc 返回看板页（同上）
  ✗ B5 切到看板页（同上）
  ✗ B5 esc 回到看板页（同上）
  · 夹具 6.1 的点击点取自 lane-first 帧：row=4 col=36（P14 的 id 列）
== 结果 ==  ✓ 130  ✗ 7        （rc=1，2026-10-21T04:52:17Z）
```

两件事都在这一次运行里：

- 红得准确——帧上的车道头仍 1 处（`todo` 还在展开），失败消息只说「六条车道」那一半不成立，没有把两半
  混成一句。
- 顺带读数：同一次运行里，6.1 的点击点从 `col=30` 变成 `col=36`（少一条车道 → 未折叠车道变宽 → P14 右移），
  **点击仍然绿**。坐标是跟着帧走的，不是又换了一个常数。

### B · 卡片命中区左边界右移 7 列（画出来的 id 那几列不再属于这张卡）

```
$ cd /var/tmp/p352/b && bash skills/teamsmith/tests/panel-b3.sh board detail workdetail
  ✗ 车道内滚轮上滚后没有看到原先隐藏的 done 卡片（车道没有滚动）
  · 夹具 6.1 的点击点取自 lane-first 帧：row=4 col=30（P14 的 id 列）
  ✗ 点击卡片后焦点没有移到被点的卡（no）
  ✗ 点击 tab 行切到 review（[review] 高亮）（…/detail/detail-click.txt 里找不到 [[review]]）
== 结果 ==  ✓ 134  ✗ 3        （rc=1，2026-10-21T04:54:13Z）

$ cd /var/tmp/p352/b && bash skills/teamsmith/tests/panel-b3.sh board      # 只跑 board，复现同一红
  ✗ 车道内滚轮上滚后没有看到原先隐藏的 done 卡片（车道没有滚动）
  · 夹具 6.1 的点击点取自 lane-first 帧：row=4 col=30（P14 的 id 列）
  ✗ 点击卡片后焦点没有移到被点的卡（no）
== 结果 ==  ✓ 31  ✗ 2        （rc=1，2026-10-21T04:59:55Z，修完已经跑过 --all 之后）
```

机制（读代码 + 上面两处读数对上）：`cardBody` 把卡片命中区从内容首列（车道偏移 2）右移后，卡片左侧那几列
**既不在卡片里、也不落进车道的 hover 区**（`laneColumn` 只给「这一行没有任何命中」的行补 hover）→ 那几列成了
死区。于是所有「点/滚在卡片左侧几列」上的断言都红：第 8 条点的正是 id 列（车道偏移 6），滚轮那条点的是 done
车道偏移 6，详情 tab 那条的点击（`--click-col 27 --click-row 4`）落在被推走的命中区左侧。**这不是抖动**：
单跑 `board` 两次都是同一条红，而且那 7 条仍然绿着（它们不依赖命中区）。

### 翻回

两个副本只活在 `/var/tmp/p352`；产品与规格文件从未出现在本分支的 diff 里（本任务的提交只有 `tests/panel-b3.sh`
与这份报告）。所以绿侧读数就是「未变异的原树」上的读数，不需要再翻回一次。

## 5 · 命令与读数（原样）

改前（同一分支，`panel-b3.sh` 还是 main 的样子；`git diff main -- skills/teamsmith/tests/panel-b3.sh` 为空）：

```
$ date -u +%FT%TZ; uptime
2026-10-21T04:43:50Z
 04:43:50 up 8 days,  1:55, 15 users,  load average: 7.86, 8.69, 9.06
$ bash skills/teamsmith/tests/panel-b3.sh board detail workdetail
  ✗ 按 4 切到看板页（六车道在场）（…/board/p4.txt 里找不到 [已放弃]）
  ✗ 重启后仍在看板页（panel-page 记忆）（… 里找不到 [已放弃]）
  ✗ 点击卡片后焦点没有移到被点的卡（no）
  ✗ 夹具：控制台停在看板页（六车道在场）（… 里找不到 [已放弃]）
  ✗ q 返回看板页（… 里找不到 [已放弃]）
  ✗ Esc 返回看板页（… 里找不到 [已放弃]）
  ✗ B5 切到看板页（… 里找不到 [已放弃]）
  ✗ B5 esc 回到看板页（… 里找不到 [已放弃]）
== 结果 ==  ✓ 129  ✗ 8        （rc=1，107.4 s，2026-10-21T04:43:50Z → 04:45:37Z）
```

改后：

```
$ date -u +%FT%TZ; uptime
2026-10-21T04:46:08Z
 04:46:08 up 8 days,  1:57, 15 users,  load average: 9.04, 9.07, 9.17
$ bash skills/teamsmith/tests/panel-b3.sh board detail workdetail
  ✓ B5 切到看板页（帧上是看板页：车道头 1 处；六条车道按图例顺序：todo,wip,review,done,blocked,dropped）
  …
  · 夹具 6.1 的点击点取自 lane-first 帧：row=4 col=30（P14 的 id 列）
  ✓ 点击 wip 车道第一张卡后焦点光标落在 P14 上（点击 = 聚焦）
  ✓ 详情视图替换了看板块（替换块不留内容）（帧上没有看板页的车道头）
== 结果 ==  ✓ 137  ✗ 0        （rc=0，109.3 s，2026-10-21T04:46:08Z → 04:47:57Z）
```

全量（本任务的红线）：

```
$ date -u +%FT%TZ; uptime
2026-10-21T04:56:22Z
 04:56:22 up 8 days,  2:07, 15 users,  load average: 8.37, 12.19, 10.97
$ /usr/bin/time -f 'WALL %e s' bash skills/teamsmith/tests/panel-b3.sh --all
  ✓ 详情会话没有写 state/ 下除控制台自有三文件之外的任何文件
  ✓ 收起后巡检仍在跑（capacity.log 1 → 2 行）
  ✓ pulse up 原地恢复控制台
== 结果 ==  ✓ 231  ✗ 0
WALL 211.43 s
rc=0                        （2026-10-21T04:56:22Z → 04:59:53Z）
```

帧读数（保留的夹具目录，改后那次运行）：

```
120x32 看板页（page 4）第 3-4 行（保留夹具里的原行）：
╭─ ▾ 待办 1 ──────────────╮ ╭─ ▾ 进行 1 ──────────────╮ ╭─╮ ╭─ ▾ 完成 8 ──────────────╮ ╭─ ▾ 阻塞 1 ──────────────╮ ╭─╮
│ › · V14 独立复验：控制… │ │   ▸ P14 控制台表面：三… │ │…│ │   ✓ P13 消息入口与三个… │ │   ✗ V21 阻塞夹具        │ │…│

lane-fold 目标 63 个 → 去重顺序 ['todo','wip','review','done','blocked','dropped']（第 2 行的 6 个就是六条车道头）
page 4 帧：▾ 待办 1 处、▾ 4 处；page 1 / page 2 帧：两样都是 0 处
B3_STUB_DONE=20 那一幅：wip 边框 24 列、内容首列 26、▸ 28、P14 列 30；写死的 25 = 内容与边框之间的空白
```

规格与门禁面：

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 21 passed, 0 failed (21 items)

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=$HOME/…/.worktrees/dev scope=published files=2013 hits=0 names=ok user=resolved
（rc=0：本报告本身也要过账本面这条；这一行里的家目录按 $HOME 写，避免绝对家目录进账本）
```

## 6 · 没做 / 没验 / 留给你判的

- **任务期间 main 前进了 3 个提交**（`04ed916d` P344/V84 的夹具修复 + 两条账本提交）：动的是
  `tests/routes.sh`、`tests/smoke.sh` 与 `docs/team/`，**没碰 `tests/panel-b3.sh`，也没碰面板 bundle**
  （`git diff main -- skills/teamsmith/scripts/panel/panel.js` 为空）。所以上面实测的那棵树的判定面与交付
  分支逐字节相同，合并到新 main 不会改变这些读数。

- **产品、规格、`smoke.sh`、`section-paths.tsv` 一个字没动**；接线（把本文件放进门禁段）是 P349。
- **P351 §5.2 的规格冲突没动**：`panel/spec.md:968-970`、`979-981`、`993-999`、`2445-2450` 仍是 P125 之前的
  写法，需要一条 MODIFIED delta 收口——那是另一条 change 的账，不在本任务书。
- **两处写死的点击坐标不在 8 条里、今天绿**：`workdetail ⑤`（`--click-col 20 --click-row 6`）与 `detail` 的
  详情 tab 点击（`--click-col 27 --click-row 4`）。红侧 B 证明它们对同类产品缺陷是敏感的（跟着红），所以不是
  橡皮章；但性质与第 8 条一样「只在某一版布局下成立」。要不要也改成从帧里取，请你判——我没扩大写集。
- **没在容器里跑**：这不是 smoke 段（本文件还不在任何门禁段里），宿主机直跑。树的状态要说准：改前那次与绿侧
  那次 `panel-b3.sh` 的改动已经在盘上；`--all` 那次运行时，工作树里唯一未提交的是 `assert_board_page` 上方那行
  注释（正是随后 `2f7db7b2` 提交的字节，跑完到提交之间没再动过）——**交付 tip 的测试文件与实测 tip 逐字节相同**。
- **代价**：每处 `assert_board_page` 多起一个 `--snapshot --targets`（node）进程，一轮 7 次。上面的耗时已含它：
  三个场景 107.4 → 109.3 s、`--all` 211.4 s（P351 在未加这 7 次调用的树上量到 212.6 s，差异在噪声内）。
