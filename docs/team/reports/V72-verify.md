# V72 · P335 的独立定点验收：缺失尾屏的两个症状都收掉了，没有换新的吞法

task: V72   status: delivered   phase: verify   change: -
time: 2026-10-20T08:51Z
branch: `task/V72-launch-diag-verify`（本分支只放这份报告，不改实现）
受检对象：候选 `a5fd7add`（实现提交 `f7127401`），报告 `docs/team/reports/P335-dev-bob.md`。
方式：**自建私有夹具**（`/var/tmp/v72-verify`，不启 tmux、不碰任何席位的运行现场）+ 静态核对 + 轻量收口。
**没有跑门禁选段**（原因与证据见 §6），因此本报告不报任何「smoke 通过」。

## 判定：**PASS**（只对产品那一处：`team_pm_launch_diag` 的尾屏读数）

一句话：`pm-launch-tail.txt` 不存在时，改前那两条症状（shell 自己的 `No such file or directory` 漏到 stderr、
字节数印成空白）在改后都消失（stderr **131 → 0** 字节，那一格变成具名的一句），而尾屏存在/空白/空白且窗口仍在
三种现场与改前**逐字节相同**；读数上不再有任何 `2>/dev/null` / `|| true` / `then :`，判了存在之后读失败的那条
分支是具名的一句话（§4、§5）。

§5 另记一条我加测的边界现场（文件存在但**不可读**）：具名句子成立，但 stderr 仍有 **217 字节**噪声 —— 改前也是
217 字节，**不是本次引入、也不是本次承诺覆盖**的现场，因此不进判定，只作为可选后续登记。

## 1 · 反例（核心）：两条症状改前都复现，改后都消失

夹具（附录 A 原文，可重建）：只 source 一份 `lib/common.sh`，把三处「现场提问」用桩代替
（`team_pm_window_exists` / 状态 / `team_tmux` 抓屏），`TEAM_STATE_DIR` 指向 `/var/tmp/v72-verify/state/*`。
改前/改后两份库来自 `git show a5fd7add~2:…` 与 `git show a5fd7add:…`（注意：**`<候选>^` 是已有的实现提交**
`f7127401`，取到的是改后那份；真正的改前是 `<候选>~2`，§8 有 cmp 证明）。每个 case 跑两次：一次 `2>&1` 合并，
一次 `2>` 单收。

`pm-launch-tail.txt` 不存在（`state/missing`，`pm-launch.exit` 记 `1750000000 7`）：

```
### before · missing · 2>&1 合并
/var/tmp/v72-verify/work/lib/common.sh: line 3401: /var/tmp/v72-verify/state/missing/pm-launch-tail.txt: No such file or directory
/var/tmp/v72-verify/state/missing/pm-launch-failed.log
### before · missing · stderr 单收：131 字节
    | /var/tmp/v72-verify/work/lib/common.sh: line 3401: …/missing/pm-launch-tail.txt: No such file or directory
### before · missing · 诊断正文（读者第一眼看到的那一格）
pane   : /var/tmp/v72-verify/state/missing/pm-launch-tail.txt（ 字节）
```

```
### after · missing · 2>&1 合并
/var/tmp/v72-verify/state/missing/pm-launch-failed.log
### after · missing · stderr 单收：0 字节（空文件）
### after · missing · 诊断正文
pane   : /var/tmp/v72-verify/state/missing/pm-launch-tail.txt（未写出：harness 还没落这份尾屏）
```

两侧其余各行（`reason` / `target` / `state` / `cmd` / `bin` / `exit` / `render` / `--- pane ---` 那条提示）
逐字相同 —— 也就是这一改动只碰了那一格。

**这不是人为造的现场**：`common.sh:3646` 在 respawn 前 `rm -f` 掉上一轮的尾屏，而尾屏由窗口 harness
**在 CLI 退出之后**才写（`team_pm_launch_cmd` 生成的 inner 脚本：`exec <cli>` → `rc=$?` → 写 exit 文件 →
`capture-pane` 落 `pm-launch-tail.txt`，`common.sh:3542`/`3546`）。所以 CLI 还活着就走失败早退（V71 读到的
`model metadata publication failed`，`common.sh:3665`/`3676`）时，那份尾屏**按构造就是不存在**。
（行号是候选 `a5fd7add` 的；改前那份同样三处各早 12 行。）

