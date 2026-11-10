# P443 · 自我提醒的停止恢复与剩余生命周期

agent: dev   status: delivered   time: 2026-11-10T13:50:13Z
branch: `task/P443-remind-recovery-lifecycle`   PR/MR: -

## V151 定点返修结论

W1 与计数建议均已修复：`team_watch_loop_cleanup` 只对预期已退出/被 TERM 的 `kill`/`wait` 写带注释的显式容忍，不再在 `set -e` 下跳过 `team_watch_unlock` 或后续子进程；没有使用 blanket `set +e`。

- 新增两条行为断言：停止后 `watchdog.pid` 不存在，停止前登记的循环自身 `sleep` 全部消失。新版 Pulse 为 11/0。
- `--flip=cleanup` 恢复旧清理后，两条断言同时变红（`W1 failures=2`）：锁文件留下、循环 `sleep` 留下；证据为 `docs/team/reports/P443-dev/pulse-v151-flip-cleanup.log`。
- §68 对 recovery-unit 和 Pulse 改为结果行存在且 ✗0，不钉未来断言总数；当前分别为 20 和 11。
- `smoke.sh --select 68` 及依赖共 12 段、331 条断言全绿（后台 `p443-v151-selected68-r2`，156.6s，rc=0）；另外 128 键未跑。首轮遇到的长 TMPDIR socket 路径问题只涉及夹具，缩短私有 socket 名后同一环境通过。

## 结论

任务书指定的 **2.3.2、4.1.2、4.2、4.3、4.4 已完成**，2.3 与 4.1 的两个父项也按既有子项证据勾选；5.x 和真实模型自主创建均未做。

- 停止的内置 Pi PM 能由提醒恢复：真实参数含 `-c` 和通常 PM 扩展，不含 `@pm-prompt` 或替代初始提示；恢复后的第一个模型回合就是提醒，普通待办没有先执行，续跑会话 ID 不变。
- running/busy/already-starting 不重复启动；quota、identity、missing extension/window、unsupported adapter、start-failed 都有明确非成功结果。只有匹配的 `message_start` 才观察成功并按代次退出 Standby。
- 两种真实 Pulse 形状都能在四秒长巡检期间入队，不重叠执行全巡检；每批 ID 每次全巡检后至多一次恢复复查，停止时子进程全部回收。30 秒是入队目标，不是模型延迟承诺。
- 并发创建、cancel/intent 两种顺序、key 复用、旧 unknown 保留和修剪后迟到事件均有真实状态证据；迟到事件不会合成提醒或复活批次。
- V150 两条建议已落地：stdin 正文拒绝在 `--json` 下返回结构化对象；new/fork/reload 后工具与 doctor 不再沿用 ready。
- 最终相关选段 **18 段、657 条断言全绿**。未跑全量、夜间或 61b。

## Deliverables

| Path | What |
|---|---|
| `scripts/lib/{common.sh,cmd-remind.sh,cmd-watch.sh}`、`scripts/team` | Reminder-only 恢复、现有启动/身份/额度守卫复用、无提示启动、headless Pulse 调度与回收 |
| `extension/{team-inbox-watch.ts,team-remind.ts}` | 观察前抑制普通 backlog；观察允许后恢复；切换/分叉/reload 立即撤下工具证据 |
| `scripts/{remind-store.mjs,remind-tick.mjs,state-authority.mjs,remind-capability.mjs}` | 并发/保留/迟到生命周期、恢复 ID 视图、JSON 拒绝、doctor hidden 状态 |
| `scripts/panel/src/{data.ts,main.tsx}`、`scripts/panel/panel.js` | console Pulse 的非重叠调度、合并恢复与子进程回收；钉住工具链重建产物 |
| `tests/remind-{lifecycle,recovery-unit,recovery-real,pulse}.sh` 及既有真实 Pi 夹具 | 生命周期、恢复拒绝矩阵、两种 Pulse、真实停止恢复与工具撤下 |
| `references/{reminders,migration,workflows}.md` | 无额度、同 key 一次性序列、due≠wake、Standby 歧义、unknown/resolve、停止恢复、flock、升级与回滚 |
| `tests/{smoke.sh,section-paths.tsv}` | 新 §68 与依赖登记；first-order 清单同步 |
| `openspec/changes/agent-self-reminder/tasks.md` | 只勾选本片覆盖项；5.x 保持未完成 |
| `docs/team/reports/P443-dev/` | 脱敏的真实 argv/会话/状态收据、Pulse 红绿输出和选段摘要 |

