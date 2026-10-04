# P33 · team_bg_run 的结果里带上原始命令（太长缩略）

agent: dev2   status: DONE（实现 + 夹具 + 文档 + 复验包；本地模式，未 push）
branch: `task/P33-team-bg-run`   PR/MR: -（local 模式：分支留在本地 worktree，PM 复验后本地合并）
task:   P33   phase: apply
change: -     specs: -     anchor: none (infra) — team-bg 的**工具输出文本**（显示层；作业语义/生命周期/台账一律不动）
tip:    `bd5858c`（6 个提交：实现 → 夹具 → flip → 文档 → 复验包 → 原文对照工具；本报告提交在其上）
verdict: 三段验收全绿（第一条的 runner 说明见 §5.1）+ 复验包 22 条断言 0 ✗；无 BLOCKED

## 0. 结论（一句话）

`team_bg_run` / `team_bg_wait` 的结果现在点名命令（`  cmd: <单行化、>100 码点缩略加 `…`、按码点切>`），
`details.cmd` 原样带回；用户反馈的「看不出我到底跑的是什么命令」不再成立，
而 id/pid/日志路径/台账/收割/裁剪/根解析（M27·M30）**一个字节没动**。

## 1. 交付内容（Deliverables）

| Path | What |
|---|---|
| `skills/teamsmith/extension/team-bg.ts` | `displayCmd()`（单行化 + 100 码点缩略）+ `team_bg_run`/`team_bg_wait` 三个结果文本各加 `  cmd:` 行 + `details.cmd`（原样） |
| `skills/teamsmith/tests/team-bg-harness.mjs` | S12 新增 11 条断言（短 / 长 CJK+代理对 / 多行 / 两种收割回执 / `details.cmd` 原样） |
| `skills/teamsmith/tests/team-bg-flip.sh` | 红① 改成按 base 的形状分类（P33 之前 / M30 之前 / 无扩展 / 已含修复→可见跳过）+ 红② 增 4 条 P33 定点破坏 |
| `skills/teamsmith/references/agent-adapters.md` | §3a 一句话：结果里带命令、缩略规则、`details.cmd` 原样 |
| `skills/teamsmith/references/workflows.md` | §E2 的文字记录（示例输出）补上 `cmd:` 行，避免文档漂移 |
| `docs/team/reports/P33-dev2/pkg/**` | 独立复验包（官方夹具翻转 / 自有边界探针 / 独立破坏对照）+ `dump-text.mjs` 原文对照工具 |
| `docs/team/reports/P33-dev2/logs/**` | 复验包三节的实际输出（本报告的引用来源） |

结果文本的形状：

```text
team_bg_run   → job <id> started (pid N); log: <path>
                  cmd: <单行化 + 缩略>
                Harvest it with team_bg_wait <id>.

team_bg_wait  → job <id> is still running (pid N); log: <path>        ← running 形状
                  cmd: <同一形状>

team_bg_wait  → job <id> finished exit=E after Ns; log: <path>        ← finished 形状
                  cmd: <同一形状>
                --- tail ---
                <日志尾段>
```

## 2. 缩略前后的原始文本对照

同一组命令、同一套夹具宿主，对**修复前的 revision**（`51fd26c`，P33 之前）与**当前树**各跑一遍
（`pkg/dump-text.mjs`，无断言、只打印；可用 `P33_EXT`/argv 指向任意 revision 重跑）：

**修复前**（结果里没有命令，`details.cmd` 不存在）：

```text
---- 短命令 · team_bg_run ----
  │ job dump-0 started (pid 3447778); log: <root>/.pi/team/state/bg/dump-0.log
  │ Harvest it with team_bg_wait dump-0.
  [details.cmd 原样] undefined
---- 长命令（>100 码点，含 CJK + 代理对） · team_bg_run ----
  │ job dump-1 started (pid 3447796); log: <root>/.pi/team/state/bg/dump-1.log
  │ Harvest it with team_bg_wait dump-1.
  [details.cmd 原样] undefined
---- 多行命令 · team_bg_run ----
  │ job dump-2 started (pid 3447805); log: <root>/.pi/team/state/bg/dump-2.log
  │ Harvest it with team_bg_wait dump-2.
  [details.cmd 原样] undefined
```

