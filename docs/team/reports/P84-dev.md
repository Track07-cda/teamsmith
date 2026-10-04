# P84 · bottom-border-candidate-selection 独立验证（verify 阶段）— 交付报告

```
agent:   dev
status:  delivered（verify 完成；brief 六项全绿 + 三条变异；另交一条 finding，请 PM 裁定）
time:    2026-09-22T21:57Z
branch:  task/P84-p84（local 模式：不 push，分支留在 .worktrees/dev，PM 复验后本地合并）
change:  bottom-border-candidate-selection（propose=P78 verify · apply=P80 dev3；phase=verify；deltas=delivery-guard）
brief:   docs/team/tasks/P84-bottom-border-verify.md
tip:     task/P84-p84（cacd0669 = package + 报告初稿；78318db4 = 全量门禁 tail + 真帧字节断言；HEAD 只比它们多本行）
baseline: 旧树 = P80 apply（c9b1de90）的父提交 df284000，`git archive df284000 -- skills/teamsmith` 取整棵树对照
```

## 交付物

| Path | What |
|---|---|
| `docs/team/reports/P84-dev.md` | 本报告（brief 六项 + 变异 + finding 的全部原始输出） |
| `docs/team/reports/P84-dev/pkg/run.sh` | 验证包入口：`bash docs/team/reports/P84-dev/pkg/run.sh [10 20 … 80]`，退出 0 = 脚本级断言全过（finding 不失败） |
| `docs/team/reports/P84-dev/pkg/lib.sh` | 断言/探针/自造帧/旧树基线/scratch 复制（全部只读实现树） |
| `docs/team/reports/P84-dev/pkg/frame-probe.sh` | 纯帧探针：`_team_box_geometry` + `_team_box_text_of_frame` + `team_box_frame_verdict`，可选影子 |
| `docs/team/reports/P84-dev/pkg/production-probe.sh` | 生产路径探针：真 `team_input_box_state`/`team_input_box_text` 走 PATH 上的**假 tmux**（不开真 server/session） |
| `…/pkg/10-shapes.sh` … `80-candidate-fix.sh` | §10 五形态自造帧 / §20 单调性 / §30 代价 / §40 一处实现 / §50 反例 finding / §60 三条变异 / §70 守卫矩阵 / §80 实测的候选修复（scratch） |
| `docs/team/reports/P84-dev/logs/{run-full,pkg-10…pkg-80,fast-smoke,full-gate,matrix-*}.log` | 下面所有 tail 的原始来源 |

## 一、结论速览（brief 六项 + 三条变异 + finding）

