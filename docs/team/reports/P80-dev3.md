# P80 · `bottom-border-candidate-selection`：下边框取「最低的合格规则行」· **apply** · dev3

agent: dev3   status: **DONE**
time: 2026-09-23（全套门禁口径）
branch: `task/P80-apply`（local 模式：**不 push**，分支留给 PM）
change: `bottom-border-candidate-selection` ｜ specs: `delivery-guard#The bottom border is the lowest qualifying rule row below the cursor` ｜ phase: apply ｜ deltas: `delivery-guard`
grant 内改动: `skills/teamsmith/scripts/lib/outbox.sh`（判定 + 一处决策点）· 新增
`skills/teamsmith/tests/frames/p78-*.txt`（8 份）与 `tests/frames/README.md` 行 · `skills/teamsmith/tests/smoke.sh`
（新增 §12b-h0d 与 §44；另有**一处既有断言**因新规则的必然后果更新，见 §8 的 F1） ·
`skills/teamsmith/references/troubleshooting.md` §3 一段
grant 提到但**不需要动**: `tests/lib/box-judge.sh` 与 `tests/pm-box-real.sh` —— 它们本来就调用同一份
生产判据（`_team_box_geometry` / `_team_box_text_of_frame` / `team_box_frame_verdict`），改动自动继承
证据包: `docs/team/reports/P80-dev3/`（`repro.sh` 可重跑；`logs/` 是原始输出）

**总结论**：下边框从「光标下方**最近**的合格整行 ─」改成「**最低的**合格整行 ─」（上边框 HIGHEST 的
镜像，design D1-B）。草稿自己在光标下方画的等宽框线现在落在框**内**算内容：框不再被截断，
`[1 3]`/`EMPTY` 变成 `[1 5]`/`NOT-EMPTY`，就绪门不放行、payload 不进人的草稿（§3 逐帧表）。
候选**尝试顺序**收在一个可影子的函数 `_team_box_bottom_candidate_order`（生产里没有开关）；测试进程
把它影子成升序（= 旧的最近优先）时，攻击帧逐字翻回旧值 —— 红侧在 FAST 门禁里常驻（§2、§3）。
方向单调：相对旧顺序框只会变大，所以任何帧都不许从 BUSY 翻成 EMPTY（13 份已存帧逐帧断言，§4）；
五份真帧与 guard-matrix 的 31 条 state/`holds_only` 行在改动前后**逐字相同**（§4）。代价（框下方
的整行 ─ 会把框撑大 → BUSY → 投递等待）写进 `references/troubleshooting.md` §3，附实测不可达与
「两种读法同一串字节」的 sha256（§5）。

**一处设计影响**（设计 §11 假设「既有断言不会变」，实测不成立）：M45 段一份**合成**对抗帧的框文本
随规则变长（几何 `[1 5]`→`[1 7]`，框自带的那条上边框 rule 行也落在框内成了内容），该断言按新值
**加长**（更强，不是放宽）。判定不变（BUSY），五份**真**帧不受影响。见 §8 F1。

## 1 · 交付物与 commits

```
skills/teamsmith/scripts/lib/outbox.sh               _team_box_bottom_candidate_order()（新的唯一决策点）+
                                                     _team_box_geometry() 改成「每个候选先配对、胜者由顺序函数定」
skills/teamsmith/tests/frames/p78-*.txt              8 份合成帧（与提案 pkg 的构造逐字节相同）
skills/teamsmith/tests/frames/README.md              8 行来源/形状/光标行 +「合成，不是实拍」段 + P80 小节
skills/teamsmith/tests/smoke.sh                      §12b-h0d（FAST，纯帧，83 条断言）+ §44（非 FAST，真 pane）
skills/teamsmith/references/troubleshooting.md       §3「框下方的整行 rule 会撑大框」代价段
docs/team/reports/P80-dev3/                          repro.sh + logs/（原始输出）
```

commits（小步，各带 `Agent: dev3` trailer）：

