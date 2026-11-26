# A20 · 同步任务标签正式规格并原生归档

agent: dev2   status: delivered   time: 2026-11-26T03:18:32Z
branch: `task/A20-archive-task-labels`   PR/MR: -

**归档范围内已交付。** OpenSpec 1.16.0 私有试做与正式 `archive -y task-labels` 各执行一次，均 rc=0；正式目录为 `2026-11-26-task-labels`。六份规划文件全部 R100；`board-and-status` 新增三个要求，`panel` 新增一个、修改一个要求。正式与试做的整个 `openspec/` 树逐文件相同。普通 validate 21/21、spec-refs 122 条、Git 差异检查通过；未运行全仓 strict 或产品验证。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/archive/2026-11-26-task-labels/` | 原生一次归档；六份工件与入档前 Git 对象逐字节相同 |
| `openspec/specs/board-and-status/spec.md` | 只追加已验收的三个标签与看板列表要求 |
| `openspec/specs/panel/spec.md` | 只追加一个标签视图要求并替换同名看板要求；保留其它要求和场景 |
| `docs/team/reports/A20-dev2.md` | 本报告、原件同一性、格式差异及静态检查回执 |

归档提交：`4d91c89b88fac1cc5ef1a3770e81fd2f1162a184`（`docs(task-labels): archive accepted label requirements (A20)`）。报告另作小步提交；不推送、不合并。私有试做、原始日志和审计文件保留在 `/var/tmp/a20-task-labels-archive.fQRW4d/`，待 PM 收存后再清。

## OpenSpec assessment

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 6/6；归档 4 added / 1 modified | 原生 `list --json` 为 completedTasks/totalTasks = 6/6，proposal/specs/design/tasks 全 done；试做与正式输出均为 `+ 4, ~ 1, - 0, → 0`，六份现存工件全部入档 |
| Correctness | PASS（归档范围） | 六份工件全部 R100；目标块的非末尾 LF 字节与已接受 delta 相同，Purpose 和其它要求正文不变；普通 validate 21 passed / 0 failed、spec-refs 122 条均 rc=0 |
| Coherence | PASS（归档范围） | 正式与试做 `diff -qr openspec …` 无输出；最小 delta 应用加本报告列明的纯 LF 格式差异即可逐字节重建正式结果，没有其它内容差异 |

## CRITICAL

- None。

## WARNING

- None（归档范围）。普通 `openspec validate --all` 有 224 条 `[WARNING]` 文字长度或 Purpose 提示、0 条 `[ERROR]`，最终 21 passed / 0 failed、rc=0。本单不将这些提示写成 strict 已通过，也不按任务书运行全仓 strict。

## SUGGESTION

- None。

## Final assessment

- Counts: CRITICAL 0 · WARNING 0 · SUGGESTION 0（本单归档同步范围）。
- Readiness: 六份原件移动、五个目标要求同步及本报告列出的静态检查范围内可交付。
- Unverified applicable checks and reasons: 按任务书明确不跑全仓 strict、产品行为、完整 smoke、重新构建、安装、发布、当前 Pulse 或真实项目操作；这些项目本轮未执行，不记为通过。P497/V196 的候选 46/0 与合并同一性、一次正向排序证据保持原记录，本单没有重跑或改判原四轮 FAIL。

## Verification evidence (must have actually been run)

以下 OpenSpec 命令均使用：

```text
$ export PATH="$HOME/.bun/bin:$PATH" OPENSPEC_TELEMETRY=0 TMPDIR=/var/tmp
$ openspec --version
1.16.0
```

### 分支、归属和归档前置条件

```text
$ git branch --show-current
task/A20-archive-task-labels
$ git rev-parse --show-toplevel
<worktree>（本人 `.worktrees/dev2`，实际绝对路径见派单）
$ git status --short --branch
## task/A20-archive-task-labels
$ git rev-parse HEAD
3d34444bb8d889f89fb26f7f90e5df33a4f80161
```

`OWNERSHIP.md` 临时授予本席位该 change、唯一归档目录、两份正式规格的五个目标条款及本报告。V196 接受候选 `9b491f07` 与合并 `c9fbb5e7` 的证据，D267 记录 A20 的可逆文档收尾确认。原目录只有 `.openspec.yaml`、proposal、design、tasks 和两个 delta，共六份，无当前 `BLOCKED.md`。

```text
$ openspec list --json
change=task-labels completedTasks/totalTasks=6/6 status=complete
$ openspec status --change task-labels --json
isPlanningComplete=true isComplete=true
artifacts=proposal:done,specs:done,design:done,tasks:done
$ openspec instructions archive --change task-labels
## Archive Inputs: task-labels
No project context or operation guidance configured.
```

`team change status task-labels` 的归档前输出中 P496、P497、P505、V195、V196、V205 全部 done；唯一未完成项和 blocker 是本 A20 自己尚无报告及归档目录。该命令按预期 rc=1，没有被当作产品失败。

### 私有试做：一次

试做根由 `mktemp -d -p /var/tmp a20-task-labels-archive.XXXXXX` 创建；将实际分支的 `openspec/` 用 `cp -a` 复制到 `$trial_root/project/`，随后只在该副本执行：

```text
$ openspec archive -y task-labels
Task status: ✓ Complete

