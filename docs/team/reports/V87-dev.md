# V87 · P350 的独立验收：产品里那两处管道判定

agent: dev   status: **PASS**（四件事逐条成立；一处数字按实测纠正、一条不阻塞的覆盖缺口见第 7 节）
             time: 2026-10-21T04:11Z（`date -u`）
branch: `task/V87-product-sigpipe-verify`（local 模式，未 push、未合并）   PR/MR: -
受检：`03d29158`（产品是两个提交 `05dd6862` + `eedacbbe`；`git diff --numstat 7cbe373a 03d29158 -- skills/`
      给出 `common.sh` 8+/3−、`cmd-status.sh` 8+/4− —— 任务书写的 +11/−3、+12/−4 是变动行数合计；
      整份候选相对 `7cbe373a` 只有这两个文件、两处 hunk）
作者报告：`docs/team/reports/P350-dev-bob.md`

## 结论（先看这里）

**PASS。** 红侧不是抄作者的读数：我在自己的私有副本里把这两处**改回管道写法**（改完那两个文件与
`7cbe373a` 逐字节相同），用它跑同一套夹具，两个缺陷都复发了；换回候选树就都消失。

1. **判定没放宽。** 两处都是「同一份数据、同一条判据」，只是不再经过管道：explore 那处仍是
   `grep -E '^#{1,6}[[:space:]]'` 取标题流 + 同一条 ERE（id 两侧 `[^[:alnum:]_]`）；squash 那处仍是
   `grep -qx "$tree"` 整行精确匹配。反例实测（候选树、83 KB 标题流）：标题点名 `E710` 而探针是 `E71`
   → 10/10 拒绝；点名 `E719` → 10/10 拒绝；id 只在正文出现 → 10/10 拒绝；只有点名 `E71` 才 10/10 通过。
   树哈希侧：已合并分支的 tree、与只差一个字节的分支 tree 摆在一起时，后者判「领先 2」，不判已合并。
2. **红侧自己复现。** 私有红树（`common.sh`/`cmd-status.sh` 与改前逐字节相同）：explore 长标题流
   **30/30 误判**、squash 缓存腿在 `TEAM_SQUASH_LOOKBACK=400` **30/30 误判**、直读腿 **30/30 误判**；
   候选树同夹具三项都是 **30/30 正确**。机制读数同向：83 410 B 同一形状直跑管道三次，`PIPESTATUS=(141 0)`（写端吃 SIGPIPE、匹配端命中，`pipefail` 把它变成失败）。
3. **`git … || true` 那处合法，且「查不到 → 空答案」与原实现同判。** 它盖的是一个能点名的失败：
   `git log <保护分支>` 解析不到 ref（例如 `TEAM_PROTECTED_BRANCH=no-such-branch`）；CLI 顶层是
   `set -euo pipefail`，去掉 `|| true` 一个裸赋值就会带走整个进程（实测 rc=128）。判据一侧：同一份失败的
   git，旧写法（管道 + pipefail）rc=1、`PIPESTATUS=(128 1)`，新写法 rc=1、`trees` 为空 —— 两边都判「不在」。
   现场读数：`TEAM_PROTECTED_BRANCH=no-such-branch` 时红树/候选、缓存开/关四种组合，roster 全都给 `?`。
4. **没有别的行为变化。** 候选在 `skills/` 下只有这两处 hunk；受影响的用户可见面是
   `team board set <ID> done`（explore 的 done 闸门）、`team digest` 的 [4] 待收尾、`team roster` 的「领先」列
   （`team change status` 的 evidence 列同源）。同一夹具上红树把已 squash 的分支报成
   「领先 main 1（本地模式：PM 合并，不需要 push）」，候选报「已合并（squash，内容一致）· 无需 push」。

另有两件事要 PM 知道：**作者报告里 explore 侧的「16.5 KB 必错」在本机是竞态，不是稳定边界**（我实测
16 498 B 时 60 次里只错 2 次，83 KB 才是 30/30 必错；结论不变，见第 6 节）；**这次修复没有带测试，现有选段
在两处改回管道后照样全绿**（第 7 节，是否开一条补测试的后续任务由 PM 定）。

## 1 · 我拿什么跑的（副本与夹具）

受检树只读。所有破坏都在 `/var/tmp/v87/` 的私有副本里：

