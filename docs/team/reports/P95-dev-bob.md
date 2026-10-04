# P95 · `--post-merge` 的比较基准：从 main 的 tip 改到该任务的 squash 提交

agent: dev-bob   status: done   time: 2026-09-23T05:20Z（P95 主体）· 2026-09-28T08:2xZ（P96/F1 并入后重跑）
branch: `task/P95-post-merge`（代码 tip `c153a6a5`；其后只有报告/证据日志提交，本地模式不 push）   PR/MR: -

> **本轮增量（2026-09-28，PM 把 P96 的 F1 并入本任务）**：`--post-merge` 打印的「取记录」修法现在**自带提交**
> （一行 `checkout … && commit … -- <路径>`），原样执行后重跑就收敛；第 50 段新增 ⑥ 组 20 条断言（含旧形状红侧），
> 翻转包的 ④ 对 + §26 表格行同步。下面是 P95 主体的原文，修改处见 Deliverables / Flip evidence / Decisions 10-12。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-review.sh` | `team_review_postmerge_squash <ID>`（按既有约定在保护分支上定位该任务的 squash 提交：subject `<ID>[: ]` 前缀，或带 `Agent:` trailer 且 subject 点名任务）；`team_review_postmerge_paths <branch> [<basis>]` 的 P95 口径（`converged`/`late`/`behind`/`other`/`resolved`，缺省 basis = 旧口径）；`team_review_postmerge_versions_collide`（旧的「版本对不上」提示，只给 late 路径）；`team_review_postmerge_take_cmd`（**P96/F1**：取记录的修法 = 一行 `checkout … && [rm … &&] commit -m … -- <路径>`，自带收敛）；`team_cmd_review_postmerge` 的抬头/四种出口/退出码 |
| `skills/teamsmith/tests/smoke.sh` | 第 50 段（**append-only**，现在 62 条断言）：解冲突形状（含探针红侧翻转）、收敛、晚到代码仍非零、未合并分支回落、`Agent:` trailer 约定、多候选取最新、**⑥ 取记录修法自带收敛**（含旧形状红侧） |
| `skills/teamsmith/references/troubleshooting.md` | §26 重写：基准 = 合并提交、四种出口表、多候选规则（grant 写的 `§20` 是这一节在 P91 时的旧编号 —— 见 Decisions 7）；P96/F1 后又补上「取记录修法自带提交」那一行与收尾句 |
| `docs/team/reports/P95-dev-bob/run-section50.sh` | 第 50 段的聚焦运行器（smoke.sh 没有「只跑一段」的开关；抽前导 + 第 50 段，可指向变异树） |
| `docs/team/reports/P95-dev-bob/flip-post-merge-basis.sh` · `logs/flip-post-merge-basis.log` | 翻转证据包（旧实现 / 交付实现 / 反向控制 / 真仓库 P82 / **④ P96/F1 收敛对**），22 ok / 0 BAD |
| `docs/team/reports/P95-dev-bob/logs/full-gate.log` · `section50-focused.log` · `openspec-validate.log` | 完整门禁 / 第 50 段聚焦 / validate 的原始日志（交付树最终复跑，✓3535 ✗0 / ✓62 ✗0 / 18 passed 0 failed） |

## Verification evidence (must have actually been run)

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 18 passed, 0 failed (18 items)
VALIDATE_EXIT=0

$ TMPDIR=/var/tmp/p95-gate bash skills/teamsmith/tests/smoke.sh </dev/null   # 完整门禁（代码 tip c153a6a5）
== 结果 ==  ✓ 3535  ✗ 0
smoke 全绿
GATE_EXIT=0
（`TMPDIR` 是环境的无奈：/tmp 这块 15G tmpfs 余量一直在 6G 上下浮动，完整套会随机假红（见 Decisions 8）——
 原始日志随报告提交：`docs/team/reports/P95-dev-bob/logs/full-gate.log`）

# 交付树最终复跑（2026-09-28T08:4xZ，TMPDIR=/var/tmp/p95-final；日志同在 logs/ 目录）
$ bash docs/team/reports/P95-dev-bob/run-section50.sh              → == 结果 ==  ✓ 62  ✗ 0（rc=0）
$ bash docs/team/reports/P95-dev-bob/flip-post-merge-basis.sh      → == 结果 ==  ok 22  BAD 0（rc=0）
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict    → Totals: 18 passed, 0 failed（rc=0）

$ bash docs/team/reports/P95-dev-bob/run-section50.sh                       # 第 50 段聚焦（附录：smoke 没有段落开关）
== 结果 ==  ✓ 62  ✗ 0
section50 全绿
（⑥ 组 20 条：修法自带提交 / 原样执行 → 0 / 重跑不再劝 / 诱饵不被顺手提交 / 旧形状红侧）

$ bash skills/teamsmith/scripts/team review P82 --post-merge                     # 真仓库、真陈旧分支（修前 rc=1）
review P82 --post-merge：分支 task/P82-sender-apply（tip a4fb5a3f）vs main 的合并提交 0af22bcc0c（P82: apply notify-sender-identity — …）
  基准 = 这个任务的 squash 提交（main 的 tip 是 …）：后来者合进 main 的内容不再计入
  解冲突形状（4 个路径）：合并提交那一版与分支这一版互不来自对方 —— 这不是「代码没合并」：
      docs/team/threads/dev-bob.md
      skills/teamsmith/references/agent-adapters.md
      skills/teamsmith/references/troubleshooting.md
      skills/teamsmith/tests/smoke.sh
  做什么：按内容核对（`git diff 0af22bcc0c..task/P82-sender-apply -- <路径>` / grep 关键符号）确认分支的改动确实进了合并提交；
          记录若确实晚到，按内容取（整份 `git checkout task/P82-sender-apply -- <路径>` 会覆盖 main 上解冲突那一版）
rc=0        （0.46s；基线 = 该任务的 squash 提交）
```

