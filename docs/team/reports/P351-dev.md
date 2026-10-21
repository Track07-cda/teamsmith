# P351 · `panel-b3.sh` 那 8 条红的归因

task: P351 · agent: dev · phase: apply · category: analysis · branch: `task/P351-panel-b3-reds`

受检树：`cf834904`（= main 的 tip，`git diff main` 为空；我这一支没有改动任何产品/夹具文件）
主命令：`bash skills/teamsmith/tests/panel-b3.sh --all` → **✓ 223 ✗ 8**（WALL 212.6s，宿主 loadavg 11.5，32 核）
复核命令：`bash skills/teamsmith/tests/panel-b3.sh board detail workdetail` → **✓ 129 ✗ 8**

## 结论

**8 条全是夹具假设，没有一条是产品缺陷。** 两类原因、同一个来源：P125（`a78473ae`，2026-09-29）把宽档里折叠的车道从「一行摘要」改成「三列小框」，未折叠车道因此变宽；夹具里 7 条拿一个车道标签（`已放弃`）当「看板页在场」的判据，1 条把卡片点击的坐标写死在旧几何上。两样都在那次改动后失效，而 P125 只更新了它自己的 `fold` 场景（`git show a78473ae -- skills/teamsmith/tests/panel-b3.sh` 的 8 个 hunk 全在 `scn_fold` 内），这个文件又不在任何门禁段里（`skills/` 下没有任何非注释调用点：smoke 段只调用 `panel-b3-stub.sh` 与两个 pty 驱动，另有 `panel-flip-*`/`flip-*` 会调它），于是红着留到现在。

| # | 场景 · 断言原文 | 判定 | 一句依据 | 建议处置 |
|---|---|---|---|---|
| 1 | board · `按 4 切到看板页（六车道在场）`（`已放弃`） | 夹具假设过窄 | 120 列是并排档：空车道按规格折成三列小框，框里带不了标签（`panel/spec.md:2410-2424`） | 改判「六条车道目标按图例顺序在场」 |
| 2 | board · `重启后仍在看板页（panel-page 记忆）`（`已放弃`） | 夹具假设过窄 | 同上；`panel-page=4` 已单独断言（该条一直是绿的） | 同上 |
| 3 | board · `点击卡片后焦点没有移到被点的卡`（`--click-col 25`） | 夹具假设过窄 | P125 让未折叠车道 19→22 列，点的那张卡内容列 23→26；25 落在卡片内边距那一列 | 从帧里取列/行，见第五节 |
| 4 | detail · `夹具：控制台停在看板页（六车道在场）`（`已放弃`） | 夹具假设过窄 | 同 #1 | 同 #1 |
| 5 | detail · `q 返回看板页`（`已放弃`） | 夹具假设过窄 | 同 #1 | 同 #1 |
| 6 | detail · `Esc 返回看板页`（`已放弃`） | 夹具假设过窄 | 同 #1 | 同 #1 |
| 7 | workdetail · `B5 切到看板页`（`已放弃`） | 夹具假设过窄 | 同 #1 | 同 #1 |
| 8 | workdetail · `B5 esc 回到看板页`（`已放弃`） | 夹具假设过窄 | 同 #1 | 同 #1 |

四选一里落到的是「夹具假设过窄（写死了一种列宽/一档布局）」；「产品缺陷」「夹具假设错」「与规格无关的噪声」都不成立，逐条依据在下面。第 8 条单独查过：**不是时序，也不是行为差异，是坐标**（第三节）。

## 一、产品在 120 列这一刻显示什么，依据在哪

规格里写死了这一档的形态，不是未承诺的角落。`openspec/specs/panel/spec.md:2410-2424`（P123/P125 那条需求）：

> In the tiers where the board draws its lanes side by side, a folded lane SHALL take a three-column frame: a rounded corner at each of its four corners …, a vertical border on each side and, in the middle column, the ellipsis (`╭─╮` over `│…│` over `╰─╯` …). The folded lane SHALL keep its position in the fixed lane order, **so the frame alone says which lane it is**, and the whole width the three columns do not use SHALL go to the unfolded lanes … **The focused folded lane SHALL name itself — its label and card count — where the focused card's demoted pair renders, since three columns cannot carry the label.**

夹具的 pane 是 `120x32`（`panel-b3.sh:215`），≥100 列 → 并排档。默认看板 `review`、`dropped` 两个车道为空、按默认折叠，实帧是这样（`board/p4.txt`，去色）：

