# P127 · 等待引擎的 `printf | grep -q` 假缺（长帧下 SIGPIPE → 命中被当成「没出现」）· **apply** · dev

agent: dev　status: **DONE**
time: 2026-09-29T09:00Z
branch: `task/P127-pipefail-grep-q-sigpipe`（local 模式：不 push；分支留在 `.worktrees/dev` 等 PM 复验）
change: `-` ｜ specs: `-` ｜ phase: `apply`
anchor: `none (infra) — 只改等待引擎的匹配实现与自检，不改等待语义/预算/归因` ｜ deltas: `-`
证据包: `docs/team/reports/P127-dev/pkg/`（`lib.sh` + `run.sh` + `10-repro/20-fixed/30-libselftest/40-sweep`；不碰 tmux）
原始日志: `docs/team/reports/P127-dev/logs/`（`pkg-run.log`、`smoke-select-53.log`、`smoke-fast.log`、`smoke-full.log`）

**总结论**：等待引擎的四处 `printf '%s\n' "$c" | grep -qF` 在长帧上是**确定性**假缺 —— `grep -q`
命中即退 → 写端 SIGPIPE → `lib` 的 `set -o pipefail` 把整条管道读成 141 → 等待报「没出现」并耗尽视界。
同一帧、同一 needle 在修复前的谓词上 6/6 次 rc=1、裸管道 rc=141（pkg §10）；改成 bash 内匹配
（`[[ $c == *"$n"* ]]`，不存在写端）后 20/20 次 rc=0，长帧缺失仍照缺报（pkg §20）。
同族扫描把 `tests/**` 里「无界生产者 + 早退消费者 + rc 判定」的其余 27 处一并加上
`{ producer || true; } | grep -q` 守卫（判定语义不变，只掐掉写端 SIGPIPE），其余 124 处按「上界」逐类判定后保留。
长帧两向进自检（判据⑥：140017 B 帧，needle 在首行必须命中；不在必须报缺）并被 smoke §53 钉住，
红侧用 `--break=pipeshadow` 把匹配器影子回旧管道 —— 红侧精确红在「长帧命中」那条。

## 1 · 现场与根因

**机制**（PM 复现 + 我按 P124 的帧量级放大）：

```bash
$ bash -c 'set -uo pipefail; c="$(cat frame.txt)"; printf "%s\n" "$c" | grep -qF -- MARKER; echo rc=$?'
rc=141        # 真命中，却被 pipefail 读成「写端被 SIGPIPE 杀掉」
```

`grep -q` 命中第一行就退出 → `printf` 还在往管道里写 140 KB → 写端 SIGPIPE（141）→ `pipefail`
取管道最后一个非零 rc → 调用方 `|| return 1` / `|| miss=…` 把**命中**当成**没出现**。
上界是管道缓冲 64 KiB：帧小于它时写端早已写完，rc 不暴露问题（这也是它潜伏至今的原因）。

**为什么现在爆**：P124 的独立验证造出 **120607 B** 的合成帧，四条站点（`_pty_has_all` 的
`!needle`/正向两处 + `_pty_report_missing` 两处，brief 给的 `lib/pty-wait.sh:120/121/133/134`）
全部走这条管道 → 等待明明看见内容却报缺 → 超时 → 夹具假红（或该报缺的反而沉默）。
P94 的 `TEAM_AGENT_SCENE_LINES=0` 是同族（`tail -n 0` 让上游吃 SIGPIPE，CLI 141 中断）。

**回归窗口**：`P124-verify` 把最小复现留在
`docs/team/reports/P124-verify/pkg/logs/pty-needle-pipefail.log` —— 该包所在的 `task/P124-p124` 分支
**尚未并入本树**（`ls` 不存在）；本包 §10 用同一形状自建（`_pty_has_all` 6/6 假缺 + 端到端
「缺 [P127-长帧标记]」），不依赖那份文件。

## 2 · 修法