- Verdict: **pass**（validate 18/0；完整 smoke 在 P96/F1 并入后的 tip `c153a6a5` 上全绿；第 50 段聚焦 62/0）
- Notes:
  - 第 50 段全是**纯 git** 夹具（不开 tmux、不跑 pi），FAST 与完整门禁都跑它（不存在「宣称在完整门禁里跑、
    实际没有调用点」的 P32/F1 形状）。
  - 零回归：既有的 §48（P91 的 8 个形状 52 条）在完整门禁里逐条照绿；`--pre-merge`（P76 的夹具）与
    `--post-merge` 的参数互斥 / fail-closed / 只读性（夹具断言 main 的 HEAD 不动）一个字节没动。
  - 真仓库实测：`team review P82 --post-merge` 从 rc=1（P91 复验记录里那条假红）变成 rc=0 + 解冲突形状
    四条（其中两条正是 brief 点名的 `threads/dev-bob.md`、`smoke.sh`）。
  - 未跑：真 tmux 场地与真 pi 进程（本任务不涉及）；`git push`（本地模式）。
  - 只读性：命令不写 state/、不动工作树（第 50 段的夹具照 §48 的口径只读；`--post-merge` 不跑门禁、不写记录）。

## Flip evidence (required for defect-fix tasks)

**红 → 绿（同一份夹具，换实现）**：`docs/team/reports/P95-dev-bob/flip-post-merge-basis.sh`（只读；夹具在 mktemp 里）
把 main 上 P91 那一版 `cmd-review.sh` 与交付树各拷一份，同一份「squash + PM 解冲突 + 晚到记录」夹具分别跑：

```
$ bash docs/team/reports/P95-dev-bob/flip-post-merge-basis.sh        # 22 ok / 0 BAD，rc=0
① 旧实现（main 的 P91 口径）vs 交付实现（同一份夹具）
  --- old rc=1 ---
  ✗ 两边都动过、版本对不上（main 那一版不来自这条分支，分支这一版 main 也没有过）
        docs/team/NOTES.md · skills/a.sh
    修法：重新合并这条分支（squash 或新 PR）+ 重跑门禁
  --- new rc=0 ---
    基准 = 这个任务的 squash 提交（main 的 tip 是 …）：后来者合进 main 的内容不再计入
    解冲突形状（2 个路径）：… 这不是「代码没合并」：docs/team/NOTES.md · skills/a.sh
    记录有更新 —— 取它：docs/team/reports/P95-dev.md
② 反向控制：把交付实现的「合并提交定位」影子掉（= 退回旧口径）→ 同一夹具必须重新变红
  --- shadow=0 rc=0 ---（不影子：夹具照旧绿，「解冲突形状」在场）
  --- shadow=1 rc=1 ---（影子掉：rc=1 +「版本对不上」，「解冲突形状」消失）
③ 真仓库 P82：旧实现 rc=1（假红）→ 交付实现 rc=0
④ P96/F1 收敛对（同一份夹具 + 一条新的晚到记录）
  --- 交付树 ---
  修法：git -C … checkout task/P95-flip -- docs/team/reports/P95-dev.md && git -C … commit -m "docs(team): take P95's late records from task/P95-flip" -- docs/team/reports/P95-dev.md
  原样执行后立刻重跑 → 0，且不再劝取记录（收敛）
  --- 变异树（打印器退回 P96/F1 之前的形状：只 checkout） ---
  修法：git -C … checkout task/P95-flip -- …（没有 commit）
  原样执行后：main 的 tip 没动（记录只进了索引），重跑还在劝取同一条记录（原地打转 = 病重现）
== 结果 ==  ok 22  BAD 0
```

