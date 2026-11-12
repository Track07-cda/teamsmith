# A6 · 归档 spec-clarity-burn-down 三份试点

agent: dev3   status: DONE   time: 2026-11-12T05:26:51Z
branch: `task/A6-archive-spec-clarity-pilot`   PR/MR: -

结论：真实归档已完成并提交为 `7c73720bc8b6`；三份 canonical spec 的 strict 均为 rc=0、0 warning，普通全仓校验 20/20 通过。归档变更 `+0 / ~15 / -0 / →0`，全局长需求计数 239→224。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/archive/2026-11-12-spec-clarity-burn-down/` | 由 `openspec archive -y` 移入的完整 change，5 个原文件均为 100% rename |
| `openspec/specs/writing-discipline/spec.md` | 归档 4 条改写后的 requirement |
| `openspec/specs/extension-slash/spec.md` | 归档 6 条改写后的 requirement |
| `openspec/specs/help-surface/spec.md` | 归档 5 条改写后的 requirement |
| `docs/team/reports/A6-dev3.md` | 本报告与实跑证据 |

## OpenSpec assessment

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | PASS | 试归档与真实归档均为 `+0 / ~15 / -0 / →0`；归档目录包含 proposal、tasks 和三份 delta，live change 已移除 |
| Correctness | PASS | 三份 canonical strict 均 rc=0、0 warning；原 43 个场景保留 43 个，归档后共 60 个场景 |
| Coherence | PASS | 私有副本与真实树的 `openspec/` 递归比较无差异；引用检查 122 条、undeclared 0，普通全仓校验 20/20 |

## CRITICAL

None.

## WARNING

None（本归档范围内）。全仓 strict 的其余 224 条长需求与既有 Purpose 问题仍在，未计入本片的 CRITICAL/WARNING。

## SUGGESTION

None.

## Final assessment

- Counts: CRITICAL 0 · WARNING 0 · SUGGESTION 0。
- Readiness: A6 的归档交付已完成，分支可由 PM 独立复验并合并；本结论只覆盖任务书指定的归档与静态检查。
- Unverified applicable checks and reasons: 未跑全量 smoke、夜间套件、61b 和产品行为测试；任务书明确记录这些范围未跑，且本次只移动和合并规格文本。`validate --all --strict` 实跑 rc=1，仍有范围外 224 条长需求及既有 Purpose 警告，不声称全仓 strict 通过。

## Verification evidence (must have actually been run)

归档前任务状态只剩 A6 自身未完成；命令因 A6 当时为 wip 而 rc=1，符合前置判据：

```
$ bash skills/teamsmith/scripts/team change status spec-clarity-burn-down
change spec-clarity-burn-down · not ready
  A6      archive      dev3  wip
  P408    apply        dev   done  docs/team/P408.md: PASS
  V157    opsx-verify  dev3  done  docs/team/V157.md: PASS
rc=1
```

私有副本先试归档，再在本分支执行同一命令；OpenSpec 版本为 1.16.0：

```
$ trial=$(mktemp -d -p /var/tmp a6-archive-trial.XXXXXX)
$ git archive HEAD | tar -x -C "$trial"
$ cd "$trial" && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y spec-clarity-burn-down
Totals: + 0, ~ 15, - 0, → 0
Specs updated successfully.
Change 'spec-clarity-burn-down' archived as '2026-11-12-spec-clarity-burn-down'.
rc=0

$ cd <own-worktree> && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y spec-clarity-burn-down
Totals: + 0, ~ 15, - 0, → 0
Specs updated successfully.
Change 'spec-clarity-burn-down' archived as '2026-11-12-spec-clarity-burn-down'.
rc=0
$ diff -qr openspec /var/tmp/a6-archive-trial.gZjAwU/openspec
rc=0
```

真实树上的三份 strict 与全仓校验：

```
$ for spec in writing-discipline extension-slash help-surface; do
    "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate "$spec" --strict
  done
Specification 'writing-discipline' is valid   rc=0  warnings=0  long_requirements=0
Specification 'extension-slash' is valid      rc=0  warnings=0  long_requirements=0
Specification 'help-surface' is valid         rc=0  warnings=0  long_requirements=0

$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all
Totals: 20 passed, 0 failed (20 items)
rc=0

$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
rc=1
$ awk '/Requirement text is very long/{n++} END{print n+0}' /var/tmp/a6-dev3-evidence.Qcx3Hj/all.strict.log
224
```

场景、引用、选段与空白检查：

```
$ python3 <scenario-block-comparison>
writing-discipline: original=8 verbatim_survivors=8 current=12
extension-slash: original=14 verbatim_survivors=14 current=16
help-surface: original=21 verbatim_survivors=21 current=32
TOTAL original=43 verbatim_survivors=43 current=60 added=17
rc=0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14077 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 13  bad 0  SKIP 1
rc=0

$ git diff --check
rc=0
```

- Verdict: PASS。
- Notes: 原始日志在 `/var/tmp/a6-dev3-evidence.Qcx3Hj/`。试归档副本 `/var/tmp/a6-archive-trial.gZjAwU/` 在保留日志并完成比对后清理；未把临时目录提交进仓库。
- Ledger ban（报告落盘后在本 worktree、本分支树运行）：

  ```
  $ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev3 scope=published files=2745 hits=0 names=ok user=resolved
  $ echo $?
  0
  ```

## Flip evidence (required for defect-fix tasks)

N/A — 本任务是已验证规格的归档，不是缺陷修复；未改产品实现或测试。

## Decisions and deviations

- `openspec` 不在 PATH，因此使用机器上现有的 Bun 入口 `"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec"`，实测版本 1.16.0；未安装依赖或修改环境。
- 额外场景比对第一版把文件末尾空行计入场景块，得到 42/43；逐项 diff 证明唯一差异是 `extension-slash` 末尾少一个空行。仅去除场景块末尾空行后重跑为 43/43，场景标题和正文均逐字保留。该仪器误报没有改变归档内容。
- 无范围偏离；未手改 delta 或 canonical spec，未合并、未推送。

## Suggested next steps

- PM 在本提交及最终报告提交上独立复验，复验通过后按本地流程合并；本席位不执行合并或推送。
