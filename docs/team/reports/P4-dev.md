# P4 · dev · apply report: change `launch-and-adapter-evidence` (C1 backfill)

```
task:   P4                        phase:  apply       deps:  P3 proposal ACCEPTED; D23 (C0 dropped)
agent:  dev                       status: DELIVERED   (rework 1 after the PM's FAIL on 52baebe)
branch: task/P4-apply-launch-and-adapter-evi          PR/MR: - (local mode, no remote)
```

> **All three gates are green on tip `b22736d`** (the code/spec tip; this report only adds `docs/team/reports/**`): `openspec validate --all --strict`
> `9 passed, 0 failed`; `bash skills/teamsmith/tests/spec-lint.sh` `OK — 11 spec file(s), 56 requirement(s),
> 115 scenario(s)`; `bash skills/teamsmith/tests/smoke.sh` **✓ 1331 ✗ 0** (2m39s, full mode). The first
> delivery (`52baebe`) shipped smoke red with two known lines and called it pre-existing — the PM authorized
> the fix (F6) and returned the task; §"Rework" below is the response.

## Rework (2026-09-15) — the PM's FAIL, item by item

The PM's verdict is in `docs/team/threads/dev.md` (13:48) and the FAIL record is `docs/team/reviews/P4.md`
(HEAD `52baebe`, gate `✓ 1317 ✗ 2`). The review ran on the pre-rework tip, and my rework was still in the
working tree while it ran; every item it lists is addressed below, on the new tip.

