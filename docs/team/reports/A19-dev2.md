# A19 · 原生同步 PM 待命文字要求并收尾

agent: dev2   status: delivered   time: 2026-11-26T02:23:16Z
branch: `task/A19-archive-clarified-pm-standby-guidance`   PR/MR: -

**归档范围内已交付。** OpenSpec 1.16.0 私有试做与正式 `archive -y` 均成功；正式归档只执行一次，生成 `2026-11-26-clarify-pm-standby-guidance`。五份工件全部 R100，正式 `init-skill` 只同步已批准的一个 MODIFIED requirement；原生工具另在目标块边缘新增一个 LF 空行，已保留并单列。普通 validate 22/22、spec-refs、精确字节对照和差异检查通过。未运行产品行为、模型、安装、生成、发布或全仓 strict。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/archive/2026-11-26-clarify-pm-standby-guidance/` | 原生一次归档；五份工件与入档前 Git 对象逐字节相同 |
| `openspec/specs/init-skill/spec.md` | 只更新 `Installed team instructions separate shared rules from role procedures without losing required duties`；保留原六个场景并新增已批准的待命场景 |
| `docs/team/reports/A19-dev2.md` | 本报告、试做与正式归档回执、字节及格式差异审计 |

归档提交：`3d68ae9475147f0fb446ad84f34ed724ef72a50d`（`docs(init-skill): archive standby guidance (A19)`）。报告另作小步提交；不推送、不合并。私有试做与原始日志保留在 `/var/tmp/a19-pm-standby-archive.B40K7P/`，待 PM 收存后再清。

## OpenSpec assessment

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 7/7 | 原生 `list --json` 为 completedTasks/totalTasks = 7/7；`status --json` 的 proposal/specs/design/tasks 全部 done；归档报告仅 `init-skill: update`、`~ 1 modified` |
| Correctness | PASS（归档范围） | 五份工件全部 R100；目标要求的非空正文与已批准 delta 完全一致，原六个场景名称与顺序保留，新增一个待命场景；普通 validate 22 passed / 0 failed、spec-refs 122 条均 rc=0 |
| Coherence | PASS（归档范围） | 正式 `openspec/` 与试做结果整树 `diff -qr` 相同；目标外保留文件逐字节相同，Purpose、其它 requirement 的非空正文和要求顺序不变；唯一格式变化是新文件第 678 行一个 LF 空行 |

## CRITICAL

- None。

## WARNING

- None（归档范围）。普通 `openspec validate --all` 输出 224 条 `[WARNING]` 文字长度或 Purpose 提示、0 条 `[ERROR]`，最终 22 passed / 0 failed、rc=0。本单不将这些提示写成 strict 已通过，也不按任务书重跑含既有长条款的全仓 strict。

## SUGGESTION

- None。

## Final assessment

- Counts: CRITICAL 0 · WARNING 0 · SUGGESTION 0（本单归档同步范围）。
- Readiness: 五份原件移动、单个目标要求同步及本报告列出的静态检查范围内可交付。
- Unverified applicable checks and reasons: 按任务书明确不跑全仓 strict、产品行为、模型、模板生成、安装、现有项目采用、真实待命或提醒切换、全量 smoke 与发布；这些项目本轮未执行，不记为通过。P510/V204 的文字核对与未解决项 0 保持原记录，本单不把它们改写成行为验收。

## Verification evidence (must have actually been run)

以下 OpenSpec 命令均使用：

```text
$ export PATH="$HOME/.bun/bin:$PATH" OPENSPEC_TELEMETRY=0
$ openspec --version
1.16.0
```

### 分支、归属和归档前置条件

```text
$ pwd
<worktree>（本人 `.worktrees/dev2`，实际绝对路径见派单）
$ git branch --show-current
task/A19-archive-clarified-pm-standby-guidance
$ git status --short --branch
## task/A19-archive-clarified-pm-standby-guidance
$ git rev-parse HEAD
d780bb4868cfc86d45b5f0200155404a1b6226a5
```

`OWNERSHIP.md` 临时授予本席位该 change、唯一归档目录、`init-skill` 单个目标要求及本报告。P510 接受记录与 V204 合并版报告均指向 `dad295e20d8f1ccbbde512b4aa247e1254613c37`，未解决项 0；D270 记录 A19 的可逆小范围确认。

```text
$ openspec list --json
change=clarify-pm-standby-guidance completedTasks/totalTasks=7/7 status=complete
$ openspec status --change clarify-pm-standby-guidance --json
schemaName=spec-driven
proposal=done
specs=done
design=done
tasks=done
isComplete=true
$ openspec instructions archive --change clarify-pm-standby-guidance
## Archive Inputs: clarify-pm-standby-guidance
No project context or operation guidance configured.
```

`team change status clarify-pm-standby-guidance` 的归档前输出中 P504、P508、P510、V201、V204 全部 done；唯一 blocker 是本 A19 自己尚为 wip、尚无报告和归档目录。该命令按预期 rc=1，没有被当作产品失败。目标归档目录执行前不存在。

### 私有试做

试做根由 `mktemp -d -p /var/tmp a19-pm-standby-archive.XXXXXX` 创建；将实际分支的 `openspec/` 用 `cp -a` 复制到 `$trial_root/project/`，随后只在该副本执行：

```text
$ date -u +%Y-%m-%dT%H:%M:%SZ
2026-11-26T02:19:46Z
$ openspec archive -y clarify-pm-standby-guidance
Task status: ✓ Complete

