# P413 · 单独裁出来的段不再 `command not found`（段副本自足，静态守在 §0c）

agent: dev   status: done   time: 2026-11-05T02:35Z
branch: `task/P413-select-self-contained`   PR/MR: -

**结论**：这一类的根因不是「11b4 少一个 helper」，而是「段的助手住在上一段的段体里，而 `--select` 只复制
选中的段」。所以我先修现场（助手搬进 `tests/lib/pm-window.sh`，任何选段都 source），再把判据做成**静态、
全键**的检查（`section-select.sh --self-sufficient`），让下一次同样形状的改动在 §0c 就红，而不是等公开 CI
的分片跑到才红。检查打在改动前的树上恰好点名 1 个键、2 个函数（11b4 · `make_pm_idle` / `pm_state_now`），
打在现在的树上 `ok 139 bad 0`。

跑真段的过程中，我自己第一版还有两个前置没备齐，都是**真跑才看见**的，已一并修掉并留了证据：
①`make_pm_idle` 假设 session 已经存在（单独裁出来的 11b4 前面没人建 → 白等 300s，一条红）；
②`11c` 的 `needs: 11b` 不能撤 —— 函数依赖没了，**场景**依赖还在（dev 窗口是该 run 里唯一的窗口，
假 pi 一退出窗口关掉、session 随之消失，后面五条连带红）。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/lib/pm-window.sh` | 新增。PM 窗口现场的共享助手：`pm_window_name`、`pm_state_now`、`pm_state_until(_not)`、`wait_session_gone`、`wait_window_gone`、`make_pm_idle`。由 `smoke.sh` 顶部 source（前导段，任何选段都带上）。段自己的夹具数据仍在段内 |
| `skills/teamsmith/tests/smoke.sh` | §11b 段体里那 6 个助手删除，只留本段夹具；§11b2/§11b3 显式 `pm_window_name`；§11c 去掉 `declare -F make_pm_idle` 兜底；§0c 的逐词 `grep assert_*` 退役，换成 §0c 段副本自足扫描（净零：断言条数仍 9） |
| `skills/teamsmith/tests/section-select.sh` | 新模式 `--self-sufficient`（读表＋源码，不起段、不写临时文件）；抽出 `mark_kept_groups` / `run_src_spec` 让「检查的副本」与「真跑的副本」共用一份几何；`sec_line`/`row_idx`/`key_group`/`sort_run_by_source` 改索引，去掉 hot loop 里的 fork |
| `skills/teamsmith/tests/lib/section-calls.pl` | 新增。一次进程解析整份套件 + 按区间缓存，输出「哪个键的副本调用了没有定义的段体函数」；附带 `assert_*` 用了没定义 |
| `skills/teamsmith/tests/section-paths.tsv` | `11b4` 补 `needs: 2`（它的 ① 用 `up --print`，需要 §2 写的 `.pi/team/config.sh`）；`11c` 的 needs 注释改成真正的原因（场景依赖）；`0c` 补两条它现在真的读的路径 |
| `skills/teamsmith/tests/loop-inventory.tsv` | 5 个 `while`+`sleep` 循环随助手搬到 `lib/pm-window.sh`，登记项按文件顺序同步搬 |

## Verification evidence (must have actually been run)

所有命令都在 `.worktrees/dev`、提交 `0114cf38` 的树上跑（工作树干净，`git status --short` 空）。

**① 静态检查（快，全键）**

```
$ bash skills/teamsmith/tests/section-select.sh --self-sufficient
== 段副本自足 == ok 139 bad 0（139 个键；段体函数 438 个，assert_* 未定义 0 个，整份套件的命令词 821 个）
wall=2.64s

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 13  bad 0  SKIP 1

$ bash skills/teamsmith/tests/section-select.sh --verify-copies
== 段副本 bash -n 扫描 == ok 139 bad 0

$ bash skills/teamsmith/tests/section-guard.sh --loop-check
section-guard --loop-check: 全过

$ git diff --check && echo clean
clean
```

**② 任务书点名的那三个选段（真跑，全部绿）**

```
$ bash skills/teamsmith/tests/smoke.sh --select 11b4          # 26s
#1 0 ✓3  #2 0b ✓3  #3 0c ✓9  #4 0d ✓9  #5 2 ✓39
#6 11b4 · PM 交接：--fresh-pm 与同 cwd 活会话提示（P36） · 参考 用时 17s · ✓33 ✗0
账本自查： 6 段收口 · 增量 ✓96 ✗0 SKIP0 ｜ 结果行 ✓96 ✗0 —— 一致
== 选段结果 ==  ✓ 96  ✗ 0        （rc=0）