**当前树**（同一组命令）：

```text
---- 短命令 · team_bg_run ----
  │ job dump-0 started (pid 3438005); log: <root>/.pi/team/state/bg/dump-0.log
  │   cmd: echo P33-SHORT
  │ Harvest it with team_bg_wait dump-0.
  [details.cmd 原样] "echo P33-SHORT"
---- 短命令 · team_bg_wait（finished） ----
  │ job dump-0 finished exit=0 after 0.0s; log: <root>/.pi/team/state/bg/dump-0.log
  │   cmd: echo P33-SHORT
  │ --- tail ---
  │ P33-SHORT
---- 长命令（>100 码点，含 CJK + 代理对） · team_bg_run ----
  │ job dump-1 started (pid 3438015); log: <root>/.pi/team/state/bg/dump-1.log
  │   cmd: 命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令🚀令令令令令令令令令…
  │ Harvest it with team_bg_wait dump-1.
  [details.cmd 原样] "命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令命令🚀令令令令令令令令令令令令令令令令令令令令 DROP-ME-TAIL"
---- 多行命令 · team_bg_run ----
  │ job dump-2 started (pid 3438024); log: <root>/.pi/team/state/bg/dump-2.log
  │   cmd: echo P33-MULTI-A echo P33-MULTI-B echo P33-MULTI-C
  │ Harvest it with team_bg_wait dump-2.
  [details.cmd 原样] "echo P33-MULTI-A\necho P33-MULTI-B\t   \n    echo P33-MULTI-C"
---- 形状 ----
  长命令夹具：124 码点 / 125 UTF-16 单元
```

可见：**显示行被单行化 + 缩略**（尾部 `DROP-ME-TAIL` 消失、末尾是 `…`），而 `details.cmd`
把原始命令**逐字**保留（含 `\n` / `\t` / 尾段）。

## 3. 码点边界证据

`pkg/probe-display.mjs`（自有宿主，硬编码期望串；不复用官方夹具代码）对边界逐条打点
（原文见 `docs/team/reports/P33-dev2/logs/20-display.log`，15 条断言全过）：

```text
  ✓ exactly 100 code points are shown unchanged (no ellipsis) :: shown codepoints=100
  ✓ 101 code points are cut to the first 100 + ellipsis :: shown="命命…" codepoints=101
  ✓ 101-code-point command: details.cmd keeps all 101 code points verbatim :: codepoints=101
  ✓ astral char at position 100 survives whole (no ellipsis) :: codepoints=100
  ✓ astral char at position 101 is dropped whole (no lone surrogate) :: codepoints=101 roundtrip=true
  ✓ multiline command is single-lined (hardcoded expectation) :: "echo P33-MULTI-A echo P33-MULTI-B echo P33-MULTI-C"
  ✓ the multiline result text keeps its 3-line shape (no newline/CR/TAB leaked) :: lines=3
  ✓ finished receipt truncates the long command the same way :: "echo 命…命…"
  ✓ still-running receipt names the command :: "sleep 2; echo P33-RUNNING-DONE"
  ✓ every displayed command is unchanged by a UTF-8 write/read round trip :: displays=7
```

- 判据是「切完的串恰好 101 个码点（前 100 + `…`）」与「第 100 位是代理对 `🚀` 时整只留下」；
  官方夹具那条长命令是 124 码点 / 125 UTF-16 单元，**单元切与码点切结果不同** —— 所以 `30-break.sh` 的
  `unit-slice` 变体（`Array.from(one)` → `one.split("")`）能把它打红（见 §4.3）。
- 兼容性口径：`Array.from` 是**码点**迭代（CJK 与代理对都不会被劈开），并且探针额外要求
  「显示串经 UTF-8 写读往返不变」—— 这条直接钉住 P28 的教训（字节切会造非法 UTF-8 / U+FFFD）。

