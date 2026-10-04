# M59 · pty 夹具的等待与清理：把"假红级联"变成机制（infra）

```
task:    M59
agent:   dev3
branch:  task/M59-pty（local 模式：不 push；分支留在 .worktrees/dev3，PM 复验后本地合并）
change:  -（anchor: none (infra) — 测试夹具自身的等待/清理健壮性；不改产品契约，不改门禁语义）
deps:    M55（已合并；事故现场 = 第一次复验的 §38-b 62 条红）
status:  DONE（返工后）
tips:    首版 2b54c63 → PM 复验 FAIL（choices ✓34 ✗77）→ 返工 tip 见 §0.5
```

> 续跑说明：本任务由 PM 快照 `4cf5e4a`（我的 M55 收尾时在途的夹具硬化）续跑完成。快照里的
> WIP（条目标记等待、`leave_*`、`remain-on-exit` 死因点名）保留并全部纳入
> `tests/lib/pty-wait.sh` 的机制化实现；M55 报告 §11 的措辞与本报告一致。

## 0. PM 复验 FAIL 的返工（本轮新增，逐条对 PM 的返工要求）

PM 复验（`docs/team/reviews/M59.md` / `f45c361`，tip `2b54c63`）判 FAIL：choices 段 `✓ 34 ✗ 77`，
同一夹具在 main 树 `✓ 74 ✗ 0`。自己的责任：**我把 lib 里的 `pty_frame_settled` 改名成 public 的那一
提交（`1d50afd`）落在 PM 取 tip 的 `2b54c63` 之后**——中间那一版 fixture 调用 public 名、lib 只有私有名。
PM 的判定是对的，下面每条要求都给原始证据。

### 0.1 根因与红→绿（返工要求 1）

红灯不是「夹具断言被放宽后不成立」，而是**调用了一个当时不存在的函数名**：

```text
$ # 把 PM 取的那个 tip 原样导出（不碰任何分支/工作树状态）
$ git archive 2b54c63 | tar -x -C /tmp/m59/red
$ cd /tmp/m59/red && bash skills/teamsmith/tests/panel-p21.sh choices 2>&1 | tail -2
  ✗ bool 选择器里没有 关（0）
  ✗ bool 选中后没有打开写编辑器
  ✗ 选项落到同一个写编辑器里（…/choices/bool-editor.txt 里找不到 [╭─ TEAM_NOTIFY_TMUX]）
  ✗ bool 的确认行没出现
== 结果 ==  ✓ 34  ✗ 77          # 与 PM 复验逐字一致（同样这四条在前）

$ grep -m3 'command not found' /tmp/m59/choices-red-2b54c63.log   # 10 条，前 3 条都在 292 行
skills/teamsmith/tests/panel-p21.sh: line 292: pty_frame_settled: command not found
skills/teamsmith/tests/panel-p21.sh: line 292: pty_frame_settled: command not found
skills/teamsmith/tests/panel-p21.sh: line 292: pty_frame_settled: command not found

$ grep -n 'pty_frame_settled' /tmp/m59/red/skills/teamsmith/tests/panel-p21.sh | head -3   # 调用方
239:      if pty_frame_settled "$c"; then          # focus_row
292:      if pty_frame_settled "$c"; then          # pick_option ← 首红就死在这
386:      if pty_frame_settled "$c_probe"; then    # 点击探针
$ grep -n '^_*pty_frame_settled()' /tmp/m59/red/skills/teamsmith/tests/lib/pty-wait.sh      # 定义方
98:_pty_frame_settled() {                           # ← 名字对不上：bash 报 not found（127），if 走 else
```

链路：`pty_frame_settled` 未知命令（127）⇒ `if` 恒假 ⇒「稳定帧」这道闸门永不通过 ⇒ `pick_option`/
`focus_row` 一直按 Down **越过目标行** ⇒ `pick_option '关（0）'` 判负（首红）⇒ 其后的编辑器/确认行/
回执断言全部跟着红（77 条）。这与真正的假红级联是同一形状，只是触发器换成了名字不一致。

**修法**：`1d50afd` 把 lib 的定义改成 public 名（fixture 侧本来就用 public 名调用，lib 内部三处调用
一并改名）。修后同一段连跑 5 次：

```text
$ for i in 1 2 3 4 5; do bash skills/teamsmith/tests/panel-p21.sh choices 2>&1 | tail -1; done
== 结果 ==  ✓ 80  ✗ 0        # ×5，rc=0 每次
```

返工 tip 上再各跑一次「红树 / 新树」对照（今天重跑，防止只拿旧日志说话）：红树 `✓ 34 ✗ 77`
（上面那一段），新树 `✓ 80 ✗ 0`。

### 0.2 断言覆盖没有缩水（返工要求 1 的后半句）

两个口径都测了，**都是增不是减**：