**引擎（4 站点，一处收口）**：新增 `_pty_contains`（`skills/teamsmith/tests/lib/pty-wait.sh:122`）：

```bash
_pty_contains() {                       # <capture> <literal>
  if [ "${PTY_SELFTEST_BREAK:-}" = "pipeshadow" ]; then
    printf '%s\n' "$1" | grep -qF -- "$2"; return $?   # 影子红侧：修复前的形状
  fi
  [[ "$1" == *"$2"* ]]
}
```

`_pty_has_all`（`!needle` = 必须缺席、正向 = 必须出现）与 `_pty_report_missing`（点名缺项/仍在项）
改为调用它 —— **不存在写端进程，就不存在 SIGPIPE**，`!` 取反与「缺/仍在」的语义逐字不变
（needle 都是单行字面量，子串判定与原 `grep -qF` 等价；pkg §20 用 20/20 命中、`!` 判假、
缺失 rc=1、报告串四个方向各钉一条）。

**为什么不用 here-string / 临时文件**：
- here-string（`grep -qF -- "$n" <<< "$c"`）也正确（pkg §10 控制组 rc=0），但每轮每 needle 多写一次
  临时文件、多 fork 一次 grep；等待引擎每轮跑 2× captures × N needles × 2 个谓词，成本要乘以轮数。
- 临时文件（`printf > f; grep -f`）多一次盘写 + 需要清理，收益相同。
- bash 内匹配是零进程、零 IO 的等价判定，且**构造上**没有写端 —— 后面再有人把 needle 换成
  多行/正则时，缺的会是功能而不是静默的假缺（`_pty_contains` 的注释里写明了这一点）。

**同族（27 处，见 §4）**：`{ producer || true; } | grep -q …`。`|| true` 只吞生产者的 SIGPIPE/读失败，
管道最后一个组件的 rc（也就是判定依据）逐字节不变：命中→0、未命中→1、生产者读不到→空输入→1
（与修复前「生产者失败 + grep 未命中」同一条分支）。

## 3 · Flip evidence（红 → 绿；PM 要的翻转证据）

### 3.1 历史红 → 当前绿（对象是**同一个 140019 B 的合成帧**）

`docs/team/reports/P127-dev/pkg/10-repro.sh` 从 git 历史里取修复前的 `pty-wait.sh`
（`git log -n2 -- lib/pty-wait.sh` 的倒数第二个版本），`20-fixed.sh` 跑当前树：

```
== 10 红前 结果 == ok=6 bad=0
  ok  合成帧 > 128 KiB（140019 B）
  ok  needle 在帧的最前面（第 1 行）
  ok  裸管道复现：printf|grep -qF 命中即退 → 写端 SIGPIPE → rc=141
  ok  修复前 _pty_has_all：6/6 次 rc=1（确定性假缺，不是竞态）
  ok  修复前端到端：needle 就在第一行，等待仍报 rc=1 + 现场「缺 [P127-长帧标记]」
== 20 绿后 结果 == ok=7 bad=0
  ok  绿后 _pty_has_all：20/20 次 rc=0
  ok  绿后 !needle：长帧里 needle 在 → 反向 needle 判假（rc=1）
  ok  绿后 _pty_report_missing：缺项点名、在场项不误报（缺 [P127-PREFIX-NEVER]）
  ok  绿后端到端：needle 在长帧最前面 → 等待 rc=0 并放出帧（首行 = needle）
  ok  绿后端到端：needle 不在长帧里 → rc=1 且现场点名缺项
```

### 3.2 红侧不依赖 git 历史：影子匹配器（`--break=pipeshadow`）

把 `_pty_contains` 影子回修复前的管道（同一份代码、只换匹配实现）：

```
== 30 库内自检 结果 == ok=6 bad=0
  绿侧结果行：== 结果 ==  ✓ 17  ✗ 0  SKIP 1
  影子结果行：== 结果 ==  ✓ 16  ✗ 1  SKIP 1
  ok  影子红侧：红的正是长帧命中那条（✗ 长帧命中被判成没出现（rc=1；断点=pipeshadow））
  ok  影子红侧：缺失那条在旧写法下仍然照缺报（红侧只动命中方向，方向分辨力在）
```

