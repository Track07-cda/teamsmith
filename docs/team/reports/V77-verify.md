# V77 · P337 的独立验收（一条登记的对齐，判据仍是源码）

agent: verify   status: PASS   time: 2026-10-20T12:11Z
branch: `task/V77-loop-inventory-verify`（local 模式，未 push）   PR/MR: -

## 结论（先看这里）

**PASS。** 候选 `1db1bc0c`（实现 `1cda2e4a`）把 `loop-inventory.tsv` **一行**改对了：改的是 `--loop-check`
实际点名的那个循环（`smoke.sh:6392`，`smoke.sh` 里第 30 个 `while`+`sleep`，清单文件第 47 行），
任务书说的「清单第 30 条」（文件第 30 行，`smoke.sh 4688` / `${4:-50}`）**未动**。作者对任务书编号的纠正是对的。

四条判据都自己跑过：候选树上 `--loop-check` 绿（`85 行清单 / 85 个 while+sleep 循环，配平 85 个`）；
红侧在私有副本里两种破坏各点名一次 `smoke.sh:6392` 并 rc=1，还原即绿；`--select 0e` 从改前 `✓42 ✗3`
（rc=1）变成 `✓45 ✗0`（rc=0），多出来的正好是被修的那三条（42+3=45，没有别的计数变化）。

一条 PM 需要知道的口径：候选树相对**今天的 main** 并不是「只差这一个文件」—— main 在候选的基点之后自己
走了一个 P329 apply（`6d6b87db`），改了 `smoke.sh` 与 `section-paths.tsv`。候选相对**它自己的基点**
`5c62ab5d` 只有 `loop-inventory.tsv` 一行 + 作者报告，所以「候选没碰扫描面」成立；而「合并到今天的 main
之后这条修复还有效」我单独造了合并现场验证过：main 的树 + 候选的清单 → `--loop-check` 仍绿（85/85/85）。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/V77-verify.md` | 本复验报告（唯一的写入） |

受检对象（读，不改）：`skills/teamsmith/tests/loop-inventory.tsv` @ `1db1bc0c`。

## Verification evidence (must have actually been run)

### 1. `--loop-check` 在候选上：绿，且配平 85/85/85

在候选的整棵树副本里跑（`git archive 1db1bc0c` 解到 `/tmp/v77-verify-run/cand`），脚本用它自己的默认树：

```
$ cd /tmp/v77-verify-run/cand && bash skills/teamsmith/tests/section-guard.sh --loop-check
ok: 扫描 85 行清单 / 85 个 while+sleep 循环，配平 85 个

section-guard --loop-check: 全过
rc=0
```

### 2. 差异面：只有一行，改的是被点名的那一条

```
$ git diff main 1db1bc0c -- skills/teamsmith/tests/loop-inventory.tsv
@@ -44,7 +44,7 @@
-smoke.sh	6365	cap="$R_WAIT" -lt 1500	  while [ "$R_WAIT" -lt 1500 ] && ! $TEAM roster 2>/dev/null | grep -qF "pi 已退出"; do sleep 0.2; R_WAIT=$((R_WAIT + 1)); done
+smoke.sh	6392	cap="$R_WAIT" -lt "$R_MAX"	  while [ "$R_WAIT" -lt "$R_MAX" ]; do
```

编号对得上：清单文件第 **47** 行的那一行，按文件内出现顺序是 `smoke.sh` 的第 **30** 个循环
（`awk` 按 `file<TAB>line` 逐行数出来的 `smoke_index`）：

```
$ awk -F'\t' '!/^#/ && NF==4 {n++; if ($1=="smoke.sh") {sn++; print "tsv_line="NR"  smoke_index="sn"  src_line="$2}}' skills/teamsmith/tests/loop-inventory.tsv | sed -n '29,31p'
tsv_line=46  smoke_index=29  src_line=6288
tsv_line=47  smoke_index=30  src_line=6365     <- 改的就是这条（改后 6392）
tsv_line=48  smoke_index=31  src_line=6854
```

任务书说的「文件第 30 行」是另一条，两棵树上一致、未被触碰（候选里仍是 `smoke.sh 4688 / ${4:-50}`，
也是 `--loop-check` 绿所覆盖的 85 条之一）：

```
$ sed -n '30p' skills/teamsmith/tests/loop-inventory.tsv
smoke.sh	4688	cap="$i" -lt "${4:-50}"	    local i=0; while [ "$i" -lt "${4:-50}" ]; do
$ sed -n '4688p' skills/teamsmith/tests/smoke.sh
	    local i=0; while [ "$i" -lt "${4:-50}" ]; do
