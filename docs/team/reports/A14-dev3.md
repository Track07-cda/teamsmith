# A14 · 同步帮助检查的性能命令交接规格

agent: dev3 · phase: archive · status: DELIVERED · time: 2026-11-20T08:10:34Z · branch: `task/A14-archive-help-perf-entry` · PR/MR: -（local）

## 结论

OpenSpec 1.16.0 已把已验收的帮助检查变更同步到正式规格，归档提交 `25ced7a53ae3e3552efa55e1fcc09dce9868b7ba`。归档五份工件与原件逐字节相同。正式规格只改 **A gate that cannot judge says so**：保留原有 23 个场景及顺序，加入三个已验收场景。同步的需求块与已接受变更正文逐字节一致，没有缩减连续空行；标题、Purpose、目标外正文及全部可执行文件未改。

## Deliverables

| 路径 | 交付 |
|---|---|
| `openspec/changes/archive/2026-11-20-help-perf-entry-without-measurement/` | `.openspec.yaml`、`design.md`、`proposal.md`、`specs/verification/spec.md`、`tasks.md` 原样移入；Git 五项均 `R100`。 |
| `openspec/specs/verification/spec.md` | 仅同步上述既有需求。普通差异分五处：例外清单、交接检查的口径、两个旧覆盖场景各自的限定、三个新场景。 |
| `docs/team/reports/A14-dev3.md` | 本报告；原始证据留在本人唯一目录 `E=/var/tmp/a14-help-perf-archive.u2FrzE`。 |

## OpenSpec assessment

| 项目 | 证据 |
|---|---|
| 完整性 | `openspec list --json` 显示任务 4/4、`complete`；`openspec status --change … --json` 显示 proposal/specs/design/tasks 四项 `done`。`root.source=nearest`、`planningHome.kind=repo`，均指本人 `.worktrees/dev3`。 |
| 正确性 | 私有副本与实际归档的完整 OpenSpec 树 `diff -qr` 为 0，共 507 个文件。五个实际工件与基线 Git 正文各 `cmp` 为 0；正式目标块 38,777 字节匹配已接受正文，保留原块间分隔。 |
| 一致性 | 正式规格目标前 86,239 字节（含标题、Purpose）、目标后 68,947 字节及其他 501 个 OpenSpec 文件不变。实际暂存范围只有五项 `R100` 和正式规格一项 `M`；相对已验合并版的 `skills`、`.github`、`ci` 差异检查为 0。 |

CRITICAL：无。WARNING：原生结构提示见下方回执。SUGGESTION：无。此结论限规格同步，不是行为复验。

## Verification evidence

依据：D264 依 D241 确认收尾；P482、V182、P483、V183 已接受关闭。基线 `92e589e0` 确实包含 `282b9dc79dd1c1fb751e50a040f2834612ff26be`（`git merge-base --is-ancestor` 退出 0）。作者 dev-bob、独立验证者 verify；候选三个样本和合并版正式 PASS 借用 `docs/team/reviews/V183.md`、`docs/team/reviews/P483.md` 和最终报告提交 `73617359` 的证据，不重复执行。两次验证侧准备问题的原记录及 V174 历史结论不变；真实性能执行是否写入调用项目仍未验证。

使用 `PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0`。`openspec --version`、`openspec list --json`、`openspec status --change help-perf-entry-without-measurement --json`、`openspec instructions archive --change help-perf-entry-without-measurement --json`、`openspec instructions specs --change help-perf-entry-without-measurement --json` 均退出 0，stderr 为空；实际命令、JSON 和退出码在 `E`。私有树 `E/project/openspec` 由 `cp -a openspec` 生成，抽查 `tasks.md` inode 与源不同，未用硬链接。先审完整试做差异，再在自己任务分支原生执行一次；未初始化、升级、跳验证、跳同步或手工拼接、移动规格。

```text
$ openspec archive -y help-perf-entry-without-measurement
Task status: ✓ Complete

Specs to update:
  verification: update
Applying changes to openspec/specs/verification/spec.md:
  ~ 1 modified
Totals: + 0, ~ 1, - 0, → 0
Specs updated successfully.
Change 'help-perf-entry-without-measurement' archived as '2026-11-20-help-perf-entry-without-measurement'.
```

试做与实际执行均退出 0、stderr 为空，无归档警告。对照原件：`trial-spec.diff`、`trial-compare.log`、`actual-spec.diff`、`actual-compare.log`、`archive-staged-status.log`；实际执行后原活跃目录不存在。

在归档提交上实际运行，后台作业 `A14-archive-short-checks` 已收取，整体退出 0。各项原始命令、输出和退出码保存在 `E`。

```text
$ openspec validate --all
Totals: 20 passed, 0 failed (20 items)
rc=0
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14279 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0
$ git diff --check 92e589e0 HEAD
rc=0
```

普通校验 stderr 有 222 条需求文字超过 500 字符提示和 1 条 Purpose 占位提示，未为消除提示改写已验正文；其他两项 stderr 为空，已提交差异检查 stdout 为空。

本人工作树上报告暂存后执行原账本公开文件检查，使用既有名单路径，未读取名单正文。以下回执写入报告后，再暂存并验证最终版；原件分别保存在 `E/ledger-receipt.*` 与 `E/ledger-final.*`。

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev3 scope=published files=2946 hits=0 names=ok user=resolved
rc=0
$ git diff --check
rc=0
$ git diff --cached --check
rc=0
```

以上三项 stderr 为空，两项差异检查 stdout 也为空。

## Flip evidence、范围与交接

本任务只同步规格，不是缺陷修复。未运行帮助、性能测量、smoke、真实团队或模型；不将普通结构校验称为全仓 strict，也不从历史 705 秒推算本次节省。仅在本人任务分支做本地提交；未推送、合并、发布或改看板。私有试做和执行原件留给 PM 核对后再处理。