### 3.3 门禁里的常驻钉（smoke §53，append-only 一段）

`skills/teamsmith/tests/smoke.sh` 末段新增 §53（不碰 tmux、FAST 也跑）：

- 绿侧：`pty-wait.sh --self-test` rc=0，且日志里两条长帧断言都在；
- 红侧：`pty-wait.sh --self-test --break=pipeshadow` rc≠0，且 ✗ 正是「长帧命中被判成没出现」。

实跑（选段，8–9 s）：`✓ 53 绿侧…`、`✓ 53 红侧…`（日志 `logs/smoke-select-53.log`）。
配套把 §53 登记进 `section-paths.tsv`（key `53`）与 `section-budgets.tsv`（band 9 s → budget 60 s），
否则 §36①（「源码里有段没有行」）与 §0e 预算检查会红 —— 这一段是「新段落必须被门禁看见」的强制项。

### 3.4 守卫形状的机械断言 + 变异红侧（「改坏实现 → 守卫必须红 → 还原」）

`40-sweep.sh` 机械断言每个已修站点：旧形状 0 处 + 守卫形状在场（`pkg-run.log` 里逐条 ok）。
mutation 类红侧由 `--break=pipeshadow` 承担（§3.2/§3.3）。

### 3.5 被改动的既有翻转包实跑（证明守卫没把判定改坏）

| 翻转包 | 结果 |
|---|---|
| `flip-p23.sh`（九对断→红→还原→绿） | rc=0，✓27 ✗0（`== 结果 ==  ✓ 27  ✗ 0`） |
| `flip-m48.sh add`（重复 ID 守卫，两个方向） | rc=0，`flip-m48 全部成立` |
| `flip-m48.sh`（无参 = focus+add+assign） | add/assign 两腿 ✓；focus 腿在前置就停：`pattern not unique (0)` —— P123 `d0c35821` 重写 App.tsx 后夹具的变异锚点已失配（本任务未动面板源码；`main` 上同样失配） |
| `flip-p72.sh`（notify 发送者身份） | rc=0，`flip-p72 翻转成立`（✓13 ✗0；a–d 四条变异断掉→红→还原→绿） |
| `flip-m44.sh`（九现场红→绿 + 三变异） | rc=0，`九条预期全部成立` |
| `flip-m16.sh` | rc=2 前置不满足（该包要求 `TEAM_FLIP_BASE=<M16 修复前 sha>`；当前基线已含 M16），与本次改动无关 |
| `flip-p22.sh` | rc=3 前置不满足（要 `scripts/panel/node_modules`：`bun install --frozen-lockfile`），与本次改动无关 |
| `fixtures/p55/flip-p49.sh`（改过的回滚捕获） | 在一次性容器里跑（`container-tmux.sh -- bash …flip-p49.sh`）：rc=0，`FLIP 全绿：green 腿全绿 + 三条变异腿各在锚点转红`（leg1 B1 / leg2 C2 / leg3 E1）；宿主默认 server 不参与 |

## 4 · 同族扫描：界怎么判、剩下的为什么留

判定规则（brief 原文）：**生产者内容无界**（`printf '%s…' "$大变量"` / `cat <大文件>` / 全回滚
`capture-pane -S -`、`-S -400`）+ **消费者会早退**（`grep -q` / `head`）+ **rc 被用来判定**。
三者同时成立才算同族；只要其中一条不成立就保留。

**已修 27 处（+ 引擎 4 站点）**：