```

源码侧确实就是守卫点名的那个循环，而且新的 `cap=` 是真上限（`R_MAX=1500` × `sleep 0.2` = 300 s；
耗尽有具名红，不是静默空转）：

```
$ sed -n '6390,6399p' skills/teamsmith/tests/smoke.sh
  R_WAIT=0; R_MAX=1500; R_OUT=""; R_RC=0; R_HIT=0
  R_T0="$(date +%s)"
  while [ "$R_WAIT" -lt "$R_MAX" ]; do
    ...
    sleep 0.2; R_WAIT=$((R_WAIT + 1))
  done
$ sed -n '6401,6405p' skills/teamsmith/tests/smoke.sh
  # 耗尽不许静默：...
  if [ "$R_HIT" != 1 ]; then
    ... bad "§11c 夹具前提：$R_MAX 轮内 roster 没报出「pi 已退出」..."
```

扫描面（逐文件 blob 比对）：

```
# 候选 vs 它自己的基点 5c62ab5d —— 只有清单这一行
DIFF  skills/teamsmith/tests/loop-inventory.tsv

# 候选 vs 今天的 main —— 三个文件，多出来的两个是 main 自己 6d6b87db（P329 apply）改的
DIFF  skills/teamsmith/tests/loop-inventory.tsv   main=066ec2169002  cand=8f6732a5f09f
DIFF  skills/teamsmith/tests/section-paths.tsv    main=deeebb6d4d89  cand=695daf034578
DIFF  skills/teamsmith/tests/smoke.sh             main=e9faaef20ac6  cand=e938ba072bbb
$ git log --oneline 5c62ab5d..main -- skills/teamsmith/tests/smoke.sh skills/teamsmith/tests/section-paths.tsv
6d6b87db refactor(lock,gate): P329 one seat-directory derivation, and drop assertions that guard a number nobody produces
```

`section-guard.sh`、`lib/loop-scan.awk`、`lib/section-guard.sh` 及扫描面其余文件在候选与 main 之间
**逐字节相同**（blob 比对未列出的文件即相同）。

漂移的来源也点名了（对照任务书的「P326 改写后没登记」）：P326 的 `33da8f86` 改了 `smoke.sh` 94 行，
同一提交**没有**改清单：

```
$ git log --oneline -S'while [ "$R_WAIT" -lt "$R_MAX" ]; do' -- skills/teamsmith/tests/smoke.sh
33da8f86 feat(ci): P326 judge behaviour on the floor and on the changed paths, not the whole suite
$ git show 33da8f86 --stat | grep -E 'loop-inventory|smoke.sh'
 skills/teamsmith/tests/smoke.sh  |  94 +-
```

### 3. 红侧（私有副本，真实树不碰）：两种破坏各点名一次 `smoke.sh:6392`

副本 = `/tmp/v77-verify-run/red*`（候选整树拷贝）。

锚点列破坏（把锚点改成 `while … ] && false; do`，`cap=` 列不动）：

```
bad: smoke.sh:6392 的 while 行与清单第 30 行的锚点不符
     源码：  while [ "$R_WAIT" -lt "$R_MAX" ]; do
     清单：  while [ "$R_WAIT" -lt "$R_MAX" ] && false; do
ok: 扫描 85 行清单 / 85 个 while+sleep 循环，配平 85 个

section-guard --loop-check: 1 条不成立
rc=1
```

上限列破坏（`"$R_MAX"` → `"$R_CAP"`）：

```
bad: smoke.sh:6392 的循环丢了上限（清单要求循环体里出现 ["$R_WAIT" -lt "$R_CAP"]）
ok: 扫描 85 行清单 / 85 个 while+sleep 循环，配平 85 个

