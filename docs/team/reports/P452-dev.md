# P452 · 修复停止 PM 恢复场景 argv.bin 缺失

agent: dev   status: DELIVERED（任务内验收完成；全量 OpenSpec 有一项既有越界红）   time: 2026-11-13T05:40Z
branch: `task/P452-reminder-recovery-argv`   PR/MR: -

## 根因与结论

根因在 P450 对真实 Pi 夹具的改动，不在 PM 启动或 Reminder 产品逻辑。`730d906e` 给 `info.env` 增加了 `TEAM_PI_BIN: pi`；停止恢复场景随后只把配置文件中的 `TEAM_PI_BIN` 改为 argv 包装脚本，但 `team_load_config` 明确规定环境变量覆盖配置文件，`recover()` 又把同一份 `info.env` 发布到私有 tmux。因此恢复实际执行的仍是原始 `pi`，包装脚本没有运行，测试读取 `argv.bin` 时得到 ENOENT。

原始发布现场已经证明产品行为本身成功：`recovery/recovery-1794540136545.txt` 为 `result=started`，`events.jsonl` 有第二个 `session_start` 和 `customType=team-reminder`，`requests.jsonl` 的恢复请求只含 `P443_RECOVERY_ONLY`。失败发生在产品行为之后的参数采集读取。

修复只在夹具切换可执行文件时同步 `info.env.TEAM_PI_BIN = wrapper`，使配置与环境指向同一个包装脚本。没有修改产品脚本、启动等待时间、Reminder 语义或规格。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/remind-tool-real.mjs` | 同步恢复场景的 `TEAM_PI_BIN` 环境覆盖与配置文件，让真实恢复 argv 经过既有采集包装脚本 |
| `docs/team/reports/P452-dev.md` | 根因、红绿、反向改坏、真实启动证据和验收边界 |

产品源码差异为零；本任务提交 `3c4b3da3 test(P452): route recovery argv through fixture wrapper`。

## OpenSpec assessment

这是既有 `pm-lifecycle` 行为的夹具修复，没有规格变化，也没有新 delta。相关规格单独验证有效；全量 `--all` 的既有越界红列在 WARNING。

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | PASS | 改前同场景红、改后绿；真实工具、真实恢复、恢复单元及 §67/§68 均已运行 |
| Correctness | PASS | argv 无 `@`/`pm-prompt`，含 `-c` 与两个既有扩展；会话不变，Reminder 先于普通积压；删除修复行后同场景重新红 |
| Coherence | PASS | 遵循 `team_load_config` 的既有环境优先规则；`openspec validate pm-lifecycle --type spec` 有效，规格无需改动 |

## CRITICAL

None。

## WARNING

- 全量 `openspec validate --all` 为 20 passed / 1 failed：既有 `change/panel-symlink-inside-project` 没有 delta。该目录归 PM，且与本夹具修复无关；本任务未修改它。相关 `pm-lifecycle` 规格单独验证通过。原始输出在 `/var/tmp/p452-acceptance.UmCjQJ/openspec.log`。

## SUGGESTION

None。

## Final assessment

- Counts: CRITICAL 0 · WARNING 1 · SUGGESTION 0。
- Readiness: 可以交非作者做定点复验；本报告不宣称全量 OpenSpec 或全量 smoke 通过。
- Unverified applicable checks and reasons: 按任务书未跑全量 smoke、夜间或 61b。§67/§68 选段另有 129 个键未运行，完整名单保存在 `/var/tmp/p452-acceptance.UmCjQJ/smoke-67-68.log`；选段不等于全套门禁。未运行 strict OpenSpec，本仓当前门禁为普通 `--all`。

## 原始错误与独立改前复现

发布原始日志 `/var/tmp/rel47-first-order.log`：

```text
✗ P443 真实 Pi 恢复夹具红（rc=1）
FAIL real Pi stopped PM resumes without a generic prompt; Reminder arrives before ordinary backlog:
Error: ENOENT: no such file or directory, open '/var/tmp/p442-real-evidence-1794540132695/recovery/argv.bin'
remind-tool-real: passed=2 failed=1 evidence=/var/tmp/p442-real-evidence-1794540132695
```

未修改代码上的独立复现：

```text
$ P442_EVIDENCE=/var/tmp/p452-before.j04E5q node skills/teamsmith/tests/remind-tool-real.mjs --select=recovery
FAIL real Pi stopped PM resumes without a generic prompt; Reminder arrives before ordinary backlog:
Error: ENOENT: no such file or directory, open '/var/tmp/p452-before.j04E5q/recovery/argv.bin'
remind-tool-real: passed=0 failed=1 evidence=/var/tmp/p452-before.j04E5q
rc=1
```

该改前现场同样留下了真实 `result=started`、第二次 `session_start` 和受控 Reminder 响应；不是产品没有启动。

## 改后真实 argv / session / state

```text
$ P442_EVIDENCE=/var/tmp/p452-after.l4Gxkd node skills/teamsmith/tests/remind-tool-real.mjs --select=recovery
PASS real Pi stopped PM resumes without a generic prompt; Reminder arrives before ordinary backlog
remind-tool-real: passed=1 failed=0 evidence=/var/tmp/p452-after.l4Gxkd
rc=0
```

`/var/tmp/p452-after.l4Gxkd/recovery/recovery-argv.json` 记录的真实参数包含 `--provider p442`、`--model controlled`、`-c`、`team-inbox-watch.ts` 与 `team-remind.ts`；没有任何以 `@` 开头的参数，也没有 `pm-prompt`。

同目录 `recovery-receipt.json` 记录：

```text
seedSession == recoveredSession: true
genericTurns: 0
ordinaryBacklogTurns: 0
standby.on: false
standby.generation: 1
recovery Reminder: observed
busy follow-up Reminder: observed
```

## Verification evidence (must have actually been run)

以下命令均在本任务分支实际执行；原始日志统一位于 `/var/tmp/p452-acceptance.UmCjQJ/`。

```text
$ bash skills/teamsmith/tests/remind-tool-real.sh
PASS real Pi PM add/list/show/cancel, retry, observed same-key renewal and no-key IDs
PASS real Pi 64 KiB plus final newline through real PM tool add/show/list/cancel
PASS real Pi ordinary: globally loaded copy stays hidden with zero Reminder state
PASS real Pi worker: globally loaded copy stays hidden with zero Reminder state
PASS real Pi forged: globally loaded copy stays hidden with zero Reminder state
PASS real Pi reload into an invalid pane hides all actions without changing Reminder state
PASS real Pi running PM with no entry is unknown, not a load failure
PASS real Pi generated config mismatch hides the tool and leaves a specific doctor error
PASS real Pi flip: deleting config-error evidence turns the named visibility assertion red
PASS real Pi explicit bootstrap failure is error while fresh
remind-tool-real: passed=10 failed=0 evidence=/var/tmp/p452-acceptance.UmCjQJ/tool-real

