# V60 · P317 吞错清理的独立复核（不合入 0.3.0）

agent: verify   status: delivered   time: 2026-10-19T11:05Z
branch: `task/V60-swallowed-errors-review`   PR/MR: -（local 模式）

## 结论

**PASS。** 两个问题分别回答：**是**——P317 之后那几处真正的失败会自己说出来，返回码与改动前逐一对齐；
**没有破坏**——正常缺失查询在候选树上一条字节都不多（7 条只读命令的 stderr 全为 0 字节，与基线相同），
竞态路径的吞错仍留着并写了理由。三条残余（R1 三处极窄的 `set -e` 竞态、R2 一条既有的假成功文案、R3 记账口径）
都不阻断，交 PM 裁定。

受检对象与基线（开工解析的完整 SHA）：

```
candidate  c2b0dafbace37faa071e2dd302be44a2276e946c   task/P317-swallowed-errors-common
baseline   ed165191517f4d8af4170d155934da729fff0fc5
diff       skills/teamsmith/scripts/lib/common.sh  +248 / -246（248 insertions, 246 deletions）
```

两棵树用 `git archive <rev> skills/teamsmith` 导出到 `/tmp/v60/{base,cand}` 后跑，本分支树除本报告外未改任何文件
（`git status --short` 在提交前后都只有这份报告）。

## 复核一 · 代码差异本身（结论先写，证据在后）

| 问的问题 | 答案 | 证据 |
|---|---|---|
| 告警是否仍被重定向吞掉 | 没有 | 新增的 7 处 `\|\| team_warn` / `\|\| team_err` 全都没有跟随重定向；`4616` 的 `>/dev/null 2>&1` 只作用于 `team_send_guarded` 那一条命令，`team_warn` 的 stderr 照常上屏 |
| 返回码是否被 `team_warn`/`team_err` 掩盖 | 没有变化 | 两棵树实测 `team_warn` / `team_err` 都 rc=0，与原来的 `\|\| true` 逐字节同义（见下「返回码」） |
| 条件分支是否意外改变 | 没有 | 被删的 `2>/dev/null` 只影响 stderr；`[ ]` 在非数字时 rc=2，旧版也被 `if` 当 false —— 分支结果同一（`121`、`1259`、`3963`、`3966`、`4559`、`4580`） |
| 新增行尾注释有没有破坏续行/引号 | 没有 | 三重机械检查（见下），含 `declare -f` 逐函数比对：**注释一个字都没进解析结果** |
| 理由是否真正解释预期失败 | 大体是，个别分类名不副实 | 187 处 `# 留：`；代码行里仍吞着又没写理由的只剩 4 行（`424`、`453`、`454`、`3534`），四行都有行内或上一行的文字理由；分类问题见 R3 |

**报告的三个数字我独立重算了一遍，全部对得上**：

```
$ python3 <归一化后比较：删掉所有 '# 留：' 后缀再 diff>
  old 侧变更行: 65   new 侧变更行: 66   替换块数: 63
  → 真改代码 66 处（与报告「66 处改掉」一致），其余 181 处只加了理由注释

$ for f in base cand; do <同一计数器：跳过注释行>; done
  base: code || true=136  code 2>/dev/null=234
  cand: code || true=117  code 2>/dev/null=173      # 与报告 136→117、234→173 一致

$ grep -c '# 留：' cand/common.sh
187                                                  # 与报告一致
$ grep -c '^| [0-9]' P317-dev2.md
247                                                  # 66 + 181 逐条表行数一致
```

**注释安全性（这是差异里最容易出事的一类，做了三条独立的机械检查）**：

```
1) bash -n 两棵树都 rc=0。
2) 以反斜杠结尾的行：old 65 行 / new 65 行，逐行内容比对只有 3 行因删 2>/dev/null 而变，
   没有任何一行是「反斜杠后加了注释」（grep '\\[[:space:]]\+#' 命中 0）。
   §6i 那次回归就死在这一条上：作者修好后，3533 的理由改成独立一行，3534 的续行完好。
3) 唯一一处 heredoc（TEAM_INOTIFY_PROBE_JS，1355–1369）一个字节未动；改动落在它之后的 1371/1373。
4) 最强的一条：两棵树 source 之后 `declare -f` 转储全部函数体（注释由 bash 剥掉）——
   old 414 个函数 / new 414 个函数，函数体差异 135 行 ≈ 66 处真改动，没有一处把注释文本带进命令字符串。
```

**返回码：20 处删掉 `|| true`，逐处核过，只有三处真的从「永远 0」变成「可能非 0」**