section-guard --loop-check: 1 条不成立
rc=1
```

还原（把候选的清单覆盖回去）→ 绿：

```
ok: 扫描 85 行清单 / 85 个 while+sleep 循环，配平 85 个

section-guard --loop-check: 全过
rc=0
```

### 4. `--select 0e`：候选全绿（改前 `✓42 ✗3`）

两棵树都是干净的 git worktree（`git worktree add --detach`，候选 `1db1bc0c`、改前基点 `5c62ab5d`），
各给一把私有门禁锁（不去抢机器级锁），`</dev/null`：

```
$ cd <wt-prefix: 5c62ab5d> && TEAM_SMOKE_LOCK=/tmp/v77-verify-run/.lock-prefix \
    bash skills/teamsmith/tests/smoke.sh --select 0e </dev/null
  #5 0e · 段落自述：看门狗 / 循环清单（P70 · P316） · 参考 用时 50s · ✓19 ✗3 SKIP0 · ticks 22
账本自查： 5 段收口 · 增量 ✓42 ✗3 SKIP0 ｜ 结果行 ✓42 ✗3 —— 一致
== 选段结果 ==  ✓ 42  ✗ 3
rc=1
```

改前的三条红，正好是循环清单那三条（不是别的东西顺带红的）：

```
✗ P70 循环清单：干净树绿（85 行清单 / 85 个 while+sleep 循环，配平 85 个）（期望 [0]，实际 [1]）
✗ P70 翻转（循环）还原：绿（期望 [0]，实际 [1]）
✗ P313 翻转（盲区）还原：绿（期望 [0]，实际 [1]）
```

候选：

```
$ cd <wt-cand: 1db1bc0c> && TEAM_SMOKE_LOCK=/tmp/v77-verify-run/.lock-cand \
    bash skills/teamsmith/tests/smoke.sh --select 0e </dev/null
  #5 0e · 段落自述：看门狗 / 循环清单（P70 · P316） · 参考 用时 49s · ✓22 ✗0 SKIP0 · ticks 22
账本自查： 5 段收口 · 增量 ✓45 ✗0 SKIP0 ｜ 结果行 ✓45 ✗0 —— 一致
== 选段结果 ==  ✓ 45  ✗ 0
rc=0
```

两轮运行指纹都没报「本次运行无效」（`RF_ROOT` = 各自 worktree 根，`checkout_shape` 是 git 检出，比较一致时
按设计一字不打印；`grep -c '本次运行无效'` = 0/0），两次跑动的树都是干净的。

选段不是整套：这次没跑的 130 个段照原有清单跳过（`--select 0e` 的前导段 `0 0b 0c 0d` + `0e`），
本报告不据此声称任何其它段的结果。

### 5. 合并到今天的 main 之后仍绿（我自己加的一条，任务书没写）

候选的基点在 todays main 之前，所以「相对 main 逐字节未变」这条字面判据今天已经不可满足了（见第 2 条）。
真正要回答的是「改这一行在今天 main 的 `smoke.sh` 上还成立吗」，因此造了这个现场（main 的整树 + 候选的清单）：

```
$ cd /tmp/v77-verify-run/merge && bash skills/teamsmith/tests/section-guard.sh --loop-check
ok: 扫描 85 行清单 / 85 个 while+sleep 循环，配平 85 个

section-guard --loop-check: 全过
rc=0
```

对照（同一份 main 的树、**不带**候选的那一行）：

```
$ cd /tmp/v77-verify-run/main && bash skills/teamsmith/tests/section-guard.sh --loop-check
bad: smoke.sh:6392 的 while 行与清单第 30 行的锚点不符
     源码：  while [ "$R_WAIT" -lt "$R_MAX" ]; do
     清单：  while [ "$R_WAIT" -lt 1500 ] && ! $TEAM roster 2>/dev/null | grep -qF "pi 已退出"; do sleep 0.2; R_WAIT=$((R_WAIT + 1)); done
ok: 扫描 85 行清单 / 85 个 while+sleep 循环，配平 85 个

section-guard --loop-check: 1 条不成立
rc=1
```

### 6. 轻量收口

```
$ git diff --check 5c62ab5d 1db1bc0c
rc=0
```

账本禁令（本工作树、本分支的树上跑；本报告写完之后跑的那一次）：

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（…/.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=…/.worktrees/verify scope=published files=1917 hits=0 names=ok user=resolved
$ echo $?
0
```

