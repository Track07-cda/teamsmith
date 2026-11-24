# V190 · 0.4.8 提醒到达后，新一轮待命保持开启

agent: verify   status: PASS   time: 2026-11-24T03:09:00Z（测试完成）

branch: `task/V190-release-048-reminder-event`   PR/MR: -

**定点复验通过。** `v0.4.8` 的固定源码真实运行一次 `adversarial-event-after`：Pi 收到一条发给第一轮待命的提醒；系统记录已收到、无法确认与新待命的先后关系，因此第二轮待命仍开启。原场景 `passed=1 failed=0`，测试入口与外围执行均退出 0。

## Deliverables

| 路径 | 内容 |
|---|---|
| `docs/team/reports/V190-verify.md` | 固定版本的独立复验结论、原件位置及执行边界。 |
| `/var/tmp/v190.ZHCs4v/` | 私有原件，待 PM 接收；含原命令、输出、退出码及一套实际 Pi 事件和待命状态。 |

## OpenSpec assessment

`change: -`，这是发布补验，不是新变更验收。只核 `agent-self-reminder` 的 “A newer Standby survives an ambiguous event order” 中事件在 G2 后到达的一侧：原驱动先确认忙碌期间已有 G1 发送记录、但没有提醒事件；手动关 G1 再开 G2，才释放忙碌请求。随后独立读取保存的事件和最终结果，对上同一批次、会话、识别码和提醒 ID。另一侧及相邻场景未运行。

CRITICAL 0 · WARNING 0 · SUGGESTION 0，限本次实跑场景。V174 原全量 `5139/2/19` 的失败记录不变；未重跑全量、自检、其他场景或做新模型行为测试。不据此单独判定可发布。

## Verification evidence

固定只读检出：`/var/tmp/rel048-meta-p490.87ZeWU`。前后 `HEAD` 与 `v0.4.8^{commit}` 均为 `c34e1468ea2ab76bdff9cd2bbef0db650604d151`，`git status --porcelain=v1 --untracked-files=all --ignored` 前后均空（`source.before`、`source.after`）。

实际命令如下，真实 Pi 路径的家目录在公开报告中省略，完整命令见原件 `command`：

```sh
pi='<home>/.bun/bin/pi'
root=/var/tmp/v190.ZHCs4v
src=/var/tmp/rel048-meta-p490.87ZeWU
env -i PATH="$(dirname "$pi"):/usr/local/bin:/usr/bin:/bin" HOME="$root/home" LC_ALL=C \
  TMPDIR=/var/tmp P442_EVIDENCE="$root/evidence" P442_KEEP=1 P442_PI="$pi" \
  bash "$src/skills/teamsmith/tests/remind-tool-real.sh" --select=adversarial-event-after </dev/null
```

`team_bg_run` 作业 `v190-event-after` 启动后结束当轮，完成唤醒后收取，外层 exit=0。实际脚本记录 `03:08:56Z` 开始、`03:09:00Z` 完成。原输出和实码分别保存在 `test.log`、`test.rc`、`outer.rc`：

```text
PASS real Pi busy follow-up emitted after manual G2 keeps the unprovable order boundary
remind-tool-real: passed=1 failed=0 evidence=/var/tmp/v190.ZHCs4v/evidence
kept private fixture root=/var/tmp/v190.ZHCs4v/evidence/run-T6gYK9
remind-tool-real.sh rc=0; boundary diff rc=0
```

| 实际读数 | 原件位置，相对 `/var/tmp/v190.ZHCs4v/` |
|---|---|
| 1 条 `custom_start/team-reminder`，批次 `bat-d1e0cf69-3570-4a8f-84e4-80daa4da7d0b-1`、会话 `01a20b87-2a02-7104-9320-10bbe42b210a`、绑定第 1 代；事件与回执的 `timeline` 完全一致。 | `evidence/adversarial-event-after/events.jsonl`、`receipt.json`，提取结果 `event-check.txt`。 |
| 提醒与批次均为 `observed`；批次 `outcome.standby=generation-ambiguous`；`standby.on=true`、`generation=2`、`reason=G2`。最终状态文件与回执在这些字段上一致；监视日志先记第 1 代 `intent-sent`，再记 `observed` 和同一结果。 | `evidence/adversarial-event-after/receipt.json` 与 `evidence/run-T6gYK9/adversarial-event-after/.pi/team/state/` 下的 `reminders/state.json`、`inbox-watch.log`。 |
| 隔离核对：`env -i` 和私有 HOME；真实 Pi 启动记录指向私有项目、配置及状态，使用 `--offline` 和既有 `127.0.0.1` 测试服务；3 条本机请求，含 1 条提醒请求。Pi 的会话文件在私有目录。结束后私有终端的 socket 文件保留在证据目录内，监听数为 0。 | `command`、`evidence/adversarial-event-after/launch.txt`、`events.jsonl`、`requests.jsonl`、`socket-listeners.txt`。 |
| 真实项目的配置和提醒／待命状态文件前后 SHA-256 相同，旧待命标记前后均不存在；实际所用 Pi 安装入口及目标文件的元数据未变。没有使用真实模型、账号、团队会话或待命命令。 | `boundary.before`、`boundary.after`、空 `boundary.diff`、`boundary.rc=0`，以及上列私有 Pi 路径。 |

Ledger ban（在本人任务工作树，非主检出）：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=3013 hits=0 names=ok user=resolved
rc=0
```

## Flip evidence

本轮没有修复代码或重复运行反例。旧断言受控失败及恢复的独立对照在 `docs/team/reports/V176-verify.md`；本报告只计上述一次未修改的发布源码运行。

## Decisions and next step

仅执行任务书指定场景一次，未改源码、清单或标签，未推送、暂存发布或发布。请 PM 收取 `/var/tmp/v190.ZHCs4v/` 的原件并接入本版已批准的组合证据；收取前保留现场。