| 类型 | 处数 | 处置与实测 |
|---|---:|---|
| 换成 `\|\| team_warn` / `\|\| team_err` | 7 | `team_warn`/`team_err` 实测 rc=0（两棵树都测了），与 `\|\| true` 同义 |
| 换成显式空值 / 显式分支（`966`、`1345`、`1349`、`1352`） | 4 | 每条路径仍 rc=0 |
| 前提恒成立（`707`、`1336`、`4023`、`6354`） | 4 | `team_js_runner` 末尾 `return 0`、`team_project_ns` 末尾 `printf`、`shift` 已显式判空 |
| 不在能触发 `set -e` 的位置（`2072` 的 for 列表、`2141` 的 `[ ]` 条件） | 2 | 实测 `set -euo pipefail` 下 `for v in $(compgen …)` 不中止 |
| **真的变了**：`old 85`、`2863`、`3962`+`3965` | 3 | 都是「先判 `[ -r ]`/`[ -f ]`，判完到读之间文件消失」的窄竞态；读失败现在会让 `set -e` 中止而不是记空。三处都在报告的清单 A 里逐条登记（行 `85`、`133`、`148`、`150`），调用方也都有 `\|\| true` 兜着 → 归入 R1 |

## 复核二 · 三条独立复现（我自己写现场，不复用作者的 `p317-red-side.sh`）

脚本 `/tmp/v60/repro.sh`，两棵树各跑一遍；只写 `/tmp/v60` 下自己的临时根，不碰真实项目、不碰任何 tmux server
（演示二用私有 `TMUX_TMPDIR` 指向一个普通文件，tmux 根本起不来）。`env -i` 隔离继承的 `TEAM_*` 身份。

```
$ bash /tmp/v60/repro.sh base      # 基线
### A：配置根不存在（team_find_config 的 cd）
rc=1
✗ 当前目录不在 git 仓库内（teamsmith 需要 git 来做 worktree 隔离）

### B：私有 tmux 建不出 session（team_tmux_ensure_session 的 new-session）
rc=0

### C：正常缺失查询（只读命令，stderr 应为空）
--- team status: rc=0  stdout行数=10  stderr字节=0
--- team board: rc=1  stdout行数=3  stderr字节=0
--- team ps: rc=0  stdout行数=17  stderr字节=0
--- team digest: rc=0  stdout行数=17  stderr字节=0
--- team paths: rc=0  stdout行数=1  stderr字节=0
--- team roster: rc=0  stdout行数=8  stderr字节=0
--- team status V60（不存在的任务）: rc=0  stdout行数=11  stderr字节=0
--- team change status nope（不存在的变化）: rc=1  stdout行数=0  stderr字节=131
    stderr| ✗ change nope：没有任务指向它（docs/team/tasks/*.md 里没有 change: nope），也没有 openspec/changes/nope/ 目录

$ bash /tmp/v60/repro.sh cand      # 候选
### A：配置根不存在（team_find_config 的 cd）
rc=1
/tmp/v60/cand/skills/teamsmith/scripts/lib/common.sh: line 909: cd: /tmp/v60/work-cand/does-not-exist: No such file or directory
✗ 当前目录不在 git 仓库内（teamsmith 需要 git 来做 worktree 隔离）

### B：私有 tmux 建不出 session（team_tmux_ensure_session 的 new-session）
couldn't create directory /tmp/v60/work-cand/notadir/tmux-1000 (Not a directory)
✗ 建不出 tmux session proj（tmux 起不来？后面的窗口操作都会失败）
rc=0

### C：正常缺失查询 —— 七条命令的 stderr 字节数与基线逐条相同（0,0,0,0,0,0,0）
--- team status: rc=0  stderr字节=0     --- team digest: rc=0  stderr字节=0
--- team board: rc=1   stderr字节=0     --- team paths: rc=0  stderr字节=0
--- team ps: rc=0      stderr字节=0     --- team roster: rc=0  stderr字节=0
--- team status V60（不存在的任务）: rc=0  stderr字节=0
--- team change status nope（不存在的变化）: rc=1  stderr字节=131（与基线逐字节相同）
```

我的判断（不看作者的断言）：A 与 B 都是「**旧版吞、新版说，返回码不变**」，与作者声称的红侧关系一致；
C 证明丢掉 `2>/dev/null` 没有把噪音带进只读面 —— 七条命令的 stderr 字节数与基线**逐条相同**，
唯一有输出的那条是**真的**不存在的变化，它给的是具名诊断而不是堆栈。

只读面的 stdout 也对照了：`status`、`roster` 逐字节相同；`ps`、`digest`、`paths` 的差异只有
临时根 ns（两个临时项目目录不同）、时间戳与实时内存读数,没有形状变化。

**「警告但仍返回成功」与「调用真正失败」我分开了**：候选把所有改动点都保持成「说了但照旧返回」
（`team_tmux_ensure_session` 仍 rc=0，演示二两棵树都是 rc=0）——这是任务书要求的「行为不变」，不是漏改。
真正的失败仍由返回码表达：同一现场里 `team_tmux_new_window` 是 rc=1（下面 R2 引用了它）。