```
$ git archive 03d29158 skills/teamsmith | tar -x -C /var/tmp/v87/cut          # 候选树（TEAM_BIN 指向它）
$ git diff -R 7cbe373a 03d29158 -- skills/teamsmith/scripts/lib/common.sh \
                                   skills/teamsmith/scripts/lib/cmd-status.sh > /var/tmp/v87/revert.patch
$ cp -a /var/tmp/v87/cut/skills /var/tmp/v87/red && cd /var/tmp/v87/red && patch -p1 < /var/tmp/v87/revert.patch
$ diff -q <(git -C <本仓> show 7cbe373a:skills/teamsmith/scripts/lib/common.sh) skills/teamsmith/scripts/lib/common.sh
  （空）—— cmd-status.sh 同样为空
$ bash -n skills/teamsmith/scripts/lib/{common.sh,cmd-status.sh}              # 两棵树的这两个文件都通过
```

红树 = 候选树，只把那两处还原成管道写法；两个文件与改前 `7cbe373a` **逐字节相同**，其余文件未动。
夹具用候选自己的 `team init --no-skills --agents …` 建项目，产物都在 `/var/tmp/v87/{proj-e,proj-s}`；
驱动脚本 `/var/tmp/v87/{setup-project,setup-squash,repro-explore,repro-squash,mechanism}.sh`。
全部读数可复跑（脚本参数见下），`TEAM_BIN` 换红树/候选树即得红/绿两侧。

## 2 · 问题一：判定没被放宽（候选树上的负向对照）

两处新判据，逐条对过：

- **`common.sh:5226 team_done_phase_evidence`（explore）**：`heads="$(grep -E '^#{1,6}[[:space:]]' "$f")"`
  之后仍是原来那条 ERE
  `(^|[^[:alnum:]_])$(team_regex_escape "$id")([^[:alnum:]_]|$)`，只是从 here-string 读。
  `[ -f "$f" ]`、`team_regex_escape`、`heads` 的 local 声明都在。
- **`cmd-status.sh:146 team_branch_squash_merged`**：两条腿（缓存 / 直读）落到同一个 `trees`，最后一行
  `grep -qx "$tree" <<< "$trees"` —— 仍是 `-x`（整行）而不是「包含」。`lookback` 的校验、
  `tree` 非空的守卫（`[ -n "$tree" ] || return 1`，候选 `cmd-status.sh:151`）一字未动。

负向对照（每条 10 次，探针 id 与标题的差别只有一处）：

| 现场 | 候选树（83 461 B 标题流） | 红树（2 218 B 标题流） |
|---|---|---|
| 标题点名 `<id>0`，探针 `<id>` | 拒绝 10/10 | 拒绝 10/10 |
| 标题点名 `<id>9`，探针 `<id>` | 拒绝 10/10 | 拒绝 10/10 |
| `<id>` 只在正文，没有标题点名 | 拒绝 10/10 | 拒绝 10/10 |
| 标题点名 `<id>` | 通过 10/10 | 通过 10/10 |

```
explore/prefix   headings=83461 B  trials=10: ACCEPT 0 / REFUSE 10 / other 0
explore/suffix   headings=83461 B  trials=10: ACCEPT 0 / REFUSE 10 / other 0
explore/bodyonly headings=83512 B  trials=10: ACCEPT 0 / REFUSE 10 / other 0
explore/exact    headings=83460 B  trials=10: ACCEPT 10 / REFUSE 0 / other 0
```

红树那一列用的是 2 218 B（短到管道不出错），所以它量的是**判据本身**：改前改后对四种近似形状的判断完全一致。
候选在 83 KB 上也照样拒绝近似形状 —— 这条同时否掉了「长标题流 → 一律放行」这种放宽形态。

树哈希侧（squash 那处）：

- 未合并的对照分支 `task/S2`（内容不同）：红树/候选 × 三种配置都是「领先 1」，没有一次说已合并。
- 已合并的 `task/S1` 再追加一个只改一个字节的提交：候选两条腿都变成「领先 2」，不认成已合并；随后
  `git reset --hard HEAD~1` 还原，tree 回到 `7f749f94…`。
- 匹配行本身：清单里放 `<tree>` 的精确行 → rc=0；只放 `<tree>0` 与 `<tree` 去掉末字符 → rc=1（前缀/扩展不命中）。

## 3 · 问题二：红侧在我自己的副本里复发

### 3.1 explore 那处（`team board set <ID> done` 走 done 闸门）

夹具：DECISIONS.md 只有标题条目，点名接受条目是第 7 条标题，后面还有 1 500 条（文件 83 775 B）。

