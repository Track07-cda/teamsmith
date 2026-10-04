# P63 · 单行草稿被读成空框（Pi 0.87 布局）· **propose 阶段** · dev3

agent: dev3   status: **DONE（propose：一个提案包，不写实现）**
time: 2026-09-22T16:10Z（两条 smoke 门禁跨到此时：全量排队 27 分钟 + 跑 42 分钟）
branch: `task/P63-propose`（local 模式：**不 push**，分支留给 PM）
change: `one-line-draft-judgement`（`phase: propose`，propose = P63 dev3；apply 另行派单）
deltas: `delivery-guard`（MODIFIED ×1，追加 5 条 scenario）、`notify-and-inbox`（MODIFIED ×1，追加 1 条 scenario）
证据包: `docs/team/reports/P63-dev3/`（`repro.sh` / `fixture-impact.sh` 可重跑，`logs/` 是原始输出）

**总结论**：提案包四件套（proposal / design / tasks / 两个 delta spec）已落盘，`openspec` 校验绿（change 单体
`--strict` 绿、全库 `--all --strict` 25/25）。判据的裁决是 **D：光标优先、状态行形状只作降级信号** ——
`OFFSET==1` 那一行只有在「光标不在其上 **且** 文本匹配实测的状态行形状」时才当 chrome 排除，其余一律是内容；
0.85.1 与 0.87.0 两版真帧都通过（本树实测的基线在 §2）。F2 **本 change 不修**（理由与后续归属在 §4）。
提案里没有代码改动。两条 smoke 门禁唯一的红是**既有** F3 lint（`container-tmux.sh:159/215`，与改动前基线逐字
相同，P61 已裁定为单独的小收尾），本单没有引入新红（§5）。

## 1 · 交付物

```
openspec/changes/one-line-draft-judgement/proposal.md        为什么 / 改什么 / 翻转 / 边界 / 验收 / 报告证据
openspec/changes/one-line-draft-judgement/design.md          实测现场 / 规则选型（A–E 对照）/ 同源 / F2 裁决 / 红绿计划 / 残余
openspec/changes/one-line-draft-judgement/tasks.md           一个 apply 单（B1–B3），逐项带 Verify 命令 + 路径授权
openspec/changes/one-line-draft-judgement/specs/delivery-guard/spec.md   MODIFIED：判据语义 + 单一实现（+5 scenario）
openspec/changes/one-line-draft-judgement/specs/notify-and-inbox/spec.md MODIFIED：单行草稿必须排队（+1 scenario）
```

`openspec status --change one-line-draft-judgement` → `Progress: 4/4 artifacts complete`；
`openspec validate one-line-draft-judgement --type change --strict` → `Change 'one-line-draft-judgement' is valid`。

## 2 · 事实与实测（红侧基线，**本树当前实现**）

P61 的 F1 现场（`docs/team/reports/P61-dev3/logs/`）用**未改动的本树**重跑，逐字如下（完整原文
`logs/10-baseline.txt`，可重跑脚本 `repro.sh`）：

```
--- 0.87.0 单行草稿（P61 15b，真 pane 实拍）
frame=docs/team/reports/P61-dev3/logs/15b-one-line-draft-frame.log cy=26
  geometry=[25 27]  rows=[1|HUMAN-ONE-LINE-DRAFT|26 ]  box_text=[|]  frame_verdict=[idle-read=EMPTY]
--- 0.87.0 单行草稿（P61 10c，DRAFT-p61-half-sentence）
  geometry=[25 27]  rows=[1|DRAFT-p61-half-sentence|26 ]  box_text=[|]  frame_verdict=[idle-read=EMPTY]
--- 0.87.0 空闲空框（对照）
  geometry=[25 27]  rows=[1||26 ]  box_text=[|]  frame_verdict=[idle-read=EMPTY]
--- 0.85.1 空闲空框（状态行在框内 OFFSET==1）
  geometry=[24 29]  rows=[4||25 3||26 2||27 1| deepseek-flash  Deepseek  max|28]  box_text=[|]  frame_verdict=[idle-read=EMPTY]
```

- 0.87.0 的框是「上边框 / 内容行 / 下边框」，状态行在框**外**；单行草稿就落在 `OFFSET==1`，被位置排除 →
  `EMPTY`。0.87.0 的空框与单行草稿帧几何**完全相同**（`[25 27]`、只有第 26 行一个内容行），差别只有那一行有没有字。
- 0.85.1 的框内最后一行是框自带状态行（` deepseek-flash  Deepseek  max`，同一形状在 E3 夹具里是
  ` k3  Kimi Coding  max`）——排除它是对的，所以判据不能只是「不要排除」。
- 后果两条都有现场（引用 P61）：① 就绪门带着人的单行草稿放行并投递（`15d`：夹具 `rc=0`、
  `M45 idle-read=EMPTY ok`、keylog 收到 1 行输入）；② 生产路径 `team_delivery_verdict` 同判 `EMPTY`、
  `team_box_holds_only` 返回空框语义（payload 会被贴进人的草稿）。多行草稿不受影响（`15c`：`BUSY`）。
