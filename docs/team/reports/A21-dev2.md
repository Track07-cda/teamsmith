# A21 · 同步项目设置管理任务标签的正式说明

agent: dev2   status: delivered   time: 2026-11-26T04:08:52Z
branch: `task/A21-archive-project-label-management`   PR/MR: -

**归档范围内已交付。** OpenSpec 1.16.0 私有试做与正式 `archive -y project-label-management` 各执行一次，均 rc=0；正式目录为 `2026-11-26-project-label-management`。六份规划文件全部 R100；`board-and-status` 新增一个要求，`panel` 新增一个并替换三个同名要求。正式与试做的整个 `openspec/` 树逐字节相同，原 A20 标签定义、未点名要求、场景、Purpose 和顺序均保持不变。普通 validate 20/20、spec-refs 122 条及 Git 差异检查通过；未运行全仓 strict 或产品验证。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/archive/2026-11-26-project-label-management/` | 原生一次归档；六份工件与入档前版本逐字节相同 |
| `openspec/specs/board-and-status/spec.md` | 只追加标签定义命令的结构化结果要求；A20 标签定义及场景原样保留 |
| `openspec/specs/panel/spec.md` | 只追加项目设置标签管理要求，并替换三个已审核的同名要求 |
| `docs/team/reports/A21-dev2.md` | 本报告、原件同一性、目标块与格式审计、静态检查回执 |

归档提交：`2bf50f9c`（`docs(openspec): archive project label management (A21)`）。报告另作小步提交；不推送、不合并。私有试做、原始日志和差异文件保留在 `/var/tmp/a21-project-label-archive.Gk0PLM/`，待 PM 收存后再清。

## OpenSpec assessment

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 8/8；归档 2 added / 3 modified | 清单 8/8；试做与正式输出均为 `+ 2, ~ 3, - 0, → 0`，六份现存工件全部入档 |
| Correctness | PASS（归档范围） | 六份工件全部 R100；五个目标要求块与已接受 delta 相同，A20 标签定义及其它要求正文不变；普通 validate 20 passed / 0 failed、spec-refs 122 条均 rc=0 |
| Coherence | PASS（归档范围） | 正式与试做 `diff -r openspec …` 无输出；最小 delta 应用与正式结果逐字节相同，没有额外空行或其它格式差异 |

## CRITICAL

- None。

## WARNING

- None（归档范围）。普通 `openspec validate --all` 有 224 条 `[WARNING]` 文字长度或 Purpose 提示、0 条 `[ERROR]`，最终 20 passed / 0 failed、rc=0。本单不将这些提示写成 strict 已通过，也不按任务书运行全仓 strict。

## SUGGESTION

- None。

## Final assessment

- Counts: CRITICAL 0 · WARNING 0 · SUGGESTION 0（本单归档同步范围）。
- Readiness: 六份原件移动、五个目标要求同步及本报告列出的静态检查范围内可交付。
- Unverified applicable checks and reasons: 按任务书明确不跑全仓 strict、产品行为、完整 smoke、重新构建、安装、发布、当前 Pulse 或真实项目操作；这些项目本轮未执行，不记为通过。未确认回复、读取失败和看板新旧请求相遇仍保持 V206 的源码核对边界，本单未实跑或改判；任务书所述作者全仓 strict 5/17 旧失败也保留原记录。P511/V206 的候选 49/0、定点布局、合并后 284 文件一致及实际打开与返回证据不由本单重新生成。

## Verification evidence (must have actually been run)

以下 OpenSpec 命令均使用：

```text
$ export PATH="$HOME/.bun/bin:$PATH"
$ openspec --version
1.16.0
```

### 分支、归属和归档前置条件

```text
$ git branch --show-current
task/A21-archive-project-label-management
$ git rev-parse --show-toplevel
<worktree>（本人 `.worktrees/dev2`）
$ git status --short --branch
## task/A21-archive-project-label-management
```

`OWNERSHIP.md` 临时授予本席位该 change、唯一归档目录、两份正式规格的五个目标条款及本报告。`team change status project-label-management` 显示 P506、P507、P511、V203、V206 全部 done；唯一未完成项和 blocker 是本 A21 自己尚无报告及归档目录。该命令按预期 rc=1，没有被当作产品失败。

### 私有试做：一次

试做根由 `mktemp -d -p /var/tmp a21-project-label-archive.XXXXXX` 创建；将实际分支的 `openspec/` 用 `cp -a` 复制到 `$trial_root/project/`，随后只在该副本执行：

```text
$ openspec archive -y project-label-management
Task status: ✓ Complete

Specs to update:
  board-and-status: update
  panel: update
Applying changes to openspec/specs/board-and-status/spec.md:
  + 1 added
Applying changes to openspec/specs/panel/spec.md:
  + 1 added
  ~ 3 modified