- `a9a7de90` — `P80: apply bottom-border-candidate-selection — the bottom border is the lowest qualifying rule row below the cursor`
  （实现 + M45 断言的必然后果更新；见 §8 F1）
- `1ea0dd1c` — `P80: store the eight synthetic p78 frames and their README rows`
- `98ba726e` — `P80: pin the frame-level judgement in the FAST gate, in both candidate orders`
- `488f64fc` — `P80: the real-pane face (section 44) and the documented mirror cost`
- `6b532d31` — 清理重复日志（`say-standalone.log` 是记录）
- `b4621ef0` — `P80: assert the monotonicity direction over every stored frame, and add the reproduce package`
- 报告提交（本文件 + 证据包）

## 2 · 判定与「一处实现」

`_team_box_geometry` 仍然对**每个**「光标行以下、整行 ─」的候选算出它配对的上边框（tier1 等宽整行 ─ /
tier2 spinner 形态；横幅块排除、两遍回退、严格在光标下方搜索一字未改），但**胜者不再由循环方向决定**：

```sh
# 唯一决策点（outbox.sh）
_team_box_bottom_candidate_order() {   # stdin：升序的「候选 上边框」对 → stdout：按尝试顺序
  LC_ALL=C awk '{ a[NR]=$0 } END { for (i=NR;i>=1;i--) print a[i] }'   # 最低优先（本变更）
}
# 几何里：ordered="$(_team_box_bottom_candidate_order <<< "$res")"; pick="${ordered%%$'\n'*}"
```

影子成 `cat`（保持升序）就是**逐字**的旧行为（旧代码就是升序取第一个配对的候选）；red side 因此
不需要复制一份几何实现，也不会与生产实现漂移。生产里**没有**环境开关（design D3）：有开关就等于
发布两种行为，而规格钉的是一种。

门禁的锚点（§12b-h0d 末尾）：

```sh
assert_eq "P80 一处实现：tests/** 里没有第二份几何/候选循环实现（影子只覆盖那一个顺序函数）" "${P80_REDEF:-none}" "none"
assert_eq "P80 一处实现：候选顺序决策在 outbox.sh 里定义恰一处" "$(grep -c '^_team_box_bottom_candidate_order() {' …)" "1"
assert_eq "P80 一处实现：几何里向它要顺序的调用恰一处" "$(grep -c 'ordered="\$(_team_box_bottom_candidate_order' …)" "1"
```

（`flip-m45.sh` 的跨树探针是 design §11 记录的**唯一**例外：它故意自己提行以解析修前的树。）

## 3 · 逐帧红/绿表（原始输出在 `logs/`）

`p80-frame-probe.sh`（§12b-h0d 写入 `$TMP`，与 gate 同源）：生产判据 + 帧级判定；`shadow=1` = 把
顺序函数影子成升序。`─×120`/`─×140` 是 rule 行的简写（原始字节在 `logs/`）。

| 帧 | cy | 绿 = 生产（最低优先） | 红 = 影子（旧的最近优先） |
|---|---|---|---|
| `p78-draft-rule-below-cursor.txt` | 2 | `geometry=[1 5]` box 含 `─×120` + `drafttextbelowmyownrule`，`NOT-EMPTY` rc=1 | `geometry=[1 3]` box `[]`，`EMPTY` rc=0 |
| `p78-draft-rule-only.txt` | 2 | `geometry=[1 4]` box 含 `─×120`，`NOT-EMPTY` rc=1 | `geometry=[1 3]` box `[]`，`EMPTY` rc=0 |
| `p78-wider-rule-below-cursor.txt` | 2 | `geometry=[1 5]` box 含 `─×140` + `drafttext`，`NOT-EMPTY` rc=1 | **逐字相同** |
| `p78-spinner-row-below-cursor.txt` | 2 | `geometry=[1 5]` box 含 `──⠋Blanching…0s…` + `drafttext`，`NOT-EMPTY` rc=1 | **逐字相同** |
| `p78-cursor-mid-draft.txt` | 3 | `geometry=[1 5]` box `draftline1draftline2draftline3` | **逐字相同** |
| `p78-conversation-rule-below-box.txt` | 2 | `geometry=[1 4]` box 含 `─×120`，`NOT-EMPTY` rc=1（**记录在案的代价**） | `geometry=[1 3]` box `[]`，`EMPTY` rc=0 |
| `p78-draft-rule-blank-region.txt` | 2 | `geometry=[1 5]` box 含 `─×120`，`NOT-EMPTY` rc=1 | `geometry=[1 3]` box `[]`，`EMPTY` rc=0 |
| `p78-draft-rule-below-cursor-line.txt`（payload=`half a sentence`） | 2 | box 含 `halfasentence` + `─×120` + `moredraft`，`holds_only=extra-text` | box `[halfasentence]`，`holds_only=only-ours`（P80 前的事故形状） |

