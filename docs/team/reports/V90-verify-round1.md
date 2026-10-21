# V90 · §61b 进度接线的独立验收（发布阻塞项）

agent: verify · branch `task/V90-61b-progress-verify` · change: `-` · anchor: none (infra) — 挂住判据的进度证据
受检：`ca98f874`（我的分支 tip `11ec6719` = 它 + 两个账本提交，产品面逐字节相同）· time: 2026-10-21T08:53:45Z

**判定：PARTIAL。**

- **A（两个方向都要有）：成立。** 动的替身（每 1 s 一行、跑 20 s）**没被停**，本段正常收口、`ticks 21`、退出码 0；
  不动的替身（20 s 一行不写、末尾 rc=0）在 **~5 s** 被停掉，**恰好一条**点名「61b 挂住」的红行，**没有**同时冒出
  「有失败 rc=…」那条，退出码 2。证据见 §2。
- **B（到硬上界那条路）：不成立。** `break`、`bad` 两句在代码里成立，**`kill` 不成立**：它写在阻塞的
  `wait "$P238_FLIP_PID"` **之后**，子进程永不退出时永远走不到——7200 s 的上界对它唯一要防的形状**不做任何事**。
  另有第二处：子进程若在 cap 那一秒窗口内正常退出（rc=0），也照样打「挂住，不是慢」（假红），并吞掉本该打的 ok 行。
  证据见 §3。
- **C（没把别的东西带坏）：成立。** `--loop-check` 83/83 全过；新增循环在清单里、上限字面量在循环体内（两条翻转各自点名
  `smoke.sh:22875` 变红、还原变绿）；收口行格式未变且 `ticks` 非零；`git diff ca98f874^ ca98f874 --stat` 只有两个文件、
  `smoke.sh` 只有 1 个 hunk、`section-paths.tsv` 不在改动里。证据见 §4。
- **任务书写的那条复现命令按字面跑不通，两件事各自实测过**（§2.1）：`SG_FIXTURE/SG_HANG_CAP_OVERRIDE/SG_STUCK_SECTION`
  是库内壳变量、不读环境（只给这三个 → 20 s 不写一行的替身照样判绿，5 s 上限一次没用上，连「忽略它」那行都不打）；
  而 `TEAM_SMOKE_STUCK_SECTION` 的作用也不是「给这段压上限」，是**把这段整段换成永不返回的注入夹具**（段体不跑）。
  可用的配方与 A1/A2 实测见 §2.2–§2.3。

---

## 1. 我判的是什么

受检树 = 我的分支 tip `11ec6719`。`git diff ca98f874^ ca98f874 --name-only` 只有
`skills/teamsmith/tests/loop-inventory.tsv` 与 `skills/teamsmith/tests/smoke.sh`；我的分支相对 `ca98f874` 只多了两个
`docs/team/**` 账本提交，所以在本树上跑的等价于在 `ca98f874` 上跑。所有替身与日志都在 `/var/tmp/v90-verify/**`
（私有目录，不进仓库、不进 `tests/`）；每次门禁运行用私有 `TMPDIR`/`TMUX_TMPDIR`/`TEAM_SMOKE_LOCK`，不抢机器级门禁锁；
四次运行（c0 字面配方、c1 注入夹具、c1b 动替身、c2 不动替身）都没有出现「本次运行无效」（退出码是 0/2 而不是 4 → 树在跑动中没被改）。

## 2. A · 两个方向

### 2.1 任务书那条命令按字面跑不通（两件事，各有一次运行）

两件事都要先钉住，否则 A 的演示会在**段体根本没跑**的情况下「看起来通过」。

**(a) `SG_*` 三个名字不读环境 → 5 s 上限完全没生效。** 按任务书字面，只给 `SG_*`、用**不动**的替身：

```
TMPDIR=/var/tmp/v90-verify/c0/tmp TMUX_TMPDIR=/var/tmp/v90-verify/c0/tmux \
TEAM_SMOKE_LOCK=/var/tmp/v90-verify/c0/lock/gate.lock \
P238_SUITE=/var/tmp/v90-verify/fixtures/flip-stuck.sh \
SG_FIXTURE=1 SG_HANG_CAP_OVERRIDE=5 SG_STUCK_SECTION=61b \
  timeout 400 bash skills/teamsmith/tests/smoke.sh --select 61b   →  rc=0（elapsed 26s）

== #5 61b · … == 2026-10-21T08:55:22+00:00
  ✓ 61b 路由翻转变异：0 条臂按名变红并还原（RESULT flip stub-stuck（20 秒一行没写，rc=0））
#5 61b · … · 参考 用时 21s · ✓1 ✗0 SKIP0 · ticks 2

grep -c '挂住' = 0 ｜ grep -c '\[fixture\]' = 0 ｜ grep -c '非夹具路径忽略它' = 0
```

