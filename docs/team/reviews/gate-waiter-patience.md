# gate-waiter-patience · 独立复验（清单 7.1–7.4）

- 判定: **PASS**（附一条与本 change 无关的门禁夹具缺口 F1，见 §6）
- task: **V103** · agent: dev3 · phase: verify · change: `gate-waiter-patience`
- 受检提交: `57bed221`（我的 worktree `task/V103-gwp-verify` 与 main 同一个提交，`git diff HEAD main` 为空）
- 受检实现与缓存反例: P338（`4f11ede7`）、P372（`§34b⑨c`）
- 现场: `/var/tmp/v103/{logs,repo,tmp}`；作业 `v103-7-1-7-2`、`v103-34d-default-lock`。除私有克隆 `/var/tmp/v103/repo` 里那一次变异（已还原）之外，本轮没有改动任何代码。

## 0 · 结论

| 清单 | 结果 | 一句话 |
|---|---|---|
| 7.1 定点执行 `--select 34,34b,34d,36` | **成立** | ✓390 ✗1；唯一那条红是夹具在私有锁名下自相矛盾（F1），换回默认约定后 §34d 单段重跑 ✓107 ✗0。四段合计 367 条段内断言全绿 |
| 7.2 一条反向对照（心跳来源砍回只读 `.holder`） | **成立** | 红的恰是 `§34b⑭①` 那四条（含 `rc=0` 那条正向断言），⑨b 的 12 条纯函数腿照旧绿；还原后 ✓128 ✗0 |
| 7.3 没有回归 | **成立** | §34b① 7 条、§34b⑦ 9 条、§34② 7 条，共 23 条全绿：`rc=2`、点名持有者、`没有运行`、判定 `FAIL`，以及「排队超限不产生 TIMEOUT 判定」这一条正向断言 |
| 7.4 本记录 | **成立** | 本文件 |

清单条目没有勾，按协议留给 PM。

## 1 · 7.1 定点执行（不是查表）

```bash
# $HOME/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev3
TMPDIR=/var/tmp/v103/tmp/7-1 TEAM_SMOKE_LOCK=/var/tmp/v103/lock/7-1.lock TEAM_SMOKE_LOCK_WAIT=1800 \
  bash skills/teamsmith/tests/smoke.sh --select 34,34b,34d,36
```

`TMPDIR` 与 `TEAM_SMOKE_LOCK` 都指向 `/var/tmp/v103` 下我自己的目录（不排队、不占机器级门禁锁）。日志 `/var/tmp/v103/logs/7-1.log`。

```
7.1 RC=1 WALL=1563s
--- fingerprint after 7.1: 57bed221e140d757d8ecfd426fcfd83c1eb97b24 / 0 dirty

#5 34  · 门禁锁：排队/运行分开记账                     · ✓35  ✗0 SKIP0 · 67s
#6 34b · 门禁锁排队守卫：超上限要大声失败并点名持有者  · ✓104 ✗0 SKIP0 · 46s
#7 34d · 身份面：锁被删/被换 … 入场检查；等待者          · ✓106 ✗1 SKIP0 · 244s
#8 36  · 选段与分段账本自检                            · ✓121 ✗0 SKIP3 · 1201s
账本自查： 8 段收口 · 增量 ✓390 ✗1 SKIP3 ｜ 结果行 ✓390 ✗1 —— 一致
== 选段结果 ==  ✓ 390  ✗ 1
```

（`#1`–`#4` 是前导段 0/0b/0c/0d 共 24 条 ✓。）跑前与跑后 `git rev-parse HEAD` 都是 `57bed221e140…`、`git status --porcelain --untracked-files=all` 都是 0 行，而且这一跑不是以 exit 4（运行指纹不一致 → 判定无效）收场的，所以它的 ✓/✗ 算数。

唯一那条红，原文：

```
✗ 34d 2.1 默认路径 → 伴生锁（同行同目录、basename + .machine）
    （期望 [/var/tmp/v103/lock/.teamsmith-smoke.lock.machine]，实际 [/var/tmp/v103/lock/.7-1.lock.machine]）
```