```
  总览   工作   消息与日志  [看板]  关键回复
╭─ ▾ 待办 1 ──────────────╮ ╭─ ▾ 进行 1 ──────────────╮ ╭─╮ ╭─ ▾ 完成 8 ──────────────╮ ╭─ ▾ 阻塞 1 ──────────────╮ ╭─╮
│ › · V14 独立复验：控制… │ │   ▸ P14 控制台表面：三… │ │…│ │   ✓ P13 消息入口与三个… │ │   ✗ V21 阻塞夹具        │ │…│
```

六条车道都在：四处带标签的头（27 列），两处折叠成 3 列小框（第 3、第 6 条，位置即身份）。`已放弃` 这个字符串在这一档里**按规格不存在**；它只在 <100 列的单列档、或者该车道有卡片/被显式展开时出现。

产品侧对应实现：`layout.ts:872 foldedLaneFrame()`（三列小框）与 `layout.ts:850 foldedLaneLine()`（窄档的原地一行），宽档走前者，注释里也写明了「the frame alone says which lane it is」。

**但规格本身有两套互相冲突的写法**，这正是夹具能写出错期望的来源，必须点名（见第五节 5.2）：

- `panel/spec.md:968-970`（kanban 需求）：「an unfolded empty lane shows a dim empty marker, **an empty lane folded by default shows its folded line**」。
- `panel/spec.md:979-981`（同一需求）：「a folded lane's **one line takes the width it needs**」——P125 之前的宽度规则。
- `panel/spec.md:993-999` 场景「Six lanes at the reference geometry」（**160 列**）：「the empty `blocked` lane rendered as **its folded line with its count `0`**」。
- `panel/spec.md:2445-2450` 场景「Folding a lane stops rendering its cards」（**160 列**）：「the folded frame draws **the lane's one line with its count `20`**」。
- 对照生效的那两条：`panel/spec.md:2493-2500`（190 列 → 三列小框）、`2501-2505`（聚焦的折叠车道在底栏点名自己）。

也就是说：同一条需求里的前后两段（`2397-2408` 的一行+「取所需宽度」 vs `2410-2424` 的三列小框）、以及两条 160 列旧场景，都还停在 P125 之前的形态；归档里 `design.md:78` 也仍是「F1 · In place, width re-shared … **chosen**」。P125 的提交没有碰 `openspec/`（`git show --stat a78473ae` = README + `panel.js` + `layout.ts` + 四个测试文件），规格文本靠更早的 `592c1657` 补进，旧句子就此留下。任何照着这些旧句子写断言的人都会写出这 7 条红。

**用户影响（如实）**：120 列上，空车道是一列无标签的小框；不记得图例顺序的人分不出第 3 个框是「待复验」还是「已放弃」，点一下它（或聚焦后用底栏）才会点名。这是 P125 用「把 17 列还给未折叠车道」换来的取舍：方向见 `592c1657` 的设计文本，具体形态（四个圆角 + 省略号列）是用户当时点名的要求（`f9a54faf`：the user asked）。所以它不是缺陷，但确实是可感知的摩擦点——要动它属于**产品变更**（例如聚焦/悬停时在底栏点名该车道），需要自己的 change，而不是改夹具。

## 二、类 A：7 条把「看板页在场」判成一个车道标签

它们想守的东西是**页切换与块替换**，不是标签本身：

- #1/#4/#7：「按 4 / Esc / q 之后，帧上是看板页，不是工作页/详情」；
- #2：「重启后仍停在第 4 页」；
- #5/#6：「从详情返回的是看板页」。

`已放弃` 只是当时随手选的「看板页独有字符串」。P125 之后这个字符串在 120 列不出现（该车道为空 → 三列小框），而**其余断言都绿**：`按 4 后 panel-page=4`、`重启后 panel-page 仍是 4`、`q/Esc 之后详情视图关闭`、`B5 看板页返回后 panel-page=4`。也就是说页切换本身是好的，红的只是这个代理判据。同一场景里 `p4` 帧上四条带标签的车道头（`▾ 待办 1` 等）都在，看板页确实画出来了。