五份**真**帧（`[25 27]`/`[25 27]`/`[25 27]`/`[24 29]`/无框 overlay）在两个方向**逐字相同**（§4）。

## 4 · 单调性、回归与同源

**单调性**（requirement 的方向承诺，§12b-h0d）：对全部 13 份已存帧逐帧对比红/绿两侧 ——
`assert_eq "P80 单调性：红侧判忙的帧在绿侧没有一个翻成 EMPTY（框只变大）" "${P80_MONO_BAD:-none}" "none"`
（对比帧数断言为 13）。几何层面的理由：胜者候选只会更低（`c_new ≥ c_old`）、它的上边框只会更高或不变
（搜索区间是超集），于是框的区间只扩不缩；`_team_box_text_of_frame` 只按内容排除（排除集不随几何变大
而变大），所以内容只增不减。

**guard-matrix 逐行相同**（`logs/matrix-{base,change}.log`；base = `aa234729` 的 `git archive` 树）：

```sh
$ diff <(sed 1d logs/matrix-base.log) <(sed 1d logs/matrix-change.log)     # 只差首行的 skill 路径
$ tail -n2 logs/matrix-base.log; tail -n2 logs/matrix-change.log
== 结果 ==  ✓ 31  ✗ 0
== 结果 ==  ✓ 31  ✗ 0
```

19 条 state 行 + 12 条 holds/中间帧行（H1–H12）逐字一致（含 9b 纯空白盲区与 12/13/14/15/16/17
草稿框线形状）——**没有任何判定从 BUSY 移到 EMPTY**。

**同源**（§12b-h0d）：13 份已存帧上，纯探针（生产提取 `_team_box_geometry` + `_team_box_text_of_frame`）
与 `pm-box-real.sh --frame`（共享判据 `team_box_frame_verdict`）的框文本、判定与 rc 逐字一致（26 条断言）。

**真帧结构**（`logs/` 的 probe 输出 + §12b-h0d）：五份真帧里 pane 最低的整行 ─ 就是框自己的下边框，
其下没有第二条整行 ─ —— 镜像代价在已测布局上不可达。

## 5 · 代价与「两种读法同一串字节」

`references/troubleshooting.md` §3 的 bullet *Rule-looking rows inside your own draft are not borders* 现在
写明：下边框 = **最低**的合格整行 ─（上边框仍是最高的），草稿画的框线是内容 → BUSY；第三个记录在案的
代价是**框下方**的整行 ─（对话区画的 rule / 框下方的 chrome rule）会把框扩过它和它到框底之间的行 →
BUSY → 投递等待（保守方向，永不粘连）。原文（改动后的整段在 git diff 里；`grep` 定位见 §7）：

- 实测不可达：两份已存布局（Pi 0.85.1 / 0.87.0）里 pane 最低的整行 ─ 就是框自己的下边框，其下只有
  footer/status 行；信任弹窗帧根本没有框（overlay 判据优先）。
- 不可分离：`p78-draft-rule-only.txt`（草稿只有一条 rule）与「空框正下方紧贴一条 rule」的读法是
  **同一串字节** —— 重新测量（第二份是提案 pkg 用同一构造生成的 `p78-conversation-rule-adjacent.txt`）：