```
# 红树（两处改回管道，其余与候选相同）
$ TEAM_BIN=/var/tmp/v87/red/skills/teamsmith/scripts/team bash /var/tmp/v87/repro-explore.sh long 30
explore/long     headings=83775 B  trials=30: ACCEPT 0 / REFUSE 30 / other 0
$ TEAM_BIN=/var/tmp/v87/cut/skills/teamsmith/scripts/team bash /var/tmp/v87/repro-explore.sh long 30
explore/long     headings=83775 B  trials=30: ACCEPT 30 / REFUSE 0 / other 0
```

同一条命令的用户可见差异（各跑一次，DECISIONS.md 83 780 B，标题里点名了该 id）：

```
# 红树
  - ③ 阶段 explore 的交付证据：既没有标题点名 Sred… 的 docs/team/DECISIONS.md，也没有 docs/team/reviews/Sred….md
✗ 没有可核对的证据（BOARD 未改动）——done 是一句承诺，不能只凭手写
✗   ③ 阶段 explore 的交付：PM 把接受结论落盘：docs/team/DECISIONS.md 里用一个标题条目点名 Sred…，或写 …
# 候选
  done 证据：OK：阶段 explore 的交付证据：PM 接受记录 docs/team/DECISIONS.md（标题点名 Scut…）
✓ board Scut… → done
```

短标题流是这处的对照（同一夹具、同一命令，只有 DECISIONS.md 变短）：红树 `ACCEPT 30/30`，候选 `ACCEPT 30/30`
—— 说明红的是长标题流这条路径，不是夹具或 done 闸门的其它条件。

### 3.2 squash 那处（`team roster` 的「领先」列）

夹具：`main` 405 个提交（其中 402 个空提交，把保护分支的 tree 清单撑长），`task/S1` 有真内容、
已 `git merge --squash` 进 main，工作树 `.worktrees/s1` 停在分支上；`task/S2` 是未合并的对照。
`200` 行清单 8 200 B、`400` 行 16 400 B。

```
# 红树
squash/default     trials=30: 已合并 30 / 领先1 (wrong: the branch IS squash-merged) 0 / other 0
squash/lookback400 trials=30: 已合并 0  / 领先1 (wrong: the branch IS squash-merged) 30 / other 0
squash/cacheoff    trials=30: 已合并 0  / 领先1 (wrong: the branch IS squash-merged) 30 / other 0
# 候选树
squash/default     trials=30: 已合并 30 / 领先1 (wrong) 0 / other 0
squash/lookback400 trials=30: 已合并 30 / 领先1 (wrong) 0 / other 0
squash/cacheoff    trials=30: 已合并 30 / 领先1 (wrong) 0 / other 0
```

三种配置：默认（缓存开、lookback 200）、缓存开 + `TEAM_SQUASH_LOOKBACK=400`、`TEAM_SCAN_CACHE=0`（直读腿）。
红树的默认配置是绿的（清单 8 200 B 没跨过写端缓冲），另两种 30/30 错 —— 与作者报告的方向一致。

机制读数（同一份负载直跑，不经过产品）：

```
$ bash /var/tmp/v87/mechanism.sh 16 40      # 16 413 B 标题流，写端 = grep 读文件
explore-shape file=16413 B trials=40: pipeline rc!=0 (misjudged) 13 / rhs matched 40
$ bash /var/tmp/v87/mechanism.sh 64 20
explore-shape file=65562 B trials=20: pipeline rc!=0 (misjudged) 20 / rhs matched 20
```

即：匹配端每次都命中了（40/40、20/20），是 `pipefail` 把写端的 141 当成了失败 —— 正是被修的那个根因。

## 4 · 问题三：`|| true` 那处是否合法

候选 `cmd-status.sh:160`：

```sh
trees="$(git -C "$wt" log --format=%T --max-count="$lookback" "$TEAM_PROTECTED_BRANCH" 2>/dev/null || true)"   # 留：查不到=空答案（不是故障）
```

**能一句话点名的失败**：`git log <保护分支>` 解析不到 ref。这不是假设：`TEAM_PROTECTED_BRANCH` 是可配置值，
本地模式下保护分支也可能改名/尚未建。同文件 `common.sh:381` 的 `_team_prot_trees_load` 是同一个形状、同一条
`留：` 注释 —— 缓存腿一直这么写，新代码只是让直读腿与它对齐。

**它是承重的**（CLI 顶层 `set -euo pipefail`）：

```
$ bash -c 'set -euo pipefail; trees="$(git -C <proj> log --format=%T --max-count=3 no-such-branch 2>/dev/null || true)"; echo "with || true: rc=$? trees=<${trees}>"'
  with || true: rc=0 trees=<>
$ bash -c 'set -euo pipefail; trees="$(git -C <proj> log --format=%T --max-count=3 no-such-branch 2>/dev/null)"; echo reached'
  （没有输出）—— shell rc=128，整个脚本在这里结束
```

