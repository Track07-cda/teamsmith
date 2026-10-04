# P74 · one-line-draft-judgement 独立验证（verify 阶段）

agent: dev2   status: PASS（本 change 的 delta/验收全部通过；三条 follow-up 项已点名，均不构成本 change 的缺陷）   time: 2026-09-22T18:2xZ
branch: `task/P74-p74`（local 模式：不 push，分支留在 `.worktrees/dev2`）
change: `one-line-draft-judgement`（propose=P63/dev3 · apply=P67/dev3 · verify=P74/dev2）
tip: `1e17f3d4`（P74 brief）；apply 落地提交 `baca95ee`（已在 `main` 上；`git merge-base --is-ancestor baca95ee main` = YES）

## 交付物

| Path | What |
|---|---|
| `docs/team/reports/P74-dev2/pkg/run.sh` | **独立验证包入口**（不复用 apply 的 `P67-dev3/pkg/`；六节；`bash run.sh` 一次跑全；exit 0 = 全部断言通过，findings 不改 rc） |
| `docs/team/reports/P74-dev2/pkg/lib.sh` | 私有 tmux socket（PATH shim + 已 mkdir 的 `TMUX_TMPDIR` 双保险）、身份清理（TEAM_* / TEAM_REVIEW_*）、自造帧构造器、纯帧探针、修前树对照探针、假 TUI、断言/记账 |
| `docs/team/reports/P74-dev2/pkg/10-frames.sh` | §10 自造帧：0.87/0.85.1 两种布局、边框邻行、光标行、多行、V7-F1 上下方内容、残余形状、形状边界 |
| `docs/team/reports/P74-dev2/pkg/20-border.sh` | §20 边框配对：最高候选 / 短框线 / 更宽框线 / spinner 顶边框 / spinner 不作下边框 / braille 不候选；两个同族洞 + 修前树对照 |
| `docs/team/reports/P74-dev2/pkg/30-same-source.sh` | §30 两处判据同源（生产提取 / 帧判定 / `pm-box-real.sh --frame` 三调用点逐字一致 + 静态检查） |
| `docs/team/reports/P74-dev2/pkg/40-safety-live.sh` | §40 真 tmux pane 安全面：就绪门拒绝、`team say`/`draft send` 只排队、keylog 零行、真 pane 同源、真实仓库账本前后 hash |
| `docs/team/reports/P74-dev2/pkg/50-overlay.sh` | §50 覆盖层优先权（真弹窗帧 + 自造弹窗帧 + 红侧）+ `pm-box-real.sh` 三态 + 已声明残余 F2 |
| `docs/team/reports/P74-dev2/pkg/60-mutations.sh` | §60 三条变异（全部在 `/tmp` scratch 副本上做；实现目录 `skills/teamsmith` 零改动） |
| `docs/team/reports/P74-dev2/logs/pkg-{10,20,30,40,50,60}.log` | 本报告所有引用的原始输出 |
| `docs/team/reports/P74-dev2/logs/{fast-smoke,full-smoke}.log` | 门禁原始输出 |
| `docs/team/reports/P74-dev2/logs/pm-box-real-realpi.log` | `pm-box-real.sh` 真 pi（0.87.0）空框三态端到端一次 |

## 一、结论速览（brief 的七项）

