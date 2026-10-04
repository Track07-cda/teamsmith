# M24 · PM 空闲时空框仍 draft-race + 收回零成功：投递守卫误判调查

agent: dev2   status: DELIVERED   time: 2026-09-18T02:10:00Z
branch: `task/M24-pm-draft-race`（从干净 main 切）   PR/MR: -（本仓库 local 模式，分支留本地，PM 复验后本地合并）

## Context / 结论一句话

**根因是两个都成立的缺陷，互相掩盖**：

1. **判据只认一半的折叠形状**：真实 pi 0.85.1 折叠粘贴有**两条**路径 —— 行数多用
   `[paste #N +K lines]`（M17 已处理），**行数少、字符多用 `[paste #N <chars> chars]`**
   （`chars` = 字符/码点，不是字节）。旧代码只认第一条 → 把我们**自己刚打进去的**粘贴读成
   「框里混了别人的字」→ 不按 Enter → rc 3 → 条目终态 `draft-raced-left`、消息留在框里。
2. **收回键序在真实 pi 上根本不清框**：M17 用的 `ctrl+a` + `ctrl+k` 是按**假 TUI 的（错误）键位
   模型**写的；真实 pi 上这两个键不清行（实测：3 行展开的粘贴按 24 对 C-a/C-k，只掉最后一行、
   另两行留在框里）。所以「已收回」一次都没成功过（现场 `draft-raced-left` ×3 /
   `draft-raced-retracted` ×0），残留把输入框一直占着 → 之后 28 条 pulse nudge 全部 `expired-ttl`
   （整夜堵死）。