**「查不到 → 空答案」与原实现同判**：

```
$ bash -c 'set -uo pipefail; git -C <proj> log --format=%T --max-count=3 no-such-branch 2>/dev/null | grep -qx deadbeef; echo "old rc=$? PIPESTATUS=(${PIPESTATUS[*]})"'
  old rc=1 PIPESTATUS=(128 1)
$ bash -c 'set -uo pipefail; t="$(git -C <proj> log --format=%T --max-count=3 no-such-branch 2>/dev/null || true)"; grep -qx deadbeef <<< "$t"; echo "new rc=$? trees=<${t}>"'
  new rc=1 trees=<>
```

两边都是「不在」。现场读数也一致：`TEAM_PROTECTED_BRANCH=no-such-branch` 时，红树与候选、`TEAM_SCAN_CACHE=1/0`
四种组合的 roster 全都给 `?`（不是「已合并」，也不是「领先 0」）：

```
s1         · 无窗口 task/S1                       0        ?       -  ·unavailable                      -                -
```

有一点值得写下（不是缺陷）：`grep -qx "" <<< ""` 会匹配空行（实测 rc=0），所以 `tree` 非空的那条守卫是这行的
前提；它没有被这次改动碰到（候选 `cmd-status.sh:151`），空答案只会走「不在」。

## 5 · 问题四：没有别的行为变化（调用点与用户可见效果）

候选在 `skills/` 下只有两处 hunk，所以「别的变化」只能从这两处的消费者看：

| 位置 | 谁在用 | 用户可见效果 |
|---|---|---|
| `common.sh:5240` explore 判定 | `team_done_evidence`（定义 `:5397`，在 `:5450` 调它）← `team_done_gate`（`:5699`）← `team_board_set`（`:5752`） | `team board set <ID> done`：标题条目确实点名时不再被拒；`team_task_open_reason`（派单叠第二个任务时问「结束了吗」）同源 |
| 同上 | `team_task_evidence_line`（`:5679`） | `team change status` 的 evidence 列（explore 任务的「凭什么算结束」） |
| 同上 | `team_report_pending_action`（`cmd-status.sh:325`，`:331` 调它） | `team digest` 的待复验下一步 / `team status`：从「阶段 explore 证据未就绪」变成「阶段证据已就绪（PM 接受记录 …）→ 等 PM 把看板移入 done」 |
| `cmd-status.sh:146` squash 判定 | `team_wrapup_is_squash_merged`（`:166`）← `team digest` [4] 待收尾（`:949`） | 已 squash 的分支显示「已合并（squash，内容一致）· 无需 push」，不再显示「领先 main N（…要 push…）」 |
| 同上 | `team roster` 的「领先」列（`:1463`） | 列里显示「已合并」而不是「1」 |

同一夹具上的对照（`TEAM_SQUASH_LOOKBACK=400`，红树唯一出错的那条缓存腿；直读腿同样）：

```
# 红树 digest [4]
  s1         — ｜ 无 upstream（未 push 无法判定） · 领先 main 1（本地模式：PM 合并，不需要 push） ｜ task/S1 ｜ -
  s2         — ｜ 无 upstream（未 push 无法判定） · 领先 main 1（本地模式：PM 合并，不需要 push） ｜ task/S2 ｜ -
# 候选 digest [4]
  s1         已合并（squash，内容一致）· 无需 push   ｜ task/S1 ｜ -
  s2         — ｜ 无 upstream（未 push 无法判定） · 领先 main 1（本地模式：PM 合并，不需要 push） ｜ task/S2 ｜ -
```

`s2`（真未合并）两边一致 —— 修的是误判，不是把「领先」全改掉。

一处顺带确认（不是这次引入的）：`cmd-status.sh` 里 `team_cmd_roster` 定义了两次（候选 `:427` 与 `:1445`），
bash 后定义生效，所以 `:441` 那处调用是死代码；生效的是 `:1463`。两处调用形状相同，这次改动同时覆盖了它们。

## 6 · 与作者报告对不上的一处数字（请 PM 按这节复核）

作者写「explore 侧长标题流改前 30/30 误判」，并把触发尺度说成「约 16 KB」。**16.5 KB 在本机是竞态，不是稳定边界**：