一个 20 s 一行不写、`ticks 2` 的段**没有被停**、还判了绿——`cap=5` 一次都没用上；而且连「忽略它」那行都没打（库只审计
`TEAM_SMOKE_*` 这几个名字，`SG_*` 的名字不在审计面里），所以按任务书字面跑是**静默无效**。原因在
`lib/section-guard.sh:123` 与 `:148-155`：`SG_FIXTURE="${TEAM_SMOKE_FIXTURE:-0}"`（覆盖掉环境里的 `SG_FIXTURE=1`），
`SG_STUCK_SECTION`/`SG_HANG_CAP_OVERRIDE` 只在 `SG_FIXTURE=1` 时从 `TEAM_SMOKE_STUCK_SECTION`/`TEAM_SMOKE_SECTION_HANG_CAP`
读入。正确的名字是 `TEAM_SMOKE_FIXTURE` / `TEAM_SMOKE_SECTION_HANG_CAP` / `TEAM_SMOKE_STUCK_SECTION`。

**(b) `TEAM_SMOKE_STUCK_SECTION=61b` 不是「只给 61b 压上限」，是把这段换成一个永不返回的注入夹具。** 实测（动替身、
`TEAM_SMOKE_*` 全套给齐；那次 `SG_*` 也在环境里，已由 (a) 证明不起作用）：

```
P238_SUITE=/var/tmp/v90-verify/fixtures/flip-moving.sh \
TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_SECTION_HANG_CAP=5 TEAM_SMOKE_STUCK_SECTION=61b \
  timeout 400 bash skills/teamsmith/tests/smoke.sh --select 61b   →  rc=2（elapsed 10s）

== #5 61b · 任务类别模型路由：翻转变异自检（P228 · task-model-routing） == 2026-10-21T08:49:27+00:00
  [fixture] 注入永不返回的段落（61b · …，挂住上限 5s）
  ✗ 段落 #5（61b · …）挂住：已 5s 没有进度（挂住上限 5s；段落已运行 6s，ticks 0）→ 停跑（exit 2），现场 …
```

段体一行都没跑：既没有替身打的 20 行 `CONTROL`，也没有 §61b 自己的 `ok`/`bad` 行，`ticks 0`。代码路径是
`section_guard_begin` 里的注入分支：命中 `SG_STUCK_SECTION` 就起一个 bounded_spin 然后**`wait "$child"`**
（`lib/section-guard.sh:334`），段体永远不会被走到。所以「动的替身不许被停 / 不动的替身必须被停」这种**要让真实段体跑**的
演示，不能用 `TEAM_SMOKE_STUCK_SECTION`。

**A 用的配方**：`TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_SECTION_HANG_CAP=5`，**不点名段** —— `section_guard_hang_cap_for` 的规则是
「没点名就作用于每段」，于是 5 s 上限落在每一段上；`--select 61b` 的前四段（0/0b/0c/0d）各 0–1 s、`ticks 2–9`，A1 实测
没有一段被误停。这也是这条旋钮无法表达「只给 61b 压上限、段体照跑」的直接后果（见 F3；我没有动它）。

### 2.2 A1 · 动的替身（每 1 s 写一行、跑 20 s）：不许被停

替身 `/var/tmp/v90-verify/fixtures/flip-moving.sh`：每 1 s 打 `CONTROL arm=N source_restored=1`，20 次后打
`RESULT flip stub-moving arms=20`、`exit 0`。