| 文件 | 站点 | 旧形状 → 新形状 |
|---|---|---|
| `lib/pty-wait.sh` | `_pty_has_all`×2、`_pty_report_missing`×2（原 120/121/133/134） | `printf | grep -qF` → bash 内匹配 |
| `panel-p21.sh` | 选择器探针（`focus_row`/`poll_row`） | `printf $c_probe \| grep -qF` → here-string（帧变量） |
| `panel-p21.sh` | `assert_no_class_heading`（保存的帧文件） | `sed 帧 \| grep -qE` → `{ sed … \|\| true; } \| grep -qE` |
| `panel-b2.sh` | 编辑器等待 ×2（`cap` = `-S -400`） | `cap \| grep -q` → `{ cap \|\| true; } \| grep -q` |
| `panel-b3.sh` | 详情/brief 等待 ×2（`cap` = `-S -400`） | 同上 |
| `panel-flip-p123.sh` | b3 fold 日志判红 | `sed 日志 \| grep -qF` → 守卫 |
| `smoke.sh` | `pm_wait_delta`（PM 日志的 sed 区间） | sed → 守卫 |
| `smoke.sh` | P55 真 pane 等待（`-S -` 全回滚） | `tmux capture-pane \| grep -q` → 守卫 |
| `flip-m44.sh` | 探针日志 ×2（`plain`） | `plain \| grep -q` → 守卫 |
| `flip-m48.sh` | 探针日志 ×6（`plain`，三个模式共用的断言） | 同上 |
| `flip-m16.sh` | digest 探针日志（`grep \| grep -q`） | 过滤器 → 守卫 |
| `flip-p22.sh` | 红侧日志过滤 | `grep '\✗' \| grep -q` → 守卫 |
| `flip-p23.sh` / `flip-p72.sh` | 红侧日志过滤（各 1） | 同上 |
| `fixtures/p55/flip-p49.sh` | 回滚捕获 ×2 + 遗体现场读取 + 现场文件链 | 守卫 |
| `death-cause.sh` | 回滚捕获轮询 | 守卫 |

**保留 124 处，按「上界」分类**（全文清单 `docs/team/reports/P127-dev/sweep-grepq.tsv`，一行一站点）：

> `sweep-grepq.tsv` 的 `fixed` 类按**形状**判定（`{ … || true; } \| grep -q` 或 `<<<`），共 31 行 =
> 上表 27 处 + 2 行注释（`panel-p21.sh:489/527`）+ 2 行本任务之前就在的守卫（`panel-flip-m54.sh`）；
> 155 行 = 124 `other` + 31 `fixed`，逐行可对。

| 类 | 数量 | 上界 |
|---|---|---|
| 标量/消息 `printf '%s' "$var"`（CLI 输出、错误串、help、单行 JSON、一个窗口的捕获） | 74 | 单条消息/单值，远小于 64 KiB；样例：`$ISOLATE`（`team paths` 的 JSON）、`$P10_CAP`（一个 pane 屏） |
| 其它（夹具单词输出、`roster` 行、`panel.js --version`、私有 server 的 `tmux ls`） | 21 | 均一行或数行 |
| 可见屏 `capture-pane`（**无** `-S`） | 9 | 上界是窗格几何（≤ 若干屏） |
| `tmux list-windows/list-panes/display-message` | 7 | 协议输出，一行/窗口 |
| `grep … \| grep -q`（先过滤再判） | 6 | 中间输出是过滤后的命中行 |
| `git status --porcelain` / `git show` | 4 | 夹具仓库，很小 |
| `tail -1/-25`、`head -1` | 3 | 消费者自己在管道**末尾**，输出已被限行 |

**`| head` 家族**（18 处含 `head` 于条件中的站点，清单 `sweep-head.txt`）：两类 ——
`… | head -N` 里 `head` 是**最后一个消费者**（rc 不参与判定，如 `diff | head -4` 只用于失败信息），
或生产者的输出本身已定行（`tmux list-panes | head -1`，夹具里 1–3 个 pane）。
真正同族的「回滚捕获 + `head`」只出现在 `p55` 两处，其改动与本次一并做了（见上表）。

## 5 · 验收命令与结果