$ bash skills/teamsmith/tests/smoke.sh --select 11b,11b3,11b4 # 145s
#11 11b  ✓57 ✗0   #12 11b3 ✓56 ✗0   #13 11b4 ✓33 ✗0   （另含 0 0b 0c 0d 2 4 5 3b 6 6i，全绿）
账本自查： 13 段收口 · 增量 ✓450 ✗0 SKIP0 ｜ 结果行 ✓450 ✗0 —— 一致
== 选段结果 ==  ✓ 450  ✗ 0        （rc=0）

$ bash skills/teamsmith/tests/smoke.sh --select 11c          # 103s
#12 11c · agent 续跑是 PM 的事（pulse 不碰） · 参考 用时 19s · ✓16 ✗0
（含 needs 的 11b ✓57 ✗0）
账本自查： 12 段收口 · 增量 ✓377 ✗0 SKIP0 ｜ 结果行 ✓377 ✗0 —— 一致
== 选段结果 ==  ✓ 377  ✗ 0        （rc=0）

$ bash skills/teamsmith/tests/smoke.sh --select 11b2         # 98s（同一批助手的另一个调用方）
#12 11b2 · PM 存活必须被证明 · ✓36 ✗0
账本自查： 12 段收口 · 增量 ✓397 ✗0 SKIP0 ｜ 结果行 ✓397 ✗0 —— 一致
== 选段结果 ==  ✓ 397  ✗ 0        （rc=0）
```

裸跑收口行（无 ANSI）：四个 run 都是 rc=0；`/var/tmp/p413-runs/summary.txt` 留了每段 `✓/✗/SKIP` 与用时。

- Verdict: pass（三个点名选段 + 11b2 全绿；静态四条全绿）
- 没跑的：**124 个键没跑**（本机整份套件一个多小时；按项目规则选段只覆盖它真跑过的段。上面四个 run
  覆盖 0 0b 0c 0d 2 3b 4 5 6 6i 11b 11b2 11b3 11b4 11c）。整份门禁由 PM/公开 CI 跑。
- 已知边界（别当保证看）：新检查只认「**段体里定义的函数**」。①变量/目录的跨段假设不在射程内 ——
  实测这种缺口是 `set -u` 下的 `rc=127` 硬失败（`bash -c 'set -uo pipefail; echo "$X"; echo after'`
  → `X: unbound variable`，`after` 不执行），是响亮的、点名的失败，不是静默塌陷；机械扫到的 41 对
  跨段变量我逐个看过，其中「生产者已在该段 needs 闭包里」与「`PATH=`/`TMPDIR=` 这类只作用于本条命令」
  两类之外，唯一真正共享的是 PM 窗口名，已经变成 lib 里的幂等 `pm_window_name`。②「段调了某个 lib
  却没 source 它」也不在射程内（lib 由前导段 source，形状稳定）。
- Ledger ban（在**自己的 worktree、自己的分支树**上跑）：

  ```
  $ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  ledger-ban: root=…/.worktrees/dev scope=published files=2377 hits=0 names=ok user=resolved
  $ echo $?
  0
  ```

## Flip evidence (required for defect-fix tasks)

两侧都打在**改动前的提交** `98c95289`（`git archive` 到 `/var/tmp/p413-red2`，与我的分支同一棵树）和
**现在的提交** `0114cf38` 上。

**红侧 1：改前的树上，`--select 11b4` 就是 command not found（25 条红，含后续断言全塌）**

```
$ bash skills/teamsmith/tests/smoke.sh --select 11b4        # 改前的树
/var/tmp/teamsmith-select.p413_red2-*.sh: line 2092: make_pm_idle: command not found
/var/tmp/teamsmith-select.p413_red2-*.sh: line 2101: pm_state_now: command not found
/var/tmp/teamsmith-select.p413_red2-*.sh: line 2103: pm_state_now: command not found
...
#5 11b4 · PM 交接：--fresh-pm 与同 cwd 活会话提示（P36） · 参考 用时 22s · ✓9 ✗25
== 选段结果 ==  ✓ 32  ✗ 26        （rc=1；另有一条 0d 红是 archive 树不是 git 仓库，与本案无关）
```

**红侧 2：新检查打在同一个改前的树上，点名 1 个键、2 个函数**

```
$ bash skills/teamsmith/tests/section-select.sh --self-sufficient --root /var/tmp/p413-red2
bad: 11b4 · 段体函数 make_pm_idle 在这份副本里没有定义（…/smoke.sh 的源码行 6315，11b）—— 定义搬进 tests/lib/ 或把 needs 写进映射表
bad: 11b4 · 段体函数 pm_state_now 在这份副本里没有定义（…/smoke.sh 的源码行 6264，11b）—— 定义搬进 tests/lib/ 或把 needs 写进映射表
== 段副本自足 == ok 138 bad 1（139 个键；段体函数 444 个）      （rc=1）
```

**绿侧：同一批命令打在 `0114cf38` 上**

```
$ bash skills/teamsmith/tests/section-select.sh --self-sufficient
== 段副本自足 == ok 139 bad 0