```
TMPDIR=/var/tmp/v90-verify/c1b/tmp TMUX_TMPDIR=/var/tmp/v90-verify/c1b/tmux \
TEAM_SMOKE_LOCK=/var/tmp/v90-verify/c1b/lock/gate.lock \
P238_SUITE=/var/tmp/v90-verify/fixtures/flip-moving.sh \
TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_SECTION_HANG_CAP=5 \
  timeout 400 bash skills/teamsmith/tests/smoke.sh --select 61b   →  rc=0（elapsed 24s）

== #5 61b · 任务类别模型路由：翻转变异自检（P228 · task-model-routing） == 2026-10-21T08:50:24+00:00
  ✓ 61b 路由翻转变异：20 条臂按名变红并还原（RESULT flip stub-moving arms=20）
#5 61b · 任务类别模型路由：翻转变异自检（P228 · task-model-routing） · 参考 用时 20s · ✓1 ✗0 SKIP0 · ticks 21

账本自查： 5 段收口 · 增量 ✓24 ✗0 SKIP0 ｜ 结果行 ✓24 ✗0 —— 一致
== 选段结果 ==  ✓ 24  ✗ 0
```

读法：挂住上限被压到 5 s，而这一段**每 1 s 有一次 `section_guard_check`**（收口行的 `ticks 21` 就是这 20 次进度
加收口那一次），所以「慢」不再被判成「挂住」——这正是 `ca98f874` 要买的东西。注意这次因为没有
`TEAM_SMOKE_STUCK_SECTION`，5 s 上限按 `section_guard_hang_cap_for` 的「没点名就作用于每段」落在**每一段**上；
前四段（0/0b/0c/0d）各 0–1 s、ticks 2–9，没有一段被误停。

### 2.3 A2 · 不动的替身（20 s 一行不写、末尾 rc=0）：必须 ~5 s 被停、只红一次

替身 `/var/tmp/v90-verify/fixtures/flip-stuck.sh`：`sleep 20` 后打一行 `RESULT`、`exit 0`。

```
（同样的私有 TMPDIR/TMUX_TMPDIR/TEAM_SMOKE_LOCK）
P238_SUITE=/var/tmp/v90-verify/fixtures/flip-stuck.sh \
TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_SECTION_HANG_CAP=5 \
  timeout 400 bash skills/teamsmith/tests/smoke.sh --select 61b   →  rc=2（elapsed 10s）

== #5 61b · 任务类别模型路由：翻转变异自检（P228 · task-model-routing） == 2026-10-21T08:50:56+00:00

  ✗ 段落 #5（61b · 任务类别模型路由：翻转变异自检（P228 · task-model-routing））挂住：已 5s 没有进度（挂住上限 5s；段落已运行 5s，ticks 0）→ 停跑（exit 2），现场 /var/tmp/v90-verify/c2/tmp/.teamsmith-smoke-scene.1096279
Terminated                 sleep 1
Terminated                 sleep 0.02
Terminated                 sleep 0.02
  · 临时根（结束）：…（332 KB · 128 文件 · source=tmpdir）

== 选段：这次没跑的段 == 130 个键
```

- **点名**：一行，含段号 `#5`、段 id `61b · …`、`挂住`、`已 5s 没有进度`、`挂住上限 5s`、`ticks 0`、现场路径。
- **只红一次**：`grep -c '^  ✗ '` = **1**（含 `✗` 的其余 4 行都是收口行里的 `✗0` 计数），`grep '有失败'` = 空
  —— 没有同时冒出「61b 路由翻转变异有失败（rc=…）」那条。
- **停跑路径**：主 shell 一直在 `sleep 1` 的循环里、走不到安全点，所以由看门狗 TERM → `section_guard_on_term` 认标记 →
  `exit 2`；没有 `== 结果 ==` 行。
- **无残留**：运行结束后 `ps` 里没有 `flip-stuck`/`sleep 20` 的孤儿。

## 3. B · 到硬上界那条路（只能读代码，替身压不到 7200 s）

`smoke.sh:22875-22897`（候选树）逐句核对：

| 任务书要求 | 代码 | 判 |
|---|---|---|
| 到 7200 s 时 `break` | `if [ "$P238_FLIP_ELAPSED" -ge 7200 ]; then break; fi`（22878） | ✓ |
| `kill` 子进程 | `kill "$P238_FLIP_PID"`（22887）**写在 `wait`（22885）之后** | **✗ 到不了** |
| 打一条 `bad`「没等到结果…（挂住，不是慢）」 | 22888，原文 `61b 路由翻转变异没等到结果：已 ${P238_FLIP_CAP}s 仍在跑（挂住，不是慢）—— 见 …` | ✓（文本），但同样在 `wait` 之后 |
| 不再判 rc（不重复红） | `if [ "$P238_FLIP_ELAPSED" -lt 7200 ]; then …ok/bad rc=…`（22892） | ✓（结构），但见 F2 |

