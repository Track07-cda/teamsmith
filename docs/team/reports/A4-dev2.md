# A4 · 归档 panel-symlink-inside-project

agent: dev2   status: PASS（原生归档完成，任务书验收 5/5 通过）   time: 2026-11-10T10:54:33Z
branch: `task/A4-archive-panel-symlink`   PR/MR: -（local 模式，分支留本地）

## 结论

已在私有副本试归档并检查，再在任务分支执行同一条 `openspec archive -y panel-symlink-inside-project`。
生成 `openspec/changes/archive/2026-11-10-panel-symlink-inside-project/`，三份 change 文件均为 100% 内容不变的移动，
正式 `panel` 规格同步 1 条 MODIFIED Requirement；tasks 为 6/6，既有 Purpose 逐字保留。归档提交为 `f5021422`。

前置 `team change status` 只有 A4 自身的 archive 阻塞，V145 已 done。V145 在 merged SHA `d5a65d53` 的最终结论为
PASS（选段 ✓426/0、CRITICAL 0、WARNING 0），本任务没有把这段引用证据当成本轮重新执行的产品测试。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/archive/2026-11-10-panel-symlink-inside-project/proposal.md` | 从活动 change 100% 移入归档 |
| `openspec/changes/archive/2026-11-10-panel-symlink-inside-project/specs/panel/spec.md` | 从活动 change 100% 移入归档 |
| `openspec/changes/archive/2026-11-10-panel-symlink-inside-project/tasks.md` | 从活动 change 100% 移入归档；6 项全勾、0 项未勾 |
| `openspec/specs/panel/spec.md` | 原生 archive 同步 panel 的 MODIFIED Requirement 与场景；Purpose 未改 |
| `docs/team/reports/A4-dev2.md` | 本报告 |

归档提交的文件集仅为上述四个 OpenSpec 路径：

```
R100  openspec/changes/panel-symlink-inside-project/proposal.md
      -> openspec/changes/archive/2026-11-10-panel-symlink-inside-project/proposal.md
R100  openspec/changes/panel-symlink-inside-project/specs/panel/spec.md
      -> openspec/changes/archive/2026-11-10-panel-symlink-inside-project/specs/panel/spec.md
R100  openspec/changes/panel-symlink-inside-project/tasks.md
      -> openspec/changes/archive/2026-11-10-panel-symlink-inside-project/tasks.md
M     openspec/specs/panel/spec.md
```

## OpenSpec assessment

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 6/6 | 归档副本 tasks 为 `tasks_checked=6 tasks_unchecked=0`；三份规划文件均 R100，活动目录已消失 |
| Correctness | Archive checks PASS | 私有试归档与真实归档均成功；任务书五条验收命令全部 rc=0；产品行为的 merged-SHA 证据引用 V145，不在本轮重跑 |
| Coherence | 1 capability | 原生工具只更新 `panel`；Purpose 前后相同，没有手改 delta、正式规格或 Purpose，没有其它 change 被归档 |

## CRITICAL

- None。前置无其它 blocker，归档副本无未勾任务，结构与引用检查均通过。

## WARNING

- None（本归档新增）。`openspec validate --all` 为 20 passed / 0 failed；输出中的长需求和既有 Purpose 提示是非 strict 警告，未导致失败。V145 对实现的结论也是 WARNING 0。

## SUGGESTION

- 保留 V145 的一条非阻塞建议：详情文件在发现之后、读取之前被并发替换成 FIFO/设备等非普通文件时，可能返回空正文而不点名类型。该项已在 `docs/team/OPEN-ITEMS.md` 登记，按任务书留待后续单独修复；本次没有改产品代码。

## Final assessment

- Counts: CRITICAL 0 · WARNING 0 · SUGGESTION 1（既有、非阻塞、已登记）。
- Readiness: 原生归档和本任务验收已完成，分支可交 PM 审阅、合并与关闭；未合并、未推送。
- Unverified applicable checks and reasons: 本归档任务未跑全量/夜间/61b smoke，未重跑 V145 的详情行为探针与 `--select 28`，也未运行全量 `--strict`。这些不属于 A4 的验收清单；V145 已明确其产品选段覆盖范围及全量 strict 的既有长需求失败，本报告不把它们说成已通过。

## Verification evidence

### 1) 归档前置

```
$ bash skills/teamsmith/scripts/team change status panel-symlink-inside-project
change panel-symlink-inside-project · not ready
  tasks
    A4      archive  dev2      wip     未合并（分支没有自己的改动）……
    V145    opsx-verify dev3      done    docs/team/V145.md: PASS
  blockers
    A4 · archive · wip · …… ① 复验记录不存在；② 报告未提交；③ 归档目录不存在