$ bash skills/teamsmith/tests/smoke.sh --select 11b4
#6 11b4 · 参考 用时 17s · ✓33 ✗0     （rc=0，26s 跑完）
```

**我自己第一版的两次假绿/假红也留在这里**（同一个 run 的两轮之间）：

```
# 第一轮：--select 11b4  ── ✓33 ✗1
✗ make_pm_idle：没等到窗口稳定在空提示符（上限 300s；最后状态 missing，前台命令 []）
#    → 原因：session 不存在，tmux new-window 直接失败。修：lib 里 session 不在就 new-session -n keep。

# 第一轮：--select 11c   ── ✓8 ✗9
can't find session: teamsmith-smoke-3764314
✗ 崩溃 agent 的任务记录还在（…/state/dev.env 中找不到 [task=T1.1]）
#    → 原因：我把 11c 的 needs:11b 撤掉了，但它还需要 §11b 造的场景。修：needs 恢复 4,11b，
#      注释改成真正的原因（函数依赖已取消、场景依赖仍在）。
# 第二轮（0114cf38）：11b4 ✓33 ✗0（26s）／11c ✓16 ✗0（103s）
```

## Decisions and deviations

- **净零**：§0c 原来那条逐词 `grep assert_[a-z_]+` 退役，被新扫描完全覆盖（`assert_*` 用了没定义照样红），
  断言条数不变（9 → 9）。没有「只加一条守卫」。
- **检查放在 §0c 而不是新段**：不新增段键（段表 139 行不变），选择器本身已有 `--check`/`--verify-copies`
  两个静态模式，`--self-sufficient` 是同一族的第三个；分片/`--check`/映射表都不需要再扩。
- **`--self-sufficient` 与 `emit_copy` 共用一份几何**（`mark_kept_groups`）：各写一遍会让「被检查的副本」与
  「真跑的副本」悄悄分叉，检查就成了橡皮章。
- **选择器 hot path 顺手改成索引/无 fork**：同一批几何算 139 次从 11.4s 降到 2.64s。决策输出与改前**逐字节
  相同**（14 组 `--paths/--floor/--select/--slice/--meta` 调用对照，全部 `same rc=0`）：
  `/var/tmp/p413-equiv.log`。
- **`make_pm_idle` 现在会建 session**：场景助手把场景备齐。副作用是「session 意外消失」时不再白等 300s，
  对既有四个调用方行为不变（session 在时走原来那条 `new-window -n keep`）。
- 与任务书的偏差：无（三个点名选段都真跑；另外补跑了 11b2，因为它是同一批助手的第四个调用方）。

## Suggested next steps

- PM 复验建议用独立 worktree 跑同样的四个选段（`--select 11b4` / `--select 11b,11b3,11b4` / `--select 11c`
  / `--select 11b2`）+ 三条静态命令；整份门禁留给合并前的那次全量。
- 公开 CI 的 shard 3 是这次事故的现场：合并后确认它在一次公开 run 里绿（`--self-sufficient` 2.6s 的增量
  对分片几乎无感）。
- 留给以后（不在本任务射程内，已写进检查的头注与上面的「已知边界」）：变量/目录的跨段假设没有静态守卫。
  若哪天出问题，方向是让 `section-calls.pl` 顺带扫「段内赋值、别段读取、且别段没把它写进 needs」——
  现在机械扫出来 41 对，噪音大（同名的两个局部夹具、`PATH=` 之类命令前缀），先不加。