| # | brief 项 | 结果 | 证据 |
|---|---|---|---|
| 1 | 边框邻行按内容读（自造帧：0.87+单行草稿→BUSY；0.85.1 空框→EMPTY；光标在邻行不误判；多行→BUSY） | **通过** | §10 `10 结果 ✓32 ✗0` |
| 2 | 边框配对（顶边框候选 / spinner / 两类可辨） | **规格语义通过；brief 措辞与规格相反** | §20 `✓20 ✗0 · findings=3`；见 F2 |
| 3 | 检查框内每一行（含光标下方；回车后打字 + ↑ 取回） | **通过** | §10 1e/1e2 |
| 4 | 两处判据同源（改一处另一处跟着变，分叉即失败） | **通过** | §30 `✓15 ✗0` + §60 M3 |
| 5 | 安全面（就绪门拒绝、只排队、一个键都不许敲） | **通过** | §40 `✓25 ✗0`（真 pane，keylog 零行、pane sha256 前后不变） |
| 6 | 覆盖层优先权未回退 | **通过** | §50 `✓15 ✗0`（真弹窗帧 overlay；M24_OVERLAY_DETECT=0 红侧可见） |
| 7 | 零回归（FAST + 全量 smoke、`pm-box-real.sh` 三态） | **通过** | FAST `✓2430 ✗0`；全量 `✓3074 ✗0`（两条已知红均翻绿）；真 pi 三态 rc=0 |
| M | 至少三条变异（红→绿原始输出） | **通过** | §60 `✓13 ✗0`；见「Flip evidence」 |

`bash docs/team/reports/P74-dev2/pkg/run.sh` 总账（全部六节）：

```
  §10  ✓32   ✗0   findings=0  skip=0
  §20  ✓20   ✗0   findings=3  skip=0
  §30  ✓15   ✗0   findings=0  skip=0
  §40  ✓25   ✗0   findings=0  skip=0
  §50  ✓15   ✗0   findings=1  skip=0
  §60  ✓13   ✗0   findings=0  skip=0
  合计 ✓120 ✗0 · findings=4 · skip=0
```

## 二、逐项证据（自造帧 + 可复现命令 + 原始输出）

所有帧由本包构造（`pkg/lib.sh` 的 `p74_frame_087`/`p74_frame_085`），**不读** apply 的
`tests/frames/*` 作为输入（只有 §50a 的「真信任弹窗」按 brief 第 6 项点名用仓库里的实测帧）。
复现：`bash docs/team/reports/P74-dev2/pkg/run.sh 10 20 30`（纯帧，不开 tmux）。

### 2.1 边框邻行 = 内容（brief 1/3）

```
$ bash pkg/10-frames.sh
  ok    1a 0.87 单行草稿：框文本就是草稿          box_text=[ half a sentence] / geometry=[1 3] / NOT-EMPTY rc=1
  ok    1a 红侧（影子=老槽位排除）：同一帧翻回 EMPTY   box_text=[] / idle-read=EMPTY rc=0
  ok    1b 0.87 空框：框文本空 / EMPTY rc=0
  ok    1c 0.85.1 空框：状态行被排除（框文本空）/ EMPTY rc=0
  ok    1c2 0.85.1 草稿在状态行上方：读出草稿 / NOT-EMPTY；自带状态行没有被读成内容
  ok    1c3 光标踩在状态行形状行上：该行是内容 → box_nows=[k3KimiCodingmax] / NOT-EMPTY rc=1
  ok    1c4 同形状（光标不在其上）→ chrome / EMPTY rc=0
  ok    1d 多行草稿（光标在最后一行 / 中间行）：三行都读出 / NOT-EMPTY
  ok    1e 文字在光标下方（V7-F1）：box_nows=[typedafteraleadingnewline] / NOT-EMPTY
  ok    1e2 ↑ 取回（光标上方空行）：box_nows=[recalledlineArecalledlineB] / NOT-EMPTY
  ok    1f 残余（已声明）：邻行是状态行克隆且光标在草稿上 → 克隆被判 chrome（草稿读出）
  ok    1f2 残余（已声明）：唯一一行是克隆 + 光标在空行 → EMPTY（形状不可分，design §7.1）
  ok    1f3 不认识的状态行拼写（` fake-pi 1.0`）→ 内容 / NOT-EMPTY（保守方向）
  ok    1f4 实测状态行形状被排除：` deepseek-flash  Deepseek  max` / ` k3  Kimi Coding  max`
  ok    1f5 形状近似拼写（模型 token 带空格）→ 内容（谓词窄，不误吞）
```