$ bash skills/teamsmith/tests/remind-recovery-real.sh
PASS real Pi stopped PM resumes without a generic prompt; Reminder arrives before ordinary backlog
PASS real Pi new: invalid replacement session immediately loses ready evidence
PASS real Pi fork: invalid replacement session immediately loses ready evidence
remind-tool-real: passed=3 failed=0 evidence=/var/tmp/p452-acceptance.UmCjQJ/recovery-real

$ bash skills/teamsmith/tests/remind-recovery-unit.sh
== remind-recovery-unit 结果 == ✓20 ✗0 SKIP0

$ bash skills/teamsmith/tests/smoke.sh --select 67,68 </dev/null
#11 67 · ✓8 ✗0 SKIP0
#12 68 · ✓8 ✗0 SKIP0
账本自查：12 段收口 · 增量 ✓331 ✗0 SKIP0 ｜ 结果行 ✓331 ✗0 —— 一致
== 选段结果 == ✓331 ✗0

$ "$HOME/.bun/bin/openspec" validate pm-lifecycle --type spec
Specification 'pm-lifecycle' is valid

$ "$HOME/.bun/bin/openspec" validate --all
✗ change/panel-symlink-inside-project
  ✗ [ERROR] file: Change must have at least one delta. No deltas found.
Totals: 20 passed, 1 failed (21 items)
rc=1（上述既有越界红）

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14242 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 == ok 13 bad 0 SKIP 1
（internal 检出没有机器生成的 .pi/skills；其余 731 条字面模式在位）

$ node --check skills/teamsmith/tests/remind-tool-real.mjs
rc=0

$ git diff --check
rc=0
```

- Verdict: 任务相关行为与静态检查通过；全量 OpenSpec 只有上述既有越界红。
- 后台作业 `p452-acceptance` 已收割。它的总 rc=1 来自最后执行的全量 OpenSpec；在此之前，真实工具 10/10、真实恢复 3/3、恢复单元 20/20 和选段 331/0 均已各自成功。后续缺失的静态命令已单独补跑。
- Ledger ban（最终报告写入后在本工作树运行）：

  ```text
  $ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev scope=published files=2763 hits=0 names=ok user=resolved
  rc=0
  ```

## Flip evidence

改前红 → 改后绿见上两节。另在 `/var/tmp/p452-flip.9DJVyU/teamsmith` 的独立副本中只删除新增的 `info.env.TEAM_PI_BIN = wrapper`，工作树不变，再跑同一场景：

```text
$ P442_EVIDENCE=/var/tmp/p452-flip.9DJVyU/evidence node /var/tmp/p452-flip.9DJVyU/teamsmith/tests/remind-tool-real.mjs --select=recovery
FAIL real Pi stopped PM resumes without a generic prompt; Reminder arrives before ordinary backlog:
Error: ENOENT: no such file or directory, open '/var/tmp/p452-flip.9DJVyU/evidence/recovery/argv.bin'
remind-tool-real: passed=0 failed=1 evidence=/var/tmp/p452-flip.9DJVyU/evidence
EXPECTED RED rc=1: removing the environment synchronization restores the argv.bin failure
```

这证明失败没有被吞，新增同步赋值是该场景从红到绿的承重变化。原始日志为 `/var/tmp/p452-flip.9DJVyU/flip.log`。

## Decisions and deviations

- 只修夹具环境覆盖，不改产品：原始与改前现场均显示 PM 已恢复，且 P450  diff 直接引入了覆盖包装脚本的环境变量。
- 全量 OpenSpec 的既有越界红如实保留，没有为追求总 rc=0 修改 PM 所有的 change 目录。
- 所有真实 Pi/tmux 运行均使用夹具新建的隔离项目、私有 HOME、私有 socket 和 controlled loopback provider；未操作真实团队 PM、Pulse 或 Standby。

## Suggested next steps

由非作者在独立检出复验同一停止恢复场景及 §67/§68；全量 OpenSpec 的 `panel-symlink-inside-project` 既有红由 PM 另行处理，不属于 P452。