```sh
$ sha256sum skills/teamsmith/tests/frames/p78-draft-rule-only.txt
$ P78_KEEP=1 bash -c '. docs/team/reports/P78-verify/pkg/lib.sh; p78_build_frames; printf "%s\n" "$P78_FRAMES"'
$ cmp skills/teamsmith/tests/frames/p78-draft-rule-only.txt "$P78_FRAMES/p78-conversation-rule-adjacent.txt"   # cmp 无输出 = 相同
e463c80cddc00efb84456a93b151536cd2683da923a789a5381baacb4f5053a6  skills/teamsmith/tests/frames/p78-draft-rule-only.txt
e463c80cddc00efb84456a93b151536cd2683da923a789a5381baacb4f5053a6  $P78_FRAMES/p78-conversation-rule-adjacent.txt
```

（与提案 `design.md` §6 的 `e463c80c…f5053a6` 一致。）八份合成帧逐字节等于提案 pkg 的
`p78_build_frames` 输出（`logs/` 里的复现与 `1ea0dd1c` 的提交说明）：

```sh
$ sha256sum skills/teamsmith/tests/frames/p78-draft-rule-only.txt
$ P78_KEEP=1 bash -c '. docs/team/reports/P78-verify/pkg/lib.sh; p78_build_frames; printf "%s\n" "$P78_FRAMES"'
$ for f in skills/teamsmith/tests/frames/p78-*.txt; do cmp "$P78_FRAMES/$(basename "$f")" "$f" && echo "cmp ok $(basename "$f")"; done
cmp ok p78-conversation-rule-below-box.txt
cmp ok p78-cursor-mid-draft.txt
cmp ok p78-draft-rule-below-cursor-line.txt
cmp ok p78-draft-rule-below-cursor.txt
cmp ok p78-draft-rule-blank-region.txt
cmp ok p78-draft-rule-only.txt
cmp ok p78-spinner-row-below-cursor.txt
cmp ok p78-wider-rule-below-cursor.txt
```

## 6 · 端到端（真 pane）与 flip 证据

`repro.sh`（`logs/repro.log`）用 `git archive <最早一条 P80 提交>^` 还原修前的树，同一份夹具跑两条路径：

```sh
$ bash docs/team/reports/P80-dev3/repro.sh
老树 · 生产（最低优先）：   geometry=[1 3] box_nows=[] verdict=idle-read=EMPTY rc=0
新树 · 生产（最低优先）：   geometry=[1 5] box_nows=[─×120 drafttextbelowmyownrule] verdict=idle-read=NOT-EMPTY rc=1
新树 · 影子（最近优先）：   geometry=[1 3] box_nows=[] verdict=idle-read=EMPTY rc=0
---- 共享判据（pm-box-real.sh --frame）----
老树：idle-read=EMPTY  box_text=[]  rc=0
新树：idle-read=NOT-EMPTY  box_text=[─×120 draft text below my own rule]  rc=1
==== ② 真 pane：静止的攻击帧 + 就绪门 ====
老树（rc=0）：  · 就绪：判定定位到输入框且为空 …   M45 idle-read=EMPTY ok   deliver_text_lines=1 bracketed=no   keylog 行数=1
新树（rc=1）：  ✗ 夹具：就绪门 4 拍内没有放行（最后判定=idle-read=NOT-EMPTY）…（打印最后一帧）keylog 行数=0
```

- **红（修前）**：就绪门**放行**（`rc=0`），帧中出现 `deliver_text_lines=1`（一次真实粘贴），
  keylog 有 1 行字节 —— 攻击帧的草稿会被粘上自动化文本（P74 的 F1 现场）。
- **绿（修后）**：`rc=1`，最后判定 `idle-read=NOT-EMPTY`，打印最后一帧（就是那份攻击草稿），
  没有 `deliver_text_lines=`，keylog **0 行**。
