# A18 · 同步已验证的 Pulse 看板更新时间排序要求

agent: dev2   status: delivered   time: 2026-11-25T11:41:49Z
branch: `task/A18-archive-pulse-board-recent-first`   PR/MR: -

**归档范围内已交付。** OpenSpec 1.16.0 原生 `archive -y` 只执行一次，归档为 `2026-11-25-pulse-board-recent-first`；实际五份工件全部 R100，正式规格只同步 `board-and-status` 两条和 `panel` 一条 MODIFIED requirement。普通 validate 21/21、spec-refs、差异与账本隐私检查均退出 0。产品行为沿用任务书点名的 V200 组合证据，本单没有重跑产品行为。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/archive/2026-11-25-pulse-board-recent-first/` | 原生一次归档；磁盘实际五份工件与入档前 Git 对象逐字节相同 |
| `openspec/specs/board-and-status/spec.md` | 只更新 delta 点名的两条 requirement；其它非空正文和全部 requirement 顺序不变 |
| `openspec/specs/panel/spec.md` | 只更新看板页一条 requirement；其它非空正文和全部 requirement 顺序不变 |
| `docs/team/reports/A18-dev2.md` | 本报告、字节对照及实际命令回执 |

归档提交：`d22f90acbd17be8c87d62795c5e974d691a3e32f`（`docs(panel): archive recent-first board ordering (A18)`）。报告另作小步提交；不推送、不合并。

## OpenSpec assessment

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 5/5 | 原生 `status` 的 proposal/specs/design/tasks 全部 done；`list --json` 唯一匹配本 change，completedTasks/totalTasks = 7/7；原生归档报告 `~ 3 modified` |
| Correctness | PASS（归档范围） | 五份实际工件全部 R100；三条目标的非空内容与已接受 delta 完全一致，场景名称和顺序不变；普通 validate 21 passed / 0 failed、spec-refs 122 条均 rc=0 |
| Coherence | PASS（归档范围） | 两份正式规格的 requirement 集合与次序不变，目标外非空正文不变；Purpose 非空文本不变。原生工具另有五处 LF 空行变化，逐处列在下文，没有手工修齐 |

## CRITICAL

- None。

## WARNING

- None（归档范围）。普通 `openspec validate --all` 仍打印 223 条长 requirement 警告和 1 条 `seat-visibility` 的既有 Purpose 占位警告；命令最终为 21 passed / 0 failed、rc=0。本单不把这些旧警告写成新失败，也不声称 strict 已通过。

## SUGGESTION

- None。

## Final assessment

- Counts: CRITICAL 0 · WARNING 0 · SUGGESTION 0。
- Readiness: 归档同步和本报告列出的静态检查范围内可交付。
- Unverified applicable checks and reasons: 按任务书明确不跑 strict 全仓、应用、真实任务写入、产品/模型/发布、全量 smoke 或已接受的行为测试；这些项目本轮未执行，不记为通过。V200 的首轮 FAIL、返修 PASS 和 merged 短核边界均保留，未改写成同一提交完整重跑。

## Verification evidence (must have actually been run)

以下 OpenSpec 命令均在同一 shell 环境中先执行：

```
$ export PATH="<home>/.bun/bin:$PATH" OPENSPEC_TELEMETRY=0
$ openspec --version
1.16.0
```

### 分支、root、工件和 7/7

```
$ git branch --show-current
task/A18-archive-pulse-board-recent-first
$ git status --porcelain=v1
[无输出，rc=0]

$ openspec list --json
root.path=<home>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev2
root.source=nearest
change matches=1
completedTasks/totalTasks=7/7

$ openspec status --change pulse-board-recent-first --json
schemaName=spec-driven
proposal=done
specs=done
design=done
tasks=done
specs.existingOutputPaths=[
  .../specs/board-and-status/spec.md,
  .../specs/panel/spec.md
]
```

`team change status pulse-board-recent-first` 的归档前输出中 P501、P502、P503、V199、V200 都是 done；唯一任务 blocker 是本 A18 自己尚为 wip、尚无报告和归档目录。该命令按预期 rc=1，没有被当作产品失败。

### 唯一一次正式原生归档

```
$ date -u +%Y-%m-%dT%H:%M:%SZ
2026-11-25T11:37:39Z
$ openspec archive -y pulse-board-recent-first
Task status: ✓ Complete

Specs to update:
  board-and-status: update
  panel: update
Applying changes to openspec/specs/board-and-status/spec.md:
  ~ 2 modified
Applying changes to openspec/specs/panel/spec.md:
  ~ 1 modified
Totals: + 0, ~ 3, - 0, → 0
Specs updated successfully.
Change 'pulse-board-recent-first' archived as '2026-11-25-pulse-board-recent-first'.
archive rc=0
```

没有手工同步或移动、硬链接、跳过参数、试归档或第二次正式归档。

### 工件 Git 对象与 R100 对照

入档前逐个执行 `git rev-parse HEAD:<active-path>`，入档后对归档文件执行 `git hash-object`；五对结果完全相同：

```
562a97efaae77354c303fb995b80a2135b8a0f24  design.md
3df7d4269d0e9e6cdd47e17fe5c49ab76201ff30  proposal.md
9dde465fcae0453c25ea97ba6104090e00787401  specs/board-and-status/spec.md
56f83e1eec250f4122dd91bf15337817c38f5624  specs/panel/spec.md
887da7aff57ba9a9afb58819bbaf45ed54448def  tasks.md
```

暂存后实际 `git diff --cached --name-status`：

```
R100  openspec/changes/pulse-board-recent-first/design.md
      → openspec/changes/archive/2026-11-25-pulse-board-recent-first/design.md