| brief 项 | 判定 | 关键值（原始输出见 §二） |
|---|---|---|
| 1 下边框 = 最低合格行（**自造帧**） | ✓ | ① `[1 3] EMPTY` → `[1 5] NOT-EMPTY`；①b `→ [1 4]`；② `[1 5]` 不变；③ spinner 留框内；④ 光标行不是候选（严格下方）；⑤ 三行草稿全在框内 |
| 2 单调性：全部已存帧 旧序 vs 新序，不得 BUSY→EMPTY | ✓ | 13/13 帧逐帧对比：**0 违规**（4 帧 EMPTY→BUSY、1 帧仅几何、8 帧不变） |
| 3 代价边界（自造帧） | ✓ | 框下方整行 rule → 框撑大 `[1 3]→[1 4]` / `[1 3]→[1 5]`，一律 `NOT-EMPTY`（保守方向） |
| 4 一处实现 | ✓ | tests/** 无第二份几何/候选循环；生产路径与夹具判定在 **26 帧**上逐字一致；影子 = 真旧树（26 帧逐字）；红侧到得了生产路径 |
| 5 真帧不回退（0.85.1 / 0.87.0） | ✓ | 5 份真帧新旧两侧**逐字相同**（几何+判定+rc），且帧**字节**与 P80 之前逐字相同（apply 没改实拍）；绝对值与 delta 场景一致 |
| 6 零回归 | ✓ | `openspec validate --all --strict` 30/0；FAST **✓2550 ✗0**；**全量门禁 ✓3216 ✗0（含 44·P80-真pane，就绪门拒绝 + keylog 零行）**；守卫矩阵新旧 31 行逐字相同 |
| 变异 A/B/C（红→绿，全在 scratch） | ✓ | 见 §三；还原后实现树 `git status`/`git diff` 干净 |
| **finding F1** | **! 1 条（3 帧）** | 混宽度帧上「框只会变大」被证伪：旧树 BUSY → 新判据 EMPTY（**危险方向**）；实测布局不可达，裁切型 TUI 模型可达；§六 给出实测修复路径（`pkg/80`） |

**一句话**：brief 的六项验收与三条变异全部通过，apply 的每一条承诺都逐字复现了；但对抗性探针造出了**本 change 引入的一条反向行为**（F1），它不违反 brief 的字面（brief 的硬性单调性只要求「全部已存帧」），却与 delta requirement 与 design §3 的**普遍**声明相反，方向是粘连（危险）那一侧。请 PM 裁定返工或收窄文字。

## 二、逐项证据（自造帧 + 复现命令 + 原始输出）

复现命令（全部只读实现树；实现树是 main tip `8eae8af8`，已含 P80 apply `c9b1de90`）：

```sh
bash docs/team/reports/P84-dev/pkg/run.sh          # 全部：== run 结果 == ✓130 ✗0 · findings=3
bash docs/team/reports/P84-dev/pkg/run.sh 10 20    # 单项：10/20/30/40/50/60/70/80
```

### 2.1 五种形态（brief 1，帧由我自己构造，不复用已存八份）

自造帧用 80 字符宽的 rule（与已存帧的 120 不同），①–⑤ 每例都同时跑「新树 / 真旧树 / 影子」三侧：

```
① equal-width draft rule below the cursor (cy=2)
  new    geometry=[1 5] box_nows=[────(80)…drafttextbelowmyownrule]  verdict=idle-read=NOT-EMPTY rc=1
  old    geometry=[1 3] box_nows=[]                                   verdict=idle-read=EMPTY rc=0
  shadow geometry=[1 3] box_nows=[]                                   verdict=idle-read=EMPTY rc=0
①b the draft is exactly one rule row (cy=2)
  new    geometry=[1 4] verdict=idle-read=NOT-EMPTY rc=1     old [1 3] EMPTY rc=0（shadow=old）
② a wider rule row below the cursor (100 vs 80, cy=2)
  new/old 几何与判定逐字相同 [1 5] NOT-EMPTY（宽行不配对 → 不能当边框）
③ a spinner-shaped row below the cursor (cy=2)
  new/old [1 5]，spinner 行留在框内算内容（Blanching）→ NOT-EMPTY
④a cursor row is itself a full-rule row, real bottom border below (cy=2)
  new/old geometry=[1 3] NOT-EMPTY（下边框在光标**下方**取；光标行是内容）
④b cursor row is a full-rule row and nothing below pairs (cy=2)
  new/old geometry=[]（严格下方无合格候选，不伪造框）；生产路径 input_box_state=UNKNOWN
⑤ cursor in the middle of a three-line draft (cy=3)
  new/old [1 5]，框文本 = draftline1draftline2draftline3 → NOT-EMPTY
⑦ payload == 框线上半段（cy=2, payload="half a sentence"）
  new  [1 5] box_nows=[halfasentence────…moredraft] holds_only=extra-text
  old  [1 3] box_nows=[halfasentence]              holds_only=only-ours
```

对应断言（`logs/pkg-10.log`：`== 10 结果 == ✓34 ✗0`）：

- ①/①b：新判据把草稿自己画的框线**留在框内**（box 文本含该 rule 行与下方草稿文字）、判 `NOT-EMPTY rc=1`；旧树在同一帧读 `[1 3]`/`EMPTY rc=0`（P74-F1 的红形状逐字复现）。
- ②/③/⑤/④a/④b：**控制帧**，新旧逐字相同 → 判据只动了它该动的那一维。
- ⑦：`holds_only` 从 `only-ours` → `extra-text`（截断框不再吞掉下半段）。

### 2.2 单调性（brief 2）与真帧不回退（brief 5）

我自己的对比脚本（`pkg/20`，不是跑门禁的断言）：一侧是 `git archive df284000` 取出的**真旧树**，另一侧是实现树；逐帧打印 `old-geo old-verdict / new-geo new-verdict`，分类计数：

```
frame                                      cy   old-geo      old                    new-geo      new                    flag
p78-conversation-rule-below-box.txt        2    [1 3]        idle-read=EMPTY        [1 4]        idle-read=NOT-EMPTY    ↑ EMPTY→BUSY（允许）
p78-cursor-mid-draft.txt                   3    [1 5]        idle-read=NOT-EMPTY    [1 5]        idle-read=NOT-EMPTY    = unchanged
p78-draft-rule-below-cursor-line.txt       2    [1 3]        idle-read=NOT-EMPTY    [1 5]        idle-read=NOT-EMPTY    ~ 仅几何变化
p78-draft-rule-below-cursor.txt            2    [1 3]        idle-read=EMPTY        [1 5]        idle-read=NOT-EMPTY    ↑ EMPTY→BUSY（允许）
p78-draft-rule-blank-region.txt            2    [1 3]        idle-read=EMPTY        [1 5]        idle-read=NOT-EMPTY    ↑ EMPTY→BUSY（允许）
p78-draft-rule-only.txt                    2    [1 3]        idle-read=EMPTY        [1 4]        idle-read=NOT-EMPTY    ↑ EMPTY→BUSY（允许）
p78-spinner-row-below-cursor.txt           2    [1 5]        idle-read=NOT-EMPTY    [1 5]        idle-read=NOT-EMPTY    = unchanged
p78-wider-rule-below-cursor.txt            2    [1 5]        idle-read=NOT-EMPTY    [1 5]        idle-read=NOT-EMPTY    = unchanged
pi-0.85.1-update-banner.txt                26   [24 29]      idle-read=EMPTY        [24 29]      idle-read=EMPTY        = unchanged
pi-0.87.0-draft-half-sentence.txt          26   [25 27]      idle-read=NOT-EMPTY    [25 27]      idle-read=NOT-EMPTY    = unchanged
pi-0.87.0-empty-box.txt                    26   [25 27]      idle-read=EMPTY        [25 27]      idle-read=EMPTY        = unchanged
pi-0.87.0-one-line-draft.txt               26   [25 27]      idle-read=NOT-EMPTY    [25 27]      idle-read=NOT-EMPTY    = unchanged
pi-0.87.0-project-trust-prompt.txt         16   []           overlay=trust-prompt   []           overlay=trust-prompt   = unchanged
ok    20.1 逐帧对比的语料 = 全部 13 份已存帧（不是抽样）
ok    20.2 硬性单调性：没有任何帧从非 EMPTY 翻成 EMPTY          ← brief 写死的那条
ok    20.3 没有意外方向（overlay/UNKNOWN 等都没被这条判据动到）
ok    20.3b 每帧都被归类（不变 8 / EMPTY→BUSY 4 / 仅几何 1 / 违规 0）
ok    20.3c 允许方向的变化恰好是任务书/场景点名的 4 帧
ok    20.3d 仅几何变化恰好 1 帧（draft-rule-below-cursor-line）
```

真帧（brief 5）逐帧逐字对比：5/5 `= 逐字相同`，且 `20.4c` 用 `cmp` 证明 5 份真帧的**字节**与 P80 之前完全一致（apply 没改实拍帧）；绝对值 `[25 27] NOT-EMPTY` / `[25 27] EMPTY` / `[24 29] EMPTY` / `overlay=trust-prompt`（`20.5a–e` 全 ok）。我自造的 10 份本征帧同一扫描也 0 违规（`20.6`）。

### 2.3 代价边界（brief 3）

我用自己造的**代价帧**（不是它存的 `p78-conversation-rule-below-box`）测两个变体：

```
⑥a 空框正下方紧贴一条 rule       new [1 4] NOT-EMPTY rc=1      old [1 3] EMPTY rc=0
⑥b 空框下方先文字、再一条 rule   new [1 5] NOT-EMPTY rc=1      old [1 3] EMPTY rc=0（框把 conversation text 圈进来）
⑥c 它存的代价帧                  new [1 4] NOT-EMPTY rc=1      old [1 3] EMPTY rc=0
⑥d 自造 10 帧在新判据下判 EMPTY 的数量 = 0（只往忙的方向动）
⑥e sha256(p78-draft-rule-only.txt) = e463c80cddc00efb84456a93b151536cd2683da923a789a5381baacb4f5053a6
     = 规格/README 里写的值（「草稿只有一条 rule」与「空框正下方紧贴一条 rule」同一串字节）
     troubleshooting §3 含镜像代价段、§3 的同类洞清单仍列 whitespace-only 与 status-row clone
⑥f tests/frames/README.md 的 8 份 p78 帧都标着「合成帧」，真帧未被标成合成
```

### 2.4 一处实现（brief 4）

```
ok    40.1  tests/** 里没有第二份 _team_box_geometry 定义（几何只有一处）
ok    40.1b tests/** 里没有第二份候选循环（for (k=）
ok    40.1c outbox.sh 里候选顺序决策恰好定义一处
ok    40.1d 几何里向它要顺序的调用恰好一处
ok    40.2  tests 里的顺序函数影子恰好一处（红侧，不是第二实现）
ok    40.2b 门禁 12b-h0d 里有 11 条 P80 红侧断言（影子路径真的被断言，不是摆设）
ok    40.3a 逐帧对比的语料 = 13 已存 + 10 自造 + 3 反例 = 26
ok    40.3b 生产状态与夹具判定逐帧同结论（EMPTY↔EMPTY，NOT-EMPTY↔BUSY/UNKNOWN）
ok    40.3c 生产框文本与夹具框文本逐帧逐字相同
ok    40.4  影子（升序=最近优先）与真旧树逐帧逐字相同
      production new:    BUSY
      production shadow: EMPTY
ok    40.5a 生产路径（绿）读 BUSY
ok    40.5b 生产路径吃影子（红）读 EMPTY —— 决策点确实是共用的那一个
```

同源的做法比 apply 的门禁更强一档：生产侧走的是**真 `team_input_box_text`/`team_input_box_state`**，只把 `tmux` 换成 PATH 上的假 tmux（`display-message cursor_y` / `capture-pane` 由帧供给）；夹具侧走 `team_box_frame_verdict`。26 帧（13 已存 + 10 自造 + 3 反例）两路的 `EMPTY`/`NOT-EMPTY`/`overlay` 与框文本逐字一致。影子只覆盖那一个顺序函数，而它在**生产进程**里同样把攻击帧读成 `EMPTY`（40.5），说明影子不是夹具侧的假象。

### 2.5 零回归与矩阵（brief 6 的一部分）

守卫矩阵（`pkg/70`，旧树 vs 实现树各跑一次，我自己的 diff）：

```
ok 70.1 新树矩阵 rc=0       ok 70.2 旧树矩阵 rc=0
ok 70.3 新树矩阵断言数（19 状态 + 12 holds）= 31       ok 70.4 旧树 = 31
ok 70.5 19 状态行 + 12 holds_only 行在新旧两棵树上逐字相同（没有 BUSY→EMPTY 的状态漂移）
```

门禁见 §五。

## 三、Flip evidence（三条变异，红→绿原始输出；全部在 `$P84_TMP` scratch 副本上）

```
-- 变异 A：把唯一的顺序决策改回「最近优先」（升序）--
ok    变异A：补丁只在 scratch 副本上（/tmp/p84pkg.*/mut-mutA/skills/teamsmith）
      红（变异树）: geometry=[1 3] box_nows=[] verdict=idle-read=EMPTY rc=0
      绿（原  树）: geometry=[1 5] box_nows=[────(80)…drafttextbelowmyownrule] verdict=idle-read=NOT-EMPTY rc=1
