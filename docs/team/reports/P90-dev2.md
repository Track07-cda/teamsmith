# P90 · bottom-border-candidate-selection 重新验证（F1 修复后 · 换人）— 交付报告

```
agent:   dev2
status:  DONE（verify 完成；brief 六项 + 三条变异 + delta 场景值复核全过；一条散文 finding）
time:    2026-09-23T00:30Z
branch:  task/P90-p90（local 模式：**不 push**，分支留在 .worktrees/dev2，PM 复验后本地合并）
brief:   docs/team/tasks/P90-bottom-border-reverify.md
tip:     本报告的提交（package 在 ba36b3b7 / 6e99a9e4，报告在最后一笔）
change:  bottom-border-candidate-selection（propose=P78 verify · apply=P80 dev3 · verify=P84 dev · F1 修复=P86 dev）
phase:   verify
specs:   delivery-guard#The bottom border is the lowest qualifying rule row below the cursor
anchor:  change（deltas: delivery-guard）
被测：   main（含 P86 修复 13686d9d）+ P90 任务书 1263fa9f；实现树**只读**，全部临时物在 mktemp 目录
```

## 交付物

| Path | What |
|---|---|
| `docs/team/reports/P90-dev2.md` | 本报告 |
| `docs/team/reports/P90-dev2/pkg/run.sh` | 验证包入口：`bash docs/team/reports/P90-dev2/pkg/run.sh [10 20 … 60]`，退出 0 = 脚本级断言全过（finding 不失败） |
| `docs/team/reports/P90-dev2/pkg/lib.sh` | 断言/探针调用/自造帧构造/光标表/判定归一（**不复用 smoke 的断言文本**） |
| `docs/team/reports/P90-dev2/pkg/probe.sh` | 纯帧探针：`_team_box_geometry` + `_team_box_text_of_frame` + `team_box_frame_verdict`，四个影子方向 |
| `docs/team/reports/P90-dev2/pkg/prod.sh` | 生产路径探针：真 `team_input_box_state`/`team_input_box_text` 走 PATH 上的**假 tmux**（不开真 server/session/pane） |
| `…/pkg/10-selfmade.sh` | 自造三种混宽度变体（等宽对 / spinner 作上边框 / 更窄的对）四方向对照 |
| `…/pkg/20-admission.sh` | 准入条件：严格之上、跳过→继续找更近、全语料含光标（16/16）、「碰到即可」的承重性 |
| `…/pkg/30-monotonicity.sh` | 本包自写的逐帧旧/新对比（两个旧侧；已存 16 帧 + 自造 7 帧） |
| `…/pkg/40-boundary.sh` | PM 裁定的边界形状逐条核对（结构 + 三侧判定 + 生产状态） |
| `…/pkg/45-scenarios.sh` | delta 场景值逐条复算（几何/判定/`holds_only`/真帧/V9-A10/sha256） |
| `…/pkg/50-one-implementation.sh` | 一处实现：静态计数 + 24 帧生产↔夹具逐字一致 + 影子两侧一致 |
| `…/pkg/60-mutations.sh` | 三条变异（去掉准入 / 放宽成碰到 / 夹具分叉），只在 scratch 副本上，红→绿 |
| `…/logs/` | `run-full.log`、`60-mutations.log`、`openspec.log`、`gate-fast.log`、`gate-full.log`、`guard-matrix.log` |

## 一、结论速览