口径 A · 实跑结果行：两个树各跑一次**全场景 p21**（main 用 `git archive main` 导出到 `/tmp/m59/base`，
互不干扰的私有 tmux server）：

| section | main（实测） | 返工 tip（实测） | 差 |
|---|---|---|---|
| settings | 36 | 37 | +1 |
| choices | 74 | 80 | +6 |
| choices-schema | 9 | 9 | 0 |
| write | 23 | 24 | +1 |
| conflict | 6 | 7 | +1 |
| seats | 22 | 22 | 0 |
| readonly | 5 | 5 | 0 |
| 合计 | **175** | **184** | **+9** |

choices 的 74 与 PM 给的基线逐字对上（`✓ 74 ✗ 0`）。多出的 6 条是本任务新加的探针
（清理守卫「已关闭的选择器一个键都不发」、trace 探针、`wait_picker` 回归钉、确认行的条件等待等）。

> 上一版报告里自报的「全场景 ✓ 187」不在任何提交上（中间工作树状态的自报值），本轮实测为 **184**；
> 对外基线一律用 **main 的 175**（上表），因为那才是 PM 的判据；若按旧口径 FAST 比，也不存在「断言
> 被删」的形状——下面口径 B 的静态表能证伪「新增了等待就少验了什么」。

口径 B · 断言点静态计数（每个 section 的 `ok/assert_*` 调用点，含只在红路径执行的那些）：

| section | main | 返工 tip | 差 |
|---|---|---|---|
| settings | 40 | 48 | +8 |
| choices | 111 | 128 | +17 |
| choices-schema | 12 | 12 | 0 |
| write | 42 | 51 | +9 |
| conflict | 9 | 12 | +3 |
| seats | 34 | 42 | +8 |
| readonly | 6 | 10 | +4 |
| 合计 | 254 | 303 | +49 |

有 8 处是「换了写法/标签」而不是删断言——全部是 `cap_to X + assert_has X` 改写成
`if wait_cap X <needle>; then ok …; else bad …; fi`（固定 sleep 变条件等待），语义逐条对齐：

| section | main 的写法 | 返工 tip 的写法 |
|---|---|---|
| settings | `assert_has refuse-route.txt "手改" "refuse 行的回执点名路线"` | `if wait_cap refuse-route "手改"; then ok "refuse 行的回执点名路线"; else bad …` |
| choices | `assert_has bool-confirm.txt "→ 0" "确认行拿着选项的值"` | `if wait_cap bool-confirm "→ 0"; then ok "确认行拿着选项的值"; else bad …` |
| choices | `assert_has enum-confirm.txt "需要重启才生效" "restart 类的确认行说明重启时机"` | `if wait_cap enum-confirm "需要重启才生效"; then ok "restart 类的确认行说明重启时机"; else bad …` |
| write | `assert_has danger.txt "危险：" "危险值先要一个额外确认"` | `if wait_cap danger "危险："; then ok "危险值先要一个额外确认"; else bad …` |
| write | `assert_match invalid.txt '最小 60' "回执点名接受域（最小 60）"` | `if wait_cap invalid "最小 60"; then ok "越界数值的拒绝点名最小 60"; else bad …` |
| conflict | `assert_has conflict.txt "指纹不符" "回执点名指纹冲突"` | `if wait_cap conflict "指纹不符"; then ok "回执点名指纹冲突"; else bad …` |
| seats | `assert_has shapeless.txt "provider/model" "没有 provider 的模型被命令拒绝"` | `if wait_cap shapeless "provider/model"; then ok "没有 provider 的模型被命令拒绝"; else bad …` |
| settings | `assert_match "$(argv_log)" 'pulse collapse' "q 仍然触发全局的收起动作"` | `if wait_argv q-collapse 'pulse collapse'; then ok "q 仍然触发全局的收起动作"; else bad …`（同一针，改成文件轮询） |

### 0.3 我实际跑过的段落与结果行（返工要求 3 —— 这是上一版报告的口径缺口）

上一版报告把 `pty-wait.sh --self-test`（新引擎自测）的 5 连跑写成了交付证据之一，**覆盖了新引擎、
没有覆盖被改写的段落** —— PM 点得对。本轮按「段」逐个列，命令与末行都来自实际运行：