## 复核三 · 报告里的理由与分类

- **理由覆盖成立**：`# 留：` 187 条；代码行里仍带 `|| true` / `2>/dev/null` 却没有理由的只有 `424`（行内原有说明）、
  `453`/`454`（loader 纪律）、`3534`（`3533` 上一行散文理由）—— 与报告自述的「187 = 180 + 7，另有 2 处写在上一行」吻合。
- **分类计数对不上（记账问题）**：报告的分类表写 A 74 / C 57 / B 35，文件里的标签实际是 A 74 / C 56 / B 33，
  另有 5 个子类没进表（`没有这个键=空` 3、`目标可能还没起/已经没了` 2、`没登记=空` 1、`没有判定行=空` 1、
  `文件刚判过 -f` 1、`动词判不出=空` 1）。总数 187 是对的，分类合计差 3 处 → R3。
- **两处理由分类名不副实**：`1723`（`team_launch_path_valid` 里的 `cd` 被标成「进程/窗口刚消失（竞态）」，
  实际是「启动路径不可解析=校验失败」）、`1312`（读 `/proc/self/status` 被标成竞态，实际是「本机没有 /proc」）。
  判据不假，只是归错了桶 —— 措辞问题，不是产品问题。
- **我没有重跑作者的三次门禁读数**（任务书明确不做）。本复核的结论只建立在上面这些可复跑的命令上；
  作者的门禁读数、`§54` 既有红的归类都按作者自报采信，未独立验证。

## 残余（交 PM 裁定，均不阻断）

**R1 · 三处极窄的 `set -e` 竞态**（`old 85`、`2863`、`3962`+`3965`）。三处都是「先判 `[ -r ]`/`[ -f ]`，
判完到读之间文件消失」，旧版 `|| true` 记空，新版会以 rc≠0 结束并让 `set -euo pipefail` 的 CLI 中止。
`2863` 的调用方 (`2991`、`2992`) 与 `old 85` 的调用路径都有兜底；zram 那两条（`3962`/`3965`）的
`team_swap_breakdown` 被 4 个 `read -r … <<<` 直接调用，没有兜底 —— zram 设备在读数瞬间消失才可能触发，
我不认为值得回改，但这条要 PM 认。

**R2 · 一条既有的假成功文案（P317 未改，超出它的声明范围）**。现场：

```
$ <TMUX_TMPDIR 指向普通文件> team_tmux_ensure_session; team_tmux_new_window "$TEAM_SESSION" "$TEAM_PM_WINDOW"
couldn't create directory …/notadir/tmux-1000 (Not a directory)
✗ 建不出 tmux session proj（tmux 起不来？后面的窗口操作都会失败）
couldn't create directory …/notadir/tmux-1000 (Not a directory)
new_window rc=1
```

`cmd-watch.sh:383-384` 是 `team_tmux_new_window … || true; team_ok "创建 PM 窗口 …"` —— 窗口没建出来，
下一行照样打「✓ 创建 PM 窗口」。P317 之前它也是这么说的（只是静静地），P317 之后至少两行错误在它上面。
要不要把 `team_ok` 挂在 rc 上，是行为决定，交 PM。

**R3 · 记账口径**：报告分类表与文件里的标签差 3 处（见复核三）；2 处理由归错桶。不影响判据。

## Decisions and deviations

- 我按任务书**没有**重跑全量门禁或 45 段闭包，也没有重跑任何选段：差异本身没有提出需要选段才能回答的疑问
  （注释安全性用 `bash -n` + `declare -f` 逐函数比对 + 反斜杠行比对就答完了，比跑门禁更直接）。
- 复现现场的**形状**与作者相同（配置根不存在 / 私有 `TMUX_TMPDIR`），但脚本、断言与临时根都是我自己的；
  作者的脚本我读原文核对过，没有直接运行它。
- 未改任何产品/测试/规格文件；未合并、未推送、未重选模型。

## Suggested next steps

- PM 若按本复核合入：`R1` 建议只在 `CHANGELOG`/`DECISIONS` 留一句（zram 读数瞬间消失会中止 `team ps`），不复改；
  `R2` 需要一次行为裁定（`team_ok "创建 PM 窗口"` 要么挂 rc，要么改成「session/window 没建出来」的具名失败）；
  `R3` 建议在 P317 报告里改数字或直接删掉分类计数，避免下一个人拿它当口径。
- 作者建议的「静态守卫（`|| true`/`2>/dev/null` 必须带理由标签）」属 `skills/teamsmith/tests/**`（`agent:dev`），
  是否要开下一条任务，请 PM 定；按复杂度纪律它是「新增守卫」，需要一个等价的退役项。