### 2.2 边框配对（brief 2）

```
$ bash pkg/20-border.sh
  ok    20a 顶边框取最高：几何 = [1 5]（不是 [3 5]）；草稿自画的等宽框线成为框内容 → 判忙
  ok    20b 短框线（40 宽）不冒充边框：几何仍是真框 [1 5]；是内容 → 忙
  ok    20c 更宽框线（140 宽）不是边框：几何 [1 4]；是内容 → 忙
  ok    20d spinner 行可作顶边框（tier2）：几何 [1 3]，内容读出
  ok    20e spinner 行在光标下方：不作下边框（几何 [1 4]，下边框=真整行 ─）；留在框内当内容 → 忙
  ok    20f braille 工作行（` ⠋ Blanching… · 0s`）不作边框：几何 = 真框 [2 4]，不撑到 [1 4]（V9-D2）
  ok    20g 光标停在自己的等宽框线上：下边框只在光标下方找 → 几何 [1 4]；该行是内容 → 忙（V9-A10）
  ok    20h / 20h2 两个同族洞的观测 + 修前树对照（见 F1）
```

### 2.3 同源（brief 4）

```
$ bash pkg/30-same-source.sh
  ok    30a 0.87 单行草稿：生产提取 = ` HUMAN-P74-ONE-LINE-DRAFT` = pm-box-real --frame 的 box_text；帧判定 NOT-EMPTY rc=1
  ok    30b 0.85.1 空框：生产提取空 = 帧判定 EMPTY rc=0 = pm-box-real rc=0
  ok    30c 影子谓词：三个调用点一起翻回空/EMPTY
  ok    30d box-judge.sh 调用 `_team_box_text_of_frame`；无内联槽位排除（grep `$1+0 != 1` 无命中）；pm-box-real.sh 走 `team_box_frame_verdict`
```

真 pane 上的同源（§40③）：`team_input_box_text` 与同一帧的 `_team_box_text_of_frame` 逐字一致
（`[ HUMAN-P74-ONE-LINE-DRAFT|]`），`team_input_box_state=BUSY` ↔ `team_box_frame_verdict=idle-read=NOT-EMPTY`。

### 2.4 安全面（brief 5，真 tmux pane / 私有 socket）

夹具：本包自造的帧回放假 TUI（`pkg/lib.sh` 的 `p74_fake_pi_write`）画 0.87 布局单行草稿
`HUMAN-P74-ONE-LINE-DRAFT`；pane 收到的每个字节写 keylog（hex）。

```
$ bash pkg/40-safety-live.sh
  ok    40① 就绪门拒绝放行（rc=1≠0）
  ok    40① 拒绝时最后判定点名 idle-read=NOT-EMPTY
  ok    40① 拒绝时打印最后一帧（含草稿原文）+「--- 最后一帧（原样，留给报告）---」
  ok    40① 拒绝后投递步骤一步没跑（无 deliver_text_lines=）
  ok    40① keylog 零行（一个键都没敲进人的草稿）
  ok    40② team say：报 queued；队列恰好 1 条；keylog 仍 0 行；pane sha256 不变；payload 没出现在 pane
  ok    40② draft send：报 queued；队列 2 条；keylog 仍 0 行；pane sha256 仍不变；payload 没出现在 pane
  ok    40③ 真 pane：生产提取 = HUMAN-P74-ONE-LINE-DRAFT = 帧级提取；BUSY = NOT-EMPTY
  ok    40③ holds_only：框里就是我们的那行 → yes；外来 payload → no
  ok    40④ 真实仓库 docs/team/inbox/** 与 .pi/team/state/**（去 bg/）前后 hash 相同（1 个文件）
```

隔离证据（`team paths` 片段，main_root 是临时夹具不是本仓库）：