| 命令 | 段落 | 结果行 | rc |
|---|---|---|---|
| `panel-p21.sh choices` | choices | `✓ 80 ✗ 0` | 0 |
| `panel-p21.sh`（全 7 段） | settings | `✓ 37 ✗ 0` | 0 |
| | choices | `✓ 80 ✗ 0` | |
| | choices-schema | `✓ 9 ✗ 0` | |
| | write | `✓ 24 ✗ 0` | |
| | conflict | `✓ 7 ✗ 0` | |
| | seats | `✓ 22 ✗ 0` | |
| | readonly | `✓ 5 ✗ 0` | |
| | 合计 | `== 结果 == ✓ 184 ✗ 0` | 0 |
| `pty-wait.sh --self-test` | lib 自检（判据①②③） | `✓ 12 ✗ 0` | 0 |
| `pty-wait.sh --self-test --break=early` | 翻转（判据①） | `✓ 8 ✗ 3`（红演示成立） | 1 |
| `panel-flip-m54.sh F-B` | choices 读取断掉的翻转 | `✓ 4 ✗ 0`（红侧 149 条带场景红） | 0 |
| `panel-flip-m54.sh F-C` | 机器目录泄漏的翻转 | `✓ 4 ✗ 0`（红侧 `✓ 79 ✗ 1`） | 0 |
| `smoke.sh`（全量，含 §38-b 真 tmux） | 全 89 个小节 | `== 结果 == ✓ 2704 ✗ 0`（§38-b `✓ 80 ✗ 0`、§38-c `✓ 12 ✗ 0`） | 0 |
| `TEAM_SMOKE_FAST=1 smoke.sh` | brief 的字面行（快模式） | `== 结果 == ✓ 2206 ✗ 0` | 0 |

覆盖缺口（如实登记）：`choices-schema`（9 条）与 `readonly`（5 条）我只在全景跑里跑过，没有单独
连跑；新引擎的自检只覆盖 lib 的三条机制，不覆盖任何真面板段落——两者不可互相替代。

### 0.4 合 main 并重跑门禁（返工要求 4）

```text
$ git merge main --no-edit
Merge made by the 'ort' strategy.        # rc=0，无冲突；smoke.sh 的 §38-c 调用声明与 M58 的
                                         # perf-suite-split 改动自动合上（§38-c 仍在 11388 行处）
$ git log --oneline -1
a68a249 Merge branch 'main' into task/M59-pty
```

M58 之后的正确性门禁不再判性能（`smoke.sh` §35：装配时间红线/帧预算/中位已搬进 `tests/perf.sh`），
所以上一轮那条宿主 perf 红不再出现（§7.1 是全量实测）。

### 0.5 返工 tip（返工要求 5）

```text
767e14c test(pty): M59 — focus_row re-checks a repainting row instead of walking past it
+ 本报告的提交（docs/team/reports/M59-dev3.md）
```

另一半修改（收在这一提交里）：行集异步替换/短暂空白时，`focus_row` 对「行在屏上但帧还在重画」
只重看不走位、对「行不在屏上」按 Down（空表上无害 no-op，行集回来续走），上限 80 轮 ≈ 40s
（只在失败时才花）；`fa09d5e` 加的三处预等待折进 `focus_row` 自身（预等待抓住的最后一帧之后，
空窗仍可能打开——容忍必须做在走位上）。这不属于 PM 的 FAIL 根因，是同一现场的另一半。

---

## 1. 交付物

| 文件 | 内容 |
|---|---|
| `skills/teamsmith/tests/lib/pty-wait.sh`（新） | 三件事一套机制：**①稳定帧等待** —— 针不只在同一帧，且连续两次 capture 逐字节相同（标题时钟掩码后）才放行；支持 `!text` 反义针（等「不在场」）。**②状态确认的清理键** —— `pty_key_when`/`pty_cleanup_esc`：标记不在稳定帧上就不发键，esc 发出后还确认目标真的关闭。**③失败自带现场** —— 超时打印等待名/轮数/耗时/缺失项/pane 末 12 行/超时后立即再 capture（画面静止还是还在变）/孤立还是级联；`remain-on-exit` + `pty_pane_state` 让死掉的 pane 被点名而不是比空帧。`--self-test` 用假 pane 注入事故的中间帧（每次 capture 多画一行 + 时钟每秒跳）做红绿对照；`--break=<stage>` 是自检专用翻转开关（ sabotage 一条规则让守卫测试变红，见 §3）。 |
| `skills/teamsmith/tests/panel-p21.sh` | 全部等待（面板首帧/视图打开/选择器/写编辑器/回执/焦点行/选项/过滤应用与清除）改走 lib；全部清理 esc（`leave_*`、导航 esc、取消 esc、测试动作 esc）改走守卫；`bad()` 带现场；一批「装睡 fixed sleep」改成条件等待（回执、确认行、过滤落地、滚轮落定、q 收起走 argv 日志）；键程节拍（两次 Enter 之间、打字后）保留固定 sleep，理由见 §5。 |
| `skills/teamsmith/tests/panel-flip-m54.sh` | 修一个被 M59 现场暴露的真 bug：红点点名检查 `grep -E ✗ log \| grep -q -- re` 在 `set -o pipefail` 下随日志变大而 SIGPIPE（141）——grep -q 先退、扫描中的 grep 继续 flush 被 PIPE 杀，真命中读成未命中（F-B 实测复现，CHECK_RC=141，见 §3.5）。改 `{ grep … \|\| true; } \| grep -q` 幂等写法。 |
| `skills/teamsmith/tests/smoke.sh` | 仅 §38 调用声明：新增 §38-c 跑 lib 自检（FAST 也跑：不依赖 tmux/真 bundle）。 |
| 未动 | `panel-choices.sh`（headless，无 pty 等待，grant 内有它但本任务用不到）；产品代码 `panel/src/**`、`scripts/lib/**`、`extension/**` 一行未碰；`TEAM_P21_*`/`TEAM_SMOKE_*` 语义未动（新增 `TEAM_P21_TRACE` 诊断开关，登记于 §6）。 |

