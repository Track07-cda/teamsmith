---
id: V194
title: 独立验证两项提醒诊断的正式启动方式
agent: dev3
category: verify
phase: verify
change: -
specs: agent-self-reminder#PM tool availability is honestly diagnosed
deltas: -
branch: task/V194-ci-reminder-formal-test-verify
---

# V194 · 只在原 CI Pi 布局跑两例

作者 dev-bob；冻结候选 `acf2f86c` 的独立检出见线程。P493 原两例与正式启动对照已经实跑，见报告及私有包；复验复用原机理与旧侧原件，不再跑旧侧。按相同 Pi 1.6.0/npm 容器布局（可在自有临时前缀下载该依赖、复用已有本地固定镜像；不得升级当前用户安装、重建或改共享镜像），在当次隔离的 HOME/项目/tmux、本机 loopback 实际执行候选原入口 `bash skills/teamsmith/tests/remind-tool-real.sh --select=pm,noentry </dev/null`。按 P493 容器准备方式读原件，`P442_EVIDENCE` 外置、保留真实退出码与日志；从冻结 Git 对象导出的宿主可读副本须核对象与运行文件一致，不改任何源文件或加插桩来跑候选。

仅在两个原具名例都通过且 2/0、实际退出 0 时接受；核产品 `team_pm_start` 实际登记 PID，`pm.pid`/`pm.pid.spawn`/Pi `session-start` 一致与相应 `doctor` 原件、该有入口的 `ready`、无入口的 `unknown evidence:ENOENT`、真实停机后的 `not-running`，没有本轮遗留 Pi 或监听。只读核其余场景默认选择/启动行为未改；不主动新跑中断、旧侧、完整 §67 或整套。若实际失败，保留现场不自行返修或重跑。提醒事件和响应使用离线 Pi/受控 loopback，不连真实模型或账号；不碰项目、状态、发布物和 CI。交 `docs/team/reports/V194-dev3.md`、原件位置和实码；长命令后台，收割后报告。合并后同一人核对应字节，不重复两例。