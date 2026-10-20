# V71 · CI 减重复返修的增量独立行为复核

task: V71   agent: dev2   phase: verify   change: `behavior-focused-ci`
specs: `verification#A changed-path list selects the sections to run, or the full suite`
branch: `task/V71-ci-repair-increment-review`（local 模式；本分支只放这份报告与我的线程）
status: delivered —— **第二轮：增量 PASS**（两处必修都关闭，36⑨ 在同一次 `--select 36` 里真执行）；整体验收仍未完成
time: 2026-10-20T09:31:00Z（第二轮）；第一轮 2026-10-20T08:35:40Z

两轮的受检对象都在同一个**独立 clone** `/var/tmp/v71-dev2/clone`（不是 worktree，`.git` 是真目录）：
第一轮 `f14be42b`（作者报告 `4760f7a1`，再往后 `71a3be19` 只动报告，`skills/ openspec/ .github/ ci/` 逐字节未变）；
第二轮 `295e966a`（作者报告 `4068e287`，`b1924577` 只把 `tip:` 行改回实现提交）。

## 第二轮结论（先读这一节 · 2026-10-20T09:31:00Z）

增量判定 **PASS**：PM 裁回的两处必修都已关闭，且 36⑨ 这次**真的执行**（不是 SKIP）。整体（容器、floor 整体、C4、发布）仍未验收，本轮不冒充。

| 必修 | 关闭依据 | 读数 |
|---|---|---|
| ① 36⑨ 在门禁里从不执行 | 调用条件与 `--tree` 都改成 `$CHECKOUT_REPO_ROOT`；代码差异只有这 9 行 | `--select 36` 一次：`✓ 36⑨ CI 入口：workflow-entry 三条行为全绿（ok 7 bad 0 skip 0）`，整段 `✓121 ✗0 SKIP3`、`✓144 ✗0`、rc=0 |
| ② 报告把 M35 豁免归因给 P330 | 三处都改成「注册时即无对象 + P330 的 `a62ab6bb` 只删 `skills/teamsmith/tests/**`」 | 报告 §7.3b / 未观测边界两处正文已改，退役本身保留 |

同段 36⑦ / 36⑧ 没有因此变红：`36⑦ 全键副本 bash -n 扫描：ok 135 / bad 0`（含三条红侧）、`✓ 36⑧ 产品面检出探针全绿（ok 144 bad 0 skip 0）`。
3 条 SKIP 全是既有形状：`36① --check` 三个副本都因 `.pi/skills`（机器生成面）不在检出里而如实跳过。

### 2.1 · 静态：差异只有这两处

```
$ git diff --stat f14be42b 295e966a
 docs/team/reports/P326-dev.md | 165 ++++++++++++++++++++++++-------   （其余是 BOARD/DECISIONS/tasks/threads/reviews 等账本）
 skills/teamsmith/tests/smoke.sh |   9 +-

$ git diff f14be42b 295e966a -- skills/ .github/ openspec/ ci/
（全文只有 smoke.sh 的那一个 hunk）
-if [ -f "$SKILL_DIR/tests/workflow-entry.sh" ] && [ -f "$REPO/.github/workflows/gates.yml" ]; then
-  if bash "$SKILL_DIR/tests/workflow-entry.sh" --tree "$REPO" >"$TMP/p326-workflow-entry.log" 2>&1; then
+# 看的是**产品面检出的那棵树**（`$CHECKOUT_REPO_ROOT`）…（三行说明）
+if [ -f "$SKILL_DIR/tests/workflow-entry.sh" ] && [ -f "$CHECKOUT_REPO_ROOT/.github/workflows/gates.yml" ]; then
+  if bash "$SKILL_DIR/tests/workflow-entry.sh" --tree "$CHECKOUT_REPO_ROOT" >"$TMP/p326-workflow-entry.log" 2>&1; then
```

PM 给的那对 ref 方向反了（只影响查法，不影响结论）：`b1924577` 是 `295e966a` 的**后代**（`295e966a → 4068e287 → b1924577`），所以
`git diff b1924577 295e966a` 只会显示报告被倒回去；要看新增应当用 `git diff f14be42b 295e966a`（就是上面那 9 行 + 账本）。

一处**作者报告里的事实**（不影响代码结论，但下一轮别按那个标签读日志）：报告说「第一次（`0b7e1ffe`）36⑨ 已经真跑起来了」，
而 `0b7e1ffe` 提交里的第 18286 行仍是 `if [ -f "$REPO/.github/workflows/gates.yml" ]`；它记录的那条红是
`token AGENTS.md（源码行 18286）`，而 `0b7e1ffe:18286` 是 `if` 行、不含任何 `AGENTS.md` token —— 说明那次跑的是**未提交的在改树**（注释里点了 `AGENTS.md`），
不是 `0b7e1ffe` 这个提交。最终提交的树我另外直接跑过（§2.2），结论不受影响。