```bash
# 1) spec 结构
openspec validate --all --strict                       # Totals: 14 passed, 0 failed
# 2) 段落登记自检（新增 §53 的必配项）
bash skills/teamsmith/tests/section-select.sh --check  # ok 7  bad 0（115 段 / 115 行）
bash skills/teamsmith/tests/section-guard.sh --budget-check
                                                       # ok 覆盖 115/115；factor=4 / floor=60
# 3) 证据包（红前/绿后/影子红侧/同族）
bash docs/team/reports/P127-dev/pkg/run.sh             # ok=50 bad=0 finding=0 skip=0 → PASS
# 4) 门禁
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh # → FAST 结果行见 logs/smoke-fast.log
bash skills/teamsmith/tests/smoke.sh                   # → 全量结果行见 logs/smoke-full.log
```

- **FAST**（`logs/smoke-fast.log`）：**✓ 3093 ✗ 0**，rc=0（`smoke 全绿`；115 段收口，增量与结果行都是 ✓3093 ✗0，
  一致；FAST 模式跳过 34 个真进程段落）。§53 预算 60s、用时 9s、✓2 ✗0；
  第一轮跑（§53 未登记时）是 ✗6 —— 6 条红全部落在「新段落没登记进 `section-paths.tsv`/`section-budgets.tsv`」
  （§36① 的「源码里有段没有行：53」、§36④ 的 FULL 计数 114 vs 115、§0e 的预算检查 2 条）；登记后归零。
- **全量**（`logs/smoke-full.log`）：**✓ 3759 ✗ 0**，rc=0（`smoke 全绿`；08:59:49→09:25:59，
  114 段收口 —— `14c` 是 FAST-only 自检，全量本就不开它；增量与结果行都是 ✓3759 ✗0，一致；
  开跑时排在另一套全量之后（门禁锁排队，日志第一行记了它），无冲突）。
  相关段落：§53 ✓2 ✗0（9s）· §41 p55 pane 留存 ✓（含 `-S -` 遗体画面）· §52 p113 席位死因 ✓3。
  最慢段：§38 设置选项 295s（预算 1248s），无超时、无 SKIP。
- 本任务只改 `skills/teamsmith/tests/**`（含 smoke 的 append-only §53 与两张登记表），
  不改等待语义、预算系数、归因规则，也不动任何生产路径。

## 6 · 残余与已知限制

1. **长帧守卫用合成长帧，不用真 pane**：§53 的证据是 140017 B 的合成帧（needle 在首行）。
   真 pane 的 120 KB 帧要 tmux + 面板构建，属 `38-b/38-f` 的真 pane 段；本段是纯逻辑、
   FAST 也跑，作为常驻钉更合适（真 pane 段不需要重复钉这个机制）。
2. **bash 内匹配与 `grep -qF` 的等价边界**：对**单行字面量** needle 两者等价（`grep -qF` 用换行分隔，
   子串包含关系一致）。若以后有人把 needle 写成多行，`_pty_contains` 需要同步升级（注释里点名了）。
3. **`head` 家族未动**：见 §4 的分类 —— 没有「无界生产者 + rc 判定」的组合；
   若以后出现 `cat 大文件 | head -N` 且拿 rc 判定，需要同族处理。
4. **观察（不在 P127 范围，未改）**：`section-guard.sh --loop-check` 在真 tests 目录上报
   `tmp-hygiene.sh:1149` 有一条未登记的 `while+sleep` 循环（P122 `5e244057` 引入；
   门禁的 §0e 夹具只扫 smoke.sh + lib，覆盖不到它）。留给 PM 决定是否开任务补登记。
5. **观察（不在 P127 范围，未改）**：`flip-m48.sh` 的 focus 腿已失配（P123 `d0c35821` 重写 App.tsx
   后锚点 `const row = focusRow(rows, current)\n if (!row) return\n…` 不再唯一）；`add`/`assign` 两腿照旧成立。
   门禁不调用它（`grep flip-m48 smoke.sh` = 0），但下次动到 §4c/面板焦点时建议顺手把锚点改成
   `focusRow(rows, current)` 的行锚。