**门禁内的红侧**（不依赖那份包）：第 50 段 ① 组里有一个同源探针，把 `team_review_postmerge_squash`
影子成 `return 1`（= 旧口径），同一份解冲突夹具必须翻回非零 —— 断言里同时钉住「红侧确实报版本对不上 /
确实劝重新合并 / 确实没有解冲突形状出口」：

```
  ✓ P95 ① 探针（同源、不影子）：同一夹具照旧 0
  ✓ P95 ① 翻转红侧：影子掉基准定位（= 旧口径）→ 同一夹具非零（P91 的假红重现）
  ✓ P95 ① 红侧：旧口径确实报「版本对不上」
  ✓ P95 ① 红侧：旧口径确实劝「重新合并」
  ✓ P95 ① 红侧：旧口径没有「解冲突形状」这个出口
```

即：把这次修的东西拿掉，同一份夹具立刻回到非零 +「重新合并」；把检查整体删掉（影子掉 `_paths`）的红侧由
P91 的 §48 ③ 继续钉着。原始日志：`logs/flip-post-merge-basis.log`。

## Decisions and deviations

1. **判定仍是「路径归属」，基准换成该任务的 squash 提交**（`team_review_postmerge_paths <branch> <basis>`）：
   每条路径拿 `base = merge-base(basis, branch)`、`basis:P`、`branch:P`、保护分支 tip 的 `P` 四份做三路判定 ——
   `converged`（分支这一版已经在保护分支上 = 取过/覆盖过）、`late`（分支有而基准没有）、`behind`（分支没动过 =
   差异在基准一侧）、`other`（基准在分支那一版之后又动过它）、`resolved`（两边都动过、版本互不来自对方）。
   「后来者合进 main 的内容」在基准换掉之后**根本不进 diff**（旧的 `behind`/`other` 分支仍留给回落口径用）。
2. **`resolved`（解冲突形状）退出 0，不报「代码没合并」**：这就是 brief 点的现场（P82 的
   `threads/dev-bob.md`、`smoke.sh` **是代码路径**）—— 判定依据只能是"合并提交里有没有分支的改动"，而
   解冲突那一版**既不是**分支那一版、**也不是** main 上别人的那一版（两边互不来自对方的历史），三路合并也
   解不出（P91 的 `unclear` 出口）。所以：**报出来 + 给出按内容核对的配方，但不自动重合并**；真正「分支带来
   的代码路径在合并提交里缺失/不同」的形状（`basis:P == base:P` 或分支在基准记下的那一版之后又动了它）仍然
   非零（第 50 段 ②）。代价说清：`resolved` 里的代码改动**不会**被判红，得靠 PM 按内容看（配方就印在那里；
   真仓库 P82 的 4 条已用 `git diff` 逐条核过，见报告上面的输出）。
3. **多候选取最新（不是「不猜」）**：同一任务在保护分支上落过多次（propose / 部分合并 / 补丁）时，先按
   `Agent:` trailer 收窄，仍多个就取**最新**那个 —— 线性历史里它是其余候选的后代，内容只多不少，只会让判定
   **更严**、不会更松；并且抬头点名用的是哪一个、`注：… 取最新的那个` 明说这件事。真仓库里 P18/P75/M38
   就是这种形状（旧的那条是部分合并）。
4. **收敛判定（`converged`）是这次新加的**：基准一旦换成"合并提交"，保护分支 tip 上"取过没有"就不再是 diff
   的一部分 —— 而 §48 ⑤ 的既有断言要求「取完记录后再核对 → 没有合并后新增」。所以逐路径额外比一次保护分支
   的 tip（同版或 blob 历史里用过 = 已收敛）。**不用时间戳**判：P82 的作者提交 `df6c03c6` 比 squash 提交
   `0af22bcc` 只早 1 秒（23:28:28 vs 23:28:29），时间戳根本分不出"合并后才提交的"。
5. **找不到合并提交 → 明说 + 回落旧口径**（brief 第 2 条）：`未找到这个任务的合并提交（约定：…）` 之后，逐字
   走 P91 的判定（第 50 段 ③：未合并的分支照旧报代码差异、非零）。`--branch` 之类含混用法照旧拒绝。