## 4. Flip evidence

三条独立证据链：官方夹具的 red→green、官方 flip 的定点破坏、复验包自己的破坏对照。
（本节所有输出都能用下面命令原样重放；`pkg` 的日志在 `docs/team/reports/P33-dev2/logs/`。）

同一套判据在**修复前**的树上红、在当前树上绿（下面 4.1 是这条的完整原文）：

```text
  ✓ 红：51fd26c 的 extension/team-bg.ts（P33 之前）→ 官方夹具非 0 退出，失败点全是 S12，例：
       TEAM-BG-CASE FAIL S12 short command is named in the result text :: (no cmd line)
       TEAM-BG-CASE FAIL S12 details.cmd is the short command verbatim :: null
  ✓ 绿：当前树的 extension/team-bg.ts → TEAM-BG-HARNESS OK（60 条用例，0 FAIL）
```

### 4.1 红（修复前）→ 绿（当前树）：官方夹具

```sh
bash docs/team/reports/P33-dev2/pkg/10-harness.sh
```

```text
  ✓ 修复前的树：51fd26ca09fa53dac0db740d93cb20c1cb890536 的 extension/team-bg.ts 不含 P33 的 displayCmd（运行时：<home>/.bun/bin/bun）
  ✓ 红：修复前的树让官方夹具非 0 退出（rc=1）
  ✓ 红：失败点正是 P33 的显示用例（结果里没有命令）
  ✓ 红：其余用例一条都没被带红（红的边界干净）
  修复前（51fd26ca09fa53dac0db740d93cb20c1cb890536）的 S12 原始输出：
    TEAM-BG-CASE FAIL S12 short command is named in the result text :: (no cmd line)
    TEAM-BG-CASE FAIL S12 details.cmd is the short command verbatim :: null
    TEAM-BG-CASE PASS S12 the named short command still runs
    TEAM-BG-CASE FAIL S12 long command is truncated at the 100th code point + ellipsis :: codepoints=6 tail="ne)"
    TEAM-BG-CASE FAIL S12 truncation drops the tail and never splits a code point (valid UTF-8) :: tail-leak=false roundtrip=true
    TEAM-BG-CASE FAIL S12 details.cmd stays verbatim (untruncated) for the long command :: codepoints=0
    TEAM-BG-CASE FAIL S12 multiline command is single-lined in the result text :: "(no cmd line)"
    TEAM-BG-CASE FAIL S12 details.cmd keeps the multiline command verbatim
    TEAM-BG-CASE PASS S12 the multiline job still runs as written (all three echoes)
    TEAM-BG-CASE FAIL S12 the harvest receipt (finished) names the command too :: (no cmd line)
    TEAM-BG-CASE FAIL S12 the harvest receipt (still running) names the command too :: (no cmd line)
  ✓ 绿：当前树的官方夹具全绿（60 条用例）
  ✓ 绿：S12 short command is named in the result text
  ✓ 绿：S12 details.cmd is the short command verbatim
  ✓ 绿：S12 the named short command still runs
  ✓ 绿：S12 long command is truncated at the 100th code point + ellipsis
  ✓ 绿：S12 truncation drops the tail and never splits a code point (valid UTF-8)
  ✓ 绿：S12 details.cmd stays verbatim (untruncated) for the long command
  ✓ 绿：S12 multiline command is single-lined in the result text
  ✓ 绿：S12 details.cmd keeps the multiline command verbatim
  ✓ 绿：S12 the multiline job still runs as written (all three echoes)
  ✓ 绿：S12 the harvest receipt (finished) names the command too
  ✓ 绿：S12 the harvest receipt (still running) names the command too
```

### 4.2 官方 flip：红① + 红②×10

```sh
bash skills/teamsmith/tests/team-bg-flip.sh
```