```
# 红树、16 498 B 标题流，60 次
explore/mid      headings=16498 B  trials=60: ACCEPT 58 / REFUSE 2 / other 0
# 红树、83 775 B 标题流，30 次
explore/long     headings=83775 B  trials=30: ACCEPT 0 / REFUSE 30 / other 0
# 机制探针（不经过产品）：16 413 B 的同一形状，40 次里 13 次 pipeline rc≠0
explore-shape file=16413 B trials=40: pipeline rc!=0 (misjudged) 13 / rhs matched 40
```

换句话说：写端（`grep` 读文件）与读端（`grep -q` 命中即退）谁先完成是排程决定的，16 KB 附近只是它偶尔撞上
（作者那次 30/30 全撞上，我这次 60 次里 2 次）；**跨过管道缓冲（本机 64 KB）之后才是确定性的**。结论不变：
默认 200 行（8 200 B）的缓存腿与直读腿都会错（第 3.2 节 30/30），修复把这条路径整个去掉了。作者对自己
squash 侧边界的修正（392→393 行）方向与我的 200/400 两端一致，我没有重做逐行二分。

## 7 · 跑过的检查，和一条不阻塞的覆盖缺口

私有 clone `/var/tmp/v87/repo-cut`，同一个选段跑两次，退出码直接取（不经管道）：

```
$ cd /var/tmp/v87/repo-cut && echo "HEAD=$(git rev-parse --short HEAD) dirty=$(git status --porcelain --untracked-files=all | wc -l)"
  HEAD=f679d883 dirty=0            # = 03d29158 + 把这两处改回管道的私有提交
$ bash skills/teamsmith/tests/smoke.sh --select 11i,20,24,37 > /var/tmp/v87/rc-reverted.log 2>&1
  REVERTED_SMOKE_RC=0
== 选段结果 ==  ✓ 166  ✗ 0        # 9 段收口（前导 0/0b/0c/0d/2 + 11i/20/24/37），账本自查 ✓166 ✗0 一致
  2 · ✓38 ✗0 ｜ 11i · ✓15 ✗0 ｜ 20 · ✓43 ✗0 ｜ 24 · ✓24 ✗0 ｜ 37 · ✓23 ✗0
$ git checkout -q 03d29158 && echo "HEAD=$(git rev-parse --short HEAD) dirty=$(git status --porcelain --untracked-files=all | wc -l)"
  HEAD=03d29158 dirty=0
$ bash skills/teamsmith/tests/smoke.sh --select 11i,20,24,37 > /var/tmp/v87/rc-candidate.log 2>&1
  CANDIDATE_SMOKE_RC=0
== 选段结果 ==  ✓ 166  ✗ 0        # 同样 9 段、同样 ✓166 ✗0；账本自查一致
  2 · ✓38 ✗0 ｜ 11i · ✓15 ✗0 ｜ 20 · ✓43 ✗0 ｜ 24 · ✓24 ✗0 ｜ 37 · ✓23 ✗0
```

（更早一轮先跑过同样两次，读数一致：候选 ✓166 ✗0 用时 138 s、改回管道后 ✓166 ✗0 用时 88 s；那两轮的输出
经了 `tail` 管道，退出码不作数，所以用上面这一轮。）

**这是这条任务里唯一值得 PM 决策的发现**：候选没有带任何测试（`skills/` 下只有两处产品 hunk），而现有选段
在**缺陷已经被放回去**的树上照样全绿 —— 夹具的 DECISIONS.md 与 tree 清单都太短，两个缺陷都需要长数据才现形。
所以这次修复今天没有任何门禁守着它，同样的写法再回来时不会有红灯。按项目纪律（「加个守卫要在同一次变更里
换掉一个旧的」），我没有在本轮自行补测试；要不要开一条后续任务补一条能复现的墓碑，请 PM 定。

没跑的：整套（其余 126 个键，见 `state/bg/v87-select-11i-20-24-37.log` 末尾逐个列出）；也没跑两处之外的段。
第一次开跑前 `ps` 确认没有别人的 `smoke.sh`；第二次在第一次结束之后接着跑（同一次任务）。两次都没有绕锁（未设 `TEAM_SMOKE_NO_LOCK`，两份日志里也没有排队行）。

## 8 · 一句话给 PM

候选把两个真缺陷的根因去掉了，判据一字未松，红侧我自己复现得出，`|| true` 那处盖的是一个能点名的 ref 解析失败
并且是 `set -e` 下必需的；可以合并。除合并外只有两件可选动作：作者报告里「16.5 KB 必错」改成「16 KB 附近是竞态，
跨过 64 KB 才确定」（第 6 节），以及要不要补一条能抓住「把它改回管道」的测试（第 7 节）。