- 光标行敏感度：0.85.1 帧在 cy=25/26/27/28 下当前都读空；0.87.0 草稿帧在 cy=26（草稿行本身）读空。

## 3 · 设计裁决（brief 的五个问题）

1. **判据改成结构优先、形状降级（D）**。规则：框内逐行 —— 空行不算内容；**光标所在行一律是内容**；
   `OFFSET==1` 且匹配实测状态行形状 → chrome 排除；其余一律内容。A（今天的按位置排除）就是缺陷；
   B（只看形状）会把「正在编辑的、形状像状态行的草稿」吞掉；C（纯结构：仅一行非空且光标不在其上）在
   V7-F1 的 0.87.0 形状（空行光标 + 唯一文本行恰在 `OFFSET==1`）上仍然漏判 —— C 与 0.85.1 空框的帧**只差
   那一行的文本**，所以文本信号无法完全避开，只能降级成第二信号。E（完全不排除）会让 0.85.1 的空框永远
   BUSY（投递全排队）。两版真帧都通过：0.87.0 两张草稿帧 → 内容/BUSY，0.87.0 空框 → EMPTY，
   0.85.1 状态行帧 → EMPTY。**方向**：排除集合严格变小（旧规则排除每一行 `OFFSET==1`），只会多认出草稿，
   不会少认 —— 所以没有放宽 M24/M30 的红线。
2. **两处判据同源**。单一实现进 `outbox.sh`（纯函数 `_team_box_text_of_frame <cy>` + 一个可覆盖的
   边框邻行判定 `_team_box_row_is_chrome`），`team_input_box_text`、`box-judge.sh` 的帧级判定、门禁的帧探针
   全部调它；红侧不需要产品开关 —— 测试进程里把谓词 shadow 成「永远 chrome」就逐字复刻旧行为。
   唯一例外写进 design：`flip-m45.sh` 的跨树探针要读**修复前**的树，保留它自己的提取（并注明它不是本判据的证据）。
3. **红/绿帧**。红侧用 `15b`/`15d` 的现场存成真帧（`tests/frames/pi-0.87.0-*.txt`）做纯帧断言：
   单行草稿 → 非空文本 / `NOT-EMPTY`（`HOLDS_ONLY=no` 对外来 payload、`yes` 对我们自己的）；绿侧：0.87.0
   空框仍 `EMPTY`、0.85.1 帧仍 `EMPTY`、多行草稿仍 `BUSY`；就绪门在单行草稿的 pane 上**不放行**（夹具 `rc≠0`、
   零按键、无 `deliver_text_lines=`）。红/绿两个方向都进 FAST 的纯帧段，翻转用 shadow 谓词证明。
4. **F2 裁决：本 change 不修，记理由 + 点名后续归属**。倾向的「位置/结构优先」已经落在**本 change 的判据**上；
   覆盖层谓词（`team_box_overlay_kind`）本身不动，因为它是 `trust-prompt-and-fixtures`（未归档）在
   `verification` capability 里的承诺（30/30 光标行扫描是它的证据），把它改成结构优先要定义「贴着 pane 底部
   的真输入框」并重做那份证据 —— 那是另一个 `verification` change，不在本单 `deltas:`（`delivery-guard` +
   `notify-and-inbox`）里。方向无害：夹具遇这个名字会停止投递（不往草稿打字），生产守卫根本不看覆盖层谓词；
   本 change 也没有新增文本吞噬（见第 1 条的「排除集合严格变小」）。后续形状已写进 design §5（含两条红侧帧）。
5. **红线不动**。新规则只减少排除；设计里明写 apply 不得把判据退化成「有字就 BUSY」，不得碰 M45 几何/横幅、
   V8/V9 的折叠与前缀窗口、`team_box_mid_render`、收回键序、覆盖层谓词。

## 4 · 影响面（apply 必须按这个清单动夹具，实测）

新规则会把现有合成帧的状态行 ` fake-pi 1.0` 读成**内容**（它不匹配实测形状），空框夹具会因此变红 ——
这不是判据的错，是夹具画的不是真 pi 的形状。实测（`logs/20-fixture-impact.txt`、`logs/22-fake-tui-impact.txt`，
可重跑 `fixture-impact.sh`）：

```
banner-empty.txt       legacy_box_nows=[]                         new=[ fake-pi1.0]        ← M45 断言 box_nows=[]
banner-draft.txt       legacy=[半句草稿halfasentence]              new=[…fake-pi1.0]        ← M45 断言
draft-like-block.txt   legacy=[…UpdateAvailable…]                  new=[…fake-pi1.0]        ← 子串断言，不受影响
draft-top.txt          legacy=[UpdateAvailable…Runpiupdate]         new=[…RunpiupdateChangelog:https://x]  ← 期望串按帧真实内容加长
no-banner.txt          legacy=[halfsentence]                       new=[halfsentencefake-pi1.0]
m59-empty-box.txt      legacy=[]                                   new=[fake-pi1.0]         ← M59 rc=0 对照
m59-draft-box.txt      legacy=[halfsentence]                       new=[halfsentencefake-pi1.0]
live fake-tui 空框      legacy=[]                                   new=[fake-pi1.0]         ← 12b-h 的投递用例
```