```text
== 红①：修复前的树里的 team-bg（M30 之前 / P33 之前 / 根本没有这个扩展） ==
  ✓ 前提成立：51fd26ca09fa53dac0db740d93cb20c1cb890536 里有 M30 之后的 team-bg.ts（P33 之前：结果里还不点命令）
  ✓ 修复前：结果里没有命令 → S12 的显示用例红 —— 缺失被夹具复现
== 红②：定点破坏（每个只改一行，各自必须红在对应用例） ==
  ✓ harvest-silent：红在「S2 harvested job never wakes the agent」
  ✓ merge-window：红在「S3 two jobs finishing together produce exactly one message」
  ✓ wake-mode：红在「S1 wake is a followUp with triggerTurn」
  ✓ ledger-format：红在「S5 settled lines report the unharvested count」
  ✓ log-cap：红在「S6 log stays under the cap」
  ✓ worktree-root：红在「S11 a worktree session writes its job log inside the worktree」
  ✓ cmd-line-drop：红在「S12 short command is named in the result text」
  ✓ cmd-raw-passthrough：红在「S12 multiline command is single-lined in the result text」
  ✓ cmd-unit-slice：红在「S12 long command is truncated at the 100th code point + ellipsis」
  ✓ cmd-wait-drop：红在「S12 the harvest receipt (still running) names the command too」
== 绿：当前树的真扩展（同一套夹具） ==
  ✓ 绿：夹具全绿（60 条用例，TEAM-BG-HARNESS OK）
  ✓ 绿：没有 FAIL 用例
  ✓ 反向守卫：夹具确认真实仓库 state/ 未被触碰
== 真 pi 加载链：notify + bg 两个 -e（零模型调用），坏扩展必须让 pi 失败 ==
  ✓ 真 pi 接受两个 -e（notify + bg）且无加载错误
  ✓ 坏扩展对照：pi 拒绝加载（rc≠0 且报出被抛的错误）

team-bg-flip：翻转已复现（红① + 红②×10 → 绿）      （FLIP_RC=0，用时 99.3s）
```

### 4.3 复验包自己的「破坏 → 守卫红 → 还原」

`pkg/30-break.sh` 只改一行生成变体（不碰主树），跑 §3 那条**自有**探针，必须红在点名的那条断言上；
跑完核对主树扩展 sha256 未变：

```text
  ✓ unit-slice：红在「astral char at position 100 survives whole (no ellipsis)」（rc=1）
        ✗ astral char at position 100 survives whole (no ellipsis) :: codepoints=101
        ✗ every displayed command is unchanged by a UTF-8 write/read round trip :: displays=7
  ✓ raw-passthrough：红在「multiline command is single-lined (hardcoded expectation)」（rc=1）
        ✗ multiline command is single-lined (hardcoded expectation) :: ""
        ✗ the multiline result text keeps its 3-line shape (no newline/CR/TAB leaked) :: lines=7
  ✓ no-ellipsis：红在「101 code points are cut to the first 100 + ellipsis」（rc=1）
        ✗ 101 code points are cut to the first 100 + ellipsis :: shown="命命命" codepoints=100
  ✓ 主树扩展未被变体实验动过（sha256 59e4226720ad… 前后一致）
== 30-break.sh 结果 ==  ✓ 4  ✗ 0  findings 0  skip 0
```

## 5. Verification evidence（实际跑过的验收命令）

### 5.1 第一条验收（runner 说明，**先看这段**）

brief 的第一条写的是 `node skills/teamsmith/tests/team-bg-harness.mjs`。本机两个问题（**都是既有的，与 P33 无关**）：

```text
$ node skills/teamsmith/tests/team-bg-harness.mjs
usage: team-bg-harness.mjs <path/to/team-bg.ts> [--keep]
rc=2                                     ← 夹具的契约一直是「必须给扩展路径」

$ node skills/teamsmith/tests/team-bg-harness.mjs skills/teamsmith/extension/team-bg.ts
TEAM-BG-CASE FAIL import :: TypeError [ERR_UNKNOWN_FILE_EXTENSION]: Unknown file extension ".ts" …
rc=1                                     ← 本机 node（v24.19.0）process.features.typescript === false

$ node -p 'process.features.typescript'
false
```