它不是我给的锁名造成的**产品**问题：被断言的推导正好是对的（`.7-1.lock.machine` 就是「basename + `.machine`」），红的原因是夹具把默认 basename 写死在期望值里 —— 详见 §6 的 F1。换回默认约定（不设 `TEAM_SMOKE_LOCK`，`TMPDIR` 仍是私有目录，于是默认锁路径落在 `/var/tmp/v103/tmp/7-1b/teamsmith-smoke.lock`，依旧不碰机器锁）重跑这一段：

```bash
env -u TEAM_SMOKE_LOCK TMPDIR=/var/tmp/v103/tmp/7-1b \
  bash skills/teamsmith/tests/smoke.sh --select 34d
```

```
✓ 34d 2.1 默认路径那一条：外层设了 TEAM_SMOKE_LOCK=/var/tmp/v103/tmp/7-1b/teamsmith-smoke.lock → 按同一规矩换输入（避免误判）
✓ 34d 2.1 默认路径 → 伴生锁（同行同目录、basename + .machine）
✓ 34d 2.1 私有 TEAM_SMOKE_LOCK 形状 → 默认路径取它
✓ 34d 2.1 私有 TEAM_SMOKE_LOCK 形状 → 伴生锁推导
✓ 34d 2.1 伴生锁名点开头（事故那条平铺 glob 够不着）
#5 34d · 身份面 … · 参考 用时 191s · ✓107 ✗0 SKIP0 · ticks 107
账本自查： 5 段收口 · 增量 ✓131 ✗0 ｜ 结果行 ✓131 ✗0 —— 一致
== 选段结果 ==  ✓ 131  ✗ 0        （RC=0）
```

两跑合起来，四段的段内断言全绿：**34 = 35、34b = 104、34d = 107、36 = 121（另 3 条 SKIP）**，共 367 条；两跑跑前跑后的树都是同一个 HEAD、零未暂存/未跟踪改动。

## 2 · 7.2 唯一一条反向对照

变异只在私有克隆 `/var/tmp/v103/repo`（`57bed221` 的干净克隆，`status` 0 脏）里做，`git diff` 只有这一处（`gate-lock.sh:482`，`gate_lock_heartbeat_newest` 内）：

```diff
 gate_lock_heartbeat_newest() { # <lock> → "path<TAB>mtime"（没有可用心跳 → 非 0，无输出）
   local lock="$1" f hb mt best_path="" best_mt=""
-  for f in "$(gate_lock_holder_file "$lock")" "$(gate_lock_runs_dir "$lock")"/*.run; do
+  for f in "$(gate_lock_holder_file "$lock")"; do
     [ -f "$f" ] || continue
```

即「心跳只从持有者记录读」，`runs/*.run` 里子登记公布的活心跳全部看不见 —— 这正是 `§34b⑭①` 要杀的形状（`team review` 形状的持有者记录写 `heartbeat=-`，真正在动的只有子登记）。变异提交 `a0148f33`（只用于本对照；克隆里随后 `git reset --hard 57bed221`）。

```bash
TEAM_SMOKE_LOCK=/var/tmp/v103/lock/7-2-red.lock TMPDIR=/var/tmp/v103/tmp/7-2-red \
  bash skills/teamsmith/tests/smoke.sh --select 34b        # 变异版
# → RC=1 WALL=40s · #5 34b ✓100 ✗4 · 结果行 ✓124 ✗4
```

红的四条，全部落在 `§34b⑭①` 那一组，没有一条来自别处：

```
✗ 34b⑭ 心跳在动 → 等待者越过 W 也没被误杀（持有者比 W 晚释放，它仍拿到了锁：rc=0）（期望 [0]，实际 [2]）
✗ 34b⑭ 排队行说出上限来自活心跳（来自子登记，不是持有者记录）（…/p338/live.log 中找不到 [心跳仍在动]）
✗ 34b⑭ 心跳在动时不报排队超限（不该出现 [排队超限]）
✗ 34b⑭ 它拿到锁后走到了子进程出口（真的取到锁）（…/p338/live.log 中找不到 [自检出口]）
```

`§34b⑨b` 的 12 条纯函数腿在变异下**仍全绿**（它们直接喂记录文件，不经过 `heartbeat_newest` 的遍历范围），所以这一跑证明的是「读全部活登记」这一层，而不是又一份重复覆盖。

还原后同一段：