## 2. 判据①：等待必须是"稳定帧"，不是"标题出现"

**机制**：`pty_wait_frame` 的放行条件 = 针全部在同一帧 ∩ 下一拍再 capture 逐字节相同（`HH:MM:SS`
标题时钟掩码后）。Ink 逐行画帧 ⇒ "标题已到、条目未到"的中间帧要么针不齐、要么帧还在变，两条都拦。

**红（旧逻辑，演示）→ 绿（新逻辑）**，`bash skills/teamsmith/tests/lib/pty-wait.sh --self-test`
（假 pane：选择器打开后每次 capture 多画一行；时钟每次 capture 跳一秒）：

```text
== pty-wait 自检（注入中间帧 + 清理守卫 + 失败现场） ==
  注入的帧序列：选择器打开后每次 capture 多画一行（标题→› 保持未设→tui · 当前→auto · 默认），
  标题时钟每次 capture 跳一秒（只有 HH:MM:SS 掩码后的比较才算「帧静止」）。
  ✓ 旧逻辑（只看标题 + 固定 sleep）在同一帧序列上第 1 帧就放行，而那一帧还没有条目标记 —— §38-b 的假红入口
      旧逻辑放行的那一帧：
      │ ╭─ 项目设置 · 09:41:01
      │ │ 监控界面  tui · 当前
      │ 选择 监控界面 的值 · TEAM_MONITOR_UI
  ✓ 新逻辑等到条目落地、帧静止才放行（6 次 capture / 8 轮预算 —— 自适应，不是熬预算）
  ✓ 新逻辑放行的那一帧同时有条目标记 [› 保持未设] 和最后一条目 [auto · 默认]（标题命中不算数，中间帧不放行）
```

**翻转（断实现 → 守卫测试必须红 → 恢复）**：同一命令加 `--break=early`（退回"只看标题"）/
`--break=nosettle`（只留条目标记、关掉稳定确认）/`--break=noclockmask`（比较不掩时钟，任何帧都"在动"）：

```text
$ bash skills/teamsmith/tests/lib/pty-wait.sh --self-test --break=early 2>&1 | grep -E '✗|结果'
  ✗ 新逻辑没有等到稳定帧（rc=0，PTY_SELFTEST_BREAK=early）        ← 第 1 帧就放行（红演示成立）
  ✗ 超时现场缺项（见 …/scene1.txt）                               ← 连锁：判负面也红了
  ✗ 第一次失败没有被标成孤立
== 结果 ==  ✓ 8  ✗ 3        rc=1

$ bash skills/teamsmith/tests/lib/pty-wait.sh --self-test --break=nosettle 2>&1 | grep -E '✗|结果'
  ✗ 新逻辑没有等到稳定帧（rc=0，PTY_SELFTEST_BREAK=nosettle）      ← 只凭条目标记在 paint=2 放行，该帧还缺 [auto · 默认]
== 结果 ==  ✓ 10  ✗ 1       rc=1

$ bash skills/teamsmith/tests/lib/pty-wait.sh --self-test --break=noclockmask 2>&1 | grep -E '✗|结果'
  ✗ 新逻辑没有等到稳定帧（rc=1，PTY_SELFTEST_BREAK=noclockmask）   ← 每个帧都因时钟被判"在画"，永不放行
  ✗ 清理守卫在选择器开着时没有 esc 或没有关掉（keys=0 mode=picker）
== 结果 ==  ✓ 9  ✗ 2        rc=1
```

真夹具侧的同机制回归钉（选择器真开着时，要一个不存在的条目必须判负；判负现场见 §4）：
`✓ wait_picker 要的条目不在稳定帧里时判负（标题命中不算，现场见上面的黄点场景）`；
外加 trace 探针 `✓ 正常等待放行在稳定帧上（trace 可见轮数）`（`wait picker TEAM_MONITOR_UI rounds=N settled=1`）。

## 3. 判据②：清理按键必须先确认当前状态

**机制**：`pty_key_when <label> <needle> <key…>` —— 针在稳定帧上才发键；`pty_cleanup_esc` 在其上
再加"esc 后确认目标消失"。标记不在 ⇒ 一个键都不发（返回 0："已经不在场"，调用方可用 trace 区分）。

**红（旧写法演示）→ 绿（守卫）**，同一"选择器早已关闭"现场：

