# M56 · watch-degradation 独立复验

agent: verify
status: PASS（无实现阻塞项；性能红线在本机负载前提不成立时按契约 SKIP，未把它误报为回归）
time: 2026-09-21
branch: `task/M56-watch-degradation`
PR/MR: -（local 模式；未 push，分支留在 `.worktrees/verify`）
change: `watch-degradation`（phase: verify；apply 作者为 dev2）

## Verdict

M53 的 watcher 注册失败路径可用且可审计：ENOSPC 被记录、`.reg` 未丢失、轮询在 200ms
配置下单次唤醒，消息形状与正常路径一致；严格模式将同一前提明确判红，而非将其静默跳过。
`team doctor` / `team status` 只将**存活**降级记录报为投递通道降级，并提供配额修复命令。

M50/首帧问题的结论是：**不是 inotify 耗尽造成的 M50 读路径退化。** M53 没有改
`panel/src/data.ts`（首帧调度）；首屏机器块不含 health/doctor；inotify probe 只在 console 的
health reader 中调用。M53 新增的首屏 PM reader 在干净 parent/tip 快照各五次测量的中位数为
`314ms` / `287ms`，远低于 2s，且 tip 未变慢。全首帧配对样本期间宿主 loadavg 均高于性能前提，
因此按门禁契约只记录 SKIP / 环境 observation，未据此声称性能绿或代码红。

## Independent evidence

可复跑包与全部原始输出：`docs/team/reports/M56-verify/pkg/`。

| Check | Independent result |
|---|---|
| `10-fallback.sh` | 从真实扩展的公开 Pi hooks 建立新临时 git 项目；强制 ENOSPC 后 `.reg` 存在，`elapsed_ms=201`，仅一条 wake，且 `customType=team-inbox`、`triggerTurn=true`、`deliverAs=followUp`。账本行含 `errno=ENOSPC watches=unknown/524288 poll_ms=200 fallback=polling forced=1`；`.degraded` 自描述。|
| `20-doctor-states.sh` | 活 pid + `.reg` + `.degraded` 时 doctor/status 均报告降级和 `fs.inotify.max_user_watches=524288` 修法；低余量、runtime unavailable、死 pid 都分别验证。死 pid 后两处均不再报告降级。|
| `30-gate-modes.sh` | `S2` 在不可用前提下显式 SKIP，`S22/S23` 仍 PASS；`TEAM_IW_REQUIRE_WATCH=1` 将同一前提变为非零 `FAIL S2`。真实路径注入 `TEAM_PANEL_CPU_*` 被逐项打印为忽略，未改变读到的真值。|
| `40-preservation.sh` | M53 前后 `team_inbox_watch_route` 与 `team_cmd_standby` 的函数 hash 相同；默认 `DEFAULT_POLL_MS=5000` 相同；健康 harness 覆盖旧 spool 格式、消息形状和去重；隔离项目的 standby on/off 状态循环通过。|
| `50-panel-cause.sh` | 静态首屏调用链与干净快照 PM-reader 对照如上。parent/tip 全首帧器件在负载前提外运行，输出保留但不是性能 verdict。|

### Flip evidence

在 `/tmp` 的扩展副本中仅移除 forced 状态下的 `pollTimer`（真实技能目录通过只读 symlink
保留，避免改变 route fixture）。同一 `ENOSPC` 命令得到：

```text
TEAM-IW-CASE SKIP S2 ... watch unavailable
TEAM-IW-CASE FAIL S23 a forced-failure session still wakes within one poll interval :: messages=0
TEAM-IW-HARNESS FAIL (3)
```

恢复未修改的真实扩展后：

```text
TEAM-IW-CASE SKIP S2 ... watch unavailable
TEAM-IW-CASE PASS S22 ... fallback=polling forced=1
TEAM-IW-CASE PASS S23 ... wakes within one poll interval (200 ms) :: messages=1
TEAM-IW-HARNESS OK (skipped=4)
```

故 SKIP 计数与失败计数独立；watch 不可用不会掩盖 polling fallback 的断言。

## Acceptance commands actually run

```text
$ bash docs/team/reports/M56-verify/pkg/run.sh
== M56 package result == PASS

$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 18 passed, 0 failed (18 items)

$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && \
    bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2721  ✗ 0
smoke 全绿

$ distrobox-host-exec podman run --rm --userns=keep-id --pid=host --cgroups=enabled \
    -e HOME=/tmp -v <independent-clone>:/work:ro -w /work \
    localhost/teamsmith-gate:m51 \
    bash -c 'openspec validate --all --strict && taskset -c 0-3 bash skills/teamsmith/tests/smoke.sh </dev/null'
clone HEAD=74554f7
Totals: 18 passed, 0 failed (18 items)
== 结果 ==  ✓ 2705  ✗ 0
计时断言按负载前提跳过 1 条：27-d 装配红线（loadavg 9.50）
smoke 全绿
```

原始输出位置：

- `pkg/logs/{10-fallback,20-doctor-states,30-gate-modes,40-preservation,50-panel-cause}.log`
- `pkg/logs/60-container-gate.log`（独立 clone + pinned image）
- `pkg/logs/70-openspec-validate.log`、`pkg/logs/70-local-gate.log`

## Scope

仅新增本 agent 所有的 `docs/team/reports/M56-verify.md` 及其 `pkg/` 复验证据。未修改 M53
实现、OpenSpec、PM 文件、main、远端、tmux 实际会话或宿主 inotify 配额。