ok    变异A 红：同族帧退回最近候选 [1 3] EMPTY rc=0
ok    变异A 绿（未变异原树）：[1 5] NOT-EMPTY rc=1
ok    变异A：红侧数值与真旧树逐字一致（说明断言咬的正是这条判据）

-- 变异 B：让下边框候选包含光标行自身（i=cy 而不是 cy+1）--
      红（变异树）: geometry=[1 2] box_nows=[] verdict=idle-read=NOT-EMPTY rc=1
      绿（原  树）: geometry=[]     box_nows=[] verdict=idle-read=NOT-EMPTY rc=1
ok    变异B 红：光标行成了候选 → 几何 [1 2]（原树为空）
ok    变异B 绿（未变异原树）：严格下方无合格候选 → 几何为空
ok    变异B 对照：有真下边框时两个版本的几何相同（[1 3]，说明红值确实来自光标行）

-- 变异 C：只把夹具判定改成旧几何（box-judge.sh 内嵌旧实现）→ 同源断言必红 --
      红 夹具（变异）: geometry=[1 3] box_nows=[] verdict=idle-read=EMPTY rc=0 | 生产（未变异）: BUSY
      绿 夹具（原树）: geometry=[1 5] … verdict=idle-read=NOT-EMPTY rc=1                | 生产（原树）  : BUSY