6. **`--pre-merge` 一字未动**，`--post-merge` 的互斥/只读/fail-closed 语义也不变；新增的判定函数仍是纯 git。
7. **文档 grant 的 `§20` → 实际改了 `§26`**：`--post-merge` 那一节是 P91 时以 "## 20 ·" 写下的
   （见 `f534ec4b`），后来 references 重排 + 英文化把它挪到了 §26（`aa138b84`）。改的是**同一节**，没有碰 §20
   （inbox wake 重放）那节。
8. **门禁环境：/tmp 满了（15G tmpfs），完整门禁用 `TMPDIR=/var/tmp/p95-full` 跑**：第一次完整跑在 §50
   前面就被 `No space left on device` 打死（`printf: write error`，夹具 init 失败 —— 那些红是环境的，不是代码的）。
   自查：`tmp-hygiene.sh --sweep --dry-run` 认出 88 个可回收根（1.5 GB）但**整体拒绝**——
   `/tmp/review-M6.7`（876 MB）的 review 记录 `docs/team/reviews/M6.7.md` 不存在（安全前提不成立 → 一个都不删）。
   那不是我该动的东西（也没去绕过它）；我清掉了自己 P66 的 scratch（`/tmp/p66-pkg-out`，157 MB，P66 包脚本可重建），
   然后把完整门禁的 `TMPDIR` 指到 302 GB 空闲的 overlay 上跑绿。**请 PM 处理 /tmp**：这块盘是全队共享资源，
   现在的状态会让任何人的完整门禁随机假红（这就是 D50 说的"机器欠的红"）。
9. **没动 `team help`**（`cmd-project.sh` 不在 grant 里）：P91 的 Decisions 5 还在（`--pre-merge`/`--post-merge`
   都不在那张表里）—— 需要单独 grant。
10. **P96/F1 的并入（取记录修法自带收敛）**：PM 的指令是「打印的命令自带提交 + 一条『原样执行后立刻重跑 → 0』
   的断言」。落地时发现一条要写进报告的事实：**只有记录晚到这个形状的退出码本来就是 0**（取记录不是错误，
   取完也不报红），病在「每次重跑都还在劝取同一条记录」——所以 ⑥ 除了 PM 点名的那条 rc 断言，另钉了
   `重跑不再劝取记录`（真正的收敛判据）与红侧 `旧形状取完再跑 → 还在劝取同一条记录`。P96/F1 原文也写的
   是「照字面执行会**原地打转**」（rc 层面的「非零」只出现在同时有晚到代码的形状，那个形状不走这段修法）。
11. **取记录的那次 commit 用 pathspec 形式、而且故意不写成候选**：`git commit -m … -- <路径>` 只提交它点名
   的路径（夹具里放了一个暂存的诱饵 `skills/a.sh`，断言它仍在暂存区照旧）；提交信息不带 `<ID>[: ]` 前缀也
   不带 `Agent:` trailer，否则它自己会被 `team_review_postmerge_squash` 当成「该任务的合并提交」候选，
   基准就从合并那次漂到取记录那次（第 50 段 ⑥ 末尾断言取完之后基准仍是那个 squash 提交）。
12. **`SKILL.md:118-120` 的同一句话现在陈旧了（未改：不在 grant 里）**：它还说记录→ `take them with the printed
   `git checkout <branch> -- …`」；实际打印的已经是一行带 `commit` 的 `&&` 链。建议的一行改法：
   `records-only → take them with the printed `git checkout … && git commit …` (one paste-able line; it commits,
   so the next run is already quiet)`。需要一条带 `SKILL.md` 的 grant（小事，可与上面 `team help` 那条一起派）。

## Suggested next steps

- 合并流程照 D49 用 `team review <ID> --post-merge`；看到 `解冲突形状` 就按印出的 `git diff <合并提交>..<分支>`
  逐条核对内容，别机械重合并；看到 `代码有未合并的改动` 才重合并 + 重跑门禁；看到 `记录有更新` 就把印出的那一行
   **原样**跑掉（它自带提交，下次就安静了）。
- 两个小 grant（各自一行）：`SKILL.md` 的合并小节那句（Decisions 12）+ 把 `--pre-merge`/`--post-merge` 列进
  `team help`（`cmd-project.sh`，Decisions 9）。
- /tmp 的 sweep：先落 `docs/team/reviews/M6.7.md`（或把 `/tmp/review-M6.7` 的处置写进账），再让
  `tmp-hygiene.sh --sweep` 走一遍 —— 否则下一次完整门禁还会随机红在磁盘上。
- 若接受把 `--pre-merge`/`--post-merge` 列进 `team help`，派一个带 `cmd-project.sh` grant 的小任务。