Specs to update:
  init-skill: update
Applying changes to openspec/specs/init-skill/spec.md:
  ~ 1 modified
Totals: + 0, ~ 1, - 0, → 0
Specs updated successfully.
Change 'clarify-pm-standby-guidance' archived as '2026-11-26-clarify-pm-standby-guidance'.
trial_archive_rc=0
```

### 唯一一次正式原生归档

```text
$ date -u +%Y-%m-%dT%H:%M:%SZ
2026-11-26T02:21:39Z
$ openspec archive -y clarify-pm-standby-guidance
Task status: ✓ Complete

Specs to update:
  init-skill: update
Applying changes to openspec/specs/init-skill/spec.md:
  ~ 1 modified
Totals: + 0, ~ 1, - 0, → 0
Specs updated successfully.
Change 'clarify-pm-standby-guidance' archived as '2026-11-26-clarify-pm-standby-guidance'.
formal_archive_rc=0
```

没有手工移动或同步、硬链接、跳过参数或第二次正式归档。

### 五份工件与精确文件集

入档前逐个执行 `git rev-parse HEAD:<active-path>`，入档后对归档文件执行 `git hash-object`；五对结果完全相同：

```text
3582514ed38dd5714856b47094cee8abd83958c6  design.md
7ed429c59271022891e74ad32b8a3570fa51fa65  .openspec.yaml
021e0adefa167bcbba96f7cb682cce583b1ec4b7  proposal.md
729fb247ce4a246912d614a3f226554f01faa014  specs/init-skill/spec.md
9a00135f3fab2cfe7adab0a8c96edc92ca1716fb  tasks.md
```

暂存后的实际 `git diff --cached --name-status`：

```text
R100  openspec/changes/clarify-pm-standby-guidance/.openspec.yaml
      → openspec/changes/archive/2026-11-26-clarify-pm-standby-guidance/.openspec.yaml
R100  openspec/changes/clarify-pm-standby-guidance/design.md
      → openspec/changes/archive/2026-11-26-clarify-pm-standby-guidance/design.md
R100  openspec/changes/clarify-pm-standby-guidance/proposal.md
      → openspec/changes/archive/2026-11-26-clarify-pm-standby-guidance/proposal.md
R100  openspec/changes/clarify-pm-standby-guidance/specs/init-skill/spec.md
      → openspec/changes/archive/2026-11-26-clarify-pm-standby-guidance/specs/init-skill/spec.md
R100  openspec/changes/clarify-pm-standby-guidance/tasks.md
      → openspec/changes/archive/2026-11-26-clarify-pm-standby-guidance/tasks.md
