# P494 · 两项提醒诊断测试改用正式 PM 启动

agent: dev-bob   status: DELIVERED（作者静态检查通过；待独立实跑）   time: 2026-11-24 UTC
branch: `task/P494-ci-reminder-formal-test-launch`   PR/MR: -

**只改两项测试的启动，未改产品。** `pm`、`noentry` 在私有 tmux 中调用 `team_pm_start`，由产品写入 PM 登记；`noentry` 从实际命令里去掉提醒入口，不是屏蔽 `doctor` 或伪造证据。原有 `ready`、`unknown evidence:ENOENT`、真实退出后的 `not-running` 断言均未改。候选提交 `acf2f86c` 已做语法及范围检查，未启动 Pi。

## 交付与边界

| 路径 | 交付 |
|---|---|
| `skills/teamsmith/tests/remind-tool-real.mjs` | 两例复用原私有 tmux、回环模型和测试回执；其它场景仍走原 `launch.sh`。新增 `--select=noentry` 可与 `pm` 一起单独运行；默认 `doctor` 组仍跑原四例。 |
| `docs/team/reports/P494-dev-bob.md` | 作者检查、P493 对照和独立复验范围。 |

正式启动之前仍把 `pm.pid.spawn` 路径交给原清理程序；启动失败保留 `formal-start.txt` 和产品生成的 `pm-launch-failed.log`（若有）。若登记成功但在 `session-start` 前退出，从已登记 PID 和私有窗口取退出信息，不另写 `done` 或 PID。正常停止仍走原 `stopPi`，该函数此前已能等待没有 `done` 回执的正式启动进程；本单不改停止和 shell 清理代码。

OpenSpec 锚点：`agent-self-reminder#PM tool availability is honestly diagnosed`（`spec.md:158`）。未创建变更或改规格；仅更正测试准备方式。源码范围审查未见超出任务书的产品变更；本次不能据静态检查给出运行结论。无偏离任务书的运行或环境写入。无推送、无 CI 重跑、无全局安装改动。

## 作者检查

```text
$ node --check skills/teamsmith/tests/remind-tool-real.mjs
node --check: rc=0
$ node --input-type=commonjs <<'NODE'  # 只展开 startRegistered 内的两个 Bash 模板，分别传给 bash -n；不执行模板
embedded bash -n (pm): rc=0
embedded bash -n (noentry): rc=0
static scope: two opt-ins; pm/noentry assertions, other scenario bodies and stop(info) unchanged
$ git diff --check HEAD  # 提交候选前，并确认唯一改动路径为 remind-tool-real.mjs
git diff --check and changed-path check: rc=0
```

范围比对使用 `git show HEAD:skills/teamsmith/tests/remind-tool-real.mjs` 的基线正文：两例断言段、其余场景主体和 `stop(info)` 逐字节相同，只有两个调用传 `formalStart: true`。未运行本候选的两例、启动失败或信号中断场景，也未运行整组测试或全量检查；任务书把运行验证留给独立复验者。

### 账本检查

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev-bob scope=published files=3029 hits=0 names=ok user=resolved
ledger-ban rc=0
```

## 修复前后对照与独立复验

P493 已在同一 npm Pi 1.6.0 布局验证启动方式的影响，见 [P493-dev-bob.md](P493-dev-bob.md) 和已保存的原件；以下是 **P493 实验**，不是 P494 候选实跑：

```text
mode=original rc=1
remind-tool-real: passed=0 failed=2
mode=formal rc=0
remind-tool-real: passed=2 failed=0
```

P493 中，原路径两例同报 `not-running (unknown:sh)`；正式启动分别报 `ready extension reported registered/active`、`unknown evidence:ENOENT`，`pm` 实际退出后报 `not-running (missing)`。复验者在相同 npm Pi 布局下仅需运行 `bash skills/teamsmith/tests/remind-tool-real.sh --select=pm,noentry`，为每例保留真实 pane、`session-start`、`pm.pid.spawn`、`pm.pid`、`pm.pid.proof`、`pm-launch.env` 和 `doctor` 的读数；核两例未使用 `launch.sh`，`noentry` 实际未加载提醒入口，确认退出后不再有本轮 Pi 或私有 tmux。使用 `P442_EVIDENCE` 和 `P442_KEEP=1` 可保留现场供复验，保留的目录不等于进程仍在运行。

### P493 原临时目录清理回执

仅清理自建宿主目录 `/var/tmp/p493-bob.ECoUS5`。当时目录只剩单个压缩包；宿主 `lsof -nP +D` 未列任何打开项（退出 `1`，另有无关 btrfs 路径告警），宿主 Podman 按挂载路径过滤无运行实例。先 `cmp` 核对保存原件，再逐个删除压缩包、空目录并通过 `test ! -e`。留存文件 `.pi/team/state/release-0.4.8/p493/P493-evidence.tar.gz` 的 SHA-256 仍为 `dd4ccb196c0a14baff66836dfff0e7f2d980aa74318a507d5bb51f9602e9b87f`。