**夹具没有碰 tmux**：把 `tmux` 换成一个打印 `TMUX-TOUCHED-BY-FIXTURE` 并 `exit 99` 的桩放在 PATH 最前、
`TMUX_TMPDIR` 指向不存在的目录再跑一次同一条 case：

```
$ env PATH="/var/tmp/v72-verify/shimtmux:$PATH" TMUX_TMPDIR=/nonexistent-tmux-dir \
      bash case.sh …/common.after.sh missing …/probe-state 2>probe.stderr >probe.stdout
rc=0 ; stderr：空 ; TMUX-TOUCHED 命中数：0
```

## 2 · 正向不变：尾屏存在且非空

同一夹具、同一 state 目录路径（改前/改后各跑一次，输出只把 `==== <时间戳> · PM 启动失败 ====` 那一行归一化）：

```
### tail-ok（内容 41 字节）· 改后诊断正文
pane   : /var/tmp/v72-verify/state/tail-ok/pm-launch-tail.txt（41 字节）
--- pane（CLI 退出那一刻，harness 自抓）---
FAKE-PM-FAIL: cannot start (intentional)
--- end ---
```

```
$ cmp -s <(norm before/tail-ok.diag) <(norm after/tail-ok.diag)  → IDENTICAL
$ stderr 单收：before 0 字节 / after 0 字节
```

## 3 · 空白尾屏：两个原分支一个字没动

```
### tail-blank（文件只有 7 个换行，窗口不在）· before 与 after 相同
pane   : /var/tmp/v72-verify/state/tail-blank/pm-launch-tail.txt（7 字节）
--- pane ---
（窗口已不存在或始终空白：用上面的 render 命令手工跑一次看它的报错）

### tail-blank-window（文件只有 3 空格 + 2 换行 = 5 字节，窗口还在）· before 与 after 相同
pane   : /var/tmp/v72-verify/state/tail-blank-window/pm-launch-tail.txt（5 字节）
--- pane（重新抓取）---
RECAPTURED-FROM-PANE
--- end ---
```

```
$ cmp -s <(norm before/tail-blank.diag)          <(norm after/tail-blank.diag)          → IDENTICAL
$ cmp -s <(norm before/tail-blank-window.diag)   <(norm after/tail-blank-window.diag)   → IDENTICAL
```

后一例走的是**真代码**：`team_pm_window_exists` 桩成「在」，`team_tmux` 桩成返回一屏内容，
`team_pm_pane_tail` 与 `team_pane_tail_normalize` 都是库里原样的实现（含 12 次有界重试与归一化）。

四个现场的 stderr 字节数（改前 / 改后）：`missing 131/0`、`tail-ok 0/0`、`tail-blank 0/0`、
`tail-blank-window 0/0`。

## 4 · 没有换成另一种吞法（静态 + 实测）

改后那一块（`common.sh:3399-3413`）里逐项核对：

| 检查 | 读数 |
|---|---|
| 读数行上还有 `2>/dev/null` 吗 | 没有。整块唯一的 `2>/dev/null` 在**注释里**（解释历史成因），不在代码上 |
| 还有 `\|\| true` / `if … then :` 吗 | 没有 |
| 判了存在之后读失败 | 落到具名一句 `（读不出字节数：判了存在之后、读之前文件被移走或不可读）`（实测见 §5） |
| 文件不在 | 具名一句 `（未写出：harness 还没落这份尾屏）`，不是空答案、也不是 0 |

