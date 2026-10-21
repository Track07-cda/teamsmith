# V90 · §61b 进度接线的独立验收（第二轮：F1/F2 定点复看）

agent: verify · branch `task/V90-r2-61b-verify` · change: `-` · anchor: none (infra) — 挂住判据的进度证据
受检：`bb5a443d`（代码面 `a189b932`，相对上一轮的 `ca98f874` 只动 `tests/smoke.sh` 的 §61b 收口）· time: 2026-10-21T09:06Z

**判定：PASS** —— 任务书第二轮的三件全部成立：①永不退出的替身到上界被点名一次并被真正收尸；②恰在
上界秒上正常退出的替身正常收口（4/5/6 秒三次读数，边界落在 5 与 6 之间）；③`--loop-check` 83/83，`skills/`
面相对 `ca98f874^` 只有 `smoke.sh` 与 `loop-inventory.tsv`。

本轮只做这三件，A/C 没有重开。上一轮的记录**不在盘上**：本席位上一轮的会话没有留下
`docs/team/reports/V90-verify.md`，只剩任务书末节与 `docs/team/threads/verify.md`（2026-10-21T08:59Z）
转述我点的 F1/F2。因此本报告自成一体，只对本轮三条读数的成立负责，不复述上一轮未落盘的读数。

---

## 1. 方法：私有副本只改两行，替身走 `P238_SUITE`

受检代码的上界是写在段里的字面量 `7200`，几分钟内跑不到；任务书允许在私有副本里改它。副本与受检树
的唯一差异就是这两行（`diff -u` 全文）：

```diff
-  P238_FLIP_CAP=7200   # 防死等：这个上界只回答「它没动」，不回答「它慢」（…）
+  P238_FLIP_CAP=5   # 防死等：这个上界只回答「它没动」，不回答「它慢」（…）
-    if [ "$P238_FLIP_ELAPSED" -ge 7200 ]; then break; fi   # 硬上界：只回答「它没动」，不回答「它慢」
+    if [ "$P238_FLIP_ELAPSED" -ge 5 ]; then break; fi   # 硬上界：只回答「它没动」，不回答「它慢」
```

副本放在 `/var/tmp/v90-r2-verify/run-090137-2529122/tree`（`skills/teamsmith` + `skills/teamsmith-init`，
并 `git init` 一次，让前导段 §0d 的「受检 git 工作树」腿有仓库可查；不做这一步 §0d 会因「找不到受检的
git 工作树」红一条，与本修法无关）。受检树逐字节未动：`git status --porcelain -uall` 干净。
每次运行都用自己的 `TMPDIR` 与自己的 `TEAM_SMOKE_LOCK`，没有碰机器级门禁锁，也没有跑整套、没有跑容器。

替身都放在 `/var/tmp/…`，没有往 `tests/` 加文件：

```bash
# 永不退出（F1）：exec 后 SIG_IGN 跨 execve 保留，只能 kill -9；自报 pid 供事后核对
printf '%s\n' "$$" > "${V90_FX_PIDFILE:?}"
trap '' TERM
exec sleep 100000
# 正常退出（F2）：跑 N 秒后写正常形状的 CONTROL/RESULT 再 rc=0
sleep N; printf 'CONTROL …\n'; printf 'RESULT ok arms=1 fixture=sleep-N\n'; exit 0
```

替身结构本身先自证一次（这样「孤儿」在构造上不可能出现）：`comm=sleep`、`children=[]`、
`SigIgn=0000000000004006`（bit14 = SIGTERM 被忽略），`kill -9` 之后 `/proc/<pid>` 立刻消失。

每次运行的命令都是同一形状，只换 `P238_SUITE`：

```bash
env TMPDIR=$RUN/tmp TEAM_SMOKE_LOCK=$RUN/tmp/gate.lock P238_SUITE=$RUN/fx/<替身>.sh \
  bash $RUN/tree/skills/teamsmith/tests/smoke.sh --select 61b
```

`--select 61b` 跑的是前导段 §0/0b/0c/0d + §61b（5 段），单次 8–14 s。

---

## 2. F1 成立：到上界一条 `bad`，进程真被收掉

替身 `never.sh`（永不退出、忽略 TERM），副本上界 5 s。段尾原文：

```
== #5 61b · 任务类别模型路由：翻转变异自检（P228 · task-model-routing） == 2026-10-21T09:03:40+00:00
  ✗ 61b 路由翻转变异没等到结果：已 5s 仍在跑（挂住，不是慢）—— 见 …/p238-routing-flip.log 尾部
#5 61b · 任务类别模型路由：翻转变异自检（P228 · task-model-routing） · 参考 用时 10s · ✓0 ✗1 SKIP0 · ticks 1
```

读数与它们各自证明了什么：