这正是 `smoke.sh` 自己探测 `TS_RUNNER`（node → bun → `$HOME/.bun/bin/bun` → tsx）的原因：
在本机它选中 `$HOME/.bun/bin/bun`，`team-bg-flip.sh` 也用同一顺序。所以我按**同一 runner**跑，
并且把**改动前的夹具**（`git show 51fd26c:skills/teamsmith/tests/team-bg-harness.mjs`）拿回来在 node 下重跑，
失败形状逐字相同（rc=2 / rc=1）——即这两条限制与 P33 无关。没有为了跑通验收去改夹具的 runner 契约。

### 5.2 三条验收命令（实际输出尾段）

```sh
$HOME/.bun/bin/bun skills/teamsmith/tests/team-bg-harness.mjs skills/teamsmith/extension/team-bg.ts
```

```text
TEAM-BG-CASE PASS S12 short command is named in the result text ::   cmd: echo P33-SHORT
TEAM-BG-CASE PASS S12 details.cmd is the short command verbatim :: "echo P33-SHORT"
TEAM-BG-CASE PASS S12 the named short command still runs
TEAM-BG-CASE PASS S12 long command is truncated at the 100th code point + ellipsis :: codepoints=101 tail="令令…"
TEAM-BG-CASE PASS S12 truncation drops the tail and never splits a code point (valid UTF-8) :: tail-leak=false roundtrip=true
TEAM-BG-CASE PASS S12 details.cmd stays verbatim (untruncated) for the long command :: codepoints=124
TEAM-BG-CASE PASS S12 multiline command is single-lined in the result text :: "  cmd: echo P33-MULTI-A echo P33-MULTI-B echo P33-MULTI-C"
TEAM-BG-CASE PASS S12 details.cmd keeps the multiline command verbatim
TEAM-BG-CASE PASS S12 the multiline job still runs as written (all three echoes)
TEAM-BG-CASE PASS S12 the harvest receipt (finished) names the command too ::   cmd: echo P33-RECEIPT
TEAM-BG-CASE PASS S12 the harvest receipt (still running) names the command too ::   cmd: sleep 2; echo P33-RUNNING-DONE
TEAM-BG-HARNESS OK
rc=0                                     ← 60 条用例，0 FAIL
```

```sh
bash skills/teamsmith/tests/team-bg-flip.sh
```

（完整输出见 §4.2；末行 `team-bg-flip：翻转已复现（红① + 红②×10 → 绿）`，`FLIP_RC=0`，99.3s。）

```sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
```

```text
== 15 · 完成 ==
== 结果 ==  ✓ 2301  ✗ 0
FAST 模式：跳过 27 个真进程段落（… 完整门禁请不带 TEAM_SMOKE_FAST 重跑）
smoke 全绿                                ← 491.3s（后台作业 rc=0，日志 state/bg/p33-smoke-fast.log）
```

- Verdict: **pass**（三段都实跑过；没有跑**完整**门禁 —— 按项目纪律由 PM 复验时跑）。
- 已知风险/未验证项：完整门禁（非 FAST）与真进程段落未在本回合跑；`openspec validate --all --strict`
  与本改动无关（`change: -`），留给 PM 的 gate 一起跑。

## 6. Independent verification package

```sh
bash docs/team/reports/P33-dev2/pkg/run.sh            # 全部 3 节（约 2 分钟）
bash docs/team/reports/P33-dev2/pkg/run.sh 10 20      # 只跑指定前缀的分节
```

```text
P33 复验包 · 2026-09-22T06:54:32+00:00
10-harness   ✓ 16  ✗ 0  findings 0  skip 0
20-display   ✓ 2  ✗ 0  findings 0  skip 0
30-break     ✓ 4  ✗ 0  findings 0  skip 0

== 复验包汇总 ==
  10-harness|✓ 16  ✗ 0  findings 0  skip 0|rc=0
  20-display|✓ 2  ✗ 0  findings 0  skip 0|rc=0
  30-break|✓ 4  ✗ 0  findings 0  skip 0|rc=0
复验包：没有 ✗（finding 是记录，不是失败）
```