```text
  ✓ 选择器早已关闭的现场：清理不发键（0 次 send-keys），设置视图完好 —— 旧写法的裸 esc 在这里
  ✓   会把它整个关掉
  ✓ 旧写法（裸 esc）在同一现场按下一次键、设置视图被关掉 —— 这就是 62 条级联的第一个入口
  ✓ 选择器真开着：守卫恰好发一个 esc 并确认关闭（选择器 → 设置视图）
```

**翻转**：`--break=unguarded`（守卫旁路，退回裸 esc）：

```text
$ bash skills/teamsmith/tests/lib/pty-wait.sh --self-test --break=unguarded 2>&1 | grep -E '✗|结果'
  ✗ 清理守卫把键发出去了或视图没了（keys=1 mode=closed rc=0）   ← 裸 esc 把设置视图关了（62 条级联的形状）
== 结果 ==  ✓ 10  ✗ 1       rc=1
```

真夹具侧（choices 段，TEAM_P21_KEEP=1 实测采证）：

```text
$ cat …/choices/cleanup-trace.txt
  · pty-wait: key - label=回归钉：已关闭的选择器 action=none reason=not-settled   ← 一个键都没发
$ cat …/choices/wait-trace.txt
  · pty-wait: wait picker TEAM_MONITOR_UI rounds=12 settled=1                      ← 放行在稳定帧上（预算 32）
$ head -4 …/choices/cleanup-after.txt
  teamsmith pulse · root  11:22:19  巡检 900s · 待命 off
  [总览]  工作   消息与日志   看板
  ╭─ 项目设置 ────…────╮                              ← 设置视图完好（没有裸 esc 打到它身上）
```

对应断言：`✓ 已关闭的选择器：清理守卫一个键都不发` / `✓ 守卫的理由是「标记不在稳定帧上」，不是预算` /
`✓ 设置视图还开着（没有裸 esc 打到它身上）` / `✓ 正常等待放行在稳定帧上（trace 可见轮数）`。

## 3.5 顺手修的真 bug：flip 红点点名的 SIGPIPE 竞态（F-B 首跑红的根因）

PM 复验命令 `panel-flip-m54.sh F-B` 首跑出现 1 条红：`红侧没有点到预期的那条（保持未设）`——
而红侧尾部明明印着含 `保持未设` 的 ✗ 行。复现与定位（保存的完整 96KB 红日志）：

```text
$ set -o pipefail; grep -E '✗' /tmp/fb-red-full.log | grep -q -- '保持未设'; echo $?
141        ← SIGPIPE：grep -q 命中即退，扫描中的 grep 还在分块 flush 输出，被 PIPE 杀
```

M59 的失败现场让红日志变大（每条红带 pane 场景），把这个随日志体积/调度时序而发作的 latent
竞态变成了必发。修法：`{ grep -E '✗' "$log" || true; } | grep -q -- "$red_re"`（pipefail 下
管道状态只看 grep -q）；panel-p21 的 `focus_row`/`pick_option` 同款三程管道一并改掉。修复后
用同一份真实红日志验证通过；F-B/F-C 复跑全绿（原始输出见 §7）。

## 3.6 全量自测抓到并已修的三处（交付前最后一轮 full p21 的 11 条红 → 0）

choices 段连绿之后跑全场景，settings/conflict/seats 红了 11 条（choices/choices-schema/write/readonly
仍绿）。逐一定位（失败现场 + KEEP+TRACE 采证 + 面板数据模型核对）——**三处全是夹具侧的同步缺口，
产品行为没变**：

1. **点击用例的第二次点击探针**：我上一版等的是「任意稳定帧」，而视图在编辑器打开**之前**就是
   稳定的（行数据 open 时要重读，`wait_editor` 注释里 M55 写过这一拍）——探针误判「没打开」，
   留下的编辑器让 refuse 用例的过滤键吃进草稿、Enter 确认了 512→512（级联 5 条）。修法：探针
   改等**本行自己的**托盘/选择器标题落在稳定帧上（预算 24 轮，不再烧两份全预算）。
2. **`wait_cap` 的字面针误用 ERE 形状**：`"重复提醒间隔 +900"` 里的 ` +` 是 assert_match 的正则，
   wait_cap 是 grep -F——字面「一个空格」永远匹配不上行里的宽留白，12s 预算空转。修法：等待
   钉「900 · 立即生效」，「标签 + 值」的形状交给后面的 assert_match（ERE）验。