### 2.2 · 一次 `--select 36`：36⑨ 真执行

```
$ cd /var/tmp/v71-dev2/clone && git fetch -q --all && git checkout -q 295e966a
HEAD=295e966a1b9763b45456642d2f044b79119ee1f5        status-lines=0
$ env -u TMUX -u TMUX_PANE -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SESSION -u TEAM_PROJECT \
    -u TEAM_SIGNAL_CALLS_LOG -u TEAM_SIGNAL_REAL -u TEAM_TMUX_CALLS_LOG -u TEAM_TMUX_REAL \
    TMPDIR=/var/tmp/v71-dev2/tmp TEAM_SMOKE_LOCK=/var/tmp/v71-dev2/lock/smoke-36.lock \
    bash skills/teamsmith/tests/smoke.sh --select 36
rc=0
== 选段 == decision=RUN · 运行 5/135 段 · 未跑 130 段
== #5 36 · 选段与分段账本自检（P98 · gate-runtime-budget） == 2026-10-20T09:15:00+00:00
  SKIP（条件不满足） 36① --check（真树/表副本/变体树）：行 19 的字面模式在检出里不存在（…机器生成面）：.pi/skills   ×3
  ✓ 36③ 结果行用 == 选段结果 ==
  ✓ 36⑦ 全键副本 bash -n 扫描：ok 135 / bad 0
  ✓ 36⑦ 红侧（旧剪贴器=按段头一刀切）：全键扫描红了并点名 14/14c
  ✓ 36⑦ 坏副本在跑任何段之前被拒（rc=2、点名、零段头）
  ✓ 36⑧ 产品面检出探针全绿（ok 144 bad 0 skip 0）
  ✓ 36⑨ CI 入口：workflow-entry 三条行为全绿（ok 7 bad 0 skip 0）
#5 36 · … · 参考 用时 844s · ✓121 ✗0 SKIP3 · ticks 124
账本自查： 5 段收口 · 增量 ✓144 ✗0 SKIP3 ｜ 结果行 ✓144 ✗0 —— 一致
```

判据（brief 的两条）都成立：`36⑨` 这一行是 **✓ 且带 `ok 7 bad 0 skip 0`**（脚本自己打的收口行）——如果还走旧的 `$REPO` 条件，这里只会出现一条
`SKIP（条件不满足） 36⑨ …`；同段的 36⑦ 与 36⑧ 也在，且都是绿的，没有因为改条件而变红。
844 s 只是**参考值**（作者同段 773 s）；本轮不拿它当判据。树在跑动中没被改：验后同一 HEAD、`status-lines=0`，而套件在指纹不一致时会打印「本次运行无效」并以 4 退出（本轮 rc=0）。

同一次作业里又跑了一次独立入口：

```
$ bash skills/teamsmith/tests/workflow-entry.sh --tree /var/tmp/v71-dev2/clone
  ✓ workflow-entry ①：有效基点时这一步退出 0
  ✓ workflow-entry ①：容器命令带 `--floor` 与 `--paths "$@"`（不是全套、也不会丢路径）
  ✓ workflow-entry ①：3 条特殊文件名（换行 / 空格 / 引号+反斜杠）逐字节到达容器参数（cmp 一致）
  ✓ workflow-entry ②：基点不可解析（空 / 0000…0 / no-such-sha-1693097）→ ::warning:: + 正向确认执行完整入口（…）  ×3
  ✓ workflow-entry ③：容器执行失败（stub rc=5）→ 这一步非 0（rc=5），失败没被吞
== workflow-entry == ok 7 bad 0 skip 0        rc=0
```

### 2.3 · PM 的算术：两个数**同口径**，但都还不是 floor 的墙钟

只按日志核（`$HOME/.cache/p326-c4/c4.log`，不新跑任何测量）：

| 量 | 我从日志核到的值 | 怎么来的 |
|---|---|---|
| 段账本行数与合计 | **96 行，合计 2601 s（43.4 分）** | `grep -oE '参考 用时 [0-9]+s'` 求和 —— 与作者报告的 2601 s 一致 |
| 墙钟 | 报告 2699 s（44:59）；日志首段 06:49:36 → 报告记的收口 07:34:18 = 2682 s | 差值是 2699 与 2682 的口径细节（2699 从套件开跑算，2682 从第一个段头算），**不含**任何未闭段的整段用时；96 段之外的余额 ≈ 81–98 s 是前导、段间开销与第 97 段（`34d`）被杀时的残段 |
| 11c | 段账本 `#42 11c … 用时 1018s`，现场行 `有界轮询 986s 内 roster 没看到「pi 已退出」` | 986 ⊂ 1018 ⊂ 2699 —— **11c 是 96 个已闭段之一**，所以那 986 s 确实在 2699 s 之内 |
| 选择 | `decision=RUN · 运行 133/135 段`，未选只有 `0g 61b`；实跑 96 段后被 45 分钟预算停掉，**§36 从未开跑** | 决策行 + 报告列的 37 个未跑段（含 36/58/61/38） |