M  openspec/specs/init-skill/spec.md
```

试做审计逐文件比较实际分支原件与入档文件，并比较完整路径集：545 份 OpenSpec 文件中，除五份移动和目标规格外，所有保留文件逐字节相同。正式归档后执行：

```text
$ diff -qr openspec /var/tmp/a19-pm-standby-archive.B40K7P/project/openspec
[无输出]
formal_trial_tree_cmp=exact
$ cmp openspec/specs/init-skill/spec.md /var/tmp/a19-pm-standby-archive.B40K7P/project/openspec/specs/init-skill/spec.md
[无输出]
target_spec_trial_cmp=exact
```

### 目标要求与原生空行字节

审计从入档前正式规格按 `### Requirement:` 分块，仅以 delta 的同名块替换目标，再与实际结果比较。结果：

```text
requirements_exact=yes count=16
target_non_empty_matches_delta=yes
Purpose_and_other_non_empty_text_exact=yes
target_scenarios=6_prior+1_standby
prior_order_exact=yes
historical_qualifier=present
```

`The new rule does not change installation or refresh` 的既有历史限定 `for the change introducing the proceed-within-authorization rule` 保留。目标外 requirement 集合和次序不变。

实际结果与“只替换目标块”的期望文件只有一处格式差异：在新文件第 678 行插入一个空行，新增字节为换行 `0a`；没有空格、其它字符或第二处格式变化。期望与实际的 SHA-256 分别为：

```text
expected=2be604874cdd776c245dc35941c71d16aaccbfae9a0e71406e0c5031ea75eb1c
actual  =0ead594659ba5662a9b64b8bd7e8a82eb83a701a03493b0d7b15449c151ba7bf
```

该原生差异保留，没有手改归档文件、正式规格或工具。审计脚本、`expected-init-skill-spec.md`、`native-format-delta.txt`、`trial-spec.diff` 和原始命令日志均在上述临时根。

### 归档后普通校验与引用检查

```text
$ openspec validate --all
…
✓ spec/writing-discipline
Totals: 22 passed, 0 failed (22 items)
validate_rc=0
warning_markers=224
error_markers=0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14718 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
spec_refs_rc=0
```

普通 validate 完整输出为临时根的 `validate.log`；上文省略号只省略同类 warning 和成功行，不省略失败。没有运行 strict。

### 差异检查

```text
$ git diff --check
[归档提交前无输出]
unstaged_diff_check_rc=0
$ git diff --cached --check
[归档暂存时无输出]
cached_diff_check_rc=0
```

```text
$ git diff --check
[报告写入后无输出]
report_diff_check_rc=0
```

### 账本隐私检查

```text
$ TMPDIR=/var/tmp bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<worktree> scope=published files=3162 hits=0 names=ok user=resolved
ledger_rc=0
```

`<worktree>` 仅替代本机绝对路径；`files`、`hits` 与 rc 为实际输出。

- Verdict: pass（以最终报告已加入本分支树后的实跑回执为准）。
- Notes: 只声明归档同步与上述静态检查；未运行项已在 Final assessment 列明。
- Ledger ban: 在本人 worktree、本人分支树上运行；真实 `files`、`hits` 和 rc 见上方回执。

## Flip evidence

N/A — 本单是已验收文字变更的归档同步，不是缺陷修复。P510/V204 已有的源文字前后对照保持原记录，本单没有重跑或复制成新证据。

## Decisions and deviations

- 无范围偏离。实际五份工件包含 `.openspec.yaml`，均按原生工具 R100 入档。
- 原生工具只在目标块边缘新增上述一个 LF 空行；按任务书保留并列明，没有为格式另行修改。
- 没有改产品、模板、当前项目指令、其它规格、真实运行状态或并行标签变更；没有更新看板或任务书。

## Suggested next steps

- PM 复验本分支的归档对象、目标范围和静态回执后按 local 模式合并；不推送、不发布。临时证据根留给 PM 收存，本席位不提前清理。
