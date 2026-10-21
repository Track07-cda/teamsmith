# P342 · 「夹具痕迹不许出现在真实账本里」把发布证据误判成泄漏

agent: dev-bob   status: delivered   time: 2026-10-20
branch: `task/P342-ledger-leak-release-logs`   PR/MR: -（本仓 local 模式）

**结论**：`--floor` 在 main 上报的那两条红（M9.8 / M16「夹具的痕迹出现在真实账本里」）是**取样范围**问题，
不是隔离破了。命中的两个文件是 0.3.0 发布留在 `.pi/team/state/release-030/` 的门禁日志与公开 CI 日志，
它们是「**关于**一次夹具运行的日志」，不是夹具自己写进账本的东西。修法按任务书收窄取样：`real_ledger_hits`
增加一条**按路径前缀**的豁免 `<root>/.pi/team/state/release-<名字>/`，注释写清它只覆盖发布证据目录、并点名
残余风险。承重证据：同一个扫描器在真实账本上 2 命中 → 0 命中；私有副本里往**真实状态目录**放一个带夹具
标记的探针，M9.8 / M16 **仍然红并且只点名探针**（发布证据不再被点名）；把豁免放宽成「路径里出现 `release-`
就跳过」会立刻造出假阴（同一前缀的普通账本文件被静默）。没有新增检查器（净零）。

**测试状态（先说）**：`bash -n` / `git diff --check` / `section-select.sh --check` / 账本禁令 / `openspec
validate --all --strict` 全绿；`--select 25,30`（两条隔离断言所在段）✓108 ✗0；`--select 12b,25,26,30`（扫描器
的**全部四个消费者**）✓379 ✗0；真实账本前后对比与私有副本翻转 A红/B绿/C红均已跑。**全套门禁没跑成**：它跑到
第 128 段 `61b` 被挂住上限停跑（exit 2），那是路由变异自检段、与本改动无关，细节与它自己的既往记录见第 6 节。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/smoke.sh` | `real_ledger_hits` 的 awk 过滤新增 `in_release_dir()`：前缀 `<root>/.pi/team/state/release-` 且目录名之后还有路径分量；头注加「排除之四」并把口径行改成「三条按确切路径的流量记录 + 一处按前缀的取样范围」，注释点名残余风险与三种不豁免的同前缀形状 |
| `docs/team/reports/P342-dev-bob.md` | 本报告 |

写集内：只动了过滤与注释，**没有**改隔离判据的其它部分、没有移动发布证据文件、没有新增门禁段或断言。

## 段号是怎么查出来的（任务书说「`--select 13` 或 M9.8/M16 所在的段」）

`13` 不是这两条断言所在的段（`13 · notify 扩展` 与本判据无关）。查法：

```
$ grep -n '^section "' skills/teamsmith/tests/smoke.sh | awk -F: '$1>10000 && $1<15000'
11152: section "25 · 唤醒计数 = digest 的可行动列表（M9.8）"
14157: section "30 · 代号必须带名字（M16）"
$ sed -n '11414p;14254p' skills/teamsmith/tests/smoke.sh
M98_PHANTOM="$(real_ledger_hits "M98[.A-G]|$M98SES" "$M98_REAL_MAIN")"
M16_PHANTOM="$(real_ledger_hits "M16[.A-E]|$M16SES" "$M16_REAL_MAIN")"
$ bash skills/teamsmith/tests/section-select.sh --select 25,30
decision=RUN
sections=135
keys=6
reason=0 ← prologue
reason=0b ← prologue
reason=0c ← prologue
reason=0d ← prologue
reason=25 ← selected
reason=30 ← selected
```

所以验收跑的是 `--select 25,30`（含前导 0/0b/0c/0d）。同一个扫描器还被 §12b（`ob_leak_scan`）与 §26
（面板隔离，`P10_LEAK_SCAN`）用，它们另跑了一次定向选段（第 5 节）。

## Verification evidence (must have actually been run)

**1. 真实账本上的前后对比（只读；就是报告里那两条红的现场）**

同一个根（本仓真实的 `.pi/team/state`），旧扫描器文本从 `HEAD~1` 原样抽出、新扫描器从工作树抽出：

```
$ bash /var/tmp/p342-flip/real-tree-before-after.sh
== 修复前（HEAD~1 的 real_ledger_hits）· M9.8 的取样模式 ==
.pi/team/state/release-030/container-full.log
.pi/team/state/release-030/public-ci.log
  (old: 2 个命中)