**结论一（同一口径，你的减法成立）**：`2699 − 986 = 1713 s`，`×133/96 = 2373 s ≈ 39.6 分钟` —— 与作者的 62 分钟（`2699 × 133/96 = 3739 s`）是**同一个算式**，只是去掉了已查明属于 11c 的空转。
换成同一单位（用段账本而不是墙钟）：`2601 − 986 = 1615 s`，`×133/96 = 2238 s ≈ 37.3 分钟`，再加那 81–98 s 开销 ≈ 39 分钟 —— 与 40 分钟差不到一分钟。所以「约 40 分钟」不是另一个口径算出来的，它就是同一外推的更正。

**结论二（但这仍然不是 floor 墙钟，请别用它给 45 分钟背书）**：这条外推的隐含前提是「每段平均 27 s」，而 37 个未测段里**单个**就打破它 ——
§36 在**修好之后**的树上，我这台机器量到 **844 s**（作者 773 s），是那个平均值（27 s）的 31 倍。只把 §36 一项加回已测基座：
`(1615 + 844) × 133/97 = 3372 s ≈ 56 分钟`（按作者的 773 s 则 ≈ 53 分钟）。也就是说：

- 62 → 40 的更正**方向对**（986 s 确实是被这次修掉的空转）；
- 但「40 分钟 < 45 分钟」这个结论**还不成立**，因为未测段里已知有一个约 14 分钟的 §36；
- 另外 133 段 ≠ floor 128 段（多出 `0e 0f 0h 0i 36` 五个自检段，其中 36 就是那个 844 s），C4 那棵树还落后 main 50 个提交、容器挂载坏了 git、机器 loadavg 11.75 / 32 核 —— 都不是 runner 读数。

建议的措辞（供你在 DECISIONS 里改一句）：保留 ①「不缩地板」与 ③「以修好之后一次干净容器运行作准」；把 ② 的「约 40 分钟，落在 45 以内」改成「已测得 96 段 2601 s（含 986 s 空转，已修掉）；剩余 37 段的成本没有任何测量，其中 §36 单段 844 s，所以 133 段/floor 的墙钟仍未测出」。我没有改任何账本，只报这个读数。

## 第一轮判定（先给答案 · 2026-10-20T08:35:40Z，历史记录）

| 项 | 结论 | 一句话依据 |
|---|---|---|
| ① 11c 的返修（判定 / 耗尽 / 前提） | **成立** | 独立 clone 上 `--select 11c --keep` 一次，12 段 `✓341 ✗0`，11c `✓16 ✗0`；`up-agents.log` 是真续跑 + 真启动失败；15 条产品断言一条没删 |
| ② `workflow-entry.sh` 本身的三条行为 | **成立** | `--tree <clone>` 一次 `ok 7 bad 0 skip 0` rc=0；有效基点特殊字符逐字节到达、无效基点正向确认走完整入口、底层失败传播 |
| ③ 轻量检查与 M35 豁免退役 | **成立**（报告归因要改） | `signal-lint` 干净、`--check ok 9 bad 0 SKIP 1`；空清单不影响产品扫描面；但报告把退役归因给 P330 没有证据 |
| ④ probe 合并 / workflow→36 / 11c needs / main 成果保留 | **成立** | 每组合并 run 只留一条整体退出码；`--paths .github/workflows/gates.yml` 由 FULL 变 `RUN keys=5`；`11c` needs=`4,11b`；候选 = `f9d34e57` + 14 个文件 |
| ⑤ **36⑨ 在套件里的承接** | **不成立（必修项）** | 调用点传的是夹具项目 `$REPO`（`$TMP/repo`，结构上没有 `.github`），所以**每一次**门禁里 36⑨ 都走 `cond_skip`，这条检查在门禁中从未执行 |

**能否交给 PM 准备最终组合验收**：11c、probe 合并、选择器映射、main 成果保留这四部分可以；但 ⑤ 必须先有一个字的修法（见 §6），否则最终组合验收会把一条**从不运行**的检查当成「CI 入口有承接者」。本轮**不是**整个 change 的验收，C4 与发布仍属 PM 另行统一安排。

## 一、受检现场：独立 clone，固定且干净

```
$ git clone -q --no-hardlinks <main checkout> /var/tmp/v71-dev2/clone
$ git -C /var/tmp/v71-dev2/clone checkout -q f14be42b
HEAD=f14be42b9d227abf8a6580290a29923f40085bca
$ git status --porcelain --untracked-files=all      # 空
$ ls -ld .git → 目录（不是 `gitdir:` 指针文件）
```