- Verdict: **PASS**
- Notes（如实写没做的）：没有跑整套门禁、没有跑容器、没有 `--select 11c` 真跑那段 tmux 夹具（任务书明说不要跑整套；
  `11c` 的夹具行为不属于这条登记的判据，判据是源码锚点与守卫自检）。`--select 0e` 是选段运行，130 个段没跑。
- 本分支自己的树（= `main` + 这份报告，**不含** P337 的那一行）上 `--loop-check` 仍是**红**的，因为漂移就在
  `main` 里；这是候选 `1db1bc0c` 要修的东西，不是本分支的缺陷，也不该被当成「复验分支自带红」：

  ```
  $ bash skills/teamsmith/tests/section-guard.sh --loop-check   # 在 task/V77-loop-inventory-verify 上
  bad: smoke.sh:6392 的 while 行与清单第 30 行的锚点不符
  section-guard --loop-check: 1 条不成立
  ```

## Flip evidence（缺陷修复类：红→绿）

守卫层（同一棵树形状，只差清单那一行）：

```
# 改前（main / 候选基点 5c62ab5d 的清单 + 源码） rc=1
bad: smoke.sh:6392 的 while 行与清单第 30 行的锚点不符
# 改后（候选 1db1bc0c） rc=0
ok: 扫描 85 行清单 / 85 个 while+sleep 循环，配平 85 个 · section-guard --loop-check: 全过
```

段层（同一段 `0e`）：

```
# 改前 rc=1：== 选段结果 ==  ✓ 42  ✗ 3
# 改后 rc=0：== 选段结果 ==  ✓ 45  ✗ 0
```

「砸掉实现 → 守卫必须红 → 还原」：见第 3 条，锚点/上限两种破坏各点名 `smoke.sh:6392` 并 rc=1，还原后 rc=0。

## Decisions and deviations

- **报告文件名**：任务书头写的是 `agent: dev` / `docs/team/reports/V77-dev.md`，但本席位是 `verify`
  （派单与 OWNERSHIP 一致：verify 只写报告），所以写 `docs/team/reports/V77-verify.md`；主检出与本分支上都
  没有 `V77-dev.md`（`git ls-tree -r --name-only main | grep V77` 只有任务书那一条），不存在两份报告并存。
- 任务书第 2 条的「`smoke.sh` / `section-guard.sh` / 扫描面相对 main 逐字节未变」按字面今天已不成立：main 在
  候选基点之后走了 `6d6b87db`（P329 apply），`smoke.sh` 与 `section-paths.tsv` 因此与候选不同。我没有把这条
  判成红，而是拆成两件可判的事并各自取证：候选相对基点的改动面（只有清单一行）+ 合并到今天 main 后的
  `--loop-check`（绿）。若 PM 要求字面判据，需要的是候选 rebase 到 main —— 那是新的候选，不在本任务范围。
- `--select 0e` 用了私有门禁锁路径（`TEAM_SMOKE_LOCK=/tmp/...`），避免与别人的全量运行排队；任务书要求「不要抢
  机器级门禁锁」，这与那种做法一致。
- 破坏只在 `/tmp/v77-verify-run/` 的副本与两个 detached worktree 里做；两个 worktree 与副本在收尾后删除，
  本工作树只剩这份报告。

## Suggested next steps

- PM 可以合入 `1db1bc0c`。合入后建议在合并结果上跑一次 `bash skills/teamsmith/tests/section-guard.sh --loop-check`
  （或 `--select 0e`），因为 main 还在动，锚点这类登记对 `smoke.sh` 的行级改动敏感；本次已证明今天的 main 上仍然成立。
- 这类漂移的根因是 `while` 行改写与清单登记在同一次提交里分开做（P326 的 `33da8f86` 改 `smoke.sh` 94 行未碰清单）。
  若 PM 想减少下次的漂红，可考虑把「`--loop-check`」放进 §0e 已覆盖的自检里（它本来就有一条）并让改 `smoke.sh` 的
  任务书强制带跑 —— 这里只作提示，不属本任务范围。
