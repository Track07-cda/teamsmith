# P450 · 默认配置下提醒工具必须可用

agent: dev   status: **DELIVERED（P450 定点验收通过；等待 V158 复验）**   time: 2026-11-12T08:05:10Z
branch: `task/P450-remind-init-config`   PR/MR: -

## 结论

默认 `team init` 生成的带行尾注释配置现在可以注册并暴露 `team_remind`；配置确实不匹配时工具保持隐藏，留下 `status=error`、具体键名和原因，doctor 报告同一错误。未加载扩展仍是 `unknown evidence:ENOENT`，普通 Pi、worker 和伪造身份仍不留下 Reminder 状态。

真实 Pi 夹具改为通过 `team init` 生成配置，不再手写无注释配置。完整真实 Pi 定点夹具 10/0、提醒段入口 32/0、doctor/init 及其依赖选段 159/0；旧 `configValue()` 与删除错误证据写入两个变异均让具名断言变红，生产源码未随变异改变。

唯一非绿检查是 `openspec validate --all`：20 项通过、1 项失败，失败来自本任务起点已有的 `panel-symlink-inside-project` 空 delta；本任务未修改该 change。`agent-self-reminder` 单独校验通过。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/remind-capability.mjs` | 窄化解析 quoted value + 行尾注释；保留引号内及未加引号值中的 `#`；为有效 PM 的配置错误提供可诊断证据 |
| `skills/teamsmith/extension/team-remind.ts` | 配置校验失败时仅绕过配置比较来取得有效 PM 身份，工具保持隐藏并发布具体 `status=error`；身份伪造仍无证据 |
| `skills/teamsmith/scripts/lib/cmd-project.sh` | doctor 在错误证据仍属于活 PM 时优先显示配置错误；保留 not-running 与 missing-evidence 分支 |
| `skills/teamsmith/tests/remind-tool-node.mjs` | 默认注释、quoted `#`、未加引号值及旧解析函数红侧 |
| `skills/teamsmith/tests/remind-tool-real.mjs` | 用真实 `team init` 配置驱动私有 HOME/tmux/Pi；新增真实 mismatched 配置、doctor error 与删除证据写入的红侧 |
| `skills/teamsmith/tests/smoke.sh` | 更新快速夹具 9 项、真实 Pi 10 项的精确计数 |
| `docs/team/reports/P450-dev.md` | 本报告 |

## OpenSpec assessment

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | P450 范围完整 | 默认配置注册、quoted/unquoted 解析、真实 mismatch、error evidence、doctor 区分及两条红侧均有行为断言；未改提醒语义、额度或配置键 |
| Correctness | 定点通过 | `remind-tool-node` 9/0；真实 Pi 10/0；`remind-delivery` 101/0；`state-authority` 119/0；smoke 67 入口 32/0 |
| Coherence | 与既有诊断契约一致 | `PM tool availability is honestly diagnosed` 要求区分 missing/stale/mismatched evidence、explicit load failure 与 fresh registration；本次复用现有 capability evidence，没有新增第二套状态或规格 |

## CRITICAL

None（P450 范围内）。

## WARNING

1. 全量 OpenSpec 不能记为绿：`panel-symlink-inside-project` 在本任务起点已有 proposal/tasks、没有 delta，`openspec validate --all` 报 `Change must have at least one delta`，总计 20 passed / 1 failed。该 change 不属于 P450，未修改；`agent-self-reminder` 定点校验为 valid。PM 需由该 change 的 owner 收口，不应把这条红归因于本修复。

## SUGGESTION

None。

## Final assessment

- Counts: CRITICAL 0 · WARNING 1 · SUGGESTION 0。
- Readiness: P450 可以交 V158 独立复验；本报告只覆盖下文实际运行的定点检查，不宣称全量门禁或归档就绪。
- Unverified applicable checks and reasons: 按任务书未跑全量 smoke、夜间、61b；作者未重复 V158 的 AC-02/AC-09 长真实模型场景，需原 verifier 用未修改的 `team init` 配置重跑；未运行 strict OpenSpec（本仓当前门禁为普通 `--all`）。全量普通 OpenSpec 已运行，但有一条上述越界既存红。

## Verification evidence (must have actually been run)

