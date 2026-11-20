# P483 · 帮助检查核对性能命令交接，不再尝试测量

agent: dev-bob   status: DELIVERED — 作者静态检查完成   time: 2026-11-20T07:47:15Z
branch: `task/P483-help-perf-entry-apply`   PR/MR: -

**只替换一条 `perf` 帮助检查。** 实现提交 `eb060d6566384e126b79bef57c2006f0f7a58d8e` 仍从原临时项目调用真实 CLI。私有 CLI 副本只把测量目标换成记录器；实际交接一次、参数和目录相符、CLI 返回 `23`、原六项指纹均不变，缺一项就不通过。作者仅做静态检查；三个行为样本留给非作者执行。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/help-surface.sh` | `eb060d65`：保留原 `proj` 准备与 `perf --host` 用法，复用原命令执行和退出状态采集。记录器把退出状态、实际物理目录、参数个数和参数逐项写在同一行；检查按字节比对整份回执。设置 `TEAM_HELP_SURFACE_KEEP=1` 后，原临时根下的 `logs/p-perf.receipt` 与 `logs/p-perf.out` 可供复验。 |
| `openspec/changes/help-perf-entry-without-measurement/tasks.md` | 作者仅勾 1.1、1.2；2.1、2.2 留给非作者。 |

## OpenSpec assessment

| Dimension | Result | Evidence |
|---|---|---|
| Completeness | 作者工作已完成 | `git diff --unified=0` 显示两处差异：有界名单只剩 `smoke`、紧接原调用前指纹插入 `perf` 专用分支。新分支通过原 `ok` / `finding` 记一次结果，并在进入其他命令的检查前返回。 |
| Correctness | 待独立实测 | 整份回执按预期字节比较，缺失、重复、内容不符均不能通过；退出状态单独核对，`124` 点名超时；继续用原 `fp_all`，失败行点名变化的项目内容，例如 `state`。这些是代码判据，不是实测结果。 |
| Coherence | 写入范围已核对 | `scripts/team:141` 仍走 `team_cmd_perf "$@"`，`scripts/lib/cmd-docs.sh:148` 仍调用同一真实测量入口。实际测量程序、`smoke` 程序和原 `smoke --select 0` 分支、其他帮助路径、CI、正式规格都未改。 |

## Final assessment

可交非作者复验，不作运行通过或可收尾结论。三样本、帮助整组、真实 `team perf`、FAST/全套均未跑。与旧检查一样，六项指纹用于比较两次取值；这次只围绕替代记录器的调用，不能说明真实测量的准备和执行期间是否写入调用项目。P481 的整段 705 秒不是此调用的改前耗时，本次未测时间收益。

## Verification evidence

```text
$ bash -n skills/teamsmith/tests/help-surface.sh
bash_n_rc=0
$ git diff --check
diff_check_rc=0
$ git status --short
 M skills/teamsmith/tests/help-surface.sh
$ test "$(git diff --name-only)" = skills/teamsmith/tests/help-surface.sh
$ test -z "$(git diff --cached --name-only; git ls-files --others --exclude-standard)"
implementation_write_set_rc=0
$ git diff --exit-code -- skills/teamsmith/scripts/team skills/teamsmith/scripts/lib/cmd-docs.sh skills/teamsmith/tests/perf.sh skills/teamsmith/tests/smoke.sh .github/workflows/gates.yml openspec/specs
unchanged_entry_and_suites_rc=0
$ git diff HEAD^ HEAD --check   # HEAD = eb060d65
committed_diff_check_rc=0
```

结构和账本检查只检查文件，不是操作验证：

```text
$ export PATH="$HOME/.bun/bin:$PATH" OPENSPEC_TELEMETRY=0 TMPDIR=/var/tmp
$ openspec status --change help-perf-entry-without-measurement
Progress: 4/4 artifacts complete
status_rc=0
$ openspec instructions apply --change help-perf-entry-without-measurement --json
state=ready, taskTrackingConfigured=true, progress=0/4（实施前）
apply_instruction_rc=0
$ openspec validate help-perf-entry-without-measurement --strict
Change 'help-perf-entry-without-measurement' is valid
change_validate_rc=0
```

```text
$ TMPDIR=/var/tmp bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/dev-bob scope=published files=2938 hits=0 names=ok user=resolved
ledger_rc=0
```

## Flip evidence

作者未执行故障对照。基线 `9a181efc` 源码只有 300 秒窗口前后指纹比较，没有依据 CLI 退出状态判定；P481 已记录假终端无法返回首帧。非作者按 OpenSpec 的 2.1 跑一次正常、一次提前退出 `0` 没有回执、一次成功交接但修改 `state`；初始化失败或超时不能替代预期的两种失败。

## Decisions and deviations

无。仅在任务分支提交，不推送、不发布。保留既有临时目录、选择方式和 `smoke` 的 300 秒处理；`perf` 使用原普通命令执行时限，无新开关。

## Suggested next steps

由 PM 固定候选并派非作者做三个样本。候选交付后不再修改；合并后由同一复验人员按 2.2 核对相关文件和接入点，不重复样本。