Specs to update:
  board-and-status: update
  panel: update
Applying changes to openspec/specs/board-and-status/spec.md:
  + 3 added
Applying changes to openspec/specs/panel/spec.md:
  + 1 added
  ~ 1 modified
Totals: + 4, ~ 1, - 0, → 0
Specs updated successfully.
Change 'task-labels' archived as '2026-11-26-task-labels'.
trial_archive_rc=0
```

试做完整树差异只包含原目录消失、唯一 dated 目录出现和两份目标规格变化。审计确认 `board-and-status` 要求数 12→15，`panel` 44→45；目标新增/修改块的非末尾 LF 字节与 delta 相同，其它要求正文和 Purpose 保留。

### 唯一一次正式原生归档

```text
$ date -u +%Y-%m-%dT%H:%M:%SZ
2026-11-26T03:17:26Z
$ openspec archive -y task-labels
Task status: ✓ Complete

Specs to update:
  board-and-status: update
  panel: update
Applying changes to openspec/specs/board-and-status/spec.md:
  + 3 added
Applying changes to openspec/specs/panel/spec.md:
  + 1 added
  ~ 1 modified
Totals: + 4, ~ 1, - 0, → 0
Specs updated successfully.
Change 'task-labels' archived as '2026-11-26-task-labels'.
formal_archive_rc=0

$ diff -qr openspec /var/tmp/a20-task-labels-archive.fQRW4d/project/openspec
[无输出]
formal_trial_tree_cmp=exact
```

没有手工移动或同步、硬链接、跳过参数或第二次正式归档。

### 六份原件同一性与精确文件集

入档前逐个执行 `git rev-parse HEAD:<active-path>`，入档后对归档文件执行 `git hash-object`；六对结果完全相同：

```text
c249cfb7cf11d88c938e9cb6a691b8b68b180e79  design.md
462e04dae38d3ff2832b1a937ac273206cdcd818  .openspec.yaml
c13c324dda85af593b2e4205d9a764c003e10ad9  proposal.md
99e79e328ba88b3d627e832dcb092c6d84ae82e8  specs/board-and-status/spec.md
dcf8b3d4d2d7640b97aa21a36556167d502a1c8b  specs/panel/spec.md
f925ac31073a8878d5d2f8d23c335660dd2cc3a3  tasks.md
archived_files=6
```

暂存后的实际 `git diff --cached --name-status` 为六条 R100 加两条 M：

```text
R100  openspec/changes/task-labels/.openspec.yaml
      → openspec/changes/archive/2026-11-26-task-labels/.openspec.yaml
R100  openspec/changes/task-labels/design.md
      → openspec/changes/archive/2026-11-26-task-labels/design.md
R100  openspec/changes/task-labels/proposal.md
      → openspec/changes/archive/2026-11-26-task-labels/proposal.md
R100  openspec/changes/task-labels/specs/board-and-status/spec.md
      → openspec/changes/archive/2026-11-26-task-labels/specs/board-and-status/spec.md
R100  openspec/changes/task-labels/specs/panel/spec.md
      → openspec/changes/archive/2026-11-26-task-labels/specs/panel/spec.md