- **生产路径**（`logs/say-standalone.log` / `draft-standalone.log`，同一形状的私有 fixture）：`team say`
  与 `team draft send` 都报 `queued`（"目标输入框里有草稿：没有写任何键"），队列 2 条，keylog 0 行，
  payload 不出现在 pane 上，草稿原样。
- 同一条链在 smoke §44（非 FAST）里常驻：帧回放假 pi 画攻击帧 → 就绪门拒绝 + `team say`/`draft send`
  只排队（真 tmux + python3 才跑，FAST 显式跳过）。

## 7 · 验收命令与结果

```sh
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 28 passed, 0 failed (28 items)
✓ change/bottom-border-candidate-selection（含）

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2530  ✗ 0
smoke 全绿                     # FAST_EXIT=0
# §12b-h0d 的 83 条 P80 断言全绿；§44（真 pane）显式跳过：
#   SKIP（FAST 模式） 44·P80-真pane —— 要真 tmux pane + 帧回放假 pi（真进程段落）
# 断言数对照：FAST 基线（本树，实测）2447 → 2530，+83 = §12b-h0d 的新断言；§8 F1 那条 M45 红已随断言修正回归

$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
Totals: 28 passed, 0 failed (28 items)
== 结果 ==  ✓ 3192  ✗ 0
smoke 全绿                     # GATE_EXIT=0
# 排队 ~7 分钟后拿到机器锁（20:25:26），约 18 分钟跑完；§12b-h0d 83 条 + §44 18 条全绿
# 断言数：3192 = FAST 的 2530（含新段 83）+ §44 的 18 + 644 条只在全量里跑的真进程/场地断言
# （与 P75 报告的全量基线 3091 + 101 一致）
```

§44 的真 pane 面（全量日志原文，节选）：

```
== 44 · P80 输入框判据：草稿自己的下边框框线（真 pane 就绪门 + 生产路径只排队） ==
  ✓ P80 就绪门：面对「草稿自带下边框框线」的 pane 拒绝放行（rc=1≠0）
  ✓ P80 就绪门：拒绝时最后判定点名 idle-read=NOT-EMPTY
  ✓ P80 就绪门：拒绝时打印最后一帧
  ✓ P80 就绪门：最后一帧就是那份攻击草稿（不是别的失败）
  ✓ P80 就绪门：拒绝后一步投递都没跑
  ✓ P80 就绪门：keylog 零行（一个键都没敲进人的草稿）
  ✓ P80 生产路径：dev 窗口画的正是攻击帧
  ✓ P80 生产路径：team_input_box_state 报 BUSY（不是 EMPTY）
  ✓ P80 生产路径：team_delivery_verdict 不是 EMPTY
  ✓ P80 生产路径：生产提取读到的就是框线行 + 框线下面的草稿
  ✓ P80 生产路径：攻击草稿在场 → team say 报 queued（不是已送达）
  ✓ P80 生产路径：say 之后队列里恰好一条
  ✓ P80 生产路径：say 一个键都没敲（keylog 仍 0 行）
  ✓ P80 生产路径：say 的文字没有出现在 pane 上
  ✓ P80 生产路径：攻击草稿仍在 pane 上（原样）
  ✓ P80 生产路径：draft send 也只入队（queued）
  ✓ P80 生产路径：draft send 之后队列里两条（say 的 + draft 的）
  ✓ P80 生产路径：draft send 一个键都没敲（keylog 仍 0 行）
```

`references/troubleshooting.md` §3 的定位（供复验 grep；已实际跑过，全部命中）：

```sh
$ grep -n "qualifying row below it as the bottom border" skills/teamsmith/references/troubleshooting.md
174:  qualifying row below it as the bottom border (a full-rule row of equal width, or the E3-era spinner shape where a
$ grep -n "not reachable in either measured" skills/teamsmith/references/troubleshooting.md
184:  the top border's cost, on the same conservative side. That last cost is **not reachable in either measured
$ grep -n "e463c80c" skills/teamsmith/references/troubleshooting.md
189:  rule row immediately below an empty box are the **same bytes** (sha256 `e463c80c…f5053a6`), so one rule must
$ grep -n "whitespace-only draft" skills/teamsmith/references/troubleshooting.md     # 同类洞清单里仍在（113/120/145）
$ grep -n "status-row clone" skills/teamsmith/references/troubleshooting.md         # 同类洞清单里仍在（147）
```