跑动前后的树指纹（套件自己写、我另外核对）：

```
$ cat <现场>/run-fingerprint.txt
root: /var/tmp/v71-dev2/clone
start: head=f14be42b9d227abf8a6580290a29923f40085bca dirty=0 sha=01ba4719c80b6fe9…
end:   head=f14be42b9d227abf8a6580290a29923f40085bca dirty=0 sha=01ba4719c80b6fe9…
verdict: same

$ git -C /var/tmp/v71-dev2/clone status --porcelain --untracked-files=all | wc -l   → 0
```

即：两个入口都在这棵固定树上跑，跑完一个字节没改（`make_pm_idle` 也没写到树里）。

## 二、11c：一次非 FAST 运行，`--keep` 现场留在磁盘

命令（私有磁盘 TMPDIR、私有锁、显式清掉我这一席继承的 `TEAM_*`/`TMUX*` 身份；**没有** FAST）：

```
$ cd /var/tmp/v71-dev2/clone && env -u TMUX -u TMUX_PANE -u TEAM_ROOT -u TEAM_MAIN_ROOT \
    -u TEAM_SESSION -u TEAM_PROJECT -u TEAM_SIGNAL_CALLS_LOG -u TEAM_SIGNAL_REAL \
    -u TEAM_TMUX_CALLS_LOG -u TEAM_TMUX_REAL \
    TMPDIR=/var/tmp/v71-dev2/tmp TEAM_SMOKE_LOCK=/var/tmp/v71-dev2/lock/smoke-11c.lock \
    TEAM_SMOKE_LOCK_WAIT=600 bash skills/teamsmith/tests/smoke.sh --select 11c --keep
```

返回码 0，墙钟 123.9 s（仅参考值）。尾部原文：

```
== 选段 == decision=RUN · 运行 12/135 段 · 未跑 123 段
· tmux 私有 socket：/var/tmp/v71-dev2/tmp/.t-1000.cUtTLX/tmux-1000/default（…；调用者的默认 server 不参与；54 字节 ≤ AF_UNIX 上限 107）
== #12 11c · agent 续跑是 PM 的事（pulse 不碰） == 2026-10-20T08:33:45+00:00
  ✓ roster 能区分「窗口在但 pi 已退出」（有界轮询，不是赌一次 sleep）
  ✓ agent 没在跑时 say 落收件箱并返回 0
  ✓ 说明消息进了收件箱（而不是打进 shell）
  ✓ 读命令之后 state/ 一个字节没变（F28）
  ✓ 崩溃 agent 的任务记录还在
  ✓ digest 仍把崩溃 agent 算成待办
  ✓ 死窗口释放模型槽位（RUNNING=0）
  ✓ pulse 不续跑 agent（窗口仍不在）
  ✓ pulse 输出里没有 agent 续跑动作
  ✓ resume --dry-run 能识别待续跑任务
  ✓ resume（PM 工具）退出码 0
  ✓ resume 重新派单
  ✓ resume 后 dev 窗口回来了
  ✓ §11c 前提：up --agents 之前 PM 是 idle（窗口是空 shell、无在飞标记 → up 会真的尝试启动）
  ✓ up --agents 才会续跑 agent
  ✓ （假 pi 秒退：up 同时也如实报了 PM 没起来）
#12 11c · agent 续跑是 PM 的事（pulse 不碰） · 参考 用时 23s · ✓16 ✗0 SKIP0 · ticks 16
账本自查：12 段收口 · 增量 ✓341 ✗0 SKIP0 ｜ 结果行 ✓341 ✗0 —— 一致
== 选段结果 ==  ✓ 341  ✗ 0
保留临时根：/var/tmp/v71-dev2/tmp/teamsmith-smoke-clone-b47505fb.VrkPqC（TEAM_TMP_KEEP=1）
```

选段带上了必要前置（`section-select.sh --select 11c` → 12 键：前导 `0 0b 0c 0d` + `2 5 3b 6 6i 4 11b` + `11c`），其中 `11b` 的理由行是 `← needs:11c`。现场保留到复核收口。

### 2.1 现场里的 `up-agents.log`：真续跑 + 真启动失败

```
$ cat <现场>/repo/.pi/team/state/../up-agents.log      # 即 <现场>/up-agents.log
teamsmith up · repo（只负责 PM）
! PM 没在跑（空提示符）：启动 pi
✗ PM 启动失败：6s 内既没看到配置的 PM 进程，也没等到我们 spawn 的 pid 写盘
✗   诊断（窗口最后 30 行 + 渲染出的命令 + 解析到的可执行文件）已写入：…/repo/.pi/team/state/pm-launch-failed.log
  手工复现：在隔离窗口跑诊断中的 render；或写绝对路径：TEAM_PM_BIN=/abs/path/<cli> team up
✗ PM 启动失败：请手动到 teamsmith-smoke-2878368:pm 里跑 …/fake-bin/pi；诊断见 …/pm-launch-failed.log

teamsmith resume · repo
  续跑 dev · T1.1
  分支：task/T1.1-smoke-task（来源：任务书 branch: 行）
✓ dispatched T1.1 → teamsmith-smoke-2878368:dev（含启动校验：proof=spawn pid=3380044；provider=deepseek model=deepseek-flash session=…）
! 但窗口里的 agent 已经退出（exit code 0）：team roster 会显示「pi 已退出」（续跑：team resume --agent dev）
```

