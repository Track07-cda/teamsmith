---
id: P420
title: 派单的身份必须来自 root，不是继承的 TEAM_STATE_DIR；守卫不许只警告却回非零
agent: dev2
category: code
phase: apply
change: -
specs: dispatch
anchor: openspec/specs/dispatch/spec.md
deltas: -
branch: task/P420-dispatch-state-identity
---

# P420 · 两条，都有现场

## 现场 A：沙盒里的派单读到了**真实项目**的状态

`bash skills/teamsmith/tests/smoke.sh --select 6 --keep`，沙盒 repo 在
`/var/tmp/teamsmith-smoke-pm_skills-deb708fe.fk01t4/repo`，但 `dispatch-dirty.log` 报的是：

```
✗ 拒绝派单：dev 上还有一个没结束的任务（P417）
✗   分支：task/P417-mark-loaded-at-launch（工作树 /home/<user>/…/pm-skills/.worktrees/dev 还停在它上面）
```

P417 是**真实项目里在飞的任务**，沙盒里根本没有它。PM 会话的环境里有
`TEAM_STATE_DIR=/home/<user>/…/pm-skills/.pi/team/state`，而这几个断言跑 `$TEAM dispatch … --root "$REPO"` 时，
身份仍按继承的 `TEAM_STATE_DIR` 解析，于是读到真实席位记录。

要做的：派单（以及所有需要项目身份的路径）**按 root 解析状态目录与席位记录**，继承来的 `TEAM_STATE_DIR`
与本项目不一致时按「继承被忽略」处理（其它命令已经有这条告警，`team paths` 那套是现成的判据），不许静默采用。
红侧：沙盒里放一个假的 `state/dev.env` 说 dev 有在飞任务 → 必须按它判；把真实项目的 `TEAM_STATE_DIR` 注进来 →
必须仍按沙盒判（并打一行说明继承被忽略）。

## 现场 B：一个守卫只写了「警告」，却把派单判成阻塞

同一选段里 `print-branch.log` 末尾：

```
! TEAM_PI_BIN 不是绝对路径（pi）：窗口里可能 PATH 未就绪，建议写死绝对路径
✗ 共 1 个阻塞项 —— 修好上面每一项后重新派单（--force 只覆盖允许覆盖的项）
```

`!` 是 `team_df_warn`（说明），阻塞项是 `team_df_err`（✗）+ `_TEAM_DF_N`。也就是说某个守卫**返回了非零却没有
任何 ✗ 行**，report 只把警告重放出来，于是人看到「共 1 个阻塞项」却找不到是哪一项。

要做的：`team_df_run` / `team_df_run_lib` 在 `rc != 0` 且该次守卫**没有产出任何 ✗ 行**时，补一条显式阻塞行
（例如 `✗ <守卫名>：判不了（rc=N），没有任何具体原因`）——判不了就是阻塞，但不许无声。红侧：造一个只 warn 后
`return 1` 的守卫 → 断言必须出现那条补行；`return 0` 时不得出现。

## 边界

只改 `scripts/lib/cmd-agents.sh`（若身份解析在别处，允许动那一处并说明）、相关夹具与 `openspec/specs/dispatch/spec.md`。
不改 smoke 的选择器与锁；不跑全量 smoke（选段 6 即可，另加你改到的面）。

## 验收

- `bash skills/teamsmith/tests/smoke.sh --select 6 --keep </dev/null`（改前 41 红，改后应明显不同；把改前/改后的段结果行都贴出来）
- `openspec validate --all`、`spec-refs.sh --check`、`section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 报告 `docs/team/reports/P420-dev2.md`，提交推分支，通知 PM

**注意**：这条不要求你一次把 41 条都变绿；要求的是把上面两个根因修掉并在报告里写清「剩下哪些红、每个红的真因」。