Totals: + 2, ~ 3, - 0, → 0
Specs updated successfully.
Change 'project-label-management' archived as '2026-11-26-project-label-management'.
trial_archive_rc=0
```

试做完整树差异只包含原目录消失、唯一 dated 目录出现和两份目标规格变化；六份工件 `diff -r` rc=0。目标块审计实跑结果：

```text
MATCH board-and-status: Project label definition commands can report a structured outcome
MATCH board-and-status: Purpose prefix unchanged (342 bytes)
MATCH board-and-status: Project labels are managed by name beside the board
  sha256=7d1412a371fd5659df14428d54811a3f8319bd9d677094981571c4d0872259de
MATCH board-and-status: all unnamed requirements and original order unchanged
MATCH panel: Project settings manage the current project's task label definitions
MATCH panel: The console is read-only except through its owning commands
MATCH panel: Project settings expose selected user operations rather than the complete configuration table
MATCH panel: Settings groups follow user purposes and keep visible action state
MATCH panel: Purpose prefix unchanged (734 bytes)
MATCH panel: all unnamed requirements and original order unchanged
```

上述五个目标块均与对应 delta 逐字节相同；A20 标签定义的整要求块（含全部场景）与归档前正式规格逐字节相同。

### 原生空行与其它字节审计

以“保留原规格字节、只替换同名 MODIFIED 块并追加 ADDED 块”的最小应用结果为基准，内存构造的期望文件与原生结果逐字节比较：

```text
EXACT board-and-status: native output equals original bytes + named block replacements + appended ADDED block; no extra blank-line or other byte changes
EXACT panel: native output equals original bytes + named block replacements + appended ADDED block; no extra blank-line or other byte changes
byte_audit_rc=0
```

因此本单没有需要保留的原生额外空行；未手改归档文件、正式规格或工具。

### 唯一一次正式原生归档

```text
$ openspec archive -y project-label-management
Task status: ✓ Complete

Specs to update:
  board-and-status: update
  panel: update
Applying changes to openspec/specs/board-and-status/spec.md:
  + 1 added
Applying changes to openspec/specs/panel/spec.md:
  + 1 added
  ~ 3 modified
Totals: + 2, ~ 3, - 0, → 0
Specs updated successfully.
Change 'project-label-management' archived as '2026-11-26-project-label-management'.
formal_archive_rc=0

$ diff -r openspec /var/tmp/a21-project-label-archive.Gk0PLM/project/openspec
[无输出]
formal_trial_tree_cmp=exact
```

没有手工移动或同步、硬链接、跳过参数或第二次正式归档。

### 六份原件同一性与精确文件集

暂存后的实际 `git diff --cached --name-status` 为六条 R100 加两条 M：

```text
R100  openspec/changes/project-label-management/.openspec.yaml
      → openspec/changes/archive/2026-11-26-project-label-management/.openspec.yaml
R100  openspec/changes/project-label-management/design.md
      → openspec/changes/archive/2026-11-26-project-label-management/design.md
R100  openspec/changes/project-label-management/proposal.md
      → openspec/changes/archive/2026-11-26-project-label-management/proposal.md
R100  openspec/changes/project-label-management/specs/board-and-status/spec.md
      → openspec/changes/archive/2026-11-26-project-label-management/specs/board-and-status/spec.md
R100  openspec/changes/project-label-management/specs/panel/spec.md
      → openspec/changes/archive/2026-11-26-project-label-management/specs/panel/spec.md
R100  openspec/changes/project-label-management/tasks.md
      → openspec/changes/archive/2026-11-26-project-label-management/tasks.md
M  openspec/specs/board-and-status/spec.md
M  openspec/specs/panel/spec.md
archived_files=6
```

### 归档后普通校验与引用检查

```text
$ openspec validate --all
…
✓ spec/writing-discipline
Totals: 20 passed, 0 failed (20 items)
validate_rc=0
warning_markers=224
error_markers=0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14718 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
spec_refs_rc=0
```

普通 validate 完整输出为私有根的 `formal-validate.log`；上文省略号只省略同类 warning 和成功行，不省略失败。没有运行 strict。

### Git 差异检查

```text
$ git diff --cached --check
[归档提交前无输出]
cached_diff_check_rc=0
$ git diff HEAD^ HEAD --check
[归档提交后无输出]
committed_diff_check_rc=0
```

### 账本隐私检查

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<worktree> scope=published files=3182 hits=0 names=ok user=resolved
ledger_rc=0
```

- Verdict: pass（归档同步及以上静态检查范围）。
- Notes: 只声明归档同步与上述静态检查；未运行项已在 Final assessment 列明。
- Ledger ban: 在本人 worktree、本人分支树上运行，实际结果见上。

## Flip evidence

N/A — 本单是已验收文字变更的归档同步，不是缺陷修复。P511/V206 已有候选、合并及界面证据保持原记录，本单没有重跑或复制成新证据。

## Decisions and deviations

- 无范围偏离。实际六份工件包含 `.openspec.yaml`，均按原生工具 R100 入档。
- 原生工具没有引入额外空行或其它格式变化；精确字节审计 rc=0。
- 没有改产品、测试、真实运行状态、当前 Pulse、看板或任务书。

## Suggested next steps

- PM 复验本分支的归档对象、目标范围、字节审计和静态回执后按 local 模式合并；不推送、不发布。临时证据根留给 PM 收存，本席位不提前清理。
