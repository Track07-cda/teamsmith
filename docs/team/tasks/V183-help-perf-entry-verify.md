---
id: V183
title: 独立验证性能命令交接和两种失败
agent: verify
category: verify
phase: opsx-verify
change: help-perf-entry-without-measurement
specs: verification, help-surface
deltas: -
branch: task/V183-help-perf-entry-verify
---

# V183 · 一次正常、两次故障，不重跑整组

P483 实现者 dev-bob。固定候选 `645ec4b390ace52ef4408f1fcd080782abf1d556`，PM 干净检出 `/var/tmp/p483-review-645ec4b3.WqD4p1`，只读。按该检出 `openspec/changes/help-perf-entry-without-measurement/tasks.md` 的三个样本和原任务范围，在私有 `/var/tmp` 根合并执行一次；不要改实现或勾任务清单，由 PM 按两阶段证据收尾。跑在本席位后台，固定检出仅供读与执行。

只允许原生 `team review P483 --dir /var/tmp/p483-review-645ec4b3.WqD4p1 --branch 645ec4b390ace52ef4408f1fcd080782abf1d556` 写中央 `docs/team/reviews/P483.md` 与 `P483-verify.log`；通过 `TEAM_GATES='bash /var/tmp/<本次根>/<定点脚本>'` 和专属锁/环境运行，`OPENSPEC_TELEMETRY=0`。定点脚本应从固定检出执行实际新测试；正常传冻结根，故障各复制 `skills/teamsmith` 到独立 `<copy-root>/skills/teamsmith` 并把 `TEAM_HELP_SURFACE_TREE` 传复制根。只改变故障副本 `perf` 命令入口，勿改原测试判据或记录器；准确区分准备失败与应判失败。原始子命令 `rc`、回执、命名结果、六面比对和故障写入的实际私有位置均需有回执，特别是有有效回执而仅 `state` 变的第二条。旧版长等待只读源码，不再运行。确认性能程序未运行、`smoke` 等其它路径原样，旧及新覆盖各自说清。仅该变更 strict、必要语法/静态回执；全量、帮助其它组及真实性能都不跑，不承诺省时，真实性能全程项目不变未验。

报告 `docs/team/reports/V183-verify.md` 在本地提交，记录实际命令及退出码，私有现场保留直至 PM 接受。未完成不得报通过。候选已通过。合并版固定 `282b9dc79dd1c1fb751e50a040f2834612ff26be`，PM 干净检出 `/var/tmp/p483-merged-282b9dc7.LctwJq`。由同一验证者用原生 `team review P483 --dir /var/tmp/p483-merged-282b9dc7.LctwJq --branch 282b9dc79dd1c1fb751e50a040f2834612ff26be` 只对候选和此版本的 `help-surface.sh`、§51 调用方及 `team`/`cmd-docs`/`perf.sh` 相关文件字节、语法和接入点核对。前两份中央原件已由 PM 收存。不要重复三个样本、OpenSpec 校验或测量；保留私有原件至通知。