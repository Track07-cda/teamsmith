# M45 · pi 的「有新版本」横幅把输入框判据读成 BUSY

agent: dev2   status: done   time: 2026-09-20
branch: `task/M45-pi-busy`   PR/MR: -（本仓库 local 模式，分支留在 `.worktrees/dev2`，未 push）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/outbox.sh` | **判据层**：`_team_box_banner_rows` 标出 pi 的更新横幅块，`_team_box_geometry` 几何扫描整块跳过（两遍：跳完找不出框就退回不跳的保守行为）；`team_transcript_text` 同样排除横幅行；抽出纯帧入口 `_team_box_rows_of_frame`（真帧夹具与真 pane 走同一条实现） |
| `skills/teamsmith/tests/frames/pi-0.85.1-update-banner.txt` · `README.md` | 真实现场帧（真 pi 0.85.1 在私有 socket 上实拍）+ 来历、光标行、复现命令 |
| `skills/teamsmith/tests/pm-box-real.sh` | **现场断言**：**不关** pi 的更新检查（用户指令）；打印 `banner=present\|absent`、`banner_rows=[…]`、`M45 idle-read=EMPTY\|NOT-EMPTY`；空闲帧读成 BUSY 时夹具自己非 0 退出；`M45_REQUIRE_BANNER=1` 要求这轮真的有横幅（证据轮次用，避免拿无横幅的帧冒充现场证据） |
| `skills/teamsmith/tests/fake-tui.py` | `FAKE_TUI_BANNER=pi\|note\|packages\|both`：按真实现场帧在框上方画横幅（note 变体带任意 markdown release note） |
| `skills/teamsmith/tests/smoke.sh` | 12b-h0b（纯函数，**FAST 照跑**：真帧 + 合成帧 + 对抗帧 + 破坏实现翻转）；12b-h ⑳（真 pane：横幅+空框照样投、横幅+真草稿仍读成真草稿）；新增 `assert_not_echo()` |
| `skills/teamsmith/tests/flip-m45.sh` | 独立翻转包：红（分叉点实现）→ 绿（本树）→ 变异红（横幅识别清空），两条路径（真帧 + 真 pane） |
| `skills/teamsmith/references/troubleshooting.md` | 新增 §21：症状 / 根因 / 处置（`PI_SKIP_VERSION_CHECK=1`、`PI_OFFLINE=1` 的差别）/ 诚实边界 |
| `docs/team/reports/M45-dev2/pkg/**` | 可复现证据包：`lib.sh` / `10-frame-flip.sh` / `20-repo-tests.sh` / `30-container-red-green.sh` / `run.sh` + 原始日志 |

提交（本分支，trailer `Agent: dev2`）：

| 提交 | 内容 |
|---|---|
| `605d359` | fix(outbox)：横幅块识别 + 几何跳过（+ 真帧夹具 `tests/frames/`） |
| `41bbb9a` | test(M45)：现场断言夹具、fake-tui 横幅、smoke 12b-h0b/⑳、troubleshooting §21 |
| `4f4f7b7` | test(M45)：翻转包 flip-m45.sh（红→绿→变异红） |
| `569dca8` | test(M45)：12b-h ⑳ 打到正确窗口 + 用守卫读框内容断言（全量门禁抓到的三处断言写错；实现没错） |
| `3a0b9c7` | test(M45)：按用户指令**不关** pi 的更新检查 —— 夹具在真横幅现场断言（`M45_REQUIRE_BANNER=1`） |

## 1. 根因（实测，不是推断）

### 1.1 现场帧（真 pi 0.85.1，私有 socket，pane 120×30，空闲 25s）

```
    11	──────────────────────────────────────────── (120 × ─)
    12	 Package Updates Available
    13	 Package updates are available. Run pi update --extensions
    14	 Packages:
    15	 - pi-web-access
    16	────────────────────────────────────────────
    17	
    18	────────────────────────────────────────────
    19	 Update Available
    20	 New version 0.86.0 is available. Run pi update
    21	 Changelog: https://pi.dev/changelog
    22	────────────────────────────────────────────
    23	
    24	────────────────────────────────────────────   ← 输入框的上边框
    25	
    26	
    27	
    28	 deepseek-flash  Deepseek  max              ← 框自带的提示行（在框内，OFFSET==1）
    29	────────────────────────────────────────────   ← 输入框的下边框
    30	 proj | mc: 0 (0%) · idle …                 ← 状态行
```

光标行 `#{cursor_y}=25`（0-based）→ 1-based 第 26 行（框内内容行）。
帧本体：`skills/teamsmith/tests/frames/pi-0.85.1-update-banner.txt`（1–9 行是与判据无关的启动输出，已置空，
**行号与实拍一致**）。复现：`bash skills/teamsmith/tests/pm-box-real.sh --idle-secs 25`。

pi 侧来源（0.85.1 安装包，供核对）：`dist/modes/interactive/interactive-mode.js` 的
`showNewVersionNotification()`（`Update Available` + `New version ${version} is available. Run pi update` +
`Changelog: <url>`，上下各一条 `DynamicBorder`）与 `showPackageUpdateNotification()`
（`Package Updates Available` / `Packages:` / `- <pkg>`）；`DynamicBorder.render()` 画的就是
`"─".repeat(width)` —— **与输入框边框逐字节同形等宽**（实测每行 360 字节 = 120 个 `─`）。

### 1.2 判据在哪一步被带偏

`_team_box_geometry`（唯一几何实现）= 「光标下方最近一条整行 `─` 是下边框；再向上取**最高**的一条等宽
整行 `─` 当上边框」。取最高是 V9 的**故意**选择（草稿自己画的等宽框线要留在框内 → BUSY，永不粘连）；
而横幅的两条 `DynamicBorder` 正好是等宽整行 `─`，所以最高的一条变成了**横幅的上界 11**：

```
$ bash docs/team/reports/M45-dev2/pkg/10-frame-flip.sh          # 修前的实现 + 真帧（§10）
  红：geometry=[11 29] box_nows=[PackageUpdatesAvailable…UpdateAvailable…Changelog:https://pi.dev/changelog──…──]
  绿：geometry=[24 29] box_nows=[]
```
修前 `_team_box_geometry 26` 给出的框是 **11..29**：框内内容 = 两条横幅的文字 + 它们自己的
DynamicBorder 行 + 输入框自己的上边框（第 24 行）→ 非空 → BUSY。

所以被带偏的**不是折叠/占位符判据，而是几何**：框被算大，框内的「内容」= 横幅文字 + 框自己的上边框。
后果与 brief 一致：`team_input_box_text` 非空 → `team_input_box_state=BUSY` → 投递守卫把「空闲」读成
「有草稿」→ 通知排队/held（M17/M24/M30 一路在治的病的同一族），`RETRACT` 也无从下手
（`box_text` 里混着横幅 → `holds_only=no`）。

## 2. 修法（判据层 + 现场断言）

### 2.1 判据层（窄且可测）——真正的修法

`_team_box_banner_rows` 只认**块界与两行配对头**，块内文字（release note 是任意 markdown）一概不看内容：

* 开界：整行 `─`（在光标上方）；
* 紧随两行必须是配对头之一 —— `Update Available` + `New version <ver> is available. Run …`，
  或 `Package Updates Available` + `Package updates are available. Run …`；
* 闭界：开界之后第一条**等宽**整行 `─`，且紧贴它上面那行是本横幅的固定尾行（`Changelog: <url>`；
  包横幅是 `Packages:` 之后的 `- <pkg>`）—— 这条要求是为了不被 note 里 markdown 的 `---`
  （pane 宽 ≤ 80 时也是等宽整行 `─`）骗到；
* 块整体在光标上方。

命中后几何扫描**跳过这些行**（不是改成「最近优先」—— V9 的保守方向一个字没改）；`team_transcript_text`
也排除这些行（否则引用了横幅原文的 payload 会在「提交证据」的基线里假命中）。
**两遍回退**：若跳过横幅后连一个框都找不出来（可以构造的对抗形状：草稿自己就是「整行 ─ + 两行头 + 尾行 +
整行 ─」，而框的上边框被当成开界），就退回**不跳**的保守行为 —— 绝不退成 `NONE`，因为
`NONE → UNKNOWN → 守卫不生效 → 往人的草稿上白打字`（D20 的形状）。这一条有专门的对抗帧夹具（见 3.2 的对抗帧①/②）。

### 2.2 「环境层」的结论：**不用开关**（用户指令）

brief 让我先查 pi 有没有关更新检查的开关，有就用。开关确实有，而且两个都实测有效：

| 开关 | 关掉什么 | 怎么验的 |
|---|---|---|
| `PI_SKIP_VERSION_CHECK=1`（`docs/settings.md`；源码 `checkForNewPiVersion()` 直接读它） | 只关 **pi 版本**检查 | 本机真 pi：加它之后 `banner=absent`（版本横幅消失），扩展包横幅仍在 |
| `--offline` / `PI_OFFLINE=1`（`PI_OFFLINE` 会连带设 `PI_SKIP_VERSION_CHECK`） | 全部启动期网络操作，含**扩展包**更新检查 | PM 实测有效（转达）；本机也实测：`PI_OFFLINE=1 bash tests/pm-box-real.sh --idle-secs 20` → `banner=absent`、`banner_rows=[]`、`EMPTY`/`RETRACT=ok`（rc=0） |

**但用户随后点名作废了这条路**（PM 转达 2026-09-20T01:34:57Z：「不要关 pi 的更新检查（`PI_OFFLINE`
作废）—— 改判据层，让它容忍横幅；夹具用带横幅的现场断言」）。所以：

- 判据层照旧（§2.1）——**它才是解决方案**，横幅在不在场都能读对；
- `pm-box-real.sh` **不再**给 pi 加任何开关，更新检查照开；横幅出现与否如实打印（`banner=…`），
  空闲帧的 `EMPTY` 断言就落在这个真实帧上；
- 证据轮次用 `M45_REQUIRE_BANNER=1` 把「这轮真的有横幅」变成硬断言（没横幅就红），
  这样「绿」不会来自一个碰巧没有横幅的帧；
- 门禁本身不硬要求横幅（否则会跟着 pi 的发布节奏/网络变红）——横幅形状由 12b-h0b / 12b-h ⑳
  的合成帧与真 pane 夹具常驻覆盖，容器体检的横幅状态只打一行说明。

## 3. Verification evidence（全部实际跑过）

> 下面这些数字都是在**交付代码的 HEAD `3a0b9c7`** 上重跑得到的（工作树干净，`git status` 无输出；
> 其后只有报告文档提交）。

### 3.1 门禁（brief 的验收命令）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 14 passed, 0 failed (14 items)

$ bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2328  ✗ 0
smoke 全绿
# 其中与本任务直接相关的三行（前两行就是 main 上连续两次红的那两行；容器这轮真有横幅）：
  ✓ M28 容器里跑真 pi 体检：输入框判据 + 收回在真实现场成立
  ✓ M28 容器里跑真 pi 体检：空闲空框被判 EMPTY（没被误判成忙）
  ✓ M45 容器体检这轮有更新横幅：EMPTY/RETRACT 是在真横幅现场上成立的

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1838  ✗ 0
smoke 全绿
```

### 3.2 M45 自己的断言（FAST smoke 12b-h0b 段节选）

```
  ✓ M45 真帧：几何落在真正的输入框上（24 29，不是横幅上界 11）
  ✓ M45 真帧：空闲空框读成空（横幅文字不是框内容）
  ✓ M45 真帧：两个横幅块的行都被认出来（11–16 包横幅 / 18–22 版本横幅）
  ✓ M45 真帧翻转（破坏实现）：几何退回横幅上界（11）—— 证明这个形状确实是老判据的错误来源
  ✓ M45 真帧翻转（破坏实现）：空框读出横幅文字（老判据的真实现场）
  ✓ M45 合成帧：横幅 + 真草稿 → 读出的仍然是**真草稿**（不是横幅）
  ✓ M45 合成帧：带横幅的真草稿仍然是「框里只有它」
  ✓ M45 对抗帧①：草稿自己像横幅块 → 仍然是框内容（BUSY，不粘连）
  ✓ M45 对抗帧②：跳过横幅后一个框都找不出来时退回保守行为（绝不退成 NONE → 守卫失效）
  ✓ M45 对照：没有横幅时几何与行为不变
```

真 pane 端到端（12b-h ⑳，非 FAST）：

```
  ✓ 12b-h ⑳ M45：带横幅的空框照样投递（没把横幅读成框内容 → 没有误判 BUSY）
  ✓ 12b-h ⑳ M45：横幅 + 真草稿 → 排队（没有粘字）
  ✓ 12b-h ⑳ M45：横幅 + 真草稿 → 零提交
  ✓ 12b-h ⑳ M45：守卫读到的框内容就是**真草稿**（横幅没被当成草稿、草稿也没被横幅吞掉）
```

### 3.3 容器体检（brief 的第三条验收命令，当前 pi 版本；更新检查**照开**）

**这一轮里真横幅就在场上**（`banner=present`，`banner_rows` 认出了行 20–24）——空闲框仍然判 `EMPTY`、
收回 `RETRACT=ok`、rc=0（"这轮有横幅"这件事也在全量门禁的 31b2 里被断言）：

```
$ bash skills/teamsmith/tests/container-tmux.sh --with-pi --cmd "bash $PWD/skills/teamsmith/tests/pm-box-real.sh --idle-secs 3" | tail -12
· banner=present（输入框上方有更新横幅：这轮的空框判据就在这个形状上受考）

--- 空闲空框（真实 pi） ---
         22	 New version 0.86.0 is available. Run pi update
         23	 Changelog: https://pi.dev/changelog
         24	────────────────────────────────────────────────────────────
         25	
         26	────────────────────────────────────────────────────────────
         27	
         28	────────────────────────────────────────────────────────────
         29	/tmp/teamsmith-pmbox.CMBmKg/proj (main)
         30	0.0%/0 (auto)                            unknown
  verdict=EMPTY state=EMPTY
  box_rows=[1||27|]
  box_text=[|]
  M45 banner_rows=[20 21 22 23 24 ]
  M45 idle-read=EMPTY ok
...
  verdict=BUSY state=BUSY
  box_rows=[3|[auto] agent:dev2 · M24 · branch:task/M24-pm-draft-race · 状态=fixture|25|2|第二行：payload 的第二行|26|1|第三行：payload 的第三行|27|]
  box_text=[[auto] agent:dev2 · M24 · branch:task/M24-pm-draft-race · 状态=fixture第二行：payload 的第二行|]
  HOLDS_ONLY=yes MID_RENDER=no RETRACT_SAFE=yes
  RETRACT=ok
  BOX_AFTER=[|]
✓ 隔离自检：夹具 session 不在真实默认 server 上
```

横幅的**判断行**：`banner_rows=[20 21 22 23 24 ]` 就是被认出来并跳过的横幅块；没有它时
（`geometry=[11 29]`，见 §4 的红）同一帧就是 `BUSY` / `RETRACT=failed`。

## 4. Flip evidence

**红 → 绿（同一份证据，两条路径；真实现场，不是推断）**

（a）本机真 pi 0.85.1，**更新检查照开**（夹具默认行为，`M45_REQUIRE_BANNER=1` 要求真有横幅）
—— 同一个窗格、同一套判据函数：

```
# 修前（分叉点 b8fab15 的实现）
  verdict=BUSY state=BUSY
  RETRACT=failed          （HOLDS_ONLY=no MID_RENDER=no RETRACT_SAFE=no）
  BOX_AFTER=[ Package Updates Available … Update Available … Changelog: … ────── ]
# 修后（本树）
  M45 banner_rows=[11 12 13 14 15 16 18 19 20 21 22 ]      ← 两个横幅块都被认出来
  verdict=EMPTY state=EMPTY
  RETRACT=ok
  BOX_AFTER=[|]
```

（b）**容器里真 pi + 真横幅**（红树在宿主上 `git archive` 到容器只读挂载的 CT_CACHE ——
link worktree 的 git 元数据在主仓库里、容器看不见，所以不能在容器内取；同一发夹具命令，只换 `M24_SKILL_DIR`）：

```
$ bash docs/team/reports/M45-dev2/pkg/30-container-red-green.sh      # 原始日志在 pkg/logs/
红：· banner=present（输入框上方有更新横幅：这轮的空框判据就在这个形状上受考）
    verdict=BUSY state=BUSY
    box_text=[ Update Available New version 0.86.0 is available. Run pi update Changelog: https://pi.dev/changelog──…── ]
    M45 idle-read=NOT-EMPTY BAD
    RETRACT=failed
    ✗ M45：空闲空框没被判成 EMPTY        （夹具 rc=1）
绿：· banner=present
    M45 banner_rows=[20 21 22 23 24 ]
    verdict=EMPTY state=EMPTY
    box_text=[|]
    M45 idle-read=EMPTY ok
    RETRACT=ok                            （夹具 rc=0）
```

（c）**破坏实现 → 守卫断言必须红**：`tests/flip-m45.sh`（独立包，真帧 + 真 pane 两条路径）
与 smoke 12b-h0b 的 `M45_NO_STRIP=1` 都同一形状 —— 把 `_team_box_banner_rows` 变成空实现，
真帧立刻回到 `geometry=[11 29]` + 读出横幅文字，真 pane 上那一发投递立刻变成
`queued for …`、零提交。

```
$ bash skills/teamsmith/tests/flip-m45.sh        # 11 项全绿；证据包 §20a 的原始日志在 pkg/logs/
  ✓ 红（修前实现）：几何落在横幅上界（geometry=[11 29]）—— 帧是真的、判据是旧的
  ✓ 红（修前实现）：空闲空框读出了横幅文字（真实现场 = BUSY）
  ✓ 绿（本树）：几何落在真正的输入框上（geometry=[24 29]）
  ✓ 绿（本树）：同一帧的空闲空框读成空（横幅不是框内容）
  ✓ 变异（横幅识别清空）：同一帧回到红 —— 守门判据不是空转扫描
  ✓ 绿（本树）：草稿自己长得像横幅块 → 仍然读成框内容（BUSY；不粘连、不退化成 NONE）
      red：send=queued for …:pane（输入框有草稿或目标没在跑）submits=0 banner=1
  ✓ red（真 pane + 横幅）：空闲框被判 BUSY → 消息排队、零提交（修前的真实行为）
      green：send=draft：已确认送达 …:pane  submits=1 banner=1
  ✓ 绿（真 pane + 横幅）：空闲框照样投出去（确认送达 + 恰好一次提交）
  ✓ 绿：提交的正文就是 payload 本身
  ✓ 绿：投递后框里没有残留（box_nows=[]）
  ✓ mut（真 pane + 横幅）：空闲框被判 BUSY → 消息排队、零提交（修前的真实行为）
== 结果 == flip 全绿（红→绿→变异红）
```

独立复现包（不依赖本报告的命令历史）：`docs/team/reports/M45-dev2/pkg/run.sh`
= `10-frame-flip.sh`（纯帧红/绿）+ `20-repo-tests.sh`（flip-m45 + FAST smoke 的 M45 段）
+ `30-container-red-green.sh`（容器红/绿，没有 podman 时 SKIP）。

## 5. Decisions and deviations

- **动了两个 OWNERSHIP 上属于 PM 的文件**：`skills/teamsmith/scripts/lib/outbox.sh`（判据层）与
  `skills/teamsmith/references/troubleshooting.md`（brief 的 Deliverables 2/4 明确要求）；
  brief 的 Boundaries 写的是「只动**判据**与夹具/文档」，本任务据此执行，没有碰投递契约、
  草稿守卫语义、收件箱格式中的任何一条（outbox.sh 的改动只在几何/转录两处判据函数内）。
  另外 OWNERSHIP 把 `tests/**` 标成 `agent:dev`，而 M45 派给 dev2 且允许改 `smoke.sh`
  —— 按 brief 执行，`smoke.sh` 只**追加**了 12b-h0b / 12b-h ⑳ 两段与一个 `assert_not_echo()` 助手，
  没有重排别人的段落。
- **只认两个横幅形态**（版本横幅 + 扩展包横幅），都按真帧定形状；`What's New`（pi 更新后首次启动画的
  同族 DynamicBorder 块）与扩展自定义消息框**没有**覆盖 —— 它们仍会把框算大 → BUSY（有界排队，
  不粘连），原因写在 troubleshooting §21 的「诚实边界」：仅凭形状无法与「草稿自己画框线」区分，
  保守方向必须选 BUSY。这一块要不要做，请 PM 定（要做就需要能渲染出该块的帧或用户点名的截图）。
- **回退设计**：跳过横幅后若几何为空则退回不跳（绝不 NONE）。这是本次实现里唯一一处「为了让判据不退化
  而加的守卫」，有对抗帧①/②两条断言钉住。
- **与 brief 的一处主动偏离（用户指令）**：brief 的 Deliverable 2 要求做「环境层」（用一个开关关掉
  pi 的更新检查）。开关确实存在并且两个都验过有效（见 §2.2 的表），但用户随后点名作废这条路
  ——夹具不做任何抑制，改由判据层容忍横幅、**夹具在真横幅现场上断言**（`M45_REQUIRE_BANNER=1`）。
  这条偏离是「用户指令 > brief」，两个开关的用法仍写进 troubleshooting §21 供用户自己选。
- 本机复现时，宿主 pi 在 0.85.1 上同时画了两个横幅（版本 + `pi-web-access` 包），所以真帧里两个形态
  都在；容器（HOME=/root，无扩展）只有版本横幅 —— 两条路径都验过。

## 6. Suggested next steps

- PM 复验建议起点：`bash docs/team/reports/M45-dev2/pkg/run.sh`（10/20 在宿主安全；30 需要 podman），
  加上 brief 的三条验收命令。
- 若日后要收掉 `What's New` 那一族：需要一个能渲染该块的现场帧（`pi update` 后首次启动，或用户截图），
  形状测量之后扩一条 header 规则即可，代价约 5 行。
- 用户侧不需要为横幅做任何事（判据层已容忍）；若只是想把提示消掉，`pi update` 即可，
  或自己选 `PI_SKIP_VERSION_CHECK=1` / `PI_OFFLINE=1`（夹具与门禁都不用它们）。
