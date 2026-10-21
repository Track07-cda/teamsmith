# V88 · P352 那 8 条改成判行为之后还有判别力吗

agent: dev-bob　status: delivered　time: 2026-10-21T06:34Z（`date -u`，各次运行的读数见 §4）
branch: `task/V88-panel-b3-assertions-verify`（local 模式，未推）　phase: verify　change: -　deltas: -
anchor: none (infra) — 夹具断言
specs: `verification#The gate judges behaviour only, and never reports a skip as a pass`

## 结论（先看这一段）

**PASS。** 三件都验到了正面的读数，没有一件只能靠「作者说」：

1. **新判据不是换个姿势又写死一次。** 它不读任何列号：120 列只是它被借用的那个档，判据本身在 **80/90/99/100/110/140/160/200 列（两档形态都有）与 120×40** 上全部成立——锚 `▾ 待办` 恰好 1 处、六条车道顺序逐次 `todo,wip,review,done,blocked,dropped`。锚确实是具体字符，它的失效面我在 §1.2 逐条量了：**失效方向是红，不是假绿**（唯一的例外是「捕获文件本身缺失」时的反向那条，见 §1.2 末，那是改前就有的洞，不是新引入）。
2. **红侧三条变异各自红在该红的地方**（`/var/tmp/v88/` 私有副本，源文件未动）：看板页不再画 → 两个判据半边都塌（帧上车道头 0 处、车道目标 `[todo]`）；车道表少一条 → **恰好那 7 条**（✓130 ✗7，消息点名 `[todo,wip,review,done,dropped]` 少了 `blocked`）；卡片命中区左边界右移 → **第 8 条点击红**（✓135 ✗2）。
3. **没有顺手削弱。** 整份 diff 只有 12 个 hunk、10 行删除（正是那 8 条 + 1 行写死坐标）、97 行新增（5 个 helper 85 行 + 10 行替代断言 + 2 行坐标取点），**全部落在 `scn_workdetail` / `scn_board` / `scn_detail` 与它们上面的 helper 块里**，场景数 12 → 12，别的断言一条没动。

基线读数（同一份夹具、同一台机器）：受检树 `board detail workdetail` **✓137 ✗0**（WALL 108.54 s）；同一 bundle 换回改前的 `panel-b3.sh` **✓129 ✗8**（WALL 107.60 s）——总数都是 137，**这三条场景里没有增减断言**。

## 1 · 新判据随布局变化还成立吗

### 1.1 它判的是什么（读代码）

- **锚半边**：`board_anchor_hits` 数帧上 `▾ 待办` 的行数。`▾` 在 bundle 里只有一处来源——`UNFOLD_MARKER`
  （`src/layout.ts:795`），带它的只有 `laneColumn` 的展开车道头（`layout.ts:1072`）与
  `kanbanGrouped` 的展开车道头（`layout.ts:1144`）。两条都只在 `case 4` 的 `kanbanBlock` 里（`layout.ts:2804`），
  所以「帧上有展开车道头」⇒「这一帧画了看板页」。它不读列宽、不读列号、不读边框字形。
- **车道半边**：`board_lane_list` 跑产品自己的 `--snapshot --targets --page 4`，把 `lane-fold` 目标按出现顺序
  去重。车道顺序由 `BOARD_LANES`（`src/types.ts:20`）写死，规格把它当图例契约；折叠车道的每一行也带
  `lane-fold`（`foldedLaneFrame`，`layout.ts:858/876`），所以**折叠与否都不影响这一半**。

### 1.2 实测：换档、换宽、换高都不动，失效时是红

`--snapshot`（helper 用的同一个命令、同一个夹具态）在候选 bundle 上逐档读数：