ok    变异C 红：夹具判定与生产提取分叉（夹具 EMPTY vs 生产 BUSY）→ 40.3b 式断言在这种情况下必红
ok    变异C 绿（未变异原树）：两路一致（夹具 NOT-EMPTY vs 生产 BUSY）

-- 还原：所有变异都只发生在 scratch 副本；实现树从未被写入 --
ok    60.Z1 实现树 skills/teamsmith + openspec 的 git 工作区干净
ok    60.Z2 实现树相对 HEAD 的 diff 为空
ok    60.Z3 原树在同一攻击帧上仍然是绿值（变异没有渗进实现树）
```

变异 A 用文件级补丁（`_team_box_bottom_candidate_order` 的 awk 换成 `cat`），不是 in-process 影子；B 改的是候选循环下界；C 只在 scratch 的 `tests/lib/box-judge.sh` 里内嵌旧几何（生产树不动）。三条都红在预期的断言上、绿在原树上，且 `git status`/`git diff` 为空。

## 四、隔离与安全（本包自己）

- **不开真 tmux、不动任何 session**：生产路径的 `tmux` 是 PATH 最前面的假脚本（`cursor_y`/`capture-pane`/`pane_id` 由帧供给），并且 `env -u TMUX -u TMUX_PANE`；本包从不调用 `kill-server`/`kill-window`，不使用任何真实 session 名。
- **身份卫生**：`lib.sh` 载入时 `unset` 全部 `TEAM_*` 身份变量（memory #1017 的同族做法）。
- **实现树只读**：三条变异都在 `mktemp -d` 下的整棵副本上（`$P84_TMP/mut-*/`）；`60.Z1/Z2` 断言 `git status --porcelain -- skills/teamsmith openspec` 与 `git diff --stat` 为空。旧树由 `git archive` 取出，不改仓库。
- **无残留**：跑完 `pgrep -f 'p84pkg|p84prod'` = 空；探针的临时目录有 EXIT trap（带 `BASHPID` 守卫，memory #1053 的教训）。
- 帧工具（`p84_rule`/`p84_spin`）与探针里的正则全部自行编写，没有 source 门禁里的同名 helper。

## 五、门禁

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/bottom-border-candidate-selection … ✓ spec/watchdog
Totals: 30 passed, 0 failed (30 items)
OPENSPEC_RC=0                                        # logs/full-gate.log

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2550  ✗ 0
FAST 模式：跳过 33 个真进程段落（… 44·P80-真pane）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿                                            # logs/fast-smoke.log（含 12b-h0d 的 P80 段）

$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
== $(date -Is) openspec validate --all --strict =
… Totals: 30 passed, 0 failed (30 items)
OPENSPEC_RC=0
== $(date -Is) bash skills/teamsmith/tests/smoke.sh (full) ==
另一套全量 smoke 正在跑（… pid=180802 cmd=smoke.sh）；本套排队，最多等 5400s（TEAM_SMOKE_NO_LOCK=1 可跳过排队）
轮到本套了（排过队）
…
== 44 · P80 输入框判据：草稿自己的下边框框线（真 pane 就绪门 + 生产路径只排队） ==
  ✓ P80 就绪门：面对「草稿自带下边框框线」的 pane 拒绝放行（rc=1≠0）
  ✓ P80 就绪门：拒绝时最后判定点名 idle-read=NOT-EMPTY
  ✓ P80 就绪门：拒绝后一步投递都没跑
  ✓ P80 就绪门：keylog 零行（一个键都没敲进人的草稿）
  ✓ P80 生产路径：team_input_box_state 报 BUSY（不是 EMPTY）
  ✓ P80 生产路径：攻击草稿在场 → team say 报 queued（不是已送达）
  ✓ P80 生产路径：say/draft send 一个键都没敲（keylog 仍 0 行）
== 结果 ==  ✓ 3216  ✗ 0
smoke 全绿
SMOKE_RC=0 ; FULL_RC=0                              # logs/full-gate.log（本条包含 44·P80-真pane）
```