两条都在**真实 pi 窗格**上复现（`tests/pm-box-real.sh`，本机 pi v0.85.1），不是推理。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/outbox.sh` | ① `team_box_text_holds_only` 认第二条折叠（`[paste #N <chars> chars]`，字符数必须**精确相等**）；`team_box_mid_render` 认它的半成品；`team_transcript_mentions` 也数这种气泡。② 新增 `team_text_chars`（UTF-8 下按码点计数，与 pi 同口径）。③ `team_tmux_retract <target> <payload>` 重写：`ctrl+u` 逐行清 + 每步回读 + 清理前先判「还是我们的」；`ctrl+u` 无进展才补**一记** `ctrl+c`（且必须是刚读到框非空时） |
| `skills/teamsmith/tests/pm-box-real.sh`（新） | **真实 pi 窗格**体检夹具：空闲空框 / 粘贴后 / 收回，打印原始帧 + 守卫判定（机器可读 `HOLDS_ONLY=`/`RETRACT=`/`BOX_AFTER=`）；只用私有 socket，结尾断言自己的 session 没出现在调用者的默认 server 上 |
| `skills/teamsmith/tests/fake-tui.py` | 键位模型按实测**改正**：`C-a`/`C-k` 变空操作（回退到旧键序会在门禁里现形）、`C-u` 保持真实语义、`C-c` 非空清空 / 空框退出（危险语义保留）；新增 `FAKE_TUI_CHARS_MARKER`（第二条折叠）、`FAKE_TUI_KEY_LOG`（键审计）、`FAKE_TUI_BREAK_CTRL_U`（测升级路径） |
| `skills/teamsmith/tests/smoke.sh` | 新增 `12b-h0`（5 条纯函数判据，含反向对照，FAST 也跑）、`12b-h ⑱d`（char 折叠端到端投递）、`12b-h ⑲a-c`（收回键序/键审计/升级只补一记）、`12b-h1`（真 pi 体检，`TEAM_SMOKE_REAL_PI=1` 时跑） |
| `docs/team/reports/M24-dev2/pkg/run.sh` | 独立复验入口（一条命令）：`bash docs/team/reports/M24-dev2/pkg/run.sh [--with-real-pi]` → 判据级翻转 + 真实现场体检（`flip.sh` 是它的实现） |

## 逐条回答任务书的三个怀疑方向（都实测）

| 怀疑 | 结论 | 证据 |
|---|---|---|
| ① 空闲输入的占位符/状态栏/光标行被读成「有内容」或「混了别人的字」 | **证伪**。真实空闲 pi 窗格：框内容行全空，`verdict=EMPTY state=EMPTY`；框自带的那行 chrome（` deepseek-flash  Deepseek  max`）位置在 OFFSET==1，早就被几何规则排除 | `pm-box-real.sh` 的「空闲空框」段：`box_rows=[4||21|3||22|2||23|1| deepseek-flash…|24|]`、`box_text=[|]` |
| ② draft-race 判定窗口期：粘贴发起时的快照 vs 复检快照，TUI 自己的重绘把「只有我们的 payload」误判成 race | **部分证实（但不是「重绘」而是「形状不认识」）**。复检的判据落点没问题（payload 逐字出现即 break / 连续两拍相同才算停）；错的是**判据认不出 char 折叠形态** → `team_box_holds_only` 返回 1 | `flip.sh --with-real-pi`：同一份粘贴，旧代码 `HOLDS_ONLY=no`、新代码 `HOLDS_ONLY=yes`；框里就是 `[paste #1 1504 chars]` |
| ③ 收回函数 `team_tmux_retract` 的清键序列在真实 pi 编辑器的实际效果 | **证伪（旧键序无效）**。实测：`C-k` 不删到行尾、`C-a` 也不是「到行首」（假 TUI 模型写错了）；3 行展开粘贴按 24 对 C-a/C-k → 只掉最后一行，`RETRACT=failed` + 框里留 2 行。**真实有效的是 `C-u`（逐行删到行首）** 与 `C-c`（一次性清空，但空框上会退出 pi） | `pm-box-real.sh` 输出 `RETRACT=failed`、`BOX_AFTER=[第1行…第2行…|]`（旧）vs `RETRACT=ok`、`BOX_AFTER=[|]`（新） |
| ④（PM 追加）复现「空闲整夜」形状 | 空闲越久形状越**稳定**（不出现自发占位符/倒计时）→ 误判与「空框」无关，问题在检测器本身（方向 ①②③ 的结论一致） | `--idle-secs` 参数可拉长；本次实验跑到 6s 与 4s 两种，帧一致 |

## 现场事故链（用数据对上）

```
HOLDING.log：draft-raced-left ×3（09:10Z / 10:51Z / 18:08Z）· draft-raced ×2 · unconfirmed ×1 · expired-ttl ×445
             draft-raced-retracted ×0   ← 「已收回」从来没有发生过（M17 的键序在真实 pi 上无效）
```
链条：抢到队列 → 框 EMPTY ✓ → 粘贴（长摘要，字符多）→ 真实 pi 折成 `[paste #N <chars> chars]` →
旧判据不认 → 「混了别人的字」→ 不按 Enter → **收回**（C-a/C-k 无效，留残行）→ rc 3 → `draft-raced-left` →
框被残行占住 → 之后所有 nudge/敲门进 box-BUSY 分支 → `expired-ttl`（整夜）✓ 与现场完全一致。

## 修复

1. **判据**：`team_box_text_holds_only` 增加 char 折叠分支；**只有字符数与 payload 精确相等才算我们的**
   （人的粘贴字符数不同 → 仍然 `not ours`，判定力不降 —— 有反向断言钉住）。`team_box_mid_render`
   认半成品 `[paste #2 100`；`team_transcript_mentions` 也认同形气泡（提交确认路径）。
2. **收回**（`team_tmux_retract <target> <payload>`）：
   - 每步之前先判「还是我们的」（完整 payload / 折叠占位符 / payload 前缀 = 逐行删到一半），
     不是就**立即停手**并返回 1（红线「框里混了人的字一个键都不碰」原样保留；字留在框里，条目进
     held/ 可见）；
   - `ctrl+u` 一次一行 + 每步回读，框空即返回（幂等：空框不发键）；
   - `ctrl+u` 连续三拍无进展 → 补**一记** `ctrl+c`（仅在刚读到框非空时；空框上按 C-c 会退出 pi，
     所以全程最多一次、发完立刻回读）。
3. **夹具不再说谎**：假 TUI 的键位模型按实测改正（旧键序在门禁里会红）+ 键审计日志。

## Verification evidence (must have actually been run)

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
Totals: 13 passed, 0 failed (13 items)
== 结果 ==  ✓ 1864  ✗ 0
smoke 全绿
== 结果 ==  ✓ 1438  ✗ 0          ← 同一条链里的 TEAM_SMOKE_FAST=1（见下）
smoke 全绿

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1438  ✗ 0
smoke 全绿
FAST 模式：跳过 18 个真进程段落（…）

（上面是最终树 `3570a7f` 上的重跑；同一批断言在交付过程中跑到过 ✓1865/✗0 与 ✓1867/✗0 ——
±1 的差异来自条件断言的跳过（本机 tmux/python/pi 探测），全部为绿。）
```
新增断言（M24 段）：`12b-h0` 5 条 + `12b-h ⑱d` 4 条 + `12b-h ⑲a-c` 7 条 = 16 条常驻；`12b-h1`（真 pi，需 `TEAM_SMOKE_REAL_PI=1`）3 条。

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
（同上：链里第三段就是它；单独跑的数字 1438）
```

真实 pi 窗格（本机 pi v0.85.1，`tests/pm-box-real.sh`；只用私有 socket）：
```
```
$ bash tests/pm-box-real.sh --idle-secs 4 --payload "$(5 行 × 300 字符)"
· 输入框已画出，空闲 4s（复现「PM 空闲」形状）…
--- 空闲空框（真实 pi） ---
        22	
        23	
        24	 deepseek-flash  Deepseek  max
        25	──────────────────────────────────────────────────────────────────────────────
HOLDS_ONLY=yes MID_RENDER=no RETRACT_SAFE=yes
RETRACT=ok
BOX_AFTER=[|]
✓ 隔离自检：夹具 session 不在真实默认 server 上

$ TEAM_SMOKE_FAST=1 TEAM_SMOKE_REAL_PI=1 bash tests/smoke.sh     # FAST 契约：真进程段不跑
  · （TEAM_SMOKE_REAL_PI=1 在 FAST 下不跑：真 pi 属真进程段落；完整门禁会跑）
== 结果 ==  ✓ 1438  ✗ 0
smoke 全绿

$ TEAM_SMOKE_REAL_PI=1 bash tests/smoke.sh                       # 完整门禁带真 pi 体检
  ✓ M24 真实 pi 窗格：体检跑完（空闲/粘贴/收回，见 <tmp>/m24-realbox.log）
  ✓ M24 真实 pi 窗格：收回在真实 pi 上成功
  ✓ M24 真实 pi 窗格：没有收回失败
== 结果 ==  ✓ 1867  ✗ 0
smoke 全绿
```

`pm-box-real.sh` 打印的原始帧（旧代码同一形状）：框里是展开的多行 → 收回失败留残行；char 折叠那组
见下面的翻转证据 ②。
```

`TEAM_SMOKE_REAL_PI=1` 时门禁里也会跑这段体检（断言 `RETRACT=ok`、没有 `RETRACT=failed`）。

## Flip evidence (required for defect-fix tasks)

**① 判据级（`bash docs/team/reports/M24-dev2/pkg/flip.sh`，不需要 tmux/真 pi）**：

```
== 判据级：旧代码（a73d92a 的 outbox.sh）==
  RED char 折叠（真实 pi 第二条路径） no（期望 yes）
  ok  字符数对不上                 no
  RED chars 数的是字符（中文 12 字） no（期望 yes）
  ok  chars 不是字节（中文 36 字节） no
  ok  行数折叠（老形状不回归） yes
== 判据级：修复后的代码（本工作树）==   → 5 条全 ok
  ok 旧代码有 2 条判据红 · ok 修复后的代码 5 条判据全绿
```

**② 现场级（`bash docs/team/reports/M24-dev2/pkg/flip.sh --with-real-pi`）** —— 同一台机器、
同一个真实 pi、两种 payload 形状，旧/新代码各跑一次：

```
  旧代码  展开3行  HOLDS_ONLY=yes RETRACT=failed     守卫看到的框：[第1行：alpha第2行：beta第3行：gamma|]
  旧代码  char折叠 HOLDS_ONLY=no  RETRACT=ok         守卫看到的框：[[paste #1 1504 chars]|]   ← 我们的粘贴被判成别人的
  修复后  展开3行  HOLDS_ONLY=yes RETRACT=ok         守卫看到的框：[第1行：alpha第2行：beta第3行：gamma|]
  修复后  char折叠 HOLDS_ONLY=yes RETRACT=ok         守卫看到的框：[[paste #1 1504 chars]|]
== 结果 == 翻转成立（旧红 → 新绿）
```

**③ 残留分档从 0 变成有**（门禁里的断言，来自 12b-h ⑲）：
```
✓ 12b-h ⑲a M24：收回成功 → draft-raced-retracted（M17 之后第一次真的有「已收回」）
✓ 12b-h ⑲b M24：收口用的是 C-u（真实 pi 上确实有效的逐行清框键）
✓ 12b-h ⑲b M24：C-u 有效时不补 C-c（空框上按 C-c 会退出 pi）
✓ 12b-h ⑲c M24：C-u 不动 → 升级清理后仍算「已收回」（C-c 全程只补一记）
```
旧代码在同一段上红：⑲a（收不回、`draft-raced-left`）、⑲b/⑲c（键审计不符）—— 见
`tests/fake-tui.py` 的键位模型改正说明；`flip.sh` 的 ② 用真 pi 复现了同一对比。

## Decisions and deviations

- **不回退红线**：draft-raced/unconfirmed 仍是终态、绝不重贴；「框里有人的字就一个键都不碰」不变
  （收回循环每步都重新确认「还是我们的」才继续）。C-c 升级被三重约束（框刚读到非空、只有我们、
  最多一次），并在门禁里用假 TUI 的「空框 C-c = 退出」语义钉死不许连发。
- **判定力不降**：char 折叠只认字符数**精确相等**——有反向断言（305 vs 304、字节数 vs 字符数）。
- **加了字符计数助手**而不是复用 `wc -c`：pi 报的是**码点**（3×400 中文字 = 3602 字节 → `1202 chars`），
  计数强制在 UTF-8 locale 下做（调用方可能是 `LC_ALL=C` 的夹具）。
- **真实 pi 体检默认不进门禁**（`TEAM_SMOKE_REAL_PI=1` 才跑）：它要用使用者的 pi 配置（`--no-session`
  不写会话文件，但会加载扩展），不适合塞进每一条门禁；单独命令一次即可复现（brief 的验收要求已满足）。
- **没动 `references/**`**（M24 边界写明只允许 lib/ + tests/ + 报告）。但 `references/troubleshooting.md` §3
  里关于「收回键序/投递守卫」的说明现在**过时**（它按 M17 的 C-a/C-k 描述）→ 见下 BLOCKED。

## BLOCKED / 交回 PM

1. **`references/troubleshooting.md` §3 + `references/protocol.md:64` 需要更新**（PM 目录，M24 边界外）：
   要写「pi 的两条折叠路径」「收回用 C-u（逐行）/ C-c（一记，空框禁用）」以及「真 pi 体检怎么跑」。
2. 事故复盘里提到的 `M23` 遗留请求（默认 tmux server 死亡那次的实验形状分析与 165 红证据）已在
   M23 的报告/提交里给出（该分支已合并）——本任务不重复。

## Risks / not verified

- **只在本机 pi v0.85.1 上实测**。pi 升级后折叠词形或键位可能再变：`pm-box-real.sh` 是那条形状的
  体检入口（`HOLDS_ONLY=`/`RETRACT=` 会直接报出来），建议 pi 升级后跑一次。
- **未复现 1800s 卡死那类并发问题**（与 M23 无关，本任务不涉及）。
- 折叠阈值（约 1000 字符）只用于**构造测试数据**，产品代码不依赖阈值（两种形状都认）✓。
- `team_text_chars` 在没有任何 UTF-8 locale 的机器上退回当前 locale 的 `wc -m`（此时 CJK 会按字节算 →
  char 折叠判据对 CJK payload 会保守地判「不是我们的」→ 走安全侧：不按 Enter、进 held，不会粘连）✓。

## Suggested next steps

- 把 `tests/pm-box-real.sh` 也接到发布前的手工清单（或 CI 的可选 job）里，作为「pi 形状变化」的哨兵。
- `references/troubleshooting.md` 的更新（见 BLOCKED）建议在 PM 合并本任务后一起做。