## OpenSpec assessment

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 本片完成 | 2.3.2、4.1.2、4.2、4.3、4.4 均有实现与实跑；未把 5.x 或自主创建提前勾掉 |
| Correctness | 本片通过 | 生命周期 32、恢复单元 20、Pulse 8、真实恢复 3 组；既有 CLI 112、delivery 94、工具 8 组保持绿 |
| Coherence | 与设计一致 | 一个状态权威、通常 resume 参数、无通用提示、直接 watcher 投递、每批一次代次权利、无新配置/可视化 |

## CRITICAL

None（限本任务书范围）。

## WARNING

None（限本任务书范围）。完整 5.x 故障矩阵和独立复验不在这份作者自验结论内。

## SUGGESTION

None.

## Final assessment

- Counts: CRITICAL 0 · WARNING 0 · SUGGESTION 0。
- Readiness: 本片可交非作者复验；不表示整个 change 可验收或归档。
- Unverified applicable checks and reasons: 5.1–5.5 未做；真实模型自主创建/连续自主唤醒未做；全量、夜间、61b 按任务书明确不跑。

## 真实停止恢复证据

证据目录 `docs/team/reports/P443-dev/` 保存了脱敏后的真实参数与状态。`recovery-argv.json` 依次含：

```text
--provider p442 --model controlled
-e …/team-bg.ts -e …/team-inbox-watch.ts -e …/team-reply.ts -e …/team-remind.ts
--skill …/teamsmith -c --offline --no-extensions --no-skills --no-context-files -e …/remind-tool-provider.ts
```

数组中没有任何以 `@` 开头的参数，也没有 `pm-prompt`。`recovery-receipt.json` 记录 `genericTurns: 0`、`ordinaryBacklogTurns: 0`，恢复前后 `seedSession == recoveredSession`；最终两条提醒都为 `observed`，Standby 已按匹配事件退出。

实际命令与结果：

```text
$ bash skills/teamsmith/tests/remind-recovery-real.sh
PASS real Pi stopped PM resumes without a generic prompt; Reminder arrives before ordinary backlog
PASS real Pi new: invalid replacement session immediately loses ready evidence
PASS real Pi fork: invalid replacement session immediately loses ready evidence
remind-tool-real: passed=3 failed=0 evidence=/var/tmp/p443-dev/final-real-evidence
rc=0（后台作业 p443-recovery-real7，16.6s）
```

忙碌回合的第二次恢复决策没有 `result=started`，`pm-restarts.log` 逐字节不变且 PID 不变。`result=started` 只表示取得启动证明，没有被当成提醒送达；最终状态由匹配事件写成 `observed`。

## 两种 Pulse

`tests/remind-pulse.sh` 驱动真实 headless `team watch` 循环和真实 console bundle，给全巡检注入四秒执行时间：

```text
PASS headless: due queued during long patrol; one recovery followed before the next patrol
PASS console: due queued during long patrol; one recovery followed before the next patrol
  ✓ headless 第一次长巡检与第二次巡检之间恰有一次恢复
  ✓ headless 停止后巡检与其外部子进程都已回收
  ✓ console SIGTERM 后退出并执行清理
  ✓ console 停止后巡检与其外部子进程都已回收
== remind-pulse 结果 == ✓8 ✗0 SKIP0
```

入队发生在四秒巡检窗口内，满足正常 30 秒入队目标；没有使用模型延迟充当保证。普通巡检优先，避免持续拒绝的恢复挤占所有空档；同一批 queued ID 在每次全巡检后至多复查一次。

## 生命周期与 V150

- 8 个真实并发写者提交同 key 全文请求，只得到一个 ID 和固定 due；4 个冲突写者全部 `key-conflict`。取消后 4 个并发复用者只得到一个新的单调 ID，旧 cancelled 保留，正文及结尾换行逐字节一致。
- cancel 先于 intent 时，B 被取消且不在消息中；intent 先提交时，cancel 返回 `in-flight`，批次成员与 unspent right 不变。
- 1005 个新终态批次触发修剪后，旧 unknown 与 unspent right 保留，批次总数为 1001（1000 终态 + 1 unknown）；其迟到事件可观察一次，重放只报 duplicate。另一个已修剪批次返回 `history-pruned`，没有新增提醒或批次序号。
- NUL 与非 UTF-8 的 `--json` 拒绝均 rc=1、`refusal=bad-message`，stdout 可 `JSON.parse`，快照不变。
- new/fork 进入无效替换会话后，工具为 hidden、active 列表为空；doctor 当场不再报 ready，不等 20 秒 TTL，Reminders 快照逐字节不变。