P125 自己的改动是最直接的对照：它在 `fold` 场景把 `assert_has … "▸ 待复验 0（已折叠）"` 换成 `assert_not` + `assert_has "╭─╮"`（`git show a78473ae -- skills/teamsmith/tests/panel-b3.sh`），**同一件事它只改了自己那一段**，另外三处场景的 `已放弃` 代理没跟着改。

另有一条反向断言在同一个坑里：`board` 场景 `panel-page=9 时没有渲染看板页` 用 `assert_not … "已放弃"`——这个字符串在该档已不可能出现，该断言现在**恒真**（哑断言）。`detail` 场景的 `详情视图替换了看板块（替换块不留内容）` 同样恒真。这两条不在 8 条红里（它们绿），但性质更坏：接线（P349）会把它当覆盖，实际上什么都不守。修 #1-#8 时必须一并改，否则只是把红换成永真。

## 三、类 B：`--click-col 25` 那一条 —— 坐标，不是时序、不是行为差异

- **不是时序**：同一套注入（按下+释放，间隔 0.3s，之后 drain 1.0s）落在第 26 列时，光标在**同一个 drain 内**就移到 P14 上了（见下表的字节长度：点击后多出一整帧）。第 24、25 列那两次注入**没有产生任何重绘**（长度与「没点」一样），不是「结算晚了」，是根本没被当成卡片点击。
- **不是行为差异**：产品在这一刻就是「点卡片聚焦、点车道头折叠、点车道其它位置算该车道的滚轮区」，规格 `panel/spec.md:761-764`（a click on a kanban card SHALL focus it … a lane's header line … SHALL toggle that lane's fold）与实现一致；点在卡片左边的内边距那一列（lane 偏移 1）落在车道的 hover 区，什么也不发生。
- **是坐标**：P125 换了宽度分配，卡片的命中区跟着右移了一列。

量出来的几何（`B3_STUB_DONE=20` 那一刻的板，120 列，只有 `review` 是空车道）：

| | 未折叠车道宽 | wip 车道边框列 | 卡片内容起始列 | 夹具点的列 |
|---|---|---|---|---|
| P125 之前（`a78473ae^` 的 bundle） | 19 | 21 | 23 | 25 → **卡片内**，✓ |
| 现在（本树） | 22 | 24 | 26 | 25 → **内边距那一列**，✗ |

直驱 pty 扫列（同一份 fixture 根、同一张卡、`--click-row 4`）——「点完的帧里有没有 `› … P14`」：

```
now  col=24 → 光标没动（16756 字节，无重绘）   col=25 → 光标没动（16756 字节，无重绘）
     col=26 → › ▸ P14 控制台表面（33456 字节）  col=27/28/30/33 → 同样 › ▸ P14
pre  col=22 → 光标没动                          col=23/24/25/26 → › ▸ P14
```

（`pre` = `git show a78473ae^:skills/teamsmith/scripts/panel/panel.js` 的 bundle，同一 fixture、同一注入。）

所以原断言该守的东西没变、也仍然成立：**「点卡片 = 聚焦那张卡」**。失效的是它把列号写死成一个只在一版布局里成立的常数。

## 四、我没有把它当缺陷，但也不把它藏起来

- 三列小框不带标签**是规格明写的**（`2410-2424`），且方向与具体形态都定于 P125 那一批（`592c1657` 设计文本、`f9a54faf` 用户点名的四个圆角），所以不是「该显示却没显示」。
- 三列小框里连计数也没有；「折叠车道带 count」那句仍在 `2397-2398` 与两条 160 列场景里（`2445-2450`、`2453-2460`）。这是**规格冲突**，不是产品缺功能；收口方式见 5.2。
- 卡片内边距那一列（lane 偏移 1）点了没反应：规格没有承诺命中区的边界（只说 a click on a kanban card SHALL focus it），属于未承诺的角落；对用户的影响是点卡片最左边一列不生效。若要收，那是产品侧一行改动（把命中区左边界从 2 挪到 1），需要产品裁定，不属于本任务。

## 五、建议的处置

### 5.1 夹具（建议给 P352；我在 `/var/tmp` 私有副本里验证过，本分支未实现）

三处场景、9 处断言 + 1 处点击坐标，1:1 替换（断言总数不变，仍是 137 条）：