```
{ "project": "fx", "main_root": "/tmp/p74pkg.dsG4eB/fx", "worktree": "/tmp/p74pkg.dsG4eB/fx",
  "docs": "/tmp/p74pkg.dsG4eB/fx/docs/team", "session": "p74sess-3377045-15886", ... }
```

P67 的 `15d` 红侧（修前：就绪门放行并把 payload 打进草稿）在本树已翻绿：同一形状 rc=1、零按键。

### 2.5 覆盖层优先权 + 三态（brief 6/7）

```
$ bash pkg/50-overlay.sh
  ok    50a 真信任弹窗帧（tests/frames/pi-0.87.0-project-trust-prompt.txt，cursor 16）：overlay=trust-prompt rc=0
  ok    50a 不是 NOT-EMPTY / 不是 EMPTY
  ok    50a 红侧（M24_OVERLAY_DETECT=0）：退回 idle-read=NOT-EMPTY、不再点名 overlay（可证伪）
  ok    50b 自造弹窗帧（三组文案标记）：overlay=trust-prompt
  ok    50c 三态① 空框 → idle-read=EMPTY rc=0
  ok    50c 三态② 单行草稿 → idle-read=NOT-EMPTY rc=1
  ok    50c 三态③ 覆盖层 → overlay=trust-prompt rc=0
```

### 2.6 apply 承诺的其余证据（本包独立复跑）

```
$ cmp skills/teamsmith/tests/frames/pi-0.87.0-one-line-draft.txt   docs/team/reports/P61-dev3/logs/15b-one-line-draft-frame.log
$ cmp skills/teamsmith/tests/frames/pi-0.87.0-draft-half-sentence.txt docs/team/reports/P61-dev3/logs/10c-real-draft-box.log
$ cmp skills/teamsmith/tests/frames/pi-0.87.0-empty-box.txt      docs/team/reports/P61-dev3/logs/10c-real-empty-box.log
ok 三份全部逐字节相同（proposal 的 cmp 承诺）

$ env -u TEAM_ROOT -u TEAM_SESSION bash skills/teamsmith/tests/guard-matrix.sh
== 结果 ==  ✓ 31  ✗ 0      # 未修改（apply 的 diff 里没有它），全绿

$ git diff baca95ee^ baca95ee -- skills/teamsmith/tests/smoke.sh | grep '^-' | grep -vc '^---'
9                            # 逐条核对：1 条旧内联提取被共享调用替代；1 条 M45 对抗帧期望串按设计
                             # §4 加长（` Changelog: https://x`，断言性质不变）；7 条是 ` fake-pi 1.0`
                             # → ` fake-pi  Fake Pi  max` 的合成状态行整形。没有断言被删/弱化。

$ git diff --name-only baca95ee^ baca95ee（排除 docs/team/**）
skills/teamsmith/references/troubleshooting.md · scripts/lib/outbox.sh · tests/{fake-tui.py,
flip-m45.sh,frames/README.md,frames/pi-0.87.0-*.txt,lib/box-judge.sh,pm-box-real.sh,smoke.sh}
# design §8 禁改清单核对（对 apply diff grep）：_team_box_geometry / _team_box_banner_rows /
# team_retract / team_payload_slice / team_transcript_* / overlay 谓词改动数 = 0；
# `_team_box_row_is_chrome` 里没有生产开关（M24_*/TEAM_* = 0 命中）；guard-matrix.sh / tmp-root.sh 未动。
```

- `troubleshooting.md` §3 现在点名了两个新残余（status-row 逐字克隆 + 光标在别处；不认识的未来状态行
  拼写读忙不读空），并且不再声称 V9-C3 的槽位洞是开着的（`grep -n` 证据：第 121–122、144–147 行）。
- `flip-m45.sh` 的跨树探针保留自有提取器，注释里明写这是「唯一文档化例外」（design §4）——已复核。
- 小瑕疵（不阻断）：`flip-m45.sh` 第 2 行注释被并到了同一行（结尾 `变异红#`），纯排版。