R100  openspec/changes/task-labels/tasks.md
      → openspec/changes/archive/2026-11-26-task-labels/tasks.md
M  openspec/specs/board-and-status/spec.md
M  openspec/specs/panel/spec.md
```

### 原生空行位置与字节

以“保留原规格字节、只替换同名 MODIFIED 块并追加 ADDED 块”的最小应用结果为基准，原生结果的全部格式差异如下；每个新增字节或删除字节都是 LF `0a`，没有空格、其它字符或非空正文差异：

| 文件 | 准确位置 | 原生格式变化 |
|---|---|---|
| `board-and-status/spec.md` | 新文件第 403 行 | 在原最后一个要求与首个新增要求之间加入一个空行；除此之外与最小应用逐字节相同 |
| `panel/spec.md` | 新文件第 1096 行，`A focused card opens a read-only markdown detail view` 前 | 修改块后加入一个空行，新增 `0a` |
| `panel/spec.md` | 新文件第 2454 行，`String completeness follows purpose references` 场景后 | 原最后一个要求与新增要求之间加入一个空行，新增 `0a` |
| `panel/spec.md` | 最小应用期望文件第 2542 行，文件末尾 | 删除末尾额外空行：`...changing the card\n\n` 变为 `...changing the card\n`，少一个 `0a` |

将以上四处 LF 变化计入后，审计脚本可从原件与 delta 逐字节重建试做结果；正式树又与试做完全相同。审计 JSON、`native-format-delta.txt`、期望文件和原始 diff 均保存在私有试做根。没有手改归档文件、正式规格或工具。

### 归档后普通校验与引用检查

```text
$ openspec validate --all
…
✓ spec/writing-discipline
Totals: 21 passed, 0 failed (21 items)
validate_rc=0
warning_markers=224
error_markers=0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14718 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
spec_refs_rc=0
```

普通 validate 完整输出为私有根的 `validate.log`；上文省略号只省略同类 warning 和成功行，不省略失败。没有运行 strict。

### Git 差异检查

```text
$ git diff --check
[归档暂存后无输出]
unstaged_diff_check_rc=0
$ git diff --cached --check
[无输出]
cached_diff_check_rc=0
```

报告写入后再执行最终工作树与暂存差异检查，回执见最终提交前的命令日志。

### 账本隐私检查

报告首次纳入暂存树后实跑一次，发现本报告保留了本机绝对工作树路径：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
docs/team/reports/A20-dev2.md:61: [home] <home>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev2
ledger-ban: root=<worktree> scope=published files=3172 hits=1 names=ok user=resolved
ledger_first_rc=1
```

按既有隐私口径仅将该路径改为 `<worktree>`，不放宽名单。修正后的第二次实跑：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<worktree> scope=published files=3172 hits=0 names=ok user=resolved
ledger_second_rc=0
```

本回执写入并暂存后，最终再以同一命令检查冻结报告；结果追加到私有根 `final-checks.log`，此后不再改报告。

- Verdict: pass（归档同步及以上静态检查范围）。
- Notes: 只声明归档同步与上述静态检查；未运行项已在 Final assessment 列明。
- Ledger ban: 在本人 worktree、本人分支树上运行；首次 rc=1 的报告路径问题已修正，第二次真实 `files=3172`、`hits=0`、rc=0；冻结报告的最终重跑见上述日志。

## Flip evidence

N/A — 本单是已验收文字变更的归档同步，不是缺陷修复。P497/V196 已有的候选、合并和算分对照保持原记录，本单没有重跑或复制成新证据。

## Decisions and deviations

- 无范围偏离。实际六份工件包含 `.openspec.yaml`，均按原生工具 R100 入档。
- 原生工具只在上述位置增删 LF 空行；按任务书保留并准确列明，没有为格式另行修改。
- 没有改并行 `project-label-management`、产品、测试、真实运行状态、当前 Pulse、看板或任务书。

## Suggested next steps

- PM 复验本分支的归档对象、目标范围、空行字节和静态回执后按 local 模式合并；不推送、不发布。临时证据根留给 PM 收存，本席位不提前清理。