```bash
$ node skills/teamsmith/tests/remind-tool-node.mjs
PASS config: default comments, quoted hashes and unquoted values parse by behavior
EXPECTED RED configValue: default generated quoted value with trailing comment
PASS flip: restoring old configValue turns the named default-config assertion red
remind-tool-node: passed=9 failed=0

$ bash skills/teamsmith/tests/remind-tool-real.sh
PASS real Pi PM add/list/show/cancel, retry, observed same-key renewal and no-key IDs
PASS real Pi 64 KiB plus final newline through real PM tool add/show/list/cancel
PASS real Pi ordinary: globally loaded copy stays hidden with zero Reminder state
PASS real Pi worker: globally loaded copy stays hidden with zero Reminder state
PASS real Pi forged: globally loaded copy stays hidden with zero Reminder state
PASS real Pi reload into an invalid pane hides all actions without changing Reminder state
PASS real Pi running PM with no entry is unknown, not a load failure
PASS real Pi generated config mismatch hides the tool and leaves a specific doctor error
EXPECTED RED config-error evidence: mismatched config leaves visible error evidence
PASS real Pi flip: deleting config-error evidence turns the named visibility assertion red
PASS real Pi explicit bootstrap failure is error while fresh
remind-tool-real: passed=10 failed=0 evidence=/var/tmp/p442-real-evidence-1794470361915

$ bash skills/teamsmith/tests/remind-delivery.sh
== remind-delivery 结果 == ✓101 ✗0 SKIP0

$ bash skills/teamsmith/tests/state-authority.sh
== state-authority 结果 == ✓119 ✗0 SKIP0

$ bash skills/teamsmith/tests/smoke.sh --select 1,2,3,15b </dev/null
账本自查：11 段收口 · 增量 ✓159 ✗0 SKIP0 ｜ 结果行 ✓159 ✗0 —— 一致
== 选段结果 == ✓159 ✗0

$ bash skills/teamsmith/tests/smoke.sh --select 67 </dev/null
✓ P442 假宿主：身份零读写、配置解析与全文红绿全绿
✓ P442 真实 Pi：PM 工具/身份/配置错误/doctor 十组全绿
== 选段结果 == ✓32 ✗0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14077 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 == ok 13 bad 0 SKIP 1
# SKIP 是 internal 检出没有机器生成的 .pi/skills；其余 731 条字面模式在位。

$ "$HOME/.bun/bin/openspec" validate agent-self-reminder --type change
Change 'agent-self-reminder' is valid

$ "$HOME/.bun/bin/openspec" validate --all
✗ change/panel-symlink-inside-project
  ✗ [ERROR] file: Change must have at least one delta. No deltas found.
Totals: 20 passed, 1 failed (21 items)
```

- Verdict: P450 定点验收通过；全量 OpenSpec 的上述越界红不作为通过。
- Raw logs: `/var/tmp/p450-acceptance-84bd610a/{receipt.txt,remind-tool-real.log,smoke-init-doctor.log,smoke-67.log}`。两次后台作业 `p450-focused-acceptance`、`p450-section-67` 均 rc=0 并已收割。
- Ledger ban (fixed acceptance line — run it **in your own worktree, on your branch's tree**):

  ```
  $ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev scope=published files=2750 hits=0 names=ok user=resolved
  $ echo $?
  0
  ```

## Doctor and generated-init evidence

完整真实 Pi 运行保留的生成配置仍是模板原形状：

```bash
TEAM_SESSION="p442-config-mismatch"            # tmux session name (...)
TEAM_PM_WINDOW="pm"        # window running the PM; ...
```

同一运行的 mismatch 场景在算出真实 directed launch 后只改配置文件里的 `TEAM_SESSION`，launch 环境仍为 `p442-config-mismatch`，因此不是伪造 tmux/PM 身份。doctor 与未加载扩展的对照为：

```text
PM 提醒工具 ! error PM config TEAM_SESSION does not match the directed launch; ... loaded=<同 disk hash>
PM 提醒工具 ! unknown evidence:ENOENT; at=unknown; loaded=unknown; disk=<同一 hash>
```

原始输出：`/var/tmp/p442-real-evidence-1794470361915/config-mismatch/doctor-*.txt` 与 `noentry/doctor-*.txt`。

## Flip evidence (required for defect-fix tasks)

1. **旧解析函数红 → 修复绿**：快速夹具把当前源码复制到私有临时根，仅将 `configValue()` 换回 V158 的旧实现，对同一组断言求值；首先失败的是 `default generated quoted value with trailing comment`。当前实现同一组断言通过。变异只在临时副本，产品源码未改。
2. **删除 error 证据写入红 → 修复绿**：真实 Pi 夹具复制 skill，只删除初始配置校验 catch 中的 `publish('error', ...)`；真实 `agent_settled` 后，`mismatched config leaves visible error evidence` 按名失败并打印 `EXPECTED RED`。未变异源码在同一完整运行中通过 mismatch 的 status/exposure/reason/doctor/零 Reminder 状态断言，最终 10/0。

## Decisions and deviations

- 没有删除模板注释、迁移真实项目配置或新增配置键；解析只覆盖既有 quoted value 与空白分隔的行尾注释，不 source 项目配置，也不另造通用 shell 解析器。
- 为让 doctor 能报告真正的 SESSION/WINDOW 不匹配，能力检查会先验证错误记录仍属于同一活进程、pane 和 launch，再显示 error；不会把旧记录或死进程记录当作当前错误。
- 测试所需 controlled model 在 `team init` 参数中指定；Pi 路径和离线/夹具参数通过测试环境覆盖。私有 HOME、tmux socket、项目根和证据目录均保留，未接触真实团队或真实模型凭据。
- 未修改 `tasks.md`、BOARD、规格、其他 change；未合并、归档、发布或 push。

## Suggested next steps

- PM 将本分支交 V158 原 verifier：用未修改的 `team init` 配置重跑 AC-02/AC-09，并复核本报告两条红侧与 doctor error。
- `panel-symlink-inside-project` 的空 delta 由其 owner 处理；不要为了让 P450 的全量 OpenSpec 变绿而在本分支补它。