== 修复后（工作树的 real_ledger_hits）· M9.8 的取样模式 ==
  (new: 0 个命中)
== 修复前 · M16 的取样模式 ==
.pi/team/state/release-030/container-full.log
.pi/team/state/release-030/public-ci.log
  (old: 2 个命中)
== 修复后 · M16 的取样模式 ==
  (new: 0 个命中)
```

**2. 本树选段门禁（真实项目的真实账本）**

```
$ bash skills/teamsmith/tests/smoke.sh --select 25,30
  ✓ M9.8 隔离：真实账本的 inbox/state 里没有夹具的痕迹
  #5 25 · 唤醒计数 = digest 的可行动列表（M9.8） · 参考 用时 31s · ✓58 ✗0 SKIP0 · ticks 58
  ✓ M16 隔离：真实账本的 inbox/state 里没有夹具的痕迹
  ✓ M16 隔离对照：真正写进 state/ 的痕迹必须被同一个扫描抓到
  ✓ M16 隔离对照：inbox/bg/ 里的痕迹必须被抓到（bg 排除是确切路径，不是目录名）
  ✓ M16 隔离对照：三条真痕迹腿恰三条命中（state/bg/、审计日志与长保留付本仍不在清单里）
  #6 30 · 代号必须带名字（M16） · 参考 用时 6s · ✓27 ✗0 SKIP0 · ticks 27
== 选段结果 ==  ✓ 108  ✗ 0
```

**3. 私有副本里的红侧/绿侧（不往真实 state 写任何东西）**

两棵 `git archive` 出来的完整检出（旧 = `HEAD~1`，新 = `HEAD`），各自 `git init` 一次提交，
`.pi/team/state/release-030/` 里放的是**真实那两份日志的拷贝**：

```
$ bash /var/tmp/p342-flip/run-flip.sh
===== A-old-release =====            # 旧扫描器 + 发布证据
✗ M9.8 隔离：夹具的痕迹出现在真实账本里：/var/tmp/p342-flip/old/.pi/team/state/release-030/container-full.log /var/tmp/p342-flip/old/.pi/team/state/release-030/public-ci.log
✗ M16  隔离：夹具的痕迹出现在真实账本里：/var/tmp/p342-flip/old/.pi/team/state/release-030/container-full.log /var/tmp/p342-flip/old/.pi/team/state/release-030/public-ci.log
== 选段结果 ==  ✓ 106  ✗ 2
===== B-new-release =====            # 新扫描器 + 同一份发布证据
✓ M9.8 隔离：真实账本的 inbox/state 里没有夹具的痕迹
✓ M16 隔离：真实账本的 inbox/state 里没有夹具的痕迹
== 选段结果 ==  ✓ 108  ✗ 0
===== C-new-probe =====              # 新扫描器 + 发布证据 + 真的写进状态目录的探针
✗ M9.8 隔离：夹具的痕迹出现在真实账本里：/var/tmp/p342-flip/new/.pi/team/state/m98-leak-probe.txt
✗ M16  隔离：夹具的痕迹出现在真实账本里：/var/tmp/p342-flip/new/.pi/team/state/m98-leak-probe.txt
== 选段结果 ==  ✓ 106  ✗ 2
```

A 复现了报告里的假红，B 是绿侧，C 是承重红侧：探针内容 `M98G1 … / M16A …` 仍被两套模式抓到，而**同一棵树
里仍在的发布证据没有被点名**——豁免没有把整片判断关掉。探针：`/var/tmp/p342-flip/new/.pi/team/state/m98-leak-probe.txt`。

**4. 前缀边界（同一份函数文本，私有根）**

```
$ bash /var/tmp/p342-flip/prefix-check.sh
docs/team/inbox/release-9/leak.md          ← inbox 侧同名目录：点名
.pi/team/state/m98-leak-probe.txt          ← 真写进 state：点名
.pi/team/state/nested/release-9/x.log      ← 前缀没锚上：点名
.pi/team/state/release-scan-current.log    ← 同前缀的**文件**：点名
--- 第二根 ---
.pi/team/state/release-030                 ← 名字正好是 release-030 的文件：点名
```

被豁免的（不在清单里）：`.pi/team/state/release-030/container-full.log`、
`.pi/team/state/release-2026-10-20/other.log`、既有的 `.pi/team/state/bg/job.log`、`.pi/team/state/tmux-calls.log`。

**5. 扫描器的全部四个消费者（定向选段）**

```
$ bash skills/teamsmith/tests/smoke.sh --select 12b,25,26,30
  ✓ M9.8 隔离：真实账本的 inbox/state 里没有夹具的痕迹
  #7 12b · 延后投递与草稿入口（delivery-guard：守卫 / 队列 / 排水 / 草稿） · 参考 用时 45s · ✓87 ✗0 SKIP0 · ticks 87
  #8 25 · 唤醒计数 = digest 的可行动列表（M9.8） · 参考 用时 31s · ✓58 ✗0 SKIP0 · ticks 58
  #9 26 · 面板（pulse-tui-panel：模式 / 布局降级 / 净化 / 队列 / 运行时 / 隔离） · 参考 用时 124s · ✓143 ✗0 SKIP0 · ticks 143
  #10 30 · 代号必须带名字（M16） · 参考 用时 6s · ✓27 ✗0 SKIP0 · ticks 27