- 新增两个 helper（判行为，不判列宽）：`board_lanes` 从 `--snapshot --targets` 的目标表里按图例顺序取出去重的 `lane-fold` 车道名；`assert_board_lanes` 断言它等于 `todo,wip,review,done,blocked,dropped`。另加 `board_anchor()`（`▾ 待办`）给两条反向断言用。
- #1/#2/#4/#5/#6/#7/#8 → `assert_board_lanes "<原标签>"`。
- 两条哑断言改成判画布锚点：`assert_not "$(bfile oob)" "$(board_anchor)"`、`assert_not "$(dfile open)" "$(board_anchor)"`（看板页在时锚点必在、不在页上时必无——反侧已实测：page 4 快照有 1 处、page 1/2 有 0 处；目标表 page 4 = 六个车道、page 1/2 = 空）。
- #3 → 从帧里取坐标：行 = 带 `▾ 待办` 的那一行的下一行，列 = `进行` 标签列 + 1（`lane-first.txt` 已经是同一块板的捕获），再断言点完的帧里 `› … P14`。

验证（`/var/tmp` 副本、同一棵树的 `git archive` 展开、只改 `panel-b3.sh`）：

```
bash skills/teamsmith/tests/panel-b3.sh board detail workdetail
== board · 看板页：第四页记忆 / 焦点随重排 / 车道滚动 / 鼠标（4.2/5.3/5.4/6.1/6.2） ==
== detail · 详情视图：打开/返回 / tab / 滚动 / 只读 / 首帧（9.1–9.4） ==
== workdetail · P20/B5 工作页看板行：焦点 / 详情 / 原地返回 / 空与降级无死项 ==
== 结果 ==  ✓ 137  ✗ 0
```

对照未改的树：同三个场景 **✓ 129 ✗ 8**（137 条，一条没少），见「七、命令与输出」。完整 diff 见附录 A。

### 5.2 规格（另开一条；不是 P352 的范围）

现行 base spec 同时在说两种形态（第一节列了五处），必须用一条 **MODIFIED** delta 收口，否则下一个写夹具的人还会照旧句子写出同样的红：

- `panel/spec.md:968-970`（「an empty lane folded by default shows its folded line」）与 `979-981`（「a folded lane's one line takes the width it needs」）：改成「按宽度档：并排档三列小框、分组档原地一行；折叠车道的宽度份额由折叠需求那条决定」。
- 两条 160 列场景（`2445-2450`、`2453-2460`）与「Six lanes at the reference geometry」（`993-999`）：要么改成 190 列/三列小框，要么改成 99 列的窄档并把断言落在原地一行；不能保持现状（现文案与 `2410-2424` 直接冲突）。
- `2397-2398`（「A folded lane SHALL render as exactly one line carrying its label, its card count …」）：加一句「except where the three-column frame applies, where only the focused lane names itself」。

这是规格账，不是产品改动；也不需要动 `panel.js`。

### 5.3 产品：不改

P352 同批不要把本条解释成「让标签在 120 列也显示」。那会：
(a) 与 `2410-2424` 直接冲突（三列宽的框里放不下 `已放弃` 这种 6 列宽的标签）；
(b) 把 P125 刚刚还给未折叠车道的列再吃回去（默认板上就是每折叠一条少 24 列）；
(c) 需要自己的 change + 用户裁定（是「图例字母」还是「悬停/聚焦点名」）。

## 六、我没做 / 没验的

- 我没有跑 `smoke.sh` 的任何段（本任务只判这个夹具；接线是 P349；本分支只加了一份报告，跑的是 `openspec validate --all --strict`，21/21）。
- 我没有在源码树里改 `panel-b3.sh`、产品、门禁——写集只有本报告。第 5.1 的改法只在 `/var/tmp` 的 `git archive` 副本上验证过，没有提交。
- 我没有证明「P125 之前整份 `panel-b3.sh` 全绿」：我只证明了这 8 条断言在该版本上会绿（7 条标签：`a78473ae^` 的 bundle 在 120x32、page 4 的默认板上渲染出 `已放弃` 1 次（`▸ 已放弃 0（已折叠）`），现在是 0 次；1 条点击：见第三节的扫列）。其它场景的翻转未逐个重跑。
- 我没有改动或评价 `panel-flip-p123.sh`/`panel-flip-p125.sh` 是否该进 `fold` 段的红侧；那是接线任务的书。
- 「用户是否接受无标签小框」不是我能定的：这是 5.2/5.3 之间的产品裁定点，我只给出规格与实测。

## 七、命令与输出

受检树的干净度（跑之前/之后）：