`tests/fake-tui.py:243`、`smoke.sh` §12b-h0b / §12b-h0c 的合成帧、`flip-m45.sh` 的对抗帧都要改成实测形状
（例如 ` fake-pi  Fake Pi  max`）或 0.87.0 的框形；改完这些断言**逐条不变**地绿。`draft-top.txt` 是唯一一条
期望串要加长的：它定位到的框是 `[1 5]`，`OFFSET==1` 是它自己那行 ` Changelog: https://x`（真内容）。
`tasks.md` 的 fixture note 与 2.2 已写死这张清单；**不许删/弱化任何断言**。

## 5 · 验收

```sh
$ PATH="$HOME/.bun/bin:$PATH" openspec validate one-line-draft-judgement --type change --strict
Change 'one-line-draft-judgement' is valid                                   # rc=0

$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/one-line-draft-judgement … ✓ change/trust-prompt-and-fixtures …
Totals: 25 passed, 0 failed (25 items)                                       # rc=0（logs/30-openspec-all.log）

$ bash docs/team/reports/P63-dev3/repro.sh            # 红侧基线（本树未改动）
  → 两张 0.87.0 单行草稿帧：box_text=[] / idle-read=EMPTY；0.85.1 帧：EMPTY        （logs/10-baseline.txt）
$ bash docs/team/reports/P63-dev3/fixture-impact.sh   # 夹具影响面（模拟新规则）      （logs/20-…）
```

两条 smoke 门禁（`logs/40-fast-gate.txt` / `logs/41-full-gate.txt`）：

```sh
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
✗ 40 lint 有 finding（rc=1）：tests/container-tmux.sh:159/215 fpcheck*.XXXXXX 名字不在 owned 家族
== 结果 ==  ✓ 2367  ✗ 1                                                     # rc=1 —— 唯一红是既有 F3

$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2898  ✗ 1                                                     # rc=1 —— 唯一红同样是 F3
```

**唯一红是既有 finding，不是本单引入**：同一 worktree 里改动前的 P61 全量日志
（`.pi/team/state/bg/p61-full-smoke.log`）是逐字相同的 `✓ 2898 ✗ 1` + 同一个 `container-tmux.sh:159/215`
lint 红（P61 的 F3，PM 已裁定为单独的小收尾任务）；本单只改 `openspec/**` 与 `docs/team/reports/**`，没有代码/
夹具改动，所以计数与基线一致。全量门禁在锁上排了约 27 分钟（同时有三套全量在排队），实际跑 42 分钟。

## 6 · 给 apply / verify 的交接

- **apply**：按 `tasks.md` 的 B1→B2→B3 走；路径授权要写进任务书：`skills/teamsmith/scripts/lib/outbox.sh`、
  `skills/teamsmith/tests/**`（含 `tests/frames/**`）、`skills/teamsmith/references/troubleshooting.md`。
  红侧现场用 P61 的 `15b`/`10c` 帧（先 `cmp` 逐字节，别手抄）；就绪门那条要真 tmux pane，放非 FAST 段。
- **verify**：独立复验要核（a）两张草稿帧与 0.85.1 帧的三份读数（纯帧）、（b）shadow 谓词的翻转、
  （c）就绪门拒绝（`rc≠0` + 零按键）、（d）多行草稿仍 `BUSY`、（e）M45/M59/guard-matrix 没有靠弱化断言变绿、
  （f）`troubleshooting.md` §3 的残余清单与 spec 文案一致。
- **残余（写进 spec 的同类清单，不假装没有）**：状态行克隆（唯一一行恰好是形状克隆且光标停在别处）仍是空框；
  未来 Pi 改状态行拼法 → 读成内容 → 保守 BUSY；纯空白草稿仍是有记录的洞。

## 7 · 门禁

见 §5：`openspec validate --all --strict` 25/25 绿；FAST `✓2367 ✗1`；全量 `✓2898 ✗1`。两条 smoke 的
唯一红都是同一个**既有** F3 lint（`tests/container-tmux.sh:159/215`），与改动前 P61 的基线逐字相同；
本单没有引入新红。原始尾部在 `logs/40-fast-gate.txt`、`logs/41-full-gate.txt`，完整日志在
`.pi/team/state/bg/p63-{fast,full}-gate.log`。

---

**备注**：本单 **propose only**（brief：「本单先只做 propose」）；没有实现改动，没有 push（local 模式）。
`docs/team/tasks/P63-one-line-draft-apply.md` 是 PM 的只读文件，未改动。