```
width  height anchor     lane-order                                       verdict
80     32     1          todo,wip,review,done,blocked,dropped             MATCH   （分组档 <100）
90     32     1          todo,wip,review,done,blocked,dropped             MATCH
99     32     1          todo,wip,review,done,blocked,dropped             MATCH
100    32     1          todo,wip,review,done,blocked,dropped             MATCH   （并排档 ≥100）
110    32     1          todo,wip,review,done,blocked,dropped             MATCH
120    32     1          todo,wip,review,done,blocked,dropped             MATCH   （夹具用的档）
120    40     1          todo,wip,review,done,blocked,dropped             MATCH
140    32     1          todo,wip,review,done,blocked,dropped             MATCH
160    32     1          todo,wip,review,done,blocked,dropped             MATCH
200    32     1          todo,wip,review,done,blocked,dropped             MATCH
```

锚的分布（120×32，zh）：只有看板页有它，别的页一处也没有。

```
page 1: ▾ 待办 0 处（▾ 共 0 处）    page 4: ▾ 待办 1 处（▾ 共 4 处）
page 2: ▾ 待办 0 处（▾ 共 0 处）    page 5: ▾ 待办 0 处（▾ 共 0 处）
page 3: ▾ 待办 0 处（▾ 共 0 处）
```

锚的四种失效，各自的方向：

| 失效条件 | 读数 | 方向 |
|---|---|---|
| `todo` 被显式折叠（`boardFold=todo`，`fold` 场景自己就会写这个配置） | 看板页仍在（三列小框 3 处、`▾` 3 处），但 `▾ 待办` **0 处** | **红**（假红：看板页画着却说没有）。今天 `board/detail/workdetail` 三条场景不设这个键，所以是绿的；谁以后在这三条里加了这个键，红会替他说。 |
| 语言换成 `en` | 锚文本变成 `▾ todo`（实测 `▾ todo ▾ wip ▾ done`） | 红。helper 写死 `--lang zh`，所以不进这条；写死语言是它成立的前提，不是巧合。 |
| 夹具里 `todo` 变空（空车道默认折叠） | 实测（`B3_STUB_BOARD_FILE` 喂一份没有 todo 行的板）：看板页照画（`▾` 3 处、小框 3 处、`▾ 进行` 1 处），但 `▾ 待办` **0 处**；车道目标仍完整 | **红**（假红，同第一行）。`boardEmptyFold=0` 时锚回到 1 处 |
| 捕获文件本身不存在 | `board_anchor_hits` 返回 0 | `assert_board_page` → **红**（好）；`assert_not_board_page` → **绿**（恒真）。改前的 `assert_not … 已放弃` 在同一种情况下同样恒真（`grep` 读不到文件就不匹配），所以这不是削弱，但也没有收口。 |

## 2 · 红侧（自己造的三条变异）

三份副本都从 `git archive 43208b54` 展开，**只改 `skills/teamsmith/scripts/panel/panel.js` 一处**，改点用
`cmp -l` 证明是单点（m1 1 字节、m2 删 10 字节、m3 1 字节）；产品树与分支上的文件一个字节没动。

| 变异 | 改点（bundle 原文 → 变异） | 走哪种观测 | 读数 |
|---|---|---|---|
| **m1** 看板页不再被画出来 | `case 4:D.push(I.view.detail?j5(I):eL(I));break;` → `case 6:…`（page 4 落到 `default` 分支，画消息页那套块） | helper 自己的两条命令 + pty 实跑 | 帧 **车道头 0 处**、车道目标 **[todo]**（只剩页脚 `c` 键那条指向焦点车道）→ 两个半边同时塌。pty 实跑在到达的两条场景里给出：`✗ 按 4 切到看板页`、`✗ 重启后仍在看板页`、`✗ 夹具：控制台停在看板页`，`✗ 点击卡片后焦点没有移到被点的卡`，反向那条 `✓ panel-page=9 时没有渲染看板页`（看板页没画，它本来就该绿）。同一次里看板自身的读法也随之全红（M48 重复 id、done 车道锚定等）——板子不在，它们本来就该红。 |
| **m2** 车道表少一条 | `var L1=["todo","wip","review","done","blocked","dropped"];` → 去掉 `"blocked"` | pty 实跑（源文件 `board detail workdetail`） | **✓130 ✗7**，WALL 108.97 s。红的**恰好**是那 7 条看板页断言，消息把两半分开报：`帧上车道头 1 处、期望 ≥1；车道目标 [todo,wip,review,done,dropped]、期望 [todo,wip,review,done,blocked,dropped]`。其余 130 条全绿。 |
| **m3** 卡片命中区左边界右移 | `hits:[{start:0,end:…}` → `start:9`（画出来的 id 那几列不再属于这张卡） | pty 实跑 | **✓135 ✗2**，WALL 109.31 s：`✗ 点击卡片后焦点没有移到被点的卡`（第 8 条，写死 `--click-col 25` 时红的就是它，取帧坐标后仍然红）+ `✗ 车道内滚轮上滚后……`（同一处死区的同族读数）。7 条看板页断言保持绿——这条变异不碰页面，它们不该红。 |