3. **走位走进了行集替换/块降级的空窗**：seat 写入后视图异步重读合同，行集被整批替换、甚至
   **整段空缺**——面板的 data 块一次构建失败就按设计渲染成空表（`snapshot()` 只收
   `at>0 && !error` 的块，失败块渲染 `—`/`—` 直到下一个 TTL 周期的成功读；实测在负载下空窗
   可持续 40s+），M55 注释记载过同形坑（「拿旧帧算出 40 步，新帧一到就冲过 dev 行」）。
   focus_row 在空行集上 40 步空转后，**盲发的 Enter 打中了 dev2 行**（采证：pane 上是
   `选择 dev2 的模型`，dev 的移除写到了 dev2 上）。修法（两迭代）：先在各走位点前加目标行内容
   预等待 —— 全量复跑证明空窗会落在预等待**之后**（预等待抓住的最后一帧是好帧，0.3s 后行集又没了）；
   最终版把容忍做进 `focus_row` 本身：行在屏上但帧还在动就只重看不走位、行不在屏上才 Down
   （空行集上的 Down 是无害 no-op，行集回来续走）、上限 80 轮（≈40s，失败才花）；各调用点的
   `Enter` 只跟在成功的走位后（`if focus_row; then keys Enter; else bad; fi`）——判据②同款守卫
   cover 到**测试动作键**。

修复后三场景复跑全绿（settings 37✓ / conflict 7✓ / seats 22✓），随后重跑全场景 + 5 连跑 + FAST
门禁（§7 为最终态实测值）。教训已吸收进判据②的适用范围：**任何**按键（含测试动作键）前都要
先确认状态，不只清理键；以及：**空表也是一帧**——"稳定帧"不等于"正确的帧"，等待的针必须是
"将要断言/操作的那个状态"。

## 4. 判据③：失败必须自带现场

**机制**：等待超时即打印（stderr，不影响 ✓/✗ 计数）：哪条等待、轮数与耗时、缺什么、超时时的
pane 末 12 行、**超时后立即再 capture**（与超时帧一致=画面静止/条件没到；不同=中间帧或慢帧）、
`pty_pane_state` 的死因；随后 `bad()` 再打孤立/级联（`pty_failure_context`：首轮失败给全现场，
级联只给 4 行并指回第一条；任一条 `ok` 把级联清零）。超时现场同时落盘
`$PTY_SCENE_DIR/pty-scene-*.txt`（两份 capture 全文）。

**故意让一个等待超时**（自检段，短预算 3 轮）：

```text
  · 等待超时：绝不存在的条目
      轮数 3/3，耗时约 0s（轮询 0.01s + 稳定确认 0.01s）；缺 [这条目永远不来]
      超时后立即再 capture：画面已静止（条件确实没到，不是中间帧）
      pane 末 12 行（超时时）：
      │ …（假 pane 的完整视图）…
  ✗ 故意失败①
      现场：这次失败来自等待超时 —— 绝不存在的条目（3 轮 / 约 0s；缺 [这条目永远不来]），上面的 pane 现场就是它
      这是一次孤立失败（上一个失败之后有过成功）
  ✗ 故意失败②
      级联：这是本轮第 2 次失败（上一个失败之后没有再通过过）——先修第一条
  ✓ （级联计数中间的一次成功，等价于真夹具里通过的那条断言）
  ✗ 故意失败③
      这是一次孤立失败（上一个失败之后有过成功）
```

真夹具侧的同类现场：choices 段回归钉（选择器开着、要一个不存在的条目）每次判负都打出黄点场景，
5 连跑的日志里可见。实测采证（短预算 6 轮；这一幕发生在 rc=0 的绿跑里，是**故意触发的判负**）：

```text
  · 等待超时：picker TEAM_DEFAULT_MODEL
      轮数 6/6，耗时约 1s（轮询 0.25s + 稳定确认 0.2s）；缺 [这条目不存在-硬线自检]
      超时后立即再 capture：画面已静止（条件确实没到，不是中间帧）
      pane 末 12 行（超时时）：
      │ ╰────…（选择器列表底部边框）────╯
      │ （空行 ×10）
      │  ( m 写信 ) ( f 冲刷 ) ( s 待命 ) ( , 设置 ) · ↑/↓ 行 · Enter 打开 · Esc/q 返回
  ✓ wait_picker 要的条目不在稳定帧里时判负（标题命中不算，现场见上面的黄点场景）
```

（pane 末行里看不到选择器标题，是因为长列表滚过了它——「缺 [这条目不存在-硬线自检]」一行
点名了真正的缺失项；这正是「现场给够、但不级联」的样子。）

**翻转**：`--break=noscene`（场景打印旁路）：

```text
$ bash skills/teamsmith/tests/lib/pty-wait.sh --self-test --break=noscene 2>&1 | grep -E '✗|结果'
  ✗ 超时现场缺项（见 …/scene1.txt）
  ✗ 第一次失败没有被标成孤立
  ✗ 第二次失败没有被标成级联
  ✗ 成功之后的新失败没有回到孤立
== 结果 ==  ✓ 8  ✗ 4        rc=1
```

## 5. 判据④：没有拿"加预算"当修法

报告要求写明"哪一处条件化、哪一处保留固定等待、为什么"：