判据核过三条：

1. **是真续跑**：日志里是一次真的 `resume`（`续跑 dev · T1.1`、真分支、真派单回执带 spawn pid 与会话名），不是一句「续跑」文案；被断言的串也是这两条具体文本，不是任意 PM 消息。
2. **PM 真的被尝试启动并失败**：`up` 先打「PM 没在跑（空提示符）：启动 pi」再打两条「PM 启动失败」，失败原因是假 pi 秒退（注释早就写明），与现场一致。
3. **前提是真的**：同一现场的 `repo/.pi/team/state/pm-restarts.log` 在 `up --agents` 前一秒记着

```
1792485224 2026-10-20T08:33:44Z state=idle evidence=PM 窗口是空提示符（cmd=bash）
```

`pm.pid.starting` 不存在（无在飞启动标记）——正是新前提断言要的形状。作者上一轮的对照红仍在盘上：`/var/tmp/p326-11c3/run.log` 里
`✗ §11c 前提：up --agents 之前 PM 状态是「running:1677517」`；第 4 次（`/var/tmp/p326-11c4/run.log`）`✓16 ✗0` 与 `✓ 342 ✗ 0`。

**保留 15 条产品断言**（不是只在报告里说）：同段在 `f9d34e57` 与 `f14be42b` 的断言行集合比对，**删除行 0**：

```
$ comm -23 <(f9d34e57 的 11c 断言行 | sort) <(f14be42b 的 11c 断言行 | sort)
（空）
$ comm -13 …   # 新增：§11c 前提（idle）的 ok/bad + roster 耗尽的一条 bad + make_pm_idle 不可用的一条 bad
```

### 2.2 `make_pm_idle`：只碰私有夹具，依赖已在表里声明

静态读 `smoke.sh:5631`：它只用 `$SESSION`（`teamsmith-smoke-$$`）、`$REPO`（`$TMP/repo`）、`$PMW`（`team paths` 读夹具配置得出），
加上 `pm_state_now`（子 shell 里 source `common.sh` + `team_load_config`，读的是夹具 `.pi/team/config.sh`）。它与 `$SKILL_DIR` 外部没有任何写路径，
判据是「连续 3 次采样都是 `idle:*` 且前台命令是真 shell」（`bash --noprofile --norc`，构造性空提示符），上限 600×0.5s，超时 `bad` 并打印最后状态。
本次运行的隔离证据：私有 socket `/var/tmp/v71-dev2/tmp/.t-1000.cUtTLX/…`，`0c` 断言「默认 server 上没有本轮的 session」为 ✓，`TEAM_*` 身份已显式清空。

**额外依赖一条，但已声明**：11c 现在需要 §11b 的 helper（`make_pm_idle` / `pm_state_now`）。表里 `11c` 的 needs 是 `4,11b`
（`section-paths.tsv:74`），选择器把 `11b`（及 `6i 6 3b 5 2`）带进来，实测 `--select 11c` → 12 段。缺 11b 时不会静默：`declare -F` 分支直接 `bad`。
未发现第二条隐含依赖（不依赖真 `pi`、不依赖登录 shell、不赌 sleep）。

一处**既有**噪音（不是本 change 引入，`scripts/**` 本 change 一字未动）：`common.sh:3401` 在诊断里 `< pm-launch-tail.txt`，该文件没写成时 shell 把
`No such file or directory` 打到 stderr（`up-agents.log` 第 3 行）。它不影响任何断言，但下一轮如果继续看这条路径，这是本函数的「留」注释与实际行为不一致。

## 三、`workflow-entry.sh`：一次运行，三条行为

```
$ cd /var/tmp/v71-dev2/clone && env -u TMUX -u TMUX_PANE … TMPDIR=/var/tmp/v71-dev2/tmp \
    bash skills/teamsmith/tests/workflow-entry.sh --tree /var/tmp/v71-dev2/clone
  ✓ workflow-entry ①：有效基点时这一步退出 0
  ✓ workflow-entry ①：容器命令带 `--floor` 与 `--paths "$@"`（不是全套、也不会丢路径）
  ✓ workflow-entry ①：3 条特殊文件名（换行 / 空格 / 引号+反斜杠）逐字节到达容器参数（cmp 一致）
  ✓ workflow-entry ②：基点不可解析（空）→ ::warning:: + 正向确认执行完整入口（openspec 校验 + smoke.sh --keep，且没有 --floor）
  ✓ workflow-entry ②：基点不可解析（0000…0000）→ ::warning:: + 正向确认执行完整入口（…）
  ✓ workflow-entry ②：基点不可解析（no-such-sha-2821055）→ ::warning:: + 正向确认执行完整入口（…）
  ✓ workflow-entry ③：容器执行失败（stub rc=5）→ 这一步非 0（rc=5），失败没被吞
== workflow-entry == ok 7 bad 0 skip 0        rc=0
```