```
$ awk '/^team_pm_launch_diag\(\)/,/^}/' variants/common.after.sh | grep -nE 'tailf|tail_bytes|2>|\|\|'
9:printf 'state  : %s\n' "$(team_pm_state 2>/dev/null || echo '?')"        # ← 既有，问「状态」，不是读数
11:printf 'bin    : %s\n' "$(team_pm_bin_path 2>/dev/null || echo '?')"     # ← 既有，问「可执行文件」
18:tailf="$(team_pm_launch_tail_file)"; pane=""; src=""; tail_bytes=""
22:if [ -f "$tailf" ]; then
23:  tail_bytes="$(wc -c < "$tailf" | tr -dc '0-9')"
25:    printf 'pane   : %s（%s 字节）\n' "$tailf" "$tail_bytes"
27:    printf 'pane   : %s（读不出字节数：判了存在之后、读之前文件被移走或不可读）\n' "$tailf"
30:  printf 'pane   : %s（未写出：harness 还没落这份尾屏）\n' "$tailf"
```

带 `# 留：` 的两行是既有的、有具名理由的吞（问「状态/可执行文件」的现场提问，进程/窗口可能刚消失），
本次没有改它们，也没有把它们扩展到读数上。

## 5 · 我加测的边界现场：文件存在但不可读 → 具名句子成立，stderr 仍有 217 字节噪声（既有、非本次引入）

`chmod 000` 造一个「判得出存在、读不出内容」的文件，两侧都跑：

```
### before · tail-unreadable · stderr：217 字节
    | …/common.sh: line 3401: …/pm-launch-tail.txt: Permission denied
    | grep: …/pm-launch-tail.txt: Permission denied
### before · 那一格
pane   : …/pm-launch-tail.txt（ 字节）

### after · tail-unreadable · stderr：217 字节
    | …/common.sh: line 3405: …/pm-launch-tail.txt: Permission denied
    | grep: …/pm-launch-tail.txt: Permission denied
### after · 那一格
pane   : …/pm-launch-tail.txt（读不出字节数：判了存在之后、读之前文件被移走或不可读）
```

读法：改后**具名分支确实是这条路走到的**（那句「读不出字节数」出现在诊断里），读者不再拿到空数字；
但 stderr 上仍有两条噪声，来源是两处**既有**的写法 —— `wc -c < "$tailf"` 的重定向失败由 shell 自己报
（这次没有 `2>/dev/null` 可挡），以及紧随其后的 `if [ -s "$tailf" ] && grep -q …` 里 `grep` 读不了。
触发条件很窄：文件被 harness 写出来、但当前用户打不开（同一用户写的一般不会）；改前改后同为 217 字节，
所以**不是回归**，也不在本次要修的现场（缺失）里。

它改变的是下一步，不是判定：如果 PM 要收这一类，最省的一笔是**与 `cmd-agents.sh:533` 同批**（§9 同一行缺陷），
把读数收进一个具名失败分支；不建议为它单独开一笔。本次不改实现、也不因此扣分。

## 6 · 门禁面：6i 的断言不受这次改动影响（静态 + 形状证据）；选段未跑

`smoke.sh:4468` 断的是 `^pane   : .*（[0-9]+ 字节）`，而它所在的 6i 现场**一定会写出尾屏** —— 同一段
`smoke.sh:4471` 还有一条 `assert_has …/pm-launch-tail.txt "FAKE-PM-FAIL"`，即该现场尾屏存在且非空。所以
这次新增的「未写出」分支在那条断言里不可达，6i 走的是没变的那一格：

```
$ grep -Eq '^pane   : .*（[0-9]+ 字节）' after/tail-ok.diag   → MATCH（6i 断言形式成立）
   after/tail-ok.diag:9:pane   : …/tail-ok/pm-launch-tail.txt（41 字节）
$ grep -Eq '^pane   : .*（[0-9]+ 字节）' after/missing.diag   → NO MATCH（新分支不落在该正则上，也不该落）
```

**选段没跑**，原因不是省事，而是任务书的前置条件当场不成立 —— `ps` 里有别的席位在跑 smoke：