**条件化的（条件成立即返回；预算是失败探测 horizon，绿跑只在第 1–3 轮花掉）**
- 全部内容等待：面板首帧、设置视图 marker、选择器（标题+条目标记）、写编辑器（托盘+正文标记）、
  回执 `wait_cap`、焦点行/选项行（光标+稳定帧）、过滤应用与清除（compose 托盘的不在场）、
  滚轮落定（隐藏计数下降）、argv 日志（`wait_argv`，文件非 pane）。
- 预算数字的来历：默认 32 轮×0.35s ≈ 11s（选择器/编辑器/关闭），回执 30×0.4 ≈ 12s，视图 40×0.4 ≈ 16s，
  面板首帧 80×0.25 ≈ 20s（真 bundle 冷启动 + 负载）。这些是**红侧才付得起**的上限；判定面收紧后
  绿跑通常 ≤3 轮（trace 探针实测 `rounds=1..3`）。M55 WIP 已把这些从 7s 级提到 11s 级，理由是
  PM 复验时门禁与其它任务同机（`openSettingsRow` 的 `await refreshSettings()` 会撞 7s 死线）——
  本轮保留该 horizon 不动，**修法不含任何预算上调**（相对 WIP 没有再加）。

**保留固定 sleep 的（键程节拍，不是等待）**
- 两次 Enter 之间（confirm → write）、typing 后、send-keys 序列之间（0.3–0.5s）：按键事件由应用
  逐个处理，节拍是让上一个状态变迁落地再发下一个键；这些点之后都有条件等待或断言兜底，
  即使节拍不够，失败也是带现场的单条红，不再级联。
- `open_view` 的开场（`,` → Down×5 → Enter）：overlay 打开没有可观测 marker，下游等待兜住。
- `pick_option` 命中后的 `sleep 1.3`：选中后的写编辑器打开由紧随的 `wait_editor` 条件等待接住。

**显式拒绝的修法**：把 `sleep 0.9` 改成 `sleep 3` 这类"加预算"一处都没有；反向地，本轮把
sleep-2/sleep-2.5/sleep-1.2/sleep-0.9 等 14 处"装睡的等待"改成了条件等待。

## 6. 诊断开关登记（夹具专用，不动产品语义）

| 开关 | 默认 | 作用 |
|---|---|---|
| `TEAM_P21_TRACE` → `PTY_TRACE` | 0 | p21 每次等待/清理决定打 stderr（`wait <label> rounds=N settled=0/1`、`key … action=sent/none reason=…`）；choices 段两条探针断言依赖它 |
| `PTY_SCENE_DIR`（p21 内设为 `$tmp/<scn>`） | 空 | 超时现场两份 capture 落盘 `pty-scene-*.txt` |
| `--break=<stage>`（lib 自检专用） | 关 | `early`（只看标题）/ `nosettle` / `noclockmask` / `unguarded` / `noscene`：sabotage 一条规则让守卫测试红（§2/§3/§4 的翻转面） |

## 7. Acceptance（返工 tip 实测，原始输出）

```text
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 17 passed, 0 failed (17 items)                    # rc=0（合 main 后 main 归档了一个 change：18→17）

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null   # brief 的字面验收行（快模式，私有锁不排队）
== 结果 ==  ✓ 2206  ✗ 0                                   # rc=0  ✓ 38-a ✓ 35 ✗ 0 / ✓ 38-c ✓ 12 ✗ 0

$ bash skills/teamsmith/tests/smoke.sh </dev/null          # **全量**（非 FAST：真 tmux / 真进程段落都跑）
== 结果 ==  ✓ 2704  ✗ 0                                   # rc=0（排队后开跑，见 §7.1 口径说明）
  ✓ 35 门禁只判正确性（M58 · perf-suite-split）：性能判定已搬进 tests/perf.sh，本段不判性能
  ✓ 38-a panel-choices.sh 全绿（ ✓ 35 ✗ 0；含一致性走查与 F-A/F-D 翻转）
  ✓ 38-b panel-p21.sh choices 全绿（ ✓ 80 ✗ 0）
  ✓ 38-c pty-wait 自检全绿（ ✓ 12 ✗ 0；中间帧注入 + 清理守卫 + 失败现场）

$ for i in 1 2 3 4 5; do bash skills/teamsmith/tests/panel-p21.sh choices 2>&1 | tail -1; done
== 结果 ==  ✓ 80  ✗ 0    （×5 连跑，rc=0 每次；含 §2 回归钉、§3 清理探针、§4 判负现场）

$ bash skills/teamsmith/tests/panel-p21.sh               # 全场景（settings choices choices-schema write conflict seats readonly）
== 结果 ==  ✓ 184  ✗ 0                                  # rc=0；逐段结果行见 §0.3

$ bash skills/teamsmith/tests/panel-flip-m54.sh F-B
  ✓ F-B choices 读取被断掉：断掉之后 choices 变红（rc=1）
  ✓ F-B choices 读取被断掉：红侧的失败点就是预期的那条（保持未设）
  ✓ F-B choices 读取被断掉：恢复之后 choices 变绿
  ✓ F-B choices 读取被断掉：恢复后 bundle 与提交的逐字节一致
== 结果 ==  ✓ 4  ✗ 0                                      # rc=0（§3.5 修复后复跑）

$ bash skills/teamsmith/tests/panel-flip-m54.sh F-C
  ✓ F-C 机器目录泄漏进选择器：断掉之后 choices 变红（rc=1）
  ✓ F-C 机器目录泄漏进选择器：红侧的失败点就是预期的那条（sub2api）
  ✓ F-C 机器目录泄漏进选择器：恢复之后 choices 变绿（ ✓ 79 ✗ 1）
  ✓ F-C 机器目录泄漏进选择器：恢复后 bundle 与提交的逐字节一致
== 结果 ==  ✓ 4  ✗ 0                                      # rc=0
```

