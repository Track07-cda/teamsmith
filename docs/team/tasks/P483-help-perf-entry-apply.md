---
id: P483
title: 去掉帮助检查中的无效性能测量并验证命令交接
agent: dev-bob
category: routine
phase: opsx-apply
change: help-perf-entry-without-measurement
specs: verification, help-surface
deltas: -
branch: task/P483-help-perf-entry-apply
---

# P483 · 只实施已接受的一处替换

读本人线程、OWNERSHIP、`docs/team/reviews/help-perf-entry-without-measurement-proposal.md` 的 ACCEPTED 记录及 `openspec/changes/help-perf-entry-without-measurement/{proposal,design,tasks}.md`、verification delta；按 OpenSpec apply 当前上下文和任务 1.1–1.2 实施。任务 2.x 由非作者验证，不得代跑或勾上。若工具要求任务更新，在实现和作者静态证据提交后只勾 1.x，不改规划正文、delta 或正式规格。

只改 `skills/teamsmith/tests/help-surface.sh` 一处相关路径：沿已接受方案用私有 CLI 副本和短记录器替换 perf 测量，保留真实参数与目录传递、明确退出状态、六面不变以及唯一通过判定。沿用原测试临时根与准备机制；不增加框架、运行开关、通用防护或第二次测试。其它帮助命令和 `team smoke --select 0` 调用不变；不改 CI、性能/CLI 实现、项目配置、真运行、超时。不得先补与本范围无关的测试清理。

作者验收只在本席位 `bash -n skills/teamsmith/tests/help-surface.sh`、`git diff --check` 及写集核对。如果执行已安排的结构和账本检查记录实际退出码，不将其称为操作验证。不要运行三个行为样本、帮助整组、`team perf` 或整套；三个样本由独立人员只执行一次。分步本地提交，写 `docs/team/reports/P483-dev-bob.md` 交精确提交号、改动、静态回执和未验边界；不推送、不发布。候选交付后停止更改待独立验证。