```
HEAD=cf834904 dirty=0 load=11.55 7.75 8.41 11/8291 2628118 2026-10-21T04:31:30Z
```

整份夹具（本树）：

```
$ bash skills/teamsmith/tests/panel-b3.sh --all
...
== 结果 ==  ✓ 223  ✗ 8
  ✗ 按 4 切到看板页（六车道在场）（…/board/p4.txt 里找不到 [已放弃]）
  ✗ 重启后仍在看板页（panel-page 记忆）（…/board/relaunch.txt 里找不到 [已放弃]）
  ✗ 点击卡片后焦点没有移到被点的卡（no）
  ✗ 夹具：控制台停在看板页（六车道在场）（…/detail/board.txt 里找不到 [已放弃]）
  ✗ q 返回看板页（…/detail/back-q.txt 里找不到 [已放弃]）
  ✗ Esc 返回看板页（…/detail/back-esc.txt 里找不到 [已放弃]）
  ✗ B5 切到看板页（…/workdetail/board.txt 里找不到 [已放弃]）
  ✗ B5 esc 回到看板页（…/workdetail/board-back.txt 里找不到 [已放弃]）
rc=1 WALL 212.60 s
```

分段计数（同一份日志）：board ✓30 ✗3 · fold ✓28 ✗0 · detail ✓40 ✗3 · workdetail ✓59 ✗2 · 其余九段全绿（pages · settings · conf · queue · fold · mouse · wheel · resize · collapse）。8 条红集中在三个场景，`fold`（P125 自己改过的那段）全绿——这个分布本身就是「谁被更新、谁没被更新」的证据。

规格依据（原文截取）：

```
$ sed -n '968,970p;979,981p;993,999p' openspec/specs/panel/spec.md
the folded line … / one line takes the width it needs … / Six lanes at the reference geometry … its folded line with its count 0
$ sed -n '2410,2424p' openspec/specs/panel/spec.md
In the tiers where the board draws its lanes side by side, a folded lane SHALL take a three-column frame: …
```

P125 只改了自己的场景：

```
$ git show a78473ae -- skills/teamsmith/tests/panel-b3.sh | grep -c '^@@'
8        # 8 个 hunk 全部落在 scn_fold 内（1 个 helper + 若干断言）
$ git show --stat a78473ae | grep -c openspec
0
```

标签类翻转（同一 fixture 根、120x32、page 4、默认板）：

```
pre125  bundle: contains 已放弃 = 1   (▸ 已放弃 0（已折叠）)
current bundle: contains 已放弃 = 0
```

点击类翻转（同一 fixture 根、`B3_STUB_DONE=20`、120x32、`--click-row 4`）：

```
now  col 24/25 → 16756 字节，无重绘，光标仍在 V14
now  col 26/27/28/30/33 → 33456 字节，› ▸ P14 控制台表面
pre  col 22 → 无重绘；col 23/24/25/26 → › ▸ P14
```

几何（显示列，非字节）：

```
默认板（review+dropped 折叠）：未折叠车道 27 列、折叠框 3 列、车道行 119 列
点击那一幕（只有 review 折叠）：未折叠车道 19（P125 前）→ 22（现在）；wip 边框 21 → 24；卡片内容 23 → 26；行宽 120 → 118
```

建议改法的验证（`/var/tmp` 副本）：

```
patched-copy board detail workdetail 2026-10-21T04:36:52Z load=12.31 11.00 9.68
== 结果 ==  ✓ 137  ✗ 0
rc=0 WALL 108.11 s
```

副本留在 `/var/tmp/p351/exp/tree`（PM 可直接复跑 `bash skills/teamsmith/tests/panel-b3.sh board detail workdetail`），同一份改动对源文件的 diff 在 `/var/tmp/p351/exp/proposed-panel-b3.patch`；两者都不在本分支里，随时可丢。