| Finding | PM ruling | What I changed | Commit |
|---|---|---|---|
| **F6** smoke §16 counts only `specs/` while the lint counts base **+ active deltas** → any active change red | **authorized to fix**: same scope as the lint + a clean-tree control | `sl_scope_files`/`sl_count` scope the expectation to `specs/*/spec.md` + active `changes/*/specs/**` (`changes/archive/` skipped), plus two controls (clean tree == specs-only; an added delta must be counted) | `368292f` |
| **F2** the new `--print` clause had no assertion for the non-`--print` half | **must add** (tests are mine) | `F15：项目外任务书被拒（不带 --print 同样拒绝）` + the error text + a tmux shim proving the refusal happens **before any window** + no success line | `368292f` |
| **F3** base scenario claimed `team status` shows the recorded worktree | **rewrite the scenario in this change's delta**, do not touch the base spec | the MODIFIED block now states the two observable halves; five smoke assertions pin them; `design.md` D2 declares the correction as the one allowed deletion | `443d972` + `368292f` |
| **F1** the migrated 100 KB / 100KB long-prompt scenario has no runnable falsifier | **record as a known limitation**; queue a follow-up; never delete or invent a checker | `design.md` Risks carries the limitation note; `ROADMAP.md` gets one queued row; 20-anchors asserts the note exists **and** the scenario is still there untouched | `443d972` + `75cf6de` |
| **F5** `tasks.md` 4.3's command fails as written on openspec 1.8.0 | accepted | already fixed in the first delivery (`ea37c72`) | `ea37c72` |
| P3 branch merged into the P4 branch | accepted (D16's apply-on-propose-tip convention) | — | `40991ab` |

Process note taken from the PM: the first delivery reported "DELIVERED" while gate 3 was red. This rework's
acceptance was run **on the final tip**, and the report's headline is derived from that run.

## What this task was

Execute `openspec/changes/launch-and-adapter-evidence/tasks.md` in order (1.1 → 4.4), verify every scenario's
named falsifier today, run the trial archive and the migration diff on a scratch copy, and report every place
where a scenario's claim does not match reality. `openspec/specs/**` was **not** touched; neither were code,
the ledger, or `references/openspec.md`.

## Where the artifacts came from (deviation 1 — the dispatch precondition)

P4's worktree was created from `main` (`git reflog`: `branch: Created from main`), but the change's artifacts
live only on `task/P3-propose-launch-and-adapter-e` — P3 is accepted and closed, but its branch is not in
`main`. The apply convention is that the apply branch stacks on the propose branch (`task/P2-…` was created on
`task/P1-…`), so I merged P3 into my branch (`40991ab`): conflict-free, adds P3's 9 paths, reverts nothing on
`main`, no push, no other branch touched.

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/launch-and-adapter-evidence/**` | the three deltas, verified; F3's correction; F1's limitation; `tasks.md` ticks + two broken commands fixed |
| `skills/teamsmith/tests/smoke.sh` | F6's scope fix + controls; F2's and F3's assertions (PM-authorized) |
| `docs/team/ROADMAP.md` | one queued row for F1's falsifier (PM's instruction; ROADMAP is PM-owned) |
| `docs/team/reports/P4-dev/pkg/{lib,run,10-gates,20-anchors,30-archive,40-migration,50-smoke,60-task-verify}.sh` | the reproducible evidence package (one command; `--slow` adds the full suite + mutant) |
| `docs/team/reports/P4-dev.md` | this report |

## Acceptance on the final tip (`b22736d`), verbatim

```console
$ openspec validate --all --strict
✓ spec/board-and-status … ✓ change/launch-and-adapter-evidence … ✓ spec/watchdog
Totals: 9 passed, 0 failed (9 items)                                    rc=0
   (openspec lives in ~/.bun/bin and is not on a non-login bash PATH; the package's lib.sh prepends it, so
    the command stays the literal one — a background shell without it exits 127)

$ bash skills/teamsmith/tests/spec-lint.sh
spec-lint: OK — 11 spec file(s), 56 requirement(s), 115 scenario(s) under openspec    rc=0
   (11 = 8 base + 3 delta; 56 = 45 + 11; 115 = 77 + 38 — the arithmetic proves the deltas are really linted)

$ bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1331  ✗ 0                                                  rc=0   (2m39s, full mode)
   (before the F6 rework, on 52baebe: ✓ 1317 ✗ 2 — the same command, the same tree shape)

$ git status --porcelain
(clean — the change directory, the smoke fix and this report are committed)

$ git diff --stat main...HEAD | tail -1
 20 files changed, 2270 insertions(+), 6 deletions(-)

# re-run on the tip this report is committed on (docs-only difference from b22736d; the machine was under
# load average 6.5 so the full suite took ~9 min instead of 2m39s):
$ openspec validate --all --strict | tail -1        → Totals: 9 passed, 0 failed (9 items)      rc=0
$ bash skills/teamsmith/tests/spec-lint.sh          → spec-lint: OK — 11 spec file(s), 56 requirement(s), 115 scenario(s)   rc=0
$ bash skills/teamsmith/tests/smoke.sh | tail -3    → == 结果 ==  ✓ 1331  ✗ 0                        rc=0
```

## Flip evidence (F6 — required for defect-fix work)

**Red before → green after**, same command, same tree shape (an active change), only the fix differs:

```console
# before (commit 52baebe): smoke §16 expected 45/77 from openspec/specs/*/spec.md, the lint reports 56/115
$ bash skills/teamsmith/tests/smoke.sh
  ✗ lint 报的 requirement 数与真树一致（45）（… 中找不到 [45 requirement(s)]）
  ✗ lint 报的 scenario 数与真树一致（77）（… 中找不到 [77 scenario(s)]）
== 结果 ==  ✓ 1317  ✗ 2                                                  rc=1
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1031  ✗ 2                                                  rc=1

# after (tip b22736d)
$ bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1331  ✗ 0                                                  rc=0
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1045  ✗ 0                                                  rc=0
```

**Break the fix → the guard must fail → restore it** (the mutant run in `pkg/50-smoke.sh`): clone the branch,
revert `sl_scope_files` to the specs-only scope, run the suite → the two rewritten assertions go red again
(`rc=1`, both lines carry `数与真树同口径`). Without this the green above could be a widened expectation that
can no longer fail. The same section keeps the pristine-`main` control green (`✓ 1033 ✗ 0`), so the check did
not become vacuous in the other direction either.

## The claim behind this change: every scenario has a falsifier that exists **today**

`20-anchors.sh` carries the requirement → scenario → falsifier map as **119** assertion labels, each grepped in
skills/teamsmith/tests/smoke.sh; a self-control anchor proves the lookup can report a miss. One scenario comes
back with no anchor (F1, the known limitation recorded in `design.md`); everything else resolves to a real
assertion — including the three scenarios the PM's verdict was about (F2/F3 now have anchors, F1 is documented
and verified as *still present*, not deleted):

| requirement | scenario | falsifier (assertion label in `smoke.sh`) | line | section |
|---|---|---|---|---|
| `A-brief-is-self-contained` | A generated brief carries the contract | `生成任务书` | 361 | 4 · task + board |
|  |  | `任务书含 agent 字段` | 362 | 4 · task + board |
|  |  | `任务书写入门禁命令` | 363 | 4 · task + board |
| `A-brief-is-self-contained` | The prompt points at the brief | `reports/T1.1-dev.md` | 532 | 6 · dispatch |
|  |  | `提示词指明报告路径` | 532 | 6 · dispatch |
| `A-brief-is-self-contained` | A brief outside the project is refused, --print included | `F15：项目外任务书被拒（--print 也不放行）` | 508 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
|  |  | `F15：报错说明任务书在项目外` | 509 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
|  |  | `F15：报错点名项目主工作树` | 510 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
|  |  | `F15：不再把项目外路径称作 repo-relative` | 511 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
|  |  | `F15：项目外任务书被拒（不带 --print 同样拒绝）` | 520 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
|  |  | `F15：不带 --print 的报错同样说明任务书在项目外` | 521 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
|  |  | `F15：拒绝发生在开窗之前（tmux 一次都没被要求建窗口）` | 522 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
|  |  | `F15：不带 --print 也没有真的派单` | 524 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
| `One-task-branch` | The branch identity is visible | `F3：roster 的 dev 行显示工作树当前的分支` | 489 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
|  |  | `F3：roster 的 dev 行显示记录下来的任务` | 493 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
|  |  | `F3：team status 打印的是同一份 roster 行` | 497 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
|  |  | `F3：team status 打印该任务的标题行` | 499 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
|  |  | `F3：team status 打印该任务的报告行` | 500 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
| `One-task-branch` | A dirty worktree blocks a branch switch | `脏工作树拒绝派单` | 457 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
|  |  | `说明 git 归 PM` | 458 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
| `One-task-branch` | A worktree parked on another task's branch is refused | `F16：工作树停在别的任务的分支上 → dispatch 拒绝` | 467 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
|  |  | `F16：报错点名了工作树当前的分支` | 468 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
|  |  | `F16：报错点名了本任务的规范分支` | 469 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
|  |  | `F16：给出 PM 该跑的 git switch 命令` | 470 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
|  |  | `F16：没有真的派单` | 471 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
|  |  | `F16：续跑同一个任务时允许旧 slug 的分支` | 478 | 3b · git 归 PM（skill 不执行、也不过度包装 git） |
| `D3-launch-proof` | A wedged window is a failure, not a success | `M4.3 B1：派单进楔死窗口 → 如实报失败` | 1186 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `B1：标题就是「未能确认启动」（不是成功）` | 1187 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `B1：按约定重试了一次` | 1189 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `B1：失败后的窗口终态 = 不存在` | 1194 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
| `D3-launch-proof` | A stale exit record is not this round's evidence | `M7.5 B4a：旧 nonce 的退出记录不算本轮证据` | 1208 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `B2：还在跑的 agent 不会被误报成已退出` | 1230 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
| `D3-launch-proof` | The exit code comes from the event file, not from the pane | `M4.3 B3：有启动证据 → 派单成立` | 1238 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `B3：agent 秒退被明确说出来` | 1241 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `B3：退出证据落盘（state/dispatch-dev.exit）` | 1245 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `B3：退出证据与本轮启动证据同一个 nonce` | 1247 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `B3：通知报出的是真实退出码（不是「大概退了」）` | 1246 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
| `D3-launch-proof` | An adapter that exits non-zero fails the dispatch with diagnostics | `M8.2：agent 秒退非 0 → 派单失败` | 1755 | 6j · worker adapter：裸名字解析 + agent 没跑起来必须响亮失败（M8.2） |
|  |  | `M8.2：失败文案报出真实退出码（exit=7）` | 1757 | 6j · worker adapter：裸名字解析 + agent 没跑起来必须响亮失败（M8.2） |
|  |  | `M8.2：失败文案给出诊断文件路径` | 1758 | 6j · worker adapter：裸名字解析 + agent 没跑起来必须响亮失败（M8.2） |
|  |  | `M8.2：失败的派单不写任务记录（roster 不会说它接过这个任务）` | 1759 | 6j · worker adapter：裸名字解析 + agent 没跑起来必须响亮失败（M8.2） |
|  |  | `M8.2：诊断里有 CLI 自己的报错（harness 自抓的尾屏）` | 1762 | 6j · worker adapter：裸名字解析 + agent 没跑起来必须响亮失败（M8.2） |
|  |  | `M8.2：诊断里有渲染出的命令（可手工复现）` | 1764 | 6j · worker adapter：裸名字解析 + agent 没跑起来必须响亮失败（M8.2） |
|  |  | `M8.2：诊断里有解析到的可执行文件` | 1765 | 6j · worker adapter：裸名字解析 + agent 没跑起来必须响亮失败（M8.2） |
| `D4-session-window` | A big session with a small-window model is refused | `M4.3 A1：大会话 + 小窗口模型被拒` | 1100 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `A1：报出选中模型的窗口（来自 Pi 模型目录，不是猜的）` | 1102 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `A1：说清 token 是粗糙估算（JSONL 字节 ÷ 4）` | 1103 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `A1：给出 --fresh 出路` | 1104 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `A1：给出显式放行的出路` | 1105 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `M4.3 A2：--print 也被拒` | 1111 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
| `D4-session-window` | A wider window may reuse the same session | `M4.3 A3：大窗口模型可以复用同一会话` | 1115 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
| `D4-session-window` | An unresolvable window falls back to the conservative threshold, and says so | `M4.3 A6：未知窗口按保守阈值拒绝` | 1134 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `A6：明说窗口解析不到` | 1135 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `A6：报出用的是保守阈值（不小于 200k）` | 1136 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
| `D4-session-window` | `--fresh` and `--allow-overflow` are the two explicit ways out | `M4.3 A4：--allow-overflow 显式放行` | 1121 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `A4：放行是醒目的警告（不是静默）` | 1123 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `M4.3 A5：--fresh 不受历史会话大小影响` | 1127 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `A5：--fresh 用带时间戳的新 session id` | 1129 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
| `D4-session-window` | `TEAM_MODEL_WINDOWS` overrides the catalogue | `M4.3 A7：TEAM_MODEL_WINDOWS 可显式覆盖窗口` | 1140 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
| `D4-session-window` | roster and ps show the estimate against the window | `A9：roster 显示已用/窗口并标出超窗` | 1151 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `A9：roster 说明会话数字的口径` | 1152 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
|  |  | `A9：ps 显示 dev 的会话大小` | 1155 | 6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B） |
| `A1a-template-engine` | An unknown placeholder fails with the supported set | `报错点名了写错的占位符` | 815 | 6f · agent adapter（任意 TUI agent）：渲染 / 占位符 / 文档契约 / 降级 |
|  |  | `报错列出支持的占位符` | 816 | 6f · agent adapter（任意 TUI agent）：渲染 / 占位符 / 文档契约 / 降级 |
|  |  | `报错指明了是哪个配置键` | 817 | 6f · agent adapter（任意 TUI agent）：渲染 / 占位符 / 文档契约 / 降级 |
| `A1a-template-engine` | A malformed placeholder is not silently passed through | `F4 占位符 { cwd }` | 951 | 6f · agent adapter（任意 TUI agent）：渲染 / 占位符 / 文档契约 / 降级 |
|  |  | `F4 占位符 {cwd'}'` | 954 | 6f · agent adapter（任意 TUI agent）：渲染 / 占位符 / 文档契约 / 降级 |
|  |  | `F4 占位符 {{cwd}}` | 953 | 6f · agent adapter（任意 TUI agent）：渲染 / 占位符 / 文档契约 / 降级 |
|  |  | `F4 占位符 {cwd'}` | 954 | 6f · agent adapter（任意 TUI agent）：渲染 / 占位符 / 文档契约 / 降级 |
| `A1a-template-engine` | A multi-line template cannot become a script | `F6：多行模板的第二行没有机会被窗口 shell 执行` | 957 | 6f · agent adapter（任意 TUI agent）：渲染 / 占位符 / 文档契约 / 降级 |
| `A1a-template-engine` | A long prompt does not enter the command line | **none — known limitation, see F1** | - | - |
| `A1b-first-word` | A bare first word is rendered as the absolute path from the caller's PATH | `M8.2：裸名字被换成调用者 PATH 解析出的绝对路径` | 1693 | 6j · worker adapter：裸名字解析 + agent 没跑起来必须响亮失败（M8.2） |
|  |  | `M8.2：渲染出的命令不再出现裸名字` | 1694 | 6j · worker adapter：裸名字解析 + agent 没跑起来必须响亮失败（M8.2） |
|  |  | `M8.2：裸名字的 CLI 真的在窗口里跑起来了（它自己的日志）` | 1741 | 6j · worker adapter：裸名字解析 + agent 没跑起来必须响亮失败（M8.2） |
|  |  | `M8.2 夹具有效：登录 bash 看不到` | 1685 | 6j · worker adapter：裸名字解析 + agent 没跑起来必须响亮失败（M8.2） |
|  |  | `M8.2 夹具有效：调用者 PATH 看得到它` | 1687 | 6j · worker adapter：裸名字解析 + agent 没跑起来必须响亮失败（M8.2） |
| `A1b-first-word` | An absolute first word, or one pinned to another binary, is left as written | `M8.2：已经是绝对路径的首词原样保留` | 1699 | 6j · worker adapter：裸名字解析 + agent 没跑起来必须响亮失败（M8.2） |
|  |  | `M8.2：TEAM_AGENT_BIN 指向别的名字时不改模板首词` | 1704 | 6j · worker adapter：裸名字解析 + agent 没跑起来必须响亮失败（M8.2） |
| `A2-pm-adapter` | The empty keys keep the built-in Pi launch path | `M8.1 默认渲染与历史逐字节一致（TEAM_PM_CMD/BIN/RESUME_ARGS 全空）` | 1325 | 6i · PM adapter（任意 TUI agent 当 PM）：默认不变 / 模板 / 存活 / 真窗口 |
|  |  | `默认仍是内置 Pi adapter（--print 标明）` | 717 | 6f · agent adapter（任意 TUI agent）：渲染 / 占位符 / 文档契约 / 降级 |
|  |  | `①b：这一轮真的用 -c 拉起 PM` | 2520 | 11b2 · PM 存活必须被证明（M6.5：空窗 ≠ PM 在运行） |
|  |  | `①b：这一轮真的用 @ 提示词文件拉起 PM` | 2521 | 11b2 · PM 存活必须被证明（M6.5：空窗 ≠ PM 在运行） |
| `A2-pm-adapter` | A malformed PM template fails before the window is respawned | `坏 PM 模板 → 直接失败` | 1398 | 6i · PM adapter（任意 TUI agent 当 PM）：默认不变 / 模板 / 存活 / 真窗口 |
|  |  | `报错点名了配置键` | 1410 | 6i · PM adapter（任意 TUI agent 当 PM）：默认不变 / 模板 / 存活 / 真窗口 |
|  |  | `报错列出支持的占位符（含 PM 专有键）` | 1411 | 6i · PM adapter（任意 TUI agent 当 PM）：默认不变 / 模板 / 存活 / 真窗口 |
|  |  | `多行 PM 模板的第二行没有机会被执行` | 1406 | 6i · PM adapter（任意 TUI agent 当 PM）：默认不变 / 模板 / 存活 / 真窗口 |
| `A2-pm-adapter` | An unresolvable PM CLI fails before the start | `不可解析的 PM CLI → 启动前失败` | 1437 | 6i · PM adapter（任意 TUI agent 当 PM）：默认不变 / 模板 / 存活 / 真窗口 |
|  |  | `报错说明了是哪个可执行文件` | 1438 | 6i · PM adapter（任意 TUI agent 当 PM）：默认不变 / 模板 / 存活 / 真窗口 |
|  |  | `报错指向 TEAM_PM_BIN` | 1439 | 6i · PM adapter（任意 TUI agent 当 PM）：默认不变 / 模板 / 存活 / 真窗口 |
| `A2-pm-adapter` | A custom PM CLI receives the briefing and runs in the main worktree | `非 Pi PM 被拉起` | 1469 | 6i · PM adapter（任意 TUI agent 当 PM）：默认不变 / 模板 / 存活 / 真窗口 |
|  |  | `提示词文件的内容真的交给它了（argv[0] 与文件同源）` | 1516 | 6i · PM adapter（任意 TUI agent 当 PM）：默认不变 / 模板 / 存活 / 真窗口 |
| `A2-pm-adapter` | An empty resume setting is reported as not continuing | `自定义 CLI + 空 resume 参数 → 明确报「不延续」` | 1444 | 6i · PM adapter（任意 TUI agent 当 PM）：默认不变 / 模板 / 存活 / 真窗口 |
|  |  | `resume 参数真的进了这一轮的 argv` | 1560 | 6i · PM adapter（任意 TUI agent 当 PM）：默认不变 / 模板 / 存活 / 真窗口 |
| `A2-pm-adapter` | A failed PM start leaves evidence and exits non-zero | `pm-launch-failed.log` | 1645 | 6i · PM adapter（任意 TUI agent 当 PM）：默认不变 / 模板 / 存活 / 真窗口 |
|  |  | `exit   : 7` | 1655 | 6i · PM adapter（任意 TUI agent 当 PM）：默认不变 / 模板 / 存活 / 真窗口 |
| `W1-liveness` | An empty window is not a running PM | `M6.5 ①：不再把 tmux 自己报成运行中的 PM` | 2495 | 11b2 · PM 存活必须被证明（M6.5：空窗 ≠ PM 在运行） |
|  |  | `M6.5 ①b：前台是 tmux 的窗口不算 PM` | 2509 | 11b2 · PM 存活必须被证明（M6.5：空窗 ≠ PM 在运行） |
|  |  | `M6.5 ①：假 agent 真的被拉起（argv 落盘）` | 2497 | 11b2 · PM 存活必须被证明（M6.5：空窗 ≠ PM 在运行） |
| `W1-liveness` | A recorded pid that has died is not a running PM | `M6.5 ②：记录的 pid 死了 → 不再算存活` | 2526 | 11b2 · PM 存活必须被证明（M6.5：空窗 ≠ PM 在运行） |
| `W1-liveness` | A non-PM occupant is not a running PM and does not suppress a start | `M6.5 ③：本项目里的非 PM 进程 → unknown:*` | 2537 | 11b2 · PM 存活必须被证明（M6.5：空窗 ≠ PM 在运行） |
|  |  | `M6.5 ③：非 PM 占用不压制启动（up 真的拉起 PM）` | 2545 | 11b2 · PM 存活必须被证明（M6.5：空窗 ≠ PM 在运行） |
| `W1-liveness` | A foreign occupant is refused, not overwritten | `M6.5 ④：up 明确拒绝覆盖外来进程` | 2565 | 11b2 · PM 存活必须被证明（M6.5：空窗 ≠ PM 在运行） |
| `W1-liveness` | A manually started PM, and a wrapper that `exec`d itself, are recognized | `M6.5 ④b：人工在窗口里启动的 agent 被认成 running` | 2570 | 11b2 · PM 存活必须被证明（M6.5：空窗 ≠ PM 在运行） |
|  |  | `F30：启动证据就是 spawn` | 2585 | 11b2 · PM 存活必须被证明（M6.5：空窗 ≠ PM 在运行） |
|  |  | `F30：别人放的 sleep 只是 unknown` | 2599 | 11b2 · PM 存活必须被证明（M6.5：空窗 ≠ PM 在运行） |
| `W1-liveness` | A read-only command does not clear the evidence | `只读命令零写入 state/（F28）` | 3449 | 12 · roster / status / ps |
|  |  | `读命令之后 state/ 一个字节没变（F28）` | 2845 | 11c · agent 续跑是 PM 的事（watchdog 不碰） |
| `W2-starting` | A second tick during a start does not start a second PM | `第二拍没有杀掉刚起来的 PM（pane 没换）` | 2679 | 11b3 · 启动中的 PM：一拍只拉起一次（M7.2） |
|  |  | `重启配额只记 1 次（一次启动一行）` | 2673 | 11b3 · 启动中的 PM：一拍只拉起一次（M7.2） |
|  |  | `PM 只被启动了一次（argv 里只有一个 @pm-prompt.md）` | 2677 | 11b3 · 启动中的 PM：一拍只拉起一次（M7.2） |
|  |  | `启动标记用完就撤` | 2680 | 11b3 · 启动中的 PM：一拍只拉起一次（M7.2） |
| `W2-starting` | A stale marker expires, a fresh one is reported as starting | `手动落下的启动标记 → team_pm_state 报 starting:*` | 2718 | 11b3 · 启动中的 PM：一拍只拉起一次（M7.2） |
|  |  | `启动中的一拍不吃配额` | 2736 | 11b3 · 启动中的 PM：一拍只拉起一次（M7.2） |
|  |  | `陈旧标记过期后不再报 starting:*` | 2745 | 11b3 · 启动中的 PM：一拍只拉起一次（M7.2） |
|  |  | `陈旧标记不阻塞拉起` | 2748 | 11b3 · 启动中的 PM：一拍只拉起一次（M7.2） |
| `W3-reload` | The reload text matches the mechanism | `F23：不再承诺 watchdog 会重启 PM 会话` | 3147 | 11h · 信号与承诺的诚实（V4.0 F4/F6/F19/F21/F23） |
|  |  | `F23：明说 marker 不会重启任何东西` | 3148 | 11h · 信号与承诺的诚实（V4.0 F4/F6/F19/F21/F23） |
|  |  | `F23：给出真正生效的方式（会话内 /reload）` | 3149 | 11h · 信号与承诺的诚实（V4.0 F4/F6/F19/F21/F23） |
|  |  | `F23：scripts/ 里除 cmd-update.sh 外没有组件读 marker` | 3151 | 11h · 信号与承诺的诚实（V4.0 F4/F6/F19/F21/F23） |
| `W3-reload` | `--done` clears the marker | `F23：reload --done 仍然能清掉 marker` | 3154 | 11h · 信号与承诺的诚实（V4.0 F4/F6/F19/F21/F23） |

## Findings — final state after the PM's rulings

| # | Finding | Ruling | State on this tip |
|---|---|---|---|
| **F1** | The migrated scenario `A long prompt does not enter the command line` (GIVEN a brief > 100 KB / 100KB) has no runnable falsifier: the byte-for-byte `argv[0]` comparison exists only on the PM side (`smoke.sh` §6i), no test anywhere uses a brief over 100 KB, no worker-side comparison exists | record as a **known limitation**, queue a follow-up, never delete the scenario or invent an unrunnable checker | **Recorded** — `design.md` Risks states the limitation and why the byte-identity rule (D1) forbids fixing it here; `ROADMAP.md` has one queued row ("C1 跟进（P4 finding F1）"); `20-anchors.sh` asserts both the note's presence and that the scenario is still there untouched. The anchor table shows `none — known limitation`. |
| **F2** | The new clause "the same command without `--print` exits non-zero before any window is opened" had no assertion | **must add** | **Fixed** (`368292f`): `F15：项目外任务书被拒（不带 --print 同样拒绝）`, the error text, `F15：拒绝发生在开窗之前（tmux 一次都没被要求建窗口）` (a per-invocation tmux shim records every call; window-creating verbs must be zero) and `F15：不带 --print 也没有真的派单`. Reality was already correct (`cmd-agents.sh:510-517` refuses before any window work) — the falsifier was the gap. |
| **F3** | `D1`'s restated base scenario claimed `team status <ID>` shows the recorded worktree; nothing does (`team status` prints the roster, the board row, the report path and the review record; the roster's branch column is the worktree's HEAD branch) | **rewrite the scenario in this change's delta** (base specs are archive's job) | **Fixed** (`443d972` + assertions in `368292f`): the MODIFIED block now states the two observable halves; `F3：roster 的 dev 行显示工作树当前的分支`, `…显示记录下来的任务`, `F3：team status 打印的是同一份 roster 行`, `…标题行`, `…报告行` pin them; `design.md` D2 declares it as the one allowed deletion; `pkg/40-migration.sh` fails on any deletion outside that scenario and verifies the *archived* spec carries the corrected text. |
| **F4** | `A2`'s clause "`team paths` reports the worker adapter as `built-in (Pi)`" is true but asserted only for custom adapters | (not ruled) | **Open, minor** — live check in this worktree: `"agent_adapter": "built-in (Pi)"`; the suite asserts the JSON key for a custom adapter (`smoke.sh:805`) and the built-in label from `dispatch --print` (`:686`). |
| **F5** | `tasks.md` 4.3's verbatim scratch-archive command fails on openspec 1.8.0 (`Change … not found. No active changes exist in this root.`); 4.2's extra C0-branch lint no longer exists | accepted (already fixed) | **Fixed** (`ea37c72`): the corrected command plus a note naming this finding; 4.2's C0 clause replaced with the D23 rationale. |
| **F6** | smoke §16 compared the lint's summary (base + active deltas) against counts from `openspec/specs/*/spec.md` alone → any active change red; the fix (C0 task 2.3) was dropped with C0 | **authorized to fix** (the legitimate successor of C0 2.3) | **Fixed** (`368292f`) with flip + mutant evidence (above). Full suite on this tip `✓ 1331 ✗ 0`. |

### Minor notes (recorded, no action taken)

- **N1** `D1`'s other restated base scenario ("A generated brief carries the contract") asserts the file, the
  agent field and the gate command, but not the "acceptance section" and "report path" clauses; the template does
  carry both.
- **N2** `A2`'s illustrative built-in argv writes `@.pi/team/state/pm-prompt.md` (relative) while the render and
  the real-window assertions use the absolute `@<root>/.pi/team/state/pm-prompt.md`.
- **N3** The proposal (`proposal.md`) was **not** edited for the F3 correction: `openspec/config.yaml:36` keeps
  proposals under 500 words and this one is at 495, so the correction is declared in `design.md` (the PM allowed
  "提案/设计").
- **N4** `smoke.sh:2894` prints `team_dim: command not found` when the `keep` window is absent: `team_dim` lives in
  `scripts/lib/common.sh`, not in the smoke, and this branch is only a skip note. Pre-existing (it is in the PM's own
  `reviews/P4-verify.log` and in every full run here), cosmetic, and it does not affect the exit code or the result
  line — but it is stray stderr in a gate log, so it is recorded rather than left to puzzle the next reader.

## Decisions and deviations

- **Merged P3's propose branch into the P4 branch** (deviation 1, above) — accepted by the PM.
- **Fixed two commands in `tasks.md`** and **ticked 1.1–3.3 + 4.1–4.4** after verifying each row's `Verify:` line
  in `60-task-verify.sh`; 4.5 (injection matrix) and 4.6 (archive) stay unticked — other phases own them.
- **Wrote one row in `docs/team/ROADMAP.md`** on the PM's explicit instruction in the thread (ROADMAP is
  PM-owned; nothing else in it was touched). The stale "C1 ⏸ 待 C0 收口" status line above it is the PM's to update.
- **Own guard tightened during the rework**: `pkg_del_lines` replaces `grep -c '^-[^-]'`, which silently
  undercounted deletions — a removed markdown list item appears in a `diff -u` as `-- **THEN** …` (diff marker
  plus the item's own dash). Found by probe while building the F3 allowance; noted here because a guard that
  undercounts is exactly the false green this change exists to kill.
- **Mutant runs use the working tree's test scripts** (copied into the clone) so the mutant mutates what is being
  delivered even if the package is run before committing; the pristine-`main` control uses the clone's own
  (pre-fix) suite, which is the point of that control.
- The `openspec` binary is not on a non-login bash PATH (`~/.bun/bin`); the package prepends it so the brief's
  commands run verbatim. A background run without it exits 127 (seen and re-run).
- **Untouched**: `openspec/specs/**`, all `scripts/**`, the ledger, `references/**` (the authorized paragraph in
  `references/openspec.md` was not needed), other agents' directories. 4.5's injection matrix is not mine to run.

## Verification evidence (the package, actually run)

```console
$ bash docs/team/reports/P4-dev/pkg/run.sh --slow
== 10 gates 结果 ==        ✓ 6   ✗ 0  ! 0  skip 1
== 20 anchors 结果 ==      ✓ 7   ✗ 0  ! 1  skip 0
== 60 task-verify 结果 ==  ✓ 25  ✗ 0  ! 0  skip 0
== 30 archive 结果 ==      ✓ 14  ✗ 0  ! 1  skip 0
== 40 migration 结果 ==    ✓ 9   ✗ 0  ! 0  skip 0
== 50 smoke 结果 ==        ✓ 7   ✗ 0  ! 0  skip 0
### repository untouched
  ok      openspec/ + smoke.sh fingerprints identical before and after the package
== 结果 ==  ✓ 69  ✗ 0  ! 2  skip 1
```

The two remaining `!` lines are observations, not failures: tasks 4.3's verbatim command defect (F5, fixed in
the task file and reported) and F1's known limitation. `30-archive.sh` also confirms the archive promise on a
scratch copy — `Totals: + 8, ~ 2, - 1, → 0`, `dispatch` update + `agent-adapters`/`pm-lifecycle` create, real
`## Purpose` on both (no `TBD`), the archived tree validates (`10 passed`), and the repository's `openspec/`
fingerprint is unchanged. `40-migration.sh` confirms the moved block is byte-identical base ↔ delta ↔ archived
and that both MODIFIED blocks keep every base scenario.

## Suggested next steps

1. PM re-verify this tip (`team review P4 --strong`) — all three gates are green here, and `pkg/50-smoke.sh`
   reproduces the flip plus the mutant on demand.
2. Independent verify phase (task 4.5): the injection matrix, run by a **different** agent; `pkg/20-anchors.sh`
   and `pkg/40-migration.sh` are the nets it should mutate.
3. Archive (4.6) only after that verification and the user's confirmation.
4. Optional dispositions: F4 (one assertion) and N1/N2 (cosmetic) belong to a later change; F1's falsifier is
   queued in `ROADMAP.md`.