## 三、Flip evidence（三条变异，红→绿原始输出）

变异全部在 `/tmp` scratch 副本（`git archive HEAD skills/teamsmith`）上做；结束断言实现目录
`git status --porcelain -- skills/teamsmith` 空。原始输出见 `logs/pkg-60.log`、`logs/pkg-30.log`。

**M1 · 把邻行谓词改回「一律 chrome」（= 老的槽位排除）→ 单行草稿帧翻 EMPTY**

```
[M1 红侧 · scratch 谓词=一律 chrome]      scratch pkg/lib.sh: _team_box_row_is_chrome → return 0
      box_text=[] / geometry=[1 3] / verdict=idle-read=EMPTY rc=0
  ok    M1 红：单行草稿帧翻回 EMPTY（箱子在，文字消失）；框文本变空
[M1 绿侧 · 真树]
      box_text=[ HUMAN-P74-ONE-LINE-DRAFT] / verdict=idle-read=NOT-EMPTY rc=1
  ok    M1 绿：真树读出草稿；真树判 NOT-EMPTY
```

**M2 · 顶边框从「取最高候选」改成「取最近」→ 草稿自画等宽框线的形态红**

```
[M2 红侧 · scratch 顶边框=最近候选]       awk 循环 for (i=cand-1;i>=1;i--) → for (i=1;i<=cand-1;i++)
      geometry=[3 5] / verdict=idle-read=EMPTY rc=0
  ok    M2 红：草稿自画的等宽框线冒充顶边框 → 几何缩到 [3 5]；框判 EMPTY
[M2 绿侧 · 真树（顶边框=最高候选）]
      geometry=[1 5] / verdict=idle-read=NOT-EMPTY rc=1
  ok    M2 绿：真树几何 [1 5]；真树判忙（框线是内容）
```

**M3 · 只改 `box-judge.sh`（让两处判据分叉）→ 同源断言红**

```
[M3 红侧 · scratch 只改 box-judge.sh（第二份老提取）]
      box_text=[ HUMAN-P74-ONE-LINE-DRAFT]     ← 生产提取（outbox.sh 未动）读得出草稿
      verdict=idle-read=EMPTY rc=0             ← 帧判定说空 → 分叉
  ok    M3 红：生产提取仍读得出草稿（outbox.sh 未动）；帧判定说 EMPTY（分叉成立）
[M3 绿侧 · 真树（两处同源，逐字一致）]
      box_text=[ HUMAN-P74-ONE-LINE-DRAFT] / verdict=idle-read=NOT-EMPTY rc=1
  ok    M3 绿：真树两处都读出草稿（box_text 与 verdict 同向）；真树帧判定 NOT-EMPTY（无分叉）
  ok    60 变异全在 /tmp scratch：实现目录 skills/teamsmith git status 干净
```

## 四、隔离与安全（本包自己）

- 一切 tmux 调用经 PATH shim → `/usr/bin/tmux -L p74pkg-<pid>`，`TMUX`/`TMUX_PANE` 清空、
  `TMUX_TMPDIR` 指向已 `mkdir -p` 的私有目录（memory #1250 的两个回落陷阱都堵住）；
  破坏性命令（kill-server/kill-session）只打自己的 socket；默认 server 只做只读 `tmux ls`。
- 包运行前后默认 server 的会话列表不变（`<peer>`/`<crm-project>`/`do`/`teamsmith` 四会话仍在）；
  未触碰 `teamsmith` 会话。
- 真实仓库 `docs/team/inbox/**` + `.pi/team/state/**`（去 `bg/`，那是后台作业日志）前后逐文件 sha256 相同（§40④）。
- 继承的 `TEAM_*` 身份与 `TEAM_REVIEW_*` 旋钮全部清掉；夹具仓库/会话名 `p74*`；`team paths`
  证明 main_root 落在 `/tmp/p74pkg.*/fx`。

