# P335 · PM 启动失败诊断里那两个空答案

agent: dev-bob   status: delivered   time: 2026-10-20T08:50Z
branch: `task/P335-launch-diag-tail`   phase: apply   change: `-`
写集：`skills/teamsmith/scripts/lib/common.sh`（只 `team_pm_launch_diag` 的一处读数与它必要的分支）+ 本报告
提交：`f7127401`

## 结论先写

`pm-launch-tail.txt` 不存在时那两个症状是一件事的两个后果，现在两处都按「先判存在、再读数」收掉：

- **改前实测**：stderr 收到 `…/pm-launch-tail.txt: No such file or directory`（138 字节），诊断里那一格是
  `（ 字节）`（空数字）。原因是 `2>/dev/null` 写在 `< "$tailf"` **之后**——shell 处理这个重定向时它还没生效；
  而 `wc` 没跑，管道末端的 `tr` 照样退出 0，`|| echo 0` 因此不触发。
- **改后实测**：同一现场 stderr **0 字节**，那一格变成具名的一句 `（未写出：harness 还没落这份尾屏）`。
- 文件存在时行为逐字未变（同样四字节数、同样 `--- pane（…）---` 段）；「只有空白不算抓到」的那套
  `[ -s ] && grep -q '[^[:space:]]'` 分支与外面重抓**一个字没动**（四处现场 diff 只有缺失那一条不同，见「翻转证据」§3）。

没有新增函数、没有新增门禁段、没有换新的吞法：文件不在就说出「什么没写出来」，判断存在之后读失败（文件被移走/不可读）
也单独具名，不再有任何 `2>/dev/null` 挂在读数上。

## 翻转证据（红 → 绿）

夹具（私有磁盘，不入库）：`/var/tmp/p335-dev-bob/{fixture.sh,run.sh}`，改前的 `common.sh` 快照在
`/var/tmp/p335-dev-bob/before/lib/common.sh`。夹具只 source 一份 `lib/common.sh`，把 `TEAM_STATE_DIR`
指到私有目录，并用同签名的桩替掉三个「现场提问」（`team_pm_state` / `team_pm_bin_path` / `team_pm_window_exists`，
`tail-blank-window` 一例另替 `team_tmux`）——不启 tmux、不碰仓库、不动任何席位的运行现场。这正是
`team_pm_launch_diag` 被 `model metadata publication failed` 早退分支调用时的状态：respawn 刚发生，窗口里的
harness 还没走到写尾屏那一步。

跑法：`bash /var/tmp/p335-dev-bob/run.sh {before,after} <lib/common.sh 路径>`，每个 case 跑两次——
一次 `2>&1` 合并（读者第一眼看到的东西），一次 `2>` 单收（量 stderr 字节数）。完整原始输出：
`/var/tmp/p335-dev-bob/out/before.log`、`/var/tmp/p335-dev-bob/out/after.log`。

### 1 · 反例：`pm-launch-tail.txt` 不存在

改前（`common.sh` 为 HEAD 的父提交快照）：

```
### [before] missing-tail · 2>&1 合并输出
before/lib/common.sh: line 3401: /var/tmp/p335-dev-bob/out/before/missing-tail/state/pm-launch-tail.txt: No such file or directory
--- diag: /var/tmp/p335-dev-bob/out/before/missing-tail/state/pm-launch-failed.log ---
reason : 窗口里的 pi-fake 立刻退出了（exit code 7）
target : p335-fixture-sess:pm
state  : missing
cmd    : TEAM_PM_CMD=/fixture/bin/pi-fake\ --pf\ \{prompt_file\}
bin    : /fixture/bin/pi-fake
exit   : 7（harness 记录的 CLI 退出码）
render : exec bash -lc …(render)·
pane   : /var/tmp/p335-dev-bob/out/before/missing-tail/state/pm-launch-tail.txt（ 字节）
--- pane ---
（窗口已不存在或始终空白：用上面的 render 命令手工跑一次看它的报错）
### [before] missing-tail · stderr 单独收：138 字节
    | before/lib/common.sh: line 3401: /var/tmp/p335-dev-bob/out/before/missing-tail-stderr/state/pm-launch-tail.txt: No such file or directory
```

