# P203 · P201 发送者身份独立验证

agent: verify   status: PARTIAL   verdict: 任务行为范围 PASS / 规范一致性 BLOCKED   time: 2026-10-03T06:06Z
branch: `task/P203-verify`   PR/MR: -（local 模式，不 push）
被测源码：`05b90f4aba65999ca4c95919e31019044e094344`（P201 已合入的版本）
change: -（infra verify；没有可核对的 proposal/delta/tasks）

## Deliverables

| Path | 内容 |
|---|---|
| `docs/team/reports/P203-verify/pkg/check.py` | 自造 git 项目、名册、worktree 与容器内真实 tmux pane；16 格 CLI 断言 |
| `docs/team/reports/P203-verify/pkg/run.py` | 两种源码影子、实际非零断言进程、原版还原与 SHA256 校验 |
| `docs/team/reports/P203-verify/pkg/{gates,probes}.sh` | 独立 clone 的串行门禁与容器探针入口 |
| `docs/team/reports/P203-verify/pkg/README.md` | 可复跑方法、夹具边界、失败方法记录 |
| `docs/team/reports/P203-verify/logs/` | 原始 stdout/stderr、每格退出码/文件快照、变异锚点/源码哈希、门禁全文 |

没有改实现、spec、任务书或其他席位文件，没有切分支、merge、远端操作或宿主 tmux 探针。所有后台作业均已收齐；本地分支保留供 PM 复验。

## 结论

任务书第 1–5 项的行为与命令全部通过。主检出里的名册席位线索确实拒绝，拒绝时 inbox/state 的文件路径清单和全部内容哈希均不变；非名册名字不误拒；显式声明保留告警且记录正确作者；席位工作树仍按目录署名。两种影子分别打红对应断言，还原后全绿。

**仍有一个 finding：现行主 spec 未表达 P201 的新例外（F1）。** 这是规范与已批准行为的漂移，不是上述实现行为失败。没有把“格式校验通过”当作语义一致的证明；需要 PM 处置后才能给无保留的整体 PASS。

## Verification evidence（实际已执行）

工作树内启动命令：

```sh
bash -n docs/team/reports/P203-verify/pkg/{probes,gates}.sh
python3 -m py_compile docs/team/reports/P203-verify/pkg/{check,run}.py
bash docs/team/reports/P203-verify/pkg/gates.sh
bash docs/team/reports/P203-verify/pkg/probes.sh
```

两个 wrapper 均由 `team_bg_run` 启动、`team_bg_wait` 收齐，最终各 exit 0。门禁 wrapper 耗时约 1494 秒。被测 clone 与源码 revision 相同，见 `logs/gate-meta.log`。镜像 ID：`1d723525ee58a8b177862746bc92cde2307a7d5f8a76045f5641703d8ac1a50b`。

### 独立行为表

未借用 PM/P201 的 probe，也没有用产品 flip 包替代独立证据。名册是 `dev dev2`；实际查询容器内真实 pane（构造的 `TMUX`/`TMUX_PANE` 上下文），每格重新清空历史投递记录并放入非空 inbox sentinel。

| 调用上下文 | 真实结果 |
|---|---|
| 主检出，无任何线索 | exit 0，追加一行 `agent:pm` |
| 主检出，`TEAM_AGENT=dev2` | exit 1，零写入；点名目录 pm/线索 dev2 与两条出路 |
| 主检出，本项目窗口 dev2 | exit 1，零写入；同上 |
| 主检出，窗口 dev + `TEAM_AGENT=dev2` | exit 1，零写入；两个冲突线索均点名 |
| 主检出，`TEAM_AGENT=dev2` + `--from dev2` | exit 0，`agent:dev2`；保留与目录不一致的告警 |
| 主检出，窗口 dev2 + `--from dev2` + 可写监视通道 | exit 0，`agent:dev2`；告警保留，真实 `.wake` spool 同名 |
| 主检出，席位线索 + `--from pm` | exit 0，显式声明仍按 pm 记录 |
| 主检出，`TEAM_AGENT=nosuch` | exit 0，`agent:pm`；点名被忽略的继承值 |
| 主检出，本项目窗口 nosuch | exit 0，`agent:pm` |
| 主检出，`TEAM_AGENT=pm` / 本项目窗口 pm | 各 exit 0，`agent:pm` |
| 主检出，另一私有会话的窗口 dev2 | exit 0，`agent:pm` |
| `.worktrees/dev2`，无任何线索 | exit 0，`agent:dev2` |
| `.worktrees/dev2`，窗口 pm | exit 0，`agent:dev2` |
| `.worktrees/dev2`，窗口 dev + `TEAM_AGENT=dev` | exit 0，`agent:dev2` |
| `.worktrees/dev2/sub`，窗口 pm + `TEAM_AGENT=pm` | exit 0，`agent:dev2` |

原始输出尾部（`logs/independent-driver.log`）：

```text
== P203 oracle == PASS=16 FAIL=0
original: assertion-process-exit=0; expected=0
== P203 independent package == failed=0
```

拒绝格开启了 `TEAM_NOTIFY_TMUX=1`，并具备活的、可写的合成监视注册；显式声明格会实际写 `.wake`，证明拒绝格的“无 wake”不是关闭投递造成的空转。快照范围包含 inbox、spool、队列和 delivery 日志。注册由自己 spawn 的 sleep PID 支撑，不是实际 Pi watcher；并未证明 wake 被 Pi 消费。