```bash
git reset --hard -q 57bed221        # HEAD 57bed221，status 0 脏
TEAM_SMOKE_LOCK=/var/tmp/v103/lock/7-2-green.lock TMPDIR=/var/tmp/v103/tmp/7-2-green \
  bash skills/teamsmith/tests/smoke.sh --select 34b
# → RC=0 WALL=47s · #5 34b ✓104 ✗0 · 结果行 ✓128 ✗0
```

红→绿之间只差上面那一行 diff；两跑 40 s / 47 s，排除「差分没生效、跑的是同一棵树」。日志 `7-2-red.log`、`7-2-green.log`。

## 3 · 7.3 没有回归

从 7.1 那一跑（未变异的实现）里取出的原始读数，共 23 条：

```
✓ 34b① 排队超上限 → exit 2（约定的那个：不是 1，也不是静默）
✓ 34b① 一行说明是排队超限，并报出等了多久
✓ 34b① 那一行点名 <lock>.holder 里的持有者
✓ 34b① 那一行说明本套没有运行（不是对代码的判定）
✓ 34b① 子套件一次都没跑（输出里没有段落头）
✓ 34b① 也没有「轮到本套了（排过队）」
✓ 34b① holder 还写着持锁者（子进程没跑，没被改写）
✓ 34b⑦ 等待者撞上限 → exit 2（约定的那个）
✓ 34b⑦ 排队行点名 kind=nested + 席位 + 工作树 + expected + bound
✓ 34b⑦ 撞上限行也点名同一批字段
✓ 34b⑦ 两行的「已跑 Ns」都按记录里的 started 现算（各自落在自己 started 决定的区间里，不是某个 10 秒带）
✓ 34b⑦ 真持有者活着 → 绝不打印「持有者未知」
✓ 34b⑦ 活着的登记不算陈旧
✓ 34b⑦ 红侧：删掉嵌套登记 → 那一行丢字段（缺：kind=nested expected=300 bound=1200）
✓ 34b⑦ 红侧：只剩持有者的 kind=top（嵌套那一层确实没了）
✓ 34b⑦ 还原登记 → 字段齐了（绿）
✓ 34② 排队超上限 → 非 0
✓ 34② 判定是 FAIL
✓ 34② 记录写明门禁没有运行
✓ 34② 记录点名持锁者（夹具的 holder 记录）
✓ 34② 旧记录缺的字段写 ?（不编数字）
✓ 34② 排队超限不产生 TIMEOUT 判定
✓ 34② team_review_verdict 仍解析出 FAIL
```

`§34②` 是 `team review` 那一侧的形状：判定落 `FAIL`、记录写「门禁没有运行」，并且有一条专门断言「排队超限**不产生** TIMEOUT 判定」—— 所以「FAIL 不是 TIMEOUT」有正向读数，不是靠没红来推断。

`§34b⑦` 自己带红/绿两侧（删掉嵌套登记 → 那一行丢字段；还原 → 字段齐了），说明「点名持有者」这条断言仍会因被测行为消失而变红，不是真空通过。

`§34b①` 的 7 条同时钉住语义的五面：退出码 2、一行说明是排队超限并报出等了多久、点名持有者、`没有运行`、子套件零运行且没有「轮到本套了」、持锁者记录未被改写。

## 4 · 未测项

- **没跑整套**：`--select` 只跑了 34/34b/34d/36 与前导段；其余 127 个键没跑（`§34c` 命名面也在其中）。交付 / 归档前的整套仍归 PM。
- **没跑容器**：宿主、私有 `TMPDIR`、私有锁。
- **`TEAM_SMOKE_FAST` 没有单独读数**（change 任务书 7.3 提到它「`no_lock=1`、不排队」，本任务书的 7.3 只点名 §34b①/⑦）。
- **耗时只作参考**：这几跑处在 loadavg ≈ 30 的机器上，1563 s / 191 s / 46 s / 40 s 这些数字不是性能判据，本记录也不拿它们做判据。
- **`§34b⑫` 既有不稳定断言本轮三次 34b 运行都没红**。它与本 change 无关，我不把它算成「已修」，只记「本轮没有复现」。
- `expected` 生产者仍未退役（change 4.1 只改文档口径）；本轮没有复验那一项。

## 5 · 附带核查：每轮重算的调用点（change 任务书 3.8② 要 verify 核的那一条）

change 的 3.8② 要求独立审阅「核循环内的调用点、确认没有跨轮缓存」，V78 没有做（它用定向变异代替）。本轮静态核过：