## 验收命令（实际执行）

```text
$ bash skills/teamsmith/tests/remind-cli.sh
== remind-cli 结果 == ✓112 ✗0 SKIP0

$ bash skills/teamsmith/tests/remind-delivery.sh
== remind-delivery 结果 == ✓94 ✗0 SKIP0

$ bash skills/teamsmith/tests/remind-lifecycle.sh
== remind-lifecycle 结果 == ✓32 ✗0 SKIP0

$ bash skills/teamsmith/tests/remind-recovery-unit.sh
== remind-recovery-unit 结果 == ✓20 ✗0 SKIP0
```

最终相关选段（后台作业 `p443-selected-gates`，353.2s，rc=0）：

```text
$ bash skills/teamsmith/tests/smoke.sh --select 3,6i,7,11b,26,65,66,67,68 </dev/null
#17 67 · ✓8 ✗0（CLI 112 / delivery 94 / PM 工具真实 Pi 8 组）
#18 68 · ✓6 ✗0（lifecycle 32 / recovery unit 20 / Pulse 8 / 真实恢复 3 组）
账本自查：18 段收口 · 增量 ✓657 ✗0 SKIP0 ｜ 结果行 ✓657 ✗0 —— 一致
== 选段结果 == ✓657 ✗0
```

未跑的另外 122 个键记录在 `docs/team/reports/P443-dev/selected-summary.txt`；选段不是全套门禁。

```text
$ "$HOME/.bun/bin/openspec" validate --all
Totals: 20 passed, 0 failed (20 items)（既有长 Requirement 警告）

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14088 effective line(s); retired 0; undeclared 0

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 == ok 13 bad 0 SKIP 1

$ git diff --check
rc=0
```

面板产物使用 `"$HOME/.bun/bin/bun" install --frozen-lockfile` 和 `PATH="$HOME/.bun/bin:$PATH" bash build.sh` 重建；最终 §26 的沙盒重建一致性检查随选段通过。

- Verdict: 上述命令均实际运行并通过；本报告是 apply 作者证据，不代替非作者复验。
- Ledger ban: 见下方实际输出。

## Flip evidence

```text
--json 拒绝退回人读行
  → JSON.parse 失败，B 的结构化拒绝断言会红；恢复后 CLI 112 绿
去掉活跃 key 检查
  → 同 key 分出两个 ID，A 的并发断言会红；恢复后 lifecycle 32 绿
修剪丢掉 unknown
  → 旧活跃记录被删除，C 的保留断言会红；恢复后旧 unknown/right 保留
```

Pulse 的真实红绿：`docs/team/reports/P443-dev/pulse-before-priority.log` 记录恢复持续占用空档、第二次全巡检未出现；改为普通巡检优先并按 queued ID 合并复查后，`pulse-final.log` 两种形状均通过，且每次巡检之间恰有一次恢复。

```text
before: == remind-pulse 结果 == ✓7 ✗1（第二次巡检未出现）
after:  == remind-pulse 结果 == ✓8 ✗0
```

## Decisions and deviations

- 持续存在的 queued ID 不再每秒触发恢复：每批 ID 每次全巡检后至多一次；新 ID 或下一次全巡检才重新武装。这保留合并复查语义，同时避免普通巡检被恢复饿死。
- 真实参数不能从 `/proc/<pid>/cmdline` 读取（Pi 会把标题改写成 `pi`），所以真实 Pi 夹具在私有启动入口记录 argv 后原样 exec；没有改产品启动参数。
- 未操作真实团队的 PM/Pulse/Standby，未修改主检出代码、真实模型或凭据。所有真实 Pi 验证均为私有 tmux、私有 HOME、controlled loopback provider。

## Suggested next steps

由非作者复验本分支。5.x 完整对抗验收和单独授权的真实模型自主创建另行执行；不合并、不归档、不发布。

## Ledger ban

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev scope=published files=2612 hits=0 names=ok user=resolved
rc=0
```
