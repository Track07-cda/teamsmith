---
id: P482
title: 制定帮助测试不再尝试性能测量的最小方案
agent: dev2
category: analysis
phase: opsx-propose
change: help-perf-entry-without-measurement
specs: verification, help-surface
deltas: verification
branch: task/P482-help-perf-entry-proposal
---

# P482 · 只制定正式方案，不实施

承接已接受的 `docs/team/reports/P481-dev2.md` 和 `docs/team/reviews/P481.md`，不要重做研究。`help-surface.sh` 的性能入口检查调用真实测量，但假终端不会给它首帧，命令超时或早退也可能被记成通过。旧 705 秒不能拆分，不承诺节省时长。现行 `verification#The performance suite is separate, self-describing, and its numbers are reference-only` 已禁止正确性检查调用性能测量；`verification#A gate that cannot judge says so` 仍需给这个单一替换写明覆盖边界，继续遵守 `help-surface#Every behaviour a help page states is declared and probed` 的既有要求，不放松通用规则，不为同一要求复制第二份规格。

规划保留真实 CLI `team perf --host` 从原临时项目交接给性能程序；在私有源内以一个短记录器替换测量程序，记录次数、真实参数、调用目录以及可辨认的退出状态；照旧核对项目原六面不变。足够证明入口交接而不是测量，不伪造读数，不把早退、超时、项目变化判过。说明改不了真实测量全程不写调用项目这一证据边界：独立的既有真实测量继续原样执行，不为它另起一轮；如需改独立测量来补证，先在报告标明缺口，不扩本变更。`team smoke --select 0`、性能实现、真实测量、正式超时和其余帮助检查均不动。不要为这个替换增加通用防护、框架或新配置。

交付 `openspec/changes/help-perf-entry-without-measurement/` 的 proposal、design、verification delta、tasks 和本席位报告。计划写明由独立验证者统一验证一个正常和两个故意破坏的短样本（提前正常返回无交接、仍交接但改变项目状态），避免先让作者跑一轮再重复跑。提案期只运行 `openspec validate help-perf-entry-without-measurement --strict`、`openspec validate --all`、`git diff --check` 和账本公开文件检查，记录真实退出码；不跑性能、整组帮助或完整测试，不改实现。小步本地提交，保留验收命令，不推送。交付后先交非作者审阅；本单不授权实施。

V182 首轮退回（`8f2901f9`）：仅修两处。`tasks.md` 明确故障复制目录根包含 `skills/teamsmith/`，`TEAM_HELP_SURFACE_TREE` 取目录根，不要传技能目录；仅改该副本 `scripts/team` 的 perf 分支。`verification` delta 的 *The named replacement cannot hide a lost CLI or renderer assertion* 封闭清单加入已定义的单一 perf 替换，保留原判据及其余文字。修后只做该 change strict 和 diff 检查，提交两处改动及短回执；不重跑首轮其它检查或任何行为测试，不写实现。
