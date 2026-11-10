# A1 · 归档 route-page-check-determinism

agent: dev2   status: BLOCKED（归档已提交；基线既有账本禁令命中使验收 rc=1）   time: 2026-11-10T05:19:29Z
branch: `task/A1-archive-route-page`   PR/MR: -

## 结论

归档已在私有副本试跑成功，并在本任务分支真实执行：活动 change 已移入
`openspec/changes/archive/2026-11-10-route-page-check-determinism/`，`dispatch` 与 `verification`
正式规格各同步 1 个 MODIFIED requirement，归档任务清单保持 **8/8**。归档提交为 `7110f167`。

`openspec validate --all`、`spec-refs.sh --check`、`section-select.sh --check` 与 `git diff --check` 均通过。
**BLOCKED:** `ledger-ban.sh --names-file <主检出名单>` 返回 1，报告 13 处 `[home]` 命中；对未修改的
HEAD `1c92d960` 独立导出树运行同一检查也得到相同 13 处与 rc=1。命中全部位于本任务未改的
`docs/team/PROTOCOL.md`（11 处）和 `docs/team/reviews/P439.md`（2 处）。这些文件归 PM，未越权修改；
需 PM 修复基线或明确处置后再接收本任务。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/archive/2026-11-10-route-page-check-determinism/` | 六个原始工件由活动目录移入；逐字节相同，含 8/8 tasks |
| `openspec/specs/dispatch/spec.md` | OpenSpec 自动同步 **The printed route is a route that works** |
| `openspec/specs/verification/spec.md` | OpenSpec 自动同步 **A gate that cannot judge says so** |
| `docs/team/reports/A1-dev2.md` | 本报告 |

实际归档移动的文件为 `.openspec.yaml`、`design.md`、`proposal.md`、`tasks.md`、
`specs/dispatch/spec.md`、`specs/verification/spec.md`；暂存时六项均识别为 100% rename。
未手改 delta、正式规格或 Purpose，未归档 reply-observer、delegate 或 panel，未合并、未推送。

## OpenSpec assessment

本任务是 archive，不替代 V136 的非作者最终验证；下表只评本次归档操作及其直接证据。

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 8/8 | `openspec instructions apply` 为 `state=all_done`；归档 tasks 为 8 done / 0 open |
| Correctness | 2/2 | 两个 MODIFIED requirement 均由归档命令写入正式规格；`validate --all` 为 23/23 |
| Coherence | 6/6 | 六个归档工件与 HEAD 原文件逐字节相同；真实归档与私有试归档结果一致 |

## CRITICAL

- 本次归档内容未发现 CRITICAL。总体交付阻塞见 WARNING 1 与文末 `BLOCKED:`。

## WARNING

1. **基线账本禁令未通过。** 当前树与未修改 HEAD 都是 13 hits / rc=1；不是本次归档引入，但它是任务书
   指定的验收命令，因此不声称 A1 全部验收通过。需 PM 处理 `docs/team/PROTOCOL.md` 与
   `docs/team/reviews/P439.md` 的既有绝对家目录文本，或记录明确处置。

### V136 既有 WARNING 的处置

任务书已记录 PM 接受 V136 WARNING：未按字面跑改前/改后 FAST，采用真实走查 255 行清单一致及受影响
文件相同作为等价证据。本归档没有补跑这两次 FAST，也不声称其它段的通过数已本轮实测或全覆盖。
V136 的计数建议一并落实记录：旧④/⑪/⑬各一条父级 `ok` 合并为新父级一条，父级计数 **−2**；嵌套
`pages` 的 ✓7 不计入父级。

## SUGGESTION

- None.

## Final assessment

- Counts: CRITICAL 0 · WARNING 1 · SUGGESTION 0。
- Readiness: 归档内容已完成且结构检查通过；A1 总体仍被上述既有账本检查阻塞，不能标为完整交付。
- Unverified applicable checks and reasons: 本归档任务未跑全量 smoke、完整 51m/flips、36、61b、公开 CI、
  `openspec validate --all --strict`；任务书未要求。V136 的 FAST 改前/改后字面对照按上述 PM 决定接受，
  没有在本轮伪造为已执行。实现行为证据沿用 P430、V132、V136，本轮未重跑 routes 行为套件。

## Verification evidence (must have actually been run)

OpenSpec 命令使用实际运行环境：

```bash
export PATH="$HOME/.bun/bin:$PATH" OPENSPEC_TELEMETRY=0
$ openspec --version
1.16.0
```

### 前置与私有副本试归档

`team change status route-page-check-determinism` 列出 P429、P430、V130、V131、V132、V136 全为 done；
唯一未完成项是 A1 自身。`openspec instructions apply --change route-page-check-determinism --json`
返回 `total: 8, complete: 8, remaining: 0`、`state: all_done`。

在 `/var/tmp/A1-route-page-archive.RRjLMG` 复制 `openspec/` 后运行：

```bash
$ openspec archive -y route-page-check-determinism
Task status: ✓ Complete
Specs to update:
  dispatch: update
  verification: update