静态读它执行的是什么：`awk` 只按缩进切出 `Gates (pinned container)` 这一步的 `run: |` 原文，`sed` 只换 `github.event.before` / `github.sha` 两个表达式
（若有别的 `${{ … }}` 残留直接 `bad`），`docker` 换成记录 NUL argv 的桩——**是执行工作流自己的块**，不是对 YAML 的再解释。它不写工作树（根在 `$TMPDIR` 下，退出删掉）。

**回退换成 `true` 的反例会不会被检出——静态核（不做变异矩阵）**：② 的判据是命令串必须同时含
`openspec validate --all --strict` 与 `bash skills/teamsmith/tests/smoke.sh --keep `，并且不含 `--floor`。把 gates.yml 里回退分支的命令换成空命令后，
argv 里记到的是 `true` / `… && true`：

```
true                                                     → CAUGHT(bad)
mkdir -p "$TMPDIR" && true                               → CAUGHT(bad)
mkdir -p "$TMPDIR" && openspec validate --all --strict && true → CAUGHT(bad)
mkdir -p "$TMPDIR" && openspec validate --all --strict && bash skills/…/smoke.sh --keep … → PASS(符合判据)
```

即旧写法（只查「缺 `--floor`」）放过的那种空命令，新断言会红。**边界**：这条检查不是真 GitHub 运行，也不证明容器里整套通过——`docker` 是桩，
`github.event.before/sha` 的真实取值、`::warning::` 在 runner 上的呈现都只有在真推一次才成立。

## 四、轻量检查、空清单语义、M35 豁免的历史

```
$ perl skills/teamsmith/tests/signal-lint.pl
signal-lint：干净（扫描 90 个脚本；pid 精确形态全部干净）            rc=0
$ perl skills/teamsmith/tests/signal-lint.pl --selftest
✓ signal-lint --selftest：29 个夹具 + 豁免机制全部符合预期           rc=0
$ perl skills/teamsmith/tests/signal-lint.pl --legacy <空文件>        # §58 现在喂给 lint 的形状
signal-lint：干净（扫描 90 个脚本；pid 精确形态全部干净）            rc=0
$ bash skills/teamsmith/tests/section-select.sh --check
ok: 映射表 key 唯一（135 行） / 段 ↔ 行一一对应（135/135） / needs 声明全部存在且指向更早的段（108 条）
SKIP（条件不满足）: 行 19 的字面模式在检出里不存在（…机器生成面）：.pi/skills
ok: 字面模式（642 条）里 641 条在位；1 条检出前提按缺失跳过（跳过不等于检查过）
ok: 豁免类（docs/*）没有任何行声明 / 前导段声明有效 / 段正文 token 覆盖（531 个）/ 账本归属 9/9 / gate-self-check 行有效（7 个 key）
== 选段自检 ==  ok 9  bad 0  SKIP 1                                 rc=0
```

**空清单不会让产品扫描被跳过**（静态读两处，不跑 §58 整段）：

- `signal-lint.pl:205-226`：扫描面 `@FILES`（90 个脚本）在 `load_legacy` **之前**就算好；豁免只决定命中是否转 LEGACY，**不决定扫谁**。空清单 → `%LEGACY` 空 → 每条命中都按普通行判红；本次运行输出里扫描数仍是 90。
- `smoke.sh:22200-22230`：`checkout_registered_paths_absent()`（`lib/checkout-shape.sh:119`）只回答「这一册账在这棵检出里能不能裁决」；空清单 → 返回 0 → §58 把一份空清单喂给 lint 并**照旧执行** lint，只多一条可见 `prereq_skip`（不计通过）。所以差别只有那条 skip 的文案对着空集，判断本身没变。

**报告里的归因要改**（这不是我的实现意见，是树与历史的事实）：作者报告 `71a3be19` 两处写「P330/V67 删夹具留下的过期豁免行」
（第 726、881 行），而同报告 §7.3b 又写「**没有**把它归因给 P330」。我核到的是：

```
$ git show --name-only --format="" a62ab6bb        # P330 的实现提交
docs/team/reports/P330-dev-bob.md
skills/teamsmith/references/troubleshooting.md
skills/teamsmith/tests/…（37 个 facets 文件）
（没有 docs/team/reports/** 的删除）

$ git log main --oneline -- docs/team/reports/M35-dev2        # 空：现行 main 历史里没有这条路径
$ git cat-file -e 05c6dabc:docs/team/reports/M35-dev2/pkg/lib.sh   # P159 注册这条豁免的提交上
→ absent
```