- `skills/teamsmith/tests/smoke.sh:605-613`：`gate_lock_patience_pair` 落在重试 `while :; do … sleep 1; done` 的循环体内，`SMOKE_LOCK_CAP/PAT/SILENT` 每轮 `read` 覆盖，没有任何「把第一轮的读数留到后轮」的分支。
- `skills/teamsmith/scripts/lib/cmd-review.sh:1148-1152`：同样在排队 `while` 内，`lock_cap/lock_pat/lock_silent` 每轮重读；`lock_cap` 只与当前轮的 `queue_started` 比较，不跨轮存。
- `skills/teamsmith/tests/perf.sh:181`：单点读数，不在循环里。

结论：**结构上没有「排队时算一次就缓存」**。这是源码事实，不是运行读数，也不替代 §34b⑨c（P372）那条可证伪的缓存反例。

## 6 · F1（发现，不属于本任务范围；verify 席位不改实现）

`§34d 2.1` 的两条断言对同一个前提给出了两个相反的答案（`skills/teamsmith/tests/smoke.sh:18187-18198`）：

```bash
if [ -z "${TEAM_SMOKE_LOCK:-}" ]; then
  assert_eq "34d 2.1 默认路径（未设 TEAM_SMOKE_LOCK）" "$(gate_lock_default_path)" "$P287D_DEF"
else
  ok "34d 2.1 默认路径那一条：外层设了 TEAM_SMOKE_LOCK=… → 按同一规矩换输入（避免误判）"
fi
assert_eq "34d 2.1 默认路径 → 伴生锁（同行同目录、basename + .machine）" \
  "$(gate_lock_companion_path "$P287D_DEF")" "$(dirname "$P287D_DEF")/.teamsmith-smoke.lock.machine"
```

第一条**显式**支持「外层设了 `TEAM_SMOKE_LOCK` → 换输入」；紧随其后的那条却把期望值写死成 `.teamsmith-smoke.lock.machine`。于是任何席位用自己的私有锁名跑门禁，就会拿到一条与代码无关的红 —— 本轮 7.1 的红就是它（§1 原文）。产品侧推导是对的：`gate_lock_companion_path` 给出 `.7-1.lock.machine`，正是 spec 要求的「同目录、basename 前加点、后缀 `.machine`」，私有形状本来也由紧随其后的 `P287D_PRIV` 三条断言覆盖。

两句补充观察，都是本轮实测的：

- 在真实运行里 `if` 那半边**不会**成立：7.1b 那一跑我没有设 `TEAM_SMOKE_LOCK`，段内读到的仍是 `TEAM_SMOKE_LOCK=/var/tmp/v103/tmp/7-1b/teamsmith-smoke.lock`（smoke.sh 自己在排队代码里把这个变量导出了），所以每次真正跑到的只有那条写死 basename 的断言。
- 换句话说：这条断言在默认锁名下**恰好**通过，靠的是默认 basename 与写死的常量相同；它没有单独验证「推导随输入走」—— 那是 `P287D_PRIV` 那三条的活。

建议（一个改动、不新增断言）：把那条也收进同一个 `if`（设了 `TEAM_SMOKE_LOCK` 就跳过），或让期望值从 `basename "$P287D_DEF"` 派生。两种写法都只是让夹具承认它自己上一行已经承认的前提。

影响面：所有按本仓「不抢机器级门禁锁」惯例用私有 `TEAM_SMOKE_LOCK` 跑 `§34d` 的席位都会看到这条红，容易被误读成「§34d 回归」。交 PM 决定是否派单。

## 7 · 引用

- 合同与理由：`openspec/changes/gate-waiter-patience/{proposal,design,tasks}.md`、`openspec/changes/gate-waiter-patience/specs/verification/spec.md`
- 实现与断言账：`docs/team/reports/P338-dev-bob.md`（§4 断言账、§6 flip A、§7 读数）、`docs/team/reports/V78-verify.md`、`docs/team/reviews/V78.md`
- 缓存反例：P372 · `§34b⑨c`（`skills/teamsmith/tests/smoke.sh:17569-17575`）
- 本轮日志：`/var/tmp/v103/logs/{7-1,7-1b-34d,7-2-red,7-2-green}.log`；作业 `v103-7-1-7-2`、`v103-34d-default-lock`