```
$ ps -eo pid,etime,args | grep "[s]moke.sh"
 517281  06:27 bash -c cd …/.worktrees/dev && … smoke.sh --select 36 …
 517488  06:27 bash skills/teamsmith/tests/smoke.sh --select 36
1270933  00:25 bash …/p98-tree-…/skills/teamsmith/tests/smoke.sh --select 12k,31
```

**未验**：6i 的端到端实跑（`team up` 失败现场的真 tmux 路径）。替代证据是 §2 的 `tail-ok` —— 它与 6i 走同一个
函数、打印同一形状的 `（41 字节）` 行，并与改前逐字节相同。

## 7 · 轻量收口（全部实跑）

| 命令 | 读数 |
|---|---|
| `bash -n /var/tmp/v72-verify/variants/common.after.sh`（候选那份逐字节） | 无输出，rc=0 |
| `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` | `Totals: 21 passed, 0 failed (21 items)`，rc=0 |
| `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"` | `files=1879 hits=0 names=ok user=resolved`，rc=0 |
| `git diff --check a5fd7add~2 a5fd7add` | 无输出，rc=0 |
| `git diff --check`（工作树） | 无输出，rc=0 |

`openspec` 不在登录 shell 的 PATH 上（`bash -lc 'command -v openspec'` → rc=1），它装在 `$HOME/.bun/bin/openspec`；
上表那条是前置了 `$HOME/.bun/bin` 之后跑的。

## 8 · 范围核对：候选改的确实只有那一处

```
$ git show --stat --oneline f7127401 | tail -2
 skills/teamsmith/scripts/lib/common.sh | 18 ++++++++++++++---
 1 file changed, 15 insertions(+), 3 deletions(-)
$ git show --stat --oneline a5fd7add | tail -2
 docs/team/reports/P335-dev-bob.md | 183 ++++++++++++++++++++++++++++++++++++++
$ git diff --stat main...a5fd7add
 docs/team/reports/P335-dev-bob.md      | 183 +++++++++++++++++++++++++++++++++
 skills/teamsmith/scripts/lib/common.sh |  18 +++-
 2 files changed, 198 insertions(+), 3 deletions(-)
```

两份库整文件 `diff -u` 只有那一个 hunk（`@@ -3396,9 +3396,21 @@`，15 增 3 删），其余 375 000 余字节逐字未动。
夹具取的两份库也核对过：`git show a5fd7add:… | cmp -` 与夹具的 `after` **逐字节相同**，
`git show a5fd7add~2:… | cmp -` 与夹具的 `before` 逐字节相同；且改前那份与 main 的库逐字节相同
（`git diff --stat main:… a5fd7add~2:…` 空输出）—— 也就是说，改前侧测的就是 main 上的行为，不是另一个版本的。

任务书提到候选落后 main 的两处（`docs/team/BOARD.md`、`docs/team/reports/V71-dev2.md`）不在本判定里，
本报告没有对它们取证。

## 9 · 相邻缺陷（作者已登记，我确认它真实存在，未动）

`skills/teamsmith/scripts/lib/cmd-agents.sh:533` 是**同一行**写法，位于 `team_dispatch_launch_diag` 里：

```bash
printf 'pane   : %s（%s 字节）\n' "$tailf" "$(wc -c < "$tailf" 2>/dev/null | tr -dc '0-9' || echo 0)"
```

它上面确实有一个「等尾屏落盘」的有界循环（`while [ "$i" -lt 20 ] … sleep 0.05`，最多 ~1s，`cmd-agents.sh:520-523`），
所以比 PM 侧稀；等完之后文件仍不在时，两个症状与 PM 侧改前同形。任务书明确「不碰别的 `cmd-*.sh`」，
所以本次没动、也没实测（静态成立）。建议与 §5 合成一笔后续，由 PM 决定是否开。

## 附录 A · 夹具原文（可用它复跑，不依赖我的 `/var/tmp` 状态）