**m1 的边界（说准）**：这条变异的 pty 实跑没走完——看板页不在，夹具里那些「等下一帧」的等待会一路烧到上界
（`detail` 场景实测一次 `Enter→详情标题` 等了 **559.138 s**），跑到 12 分 08 秒时按任务书的时间盒停下，所以
那 7 条里**只有 3 条拿到了 pty 上的逐字读数**（上表），另 4 条（`q`/`Esc` 返回、`B5` 两条）没有跑完。它们的
判据与那 3 条是同一个函数、同一个帧来源，我在同一份变异 bundle 上用 helper 自己的两条命令量到
`锚 0 处 / 车道目标 [todo]`——按 `assert_board_page` 自己的代码，这两半任一不成立就 `bad`。

## 3 · 没有顺手削弱（逐条核 diff）

`diff -u0` 于「改前 `panel-b3.sh`」与「候选 `panel-b3.sh`」之间：

```
hunks: 12   removed lines: 10   added lines: 97
```

- **删除的 10 行就是全部改动面**：7 条 `assert_has … 已放弃`、2 条 `assert_not … 已放弃`、
  1 行 `--click-col 25 --click-row 4`。没有删别的断言、注释、等待或场景。
- **新增的 97 行** = 5 个 helper 与它们的注释（85 行：`board_lane_list` / `board_anchor_hits` /
  `assert_board_page` / `assert_not_board_page` / `card_point`）+ 10 行替代断言 + 2 行取点与它的 `· 夹具` 日志行。
- **hunk 归属**（改前行号 → 场景）：`332`（helper 块，`scn_pages` 之前）、`511/518` → `scn_workdetail`、
  `894/898/905/1045/1048` → `scn_board`、`1087/1113/1135/1150` → `scn_detail`。
  **别的场景、别的断言一条没进 diff。**
- **数量核对**：断言调用行 179 → 181（新增的正是两个 helper 各一条调用：一个 `ok` 分支、一个 `bad` 分支，
  静态计为 2 行 `assert_*` 定义体里的 `ok/bad`，故直接 `ok`/`bad` 行 52 → 56）；场景函数 12 → 12（名字与顺序未变）。
  运行时总数：受检树三条场景 **137**（✓137 ✗0），改前脚本同三条场景 **137**（✓129 ✗8）——**断言总数没变**。

## 4 · 命令与读数（原样）