Totals: + 0, ~ 2, - 0, → 0
Specs updated successfully.
Change 'route-page-check-determinism' archived as '2026-11-10-route-page-check-determinism'.
$ openspec validate --all
Totals: 23 passed, 0 failed (23 items)
```

试归档活动 change 消失、归档目录与两个同步 requirement 均存在。只清理了该确切私有目录，真树此时未改。

### 真实归档与同步检查

```bash
$ openspec archive -y route-page-check-determinism
Task status: ✓ Complete
Specs to update:
  dispatch: update
  verification: update
Applying changes to openspec/specs/dispatch/spec.md:
  ~ 1 modified
Applying changes to openspec/specs/verification/spec.md:
  ~ 1 modified
Totals: + 0, ~ 2, - 0, → 0
Specs updated successfully.
Change 'route-page-check-determinism' archived as '2026-11-10-route-page-check-determinism'.

$ # 六个工件逐一以 git show HEAD:<活动路径> | cmp - <归档路径> 比较
archived_files_byte_identical=6 active_change_absent=yes
tasks_done=8 tasks_open=0
```

正式规格中可定位到两个目标 requirement，以及新场景
`The replacement controls still catch real renderer defects` 与
`Route-page replacement evidence does not manufacture the old pass total`。

### 任务书验收命令

```bash
$ openspec validate --all
Totals: 23 passed, 0 failed (23 items)
$ echo $?
0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14084 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
$ echo $?
0

$ bash skills/teamsmith/tests/section-select.sh --check
ok: 分片是地板的精确划分（N=2 3 4 5 6 8 12：129 段，每片非空、无重复、无遗漏）
ok: 两阶段是全部段的精确划分（一阶 133 + 二阶 6 = 表 139 行；二阶每段有理由、都是 gate-self-check 段）
== 选段自检 ==  ok 13  bad 0  SKIP 1
$ echo $?
0

$ git diff --check
$ echo $?
0
```

- Verdict: 上述四项 pass；账本禁令 fail，见下。
- Notes: `section-select` 的 1 个 SKIP 是 `.pi/skills` 机器生成面在当前 internal 检出不存在，工具明确
  计入 SKIP 而非 pass；本任务没有把它改写成通过。

Ledger ban（在自己的 worktree、本分支树运行；主检出名单）：

```bash
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
docs/team/PROTOCOL.md:5: [home] > `bash <home>/Documents/syncthing/Work/Projects/pm-skills/skills/teamsmith/scripts/team help`
…
docs/team/reviews/P439.md:17: [home] - agent 报告：`<home>/Documents/syncthing/Work/Projects/pm-skills/docs/team/reports/P439-dev3.md`
ledger-ban: root=<worktree> scope=published files=2559 hits=13 names=ok user=resolved
$ echo $?
1
```

这是报告写入后的复跑结果；输出没有 `docs/team/reports/A1-dev2.md`，即本报告新增 hits=0，既有总数仍为 13。
报告写入后的 `git diff --check` 与暂存内容检查均为 rc=0。

基线归属实测（`git archive HEAD` 到 `/var/tmp` 私有目录，随后只清理该目录）：

```bash
$ bash skills/teamsmith/tests/ledger-ban.sh --root <未修改HEAD导出树> --names-file <主检出名单>
ledger-ban: root=<baseline> scope=published files=2558 hits=13 names=ok user=resolved
$ echo $?
1
```

基线提交 `1c92d960` 与 main 之间仅有 `docs/team/BOARD.md` 的一行看板差异，没有账本禁令修复可接回。
本任务不改上述两个 PM 所有文件。

## Flip evidence

N/A — 本任务是归档，不是缺陷修复；未新增产品检查或翻转测试。实现及诊断特异性翻转证据见
P430、V132、V136，本归档未重跑。

## Decisions and deviations

- 真实归档内容与任务书一致；没有手动同步规格或编辑任务勾选。
- 因基线既有账本禁令 rc=1，本报告标 `BLOCKED`，不将其它检查通过包装成整单通过。

## Suggested next steps

- **BLOCKED:** PM 需处理 `docs/team/PROTOCOL.md` 的 11 处与 `docs/team/reviews/P439.md` 的 2 处既有
  `[home]` 命中，或明确记录对该基线失败的验收处置；随后在本分支复跑账本检查并接收归档。
- 归档提交 `7110f167` 保留在本地任务分支；未合并、未推送。后序 reply-observer、delegate、panel
  归档仍按任务书等待本结果合并后再开始。