### 容器门禁

实际串行执行：

```sh
openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 47 </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
```

```text
validate: Totals: 13 passed, 0 failed (13 items); exit=0
select-47: 47 段 ✓70 ✗0 SKIP0；含前导合计 ✓91 ✗0；exit=0
FAST: 123 段；✓3820 ✗0 SKIP36；exit=0
smoke 全绿
```

`logs/select-47.log` 完整打印了 **118 个未选段键**（从 0e 至 59，具体清单原样保留）；选段运行不是全套。另跑的 FAST 全套仍有 **36 个显式跳过的真进程场景**，清单在 `logs/fast.log` 的结束行及 `logs/fast-skips.log`。这些包含真正的 dispatch/PM/worker 启动、pulse/close/resume、live-pane 守卫排水、私有 server 生死、面板与会议 tmux 路径。不能把此结果称为非 FAST 全量门禁或性能结果。

## Flip evidence

只修改容器里自己复制的 skill 影子。`logs/independent/mutations.json` 保留逐字变异，两个锚点各命中一次，变异后 SHA256 不同且 `bash -n` 为 0。

1. **silent-pm 影子**：将主检出的冲突拒绝分支置为永不成立。真实窗口/环境席位两格都返回 success 并写 `agent:pm`，所以两格断言进程真正非零；无线索和 pm 窗口对照仍绿。
2. **no-roster 影子**：仅删除窗口与环境的两处 `team_agent_known` 条件。nosuch 两格被误拒，两个接受断言均红；无线索与真实席位拒绝对照仍绿。
3. **还原**：同组断言改用未变异原版，两个进程均 exit 0。原 `common.sh` 前后哈希同为 `ec567584c6b755571d0b422feb0e9399dc8f4794ed343170c431cd92699c1d2f`。

```text
FAIL main-env-seat: refusal returned success; refusal wrote inbox/state; ...
FAIL main-window-seat: refusal returned success; refusal wrote inbox/state; ...
== P203 oracle == PASS=2 FAIL=2
shadow-silent-pm: assertion-process-exit=1; expected=1
== P203 oracle == PASS=4 FAIL=0
restore-conflict: assertion-process-exit=0; expected=0
FAIL main-env-unknown: accepted call returned nonzero; ...
FAIL main-window-unknown: accepted call returned nonzero; ...
== P203 oracle == PASS=2 FAIL=2
shadow-no-roster: assertion-process-exit=1; expected=1
== P203 oracle == PASS=4 FAIL=0
restore-roster: assertion-process-exit=0; expected=0
```

## Findings / BLOCKED

### F1 · 主 spec 对主检出与继承线索的承诺仍是修复前口径

`openspec/specs/notify-and-inbox/spec.md:534–541` 仍写主工作树解析成 pm、继承 `TEAM_AGENT` 分歧时目录赢。`:584–587` 的 PM 场景也没有“无线索”的前提。这无法表达 P201 本轮测到的主检出 + `TEAM_AGENT=dev2` → exit 1、零 inbox/state 写入。

证据：`logs/spec-contract-excerpt.log` 和 `logs/independent/original/main-env-seat.{json,log}`。P201 修改了说明文档和代码，但未同步这个规范例外；本任务没有 delta，也无 spec 写权限。

**BLOCKED: 请 PM/规范 owner 将已批准的主检出冲突拒绝例外、名册命中和窗口会话限定同步到该 Requirement/scenarios，或明确记录为何现行规范可包含此例外；不要为了对齐旧文字撤回已通过的新行为。** 格式门禁虽绿，此 finding 仍需关闭。已用 `TEAM_NOTIFY_TMUX=0` 通知 PM（durable inbox only，不触碰宿主 tmux）。

## Decisions and deviations / 未测范围

- 主树任务书未出现在 dispatch checkout 中，按派单明确提供的绝对路径只读读取；没有修改主 worktree。
- 第一次后台门禁启动在 shell 重定向阶段失败（logs 目录不存在），未跑任何门禁；创建目录后重跑，记录在 `logs/launcher-error.log`。
- 独立探针首次的额外正对照误读 `.inbox` 而非真实 `.wake`，因此 15/16，属于验证方法错误。原始错误运行完整保留于 `logs/independent-first-method-error*`；修正 harness 后 16/16，不曾改产品去换绿。
- 没有非 FAST 全量门禁、性能测量、生产/共享 session 演示、交互式 Pi 执行、真实 watcher 消费、`[auto]` 扩展身份格、新的并发竞态或发布验证。没有宣称本结果覆盖这些边界。
- 门禁与探针复用源码 revision 固定的独立 clone；后续提交只含本报告与证据。此结果不代表之后 main 的门禁结论。
- 线程中的旧 P194 清理要求在本轮 baseline 已满足：`.gitignore`、包与日志已受版本控制，无 `.runtime` 目录；未额外修改该包。

## Suggested next steps

PM 独立复跑本包、关闭 F1 的规范对齐项，再决定后续收口。verify 只交证据，不修改规范或归档。可重建 `.scratch` clone 在所有作业收齐后删除；复跑入口见包内 README。