`wait <一个还活着的后台 pid>` 是阻塞的，所以顺序错了一步就足以让整个上界失效。我把这段形状原样搬成独立脚本
（`/var/tmp/v90-verify/repro/flip-shape.sh`，只把 `7200` 换成可传的 `$CAP`）跑了两个方向：

**复现 1 · 永不退出 + 有进度（cap=3）**

```
timeout 12 bash /var/tmp/v90-verify/repro/flip-shape.sh moving 3   →  rc=124（外部超时）
  tick 2
  tick 4
  loop 退出：ELAPSED=3（cap=3）
  → 进入 wait …
```

`break` 到了，`kill`/`bad` 一次都没打印，进程永久卡在 `wait`——对「它在动但永不结束」这个唯一需要 7200 s 上界的形状，
上界等于不存在（唯一还能收场的是外部的 `timeout`，门禁里没有）。

**复现 2 · 在 cap 那一秒内正常退出（子进程 rc=0，cap=3）**

```
timeout 20 bash /var/tmp/v90-verify/repro/flip-shape.sh finishing-early 3   →  rc=0
  loop 退出：ELAPSED=3（cap=3）
  → 进入 wait …
  wait 返回：rc=0
  bad 61b 路由翻转变异没等到结果：已 3s 仍在跑（挂住，不是慢）
```

子进程 2.6 s 就正常退出了（rc=0），却被打成「挂住，不是慢」，而本该打的 `ok` 行被 `-lt` 那条吞掉。
这是一个 1 秒宽的窗口（子进程在「计数到 cap−1 之后、`wait` 之前」退出）：单次运行概率极低，但方向是**假红**，
而且它同时把 rc 判定一起吞掉（真失败落在这一秒里会被误报成「挂住」）。

## 4. C · 没有把别的东西带坏

**4.1 `--loop-check` 83/83 全过**

```
bash skills/teamsmith/tests/section-guard.sh --loop-check   →  rc=0
ok: 扫描 83 行清单 / 83 个 while+sleep 循环，配平 83 个
section-guard --loop-check: 全过
```

**4.2 新增循环真的在清单里、上限字面量真的在循环体内**（在 `/var/tmp/v90-verify/lf` 的 tests 副本上翻，真树不动）

拿掉清单里那条 `smoke.sh 22875 …`：

```
bad: smoke.sh 的 while+sleep 循环数 52 ≠ 清单行数 51（新循环/漏登记/顺序变化都要点名并补清单）
bad: smoke.sh:22875 是未登记的 while+sleep 循环：  while kill -0 "$P238_FLIP_PID" 2>/dev/null; do
section-guard --loop-check: 1 条不成立      rc=1
```

把循环体里的 `-ge 7200` 改成 `-ge 9999`（清单仍写 7200）：

```
bad: smoke.sh:22875 的循环丢了上限（清单要求循环体里出现 ["$P238_FLIP_ELAPSED" -ge 7200]）
section-guard --loop-check: 1 条不成立      rc=1
```

两处还原后都回到 `83/83 全过 rc=0`。所以那行清单不是凑数：它是这条循环的**唯一登记**，去掉就红并点名。

**4.3 收口行格式没变，ticks 现在非零**

格式串在 `lib/section-guard.sh` 的 `_sg_close_current` 里，而 `git diff ca98f874^ ca98f874 --name-only` 不含该文件
→ 格式未改。本段实测：`#5 61b · … · 参考 用时 20s · ✓1 ✗0 SKIP0 · ticks 21`（动替身），
`ticks 0`（不动替身，被停）；同一次运行里前四段 `ticks 3/2/9/9`，与改动前同形同义。

**4.4 改动面**

```
git diff ca98f874^ ca98f874 --stat
 skills/teamsmith/tests/loop-inventory.tsv |  1 +
 skills/teamsmith/tests/smoke.sh           | 37 ++++++++++++++++++++++++++-----
 2 files changed, 32 insertions(+), 6 deletions(-)
git diff ca98f874^ ca98f874 -- skills/teamsmith/tests/smoke.sh | grep -c '^@@'   → 1
```