| brief 项 | 判定 | 关键值（原始输出见 §二） |
|---|---|---|
| 1 F1 自造三种混宽度变体 | ✓ | 三份都 `geometry=[1 3]`（框含光标行）、光标行草稿留在框内、`idle-read=NOT-EMPTY rc=1`；准入关掉影子 → `[5 7]`/`box_nows=[]`/`EMPTY rc=0`（红形状逐字复现） |
| 2 准入条件（严格之上 / 跳过 / 全语料含光标） | ✓ | 已存 **16/16** 帧的定位框满足 `top < cy < bottom`（唯一无框=信任弹窗，覆盖层优先）；自造三候选帧证明「跳过最低的不合格候选、胜者是较低的合格候选」：当前 `[1 7]`、最近优先 `[1 3]`、准入关掉 `[5 9]`（不含光标） |
| 3 自写单调性对比 | ✓ | 已存 16 帧 × 两个旧侧：**没有 BUSY→EMPTY**；修后翻成忙的恰好 3 份 `p86-f1-*`（不多不少）；自造 7 帧同口径也 0 违规 |
| 4 边界形状按裁定核对 | ✓ | 结构 = `rule(110) / 空(光标) / rule(110) / 空 / rule(140) / 文本 / rule(140) / footer`；当前定位**光标自己的 A 框** `[1 3]`、框文本空、`EMPTY`、生产 `state=EMPTY`；准入关掉（P80）才取不相交的 B 框 `[5 7]`、框文本=`boundarytext`、`NOT-EMPTY`、生产 `BUSY` —— 与「A 框是空的那个、旧 BUSY 来自 B 框」的裁定逐条一致 |
| 5 一处实现 | ✓ | 三个决策函数各定义 1 处、在 outbox.sh 一个文件；tests/** 无第二份候选逻辑；**24 帧**（16 已存 + 8 自造）生产路径与夹具判定逐字一致；两个影子方向上两侧仍一致；夹具分叉变异 → 同源断言红 |
| 6 零回归 | ✓ | `openspec validate --all --strict` **30 passed / 0 failed**；FAST **✓ 2642 ✗ 0**；守卫矩阵 **✓ 31 ✗ 0**；全量 smoke **✓ 3308 ✗ 0**（含 44·P80-真pane / 42·P67-真pane / 41·p55-pane 留存等真进程段落），见 §二.6 |
| 附加 §45：delta 场景值 | ✓ | 规格里写下的几何/判定/`holds_only`/真帧值 **32/32** 与实测一致；`p78-draft-rule-only.txt` 的 sha256 = 申报的 `e463c80c…f5053a6`；V9-A10（光标行自己整行 rule 不是下边框候选）由结构与行为两侧钉住 |
| 三条变异（红→绿） | ✓ | M1 去掉准入 → 6 帧 × 3 断言 = 18 条红；M2 放宽成「碰到即可」→ 自造 touch 帧 4 条红（含「框含光标」不变式）；M3 夹具分叉 → 2 帧同源红；还原后各 18/4/2 条全绿，真树 `git status`/`git diff` 空 |
| **finding F1** | **! 1 条（散文）** | delta requirement 第 13–14 行有一处重复且括号不平衡的句子（不影响规范内容，见 §三） |

**一句话**：P86 的准入修复在自造帧、全语料、两个旧侧对比、边界裁定与生产路径上全部复现；实现与夹具确实同源，
影子能把两侧一起打回旧行为；三条变异都在 scratch 上红、还原后绿。唯一 finding 是 delta 里一句重复的散文。

## 二、逐项证据（命令 + 原始输出尾）

复现命令（全部只读被测树；实现树是 main + P90 任务书）：

```sh
bash docs/team/reports/P90-dev2/pkg/run.sh                 # 全部 7 节：== run 结果 == ok=178 bad=0 finding=0  →  PASS
bash docs/team/reports/P90-dev2/pkg/run.sh 10 20 30 40 45 50 60   # 也可单节：bash …/pkg/40-boundary.sh
```

### 2.1 brief 第 1 项：自造混宽度帧（§10）

我自造三份「光标框一种宽度、下方另有一对自成配对的规则行」的帧（宽度 90/130/100 列，**与已存 p78-* 的 120 列、
p86-f1-* 的 100/120 列都不同**）。下面以等宽对那份为例（`self-mixed-equal.txt`：90 列框 + 光标行草稿 +
下方 130 列自成对，光标行 2）：

```
  -- self-mixed-equal.txt（光标行 2）--
      1 w=270 ──────────────────────────────────────────────────────────────────────────────────────────
      2 w= 17  SELF EQUAL DRAFT
      3 w=270 ──────────────────────────────────────────────────────────────────────────────────────────
      4 w=  0 
      5 w=390 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
      6 w=  0 
      7 w=390 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
      8 w=  7  footer
     shadow=0 geometry=[1 3] box_nows=[SELFEQUALDRAFT] verdict=idle-read=NOT-EMPTY rc=1
     shadow=1 geometry=[1 3] box_nows=[SELFEQUALDRAFT] verdict=idle-read=NOT-EMPTY rc=1
     shadow=2 geometry=[5 7] box_nows=[] verdict=idle-read=EMPTY rc=0
     shadow=3 geometry=[1 3] box_nows=[SELFEQUALDRAFT] verdict=idle-read=NOT-EMPTY rc=1
```

spinner 作下方上边框、更窄的对两份的四方向读数与上表**同形**（`[1 3]` 忙 / `[1 3]` 忙 / `[5 7]` 空 / `[1 3]` 忙），
逐帧断言见 `logs/run-full.log`。§10 结果：`ok=27 bad=0`。

### 2.2 brief 第 2 项：准入条件与「跳过 → 找更近」（§20）

自造三候选帧 `self-mid-skip.txt`（行 9 的 130 列候选配到的上边框是行 5 —— 在光标下方，不合格；行 7 的 90 列候选
配到行 1 —— 合格）区分三种顺序：

```
     当前      geometry=[1 7] verdict=idle-read=NOT-EMPTY rc=1
     最近优先  geometry=[1 3] verdict=idle-read=NOT-EMPTY rc=1
     准入关掉  geometry=[5 9] verdict=idle-read=NOT-EMPTY rc=1
ok   准入②：最低候选不合格被跳过，胜者是较低的那个合格候选 [1 7]（不是最近的 [1 3]）（1 7）
ok   准入②：最近优先影子回落到 [1 3]（证明两种顺序真的不同）（1 3）
ok   准入②：准入关掉影子取 [5 9]（整框在光标下方，违反含光标）（5 9）
ok   准入②：当前 [1 7] 含光标行
ok   准入②：准入关掉的 [5 9] 不含光标（缺陷形状，正是要拒绝的）
```

**全部已存帧含光标**（§20 的发现式扫描，16 帧；唯一无框的是覆盖层帧）：

```
  已存帧（发现式）：n=16 无框=[pi-0.87.0-project-trust-prompt.txt] 不含光标=[] 未声明光标行=[]
ok   准入①：全部已存帧都声明了光标行（新增帧不声明 → 直接红）（）
ok   准入①：已存帧 16 份（5 真帧 + 8 份 p78 + 3 份 p86）（16）
ok   准入①：定位出的框总是包含光标行（top < cy < bottom）（）
ok   准入①：唯一没有框的帧是信任弹窗（覆盖层先行，既有路径）（pi-0.87.0-project-trust-prompt.txt）
```

**「严格之上」是承重的**（自造 `self-touch-empty.txt`：光标行自己就是 130 列整行 rule）：

```
     当前      geometry=[] verdict=idle-read=NOT-EMPTY rc=1 | 生产 state=UNKNOWN
     碰到即可  geometry=[2 4] verdict=idle-read=EMPTY rc=0 | 生产 state=EMPTY
ok   准入④：当前不认这个候选（无框）→ 判忙（保守）（）
ok   准入④：变异的 [2 4] 违反「严格包含光标」（top==cy）
ok   准入④：碰到即可影子下判空（生产也放行）
```

已存三份 F1 帧逐帧：当前 `[1 3]`/忙，准入关掉 `[5 7]`（P84 的 F1 原始形状）。§20 结果：`ok=23 bad=0`。

### 2.3 brief 第 3 项：本包自写的单调性对比（§30）

```
  ── 已存语料 ──
  p78-conversation-rule-below-box.txt        cy=2  cur=[1 4  ]BUSY    准入关掉=BUSY    最近优先=EMPTY
  p78-cursor-mid-draft.txt                   cy=3  cur=[1 5  ]BUSY    准入关掉=BUSY    最近优先=BUSY
  p78-draft-rule-below-cursor-line.txt       cy=2  cur=[1 5  ]BUSY    准入关掉=BUSY    最近优先=BUSY
  p78-draft-rule-below-cursor.txt            cy=2  cur=[1 5  ]BUSY    准入关掉=BUSY    最近优先=EMPTY
  p78-draft-rule-blank-region.txt            cy=2  cur=[1 5  ]BUSY    准入关掉=BUSY    最近优先=EMPTY
  p78-draft-rule-only.txt                    cy=2  cur=[1 4  ]BUSY    准入关掉=BUSY    最近优先=EMPTY
  p78-spinner-row-below-cursor.txt           cy=2  cur=[1 5  ]BUSY    准入关掉=BUSY    最近优先=BUSY
  p78-wider-rule-below-cursor.txt            cy=2  cur=[1 5  ]BUSY    准入关掉=BUSY    最近优先=BUSY
  p86-f1-mixed-width-disjoint-box.txt        cy=2  cur=[1 3  ]BUSY    准入关掉=EMPTY   最近优先=BUSY
  p86-f1-narrower-width-disjoint-box.txt     cy=2  cur=[1 3  ]BUSY    准入关掉=EMPTY   最近优先=BUSY
  p86-f1-spinner-top-disjoint-box.txt        cy=2  cur=[1 3  ]BUSY    准入关掉=EMPTY   最近优先=BUSY
  pi-0.85.1-update-banner.txt                cy=26 cur=[24 29]EMPTY   准入关掉=EMPTY   最近优先=EMPTY
  pi-0.87.0-draft-half-sentence.txt          cy=26 cur=[25 27]BUSY    准入关掉=BUSY    最近优先=BUSY
  pi-0.87.0-empty-box.txt                    cy=26 cur=[25 27]EMPTY   准入关掉=EMPTY   最近优先=EMPTY
  pi-0.87.0-one-line-draft.txt               cy=26 cur=[25 27]BUSY    准入关掉=BUSY    最近优先=BUSY
  pi-0.87.0-project-trust-prompt.txt         cy=16 cur=[     ]OVERLAY 准入关掉=OVERLAY 最近优先=OVERLAY
ok   单调性：已存帧全部被本段的表覆盖（16）（16）
ok   单调性（已存）：准入关掉 → 当前 没有任何 BUSY→EMPTY（）
ok   单调性（已存）：当前翻成忙的恰好是 3 份 p86-f1-*（修复效果，不多不少）（p86-f1-mixed-width-disjoint-box.txt p86-f1-narrower-width-disjoint-box.txt p86-f1-spinner-top-disjoint-box.txt）
ok   单调性（已存）：最近优先 → 当前 也没有 BUSY→EMPTY（）
```

自造 7 帧（不含边界形状）同口径 0 违规；`self-touch-empty` 与三份混宽度帧在两个旧侧上都是「旧侧 EMPTY → 当前 BUSY」，
方向安全（EMPTY→BUSY）。§30 结果：`ok=6 bad=0`。

### 2.4 brief 第 4 项：边界形状按裁定核对（§40）

```
  -- self-boundary.txt --
      1 w=330 ──────────────────────────────────────────────────────────────────────────────────────────────
      2 w=  0 
      3 w=330 ──────────────────────────────────────────────────────────────────────────────────────────────
      4 w=  0 
      5 w=420 ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
      6 w= 14  boundary text
      7 w=420 ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
      8 w=  7  footer
  当前      geometry=[1 3  ] box_nows=[] verdict=idle-read=EMPTY rc=0 | 生产 state=EMPTY
  准入关掉  geometry=[5 7  ] box_nows=[boundarytext] verdict=idle-read=NOT-EMPTY rc=1 | 生产 state=BUSY
  最近优先  geometry=[1 3  ] box_nows=[] verdict=idle-read=EMPTY rc=0
ok   边界形状：行 1/3 是同一宽度 A=110 的整行 rule（110 110）
ok   边界形状：行 5/7 是同一宽度 B=140 的整行 rule（A≠B）（140 140）
ok   边界形状：行 2（光标行）与行 4 是空行（0 0）
ok   边界：当前定位到光标自己的 A 框 [1 3]（1 3）
ok   边界：当前 A 框里没有内容（就是空的那个框）（）
ok   边界：当前判 EMPTY rc=0（更正后的正确读法）（）
ok   边界：生产路径同步判空（EMPTY）
ok   边界：准入关掉（P80）定位到不相交的 B 框 [5 7]（5 7）
ok   边界：P80 时代的 BUSY 内容来自 B 框里的文本行（boundarytext）
ok   边界裁定①：光标所在框就是 A 对（行 1–3）（1 3）
ok   边界裁定②：B 对（行 5–7）与光标不相交，只在准入关掉时才被取到（5 7）
ok   边界：该形状不在已存语料里（scratch 专属）（0）
```

即：这个形状**确实就是裁定时说的那个**（A 对夹着空的光标行，B 对在下方且不相交），裁定接受的 `EMPTY`
是「光标自己的 A 框是空框」的正确读法，而不是别的形状或别的错误。§40 结果：`ok=17 bad=0`。

### 2.5 brief 第 5 项：一处实现（§50）

```
ok   一处实现：_team_box_geometry 定义恰一处（1）
ok   一处实现：候选顺序决策定义恰一处（1）
ok   一处实现：准入决策定义恰一处（1）
ok   一处实现：几何向顺序决策要答案恰一处（1）
ok   一处实现：几何向准入决策要上界恰一处（1）
ok   一处实现：全树这三处定义都在同一个文件（outbox.sh）（…/skills/teamsmith/scripts/lib/outbox.sh）
ok   一处实现：三处定义合计恰好三条（3）
ok   一处实现：tests/** 里没有第二份候选循环/几何重定义（0）
ok   一处实现：夹具判定自己不写候选逻辑（只调共享提取）（0）
ok   一处实现：夹具判定调用共享提取（1）
ok   同源(已存) p86-f1-mixed-width-disjoint-box.txt：生产 BUSY 与夹具 NOT-EMPTY 一致（框文本逐字相同）
ok   同源(已存) pi-0.87.0-project-trust-prompt.txt：生产 UNKNOWN（读不出来）时夹具不判空（OVERLAY）
ok   同源(自造) self-mid-skip.txt：生产 BUSY 与夹具 NOT-EMPTY 一致（框文本逐字相同）
ok   同源：逐帧比较完成（24 帧；上面的 ok/bad 行是逐帧判定）
ok   影子同源 shadow=1：两条路径同取空框/EMPTY
ok   影子同源 shadow=2：两条路径同判忙且框文本逐字相同
ok   一处实现：P80 形状当前 [1 5]（框含草稿的 rule 行）（1 5）
ok   一处实现：最近优先影子把它退回 [1 3]（夹具/生产两侧同影子）（1 3）
ok   一处实现：影子下退回 EMPTY（）
```

生产路径由**假 tmux** 驱动真 `team_input_box_state`/`team_input_box_text`（`display-message cursor_y` +
`capture-pane`，绝不连真 server/session/pane）；夹具路径由纯帧 `team_box_frame_verdict` 驱动。24 帧上两侧的框文本
逐字相同、判定同向（生产 EMPTY ⟺ 夹具 EMPTY；生产 BUSY ⟺ 夹具 NOT-EMPTY；生产 UNKNOWN 时夹具绝不判空）。
§50 结果：`ok=51 bad=0`。

### 2.6 brief 第 6 项：门禁（openspec + FAST + 全量 smoke + 守卫矩阵）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 30 passed, 0 failed (30 items)                     （exit 0；logs/openspec.log）

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2642  ✗ 0
smoke 全绿                                                  （FAST_EXIT=0；logs/gate-fast.log）

$ bash skills/teamsmith/tests/guard-matrix.sh
== 结果 ==  ✓ 31  ✗ 0
guard matrix 全绿                                           （exit 0；logs/guard-matrix.log）

$ TEAM_SMOKE_LOCK_WAIT=7200 bash skills/teamsmith/tests/smoke.sh </dev/null   # 全量（排队上锁；00:03:38 拿到锁）
== 结果 ==  ✓ 3308  ✗ 0
smoke 全绿                                                  （SMOKE_EXIT=0；logs/gate-full.log）
```

### 2.7 附加：delta 场景值逐条复算（§45）

```
ok   delta 场景 p78-draft-rule-below-cursor.txt：geometry=[1 5]（1 5）
ok   delta 场景 p78-draft-rule-only.txt：geometry=[1 4]（1 4）
ok   delta 场景 p78-wider-rule-below-cursor.txt：geometry=[1 5]（1 5）
ok   delta 场景 p78-spinner-row-below-cursor.txt：geometry=[1 5]（1 5）
ok   delta 场景 p78-cursor-mid-draft.txt：geometry=[1 5]（1 5）
ok   delta 场景 p78-conversation-rule-below-box.txt：geometry=[1 4]（1 4）
ok   delta 场景 p78-draft-rule-blank-region.txt：geometry=[1 5]（1 5）
ok   delta：草稿自己画的 rule 行留在框内（框文本含整行 ─）
ok   delta：rule 下方的草稿文字也在框内
ok   delta：三行草稿全部在框内
ok   delta：payload 「half a sentence」 对整框判 extra-text（截断框不算我们的）（extra-text）
ok   delta 红侧：最近优先影子下同一 payload 变成 only-ours（旧截断框的形状）（only-ours）
ok   delta 场景 pi-0.87.0-one-line-draft.txt：geometry=[25 27]（25 27）
ok   delta 场景 pi-0.87.0-draft-half-sentence.txt：geometry=[25 27]（25 27）
ok   delta 场景 pi-0.87.0-empty-box.txt：geometry=[25 27]（25 27）
ok   delta 场景 pi-0.85.1-update-banner.txt：geometry=[24 29]（24 29）
ok   delta 真帧：信任弹窗没有框（）
ok   delta 真帧：信任弹窗判覆盖层
ok   V9-A10：光标行不是下边框候选（几何 [1 5]，不是 [1 2]）（1 5）
ok   V9-A10：候选循环从 cy+1 开始（静态）（1）
ok   design：p78-draft-rule-only.txt 的 sha256 就是申报的那串字节（e463c80cddc00efb84456a93b151536cd2683da923a789a5381baacb4f5053a6）
== 45-scenarios 结果 == ok=32 bad=0 finding=0 skip=0
```

P86 三份帧的 sha256（与 smoke §46 的钉住值一致；README 声称与 P84 复验自造帧逐字节相同，但 P84 的临时文件已不在，
**能复核的只有哈希本身**）：

```
4a59efae747e9b81414eff7f2664d421c8bc418bd57a2afbc2e037c8d7d81ca2  p86-f1-mixed-width-disjoint-box.txt
a3d9232e6abc422984c67799af6f2b8791921848d7a65c9de8864845ad54c70e  p86-f1-narrower-width-disjoint-box.txt
67c8a6ab321693df1ddfa867af0c7e09e0e329099858c1e6dbccaa59b2546c7e  p86-f1-spinner-top-disjoint-box.txt
```

## 独立验证包 / Independent verification package

**范围与隔离（事后抽查）**：

```
$ git diff --stat main...HEAD            # 本分支相对 main 只动报告目录，skills/ 与 openspec/ 零改动
 …（16 files changed，全在 docs/team/reports/P90-dev2/**）
$ grep -rn '^[[:space:]]*tmux ' docs/team/reports/P90-dev2/pkg/*.sh | wc -l
0                                        # 包里唯一出现 tmux 的地方是 prod.sh 写出的*假* tmux shim
```

生产路径探针把假 tmux 放在 PATH 最前，并 `env -u TMUX -u TMUX_PANE` 启动——包从头到尾**没有连过真 tmux
server/session/pane**（纯函数 + 假 tmux 两条路径）。

包在 `docs/team/reports/P90-dev2/pkg/`（入口 `docs/team/reports/P90-dev2/pkg/run.sh`）：**从零自写**——
不复用 smoke 的断言文本/夹具、不调 `team review`；帧由本包自己构造（宽度与已存帧不同）；单调性对比、
`holds_only`、同源比较、变异替换全部是本包自己的实现。运行：

```sh
bash docs/team/reports/P90-dev2/pkg/run.sh
```

## Flip evidence（破坏实现 → 守卫断言红 → 还原 → 绿）

三条变异（细则见 `docs/team/reports/P90-dev2/pkg/60-mutations.sh`；全部只在 `mktemp` 下的 scratch 副本上，
真树 `skills/openspec` 只读）。运行：`bash docs/team/reports/P90-dev2/pkg/60-mutations.sh` → `logs/60-mutations.log`。

**M1 去掉准入条件（`if (top && top <= maxrow)` → `if (top)`）**

**Red before**（变异树上，6 帧 × 3 条守卫断言全红；下面是前 6 条与红条数）：

```
red    M1 变异树 self-mixed-equal.txt 几何 = [1 3]（框含光标）（期望 [1 3]，实测 [5 7]）
red    M1 变异树 self-mixed-equal.txt 判定 = 忙（期望 [idle-read=NOT-EMPTY rc=1]，实测 [idle-read=EMPTY rc=0]）
red    M1 变异树 self-mixed-equal.txt 生产 state = BUSY（不放行）（期望 [BUSY]，实测 [EMPTY]）
…
red    M1 变异树 p86-f1-narrower-width-disjoint-box.txt 生产 state = BUSY（不放行）（期望 [BUSY]，实测 [EMPTY]）
ok   M1：6 帧 × 3 条守卫断言全部翻红（准入条件确实是它们在守）（red=18）
ok   M1：变异树上生产路径把草稿帧当空框放行（真实后果）…（state=EMPTY）
```

**Green after**（还原后真树，同一批断言）：

```
green  M1 还原后真树 self-mixed-equal.txt 几何 = [1 3]（框含光标）
green  M1 还原后真树 self-mixed-equal.txt 判定 = 忙
green  M1 还原后真树 self-mixed-equal.txt 生产 state = BUSY（不放行）
…
green  M1 还原后真树 p86-f1-narrower-width-disjoint-box.txt 生产 state = BUSY（不放行）
ok   M1：还原后真树 18 条守卫断言全部绿（红→绿）（red=0）
```

**M2 准入放宽成「框碰到光标行即可」（`cy - 1` → `cy`）**

这是「框与光标**有交集**即可」的口径：框的上边框允许落在光标行上（只碰到，不含）。它不是全量去掉（F1 帧下方
那对的上边框在行 5、远在光标下方，这个放宽仍拒绝它们——见 M2 末尾的三份对照）。

**Red before**（自造 `self-touch-empty.txt`，光标行自己整行 rule）：

```
   M2 变异树：geometry=[2 4] verdict=idle-read=EMPTY rc=0 生产 state=EMPTY
red    M2 touch 帧：当前无框（严格之上拒绝）（期望 []，实测 [2 4]）
red    M2 touch 帧：判忙（期望 [idle-read=NOT-EMPTY rc=1]，实测 [idle-read=EMPTY rc=0]）
red    M2 touch 帧：生产 state=EMPTY（就绪门放行——安全后果）
red    M2 touch 帧：变异造出 [2 4]（top==cy）——「严格包含光标」断言会红
ok   M2：touch 帧上 4 条守卫断言翻红（含框含光标不变式）（red=4）
```

**Green after**（还原后真树）：

```
green  M2 还原后真树 touch 帧：无框
green  M2 还原后真树 touch 帧：判忙
green  M2 还原后真树 touch 帧：生产不放行（UNKNOWN）
ok   M2 还原后真树：无框（含光标不变式空真）
ok   M2：还原后真树 4 条守卫断言全绿（红→绿）（red=0）
```

**M3 让夹具判定与生产提取分叉（夹具侧加第二份「最近优先」提取）**

**Red before**（变异树上，夹具判空而生产判忙；F1 帧上两侧本来就同判忙，所以分叉不显形——这正是「顺序可分辨」
帧的作用）：

```
   M3 变异树 p78-draft-rule-below-cursor.txt   夹具=EMPTY[…] 生产=BUSY[…]
red    M3 分叉 p78-draft-rule-below-cursor.txt：夹具与生产必须同源一致（期望 [agree]，实测 [diverge]）
   M3 变异树 self-draft-rule-below.txt         夹具=EMPTY[…] 生产=BUSY[…]
red    M3 分叉 self-draft-rule-below.txt：夹具与生产必须同源一致（期望 [agree]，实测 [diverge]）
ok   M3：两份「顺序可分辨」的帧上同源断言翻红（red=2）
```

**Green after**（还原后真树）：两份帧上 `夹具=BUSY[…] 生产=BUSY[…]` → `agree`；`M3：还原后真树同源断言全绿（红→绿）（red=0）`。

**还原总检**

```
ok   还原：真树 skills/openspec 无未提交改动（git status --porcelain 空）（）
ok   还原：真树 skills/openspec 无未暂存 diff（）
ok   还原：三条变异的 scratch 目录都已删除（0）
== 60-mutations 结果 == ok=22 bad=0 finding=0 skip=0
```

## 三、Findings

**F1（散文，不影响规范内容）** `openspec/changes/bottom-border-candidate-selection/specs/delivery-guard/spec.md`
第 13–14 行（`MUST continue with the nearer candidates (the order is lowest-first, so the next candidate is the one
closer to the cursor (the order is lowest-first, so the next candidate is the one closer to the cursor).`）：
同一个从句被**写了两遍**，外层的括号没有闭合。规范含义本身没问题（实现是「跳过不合格候选后，在**更近**的候选里继续
按最低优先试」），但这句话读起来会让人以为存在两个不同的规则。建议归档前由 PM 顺手改成单句、配平括号；
这属于 `openspec/changes/**`（PM 的目录），dev2 没有动它。

**边界（已裁定，不是 finding）**：准入条件自己的边界形状（`rule(A)/空(光标)/rule(A)/空/rule(B)/文本/rule(B)`，
A≠B）读 `EMPTY`，P86 已申报、PM 已裁定接受；§40 逐条核对了「确实如裁定」。该形状**不在**已存语料里，
所以 §30 的「全部已存帧无 BUSY→EMPTY」成立；已存语料里没有可达的 BUSY→EMPTY。

## 四、Decisions and deviations

- **没有改实现、规格、门禁或已存帧**（verify 阶段只读）；包的 scratch 只在 `mktemp` 下，`logs/` 与报告是唯一写入。
- **自造帧不落仓**：brief 第 1 项只要「自造帧」的证据，我没有往 `tests/frames/` 加帧（避免改变门禁的帧集合、
  也避免把包自己的构造物混进语料）。包每次运行时现场构造。
- **「碰到即可」变异（M2）的口径**：brief 写的是「放宽成框与光标框有交集即可」。我把它实现为「上边框允许落在
  光标行上（`maxrow = cy`）」。对 F1 帧那一类（下方那对的上边框在光标下方 3 行）它**不**放行（所以它是部分放宽，
  不是 M1 的全量去掉）；它在一个自造帧上显形——光标行自己就是整行 rule 时，它造出一个 `[2 4]` 的空框并放行。
  于是「混宽度 + 框含光标」这组断言红，与 brief 的预期方向一致。
- **P86 三份帧与 P84 自造帧的逐字节相同**：原文件已不在（P84 scratch 已清），只能复核仓里那三份的 sha256
  （与 smoke §46 的钉住值、README 的声明一致），不能复核「与 P84 当时那份逐字节相同」这个过程本身。
- **两个旧侧的定义**：`准入关掉` = P80 apply（P86 前）；`最近优先` = P80 之前。两者都用影子函数实现
  （生产里没有开关，符合 design D3）。

## Suggested next steps

- PM 复验：`bash docs/team/reports/P90-dev2/pkg/run.sh`（期望 `ok=178 bad=0 finding=0`）+ `team review P90 --strong`
  在独立 checkout 上跑 `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`。
- 归档（PM，须用户确认）前：本 change 的 delta 已被 P86 改过一次（提案审查 ACCEPTED 早于那次改动）——
  建议补一次提案复审或至少在归档记录里点名；顺手修 F1 那句散文。
- 归档把 ADDED requirement 合入 `openspec/specs/delivery-guard/spec.md` 后，语料（16 帧）与影子口径
  （`_team_box_bottom_candidate_order` / `_team_box_top_border_max_row`）应保持原样不动。