改后（工作树里的 `common.sh`，同一个 case、同一份桩）：

```
### [after] missing-tail · 2>&1 合并输出
--- diag: /var/tmp/p335-dev-bob/out/after/missing-tail/state/pm-launch-failed.log ---
reason : 窗口里的 pi-fake 立刻退出了（exit code 7）
target : p335-fixture-sess:pm
state  : missing
cmd    : TEAM_PM_CMD=/fixture/bin/pi-fake\ --pf\ \{prompt_file\}
bin    : /fixture/bin/pi-fake
exit   : 7（harness 记录的 CLI 退出码）
render : exec bash -lc …(render)·
pane   : /var/tmp/p335-dev-bob/out/after/missing-tail/state/pm-launch-tail.txt（未写出：harness 还没落这份尾屏）
--- pane ---
（窗口已不存在或始终空白：用上面的 render 命令手工跑一次看它的报错）
### [after] missing-tail · stderr 单独收：0 字节
```

`stderr 单独收：0 字节` 就是「stderr 干净」的读数；`2>&1` 那条输出里也没有任何 `No such file or directory`。

### 2 · 正向：尾屏存在且非空（没有把这条能力改坏）

改前 / 改后逐字相同（同样的字节数、同样的 `CLI 退出那一刻，harness 自抓` 来源与内容）：

```
### [after] tail-ok · 2>&1 合并输出
pane   : /var/tmp/p335-dev-bob/out/after/tail-ok/state/pm-launch-tail.txt（44 字节）
--- pane（CLI 退出那一刻，harness 自抓）---
FAKE-PM-FAIL: cannot start (intentional)
--- end ---
### [after] tail-ok · stderr 单独收：0 字节
```

### 3 · 空白尾屏：仍走原规则

两个分支都照原样（空白不算抓到，窗口不在就明确说；窗口在就从外面重抓）：

```
pane   : …/tail-blank/state/pm-launch-tail.txt（7 字节）
--- pane ---
（窗口已不存在或始终空白：用上面的 render 命令手工跑一次看它的报错）

pane   : …/tail-blank-window/state/pm-launch-tail.txt（4 字节）
--- pane（重新抓取）---
RECAPTURED-FROM-PANE
--- end ---
```

四处现场（去掉每次不同的时间戳行）改前↔改后 `diff`：只有 `missing-tail` 的 `pane` 行不同，`44`/`7`/`4` 三处逐字相同。

```
== tail-ok ==      pane   : …（44 字节）            （两边一致）
== tail-blank ==   pane   : …（7 字节）             （两边一致）
== tail-blank-window == pane   : …（4 字节）        （两边一致）
```

## 实现（一处，12 行）

`team_pm_launch_diag` 里原来那一行 `printf 'pane   : …' "$(wc -c < "$tailf" 2>/dev/null | tr -dc '0-9' || echo 0)"`
换成三段：`[ -f "$tailf" ]` 不在 → 具名「未写出」；在 → 读字节数，读得出就照旧打印 `（N 字节）`，
读不出（判了存在之后、读之前被移走或不可读）也具名。第三段是刻意留的：这正是本次要修的那只虫子所在的竞态
（尾屏由窗口里的 harness 异步落盘），把同一个坑往下留一层就等于没修。整段上方补了一条注释说明为什么
`2>/dev/null` 写在 `<` 之后不生效，避免下次有人「顺手」把它加回来。

`[ -s ] && grep -q '[^[:space:]]'` 的分支、`team_pm_launch_tail_file` 的路径解析、诊断文件其余各行、`team_pm_pane_tail`
的重试逻辑都没有改动。

## 静态收口（实跑）