`smoke.sh` 只有 **1 个 hunk**（`@@ -22863,14 +22863,39 @@`，均落在 §61b 段内）→ 别的段逐字节未变；`section-paths.tsv` 不在改动里；
`skills/teamsmith/scripts/**`（生产代码）不在改动里。

## 5. 发现（每条都写明它改变了什么）

- **F1 · 硬上界不可达（阻塞 PASS）**：`smoke.sh:22885` 的 `wait` 在 `kill`/`bad` 之前；子进程永不退出时 7200 s
  上界不做任何事。**改变结论**：B 不成立 → 本报告 PARTIAL。修法是三行顺序（先判 cap、`kill` 进程树、`bad`，再
  `wait` 取 rc；`kill` 只打直接子进程也不够——守卫自己的 `_sg_stop_children` 走进程树，这里没有）。
- **F2 · cap 边界假红（应修，小）**：子进程在 cap 那一秒内正常退出（rc=0）也会打「挂住，不是慢」，并吞掉 ok 行
  （复现 2）。**改变结论**：不影响 A/C，但它让「挂住」这个判据在边界上不真。修法：`break` 之后再判一次存活
  （`kill -0`）或先 `wait -n`/非阻塞取状态，只有**确实还活着**才打 cap 红。
- **F3 · 任务书的复现配方不可用（口径问题，不是产品缺陷）**：`SG_FIXTURE/SG_HANG_CAP_OVERRIDE/SG_STUCK_SECTION` 是库内
  壳变量，不读环境（`lib/section-guard.sh:152-155` 读的是 `TEAM_SMOKE_*`）；而且 `TEAM_SMOKE_STUCK_SECTION` 的作用是
  **把被点名的段整段换成永不返回的注入夹具**（`section_guard_begin` 的 `wait "$child"`），段体不跑。**改变做法**：
  A1/A2 改用 `TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_SECTION_HANG_CAP=5`（不点名段）——上限按「没点名就作用于每段」落在每段上，
  前四段各 0–1 s 不会被误停（A1 实测）。**副产品**：这条旋钮无法表达「只给 61b 压上限、段体照跑」，需要的话要新增旋钮，
  我没有动它（不在我的授权面）。

## 6. 我没跑的（按任务书边界）

- `--select 61b` 用**真**套件跑一次（约 82 分钟）：任务书指定由 PM 在发布门禁里跑，我只跑替身。
- 整套门禁、容器内跑、`--flip` 全套变异矩阵：一概没跑。
- 生产代码、别的段、`section-paths.tsv`：未改一个字节（§4.4 的 diff 面为证）。

## 7. 复现

```bash
# 替身（/var/tmp 私有，不进仓库）
/var/tmp/v90-verify/fixtures/flip-moving.sh   # 每 1s 一行、20s
/var/tmp/v90-verify/fixtures/flip-stuck.sh    # 20s 不写、rc=0

# A1（动的替身）：期望 rc=0、`ticks` 非零
TMPDIR=/var/tmp/v90-verify/c1b/tmp TMUX_TMPDIR=/var/tmp/v90-verify/c1b/tmux \
TEAM_SMOKE_LOCK=/var/tmp/v90-verify/c1b/lock/gate.lock \
P238_SUITE=/var/tmp/v90-verify/fixtures/flip-moving.sh \
TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_SECTION_HANG_CAP=5 \
  bash skills/teamsmith/tests/smoke.sh --select 61b

# A2（不动的替身）：期望 rc=2、恰好一条「61b … 挂住」红行、无「有失败 rc=」
（同上，把 P238_SUITE 换成 flip-stuck.sh，目录换成 c2）

# §2.1(a) 任务书字面（只给 SG_*）：期望 rc=0、无「挂住」行——旋钮静默无效，目录 c0
# §2.1(b) 注入夹具（TEAM_SMOKE_STUCK_SECTION=61b）：期望出现「[fixture] 注入」行、段体不跑，目录 c1

# B 取证：把 §61b 的循环形状单独跑（cap=3）
bash /var/tmp/v90-verify/repro/flip-shape.sh moving 3            # → 卡在 wait（外部 timeout 收场）
bash /var/tmp/v90-verify/repro/flip-shape.sh finishing-early 3   # → rc=0 却打「挂住，不是慢」

# C：循环清单与其两条翻转
bash skills/teamsmith/tests/section-guard.sh --loop-check
```