即：这条豁免**注册那天就没有对象**（现行 main 历史里该证据包从未存在；它只出现在 `origin/main` 可达的旧历史 `938e5ea2`），P330 的实现提交删的全是 `skills/teamsmith/tests/**`，碰不到 `docs/team/reports/**`。
结论按我看到的树写：**退役本身成立**（lint 规则未放宽、清单只少了那一条无对象记录、扫描面不变），**归因 P330 没有证据，应从报告里删掉或改成上面这句**。

## 五、静态审阅：probe 合并、workflow→36、11c needs、main 成果

### 5.1 probe：每组合并 run 只留一条整体退出码，各段读自己的行

```
$ git diff 4eabb0f5 f14be42b -- skills/teamsmith/tests/checkout-shape-probe.sh   # 6 个 hunk，+59/−49
$ grep -c '^\s*nest "\$P_' …     # 24（原 29；19/31/58→1、hyteeth 31/58→1、in2 31/58→1、mix 18/19→1）
$ 断言行（peq/phas/pbad/pnot）：142 → 139
```

逐个合并点核对：

| 合并 | 整体退出码断言 | 各段读什么 |
|---|---|---|
| mix `--select 18,19` | 1 条，且断言**非 0**（这次的红来自 §18 的缺失 SCOPE.md） | §19 的收口行 `✗0`、10 条相位 ✓、0 条机器生成面 SKIP；§18 仍然点名 SCOPE.md 且「不是前提跳过」 |
| hy `--select 19,31,58` | 1 条 `rc=0` | §19 的 10 SKIP + 0 机器面红；§31 的 SKIP 与 `✓ M28 真树`；§58 的证据层 SKIP 与 `✓ 58 lint 真树` |
| hyteeth `--select 31,58` | 1 条（rc=0 才 `pbad`） | M28 真树红、`tmp-hygiene.sh` 点名、`tmp-hygiene.sh:` file:line |
| in2 `--select 31,58` | 1 条 `rc=0`（⑨ 里），⑩ 明确不再重复 | §31 带清单的「另有 1 个历史豁免文件」；§58 的 `LEGACY docs/team/reports/P222-fixture/pkg/legacy.sh` |

同一个 `$?` 不再冒充三段结果；整次 run 的失败仍被那一条兜住。唯一一处语义变化是 ⑤c：以前 `--select 19` 断言 rc=0，现在合跑必须红（§18 在），
「§19 自己绿」改由 §19 的收口行 `✗0` 承担——这符合「各段读自己的行」，但读法是行级而非 run 级，记在这里以免下一轮误读。

### 5.2 workflow→36 的映射是真的

```
$ bash skills/teamsmith/tests/section-select.sh --paths .github/workflows/gates.yml
decision=RUN  sections=135  keys=5   （0 0b 0c 0d 36）      # 修复前同一路径是 FULL
$ bash skills/teamsmith/tests/section-select.sh --floor --paths .github/workflows/gates.yml
decision=RUN  sections=135  keys=129 （floor 128 + 36）
$ bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/tests/workflow-entry.sh
decision=RUN  keys=7  （36 / 12b-h0d / 40 + 前导）
```

表里 36 行 patterns 追加了两条，`exempt:` 仍只有 `docs/*`，`.github/**` 没有豁免，FULL 兜底没有改成 floor。

### 5.3 11c 的 needs 与 main 成果保留

```
$ awk -F'\t' '$1=="11c"{print $4}' section-paths.tsv     → 4,11b
$ git diff --name-status f9d34e57 f14be42b              → 13 M + 1 A（本 change 的写集）＋ 报告
$ git diff --name-only  main f14be42b -- skills/teamsmith/scripts/   → 空（本 change 没碰产品代码）
$ flip-*.sh 计数：f9d34e57 = 17，f14be42b = 17          （P330 的删除集没被还原）
```

P318 的 §58 修复在树上（`signal-lint` 干净就是它的读数，候选树不再有 `kill $(pgrep …)` 那条红）；P331 的 panel 源码与 `panel-b2.sh` 相对 `f9d34e57` 逐字节未动。
候选相对 main 的删除行只在它自己的四类文件里（`flip-*` 的删除来自 main 的合并，不是候选新增的删除）。

## 六、必修项 / 交 PM 裁（一处实现、一处报告）

> **第二轮已关闭**：这两条都写在 `295e966a`（报告 `4068e287`）里，已在 §第二轮 用一次 `--select 36` 直接验过。本节保留第一轮的原始说法作为比对基准。

### 必修 1 · 36⑨ 在门禁里从不执行（承接缺口）

