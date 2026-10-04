# P91 · 合并之后的核对：分支在合并后又动了什么（D45 的另一半）

agent: dev-bob   status: done   time: 2026-09-23T00:45Z
branch: `task/P91-d49`（tip `1d879fb4`，本地模式不 push）   PR/MR: -

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-review.sh` | `team review <ID> --post-merge`：逐路径比对 `main..task/<分支>`，把 `<docs>/**`（记录 → 取它，退出 0）与 `skills/**`（代码 → 重新合并 + 重跑门禁，非零）分开说；新增 `team_review_postmerge_paths` / `_had_blob` / `_merge3` 三个只读函数；参数互斥与 fail-closed 照 `--pre-merge` 的口径 |
| `skills/teamsmith/tests/smoke.sh` | 第 48 段（append-only）：8 个形状 / 52 条断言 —— 刚合并完、记录晚到、代码晚到、陈旧分支反假红、取完收敛、版本对不上、含混用法、fail-closed，以及**反向**（影子掉判定 → 同一夹具被静悄悄放过） |
| `skills/teamsmith/SKILL.md` | 步骤 5 补一句「合并后若作者仍在动，先跑这一步」；命令块 3c |
| `skills/teamsmith/references/protocol.md` | §8e 在 pre-merge 那段之后补 post-merge 一段（判据 / 输出 / 退出码 / rc 2 的语义与理由） |
| `docs/team/reports/P91-dev-bob/logs/` | 原始日志：`fast-smoke.log` · `full-gate.log` · `section48-before-oldtree.log` · `section48-after.log` · `real-p82-post-merge.log` |

## Verification evidence (must have actually been run)

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
- Validating...
✓ spec/agent-adapters ... ✓ spec/watchdog
Totals: 30 passed, 0 failed (30 items)
OPENSPEC_EXIT=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null          # tip 1d879fb4
== 结果 ==  ✓ 2744  ✗ 0                 （第 48 段 52 ✓ / 0 ✗；FAST 也跑它——纯 git 逻辑，不开 tmux/不起进程）

$ TEAM_SMOKE_LOCK_WAIT=7200 bash skills/teamsmith/tests/smoke.sh </dev/null    # tip 1d879fb4，排队后拿锁实跑
另一套全量 smoke 正在跑；本套排队，最多等 7200s
轮到本套了（排过队）
== 结果 ==  ✓ 3410  ✗ 0
smoke 全绿
SMOKE_EXIT=0
（00:23:05 拿锁 → 00:42:17 跑完 ≈ 19 分钟；之前的等待是机器锁，不是本套的成本）

$ bash skills/teamsmith/scripts/team review P82 --post-merge                  # 真仓库、真陈旧分支
review P82 --post-merge：分支 task/P82-sender-apply（tip a4fb5a3f）vs main（tip 99bcc29a）
✗ review P82 --post-merge：✗ 两边都动过、版本对不上（main 那一版不来自这条分支，分支这一版 main 也没有过）—— 自己看一眼，别直接取：
      docs/team/threads/dev-bob.md
      skills/teamsmith/tests/smoke.sh
  修法：重新合并这条分支（squash 或新 PR）+ 重跑门禁，再 board set P82 done
rc=1        （0.16s；裸 `git diff --stat main..<分支>` 报 91 个路径，其中 89 个是别人任务的）
```

- Verdict: **pass**（FAST 与全量都在最终实现 tip `1d879fb4` 上；validate 30/0）
- Notes:
  - 第 48 段全是**纯 git** 夹具（不开 tmux、不跑 pi），所以 FAST 与全量都跑、都绿；不存在「宣称在完整门禁里跑、实际没有调用点」那种形状（P32 的 F1 教训）。
  - `--pre-merge` 一个字节没动：第 45 段（P76 的夹具）在 FAST 与全量里都照跑照绿。
  - 真仓库实测那两条「版本对不上」都属实：main 的 `threads/dev-bob.md` 有 PM 的两条 grant（分支没有），分支有 23:45 那条交付记录（main 没有），只取任一版都会丢东西；`smoke.sh` 是 P86 重写同段的冲突（分支的确没有 main 的那版内容）。不是工具误报。
  - 未跑：真 tmux 场地与真 pi 进程（本任务不涉及）；`git push`（本地模式）。
  - 只读性：命令不写 state/、不动工作树（第 ① 组断言 main 的 HEAD 不变）。

## Flip evidence (required for defect-fix tasks)

**红 → 绿（同一份夹具，换实现）**：`/tmp/p91-before` = `49191c21` 的旧树（`git archive`，没有 `--post-merge`），
第 48 段从交付树抽出来跑（同一份夹具、同一段断言）：

```
$ bash <runner> /tmp/p91-before/skills/teamsmith         # 旧树
  ✗ P91 ①：合并后只动了记录 → 退出码 0（能当收尾核对）（期望 [0]，实际 [2]）
  ✗ P91 ①：说清是记录有更新（…p91-records.log 中找不到 [记录有更新]）
  ✗ P91 ②：合并后动了代码 → 非零退出（不能只取记录）（期望 [1]，实际 [2]）
  ✗ P91 ②：更响地点名代码必须重新合并（…找不到 [代码有未合并的改动 —— 不能只取记录，必须重新合并并重跑门禁]）
  ✗ P91 ④ 陈旧分支：只有记录晚到 → 退出码 0（期望 [0]，实际 [2]）
  …（旧树对 --post-merge 一律 rc 2「未知参数」）
== 结果 ==  ✓ 20  ✗ 32          （rc=1）

$ bash <runner> <交付树>/skills/teamsmith                # 交付树
== 结果 ==  ✓ 52  ✗ 0           （rc=0）
```

**反向（把检查删掉 → 断言红）** —— 段内第 ③ 组：探针把 `team_review_postmerge_paths` 影子成 `:`（「检查被删除」的形状），
同一份②夹具（分支上有一条晚到的代码提交）必须被静悄悄放过：

```
$ bash <probe> <skill> <repo> 0      # 同源、不影子
review P91 --post-merge：…（tip …）vs main（tip …）
✗ review P91 --post-merge：✗ 代码有未合并的改动 —— 不能只取记录，必须重新合并并重跑门禁：
      skills/x.sh
rc=1
$ bash <probe> <skill> <repo> 1      # 影子掉判定
review P91 --post-merge：分支 task/P91-smoke（tip …）vs main（tip …）
  已核对：没有合并后新增 —— 与 main 的差异共 0 个路径，…
rc=0
```

即：把这条检查删掉/影子掉，第 48 段的 5 条断言立刻红（上面那批 32 条红里就有它们）。原始日志见 `logs/`。

## Decisions and deviations

1. **判定按「路径归属」而不是裸 `main..branch`**（brief 写的是 `main..task/<分支>`，实现是它的**可执行化**）：
   main 上别的任务合进来后，`main..<分支>` 会把**别人的**工作当成「分支删掉了它们」。照字面报出来不只是假红，
   还会给出**有害**修法（`git checkout <分支> -- <别人的记录>` 等于把别人的记录删掉）。真仓库实测：
   P82 的陈旧分支有 91 个差异路径，其中 **89 个是 main 一侧**、1 个真晚到、1 个三路冲突。
   所以逐路径做三路比较（base = merge-base）：① 分支没动过 → main 一侧；② main 没动过 → 分支新增；
   ③ 两边都动过 → 比 blob 历史（main 的版本在分支历史里 = 分支新增；分支的版本在 main 历史里 = 它只是落后）；
   ④ 都判不出来 → 拿 **git 自己的三路合并**当裁判（== main → 不是它的；== 分支 → 分支新增；冲突/第三个结果 →
   报出来「版本对不上」让人看一眼）。这一步是**先有反假红断言（第 ④ 组）才敢加的**。
2. **多了一个「版本对不上（unclear）」出口**：既不能证明是分支新增、也不能证明它落后时，**报出来**（非零），
   不静默丢——晚到的改动撞上别人的改动（第 ⑥ 组）与陈旧分支的冲突都是这个形状。三路合并说清时不会走它
   （第 ④ 组那批陈旧分支噪音全被 ③ 吸收：4 个 unclear → 2 个，两个都是真要说的事）。
3. **做成了 `--post-merge` 而不是并进 `team close` 输出**（brief 两选一）：它有自己的退出码（记录 0 / 代码非零），
   与收尾语义分开更清楚，也和 `--pre-merge` 成对。
4. **删除型记录给的是 `git rm -f`**，不是 `git checkout`（分支删了这个路径时 checkout 会报 pathspec 不匹配）；
   列表里带 `[删除]` 标记。
5. **没动 `team help` 的 review 用法表**（`cmd-project.sh` 不在 grant 里）：先例是 `--pre-merge` 也不在那张表里
   （`team help` 只列到 `--allow-unresolved-branch`）。若 PM 想让两个旋钮出现，需要 grant `cmd-project.sh`（P82 的同类教训）。
6. **合并后仍留在工作树里、从未提交的记录不归这条命令管**（它只看分支 ref）：那是 digest（M31/P47）与
   `--pre-merge` 的地盘，两套检查合起来才是 D45+D49 的完整面。

## Suggested next steps

- 合并流程里用起来：合并后若还收到该 agent 的回合通知，先 `team review <ID> --post-merge`；记录 → 取它（打印的
  checkout/rm），代码 → 重新合并 + 重跑门禁。分支已被删除时它 rc 2（「没核对过」），不报假绿。
- 若接受把 `--pre-merge`/`--post-merge` 列进 `team help`，派一个带 `cmd-project.sh` grant 的小任务（见 Decisions 5）。
- D49 第 3 条（「建议 P76 的机制扩一条」）到此闭环：`--pre-merge`（合并前未入账）+ `--post-merge`（合并后新增）
  两面都在门禁里有夹具与反向断言。