三个门禁的完整 tail 在 `logs/`：`full-gate.log`（openspec + 全量）、`fast-smoke.log`（FAST，含 12b-h0d 的 P80 段）、`matrix-{old,new}.log`（守卫矩阵）。

包证据：`bash docs/team/reports/P84-dev/pkg/run.sh` → `== run 结果 == ✓130 ✗0 · findings=3`（exit 0）。三个 finding 就是 §六 的 F1 家族，不是脚本失败。

## 六、发现与归属

### F1 · 「框只会变大」不成立于混宽度帧：更低的自配对框让判定 BUSY→EMPTY（**本 change 引入**，危险方向）

delta 的 requirement 写：

> relative to the nearest-candidate rule the located box can only grow (the bottom border can only
> move down, and a lower candidate's top-border search can only reach the same or a higher row), so a
> frame that read `EMPTY` under the old rule can only read busy under this one — **no frame's verdict
> may move from BUSY to `EMPTY`**.

design §3「Monotone direction」同句。**这句话对混宽度帧是假的**：下边框取了更低的候选，但它的
上边框搜索的**宽度不同**，最高合格行可能落在**光标框的上边框之下**，于是新框与旧框**不相交** ——
不是变大，而是换了一个框，还可能不含光标行。

复现形状（我自造，`pkg/50`；rule 宽度集合 = 300 字节(100 字符) 与 360 字节(120 字符) 两种）：

```
row1 ────────(100)              光标所在框的上边框
row2  HUMAN DRAFT LINE          ← 光标行 cy=2（人的草稿）
row3 ────────(100)              光标所在框的下边框
row4 （空）
row5 ────────(120)              下方另一对 rule 的上边框（宽度不同，自成一对）
row6 （空）
row7 ────────(120)              下方另一对 rule 的下边框
row8  footer
```

原始输出（`logs/pkg-50.log`；三份变体：等宽对 / spinner 作上边框 / 更窄的对）：

```
F1.1 f1-mixed-width-disjoint-box.txt  （rule 行宽度集合: 300 360）
      old tree : geometry=[1 3] idle-read=NOT-EMPTY rc=1   production=BUSY
      new rule : geometry=[5 7] idle-read=EMPTY      rc=0   production=EMPTY
      shadow   : geometry=[1 3] idle-read=NOT-EMPTY rc=1
! find F1.1 新判据把框定位到光标**下方**、与光标框不相交的更低框 [5 7]（不同宽度自成一对），判
       EMPTY rc=0；生产路径 EMPTY —— 需求/design §3 的『框只会变大』不成立于混宽度帧，这是危险
       方向（就地投递会打进 HUMAN DRAFT LINE）
ok    F1.1 生产路径同步翻转：旧树 BUSY → 新树 EMPTY
ok    F1.1 定位框的下边框 7 在光标行 2 之下，且上边框 5 > 2 → 该框不含光标
（F1.2 spinner-top、F1.3 narrower-box 完全相同）
```

- **归属**：本 change **引入**。旧树在这三帧判 BUSY（框 `[1 3]` 含草稿），新判据判 EMPTY；这不是
  P80 之前就有的洞。
- **后果**：`team_input_box_state`/`team_delivery_verdict` = EMPTY → 就绪门放行 → payload 按光标就地
  打字，落在 `HUMAN DRAFT LINE` 上（D20 损害）。方向是危险侧。
- **可达性（区分清楚）**：
  - **实测布局不可达**：五份真帧里 rule 行的宽度集合**只有一种**（`pkg/50` 50.2b），最低整行 rule 就是
    框自己的下边框（apply 门禁里的 `P80 结构` 断言同结论）。
  - **已存合成语料也没触发**：`p78-wider-rule-below-cursor.txt` 有 360/420 两种宽度，但更宽的那条
    **不成对**；没有一份已存帧有「光标框之外、自成一对的第二对 rule 行」。所以 20.2 的硬性单调性
    断言（13 份已存帧）不覆盖这个形状 —— **断言是真的、只是语料不含这个反例**。
  - **本 change 自己的建模宇宙里可达**：change 的合成帧就是「裁切型 TUI / 混宽度」模型（`p78-wider`
    140 vs 120）。同一宇宙里，光标框一个宽度、下方另有一对同宽 rule 行（例如对话区/代码块的
    `─` 框线对，中间夹一个空行）就命中 F1。
- **说明**：如果有人认为 f1 里「下方那对 rule 才是真框、上方是对话里的框」，那么新判据的读法是"对"的 ——
  但这仍然没有救 requirement 的那句话：判据从「光标框 BUSY」变成「另一个框 EMPTY」，照样是
  BUSY→EMPTY，而**代价清单里只写了「框变大 → 忙」**，没写「可能换框 → 空」。也就是说，要么实现补
  一条约束，要么规格文字必须收窄并把这条反向行为列为代价。**两条路都需要 PM 裁定**（见 §八）。
- **实测的修复路径（§80，scratch，未实施）**：给「最低优先」补一条**嵌套约束** —— 被选中的下边框候选，
  其配到的上边框不得低于「最近的合格候选」的上边框（于是新框必是旧框的超集，单调性成立）。实测：
  - 三份反例帧全部回到 `[1 3] NOT-EMPTY`（BUSY，不再 EMPTY）；
  - 13 已存帧 + 10 自造帧**逐字不变**（23/23）；
  - 26 帧（含反例）的旧树→修复树扫描 0 个 BUSY→EMPTY。
  补丁形式（`local … near_top _oline` + 从 `ordered` 里挑第一个 `top ≤ near_top` 的行）见
  `pkg/80-candidate-fix.sh`。

### 其余观察（不是缺陷，仅记录）

- 门禁的单调性断言（12b-h0d）用**同一语料**（13 帧）做红/绿两侧对比，措辞是「红侧判忙的帧在绿侧
  没有一个翻成 EMPTY」。它是对的；F1 只是说明「语料外还有形状」。若 PM 决定返工，建议把反例形状
  也做成 scenario + 门禁帧，让这条断言覆盖到混宽度。
- **门禁的两条隐含断言**（小，仅记录）：delta 场景 4（spinner）与 5（光标在草稿中间）都写了
  「verdict 是 `idle-read=NOT-EMPTY`（rc 1）」这一 AND 子句，但 12b-h0d 对这两帧只直接断言了
  `geometry`/框文本（`smoke.sh` 对照③只断言 `geometry=[1 5]`+`Blanching`，对照⑤只断言
  `box_nows=[draftline1draftline2draftline3]`）。该子句由「框文本非空 ⇒ 判定 NOT-EMPTY」的判据隐含，
  我的 §10（③/⑤ 直接断言 `verdict=idle-read=NOT-EMPTY rc=1`）也独立覆盖了它；但若要求「每条场景
  的每个子句都有可直接失败的断言」，这两条可以各补一行 `assert_has_echo … "verdict=idle-read=NOT-EMPTY rc=1"`。
- `p78-draft-rule-below-cursor-line.txt` 在新判据下只是「仅几何变化」（判定本来就 NOT-EMPTY，
  `holds_only` 变安全侧），没有回归。

## 七、决策与偏差

- **旧序一侧用真旧树**：brief 第 2 项说「旧顺序（最近优先）vs 新顺序」。我没有只依赖 apply 定义的
  in-process 影子，而是用 `git archive df284000`（P80 apply 的父提交）取真旧树当红侧基线；影子与真旧树
  在 26 帧上逐字相同（§2.4 40.4），两条路互为交叉验证。
- **自造帧**：brief 第 1 项要求「自己造帧，不要只用它存的八份」。我造了 13 份（①–⑤ + ①b + ⑦ + 两条代价 +
  三份反例），宽度、文字、footer 都与已存帧不同；已存 8 份只在 §2.2/§2.5 作语料对照。
- **变异在 scratch**：brief 要求三条变异全部在 scratch 副本上红→绿；A/B/C 之外我额外用 §80 在 scratch
  上测了一条**候选修复**（不是变异，是给 PM 的可行性证据）——它同样没碰实现树。
- **未执行**：本报告不跑真 pane 段（44·P80-真pane）—— FAST 会跳过它，全量门禁负责（§五）；brief 的六项
  不要求它，且 §2.4 的生产路径探针已在假 tmux 上覆盖同一条判据链。
- **范围**：只写 `docs/team/reports/P84-dev{,.md}/**`；没有改任何实现文件（`60.Z1/Z2` + `git status`）。
  local 模式：不 push，分支留在 `.worktrees/dev`。

## 八、建议下一步（给 PM）

1. **裁定 F1**（一条决定，二选一）：
   - **返工 P80**（推荐）：把 §80 的嵌套约束加进 `_team_box_geometry`（或等价写法），加一个反例
     scenario + 门禁帧（混宽度、光标框外自配对的一对 rule），门禁的单调性断言也覆盖它。我已实测这条
     约束不改任何现有帧的判定。
   - **收窄文字**：如果认为混宽度第二对 rule 属于「未知形状、按今天的行为投递（一行警告）」，那也必须
     改 requirement/design 的措辞（「框只会变大」→「同一宽度族内框只会变大」）并把它写进
     `troubleshooting.md` §3 的代价清单（现在只写了「框变大 → 忙」）—— 但这留下一个已知可达的粘连形状，
     与 change 的初衷相反，我不推荐。
2. **归档顺序**：delta 是 `## ADDED Requirements`，我没有改动 base spec（`openspec/specs/**` 在 P80 的
   diff 之外，`git status` 干净），所以与 `one-line-draft-judgement` 的归档顺序无关（design §4 的论证
   在树上成立）；archive 仍需用户确认（memory #1141）。
3. 若 PM 决定返工，请把 F1 的形状直接写进返工 brief 的验收（现在的 brief 字面只要求「已存帧」单调，
   返工 brief 要加「混宽度反例帧」这一条），否则同样的洞会在下一轮复验里再出现。