| 命令 | 读数 |
|---|---|
| `bash -n skills/teamsmith/scripts/lib/common.sh` | 无输出，rc=0 |
| `openspec validate --all --strict` | `Totals: 21 passed, 0 failed (21 items)`，rc=0 |
| `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"` | `files=1877 hits=0 names=ok user=resolved`，rc=0（写完本报告后又跑了一次，仍 0） |
| `git diff --check` | 无输出（ok） |

**`openspec` 不在登录 shell 的 PATH 上**（`bash -lc 'command -v openspec'` → rc=1），它装在 `$HOME/.bun/bin/openspec`；
任务书里那条裸命令在本机会 `command not found`。上面那次是把 `PATH="$HOME/.bun/bin:$PATH"` 前置后跑的：

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
…
✓ spec/watchdog
✓ spec/writing-discipline
Totals: 21 passed, 0 failed (21 items)
rc=0
```

## 选段：这次没跑，原因与替代证据

受影响的门禁断言是 `smoke.sh:4468`（6i：`^pane   : .*（[0-9]+ 字节）`），但任务书的开跑条件是「`ps` 里没有别人的
`smoke.sh`」——我两次检查时另一个席位（dev）的 `--select 36` 正在跑：

```
$ ps -eo pid,etime,args | grep "[s]moke.sh"
 517281  03:16 bash -c cd …/.worktrees/dev && B=/var/tmp/p326-s36; … bash skills/teamsmith/tests/smoke.sh --select 36 …
 517488  03:16 bash skills/teamsmith/tests/smoke.sh --select 36
 921717  00:04 bash /var/tmp/p326-s36/tmp/teamsmith-smoke-pm_skills-…/p98-tree-p117red3b/skills/teamsmith/tests/smoke.sh --select 3b
```

所以按任务书没起自己的运行。顺带量了一次选段规模，说明「顺手跑一段」在这里不成立：

- `section-select.sh --paths skills/teamsmith/scripts/lib/common.sh` → `keys=45`（`6i` 是被 `11b` 的 needs 带进来的），
  已接近整套 135 段；
- `--select 6i` → `keys=10`（`2,3b,4,5,6,6i` 加四个 prologue）——6i 自己带一条 5 段的前置链。

替代证据是夹具的 `tail-ok` 一例：它走的是同一个 `team_pm_launch_diag`、打印同样的 `pane   : …（44 字节）` 形状，
正是 4468 那条断言的正则要吃的东西；而缺失尾屏（4468 覆盖不到的形状）由 §1 的两份原始输出直接钉住。

## 一处同形缺陷（不在我的写集，只登记）

`skills/teamsmith/scripts/lib/cmd-agents.sh:533`（worker 侧的 `dispatch-<agent>-launch-failed.log`）是**同一行**：

```bash
printf 'pane   : %s（%s 字节）\n' "$tailf" "$(wc -c < "$tailf" 2>/dev/null | tr -dc '0-9' || echo 0)"
```

它上面有一个最多 ~1s 的等尾屏循环，所以触发得比 PM 侧稀；但等完之后文件仍不在时，两个症状一模一样（shell 的
`No such file or directory` 照样漏到 stderr，字节数照样空）。任务书明确「不碰别的 `cmd-*.sh`」，所以我没改它——
建议 PM 按同一处法另派一笔（`smoke.sh:4601` 的 M8.2 断言吃的是同一形状，修法不需要动断言）。

## 未做的与理由

- **没有端到端跑 `team up` 的缺失尾屏现场**：那份尾屏是窗口里的 harness 在 CLI 退出那一刻自己写的，只有「harness 还没
  走到那一步」才会有今天这个形状（V71 是在 `model metadata publication failed` 这条早退分支上读到的），而这条分支要
  真触发得先让 metadata 发布失败——为它造一个人为故障，证据不会比直接调 `team_pm_launch_diag` 更接近真实现场。
- **没有跑整套门禁**：任务书要求不跑；另有席位在跑。