[rc=1；仅 A4 自身 archive 阻塞，符合任务书前置]
```

merged SHA 包含关系也在真实归档前执行了 `git merge-base --is-ancestor d5a65d53 HEAD`，rc=0。

### 2) `/var/tmp` 私有副本试归档

私有根由 `mktemp -d -p /var/tmp teamsmith-a4-archive.XXXXXX` 创建，仅复制 `openspec/`；检查完成后只删除该私有根
`/var/tmp/teamsmith-a4-archive.kMNrXk`。

```
$ openspec archive -y panel-symlink-inside-project
Task status: ✓ Complete
Specs to update:
  panel: update
⚠️  Warning: panel - delta Purpose ignored; panel already has one.
Applying changes to openspec/specs/panel/spec.md:
  ~ 1 modified
Totals: + 0, ~ 1, - 0, → 0
Specs updated successfully.
Change 'panel-symlink-inside-project' archived as '2026-11-10-panel-symlink-inside-project'.

archive_dir=…/openspec/changes/archive/2026-11-10-panel-symlink-inside-project
tasks_checked=6 tasks_unchecked=0
$ openspec validate --all
Totals: 20 passed, 0 failed (20 items)
[rc=0]
```

检查了正式规格的完整 diff：只同步目标 Requirement 的软链/非普通文件合同及场景，并调整相邻空行。
Purpose 前后的前 3 行相同；工具的 `delta Purpose ignored` 提示是保留既有 Purpose 的预期行为，没有另行手改。

### 3) 任务分支真实归档

```
$ openspec archive -y panel-symlink-inside-project
Task status: ✓ Complete
Specs to update:
  panel: update
Applying changes to openspec/specs/panel/spec.md:
  ~ 1 modified
Totals: + 0, ~ 1, - 0, → 0
Specs updated successfully.
Change 'panel-symlink-inside-project' archived as '2026-11-10-panel-symlink-inside-project'.

archive_dir=openspec/changes/archive/2026-11-10-panel-symlink-inside-project
tasks_checked=6 tasks_unchecked=0
[rc=0]
```

### 4) 任务书验收命令

非交互 shell 仅在调用层补了 `PATH="$HOME/.bun/bin:$PATH"` 以解析已安装的 `openspec`；验收命令本身未改。

```
$ openspec validate --all
✓ spec/panel
✓ spec/writing-discipline
Totals: 20 passed, 0 failed (20 items)
[rc=0]

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14088 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
[rc=0]

$ bash skills/teamsmith/tests/section-select.sh --check
ok: 分片是地板的精确划分（N=2 3 4 5 6 8 12：129 段，每片非空、无重复、无遗漏）
ok: 表里每一行的 key 都能被哈希（139 个 key × 7 个 N 都在 0..N-1 内）
ok: 两阶段是全部段的精确划分（一阶 133 + 二阶 6 = 表 139 行；二阶每段有理由、都是 gate-self-check 段）
== 选段自检 ==  ok 13  bad 0  SKIP 1
[rc=0；SKIP 1 是 internal 检出没有机器生成的 .pi/skills，未把跳过说成检查过]

$ git diff --check
[无输出，rc=0；在归档提交前对真实归档 diff 执行]
```

- Verdict: PASS。上述命令均在本 worktree 实际执行；完整原始输出在写作时保存于 `/var/tmp/teamsmith-a4-acceptance.wGNfD9/`。
- Notes: 选段自检的 1 个 SKIP 有明确检出前提；没有全量 smoke 或全量 strict 的通过声明。

- Ledger ban（报告写入后在本 worktree 再跑）：

  ```
  $ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  ledger-ban: names：名单已配置（/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.git/../.pi/team/forbidden-names.txt，命中即红）
  ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev2 scope=published files=2589 hits=0 names=ok user=resolved
  $ echo $?
  0
  ```

## Flip evidence

N/A — 本任务是原生 OpenSpec 归档，不是缺陷修复；没有改实现，因此没有伪造红绿翻转。实现的红侧与 merged-SHA 复验见 V145 报告。

## Decisions and deviations

- None。未手改 delta、正式规格或 Purpose；未归档其它 change；未修复 OPEN-ITEMS 中的建议项；未合并、未推送。

## Suggested next steps

- PM 审阅 `f5021422` 及本报告后按本地流程整合并关闭 A4；详情读取窄竞态继续由 OPEN-ITEMS 单独跟踪，不随本次归档改产品。