R100  openspec/changes/pulse-board-recent-first/proposal.md
      → openspec/changes/archive/2026-11-25-pulse-board-recent-first/proposal.md
R100  openspec/changes/pulse-board-recent-first/specs/board-and-status/spec.md
      → openspec/changes/archive/2026-11-25-pulse-board-recent-first/specs/board-and-status/spec.md
R100  openspec/changes/pulse-board-recent-first/specs/panel/spec.md
      → openspec/changes/archive/2026-11-25-pulse-board-recent-first/specs/panel/spec.md
R100  openspec/changes/pulse-board-recent-first/tasks.md
      → openspec/changes/archive/2026-11-25-pulse-board-recent-first/tasks.md
M  openspec/specs/board-and-status/spec.md
M  openspec/specs/panel/spec.md
```

任务书写“六份规划”，但原生 `status`、`find` 和归档结果都只有 proposal、design、tasks 与两份 delta，共五份；目录没有 `.openspec.yaml`。本单按真实五份原样入档，没有创建第六份或改动任务书。

### 正式规格目标范围与空行字节

比较方法：从入档前副本按 `### Requirement:` 分块，仅以归档 delta 替换三条目标，生成期望文件；再与实际结果逐行、逐字节比较。结果为：

```
board-and-status: 目标 2 条非空内容 exact；其它 requirement 非空内容 exact；requirement/scenario 顺序 exact
panel:            目标 1 条非空内容 exact；其它 requirement 非空内容 exact；requirement/scenario 顺序 exact
Purpose/prefix:   两份非空文本 exact
```

除下列五次 LF 空行操作外，实际结果与“仅替换目标块”的期望文件逐字节相同。行号以该对照的期望文件或实际新文件为准；每处字节均为换行 `0a`，没有空格或其它字符变化：

| 正式规格 | 原生格式差异 | 字节 |
|---|---|---|
| `board-and-status` | 在新文件第 8 行插入一个空行 | 新增 `0a` |
| `board-and-status` | 在新文件第 10 行插入一个空行 | 新增 `0a` |
| `board-and-status` | 在新文件第 244 行插入一个空行 | 新增 `0a` |
| `board-and-status` | 删除期望文件第 400 行的空行；新文件对应边界为第 403 行前 | 删除 `0a` |
| `panel` | 在新文件第 1090 行插入一个空行 | 新增 `0a` |

对照哈希：

```
board-and-status expected=c7489bc4f4e6a3c08a5da4af974157396b58dbadbf5afecfab039550eccb8a01
board-and-status actual  =a1678f6410fae9d4a95e6e0c13a53d33da3745aa2cc82d8689add45e0cd4769f
panel            expected=03897161923de840f17890f43449b6621ab72c6990f4d62af1acf5b56f45801f
panel            actual  =96f59c06a7ff8a77a93047ff792e5f5a98706fc91f14f35d27547c7ca2afe30e
```

这些变化保留为原生结果，没有手改归档文件或正式规格。原始机器输出保存在 `/var/tmp/a18-pulse-board-archive.tG5RT1/` 下的 `git-objects-before.tsv`、`native-format-delta.txt`、`blank-line-audit.txt` 和命令日志。

### 归档后普通校验

```
$ openspec validate --all
✓ spec/board-and-status
✓ spec/panel
…
Totals: 21 passed, 0 failed (21 items)
rc=0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14594 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0

$ git diff --check
[无输出]
rc=0

$ git diff --cached --check
[归档暂存时无输出]
rc=0
```

普通 validate 的 224 条 warning 分布为 223 条 requirement 长度提示和 1 条既有 Purpose 占位提示；没有 error。完整输出保存在上述临时根的 `validate.log`，报告不以省略号冒充它们不存在。

### 差异与隐私检查

```
$ TMPDIR=/var/tmp bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.git/../.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev2 scope=published files=3112 hits=0 names=ok user=resolved
$ echo $?
0
```

- Verdict: pass（以最终报告加入本分支树后的实跑回执为准）。
- Notes: 只声明归档同步与上述静态检查；未运行项已在 Final assessment 列明。
- Ledger ban: 在本人 worktree、本人分支树上运行；最终 `files`、`hits` 和 rc 见上方真实回执。

## Flip evidence

N/A — 本单是已验收变更的归档同步，不是缺陷修复。V200 已有的正常、反转、恢复三帧证据保持原记录，本单没有重跑或复制成新证据。

## Decisions and deviations

- 任务书预计六份工件，实际只有五份且没有 `.openspec.yaml`；按真实文件集归档，五份均 R100，未补造文件。
- 原生工具产生上列五处空行变化；目标外非空正文、Purpose 非空文本、要求与场景顺序均未变，未为格式另行修改。
- 没有改代码、测试、项目看板、任务书、暂停的 `task-labels` 草案、现场或运行中的 Pulse；没有更新真实任务状态。

## Suggested next steps

- PM 复验本分支的归档对象、目标范围和静态回执后按 local 模式合并；不推送、不发布。临时证据根留给 PM 收存，本席位不提前清理。