- **独立性**：`probe-display.mjs` 是自写的假 Pi 宿主与自写断言（硬编码期望串，不复用
  `tests/team-bg-harness.mjs` 的宿主/断言）；`30-break.sh` 的变体与官方 flip 的四条破坏**不同**；
  官方夹具只在 10 节作为「被测夹具」被调用。
- **隔离**：清掉继承的 `TEAM_*/SMOKE_*` 与 `TMUX/TMUX_PANE`；夹具只落 `/tmp/p33-dev2.XXXXXX`；
  本包**不调用 tmux**（P33 是显示层，没有会话/窗口面）；`30-break.sh` 结尾核对主树扩展 sha256 未变。
- 一键重放证据：`docs/team/reports/P33-dev2/logs/{10-harness,20-display,30-break}.log`。

## 7. Decisions and deviations

1. **收割回执的形状**：brief 说「回执头一行也点名命令（同一形状；若改动超过两行就跳过并说明）」。
   实现成**紧接第一行的 `  cmd:` 行**（与 `team_bg_run` 完全同形），因为第一行已经背着
   `id/exit/duration/log 路径`，命令再塞进去会挤成一团；两种形状（running / finished）都加了。
   代码改动共 3 处文本行（>2），按 brief 的要求在此说明——这是有意的取形状，不是漏做。
2. **`team-bg-flip.sh` 的红① 原本是坏的**：它把「base 的夹具必须红在 S11」写死了，而本分支的
   `merge-base HEAD main` 是 `51fd26c`（含 M30、缺 P33），于是它在**未改动的树上也是红的**。
   已改成按 base 的形状分类（无扩展 / M30 之前→S11 / P33 之前→S12；base 已含修复→**可见跳过**
   并提示用 `TEAM_FLIP_BASE`），并让红② 的条数不再手写（打印实际执行数）。P33 的证据由红② 的
   4 条破坏 + §4.3 独立承担。
3. **references 动了两个文件**（brief 允许「必要的 `references/` 一句话」）：
   `agent-adapters.md` §3a 一句话（契约），`workflows.md` §E2 的示例输出补 `cmd:` 行
   （不改就是文档与实现漂移）。未动 `SKILL.md`、`troubleshooting.md`（它们没有逐字的输出记录）。
4. **pkg 多了一个工具** `dump-text.mjs`（无断言的原文对照器），因为 brief 明确要报告里有
   「缩略前后的原始文本对照」；有了它，PM 可以自己对任意 revision 重放（见 §2）。
5. **探针的夹具根做成了真 git 仓库**：否则 `findRoot` 里那次 `git rev-parse` 会把
   `fatal: not a git repository` 打到 stderr（Node 的 `execFileSync` 不吞子进程 stderr），
   日志会带噪音；git 不可用时仍走 `TEAM_ROOT` 兜底。
6. **自曝一处自查 bug**：探针最初把 finished 回执的期望写成 `命×100 + …`，忘了命令前缀
   `echo ` 也占 5 个码点——第一次跑就被它打红（`shown="echo …命…"` 不符合硬编码期望）。
   期望改成 `echo ` + 95 个「命」+ `…` 后全绿；这正好说明这条断言不是把实现再算一遍。
7. **未动**：`skills/teamsmith/tests/smoke.sh`（不在本任务授权路径内；它已有的 S1/S2/S3/S5/S6/S11
   断言在新夹具下全绿）、作业语义（id/pid/日志/台账/收割/裁剪/根解析）、`docs/team/**`（只写本报告目录）。

## 8. Suggested next steps

- PM：在独立 checkout 跑门禁（`openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`）
  后本地合并（本仓库 local 模式，分支已在 `.worktrees/dev2`，**没有 push**）。
- 若要更强的回归面，可考虑把 `pkg/probe-display.mjs` 的三条边界（恰好 100 / 101 码点、代理对跨截断点）
  收进官方夹具；这属于新任务，本次没自作主张。
- 无 `BLOCKED:`。