## 五、门禁

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 26 passed, 0 failed (26 items)                                        # rc=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2430  ✗ 0
smoke 全绿                                                                    # rc=0（约 10 分钟，机器上有别的门禁在跑）

$ bash skills/teamsmith/tests/smoke.sh </dev/null        # 全量（logs/full-smoke.log；排队后实跑约 39 分钟）
== 结果 ==  ✓ 3074  ✗ 0
smoke 全绿                                                                    # rc=0（FULL_RC=0）

# 本轮两条已知红都已翻绿：
  ✓ 12b-j 隔离：调用方项目的 inbox/state 里没有夹具痕迹
  ✓ 12b-j 负对照：栽进去的夹具痕迹必须被同一个扫描揪出来
  ✓ 40 lint 干净：检查了 10 个 mktemp -d 根模板
# 42 节（P67）在全量模式下逐条 ✓（含真 pane 拒绝 + say/draft 只排队、keylog 零行）

$ bash skills/teamsmith/tests/pm-box-real.sh --idle-secs 2   # 真 pi（0.87.0）
  verdict=EMPTY state=EMPTY / M45 idle-read=EMPTY ok / box_rows=[1||26|]
  ... 投递后 box_rows=[3|…|24|2|…|25|1|…|26|]（边框邻行读作内容）→ HOLDS_ONLY=yes RETRACT=ok
  ✓ 隔离自检：夹具 session 不在真实默认 server 上
  ✓ trust store 未变（sha256=228edb30…c97c5）                                  # rc=0