**§7.1 口径差异（上一版报告被 PM 点名的地方）**：上一版写「`TEAM_SMOKE_FAST=1` … ✓ 2225」与
「全场景 ✓ 187」。本轮两点都改：① 门禁跑**全量**——FAST 是它的真子集（`fast_skip` 跳过所有
「真 tmux / 真进程」段落，只为 < 60s 而设），全量把 §38-b 那一段真 tmux 也跑了；② 全场景本次
实测 **184**（逐段见 §0.3），不再引用中间工作树的自报 187；对 PM 有意义的比较是 **main 的实测 175**
（§0.2 口径 A 表）。另有：本次门禁曾在别人持锁时**排队**（共享锁 `/tmp/teamsmith-smoke.lock`，
`TEAM_SMOKE_LOCK_WAIT=3600`），日志首行留了持锁者与排队事实，不是静默降级。

两条验收行都跑了：**快模式 ✓2206 ✗0**（brief 的字面行，私有锁）与 **全量 ✓2704 ✗0**（真进程段落
含 §38-b）。二者是包含关系，不是两个不同的判据。

红侧原始输出（F-B 红侧尾部，证明新夹具仍能抓住真失败、且失败带现场不再级联成 62 条）：

```text
      红侧尾部：
        ✗ bool 的选择器没有打开
        ✗ 未设键的首个条目是保持未设（…/choices/bool.txt 里没有匹配 [› 保持未设]）
        ✗ 1 是默认条目，带表里的 on 词（…/choices/bool.txt 里找不到 [开（1） · 默认]）
# 完整红日志 96KB / 149 条 ✗ —— 每条都带场景与级联标记；对比事故那次 62 条裸红。
```

## 8. 改了什么 / 没改什么

- 改了：`tests/lib/pty-wait.sh`（新，约 330 行）、`tests/panel-p21.sh`（+等待/清理/场景接线，
  14 处固定睡眠→条件等待）、`tests/panel-flip-m54.sh`（pipefail 安全的红点名检查 + 尾部打印）、
  `tests/smoke.sh`（仅 §38-c 调用声明）。
- 没改：产品代码（`panel/src/**`、`scripts/lib/**`、`extension/**`）零行；`panel-choices.sh`
  （headless，grant 内但无 pty 等待，本任务不需要）；任何断言语义没有放宽（所有既有断言文本
  原样保留，新增的只有探针/条件等待）；`TEAM_P21_*`/`TEAM_SMOKE_*` 语义；`docs/team/DECISIONS.md`；
  没有 push（local 模式）。
- 事故复盘对齐：M55 报告 §11.3 的机制（标题先到、条目未到 ⇒ 断言红 ⇒ 裸 esc 关视图 ⇒ 级联）
  被①稳定帧②守卫清理③自带现场分别堵死；62 条级联的形状（§3 裸 esc 演示 + F-B 红侧的 149 条
  带场景红）对照可复核。

## 9. 复跑入口

```bash
bash skills/teamsmith/tests/lib/pty-wait.sh --self-test            # 判据①②③绿面（12✓）
bash skills/teamsmith/tests/lib/pty-wait.sh --self-test --break=early     # ①红：只看标题放行
bash skills/teamsmith/tests/lib/pty-wait.sh --self-test --break=nosettle  # ①红：条目标记放行太早
bash skills/teamsmith/tests/lib/pty-wait.sh --self-test --break=noclockmask # ①红：帧永不静止
bash skills/teamsmith/tests/lib/pty-wait.sh --self-test --break=unguarded # ②红：裸 esc 关视图
bash skills/teamsmith/tests/lib/pty-wait.sh --self-test --break=noscene   # ③红：现场消失
bash skills/teamsmith/tests/panel-p21.sh choices                   # 真面板全绿（80✓，含探针）
TEAM_P21_TRACE=1 bash skills/teamsmith/tests/panel-p21.sh choices  # 每次等待/清理决定可见
```