`smoke.sh:18286` 的调用条件是

```
if [ -f "$SKILL_DIR/tests/workflow-entry.sh" ] && [ -f "$REPO/.github/workflows/gates.yml" ]; then
```

而 `$REPO` 是 `$TMP/repo`（`smoke.sh:875`，套件自己建的项目仓库）。全仓 `grep -n '\.github' skills/teamsmith/tests/smoke.sh` 只命中这三行新代码——
**没有任何一处把 `.github` 拷进 `$REPO`**，现场的 `$REPO` 顶层只有 `AGENTS.md docs .git .gitignore .pi README.md .worktrees`。
所以套件里 36⑨ 恒走 `else → cond_skip "检出里没有 CI 源码或脚本"`：映射是对的，但这条检查在门禁里**一次都不会跑**，只有单独 `--tree` 才跑。
任务书这一段要求的是「由现有36段调用并可单独执行…**补齐必要拷贝依赖**」；现在只做到了「可单独执行」。

两个（不是都要）最小修法，请 PM 裁一个：
1. **推荐**：调用点传承载 workflow 的那棵树——`--tree "$CHECKOUT_REPO_ROOT"`（`smoke.sh:107` 已经是 skill 所在仓库根），条件里的 `-f` 也看同一棵树。
   `workflow-entry.sh` 自己会把 workflow 拷进它的临时仓库，所以**不需要**额外的拷贝依赖；产品面检出没有 CI 源码时照旧如实 skip。
2. 或者：调用前把 `.github/workflows/gates.yml` 拷进 `$REPO`（任务书字面上的「补齐必要拷贝依赖」），代价是每次门禁多一次写夹具。

我没有改这一行：任务书写明发现必修项先汇总交 PM，不自行改实现。

### 必修 2 · 报告两处把 M35 豁免退役归因给 P330（无证据，且与同报告 §7.3b 自相矛盾）

证据见 §4。建议把那两句改成「该证据包在现行 main 历史里从未存在（P159 注册时即 absent），P330 的实现提交未触及 `docs/team/reports/**`」，或者删掉归因。

### 不构成缺口、但要记一句的三处

- §58 的 `prereq_skip` 文案现在对着空清单说「豁免清单登记的路径逐条不在」：判断没错（没有登记、没有文件在场），但这句话的集合是空的。作者已交 PM，我这一轮同意它是**文案问题**，不是「产品扫描被跳过」。
- `common.sh:3401` 在 `pm-launch-tail.txt` 缺失时把重定向错误漏到 stderr（§2.2 末）：既有噪音，`scripts/**` 本 change 未动。
- `--floor` 的 FULL 兜底、61b 的排期、floor 墙钟：本任务不碰，也**没有**读数。

## 七、未覆盖的整体范围（本轮不构成通过的部分）

- **没有**跑容器、`--floor` 整体、§36 整段、`checkout-shape-probe.sh` 整套、路由变异矩阵、计时实验、C4；**不重做 C4**。
- §36 的 36⑧（探针）与 36⑦（全键副本扫描）本轮**没有**读数；36⑨ 的证据只有我这次单独调用与静态核对。
- §58 整段没跑：只有原 lint、`--check` 与静态读两处函数；`signal-gate.sh` / `team-bg-stop.sh` / harness 那几条腿本轮没有读数。
- **不是**真 GitHub CI：workflow 的 NUL 链在宿主上用 docker 桩执行，容器内整套、`fetch-depth: 0`、`github.*` 真值、runner 上的注解呈现都没验。
- 11c 的这一次运行是本轮唯一一次（`--keep` 现场保留在 `/var/tmp/v71-dev2/tmp/teamsmith-smoke-clone-b47505fb.VrkPqC`）；作者第 4 次的现场早已被套件删掉，我**没有**看过它原来的 `up-agents.log`——本节所有 `up-agents.log` 引用都来自**我这次**的现场。
- 耗时只作参考（11c 段 23 s、整次选段 123.9 s）：11c 的旧 1018 s 在容器里、本机不是 runner，两者不作因果提速比。

## 八、交付检查

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/dev2 scope=published files=… hits=0 names=ok user=resolved   rc=0

$ git diff --check          # 空
$ git status --short        # 只有本报告（提交后为空）
```

local 模式：分支留在本地，未 push、未开 MR、未归档；没有触发远程 CI。

## 九、第二轮交付检查（2026-10-20T09:34Z）

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/dev2 scope=published files=1874 hits=0 names=ok user=resolved   rc=0
$ git diff --check     → rc=0（无输出）
$ git status --short   → 只有 M docs/team/reports/V71-dev2.md（提交后为空）
```

第二轮只改这份报告与自己的线程；clone 停在同一 HEAD，`status-lines=0`；未碰任何源码，未跑容器/floor/probe/矩阵/11c。