账本自查： 10 段收口 · 增量 ✓379 ✗0 SKIP0 ｜ 结果行 ✓379 ✗0 —— 一致
== 选段结果 ==  ✓ 379  ✗ 0          （smoke_rc=0）
```

**6. 轻量收口**

```
$ bash -n skills/teamsmith/tests/smoke.sh && echo OK
OK
$ git diff --check && echo diff-check-OK
diff-check-OK
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 9  bad 0  SKIP 1          （rc=0）

$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 21 passed, 0 failed (21 items)       （rc=0；本机非登录 shell 里没有 openspec，需 `~/.bun/bin` 进 PATH）

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=$HOME/…/.worktrees/dev-bob scope=published files=1968 hits=0 names=ok user=resolved
$ echo $?
0
```

**7. 全套门禁：跑过，被 §61b 的挂住上限停掉（与本改动无关）**

```
$ bash skills/teamsmith/tests/smoke.sh
…
… 段落 #128（61b · 任务类别模型路由：翻转变异自检（P228 · task-model-routing））已运行 1801s（挂住上限 1800s）
✗ 段落 #128（61b …）挂住：已 1800s 没有进度（挂住上限 1800s；段落已运行 1801s，ticks 0）→ 停跑（exit 2），现场 /var/tmp/teamsmith-pm_skills-deb708fe/.teamsmith-smoke-scene.497335
```

运行到第 128/135 段（前面的 0…61 段都跑完了），作业总时长 8318s。§61b 跑的是
`tests/task-model-routing.sh --flip`：那份脚本里没有 `smoke.sh` 的引用、也不含 `real_ledger_hits`
（`grep -n 'smoke\.sh\|--flip' skills/teamsmith/tests/task-model-routing.sh` 只命中它自己的 `--flip` 分支）。
它在本机的既有记录同样不稳，同一份 `state/bg/` 日志里有：

```
#43 61b · 任务类别模型路由：翻转变异自检（P228 · task-model-routing） · 用时 678s · ✓0 ✗1 SKIP0 · ticks 1
✗ 61b 路由翻转变异有失败（rc=1；RESULT pass=167 fail=34 selected=flip）
✗ 61b 路由翻转变异有失败（rc=1；RESULT pass=200 fail=1 selected=flip）
```

- Verdict: pass（本改动面：真实账本 2→0 命中、四个消费者 ✓379 ✗0、翻转 A红/B绿/C红、轻量收口全绿）
- Notes: **全套门禁没有拿到一次绿**（§61b 挂住 → exit 2，是既有的重段/不稳段，不是本改动引入的）；
  `--select 12b,25,26,30` 覆盖了 `real_ledger_hits` 的全部消费者，但没跑的 125 个键按选段口径不算全套。

## Flip evidence (required for defect-fix tasks)

- 红（旧代码，真实账本）：`real_ledger_hits` 命中 `release-030/container-full.log`、`release-030/public-ci.log`
  → M9.8 / M16 两条隔离断言 ✗2（私有副本 A：`✓106 ✗2`）。
- 绿（新代码，同一份证据）：0 命中 → `✓108 ✗0`（B）。
- 红侧承重（新代码 + 真的写进真实状态目录的探针）：仍然 ✗2，且只点名
  `.pi/team/state/m98-leak-probe.txt`（C）——豁免是**收窄取样**，不是关掉判断。
- 破坏实现 → 判据变样 → 还原（两处变异只改 `/var/tmp` 里的函数文本，树上的文件未动）：

  ```
  $ bash /var/tmp/p342-flip/mutate-check.sh
  == 现实现 ==
  docs/team/inbox/release-9/leak.md
  .pi/team/state/m98-leak-probe.txt
  .pi/team/state/nested/release-9/x.log
  .pi/team/state/release-scan-current.log
  == 变异1：in_release_dir 恒返回 0（= 不豁免）==
  … 同上四条 + .pi/team/state/release-030/container-full.log
      + .pi/team/state/release-2026-10-20/other.log      ← 发布证据重新被点名（= A 的现场）
  == 变异2：放宽成「路径里出现 release-」==
  docs/team/inbox/release-9/leak.md
  .pi/team/state/m98-leak-probe.txt
  .pi/team/state/nested/release-9/x.log                  ← release-scan-current.log 消失（造出假阴）
  ```

  变异1 说明豁免正是那两条命中消失的原因；变异2 说明「前缀锚定 + 目录名后必须还有分量」两个条件都是承重的。

## Decisions and deviations

- 任务书写「跑一次 `--select 13`（或 M9.8/M16 所在的段）」，实际段号是 **25 与 30**（13 是 notify 扩展）；
  查法与展开结果见「段号是怎么查出来的」。
- 没有新增门禁断言：写集只允许「`real_ledger_hits` 的过滤与注释」，且净零不新增检查器。这条豁免的常驻
  承接者仍是既有的 M16 对照块（钉住三条按确切路径的排除与三条真泄漏腿），**没有**一条断言钉住
  `release-*/` 的豁免本身。
- 实现用 awk 函数而不是再串一条 `index()`：豁免要同时判「前缀命中」与「目录名后面还有路径分量」，写成
  一条表达式会把 `release-scan-current.log` 这种同前缀文件误豁免（假阴，见变异2）。
- 全套门禁没有重跑第二次：§61b 单段就在挂住上限之上（既往一次 678s 且失败），重跑仍要先付 60+ 分钟，
  而它与本改动无交集；按「一条门禁一次、共享资源」的口径改成跑消费者的定向选段。

## 残余风险与没有做成常驻断言的原因

- **残余风险（注释里已点名）**：真有夹具往 `.pi/team/state/release-*/` 里写文件，M9.8 / M16 不会再抓它。
  这个目录只该装发布复核自己写下的日志；越界写由评审与发布复核兜。
- 不给它加常驻断言，是因为写集就是「过滤与注释」，加了就是新增守卫（净零原则）。若 PM 认为这条豁免需要
  自己的墓碑，一处就够：在 M16 的负对照块里加「`state/release-x/leak.log` 静默 + `state/release-scan-current.log`
  点名」两条断言，覆盖假阴的两侧。

## Suggested next steps

- 下一次 `--floor` 在 main 上应该不再出现这两条红；若 `release-030/` 下将来出现「夹具真的写进去」的证据，
  按上面的残余风险处理。
- **§61b 需要自己的任务单**（不是本任务的范围）：它单段成本在挂住上限之上，且本机既有记录里它两次
  `RESULT … fail=34` / `fail=1`。全套门禁在这台机器上因此拿不到绿——这会让每个交付都只能交定向选段。
- PM 复验可直接复用 `/var/tmp/p342-flip/`（`real-tree-before-after.sh` 只读；`run-flip.sh` 重建两棵私有
  副本；`prefix-check.sh` 与 `mutate-check.sh` 只碰 `/var/tmp`）与 `--select 12b,25,26,30`。