规格校验（本任务唯一碰到的门禁面，因为本分支只加了一份报告）：

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 21 passed, 0 failed (21 items)     rc=0
```

（`openspec` 不在非登录 shell 与 `bash -lc` 的 PATH 上，只有 `~/.bun/bin` 里有；这里显式加上。）

反侧（证明新判据不是橡皮章）：

```
page 4 → lane-fold lanes: [todo,wip,review,done,blocked,dropped]
page 1 → lane-fold lanes: []          page 2 → lane-fold lanes: []
anchor ▾ 待办: page 4 → 1 处；page 1 → 0 处
```

收尾：两个后台作业都已收割（`p351-b3-all` exit=0、`p351-patched-3` exit=0），私有 tmux server 与临时根已按夹具自己的 cleanup 回收（`/var/tmp` 下无 `teamsmith-panel-b3-*` 残留，`tmux -L p14b3` 不存在），跑之前 `ps` 确认过没有别人的 `smoke.sh`。

## 附录 A：建议的夹具改法（在 `/var/tmp` 副本上验证过；本分支未实施）

```diff
@@ helpers（assert_* 之后）：新增两个判行为的 helper
+# 看板页「六条车道在场」的行为判据：判可点击的车道目标本身，不判某一档的列宽或标签。
+board_lanes() { # <outfile> → 打印按图例顺序去重的 lane-fold 车道名
+  "$js" "$panel" --snapshot --targets --root "$ROOT" --state-dir "$state" --team-cli "$stub" \
+    --lang zh --theme dark --width 120 --height 32 --page 4 > "$1" 2>/dev/null
+  python3 - "$1" <<'PYL'
+import json, sys
+try:
+    data = json.load(open(sys.argv[1]))
+except Exception as e:  # a broken dump must fail the assertion, not pass it
+    print(f"<unreadable: {e}>"); raise SystemExit
+seen = []
+for t in data:
+    a = t.get("action") or {}
+    if a.get("kind") == "lane-fold" and a.get("lane") not in seen:
+        seen.append(a.get("lane"))
+print(",".join(seen))
+PYL
+}
+assert_board_lanes() { # <label>
+  local want="todo,wip,review,done,blocked,dropped" got
+  got="$(board_lanes "$tmp/$current/board-lanes.json")"
+  assert_eq "$1（六条车道按图例顺序在场）" "$got" "$want"
+}
+board_anchor() { printf '▾ 待办'; }
@@ scn_workdetail
-  assert_has "$(wfile board)" "已放弃" "B5 切到看板页"
+  assert_board_lanes "B5 切到看板页"
-  assert_has "$(wfile board-back)" "已放弃" "B5 esc 回到看板页"
+  assert_board_lanes "B5 esc 回到看板页"
@@ scn_board
-  assert_has "$(bfile p4)" "已放弃" "按 4 切到看板页（六车道在场）"
+  assert_board_lanes "按 4 切到看板页"
-  assert_has "$(bfile relaunch)" "已放弃" "重启后仍在看板页（panel-page 记忆）"
+  assert_board_lanes "重启后仍在看板页（panel-page 记忆）"
-  assert_not "$(bfile oob)" "已放弃" "panel-page=9 时没有渲染看板页"
+  assert_not "$(bfile oob)" "$(board_anchor)" "panel-page=9 时没有渲染看板页（展开车道的头不在帧上）"
@@ scn_board 的 6.1 点击
-  --click-col 25 --click-row 4 --cols 120 --rows 32
+  # 坐标从帧里取：行 = 带 `▾ 待办` 的行的下一行；列 = `进行` 标签列 + 1
+  read -r click_col click_row < <(python3 - "$(bfile lane-first)" <<'PYJ'
+  … 行索引 head = 含 '▾ 待办' 的行；wip = 显示列('进行')；print(wip + 1, head + 2)
+PYJ
+  )
+  --click-col "${click_col:-26}" --click-row "${click_row:-4}" --cols 120 --rows 32
@@ scn_detail
-  assert_has "$(dfile board)" "已放弃" "夹具：控制台停在看板页（六车道在场）"
+  assert_board_lanes "夹具：控制台停在看板页"
-  assert_not "$(dfile open)" "已放弃" "详情视图替换了看板块（替换块不留内容）"
+  assert_not "$(dfile open)" "$(board_anchor)" "详情视图替换了看板块（看板锚点不在帧上）"
-  assert_has "$(dfile back-q)" "已放弃" "q 返回看板页"
+  assert_board_lanes "q 返回看板页"
-  assert_has "$(dfile back-esc)" "已放弃" "Esc 返回看板页"
+  assert_board_lanes "Esc 返回看板页"
```

（副本里 `read -r` 那段是完整的 heredoc（`PYJ`，带显示宽度函数），这里为可读性折成了伪码；要落地请按 5.1 的语义重写，别照抄折行。）
