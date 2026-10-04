# P8 · Apply: `rename-watchdog-to-pulse`（代码先行，规格增量待 P6 归档后刷新）

```
task:   P8
agent:  dev2
phase:  apply
change: rename-watchdog-to-pulse
deps:   P7 提案 ACCEPTED（docs/team/reviews/rename-watchdog-to-pulse-proposal.md）；用户批准并行开工（2026-09-16）
note:   并行纪律——你的分支基于 main。P6（deferred-delivery）还在另一个分支上没归档，它也改 watchdog 规格：
        你的规格 delta 文本按**今天 main 上**的规格写；P6 归档后 PM 会做一次"增量刷新"（把 P6 新增的场景并进
        你的 MODIFIED 重述）再归档你的 change。代码/文档/测试现在全做，不等。
```

## 范围（P7 提案已审，按其 tasks.md 顺序）

1. 命令组改名：`team pulse up|down|restart|status|logs`；`team watchdog …` 保留为别名并印一行弃用提示；
   `watchdog-status`/`install-`/`uninstall-watchdog`/`--no-watchdog` 同规则。
2. 窗口名 `teamsmith:pulse`；旧窗口名在别名期兼容（启动时检测到旧名窗口存在则复用/提示）。
3. `TEAM_PULSE_*` 新环境变量；旧 `TEAM_WATCH_*` 继续读（优先级：新 > 旧 > 默认，文档写清）。
4. state 文件名**别名期不动**（P7 提案的明确决定：防止两个巡检并存）。
5. SKILL.md / references / templates / 帮助输出全部改名；smoke 的对应断言改名 + 别名断言（旧命令仍工作）。
6. CHANGELOG 写迁移说明（老项目升级后看到什么）。

## 绑定条件

- 别名与弃用提示必须和 `pulse` 在**同一个版本**发布（不许出现旧名消失的版本）。
- 迁移夹具：沙盒里一个带旧配置 + 旧窗口名的项目，升级后两条路（新旧命令）都工作。
- 规格 delta：按今天 main 的文本写（不要预含 P6 的新场景）；PM 在归档前做刷新。

## 边界

你的文件：`scripts/**`、`SKILL.md`、`references/**`、`templates/**`、`tests/smoke.sh`、
`openspec/changes/rename-watchdog-to-pulse/**`、你的报告。不动 `openspec/specs/**`、不动账本、不归档。

## 验收

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
```