propose 阶段的证据包（design §9 第 1 条）在**修前的树**上仍是 `✓57 ✗0 · findings=1`
（`logs/p78pkg-base.log`）；在**本树**上跑同一份未修改的 pkg 时，恰好 7 条「today」断言翻成提案值、
50 条 ok（`logs/p78pkg-apply.log`）—— 这是「实现现在就是提案写的行为」的独立旁证：

```
== run 结果 == ✓57 ✗0 · findings=1 · skip=0     （修前的树）
== run 结果 == ✓50 ✗7 · findings=1 · skip=0     （本树；7 条 today = F1/F2/F6/F7×2/F8/20b）
```

## 8 · 设计影响发现与覆盖缺口

- **F1（必须让 PM 看到）**：design §11 的「既有断言不会变」在 **M45 段的合成对抗帧**上不成立。该帧
  （smoke.sh 内联构造，不是 `tests/frames/` 的真帧）在旧规则下几何 `[1 5]`、框文本 = 横幅文字；
  新规则取最低候选 row 7 → 几何 `[1 7]`，于是**框自带的那条上边框 rule 行**也落进框内成了内容，
  期望串必须加长 40 个 `─`。判定不变（BUSY），没有弱化：只是把新读到的内容也钉进同一串。
  已按新值更新该断言并在提交说明里写明（`a9a7de90`）。实现落地后的 FAST 首跑（在那个断言更新**之前**）
  就是这个唯一红：`✓ 2446 ✗ 1`（基线 `✓ 2447 ✗ 0`）；更新后全绿（§7）。
- **既有噪声（不是本单引入）**：同一条 M45 断言的**消息串**里有未转义的反引号
  （`` ` Changelog: https://x` ``），所以每次跑到那行都会执行一次空的命令替换并在 stderr 打
  `Changelog:: command not found`。基线树（`aa234729`）的同一行一字不差，所以与本单无关；
  本单只改期望值，没有顺手改它（避免不必要的 diff）。
- **覆盖缺口**：`12b-h0d` 的两个方向都是**纯帧**（`_team_box_geometry` 层），真 pane 面只有攻击帧
  一种形状（§44）；控制形状（更宽 rule / spinner 行 / 光标在中间）的真 pane 版本没有跑 —— 它们由
  P78 提案的 `10-*.sh` 纯函数测量覆盖。这是有意的取舍（真 pane 段的代价高、且判定不落在 IO 上）。
- 预先声明的范围：只动 `delivery-guard` 的 ADDED requirement 对应行为；上边框规则、边框邻行谓词、
  overlay、fold/prefix 窗口、`team_box_mid_render`、`team_retract`、粘贴/确认路径都没动（§4 的
  matrix 逐行相同 + 真帧逐字相同是这条的证据）。
- propose pkg 在本树上的 7 条红是**预期翻转**（见 §7），不是回归：它们断言的是旧行为。

## 9 · 残留与边界

- `p78-*.txt` 是**合成**帧（裁切型 TUI 的模型），README 明说没有真 pi 出处；真实现场仍由五份真帧
  与 P78 提案的实测清单守着。
- 镜像代价（框下方的整行 ─ → BUSY）按规格**不消除**，只记录 + 实测不可达；若未来布局在框下画 rule，
  症状是「排队而不是投递」——保守方向，`references/troubleshooting.md` §3 写了。
- `M45_NO_STRIP`/`M24_SHADOW_CHROME` 那类影子是**测试进程内**的函数覆写；本单没有新增任何产品开关
  （`git diff` 里 outbox.sh 不含新的 `TEAM_*` 读）。
- 无 `BLOCKED`。