```

brief 提到的两条已知红（`12b-j` 审计日志毒化 P73、`40 lint`）本轮 **没有出现**：FAST ✓2430 ✗0、
全量 ✓3074 ✗0（两条都翻绿，见 `logs/full-smoke.log`）；`openspec` 26/26。
全量那次因为机器上同时有四套门禁在排队（持有者 dev3 的全量 smoke；协议里的 gate lock），
本套排队后实跑，共消耗 2361s；结果如上——门禁全绿。

## 六、发现与归属（F1–F3：都不是本 change 引入的缺陷；F1 建议开跟进 change）

### F1 · 草稿自画的**整行框线在光标下方**时被当下边框 → 框被截短 → 判 EMPTY（同族未列名的洞）

形状（`pkg/20-border.sh` 20h/20h2，全部自造帧）：

```
row1 ────────(120)        真上边框
row2 (blank)              光标
row3 ────────(120)        草稿自己画的整行框线
row4  draft text below    草稿正文
row5 ────────(120)        真下边框
```

实测：`geometry=[1 3]`（把 row3 当下边框）、`box_text=[]`、`verdict=idle-read=EMPTY rc=0`
—— 光标下方的草稿文字在定位框之外，守卫会判空并往里贴 payload。形状 `row1/row2/row3/row4`
（草稿只有一条整行框线）同样 `EMPTY`。

- **归属**：不是本 change 引入 —— 同一帧在修前树（`baca95ee^`，用 `git archive` 取的对照树）得到
  同样的 `geometry=[1 3]` / `EMPTY`（`logs/pkg-20.log` 的 `BASE(baca95ee^)` 行）。P67 的 diff 只动了
  `outbox.sh` 的提取段（单 hunk），没有动 `_team_box_geometry`。
- **与 apply 自述矛盾**：P67 的提交信息写「the bottom-most candidate wins when several qualify」，
  但实现是「光标下方**最近**的整行 ─ 优先」（`_team_box_geometry` 的 `B[1]`…`break`）。这句话与代码不符。
- **规格现状**：delta 只规定「顶边框取**最高**候选」（V9-A4/A5/A8/A10），对下边框的多个候选没有规定；
  `troubleshooting.md` §3 把「equal-width draft rules」列为已修，但没有列这个形状。
- **建议**：开一条跟进 change（例如 `bottom-border-candidate-selection`），下边框候选取「光标下方的
  **最靠下**合格整行 ─」（或等价地：当选中的下边框与顶边框之间没有任何非空内容、而其下方有内容时继续
  向下找）——方向是保守（框更大 → BUSY），与 V9 族「宁忙不粘」一致。**本 change 的 delta 不含它**，
  所以不阻断本次 verify；但 brief 第 2 项的字面（见 F2）正指向这里，请 PM 裁定。

### F2 · brief 第 2 项的措辞与 delta 规格相反（顶边框 = 最高候选；spinner 可作顶边框）

- brief 写：「顶边框取**最靠下**的候选」「spinner 形状行**不作**候选」。
- delta 规格（base 已存在、本 change 未改）写：`the top border is the HIGHEST qualifying row above the
  bottom border, never the nearest one`；顶边框候选 = 等宽整行 ─ **或** spinner 形态（tier2）；
  只有 0.85.1 的 braille 工作行（` ⠋ Blanching…`）明确不可作边框（V9-D2）。
- 实现与 delta 一致（20a/20d 绿）；按 brief 字面会把正确实现判红。brief 括号里的意图
  （「草稿自画的等宽分隔线不许冒充边框」）只有「最高候选」能满足 —— **建议 PM 校正 brief/复验清单措辞**；
  若 PM 的真实意图是 F1 的「下边框取最靠下」，那是 delta 缺一条 requirement（需要新 change），
  而不是本实现违反了现有规格。

### F3 · 已声明残余 F2（overlay 谓词 vs 框内弹窗措辞）——跨 change，本 change 不修

`pkg/50-overlay.sh` 50d：自造帧里框内草稿恰好包含弹窗三组标记（`Trust project folder?` /
`Do not trust` / `navigate … enter select`）时，帧级判定给 `overlay=trust-prompt rc=0`
（夹具因此不投递）。这正是 design §5 点名的残余，归属未归档的 `trust-prompt-and-fixtures`
（`verification` 承诺），本 change 的 delta 不含它；生产守卫不读 overlay 谓词（真 pane 路径
框里有字一律 BUSY 排队），所以红线不受影响。**仅记录，不需要本 change 返工。**

## 七、决策与偏差

- brief 第 2 项的「顶边框取最靠下/spinner 不作候选」与 delta 规格相反：我按 **delta 规格**判
  （规格是 change 的验收来源；brief 的括号意图也支持「最高」），并把冲突作为 F2 交回 PM；
  `20h/20h2` 的洞按 brief 的真实关注点（草稿自画分隔线不许冒充边框）单独取证并归为 F1。
- brief 第 7 项的「`pm-box-real.sh` 三态」我按三种状态各取证：空框 EMPTY（真 pi 端到端，
  `logs/pm-box-real-realpi.log`）、单行草稿 NOT-EMPTY（真 pane 拒绝，§40①）、覆盖层 overlay（§50a/b/c）。
- 本任务只写 `docs/team/reports/P74-dev2{,.md}/**`；没有改任何实现文件（变异全在 `/tmp` 副本）。
  local 模式：不 push，分支 `task/P74-p74` 留在 `.worktrees/dev2`，PM 复验后本地合并。

## 八、建议下一步（给 PM）

1. **裁定 F2**：校正 P74 brief（以及后续同类 verify 清单）里「顶边框取最靠下/spinner 不作候选」的措辞；
   若本意是 F1 的形状，请按下面的跟进 change 处理。
2. **开 F1 跟进 change**（`bottom-border-candidate-selection`，建议 apply 换人）：把「下边框候选」写进
   `delivery-guard` 的 requirement + 两个 scenario（光标上方有自己的整行框线；框线下方有草稿正文），
   并修 `_team_box_geometry`；同时订正 P67 提交信息里「bottom-most candidate wins」的自述。
3. **archive 门**：本 change 的 delta/验收无返工项；按流程等独立验证（本报告）**与用户确认**后再由 PM archive。
   F1/F3 各自归属自己的 change，不占本 change 的门。