```
$ git -C . rev-parse --short HEAD  → 2a00ecec（任务分支；受检的是 43208b54 的树）
$ date -u +%FT%TZ; uptime
2026-10-21T06:16:13Z
 06:16:13 up 8 days,  3:27, 16 users,  load average: 6.34, 5.69, 6.98

# 受检树（未变异）：三条受影响场景
$ cd /var/tmp/v88/cand && bash skills/teamsmith/tests/panel-b3.sh board detail workdetail
== 结果 ==  ✓ 137  ✗ 0
panel-b3 全绿            WALL 108.54 s        （06:16:13Z → 06:18:02Z）

# 改前的 panel-b3.sh + 同一个 bundle（复现作者的「改前」）
$ cd /var/tmp/v88/base && bash skills/teamsmith/tests/panel-b3.sh board detail workdetail
  ✗ 按 4 切到看板页（六车道在场）（…/board/p4.txt 里找不到 [已放弃]）
  ✗ 重启后仍在看板页（panel-page 记忆）（…/board/relaunch.txt 里找不到 [已放弃]）
  ✗ 点击卡片后焦点没有移到被点的卡（no）
  ✗ 夹具：控制台停在看板页（六车道在场）（…/detail/board.txt 里找不到 [已放弃]）
  ✗ q 返回看板页（…/detail/back-q.txt 里找不到 [已放弃]）
  ✗ Esc 返回看板页（…/detail/back-esc.txt 里找不到 [已放弃]）
  ✗ B5 切到看板页（…/workdetail/board.txt 里找不到 [已放弃]）
  ✗ B5 esc 回到看板页（…/workdetail/board-back.txt 里找不到 [已放弃]）
== 结果 ==  ✓ 129  ✗ 8
WALL 107.60 s

# helper 自己的两条命令，四个 bundle（120x32，同一夹具态）
tree   anchor    lanes                                                verdict
cand   1         todo,wip,review,done,blocked,dropped                 GREEN
m1     0         todo                                                 RED
m2     1         todo,wip,review,done,dropped                         RED
m3     1         todo,wip,review,done,blocked,dropped                 GREEN
```

绿侧逐字（受检树，7 条看板页断言 + 1 条取点日志）：

```
✓ 按 4 切到看板页（六车道在场）（帧上是看板页：车道头 1 处；六条车道按图例顺序：todo,wip,review,done,blocked,dropped）
✓ 重启后仍在看板页（panel-page 记忆）（同上）
✓ panel-page=9 时没有渲染看板页（帧上没有看板页的车道头）
· 夹具 6.1 的点击点取自 lane-first 帧：row=4 col=30（P14 的 id 列）
✓ 夹具：控制台停在看板页（六车道在场）（帧上是看板页：车道头 1 处；…）
✓ 详情视图替换了看板块（替换块不留内容）（帧上没有看板页的车道头）
✓ q 返回看板页（帧上是看板页：车道头 1 处；…）
✓ Esc 返回看板页（帧上是看板页：车道头 1 处；…）
✓ B5 切到看板页（帧上是看板页：车道头 1 处；…）
✓ B5 esc 回到看板页（帧上是看板页：车道头 1 处；…）
```

## 5 · 没做 / 没验 / 留给你判的

- **没跑 `--all`**（任务书上限两遍，我一遍也没用）：三条受影响场景在改前/改后两个方向上各跑了一遍，
  总数 137 与作者的全量 231 不相交但同源；231 这个总数我只核了静态差（§3），没有重跑全量。
- **m1 的 4 条腿没有 pty 逐字读数**（原因与读数见 §2 末）。要给全，得让 `detail`/`workdetail` 在那份变异上
  跑到底——单 `detail` 一次就烧掉 559 s 的等待上界，我没有再开第二次（任务书给了时间盒）。
- **`assert_not_board_page` 在捕获文件缺失时恒真**（§1.2 末）。改前同病；要不要把两个反向断言也改成
  「文件不在就红」，请你判——那是另一笔改动，我没扩写集。
- **候选与 main 的关系**：main 的 `panel-b3.sh` 仍是改前版本（`git diff 43208b54 main -- …panel-b3.sh` = 10 增 107 删），
  而 `panel.js` 在候选与 main 之间**逐字节相同**——所以上面所有读数判的是那份测试文件，产品面没有被 P352 碰过。
- **写集**：只有本报告。产品、规格、`smoke.sh`、`panel-b3.sh` 在任务分支上我一个字节没改；
  三份变异副本只活在 `/var/tmp/v88/`（m1 那次运行在 12 分 08 秒时按时间盒停下，副本与日志都还在）。