```bash
# /var/tmp/v72-verify/case.sh
#!/usr/bin/env bash
set -u
lib="$1"; scene="$2"; st="$3"
TEAM_SESSION=v72-fixture-sess
TEAM_PM_WINDOW=pm
TEAM_PM_CMD='/fixture/bin/pi-fake --pf {prompt_file}'
TEAM_STATE_DIR="$st"
export TEAM_SESSION TEAM_PM_WINDOW TEAM_PM_CMD TEAM_STATE_DIR
mkdir -p "$st"
. "$lib" || { echo "SOURCE FAILED" >&2; exit 9; }

team_pm_window_exists() { case "$scene" in tail-blank-window) return 0 ;; *) return 1 ;; esac; }
team_tmux() { printf 'RECAPTURED-FROM-PANE\n'; }
case "$scene" in
  tail-blank-window) team_pm_state() { printf 'idle:pi'; } ;;
esac

team_pm_launch_diag '窗口里的 pi-fake 立刻退出了（exit code 7）' 'exec bash -lc …(render)·'
```

```bash
# /var/tmp/v72-verify/run.sh  —— 用法：run.sh <before|after>
#!/usr/bin/env bash
set -u
variant="${1:?}"; root=/var/tmp/v72-verify
lib="$root/work/lib/common.sh"
cp "$root/variants/common.${variant}.sh" "$lib"
out="$root/out/$variant"; rm -rf "$out"; mkdir -p "$out"

setup() {
  local scene="$1" st="$2"
  rm -rf "$st"; mkdir -p "$st"
  printf '1750000000 7\n' > "$st/pm-launch.exit"
  case "$scene" in
    tail-ok)           printf 'FAKE-PM-FAIL: cannot start (intentional)\n' > "$st/pm-launch-tail.txt" ;;
    tail-blank)        printf '\n\n\n\n\n\n\n' > "$st/pm-launch-tail.txt" ;;
    tail-blank-window) printf '   \n\n' > "$st/pm-launch-tail.txt" ;;
    tail-unreadable)   printf 'SECRET\n' > "$st/pm-launch-tail.txt"; chmod 000 "$st/pm-launch-tail.txt" ;;
    missing) : ;;
  esac
}

for scene in missing tail-ok tail-blank tail-blank-window tail-unreadable; do
  st="$root/state/$scene"
  setup "$scene" "$st"                                                    # ① 2>&1 合并
  bash "$root/case.sh" "$lib" "$scene" "$st" > "$out/$scene.merged" 2>&1
  cp "$st/pm-launch-failed.log" "$out/$scene.diag"
  setup "$scene" "$st"                                                    # ② 2> 单收
  bash "$root/case.sh" "$lib" "$scene" "$st" > "$out/$scene.stdout" 2> "$out/$scene.stderr"
  printf '%s\n' "$(wc -c < "$out/$scene.stderr")" > "$out/$scene.stderr.bytes"
done
chmod -R u+rwX "$root/state" 2>/dev/null
```

复现两条侧：

```bash
C=a5fd7add                                   # 或 f7127401
mkdir -p /var/tmp/v72-verify/variants
git show "$C~2:skills/teamsmith/scripts/lib/common.sh" > /var/tmp/v72-verify/variants/common.before.sh
git show "$C:skills/teamsmith/scripts/lib/common.sh"   > /var/tmp/v72-verify/variants/common.after.sh
bash /var/tmp/v72-verify/run.sh before && bash /var/tmp/v72-verify/run.sh after
cat /var/tmp/v72-verify/out/after/missing.stderr.bytes     # 0
cat /var/tmp/v72-verify/out/before/missing.stderr.bytes    # 131
```

## 未做的（如实写）

- 没有跑门禁选段/整套/容器（任务书边界 + 机器上另有席位的 smoke 在跑，§6）：6i 端到端「未验」。
- 没有端到端走真实的 `team up` 失败链去触发 `model metadata publication failed`：那份尾屏按构造就是缺席（§1 引的两处代码），
  为造这条分支要人为把 metadata 发布弄坏，证据不会比直接调该函数更接近现场。
- 没有实测 `cmd-agents.sh:533` 的 worker 侧同形缺陷（§9 只做静态确认，任务书边界是不碰其它 `cmd-*.sh`）。