- **只红一次**：全日志断言行为红 **1** 行，`有失败（rc=` 出现 **0** 次，「挂住，不是慢」出现 **1** 次。
  到上界这条路不再判 rc，两条红没有同时冒出来。
- **TERM 被忽略、kill -9 才收掉**：段用时 **10 s** = 5 s 上界 + 5 s 满宽限。宽限期一秒都没被 `kill -0`
  提前打断，说明那一次 TERM 打在一个忽略 TERM 的进程上；随后 `kill -9` 生效。
- **进程真的被收掉**：替身自报 pid `2851099`，运行结束后 `/proc/2851099` 不存在；按 cwd 指向本次运行
  目录扫全部 `/proc`，残留 **0** 个（那两个 `sleep 100000` 属于别的席位，cwd 在 `.worktrees/dev2`，
  与本轮无关）。替身 `exec` 后没有子进程（`children=[]`），所以「变成孤儿」在构造上不成立。
- 退出码 1、`== 选段结果 == ✓ 23 ✗ 1`：前导四段全绿，唯一的红就是 §61b 这一条。

## 3. F2 成立：恰在上界秒正常退出的是「收口」而不是「挂住」

同一副本、同一 5 s 上界，换正常退出的替身：

| 替身 `sleep` | 判定行 | 段收口 | 结果行 |
|---|---|---|---|
| 3 s（两次） | `✓ … 1 条臂按名变红并还原（RESULT ok arms=1 fixture=sleep-3）` | 用时 3s · ✓1 ✗0 · ticks 2 | ✓ 24 ✗ 0 |
| 4 s | `✓ … fixture=sleep-4` | 用时 4s · ✓1 ✗0 · ticks 2 | ✓ 24 ✗ 0 |
| 5 s（四次） | `✓ … fixture=sleep-5` | 用时 5s · ✓1 ✗0 · ticks 1 | ✓ 24 ✗ 0 |
| 6 s | `✗ … 没等到结果：已 5s 仍在跑（挂住，不是慢）` | 用时 6s · ✓0 ✗1 · ticks 1 | ✓ 23 ✗ 1 |

**边界落在 5 与 6 之间，而且不是运气**：替身在 t0 起 `sleep N`，循环在 t0 之后起 `sleep 1`×N，第 N 次
醒来的时刻必晚于替身退出的时刻，所以 N = 上界这一侧（5 s）落绿——四次都落绿，也顺带证明「已退出但还没
被 `wait` 收尸」的僵尸没有把 `kill -0` 弄成「还活着」（否则会误判挂住）。6 s > 上界，替身在上界那一刻
确实还在跑，判挂住是上界本身的语义（生产值 7200：跑过两小时才叫「它没动」），不是回归。

两者合起来正是 F1/F2 要的：**红/绿由「到上界时子进程还在不在」决定，不再由「跑了多少秒」决定**——
5 s 与上界同秒的替身拿到了 `ok`，而 6 s 的替身拿到的是上界那条点名，而不是 `rc` 那条。

## 4. 没有带坏 A/C

- `bash skills/teamsmith/tests/section-guard.sh --loop-check` → `ok: 扫描 83 行清单 / 83 个 while+sleep
  循环，配平 83 个` / `section-guard --loop-check: 全过`，rc=0（本轮跑两次，读数相同）。
- `git diff ca98f874^ HEAD --stat -- skills/` 只有两个文件：

```
 skills/teamsmith/tests/loop-inventory.tsv |  1 +
 skills/teamsmith/tests/smoke.sh           | 45 +++++++++++++++++++++++++++----
```

  新增循环在清单里（`smoke.sh 22875 … cap="$P238_FLIP_ELAPSED" -ge 7200`），上限字面量在循环体内。
- 段内 `ok`/`bad` 的收口行格式没变：上面 §2/§3 的收口行仍是
  `#5 61b · … · 参考 用时 Ns · ✓a ✗b SKIPc · ticks k`；ticks 现在会走到非零（§3 的 3 s/4 s 替身
  ticks 2、5 s 替身 ticks 1），这正是本修法的目的：长跑把「日志在长」当进度交出来。

## 5. 本轮边界（没有证明的东西）

- **真套件（约 82 分钟）没有在本轮跑**：任务书把这一条留在 PM 的发布门禁里。本轮只证明上界两侧的
  判定分支，不证明真实变异矩阵的时长与臂数。
- **7200 这个具体值没有被执行**：本轮用副本的 5 s 等价替换走了同一条代码路径（`break` → `kill -0` →
  `TIMED_OUT` → `kill`/宽限/`kill -9` → `wait`），字面量本身只在 §4 的清单与源码里核对。
- 副本比受检树多一次 `git init`（为了让前导段 §0d 的 git 腿成立）；这一条只影响前导段，不影响 §61b
  的判定路径。
